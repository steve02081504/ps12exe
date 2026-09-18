import assert from 'node:assert'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { resolveDirectivePath, unquote } from '../lib/definition.mjs'

suite('ps12exe directive paths', () => {
	const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
	const join = (...parts) => path.normalize(path.join(base, ...parts))

	test('resolves #_include paths', () => {
		assert.strictEqual(resolveDirectivePath(" #_include 'lib/helper.ps1'", base).file, join('lib/helper.ps1'))
		assert.strictEqual(resolveDirectivePath('#_include lib/helper.ps1', base).file, join('lib/helper.ps1'))
	})

	test('expands $PSScriptRoot', () => {
		assert.strictEqual(resolveDirectivePath('#_include $PSScriptRoot/lib/helper.ps1', base).file, join('lib/helper.ps1'))
	})

	test('resolves #_include_as_* and Resources.Icon pragma paths', () => {
		assert.strictEqual(resolveDirectivePath("#_include_as_value data 'assets/data.txt'", base).file, join('assets/data.txt'))
		assert.strictEqual(resolveDirectivePath('#_include_as_base64 blob "assets/data.bin"', base).file, join('assets/data.bin'))
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon "img/icon.ico"', base).file, join('img/icon.ico'))
	})

	test('ignores urls, dynamic expressions and unrelated lines', () => {
		assert.strictEqual(resolveDirectivePath("#_include 'https://example.com/a.ps1'", base), null)
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon "$(Join-Path $PSScriptRoot icon.ico)"', base), null)
		assert.strictEqual(resolveDirectivePath('Write-Output "hi"', base), null)
	})

	test('reports the source range of the path', () => {
		const line = '#_include  lib/helper.ps1  '
		const target = resolveDirectivePath(line, base)
		assert.strictEqual(line.slice(target.start, target.end), 'lib/helper.ps1')
	})

	test('unquotes single and double quotes', () => {
		assert.strictEqual(unquote("'it''s.ps1'"), "it's.ps1")
		assert.strictEqual(unquote('"a""b.ps1"'), 'a"b.ps1')
	})
})
