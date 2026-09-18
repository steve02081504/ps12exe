import { createHash } from 'node:crypto'
import fs from 'node:fs'
import fsp from 'node:fs/promises'
import path from 'node:path'
import * as vscode from 'vscode'
import { extractScriptToFile, compileToExe } from './powershell.mjs'

// Custom editor id and virtual file system scheme used to expose the PowerShell
// source embedded in a ps12exe-built executable as an editable document.
export const EXE_SOURCE_VIEW_TYPE = 'ps12exe.exeSource'
export const EXE_SOURCE_SCHEME = 'ps12exe-exe'

// ps12exe program frames leave one of these type names in the .NET metadata.
// A cheap byte scan of the file head is enough to skip unrelated executables
// without spawning PowerShell for them.
const PS12EXE_MARKERS = ['PSRunnerNS', 'PS12ExeLauncher', 'PS12ExeCoreHost', 'TinySharp']
const MARKER_READ_BYTES = 4 * 1024 * 1024

function t (message, ...args) {
	return vscode.l10n.t(message, ...args)
}

function isExePath (filePath) {
	return path.extname(filePath).toLowerCase() === '.exe'
}

/**
 * Replaces `target` with `source`, working around the common Windows failure
 * where a running executable cannot be overwritten. A running executable can
 * still be renamed, so the previous file is moved aside to `<target>.old`
 * first; that backup is deliberately kept so the user can recover it.
 *
 * @param {string} source
 * @param {string} target
 * @returns {Promise<string | undefined>} the backup path when one was created
 */
export async function replaceFile (source, target) {
	const backup = `${target}.old`
	await fsp.rm(backup, { force: true }).catch(() => {})

	let hadTarget = true
	try {
		await fsp.rename(target, backup)
	}
	catch (error) {
		if (error.code === 'ENOENT') hadTarget = false
		else throw error
	}

	try {
		await fsp.copyFile(source, target)
	}
	catch (error) {
		// Put the original back so a failed overwrite never loses the executable.
		if (hadTarget) await fsp.rename(backup, target).catch(() => {})
		throw error
	}

	return hadTarget ? backup : undefined
}

/**
 * Cheaply checks whether an executable looks like a ps12exe build.
 *
 * @param {string} exePath
 * @returns {boolean}
 */
export function looksLikePs12Exe (exePath) {
	if (!isExePath(exePath)) return false
	let handle
	try {
		handle = fs.openSync(exePath, 'r')
		const buffer = Buffer.alloc(MARKER_READ_BYTES)
		const read = fs.readSync(handle, buffer, 0, buffer.length, 0)
		const text = buffer.subarray(0, read).toString('latin1')
		return PS12EXE_MARKERS.some((marker) => text.includes(marker))
	}
	catch {
		return false
	}
	finally {
		if (handle !== undefined) {
			try { fs.closeSync(handle) }
			catch { /* already closed */ }
		}
	}
}

/**
 * Editable, in-memory view of the PowerShell source embedded in an executable.
 *
 * `readFile` recovers the script with `exe21sp`; `writeFile` (a normal Ctrl+S)
 * recompiles the edited source back into the same executable. Both directions
 * run through the ps12exe module in a cache directory next to the released
 * icon, so `#_pragma icon` and other `$PSScriptRoot` references keep working.
 */
export class ExeSourceFileSystemProvider {
	/**
	 * @param {object} options
	 * @param {() => Promise<{ command: string } | undefined>} options.requireHost
	 * @param {vscode.OutputChannel} options.channel
	 * @param {vscode.Uri} options.storageUri
	 */
	constructor ({ requireHost, channel, storageUri }) {
		this.requireHost = requireHost
		this.channel = channel
		this.storageRoot = path.join(storageUri.fsPath, 'exe-source')
		this.changeEmitter = new vscode.EventEmitter()
		this.onDidChangeFile = this.changeEmitter.event
		/** @type {Map<string, { script: string, mtime: number, cacheFile: string }>} */
		this.cache = new Map()
		/** @type {Map<string, Promise<{ script: string, mtime: number, cacheFile: string }>>} */
		this.pending = new Map()
	}

	/** @param {string} exePath */
	cacheDirFor (exePath) {
		const hash = createHash('sha1').update(exePath.toLowerCase()).digest('hex').slice(0, 16)
		return path.join(this.storageRoot, hash)
	}

	/**
	 * Recovers (and caches) the source embedded in `exePath`.
	 *
	 * @param {string} exePath
	 * @param {boolean} [force]
	 * @returns {Promise<{ script: string, mtime: number, cacheFile: string }>}
	 */
	async load (exePath, force = false) {
		const exeStat = await fsp.stat(exePath).catch(() => undefined)
		if (!exeStat) throw vscode.FileSystemError.FileNotFound(vscode.Uri.file(exePath))
		if (!force) {
			const cached = this.cache.get(exePath)
			if (cached && cached.mtime === exeStat.mtimeMs) return cached
			const inflight = this.pending.get(exePath)
			if (inflight) return inflight
		}

		const task = this.#extract(exePath, exeStat.mtimeMs)
			.finally(() => this.pending.delete(exePath))
		this.pending.set(exePath, task)
		return task
	}

	async #extract (exePath, mtime) {
		const host = await this.requireHost()
		if (!host) throw vscode.FileSystemError.Unavailable(t('No PowerShell host (pwsh or powershell) was found.'))

		const cacheDir = this.cacheDirFor(exePath)
		await fsp.mkdir(cacheDir, { recursive: true })
		const base = path.basename(exePath, path.extname(exePath))
		const cacheFile = path.join(cacheDir, `${base}.ps1`)

		const result = await vscode.window.withProgress({
			location: vscode.ProgressLocation.Notification,
			title: t('Reading embedded script from {0}...', path.basename(exePath)),
			cancellable: true
		}, (progress, token) => extractScriptToFile({ host, file: exePath, outputFile: cacheFile, channel: this.channel, token }))

		if (result.cancelled) throw vscode.FileSystemError.Unavailable('cancelled')
		if (result.error) throw vscode.FileSystemError.Unavailable(result.error.message)
		if (result.code !== 0 || !fs.existsSync(cacheFile)) {
			throw vscode.FileSystemError.FileNotFound(vscode.Uri.file(exePath))
		}

		const script = await fsp.readFile(cacheFile, 'utf8')
		const entry = { script, mtime, cacheFile }
		this.cache.set(exePath, entry)
		return entry
	}

	/**
	 * Recompiles edited source back into the executable. The build goes to a
	 * temporary path first so a failed compilation can never delete or corrupt
	 * the original executable.
	 *
	 * @param {vscode.Uri} uri
	 * @param {Uint8Array} content
	 */
	async writeFile (uri, content) {
		const entry = await this.load(uri.fsPath)
		const host = await this.requireHost()
		if (!host) throw vscode.FileSystemError.Unavailable(t('No PowerShell host (pwsh or powershell) was found.'))

		const text = Buffer.from(content).toString('utf8')
		await fsp.writeFile(entry.cacheFile, text, 'utf8')

		const cacheDir = path.dirname(entry.cacheFile)
		const tempOutput = path.join(cacheDir, `${path.basename(uri.fsPath, path.extname(uri.fsPath))}.exe`)
		const result = await vscode.window.withProgress({
			location: vscode.ProgressLocation.Notification,
			title: t('Recompiling {0}...', path.basename(uri.fsPath)),
			cancellable: true
		}, (progress, token) => compileToExe({ host, input: entry.cacheFile, output: tempOutput, channel: this.channel, token }))

		if (result.cancelled) throw vscode.FileSystemError.Unavailable('cancelled')
		if (result.error) throw vscode.FileSystemError.Unavailable(result.error.message)
		if (result.code !== 0 || !fs.existsSync(tempOutput)) {
			this.channel.show(true)
			throw vscode.FileSystemError.Unavailable(t('Compilation failed (exit code {0}).', String(result.code)))
		}

		const backup = await replaceFile(tempOutput, uri.fsPath)
		try { await fsp.unlink(tempOutput) }
		catch { /* best effort */ }
		if (backup) this.channel.appendLine(t('Previous executable kept as {0}.', backup))

		const exeStat = await fsp.stat(uri.fsPath)
		entry.script = text
		entry.mtime = exeStat.mtimeMs
		this.cache.set(uri.fsPath, entry)
		this.channel.appendLine(t('Recompiled {0}.', uri.fsPath))
	}

	/** @param {vscode.Uri} uri */
	async stat (uri) {
		const entry = await this.load(uri.fsPath)
		return {
			type: vscode.FileType.File,
			ctime: entry.mtime,
			mtime: entry.mtime,
			size: Buffer.byteLength(entry.script, 'utf8')
		}
	}

	/** @param {vscode.Uri} uri */
	async readFile (uri) {
		const entry = await this.load(uri.fsPath)
		return Buffer.from(entry.script, 'utf8')
	}

	readDirectory () {
		return []
	}

	createDirectory () {
		throw vscode.FileSystemError.NoPermissions('read-only')
	}

	delete () {
		throw vscode.FileSystemError.NoPermissions('read-only')
	}

	rename () {
		throw vscode.FileSystemError.NoPermissions('read-only')
	}

	watch () {
		return new vscode.Disposable(() => { /* never fires; the file system is static */ })
	}
}

/**
 * Opens the embedded source of `exeUri` in a normal, editable text editor.
 *
 * @param {vscode.Uri} exeUri
 * @param {ExeSourceFileSystemProvider} provider
 */
async function openExeSource (exeUri, provider) {
	await provider.load(exeUri.fsPath)
	const target = exeUri.with({ scheme: EXE_SOURCE_SCHEME })
	const document = await vscode.workspace.openTextDocument(target)
	await vscode.languages.setTextDocumentLanguage(document, 'powershell')
	await vscode.window.showTextDocument(document, { preview: false })
}

/** Closes the custom editor tab for `exeUri` once it has been replaced. */
async function closeCustomEditorTab (exeUri) {
	for (const group of vscode.window.tabGroups.all) {
		for (const tab of group.tabs) {
			const input = tab.input
			if (input instanceof vscode.TabInputCustom &&
				input.viewType === EXE_SOURCE_VIEW_TYPE &&
				input.uri.toString() === exeUri.toString()) {
				await vscode.window.tabGroups.close(tab)
			}
		}
	}
}

/**
 * Custom editor that turns a ps12exe `.exe` into an editable source view.
 * It does not render a webview itself: it opens the regular text editor on the
 * virtual source document and closes its own tab. Unrelated executables fall
 * back to the built-in editor.
 *
 * Contributed as the default editor for `*.exe`; disable with
 * `ps12exe.openExeSource`.
 */
export class ExeSourceCustomEditorProvider {
	/** @param {ExeSourceFileSystemProvider} provider */
	constructor (provider) {
		this.provider = provider
	}

	/**
	 * @param {vscode.TextDocument} document
	 * @param {vscode.WebviewPanel} panel
	 */
	async resolveCustomTextEditor (document, panel) {
		panel.webview.html = '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body></body></html>'
		const exeUri = document.uri
		const enabled = vscode.workspace.getConfiguration('ps12exe').get('openExeSource', true)

		let opened = false
		if (enabled && looksLikePs12Exe(exeUri.fsPath)) {
			try {
				await openExeSource(exeUri, this.provider)
				opened = true
			}
			catch (error) {
				this.provider.channel.appendLine(`ps12exe: could not open exe source for ${exeUri.fsPath}: ${error && error.message ? error.message : error}`)
			}
		}

		if (!opened) {
			try { await vscode.commands.executeCommand('vscode.openWith', exeUri, 'default') }
			catch { /* built-in editor unavailable; leave the empty custom tab */ }
		}
		await closeCustomEditorTab(exeUri)
	}
}

/**
 * Registers the virtual file system, custom editor and commands backing the
 * "edit embedded source" feature.
 *
 * @param {vscode.ExtensionContext} context
 * @param {object} options
 * @param {() => Promise<{ command: string } | undefined>} options.requireHost
 * @param {vscode.OutputChannel} options.channel
 * @returns {ExeSourceFileSystemProvider}
 */
export function registerExeSource (context, { requireHost, channel }) {
	const storageUri = context.storageUri || context.globalStorageUri
	const provider = new ExeSourceFileSystemProvider({ requireHost, channel, storageUri })

	context.subscriptions.push(
		vscode.workspace.registerFileSystemProvider(EXE_SOURCE_SCHEME, provider, { isCaseSensitive: true, isReadonly: false }),
		vscode.window.registerCustomEditorProvider(EXE_SOURCE_VIEW_TYPE, new ExeSourceCustomEditorProvider(provider), {
			webviewOptions: { retainContextWhenHidden: false }
		}),
		vscode.commands.registerCommand('ps12exe.editExeSource', async (resource) => {
			const uri = resource instanceof vscode.Uri ? resource : vscode.window.activeTextEditor?.document.uri
			if (!uri || uri.scheme !== 'file' || !isExePath(uri.fsPath)) {
				vscode.window.showWarningMessage(t('Please select an executable (.exe) file.'))
				return
			}
			if (!looksLikePs12Exe(uri.fsPath)) {
				vscode.window.showWarningMessage(t('Not a ps12exe executable: {0}', path.basename(uri.fsPath)))
				return
			}
			try {
				await openExeSource(uri, provider)
			}
			catch (error) {
				channel.show(true)
				vscode.window.showErrorMessage(t('Failed to open exe source: {0}', error && error.message ? error.message : String(error)))
			}
		})
	)

	return provider
}
