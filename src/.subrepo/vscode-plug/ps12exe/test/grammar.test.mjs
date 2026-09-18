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
	'#_endif'
].join('\n')

/** All `keyword.control.directive.ps12exe`-style scopes captured for `text`. */
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
	// vscode-textmate only registers an injected grammar when its raw grammar
	// declares an `injectionSelector` (`const t = n.injectionSelector; t && …`),
	// so a grammar listed under `injectTo` without one is silently ignored and
	// never highlights anything. This guarded exactly that regression.
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

			for (const target of grammar.injectTo) {
				assert.ok(
					source.injectionSelector.includes(target),
					`${grammar.path} injects into ${target} but its selector does not mention it: ${source.injectionSelector}`
				)
			}
		}
	})

	test('highlights directives and conditions inside PowerShell comments', async function () {
		this.timeout(60000)
		let tokens
		try {
			tokens = await captureScopes(SAMPLE)
		}
		catch {
			// `_workbench.captureSyntaxTokens` is internal; skip on VS Code builds
			// that do not expose it instead of failing the suite.
			this.skip()
		}
		const has = (content, scope) => tokens.some((token) => token.content === content && token.scopes.includes(scope))

		assert.ok(has('#_', 'punctuation.definition.directive.ps12exe'), '#_ must be a directive punctuation')
		assert.ok(has('if', 'keyword.control.directive.ps12exe'), '#_if must be a directive keyword')
		assert.ok(has('else', 'keyword.control.directive.ps12exe'), '#_else must be a directive keyword')
		assert.ok(has('endif', 'keyword.control.directive.ps12exe'), '#_endif must be a directive keyword')
		assert.ok(has('PSScript', 'constant.language.condition.ps12exe'), 'the condition must be highlighted')

		// A trailing comment after the directive must stay a PowerShell comment.
		assert.ok(
			tokens.some((token) => token.scopes.includes('comment.line.powershell')),
			'the trailing #why must remain a line comment'
		)
	})
})
