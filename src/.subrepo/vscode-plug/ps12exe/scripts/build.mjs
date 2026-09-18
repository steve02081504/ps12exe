#!/usr/bin/env node
// Packages the extension and installs the resulting VSIX into the local VS Code.
//
//   npm run build              package + install
//   npm run build -- --no-install
//   npm run build -- --test    run the test suite first
//
// The VS Code CLI is discovered with `@steve02081504/exec`'s `where_command`;
// set PS12EXE_VSCODE_EXECUTABLE_PATH to override it.
import { execFile, where_command } from '@steve02081504/exec'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const flags = new Set(process.argv.slice(2))
const shouldInstall = !flags.has('--no-install')
const shouldTest = flags.has('--test')

function readJson (file) {
	return JSON.parse(fs.readFileSync(file, 'utf8'))
}

/** Runs a command, streaming its output, and rejects on a non-zero exit. */
async function run (file, args) {
	const { code } = await execFile(file, args, { stdio: 'inherit' })
	if (code !== 0) throw new Error(`${path.basename(file)} ${args.join(' ')} exited with code ${code}`)
}

/** Path to the locally installed `vsce` entry point, if any. */
function localVsce () {
	const pkgPath = path.join(root, 'node_modules', '@vscode', 'vsce', 'package.json')
	if (!fs.existsSync(pkgPath)) return undefined
	const bin = readJson(pkgPath).bin
	const entry = typeof bin === 'string' ? bin : bin && bin.vsce
	return entry ? path.join(path.dirname(pkgPath), entry) : undefined
}

/** Runs `vsce package` and returns the produced VSIX path. */
async function packageExtension () {
	const entry = localVsce()
	if (entry) await run(process.execPath, [entry, 'package'])
	else {
		const npx = (await where_command('npx')) || 'npx'
		await run(npx, ['--yes', '@vscode/vsce', 'package'])
	}

	const { name, version } = readJson(path.join(root, 'package.json'))
	const vsix = path.join(root, `${name}-${version}.vsix`)
	if (!fs.existsSync(vsix)) throw new Error(`expected ${vsix} to exist after packaging`)
	return vsix
}

/**
 * Resolves the local VS Code CLI. `where_command('code')` returns the `code.cmd`
 * shim on Windows, which — unlike the GUI-subsystem `Code.exe` — attaches to the
 * console, so its output and exit code are usable. Override the lookup with
 * PS12EXE_VSCODE_CLI_PATH.
 *
 * @returns {Promise<string | undefined>}
 */
async function resolveCodeCli () {
	const configured = process.env.PS12EXE_VSCODE_CLI_PATH || process.env.PS12EXE_VSCODE_EXECUTABLE_PATH || process.env.VSCODE_EXECUTABLE_PATH
	if (configured) return configured
	return (await where_command('code')) || undefined
}

/**
 * Installs the VSIX with `code --install-extension … --force`.
 *
 * @returns {Promise<boolean>} whether the installation ran
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

async function main () {
	if (shouldTest) {
		console.log('Running the test suite...\n')
		const cli = path.join(root, 'node_modules', '@vscode', 'test-cli', 'out', 'bin.mjs')
		await run(process.execPath, [cli])
	}

	const vsix = await packageExtension()
	console.log(`\nPackaged ${vsix}`)

	if (shouldInstall && await installExtension(vsix)) {
		console.log('\nReload the VS Code window (Developer: Reload Window) to pick up the new build.')
	}
}

await main()
