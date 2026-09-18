// Mirrors the directive detection used by ps12exe's Preprocessor
// (src/ReadScriptFile.ps1): a directive is a line starting with optional
// whitespace followed by `#_…`, and a trailing `#comment` is allowed (ps12exe
// uses the same `(?!#.*)` lookahead). Here-string bodies and block comments are
// treated as opaque by `computeSkipMask` so the formatter never rewrites them.
// The `(?!#)` lookahead mirrors ps12exe's `(?!#.*)`: a trailing comment after
// the directive is allowed (e.g. `#_if PSEXE #reason`), anything else is not.
const IF_RE = /^\s*#_if\s+(\S+)\s*(?!#)/
const ELSE_RE = /^\s*#_else\s*(?!#)/
const ENDIF_RE = /^\s*#_endif\s*(?!#)/

const KNOWN_CONDITIONS = new Set(['psexe', 'psscript'])

// English source strings; they are also the keys of the l10n bundles.
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
 * Parses the structural preprocessor directives of a document.
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
 * Computes the foldable regions of the preprocessor blocks. Each block folds
 * from its `#_if` line down to the line before its `#_endif`, so the `#_endif`
 * stays visible (the same convention the PowerShell extension uses for `}`).
 * Nested blocks produce nested ranges.
 *
 * These ranges are *additive*: VS Code merges the ranges of every folding
 * provider for a language, so they sit next to the PowerShell extension's own
 * (AST-based) ranges. In a construct like
 *
 *     #_if PSScript
 *     if (!$nested) {
 *     #_endif
 *
 * the real `if` opens on the block's only body line, so its AST range overlaps
 * the small `#_if … #_endif` range; the editor then shows both fold markers.
 * Neither provider rewrites the document, so this is purely a display overlap,
 * not a broken fold.
 *
 * @param {string} text
 * @returns {Array<{ start: number, end: number }>} zero-based, inclusive lines
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
 * Decides where to auto-insert `#_endif` after a newline was typed on a
 * complete `#_if …` line.
 *
 * @param {string | undefined} currentLine the line the newline was typed on
 * @param {string} insertedText the text the edit inserted
 * @returns {{ offset: number, indent: string } | undefined} `offset` lines below
 *   the newline, indented like the `#_if` line
 */
function endifAutoClose (currentLine, insertedText) {
	if (currentLine === undefined || !/\r?\n/.test(insertedText)) return undefined
	if (!IF_RE.test(currentLine)) return undefined
	const indent = (currentLine.match(/^[ \t]*/) || [''])[0]
	return { offset: insertedText.split(/\r?\n/).length - 1, indent }
}

// A `#_!!` escape line, with the marker and an optional single space after it.
const BANG_RE = /^([ \t]*)#_!! ?(.*)$/
// Any other preprocessor directive (`#_if`, `#_else`, `#_endif`, `#_include`, …).
const OTHER_DIRECTIVE_RE = /^[ \t]*#_/

/**
 * Toggles the `#_!!` escape marker on a single line. `#_!!` makes the line a
 * comment when the script runs directly and real code after ps12exe strips the
 * marker, so toggling adds it to plain code and removes it again.
 *
 * Lines that are blank, or that are another preprocessor directive, are left
 * alone (`undefined`): adding `#_!!` in front of a directive would disable it.
 *
 * @param {string} line
 * @returns {string | undefined} the toggled line, or undefined when untouched
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
 * Toggles `#_!!` on every line in `[startLine, endLine]`.
 *
 * @param {string[]} lines
 * @param {number} startLine zero-based, inclusive
 * @param {number} endLine zero-based, inclusive
 * @param {boolean[]} [skipMask] lines to leave untouched (here-strings, block
 *   comments); see `computeSkipMask`
 * @returns {Array<{ line: number, text: string }>} the lines that change
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
 * Splits every block into the code fragments ps12exe feeds to the build, one per
 * branch. Nested directives stay in the text because they are just comments to
 * PowerShell; only the block's own directive lines are dropped.
 *
 * @param {Array<{ startLine: number, endLine: number, elseLine: number | null }>} blocks
 * @param {string[]} lines
 * @returns {Array<{ block: number, text: string }>} `block` is the block index
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
 * A block covering at least 90% of the file is never indented. Only one such
 * block is exempted; when several qualify the largest one wins.
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
 * Lines that must be left untouched: here-string bodies and block comments.
 * Their content is significant (or is a comment the formatter keeps verbatim).
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
			// The terminator only has to start the line; PowerShell allows a
			// pipeline or redirection to follow it on the same line
			// (`"@ *> $null`).
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
 * Re-indents the preprocessor blocks of `text` by one unit per nesting level.
 *
 * - Code lines are pushed one level deeper per enclosing (non-exempt) block on
 *   top of the indentation produced by the official formatter.
 * - Directive and comment lines are *set* to the syntax indentation of the
 *   nearest code plus the preprocessor depth. Setting (instead of prepending)
 *   keeps the result stable when the document is formatted repeatedly.
 * - Here-string bodies and block comments are left verbatim.
 *
 * @param {string} text
 * @param {{ indentUnit?: string, incompleteBlocks?: Iterable<number> }} [options]
 *   `incompleteBlocks` lists the blocks whose body does not form a complete
 *   PowerShell unit (e.g. an `if` opened inside the block and closed outside);
 *   those are never pushed deeper, see `branchFragments`.
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

	// Preprocessor depth of every line.
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

	// Syntax indentation of each block: the indentation of its first code line.
	// `null` marks "nothing found yet" so that a legitimately empty indentation
	// (a top-level block) is not mistaken for a miss and overwritten by the
	// surrounding code.
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
			// No code in either branch (e.g. the body is only `#_!!` escapes or
			// comments). The official formatter has already placed the directive
			// at the surrounding syntax indentation, so use its own leading
			// rather than the nearest unrelated code line (which may sit at the
			// enclosing construct's indentation, as in `if (` + continuation).
			block.bodyIndent = leading[block.startLine]
		}
	}

	// Nearest preceding / following code indentation, used as the syntax
	// indentation for comments that are not attached to a block.
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
			// A comment outside every preprocessor block needs no adjustment:
			// the official formatter already placed it inside its real
			// PowerShell block. `commentContext` only sees the nearest code
			// line, so when a comment is the entire body of a block it would be
			// pulled back to the enclosing statement instead.
			if (depth[i] === 0 && !startToBlock.has(i)) return line
			// Directive lines (the block's own `#_if`/`#_else`/`#_endif`) belong
			// to the block, so they align with its body. Regular comments fall
			// back to the surrounding code. `bodyIndent` may legitimately be ''
			// for a top-level block, so it must not be treated as "missing".
			const block = startToBlock.get(i)
			const base = block ? block.bodyIndent : commentContext(i)
			return base + extra + line.replace(/^[ \t]*/, '')
		}
		return extra + line
	})

	return out.join(eol)
}

/**
 * Net number of `(` minus `)` on `line`, ignoring single- and double-quoted
 * strings (with backtick escapes) and `#` comments.
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
 * Undoes PSScriptAnalyzer's over-indentation of a line that opens a scriptblock
 * or hashtable after one or more still-open parentheses, e.g.
 * `$x = (1..3 | ForEach-Object {`, `$list.Add([PSCustomObject]@{` or
 * `[ArgumentCompleter({`, as well as a backtick continuation line that starts
 * while a parenthesis is still open (`Write-Host ("{0}" -f ` + backtick).
 *
 * The indentation rule counts an open parenthesis on top of the opener, so the
 * body gets one extra level per open parenthesis and the closing line is pushed
 * down too. When the official formatter's output carries exactly that signature
 * the whole enclosed region is pulled back, matching the way the scripts in
 * this repository are written. Constructs that do not have the signature are
 * left untouched.
 *
 * Upstream bug (reproduces on PSScriptAnalyzer 1.25.0 with pwsh 7.6.6, and on
 * Windows PowerShell 5.1; both tabs and spaces): the `LParen` and the scriptblock
 * `{`/`@{` each add an indentation level. The attribute form is tracked in
 * https://github.com/PowerShell/PSScriptAnalyzer/issues/2216 (open), the
 * `.where`/`.foreach` method form in
 * https://github.com/PowerShell/PSScriptAnalyzer/issues/1168 (open) and the
 * parenthesized pipeline in
 * https://github.com/PowerShell/PSScriptAnalyzer/issues/1378 (open). Delete
 * this function (and its test) once a release fixes them.
 *
 * @param {string} text
 * @param {string} indentUnit the formatter's indentation unit (tabs or spaces)
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

		// For a scriptblock/hashtable opener the closing line starts with `}`
		// and is not body content; for a backtick continuation the closing line
		// is the last body line and must be checked as well.
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
 * Repairs the `else`/`elseif`/`catch`/`finally` line that `PSPlaceCloseBrace`
 * moves onto its own line (with `NewLineAfter`, i.e. the default of
 * `powershell.codeFormatting.newLineAfterCloseBrace`): the moved keyword keeps
 * only the single space that separated it from the `}` instead of the
 * indentation of the block, e.g. at one level of nesting
 *
 *     function f {
 *         if ($a) {
 *             $b
 *         }
 *      else {
 *
 * The clause is realigned with the closing brace directly above it. The rule
 * hardcodes spaces for the indentation it rewrites, so this only shows up when
 * the formatter is configured for tabs. When the indentation is already correct
 * (top level, or depth >= 2) nothing changes.
 *
 * Upstream limitation: PSScriptAnalyzer's brace rules do not know about tab
 * indentation, see https://github.com/PowerShell/PSScriptAnalyzer/issues/1055
 * and the duplicate https://github.com/PowerShell/PSScriptAnalyzer/issues/1441.
 * Delete this function (and its test) once the rules honour `Kind = 'tab'`.
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
