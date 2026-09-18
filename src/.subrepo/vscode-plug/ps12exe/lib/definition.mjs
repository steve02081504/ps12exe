import path from 'node:path'

const URL_RE = /^(?:https?|ftp):\/\//i
const EXPRESSION_RE = /\$\(/

// #_include_as_value <name> <path>, #_include_as_base64 <name> <path>, ...
const INCLUDE_AS_RE = /^\s*#_include_as_(?:value|base64|bytes)\s+[A-Z_a-z]\w*\s+(.+?)\s*$/
// #_include <path>
const INCLUDE_RE = /^\s*#_include\s+(.+?)\s*$/
// #_pragma Resources.Icon <path>
const PRAGMA_PATH_RE = /^\s*#_pragma\s+resources\.icon\s+(.+?)\s*$/i

/**
 * 去掉路径两端的 PowerShell 引号。
 *
 * @param {string} value - 待处理的原始路径文本
 * @returns {string} 去引号后的路径
 */
export function unquote (value) {
	const trimmed = value.trim()
	if (trimmed.length >= 2 && trimmed.startsWith('\'') && trimmed.endsWith('\'')) return trimmed.slice(1, -1).replace(/''/g, '\'')
	if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) return trimmed.slice(1, -1).replace(/""/g, '"')
	return trimmed
}

/**
 * 解析 include 指令或 `#_pragma Resources.Icon …` 引用的文件，复刻 ps12exe 自身的路径处理（`$PSScriptRoot` 替换以及相对于脚本目录的解析）。
 *
 * @param {string} line - 待解析的脚本行
 * @param {string} baseDir 正在编辑的脚本所在目录
 * @returns {{ file: string, start: number, end: number } | null} 解析出的文件引用，未引用文件时为 null
 */
export function resolveDirectivePath (line, baseDir) {
	const match = INCLUDE_AS_RE.exec(line) || INCLUDE_RE.exec(line) || PRAGMA_PATH_RE.exec(line)
	if (!match) return null

	const raw = match[1]
	const start = line.indexOf(raw)
	if (start < 0) return null

	const value = unquote(raw)
	if (!value || URL_RE.test(value) || EXPRESSION_RE.test(value)) return null

	let resolved = value.replace(/\$psscriptroot/gi, baseDir)
	if (!path.isAbsolute(resolved)) resolved = path.join(baseDir, resolved)

	return { file: path.normalize(resolved), start, end: start + raw.length }
}
