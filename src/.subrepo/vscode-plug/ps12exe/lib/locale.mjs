/**
 * 把 `vscode.env.language` 报告的语言映射为 ps12exe/ps12exeGUI 能识别的区域代码（`-Locale`）。
 *
 * ps12exe 附带以下区域：
 *   en-UK, en-US, es-ES, fr-FR, hi-IN, ja-JP, zh-CN
 */
export const PS12EXE_LOCALES = Object.freeze({
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
 * @param {string | undefined} language `vscode.env.language` 的值
 * @returns {string | undefined} ps12exe 接受的区域代码
 */
export function toPs12exeLocale(language) {
	if (!language) return undefined
	// 未知区域会原样传递：ps12exe 会回退到匹配的区域前缀（例如 `pt` -> 无匹配，然后是 en-UK），而不是失败。
	return PS12EXE_LOCALES[language.toLowerCase()] || language
}
