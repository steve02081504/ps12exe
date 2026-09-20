// `#_pragma Resources.Icon` 的支持：解析图标路径（含 desktop.ini 风格的 `,索引`），并在悬浮提示里预览图标内容。
//
// 预览分两条路径：浏览器可直接渲染的图片（png/jpg/gif/bmp/webp）在 JS 中读成 data URI，不启动进程；`.ico`、`.tif`
// 以及 exe/dll 等 PE 资源容器则由 PowerShell 用 System.Drawing 统一转成 PNG 的 data URI。容器后缀、索引约定与
// `src/InitCompileThings.ps1` 保持一致（PrivateExtractIcons 取 256 像素，失败再退回 ExtractIconEx 大图标）。
import fsp from 'node:fs/promises'
import path from 'node:path'

import { resolveDirectivePath } from './definition.mjs'
import { psQuote, resolvePlainPowerShell, runScript } from './powershell.mjs'

const MARKER = 'PS12EXE_ICON:'
const ICON_TYPE = 'Ps12exeIconPreview'

// 浏览器原生可渲染的图片：直接读成 data URI，省去一次 PowerShell 调用。
const RENDERABLE_MIME = Object.freeze({
	'.png': 'image/png',
	'.jpg': 'image/jpeg',
	'.jpeg': 'image/jpeg',
	'.gif': 'image/gif',
	'.bmp': 'image/bmp',
	'.webp': 'image/webp'
})

// 需要从 PE 资源里抽取图标的容器后缀（与 src/InitCompileThings.ps1 的 $iconContainerExtensions 一致）。
const CONTAINER_EXTENSIONS = Object.freeze(['.exe', '.dll', '.ocx', '.cpl', '.scr', '.icl', '.bpl', '.dpl', '.drv', '.sys', '.mun'])
// ps12exe 认可的图片后缀；给出索引但后缀不在其中时同样按 PE 资源抽取。
const IMAGE_EXTENSIONS = new Set(['.ico', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tif', '.tiff', '.webp'])

// 只在 Windows 上有意义（图标来自 PE 资源 / GDI+）；其它平台会由脚本自行失败，返回 null。
const EXTRACTOR_CODE = [
	'using System;',
	'using System.Runtime.InteropServices;',
	`public static class ${ICON_TYPE} {`,
	'\t[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]',
	'\tpublic static extern uint PrivateExtractIcons(string lpszFile, int nIconIndex, int cxIcon, int cyIcon, IntPtr[] phicon, uint[] piconid, uint nIcons, uint flags);',
	'\t[DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]',
	'\tpublic static extern uint ExtractIconEx(string lpszFile, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, uint nIcons);',
	'\t[DllImport("user32.dll", SetLastError = true)]',
	'\tpublic static extern bool DestroyIcon(IntPtr hIcon);',
	'}'
].join('\n')

/** @type {Map<string, Promise<string | null>>} 「文件 + 修改时间 + 索引」到预览 data URI 的缓存。 */
const previewCache = new Map()

/**
 * 返回 `line` 上 `character` 列处 `#_pragma Resources.Icon` 引用的图标文件；光标不在路径上或该行不是图标 pragma 时为 null。
 *
 * @param {string} line - 待解析的脚本行
 * @param {number} character - 光标所在的列号
 * @param {string} baseDir - 正在编辑的脚本所在目录
 * @returns {{ file: string, kind: 'icon', index: number | null, start: number, end: number } | null} 图标文件引用
 */
export function resolveIconAt (line, character, baseDir) {
	const target = resolveDirectivePath(line, baseDir)
	if (!target || target.kind !== 'icon') return null
	if (character < target.start || character > target.end) return null
	return target
}

/**
 * 判断图标是否需要从 PE 资源中抽取（而不是当作普通图片文件读取），与 ps12exe 的判定一致。
 *
 * @param {string} file - 图标文件路径
 * @param {number | null} index - 显式给出的资源索引
 * @returns {boolean} 需要抽取时为真
 */
export function needsIconExtraction (file, index) {
	const extension = path.extname(file).toLowerCase()
	if (CONTAINER_EXTENSIONS.includes(extension)) return true
	return index !== null && index !== undefined && !IMAGE_EXTENSIONS.has(extension)
}

/**
 * 浏览器可直接渲染时返回对应的 MIME，否则返回 null。
 *
 * @param {string} file - 图片文件路径
 * @returns {string | null} MIME 类型
 */
export function renderableMime (file) {
	return RENDERABLE_MIME[path.extname(file).toLowerCase()] || null
}

/**
 * 读取（并缓存）图标的预览 data URI。无法读取或转换时返回 null（悬浮提示回退到不显示预览）。
 * 缓存键包含修改时间，因此图标文件被替换后会自动重新读取。
 *
 * @param {{ file: string, index: number | null }} target - `resolveIconAt` 解析出的图标引用
 * @returns {Promise<string | null>} 预览 data URI，无法预览时为 null
 */
export async function getIconPreview ({ file, index }) {
	const stat = await fsp.stat(file).catch(() => undefined)
	if (!stat || !stat.isFile()) return null

	const key = `${file.toLowerCase()}|${stat.mtimeMs}|${index === null || index === undefined ? '' : index}`
	const cached = previewCache.get(key)
	if (cached) return cached

	const pending = buildPreview(file, index)
	previewCache.set(key, pending)
	pending.catch(() => previewCache.delete(key))
	return pending
}

/**
 * 生成预览 data URI：可直接渲染的图片直接内联，其余交给 {@link buildProbeScript} 转换。
 *
 * @param {string} file - 图标文件路径
 * @param {number | null} index - 资源索引
 * @returns {Promise<string | null>} 预览 data URI
 */
async function buildPreview (file, index) {
	const mime = renderableMime(file)
	if (mime && !needsIconExtraction(file, index)) 
		try {
			const bytes = await fsp.readFile(file)
			return `data:${mime};base64,${bytes.toString('base64')}`
		}
		catch {
			return null
		}

	const host = await resolvePlainPowerShell()
	if (!host) return null

	const result = await runScript(host, buildProbeScript(file, index))
	if (result.error || result.code !== 0) return null
	const marker = String(result.stdout || '').split(/\r?\n/).find((entry) => entry.startsWith(MARKER))
	if (!marker) return null
	return `data:image/png;base64,${marker.slice(MARKER.length).trim()}`
}

/**
 * 构造把图标统一转成 PNG 并输出 base64 的 PowerShell 脚本。它会像 ps12exe 那样先按索引或容器后缀判断是否需要
 * 从 PE 资源抽取图标，再按最大 96 像素绘制，最后输出 `PS12EXE_ICON:<base64>`。
 *
 * @param {string} file - 图标文件路径
 * @param {number | null} index - 资源索引；null 表示未显式给出
 * @returns {string} PowerShell 脚本
 */
export function buildProbeScript (file, index) {
	const containers = CONTAINER_EXTENSIONS.map((extension) => `'${extension}'`).join(', ')
	const images = [...IMAGE_EXTENSIONS].map((extension) => `'${extension}'`).join(', ')
	const numericIndex = Number.isInteger(index) ? index : -1

	return [
		'$ErrorActionPreference = "Stop"',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		'Add-Type -AssemblyName System.Drawing',
		`$path = ${psQuote(file)}`,
		`$index = ${numericIndex}`,
		'$extension = [System.IO.Path]::GetExtension($path).ToLower()',
		`$containerExtensions = @(${containers})`,
		`$imageExtensions = @(${images})`,
		'$source = $null',
		'try {',
		'  if (($containerExtensions -contains $extension) -or ($index -ge 0 -and ($imageExtensions -notcontains $extension))) {',
		'    if ($index -lt 0) { $index = 0 }',
		`    if (-not ('${ICON_TYPE}' -as [type])) {`,
		'      Add-Type -TypeDefinition @\'',
		EXTRACTOR_CODE,
		'\'@',
		'    }',
		'    $handle = [IntPtr]::Zero',
		'    $handles = [IntPtr[]]::new(1)',
		`    [void][${ICON_TYPE}]::PrivateExtractIcons($path, $index, 256, 256, $handles, $null, 1, 0)`,
		'    if ($handles[0] -ne [IntPtr]::Zero) { $handle = $handles[0] }',
		'    else {',
		'      $handles = [IntPtr[]]::new(1)',
		`      [void][${ICON_TYPE}]::ExtractIconEx($path, $index, $handles, $null, 1)`,
		'      if ($handles[0] -ne [IntPtr]::Zero) { $handle = $handles[0] }',
		'    }',
		'    if ($handle -eq [IntPtr]::Zero) { exit 2 }',
		'    $icon = [System.Drawing.Icon]::FromHandle($handle)',
		'    try { $source = $icon.ToBitmap() }',
		`    finally { $icon.Dispose(); [void][${ICON_TYPE}]::DestroyIcon($handle) }`,
		'  }',
		'  else {',
		'    $image = [System.Drawing.Image]::FromFile($path)',
		'    try { $source = New-Object System.Drawing.Bitmap($image) }',
		'    finally { $image.Dispose() }',
		'  }',
		'  $limit = 96',
		'  $scale = [Math]::Min($limit / $source.Width, $limit / $source.Height)',
		'  if ($scale -gt 1) { $scale = 1 }',
		'  $width = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))',
		'  $height = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))',
		'  $bitmap = New-Object System.Drawing.Bitmap($width, $height)',
		'  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)',
		'  try {',
		'    $graphics.Clear([System.Drawing.Color]::Transparent)',
		'    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic',
		'    $graphics.DrawImage($source, 0, 0, $width, $height)',
		'  } finally { $graphics.Dispose() }',
		'  $stream = New-Object System.IO.MemoryStream',
		'  try {',
		'    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)',
		`    Write-Output ("${MARKER}" + [Convert]::ToBase64String($stream.ToArray()))`,
		'  } finally { $stream.Dispose(); $bitmap.Dispose() }',
		'  exit 0',
		'}',
		'catch { exit 3 }',
		'finally { if ($source) { $source.Dispose() } }'
	].join('\n')
}

/** 清空预览缓存；主要用于测试。 */
export function clearIconPreviewCache () {
	previewCache.clear()
}
