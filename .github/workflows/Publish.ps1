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
$script:tabnum = 0
function PSObjectToString($obj) {
	if ($obj -is [hashtable]) {
		$script:tabnum += 1
		$str = "@{`n" + (($obj.GetEnumerator() | ForEach-Object {
					"`t" * $script:tabnum
					$_.Key + ' = ' + $(PSObjectToString($_.Value)) + "`n"
				}) -join '')
		$str += "`t" * ($script:tabnum - 1) + "}"
		$str
		$script:tabnum -= 1
	}
	elseif ($obj -is [array]) {
		'@(' + (($obj | ForEach-Object {
					$(PSObjectToString($_))
					', '
				} | Select-Object -SkipLast 1) -join '') + ')'
	}
	elseif ($obj -is [string]) {
		"'" + $obj.Replace("'", "''") + "'"
	}
	elseif ($obj -is [int]) { $obj }
	elseif ($obj -is [bool]) { if ($obj) { '$true' } else { '$false' } }
	else { throw "invalid type: $obj" }
}

$error.clear()

$repoPath = "$PSScriptRoot/../.."
try {
	# read psd1
	$packData = Import-PowerShellDataFile "$repoPath/ps12exe.psd1"
	# update version
	$packData.ModuleVersion = $version
	# update psd1
	Set-Content -Path "$repoPath/ps12exe.psd1" -Value $(PSObjectToString($packData)) -NoNewline -Encoding UTF8 -Force
	# 遍历文件列表，移除不在$packData.FileList中的文件
	Get-ChildItem -Path $repoPath -Recurse -File -Force | ForEach-Object {
		if ($packData.FileList -notcontains $_.Name) {
			Remove-Item $_.FullName -Force -Recurse
		}
	}
	# 打包发布
	Install-Module -Name 'PowerShellGet' -Force -Scope CurrentUser | Out-Null
	$errnum = $Error.Count
	Publish-Module -Path $repoPath -NuGetApiKey $ApiKey -Verbose -ErrorAction Stop
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
