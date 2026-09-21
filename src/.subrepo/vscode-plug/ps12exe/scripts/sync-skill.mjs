#!/usr/bin/env node
// 把 ps12exe 模块里的 Agent Skill 同步进扩展的 skills 目录。
//
// ps12exe 仓库的 src/AgentSkill/SKILL.md 是唯一源；扩展打包（scripts/build.mjs）与
// 测试（npm test 的 pretest）之前都会先复制，保证 VSIX 里带的和模块安装的一致。
// 生成物 skills/ps12exe/SKILL.md 已被 .gitignore 忽略。
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const source = path.join(root, '..', '..', '..', 'AgentSkill', 'SKILL.md')
const target = path.join(root, 'skills', 'ps12exe', 'SKILL.md')

/**
 * 把 ps12exe 仓库的 Agent Skill 复制到扩展的 skills 目录。
 *
 * @returns {string} 复制后的目标文件路径
 */
export function syncSkill() {
	if (!fs.existsSync(source)) throw new Error(`找不到 ps12exe 的 Agent Skill：${source}`)
	fs.mkdirSync(path.dirname(target), { recursive: true })
	fs.copyFileSync(source, target)
	return target
}

// 仅在直接运行本脚本时执行；被 build.mjs import 时不触发复制。
if (import.meta.main) syncSkill()
