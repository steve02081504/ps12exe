import { existsSync, mkdirSync, rmSync, symlinkSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@vscode/test-cli'
import { where_command } from '@steve02081504/exec'

const projectDir = path.dirname(fileURLToPath(import.meta.url))

/** Resolves the `code` command on PATH to a VS Code executable path. */
async function executableFromPath () {
	try {
		const code = await where_command('code')
		if (!code) return undefined
		if (path.extname(code).toLowerCase() === '.exe') return code
		// On Windows `code` is the `bin\code.cmd` shim; the executable is one
		// directory up. On macOS/Linux this does not apply and we just fall back.
		const exe = path.join(path.dirname(path.dirname(code)), 'Code.exe')
		return existsSync(exe) ? exe : code
	}
	catch {
		return undefined
	}
}

/**
 * `@vscode/test-electron` silently skips the tests when the VS Code install
 * lives on a different Windows drive than the project. Bridging through a
 * junction on the project drive avoids that.
 */
function bridgeToProjectDrive (executable) {
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

const configured = process.env.PS12EXE_VSCODE_EXECUTABLE_PATH || process.env.VSCODE_EXECUTABLE_PATH
const executable = bridgeToProjectDrive(configured || await executableFromPath())

export default defineConfig({
	files: 'test/**/*.test.mjs',
	// Reuse the VS Code installed on this machine when available instead of
	// downloading a 300+ MB copy; falls back to downloading otherwise. Override
	// with PS12EXE_VSCODE_EXECUTABLE_PATH.
	...(executable && { useInstallation: { fromPath: executable } })
})
