// 复刻 ps12exe Preprocessor（src/ReadScriptFile.ps1）使用的指令检测：指令是一行以可选空白开头、后跟 `#_…` 的行，且允许尾随 `#comment`（ps12exe 使用相同的 `(?!#.*)` 前瞻）。`computeSkipMask` 会把 here-string 函数体和块注释视为不透明内容，因此 formatter 永远不会改写它们。`(?!#)` 前瞻复刻了 ps12exe 的 `(?!#.*)`：指令后允许尾随注释（例如 `#_if PSEXE #reason`），其他内容则不允许。
const IF_RE = /^\s*#_if\s+(\S+)\s*(?!#)/
const ELSE_RE = /^\s*#_else\s*(?!#)/
const ENDIF_RE = /^\s*#_endif\s*(?!#)/

const KNOWN_CONDITIONS = new Set(['psexe', 'psscript'])

// 英文源字符串；它们同时也是 l10n bundle 的键。
const MESSAGES = Object.freeze({
	missingEndIf: 'Missing end of if statement: {0}',
	nestedIfDeadCode: 'Nested #_if {0} inside #_if {1}: the enclosing condition already fixes this branch, so one side is dead code.',
	unknownCondition: 'Unknown condition: {0}; assuming false.',
	strayElse: '#_else without a matching #_if.',
	strayEndIf: '#_endif without a matching #_if.',
	duplicateElse: 'Duplicate #_else in the same #_if block.'
})

function detectEol (text) {
	return text.includes('\r\n') ? '\r\n' : '\n'
}

function splitLines (text) {
	return text.split(/\r\n|\n|\r/)
}

function leadingOf (line) {
	const match = line.match(/^[ \t]*/)
	return match ? match[0] : ''
}

/**
 * 解析文档中的结构性 preprocessor 指令。
 *
 * @param {string} text
 * @returns {{
 *   lines: string[],
 *   blocks: Array<{ startLine: number, endLine: number, elseLine: number | null, condition: string, parent: number | null, depth: number, closed: boolean }>,
 *   diagnostics: Array<{ line: number, severity: 'error' | 'warning', message: string, args: string[] }>
 * }}
 */
function analyze (text) {
	const lines = splitLines(text)
	const skip = computeSkipMask(lines)
	const blocks = []
	const diagnostics = []
	/** @type {number[]} */
	const stack = []

	for (let line = 0; line < lines.length; line++) {
		if (skip[line]) continue
		const content = lines[line]
		const ifMatch = content.match(IF_RE)

		if (ifMatch) {
			const condition = ifMatch[1]
			const parent = stack.length ? stack[stack.length - 1] : null
			if (parent !== null) {
				diagnostics.push({
					line,
					severity: 'warning',
					message: MESSAGES.nestedIfDeadCode,
					args: [condition, blocks[parent].condition]
				})
			}
			if (!KNOWN_CONDITIONS.has(condition.toLowerCase())) {
				diagnostics.push({
					line,
					severity: 'error',
					message: MESSAGES.unknownCondition,
					args: [condition]
				})
			}
			const block = {
				startLine: line,
				endLine: lines.length - 1,
				elseLine: null,
				condition,
				parent,
				depth: stack.length,
				closed: false
			}
			blocks.push(block)
			stack.push(blocks.length - 1)
			continue
		}

		if (ELSE_RE.test(content)) {
			if (!stack.length) {
				diagnostics.push({ line, severity: 'warning', message: MESSAGES.strayElse, args: [] })
				continue
			}
			const top = blocks[stack[stack.length - 1]]
			if (top.elseLine !== null) {
				diagnostics.push({ line, severity: 'warning', message: MESSAGES.duplicateElse, args: [] })
			}
			top.elseLine = line
			continue
		}

		if (ENDIF_RE.test(content)) {
			if (!stack.length) {
				diagnostics.push({ line, severity: 'warning', message: MESSAGES.strayEndIf, args: [] })
				continue
			}
			const top = blocks[stack.pop()]
			top.endLine = line
			top.closed = true
			continue
		}
	}

	for (const index of stack) {
		const block = blocks[index]
		diagnostics.push({
			line: block.startLine,
			severity: 'error',
			message: MESSAGES.missingEndIf,
			args: [block.condition]
		})
	}

	return { lines, blocks, diagnostics }
}

/**
 * 计算 preprocessor 块的可折叠区域。每个块从其 `#_if` 行折叠到其 `#_endif` 之前的一行，因此 `#_endif` 保持可见（与 PowerShell 扩展对 `}` 使用的约定相同）。嵌套块产生嵌套的范围。
 *
 * 这些范围是*附加的*：VS Code 会合并某语言所有折叠 provider 的范围，因此它们与 PowerShell 扩展自己的（基于 AST 的）范围并列存在。在如下结构中
 *
 *     #_if PSScript
 *     if (!$nested) {
 *     #_endif
 *
 * 真正的 `if` 在块唯一的函数体行上打开，因此它的 AST 范围与小的 `#_if … #_endif` 范围重叠；编辑器随后会显示两个折叠标记。两个 provider 都不会改写文档，因此这纯粹是显示上的重叠，而不是折叠损坏。
 *
 * @param {string} text
 * @returns {Array<{ start: number, end: number }>} 从零开始、包含末尾的行
 */
function foldingRanges (text) {
	const { lines, blocks } = analyze(text)
	const ranges = []
	for (const block of blocks) {
		const end = Math.min(block.endLine - 1, lines.length - 1)
		if (end > block.startLine) ranges.push({ start: block.startLine, end })
	}
	return ranges
}

/**
 * 决定在完整的 `#_if …` 行上键入换行后，自动插入 `#_endif` 的位置。
 *
 * @param {string | undefined} currentLine 键入换行所在的行
 * @param {string} insertedText 编辑插入的文本
 * @returns {{ offset: number, indent: string } | undefined} 换行下方 `offset` 行处，缩进与 `#_if` 行相同
 */
function endifAutoClose (currentLine, insertedText) {
	if (currentLine === undefined || !/\r?\n/.test(insertedText)) return undefined
	if (!IF_RE.test(currentLine)) return undefined
	const indent = (currentLine.match(/^[ \t]*/) || [''])[0]
	return { offset: insertedText.split(/\r?\n/).length - 1, indent }
}

// 一条 `#_!!` 转义行，包含标记及其后一个可选空格。
const BANG_RE = /^([ \t]*)#_!! ?(.*)$/
// 任何其他 preprocessor 指令（`#_if`、`#_else`、`#_endif`、`#_include` 等）。
const OTHER_DIRECTIVE_RE = /^[ \t]*#_/

/**
 * 在单行上切换 `#_!!` 转义标记。脚本直接运行时 `#_!!` 使该行成为注释，而 ps12exe 剥离标记后则是真实代码，因此切换操作会对普通代码添加它、再将其移除。
 *
 * 空行或另一条 preprocessor 指令的行保持不变（`undefined`）：在指令前添加 `#_!!` 会禁用它。
 *
 * @param {string} line
 * @returns {string | undefined} 切换后的行；未改动时为 undefined
 */
function toggleBangLine (line) {
	if (!/\S/.test(line)) return undefined
	const marked = line.match(BANG_RE)
	if (marked) return marked[1] + marked[2]
	if (OTHER_DIRECTIVE_RE.test(line)) return undefined
	const indent = (line.match(/^[ \t]*/) || [''])[0]
	return `${indent}#_!!${line.slice(indent.length)}`
}

/**
 * 在 `[startLine, endLine]` 范围内的每一行上切换 `#_!!`。
 *
 * @param {string[]} lines
 * @param {number} startLine 从零开始、包含
 * @param {number} endLine 从零开始、包含
 * @param {boolean[]} [skipMask] 保持不变的行（here-string、块注释）；见 `computeSkipMask`
 * @returns {Array<{ line: number, text: string }>} 发生变更的行
 */
function toggleBangLines (lines, startLine, endLine, skipMask) {
	const changes = []
	const first = Math.max(0, startLine)
	const last = Math.min(endLine, lines.length - 1)
	for (let i = first; i <= last; i++) {
		if (skipMask && skipMask[i]) continue
		const toggled = toggleBangLine(lines[i])
		if (toggled !== undefined && toggled !== lines[i]) changes.push({ line: i, text: toggled })
	}
	return changes
}

/**
 * 把每个块拆分为 ps12exe 送入构建的代码片段，每个分支一个。嵌套指令会留在文本中，因为它们对 PowerShell 而言只是注释；只有块自身的指令行会被丢弃。
 *
 * @param {Array<{ startLine: number, endLine: number, elseLine: number | null }>} blocks
 * @param {string[]} lines
 * @returns {Array<{ block: number, text: string }>} `block` 是块索引
 */
function branchFragments (blocks, lines) {
	const fragments = []
	blocks.forEach((entry, index) => {
		const firstEnd = entry.elseLine === null ? entry.endLine : entry.elseLine
		fragments.push({ block: index, text: lines.slice(entry.startLine + 1, firstEnd).join('\n') })
		if (entry.elseLine !== null) {
			fragments.push({ block: index, text: lines.slice(entry.elseLine + 1, entry.endLine).join('\n') })
		}
	})
	return fragments
}

/**
 * 覆盖文件至少 90% 的块永不缩进。只会豁免一个这样的块；当有多个符合条件时，最大的那个胜出。
 *
 * @param {Array<{ startLine: number, endLine: number }>} blocks
 * @param {number} totalLines
 * @returns {object | null}
 */
function pickExemptBlock (blocks, totalLines) {
	if (!totalLines) return null
	const threshold = totalLines * 0.9
	let best = null
	let bestSpan = -1
	for (const block of blocks) {
		const span = block.endLine - block.startLine + 1
		if (span >= threshold && span > bestSpan) {
			best = block
			bestSpan = span
		}
	}
	return best
}

/**
 * 必须保持不变的行：here-string 函数体和块注释。它们的内容有意义（或是 formatter 原样保留的注释）。
 *
 * @param {string[]} lines
 * @returns {boolean[]}
 */
function computeSkipMask (lines) {
	const skip = new Array(lines.length).fill(false)
	let hereTerminator = null
	let inBlockComment = false

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i]
		const trimmed = line.trim()

		if (hereTerminator) {
			skip[i] = true
			// 终止符只需位于行首；PowerShell 允许在同一行紧跟管道或重定向（`"@ *> $null`）。
			if (trimmed.startsWith(hereTerminator)) hereTerminator = null
			continue
		}
		if (inBlockComment) {
			skip[i] = true
			if (line.includes('#>')) inBlockComment = false
			continue
		}

		const here = line.match(/@(["'])\s*$/)
		if (here) {
			hereTerminator = `${here[1]}@`
			continue
		}
		if (line.includes('<#')) {
			skip[i] = true
			if (!line.includes('#>')) inBlockComment = true
		}
	}

	return skip
}

/**
 * 按每个嵌套层级一个单位重新缩进 `text` 的 preprocessor 块。
 *
 * - 代码行在官方 formatter 产生的缩进之上，为每个外层（非豁免）块加深一层。
 * - 指令行和注释行会被*设置*为最近代码的语法缩进加上 preprocessor 深度。设置（而非前置）能让文档被反复格式化时结果保持稳定。
 * - here-string 函数体和块注释保持原样。
 *
 * @param {string} text
 * @param {{ indentUnit?: string, incompleteBlocks?: Iterable<number> }} [options] `incompleteBlocks` 列出函数体不构成完整 PowerShell 单元的块（例如在块内打开、在块外关闭的 `if`）；这些块永不加深，见 `branchFragments`。
 * @returns {string}
 */
function indentText (text, options = {}) {
	const indentUnit = options.indentUnit || '\t'
	const eol = detectEol(text)
	const { lines, blocks } = analyze(text)
	const exempt = pickExemptBlock(blocks, lines.length)
	const exemptStart = exempt ? exempt.startLine : -1
	const skip = computeSkipMask(lines)

	const incompleteStartLines = new Set()
	for (const index of options.incompleteBlocks || []) {
		const entry = blocks[index]
		if (entry) incompleteStartLines.add(entry.startLine)
	}

	const isComment = lines.map((line) => /^[ \t]*#/.test(line))
	const isCode = lines.map((line, i) => lines[i].trim() !== '' && !skip[i] && !isComment[i])
	const leading = lines.map(leadingOf)

	const startToBlock = new Map()
	for (const block of blocks) {
		startToBlock.set(block.startLine, block)
		if (block.elseLine !== null) startToBlock.set(block.elseLine, block)
		startToBlock.set(block.endLine, block)
	}

	// 每一行的 preprocessor 深度。
	const depth = new Array(lines.length).fill(0)
	const stack = []
	for (let i = 0; i < lines.length; i++) {
		const content = lines[i]
		const depthFull = stack.reduce((total, entry) => total + (entry.exempt ? 0 : 1), 0)
		if (IF_RE.test(content)) {
			depth[i] = depthFull
			stack.push({ exempt: i === exemptStart || incompleteStartLines.has(i) })
		}
		else if (ELSE_RE.test(content) || ENDIF_RE.test(content)) {
			const top = stack[stack.length - 1]
			depth[i] = depthFull - (top && !top.exempt ? 1 : 0)
			if (ENDIF_RE.test(content)) stack.pop()
		}
		else {
			depth[i] = depthFull
		}
	}

	// 每个块的语法缩进：其第一条代码行的缩进。`null` 标记「尚未找到」，这样合法的空缩进（顶层块）不会被误认为未找到并被周围代码覆盖。
	for (const block of blocks) {
		block.bodyIndent = null
		const bodyEnd = block.elseLine !== null ? block.elseLine : block.endLine
		for (let i = block.startLine + 1; i < bodyEnd; i++) {
			if (isCode[i]) { block.bodyIndent = leading[i]; break }
		}
		if (block.bodyIndent === null) {
			for (let i = bodyEnd + 1; i < block.endLine; i++) {
				if (isCode[i]) { block.bodyIndent = leading[i]; break }
			}
		}
		if (block.bodyIndent === null) {
			// 两个分支中都没有代码（例如函数体只有 `#_!!` 转义或注释）。官方 formatter 已经把该指令放在周围的语法缩进处，因此使用它自身的行首缩进，而不是最近的不相关代码行（后者可能位于外层构造的缩进处，如在 `if (` + 续行中那样）。
			block.bodyIndent = leading[block.startLine]
		}
	}

	// 最近的前/后代码缩进，用作未附着到块的注释的语法缩进。
	const prevCodeIndent = new Array(lines.length).fill(null)
	let last = null
	for (let i = 0; i < lines.length; i++) {
		prevCodeIndent[i] = last
		if (isCode[i]) last = leading[i]
	}
	const nextCodeIndent = new Array(lines.length).fill(null)
	last = null
	for (let i = lines.length - 1; i >= 0; i--) {
		nextCodeIndent[i] = last
		if (isCode[i]) last = leading[i]
	}
	const commentContext = (i) => {
		const prev = prevCodeIndent[i]
		const next = nextCodeIndent[i]
		if (prev === null) return next || ''
		if (next === null) return prev
		return prev.length >= next.length ? prev : next
	}

	const out = lines.map((line, i) => {
		if (skip[i]) return line
		if (line.trim() === '') return ''

		const extra = indentUnit.repeat(depth[i])
		if (isComment[i]) {
			// 位于所有 preprocessor 块之外的注释无需调整：官方 formatter 已经把它放在其真正的 PowerShell 块内。`commentContext` 只能看到最近的代码行，因此当注释是某个块的全部函数体时，它会被拉回外层语句。
			if (depth[i] === 0 && !startToBlock.has(i)) return line
			// 指令行（块自身的 `#_if`/`#_else`/`#_endif`）属于该块，因此与其函数体对齐。普通注释回退到周围代码。对于顶层块，`bodyIndent` 合法地可以是 ''，因此不能被视为「缺失」。
			const block = startToBlock.get(i)
			const base = block ? block.bodyIndent : commentContext(i)
			return base + extra + line.replace(/^[ \t]*/, '')
		}
		return extra + line
	})

	return out.join(eol)
}

/**
 * `line` 上 `(` 减去 `)` 的净值，忽略单引号和双引号字符串（含反引号转义）以及 `#` 注释。
 *
 * @param {string} line
 * @returns {number}
 */
function parenDelta (line) {
	let depth = 0
	let state = 'code'
	for (let i = 0; i < line.length; i++) {
		const char = line[i]
		if (state === 'single') {
			if (char === "'") {
				if (line[i + 1] === "'") i++
				else state = 'code'
			}
			continue
		}
		if (state === 'double') {
			if (char === '`') { i++; continue }
			if (char === '"') state = 'code'
			continue
		}
		if (char === "'") { state = 'single'; continue }
		if (char === '"') { state = 'double'; continue }
		if (char === '#') break
		if (char === '(') depth++
		else if (char === ')') depth--
	}
	return depth
}

/**
 * 撤销 PSScriptAnalyzer 对在还有一个或多个未闭合括号时打开 scriptblock 或 hashtable 的行的过度缩进，例如 `$x = (1..3 | ForEach-Object {`、`$list.Add([PSCustomObject]@{` 或 `[ArgumentCompleter({`，以及在前一个括号仍未闭合时开始的反引号续行（`Write-Host ("{0}" -f ` + 反引号）。
 *
 * 缩进规则会在开括号之上再计一个未闭合括号，因此函数体每个未闭合括号就多一层，闭合行也会被下推。当官方 formatter 的输出恰好带有该特征时，整个被包区域会被拉回，与此仓库中脚本的写法一致。不具备该特征的构造保持不动。
 *
 * 上游 bug（在 PSScriptAnalyzer 1.25.0 + pwsh 7.6.6 以及 Windows PowerShell 5.1 上、制表符和空格下均可复现）：`LParen` 和 scriptblock 的 `{`/`@{` 各自增加一层缩进。attribute 形式记录在 https://github.com/PowerShell/PSScriptAnalyzer/issues/2216（未关闭），`.where`/`.foreach` 方法形式记录在 https://github.com/PowerShell/PSScriptAnalyzer/issues/1168（未关闭），括号化管道记录在 https://github.com/PowerShell/PSScriptAnalyzer/issues/1378（未关闭）。某个版本修复它们后，删除此函数（及其测试）。
 *
 * @param {string} text
 * @param {string} indentUnit formatter 的缩进单位（制表符或空格）
 * @returns {string}
 */
function restoreParenIndentation (text, indentUnit) {
	if (!indentUnit) return text
	const eol = detectEol(text)
	const lines = splitLines(text)

	for (let i = 0; i < lines.length; i++) {
		const content = lines[i].trimEnd()
		if (!content) continue
		const openIndent = leadingOf(lines[i])
		const body = content.slice(openIndent.length)
		const opensBlock = /[{(]$/.test(body)
		const continues = body.endsWith('`')
		if (!opensBlock && !continues) continue

		const extra = Math.max(parenDelta(body), 0)
		if (extra < 1) continue
		const closeIndent = openIndent + indentUnit.repeat(extra)
		const bodyIndent = closeIndent + indentUnit

		let close = -1
		if (opensBlock) {
			for (let j = i + 1; j < lines.length; j++) {
				if (leadingOf(lines[j]) === closeIndent && lines[j].slice(closeIndent.length).startsWith('}')) {
					close = j
					break
				}
			}
		}
		else {
			let depth = extra
			for (let j = i + 1; j < lines.length; j++) {
				depth += parenDelta(lines[j])
				if (depth <= 0) { close = j; break }
			}
		}
		if (close < 0) continue

		// 对于 scriptblock/hashtable 开括号，闭合行以 `}` 开头，不是函数体内容；对于反引号续行，闭合行是最后一行函数体，也必须一并检查。
		const bodyLimit = opensBlock ? close : close + 1
		const firstBody = lines.findIndex((line, index) => index > i && index < bodyLimit && line.trim() !== '')
		if (firstBody < 0 || leadingOf(lines[firstBody]) !== bodyIndent) continue

		for (let k = i + 1; k <= close; k++) {
			if (lines[k].startsWith(closeIndent)) lines[k] = lines[k].slice(indentUnit.repeat(extra).length)
		}
	}

	return lines.join(eol)
}

/**
 * 修复 `PSPlaceCloseBrace` 移到独立行的 `else`/`elseif`/`catch`/`finally` 行（在 `NewLineAfter`，即 `powershell.codeFormatting.newLineAfterCloseBrace` 的默认值下）：被移动的关键字只保留了它与 `}` 之间的单个空格，而不是块的缩进，例如在嵌套一层时
 *
 *     function f {
 *         if ($a) {
 *             $b
 *         }
 *      else {
 *
 * 该子句与正上方的闭括号重新对齐。该规则为它改写的缩进硬编码了空格，因此只有 formatter 配置为制表符时才会显现。当缩进已经正确（顶层，或深度 >= 2）时不会有任何改动。
 *
 * 上游限制：PSScriptAnalyzer 的括号规则不了解制表符缩进，见 https://github.com/PowerShell/PSScriptAnalyzer/issues/1055 以及重复的 https://github.com/PowerShell/PSScriptAnalyzer/issues/1441。当这些规则支持 `Kind = 'tab'` 后，删除此函数（及其测试）。
 *
 * @param {string} text
 * @returns {string}
 */
function restoreClauseIndentation (text) {
	const eol = detectEol(text)
	const lines = splitLines(text)

	for (let i = 1; i < lines.length; i++) {
		const clause = lines[i].match(/^([ \t]+)((?:else|elseif|catch|finally)\b.*)$/)
		if (!clause) continue
		let previous = i - 1
		while (previous >= 0 && lines[previous].trim() === '') previous--
		if (previous < 0 || !lines[previous].trimEnd().endsWith('}')) continue
		const indent = leadingOf(lines[previous])
		if (clause[1] === indent) continue
		lines[i] = indent + clause[2]
	}

	return lines.join(eol)
}

export { analyze, indentText, endifAutoClose, foldingRanges, toggleBangLine, toggleBangLines, branchFragments, pickExemptBlock, computeSkipMask, restoreParenIndentation, restoreClauseIndentation, MESSAGES, IF_RE, ELSE_RE, ENDIF_RE }
