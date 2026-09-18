import assert from 'node:assert'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { resolvePlainPowerShell } from '../lib/powershell.mjs'
import { formatPreprocessedText, applyPreprocessorFormatting } from '../lib/format.mjs'
import { buildSettings, readWorkspaceFormatting, formatWithOfficialFormatter } from './officialFormatter.mjs'

// The extension lives at <repo>/src/.subrepo/vscode-plug/ps12exe, so this test
// file sits five levels below the ps12exe repository root.
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..', '..')

// The repository's own scripts are formatted by this extension, so formatting
// them with the workspace style must be a byte-for-byte no-op. `ps12exe.ps1` is
// the packaged script; `src/CodeDomCompiler.ps1` is the one whose `if (` +
// preprocessor-continuation block caught the directive mis-alignment.
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
		// Without the official formatter the base is the document itself, which
		// already carries the preprocessor indentation; applying the rules again
		// would compound one level per format.
		const current = ['if (', '\t#_if PSEXE', '\t#_!! x -or', '\t#_endif', '\ty', ') {'].join('\n')
		const staleBase = current.replace(/\t/g, '\t\t')
		assert.strictEqual(
			await applyPreprocessorFormatting(current, staleBase, false, { indentUnit: '\t' }),
			current
		)
	})
})
