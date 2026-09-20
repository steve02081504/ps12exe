// 编辑器层面的 PS2EXE -> ps12exe 迁移：把一次 PS2EXE 调用重写成 ps12exe 的对象式 API（改名 + 参数映射）。
//
// 映射与 `src/.subrepo/PS2EXE2ps12exe/PS2EXE2ps12exe.psm1` 的 `Invoke-ps2exe` 保持一致（那里组装 `$psParams` / `$app` /
// `$os` / `$build` / `$resources`）；改动那边时必须同步这里。ps12exe 没有等价能力（`conHost` / `embedFiles`）、调用用了
// splatting，或参数无法静态确定时返回 `null`——宁可不提供改写，也不生成错误或语义不同的调用。

// 需要取值的 PS2EXE 参数（小写）。
const VALUE_PARAMS = new Set([
	'inputfile', 'outputfile', 'iconfile', 'title', 'description', 'company',
	'product', 'copyright', 'trademark', 'version', 'lcid', 'embedfiles'
])

// 开关型 PS2EXE 参数（小写）。
const SWITCH_PARAMS = new Set([
	'preparedebug', 'runtime20', 'runtime40', 'x86', 'x64', 'sta', 'mta', 'nested',
	'noconsole', 'conhost', 'unicodeencoding', 'credentialgui', 'configfile', 'noconfigfile',
	'nooutput', 'noerror', 'novisualstyles', 'exitoncancel', 'dpiaware', 'winformsdpiaware',
	'requireadmin', 'supportos', 'virtualize', 'longpaths'
])

// 兼容层直接忽略的占位参数。
const IGNORED_PARAMS = new Set(['nested', 'noconfigfile'])
// 无法映射为 ps12exe 参数的参数（兼容层在编译期改写脚本来模拟，编辑器层面无法等价改写）。
const UNSUPPORTED_PARAMS = new Set(['conhost', 'embedfiles'])

/**
 * 判断一行在语法上是否完整（引号与括号都闭合，且不以续行反引号结尾）。不完整时调用可能跨行，无法静态改写。
 *
 * @param {string} text - 待检查的行
 * @returns {boolean} 行在语法上完整时为 true
 */
function isCompleteLine (text) {
	let depth = 0
	let state = 'code'
	for (let i = 0; i < text.length; i++) {
		const char = text[i]
		if (state === 'single') {
			if (char === '\'') 
				if (text[i + 1] === '\'') i++
				else state = 'code'
			continue
		}
		if (state === 'double') {
			if (char === '`') { i++; continue }
			if (char === '"') state = 'code'
			continue
		}
		if (char === '\'') { state = 'single'; continue }
		if (char === '"') { state = 'double'; continue }
		if (char === '`' && i === text.length - 1) return false
		if (char === '#' && (i === 0 || /[\s;|({]/.test(text[i - 1]))) break
		if (char === '(' || char === '{' || char === '[') depth++
		else if (char === ')' || char === '}' || char === ']') depth--
	}
	return state === 'code' && depth <= 0
}

/**
 * 跳过一个参数 token：保留引号与成对括号内的空白，因此 `"a b"`、`@{a='b c'}`、`$(Get-Item 'x y')` 都算一个 token。
 *
 * @param {string} text - 待扫描的行
 * @param {number} start - token 起始列
 * @returns {number} token 结束列（不含）
 */
function readArgumentToken (text, start) {
	let i = start
	let depth = 0
	while (i < text.length) {
		const char = text[i]
		if (char === '`') { i += 2; continue }
		if (char === '\'') {
			i++
			while (i < text.length)
				if (text[i] === '\'')
					if (text[i + 1] === '\'') i += 2
					else { i++; break }
				else i++
			continue
		}
		if (char === '"') {
			i++
			while (i < text.length) {
				if (text[i] === '`') { i += 2; continue }
				if (text[i] === '"') { i++; break }
				i++
			}
			continue
		}
		if (char === '(' || char === '{' || char === '[') { depth++; i++; continue }
		if (char === ')' || char === '}' || char === ']') {
			if (depth === 0) break
			depth--
			i++
			continue
		}
		if (depth === 0 && (char === ' ' || char === '\t' || char === ';' || char === '|')) break
		i++
	}
	return i
}

/**
 * 跳过空白。
 *
 * @param {string} text - 待扫描的行
 * @param {number} start - 起始列
 * @returns {number} 第一个非空白列
 */
function skipSpaces (text, start) {
	let i = start
	while (i < text.length && (text[i] === ' ' || text[i] === '\t')) i++
	return i
}

/**
 * 解析开关的取值：无内联值时视为 `$true`，`-x:$false` 之类的布尔字面量按字面处理，其它表达式无法静态求值。
 *
 * @param {string | true} value - 参数的取值
 * @returns {boolean} 开关的真假
 */
function switchValue (value) {
	if (value === true) return true
	const text = String(value).trim().toLowerCase()
	if (text === '' || text === '$true' || text === 'true' || text === '1') return true
	if (text === '$false' || text === 'false' || text === '0') return false
	throw new Error('non-literal switch value')
}

/**
 * 把 PS2EXE 的字符串参数转成合法的 PowerShell 字面量：已引用的与表达式原样保留，裸词加单引号。
 *
 * @param {string} raw - 原始取值文本
 * @returns {string} 字面量文本
 */
function toLiteral (raw) {
	if (raw.startsWith('\'') || raw.startsWith('"')) return raw
	if (/^[$(@[`]/.test(raw)) return raw
	return `'${raw.replace(/'/g, '\'\'')}'`
}

/**
 * `-lcid` 的取值在兼容层里会被 `"$lcid"` 字符串化，因此这里也强制成字符串。
 *
 * @param {string} raw - 原始取值文本
 * @returns {string} 字符串字面量文本
 */
function toCultureLiteral (raw) {
	if (raw.startsWith('$') || raw.startsWith('(') || raw.startsWith('@')) return `"${raw}"`
	return toLiteral(raw)
}

/**
 * 生成一个 `@{ Key = Value; … }` 哈希表字面量。
 *
 * @param {Array<[string, string]>} entries - 键值对
 * @returns {string} 哈希表字面量
 */
function hashtable (entries) {
	return `@{ ${entries.map(([key, value]) => `${key} = ${value}`).join('; ')} }`
}

/**
 * 布尔字面量。
 *
 * @param {boolean} value - 布尔值
 * @returns {string} `$true` 或 `$false`
 */
function boolLiteral (value) {
	return value ? '$true' : '$false'
}

/**
 * 把一次 PS2EXE 调用重写为等价的 ps12exe 调用。
 *
 * @param {string} line - 包含调用的整行（已去掉 `#_!!` 标记）
 * @param {{ start: number, end: number }} token - 命令名 token 的列区间
 * @returns {{ end: number, text: string } | null} 调用结束列与改写后的文本；不可改写时为 null
 */
export function convertPs2exeInvocation (line, token) {
	const content = line.slice(token.start)
	if (!isCompleteLine(content)) return null

	try {
		/** @type {Map<string, string | true>} */
		const params = new Map()
		/** @type {string[]} */
		const positionals = []
		let i = token.end
		let end = token.end

		while (i < line.length) {
			const char = line[i]
			if (char === ' ' || char === '\t') { i++; continue }
			if (char === '#' || char === ';' || char === '|' || char === ')' || char === '}') break
			const stop = readArgumentToken(line, i)
			if (stop <= i) return null
			const raw = line.slice(i, stop)
			end = stop
			i = stop

			if (!raw.startsWith('-')) {
				if (raw.startsWith('@')) return null // splatting，无法静态展开
				positionals.push(raw)
				continue
			}

			const match = /^-([A-Za-z_][A-Za-z0-9_]*)(?::([\s\S]*))?$/.exec(raw)
			if (!match) return null
			const name = match[1].toLowerCase()
			if (UNSUPPORTED_PARAMS.has(name)) return null
			if (IGNORED_PARAMS.has(name)) continue
			if (!VALUE_PARAMS.has(name) && !SWITCH_PARAMS.has(name)) return null
			if (params.has(name)) return null

			let value = match[2]
			if (VALUE_PARAMS.has(name) && value === undefined) {
				const valueStart = skipSpaces(line, i)
				if (valueStart >= line.length) return null
				const valueStop = readArgumentToken(line, valueStart)
				const candidate = line.slice(valueStart, valueStop)
				// 下一个 token 是另一个已知参数时说明取值缺失，不臆测。
				const asParam = /^-([A-Za-z_][A-Za-z0-9_]*)/.exec(candidate)
				if (asParam && (VALUE_PARAMS.has(asParam[1].toLowerCase()) || SWITCH_PARAMS.has(asParam[1].toLowerCase()))) return null
				value = candidate
				end = valueStop
				i = valueStop
			}
			params.set(name, value === undefined ? true : value)
		}

		// 位置参数按 Invoke-ps2exe 的参数顺序绑定到尚未显式给出的 inputFile / outputFile。
		const slots = []
		if (!params.has('inputfile')) slots.push('inputfile')
		if (!params.has('outputfile')) slots.push('outputfile')
		if (positionals.length > slots.length) return null
		positionals.forEach((value, index) => params.set(slots[index], value))

		/**
		 * 参数是否被显式给出。
		 *
		 * @param {string} name - 参数名（小写）
		 * @returns {boolean} 已给出时为 true
		 */
		const has = (name) => params.has(name)
		/**
		 * 读取开关参数的真假；取值不是可静态确定的字面量时抛出，由外层转成「不可改写」。
		 *
		 * @param {string} name - 参数名（小写）
		 * @returns {boolean} 开关的真假
		 */
		const bool = (name) => switchValue(params.get(name))
		/**
		 * 读取取值参数的原文本。
		 *
		 * @param {string} name - 参数名（小写）
		 * @returns {string} 取值文本
		 */
		const value = (name) => /** @type {string} */ params.get(name)

		const app = []
		if (has('noconsole')) app.push(['Windowed', boolLiteral(bool('noconsole'))])
		if (has('unicodeencoding')) app.push(['OutputEncoding', bool('unicodeencoding') ? '\'UTF16LE\'' : '\'Default\''])
		if (has('credentialgui')) app.push(['CredentialGUI', boolLiteral(bool('credentialgui'))])
		if (has('novisualstyles')) app.push(['VisualStyles', boolLiteral(!bool('novisualstyles'))])
		if (has('exitoncancel')) app.push(['ExitOnCancel', boolLiteral(bool('exitoncancel'))])
		if (has('dpiaware')) app.push(['DpiAware', boolLiteral(bool('dpiaware'))])
		if (has('winformsdpiaware')) app.push(['WinFormsDpiAware', boolLiteral(bool('winformsdpiaware'))])
		const silence = []
		if (has('nooutput') && bool('nooutput')) silence.push('Output', 'Verbose')
		if (has('noerror') && bool('noerror')) silence.push('Error', 'Warning', 'Debug')
		if (silence.length) app.push(['Silence', `@(${silence.map((name) => `'${name}'`).join(', ')})`])

		const os = []
		if (has('requireadmin')) os.push(['Admin', boolLiteral(bool('requireadmin'))])
		if (has('supportos')) os.push(['ModernOS', boolLiteral(bool('supportos'))])
		if (has('virtualize')) os.push(['Virtualize', boolLiteral(bool('virtualize'))])
		if (has('longpaths')) os.push(['LongPaths', boolLiteral(bool('longpaths'))])

		const build = []
		if (has('preparedebug')) build.push(['KeepSource', boolLiteral(bool('preparedebug'))])
		if (has('lcid')) build.push(['Culture', toCultureLiteral(value('lcid'))])
		if (has('x86') && has('x64')) return null
		if (has('x86')) build.push(['Platform', '\'x86\''])
		if (has('x64')) build.push(['Platform', '\'x64\''])
		if (has('sta') && has('mta')) return null
		if (has('sta')) build.push(['Apartment', '\'STA\''])
		if (has('mta')) build.push(['Apartment', '\'MTA\''])
		if (has('runtime20') && has('runtime40')) return null
		if (has('runtime20')) build.push(['Target', '\'Framework2.0\''])
		if (has('runtime40')) build.push(['Target', '\'Framework4.0\''])

		const resources = []
		const resourceMap = [
			['iconfile', 'Icon'], ['title', 'Title'], ['description', 'Description'], ['company', 'Company'],
			['product', 'Product'], ['copyright', 'Copyright'], ['trademark', 'Trademark'], ['version', 'Version']
		]
		for (const [name, key] of resourceMap) 
			if (has(name) && value(name) !== '' && value(name) !== '\'\'' && value(name) !== '""') 
				resources.push([key, toLiteral(value(name))])

		const parts = ['ps12exe']
		if (has('inputfile')) parts.push('-InputFile', value('inputfile'))
		if (has('outputfile')) parts.push('-OutputFile', value('outputfile'))
		for (const [flag, entries] of [['-App', app], ['-Os', os], ['-Build', build], ['-Resources', resources]]) 
			if (entries.length) parts.push(flag, hashtable(entries))

		if (has('configfile') && bool('configfile')) parts.push('-ConfigFile')

		return { end, text: parts.join(' ') }
	}
	catch {
		return null
	}
}
