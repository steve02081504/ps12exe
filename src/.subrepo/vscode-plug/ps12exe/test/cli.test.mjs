/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { analyzeCliUsage, cliTokenAt, scanCliInvocations, CLI_PARAMETER_DIAGNOSTIC, CLI_MEMBER_DIAGNOSTIC } from '../lib/cli.mjs'

// 与已安装模块 `PrarmsData` 相同的扁平形状：小写点号路径 -> { name, description }。
const DATA = new Map([
	['input', { name: 'input', description: 'input alias' }],
	['inputfile', { name: 'inputFile', description: 'input file' }],
	['outputfile', { name: 'outputFile', description: 'output file' }],
	['content', { name: 'Content', description: 'content' }],
	['app.windowed', { name: 'App.Windowed', description: 'windowed' }],
	['app.silence', { name: 'App.Silence', description: 'silence' }],
	['build.target', { name: 'Build.Target', description: 'target' }],
	['build.core.backend', { name: 'Build.Core.Backend', description: 'backend' }],
	['build.core.aot', { name: 'Build.Core.Aot', description: 'aot' }],
	['resources.icon', { name: 'Resources.Icon', description: 'icon' }],
	['quiet', { name: 'Quiet', description: 'quiet' }]
])

suite('ps12exe command-line invocations', () => {
	test('collects parameters and hashtable members with their paths', () => {
		const line = 'ps12exe -InputFile a.ps1 -App @{ Windowed = $true; Silence = @(\'Output\') } -Quiet'
		const found = scanCliInvocations(line)
		assert.deepStrictEqual(
			found.map((entry) => [entry.kind, entry.name, entry.path]),
			[
				['param', 'InputFile', 'inputfile'],
				['param', 'App', 'app'],
				['member', 'Windowed', 'app.windowed'],
				['member', 'Silence', 'app.silence'],
				['param', 'Quiet', 'quiet']
			]
		)
		// 列区间覆盖参数名（含 `-`）与成员键本身。
		const app = found.find((entry) => entry.name === 'App')
		assert.strictEqual(line.slice(app.startColumn, app.endColumn), '-App')
		const windowed = found.find((entry) => entry.name === 'Windowed')
		assert.strictEqual(line.slice(windowed.startColumn, windowed.endColumn), 'Windowed')
	})

	test('parses multi-line and nested hashtables', () => {
		const text = [
			'ps12exe -InputFile a.ps1 -Build @{',
			'\tTarget = \'Core\'',
			'\tCore = @{ Aot = $true; Backend = \'Bundled\' }',
			'}'
		].join('\n')
		const found = scanCliInvocations(text)
		assert.deepStrictEqual(
			found.map((entry) => entry.path),
			['inputfile', 'build', 'build.target', 'build.core', 'build.core.aot', 'build.core.backend']
		)
		// `Core` 在第二行的键区间落在原始文档上。
		const core = found.find((entry) => entry.path === 'build.core')
		assert.strictEqual(core.line, 2)
		assert.strictEqual(text.split('\n')[2].slice(core.startColumn, core.endColumn), 'Core')
	})

	test('ignores ps12exe text in strings, comments and non-command positions', () => {
		const text = [
			'Write-Output "ps12exe -Unknown"',
			'# ps12exe -Unknown',
			'$x = 1',
			'Get-Item ps12exe',
			'"-Unknown"'
		].join('\n')
		assert.deepStrictEqual(scanCliInvocations(text), [])
	})

	test('flags unknown parameters and members but keeps known ones', () => {
		const line = 'ps12exe -InputFile a.ps1 -App @{ Windowed = $true; Clip = 1 } -Quiet -Unknown'
		const found = analyzeCliUsage(line, DATA)
		assert.deepStrictEqual(
			found.map((d) => [d.args, d.code]),
			[
				[['Clip', '-App'], CLI_MEMBER_DIAGNOSTIC],
				[['Unknown'], CLI_PARAMETER_DIAGNOSTIC]
			]
		)
		// 诊断范围正好覆盖该名字。
		assert.strictEqual(line.slice(found[0].start, found[0].end), 'Clip')
		assert.strictEqual(line.slice(found[1].start, found[1].end), '-Unknown')
	})

	test('accepts common parameters and the input alias', () => {
		assert.deepStrictEqual(analyzeCliUsage('ps12exe -input a.ps1 -Verbose -Debug -ErrorAction Stop -Quiet', DATA), [])
	})

	test('does not report members whose parameter is unknown', () => {
		assert.deepStrictEqual(analyzeCliUsage('ps12exe -Unknown @{ Foo = 1 }', DATA).map((d) => d.code), [CLI_PARAMETER_DIAGNOSTIC])
	})

	test('finds the token under the cursor', () => {
		const line = 'ps12exe -App @{ Windowed = $true }'
		const appStart = line.indexOf('-App')
		const windowedStart = line.indexOf('Windowed')
		assert.strictEqual(cliTokenAt(line, 0, appStart + 1).path, 'app')
		assert.strictEqual(cliTokenAt(line, 0, windowedStart + 3).path, 'app.windowed')
		assert.strictEqual(cliTokenAt(line, 0, line.indexOf('@')), null)
		assert.strictEqual(cliTokenAt(line, 0, line.indexOf('$true')), null)
	})

	test('ignores here-string bodies', () => {
		const text = ['$s = @"', 'ps12exe -Unknown', '"@'].join('\n')
		assert.deepStrictEqual(analyzeCliUsage(text, DATA), [])
	})

	test('treats #_!! lines as real code', () => {
		const line = '#_!!ps12exe -Unknown'
		const found = analyzeCliUsage(line, DATA)
		assert.deepStrictEqual(found.map((d) => [d.line, d.code]), [[0, CLI_PARAMETER_DIAGNOSTIC]])
		assert.strictEqual(line.slice(found[0].start, found[0].end), '-Unknown')
	})

	test('returns no diagnostics without data', () => {
		assert.deepStrictEqual(analyzeCliUsage('ps12exe -Unknown', undefined), [])
	})
})
