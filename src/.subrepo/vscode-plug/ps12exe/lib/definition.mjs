import path from 'node:path'

const URL_RE = /^(?:https?|ftp):\/\//i
const EXPRESSION_RE = /\$\(/

// #_include_as_value <name> <path>, #_include_as_base64 <name> <path>, ...
const INCLUDE_AS_RE = /^\s*#_include_as_(?:value|base64|bytes)\s+[A-Z_a-z]\w*\s+(.+?)\s*$/
// #_include <path>
const INCLUDE_RE = /^\s*#_include\s+(.+?)\s*$/
// #_pragma Resources.Icon <path>[,<index>]
const PRAGMA_PATH_RE = /^\s*#_pragma\s+resources\.icon\s+(.+?)\s*$/i
// desktop.ini 风格的图标索引：末尾 `,<整数>`（负数为资源 ID）。
const ICON_INDEX_RE = /^(.*),(-?\d+)$/

/**
 * 去掉路径两端的 PowerShell 引号。
 *
 * @param {string} value - 待处理的原始路径文本
 * @returns {string} 去引号后的路径
 */
export function unquote(value) {
	const trimmed = value.trim()
	if (trimmed.length >= 2 && trimmed.startsWith('\'') && trimmed.endsWith('\'')) return trimmed.slice(1, -1).replace(/''/g, '\'')
	if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) return trimmed.slice(1, -1).replace(/""/g, '"')
	return trimmed
}

/**
 * 拆分 `#_pragma Resources.Icon` 取值里 desktop.ini 风格的资源索引：末尾 `,<整数>` 是图标索引（负数为资源 ID），
 * 用于从 exe/dll 等 PE 资源容器中抽取图标。路径与索引都可以分别带 PowerShell 引号。
 *
 * @param {string} value - 已去引号的取值
 * @returns {{ value: string, index: number | null }} 去掉索引后的路径与索引
 */
export function splitIconIndex(value) {
	const match = ICON_INDEX_RE.exec(value)
	return match ? { value: unquote(match[1]), index: Number(match[2]) } : { value, index: null }
}

/**
 * 解析 include 指令或 `#_pragma Resources.Icon …` 引用的文件，复刻 ps12exe 自身的路径处理（`$PSScriptRoot` 替换以及相对于脚本目录的解析）。
 *
 * `Resources.Icon` 的取值支持 `path,index`（desktop.ini 风格，用于 exe/dll 等 PE 资源），因此 `file` 会去掉索引、
 * 而 `index` 会保留下来，供调用方抽取图标；`start`/`end` 始终覆盖包含索引在内的整段取值，方便光标落在任意位置都能跳转。
 *
 * @param {string} line - 待解析的脚本行
 * @param {string} baseDir 正在编辑的脚本所在目录
 * @returns {{ file: string, kind: 'icon' | 'include', index: number | null, start: number, end: number } | null} 解析出的文件引用，未引用文件时为 null
 */
export function resolveDirectivePath(line, baseDir) {
	const pragma = PRAGMA_PATH_RE.exec(line)
	const match = pragma || INCLUDE_AS_RE.exec(line) || INCLUDE_RE.exec(line)
	if (!match) return null

	const raw = match[1]
	const start = line.indexOf(raw)
	if (start < 0) return null

	let value = unquote(raw)
	if (!value || URL_RE.test(value) || EXPRESSION_RE.test(value)) return null

	let index = null
	if (pragma) {
		const parsed = splitIconIndex(value)
		value = parsed.value
		index = parsed.index
	}

	let resolved = value.replace(/\$psscriptroot/gi, baseDir)
	if (!path.isAbsolute(resolved)) resolved = path.join(baseDir, resolved)

	return { file: path.normalize(resolved), kind: pragma ? 'icon' : 'include', index, start, end: start + raw.length }
}
