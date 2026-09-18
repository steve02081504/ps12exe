import { execFile, spawn } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { where_command } from '@steve02081504/exec'

const MODULE_PROBE = '$m = Get-Module -ListAvailable -Name ps12exe | Select-Object -First 1; if ($m) { $m.Version.ToString() }'

const HOST_NAMES = ['pwsh', 'powershell']

/** @type {{ command: string, moduleVersion: string | null } | null | undefined} */
let cachedHost

/**
 * PowerShell 的 `-EncodedCommand` 期望一个 Base64 编码的 UTF-16LE 字符串。使用它可以避开所有 shell/Windows 命令行引号陷阱，这一点很重要，因为脚本路径可能包含引号、空格和 unicode。
 *
 * @param {string} script
 * @returns {string}
 */
function encodeCommand (script) {
	return Buffer.from(script, 'utf16le').toString('base64')
}

/**
 * 把值引用为 PowerShell 单引号字符串字面量。
 *
 * @param {string} value
 * @returns {string}
 */
function psQuote (value) {
	return `'${String(value).replace(/'/g, "''")}'`
}

/**
 * 把候选 PowerShell 可执行文件解析为绝对路径（识别 PATH，在 Windows 上识别 PATHEXT），优先级高的在前。
 *
 * @returns {Promise<string[]>}
 */
async function hostCandidates () {
	const candidates = []
	for (const name of HOST_NAMES) {
		try {
			const resolved = await where_command(name)
			if (resolved) candidates.push(resolved)
		}
		catch {
			// 本机未找到。
		}
	}
	return candidates
}

/**
 * @param {string} script
 * @returns {string[]}
 */
function encodedArgs (script) {
	// `-OutputFormat Text` 让 PowerShell 的信息流不进入 stderr；否则被重定向的宿主会收到每次 Write-Host 调用的 CLIXML 副本。
	return ['-NoProfile', '-NonInteractive', '-OutputFormat', 'Text', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encodeCommand(script)]
}

/**
 * @param {string} command
 * @param {string[]} args
 * @returns {Promise<{ stdout: string, stderr: string }>}
 */
function execFileAsync (command, args) {
	return new Promise((resolve, reject) => {
		execFile(command, args, { encoding: 'utf8', windowsHide: true, maxBuffer: 8 * 1024 * 1024 }, (error, stdout, stderr) => {
			if (error) {
				error.stdout = stdout
				error.stderr = stderr
				reject(error)
				return
			}
			resolve({ stdout: String(stdout).trim(), stderr: String(stderr).trim() })
		})
	})
}

/**
 * @param {string} command
 * @returns {Promise<{ command: string, moduleVersion: string | null } | null>}
 */
async function probeHost (command) {
	try {
		const { stdout } = await execFileAsync(command, encodedArgs(MODULE_PROBE))
		return { command, moduleVersion: stdout || null }
	}
	catch (error) {
		// ENOENT 表示可执行文件本身未安装。
		if (error.code === 'ENOENT') return null
		// 宿主存在，但探测因其他原因失败；将模块视为不可用，以便调用方可以提议安装它。
		return { command, moduleVersion: null }
	}
}

/**
 * 查找能加载 ps12exe 模块的 PowerShell 宿主。由于探测会启动进程，结果会被缓存。
 *
 * @param {boolean} [refresh]
 * @returns {Promise<{ command: string, moduleVersion: string | null } | null>}
 */
async function resolvePowerShell (refresh = false) {
	if (cachedHost && !refresh) return cachedHost
	let fallback = null
	for (const command of await hostCandidates()) {
		const result = await probeHost(command)
		if (!result) continue
		if (!fallback) fallback = result
		if (result.moduleVersion) {
			// 只缓存成功的结果，这样之后安装模块能在下次运行时被识别到。
			cachedHost = result
			return cachedHost
		}
	}
	return fallback
}

/** @type {{ command: string } | null | undefined} */
let cachedPlainHost

/**
 * 解析任意可用的 PowerShell 宿主并缓存。与 {@link resolvePowerShell} 不同，它不关心 ps12exe 模块，因此可以廉价地反复调用（解析、格式化）。
 *
 * @returns {Promise<{ command: string } | null>}
 */
async function resolvePlainPowerShell () {
	if (cachedPlainHost !== undefined) return cachedPlainHost
	const candidates = await hostCandidates()
	cachedPlainHost = candidates.length ? { command: candidates[0] } : null
	return cachedPlainHost
}

/** @param {import('child_process').ChildProcess} child */
function killTree (child) {
	if (!child.pid) return
	if (process.platform === 'win32') {
		spawn('taskkill', ['/pid', String(child.pid), '/T', '/F'], { windowsHide: true })
		return
	}
	try {
		child.kill('SIGTERM')
	}
	catch {
		// 进程已不存在。
	}
}

// ps12exe 使用 ANSI 光标移动来重绘进度；它们会在输出通道中显示为乱码。
const clean = (text) => String(text).replace(/\u001b\[[0-9;]*[A-Za-z]/g, '')

/**
 * 在给定宿主中运行任意 PowerShell 脚本，把输出流式写入 `channel`。
 *
 * @param {{ command: string }} host
 * @param {string} script
 * @param {object} [options]
 * @param {import('vscode').OutputChannel} [options.channel]
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<{ code?: number | null, error?: Error, stdout: string, stderr: string, cancelled?: boolean }>}
 */
function runScript (host, script, options = {}) {
	const { channel, token } = options
	return new Promise((resolve) => {
		let child
		try {
			child = spawn(host.command, encodedArgs(script), { windowsHide: true })
		}
		catch (error) {
			resolve({ error, stdout: '', stderr: '' })
			return
		}

		let stdout = ''
		let stderr = ''
		let cancelled = false
		let settled = false

		/** @param {object} result */
		const finish = (result) => {
			if (settled) return
			settled = true
			resolve(result)
		}

		if (child.stdout) {
			child.stdout.setEncoding('utf8')
			child.stdout.on('data', (data) => {
				stdout += data
				if (channel) channel.append(clean(data))
			})
		}
		if (child.stderr) {
			child.stderr.setEncoding('utf8')
			child.stderr.on('data', (data) => {
				stderr += data
				if (channel) channel.append(clean(data))
			})
		}

		child.on('error', (error) => finish({ error, stdout, stderr }))
		child.on('close', (code) => finish({ code, stdout, stderr, cancelled }))

		if (token) {
			token.onCancellationRequested(() => {
				cancelled = true
				killTree(child)
			})
		}
	})
}

const PARSE_MARKER = 'PS12EXE_PARSE:'

/**
 * 从解析运行的 stdout 中提取 `PS12EXE_PARSE:` 结果。
 *
 * @param {string} stdout
 * @returns {boolean[]} 每个片段一个标志，无法解析时为 `true`
 */
function parseIncompleteOutput (stdout) {
	const results = []
	for (const line of String(stdout || '').split(/\r?\n/)) {
		const index = line.indexOf(PARSE_MARKER)
		if (index >= 0) results.push(line.slice(index + PARSE_MARKER.length).trim() === 'incomplete')
	}
	return results
}

/**
 * 用真正的 PowerShell 解析器解析代码片段，并报告哪些不是完整单元——即其 AST 无法独立构建。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string[]} options.texts
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<boolean[]>}
 */
async function findIncompleteFragments ({ host, texts, token }) {
	if (!texts.length) return []

	const payload = path.join(os.tmpdir(), `ps12exe-parse-${process.pid}-${Date.now()}-${Math.random().toString(36).slice(2)}.json`)
	fs.writeFileSync(payload, JSON.stringify(texts), 'utf8')
	const script = [
		'$ErrorActionPreference = "Stop"',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		`$texts = [System.IO.File]::ReadAllText(${psQuote(payload)}) | ConvertFrom-Json`,
		'foreach ($text in @($texts)) {',
		'  $tokens = $null',
		'  $errors = $null',
		'  [void][System.Management.Automation.Language.Parser]::ParseInput([string]$text, [ref]$tokens, [ref]$errors)',
		`  $state = if ($errors.Count -gt 0) { 'incomplete' } else { 'complete' }`,
		// 分支体可能是像 `[ArgumentCompleter({…})]` 这样的裸 attribute，只有在后面存在语句时才能解析（attribute 会附着到该语句上）。用一条哑语句重试这类情况，以免被误判为不完整的块；真正不完整的内容仍会失败。
		'  if ($errors.Count -gt 0 -and ([string]$text).TrimStart().StartsWith("[")) {',
		'    $tokens = $null',
		'    $errors = $null',
		'    [void][System.Management.Automation.Language.Parser]::ParseInput(([string]$text + "`n`$null"), [ref]$tokens, [ref]$errors)',
		`    if ($errors.Count -eq 0) { $state = 'complete' }`,
		'  }',
		`  Write-Output ('${PARSE_MARKER}' + $state)`,
		'}',
		'exit 0'
	].join('\n')

	try {
		const result = await runScript(host, script, { token })
		if (result.error) throw result.error
		const parsed = parseIncompleteOutput(result.stdout)
		if (parsed.length !== texts.length) {
			throw new Error(`expected ${texts.length} parse results, got ${parsed.length}: ${String(result.stderr || '').trim()}`)
		}
		return parsed
	}
	finally {
		try {
			fs.unlinkSync(payload)
		}
		catch {
			// 尽力而为；临时文件可能已经不在了。
		}
	}
}

/**
 * 在给定 PowerShell 宿主中运行 `ps12exe -inputFile <file>`。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string} options.file
 * @param {string | undefined} options.locale
 * @param {import('vscode').OutputChannel} [options.channel]
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<{ code?: number | null, error?: Error, stdout: string, stderr: string, cancelled?: boolean }>}
 */
function compileScript ({ host, file, locale, channel, token }) {
	const script = [
		'$ErrorActionPreference = "Stop"',
		'$global:LASTEXITCODE = 0',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		'Import-Module ps12exe -ErrorAction Stop',
		`ps12exe -inputFile ${psQuote(file)}${locale ? ` -Localize ${psQuote(locale)}` : ''}`,
		'exit $LASTEXITCODE'
	].join('; ')

	if (channel) {
		channel.appendLine(`> ps12exe -inputFile "${file}"${locale ? ` -Localize "${locale}"` : ''}`)
	}

	return runScript(host, script, { channel, token })
}

/**
 * 在给定宿主中运行 `exe21sp -inputFile <file> -outputFile <outputFile>`。exe21sp 会把还原出的脚本写入 `outputFile`，并在其旁边释放伴随文件（添加的 `#_pragma icon` 引用的图标），因此调用方应选择自己缓存目录内的输出路径。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string} options.file
 * @param {string} options.outputFile
 * @param {string | undefined} options.locale
 * @param {import('vscode').OutputChannel} [options.channel]
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<{ code?: number | null, error?: Error, stdout: string, stderr: string, cancelled?: boolean }>}
 */
function extractScriptToFile ({ host, file, outputFile, locale, channel, token }) {
	// ps12exe / exe21sp 是函数，设置的是 $global:LastExitCode，而不是 $LASTEXITCODE。
	const script = [
		'$ErrorActionPreference = "Stop"',
		'$global:LastExitCode = 0',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		'Import-Module ps12exe -ErrorAction Stop',
		`exe21sp -inputFile ${psQuote(file)} -outputFile ${psQuote(outputFile)}${locale ? ` -Localize ${psQuote(locale)}` : ''} | Out-Null`,
		'exit $global:LastExitCode'
	].join('; ')

	if (channel) {
		channel.appendLine(`> exe21sp -inputFile "${file}" -outputFile "${outputFile}"`)
	}

	return runScript(host, script, { channel, token })
}

/**
 * 把脚本文件编译到显式指定的输出路径。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string} options.input
 * @param {string} options.output
 * @param {string | undefined} options.locale
 * @param {import('vscode').OutputChannel} [options.channel]
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<{ code?: number | null, error?: Error, stdout: string, stderr: string, cancelled?: boolean }>}
 */
function compileToExe ({ host, input, output, locale, channel, token }) {
	const script = [
		'$ErrorActionPreference = "Stop"',
		'$global:LastExitCode = 0',
		'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
		'Import-Module ps12exe -ErrorAction Stop',
		`ps12exe -inputFile ${psQuote(input)} -outputFile ${psQuote(output)}${locale ? ` -Localize ${psQuote(locale)}` : ''}`,
		'exit $global:LastExitCode'
	].join('; ')

	if (channel) {
		channel.appendLine(`> ps12exe -inputFile "${input}" -outputFile "${output}"`)
	}

	return runScript(host, script, { channel, token })
}

const SYNC_MARKER = 'PS12EXE_SYNC:'

// 缺少 ps12exe 时安装最新版，并在 PSGallery 上有更新版本时更新它。
const SYNC_SCRIPT = [
	'$ErrorActionPreference = "Stop"',
	'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
	'if (-not (Get-PackageProvider -Name NuGet -ErrorAction Ignore)) { Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null }',
	'$installed = (Get-Module -ListAvailable -Name ps12exe | Sort-Object Version -Descending | Select-Object -First 1).Version',
	'# 0.0.0 is ps12exe\'s development version (see ps12exe.ps1): never overwrite it.',
	`if ($installed -and $installed.ToString() -eq '0.0.0') { Write-Output '${SYNC_MARKER} up-to-date 0.0.0'; exit 0 }`,
	'$latest = $null',
	'try { $latest = (Find-Module -Name ps12exe -ErrorAction Stop).Version } catch { }',
	`if (-not $installed -and -not $latest) { Write-Output '${SYNC_MARKER} unreachable'; exit 1 }`,
	'if (-not $installed -or ($latest -and $latest -gt $installed)) {',
	'  Install-Module ps12exe -Scope CurrentUser -Force -AllowClobber',
	'  $new = (Get-Module -ListAvailable -Name ps12exe | Sort-Object Version -Descending | Select-Object -First 1).Version',
	`  $state = if ($installed) { 'updated' } else { 'installed' }`,
	`  Write-Output '${SYNC_MARKER} ' + $state + ' ' + $new`,
	'  exit 0',
	'}',
	`Write-Output '${SYNC_MARKER} up-to-date ' + $installed`,
	'exit 0'
].join('\n')

/**
 * 解析 {@link SYNC_SCRIPT} 输出的最后一行 `PS12EXE_SYNC:`。
 *
 * @param {string} stdout
 * @returns {{ status: string, version?: string } | undefined}
 */
function parseSyncOutput (stdout) {
	const line = String(stdout || '')
		.split(/\r?\n/)
		.reverse()
		.find((entry) => entry.includes(SYNC_MARKER))
	if (!line) return undefined
	const parsed = line.slice(line.indexOf(SYNC_MARKER) + SYNC_MARKER.length).trim()
	const [status, version] = parsed.split(/\s+/, 2)
	return { status, version }
}

/**
 * 确保 ps12exe 模块存在且为最新版。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {import('vscode').OutputChannel} [options.channel]
 * @param {import('vscode').CancellationToken} [options.token]
 * @returns {Promise<{ status: 'installed' | 'updated' | 'up-to-date' | 'unreachable' | 'unknown' | 'error', version?: string, error?: string }>}
 */
async function syncModule ({ host, channel, token }) {
	if (channel) channel.appendLine('> syncing ps12exe module')

	const result = await runScript(host, SYNC_SCRIPT, { channel, token })
	if (result.cancelled) return { status: 'error', error: 'cancelled' }
	if (result.error) return { status: 'error', error: result.error.message }

	const parsed = parseSyncOutput(result.stdout)
	if (parsed) return parsed
	return { status: 'error', error: String(result.stderr || '').trim() || `exit code ${result.code}` }
}

/**
 * 以分离方式启动 `ps12exeGUI -PS1File <file>`，这样 GUI 保持打开时 VS Code 不会被阻塞。
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string} options.file
 * @param {string | undefined} options.locale
 * @param {string} [options.uiMode]
 * @returns {Promise<void>}
 */
function launchGUI ({ host, file, locale, uiMode = 'Auto' }) {
	const script = [
		'Import-Module ps12exe -ErrorAction Stop',
		`ps12exeGUI -PS1File ${psQuote(file)}${locale ? ` -Localize ${psQuote(locale)}` : ''} -UIMode ${psQuote(uiMode)}`
	].join('; ')

	return new Promise((resolve, reject) => {
		let child
		try {
			child = spawn(host.command, encodedArgs(script), { detached: true, stdio: 'ignore', windowsHide: false })
		}
		catch (error) {
			reject(error)
			return
		}
		child.once('error', reject)
		child.once('spawn', () => {
			child.unref()
			resolve()
		})
	})
}

export { encodeCommand, psQuote, resolvePowerShell, resolvePlainPowerShell, runScript, compileScript, compileToExe, extractScriptToFile, syncModule, parseSyncOutput, findIncompleteFragments, parseIncompleteOutput, launchGUI }
