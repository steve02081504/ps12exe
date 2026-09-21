// ps12exe 命令行调用的参数支持：识别脚本里的 `ps12exe …` 调用中的参数名与哈希表成员键，并为它们提供悬浮说明与未知名字诊断。
//
// 命令行与 `#_pragma` 使用同一份编译参数数据（`lib/pragma.mjs` 读取已安装模块的 `ConsoleHelpData.PrarmsData`），
// 因此这里把成员路径也拼成点号路径（`-App @{ Windowed = … }` -> `app.windowed`）交给同一套查找逻辑。
//
// 解析是纯文本的（不启动 PowerShell），并复用 `lib/preprocessor.mjs#computeSkipMask` 跳过 here-string 与块注释；
// `#_!!` 行会被 ps12exe 去掉标记变成真实代码，所以照常解析。调用可以跨多行（`@{ … }` 展开），
// 因此这里按整个文档扫描，而不是逐行。

import { computeSkipMask } from './preprocessor.mjs'

/** 英文源字符串；它们同时也是 l10n bundle 的键。 */
export const CLI_MESSAGES = Object.freeze({
	unknownParameter: 'Unknown ps12exe parameter "{0}".',
	unknownMember: 'Unknown key "{0}" for the ps12exe parameter {1}.'
})

/** 诊断代码：未知的命令行参数。 */
export const CLI_PARAMETER_DIAGNOSTIC = 'ps12exe-parameter'
/** 诊断代码：未知的参数成员（哈希表键）。 */
export const CLI_MEMBER_DIAGNOSTIC = 'ps12exe-parameter-member'

// 命令名（小写）：脚本调用可写成 `ps12exe` 或 `ps12exe.ps1`。
const COMMAND_NAMES = new Set(['ps12exe', 'ps12exe.ps1'])
// 取哈希表值的参数（小写）；只有这些参数的 `@{ … }` 成员才参与检查。
const GROUP_PARAMS = new Set(['app', 'os', 'build', 'resources', 'signing'])

// 高级函数（`[CmdletBinding()]`）自动附带的通用参数（小写）；它们不在 PrarmsData 里，不能当成未知参数。
const COMMON_PARAMETERS = new Set([
	'verbose', 'debug', 'erroraction', 'warningaction', 'informationaction', 'progressaction',
	'errorvariable', 'warningvariable', 'informationvariable', 'outvariable', 'outbuffer',
	'pipelinevariable', 'whatif', 'confirm'
])

// `#_!!` 标记（含其后的一个可选空格）；ps12exe 会把它去掉，因此其后的内容是代码。
const BANG_RE = /^([\t ]*)#_!! ?/

/**
 * 把文档逐行复制一份，here-string/块注释整行替换为等长空格，并抹掉 `#_!!` 标记，使字符偏移与原文一致、解析时不会被它们干扰。
 *
 * @param {string} text - 文档全文
 * @returns {string} 用于扫描的文本（换行统一为 `\n`，行长不变）
 */
function maskText(text) {
	const lines = String(text).split(/\r\n|\n|\r/)
	const skip = computeSkipMask(lines)
	return lines.map((line, index) => {
		if (skip[index]) return ' '.repeat(line.length)
		const bang = BANG_RE.exec(line)
		if (bang) return ' '.repeat(bang[0].length) + line.slice(bang[0].length)
		return line
	}).join('\n')
}

/**
 * 跳过一段字符串字面量（`'…'` 或 `"…"`），双引号内的反引号转义与单引号的双写都会正确处理。跨行（未闭合）时停在行尾。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - 起始引号所在列
 * @returns {number} 结束引号之后（或行尾）的列
 */
function skipString(text, start) {
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
function readValueToken(text, start) {
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
 * 读取哈希表的一个键：裸词（字母/数字/下划线/连字符）或引号包裹的字符串。取不到键时返回 null。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - 键起始列
 * @returns {{ name: string, start: number, end: number } | null} 键名与区间，无法识别时为 null
 */
function readKey(text, start) {
	const char = text[start]
	if (char === '\'' || char === '"') {
		const end = skipString(text, start)
		if (end <= start + 1 || text[end - 1] !== char) return null
		const raw = text.slice(start + 1, end - 1).replace(/''/g, '\'')
		if (!raw || /[\r\n]/.test(raw)) return null
		return { name: raw, start, end }
	}
	const match = /^[A-Za-z_][A-Za-z0-9_-]*/.exec(text.slice(start))
	if (!match) return null
	return { name: match[0], start, end: start + match[0].length }
}

/**
 * 解析一个 `@{ … }` 哈希表字面量，收集其中成员键的路径与区间；值为 `@{ … }` 的成员会继续向下展开（`Build.Core.Aot`）。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - `@` 所在列
 * @param {string} group - 该哈希表对应的参数名的点号路径（小写，如 `app`、`build.core`）
 * @param {Array<{ kind: 'member', name: string, path: string, start: number, end: number }>} out - 收集结果
 * @returns {number} 匹配的 `}` 之后的列
 */
function parseHashtable(text, start, group, out) {
	let i = start + 2
	while (i < text.length) {
		const char = text[i]
		if (char === ' ' || char === '\t' || char === '\r' || char === '\n') { i++; continue }
		if (char === ';') { i++; continue }
		if (char === '`') { i += 2; continue }
		if (char === '#') {
			const newline = text.indexOf('\n', i)
			i = newline === -1 ? text.length : newline
			continue
		}
		if (char === '}') return i + 1

		const key = readKey(text, i)
		if (!key) {
			// 非键的条目（动态键等）整体跳过，避免卡住。
			const end = readValueToken(text, i)
			i = end > i ? end : i + 1
			continue
		}

		const path = `${group}.${key.name.toLowerCase()}`
		out.push({ kind: 'member', name: key.name, path, start: key.start, end: key.end })
		i = key.end
		while (text[i] === ' ' || text[i] === '\t' || text[i] === '\r') i++
		if (text[i] !== '=') continue
		i++
		while (text[i] === ' ' || text[i] === '\t' || text[i] === '\r' || text[i] === '\n') i++
		if (text[i] === '@' && text[i + 1] === '{') i = parseHashtable(text, i, path, out)
		else i = readValueToken(text, i)
	}
	return i
}

/**
 * 从命令名之后开始解析一次 ps12exe 调用的参数，直到语句结束（行尾、`;`、`|`、`)`、`}` 或注释）。
 *
 * @param {string} text - 待扫描的文本
 * @param {number} start - 命令名之后的列
 * @param {Array<{ kind: 'param'|'member', name: string, path: string, start: number, end: number }>} out - 收集结果
 * @returns {number} 调用结束的列
 */
function parseInvocation(text, start, out) {
	let i = start
	while (i < text.length) {
		const char = text[i]
		if (char === ' ' || char === '\t' || char === '\r') { i++; continue }
		if (char === '\n' || char === ';' || char === '|' || char === ')' || char === '}' || char === '#') break
		if (char === '`') { i += 2; continue }

		if (char === '-') {
			const match = /^-([A-Za-z_][A-Za-z0-9_]*)/.exec(text.slice(i))
			if (!match) { i = readValueToken(text, i); continue }
			const name = match[1]
			out.push({ kind: 'param', name, path: name.toLowerCase(), start: i, end: i + match[0].length })
			i += match[0].length

			let valueStart = -1
			if (text[i] === ':') valueStart = i + 1
			else {
				let j = i
				while (text[j] === ' ' || text[j] === '\t') j++
				const next = text[j]
				if (j < text.length && next !== '-' && next !== '\n' && next !== ';' && next !== '|' && next !== ')' && next !== '}' && next !== '#')
					valueStart = j
			}
			if (valueStart < 0) continue
			if (text[valueStart] === '@' && text[valueStart + 1] === '{' && GROUP_PARAMS.has(name.toLowerCase()))
				i = parseHashtable(text, valueStart, name.toLowerCase(), out)
			else
				i = readValueToken(text, valueStart)
			continue
		}

		i = readValueToken(text, i)
	}
	return i
}

/**
 * 求绝对偏移的二分查找辅助：返回每个偏移所在行号与行内列号。
 *
 * @param {number[]} lineStarts - 每一行的起始偏移（升序）
 * @param {number} index - 绝对偏移
 * @returns {{ line: number, column: number }} 行列（从零开始）
 */
function locate(lineStarts, index) {
	let low = 0
	let high = lineStarts.length - 1
	while (low < high) {
		const mid = (low + high + 1) >> 1
		if (lineStarts[mid] <= index) low = mid
		else high = mid - 1
	}
	return { line: low, column: index - lineStarts[low] }
}

/**
 * 扫描文档中所有 ps12exe 调用的参数名与哈希表成员键，返回带绝对偏移、行列与路径的条目。
 *
 * @param {string} text - 文档全文
 * @returns {Array<{ kind: 'param'|'member', name: string, path: string, start: number, end: number, line: number, startColumn: number, endColumn: number }>} 条目列表
 */
export function scanCliInvocations(text) {
	const masked = maskText(text)
	const lineStarts = [0]
	for (let i = 0; i < masked.length; i++)
		if (masked[i] === '\n') lineStarts.push(i + 1)

	const found = []
	let i = 0
	let expectCommand = true
	while (i < masked.length) {
		const char = masked[i]
		if (char === '\n') { i++; expectCommand = true; continue }
		if (char === ' ' || char === '\t' || char === '\r') { i++; continue }
		if (char === '#') {
			const newline = masked.indexOf('\n', i)
			i = newline === -1 ? masked.length : newline
			continue
		}
		if (char === '`') { i += 2; continue }
		if (char === '\'' || char === '"') { i = skipString(masked, i); continue }

		if (expectCommand) {
			if (char === '&' || char === '.' || char === '{' || char === '(' || char === ';' || char === '|' || char === '=') { i++; continue }
			const match = /^[A-Za-z_][A-Za-z0-9_.-]*/.exec(masked.slice(i))
			if (match) {
				i += match[0].length
				if (COMMAND_NAMES.has(match[0].toLowerCase())) {
					i = parseInvocation(masked, i, found)
					expectCommand = true
					continue
				}
			}
			else
				i++
			expectCommand = false
			continue
		}

		if (char === ';' || char === '|' || char === '(' || char === '{' || char === '=') expectCommand = true
		i++
	}

	return found.map((entry) => {
		const start = locate(lineStarts, entry.start)
		const end = locate(lineStarts, entry.end)
		return {
			...entry,
			line: start.line,
			startColumn: start.column,
			endColumn: end.column
		}
	})
}

/**
 * 返回 `line`/`character` 处（从零开始）属于 ps12exe 调用的参数或成员键；不在其上时返回 null。
 *
 * @param {string} text - 文档全文
 * @param {number} line - 光标所在行
 * @param {number} character - 光标所在列
 * @returns {{ kind: 'param'|'member', name: string, path: string, start: number, end: number, line: number, startColumn: number, endColumn: number } | null} 命中的条目
 */
export function cliTokenAt(text, line, character) {
	return scanCliInvocations(text).find(
		(entry) => entry.line === line && character >= entry.startColumn && character <= entry.endColumn
	) || null
}

/**
 * 计算已知路径集合：PrarmsData 压平后的叶子键，以及所有点号前缀（分组，如 `build`、`build.core`）。
 *
 * @param {Map<string, { name: string, description: string }>} data - 扁平化后的说明数据
 * @returns {{ leaves: Set<string>, groups: Set<string> }} 叶子与分组的路径集合
 */
function pathSets(data) {
	const leaves = new Set(data.keys())
	const groups = new Set()
	for (const key of data.keys()) {
		let index = key.indexOf('.')
		while (index >= 0) {
			groups.add(key.slice(0, index))
			index = key.indexOf('.', index + 1)
		}
	}
	return { leaves, groups }
}

/**
 * 扫描文档中 ps12exe 调用的参数与成员键，对无法在 PrarmsData（或通用参数）中找到的名字给出诊断。被
 * `# use_ps12exe:ignore` 抑制的行由调用方过滤。
 *
 * @param {string} text - 文档全文
 * @param {Map<string, { name: string, description: string }>} data - 扁平化后的说明数据
 * @returns {Array<{ line: number, severity: 'error', message: string, args: string[], code: string, start: number, end: number }>} 诊断列表
 */
export function analyzeCliUsage(text, data) {
	if (!data) return []
	const { leaves, groups } = pathSets(data)
	/**
	 * 某个小写点号路径是否为已知的参数、成员或分组。
	 *
	 * @param {string} path - 小写点号路径
	 * @returns {boolean} 已知时为 true
	 */
	const known = (path) => leaves.has(path) || groups.has(path)
	const diagnostics = []

	for (const entry of scanCliInvocations(text)) {
		if (entry.kind === 'param') {
			if (known(entry.path) || COMMON_PARAMETERS.has(entry.path)) continue
			diagnostics.push({
				line: entry.line,
				severity: /** @type {'error'} */ 'error',
				message: CLI_MESSAGES.unknownParameter,
				args: [entry.name],
				code: CLI_PARAMETER_DIAGNOSTIC,
				start: entry.startColumn,
				end: entry.endColumn
			})
			continue
		}

		// 成员只在所属参数确实是已知分组时才检查；未知参数已在上面报过，避免重复。
		const group = entry.path.slice(0, entry.path.indexOf('.'))
		if (!groups.has(group) || known(entry.path)) continue
		diagnostics.push({
			line: entry.line,
			severity: /** @type {'error'} */ 'error',
			message: CLI_MESSAGES.unknownMember,
			args: [entry.name, `-${canonicalGroup(data, group)}`],
			code: CLI_MEMBER_DIAGNOSTIC,
			start: entry.startColumn,
			end: entry.endColumn
		})
	}

	return diagnostics
}

/**
 * 用某个后代键的规范大小写还原分组名（`app` -> `App`、`build.core` -> `Build.Core`）。
 *
 * @param {Map<string, { name: string, description: string }>} data - 扁平化后的说明数据
 * @param {string} lowerGroup - 分组的点号路径（小写）
 * @returns {string} 分组显示名；找不到后代时原样返回
 */
function canonicalGroup(data, lowerGroup) {
	const prefix = `${lowerGroup}.`
	for (const [key, entry] of data)
		if (key.startsWith(prefix)) return entry.name.slice(0, lowerGroup.length)
	return lowerGroup
}
