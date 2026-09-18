/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { HOVER_MESSAGES, directiveAt, conditionAt, documentationUrl } from '../lib/hover.mjs'
import { pragmaNameAt, lookupPragma, buildPragmaCandidates } from '../lib/pragma.mjs'
import { requireModulesAt } from '../lib/require.mjs'

const README_BASE = 'https://github.com/steve02081504/ps12exe/blob/master/docs/'

suite('ps12exe directive hover', () => {
	test('detects every supported directive at the cursor', () => {
		const cases = [
			['#_if PSEXE', 'if', '#_if'],
			['\t#_else # comment', 'if', '#_else'],
			['#_endif', 'if', '#_endif'],
			['#_include lib/helper.ps1', 'include', '#_include'],
			['#_include_as_value data $PSScriptRoot/data.bin', 'include', '#_include_as_value'],
			['#_include_as_base64 blob "assets/data.bin"', 'includeAs', '#_include_as_base64'],
			['#_include_as_bytes blob "assets/data.bin"', 'includeAs', '#_include_as_bytes'],
			['#_!!if ($x) {', 'bang', '#_!!'],
			['#_require ps12exe', 'require', '#_require'],
			['#_pragma App.Windowed no', 'pragma', '#_pragma'],
			['#_balus 1', 'balus', '#_balus'],
			['#_DllExport int Add(int a, int b)', 'dllExport', '#_DllExport']
		]

		for (const [line, section, token] of cases) {
			const indent = line.length - line.trimStart().length
			const found = directiveAt(line, indent + 1)
			assert.ok(found, `no directive detected in ${JSON.stringify(line)}`)
			assert.strictEqual(found.section, section)
			assert.strictEqual(line.slice(found.start, found.end), token)
		}
	})

	test('ignores the cursor outside the directive and unknown directives', () => {
		assert.strictEqual(directiveAt('#_if PSEXE', 20), null)
		assert.strictEqual(directiveAt('Write-Output "#_if"', 3), null)
		assert.strictEqual(directiveAt('#_iffy x', 2), null)
		assert.strictEqual(directiveAt('#_include_other x', 2), null)
		assert.strictEqual(directiveAt('', 0), null)
	})

	test('detects the condition keyword of an #_if line', () => {
		const cases = [
			['#_if PSEXE', 'PSEXE', 'psexe'],
			['\t#_if PSScript # comment', 'PSScript', 'psscript'],
			['#_if   PSEXE', 'PSEXE', 'psexe']
		]

		for (const [line, name, section] of cases) {
			const start = line.indexOf(name)
			for (let character = start; character <= start + name.length; character++) {
				const found = conditionAt(line, character)
				assert.ok(found, `no condition detected in ${JSON.stringify(line)} at ${character}`)
				assert.strictEqual(found.name, name)
				assert.strictEqual(found.section, section)
				assert.strictEqual(found.start, start)
				assert.strictEqual(found.end, start + name.length)
				assert.strictEqual(line.slice(found.start, found.end), name)
			}
		}
	})

	test('ignores the cursor outside the condition and unknown conditions', () => {
		assert.strictEqual(conditionAt('#_if PSEXE', 4), null)
		assert.strictEqual(conditionAt('#_if PSEXE', 11), null)
		assert.strictEqual(conditionAt('#_if Unknown', 5), null)
		assert.strictEqual(conditionAt('#_if PSEXEfoo', 5), null)
		assert.deepStrictEqual(conditionAt('#_if PSEXE # comment', 5), { name: 'PSEXE', section: 'psexe', start: 5, end: 10 })
		assert.strictEqual(conditionAt('Write-Output "#_if PSEXE"', 13), null)
		assert.strictEqual(conditionAt('#_endif', 5), null)
		assert.strictEqual(conditionAt('', 0), null)
	})

	test('links to the uniform anchor in the matching localized README', () => {
		assert.strictEqual(documentationUrl('en-US', 'if'), `${README_BASE}README_EN_US.md#preprocessing-if`)
		assert.strictEqual(documentationUrl('en-UK', 'include'), `${README_BASE}README_EN_UK.md#preprocessing-include`)
		assert.strictEqual(documentationUrl('zh-CN', 'includeAs'), `${README_BASE}README_CN.md#preprocessing-include-as`)
		assert.strictEqual(documentationUrl('ja-JP', 'require'), `${README_BASE}README_JP.md#preprocessing-require`)
		assert.strictEqual(documentationUrl('fr-FR', 'pragma'), `${README_BASE}README_FR.md#preprocessing-pragma`)
		assert.strictEqual(documentationUrl('es-ES', 'balus'), `${README_BASE}README_ES.md#preprocessing-balus`)
		assert.strictEqual(documentationUrl('hi-IN', 'bang'), `${README_BASE}README_HI.md#preprocessing-bang`)
		assert.strictEqual(documentationUrl('unknown', 'pragma'), `${README_BASE}README_EN_UK.md#preprocessing-pragma`)
		assert.strictEqual(documentationUrl(undefined, 'dllExport'), `${README_BASE}README_EN_UK.md#preprocessing-overview`)
	})

	test('every hover section has a documentation link', () => {
		for (const section of Object.keys(HOVER_MESSAGES)) {
			if (section === 'more') continue
			assert.match(documentationUrl('en-US', section), /#preprocessing-[\w-]+$/, `missing anchor for ${section}`)
		}
	})
})

suite('ps12exe pragma names', () => {
	const line = '\t#_pragma App.Windowed $false'
	const nameStart = line.indexOf('App')

	test('detects the pragma name under the cursor', () => {
		for (let character = nameStart; character <= nameStart + 'App.Windowed'.length; character++) {
			const found = pragmaNameAt(line, character)
			assert.ok(found, `no pragma name at column ${character}`)
			assert.strictEqual(found.name, 'App.Windowed')
			assert.strictEqual(found.start, nameStart)
			assert.strictEqual(found.end, nameStart + 'App.Windowed'.length)
			assert.strictEqual(line.slice(found.start, found.end), 'App.Windowed')
		}
	})

	test('ignores the cursor on #_pragma itself or an unrelated line', () => {
		assert.strictEqual(pragmaNameAt(line, nameStart - 1), null)
		assert.strictEqual(pragmaNameAt(line, line.length), null)
		assert.strictEqual(pragmaNameAt('#_pragma   ', 11), null)
		assert.strictEqual(pragmaNameAt('Write-Output "#_pragma App"', 3), null)
	})

	test('resolves a pragma description, including the no prefix', () => {
		const data = new Map([
			['app.windowed', { name: 'App.Windowed', description: 'windowed' }],
			['golf', { name: 'Golf', description: 'golf' }]
		])
		assert.deepStrictEqual(lookupPragma(data, 'App.Windowed'), { name: 'App.Windowed', description: 'windowed', negated: false })
		assert.deepStrictEqual(lookupPragma(data, 'app.windowed'), { name: 'App.Windowed', description: 'windowed', negated: false })
		assert.deepStrictEqual(lookupPragma(data, 'noGolf'), { name: 'Golf', description: 'golf', negated: true })
		assert.strictEqual(lookupPragma(data, 'Unknown'), null)
	})

	test('lists top-level parameters, then the children of a dotted prefix', () => {
		const data = new Map([
			['app.windowed', { name: 'App.Windowed', description: 'windowed' }],
			['app.silence', { name: 'App.Silence', description: 'silence' }],
			['build.target', { name: 'Build.Target', description: 'target' }],
			['golf', { name: 'Golf', description: 'golf' }]
		])

		const top = buildPragmaCandidates(data, '')
		assert.deepStrictEqual(top.map((candidate) => candidate.insertText), ['App.', 'Build.', 'Golf'])
		assert.strictEqual(top.find((candidate) => candidate.name === 'App').kind, 'object')
		assert.strictEqual(top.find((candidate) => candidate.name === 'Golf').kind, 'value')

		const nested = buildPragmaCandidates(data, 'App.Win')
		assert.deepStrictEqual(nested.map((candidate) => candidate.insertText), ['App.Windowed'])

		const exact = buildPragmaCandidates(data, 'app.sil')
		assert.deepStrictEqual(exact.map((candidate) => candidate.name), ['App.Silence'])
	})
})

suite('ps12exe require modules', () => {
	test('detects every module separated by the characters the compiler accepts', () => {
		const line = '\t#_require module1 module2,module3;module4|module5、module6　module7'
		for (const name of ['module1', 'module2', 'module3', 'module4', 'module5', 'module6', 'module7']) {
			const start = line.indexOf(name)
			for (let character = start; character <= start + name.length; character++) {
				const found = requireModulesAt(line, character)
				assert.ok(found, `no module detected at column ${character}`)
				assert.strictEqual(found.name, name)
				assert.strictEqual(found.start, start)
				assert.strictEqual(found.end, start + name.length)
			}
		}
	})

	test('strips surrounding quotes and ignores the trailing comment', () => {
		const line = '#_require "Pester" \'PSReadLine\' # not-a-module'
		const quoted = line.indexOf('"Pester"')
		assert.deepStrictEqual(requireModulesAt(line, line.indexOf('Pester')), { name: 'Pester', start: quoted, end: quoted + 8 })
		assert.strictEqual(requireModulesAt(line, line.indexOf('PSReadLine')).name, 'PSReadLine')
		assert.strictEqual(requireModulesAt(line, line.indexOf('not-a-module')), null)
	})

	test('ignores the directive itself and unrelated lines', () => {
		assert.strictEqual(requireModulesAt('#_require', 3), null)
		assert.strictEqual(requireModulesAt('#_require   ', 12), null)
		assert.strictEqual(requireModulesAt('#_pragma App.Windowed', 10), null)
		assert.strictEqual(requireModulesAt('Write-Output "#_require Pester"', 20), null)
		assert.strictEqual(requireModulesAt('', 0), null)
	})
})
