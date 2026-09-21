# 测试框架公共库：仓库定位、编译器输入指纹、JSON 读写、GitHub 报告。
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
	param([string]$StartDir)
	if ($env:REPO_ROOT -and (Test-Path -LiteralPath (Join-Path $env:REPO_ROOT 'ps12exe.psd1'))) {
		return (Resolve-Path -LiteralPath $env:REPO_ROOT).Path
	}
	$dir = if ($StartDir) { $StartDir } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
	while ($dir) {
		if (Test-Path -LiteralPath (Join-Path $dir 'ps12exe.psd1')) { return (Resolve-Path -LiteralPath $dir).Path }
		$parent = Split-Path -Path $dir -Parent
		if (-not $parent -or $parent -eq $dir) { break }
		$dir = $parent
	}
	throw "找不到仓库根目录（缺少 ps12exe.psd1）：$StartDir"
}

function Get-NormalizedRelPath {
	param([string]$Path, [string]$Base)
	$full = [System.IO.Path]::GetFullPath($Path)
	if ($Base) {
		$base = [System.IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
		if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
			$full = $full.Substring($base.Length)
		}
	}
	return ($full -replace '\\', '/').TrimStart('/')
}

# 编译输入按「组件」划分：构建缓存键只依赖该构建真正相关的组件，改 CoreCompiler 不会
# 让走 CodeDom/TinySharp 的构建一起失效。路径模式：以 '/' 结尾为目录前缀，支持 '*' 通配。
# 只收录会影响编译产物字节的文件；locale/GUI/WebServer/Interact/exe21sp 等只在编译期或
# 测试运行期使用、不进入产物的文件刻意排除，避免无关改动把构建缓存全打掉。
$script:BuildComponentPatterns = [ordered]@{
	common    = @(
		'ps12exe.ps1', 'ps12exe.psm1', 'ps12exe.psd1',
		'src/AstAnalyze.ps1', 'src/BuildFrame.ps1', 'src/ConstProgramCheck.ps1',
		'src/GolfModeHeader.ps1', 'src/InitCompileThings.ps1', 'src/PSObjectToString.ps1',
		'src/ReadScriptFile.ps1', 'src/predicate.ps1', 'src/GuestUrlGuard.ps1',
		'src/OutputCache.ps1', 'src/AsmWarmup.ps1',
		'src/programFrames/constexpr.cs', 'src/programFrames/CoreHost.cs',
		'src/programFrames/default.cs', 'src/programFrames/DllExport.cs',
		'src/programFrames/pack.cs', 'src/programFrames/TinySharp.cs',
		'src/programFrames/AssemblyInfo.cs',
		'src/RuntimePwsh2.0/'
	)
	codeDom   = @('src/CodeDomCompiler.ps1', 'src/ExeSinker.ps1', 'src/Cache.ps1', 'src/DllExportCompiler.ps1', 'src/bin/AsmResolver/')
	tinySharp = @('src/TinySharpCompiler.ps1')
	core      = @('src/CoreCompiler.ps1', 'src/CoreBundledCompiler.ps1', 'src/CoreProject.ps1', 'src/Cache.ps1')
	ps2exe    = @('src/.subrepo/PS2EXE2ps12exe/')
}

function Test-ComponentPathMatch {
	param([string]$RelPath, [string]$Pattern)
	$Pattern = $Pattern -replace '\\', '/'
	if ($Pattern.EndsWith('/')) { return $RelPath.StartsWith($Pattern, [System.StringComparison]::OrdinalIgnoreCase) }
	if ($Pattern.Contains('*')) { return $RelPath -like $Pattern }
	return $RelPath -eq $Pattern
}

# 解析单个组件的文件清单。目录模式递归收集（跳过 node_modules 与 >2mb 文件）。
function Get-ComponentInputFiles {
	param([string]$RepoRoot, [string]$Component)
	if (-not $script:BuildComponentPatterns.Contains($Component)) { throw "未知的编译输入组件：$Component" }
	$files = [System.Collections.Generic.List[string]]::new()
	foreach ($pat in @($script:BuildComponentPatterns[$Component])) {
		if ($pat.EndsWith('/')) {
			$dir = Join-Path $RepoRoot (($pat.TrimEnd('/')) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
			if (-not (Test-Path -LiteralPath $dir)) { continue }
			Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
				$rel = Get-NormalizedRelPath -Path $_.FullName -Base $RepoRoot
				if ($rel -match '/(node_modules|\.git)/') { return $false }
				if ($_.Length -gt 2mb) { return $false }
				return $true
			} | ForEach-Object { $files.Add($_.FullName) }
		}
		else {
			$p = Join-Path $RepoRoot ($pat -replace '/', [System.IO.Path]::DirectorySeparatorChar)
			if (Test-Path -LiteralPath $p -PathType Leaf) { $files.Add((Resolve-Path -LiteralPath $p).Path) }
		}
	}
	return @($files)
}

# 全部编译输入（所有组件的并集，按路径去重排序）。
function Get-CompilerInputFiles {
	param([string]$RepoRoot)
	$all = [System.Collections.Generic.List[string]]::new()
	foreach ($c in $script:BuildComponentPatterns.Keys) {
		foreach ($f in (Get-ComponentInputFiles -RepoRoot $RepoRoot -Component $c)) { $all.Add($f) }
	}
	return @($all | Sort-Object -Unique)
}

# 扫描仓库文件，默认排除 vcs/build/第三方子模块；跳过 reparse point，避免 junction 造成无限递归。
function Get-RepoFiles {
	param(
		[string]$RepoRoot,
		[string[]]$Extensions,
		[string[]]$ExcludeRelPatterns = @('^(\.git|build|img|docs)/', '^tests/\.cache/', '^src/\.subrepo/(vscode-plug|ps12exeOnline)/', '(^|/)(bin|obj)/')
	)
	$result = [System.Collections.Generic.List[object]]::new()
	function Test-Excluded([string]$rel) {
		if ($rel -match '/node_modules/') { return $true }
		foreach ($pat in $ExcludeRelPatterns) { if ($rel -match $pat) { return $true } }
		return $false
	}
	function Walk([string]$dir) {
		foreach ($item in (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
			$rel = $item.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
			if ($item.PSIsContainer) {
				if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
				if (Test-Excluded $rel) { continue }
				Walk $item.FullName
			}
			elseif (-not (Test-Excluded $rel) -and ($Extensions -contains $item.Extension.ToLowerInvariant())) {
				[void]$result.Add($item)
			}
		}
	}
	Walk $RepoRoot
	return $result
}

# 对指定组件（默认全部）的编译输入做内容哈希。构建缓存键用 -Components 只取相关组件，
# 使某个组件的源变化只让其自身及依赖它的构建失效。
function Get-SourceFingerprint {
	param([string]$RepoRoot, [string[]]$Components)
	$names = if ($Components -and $Components.Count) { @($Components) } else { @($script:BuildComponentPatterns.Keys) }
	$names = @($names | Sort-Object -Unique)
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$sb = [System.Text.StringBuilder]::new()
		foreach ($c in $names) {
			foreach ($f in (Get-ComponentInputFiles -RepoRoot $RepoRoot -Component $c | Sort-Object)) {
				$rel = Get-NormalizedRelPath -Path $f -Base $RepoRoot
				$hash = [System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($f))).Replace('-', '')
				[void]$sb.Append($rel).Append(':').Append($hash).Append("`n")
			}
		}
		$final = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))
		return [System.BitConverter]::ToString($final).Replace('-', '').Substring(0, 32)
	}
	finally { $sha.Dispose() }
}

function Get-StringHash {
	param([string]$Text)
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').Substring(0, 32)
	}
	finally { $sha.Dispose() }
}

function Write-TextFileNoBom {
	param([string]$Path, [string]$Text)
	[System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Read-JsonFile {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path)) { return $null }
	return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-JsonFile {
	param([string]$Path, $Object)
	$text = $Object | ConvertTo-Json -Depth 16 -Compress
	Write-TextFileNoBom -Path $Path -Text $text
}

# ConvertFrom-Json 产出 PSCustomObject；测试用例里统一用哈希表索引。
function ConvertTo-HashtableDeep {
	param($Value)
	if ($null -eq $Value) { return $null }
	if ($Value -is [System.Management.Automation.PSCustomObject]) {
		$ht = @{}
		foreach ($p in $Value.PSObject.Properties) { $ht[$p.Name] = ConvertTo-HashtableDeep $p.Value }
		return $ht
	}
	if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
		$arr = @()
		foreach ($item in $Value) { $arr += , (ConvertTo-HashtableDeep $item) }
		return $arr
	}
	return $Value
}

# ---- 集成状态快照 ----
# integration.toggle 会真实增删用户右键菜单注册表与 ~/.agents/skills/ps12exe。
# 这里在测试前保存完整状态、测试后原样恢复；即使 worker 超时被强杀，
# run.ps1 的兜底也能凭残留快照把环境还原。
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

function Get-VSCodeBasedEditorCommands {
	$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($name in $script:VSCodeBasedEditorNames) {
		$command = Get-Command -Name $name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
		if (-not $command) { continue }
		if ($seen.Add($command.Source)) { $command.Source }
	}
}

function Get-IntegrationVSCodeExtensionState {
	$state = [ordered]@{}
	foreach ($editor in @(Get-VSCodeBasedEditorCommands)) {
		$installed = $false
		try {
			$listed = & $editor --list-extensions 2>$null
			$installed = [bool]($listed | Where-Object { $_ -and ($_.Trim() -ieq $script:VSCodeExtensionId) })
		}
		catch {}
		$state[$editor] = $installed
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

	$vscode = Get-IntegrationVSCodeExtensionState
	Write-JsonFile -Path (Join-Path $dir 'manifest.json') -Object @{ Keys = $keys; HasSkill = [bool]$hasSkill; VSCode = $vscode }
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
		$recorded = $false
		if ($manifest.Keys -and $manifest.Keys.ContainsKey($key)) { $recorded = [bool]$manifest.Keys[$key] }
		if ($recorded) {
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
		foreach ($editor in @($manifest.VSCode.Keys)) {
			if (-not [bool]$manifest.VSCode[$editor]) { continue }
			if ($current[$editor]) { continue }
			$isInstalled = {
				try {
					$listed = & $editor --list-extensions 2>$null
					[bool]($listed | Where-Object { $_ -and ($_.Trim() -ieq $script:VSCodeExtensionId) })
				}
				catch { $false }
			}
			# 本地构建的 VSIX 一般比市场新，优先装它；没有再退回市场。
			$vsix = Get-ChildItem -LiteralPath (Join-Path (Get-RepoRoot) 'src/.subrepo/vscode-plug/ps12exe') -Filter 'ps12exe-*.vsix' -File -ErrorAction Ignore |
				Sort-Object LastWriteTime -Descending | Select-Object -First 1
			if ($vsix) {
				try { & $editor --install-extension $vsix.FullName --force 2>&1 | Out-Null } catch {}
			}
			if (-not (& $isInstalled)) {
				try { & $editor --install-extension $script:VSCodeExtensionId --force 2>&1 | Out-Null } catch {}
			}
			if (& $isInstalled) { Write-Host "== 已为 $editor 重新安装 $($script:VSCodeExtensionId) ==" }
			else { Write-Warning "测试卸载了 $editor 的 $($script:VSCodeExtensionId) 扩展且未能自动装回；请到 src/.subrepo/vscode-plug/ps12exe 运行 npm run build 恢复。" }
		}
	}

	Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Ignore
	return $true
}

function Stop-ProcessTree {
	param([int]$ProcessId)
	if ($ProcessId -le 0) { return }
	try { & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null } catch {}
}

# 与旧 CI 一致的 GitHub 友好错误格式。$Failures: @( @{ Name; Error; Stack; Log } )
function Write-CIGitHubReport {
	param([array]$Failures, [string]$ResultFile)
	if (-not $Failures -or $Failures.Count -eq 0) { return }
	Write-Output '::group::PSVersion'
	Write-Output $PSVersionTable
	Write-Output '::endgroup::'
	foreach ($f in $Failures) {
		Write-Output "::error title=TEST $($f.Name)::$($f.Error)"
		Write-Output '::group::test error details'
		Write-Output "test: $($f.Name)"
		Write-Output "message: $($f.Error)"
		if ($f.Stack) { Write-Output '--- stack trace ---'; Write-Output $f.Stack }
		if ($f.Log) { Write-Output '--- worker log ---'; Write-Output (($f.Log -split "`r?`n" | Select-Object -Last 120) -join "`n") }
		Write-Output '::endgroup::'
	}
}
