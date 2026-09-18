import config from 'https://cdn.jsdelivr.net/gh/steve02081504/my-eslint-config/deno.mjs'

/**
 * ESLint 配置：沿用全局规则，并忽略仓库内的依赖与 VS Code 测试运行时。
 * `.vscode-test` 里是完整的 VS Code 安装，自带 `eslint.config.mjs`，不忽略会因缺少其依赖而报错。
 *
 * @type {import('eslint').Linter.FlatConfig[]}
 */
export default [
	{ ignores: ['**/node_modules/**', '**/.vscode-test/**'] },
	...config,
]
