/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import * as vscode from 'vscode'

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const SAMPLE = [
	'#_if PSScript #why',
	'Write-Output 1',
	'#_else',
	'Write-Output 2',
	'#_endif',
	'#_pragma Resources.Icon img/icon.ico'
].join('\n')

/**
 * 为 `text` 捕获的所有 `keyword.control.directive.ps12exe` 风格作用域。
 *
 * @param {string} text - 待高亮的示例文本
 * @returns {Promise<object[]>} 捕获的词元与作用域列表
 */
async function captureScopes (text) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-grammar-'))
	const file = path.join(dir, 'sample.ps1')
	fs.writeFileSync(file, text)
	try {
		const tokens = await vscode.commands.executeCommand('_workbench.captureSyntaxTokens', vscode.Uri.file(file))
		return tokens.map((token) => ({ content: token.c, scopes: token.t }))
	}
	finally {
		fs.rmSync(dir, { recursive: true, force: true })
	}
}

suite('ps12exe grammar', () => {
	// vscode-textmate 只在其原始语法声明了 `injectionSelector`（`const t = n.injectionSelector; t && …`）时才注册注入语法，因此列在 `injectTo` 下却没有声明它的语法会被静默忽略，永远不会高亮任何内容。本测试正是为了防止该回归。
	test('every injected grammar declares an injectionSelector for its targets', () => {
		const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'))
		const grammars = (pkg.contributes && pkg.contributes.grammars) || []
		const injected = grammars.filter((grammar) => grammar.injectTo && grammar.injectTo.length)

		assert.ok(injected.length >= 1, 'expected at least one injected grammar')

		for (const grammar of injected) {
			const file = path.join(ROOT, grammar.path)
			assert.ok(fs.existsSync(file), `${grammar.path} is missing`)
			const source = JSON.parse(fs.readFileSync(file, 'utf8'))

			assert.strictEqual(typeof source.injectionSelector, 'string', `${grammar.path} has no injectionSelector`)
			assert.ok(source.injectionSelector.trim().length > 0, `${grammar.path} has an empty injectionSelector`)

			for (const target of grammar.injectTo) 
				assert.ok(
					source.injectionSelector.includes(target),
					`${grammar.path} injects into ${target} but its selector does not mention it: ${source.injectionSelector}`
				)
		}
	})

	test('highlights directives and conditions inside PowerShell comments', async function () {
		this.timeout(60000)
		let tokens
		try {
			tokens = await captureScopes(SAMPLE)
		}
		catch {
			// `_workbench.captureSyntaxTokens` 是内部 API；在未暴露它的 VS Code 构建上跳过，而不是让测试套件失败。
			this.skip()
		}
		/**
		 * 判断是否存在指定内容与作用域的词元。
		 *
		 * @param {string} content - 词元文本
		 * @param {string} scope - 作用域名称
		 * @returns {boolean} 是否存在匹配词元
		 */
		const has = (content, scope) => tokens.some((token) => token.content === content && token.scopes.includes(scope))

		assert.ok(has('#_', 'punctuation.definition.directive.ps12exe'), '#_ must be a directive punctuation')
		assert.ok(has('if', 'keyword.control.directive.ps12exe'), '#_if must be a directive keyword')
		assert.ok(has('else', 'keyword.control.directive.ps12exe'), '#_else must be a directive keyword')
		assert.ok(has('endif', 'keyword.control.directive.ps12exe'), '#_endif must be a directive keyword')
		assert.ok(has('PSScript', 'constant.language.condition.ps12exe'), 'the condition must be highlighted')
		assert.ok(
			has('Resources.Icon', 'entity.name.tag.pragma.ps12exe'),
			'a dotted pragma name must be highlighted as a whole'
		)

		// 指令后的尾随注释必须保持为 PowerShell 注释。
		assert.ok(
			tokens.some((token) => token.scopes.includes('comment.line.powershell')),
			'the trailing #why must remain a line comment'
		)
	})
})
