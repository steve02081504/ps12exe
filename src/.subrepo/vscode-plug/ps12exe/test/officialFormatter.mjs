// 模拟官方 `ms-vscode.powershell` 扩展运行的 formatter。
//
// PowerShell Editor Services 通过 `CodeFormattingSettings.GetPSSASettingsHashtable` 将编辑器的 `powershell.codeFormatting.*` 设置（以及 `editor.insertSpaces`/`editor.tabSize`）转发给 PSScriptAnalyzer 的 `Invoke-Formatter`。本模块镜像该映射，使测试无需启动编辑器即可检查 VS Code 会对文件做什么。当 PowerShell 扩展变更时，请保持与 https://github.com/PowerShell/PowerShellEditorServices（LanguageServerSettings.cs）同步。
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { runScript, psQuote } from '../lib/powershell.mjs'

/** ms-vscode.powershell 中 `powershell.codeFormatting.*` 的默认值。 */
export const DEFAULTS = Object.freeze({
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
 * 从 VS Code 设置构建 PSScriptAnalyzer 设置哈希表。
 *
 * @param {object} [options] - 构建选项
 * @param {Record<string, unknown>} [options.overrides] `powershell.codeFormatting.*` 的值（不含前缀）
 * @param {boolean} [options.insertSpaces] - 是否使用空格缩进
 * @param {number} [options.tabSize] - 缩进宽度
 * @returns {object} 设置哈希表
 */
export function buildSettings (options = {}) {
	const config = { ...DEFAULTS, ...options.overrides }
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
 * 读取本扩展为官方 formatter 提供的默认值（`package.json` 中的 `contributes.configurationDefaults`）。VS Code 会将未被用户或工作区覆盖的设置解析为这些值。
 *
 * @returns {{ codeFormatting: Record<string, unknown>, insertSpaces: boolean | undefined }} 扩展默认配置
 */
function readExtensionConfigurationDefaults () {
	const manifestPath = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'package.json')
	let defaults = {}
	try {
		const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
		defaults = (manifest.contributes && manifest.contributes.configurationDefaults) || {}
	}
	catch {
		// 缺少清单文件不应导致测试运行失败。
	}
	const codeFormatting = {}
	for (const [key, value] of Object.entries(defaults)) 
		if (key.startsWith(CODE_FORMATTING_PREFIX)) codeFormatting[key.slice(CODE_FORMATTING_PREFIX.length)] = value
	
	const editor = defaults['[powershell]'] || {}
	return { codeFormatting, insertSpaces: editor['editor.insertSpaces'] }
}

/**
 * 解析官方 formatter 会看到的 `powershell.codeFormatting.*` 和 `[powershell]` 编辑器设置：先是本扩展提供的默认值，然后叠加工作区的 `.vscode/settings.json` 覆盖值。
 *
 * @param {string} repoRoot - 仓库根目录
 * @returns {{ overrides: Record<string, unknown>, insertSpaces: boolean, tabSize: number }} 解析后的格式化设置
 */
export function readWorkspaceFormatting (repoRoot) {
	const extension = readExtensionConfigurationDefaults()
	const overrides = { ...extension.codeFormatting }
	let fileSettings = {}
	const settingsPath = path.join(repoRoot, '.vscode', 'settings.json')
	if (fs.existsSync(settingsPath)) 
		try {
			fileSettings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'))
		}
		catch {
			// 格式错误的工作区文件不应导致测试运行失败。
		}
	
	for (const [key, value] of Object.entries(fileSettings)) 
		if (key.startsWith(CODE_FORMATTING_PREFIX)) overrides[key.slice(CODE_FORMATTING_PREFIX.length)] = value
	
	const editor = fileSettings['[powershell]'] || {}
	const workspaceInsertSpaces = editor['editor.insertSpaces']
	// VS Code 自身的默认值是空格；本扩展提供的是制表符。
	const insertSpaces = workspaceInsertSpaces !== undefined
		? workspaceInsertSpaces
		: extension.insertSpaces !== undefined ? extension.insertSpaces : true
	return {
		overrides,
		insertSpaces: insertSpaces === true,
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
 * 对 `text` 运行模拟的官方 formatter。
 *
 * @param {object} options - 运行选项
 * @param {{ command: string }} options.host - PowerShell 主机
 * @param {string} options.text - 待格式化文本
 * @param {object} options.settings PSScriptAnalyzer 设置哈希表（参见 {@link buildSettings}）
 * @returns {Promise<{ available: boolean, text: string }>} 格式化结果
 */
export async function formatWithOfficialFormatter ({ host, text, settings }) {
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
			// 尽力清理。
		}
	}
}
