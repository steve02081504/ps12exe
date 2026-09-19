/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { parseAliasOutput, FALLBACK_ALIASES } from '../lib/aliases.mjs'
import { analyzeCommandUsage, computeIgnoredMask, IGNORE_DIRECTIVE, MODULE_ALIASES, PS2EXE_DIAGNOSTIC, MODULE_DIAGNOSTIC } from '../lib/commands.mjs'

// 模块管理告警只在使用了预处理指令的文件里出现，测试文本因此都带上一个 `#_` 指令行。
const DIRECTIVE = '#_pragma App.Windowed'

suite('ps12exe command warnings', () => {
	test('flags PS2EXE calls and proposes the ps12exe rewrite', () => {
		const text = ['ps2exe -inputFile a.ps1', 'Invoke-PS2EXE "b.ps1"', '& Win-PS2EXE', 'ps2exe.ps1 -inputFile a'].join('\n')
		const found = analyzeCommandUsage(text)
		assert.deepStrictEqual(
			found.map((d) => [d.line, d.start, d.end, d.args[0], d.code]),
			[
				[0, 0, 23, 'ps2exe', PS2EXE_DIAGNOSTIC],
				[1, 0, 21, 'Invoke-PS2EXE', PS2EXE_DIAGNOSTIC],
				[2, 2, 12, 'Win-PS2EXE', PS2EXE_DIAGNOSTIC],
				[3, 0, 23, 'ps2exe.ps1', PS2EXE_DIAGNOSTIC]
			]
		)
	})

	test('rewrites the whole invocation with the ps12exe object API', () => {
		const line = 'ps2exe -inputFile a.ps1 -outputFile b.exe -noConsole -title "My App" -version 1.0.0.0 -x64 -requireAdmin'
		const found = analyzeCommandUsage(line)
		assert.strictEqual(found.length, 1)
		assert.deepStrictEqual(
			[found[0].start, found[0].end],
			[0, line.length]
		)
		assert.strictEqual(
			found[0].replacement,
			'ps12exe -InputFile a.ps1 -OutputFile b.exe -App @{ Windowed = $true } -Os @{ Admin = $true } -Build @{ Platform = \'x64\' } -Resources @{ Title = "My App"; Version = \'1.0.0.0\' }'
		)
	})

	test('binds positional arguments and merges Silence flags', () => {
		assert.strictEqual(
			analyzeCommandUsage('ps2exe input.ps1 output.exe')[0].replacement,
			'ps12exe -InputFile input.ps1 -OutputFile output.exe'
		)
		assert.strictEqual(
			analyzeCommandUsage('ps2exe -noConsole -noOutput -noError -inputFile a.ps1')[0].replacement,
			'ps12exe -InputFile a.ps1 -App @{ Windowed = $true; Silence = @(\'Output\', \'Verbose\', \'Error\', \'Warning\', \'Debug\') }'
		)
		assert.strictEqual(
			analyzeCommandUsage('ps2exe -lcid 1033 -iconFile C:\\Data\\Icon.ico')[0].replacement,
			'ps12exe -Build @{ Culture = \'1033\' } -Resources @{ Icon = \'C:\\Data\\Icon.ico\' }'
		)
	})

	test('does not rewrite calls that cannot be mapped statically', () => {
		// conHost / embedFiles 在 ps12exe 没有等价能力，splatting 与跨行调用也无法静态展开。
		assert.strictEqual(analyzeCommandUsage('ps2exe -conHost a.ps1')[0].replacement, undefined)
		assert.strictEqual(analyzeCommandUsage('ps2exe @params')[0].replacement, undefined)
		assert.strictEqual(analyzeCommandUsage('ps2exe -inputFile a.ps1 `')[0].replacement, undefined)
		assert.strictEqual(analyzeCommandUsage('ps2exe -unknownParam a.ps1')[0].replacement, undefined)
	})

	test('flags module-management commands only in files that use the preprocessor', () => {
		const text = [
			DIRECTIVE,
			'gmo ps12exe -ListAvailable',
			'ipmo foo',
			'inmo bar',
			'Get-Module baz',
			'Import-Module qux',
			'Install-Module quux'
		].join('\n')
		const found = analyzeCommandUsage(text, MODULE_ALIASES)
		assert.deepStrictEqual(
			found.map((d) => [d.line, d.args[0], d.code]),
			[
				[1, 'gmo', MODULE_DIAGNOSTIC],
				[2, 'ipmo', MODULE_DIAGNOSTIC],
				[3, 'inmo', MODULE_DIAGNOSTIC],
				[4, 'Get-Module', MODULE_DIAGNOSTIC],
				[5, 'Import-Module', MODULE_DIAGNOSTIC],
				[6, 'Install-Module', MODULE_DIAGNOSTIC]
			]
		)

		// 普通脚本（没有预处理指令）不会被 ps12exe 编译，不该收到模块管理告警；PS2EXE 调用则照常告警。
		assert.deepStrictEqual(analyzeCommandUsage('gmo foo\nInstall-Module bar', MODULE_ALIASES), [])
		assert.deepStrictEqual(analyzeCommandUsage('ps2exe a.ps1').map((d) => d.code), [PS2EXE_DIAGNOSTIC])
	})

	test('only flags aliases that resolve to a module cmdlet', () => {
		// 未确认的别名不告警：既可能是用户自定义函数，也可能这台机器上根本不存在（例如未加载 PowerShellGet 时的 inmo）。
		assert.deepStrictEqual(analyzeCommandUsage(`${DIRECTIVE}\ngmo foo`, {}), [])
		assert.deepStrictEqual(analyzeCommandUsage(`${DIRECTIVE}\ngmo foo`, { gmo: 'Write-Host' }), [])
		assert.deepStrictEqual(analyzeCommandUsage(`${DIRECTIVE}\ninmo foo`, {}), [])

		// 完整 cmdlet 名不依赖别名，始终告警。
		const full = analyzeCommandUsage(`${DIRECTIVE}\nInstall-Module foo`, {})
		assert.deepStrictEqual(full.map((d) => d.code), [MODULE_DIAGNOSTIC])
	})

	test('offers a #_require rewrite for module install lines', () => {
		const installed = analyzeCommandUsage(`${DIRECTIVE}\nInstall-Module foo -Scope CurrentUser -Force`)
		assert.strictEqual(installed.length, 1)
		assert.deepStrictEqual(
			[installed[0].line, installed[0].start, installed[0].end, installed[0].replacement],
			[1, 0, 'Install-Module foo -Scope CurrentUser -Force'.length, '#_require foo']
		)

		const generated = analyzeCommandUsage(
			`${DIRECTIVE}\nif(!(gmo ps12exe -ListAvailable -ea SilentlyContinue)){try{Import-PackageProvider NuGet}catch{};Install-Module ps12exe -Scope CurrentUser -Force -ea Stop}`
		)
		assert.strictEqual(generated.length, 2)
		for (const entry of generated) 
			assert.strictEqual(entry.replacement, '#_require ps12exe')
		
	})

	test('does not offer #_require for gmo-only or piped lines', () => {
		assert.strictEqual(analyzeCommandUsage(`${DIRECTIVE}\ngmo foo`)[0].replacement, undefined)
		assert.strictEqual(analyzeCommandUsage(`${DIRECTIVE}\nGet-ChildItem | Install-Module foo`).at(-1).replacement, undefined)
	})

	test('ignores command names in arguments, strings and comments', () => {
		const text = [
			'Write-Output gmo',
			'Set-Alias -Name foo -Value Get-Module',
			'$x = "Invoke-PS2EXE"',
			'# ps2exe foo',
			'#_if PSEXE',
			'$y.gmo()',
			'"ps2exe"'
		].join('\n')
		assert.deepStrictEqual(analyzeCommandUsage(text), [])
	})

	test('flags #_!! lines, which become real code after compilation', () => {
		const found = analyzeCommandUsage(`${DIRECTIVE}\n#_!!gmo foo`)
		assert.deepStrictEqual(found.map((d) => [d.line, d.start, d.end, d.args[0]]), [[1, 4, 7, 'gmo']])
	})

	test('does not flag commands inside here-string bodies', () => {
		const text = ['$s = @"', 'ps2exe foo', 'gmo bar', '"@'].join('\n')
		assert.deepStrictEqual(analyzeCommandUsage(text), [])
	})

	test('detects commands after operators and assignments', () => {
		const text = [
			DIRECTIVE,
			'if (!(gmo ps12exe)) { }',
			'$m = gmo ps12exe',
			'Get-ChildItem | ipmo',
			'{ ps2exe a.ps1 }'
		].join('\n')
		const found = analyzeCommandUsage(text)
		assert.deepStrictEqual(
			found.map((d) => [d.line, d.args[0]]),
			[
				[1, 'gmo'],
				[2, 'gmo'],
				[3, 'ipmo'],
				[4, 'ps2exe']
			]
		)
	})

	test('suppresses a line with the ignore marker above it or at its end', () => {
		const above = [DIRECTIVE, '# use_ps12exe:ignore', 'gmo foo', 'ps2exe a.ps1'].join('\n')
		assert.deepStrictEqual(analyzeCommandUsage(above).map((d) => d.args[0]), ['ps2exe'])

		const trailing = `${DIRECTIVE}\ngmo foo ${IGNORE_DIRECTIVE}`
		assert.deepStrictEqual(analyzeCommandUsage(trailing), [])
	})

	test('computes the ignored-line mask', () => {
		const lines = ['gmo a', IGNORE_DIRECTIVE, 'gmo b', `gmo c ${IGNORE_DIRECTIVE}`, 'gmo d']
		assert.deepStrictEqual(computeIgnoredMask(lines), [false, true, true, true, false])
	})
})

suite('ps12exe alias probe', () => {
	test('parses alias definitions and keeps only module cmdlets', () => {
		const stdout = [
			'noise',
			'PS12EXE_ALIAS:gmo=Get-Module',
			'PS12EXE_ALIAS:ipmo=Import-Module',
			'PS12EXE_ALIAS:inmo=Install-Module',
			'PS12EXE_ALIAS:foo=Bar',
			'PS12EXE_ALIAS:broken'
		].join('\n')
		assert.deepStrictEqual(parseAliasOutput(stdout), {
			gmo: 'Get-Module',
			ipmo: 'Import-Module',
			inmo: 'Install-Module'
		})
		assert.deepStrictEqual(parseAliasOutput(''), {})
		assert.deepStrictEqual(FALLBACK_ALIASES, { gmo: 'Get-Module', ipmo: 'Import-Module', inmo: 'Install-Module' })
	})
})
