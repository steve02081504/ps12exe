/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { resolveDirectivePath, splitIconIndex, unquote } from '../lib/definition.mjs'

suite('ps12exe directive paths', () => {
	const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
	/**
	 * 拼接仓库根目录下的路径并规范化。
	 *
	 * @param {...string} parts - 路径片段
	 * @returns {string} 规范化后的绝对路径
	 */
	const join = (...parts) => path.normalize(path.join(base, ...parts))

	test('resolves #_include paths', () => {
		assert.strictEqual(resolveDirectivePath(' #_include \'lib/helper.ps1\'', base).file, join('lib/helper.ps1'))
		assert.strictEqual(resolveDirectivePath('#_include lib/helper.ps1', base).file, join('lib/helper.ps1'))
	})

	test('expands $PSScriptRoot', () => {
		assert.strictEqual(resolveDirectivePath('#_include $PSScriptRoot/lib/helper.ps1', base).file, join('lib/helper.ps1'))
	})

	test('resolves #_include_as_* and Resources.Icon pragma paths', () => {
		assert.strictEqual(resolveDirectivePath('#_include_as_value data \'assets/data.txt\'', base).file, join('assets/data.txt'))
		assert.strictEqual(resolveDirectivePath('#_include_as_base64 blob "assets/data.bin"', base).file, join('assets/data.bin'))
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon "img/icon.ico"', base).file, join('img/icon.ico'))
	})

	test('strips the desktop.ini style icon index from Resources.Icon paths', () => {
		const quoted = resolveDirectivePath('#_pragma Resources.Icon "img/icon.ico,3"', base)
		assert.strictEqual(quoted.file, join('img/icon.ico'))
		assert.strictEqual(quoted.kind, 'icon')
		assert.strictEqual(quoted.index, 3)

		const container = resolveDirectivePath('#_pragma Resources.Icon $PSScriptRoot/shell32.dll,-16', base)
		assert.strictEqual(container.file, join('shell32.dll'))
		assert.strictEqual(container.index, -16)

		// 索引在引号外时同样解析。
		const outside = resolveDirectivePath('#_pragma Resources.Icon "img/icon.ico",5', base)
		assert.strictEqual(outside.file, join('img/icon.ico'))
		assert.strictEqual(outside.index, 5)

		// 范围覆盖包含索引在内的整段取值，光标落在索引上也能跳转。
		const line = '#_pragma Resources.Icon "img/icon.ico,3"'
		assert.strictEqual(line.slice(quoted.start, quoted.end), '"img/icon.ico,3"')

		// 没有索引时 index 为 null，且不会把普通逗号当索引。
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon img/icon.ico', base).index, null)
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon img/a,b.ico', base).file, join('img/a,b.ico'))
	})

	test('ignores urls, dynamic expressions and unrelated lines', () => {
		assert.strictEqual(resolveDirectivePath('#_include \'https://example.com/a.ps1\'', base), null)
		assert.strictEqual(resolveDirectivePath('#_pragma Resources.Icon "$(Join-Path $PSScriptRoot icon.ico)"', base), null)
		assert.strictEqual(resolveDirectivePath('Write-Output "hi"', base), null)
	})

	test('reports the source range of the path', () => {
		const line = '#_include  lib/helper.ps1  '
		const target = resolveDirectivePath(line, base)
		assert.strictEqual(line.slice(target.start, target.end), 'lib/helper.ps1')
	})

	test('splits a desktop.ini style index from an icon value', () => {
		assert.deepStrictEqual(splitIconIndex('img/icon.ico'), { value: 'img/icon.ico', index: null })
		assert.deepStrictEqual(splitIconIndex('shell32.dll,-16'), { value: 'shell32.dll', index: -16 })
		assert.deepStrictEqual(splitIconIndex('"img,a.ico",7'), { value: 'img,a.ico', index: 7 })
	})

	test('unquotes single and double quotes', () => {
		assert.strictEqual(unquote('\'it\'\'s.ps1\''), 'it\'s.ps1')
		assert.strictEqual(unquote('"a""b.ps1"'), 'a"b.ps1')
	})
})
