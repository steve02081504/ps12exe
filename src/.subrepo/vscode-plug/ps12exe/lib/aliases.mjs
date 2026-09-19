// 标准 PowerShell 别名的探测：`gmo`/`ipmo`/`inmo` 这类模块管理缩写只有在机器上确实仍是标准别名时，扩展才应该就它们告警。
// 别名可能被用户或第三方模块改写、移除（例如 `inmo` 由 PowerShellGet 导出，未加载该模块时并不存在），因此会话内启动一次
// PowerShell 查询并缓存结果，查询失败时退回内置的标准映射。探测在后台进行，未完成期间先用回退映射。

import { resolvePlainPowerShell, runScript, psQuote } from './powershell.mjs'

const MARKER = 'PS12EXE_ALIAS:'
const TRACKED = ['gmo', 'ipmo', 'inmo']

/** 内置的标准别名映射，供探测完成前或失败时使用。 */
export const FALLBACK_ALIASES = Object.freeze({
	gmo: 'Get-Module',
	ipmo: 'Import-Module',
	inmo: 'Install-Module'
})

const MODULE_TARGETS = new Set(Object.values(FALLBACK_ALIASES).map((name) => name.toLowerCase()))

/** @type {Record<string, string> | null} */
let cached = null
/** @type {Promise<Record<string, string>> | null} */
let pending = null

/**
 * 当前可用的别名映射：探测结果优先，尚未就绪时为内置回退。
 *
 * @returns {Record<string, string>} 别名到定义的映射
 */
export function currentAliasMap () {
	return cached || FALLBACK_ALIASES
}

/**
 * 清空别名缓存，使下次 {@link loadAliasMap} 重新探测。
 */
export function clearAliasCache () {
	cached = null
	pending = null
}

/**
 * 查询宿主上被跟踪别名的定义，结果在一个会话内缓存。仅保留确实指向模块管理 cmdlet 的映射；查询失败或找不到宿主时
 * 返回内置回退映射。
 *
 * @returns {Promise<Record<string, string>>} 别名到定义的映射
 */
export function loadAliasMap () {
	if (cached) return Promise.resolve(cached)
	if (pending) return pending

	pending = (async () => {
		try {
			const host = await resolvePlainPowerShell()
			if (!host) return FALLBACK_ALIASES
			const script = [
				'$ErrorActionPreference = "SilentlyContinue"',
				'[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
				// `inmo` 由 PowerShellGet 导出，显式导入才能探测到（与交互式会话的模块自动加载一致）。
				'Import-Module PowerShellGet -ErrorAction SilentlyContinue',
				`foreach ($name in @(${TRACKED.map((name) => psQuote(name)).join(', ')})) {`,
				'  $alias = Get-Alias -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1',
				`  if ($alias) { Write-Output ('${MARKER}' + $alias.Name + '=' + $alias.Definition) }`,
				'}'
			].join('\n')
			const parsed = parseAliasOutput((await runScript(host, script)).stdout)
			cached = Object.keys(parsed).length ? parsed : FALLBACK_ALIASES
		}
		catch {
			cached = FALLBACK_ALIASES
		}
		finally {
			pending = null
		}
		return cached
	})()

	return pending
}

/**
 * 解析探测脚本输出的 `PS12EXE_ALIAS:<name>=<definition>` 行，只保留指向模块管理 cmdlet 的映射。
 *
 * @param {string} stdout - 探测脚本的标准输出
 * @returns {Record<string, string>} 别名到定义的映射
 */
export function parseAliasOutput (stdout) {
	const map = {}
	for (const line of String(stdout || '').split(/\r?\n/)) {
		const index = line.indexOf(MARKER)
		if (index < 0) continue
		const pair = line.slice(index + MARKER.length).trim()
		const equals = pair.indexOf('=')
		if (equals <= 0) continue
		const name = pair.slice(0, equals).trim()
		const definition = pair.slice(equals + 1).trim()
		if (!name || !MODULE_TARGETS.has(definition.toLowerCase())) continue
		map[name.toLowerCase()] = definition
	}
	return map
}
