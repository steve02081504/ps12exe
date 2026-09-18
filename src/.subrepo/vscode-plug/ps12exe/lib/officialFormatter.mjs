import * as vscode from 'vscode'

const POWER_SHELL_EXTENSION_ID = 'ms-vscode.powershell'
const FORMAT_DOCUMENT_COMMAND = 'vscode.executeFormatDocumentProvider'

/** @returns {boolean} whether the official PowerShell extension is installed. */
function isPowerShellExtensionInstalled () {
	return !!vscode.extensions.getExtension(POWER_SHELL_EXTENSION_ID)
}

/**
 * Applies `TextEdit[]` to `text` without touching the document, mirroring what
 * VS Code would do. Edits are applied from the end so offsets stay valid.
 *
 * @param {import('vscode').TextDocument} document
 * @param {string} text
 * @param {import('vscode').TextEdit[]} edits
 * @returns {string}
 */
function applyTextEdits (document, text, edits) {
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
 * Runs the official PowerShell formatter and returns its edits.
 *
 * `vscode.executeFormatDocumentProvider` always uses the configured default
 * formatter. Because this extension registers its own formatter (and would
 * recurse), the default is temporarily pointed at the PowerShell extension and
 * restored afterwards.
 *
 * @param {import('vscode').TextDocument} document
 * @param {import('vscode').FormattingOptions} options
 * @returns {Promise<import('vscode').TextEdit[]>}
 */
async function getOfficialEdits (document, options) {
	const config = vscode.workspace.getConfiguration('editor', document)
	const hasWorkspace = !!(vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length)
	const target = hasWorkspace ? vscode.ConfigurationTarget.Workspace : vscode.ConfigurationTarget.Global
	const inspected = config.inspect('defaultFormatter')
	const previous = inspected
		? (inspected.workspaceFolderLanguageValue ?? inspected.workspaceLanguageValue ?? inspected.globalLanguageValue ?? null)
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

export { POWER_SHELL_EXTENSION_ID, isPowerShellExtensionInstalled, getOfficialEdits, applyTextEdits }
