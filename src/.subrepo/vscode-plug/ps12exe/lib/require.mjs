// `#_require` 模块名的支持：解析光标所在行上的模块名，供悬浮提示（见 `lib/gallery.mjs`）定位要查询的模块。
//
// 模块名的分隔符与编译器保持一致（`src/ReadScriptFile.ps1` 的 `Split(', |;、　')`）：空格、逗号、竖线、
// 分号、中文顿号与全角空格。行尾第一个 `#` 起是注释（编译器的 `[^#]+` 同样在此截断），因此注释中的词不会
// 被当成模块名。

// 与编译器一致的 `#_require` 行；模块列表是行尾注释（`#`）之前、指令与空白之后的全部内容。
const REQUIRE_RE = /^([\t ]*)#_require[ \t]+(.*)$/
// 编译器的分隔字符集合。
const SEPARATOR_CHARS = ', |;、　'

/**
 * 判断一个字符是否为模块名分隔符。
 *
 * @param {string} character - 单个字符
 * @returns {boolean} 是分隔符时为真
 */
function isSeparator(character) {
	return SEPARATOR_CHARS.includes(character)
}

/**
 * 返回 `#_require` 行上的所有模块名与区间（按出现顺序）。非 `#_require` 行返回空数组。
 *
 * @param {string} line - 待检查的脚本行
 * @returns {Array<{ name: string, start: number, end: number }>} `name` 已去除两端引号；`start`/`end` 是含末尾的区间
 */
export function requireModules(line) {
	const match = REQUIRE_RE.exec(line)
	if (!match) return []

	const body = match[2]
	const listStart = match[0].length - body.length
	// 编译器在第一个 `#` 处截断模块列表，其后的内容都是注释。
	const commentAt = body.indexOf('#')
	const limit = commentAt >= 0 ? commentAt : body.length

	const modules = []
	let index = 0
	while (index < limit) {
		while (index < limit && isSeparator(body[index])) index++
		const start = index
		while (index < limit && !isSeparator(body[index])) index++
		if (start === index) break

		const name = body.slice(start, index).replace(/^['"]+|['"]+$/g, '')
		if (name) modules.push({ name, start: listStart + start, end: listStart + index })
	}

	return modules
}

/**
 * 返回 `#_require` 行上 `character` 列处的模块名与区间；光标不在任何模块名上时返回 `null`。
 *
 * @param {string} line - 待检查的脚本行
 * @param {number} character - 光标所在的列号
 * @returns {{ name: string, start: number, end: number } | null} `name` 已去除两端引号；`start`/`end` 是含末尾的区间
 */
export function requireModulesAt(line, character) {
	return requireModules(line).find((module) => character >= module.start && character <= module.end) || null
}
