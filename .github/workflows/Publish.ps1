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
	# read psd1
	$packData = Import-PowerShellDataFile "$repoPath/ps12exe.psd1"
	# update version
	$packData.ModuleVersion = $version
	# update psd1
	Set-Content -Path "$repoPath/ps12exe.psd1" -Value $(PSObjectToString($packData)) -NoNewline -Encoding UTF8 -Force
	# 遍历文件列表，移除.开头的文件和文件夹
	Get-ChildItem -Path $repoPath -Recurse | Where-Object { $_.Name -match '^\.' } | ForEach-Object { Remove-Item -Path $_.FullName -Force -Recurse }
	# 对于每个fbs文件，以xml格式读取，再用linux换行符+tab缩进写回源文件
	$XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
	$XmlWriterSettings.Indent = $true
	$XmlWriterSettings.IndentChars = "`t"
	$XmlWriterSettings.NewLineChars = "`n"
	Get-ChildItem -Path $repoPath -Recurse -Filter '*.fbs' | ForEach-Object {
		$XmlDoc = [xml](Get-Content -Path $_.FullName)
		$XmlWriter = [System.XML.XmlWriter]::Create($_.FullName, $XmlWriterSettings)
		$XmlDoc.Save($XmlWriter)
		$XmlWriter.Flush()
		$XmlWriter.Close()
	}
	# 打包发布
	Install-Module -Name 'PowerShellGet' -Force -Scope CurrentUser | Out-Null
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
