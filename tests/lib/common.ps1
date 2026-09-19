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
		'src/programFrames/constexpr.cs', 'src/programFrames/CoreHost.cs',
		'src/programFrames/default.cs', 'src/programFrames/DllExport.cs',
		'src/programFrames/pack.cs', 'src/programFrames/TinySharp.cs',
		'src/RuntimePwsh2.0/'
	)
	codeDom   = @('src/CodeDomCompiler.ps1', 'src/ExeSinker.ps1')
	tinySharp = @('src/TinySharpCompiler.ps1')
	core      = @('src/CoreCompiler.ps1')
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
		[string[]]$ExcludeRelPatterns = @('^(\.git|build|img|docs)/', '^tests/\.cache/', '^src/\.subrepo/(vscode-plug|ps12exeOnline)/')
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
