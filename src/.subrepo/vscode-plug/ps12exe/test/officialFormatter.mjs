// Emulates the formatter the official `ms-vscode.powershell` extension runs.
//
// PowerShell Editor Services forwards the editor's `powershell.codeFormatting.*`
// settings (plus `editor.insertSpaces`/`editor.tabSize`) to PSScriptAnalyzer's
// `Invoke-Formatter` through `CodeFormattingSettings.GetPSSASettingsHashtable`.
// This module mirrors that mapping so tests can check what VS Code would do to
// a file without launching an editor. Keep it in sync with
// https://github.com/PowerShell/PowerShellEditorServices (LanguageServerSettings.cs)
// when the PowerShell extension changes.
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { runScript, psQuote } from '../lib/powershell.mjs'

// Defaults of `powershell.codeFormatting.*` in ms-vscode.powershell.
const DEFAULTS = Object.freeze({
	preset: 'Custom',
	autoCorrectAliases: false,
	avoidSemicolonsAsLineTerminators: false,
	openBraceOnSameLine: true,
	newLineAfterOpenBrace: true,
	newLineAfterCloseBrace: true,
	pipelineIndentationStyle: 'NoIndentation',
	whitespaceBeforeOpenBrace: true,
	whitespaceBeforeOpenParen: true,
	whitespaceAroundOperator: true,
	whitespaceAfterSeparator: true,
	whitespaceInsideBrace: true,
	whitespaceBetweenParameters: false,
	whitespaceAroundPipe: true,
	addWhitespaceAroundPipe: true,
	trimWhitespaceAroundPipe: false,
	ignoreOneLineBlock: true,
	alignPropertyValuePairs: true,
	useConstantStrings: false,
	useCorrectCasing: false
})

const CODE_FORMATTING_PREFIX = 'powershell.codeFormatting.'

/**
 * Builds the PSScriptAnalyzer settings hashtable from the VS Code settings.
 *
 * @param {object} [options]
 * @param {Record<string, unknown>} [options.overrides] `powershell.codeFormatting.*` values (without the prefix)
 * @param {boolean} [options.insertSpaces]
 * @param {number} [options.tabSize]
 * @returns {object}
 */
function buildSettings (options = {}) {
	const config = { ...DEFAULTS, ...(options.overrides || {}) }
	const insertSpaces = options.insertSpaces !== false
	const tabSize = options.tabSize || 4

	const rules = {
		PSPlaceOpenBrace: {
			Enable: true,
			OnSameLine: config.openBraceOnSameLine,
			NewLineAfter: config.newLineAfterOpenBrace,
			IgnoreOneLineBlock: config.ignoreOneLineBlock
		},
		PSPlaceCloseBrace: {
			Enable: true,
			NewLineAfter: config.newLineAfterCloseBrace,
			IgnoreOneLineBlock: config.ignoreOneLineBlock
		},
		PSUseConsistentIndentation: {
			Enable: true,
			IndentationSize: tabSize,
			PipelineIndentation: config.pipelineIndentationStyle,
			Kind: insertSpaces ? 'space' : 'tab'
		},
		PSUseConsistentWhitespace: {
			Enable: true,
			CheckOpenBrace: config.whitespaceBeforeOpenBrace,
			CheckOpenParen: config.whitespaceBeforeOpenParen,
			CheckOperator: config.whitespaceAroundOperator,
			CheckSeparator: config.whitespaceAfterSeparator,
			CheckInnerBrace: config.whitespaceInsideBrace,
			CheckParameter: config.whitespaceBetweenParameters,
			CheckPipe: config.addWhitespaceAroundPipe,
			CheckPipeForRedundantWhitespace: config.trimWhitespaceAroundPipe
		},
		PSAlignAssignmentStatement: {
			Enable: true,
			CheckHashtable: config.alignPropertyValuePairs,
			CheckEnums: false
		},
		PSUseCorrectCasing: { Enable: config.useCorrectCasing },
		PSAvoidUsingDoubleQuotesForConstantString: { Enable: config.useConstantStrings },
		PSAvoidSemicolonsAsLineTerminators: { Enable: config.avoidSemicolonsAsLineTerminators }
	}

	switch (config.preset) {
		case 'Allman':
			rules.PSPlaceOpenBrace.OnSameLine = false
			rules.PSPlaceOpenBrace.NewLineAfter = true
			rules.PSPlaceCloseBrace.NewLineAfter = true
			break
		case 'OTBS':
			rules.PSPlaceOpenBrace.OnSameLine = true
			rules.PSPlaceOpenBrace.NewLineAfter = true
			rules.PSPlaceCloseBrace.NewLineAfter = false
			break
		case 'Stroustrup':
			rules.PSPlaceOpenBrace.OnSameLine = true
			rules.PSPlaceOpenBrace.NewLineAfter = true
			rules.PSPlaceCloseBrace.NewLineAfter = true
			break
		default:
			break
	}

	if (config.autoCorrectAliases) rules.PSAvoidUsingCmdletAliases = {}

	return {
		IncludeRules: [
			'PSPlaceCloseBrace',
			'PSPlaceOpenBrace',
			'PSUseConsistentWhitespace',
			'PSUseConsistentIndentation',
			'PSAlignAssignmentStatement',
			'PSAvoidUsingDoubleQuotesForConstantString'
		],
		Rules: rules
	}
}

/**
 * Reads the workspace's `powershell.codeFormatting.*` overrides and the
 * `[powershell]` editor indentation settings, if a `.vscode/settings.json`
 * exists at `repoRoot`.
 *
 * @param {string} repoRoot
 * @returns {{ overrides: Record<string, unknown>, insertSpaces: boolean, tabSize: number }}
 */
function readWorkspaceFormatting (repoRoot) {
	const overrides = {}
	let fileSettings = {}
	const settingsPath = path.join(repoRoot, '.vscode', 'settings.json')
	if (fs.existsSync(settingsPath)) {
		try {
			fileSettings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'))
		}
		catch {
			// A malformed workspace file should not fail the test run.
		}
	}
	for (const [key, value] of Object.entries(fileSettings)) {
		if (key.startsWith(CODE_FORMATTING_PREFIX)) overrides[key.slice(CODE_FORMATTING_PREFIX.length)] = value
	}
	const editor = fileSettings['[powershell]'] || {}
	return {
		overrides,
		insertSpaces: editor['editor.insertSpaces'] !== false,
		tabSize: editor['editor.tabSize'] || 4
	}
}

const MARKER = 'PS12EXE_FMT:'

const FORMAT_SCRIPT = [
	'$ErrorActionPreference = "Stop"',
	'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
	'if (-not (Get-Command Invoke-Formatter -ErrorAction Ignore)) { Write-Output "PS12EXE_FMT:missing"; exit 0 }',
	'function ConvertTo-Ps12exeHashtable($value) {',
	'  if ($null -eq $value) { return $null }',
	'  if ($value -is [System.Management.Automation.PSCustomObject]) {',
	'    $table = @{}',
	'    foreach ($property in $value.PSObject.Properties) { $table[$property.Name] = ConvertTo-Ps12exeHashtable $property.Value }',
	'    return $table',
	'  }',
	'  if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {',
	'    $items = @()',
	'    foreach ($item in $value) { $items += ,(ConvertTo-Ps12exeHashtable $item) }',
	'    return $items',
	'  }',
	'  return $value',
	'}',
	'$raw = [System.IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json',
	'$settings = ConvertTo-Ps12exeHashtable $raw',
	'$text = [System.IO.File]::ReadAllText($textPath)',
	'$formatted = Invoke-Formatter -ScriptDefinition $text -Settings $settings',
	'[System.IO.File]::WriteAllText($outPath, $formatted, [System.Text.UTF8Encoding]::new($false))',
	'Write-Output "PS12EXE_FMT:ok"',
	'exit 0'
]

/**
 * Runs the emulated official formatter on `text`.
 *
 * @param {object} options
 * @param {{ command: string }} options.host
 * @param {string} options.text
 * @param {object} options.settings the PSScriptAnalyzer settings hashtable (see {@link buildSettings})
 * @returns {Promise<{ available: boolean, text: string }>}
 */
async function formatWithOfficialFormatter ({ host, text, settings }) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ps12exe-fmt-'))
	const settingsPath = path.join(dir, 'settings.json')
	const textPath = path.join(dir, 'input.ps1')
	const outPath = path.join(dir, 'output.ps1')
	fs.writeFileSync(settingsPath, JSON.stringify(settings), 'utf8')
	fs.writeFileSync(textPath, text, 'utf8')

	const script = [
		`$settingsPath = ${psQuote(settingsPath)}`,
		`$textPath = ${psQuote(textPath)}`,
		`$outPath = ${psQuote(outPath)}`
	].concat(FORMAT_SCRIPT).join('\n')

	try {
		const result = await runScript(host, script)
		if (result.error) throw result.error
		const available = String(result.stdout || '').includes(`${MARKER}ok`)
		if (!available) return { available: false, text }
		return { available: true, text: fs.readFileSync(outPath, 'utf8') }
	}
	finally {
		try {
			fs.rmSync(dir, { recursive: true, force: true })
		}
		catch {
			// Best effort cleanup.
		}
	}
}

export { DEFAULTS, buildSettings, readWorkspaceFormatting, formatWithOfficialFormatter }
