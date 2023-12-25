$error.clear()

try{
	mkdir $PSScriptRoot/../../build | Out-Null
	& $PSScriptRoot/../../ps12exe.ps1 $PSScriptRoot/../../ps12exe.ps1 $PSScriptRoot/../../build/ps12exe.exe -verbose | Out-Host
	& $PSScriptRoot/../../build/ps12exe.exe $PSScriptRoot/../../ps12exe.ps1 -verbose | Out-Host
	Remove-Item $PSScriptRoot/../../build -Recurse -Force
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
