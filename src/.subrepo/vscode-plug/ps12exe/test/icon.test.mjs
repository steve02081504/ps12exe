/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import { Buffer } from 'node:buffer'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { resolveIconAt, needsIconExtraction, renderableMime, getIconPreview, buildProbeScript } from '../lib/icon.mjs'
import { resolvePlainPowerShell } from '../lib/powershell.mjs'

suite('ps12exe icon paths', () => {
	const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
	/**
	 * 拼接仓库根目录下的路径并规范化。
	 *
	 * @param {...string} parts - 路径片段
	 * @returns {string} 规范化后的绝对路径
	 */
	const join = (...parts) => path.normalize(path.join(base, ...parts))

	test('detects the icon path under the cursor, including its index', () => {
		const line = '\t#_pragma Resources.Icon "$PSScriptRoot/img/icon.ico,3"'
		const start = line.indexOf('"$PSScriptRoot')
		const end = line.length
		for (let character = start; character <= end; character++) {
			const found = resolveIconAt(line, character, base)
			assert.ok(found, `no icon at column ${character}`)
			assert.strictEqual(found.file, join('img/icon.ico'))
			assert.strictEqual(found.index, 3)
			assert.strictEqual(found.kind, 'icon')
		}
		assert.strictEqual(resolveIconAt(line, start - 1, base), null, 'the cursor before the value should not match')
	})

	test('ignores include directives and unrelated pragmas', () => {
		assert.strictEqual(resolveIconAt('#_include lib/helper.ps1', 12, base), null)
		assert.strictEqual(resolveIconAt('#_pragma Resources.IconFile img/icon.ico', 30, base), null)
		assert.strictEqual(resolveIconAt('#_pragma App.Windowed true', 20, base), null)
	})

	test('classifies container and image extensions like the compiler', () => {
		assert.strictEqual(needsIconExtraction('C:/Windows/System32/shell32.dll', null), true)
		assert.strictEqual(needsIconExtraction('app.exe', null), true)
		assert.strictEqual(needsIconExtraction('img/icon.ico', null), false)
		assert.strictEqual(needsIconExtraction('img/icon.png', null), false)
		// 显式索引 + 非图片后缀：按 PE 资源抽取。
		assert.strictEqual(needsIconExtraction('data.bin', 2), true)
		// 显式索引 + 图片后缀：不抽取，按图片读取（与编译器一致，索引被忽略）。
		assert.strictEqual(needsIconExtraction('img/icon.png', 2), false)
		assert.strictEqual(needsIconExtraction('img/icon.ico', 2), false)
	})

	test('maps the renderable image extensions to MIME types', () => {
		assert.strictEqual(renderableMime('a.png'), 'image/png')
		assert.strictEqual(renderableMime('a.JPG'), 'image/jpeg')
		assert.strictEqual(renderableMime('a.webp'), 'image/webp')
		assert.strictEqual(renderableMime('a.ico'), null)
		assert.strictEqual(renderableMime('a.dll'), null)
	})

	test('quotes the path and carries the index into the probe script', () => {
		const script = buildProbeScript('C:\\it\'s here\\shell32.dll', -16)
		assert.ok(script.includes('$path = \'C:\\it\'\'s here\\shell32.dll\''), 'the path must be single-quoted safely')
		assert.ok(script.includes('$index = -16'))
		assert.ok(script.includes('\'.exe\''))
		assert.ok(script.includes('$imageExtensions'))
		assert.ok(script.includes('PrivateExtractIcons'))
		assert.ok(script.includes('PS12EXE_ICON:'))
		assert.ok(buildProbeScript('img/icon.ico', null).includes('$index = -1'))
	})

	test('inlines a renderable image as a data URI without PowerShell', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-icon-'))
		try {
			const file = path.join(dir, 'icon.png')
			fs.writeFileSync(file, Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]))
			const preview = await getIconPreview({ file, index: null })
			assert.strictEqual(preview, `data:image/png;base64,${fs.readFileSync(file).toString('base64')}`)

			// 缓存命中后仍是同一个结果。
			assert.strictEqual(await getIconPreview({ file, index: null }), preview)

			assert.strictEqual(await getIconPreview({ file: path.join(dir, 'missing.png'), index: null }), null)
		}
		finally {
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('converts an .ico and a PE container to a PNG data URI', async function () {
		if (process.platform !== 'win32') this.skip()
		this.timeout(60000)
		const host = await resolvePlainPowerShell()
		if (!host) this.skip()

		// 仓库根目录（此处 use 的图标由主仓库的构建脚本提供）。
		const icon = path.normalize(path.join(base, '..', '..', '..', '..', 'img', 'icon.ico'))
		if (!fs.existsSync(icon)) this.skip()
		assert.match(await getIconPreview({ file: icon, index: null }), /^data:image\/png;base64,[A-Za-z0-9+/=]+$/)

		const container = path.join(process.env.WINDIR || 'C:\\Windows', 'System32', 'shell32.dll')
		if (!fs.existsSync(container)) this.skip()
		assert.match(await getIconPreview({ file: container, index: 0 }), /^data:image\/png;base64,[A-Za-z0-9+/=]+$/)
	})
})
