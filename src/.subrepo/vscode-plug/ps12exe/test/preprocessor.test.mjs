/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { analyze, indentText, endifAutoClose, foldingRanges, toggleBangLine, toggleBangLines, branchFragments, pickExemptBlock, computeSkipMask, restoreMarkerIndentation, restoreParenIndentation, restoreClauseIndentation, MESSAGES } from '../lib/preprocessor.mjs'

// 该扩展位于 <repo>/src/.subrepo/vscode-plug/ps12exe，因此本测试文件位于 ps12exe 仓库根目录下五层。
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..', '..')
const IGNORED_DIRS = new Set(['node_modules', '.subrepo', '.vscode-test', '.git', 'out', 'dist'])

/**
 * 递归收集目录下的脚本文件。
 *
 * @param {string} dir - 目录路径
 * @param {string[]} [out] - 输出数组
 * @returns {string[]} 脚本文件路径列表
 */
function collectPs1 (dir, out = []) {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) 
		if (entry.isDirectory()) {
			if (!IGNORED_DIRS.has(entry.name)) collectPs1(path.join(dir, entry.name), out)
		}
		else if (entry.name.toLowerCase().endsWith('.ps1')) out.push(path.join(dir, entry.name))
	
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

		// 整个 if/else 折叠为一个区域；`#_endif` 保持可见。
		const withElse = ['#_if PSEXE', 'a', '#_else', 'b', '#_endif'].join('\n')
		assert.deepStrictEqual(foldingRanges(withElse), [{ start: 0, end: 3 }])

		// 嵌套块产生嵌套区间。
		const nested = ['#_if PSEXE', 'a', '#_if PSScript', 'b', '#_endif', 'c', '#_endif'].join('\n')
		assert.deepStrictEqual(foldingRanges(nested), [
			{ start: 0, end: 5 },
			{ start: 2, end: 3 }
		])

		// 空块没有可折叠的内容。
		assert.deepStrictEqual(foldingRanges(['#_if PSEXE', '#_endif'].join('\n')), [])

		// 开启真实 PowerShell 块的主体（即 `#_if PSScript` + `if (!$nested) {` 惯用法）仍会折叠其单行主体。
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

		// 除 `#_!!` 之外的指令和空行保持不变。
		assert.strictEqual(toggleBangLine('#_if PSEXE'), undefined)
		assert.strictEqual(toggleBangLine('\t#_endif'), undefined)
		assert.strictEqual(toggleBangLine('#_include x.ps1'), undefined)
		assert.strictEqual(toggleBangLine('#_pragma App.Windowed'), undefined)
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

		// 只改动所请求的范围，且跳过掩码优先。
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

		// 18/20 = 90% => 符合条件；较大者胜出。
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

	test('aligns a block whose body has no code with the surrounding expression', () => {
		// 只包含 `#_!!` 转义的主体没有可供块基准跟随的代码行。`if (` + 续行是典型案例（src/CodeDomCompiler.ps1）：最近的代码行是第 0 列的开启符，但指令应处于官方 formatter 已经赋予它们的续行缩进处。
		const base = [
			'if (',
			'\t#_if PSEXE',
			'\t#_!! $AstAnalyzeResult.IsConst -or',
			'\t#_endif',
			'\t$requireAdmin -or $DPIAware',
			') {'
		].join('\n')
		const expected = [
			'if (',
			'\t#_if PSEXE',
			'\t\t#_!! $AstAnalyzeResult.IsConst -or',
			'\t#_endif',
			'\t$requireAdmin -or $DPIAware',
			') {'
		].join('\n')
		assert.strictEqual(indentText(base, { indentUnit: '\t' }), expected)
	})

	test('leaves comments outside preprocessor blocks to the official formatter', () => {
		// 作为块完整主体的注释在主体缩进处没有可供 `commentContext` 找到的代码行；该注释必须保留 PSScriptAnalyzer 赋予它的缩进。
		const base = ['if ($x) {', '\t# only a comment', '}'].join('\n')
		assert.strictEqual(indentText(base, { indentUnit: '\t' }), base)

		const spaced = ['if ($x) {', '    # only a comment', '}'].join('\n')
		assert.strictEqual(indentText(spaced, { indentUnit: '\t' }), spaced)
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

		// 即使同一行上终止符后跟随管道或重定向，终止符仍会结束 here-string。
		const withRedirect = computeSkipMask([
			'$s = @"',
			'content',
			'"@ *> $null',
			'$x = 1'
		])
		assert.deepStrictEqual(withRedirect, [false, true, true, false])

		// 只含块注释的行跳过，但先有代码再内联 `<# … #>` 的行是代码，必须参与缩进。
		const inline = computeSkipMask([
			'catch { <# ignore #> }',
			'\t<# pure comment #>',
			'$x = 1 <# trailing #>',
			'<# open',
			'still #>',
			'$y = 2'
		])
		assert.deepStrictEqual(inline, [false, true, false, true, true, false])
	})

	test('indents code lines that carry an inline block comment', () => {
		// 回归：`catch { <# … #> }` 以前被 skip mask 整行跳过，永远得不到 preprocessor 层级，于是和上方的 `try {` 错位。
		const base = [
			'function f {',
			'\t#_if PSEXE',
			'\ttry {',
			'\t\tWrite-Output 1',
			'\t}',
			'\tcatch { <# ignore #> }',
			'\t#_endif',
			'}'
		].join('\n')
		const expected = [
			'function f {',
			'\t#_if PSEXE',
			'\t\ttry {',
			'\t\t\tWrite-Output 1',
			'\t\t}',
			'\t\tcatch { <# ignore #> }',
			'\t#_endif',
			'}'
		].join('\n')
		assert.strictEqual(indentText(base, { indentUnit: '\t' }), expected)
	})

	test('restores the nesting of #_!! and #_balus lines from the original', () => {
		// 官方 formatter 把这些「展开为代码」的指令当成注释，压平到 `#_if` 的层级；用原文的相对缩进还原。
		const original = [
			'function f {',
			'\t#_if PSEXE',
			'\t\t#_!! if ($a) {',
			'\t\t\t#_!! foo',
			'\t\t#_!! }',
			'\t#_else',
			'\t\tbar',
			'\t#_endif',
			'}'
		].join('\n')
		const flattened = original.replace(/\t\t\t?#_!!/g, '\t#_!!')
		assert.strictEqual(restoreMarkerIndentation(flattened, original), original)

		// `#_balus` 与顶层块同样处理。
		const tailOriginal = [
			'#_if PSEXE',
			'\t#_!! if ($x) {',
			'\t\t#_balus $y',
			'\t#_!! }',
			'#_endif'
		].join('\n')
		const tailFlattened = tailOriginal.replace('\t\t#_balus', '\t#_balus')
		assert.strictEqual(restoreMarkerIndentation(tailFlattened, tailOriginal), tailOriginal)

		// 内容一旦对不上（结构已变），原样返回而不是猜。
		assert.strictEqual(restoreMarkerIndentation(flattened, original.replace('#_!! foo', '#_!! qux')), flattened)
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

	test('repairs the official formatter over-indentation after an open parenthesis', () => {
		// 针对 `LParen` + scriptblock 开启符重复计数的变通方案：
		// https://github.com/PowerShell/PSScriptAnalyzer/issues/2216（属性）
		// https://github.com/PowerShell/PSScriptAnalyzer/issues/1168（方法）
		// https://github.com/PowerShell/PSScriptAnalyzer/issues/1378（管道）
		// 上游修复后，连同 `restoreParenIndentation` 一起删除。
		const attribute = [
			'\t[ArgumentCompleter({',
			'\t\t\tParam($x)',
			'\t\t\t$y = 1',
			'\t\t})]',
			'\t$x = 2'
		].join('\n')
		const attributeFixed = [
			'\t[ArgumentCompleter({',
			'\t\tParam($x)',
			'\t\t$y = 1',
			'\t})]',
			'\t$x = 2'
		].join('\n')
		assert.strictEqual(restoreParenIndentation(attribute, '\t'), attributeFixed)
		assert.strictEqual(restoreParenIndentation(attributeFixed, '\t'), attributeFixed)

		const spaced = ['    [ValidateScript({', '            $_', '        })]'].join('\n')
		assert.strictEqual(
			restoreParenIndentation(spaced, '    '),
			['    [ValidateScript({', '        $_', '    })]'].join('\n')
		)

		// 括号链中的 scriptblock 参数、方法调用和反引号续行都会得到相同的额外层级。
		const chain = [
			'$x = (1..3 | ForEach-Object {',
			'\t\t$_',
			'\t})'
		].join('\n')
		assert.strictEqual(restoreParenIndentation(chain, '\t'), [
			'$x = (1..3 | ForEach-Object {',
			'\t$_',
			'})'
		].join('\n'))

		const twoParens = [
			'$str += (($obj.GetEnumerator() | ForEach-Object {',
			'\t\t\t$_',
			'\t\t}) -join'
		].join('\n')
		assert.strictEqual(restoreParenIndentation(twoParens, '\t'), [
			'$str += (($obj.GetEnumerator() | ForEach-Object {',
			'\t$_',
			'}) -join'
		].join('\n'))

		const continuation = ['$x = (Get-Foo -Bar `', '\t\t-Baz qux)'].join('\n')
		assert.strictEqual(restoreParenIndentation(continuation, '\t'), ['$x = (Get-Foo -Bar `', '\t-Baz qux)'].join('\n'))

		// 字符串内的前导空白不能被误认为开括号：没有任何内容具有过度缩进的特征，因此什么都不会移动。
		const stringParen = ['$x = "(" | ForEach-Object {', '\t$_', '}'].join('\n')
		assert.strictEqual(restoreParenIndentation(stringParen, '\t'), stringParen)
	})

	test('realigns an else/catch moved onto its own line', () => {
		// 针对以下 issue 中 tab 限制的变通方案：
		// https://github.com/PowerShell/PSScriptAnalyzer/issues/1055
		// （重复 https://github.com/PowerShell/PSScriptAnalyzer/issues/1441）：
		// PSPlaceCloseBrace 在将关键字下移时会硬编码一个空格。当该规则支持 `Kind = 'tab'` 后，连同 `restoreClauseIndentation` 一起删除。
		const broken = ['function f {', '\tif ($a) {', '\t\t$b', '\t}', ' else {', '\t\t$c', '\t}', '}'].join('\n')
		assert.strictEqual(restoreClauseIndentation(broken), [
			'function f {',
			'\tif ($a) {',
			'\t\t$b',
			'\t}',
			'\telse {',
			'\t\t$c',
			'\t}',
			'}'
		].join('\n'))

		// 已经正确的情况（顶层，或深度 >= 2）保持不变。
		const fine = ['\tif ($a) {', '\t\t1', '\t}', '\telse {', '\t\t2', '\t}'].join('\n')
		assert.strictEqual(restoreClauseIndentation(fine), fine)
		const topLevel = ['if ($a) {', '\t1', '}', 'else {', '\t2', '}'].join('\n')
		assert.strictEqual(restoreClauseIndentation(topLevel), topLevel)
	})

	test('ps12exe\'s own scripts analyse without diagnostics', function () {
		// 防止编辑器规则与 ps12exe 随附的脚本发生偏移。
		if (!fs.existsSync(path.join(REPO_ROOT, 'ps12exe.ps1'))) this.skip()

		const files = collectPs1(REPO_ROOT)
		assert.ok(files.length > 10, `expected to find ps12exe's scripts under ${REPO_ROOT}`)

		const failures = []
		for (const file of files) {
			const { diagnostics } = analyze(fs.readFileSync(file, 'utf8'))
			for (const d of diagnostics) 
				failures.push(`${path.relative(REPO_ROOT, file)}:${d.line + 1} [${d.severity}] ${d.message}`)
			
		}
		assert.deepStrictEqual(failures, [], `ps12exe's own scripts must be warning-free:\n${failures.join('\n')}`)
	})
})
