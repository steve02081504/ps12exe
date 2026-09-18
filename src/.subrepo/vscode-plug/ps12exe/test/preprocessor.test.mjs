import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { analyze, indentText, endifAutoClose, foldingRanges, toggleBangLine, toggleBangLines, branchFragments, pickExemptBlock, computeSkipMask, restoreAttributeIndentation, MESSAGES } from '../lib/preprocessor.mjs'

// The extension lives at <repo>/src/.subrepo/vscode-plug/ps12exe, so this test
// file sits five levels below the ps12exe repository root.
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..', '..')
const IGNORED_DIRS = new Set(['node_modules', '.subrepo', '.vscode-test', '.git', 'out', 'dist'])

/** @param {string} dir @param {string[]} [out] */
function collectPs1 (dir, out = []) {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		if (entry.isDirectory()) {
			if (!IGNORED_DIRS.has(entry.name)) collectPs1(path.join(dir, entry.name), out)
		}
		else if (entry.name.toLowerCase().endsWith('.ps1')) out.push(path.join(dir, entry.name))
	}
	return out
}

suite('ps12exe preprocessor', () => {
	test('reports unclosed, nested, unknown and duplicate directives', () => {
		const text = [
			'#_if PSEXE',
			'Write-Output 1',
			'#_if PSScript',
			'Write-Output 2',
			'#_else',
			'Write-Output 3',
			'#_else',
			'Write-Output 4',
			'#_endif',
			'#_if Unkn0wn',
			'Write-Output 5'
		].join('\n')
		const messages = analyze(text).diagnostics.map((d) => d.message)
		assert.ok(messages.includes(MESSAGES.nestedIfDeadCode))
		assert.ok(messages.includes(MESSAGES.duplicateElse))
		assert.ok(messages.includes(MESSAGES.unknownCondition))
		assert.ok(messages.includes(MESSAGES.missingEndIf))

		const stray = analyze('#_else\n#_endif').diagnostics.map((d) => d.message)
		assert.ok(stray.includes(MESSAGES.strayElse))
		assert.ok(stray.includes(MESSAGES.strayEndIf))
	})

	test('folds each block to the line before its #_endif', () => {
		const simple = ['#_if PSEXE', 'a', 'b', '#_endif'].join('\n')
		assert.deepStrictEqual(foldingRanges(simple), [{ start: 0, end: 2 }])

		// The whole if/else folds as one region; `#_endif` stays visible.
		const withElse = ['#_if PSEXE', 'a', '#_else', 'b', '#_endif'].join('\n')
		assert.deepStrictEqual(foldingRanges(withElse), [{ start: 0, end: 3 }])

		// Nested blocks produce nested ranges.
		const nested = ['#_if PSEXE', 'a', '#_if PSScript', 'b', '#_endif', 'c', '#_endif'].join('\n')
		assert.deepStrictEqual(foldingRanges(nested), [
			{ start: 0, end: 5 },
			{ start: 2, end: 3 }
		])

		// An empty block has nothing to fold.
		assert.deepStrictEqual(foldingRanges(['#_if PSEXE', '#_endif'].join('\n')), [])

		// A body that opens a real PowerShell block (the `#_if PSScript` +
		// `if (!$nested) {` idiom) still folds its single body line.
		const openIf = ['#_if PSScript', 'if (!$nested) {', '#_endif', 'x', '}'].join('\n')
		assert.deepStrictEqual(foldingRanges(openIf), [{ start: 0, end: 1 }])
	})

	test('toggles the #_!! escape marker on plain lines only', () => {
		assert.strictEqual(toggleBangLine('echo hi'), '#_!!echo hi')
		assert.strictEqual(toggleBangLine('\techo hi'), '\t#_!!echo hi')
		assert.strictEqual(toggleBangLine('  # comment'), '  #_!!# comment')
		assert.strictEqual(toggleBangLine('#_!!echo hi'), 'echo hi')
		assert.strictEqual(toggleBangLine('\t#_!! echo hi'), '\techo hi')
		assert.strictEqual(toggleBangLine('#_!!if'), 'if')

		// Directives other than `#_!!` and blank lines are left alone.
		assert.strictEqual(toggleBangLine('#_if PSEXE'), undefined)
		assert.strictEqual(toggleBangLine('\t#_endif'), undefined)
		assert.strictEqual(toggleBangLine('#_include x.ps1'), undefined)
		assert.strictEqual(toggleBangLine('#_pragma Console 0'), undefined)
		assert.strictEqual(toggleBangLine('#_balus'), undefined)
		assert.strictEqual(toggleBangLine(''), undefined)
		assert.strictEqual(toggleBangLine('   '), undefined)

		const lines = ['a', '#_if PSEXE', 'b', '#_!!c', '', '#_endif', 'd']
		assert.deepStrictEqual(toggleBangLines(lines, 0, lines.length - 1), [
			{ line: 0, text: '#_!!a' },
			{ line: 2, text: '#_!!b' },
			{ line: 3, text: 'c' },
			{ line: 6, text: '#_!!d' }
		])

		// Only the requested range is touched, and the skip mask wins.
		assert.deepStrictEqual(toggleBangLines(lines, 2, 3), [
			{ line: 2, text: '#_!!b' },
			{ line: 3, text: 'c' }
		])
		assert.deepStrictEqual(toggleBangLines(lines, 0, 3, [false, false, false, true]), [
			{ line: 0, text: '#_!!a' },
			{ line: 2, text: '#_!!b' }
		])
	})

	test('exempts only the largest block covering at least 90% of the file', () => {
		const blocks = [
			{ startLine: 0, endLine: 18 }, // 19/20 = 95%
			{ startLine: 2, endLine: 17 } // 16/20 = 80%
		]
		assert.strictEqual(pickExemptBlock(blocks, 20), blocks[0])

		// 18/20 = 90% => qualifies; the larger one wins.
		const tie = [
			{ startLine: 0, endLine: 17 },
			{ startLine: 0, endLine: 17 }
		]
		assert.strictEqual(pickExemptBlock(tie, 20), tie[0])
	})

	test('indents directives and bodies but leaves an exempt block alone', () => {
		const base = [
			'function f {',
			'    Write-Output "hi"',
			'    #_if PSEXE',
			'    Write-Output "exe"',
			'    #_else',
			'    Write-Output "script"',
			'    #_endif',
			'    $x = 1',
			'}'
		].join('\n')
		const expected = [
			'function f {',
			'    Write-Output "hi"',
			'    #_if PSEXE',
			'\t    Write-Output "exe"',
			'    #_else',
			'\t    Write-Output "script"',
			'    #_endif',
			'    $x = 1',
			'}'
		].join('\n')
		assert.strictEqual(indentText(base, { indentUnit: '\t' }), expected)

		const big = [
			'#_if PSEXE',
			'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
			'#_endif',
			'z'
		].join('\n')
		assert.strictEqual(indentText(big, { indentUnit: '\t' }), big)
	})

	test('never touches here-string bodies', () => {
		const text = [
			'$s = @"',
			'#_if PSEXE',
			'Write-Output "inside"',
			'"@',
			'#_if PSEXE',
			'Write-Output "outside"',
			'#_endif'
		].join('\n')
		const output = indentText(text, { indentUnit: '\t' })
		assert.ok(output.includes('#_if PSEXE\nWrite-Output "inside"'))
		assert.ok(output.includes('\tWrite-Output "outside"'))
	})

	test('skip mask tracks here-strings and block comments', () => {
		const mask = computeSkipMask([
			'$s = @"',
			'content',
			'"@',
			'<# block',
			'still block #>',
			'$x = 1'
		])
		assert.deepStrictEqual(mask, [false, true, true, true, true, false])
	})

	test('splits blocks into one fragment per branch', () => {
		const { blocks, lines } = analyze(['#_if PSEXE', 'a', '#_else', 'b', '#_endif'].join('\n'))
		assert.deepStrictEqual(branchFragments(blocks, lines), [
			{ block: 0, text: 'a' },
			{ block: 0, text: 'b' }
		])
	})

	test('leaves blocks with an incomplete body un-indented', () => {
		const text = [
			'#_if PSScript',
			'if (!$nested) {',
			'#_endif',
			'#_if PSEXE',
			'Write-Output "exe"',
			'#_endif'
		].join('\n')

		assert.ok(indentText(text, { indentUnit: '\t' }).includes('#_if PSScript\n\tif (!$nested) {'))

		const out = indentText(text, { indentUnit: '\t', incompleteBlocks: new Set([0]) })
		assert.ok(out.includes('#_if PSScript\nif (!$nested) {'))
		assert.ok(out.includes('\tWrite-Output "exe"'))
	})

	test('auto-closes a completed #_if line', () => {
		assert.deepStrictEqual(endifAutoClose('#_if PSEXE', '\n'), { offset: 1, indent: '' })
		assert.deepStrictEqual(endifAutoClose('    #_if PSEXE #why', '\r\n\t'), { offset: 1, indent: '    ' })
		assert.deepStrictEqual(endifAutoClose('#_if PSScript', '\n\n'), { offset: 2, indent: '' })
		assert.strictEqual(endifAutoClose('#_if', '\n'), undefined)
		assert.strictEqual(endifAutoClose('#_ifdef PSEXE', '\n'), undefined)
		assert.strictEqual(endifAutoClose('Write-Output 1', '\n'), undefined)
		assert.strictEqual(endifAutoClose('#_if PSEXE', 'x'), undefined)
		assert.strictEqual(endifAutoClose(undefined, '\n'), undefined)
	})

	test('repairs the official formatter attribute/scriptblock indentation', () => {
		// Workaround for
		// https://github.com/PowerShell/PSScriptAnalyzer/issues/2216 — remove
		// together with `restoreAttributeIndentation` once upstream fixes it.
		const broken = [
			'\t[ArgumentCompleter({',
			'\t\t\tParam($x)',
			'\t\t\t$y = 1',
			'\t\t})]',
			'\t$x = 2'
		].join('\n')
		const fixed = [
			'\t[ArgumentCompleter({',
			'\t\tParam($x)',
			'\t\t$y = 1',
			'\t})]',
			'\t$x = 2'
		].join('\n')
		assert.strictEqual(restoreAttributeIndentation(broken, '\t'), fixed)
		assert.strictEqual(restoreAttributeIndentation(fixed, '\t'), fixed)

		const spaced = ['    [ValidateScript({', '            $_', '        })]'].join('\n')
		assert.strictEqual(
			restoreAttributeIndentation(spaced, '    '),
			['    [ValidateScript({', '        $_', '    })]'].join('\n')
		)
	})

	test("ps12exe's own scripts analyse without diagnostics", function () {
		// Guards the editor rules against drifting from the scripts ps12exe ships.
		if (!fs.existsSync(path.join(REPO_ROOT, 'ps12exe.ps1'))) this.skip()

		const files = collectPs1(REPO_ROOT)
		assert.ok(files.length > 10, `expected to find ps12exe's scripts under ${REPO_ROOT}`)

		const failures = []
		for (const file of files) {
			const { diagnostics } = analyze(fs.readFileSync(file, 'utf8'))
			for (const d of diagnostics) {
				failures.push(`${path.relative(REPO_ROOT, file)}:${d.line + 1} [${d.severity}] ${d.message}`)
			}
		}
		assert.deepStrictEqual(failures, [], `ps12exe's own scripts must be warning-free:\n${failures.join('\n')}`)
	})
})
