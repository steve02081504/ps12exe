// 输入 `#_` 后补全 ps12exe 预处理器指令的支持。指令清单与悬浮提示（`lib/hover.mjs`）共用同一套 `section` 映射，
// 因此补全项的说明文字、README 链接与悬浮提示始终一致，不会各自漂移。
//
// 说明与链接的本地化复用 `HOVER_MESSAGES` 与 `documentationUrl`；补全项自身的 `detail` 由调用方本地化。

/**
 * 键入 `#_` 后可补全的预处理器指令，顺序即候选列表的展示顺序（`#_include*` 这类语义相近的指令相邻）。
 * `insertText` 末尾带空格表示该指令需要参数；`section` 是 `lib/hover.mjs` 的 `HOVER_MESSAGES` / README 小节键。
 * `followUp` 声明补全后接续的动作：`suggest` 立即再弹一次补全（`#_if` 后接条件、`#_pragma ` 后接参数名），
 * 因为插入自带尾随空格、不会再触发注册的触发字符。
 */
export const DIRECTIVE_COMPLETIONS = Object.freeze([
	{ label: '#_if', insertText: '#_if ', section: 'if', followUp: 'suggest' },
	{ label: '#_else', insertText: '#_else', section: 'if' },
	{ label: '#_endif', insertText: '#_endif', section: 'if' },
	{ label: '#_include', insertText: '#_include ', section: 'include' },
	{ label: '#_include_as_value', insertText: '#_include_as_value ', section: 'include' },
	{ label: '#_include_as_base64', insertText: '#_include_as_base64 ', section: 'includeAs' },
	{ label: '#_include_as_bytes', insertText: '#_include_as_bytes ', section: 'includeAs' },
	{ label: '#_!!', insertText: '#_!!', section: 'bang' },
	{ label: '#_require', insertText: '#_require ', section: 'require' },
	{ label: '#_pragma', insertText: '#_pragma ', section: 'pragma', followUp: 'suggest' },
	{ label: '#_balus', insertText: '#_balus ', section: 'balus' },
	{ label: '#_DllExport', insertText: '#_DllExport ', section: 'dllExport' }
])

// 光标前恰好是（缩进 +）`#_` 加可选的部分指令名（含 `!`，以匹配 `#_!!`），且尚未出现参数。
const DIRECTIVE_PREFIX_RE = /^([\t ]*)(#_[!#A-Za-z_]*)$/

/**
 * 判断光标前的文本是否处于 `#_` 指令名的输入过程，并给出可替换的列区间。
 *
 * @param {string} textBeforeCursor - 当前行光标之前的部分
 * @returns {{ start: number, prefix: string } | null} `start` 为 `#` 的列号（从零开始），不在指令名上时为 null
 */
export function directivePrefixAt(textBeforeCursor) {
	const match = DIRECTIVE_PREFIX_RE.exec(textBeforeCursor)
	if (!match) return null
	return { start: match[1].length, prefix: match[2] }
}

/**
 * 依据预处理器块结构判断光标处允许插入哪些结构性指令：
 *
 * - `#_endif` 仅在存在打开的 `#_if`（光标位于其未闭合的块内）时可用，否则它是 stray 指令。
 * - `#_else` 仅在光标所在的最内层打开块尚无 `#_else` 时可用，否则会出现 duplicate/stray `#_else`。
 *
 * `blocks` 应基于「把光标处正在输入的指令名抹掉」的探针文本分析，这样半截或完整的 `#_if`/`#_else`/`#_endif` 不会被算成已有结构。
 *
 * @param {Array<{ startLine: number, endLine: number, elseLine: number | null, closed: boolean, depth: number }>} blocks - `analyze` 得到的块列表
 * @param {number} line - 光标所在行号（从零开始）
 * @returns {{ allowElse: boolean, allowEndIf: boolean }} 允许的结构性指令
 */
export function directiveAvailability(blocks, line) {
	const open = blocks.filter((block) => line > block.startLine && (!block.closed || line < block.endLine))
	const innermost = open.reduce((best, block) => best && best.depth >= block.depth ? best : block, null)
	return {
		allowElse: Boolean(innermost && innermost.elseLine === null),
		allowEndIf: open.length > 0
	}
}

/**
 * 返回与已输入前缀匹配的指令补全候选，顺序与 `DIRECTIVE_COMPLETIONS` 一致。给出 `availability` 时，
 * 会去掉当前上下文不允许插入的 `#_else` / `#_endif`，避免补全出 stray 或 duplicate 指令。
 *
 * @param {string} prefix - 已输入的 `#_…` 前缀
 * @param {{ allowElse: boolean, allowEndIf: boolean }} [availability] 光标处的上下文，见 `directiveAvailability`
 * @returns {Array<{ label: string, insertText: string, section: string }>} 匹配的候选列表
 */
export function buildDirectiveCandidates(prefix, availability) {
	const lower = String(prefix || '').toLowerCase()
	return DIRECTIVE_COMPLETIONS.filter((entry) => {
		if (!entry.label.toLowerCase().startsWith(lower)) return false
		if (availability) {
			if (entry.label === '#_else' && !availability.allowElse) return false
			if (entry.label === '#_endif' && !availability.allowEndIf) return false
		}
		return true
	})
}

/**
 * 键入 `#_if ` 后可补全的条件关键字。`section` 是 `lib/hover.mjs` 的 `HOVER_MESSAGES` / README 小节键。
 * `followUp: 'newline'` 表示补全条件后自动换行，从而触发 `#_if` 的 `#_endif` 自动闭合。
 */
export const CONDITION_COMPLETIONS = Object.freeze([
	{ label: 'PSEXE', insertText: 'PSEXE', section: 'psexe', followUp: 'newline' },
	{ label: 'PSScript', insertText: 'PSScript', section: 'psscript', followUp: 'newline' }
])

// 光标前恰好是（缩进 +）`#_if` 加空白，后跟可选的部分条件关键字，且尚未出现尾随注释。
const IF_CONDITION_PREFIX_RE = /^([\t ]*#_if[\t ]+)([A-Za-z_]*)$/

/**
 * 判断光标前的文本是否处于 `#_if` 条件关键字的输入过程，并给出可替换的列区间。
 *
 * @param {string} textBeforeCursor - 当前行光标之前的部分
 * @returns {{ start: number, prefix: string } | null} `start` 为条件关键字的列号（从零开始），不在条件上时为 null
 */
export function ifConditionPrefixAt(textBeforeCursor) {
	const match = IF_CONDITION_PREFIX_RE.exec(textBeforeCursor)
	if (!match) return null
	return { start: match[1].length, prefix: match[2] }
}

/**
 * 返回与已输入前缀匹配的条件补全候选，顺序与 `CONDITION_COMPLETIONS` 一致。
 *
 * @param {string} prefix - 已输入的条件前缀
 * @returns {Array<{ label: string, insertText: string, section: string }>} 匹配的候选列表
 */
export function buildConditionCandidates(prefix) {
	const lower = String(prefix || '').toLowerCase()
	return CONDITION_COMPLETIONS.filter((entry) => entry.label.toLowerCase().startsWith(lower))
}
