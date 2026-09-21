# 集成测试的共享环境快照：integration.toggle 会真实增删用户右键菜单注册表与
# ~/.agents/skills/ps12exe（也可能装卸 VS Code 扩展）。这里在测试前保存完整状态、
# 测试后原样恢复；即使 worker 超时被强杀，run.ps1 的兜底也能凭残留快照把环境还原。
# 依赖 common.ps1 的 JSON 读写与 Get-RepoRoot，调用方需先 dot-source common.ps1。

$script:IntegrationRegistryKeys = @(
	'Software\Classes\*\shell\ps12exeCompile'
	'Software\Classes\*\shell\ps12exeGUIOpen'
	'Software\Classes\ps12exeGUI.psccfg'
	'Software\Classes\.psccfg'
)

# 与 src/Integration/Set-ps12exeVSCodeExtension.ps1 保持一致：探测到的编辑器与扩展 id。
$script:VSCodeExtensionId = 'steve02081504.ps12exe'
$script:VSCodeBasedEditorNames = @(
	'code', 'code-insiders', 'codium', 'vscodium', 'cursor', 'windsurf', 'trae', 'positron', 'void'
)

# 探测本机安装的 VS Code 系编辑器 CLI；指向同一 CLI 的别名只保留一次。
function Get-VSCodeBasedEditorCommands {
	$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($name in $script:VSCodeBasedEditorNames) {
		$command = Get-Command -Name $name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
		if ($command -and $seen.Add($command.Source)) { $command.Source }
	}
}

function Test-VSCodeExtensionInstalled {
	param([string]$Editor)
	try {
		$listed = & $Editor --list-extensions 2>$null
		return [bool]($listed | Where-Object { $_ -and ($_.Trim() -ieq $script:VSCodeExtensionId) })
	}
	catch { return $false }
}

function Get-IntegrationVSCodeExtensionState {
	$state = [ordered]@{}
	foreach ($editor in @(Get-VSCodeBasedEditorCommands)) {
		$state[$editor] = Test-VSCodeExtensionInstalled -Editor $editor
	}
	return $state
}

function Get-IntegrationSnapshotDir {
	param([Parameter(Mandatory)][string]$CacheRoot)
	Join-Path $CacheRoot 'integration-snapshot'
}

function Get-Ps12exeAgentSkillDir {
	param([string]$HomeDir = $HOME)
	Join-Path $HomeDir '.agents/skills/ps12exe'
}

function Save-IntegrationSnapshot {
	param([Parameter(Mandatory)][string]$CacheRoot, [string]$HomeDir = $HOME)
	# 若上次快照残留（说明有 worker 被强杀），先还原再重新快照，避免把脏状态当基线。
	if (Test-Path -LiteralPath (Join-Path (Get-IntegrationSnapshotDir -CacheRoot $CacheRoot) 'manifest.json')) {
		[void](Restore-IntegrationSnapshot -CacheRoot $CacheRoot -HomeDir $HomeDir)
	}
	$dir = Get-IntegrationSnapshotDir -CacheRoot $CacheRoot
	New-Item -ItemType Directory -Path $dir -Force | Out-Null

	$keys = [ordered]@{}
	$i = 0
	foreach ($key in $script:IntegrationRegistryKeys) {
		$exists = Test-Path -LiteralPath "Registry::HKEY_CURRENT_USER\$key"
		$keys[$key] = [bool]$exists
		if ($exists) {
			$regFile = Join-Path $dir "key-$i.reg"
			& reg.exe export "HKCU\$key" $regFile /y | Out-Null
			if ($LASTEXITCODE) { throw "导出注册表快照失败：HKCU\$key" }
		}
		$i++
	}

	$skillDir = Get-Ps12exeAgentSkillDir -HomeDir $HomeDir
	$hasSkill = Test-Path -LiteralPath $skillDir
	if ($hasSkill) { Copy-Item -LiteralPath $skillDir -Destination (Join-Path $dir 'skill') -Recurse -Force }

	Write-JsonFile -Path (Join-Path $dir 'manifest.json') -Object @{
		Keys     = $keys
		HasSkill = [bool]$hasSkill
		VSCode   = Get-IntegrationVSCodeExtensionState
	}
}

function Restore-IntegrationSnapshot {
	param([Parameter(Mandatory)][string]$CacheRoot, [string]$HomeDir = $HOME)
	$dir = Get-IntegrationSnapshotDir -CacheRoot $CacheRoot
	$manifest = Read-JsonFile -Path (Join-Path $dir 'manifest.json')
	if (-not $manifest) { return $false }
	$manifest = ConvertTo-HashtableDeep $manifest

	# 先清空测试可能改过的全部键，再按快照回填，避免残留测试数据。
	$i = 0
	foreach ($key in $script:IntegrationRegistryKeys) {
		$regPath = "Registry::HKEY_CURRENT_USER\$key"
		if (Test-Path -LiteralPath $regPath) { Remove-Item -LiteralPath $regPath -Recurse -Force -ErrorAction Ignore }
		if ($manifest.Keys[$key]) {
			$regFile = Join-Path $dir "key-$i.reg"
			if (Test-Path -LiteralPath $regFile) {
				& reg.exe import $regFile | Out-Null
				if ($LASTEXITCODE) { Write-Warning "导入注册表快照失败：HKCU\$key" }
			}
		}
		$i++
	}

	$skillDir = Get-Ps12exeAgentSkillDir -HomeDir $HomeDir
	if (Test-Path -LiteralPath $skillDir) { Remove-Item -LiteralPath $skillDir -Recurse -Force -ErrorAction Ignore }
	if ($manifest.HasSkill) {
		$skillBackup = Join-Path $dir 'skill'
		if (Test-Path -LiteralPath $skillBackup) {
			New-Item -ItemType Directory -Path (Split-Path -Parent $skillDir) -Force | Out-Null
			Copy-Item -LiteralPath $skillBackup -Destination $skillDir -Recurse -Force
		}
	}

	# VS Code 扩展：快照前已装而现在不见了，说明测试期间被卸；尽力重装并明确报告。
	if ($manifest.VSCode) {
		$current = Get-IntegrationVSCodeExtensionState
		# 本地构建的 VSIX 一般比市场新，优先装它；没有再退回市场。
		$vsix = Get-ChildItem -LiteralPath (Join-Path (Get-RepoRoot) 'src/.subrepo/vscode-plug/ps12exe') -Filter 'ps12exe-*.vsix' -File -ErrorAction Ignore |
			Sort-Object LastWriteTime -Descending | Select-Object -First 1
		foreach ($editor in @($manifest.VSCode.Keys)) {
			if (-not $manifest.VSCode[$editor] -or $current[$editor]) { continue }
			if ($vsix) {
				try { & $editor --install-extension $vsix.FullName --force 2>&1 | Out-Null } catch {}
			}
			if (-not (Test-VSCodeExtensionInstalled -Editor $editor)) {
				try { & $editor --install-extension $script:VSCodeExtensionId --force 2>&1 | Out-Null } catch {}
			}
			if (Test-VSCodeExtensionInstalled -Editor $editor) {
				Write-Host "== 已为 $editor 重新安装 $($script:VSCodeExtensionId) =="
			}
			else {
				Write-Warning "测试卸载了 $editor 的 $($script:VSCodeExtensionId) 扩展且未能自动装回；请到 src/.subrepo/vscode-plug/ps12exe 运行 npm run build 恢复。"
			}
		}
	}

	Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Ignore
	return $true
}
