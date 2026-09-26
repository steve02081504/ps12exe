// PowerShell 单行文本的词法辅助：跳过字符串字面量、读取一个值 token，以及判断一行在语法上是否完整。
// 供 `lib/commands.mjs`（命令名扫描）与 `lib/cli.mjs`（ps12exe 调用参数扫描）共用。

/**
 * `#_!!` 转义标记（含其后的一个可选空格）。ps12exe 会把它去掉，因此其后的内容是代码。
 */
export const BANG_MARKER_RE = /^([\t ]*)#_!! ?/

/**
 * 跳过一段字符串字面量（`'…'` 或 `"…"`），双引号内的反引号转义与单引号的双写都会正确处理。跨行（未闭合）时停在行尾。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - 起始引号所在列
 * @returns {number} 结束引号之后（或行尾）的列
 */
export function skipString(text, start) {
	const quote = text[start]
	let i = start + 1
	while (i < text.length) {
		const char = text[i]
		if (quote === '"' && char === '`') { i += 2; continue }
		if (char === quote) {
			if (text[i + 1] === quote) { i += 2; continue }
			return i + 1
		}
		if (char === '\n') return i
		i++
	}
	return i
}

/**
 * 从 `start` 起读取一个值 token（字符串、`@{…}`/`@(…)`/`$(…)`/`[…]`/`(…)`/`{…}` 字面量或裸词），返回其结束列。
 * 括号层级内的空白不打断 token，因此 `@{a='b c'}` 与 `$(Get-Item 'x y')` 都算一个 token。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - token 起始列
 * @returns {number} token 结束列（不含）
 */
export function readValueToken(text, start) {
	let i = start
	let depth = 0
	while (i < text.length) {
		const char = text[i]
		if (char === '`') { i += 2; continue }
		if (char === '\'' || char === '"') { i = skipString(text, i); continue }
		if (char === '(' || char === '[' || char === '{') { depth++; i++; continue }
		if (char === ')' || char === ']' || char === '}') {
			if (depth === 0) break
			depth--
			i++
			continue
		}
		if (depth === 0 && (char === ' ' || char === '\t' || char === '\r' || char === '\n' || char === ';' || char === '|')) break
		i++
	}
	return i
}

/**
 * 判断一行在语法上是否完整（引号与括号都闭合，且不以续行反引号结尾）。不完整时调用可能跨行，无法静态改写。
 *
 * @param {string} line - 待检查的行
 * @returns {boolean} 完整时为 true
 */
export function isCompleteLine(line) {
	let depth = 0
	for (let i = 0; i < line.length; i++) {
		const char = line[i]
		if (char === '#') break
		if (char === '\'' || char === '"') { i = skipString(line, i) - 1; continue }
		if (char === '`') { i++; continue }
		if (char === '(' || char === '[' || char === '{') depth++
		else if (char === ')' || char === ']' || char === '}') {
			depth--
			if (depth < 0) return false
		}
	}
	return depth === 0 && !line.trimEnd().endsWith('`')
}
