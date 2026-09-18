/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { where_command } from '@steve02081504/exec'

import { ensureDependencyTree, isDependencyTreeValid, resolveNpm } from '../scripts/build.mjs'

const PROJECT_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

suite('ps12exe build', () => {
	test('leaves a valid dependency tree untouched', async () => {
		let repairs = 0
		const warnings = []
		const repaired = await ensureDependencyTree(PROJECT_DIR, {
			check: async () => true,
			repair: async () => { repairs++ },
			log: { warn: (message) => warnings.push(message) }
		})
		assert.strictEqual(repaired, false)
		assert.strictEqual(repairs, 0)
		assert.deepStrictEqual(warnings, [])
	})

	test('repairs an invalid dependency tree exactly once', async () => {
		const repairs = []
		const warnings = []
		const states = [false, true]
		const repaired = await ensureDependencyTree(PROJECT_DIR, {
			check: async () => states.shift(),
			repair: async (cwd) => repairs.push(cwd),
			log: { warn: (message) => warnings.push(message) }
		})
		assert.strictEqual(repaired, true)
		assert.deepStrictEqual(repairs, [PROJECT_DIR])
		assert.strictEqual(warnings.length, 1)
	})

	test('fails when the tree is still invalid after repairing', async () => {
		await assert.rejects(
			ensureDependencyTree(PROJECT_DIR, {
				check: async () => false,
				repair: async () => {},
				log: { warn: () => {} }
			}),
			/npm install/
		)
	})

	test('finds npm on PATH', async function () {
		if (!await where_command('npm')) this.skip()
		assert.ok(await resolveNpm())
	})

	test('accepts the installed node_modules as a valid npm dependency tree', async function () {
		this.timeout(60000)
		if (!await where_command('npm')) this.skip()
		assert.strictEqual(await isDependencyTreeValid(PROJECT_DIR), true)
	})
})
