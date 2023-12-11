$error.clear()

try{
	mkdir $PSScriptRoot/../../build | Out-Null
	& $PSScriptRoot/../../ps2exe.ps1 $PSScriptRoot/../../ps2exe.ps1 $PSScriptRoot/../../build/ps2exe.exe -verbose | Out-Host
	& $PSScriptRoot/../../build/ps2exe.exe $PSScriptRoot/../../ps2exe.ps1 -verbose | Out-Host
	Remove-Item $PSScriptRoot/../../build -Recurse -Force
}catch{}

if($error){
	$error | ForEach-Object {
		Write-Output "::error file=$($_.InvocationInfo.ScriptName),line=$($_.InvocationInfo.ScriptLineNumber),col=$($_.InvocationInfo.OffsetInLine),endColumn=$($_.InvocationInfo.OffsetInLine),tittle=error::script error"
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
