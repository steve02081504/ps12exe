// ps12exe preprocessor 指令的悬浮提示支持：本地化的说明，以及指向该区域 README 中对应「预处理」小节的链接。
//
// 每个指令映射到 README 的一个小节。所有区域的 README（docs/README_*）都在小节旁埋了统一的显式锚点（`<a id="preprocessing-…">`），因此链接不依赖各语言标题自动生成的锚点，切换语言也不会失效。`#_DllExport` 未在 README 中单独记录，回退到「预处理」概览小节。

/** 各区域 README 所在的 GitHub 地址前缀。 */
const README_BASE = 'https://github.com/steve02081504/ps12exe/blob/master/docs/'

/** ps12exe 区域代码 -> README 文件名。 */
const README_FILES = Object.freeze({
	'en-US': 'README_EN_US.md',
	'en-UK': 'README_EN_UK.md',
	'zh-CN': 'README_CN.md',
	'ja-JP': 'README_JP.md',
	'fr-FR': 'README_FR.md',
	'es-ES': 'README_ES.md',
	'hi-IN': 'README_HI.md'
})

/** 小节键（同时也是 `HOVER_MESSAGES` 的键）-> README 中统一的显式锚点。 */
const SECTION_ANCHORS = Object.freeze({
	if: 'preprocessing-if',
	include: 'preprocessing-include',
	includeAs: 'preprocessing-include-as',
	bang: 'preprocessing-bang',
	require: 'preprocessing-require',
	pragma: 'preprocessing-pragma',
	balus: 'preprocessing-balus',
	psexe: 'preprocessing-if',
	psscript: 'preprocessing-if',
	dllExport: 'preprocessing-overview'
})

/** 指令名（小写）-> README 小节键（同时也是 `HOVER_MESSAGES` 的键）。 */
const DIRECTIVE_SECTIONS = Object.freeze({
	if: 'if',
	else: 'if',
	endif: 'if',
	include: 'include',
	include_as_value: 'include',
	include_as_base64: 'includeAs',
	include_as_bytes: 'includeAs',
	'!!': 'bang',
	require: 'require',
	pragma: 'pragma',
	balus: 'balus',
	dllexport: 'dllExport'
})

/** 英文源字符串；它们同时也是 l10n bundle 的键。 */
export const HOVER_MESSAGES = Object.freeze({
	if: '`#_if <condition>` / `#_else` / `#_endif` — conditional preprocessing. `PSEXE` is true while compiling; `PSScript` is false.',
	include: '`#_include <filename|url>` inserts a file (which is preprocessed) here; `#_include_as_value <valuename> <file|url>` inserts it as a string value (not preprocessed).',
	includeAs: '`#_include_as_base64 <valuename> <file|url>` / `#_include_as_bytes <valuename> <file|url>` insert a file as a base64 string or a byte array.',
	bang: '`#_!!` is an escape marker: it is stripped from the line, so the line is a comment when run directly and real code in the compiled EXE.',
	require: '`#_require <modulesList>` installs the listed PowerShell modules before the script runs; it installs but does not import them.',
	pragma: '`#_pragma <name> [value]` sets a compilation parameter such as `App.Windowed`, `Resources.Icon` or `Resources.Title` without modifying the script.',
	balus: '`#_balus <exitcode>` exits the process with the given exit code and deletes the compiled EXE.',
	psexe: '`PSEXE` — the condition is true while ps12exe compiles the script, so this branch is kept in the compiled EXE.',
	psscript: '`PSScript` — the condition is false while ps12exe compiles the script, so this branch is only kept when the script runs directly as a `.ps1`.',
	dllExport: '`#_DllExport <signature>` exports a PowerShell function from the compiled assembly; this macro is still experimental and undocumented.',
	requireRepository: 'Repository',
	requireGallery: 'PowerShell Gallery',
	requireTags: 'Tags',
	requireNotFound: 'No module named `{0}` was found on the PowerShell Gallery.',
	more: 'Read more in the ps12exe README'
})

// 带边界的关键字指令（`#_if`、`#_include_as_value` …）；`\b` 提供边界，因此 `#_iffy` 或 `#_include_other` 这类未知指令不会被误认。
const WORD_DIRECTIVE_RE = /^([\t ]*)#_(if|else|endif|include_as_base64|include_as_bytes|include_as_value|include|require|pragma|DllExport|balus)\b/
// `#_!!` 后紧跟任意代码（`#_!!if`），因此单独匹配且不加边界。
const BANG_DIRECTIVE_RE = /^([\t ]*)#_(!!)/
// `#_if <condition>` 的已知条件（预处理器只支持这两个）；`\b` 保证 `PSEXEfoo` 之类的未知词不会被误认。
const IF_CONDITION_RE = /^([\t ]*)#_if[\t ]+(PSEXE|PSScript)\b/

/**
 * 返回 `line` 上 `character` 列处的 preprocessor 指令。
 *
 * @param {string} line - 待检查的脚本行
 * @param {number} character - 光标所在的列号
 * @returns {{ name: string, section: string, start: number, end: number } | null} `start`/`end` 是含 `#_` 标记的区间（从零开始、含末尾）
 */
export function directiveAt (line, character) {
	const word = WORD_DIRECTIVE_RE.exec(line)
	if (word) {
		const start = word[1].length
		const end = start + 2 + word[2].length
		if (character >= start && character <= end) {
			const name = word[2].toLowerCase()
			const section = DIRECTIVE_SECTIONS[name]
			if (section) return { name, section, start, end }
		}
	}

	const bang = BANG_DIRECTIVE_RE.exec(line)
	if (bang) {
		const start = bang[1].length
		const end = start + 4
		if (character >= start && character <= end) return { name: '!!', section: 'bang', start, end }
	}

	return null
}

/**
 * 返回 `#_if` 行上 `character` 列处的条件关键字（`PSEXE` 或 `PSScript`）。
 *
 * @param {string} line - 待检查的脚本行
 * @param {number} character - 光标所在的列号
 * @returns {{ name: string, section: string, start: number, end: number } | null} `start`/`end` 是条件关键字的区间（从零开始、含末尾）
 */
export function conditionAt (line, character) {
	const match = IF_CONDITION_RE.exec(line)
	if (!match) return null
	const start = match[0].length - match[2].length
	const end = start + match[2].length
	if (character < start || character > end) return null
	return { name: match[2], section: match[2] === 'PSEXE' ? 'psexe' : 'psscript', start, end }
}

/**
 * 返回某个区域 README 中对应小节的链接；未知区域回退到 en-UK（与官网语言重定向页一致），未知小节回退到「预处理」概览小节。
 *
 * @param {string | undefined} locale ps12exe 区域代码（见 `toPs12exeLocale`）
 * @param {string} section `HOVER_MESSAGES` 的小节键
 * @returns {string} 对应小节的文档链接
 */
export function documentationUrl (locale, section) {
	const region = README_FILES[locale] ? locale : 'en-UK'
	const anchor = SECTION_ANCHORS[section] || SECTION_ANCHORS.dllExport
	return `${README_BASE}${README_FILES[region]}#${anchor}`
}
