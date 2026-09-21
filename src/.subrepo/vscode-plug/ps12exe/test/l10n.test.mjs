/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { CLI_MESSAGES } from '../lib/cli.mjs'
import { COMMAND_MESSAGES } from '../lib/commands.mjs'
import { HOVER_MESSAGES } from '../lib/hover.mjs'
import { MESSAGES } from '../lib/preprocessor.mjs'

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

/**
 * 扩展传给 `vscode.l10n.t` 的所有运行时字符串，即源码中的 `t('…')` 字面量加上分析器的消息常量。
 *
 * @returns {Set<string>} 运行时字符串集合
 */
function usedRuntimeKeys() {
	const keys = new Set([...Object.values(MESSAGES), ...Object.values(HOVER_MESSAGES), ...Object.values(COMMAND_MESSAGES), ...Object.values(CLI_MESSAGES)])
	for (const dir of [ROOT, path.join(ROOT, 'lib')])
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			if (!entry.isFile() || !entry.name.endsWith('.mjs')) continue
			const source = fs.readFileSync(path.join(dir, entry.name), 'utf8')
			for (const match of source.matchAll(/\bt\(\s*'((?:[^'\\]|\\.)*)'/g))
				keys.add(match[1].replace(/\\'/g, '\''))
		}
	return keys
}

/**
 * `package.json` 中任何位置引用的所有 `%key%` 占位符。
 *
 * @param {object} pkg - 包清单对象
 * @returns {Set<string>} 引用的键集合
 */
function referencedPackageKeys(pkg) {
	const keys = new Set()
	/**
	 * 递归收集字符串中的占位键。
	 *
	 * @param {unknown} value - 待扫描的值
	 */
	const scan = (value) => {
		if (typeof value === 'string')
			for (const match of value.matchAll(/%([^%]+)%/g)) keys.add(match[1])
		else if (Array.isArray(value)) value.forEach(scan)
		else if (value && typeof value === 'object') Object.values(value).forEach(scan)
	}
	scan(pkg)
	return keys
}

suite('ps12exe localization', () => {
	test('runtime bundles match the strings used in code', () => {
		const used = usedRuntimeKeys()
		const dir = path.join(ROOT, 'l10n')
		const files = fs.readdirSync(dir).filter((name) => name.endsWith('.json'))
		assert.ok(files.length >= 6)

		for (const file of files) {
			const bundle = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'))
			const missing = [...used].filter((key) => !(key in bundle))
			const orphan = Object.keys(bundle).filter((key) => !used.has(key))
			assert.deepStrictEqual(missing, [], `${file} is missing used keys`)
			assert.deepStrictEqual(orphan, [], `${file} has keys that are no longer used`)
		}
	})

	test('package.nls files cover every %key% used by package.json', () => {
		const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'))
		const referenced = referencedPackageKeys(pkg)

		const files = fs.readdirSync(ROOT).filter((name) => name.startsWith('package.nls') && name.endsWith('.json'))
		assert.ok(files.length >= 7)

		const reference = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.nls.json'), 'utf8'))
		const expected = Object.keys(reference).sort()
		for (const file of files) {
			const bundle = JSON.parse(fs.readFileSync(path.join(ROOT, file), 'utf8'))
			assert.deepStrictEqual(Object.keys(bundle).sort(), expected, `${file} keys differ from package.nls.json`)
			const missing = [...referenced].filter((key) => !(key in bundle))
			assert.deepStrictEqual(missing, [], `${file} is missing ${missing.join(', ')}`)
		}
	})
})
