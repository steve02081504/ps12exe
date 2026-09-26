// ps12exe formatter 中与 VS Code 无关的纯逻辑部分：官方 PowerShell formatter 生成基础文本之后发生的所有事情。放在这里能让测试在没有运行中编辑器实例的情况下走完整条流水线。
import { createHash } from 'node:crypto'

import { resolvePlainPowerShell, findIncompleteFragments } from './powershell.mjs'
import { analyze, indentText, branchFragments, restoreParenIndentation, restoreClauseIndentation, restoreMarkerIndentation } from './preprocessor.mjs'

const INCOMPLETE_CACHE_LIMIT = 32
/** @type {Map<string, Set<number>>} */
const incompleteCache = new Map()

/**
 * 找出函数体无法作为独立 PowerShell 单元解析的块（例如在块内打开、在块外关闭的 `if`）。这类块绝不能整体缩进一层，否则其函数体会偏离 `#_endif` 之后继续的代码。
 *
 * 该检查使用真正的 PowerShell 解析器；没有可用宿主时不会标记任何内容。结果按文档文本缓存。
 *
 * @param {string} text - 待检查的文档全文
 * @param {(message: string) => void} [onError] - 出错时的回调
 * @returns {Promise<Set<number>>} 不完整块的索引集合
 */
export async function findIncompleteBlocks(text, onError) {
	const { blocks, lines } = analyze(text)
	const fragments = branchFragments(blocks, lines)
	if (!fragments.length) return new Set()

	const key = createHash('sha1').update(text).digest('hex')
	const cached = incompleteCache.get(key)
	if (cached) return cached

	const host = await resolvePlainPowerShell()
	if (!host) return new Set()

	let flags
	try {
		flags = await findIncompleteFragments({ host, texts: fragments.map((fragment) => fragment.text) })
	}
	catch (error) {
		if (onError) onError(`ps12exe: could not check preprocessor blocks for completeness: ${error?.message || error}`)
		return new Set()
	}

	const incomplete = new Set()
	fragments.forEach((fragment, index) => {
		if (flags[index]) incomplete.add(fragment.block)
	})
	incompleteCache.set(key, incomplete)
	if (incompleteCache.size > INCOMPLETE_CACHE_LIMIT) incompleteCache.delete(incompleteCache.keys().next().value)
	return incomplete
}

/**
 * 对 `baseText`（官方 formatter 产生的文本，若其不可用则为原始文档）应用 ps12exe 格式化规则：修复官方 formatter 的 attribute/scriptblock 怪癖，然后缩进 preprocessor 块。
 *
 * @param {string} baseText - 官方 formatter 产生的文本
 * @param {object} [options] - 格式化选项
 * @param {string} [options.indentUnit] 默认为制表符
 * @param {string} [options.originalText] 官方 formatter 之前的文档；提供时用它还原 `#_!!`/`#_balus` 行的嵌套缩进
 * @param {(message: string) => void} [options.onError] - 出错时的回调
 * @returns {Promise<string>} 格式化后的文本
 */
export async function formatPreprocessedText(baseText, options = {}) {
	const indentUnit = options.indentUnit || '\t'
	const styled = restoreClauseIndentation(restoreParenIndentation(baseText, indentUnit))
	const incomplete = await findIncompleteBlocks(styled, options.onError)
	const indented = indentText(styled, { indentUnit, incompleteBlocks: incomplete })
	if (!options.originalText) return indented
	return restoreMarkerIndentation(indented, options.originalText)
}

/**
 * 基于 `baseText`（必须是官方 formatter 的输出）格式化 `currentText`。preprocessor 缩进叠加在官方 formatter 产生的语法缩进之上，因此只能应用于该基础文本。
 *
 * 当官方 formatter 不可用时，`baseText` 会是文档本身，而它已带有上一次运行的 preprocessor 缩进。再次应用规则会导致每次格式化都多缩进一层，因此改为原样返回文档。
 *
 * @param {string} currentText 当前状态的文档
 * @param {string} baseText `formatPreprocessedText` 运行所基于的文本
 * @param {boolean} officialApplied `baseText` 是否来自官方 formatter
 * @param {object} [options] 转发给 {@link formatPreprocessedText}
 * @returns {Promise<string>} 格式化后的文档文本
 */
export async function applyPreprocessorFormatting(currentText, baseText, officialApplied, options = {}) {
	return officialApplied ? formatPreprocessedText(baseText, { ...options, originalText: currentText }) : currentText
}
