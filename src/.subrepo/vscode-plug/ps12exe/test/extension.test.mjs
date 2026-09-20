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

	/**
	 * 轮询等待条件成立。
	 *
	 * @param {() => boolean} predicate - 条件
	 * @param {number} [timeout] - 超时毫秒数
	 * @returns {Promise<void>}
	 */
	async function waitFor(predicate, timeout = 5000) {
		const deadline = Date.now() + timeout
		while (!predicate()) {
			if (Date.now() > deadline) throw new Error('timed out waiting for the document to settle')
			await new Promise((resolve) => setTimeout(resolve, 25))
		}
	}

	/**
	 * 反复接受当前建议，直到 `predicate` 成立或超时。建议列表由文档变更监听异步弹出，列表尚未出现时该命令是空操作，
	 * 因此可安全重试。
	 *
	 * @param {() => boolean} predicate - 条件
	 * @param {number} [timeout] - 超时毫秒数
	 * @returns {Promise<void>}
	 */
	async function acceptUntil(predicate, timeout = 5000) {
		const deadline = Date.now() + timeout
		while (!predicate()) {
			if (Date.now() > deadline) throw new Error('timed out waiting for a suggestion to be accepted')
			await vscode.commands.executeCommand('acceptSelectedSuggestion')
			await new Promise((resolve) => setTimeout(resolve, 100))
		}
	}

	test('auto-closes an opened #_if with the cursor indented inside', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-autoclose-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, '#_if PSEXE')
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			const end = document.lineAt(0).range.end
			editor.selection = new vscode.Selection(end, end)
			await editor.edit((builder) => builder.insert(end, '\n'))

			await waitFor(() => document.lineCount >= 3)
			assert.strictEqual(document.getText().replace(/\r\n/g, '\n'), ['#_if PSEXE', '\t', '#_endif'].join('\n'))
			// 扩展在编辑落地后才移动光标，因此等待光标稳定，而不是仅等待文本出现。
			await waitFor(() => editor.selection.active.line === 1 && editor.selection.active.character === 1)
			assert.strictEqual(editor.selection.active.line, 1)
			assert.strictEqual(editor.selection.active.character, 1)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('skips the auto-close when the document is already balanced', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-autoclose-skip-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, ['#_if PSEXE', '#_endif'].join('\n'))
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			const end = document.lineAt(0).range.end
			editor.selection = new vscode.Selection(end, end)
			await editor.edit((builder) => builder.insert(end, '\n'))

			// 已有的 `#_endif` 已经闭合了这个 `#_if`，因此不应再补一个。
			await new Promise((resolve) => setTimeout(resolve, 300))
			assert.strictEqual(document.getText().replace(/\r\n/g, '\n'), ['#_if PSEXE', '', '#_endif'].join('\n'))
			assert.strictEqual(document.getText().split('#_endif').length - 1, 1)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('offers #_ directives through the completion provider, gated by the block structure', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-complete-'))
		try {
			/**
			 * 打开一个临时脚本并请求 `#_` 处的补全项标签。
			 *
			 * @param {string} name - 临时文件名
			 * @param {string} text - 文件内容
			 * @param {vscode.Position} position - 触发补全的位置
			 * @returns {Promise<string[]>} 补全项标签
			 */
			const labelsAt = async (name, text, position) => {
				const file = path.join(dir, name)
				fs.writeFileSync(file, text)
				const document = await vscode.workspace.openTextDocument(file)
				assert.strictEqual(document.languageId, 'powershell')
				const list = await vscode.commands.executeCommand('vscode.executeCompletionItemProvider', document.uri, position, '_')
				return list.items.map((item) => typeof item.label === 'string' ? item.label : item.label.label)
			}

			// 顶层、块已闭合：列出指令，但不能补 #_else / #_endif。
			const closed = await labelsAt('closed.ps1', ['#_if PSEXE', '$x = 1', '#_endif', '#_'].join('\n'), new vscode.Position(3, 2))
			assert.ok(closed.includes('#_if'), `#_if missing from ${JSON.stringify(closed)}`)
			assert.ok(closed.includes('#_include'))
			assert.ok(!closed.includes('#_else'))
			assert.ok(!closed.includes('#_endif'))

			// 打开的 #_if 尚无 #_else：允许补 #_else 与 #_endif。
			const open = await labelsAt('open.ps1', ['#_if PSEXE', '#_'].join('\n'), new vscode.Position(1, 2))
			assert.ok(open.includes('#_else'), `#_else missing from ${JSON.stringify(open)}`)
			assert.ok(open.includes('#_endif'))

			// 已有 #_else：不再补 #_else，但仍可补 #_endif。
			const elseUsed = await labelsAt('else.ps1', ['#_if PSEXE', '#_else', '#_'].join('\n'), new vscode.Position(2, 2))
			assert.ok(!elseUsed.includes('#_else'))
			assert.ok(elseUsed.includes('#_endif'))

			// here-string 内的 `#_` 不是指令。
			const hereString = await labelsAt('here.ps1', ['$s = @"', '#_', '"@'].join('\n'), new vscode.Position(1, 2))
			assert.ok(!hereString.includes('#_if'), `#_if should not be offered in a here-string: ${JSON.stringify(hereString)}`)
		}
		finally {
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('typing `#_` opens the suggestion list', async () => {
		// `_` 是单词字符、注释行上 quick suggestions 默认关闭，因此弹出列表依赖 registerDirectiveSuggest 显式触发。
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-suggest-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, '#')
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			const end = new vscode.Position(0, 1)
			editor.selection = new vscode.Selection(end, end)
			await editor.edit((builder) => builder.insert(end, '_'))

			// 建议列表由文档变更监听异步触发；反复接受直到某个候选被插入（列表尚未出现时该命令是空操作）。
			await acceptUntil(() => document.getText() !== '#_')
			assert.match(document.getText(), /^#_[!#A-Za-z_]/, `no #_ directive was accepted, got ${JSON.stringify(document.getText())}`)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('accepting `#_if` continues into the condition list and auto-closes `#_endif`', async () => {
		// 补全自带尾随空格，不会再触发注册的触发字符；`#_if` 用 follow-up 命令重开列表，选定条件后用换行命令触发自动闭合。
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-followup-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, '#')
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			const end = new vscode.Position(0, 1)
			editor.selection = new vscode.Selection(end, end)
			await editor.edit((builder) => builder.insert(end, '_'))

			await acceptUntil(() => /^#_if [A-Za-z]/.test(document.getText()))
			assert.match(document.getText(), /^#_if (PSEXE|PSScript)/, `condition was not completed: ${JSON.stringify(document.getText())}`)
			await acceptUntil(() => document.getText().includes('#_endif'))
			assert.match(document.getText(), /^#_if (PSEXE|PSScript)\r?\n\t\r?\n#_endif$/, `#_endif was not auto-inserted: ${JSON.stringify(document.getText())}`)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('corrects a full-width `#——` into `#_` and opens the list', async () => {
		// 输入法未切半角时 `_` 会变成中文标点；纠正后应像手动输入 `#_` 一样弹出补全。
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-fixdash-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, '#')
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const editor = await vscode.window.showTextDocument(document)
			const end = new vscode.Position(0, 1)
			editor.selection = new vscode.Selection(end, end)
			await editor.edit((builder) => builder.insert(end, '——'))

			await waitFor(() => document.getText() === '#_')
			await acceptUntil(() => document.getText() !== '#_')
			assert.match(document.getText(), /^#_[!#A-Za-z_]/, `the full-width dash was not completed: ${JSON.stringify(document.getText())}`)
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})

	test('offers quick fixes for PS2EXE and module commands', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-commands-'))
		const file = path.join(dir, 'sample.ps1')
		fs.writeFileSync(file, [
			'#_pragma App.Windowed',
			'ps2exe -inputFile sample.ps1 -noConsole',
			'gmo ps12exe -ListAvailable',
			'Install-Module foo -Scope CurrentUser -Force',
			'#_require PS2EXE'
		].join('\n'))
		try {
			const document = await vscode.workspace.openTextDocument(file)
			await vscode.window.showTextDocument(document)
			await waitFor(() => vscode.languages.getDiagnostics(document.uri).some((d) => d.source === 'ps12exe'))

			/**
			 * 取指定行上带某诊断代码的 ps12exe 诊断。
			 *
			 * @param {string} code - 诊断代码
			 * @param {number} line - 行号（从零开始）
			 * @returns {import('vscode').Diagnostic | undefined} 匹配的诊断
			 */
			const atLine = (code, line) => vscode.languages.getDiagnostics(document.uri)
				.find((d) => d.source === 'ps12exe' && d.code === code && d.range.start.line === line)
			const ps2exeDiagnostic = atLine('ps2exe-call', 1)
			const moduleDiagnostic = atLine('module-command', 2)
			const installDiagnostic = atLine('module-command', 3)
			const requirePs2exeDiagnostic = atLine('ps2exe-require', 4)
			assert.ok(ps2exeDiagnostic, 'no PS2EXE diagnostic')
			assert.ok(moduleDiagnostic, 'no gmo diagnostic')
			assert.ok(installDiagnostic, 'no Install-Module diagnostic')
			assert.ok(requirePs2exeDiagnostic, 'no #_require PS2EXE diagnostic')

			/**
			 * 在诊断处请求快速修复，并按编辑内容（而非本地化标题）挑选出目标操作。
			 *
			 * @param {vscode.Diagnostic} diagnostic - 目标诊断
			 * @param {(newText: string) => boolean} predicate - 匹配编辑新文本的谓词
			 * @returns {Promise<vscode.CodeAction>} 匹配到的代码操作
			 */
			const actionMatching = async (diagnostic, predicate) => {
				const actions = await vscode.commands.executeCommand('vscode.executeCodeActionProvider', document.uri, diagnostic.range)
				const found = actions.find((action) => action.edit && action.edit.entries().some(([, edits]) => edits.some((edit) => predicate(edit.newText))))
				assert.ok(found, `no matching action: ${JSON.stringify(actions.map((action) => action.title))}`)
				return found
			}

			// PS2EXE 调用整段改写成 ps12exe 的对象式 API。
			const rewrite = await actionMatching(ps2exeDiagnostic, (text) => text.startsWith('ps12exe -InputFile sample.ps1'))
			await vscode.workspace.applyEdit(rewrite.edit)
			assert.match(document.getText(), /^#_pragma App\.Windowed\nps12exe -InputFile sample\.ps1 -App @\{ Windowed = \$true \}$/m)

			// 模块安装行改写成 #_require。
			const require = await actionMatching(installDiagnostic, (text) => text === '#_require foo')
			await vscode.workspace.applyEdit(require.edit)
			assert.match(document.getText(), /^#_require foo$/m)

			// `#_require PS2EXE` 的模块名改写成 ps12exe。
			const requirePs2exe = await actionMatching(requirePs2exeDiagnostic, (text) => text === 'ps12exe')
			await vscode.workspace.applyEdit(requirePs2exe.edit)
			assert.match(document.getText(), /^#_require ps12exe$/m)

			// 其余诊断（这里是 gmo）只提供忽略标记。
			const ignore = await actionMatching(moduleDiagnostic, (text) => text.includes('use_ps12exe:ignore'))
			await vscode.workspace.applyEdit(ignore.edit)
			assert.match(document.getText(), /# use_ps12exe:ignore/)

			// 忽略标记生效后该行不再有诊断。
			await waitFor(() => !vscode.languages.getDiagnostics(document.uri).some((d) => d.source === 'ps12exe' && d.code === 'module-command' && d.range.start.line === moduleDiagnostic.range.start.line + 1))
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

	test('previews the Resources.Icon image on hover', async () => {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-icon-hover-'))
		const file = path.join(dir, 'sample.ps1')
		const icon = path.join(dir, 'icon.png')
		const bytes = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3])
		fs.writeFileSync(icon, bytes)
		const line = '#_pragma Resources.Icon "icon.png"'
		fs.writeFileSync(file, [line, '$x = 1'].join('\n'))
		try {
			const document = await vscode.workspace.openTextDocument(file)
			const position = new vscode.Position(0, line.indexOf('icon.png'))
			const hovers = await vscode.commands.executeCommand('vscode.executeHoverProvider', document.uri, position)
			const text = hovers
				.map((hover) => hover.contents.map((content) => typeof content === 'string' ? content : content.value).join('\n'))
				.join('\n')
			assert.match(text, /data:image\/png;base64,/, `no icon preview in ${JSON.stringify(text)}`)
			assert.ok(text.includes(bytes.toString('base64')), 'the preview should contain the image bytes')
		}
		finally {
			await vscode.commands.executeCommand('workbench.action.closeActiveEditor')
			fs.rmSync(dir, { recursive: true, force: true })
		}
	})
})
