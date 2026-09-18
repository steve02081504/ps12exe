#!/usr/bin/env node
// 打包扩展并把生成的 VSIX 安装到本地 VS Code。
//
//   npm run build              package + install
//   npm run build -- --no-install
//   npm run build -- --test    run the test suite first
//
// VS Code CLI 通过 `@steve02081504/exec` 的 `where_command` 发现；设置 PS12EXE_VSCODE_EXECUTABLE_PATH 可覆盖它。
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
function readJson (file) {
	return JSON.parse(fs.readFileSync(file, 'utf8'))
}

/**
 * 运行命令，流式输出其结果，并在非零退出时拒绝。
 * @param {string} file - 待运行的可执行文件
 * @param {string[]} args - 命令行参数
 */
async function run (file, args) {
	const { code } = await execFile(file, args, { stdio: 'inherit' })
	if (code !== 0) throw new Error(`${path.basename(file)} ${args.join(' ')} exited with code ${code}`)
}

/**
 * 本地安装的 `vsce` 入口点的路径（如果存在）。
 *
 * @returns {string|undefined} 本地 vsce 入口点路径，不存在时为 undefined
 */
function localVsce () {
	const pkgPath = path.join(root, 'node_modules', '@vscode', 'vsce', 'package.json')
	if (!fs.existsSync(pkgPath)) return undefined
	const {bin} = readJson(pkgPath)
	const entry = typeof bin === 'string' ? bin : bin && bin.vsce
	return entry ? path.join(path.dirname(pkgPath), entry) : undefined
}

/**
 * 运行 `vsce package` 并返回生成的 VSIX 路径。
 *
 * @returns {Promise<string>} 生成的 VSIX 路径
 */
async function packageExtension () {
	const entry = localVsce()
	if (entry) await run(process.execPath, [entry, 'package'])
	else {
		const npx = await where_command('npx') || 'npx'
		await run(npx, ['--yes', '@vscode/vsce', 'package'])
	}

	const { name, version } = readJson(path.join(root, 'package.json'))
	const vsix = path.join(root, `${name}-${version}.vsix`)
	if (!fs.existsSync(vsix)) throw new Error(`expected ${vsix} to exist after packaging`)
	return vsix
}

/**
 * 解析本地 VS Code CLI。`where_command('code')` 在 Windows 上返回 `code.cmd` 垫片，与 GUI 子系统的 `Code.exe` 不同，它会附加到控制台，因此其输出和退出码可用。可通过 PS12EXE_VSCODE_CLI_PATH 覆盖查找。
 *
 * @returns {Promise<string | undefined>} 本地 VS Code CLI 路径，找不到时为 undefined
 */
async function resolveCodeCli () {
	const configured = process.env.PS12EXE_VSCODE_CLI_PATH || process.env.PS12EXE_VSCODE_EXECUTABLE_PATH || process.env.VSCODE_EXECUTABLE_PATH
	if (configured) return configured
	return await where_command('code') || undefined
}

/**
 * 用 `code --install-extension … --force` 安装 VSIX。
 *
 * @param {string} vsix - 待安装的 VSIX 路径
 * @returns {Promise<boolean>} 安装是否执行
 */
async function installExtension (vsix) {
	const code = await resolveCodeCli()
	if (!code) {
		console.warn('\nCould not find the local VS Code CLI; set PS12EXE_VSCODE_EXECUTABLE_PATH to override.')
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
async function main () {
	if (shouldTest) {
		console.log('Running the test suite...\n')
		const cli = path.join(root, 'node_modules', '@vscode', 'test-cli', 'out', 'bin.mjs')
		await run(process.execPath, [cli])
	}

	const vsix = await packageExtension()
	console.log(`\nPackaged ${vsix}`)

	if (shouldInstall && await installExtension(vsix)) 
		console.log('\nReload the VS Code window (Developer: Reload Window) to pick up the new build.')
	
}

await main()
