// `#_require` 模块的 PowerShell Gallery 查询支持：按需调用图库的 OData v2 接口，取出图标、简介、tags、
// 仓库地址与图库页面地址，供悬浮提示展示。
//
// 图库对 `$format=json` 返回 400，接口只提供 Atom XML（`d:` 命名空间的数据属性），因此这里用手写的字段
// 提取加 XML 实体解码，而不是引入 XML 依赖。结果按模块名（小写）缓存；查询失败不缓存，以便网络恢复后重试。
// 悬浮只是锦上添花，调用方在失败时回退到通用的 `#_require` 说明。

const API_URL = 'https://www.powershellgallery.com/api/v2/Packages'
const PAGE_BASE = 'https://www.powershellgallery.com/packages'
const REQUEST_TIMEOUT_MS = 8000

// 图库为模块自动生成的 tag（`PSFunction_Invoke-Pester`、`PSCommand_…` …）；悬浮提示里只展示人工 tag。
const GENERATED_TAG_PREFIXES = ['PSFunction_', 'PSCommand_', 'PSIncludes_', 'PSDataFile_', 'PSRoleCapability_', 'PSWorkflow_']

/** @type {Map<string, Promise<object | null>>} 模块名（小写）到查询结果的缓存。 */
const cache = new Map()

/** 清空缓存；主要用于测试。 */
export function clearGalleryCache () {
	cache.clear()
}

/**
 * 构造图库上的模块页面地址。
 *
 * @param {string} id - 模块名
 * @param {string} [version] - 版本；省略时指向模块的最新版页面
 * @returns {string} 图库页面地址
 */
export function packagePageUrl (id, version) {
	const base = `${PAGE_BASE}/${encodeURIComponent(id)}`
	return version ? `${base}/${encodeURIComponent(version)}` : base
}

/**
 * 构造图库上按 tag 搜索的地址。
 *
 * @param {string} tag - tag 名
 * @returns {string} 搜索结果页地址
 */
export function tagSearchUrl (tag) {
	return `${PAGE_BASE}?q=${encodeURIComponent(`Tags:"${tag}"`)}`
}

/**
 * 判断一个 tag 是否为图库自动生成。
 *
 * @param {string} tag - 待判断的 tag
 * @returns {boolean} 是自动生成的 tag 时为真
 */
export function isGeneratedTag (tag) {
	return GENERATED_TAG_PREFIXES.some((prefix) => tag.startsWith(prefix))
}

/**
 * 解码 XML 文本节点中的实体。`&amp;` 必须最后处理，否则 `&amp;lt;` 会被二次解码。
 *
 * @param {string} text - 待解码的文本
 * @returns {string} 解码后的文本
 */
function decodeXml (text) {
	return text
		.replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
		.replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&quot;/g, '"')
		.replace(/&apos;/g, "'")
		.replace(/&amp;/g, '&')
}

/**
 * 去掉文本中的 HTML 标签并压平空白；图库的简介允许内嵌 HTML。
 *
 * @param {string} text - 原始文本
 * @returns {string} 纯文本
 */
function stripHtml (text) {
	return text.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
}

/**
 * 读取一个 `<d:…>` 数据属性的文本值；字段缺失或为 `m:null="true"` 时返回空串。
 *
 * @param {string} entry - 单个 `<entry>` 的 XML 文本
 * @param {string} name - 属性名（如 `Description`）
 * @returns {string} 已解码并去除首尾空白的值
 */
function fieldValue (entry, name) {
	const match = new RegExp(`<d:${name}(?:\\s[^>]*)?>([\\s\\S]*?)</d:${name}>`).exec(entry)
	return match ? decodeXml(match[1]).trim() : ''
}

/**
 * 从图库的 Atom feed 中解析第一个模块条目。
 *
 * @param {string} xml - 接口返回的 Atom XML
 * @returns {{ id: string, version: string, description: string, iconUrl: string, projectUrl: string, galleryUrl: string, tags: string[] } | null} 解析结果；没有条目时为 null
 */
export function parseGalleryEntry (xml) {
	const entry = /<entry\b[\s\S]*?<\/entry>/.exec(xml)
	if (!entry) return null

	const id = stripHtml(fieldValue(entry[0], 'Id'))
	if (!id) return null

	const version = fieldValue(entry[0], 'Version')
	const tags = fieldValue(entry[0], 'Tags').split(/\s+/).filter((tag) => tag && !isGeneratedTag(tag))

	return {
		id,
		version,
		description: stripHtml(fieldValue(entry[0], 'Description')),
		iconUrl: fieldValue(entry[0], 'IconUrl'),
		projectUrl: fieldValue(entry[0], 'ProjectUrl'),
		galleryUrl: fieldValue(entry[0], 'GalleryDetailsUrl') || packagePageUrl(id, version),
		tags
	}
}

/**
 * 查询图库上某个模块的最新稳定版。
 *
 * @param {string} id - 模块名
 * @returns {Promise<object | null>} 模块信息，未找到时为 null
 */
async function fetchPackageInfo (id) {
	// OData 字符串字面量中的单引号需要写成两个。
	const filter = `Id eq '${String(id).replace(/'/g, "''")}' and IsLatestVersion`
	const url = `${API_URL}?$filter=${encodeURIComponent(filter)}&$top=1`
	const controller = new AbortController()
	const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS)
	try {
		const response = await fetch(url, { headers: { Accept: 'application/atom+xml' }, signal: controller.signal })
		if (!response.ok) throw new Error(`PowerShell Gallery returned HTTP ${response.status}`)
		return parseGalleryEntry(await response.text())
	}
	finally {
		clearTimeout(timer)
	}
}

/**
 * 读取（并缓存）某个模块的图库信息。查询失败会从缓存中移除并抛出，未找到（null）则缓存，避免重复查询。
 *
 * @param {string} id - 模块名
 * @returns {Promise<object | null>} 模块信息，未找到时为 null
 */
export async function getPackageInfo (id) {
	const key = String(id || '').toLowerCase()
	if (!key) return null

	const cached = cache.get(key)
	if (cached) return cached

	const pending = fetchPackageInfo(id)
	cache.set(key, pending)
	pending.catch(() => cache.delete(key))
	return pending
}
