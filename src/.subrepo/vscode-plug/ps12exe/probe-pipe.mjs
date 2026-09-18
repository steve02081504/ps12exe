import fs from 'node:fs'
import { analyze, indentText, branchFragments, computeSkipMask } from './lib/preprocessor.mjs'
import { resolvePlainPowerShell, findIncompleteFragments } from './lib/powershell.mjs'

const repo = 'C:/Users/steve02081504/Documents/workstation/pwsh_workdirs/ps12exe'
const orig = fs.readFileSync(repo + '/ps12exe.ps1', 'utf8').replace(/^\uFEFF/, '')
const fmt = fs.readFileSync(process.env.TEMP + '/ps12exe.fmt.ps1', 'utf8')

const { blocks, lines } = analyze(fmt)
const fragments = branchFragments(blocks, lines)
const host = await resolvePlainPowerShell()
const flags = await findIncompleteFragments({ host, texts: fragments.map((f) => f.text) })
const incomplete = new Set()
fragments.forEach((f, i) => { if (flags[i]) incomplete.add(f.block) })
console.log('blocks', blocks.length, 'incomplete', [...incomplete])

const out = indentText(fmt, { indentUnit: '\t', incompleteBlocks: incomplete })
fs.writeFileSync(process.env.TEMP + '/ps12exe.pipe2.ps1', out)
fs.writeFileSync(process.env.TEMP + '/ps12exe.orig-nobom.ps1', orig)
console.log('orig', orig.length, 'out', out.length, 'equal', out === orig)
