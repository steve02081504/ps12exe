/* global suite: readonly, test: readonly, suiteSetup: readonly */
import assert from 'node:assert'
import { Buffer } from 'node:buffer'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import * as vscode from 'vscode'

import { ExeSourceCustomEditorProvider, looksLikePs12Exe, replaceFile } from '../lib/exeSource.mjs'
import { toPs12exeLocale } from '../lib/locale.mjs'
import { encodeCommand, psQuote, parseSyncOutput, parseIncompleteOutput, resolvePlainPowerShell, resolvePowerShell, findIncompleteFragments } from '../lib/powershell.mjs'

suite('ps12exe extension', () => {
	suiteSetup(async () => {
		const extension = vscode.extensions.all.find((candidate) => candidate.packageJSON.name === 'ps12exe')
		if (extension && !extension.isActive) await extension.activate()
	})

	test('contributes the compile, GUI, toggle, format and exe-source commands', async () => {
		const commands = await vscode.commands.getCommands(true)
		assert.ok(commands.includes('ps12exe.compilePs1ToExe'))
		assert.ok(commands.includes('ps12exe.ps12exeGUI'))
		assert.ok(commands.includes('ps12exe.toggleBang'))
		assert.ok(commands.includes('ps12exe.formatDocument'))
		assert.ok(commands.includes('ps12exe.editExeSource'))
	})

	test('detects ps12exe executables by program-frame marker', () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-detect-'))
		try {
			const ps12exe = path.join(dir, 'app.exe')
			fs.writeFileSync(ps12exe, Buffer.concat([Buffer.from('MZ'), Buffer.from('\0\0PSRunnerNS\0\0')]))
			assert.strictEqual(looksLikePs12Exe(ps12exe), true)

			const other = path.join(dir, 'other.exe')
			fs.writeFileSync(other, Buffer.from('MZ just a regular executable'))
			assert.strictEqual(looksLikePs12Exe(other), false)

			const script = path.join(dir, 'app.ps1')
			fs.writeFileSync(script, Buffer.from('PSRunnerNS'))
			assert.strictEqual(looksLikePs12Exe(script), false)
		}
		finally {
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('keeps the previous executable as .old when replacing', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-replace-'))
		try {
			const source = path.join(dir, 'new.exe')
			const target = path.join(dir, 'app.exe')
			fs.writeFileSync(source, 'new')
			fs.writeFileSync(target, 'old')

			const backup = await replaceFile(source, target)
			assert.strictEqual(backup, `${target}.old`)
			assert.strictEqual(fs.readFileSync(target, 'utf8'), 'new')
			assert.strictEqual(fs.readFileSync(`${target}.old`, 'utf8'), 'old')

			// 过期备份会被覆盖，而不是阻止重命名。
			fs.writeFileSync(source, 'newer')
			await replaceFile(source, target)
			assert.strictEqual(fs.readFileSync(target, 'utf8'), 'newer')
			assert.strictEqual(fs.readFileSync(`${target}.old`, 'utf8'), 'new')

			// 替换不存在的目标时只是复制，不会创建备份。
			const created = path.join(dir, 'created.exe')
			assert.strictEqual(await replaceFile(source, created), undefined)
			assert.strictEqual(fs.readFileSync(created, 'utf8'), 'newer')
		}
		finally {
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('toggles #_!! through the command on the selected lines', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-bang-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, ['line one', '#_if PSEXE', 'line two', '#_endif', '#_!!line three'].join('\n'))
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			// 结束于第 0 列，因此第 4 行不属于选区。
			editor.selection = new vscode.Selection(0, 0, 4, 0)

			await vscode.commands.executeCommand('ps12exe.toggleBang')

			assert.strictEqual(
				document.getText(),
				['#_!!line one', '#_if PSEXE', '#_!!line two', '#_endif', '#_!!line three'].join('\n')
			)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('maps VS Code locales to ps12exe locales', () => {
		assert.strictEqual(toPs12exeLocale('en'), 'en-US')
		assert.strictEqual(toPs12exeLocale('en-US'), 'en-US')
		assert.strictEqual(toPs12exeLocale('en-gb'), 'en-UK')
		assert.strictEqual(toPs12exeLocale('zh-cn'), 'zh-CN')
		assert.strictEqual(toPs12exeLocale('zh'), 'zh-CN')
		assert.strictEqual(toPs12exeLocale('ja'), 'ja-JP')
		assert.strictEqual(toPs12exeLocale('fr'), 'fr-FR')
		assert.strictEqual(toPs12exeLocale('es'), 'es-ES')
		assert.strictEqual(toPs12exeLocale('hi'), 'hi-IN')
		assert.strictEqual(toPs12exeLocale(undefined), undefined)
	})

	test('quotes PowerShell values safely', () => {
		assert.strictEqual(psQuote('C:\\a b\\c.ps1'), '\'C:\\a b\\c.ps1\'')
		assert.strictEqual(psQuote('it\'s'), '\'it\'\'s\'')
	})

	test('encodes commands for -EncodedCommand as Base64 UTF-16LE', () => {
		assert.strictEqual(encodeCommand('echo 1'), Buffer.from('echo 1', 'utf16le').toString('base64'))
	})

	test('parses the ps12exe sync result', () => {
		const installed = parseSyncOutput('noise\nPS12EXE_SYNC: installed 1.2.3\nmore noise\n')
		assert.deepStrictEqual(installed, { status: 'installed', version: '1.2.3' })
		assert.deepStrictEqual(parseSyncOutput('PS12EXE_SYNC: up-to-date 1.2.3'), { status: 'up-to-date', version: '1.2.3' })
		assert.strictEqual(parseSyncOutput('nothing here'), undefined)
	})

	test('flags code fragments the PowerShell parser cannot complete', async function () {
		const host = await resolvePlainPowerShell()
		if (!host) this.skip()
		assert.deepStrictEqual(
			await findIncompleteFragments({ host, texts: ['Write-Output "hi"', 'if ($x) {', '# just a comment'] }),
			[false, true, false]
		)
	})

	test('parses the incomplete-fragment results', () => {
		assert.deepStrictEqual(
			parseIncompleteOutput('warn\nPS12EXE_PARSE:complete\nPS12EXE_PARSE:incomplete\n'),
			[false, true]
		)
		assert.deepStrictEqual(parseIncompleteOutput(''), [])
	})

	test('registers a non-text custom editor so binary executables can be resolved', () => {
		const provider = new ExeSourceCustomEditorProvider({})
		assert.strictEqual(typeof provider.openCustomDocument, 'function')
		assert.strictEqual(typeof provider.resolveCustomEditor, 'function')
		// 自定义文本编辑器会先把资源读成文本模型，二进制 `.exe` 在此之前就被 VS Code 拒绝（扩展回调不会被调用）。
		assert.strictEqual(provider.resolveCustomTextEditor, undefined)
	})

	test('opens a compiled exe as editable source through the custom editor', async function () {
		this.timeout(120000)
		const here = path.dirname(fileURLToPath(import.meta.url))
		const exe = path.resolve(here, '..', '..', '..', '..', '..', 'ps12exe.exe')
		if (!fs.existsSync(exe) || !looksLikePs12Exe(exe)) this.skip()
		const host = await resolvePowerShell()
		if (!host || !host.moduleVersion) this.skip()

		await vscode.commands.executeCommand('vscode.openWith', vscode.Uri.file(exe), 'ps12exe.exeSource')
		const editor = vscode.window.activeTextEditor
		assert.ok(editor, 'the embedded source editor should be active')
		assert.strictEqual(editor.document.uri.scheme, 'ps12exe-exe')
		assert.strictEqual(editor.document.languageId, 'powershell')
	})
})
