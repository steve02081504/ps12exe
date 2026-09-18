import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { resolvePlainPowerShell } from '../lib/powershell.mjs'
import { formatPreprocessedText, applyPreprocessorFormatting } from '../lib/format.mjs'
import { buildSettings, readWorkspaceFormatting, formatWithOfficialFormatter } from './officialFormatter.mjs'

// 该扩展位于 <repo>/src/.subrepo/vscode-plug/ps12exe，因此本测试文件位于 ps12exe 仓库根目录下五层。
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..', '..')

// 仓库自身的脚本由该扩展格式化，因此用工作区风格格式化它们必须是逐字节无操作。`ps12exe.ps1` 是打包脚本；`src/CodeDomCompiler.ps1` 则是其 `if (` + preprocessor 续行块触发指令错位的那一个。
const WORKSPACE_TARGETS = [
	'ps12exe.ps1',
	'src/CodeDomCompiler.ps1'
]

/** @returns {{ text: string, indentUnit: string, settings: object } | undefined} */
function loadWorkspaceTarget (relativePath) {
	const file = path.join(REPO_ROOT, relativePath)
	if (!fs.existsSync(file)) return undefined
	const { overrides, insertSpaces, tabSize } = readWorkspaceFormatting(REPO_ROOT)
	return {
		text: fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''),
		indentUnit: insertSpaces ? ' '.repeat(tabSize) : '\t',
		settings: buildSettings({ overrides, insertSpaces, tabSize })
	}
}

suite('ps12exe formatter', () => {
	for (const relativePath of WORKSPACE_TARGETS) {
		test(`formatting ${relativePath} is a no-op`, async function () {
			this.timeout(120000)
			const target = loadWorkspaceTarget(relativePath)
			if (!target) this.skip()
			const host = await resolvePlainPowerShell()
			if (!host) this.skip()

			const official = await formatWithOfficialFormatter({ host, text: target.text, settings: target.settings })
			if (!official.available) this.skip()

			const formatted = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit })
			assert.strictEqual(formatted, target.text, `formatting ${relativePath} must not change it`)
		})

		test(`formatting ${relativePath} is idempotent`, async function () {
			this.timeout(120000)
			const target = loadWorkspaceTarget(relativePath)
			if (!target) this.skip()
			const host = await resolvePlainPowerShell()
			if (!host) this.skip()

			const official = await formatWithOfficialFormatter({ host, text: target.text, settings: target.settings })
			if (!official.available) this.skip()

			const once = await formatPreprocessedText(official.text, { indentUnit: target.indentUnit })
			const officialAgain = await formatWithOfficialFormatter({ host, text: once, settings: target.settings })
			if (!officialAgain.available) this.skip()
			const twice = await formatPreprocessedText(officialAgain.text, { indentUnit: target.indentUnit })
			assert.strictEqual(twice, once)
		})
	}

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
