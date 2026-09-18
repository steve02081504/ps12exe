import fs from 'node:fs'
import path from 'node:path'

import * as vscode from 'vscode'

import { resolveDirectivePath } from './lib/definition.mjs'
import { registerExeSource } from './lib/exeSource.mjs'
import { applyPreprocessorFormatting } from './lib/format.mjs'
import { HOVER_MESSAGES, directiveAt, conditionAt, documentationUrl } from './lib/hover.mjs'
import { toPs12exeLocale } from './lib/locale.mjs'
import { POWER_SHELL_EXTENSION_ID, isPowerShellExtensionInstalled, getOfficialEdits, applyTextEdits } from './lib/officialFormatter.mjs'
import { resolvePowerShell, compileScript, syncModule, launchGUI } from './lib/powershell.mjs'
import { pragmaNameAt, getPragmaData, lookupPragma, buildPragmaCandidates, clearPragmaCache } from './lib/pragma.mjs'
import { analyze, endifAutoClose, foldingRanges, toggleBangLines, computeSkipMask } from './lib/preprocessor.mjs'

const OUTPUT_CHANNEL_NAME = 'ps12exe'
const POWER_SHELL_SELECTOR = { language: 'powershell' }
const FIX_ALL_KIND = vscode.CodeActionKind.SourceFixAll.append('ps12exe')

/** @type {vscode.OutputChannel | undefined} */
let outputChannel
/** @type {vscode.DiagnosticCollection | undefined} */
let diagnosticCollection
let missingPowerShellNotified = false
const diagnosticsTimers = new Map()

/**
 * 本地化字符串辅助函数。
 *
 * @param {string} message - 本地化消息模板
 * @param {...any} args - 格式化参数列表
 * @returns {string} 本地化后的字符串
 */
function t (message, ...args) {
	return vscode.l10n.t(message, ...args)
}

/**
 * 获取共享输出通道。
 *
 * @returns {vscode.OutputChannel} 共享输出通道实例
 */
function getOutputChannel () {
	if (!outputChannel) outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME)
	return outputChannel
}

/**
 * 解析命令应作用的文件。从资源管理器/编辑器菜单触发的命令通过参数接收资源，从命令面板触发的命令回退到当前活动编辑器。
 *
 * @param {unknown} resource - 命令触发时传入的资源参数
 * @returns {vscode.Uri | undefined} 解析到的目标文件地址，未找到时为 undefined
 */
function resolveTarget (resource) {
	if (resource instanceof vscode.Uri) return resource
	const editor = vscode.window.activeTextEditor
	if (editor) return editor.document.uri
	return undefined
}

/**
 * 判断给定地址是否为本地 .ps1 文件。
 *
 * @param {vscode.Uri | undefined} uri - 待判断的文档地址
 * @returns {boolean} 是本地 .ps1 文件时为真
 */
function isPs1 (uri) {
	return !!uri && uri.scheme === 'file' && path.extname(uri.fsPath).toLowerCase() === '.ps1'
}

/**
 * 把 VS Code 颜色主题映射为 ps12exeGUI 的 `-UIMode` 值。
 *
 * @returns {string} 对应的界面模式取值
 */
function currentUiMode () {
	switch (vscode.window.activeColorTheme.kind) {
		case vscode.ColorThemeKind.Dark:
		case vscode.ColorThemeKind.HighContrast:
			return 'Dark'
		case vscode.ColorThemeKind.Light:
		case vscode.ColorThemeKind.HighContrastLight:
			return 'Light'
		default:
			return 'Auto'
	}
}

/**
 * 打开一个终端，为当前用户安装 ps12exe 模块。
 * @param {{command: string}} host - PowerShell 宿主信息，包含可执行命令
 */
function installModule (host) {
	const terminal = vscode.window.createTerminal(OUTPUT_CHANNEL_NAME)
	terminal.sendText(`${host.command} -NoProfile -ExecutionPolicy Bypass -Command "Install-Module ps12exe -Scope CurrentUser -Force"`)
	terminal.show()
	vscode.window.showInformationMessage(t('Installing ps12exe in a terminal. Re-run the command when it finishes.'))
}

/**
 * 解析可用的 PowerShell 宿主。若缺少 ps12exe 模块，会自动安装（最新版），仅在失败时才提供手动终端安装。
 *
 * @returns {Promise<{ command: string } | undefined>} 解析到的可用宿主，未找到或安装失败时为 undefined
 */
async function requireHost () {
	const host = await resolvePowerShell()
	if (!host) {
		vscode.window.showErrorMessage(t('No PowerShell host (pwsh or powershell) was found.'))
		return undefined
	}
	if (host.moduleVersion) return host

	const result = await vscode.window.withProgress({
		location: vscode.ProgressLocation.Notification,
		title: t('Installing ps12exe...'),
		cancellable: true
	}, (progress, token) => syncModule({ host, channel: getOutputChannel(), token }))

	if (result.status === 'installed' || result.status === 'updated') {
		const refreshed = await resolvePowerShell(true)
		clearPragmaCache()
		if (refreshed && refreshed.moduleVersion) {
			if (result.status === 'installed') vscode.window.showInformationMessage(t('ps12exe {0} has been installed.', result.version || ''))
			return refreshed
		}
	}

	getOutputChannel().show(true)
	const installLabel = t('Install ps12exe')
	const choice = await vscode.window.showErrorMessage(
		t('Failed to install ps12exe: {0}', result.error || result.status),
		installLabel
	)
	if (choice === installLabel) installModule(host)
	return undefined
}

/**
 * 在后台保持 ps12exe 模块为最新版。在激活时运行，除非被禁用或处于扩展测试框架下。
 *
 * @param {vscode.ExtensionContext} context - 扩展上下文，用于读取配置与订阅
 */
async function autoUpdateModule (context) {
	if (context.extensionMode === vscode.ExtensionMode.Test) return
	if (!vscode.workspace.getConfiguration('ps12exe').get('autoUpdate', true)) return

	const host = await resolvePowerShell()
	if (!host) return

	const result = await syncModule({ host, channel: getOutputChannel() })
	if (result.status === 'installed' || result.status === 'updated') {
		await resolvePowerShell(true)
		clearPragmaCache()
		if (result.status === 'installed') vscode.window.showInformationMessage(t('ps12exe {0} has been installed.', result.version || ''))
		else vscode.window.showInformationMessage(t('ps12exe has been updated to {0}.', result.version || ''))
	}
	else if (result.status === 'error') 
		getOutputChannel().appendLine(`ps12exe auto-update failed: ${result.error || 'unknown error'}`)
	
}

/**
 * 编译给定的 `.ps1` 文件：像命令行那样用该文件调用 ps12exe。
 *
 * @param {vscode.Uri | undefined} resource - 待编译的脚本资源，未提供时使用活动编辑器
 */
async function compileCommand (resource) {
	const uri = resolveTarget(resource)
	if (!isPs1(uri)) {
		vscode.window.showWarningMessage(t('Please select or open a PowerShell script (.ps1) file.'))
		return
	}

	const host = await requireHost()
	if (!host) return

	const file = uri.fsPath
	const locale = toPs12exeLocale(vscode.env.language)
	const outputPath = file.replace(/\.ps1$/i, '.exe')

	const result = await vscode.window.withProgress({
		location: vscode.ProgressLocation.Notification,
		title: t('Compiling {0}...', path.basename(file)),
		cancellable: true
	}, (progress, token) => compileScript({ host, file, locale, channel: getOutputChannel(), token }))

	if (result.cancelled) {
		vscode.window.showInformationMessage(t('Compilation cancelled.'))
		return
	}

	if (result.error) {
		getOutputChannel().show(true)
		vscode.window.showErrorMessage(t('Failed to start compilation: {0}', result.error.message))
		return
	}

	if (result.code === 0) {
		const message = t('Compilation succeeded: {0}', outputPath)
		if (fs.existsSync(outputPath)) {
			const revealLabel = t('Reveal Output File')
			const showOutputLabel = t('Show Output')
			const choice = await vscode.window.showInformationMessage(message, revealLabel, showOutputLabel)
			if (choice === revealLabel) vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(outputPath))
			else if (choice === showOutputLabel) getOutputChannel().show(true)
		}
		else 
			vscode.window.showInformationMessage(message)
		
		return
	}

	getOutputChannel().show(true)
	vscode.window.showErrorMessage(t('Compilation failed (exit code {0}).', String(result.code)))
}

/**
 * 为给定的 `.ps1` 文件打开 ps12exeGUI。
 *
 * @param {vscode.Uri | undefined} resource - 待打开的脚本资源，未提供时使用活动编辑器
 */
async function guiCommand (resource) {
	const uri = resolveTarget(resource)
	if (!isPs1(uri)) {
		vscode.window.showWarningMessage(t('Please select or open a PowerShell script (.ps1) file.'))
		return
	}

	const host = await requireHost()
	if (!host) return

	try {
		await launchGUI({
			host,
			file: uri.fsPath,
			locale: toPs12exeLocale(vscode.env.language),
			uiMode: currentUiMode()
		})
		vscode.window.showInformationMessage(t('Launching ps12exeGUI...'))
	}
	catch (error) {
		vscode.window.showErrorMessage(t('Failed to launch ps12exeGUI: {0}', error.message))
	}
}

/**
 * 在选区的每一普通行上切换 `#_!!` 转义标记；没有选区时则为整个文档。其他 preprocessor 指令（`#_if`、`#_include` 等）以及 here-string/块注释函数体保持不动，因此该命令永远不会把指令变成注释。
 *
 * @returns {Promise<void>}
 */
async function toggleBangCommand () {
	const editor = vscode.window.activeTextEditor
	if (!editor || editor.document.languageId !== 'powershell') {
		vscode.window.showWarningMessage(t('Please select or open a PowerShell script (.ps1) file.'))
		return
	}

	const { document, selection } = editor
	const wholeDocument = selection.isEmpty
	const first = wholeDocument ? 0 : selection.start.line
	let last = wholeDocument ? document.lineCount - 1 : selection.end.line
	// 结束于第 0 列的选区不包含该行。
	if (!wholeDocument && selection.end.character === 0 && last > first) last -= 1

	const lines = Array.from({ length: document.lineCount }, (_, index) => document.lineAt(index).text)
	const changes = toggleBangLines(lines, first, last, computeSkipMask(lines))
	if (!changes.length) return

	const edit = new vscode.WorkspaceEdit()
	for (const change of changes) edit.replace(document.uri, document.lineAt(change.line).range, change.text)
	await vscode.workspace.applyEdit(edit)
}

/**
 * 获取整个文档的范围。
 *
 * @param {vscode.TextDocument} document - 目标文本文档
 * @returns {vscode.Range} 覆盖全文的范围
 */
function fullDocumentRange (document) {
	const lastLine = Math.max(document.lineCount - 1, 0)
	return new vscode.Range(new vscode.Position(0, 0), document.lineAt(lastLine).range.end)
}

/**
 * 读取文档对应的编辑器格式化选项。
 *
 * @param {vscode.TextDocument} document - 目标文本文档
 * @returns {{insertSpaces: boolean, tabSize: number}} 编辑器缩进选项
 */
function editorFormattingOptions (document) {
	const config = vscode.workspace.getConfiguration('editor', document)
	return {
		// `[powershell]` 默认为制表符（见 package.json 中的 `configurationDefaults`）；显式的 `editor.insertSpaces` 仍然优先。
		insertSpaces: config.get('insertSpaces', false),
		tabSize: config.get('tabSize', 4)
	}
}

/**
 * 刷新指定文档的诊断信息。
 *
 * @param {vscode.TextDocument} document - 目标文本文档
 */
function updateDiagnostics (document) {
	if (!diagnosticCollection || document.languageId !== 'powershell') return
	const found = analyze(document.getText()).diagnostics
	const items = found.map((entry) => {
		const line = document.lineAt(Math.min(entry.line, document.lineCount - 1))
		const diagnostic = new vscode.Diagnostic(
			line.range,
			t(entry.message, ...entry.args),
			entry.severity === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning
		)
		diagnostic.source = 'ps12exe'
		return diagnostic
	})
	diagnosticCollection.set(document.uri, items)
}

/**
 * 延迟刷新指定文档的诊断信息，避免频繁解析。
 *
 * @param {vscode.TextDocument} document - 目标文本文档
 */
function scheduleDiagnostics (document) {
	if (document.languageId !== 'powershell') return
	const key = document.uri.toString()
	clearTimeout(diagnosticsTimers.get(key))
	diagnosticsTimers.set(key, setTimeout(() => {
		diagnosticsTimers.delete(key)
		updateDiagnostics(document)
	}, 200))
}

/**
 * 缺少 PowerShell 扩展时弹窗提示安装。
 */
function notifyMissingPowerShell () {
	if (missingPowerShellNotified) return
	missingPowerShellNotified = true
	const installLabel = t('Install PowerShell extension')
	vscode.window.showWarningMessage(
		t('The PowerShell extension is required to run the official formatter before applying ps12exe preprocessor indentation.'),
		installLabel
	).then((choice) => {
		if (choice === installLabel) vscode.commands.executeCommand('workbench.extensions.installExtension', POWER_SHELL_EXTENSION_ID)
	})
}

/**
 * 运行官方 formatter（可用时），然后应用 ps12exe preprocessor 缩进。
 *
 * @param {vscode.TextDocument} document - 要格式化的文本文档
 * @param {vscode.FormattingOptions} options - VS Code 传入的格式化选项
 * @returns {Promise<string>} 格式化后的完整文档文本
 */
async function formatDocumentText (document, options) {
	const current = document.getText()
	const formattingOptions = options || editorFormattingOptions(document)
	const indentUnit = formattingOptions.insertSpaces ? ' '.repeat(formattingOptions.tabSize || 4) : '\t'

	let base = current
	let officialApplied = false
	if (isPowerShellExtensionInstalled()) 
		try {
			const edits = await getOfficialEdits(document, formattingOptions)
			officialApplied = true
			if (edits.length) base = applyTextEdits(document, current, edits)
		}
		catch (error) {
			const channel = getOutputChannel()
			channel.appendLine(t('Failed to run the official PowerShell formatter; the document was left unchanged.'))
			channel.appendLine(String(error && error.message ? error.message : error))
		}
	
	else 
		notifyMissingPowerShell()
	

	return applyPreprocessorFormatting(current, base, officialApplied, {
		indentUnit,
		/**
		 * 输出格式化错误信息。
		 *
		 * @param {string} message - 错误信息文本
		 * @returns {void} 无返回值
		 */
		onError: (message) => getOutputChannel().appendLine(message)
	})
}

/**
 * 格式化当前 PowerShell 文档并应用编辑。
 *
 * @param {string | undefined} uri - 触发命令时传入的文档地址字符串，未提供时使用活动编辑器
 */
async function formatDocumentCommand (uri) {
	let document
	if (uri) document = await vscode.workspace.openTextDocument(vscode.Uri.parse(uri))
	else document = vscode.window.activeTextEditor && vscode.window.activeTextEditor.document

	if (!document || document.languageId !== 'powershell') {
		vscode.window.showWarningMessage(t('Please select or open a PowerShell script (.ps1) file.'))
		return
	}

	const formatted = await formatDocumentText(document, editorFormattingOptions(document))
	if (formatted === document.getText()) return

	const edit = new vscode.WorkspaceEdit()
	edit.replace(document.uri, fullDocumentRange(document), formatted)
	await vscode.workspace.applyEdit(edit)
}

/**
 * 在刚打开的块下方追加匹配的 `#_endif`。光标停留在空行上，因此可以直接键入块函数体。
 *
 * @param {vscode.TextEditor} editor - 目标编辑器
 * @param {number} line 换行后光标移动到的行
 * @param {string} indent `#_if` 行的缩进
 */
async function insertEndif (editor, line, indent) {
	const {document} = editor
	if (line >= document.lineCount) return
	const target = document.lineAt(line)
	if (/^\s*#_endif\b/.test(target.text)) return

	const eol = document.eol === vscode.EndOfLine.CRLF ? '\r\n' : '\n'
	await editor.edit((builder) => {
		builder.insert(new vscode.Position(line, target.text.length), `${eol}${indent}#_endif`)
	}, { undoStopBefore: false, undoStopAfter: false })
}

/**
 * 用户一开始输入块函数体，就用 `#_endif` 闭合 `#_if …` 行。可通过 `ps12exe.autoCloseIf` 禁用。
 *
 * @param {vscode.ExtensionContext} context - 扩展上下文，用于注册文档变更监听
 */
function registerIfAutoClose (context) {
	context.subscriptions.push(vscode.workspace.onDidChangeTextDocument((event) => {
		if (event.document.languageId !== 'powershell' || event.contentChanges.length === 0) return
		if (!vscode.workspace.getConfiguration('ps12exe', event.document).get('autoCloseIf', true)) return

		const editor = vscode.window.activeTextEditor
		if (!editor || editor.document !== event.document) return

		for (const change of event.contentChanges) {
			const breakLine = change.range.start.line
			const current = breakLine < event.document.lineCount ? event.document.lineAt(breakLine).text : undefined
			const close = endifAutoClose(current, change.text)
			if (!close) continue

			void insertEndif(editor, breakLine + close.offset, close.indent)
			return
		}
	}))
}

const formattingProvider = {
	/**
	 * 提供文档格式化编辑。
	 *
	 * @param {vscode.TextDocument} document - 要格式化的文本文档
	 * @param {vscode.FormattingOptions} options - VS Code 传入的格式化选项
	 * @returns {Promise<vscode.TextEdit[]>} 格式化编辑列表
	 */
	async provideDocumentFormattingEdits (document, options) {
		const formatted = await formatDocumentText(document, options)
		if (formatted === document.getText()) return []
		return [vscode.TextEdit.replace(fullDocumentRange(document), formatted)]
	}
}

const definitionProvider = {
	/**
	 * 从 `#_include*` 和 `#_pragma Resources.Icon` 参数跳转到它们引用的文件。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Position} position - 光标位置
	 * @returns {vscode.Location | null} 跳转目标位置，未找到时为空
	 */
	provideDefinition (document, position) {
		if (document.languageId !== 'powershell' || document.uri.scheme !== 'file') return null
		const line = document.lineAt(position.line).text
		const target = resolveDirectivePath(line, path.dirname(document.uri.fsPath))
		if (!target) return null
		if (position.character < target.start || position.character > target.end) return null
		if (!fs.existsSync(target.file)) return null
		return new vscode.Location(vscode.Uri.file(target.file), new vscode.Position(0, 0))
	}
}

/**
 * 为 `#_pragma` 变量名构造悬浮提示：其本地化说明来自当前安装的 ps12exe 模块（见 `lib/pragma.mjs`），并链接到 README 的预处理小节。区域数据不可用时回退到通用的 `#_pragma` 说明。
 *
 * @param {number} line - 悬浮提示所在行号
 * @param {{ name: string, start: number, end: number }} pragma - 识别到的 pragma 名称及其列范围
 * @param {string | undefined} locale - 当前区域标识，未知时为 undefined
 * @returns {Promise<vscode.Hover>} 构造好的悬浮提示
 */
async function createPragmaHover (line, pragma, locale) {
	let description
	try {
		const data = await getPragmaData(locale)
		const entry = lookupPragma(data, pragma.name)
		if (entry) description = entry.description
	}
	catch {
		// 模块未安装或读取失败：退回通用说明，不改动悬停本身。
	}

	const contents = new vscode.MarkdownString()
	if (description) contents.appendMarkdown(`\`#_pragma ${pragma.name}\`\n\n${description}`)
	else contents.appendMarkdown(t(HOVER_MESSAGES.pragma))
	const url = documentationUrl(locale, 'pragma')
	contents.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${url})`)
	return new vscode.Hover(contents, new vscode.Range(line, pragma.start, line, pragma.end))
}

/**
 * 为 preprocessor 指令或 `#_if` 条件关键字构造悬浮提示：本地化说明加指向当前区域 README 对应小节的链接。
 *
 * @param {number} line - 悬浮提示所在行号
 * @param {{ section: string, start: number, end: number }} token - 识别到的标记及其列范围
 * @param {string | undefined} locale - 当前区域标识，未知时为 undefined
 * @returns {vscode.Hover} 构造好的悬浮提示
 */
function createDirectiveHover (line, token, locale) {
	const contents = new vscode.MarkdownString()
	contents.appendMarkdown(t(HOVER_MESSAGES[token.section]))
	const url = documentationUrl(locale, token.section)
	contents.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${url})`)
	return new vscode.Hover(contents, new vscode.Range(line, token.start, line, token.end))
}

const hoverProvider = {
	/**
	 * 在 preprocessor 指令、`#_if` 条件关键字（`PSEXE`/`PSScript`，以及 `#_pragma` 变量名）上显示本地化的说明，并链接到当前区域 README 中对应的小节。here-string 函数体和块注释内的 `#_…` 不是指令，因此不提示。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Position} position - 光标位置
	 * @returns {Promise<vscode.Hover | null>} 悬浮提示，未命中指令时为空
	 */
	async provideHover (document, position) {
		if (document.languageId !== 'powershell') return null
		const line = document.lineAt(position.line).text
		const locale = toPs12exeLocale(vscode.env.language)

		const pragma = pragmaNameAt(line, position.character)
		if (pragma) {
			if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return null
			return createPragmaHover(position.line, pragma, locale)
		}

		const token = conditionAt(line, position.character) || directiveAt(line, position.character)
		if (!token) return null
		if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return null
		return createDirectiveHover(position.line, token, locale)
	}
}

const completionProvider = {
	/**
	 * 在 `#_pragma ` 后补全参数名；已输入父级点号（`App.`）时只列出该父级的直接子键。候选及其说明同样来自当前安装的模块。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Position} position - 光标位置
	 * @returns {Promise<vscode.CompletionItem[] | undefined>} 补全候选列表，无候选时为 undefined
	 */
	async provideCompletionItems (document, position) {
		if (document.languageId !== 'powershell') return undefined
		const line = document.lineAt(position.line).text
		const before = line.slice(0, position.character)
		const match = /^([\t ]*#_pragma[\t ]+)([A-Z_a-z][\w.]*)?$/.exec(before)
		if (!match) return undefined
		if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return undefined

		const locale = toPs12exeLocale(vscode.env.language)
		let data
		try {
			data = await getPragmaData(locale)
		}
		catch {
			return undefined
		}

		const url = documentationUrl(locale, 'pragma')
		const range = new vscode.Range(position.line, match[1].length, position.line, position.character)
		return buildPragmaCandidates(data, match[2] || '').map((candidate) => {
			const item = new vscode.CompletionItem(
				candidate.name,
				candidate.kind === 'object' ? vscode.CompletionItemKind.Module : vscode.CompletionItemKind.Property
			)
			item.insertText = candidate.insertText
			item.range = range
			item.detail = t('ps12exe compilation parameter')
			const docs = new vscode.MarkdownString(candidate.description)
			docs.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${url})`)
			item.documentation = docs
			return item
		})
	}
}

const foldingProvider = {
	/**
	 * 把每个 preprocessor 块从其 `#_if` 行折叠到其 `#_endif` 之前的一行。对 PowerShell 扩展自身基于 AST 的折叠是附加的。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @returns {vscode.FoldingRange[]} 折叠区域列表
	 */
	provideFoldingRanges (document) {
		if (document.languageId !== 'powershell') return []
		return foldingRanges(document.getText()).map(
			(range) => new vscode.FoldingRange(range.start, range.end, vscode.FoldingRangeKind.Region)
		)
	}
}

const codeActionProvider = {
	/**
	 * 提供快速修复操作，用于格式化 preprocessor 块。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @returns {vscode.CodeAction[]} 代码操作列表
	 */
	provideCodeActions (document) {
		if (document.languageId !== 'powershell') return []
		const action = new vscode.CodeAction(t('Format ps12exe preprocessor blocks'), FIX_ALL_KIND)
		action.command = {
			command: 'ps12exe.formatDocument',
			title: action.title,
			arguments: [document.uri.toString()]
		}
		return [action]
	}
}

/**
 * 激活扩展，注册命令与语言功能。
 *
 * @param {vscode.ExtensionContext} context - 扩展上下文，用于注册订阅
 */
export function activate (context) {
	outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME)
	diagnosticCollection = vscode.languages.createDiagnosticCollection(OUTPUT_CHANNEL_NAME)
	context.subscriptions.push(outputChannel, diagnosticCollection)

	context.subscriptions.push(
		vscode.commands.registerCommand('ps12exe.compilePs1ToExe', compileCommand),
		vscode.commands.registerCommand('ps12exe.ps12exeGUI', guiCommand),
		vscode.commands.registerCommand('ps12exe.toggleBang', toggleBangCommand),
		vscode.commands.registerCommand('ps12exe.formatDocument', formatDocumentCommand),
		vscode.languages.registerDocumentFormattingEditProvider(POWER_SHELL_SELECTOR, formattingProvider),
		vscode.languages.registerDefinitionProvider(POWER_SHELL_SELECTOR, definitionProvider),
		vscode.languages.registerHoverProvider(POWER_SHELL_SELECTOR, hoverProvider),
		vscode.languages.registerCompletionItemProvider(POWER_SHELL_SELECTOR, completionProvider, '.', ' '),
		vscode.languages.registerFoldingRangeProvider(POWER_SHELL_SELECTOR, foldingProvider),
		vscode.languages.registerCodeActionsProvider(POWER_SHELL_SELECTOR, codeActionProvider, { providedCodeActionKinds: [FIX_ALL_KIND] }),
		vscode.workspace.onDidOpenTextDocument(updateDiagnostics),
		vscode.workspace.onDidChangeTextDocument((event) => scheduleDiagnostics(event.document)),
		vscode.workspace.onDidCloseTextDocument((document) => diagnosticCollection.delete(document.uri))
	)

	registerIfAutoClose(context)
	registerExeSource(context, { requireHost, channel: getOutputChannel() })

	vscode.workspace.textDocuments.forEach(updateDiagnostics)

	void autoUpdateModule(context)
}

/**
 * 停用扩展，订阅会由 VS Code 自动释放。
 */
export function deactivate () {
	// 一切都通过 `context.subscriptions` 释放。
}
