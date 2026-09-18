import assert from 'node:assert'
import { HOVER_MESSAGES, directiveAt, documentationUrl } from '../lib/hover.mjs'

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
