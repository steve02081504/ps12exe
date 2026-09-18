// The pure (VS Code independent) half of the ps12exe formatter: everything that
// happens after the official PowerShell formatter has produced a base text.
// Keeping it here lets the tests exercise the exact pipeline without a running
// editor instance.
import { createHash } from 'node:crypto'
import { analyze, indentText, branchFragments, restoreParenIndentation, restoreClauseIndentation } from './preprocessor.mjs'
import { resolvePlainPowerShell, findIncompleteFragments } from './powershell.mjs'

const INCOMPLETE_CACHE_LIMIT = 32
/** @type {Map<string, Set<number>>} */
const incompleteCache = new Map()

/**
 * Finds the blocks whose body cannot be parsed as a standalone PowerShell unit
 * (for example an `if` opened inside the block and closed outside of it). Such
 * blocks must not be pushed one level deeper, otherwise their body drifts away
 * from the code that continues past `#_endif`.
 *
 * The check uses the real PowerShell parser; when no host is available nothing
 * is flagged. Results are cached per document text.
 *
 * @param {string} text
 * @param {(message: string) => void} [onError]
 * @returns {Promise<Set<number>>}
 */
async function findIncompleteBlocks (text, onError) {
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
		if (onError) onError(`ps12exe: could not check preprocessor blocks for completeness: ${error && error.message ? error.message : error}`)
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
 * Applies the ps12exe formatting rules to `baseText` (the text produced by the
 * official formatter, or the original document when it is unavailable):
 * repairs the official formatter's attribute/scriptblock quirk and then indents
 * the preprocessor blocks.
 *
 * @param {string} baseText
 * @param {object} [options]
 * @param {string} [options.indentUnit] defaults to a tab
 * @param {(message: string) => void} [options.onError]
 * @returns {Promise<string>}
 */
async function formatPreprocessedText (baseText, options = {}) {
	const indentUnit = options.indentUnit || '\t'
	let styled = restoreParenIndentation(baseText, indentUnit)
	styled = restoreClauseIndentation(styled)
	const incomplete = await findIncompleteBlocks(styled, options.onError)
	return indentText(styled, { indentUnit, incompleteBlocks: incomplete })
}

/**
 * Formats `currentText` from `baseText`, which must be the official formatter's
 * output. The preprocessor indentation is layered on top of the syntax
 * indentation the official formatter produces, so it can only be applied to
 * that base.
 *
 * When the official formatter is unavailable, `baseText` would be the document
 * itself, which already carries the preprocessor indentation of a previous run.
 * Applying the rules again would then compound one level per format, so the
 * document is returned unchanged instead.
 *
 * @param {string} currentText the document as it is now
 * @param {string} baseText the text `formatPreprocessedText` runs on
 * @param {boolean} officialApplied whether `baseText` came from the official formatter
 * @param {object} [options] forwarded to {@link formatPreprocessedText}
 * @returns {Promise<string>}
 */
async function applyPreprocessorFormatting (currentText, baseText, officialApplied, options = {}) {
	if (!officialApplied) return currentText
	return formatPreprocessedText(baseText, options)
}

export { findIncompleteBlocks, formatPreprocessedText, applyPreprocessorFormatting }
