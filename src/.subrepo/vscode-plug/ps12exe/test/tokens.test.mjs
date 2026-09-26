/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { BANG_MARKER_RE, isCompleteLine, readValueToken, skipString } from '../lib/tokens.mjs'

// `isCompleteLine` 决定 PS2EXE 调用能否被静态改写（`lib/ps2exe.mjs`），它的注释/括号处理直接
// 影响是否给出改写建议，因此把边界钉死在这里，而不是只靠 `commands.test.mjs` 的间接覆盖。
suite('ps12exe token lexing', () => {
	test('accepts complete lines and rejects unterminated or unbalanced ones', () => {
		assert.strictEqual(isCompleteLine('ps2exe -inputFile a.ps1'), true)
		assert.strictEqual(isCompleteLine('$x = @{ a = 1 }'), true)
		assert.strictEqual(isCompleteLine('ps2exe a.ps1 `'), false)
		assert.strictEqual(isCompleteLine('if ($x) {'), false)
		assert.strictEqual(isCompleteLine('foo )'), false)
		assert.strictEqual(isCompleteLine(''), true)
	})

	test('treats # as a comment terminator regardless of bracket depth', () => {
		assert.strictEqual(isCompleteLine('ps2exe a.ps1 # trailing comment'), true)
		// 注释前未闭合的括号仍算未闭合：注释不能掩盖结构不完整。
		assert.strictEqual(isCompleteLine('ps2exe (a.ps1 # comment'), false)
		// 注释前闭合完成的括号正常抵消。
		assert.strictEqual(isCompleteLine('if ($x) { } # done'), true)
		// 多出来的右括号依旧是错误，即使后面跟注释。
		assert.strictEqual(isCompleteLine('foo ) # comment'), false)
	})

	test('does not treat # inside strings or after a backtick escape as a comment', () => {
		assert.strictEqual(isCompleteLine("ps2exe 'a # b'"), true)
		assert.strictEqual(isCompleteLine('ps2exe "a # b" (c)'), true)
		// 转义的 `#` 不是注释：它后面的未闭合括号仍算不完整（对照上一条普通注释会隐藏括号）。
		assert.strictEqual(isCompleteLine('ps2exe a.ps1 # (ignored'), true)
		assert.strictEqual(isCompleteLine('ps2exe a.ps1 `# (counted'), false)
	})

	test('skipString stops at the closing quote and on line end', () => {
		assert.strictEqual(skipString("'abc' rest", 0), 5)
		assert.strictEqual(skipString('"a`"b" tail', 0), 6)
		assert.strictEqual(skipString("'unterminated", 0), 13)
		assert.strictEqual(skipString("'''' x", 0), 4)
	})

	test('readValueToken keeps whitespace inside braces together and stops outside', () => {
		assert.strictEqual(readValueToken('@{ a = 1 } tail', 0), 10)
		assert.strictEqual(readValueToken('bare rest', 0), 4)
		assert.strictEqual(readValueToken("'x y' rest", 0), 5)
	})

	test('BANG_MARKER_RE matches the #_!! escape marker', () => {
		const match = BANG_MARKER_RE.exec('\t#_!! Get-Item')
		assert.ok(match)
		assert.strictEqual(match[0], '\t#_!! ')
		assert.strictEqual(BANG_MARKER_RE.exec('Get-Item'), null)
	})
})
