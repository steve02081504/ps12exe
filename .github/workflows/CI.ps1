$error.clear()

$repoPath = "$PSScriptRoot/../.."
try{
	mkdir $repoPath/build | Out-Null
	Import-Module $repoPath -Force | Out-Host
	& $repoPath/ps12exe.ps1 $repoPath/ps12exe.ps1 $repoPath/build/ps12exe.exe -verbose | Out-Host
	& $repoPath/build/ps12exe.exe $repoPath/ps12exe.ps1 -verbose | Out-Host
	& $repoPath/build/ps12exe.exe $repoPath/ps12exe.ps1 ./tmp.exe -verbose -noConsole | Out-Host
	"'Hello World!'" | ps12exe -outputFile $repoPath/build/hello.exe -verbose | Out-Host
	& $repoPath/build/hello.exe | Out-Host
	Remove-Item $repoPath/build -Recurse -Force
}catch{}

if($error){
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
