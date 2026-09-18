/**
 * Maps the language reported by `vscode.env.language` to a locale code that
 * ps12exe/ps12exeGUI understands (`-Localize`).
 *
 * ps12exe ships the following locales:
 *   en-UK, en-US, es-ES, fr-FR, hi-IN, ja-JP, zh-CN
 */
const PS12EXE_LOCALES = Object.freeze({
	en: 'en-US',
	'en-us': 'en-US',
	'en-gb': 'en-UK',
	zh: 'zh-CN',
	'zh-cn': 'zh-CN',
	'zh-hans': 'zh-CN',
	ja: 'ja-JP',
	'ja-jp': 'ja-JP',
	fr: 'fr-FR',
	'fr-fr': 'fr-FR',
	es: 'es-ES',
	'es-es': 'es-ES',
	hi: 'hi-IN',
	'hi-in': 'hi-IN'
})

/**
 * @param {string | undefined} language value of `vscode.env.language`
 * @returns {string | undefined} locale code accepted by ps12exe
 */
function toPs12exeLocale (language) {
	if (!language) return undefined
	const key = String(language).toLowerCase()
	// Unknown locales are passed through: ps12exe falls back to a matching
	// locale prefix (e.g. `pt` -> nothing, then en-UK) instead of failing.
	return PS12EXE_LOCALES[key] || String(language)
}

export { toPs12exeLocale, PS12EXE_LOCALES }
