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
 * PowerShell's `-EncodedCommand` expects a Base64 encoded UTF-16LE string.
 * Using it avoids every shell/Windows command line quoting pitfall, which is
 * important because script paths may contain quotes, spaces and unicode.
 *
 * @param {string} script
 * @returns {string}
 */
function encodeCommand (script) {
	return Buffer.from(script, 'utf16le').toString('base64')
}

/**
 * Quotes a value as a PowerShell single quoted string literal.
 *
 * @param {string} value
 * @returns {string}
 */
function psQuote (value) {
	return `'${String(value).replace(/'/g, "''")}'`
}

/**
 * Resolves the candidate PowerShell executables to absolute paths (PATH aware,
 * PATHEXT aware on Windows), preferred first.
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
			// Not found on this machine.
		}
	}
	return candidates
}

/**
 * @param {string} script
 * @returns {string[]}
 */
function encodedArgs (script) {
	// `-OutputFormat Text` keeps PowerShell's information stream out of stderr;
	// without it redirected hosts receive a CLIXML copy of every Write-Host call.
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
		// ENOENT means the executable itself is not installed.
		if (error.code === 'ENOENT') return null
		// The host exists but the probe failed for another reason; treat the
		// module as unavailable so the caller can offer to install it.
		return { command, moduleVersion: null }
	}
}

/**
 * Finds a PowerShell host that can load the ps12exe module. The result is
 * cached because probing spawns processes.
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
			// Only cache positive results so that installing the module later is
			// picked up on the next run.
			cachedHost = result
			return cachedHost
		}
	}
	return fallback
}

/** @type {{ command: string } | null | undefined} */
let cachedPlainHost

/**
 * Resolves any usable PowerShell host and caches it. Unlike
 * {@link resolvePowerShell} this does not care about the ps12exe module, so it
 * is cheap to call repeatedly (parsing, formatting).
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
		// Process already gone.
	}
}

// ps12exe uses ANSI cursor moves to redraw its progress; they would show up as
// garbage in the output channel.
const clean = (text) => String(text).replace(/\u001b\[[0-9;]*[A-Za-z]/g, '')

/**
 * Runs an arbitrary PowerShell script in the given host, streaming the output
 * to `channel`.
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
 * Extracts the `PS12EXE_PARSE:` results from a parse run's stdout.
 *
 * @param {string} stdout
 * @returns {boolean[]} one flag per fragment, `true` when it does not parse
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
 * Parses code fragments with the real PowerShell parser and reports which ones
 * are not a complete unit — i.e. whose AST cannot be built on its own.
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
		// A branch body may be a bare attribute such as `[ArgumentCompleter({…})]`
		// that only parses once a following statement exists (the attribute sticks
		// to it). Retry those with a dummy statement so they are not mistaken for
		// incomplete blocks; anything genuinely incomplete still fails.
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
			// Best effort; the temp file may already be gone.
		}
	}
}

/**
 * Runs `ps12exe -inputFile <file>` in the given PowerShell host.
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
 * Runs `exe21sp -inputFile <file> -outputFile <outputFile>` in the given host.
 * exe21sp writes the recovered script to `outputFile` and releases companion
 * files (the icon referenced by an added `#_pragma icon`) next to it, so the
 * caller should pick an output path inside its own cache directory.
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
	// ps12exe / exe21sp are functions and set $global:LastExitCode, not $LASTEXITCODE.
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
 * Compiles a script file to an explicit output path.
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

// Installs the latest ps12exe when missing and updates it when a newer version
// is available on PSGallery.
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
 * Parses the last `PS12EXE_SYNC:` line emitted by {@link SYNC_SCRIPT}.
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
 * Ensures the ps12exe module is present and up to date.
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
 * Launches `ps12exeGUI -PS1File <file>` detached so VS Code is not blocked
 * while the GUI stays open.
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
