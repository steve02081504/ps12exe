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
			/**
			 * 始终把依赖树报告为合法。
			 *
			 * @returns {Promise<boolean>} 恒为 true
			 */
			check: async () => true,
			/**
			 * 统计修复被调用的次数。
			 *
			 * @returns {Promise<void>} 无返回值
			 */
			repair: async () => { repairs++ },
			log: {
				/**
				 * 收集警告信息。
				 *
				 * @param {string} message - 警告文本
				 * @returns {number} 收集后的警告数量
				 */
				warn: (message) => warnings.push(message)
			}
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
			/**
			 * 依次返回预设的探测结果。
			 *
			 * @returns {Promise<boolean>} 下一个预设结果
			 */
			check: async () => states.shift(),
			/**
			 * 记录被修复的目录。
			 *
			 * @param {string} cwd - 扩展目录
			 * @returns {Promise<number>} 记录后的条目数量
			 */
			repair: async (cwd) => repairs.push(cwd),
			log: {
				/**
				 * 收集警告信息。
				 *
				 * @param {string} message - 警告文本
				 * @returns {number} 收集后的警告数量
				 */
				warn: (message) => warnings.push(message)
			}
		})
		assert.strictEqual(repaired, true)
		assert.deepStrictEqual(repairs, [PROJECT_DIR])
		assert.strictEqual(warnings.length, 1)
	})

	test('fails when the tree is still invalid after repairing', async () => {
		await assert.rejects(
			ensureDependencyTree(PROJECT_DIR, {
				/**
				 * 始终把依赖树报告为不合法。
				 *
				 * @returns {Promise<boolean>} 恒为 false
				 */
				check: async () => false,
				/**
				 * 什么也不做的占位修复函数。
				 *
				 * @returns {Promise<void>} 无返回值
				 */
				repair: async () => {},
				log: {
					/**
					 * 丢弃警告信息的占位日志器。
					 */
					warn: () => {}
				}
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
