import fs from 'node:fs'
import path from 'node:path'

import * as vscode from 'vscode'

import { currentAliasMap, loadAliasMap } from './lib/aliases.mjs'
import { analyzeCommandUsage, computeIgnoredMask, IGNORE_DIRECTIVE, PS2EXE_DIAGNOSTIC, PS2EXE_REQUIRE_DIAGNOSTIC, MODULE_DIAGNOSTIC } from './lib/commands.mjs'
import { resolveDirectivePath } from './lib/definition.mjs'
import { buildDirectiveCandidates, directiveAvailability, directivePrefixAt, ifConditionPrefixAt, buildConditionCandidates } from './lib/directives.mjs'
import { registerExeSource } from './lib/exeSource.mjs'
import { applyPreprocessorFormatting } from './lib/format.mjs'
import { getPackageInfo, tagSearchUrl } from './lib/gallery.mjs'
import { HOVER_MESSAGES, directiveAt, conditionAt, documentationUrl, preserveLineBreaks, escapeHtmlAttribute } from './lib/hover.mjs'
import { resolveIconAt, getIconPreview } from './lib/icon.mjs'
import { toPs12exeLocale } from './lib/locale.mjs'
import { POWER_SHELL_EXTENSION_ID, isPowerShellExtensionInstalled, getOfficialEdits, applyTextEdits } from './lib/officialFormatter.mjs'
import { resolvePowerShell, compileScript, syncModule, launchGUI } from './lib/powershell.mjs'
import { pragmaNameAt, getPragmaData, lookupPragma, buildPragmaCandidates, clearPragmaCache } from './lib/pragma.mjs'
import { analyze, endifAutoClose, isBalanced, foldingRanges, toggleBangLines, computeSkipMask } from './lib/preprocessor.mjs'
import { requireModulesAt } from './lib/require.mjs'

const OUTPUT_CHANNEL_NAME = 'ps12exe'
const POWER_SHELL_SELECTOR = { language: 'powershell' }
const FIX_ALL_KIND = vscode.CodeActionKind.SourceFixAll.append('ps12exe')

/** @type {vscode.OutputChannel | undefined} */
let outputChannel
/** @type {vscode.DiagnosticCollection | undefined} */
let diagnosticCollection
let missingPowerShellNotified = false
let aliasProbeStarted = false
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
 * 首次需要诊断时在后台探测宿主的别名定义（`gmo`/`ipmo`/`inmo` 是否为标准别名），探测完成后刷新所有已打开文档的诊断。
 * 探测期间先使用内置回退映射，因此结果不会因等待而缺失。
 */
function ensureAliasMap () {
	if (aliasProbeStarted) return
	aliasProbeStarted = true
	void loadAliasMap().then(() => {
		vscode.workspace.textDocuments.forEach(updateDiagnostics)
	})
}

/**
 * 刷新指定文档的诊断信息。包含预处理块结构诊断与 PS2EXE / 模块管理命令诊断；被 `# use_ps12exe:ignore` 抑制的行不发布。
 *
 * @param {vscode.TextDocument} document - 目标文本文档
 */
function updateDiagnostics (document) {
	if (!diagnosticCollection || document.languageId !== 'powershell') return
	ensureAliasMap()
	const text = document.getText()
	const lines = text.split(/\r\n|\n|\r/)
	const ignored = computeIgnoredMask(lines)
	const found = [
		...analyze(text).diagnostics,
		...analyzeCommandUsage(text, currentAliasMap())
	]

	const items = found
		.filter((entry) => !ignored[entry.line])
		.map((entry) => {
			const line = document.lineAt(Math.min(entry.line, document.lineCount - 1))
			const range = typeof entry.start === 'number'
				? new vscode.Range(line.lineNumber, entry.start, line.lineNumber, entry.end)
				: line.range
			const diagnostic = new vscode.Diagnostic(
				range,
				t(entry.message, ...entry.args),
				entry.severity === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning
			)
			diagnostic.source = 'ps12exe'
			if (entry.code) {
				diagnostic.code = entry.code
				diagnostic.data = { replacement: entry.replacement }
			}
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
 * 在刚打开的块下方追加匹配的 `#_endif`，并把光标移到两者中间的空行上（缩进一层），因此可以直接键入块函数体。
 *
 * @param {vscode.TextEditor} editor - 目标编辑器
 * @param {number} line 换行后光标移动到的行
 * @param {string} indent `#_if` 行的缩进
 * @param {string} indentUnit 编辑器的一个缩进单位
 */
async function insertEndif (editor, line, indent, indentUnit) {
	const {document} = editor
	if (line >= document.lineCount) return
	const target = document.lineAt(line)
	if (/^\s*#_endif\b/.test(target.text)) return

	const eol = document.eol === vscode.EndOfLine.CRLF ? '\r\n' : '\n'
	// 只有空行才补上块内缩进；光标落在该行末尾，因此可以直接键入块函数体。
	const body = target.text.trim() === '' ? indent + indentUnit : target.text
	const applied = await editor.edit((builder) => {
		builder.replace(new vscode.Range(line, 0, line, target.text.length), `${body}${eol}${indent}#_endif`)
	}, { undoStopBefore: false, undoStopAfter: false })
	if (!applied) return

	const position = new vscode.Position(line, body.length)
	editor.selection = new vscode.Selection(position, position)
}

/**
 * 用户一开始输入块函数体，就用 `#_endif` 闭合 `#_if …` 行。可通过 `ps12exe.autoCloseIf` 禁用。
 * 若换行后（未补 `#_endif` 时）文档中的预处理块早已全部闭合，则说明该 `#_if` 已有对应的 `#_endif`，跳过补全以免产生重复的 `#_endif`。
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
			if (isBalanced(event.document.getText())) continue

			const { insertSpaces, tabSize } = editorFormattingOptions(event.document)
			const indentUnit = insertSpaces ? ' '.repeat(tabSize || 4) : '\t'
			void insertEndif(editor, breakLine + close.offset, close.indent, indentUnit)
			return
		}
	}))
}

// 输入法未切到半角时 `_` 会被打成全角/中文标点（`——`、`＿`、`–` …），它们在视觉上像 `#_`。
const MISDIRECTIVE_CHAR_RE = /[—–―＿－‐]/
const MISDIRECTIVE_RE = /^([\t ]*)#[—–―＿－‐]+$/

/**
 * 键入 `#_` 时主动唤起指令补全列表，并把全角/中文标点误打的 `#——`、`#＿` 纠正为 `#_`。
 *
 * `_` 是单词字符，VS Code 把单词字符的输入交给 quick suggestions，而 quick suggestions 默认在注释中关闭；`#_` 恰好
 * 位于注释行上，因此即使把 `_` 注册为触发字符也不会弹出菜单（触发字符路径对单词字符会让位于 quick suggestions）。
 * 这里在检测到刚输入的 `_` 落在 `#_` 指令名中时显式调用 `editor.action.triggerSuggest`，只在真正输入 `#_` 时弹出，
 * 不会干扰普通注释。纠正标点后产生的新变更会以 `_` 再次进入本监听，从而照常弹出补全。
 *
 * @param {vscode.ExtensionContext} context - 扩展上下文，用于注册文档变更监听
 */
function registerDirectiveSuggest (context) {
	context.subscriptions.push(vscode.workspace.onDidChangeTextDocument((event) => {
		if (event.document.languageId !== 'powershell' || event.contentChanges.length === 0) return
		const editor = vscode.window.activeTextEditor
		if (!editor || editor.document !== event.document) return

		for (const change of event.contentChanges) {
			if (change.text === '_') {
				const position = change.range.start.translate(0, change.text.length)
				if (position.line >= event.document.lineCount) return
				const before = event.document.lineAt(position.line).text.slice(0, position.character)
				if (!directivePrefixAt(before)) continue
				if (computeSkipMask(event.document.getText().split(/\r\n|\n|\r/))[position.line]) return
				void vscode.commands.executeCommand('editor.action.triggerSuggest')
				return
			}

			if (!MISDIRECTIVE_CHAR_RE.test(change.text)) continue
			const lineNumber = change.range.start.line
			const lineText = event.document.lineAt(lineNumber).text
			const match = MISDIRECTIVE_RE.exec(lineText)
			if (!match) continue
			const start = match[1].length + 1
			void editor.edit((builder) => builder.replace(new vscode.Range(lineNumber, start, lineNumber, lineText.length), '_'))
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

const MAX_HOVER_TAGS = 12

/**
 * 构造一个指向 `url` 的 markdown 链接，链接文字中的方括号会被移除（tag 名不受 markdown 影响）。
 *
 * @param {string} label - 链接文字
 * @param {string} url - 链接目标
 * @returns {string} markdown 链接
 */
function markdownLink (label, url) {
	return `[${String(label).replace(/[[\]]/g, '')}](<${url}>)`
}

/**
 * 为 `#_require` 中的模块名构造悬浮提示：从 PowerShell Gallery 读取图标、简介与 tags，并给出仓库与图库页面链接。
 * 图标浮动在左侧、详情在右侧并排显示；简介按 markdown 渲染且保留换行。
 * 查询失败（离线、图库不可用）时回退到通用的 `#_require` 说明。
 *
 * @param {number} line - 悬浮提示所在行号
 * @param {{ name: string, start: number, end: number }} moduleToken - 识别到的模块名及其列范围
 * @param {string | undefined} locale - 当前区域标识，未知时为 undefined
 * @returns {Promise<vscode.Hover>} 构造好的悬浮提示
 */
async function createRequireHover (line, moduleToken, locale) {
	let info
	try {
		info = await getPackageInfo(moduleToken.name)
	}
	catch {
		return createDirectiveHover(line, { section: 'require', start: moduleToken.start, end: moduleToken.end }, locale)
	}

	const contents = new vscode.MarkdownString()
	// 图标用原始 HTML 而不是 markdown 图片，这样才能靠 `align="left"` 浮动到左侧、让图标与右侧的详情并排；markdown 图片做不到浮动。
	contents.supportHtml = true
	if (info) {
		const icon = info.iconUrl ? `<img src="${escapeHtmlAttribute(info.iconUrl)}" width="64" height="64" align="left"> ` : ''
		contents.appendMarkdown(`${icon}**${info.id}**${info.version ? ` \`${info.version}\`` : ''}`)
		// 简介按 markdown 渲染（代码段、列表、链接都能显示），并把换行转成硬换行。
		if (info.description) contents.appendMarkdown(`\n\n${preserveLineBreaks(info.description)}`)
		if (info.tags.length) {
			const tags = info.tags.slice(0, MAX_HOVER_TAGS).map((tag) => markdownLink(tag, tagSearchUrl(tag))).join(' ')
			contents.appendMarkdown(`\n\n${t(HOVER_MESSAGES.requireTags)}: ${tags}`)
		}
		const links = []
		if (info.projectUrl) links.push(markdownLink(t(HOVER_MESSAGES.requireRepository), info.projectUrl))
		links.push(markdownLink(t(HOVER_MESSAGES.requireGallery), info.galleryUrl))
		contents.appendMarkdown(`\n\n${links.join(' · ')}`)
	}
	else 
		contents.appendMarkdown(t(HOVER_MESSAGES.requireNotFound, moduleToken.name))

	contents.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${documentationUrl(locale, 'require')})`)
	return new vscode.Hover(contents, new vscode.Range(line, moduleToken.start, line, moduleToken.end))
}

/**
 * 为 `#_pragma Resources.Icon` 引用的图标路径构造悬浮提示：内联预览图标内容（exe/dll 等 PE 资源会按其索引抽取），
 * 并链接到 README 的 pragma 小节。图标无法读取或转换时返回 null，让悬浮回退到不显示内容。
 *
 * @param {number} line - 悬浮提示所在行号
 * @param {{ file: string, index: number | null, start: number, end: number }} icon - 识别到的图标引用
 * @param {string | undefined} locale - 当前区域标识，未知时为 undefined
 * @returns {Promise<vscode.Hover | null>} 构造好的悬浮提示，无法预览时为 null
 */
async function createIconHover (line, icon, locale) {
	const preview = await getIconPreview(icon)
	if (!preview) return null

	const contents = new vscode.MarkdownString()
	// 图标用原始 HTML，这样才能控制预览尺寸；data URI 只含 base64 字母表，转义后可直接放进属性。
	contents.supportHtml = true
	contents.appendMarkdown(`<img src="${escapeHtmlAttribute(preview)}" width="96" height="96" alt="">`)
	contents.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${documentationUrl(locale, 'pragma')})`)
	return new vscode.Hover(contents, new vscode.Range(line, icon.start, line, icon.end))
}

const hoverProvider = {
	/**
	 * 在 preprocessor 指令、`#_if` 条件关键字（`PSEXE`/`PSScript`）、`#_pragma` 变量名、`#_pragma Resources.Icon`
	 * 的图标路径，以及 `#_require` 的模块名上显示提示：指令与条件链接到当前区域 README 中对应的小节，图标路径
	 * 内联预览图标内容，模块名则展示 PowerShell Gallery 上的图标、简介与 tags，并给出仓库与图库页面链接。
	 * here-string 函数体和块注释内的 `#_…` 不是指令，因此不提示。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Position} position - 光标位置
	 * @returns {Promise<vscode.Hover | null>} 悬浮提示，未命中指令时为空
	 */
	async provideHover (document, position) {
		if (document.languageId !== 'powershell') return null
		const line = document.lineAt(position.line).text
		const locale = toPs12exeLocale(vscode.env.language)

		// 图标路径引用的文件相对于脚本目录；虚拟的 exe 源码文档没有有意义的 $PSScriptRoot，因此只在本地 .ps1 上解析。
		const icon = document.uri.scheme === 'file' ? resolveIconAt(line, position.character, path.dirname(document.uri.fsPath)) : null
		const pragma = icon ? null : pragmaNameAt(line, position.character)
		const required = icon || pragma ? null : requireModulesAt(line, position.character)
		const token = icon || pragma || required ? null : conditionAt(line, position.character) || directiveAt(line, position.character)
		if (!icon && !pragma && !required && !token) return null
		if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return null

		if (icon) return createIconHover(position.line, icon, locale)
		if (pragma) return createPragmaHover(position.line, pragma, locale)
		if (required) return createRequireHover(position.line, required, locale)
		return createDirectiveHover(position.line, token, locale)
	}
}

/** `followUp` -> 补全后要执行的 VS Code 命令。 */
const FOLLOW_UP_COMMANDS = Object.freeze({
	suggest: 'editor.action.triggerSuggest',
	newline: 'editor.action.insertLineAfter'
})

/**
 * 给补全项挂上 `candidate.followUp` 对应的命令。补全自带的尾随空格不会触发注册的触发字符，因此需要显式接续：
 * `suggest` 重新弹出补全（`#_if` 后接条件、`#_pragma ` 后接参数名），`newline` 换行让 `#_if` 自动补出 `#_endif`。
 *
 * @param {vscode.CompletionItem} item - 补全项
 * @param {string | undefined} followUp - `lib/directives.mjs` 声明的接续动作
 */
function applyFollowUp (item, followUp) {
	const command = FOLLOW_UP_COMMANDS[followUp]
	if (command) item.command = { command, title: '' }
}

const completionProvider = {
	/**
	 * 输入 `#_` 后补全预处理器指令（每项带本地化说明与 README 链接）。在 `#_pragma ` 后补全参数名；已输入父级点号（`App.`）时只列出该父级的直接子键，候选及其说明同样来自当前安装的模块。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Position} position - 光标位置
	 * @returns {Promise<vscode.CompletionItem[] | undefined>} 补全候选列表，无候选时为 undefined
	 */
	async provideCompletionItems (document, position) {
		if (document.languageId !== 'powershell') return undefined
		const line = document.lineAt(position.line).text
		const before = line.slice(0, position.character)
		const locale = toPs12exeLocale(vscode.env.language)

		const directive = directivePrefixAt(before)
		if (directive) {
			const lines = document.getText().split(/\r\n|\n|\r/)
			if (computeSkipMask(lines)[position.line]) return undefined
			// 抹掉当前正在输入的指令名再分析块结构，这样半截或完整的 `#_if`/`#_else`/`#_endif` 不会被当成已有结构，
			// `#_else` / `#_endif` 只在插入后不会出现 stray 或 duplicate 时才进入候选。
			const probe = [...lines]
			probe[position.line] = line.slice(0, directive.start) + line.slice(position.character)
			const availability = directiveAvailability(analyze(probe.join('\n')).blocks, position.line)
			const range = new vscode.Range(position.line, directive.start, position.line, position.character)
			return buildDirectiveCandidates(directive.prefix, availability).map((candidate, index) => {
				const item = new vscode.CompletionItem(candidate.label, vscode.CompletionItemKind.Keyword)
				item.insertText = candidate.insertText
				item.range = range
				// 保留 `DIRECTIVE_COMPLETIONS` 的分组顺序（if/else/endif、include* …），而不是按字母重排。
				item.sortText = String(index).padStart(2, '0')
				item.detail = t('ps12exe preprocessor directive')
				const docs = new vscode.MarkdownString(t(HOVER_MESSAGES[candidate.section]))
				docs.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${documentationUrl(locale, candidate.section)})`)
				item.documentation = docs
				applyFollowUp(item, candidate.followUp)
				return item
			})
		}

		const condition = ifConditionPrefixAt(before)
		if (condition) {
			if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return undefined
			const range = new vscode.Range(position.line, condition.start, position.line, position.character)
			return buildConditionCandidates(condition.prefix).map((candidate) => {
				const item = new vscode.CompletionItem(candidate.label, vscode.CompletionItemKind.Constant)
				item.insertText = candidate.insertText
				item.range = range
				item.detail = t('ps12exe preprocessor condition')
				const docs = new vscode.MarkdownString(t(HOVER_MESSAGES[candidate.section]))
				docs.appendMarkdown(`\n\n[${t(HOVER_MESSAGES.more)}](${documentationUrl(locale, candidate.section)})`)
				item.documentation = docs
				applyFollowUp(item, candidate.followUp)
				return item
			})
		}

		const match = /^([\t ]*#_pragma[\t ]+)([A-Z_a-z][\w.]*)?$/.exec(before)
		if (!match) return undefined
		if (computeSkipMask(document.getText().split(/\r\n|\n|\r/))[position.line]) return undefined

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
	 * 提供快速修复操作：
	 *
	 * - 对 PS2EXE 调用，整段改写为等价的 ps12exe 调用。
	 * - 对 `#_require PS2EXE`，把模块名改写成 `ps12exe`。
	 * - 对可识别的模块安装行，改写成 `#_require <模块>`。
	 * - 对任意 ps12exe 命令诊断，在告警行上方插入 `# use_ps12exe:ignore` 以忽略它。
	 * - 始终提供格式化 preprocessor 块的 source fix-all 操作。
	 *
	 * 同一行上的多个诊断可能给出同一个修复（例如 `#_require` 生成样板的 `gmo` 与 `Install-Module`），因此按编辑效果去重。
	 *
	 * @param {vscode.TextDocument} document - 当前文本文档
	 * @param {vscode.Range} _range - 请求代码操作的选区
	 * @param {vscode.CodeActionContext} context - 该位置上的诊断
	 * @returns {vscode.CodeAction[]} 代码操作列表
	 */
	provideCodeActions (document, _range, context) {
		if (document.languageId !== 'powershell') return []
		const actions = []
		const seen = new Set()
		/**
		 * 按去重键加入操作。
		 *
		 * @param {vscode.CodeAction} action - 待加入的操作
		 * @param {string} key - 去重键
		 */
		const add = (action, key) => {
			if (seen.has(key)) return
			seen.add(key)
			actions.push(action)
		}

		for (const diagnostic of context?.diagnostics || []) {
			if (diagnostic.source !== 'ps12exe') continue
			const replacement = diagnostic.data?.replacement
			const line = diagnostic.range.start.line

			if (diagnostic.code === PS2EXE_DIAGNOSTIC && replacement) {
				const action = new vscode.CodeAction(t('Use ps12exe'), vscode.CodeActionKind.QuickFix)
				action.edit = new vscode.WorkspaceEdit()
				action.edit.replace(document.uri, diagnostic.range, replacement)
				action.diagnostics = [diagnostic]
				add(action, `ps12exe:${line}:${replacement}`)
			}

			if (diagnostic.code === MODULE_DIAGNOSTIC && replacement) {
				const action = new vscode.CodeAction(t('Use #_require'), vscode.CodeActionKind.QuickFix)
				action.edit = new vscode.WorkspaceEdit()
				action.edit.replace(document.uri, diagnostic.range, replacement)
				action.diagnostics = [diagnostic]
				add(action, `require:${line}:${replacement}`)
			}

			if (diagnostic.code === PS2EXE_REQUIRE_DIAGNOSTIC && replacement) {
				const action = new vscode.CodeAction(t('Use ps12exe'), vscode.CodeActionKind.QuickFix)
				action.edit = new vscode.WorkspaceEdit()
				action.edit.replace(document.uri, diagnostic.range, replacement)
				action.diagnostics = [diagnostic]
				add(action, `require-ps2exe:${line}:${replacement}`)
			}

			if (diagnostic.code === PS2EXE_DIAGNOSTIC || diagnostic.code === PS2EXE_REQUIRE_DIAGNOSTIC || diagnostic.code === MODULE_DIAGNOSTIC) {
				const indent = (document.lineAt(line).text.match(/^[\t ]*/) || [''])[0]
				const eol = document.eol === vscode.EndOfLine.CRLF ? '\r\n' : '\n'
				const action = new vscode.CodeAction(t('Ignore this warning'), vscode.CodeActionKind.QuickFix)
				action.edit = new vscode.WorkspaceEdit()
				action.edit.insert(document.uri, new vscode.Position(line, 0), `${indent}${IGNORE_DIRECTIVE}${eol}`)
				action.diagnostics = [diagnostic]
				add(action, `ignore:${line}`)
			}
		}

		const format = new vscode.CodeAction(t('Format ps12exe preprocessor blocks'), FIX_ALL_KIND)
		format.command = {
			command: 'ps12exe.formatDocument',
			title: format.title,
			arguments: [document.uri.toString()]
		}
		actions.push(format)
		return actions
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
		vscode.languages.registerCodeActionsProvider(POWER_SHELL_SELECTOR, codeActionProvider, { providedCodeActionKinds: [FIX_ALL_KIND, vscode.CodeActionKind.QuickFix] }),
		vscode.workspace.onDidOpenTextDocument(updateDiagnostics),
		vscode.workspace.onDidChangeTextDocument((event) => scheduleDiagnostics(event.document)),
		vscode.workspace.onDidCloseTextDocument((document) => diagnosticCollection.delete(document.uri))
	)

	registerIfAutoClose(context)
	registerDirectiveSuggest(context)
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
