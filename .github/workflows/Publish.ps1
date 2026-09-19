# pwsh ./.github/workflows/publish.ps1 -version ${{ github.ref_name }} -ApiKey ${{ secrets.NUGET_API_KEY }}

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$version,
	[Parameter(Mandatory = $true)]
	[string]$ApiKey
)
if ($version -match '^v(\d+\.\d+\.\d+)$') {
	$version = $Matches[1]
}
else {
	throw "invalid version: $version"
}

$repoPath = "$PSScriptRoot/../.."
. $repoPath/src/PSObjectToString.ps1
$error.clear()

try {
	# 读取 psd1
	$packData = Import-PowerShellDataFile "$repoPath/ps12exe.psd1"
	# 更新版本
	$packData.ModuleVersion = $version
	# 更新 psd1
	Set-Content -Path "$repoPath/ps12exe.psd1" -Value $(PSObjectToString($packData)) -NoNewline -Encoding UTF8 -Force
	# 对于每个fbs文件，以xml格式读取，再用linux换行符+tab缩进写回源文件
	. $PSScriptRoot/../../.esh/commands/lint.ps1
	# 遍历文件列表，移除.开头的文件和文件夹
	Get-ChildItem -Path $repoPath -Recurse | Where-Object { $_.Name -match '^\.' } | ForEach-Object { Remove-Item -Path $_.FullName -Force -Recurse }
	# 移除docs
	Remove-Item -Path "$repoPath/docs" -Recurse -Force
	# 移除仅开发期使用、运行时完全用不到的文件
	# 模块运行时入口为 ps12exe.psm1：它及其点源链只依赖 ps12exe.ps1、exe21sp.ps1、
	# src/**（GUI/WebServer/Interact/编译器/locale/bin/programFrames/img）。
	# 下面的测试、开发说明、lint 配置、仓库保护文件与 locale 维护脚本都不在运行时依赖内。
	$devOnlyPaths = @(
		"$repoPath/tools"
		"$repoPath/tests"
		"$repoPath/AGENTS.md"
		"$repoPath/eslint.config.mjs"
		"$repoPath/typos.toml"
		"$repoPath/src/locale/_fbs2txt.ps1"
		"$repoPath/src/locale/_txt2fbs.ps1"
		"$repoPath/src/locale/reorder_locale.ps1"
	)
	$devOnlyPaths | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Remove-Item -LiteralPath $_ -Recurse -Force }
	# 打包发布
	# 部分 runner 上 PSGallery 未预注册，或 PSGallery 偶发超时/限流，会让 Install-Module 报
	# “No match was found ... 'PowerShellGet'”；先补齐默认源再带退避重试。
	if (-not (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
		Register-PSRepository -Default -ErrorAction Ignore
	}
	for ($installTry = 1; ; $installTry++) {
		try {
			Install-Module -Name 'PowerShellGet' -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
			break
		}
		catch {
			if ($installTry -ge 5) { throw }
			Write-Output "Install-Module PowerShellGet failed (attempt $installTry/5): $_"
			Start-Sleep -Seconds (5 * $installTry)
		}
	}
	$Error.Clear()
	$errnum = $Error.Count
	Publish-Module -Path $repoPath -NuGetApiKey $ApiKey -ErrorAction Stop
	while ($Error.Count -gt $errnum) {
		$Error.RemoveAt(0)
	}
}
catch {}

if ($error) {
	Write-Output "::group::PSVersion"
	Write-Output $PSVersionTable
	Write-Output "::endgroup::"

	$error | ForEach-Object {
		Write-Output "::error file=$($_.InvocationInfo.ScriptName),line=$($_.InvocationInfo.ScriptLineNumber),col=$($_.InvocationInfo.OffsetInLine),endColumn=$($_.InvocationInfo.OffsetInLine),tittle=error::$_"
		Write-Output "::group::script stack trace"
		Write-Output $_.ScriptStackTrace
		Write-Output "::endgroup::"
		Write-Output "::group::error details"
		Write-Output $_
		Write-Output "::endgroup::"
	}
	exit 1
}

Write-Output "Nice CI!"
