// 命令用法检查：对脚本里的 PS2EXE 调用和模块管理命令给出警告，并提供快速修复。
//
// - PS2EXE 调用：`lib/ps2exe.mjs` 会把整次调用（命令名 + 参数）改写成 ps12exe 的对象式 API，因此 PS2EXE 诊断的范围覆盖整次
//   调用、`replacement` 即改写后的文本。
// - 模块管理命令：只在**使用了 ps12exe 预处理命令**（文件里出现 `#_…`）的文件里告警——普通 PowerShell 脚本不一定会被
//   ps12exe 编译，没必要对它指手画脚。若该行是手写/生成的模块安装样板，还会给出整行替换为 `#_require <模块>` 的修复。
//
// 检查是纯文本的（不启动 PowerShell），因此可以随文档变更同步运行；别名是否为标准别名由 `lib/aliases.mjs` 实时探测后作为
// `aliasMap` 传入，未确认的别名不会被误报。here-string 函数体与块注释内的命令不是调用，因此复用
// `lib/preprocessor.mjs#computeSkipMask` 跳过；`#_!!` 行会被 ps12exe 去掉标记变成真实代码，所以照常检查。

import { computeSkipMask } from './preprocessor.mjs'
import { convertPs2exeInvocation } from './ps2exe.mjs'

/** 英文源字符串；它们同时也是 l10n bundle 的键。 */
export const COMMAND_MESSAGES = Object.freeze({
	ps2exeCall: 'PS2EXE command "{0}" is deprecated; use ps12exe instead.',
	moduleCommand: 'Module-management command "{0}"; declare module dependencies with #_require so the compiled executable sets them up.'
})

/** 在告警行上方（或行尾）插入该注释即可让扩展忽略该行的诊断。 */
export const IGNORE_DIRECTIVE = '# use_ps12exe:ignore'

/** 诊断代码：PS2EXE 调用。 */
export const PS2EXE_DIAGNOSTIC = 'ps2exe-call'
/** 诊断代码：模块管理命令。 */
export const MODULE_DIAGNOSTIC = 'module-command'

// PS2EXE 模块导出的函数与别名（见 src/.subrepo/PS2EXE2ps12exe），小写。
const PS2EXE_COMMANDS = new Set([
	'ps2exe',
	'ps2exe.ps1',
	'invoke-ps2exe',
	'invoke-winps2exe',
	'win-ps2exe',
	'win-ps2exe.exe'
])

// 模块管理命令的完整 cmdlet 名，小写。
const MODULE_COMMANDS = new Set(['get-module', 'import-module', 'install-module'])

/** 文件里出现任意预处理指令即视为「会被 ps12exe 编译」。 */
const DIRECTIVE_RE = /^[\t ]*#_/

/**
 * 内置的标准别名映射，供未探测到 PowerShell 宿主时回退使用。`inmo` 由随 PowerShell 发布的 PowerShellGet 模块导出，
 * 因此也算标准别名。
 */
export const MODULE_ALIASES = Object.freeze({
	gmo: 'Get-Module',
	ipmo: 'Import-Module',
	inmo: 'Install-Module'
})

/**
 * 按行切分文档。
 *
 * @param {string} text - 文档全文
 * @returns {string[]} 行数组
 */
function splitLines (text) {
	return String(text).split(/\r\n|\n|\r/)
}

/**
 * 计算一行中属于代码的字符位置（字符串内容与 `#` 注释为 false）。用于避免把字符串或注释里的命令名当成调用。
 *
 * @param {string} line - 待扫描的行
 * @returns {boolean[]} 逐字符的代码标记
 */
function codeMask (line) {
	const mask = new Array(line.length).fill(true)
	let state = 'code'
	for (let i = 0; i < line.length; i++) {
		const char = line[i]
		if (state === 'single') {
			mask[i] = false
			if (char === '\'')
				if (line[i + 1] === '\'') { mask[i + 1] = false; i++ }
				else state = 'code'
			continue
		}
		if (state === 'double') {
			mask[i] = false
			if (char === '`') {
				if (i + 1 < line.length) { mask[i + 1] = false; i++ }
				continue
			}
			if (char === '"') state = 'code'
			continue
		}
		if (char === '#') {
			for (let j = i; j < line.length; j++) mask[j] = false
			break
		}
		if (char === '\'') state = 'single'
		else if (char === '"') state = 'double'
	}
	return mask
}

// 命令名可含连字符、点与下划线（`Get-Module`、`ps2exe.ps1`）。
const COMMAND_NAME_RE = /^[A-Za-z_][A-Za-z0-9_.-]*/

/**
 * 找出一行里处于命令位置的 token：语句开头，以及 `;`、`|`、`(`、`{`、`=` 和调用运算符（`&` / `.`）之后。
 * 只保留每个 token 的名字与列区间，交由调用方判定是否为关注的目标命令。
 *
 * @param {string} line - 待扫描的行（已去掉 `#_!!` 标记）
 * @returns {Array<{ name: string, start: number, end: number }>} 命令位置的 token
 */
function commandTokens (line) {
	const mask = codeMask(line)
	const tokens = []
	let expectCommand = true
	for (let i = 0; i < line.length; i++) {
		if (!mask[i]) { expectCommand = false; continue }
		const char = line[i]
		if (char === ' ' || char === '\t') continue
		if (expectCommand) {
			if (char === '&' || char === '.' || char === '{' || char === '(' || char === ';' || char === '|') continue
			const match = COMMAND_NAME_RE.exec(line.slice(i))
			if (match) {
				tokens.push({ name: match[0], start: i, end: i + match[0].length })
				i += match[0].length - 1
			}
			expectCommand = false
			continue
		}
		if (char === ';' || char === '|' || char === '(' || char === '{' || char === '=') expectCommand = true
	}
	return tokens
}

/**
 * 从 `aliasMap`（别名 -> 定义）中挑出确实指向模块管理 cmdlet 的别名名，小写。
 *
 * @param {Record<string, string>} aliasMap - 别名到定义的映射
 * @returns {Set<string>} 需要告警的别名名集合
 */
function moduleAliasSet (aliasMap) {
	const set = new Set()
	for (const [name, definition] of Object.entries(aliasMap || {})) 
		if (MODULE_COMMANDS.has(String(definition).toLowerCase())) set.add(name.toLowerCase())
	
	return set
}

/**
 * 判断一个命令名是否应告警，并给出诊断代码与（可选）替换文本。
 *
 * @param {string} name - 命令名（小写）
 * @param {Set<string>} moduleAliases - 已确认的标准模块别名
 * @returns {{ message: string, code: string } | null} 命中信息，未命中时为 null
 */
function commandInfo (name, moduleAliases) {
	if (PS2EXE_COMMANDS.has(name)) return { message: COMMAND_MESSAGES.ps2exeCall, code: PS2EXE_DIAGNOSTIC }
	if (MODULE_COMMANDS.has(name) || moduleAliases.has(name)) return { message: COMMAND_MESSAGES.moduleCommand, code: MODULE_DIAGNOSTIC }
	return null
}

/**
 * 计算被 `# use_ps12exe:ignore` 抑制的行。标记可以单独占一行放在告警行上方，也可以作为行尾注释附在告警行末尾。
 *
 * @param {string[]} lines - 文档的所有行
 * @returns {boolean[]} 逐行的抑制标记
 */
export function computeIgnoredMask (lines) {
	const ignored = new Array(lines.length).fill(false)
	for (let i = 0; i < lines.length; i++) {
		const trimmed = lines[i].trim()
		const previous = i > 0 ? lines[i - 1].trim() : ''
		if (previous === IGNORE_DIRECTIVE || trimmed.endsWith(IGNORE_DIRECTIVE)) ignored[i] = true
	}
	return ignored
}

// `#_require` 生成的单模块安装样板：if(!(gmo <mod> -ListAvailable …)){…Install-Module <mod>…}
// 与 `src/ReadScriptFile.ps1` 的展开以及 `exe21sp.ps1#Restore-RequiredModulePragma` 的还原模式一致。
const GENERATED_INSTALL_RE = /^([\t ]*)if\s*\(\s*!\s*\(\s*(?:gmo|Get-Module)\s+([^\s)]+)[^)]*\)\s*\)\s*\{.*(?:Install-Module|inmo)\s+([^\s;}|]+).*\}\s*$/
// 单行的 `Install-Module <mod> …` / `inmo <mod> …`。
const BARE_INSTALL_RE = /^([\t ]*)(?:Install-Module|inmo)\b(.*)$/i

/**
 * 去掉一层匹配的引号，并把单引号的双写还原。
 *
 * @param {string} text - 原始文本
 * @returns {string} 去引号后的文本
 */
function unquote (text) {
	if (text.length >= 2 && ((text.startsWith('\'') && text.endsWith('\'')) || (text.startsWith('"') && text.endsWith('"')))) 
		return text.slice(1, -1).replace(/''/g, '\'')
	
	return text
}

/**
 * 从 `Install-Module`/`inmo` 的参数文本里取第一个模块名（位置参数或 `-Name`）。
 *
 * @param {string} rest - 命令名之后的参数文本
 * @returns {string | null} 模块名；取不到或为动态表达式时为 null
 */
function installTarget (rest) {
	let text = rest.trim()
	const named = /^-(?:Name|name)\s*:?\s*(.+)$/.exec(text)
	if (named) text = named[1].trim()
	const match = /^("[^"]*"|'[^']*'|[^\s]+)/.exec(text)
	if (!match) return null
	const name = unquote(match[1])
	if (!name || name.startsWith('$') || name.startsWith('-')) return null
	return name
}

/**
 * 把一行模块安装样板改写为 `#_require <模块>`。只处理能明确识别出单一模块的独立行；动态名称、管道、多语句等一律返回 null。
 *
 * @param {string} raw - 原始行
 * @returns {{ indent: string, module: string } | null} 缩进与模块名；无法改写时为 null
 */
function requireFixForLine (raw) {
	const generated = GENERATED_INSTALL_RE.exec(raw)
	if (generated) {
		const first = unquote(generated[2])
		const second = unquote(generated[3])
		if (first && first === second && !first.startsWith('$')) return { indent: generated[1], module: first }
		return null
	}

	const bare = BARE_INSTALL_RE.exec(raw)
	if (!bare) return null
	const rest = bare[2]
	// 只改写独立的一行调用；管道/分号/大括号/尾随注释都会让 `#_require` 落错位置。
	if (/[;|{}#]/.test(rest)) return null
	const module = installTarget(rest)
	if (!module) return null
	return { indent: bare[1], module }
}

/**
 * 扫描文档中的 PS2EXE 调用与模块管理命令，返回与 `analyze` 相同形状的诊断（额外带上 `code`、列区间与替换文本），供扩展
 * 发布并据此生成快速修复。被 `# use_ps12exe:ignore` 抑制的行不会产生诊断。
 *
 * @param {string} text - 文档全文
 * @param {Record<string, string>} [aliasMap] - 别名到定义的映射（见 `lib/aliases.mjs`）
 * @returns {Array<{ line: number, severity: 'warning', message: string, args: string[], code: string, start: number, end: number, replacement?: string }>} 诊断列表
 */
export function analyzeCommandUsage (text, aliasMap = MODULE_ALIASES) {
	const lines = splitLines(text)
	const skip = computeSkipMask(lines)
	const ignored = computeIgnoredMask(lines)
	const moduleAliases = moduleAliasSet(aliasMap)
	const usesPreprocessor = lines.some((line, index) => !skip[index] && DIRECTIVE_RE.test(line))
	const diagnostics = []

	for (let line = 0; line < lines.length; line++) {
		if (skip[line] || ignored[line]) continue
		const raw = lines[line]
		if (/^[\t ]*#/.test(raw) && !/^[\t ]*#_!!/.test(raw)) continue

		let content = raw
		let offset = 0
		const bang = /^([\t ]*)#_!! ?/.exec(raw)
		if (bang) {
			offset = bang[0].length
			content = raw.slice(offset)
		}
		const requireFix = offset === 0 && usesPreprocessor ? requireFixForLine(raw) : null

		for (const token of commandTokens(content)) {
			const info = commandInfo(token.name.toLowerCase(), moduleAliases)
			if (!info) continue
			if (info.code === MODULE_DIAGNOSTIC && !usesPreprocessor) continue

			const diagnostic = {
				line,
				severity: /** @type {'warning'} */ 'warning',
				message: info.message,
				args: [token.name],
				code: info.code,
				start: offset + token.start,
				end: offset + token.end
			}

			if (info.code === PS2EXE_DIAGNOSTIC) {
				const converted = convertPs2exeInvocation(content, token)
				if (converted) {
					diagnostic.end = offset + converted.end
					diagnostic.replacement = converted.text
				}
			}
			else if (requireFix) {
				// 整行替换成 `#_require`，诊断范围也覆盖整行。
				diagnostic.start = 0
				diagnostic.end = raw.length
				diagnostic.replacement = `${requireFix.indent}#_require ${requireFix.module}`
			}

			diagnostics.push(diagnostic)
		}
	}

	return diagnostics
}
