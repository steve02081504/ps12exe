/* global suite: readonly, test: readonly */
import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { formatPreprocessedText, applyPreprocessorFormatting } from '../lib/format.mjs'
import { resolvePlainPowerShell } from '../lib/powershell.mjs'

import { buildSettings, readWorkspaceFormatting, formatWithOfficialFormatter } from './officialFormatter.mjs'

// 该扩展位于 <repo>/src/.subrepo/vscode-plug/ps12exe，因此本测试文件位于 ps12exe 仓库根目录下五层。
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..', '..')

// 仓库自身的脚本由该扩展格式化，因此用工作区风格格式化它们必须是逐字节无操作。`ps12exe.ps1` 是打包脚本；其余全是此前会被格式化改坏的文件（管道/成员访问续行被压平、括号里的 scriptblock/hashtable/数组被多缩进一层、看起来像指令的字符串字面量），见 `lib/preprocessor.mjs#restoreCarriedIndentation`。
const WORKSPACE_TARGETS = [
	'ps12exe.ps1',
	'src/CodeDomCompiler.ps1',
	'src/Cache.ps1',
	'src/ReadScriptFile.ps1',
	'tests/cases/35-gzip-determinism.ps1',
	'tests/cases/72-packaging.ps1',
	'tests/cases/31-ps12exe-args.ps1',
	'tests/lib/gui.ps1',
	'tests/lib/integration.ps1',
	'tools/AsmResolver/Update-AsmResolver.ps1',
	'tools/DialogScreenshots/Compare-Dialogs.ps1'
]

// 上面那些构造的最小复现，用于在没有对应仓库文件时也能守住行为（以及让失败信息直接指向出错的构造）。
// 注意 `Preprocessor @(` 里的字符串看起来就是指令：`analyze` 会把它们当成 `#_if`/`#_endif`，缩进必须原样保留。
const CONSTRUCT_FIXTURE = [
	'function Invoke-Sample {',
	'\tGet-ChildItem -LiteralPath $Root -Force -ErrorAction Ignore |',
	'\t\tWhere-Object { $_.LastWriteTimeUtc -lt $cutoff } |',
	'\t\tForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }',
	'\t$frame = (Get-Content "$PSScriptRoot/frame.cs" -Raw -Encoding UTF8).',
	'\t\tReplace(\'/*__MARKER__*/\', $methods).',
	'\t\tReplace($attributesMarker, $attributes)',
	'\tforeach ($vector in @(',
	'\t\t@{ Name = \'a\'; Hash = \'AA\' },',
	'\t\t@{ Name = \'b\'; Hash = \'BB\' }',
	'\t)) { $vector }',
	'\t[void](New-Thing @(',
	'\t\t\'#_if PSEXE\'',
	'\t\t\'#_else\'',
	'\t\t\'#_endif\'',
	'\t) \'C:\\compiled\\main.ps1\')',
	'\t$output = @(foreach ($item in $raw) {',
	'\t\tif ($item -is [System.Management.Automation.PSObject]) { $item.PSObject.BaseObject } else { $item }',
	'\t})',
	'\tWrite-Host ("{0}" -f `',
	'\t\t$first, $second)',
	'\t#_if PSScript',
	'\t$direct = 1',
	'\t#_endif',
	'}'
].join('\n')

/**
 * 加载工作区目标文件的文本与格式化设置。
 *
 * @param {string} relativePath - 相对路径
 * @returns {{ text: string, indentUnit: string, settings: object } | undefined} 目标数据，文件不存在时返回空
 */
function loadWorkspaceTarget(relativePath) {
	const file = path.join(REPO_ROOT, relativePath)
	if (!fs.existsSync(file)) return undefined
	const { overrides, insertSpaces, tabSize } = readWorkspaceFormatting(REPO_ROOT)
	return {
		text: fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''),
		indentUnit: insertSpaces ? ' '.repeat(tabSize) : '\t',
		settings: buildSettings({ overrides, insertSpaces, tabSize })
	}
}

/**
 * 取出测试所需的 PowerShell 主机、目标文件与设置；缺任何一项都会跳过当前用例（测试机可能既没有 pwsh 也没有该文件）。
 *
 * @param {object} context - mocha 用例上下文（用于 `this.skip()`）
 * @param {string} relativePath - 相对仓库根的目标文件
 * @returns {Promise<{ host: object, target: { text: string, indentUnit: string, settings: object } } | undefined>} 运行数据，缺依赖时为 undefined
 */
async function resolveTarget(context, relativePath) {
	const host = await resolvePlainPowerShell()
	const target = host && loadWorkspaceTarget(relativePath)
	if (!host || !target) {
		context.skip()
		return undefined
	}
	return { host, target }
}

suite('ps12exe formatter', () => {
	for (const relativePath of WORKSPACE_TARGETS)
		test(`formatting ${relativePath} is a no-op and idempotent`, async function () {
			this.timeout(120000)
			const resolved = await resolveTarget(this, relativePath)
			if (!resolved) return
			const { host, target } = resolved

			const official = await formatWithOfficialFormatter({ host, text: target.text, settings: target.settings })
			if (!official.available) this.skip()

			const once = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit, originalText: target.text })
			assert.strictEqual(once, target.text, `formatting ${relativePath} must not change it`)

			const officialAgain = await formatWithOfficialFormatter({ host, text: once, settings: target.settings })
			if (!officialAgain.available) this.skip()
			const twice = await formatPreprocessedText(officialAgain.text, { indentUnit: target.indentUnit, originalText: once })
			assert.strictEqual(twice, once, `formatting ${relativePath} twice must equal formatting it once`)
		})

	test('keeps the continuation shapes the official formatter flattens', async function () {
		// 官方 formatter 会压平管道/成员访问续行、把括号里的 scriptblock/hashtable/数组多缩进一层（见 `restoreParenIndentation`
		// 记录的 issue），并把看起来像指令的字符串当指令。这些都是仓库自身的写法，必须原样保留。
		this.timeout(120000)
		const resolved = await resolveTarget(this, 'ps12exe.ps1')
		if (!resolved) return
		const { host, target } = resolved
		const fixture = target.indentUnit === '\t' ? CONSTRUCT_FIXTURE : CONSTRUCT_FIXTURE.replace(/\t/g, target.indentUnit)

		const official = await formatWithOfficialFormatter({ host, text: fixture, settings: target.settings })
		if (!official.available) this.skip()
		const formatted = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit, originalText: fixture })
		assert.strictEqual(formatted, fixture)
	})

	test('realigns over-indented pipe and member-access continuations', async function () {
		// 作者把续行多缩进几层时，格式化应当把它收回「语句 + 1 层」；平铺到语句同级的续行（PSSA 的 NoIndentation 与有意的扁平风格同形）不动。
		this.timeout(120000)
		const resolved = await resolveTarget(this, 'ps12exe.ps1')
		if (!resolved) return
		const { host, target } = resolved

		const input = [
			'function Invoke-Sample {',
			'\tGet-ChildItem -LiteralPath $Root -Force |',
			'\t\t\tWhere-Object { $_ } |',
			'\t\t\tForEach-Object { $_ }',
			'\t$x = (Get-Content $path).',
			'\t\t\tReplace("a", $b)',
			'}'
		].join('\n')
		const expected = [
			'function Invoke-Sample {',
			'\tGet-ChildItem -LiteralPath $Root -Force |',
			'\t\tWhere-Object { $_ } |',
			'\t\tForEach-Object { $_ }',
			'\t$x = (Get-Content $path).',
			'\t\tReplace("a", $b)',
			'}'
		].join('\n')

		const official = await formatWithOfficialFormatter({ host, text: input, settings: target.settings })
		if (!official.available) this.skip()
		const formatted = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit, originalText: input })
		assert.strictEqual(formatted, expected)
	})

	test('preserves the nesting of #_!! escapes inside a block', async function () {
		// 官方 formatter 把 `#_!!` 当注释、压平整段；`#_!!` 展开后是真实代码，嵌套必须保留。
		this.timeout(120000)
		const resolved = await resolveTarget(this, 'ps12exe.ps1')
		if (!resolved) return
		const { host, target } = resolved

		const text = [
			'function f {',
			'\t#_if PSEXE',
			'\t\t#_!! if ($a) {',
			'\t\t\t#_!! foo',
			'\t\t#_!! }',
			'\t#_else',
			'\t\tbar',
			'\t#_endif',
			'}'
		].join('\n')

		const official = await formatWithOfficialFormatter({ host, text, settings: target.settings })
		if (!official.available) this.skip()
		const formatted = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit, originalText: text })
		assert.strictEqual(formatted, text)
	})

	test('skips the preprocessor indentation when the official formatter did not run', async () => {
		// 没有官方 formatter 时，基准就是文档本身，它已经带有 preprocessor 缩进；再次应用规则会导致每次格式化叠加一层。
		const current = ['if (', '\t#_if PSEXE', '\t#_!! x -or', '\t#_endif', '\ty', ') {'].join('\n')
		const staleBase = current.replace(/\t/g, '\t\t')
		assert.strictEqual(
			await applyPreprocessorFormatting(current, staleBase, false, { indentUnit: '\t' }),
			current
		)
	})
})
