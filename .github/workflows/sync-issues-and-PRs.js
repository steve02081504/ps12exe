/**
 * @param {object} params
 * @param {import('@octokit/core').Octokit} params.github
 * @param {import('@actions/github/lib/context').Context} params.context
 */
module.exports = async ({ github, context }) => {
	// --- 配置项 ---
	const SYNC_LABEL = 'synced-from-PS2EXE' // 用于标记已同步 Issue 的标签，请确保此标签在仓库中存在！
	const ISSUE_TITLE_PREFIX = '[Sync]'
	const PR_TITLE_PREFIX = '[PR Sync]'
	const targetRepoPath = 'MScholtes/PS2EXE'

	// --- 辅助函数 ---

	/** 从 Issue 正文中提取原始链接 */
	const getOriginalUrlFromIssueBody = (body) => {
		if (!body)
			return null

		// 为了日志清晰，只打印前300个字符
		const bodySnippet = body.substring(0, 300).replace(/\n/g, '\\n')

		const match = body.match(/\*\*Original (?:Issue|PR):\*\*\s*(https?:\/\/\S+)/)

		if (match && match[1])
			return match[1]
		else
			return null
	}

	/** 获取当前仓库中所有已同步的 Issue 的原始链接集合 */
	const getExistingSyncedUrls = async (currentRepo) => {
		const syncedUrls = new Set()
		const query = `repo:${currentRepo.owner}/${currentRepo.repo} is:issue label:"${SYNC_LABEL}"`

		const allSyncedItems = await github.paginate(github.rest.search.issuesAndPullRequests, {
			q: query,
		})

		for (const issue of allSyncedItems) {
			const originalUrl = getOriginalUrlFromIssueBody(issue.body)
			if (originalUrl)
				syncedUrls.add(originalUrl)
		}

		return syncedUrls
	}

	/** 同步目标仓库的项目（Issue 或 PR） */
	const syncItems = async (targetRepo, currentRepo, existingUrls, itemType) => {
		console.log(`\n>>> Starting sync for ${itemType}s from ${targetRepo.owner}/${targetRepo.repo}...`)

		const listOptions = { ...targetRepo, state: 'open' }

		let items
		if (itemType === 'Issue') {
			// 获取所有 issue，然后过滤掉 PR
			const allIssues = await github.paginate(github.rest.issues.listForRepo, listOptions)
			items = allIssues.filter(issue => !issue.pull_request)
		} else
			// 只获取 PR
			items = await github.paginate(github.rest.pulls.list, listOptions)

		let createdCount = 0
		for (const item of items) {
			const originalUrl = item.html_url
			if (existingUrls.has(originalUrl))
				continue // 如果已存在，直接跳过

			console.log(`- Processing new ${itemType} #${item.number}: ${item.title}`)

			const titlePrefix = itemType === 'Issue' ? ISSUE_TITLE_PREFIX : PR_TITLE_PREFIX
			const newTitle = `${titlePrefix} ${item.title}`
			const authorLogin = item.user.login;
			const newBody = `> [!NOTE]\n> This is a synced copy. Do not edit directly.\n> **Original ${itemType}:** ${originalUrl} from @${authorLogin}\n\n---\n\n${item.body || ''}`

			try {
				await github.rest.issues.create({
					...currentRepo,
					title: newTitle,
					body: newBody,
					labels: [SYNC_LABEL],
				})
				console.log(`  - Successfully created issue for ${itemType} ${originalUrl}`)
				createdCount++
				await new Promise(r => setTimeout(r, 1000)) // 短暂休眠，防止API速率限制
			} catch (error) {
				console.error(`  - Failed to create issue for ${originalUrl}. Error: ${error.message}`)
			}
		}

		if (createdCount === 0)
			console.log(`All ${itemType}s are already up-to-date.`)
		else
			console.log(`Successfully created ${createdCount} new issue(s) for ${itemType}s.`)
	}

	// --- 主逻辑 ---
	try {
		// 1. 获取输入和上下文
		const { owner: currentOwner, repo: currentRepoName } = context.repo
		const [targetOwner, targetRepoName] = targetRepoPath.split('/')
		if (!targetOwner || !targetRepoName)
			throw new Error('Invalid "target-repo" format. Expected "owner/repo-name".')

		const currentRepo = { owner: currentOwner, repo: currentRepoName }
		const targetRepo = { owner: targetOwner, repo: targetRepoName }

		console.log('Sync process started.')
		console.log(`Source Repo: ${targetRepoPath}`)
		console.log(`Destination Repo: ${currentOwner}/${currentRepoName}`)

		// 2. 执行同步
		const existingUrls = await getExistingSyncedUrls(currentRepo)
		await syncItems(targetRepo, currentRepo, existingUrls, 'Issue')
		await syncItems(targetRepo, currentRepo, existingUrls, 'PR')

		console.log('\nSync process finished successfully!')
	} catch (error) {
		console.error(error)
		// 在 github-script 中，抛出错误会自动将步骤标记为失败
		throw error
	}
}
