$error.clear()

$repoPath = "$PSScriptRoot/../.."
try{
	mkdir $repoPath/build -ErrorAction Ignore | Out-Null
	Import-Module $repoPath -Force | Write-Host
	Set-ps12exeContextMenu 1
	& $repoPath/ps12exe.ps1 $repoPath/ps12exe.ps1 $repoPath/build/ps12exe.exe -verbose | Write-Host
	& $repoPath/build/ps12exe.exe $repoPath/ps12exe.ps1 -verbose -noConsole -title 'lol' | Write-Host
	& $repoPath/build/ps12exe.exe $repoPath/ps12exe.ps1 $repoPath/build/ps12exe2.exe -verbose | Write-Host
	"'Hello World!'" | ps12exe -outputFile $repoPath/build/hello.exe -verbose | Write-Host
	& $repoPath/build/ps12exe2.exe -Content '$PSEXEpath;$PSScriptRoot' -outputFile $repoPath/build/pathtest.exe | Write-Host
	$pathresult=. $repoPath/build/pathtest.exe
	$pathresultshouldbe=@("$repoPath/build/pathtest.exe","$repoPath/build")
	# 在路径层面比较 $pathresult 和 $pathresultshouldbe
	if($pathresult.Count -ne $pathresultshouldbe.Count){
		Write-Error "pathresult.Count -ne pathresultshouldbe.Count"
	}
	for($i=0;$i -lt $pathresult.Count;$i++){
		$path1=[System.IO.Path]::GetFullPath($pathresult[$i])
		$path2=[System.IO.Path]::GetFullPath($pathresultshouldbe[$i])
		if($path1 -ne $path2){
			Write-Error "$path1 -ne $path2"
		}
	}
	& $repoPath/build/hello.exe | Write-Host
	Set-ps12exeContextMenu 0
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
