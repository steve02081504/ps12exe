import * as vscode from 'vscode'

/** 官方 PowerShell 扩展的 id。 */
export const POWER_SHELL_EXTENSION_ID = 'ms-vscode.powershell'
const FORMAT_DOCUMENT_COMMAND = 'vscode.executeFormatDocumentProvider'

/**
 * 检查官方 PowerShell 扩展是否已安装。
 *
 * @returns {boolean} 已安装时为 true
 */
export function isPowerShellExtensionInstalled () {
	return !!vscode.extensions.getExtension(POWER_SHELL_EXTENSION_ID)
}

/**
 * 不触碰文档，把 `TextEdit[]` 应用到 `text` 上，效果与 VS Code 的应用一致。编辑从末尾开始应用以保证偏移有效。
 *
 * @param {import('vscode').TextDocument} document - 目标文档
 * @param {string} text - 待处理的文本
 * @param {import('vscode').TextEdit[]} edits - 待应用的编辑
 * @returns {string} 应用编辑后的文本
 */
export function applyTextEdits (document, text, edits) {
	const ordered = [...edits].sort((a, b) => document.offsetAt(b.range.start) - document.offsetAt(a.range.start))
	let result = text
	for (const edit of ordered) {
		const start = document.offsetAt(edit.range.start)
		const end = document.offsetAt(edit.range.end)
		result = result.slice(0, start) + edit.newText + result.slice(end)
	}
	return result
}

/**
 * 运行官方 PowerShell formatter 并返回它的编辑。
 *
 * `vscode.executeFormatDocumentProvider` 总是使用配置的默认 formatter。本扩展注册了自己的 formatter（会递归），因此临时把默认指向 PowerShell 扩展，事后恢复。
 *
 * @param {import('vscode').TextDocument} document - 待格式化的文档
 * @param {import('vscode').FormattingOptions} options - 格式化选项
 * @returns {Promise<import('vscode').TextEdit[]>} 官方 formatter 的编辑列表
 */
export async function getOfficialEdits (document, options) {
	const config = vscode.workspace.getConfiguration('editor', document)
	const hasWorkspace = !!(vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length)
	const target = hasWorkspace ? vscode.ConfigurationTarget.Workspace : vscode.ConfigurationTarget.Global
	const inspected = config.inspect('defaultFormatter')
	const previous = inspected
		? inspected.workspaceFolderLanguageValue ?? inspected.workspaceLanguageValue ?? inspected.globalLanguageValue ?? null
		: null

	await config.update('defaultFormatter', POWER_SHELL_EXTENSION_ID, target, true)
	try {
		const edits = await vscode.commands.executeCommand(FORMAT_DOCUMENT_COMMAND, document.uri, options)
		return Array.isArray(edits) ? edits : []
	}
	finally {
		await config.update('defaultFormatter', previous === null ? undefined : previous, target, true)
	}
}
