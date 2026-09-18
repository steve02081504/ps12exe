import { createHash } from 'node:crypto'
import fs from 'node:fs'
import fsp from 'node:fs/promises'
import path from 'node:path'
import * as vscode from 'vscode'
import { extractScriptToFile, compileToExe } from './powershell.mjs'

// 用于把 ps12exe 构建的可执行文件中内嵌的 PowerShell 源码暴露为可编辑文档的自定义编辑器 id 与虚拟文件系统 scheme。
export const EXE_SOURCE_VIEW_TYPE = 'ps12exe.exeSource'
export const EXE_SOURCE_SCHEME = 'ps12exe-exe'

// ps12exe 程序帧会在 .NET 元数据中留下这些类型名之一。只需对文件头部做一次廉价的字节扫描，就能跳过无关的可执行文件，而无需为它们启动 PowerShell。
const PS12EXE_MARKERS = ['PSRunnerNS', 'PS12ExeLauncher', 'PS12ExeCoreHost', 'TinySharp']
const MARKER_READ_BYTES = 4 * 1024 * 1024

function t (message, ...args) {
	return vscode.l10n.t(message, ...args)
}

function isExePath (filePath) {
	return path.extname(filePath).toLowerCase() === '.exe'
}

/**
 * 用 `source` 替换 `target`，规避 Windows 上运行中的可执行文件无法被覆盖的常见故障。运行中的可执行文件仍可重命名，因此先把原文件移到 `<target>.old`；该备份会被特意保留，以便用户恢复。
 *
 * @param {string} source
 * @param {string} target
 * @returns {Promise<string | undefined>} 创建了备份时返回备份路径
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
		// 把原文件放回去，这样即使覆盖失败也不会丢失可执行文件。
		if (hadTarget) await fsp.rename(backup, target).catch(() => {})
		throw error
	}

	return hadTarget ? backup : undefined
}

/**
 * 廉价地检查某个可执行文件是否像 ps12exe 构建产物。
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
			catch { /* 已关闭 */ }
		}
	}
}

/**
 * 可执行文件中内嵌 PowerShell 源码的可编辑内存视图。
 *
 * `readFile` 用 `exe21sp` 还原脚本；`writeFile`（普通的 Ctrl+S）会把编辑后的源码重新编译回同一个可执行文件。两个方向都在发布图标旁的缓存目录中经由 ps12exe 模块运行，因此 `#_pragma resourceParams.iconFile` 及其他 `$PSScriptRoot` 引用可以继续正常工作。
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
	 * 还原（并缓存）`exePath` 中内嵌的源码。
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
	 * 把编辑后的源码重新编译回可执行文件。构建先输出到临时路径，这样编译失败也绝不会删除或损坏原可执行文件。
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
		catch { /* 尽力而为 */ }
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
		return new vscode.Disposable(() => { /* 永不触发；该文件系统是静态的 */ })
	}
}

/**
 * 在普通、可编辑的文本编辑器中打开 `exeUri` 中内嵌的源码。
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

/** 在 `exeUri` 被替换后关闭其自定义编辑器标签页。 */
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
 * 把 ps12exe `.exe` 变成可编辑源码视图的自定义编辑器。它自身不渲染 webview：而是在虚拟源码文档上打开普通文本编辑器，然后关闭自己的标签页。无关的可执行文件回退到内置编辑器。
 *
 * 作为 `*.exe` 的默认编辑器贡献；可通过 `ps12exe.openExeSource` 禁用。
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
			catch { /* 内置编辑器不可用；保留空的自定义标签页 */ }
		}
		await closeCustomEditorTab(exeUri)
	}
}

/**
 * 注册支撑「编辑内嵌源码」功能的虚拟文件系统、自定义编辑器和命令。
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
