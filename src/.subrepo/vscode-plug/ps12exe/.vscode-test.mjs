import { existsSync, mkdirSync, rmSync, symlinkSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { where_command } from '@steve02081504/exec'
import { defineConfig } from '@vscode/test-cli'

const projectDir = path.dirname(fileURLToPath(import.meta.url))

/**
 * 把 PATH 上的 `code` 命令解析为 VS Code 可执行文件路径。
 *
 * @returns {Promise<string|undefined>} 可执行文件路径，找不到时为 undefined
 */
async function executableFromPath() {
	try {
		const code = await where_command('code')
		if (!code) return undefined
		if (path.extname(code).toLowerCase() === '.exe') return code
		// 在 Windows 上 `code` 是 `bin\code.cmd` 垫片；可执行文件在上一级目录。在 macOS/Linux 上不适用，直接回退。
		const exe = path.join(path.dirname(path.dirname(code)), 'Code.exe')
		return existsSync(exe) ? exe : code
	}
	catch {
		return undefined
	}
}

/**
 * 当 VS Code 安装位置与项目不在同一个 Windows 驱动器时，`@vscode/test-electron` 会静默跳过测试。通过项目驱动器上的 junction 搭桥可以避免这种情况。
 * @param {string|undefined} executable - VS Code 可执行文件路径
 * @returns {string|undefined} 可用的可执行文件路径
 */
function bridgeToProjectDrive(executable) {
	if (!executable || process.platform !== 'win32') return executable
	const installDir = path.dirname(executable)
	if (path.parse(installDir).root.toLowerCase() === path.parse(projectDir).root.toLowerCase()) return executable

	const bridge = path.join(projectDir, '.vscode-test', 'vscode-local')
	const bridged = path.join(bridge, 'Code.exe')
	try {
		if (existsSync(bridged)) return bridged
		mkdirSync(path.dirname(bridge), { recursive: true })
		rmSync(bridge, { recursive: true, force: true })
		symlinkSync(installDir, bridge, 'junction')
		return bridged
	}
	catch {
		return executable
	}
}

const configured = process.env.VSCODE_EXECUTABLE_PATH || ''
const executable = bridgeToProjectDrive(configured || await executableFromPath())

/**
 * VS Code 集成测试配置，指定测试文件并复用本机安装。
 */
export default defineConfig({
	files: 'test/**/*.test.mjs',
	// 在可用时复用本机安装的 VS Code，而不是下载 300+ MB 的副本；否则回退到下载。可通过 VSCODE_EXECUTABLE_PATH 覆盖。
	...executable && { useInstallation: { fromPath: executable } }
})
