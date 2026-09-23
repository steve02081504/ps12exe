[CmdletBinding()]
param(
	# 发布输出目录。
	[string]$OutputDir = (Join-Path $PSScriptRoot 'publish'),
	[string]$Configuration = 'Release',
	# 额外生成 zip 包，便于直接上传到 Azure App Service。
	[switch]$Zip
)

$ErrorActionPreference = 'Stop'

# 从当前目录向上找到仓库根（含 ps12exe.psm1 的目录），把编译器一并打包进发布产物。
$RepoRoot = $PSScriptRoot
while ($RepoRoot -and -not (Test-Path -LiteralPath (Join-Path $RepoRoot 'ps12exe.psm1'))) {
	$RepoRoot = Split-Path $RepoRoot -Parent
}
if (-not $RepoRoot) {
	throw 'ps12exe.psm1 not found; run this script from inside the ps12exe repository.'
}

if (Test-Path -LiteralPath $OutputDir) {
	Remove-Item -LiteralPath $OutputDir -Recurse -Force
}

Write-Host "Publishing to $OutputDir ..." -ForegroundColor Cyan
& dotnet publish $PSScriptRoot -c $Configuration -o $OutputDir
if ($LASTEXITCODE -ne 0) {
	throw "dotnet publish failed with exit code $LASTEXITCODE"
}

# 部署包必须自带 ps12exe：Web 进程用 powershell.exe 调用 compiler/ps12exe.psm1。
$CompilerDir = Join-Path $OutputDir 'compiler'
New-Item -ItemType Directory -Path $CompilerDir -Force | Out-Null
foreach ($File in 'ps12exe.psm1', 'ps12exe.ps1', 'ps12exe.psd1', 'exe21sp.ps1') {
	Copy-Item -LiteralPath (Join-Path $RepoRoot $File) -Destination $CompilerDir
}
# 只复制 src 下编译器需要的目录，跳过体积巨大的 src/.subrepo（VS Code 扩展测试副本等）。
$CompilerSrc = Join-Path $CompilerDir 'src'
New-Item -ItemType Directory -Path $CompilerSrc -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'src') -Force |
	Where-Object { $_.Name -ne '.subrepo' } |
	ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $CompilerSrc -Recurse }
Copy-Item -LiteralPath (Join-Path $RepoRoot 'img') -Destination $CompilerDir -Recurse

if ($Zip) {
	$ZipPath = "$OutputDir.zip"
	if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
	Compress-Archive -Path (Join-Path $OutputDir '*') -DestinationPath $ZipPath
	Write-Host "Created $ZipPath" -ForegroundColor Green
}

Write-Host 'Done.' -ForegroundColor Green
