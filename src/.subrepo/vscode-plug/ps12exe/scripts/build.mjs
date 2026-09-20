#!/usr/bin/env node
// 打包扩展并把生成的 VSIX 安装到本地 VS Code。
//
//   npm run build              package + install
//   npm run build -- --no-install
//   npm run build -- --test    run the test suite first
//
// VS Code CLI 通过 `@steve02081504/exec` 的 `where_command` 发现；设置 VSCODE_EXECUTABLE_PATH 可覆盖它。
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { execFile, where_command } from '@steve02081504/exec'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const flags = new Set(process.argv.slice(2))
const shouldInstall = !flags.has('--no-install')
const shouldTest = flags.has('--test')

/**
 * 读取并解析 JSON 文件。
 *
 * @param {string} file - JSON 文件路径
 * @returns {any} 解析出的 JSON 内容
 */
function readJson(file) {
	return JSON.parse(fs.readFileSync(file, 'utf8'))
}

/**
 * 运行命令，流式输出其结果，并在非零退出时拒绝。
 * @param {string} file - 待运行的可执行文件
 * @param {string[]} args - 命令行参数
 * @param {object} [options] - 透传给 `execFile` 的选项（如 `cwd`）
 */
async function run(file, args, options = {}) {
	const { code } = await execFile(file, args, { stdio: 'inherit', ...options })
	if (code !== 0) throw new Error(`${path.basename(file)} ${args.join(' ')} exited with code ${code}`)
}

/**
 * 解析 npm 可执行文件路径。
 *
 * @returns {Promise<string>} npm 路径，找不到时退回当前平台上的裸命令名
 */
export async function resolveNpm() {
	return await where_command('npm') || (process.platform === 'win32' ? 'npm.cmd' : 'npm')
}

/**
 * 探测 node_modules 是否是一棵 npm 能理解的生产依赖树。
 *
 * `vsce package` 内部会执行同样的 `npm list --production` 来决定打包哪些依赖；当 node_modules 由其它包管理器（如 Deno）安装成 `.deno` + 符号链接布局时，这条命令会以 ELSPROBLEMS 失败并让整个打包失败，所以这里先探测。
 *
 * @param {string} cwd - 扩展目录
 * @returns {Promise<boolean>} 依赖树是否能被 npm 理解
 */
export async function isDependencyTreeValid(cwd) {
	const npm = await resolveNpm()
	try {
		const { code } = await execFile(npm, ['list', '--production', '--parseable', '--depth=99999', '--loglevel=error'], { cwd })
		return code === 0
	}
	catch {
		return false
	}
}

/**
 * 用 npm 重新安装依赖，把被其它包管理器改写的 node_modules 修回 npm 布局。
 *
 * @param {string} cwd - 扩展目录
 * @returns {Promise<void>} 安装完成，无返回值
 */
export async function repairDependencyTree(cwd) {
	await run(await resolveNpm(), ['install'], { cwd })
}

/**
 * 确保 node_modules 是 npm 能识别的依赖树：先探测，不合法就跑一次 `npm install` 再复查。
 *
 * @param {string} cwd - 扩展目录
 * @param {object} [options] - 覆盖检查/修复/日志，便于测试
 * @param {(cwd: string) => Promise<boolean>} [options.check] - 依赖树探测函数
 * @param {(cwd: string) => Promise<void>} [options.repair] - 依赖树修复函数
 * @param {{ warn: (message: string) => void }} [options.log] - 日志器
 * @returns {Promise<boolean>} 是否执行了修复
 */
export async function ensureDependencyTree(cwd, options = {}) {
	const { check = isDependencyTreeValid, repair = repairDependencyTree, log = console } = options
	if (await check(cwd)) return false
	log.warn('node_modules 不是 npm 依赖树（可能由 Deno 等其它包管理器安装），正在运行 `npm install` 修复……')
	await repair(cwd)
	if (!await check(cwd)) throw new Error('`npm install` 后依赖树仍不合法，请手动运行 `npm install` 后重试')
	return true
}

/**
 * 本地安装的 `vsce` 入口点的路径（如果存在）。
 *
 * @returns {string|undefined} 本地 vsce 入口点路径，不存在时为 undefined
 */
function localVsce() {
	const pkgPath = path.join(root, 'node_modules', '@vscode', 'vsce', 'package.json')
	if (!fs.existsSync(pkgPath)) return undefined
	const { bin } = readJson(pkgPath)
	const entry = typeof bin === 'string' ? bin : bin && bin.vsce
	return entry ? path.join(path.dirname(pkgPath), entry) : undefined
}

/**
 * 运行 `vsce package` 并返回生成的 VSIX 路径。
 *
 * @returns {Promise<string>} 生成的 VSIX 路径
 */
async function packageExtension() {
	await ensureDependencyTree(root)

	const entry = localVsce()
	if (entry) await run(process.execPath, [entry, 'package'], { cwd: root })
	else {
		const npx = await where_command('npx') || 'npx'
		await run(npx, ['--yes', '@vscode/vsce', 'package'], { cwd: root })
	}

	const { name, version } = readJson(path.join(root, 'package.json'))
	const vsix = path.join(root, `${name}-${version}.vsix`)
	if (!fs.existsSync(vsix)) throw new Error(`expected ${vsix} to exist after packaging`)
	return vsix
}

/**
 * 解析本地 VS Code CLI。`where_command('code')` 在 Windows 上返回 `code.cmd` 垫片，与 GUI 子系统的 `Code.exe` 不同，它会附加到控制台，因此其输出和退出码可用。可通过 VSCODE_CLI_PATH 覆盖查找。
 *
 * @returns {Promise<string | undefined>} 本地 VS Code CLI 路径，找不到时为 undefined
 */
async function resolveCodeCli() {
	const configured = process.env.VSCODE_CLI_PATH || process.env.VSCODE_EXECUTABLE_PATH
	if (configured) return configured
	return await where_command('code') || undefined
}

/**
 * 用 `code --install-extension … --force` 安装 VSIX。
 *
 * @param {string} vsix - 待安装的 VSIX 路径
 * @returns {Promise<boolean>} 安装是否执行
 */
async function installExtension(vsix) {
	const code = await resolveCodeCli()
	if (!code) {
		console.warn('\nCould not find the local VS Code CLI; set VSCODE_EXECUTABLE_PATH to override.')
		console.warn(`Install the VSIX manually: code --install-extension "${vsix}" --force`)
		return false
	}

	console.log(`\nInstalling ${path.basename(vsix)}\n  code: ${code}`)
	await run(code, ['--install-extension', vsix, '--force'])
	return true
}

/**
 * 按参数执行测试/打包/安装流程。
 *
 * @returns {Promise<void>} 执行完成，无返回值
 */
async function main() {
	if (shouldTest) {
		console.log('Running the test suite...\n')
		const cli = path.join(root, 'node_modules', '@vscode', 'test-cli', 'out', 'bin.mjs')
		await run(process.execPath, [cli], { cwd: root })
	}

	const vsix = await packageExtension()
	console.log(`\nPackaged ${vsix}`)

	if (shouldInstall && await installExtension(vsix))
		console.log('\nReload the VS Code window (Developer: Reload Window) to pick up the new build.')
}

// 仅在直接运行本脚本时执行；被测试 import 时不触发打包/安装。`import.meta.main` 从 Node 24.2 起可用（见 package.json 的 engines.node），测试宿主里是 undefined。这里不能用顶层 await——测试的 CJS mocha 会 require 它。
if (import.meta.main)
	main().catch((error) => {
		console.error(error)
		process.exitCode = 1
	})
