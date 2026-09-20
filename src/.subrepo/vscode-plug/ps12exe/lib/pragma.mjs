// `#_pragma` 变量名的支持：解析光标处的 pragma 名，并按需从**当前安装的** ps12exe 模块的本地化 ps1
// （`<ModuleBase>/src/locale/<locale>.ps1` 的 `ConsoleHelpData.PrarmsData`）读取各区域参数说明。
//
// 之所以在运行时调用已安装模块而不是内置一份快照：扩展的 `ps12exe.autoUpdate` 会持续更新模块，而
// 说明文字必须与用户实际使用的编译器版本一致，内置快照会随版本漂移。
import { psQuote, resolvePowerShell, runScript } from './powershell.mjs'

const MARKER = 'PS12EXE_PRAGMA:'

// `#_pragma` 后的变量名：一段或多段标识符（`App.Windowed`、`Build.ConstEval.Enabled` …）。
const PRAGMA_NAME_RE = /^([\t ]*)#_pragma[\t ]+([A-Z_a-z]\w*(?:\.[A-Z_a-z]\w*)*)/

/** @type {Map<string, Promise<Map<string, { name: string, description: string }>>>} */
const cache = new Map()

/**
 * 返回 `line` 上 `character` 列处 `#_pragma` 变量名的名称与区间。光标不在变量名上时返回 `null`。
 *
 * @param {string} line - 待解析的脚本行
 * @param {number} character - 光标所在的列号
 * @returns {{ name: string, start: number, end: number } | null} `start`/`end` 是从零开始、含末尾的区间
 */
export function pragmaNameAt(line, character) {
	const match = PRAGMA_NAME_RE.exec(line)
	if (!match) return null
	const start = match[0].length - match[2].length
	const end = start + match[2].length
	if (character >= start && character <= end) return { name: match[2], start, end }
	return null
}

/**
 * 把该区域的 `PrarmsData` 压平成「小写点号路径 -> { name, description }」。嵌套哈希表（`App`、`Build` …）
 * 展开为 `App.Windowed` 这样的键，标量参数（`Golf` …）保持原样。
 *
 * @param {object} data - 待压平的 PrarmsData
 * @returns {Map<string, { name: string, description: string }>} 小写点号路径到说明的映射
 */
function flattenPragmaData(data) {
	const out = new Map()
	/**
	 *
	 * @param {object} value - 当前层级的参数数据
	 * @param {string} prefix - 当前层级的点号路径前缀
	 */
	const walk = (value, prefix) => {
		for (const [key, entry] of Object.entries(value)) {
			const full = prefix ? `${prefix}.${key}` : key
			if (entry && typeof entry === 'object') walk(entry, full)
			else out.set(full.toLowerCase(), { name: full, description: String(entry) })
		}
	}
	walk(data, '')
	return out
}

/**
 * 在已安装模块的本地化 ps1 中读取指定区域的 `PrarmsData`。区域缺失时回退到同语言前缀，再回退到 `en-UK`，
 * 与 `src/LocaleLoader.ps1` 的策略一致。
 *
 * @param {{ command: string }} host - PowerShell 宿主
 * @param {string} locale - ps12exe 区域代码
 * @returns {Promise<object>} 解析出的 PrarmsData
 */
async function fetchPragmaData(host, locale) {
	const script = [
		'$ErrorActionPreference = "Stop"',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		'$module = Get-Module -ListAvailable -Name ps12exe | Sort-Object Version -Descending | Select-Object -First 1',
		'if (-not $module) { exit 3 }',
		'$dir = Join-Path $module.ModuleBase "src/locale"',
		`$name = ${psQuote(locale)}`,
		'$file = Join-Path $dir "$name.ps1"',
		'if (-not (Test-Path -LiteralPath $file)) {',
		'  $head = ($name -split "-")[0]',
		'  $similar = Get-ChildItem -LiteralPath $dir -Filter "*.ps1" | Where-Object { $_.BaseName -like "$head*" } | Select-Object -First 1',
		'  $file = if ($similar) { $similar.FullName } else { Join-Path $dir "en-UK.ps1" }',
		'}',
		'if (-not (Test-Path -LiteralPath $file)) { exit 4 }',
		'$data = & $file',
		`Write-Output ("${MARKER}" + ($data.ConsoleHelpData.PrarmsData | ConvertTo-Json -Depth 8 -Compress))`,
		'exit 0'
	].join('\n')

	const result = await runScript(host, script)
	if (result.error) throw result.error
	if (result.code !== 0) throw new Error(`reading ps12exe locale data failed (exit ${result.code})`)
	const line = String(result.stdout || '').split(/\r?\n/).find((entry) => entry.startsWith(MARKER))
	if (!line) throw new Error('no pragma data in PowerShell output')
	return JSON.parse(line.slice(MARKER.length))
}

/**
 * 读取（并缓存）指定区域的 pragma 说明数据。失败的结果不会缓存，因此模块安装完成后会自动重试。
 *
 * @param {string} [locale] ps12exe 区域代码（见 `lib/locale.mjs#toPs12exeLocale`）
 * @returns {Promise<Map<string, { name: string, description: string }>>} 小写点号路径到说明的映射
 */
export async function getPragmaData(locale) {
	const key = locale || 'en-UK'
	let pending = cache.get(key)
	if (!pending) {
		pending = (async () => {
			const host = await resolvePowerShell()
			if (!host || !host.moduleVersion) throw new Error('ps12exe module is not available')
			return flattenPragmaData(await fetchPragmaData(host, key))
		})()
		pending.catch(() => cache.delete(key))
		cache.set(key, pending)
	}
	return pending
}

/**
 * 在扁平数据中查找一个 pragma 名。`no` 前缀（如 `#_pragma noGolf`）会回退到其基名。
 *
 * @param {Map<string, { name: string, description: string }>} data - 扁平化后的说明数据
 * @param {string} name - 待查找的 pragma 名
 * @returns {{ name: string, description: string, negated: boolean } | null} 查到的说明与是否取反，未找到时为 null
 */
export function lookupPragma(data, name) {
	const lower = name.toLowerCase()
	const exact = data.get(lower)
	if (exact) return { ...exact, negated: false }
	const base = data.get(lower.startsWith('no') ? lower.slice(2) : '')
	if (base) return { ...base, negated: true }
	return null
}

/**
 * 为 `#_pragma` 名生成补全候选。`prefix` 是已输入的部分（可能含点号与尾随点，如 `App.Win`）。
 *
 * - 没有点号时列出顶层参数（`App`、`Os`、`Golf` …）；可展开的顶层参数补全为带尾随点的 `App.`。
 * - 有父级点号时列出该父级的直接子键。
 *
 * @param {Map<string, { name: string, description: string }>} data - 扁平化后的说明数据
 * @param {string} prefix - 已输入的前缀
 * @returns {Array<{ name: string, insertText: string, kind: 'object' | 'value', description: string }>} 补全候选列表
 */
export function buildPragmaCandidates(data, prefix) {
	const entries = new Map(data)

	// 所有作为其他键前缀的段（`app`、`build.consteval` …）都是可继续展开的对象：即使它们自身没有说明
	// （如 `App` 只是分组），也要作为候选出现。
	const objectNames = new Map()
	for (const key of data.keys()) {
		let index = key.indexOf('.')
		while (index >= 0) {
			const segment = key.slice(0, index)
			objectNames.set(segment, data.get(key).name.slice(0, index))
			index = key.indexOf('.', index + 1)
		}
	}
	for (const [segment, name] of objectNames)
		if (!entries.has(segment)) entries.set(segment, { name, description: '' })

	const lower = String(prefix || '').toLowerCase()
	const parentEnd = lower.lastIndexOf('.')
	const parent = parentEnd >= 0 ? lower.slice(0, parentEnd + 1) : ''
	const candidates = []
	for (const [key, entry] of entries) {
		if (!key.startsWith(parent) || !key.startsWith(lower)) continue
		if (key.slice(parent.length).includes('.')) continue
		const isObject = objectNames.has(key)
		candidates.push({
			name: entry.name,
			insertText: isObject ? `${entry.name}.` : entry.name,
			kind: isObject ? 'object' : 'value',
			description: entry.description
		})
	}
	candidates.sort((a, b) => a.name.localeCompare(b.name))
	return candidates
}

/** 清空缓存；模块更新后调用，使说明文字立即跟随新版本。 */
export function clearPragmaCache() {
	cache.clear()
}
