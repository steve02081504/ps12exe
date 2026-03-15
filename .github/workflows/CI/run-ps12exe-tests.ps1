# ps12exe 构建与基础运行测试；无状态：测试前后恢复右键菜单状态。失败时输出 GitHub 友好 ::error/::group。
$ErrorActionPreference = 'Stop'
$error.Clear()
$repoRoot = $env:REPO_ROOT
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$buildDir = Join-Path $repoRoot 'build'
$ciDir = Join-Path $repoRoot '.github/workflows/CI'

. (Join-Path $ciDir 'test-helpers.ps1')

$contextMenuWasEnabled = Save-ps12exeContextMenuState
try {
	Import-Module $repoRoot -Force
	New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

	# 构建主 exe
	& $repoRoot/ps12exe.ps1 $repoRoot/ps12exe.ps1 $repoRoot/build/ps12exe.exe -Verbose | Write-Host
	if (-not (Test-Path (Join-Path $buildDir 'ps12exe.exe'))) { throw 'ps12exe.exe not built' }

	# 无状态：仅在测试中临时启用右键菜单（若需测试菜单则启用），测试后恢复
	Set-ps12exeContextMenu -action enable | Out-Null

	# 控制台 + noConsole + 二次编译
	& $repoRoot/build/ps12exe.exe $repoRoot/ps12exe.ps1 -Verbose -noConsole -title 'lol' | Write-Host
	& $repoRoot/build/ps12exe.exe $repoRoot/ps12exe.ps1 $repoRoot/build/ps12exe2.exe -Verbose | Write-Host
	"'Hello 世界！👾'" | ps12exe -outputFile $repoRoot/build/hello.exe -Verbose | Write-Host
	& $repoRoot/build/ps12exe2.exe -Content '$PSEXEpath;$PSScriptRoot' -outputFile $repoRoot/build/pathtest.exe | Write-Host

	$pathresult = . $repoRoot/build/pathtest.exe
	$pathresultshouldbe = @("$repoRoot/build/pathtest.exe", "$repoRoot/build")
	if ($pathresult.Count -ne $pathresultshouldbe.Count) { Write-Error "pathresult.Count -ne pathresultshouldbe.Count" }
	for ($i = 0; $i -lt $pathresult.Count; $i++) {
		$path1 = [System.IO.Path]::GetFullPath($pathresult[$i])
		$path2 = [System.IO.Path]::GetFullPath($pathresultshouldbe[$i])
		if ($path1 -ne $path2) { Write-Error "$path1 -ne $path2" }
	}
	& $repoRoot/build/hello.exe | Write-Host

	# Pipeline/redirection: when stdout is redirected, ps12exe outputs only the exe path
	Set-Content -LiteralPath (Join-Path $buildDir 'redirect_test.ps1') -Value "Write-Output 'redirect-test'" -Encoding UTF8
	$expectedExePath = [System.IO.Path]::GetFullPath((Join-Path $buildDir 'redirect_test.exe'))
	$capturedPath = & $repoRoot/ps12exe.ps1 -inputFile (Join-Path $buildDir 'redirect_test.ps1') 2>$null
	if ([System.IO.Path]::GetFullPath($capturedPath) -ne $expectedExePath) { throw "ps12exe redirect: expected path $expectedExePath , got: $capturedPath" }

	# 供 workflow 上传产物：将 exe 拷到仓库根
	Copy-Item -LiteralPath (Join-Path $buildDir 'ps12exe.exe') -Destination (Join-Path $repoRoot 'ps12exe.exe') -Force
} catch {}
finally {
	Restore-ps12exeContextMenuState -WasEnabled $contextMenuWasEnabled
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'Nice CI!'