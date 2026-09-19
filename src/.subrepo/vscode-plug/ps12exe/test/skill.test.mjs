/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

/**
 * 解析 `SKILL.md` 顶部的 YAML frontmatter（只取顶层标量键）。
 *
 * @param {string} text - 文件内容
 * @returns {Record<string, string>} 解析出的键值
 */
function frontmatter (text) {
	const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)
	assert.ok(match, 'SKILL.md is missing YAML frontmatter')
	const data = {}
	for (const line of match[1].split(/\r?\n/)) {
		const entry = /^([A-Za-z-]+):\s*(.*)$/.exec(line)
		if (entry) data[entry[1]] = entry[2].trim()
	}
	return data
}

suite('ps12exe chat skill', () => {
	test('contributes a SKILL.md whose name matches its folder', () => {
		const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'))
		const skills = pkg.contributes?.chatSkills
		assert.ok(Array.isArray(skills) && skills.length >= 1, 'package.json does not contribute any chatSkills')

		for (const skill of skills) {
			assert.strictEqual(typeof skill.path, 'string', 'a chatSkills entry is missing its path')
			assert.ok(skill.path.startsWith('./'), `skill path must be relative: ${skill.path}`)

			const file = path.resolve(ROOT, skill.path)
			assert.ok(file.startsWith(ROOT + path.sep), `skill path escapes the extension root: ${skill.path}`)
			assert.ok(fs.existsSync(file), `missing skill file: ${skill.path}`)

			const meta = frontmatter(fs.readFileSync(file, 'utf8'))
			const folder = path.basename(path.dirname(file))
			assert.strictEqual(meta.name, folder, `SKILL.md name must match its folder (${folder})`)
			assert.match(meta.name, /^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'skill name must be lowercase kebab-case')
			assert.ok(meta.description && meta.description.length <= 1024, 'SKILL.md needs a description of at most 1024 characters')
		}
	})
})
