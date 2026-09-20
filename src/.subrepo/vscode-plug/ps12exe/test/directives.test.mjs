/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { DIRECTIVE_COMPLETIONS, CONDITION_COMPLETIONS, buildDirectiveCandidates, directiveAvailability, directivePrefixAt, ifConditionPrefixAt, buildConditionCandidates } from '../lib/directives.mjs'
import { HOVER_MESSAGES, documentationUrl } from '../lib/hover.mjs'
import { analyze } from '../lib/preprocessor.mjs'

suite('ps12exe directive completion', () => {
	test('detects the `#_` prefix at the start of a comment line', () => {
		assert.deepStrictEqual(directivePrefixAt('#_'), { start: 0, prefix: '#_' })
		assert.deepStrictEqual(directivePrefixAt('\t#_inc'), { start: 1, prefix: '#_inc' })
		assert.deepStrictEqual(directivePrefixAt('  #_!!'), { start: 2, prefix: '#_!!' })

		// 只接受尚未出现参数的指令名：参数一旦开始（空格、`#_pragma ` 之后）就交给各自的处理器。
		assert.strictEqual(directivePrefixAt(''), null)
		assert.strictEqual(directivePrefixAt('#'), null)
		assert.strictEqual(directivePrefixAt('# comment'), null)
		assert.strictEqual(directivePrefixAt('#_if PSEXE'), null)
		assert.strictEqual(directivePrefixAt('#_pragma '), null)
		assert.strictEqual(directivePrefixAt('Write-Output "#_"'), null)
	})

	test('lists every directive and filters by the typed prefix in a stable order', () => {
		const all = buildDirectiveCandidates('#_')
		assert.strictEqual(all.length, DIRECTIVE_COMPLETIONS.length)
		assert.deepStrictEqual(all.map((entry) => entry.label), DIRECTIVE_COMPLETIONS.map((entry) => entry.label))

		assert.deepStrictEqual(buildDirectiveCandidates('#_i').map((entry) => entry.label), [
			'#_if',
			'#_include',
			'#_include_as_value',
			'#_include_as_base64',
			'#_include_as_bytes'
		])
		assert.deepStrictEqual(buildDirectiveCandidates('#_include').map((entry) => entry.label), [
			'#_include',
			'#_include_as_value',
			'#_include_as_base64',
			'#_include_as_bytes'
		])
		assert.deepStrictEqual(buildDirectiveCandidates('#_!').map((entry) => entry.label), ['#_!!'])
		assert.deepStrictEqual(buildDirectiveCandidates('#_dll').map((entry) => entry.label), ['#_DllExport'])
		assert.deepStrictEqual(buildDirectiveCandidates('#_nope'), [])
	})

	test('computes what the block structure allows at the cursor', () => {
		const closed = ['#_if PSEXE', '$x = 1', '#_endif'].join('\n')
		// 光标在 #_if 与 #_endif 之间：可补 #_else，也可补 #_endif 闭合。
		assert.deepStrictEqual(directiveAvailability(analyze(closed).blocks, 1), { allowElse: true, allowEndIf: true })
		// 光标在 #_if 之前：没有打开的块。
		assert.deepStrictEqual(directiveAvailability(analyze(closed).blocks, 0), { allowElse: false, allowEndIf: false })

		// 已有 #_else：不能再插入第二个。
		const withElse = ['#_if PSEXE', '$x = 1', '#_else', '$y = 2', '#_endif'].join('\n')
		assert.deepStrictEqual(directiveAvailability(analyze(withElse).blocks, 3), { allowElse: false, allowEndIf: true })

		// 嵌套看最内层块；下面的 #_else 仍然属于内层，因此在其之前也不能再加 #_else。
		const nested = ['#_if PSEXE', '#_if PSScript', '$a = 1', '#_else', '$b = 2', '#_endif', '#_endif'].join('\n')
		assert.deepStrictEqual(directiveAvailability(analyze(nested).blocks, 2), { allowElse: false, allowEndIf: true })
		assert.deepStrictEqual(directiveAvailability(analyze(nested).blocks, 4), { allowElse: false, allowEndIf: true })

		// 内层没有 else 时允许，外层是否有 else 不影响。
		const nestedNoElse = ['#_if PSEXE', '#_if PSScript', '$a = 1', '#_endif', '#_endif'].join('\n')
		assert.deepStrictEqual(directiveAvailability(analyze(nestedNoElse).blocks, 2), { allowElse: true, allowEndIf: true })
	})

	test('drops #_else / #_endif when the context would make them stray or duplicate', () => {
		assert.deepStrictEqual(
			buildDirectiveCandidates('#_', { allowElse: false, allowEndIf: false }).map((entry) => entry.label),
			DIRECTIVE_COMPLETIONS.filter((entry) => entry.label !== '#_else' && entry.label !== '#_endif').map((entry) => entry.label)
		)
		assert.deepStrictEqual(
			buildDirectiveCandidates('#_e', { allowElse: true, allowEndIf: true }).map((entry) => entry.label),
			['#_else', '#_endif']
		)
		assert.deepStrictEqual(buildDirectiveCandidates('#_e', { allowElse: false, allowEndIf: true }).map((entry) => entry.label), ['#_endif'])
		assert.deepStrictEqual(buildDirectiveCandidates('#_e', { allowElse: true, allowEndIf: false }).map((entry) => entry.label), ['#_else'])
	})

	test('every directive carries a localized hint and a documentation link', () => {
		for (const entry of DIRECTIVE_COMPLETIONS) {
			assert.ok(HOVER_MESSAGES[entry.section], `missing hover message for ${entry.label}`)
			assert.match(documentationUrl('en-US', entry.section), /#preprocessing-[\w-]+$/, `missing anchor for ${entry.label}`)
			// 补全项插入的文本必须以展示的指令名开头，否则选中后会把输入替换成另一条指令。
			assert.ok(entry.insertText.startsWith(entry.label), `insertText of ${entry.label} does not start with its label`)
		}

		// `#_pragma` 必须补全为带尾随空格的形式，后续键入才会触发参数名补全。
		assert.strictEqual(buildDirectiveCandidates('#_pragma')[0].insertText, '#_pragma ')
	})

	test('detects the `#_if ` condition prefix', () => {
		assert.deepStrictEqual(ifConditionPrefixAt('#_if '), { start: 5, prefix: '' })
		assert.deepStrictEqual(ifConditionPrefixAt('\t#_if PSE'), { start: 6, prefix: 'PSE' })
		assert.deepStrictEqual(ifConditionPrefixAt('    #_if pss'), { start: 9, prefix: 'pss' })

		// 完整的条件关键字同样命中，候选会把整个词替换掉；尾随注释或多余内容出现后不再触发。
		assert.deepStrictEqual(ifConditionPrefixAt('#_if PSEXE'), { start: 5, prefix: 'PSEXE' })
		// 只在 `#_if` 与条件关键字之间；其他指令、已带尾随注释的行、以及光标不在条件上时都不触发。
		assert.strictEqual(ifConditionPrefixAt('#_if'), null)
		assert.strictEqual(ifConditionPrefixAt('#_if PSEXE # why'), null)
		assert.strictEqual(ifConditionPrefixAt('#_if PSEXE extra'), null)
		assert.strictEqual(ifConditionPrefixAt('#_endif '), null)
		assert.strictEqual(ifConditionPrefixAt('#_pragma '), null)
		assert.strictEqual(ifConditionPrefixAt('Write-Output "#_if "'), null)
		assert.strictEqual(ifConditionPrefixAt(''), null)
	})

	test('lists PSEXE and PSScript, filtered by the typed prefix', () => {
		assert.deepStrictEqual(buildConditionCandidates('').map((entry) => entry.label), ['PSEXE', 'PSScript'])
		assert.deepStrictEqual(buildConditionCandidates('ps').map((entry) => entry.label), ['PSEXE', 'PSScript'])
		assert.deepStrictEqual(buildConditionCandidates('psex').map((entry) => entry.label), ['PSEXE'])
		assert.deepStrictEqual(buildConditionCandidates('pss').map((entry) => entry.label), ['PSScript'])
		assert.deepStrictEqual(buildConditionCandidates('nope'), [])
	})

	test('every condition carries a localized hint and a documentation link', () => {
		for (const entry of CONDITION_COMPLETIONS) {
			assert.ok(HOVER_MESSAGES[entry.section], `missing hover message for ${entry.label}`)
			assert.match(documentationUrl('en-US', entry.section), /#preprocessing-[\w-]+$/, `missing anchor for ${entry.label}`)
			assert.strictEqual(entry.insertText, entry.label)
		}
	})

	test('declares which completions continue with another step', () => {
		// `#_if` 后接条件、`#_pragma ` 后接参数名；其余指令没有可自动弹出的后续补全。
		assert.strictEqual(DIRECTIVE_COMPLETIONS.find((entry) => entry.label === '#_if').followUp, 'suggest')
		assert.strictEqual(DIRECTIVE_COMPLETIONS.find((entry) => entry.label === '#_pragma').followUp, 'suggest')
		for (const entry of DIRECTIVE_COMPLETIONS) 
			if (entry.label !== '#_if' && entry.label !== '#_pragma') assert.strictEqual(entry.followUp, undefined, `${entry.label} unexpectedly declares a follow-up`)

		// 条件补全后换行，让 `#_if` 自动补出 `#_endif`。
		for (const entry of CONDITION_COMPLETIONS) assert.strictEqual(entry.followUp, 'newline')
	})
})
