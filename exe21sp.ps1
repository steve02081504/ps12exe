#Requires -Version 5.1
<#
.SYNOPSIS
	Restore equivalent ps1 from exe built by ps12exe (exe -> ps1).

.DESCRIPTION
	Uses AsmResolver to read script payload from exe:
	- For exe built with standard program frame (CodeDom/CodeAnalysis): reads embedded .NET manifest resource "main.par", GZip-decompresses and decodes as UTF-8 to get the original script.
	- For minimal exe compiled with TinySharp: parses its CIL and PE image, restores the output string and exit code captured by TinySharp,
	  and generates a minimal ps1 containing only that string (and optional exit statement) to equivalently reproduce the behavior.

.PARAMETER ExePath
	Path to the .exe file to decompile.

.PARAMETER OutFile
	Optional path for the output ps1 file. If not specified, writes to stdout.

.EXAMPLE
	exe21sp -ExePath .\myapp.exe
	exe21sp -ExePath .\myapp.exe -OutFile .\myapp.ps1
.EXAMPLE
	Get-ChildItem *.exe | exe21sp
	".\app.exe" | exe21sp
#>
[CmdletBinding()]
param(
	[Parameter(ValueFromPipeline=$true)]
	[string[]]$ExePath,
	[string]$OutFile,
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\src\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Localize,
	[switch]$help
)

#_if PSScript
$global:LastExitCode = 0
$LocalizeData = . $PSScriptRoot\src\LocaleLoader.ps1 -Localize $Localize
function Show-exe21spHelp {
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $LocalizeData.exe21spHelpData | Write-Host
}

if ($help) {
	Show-exe21spHelp
	return
}

$exePathsToProcess = @($ExePath) + @($input) | Where-Object { $_ }
if ($exePathsToProcess.Count -eq 0) {
	Show-exe21spHelp
	Write-Host
	Write-Error -Message $LocalizeData.exe21spI18nData.NoneInput -Category InvalidArgument -ErrorAction Continue
	if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
		$global:LastExitCode = 2
		return
	}
	& $PSScriptRoot\src\Interact\exe21sp.ps1 -Localize $Localize
	return
}

$exe21spI18n = $LocalizeData.exe21spI18nData

$Refs = @(
	'System',
	'System.Core',
	'System.IO.Compression',
	'netstandard, Version=2.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'
)
Get-ChildItem -LiteralPath $PSScriptRoot\src\bin\AsmResolver -Recurse -Filter *.dll | ForEach-Object {
	$Refs += $_.FullName
	try {
		Add-Type -LiteralPath $_.FullName -ErrorVariable $null
	} catch {
		$_.Exception.LoaderExceptions | Out-String | Write-Verbose
		$Error.Remove($_)
	}
}
$ExtractorCode = Get-Content -LiteralPath $PSScriptRoot\src\programFrames\exe21sp.cs -Raw -Encoding UTF8
Add-Type -TypeDefinition $ExtractorCode -ReferencedAssemblies $Refs -IgnoreWarnings

. $PSScriptRoot\src\TaskbarProgress.ps1
$total = $exePathsToProcess.Count
$currentIndex = 0
foreach ($currentExePath in $exePathsToProcess) {
	Write-TaskbarProgress -Percent ([Math]::Min(100, [int](($currentIndex / $total) * 100)))
	$currentExe = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentExePath)
	if (-not (Test-Path -LiteralPath $currentExe -PathType Leaf)) {
		Write-Error (($exe21spI18n['FileNotFound']) -f $currentExePath)
		$global:LastExitCode = 3
		Write-TaskbarProgressError
		$currentIndex++
		continue
	}
	try {
		$script = [exe21sp.Extractor]::ExtractScriptFromExe($currentExe)
	} catch {
		$msg = $_.Exception.Message
		if ($exe21spI18n.ContainsKey($msg)) {
			$msg = $exe21spI18n[$msg]
		}
		Write-Error $msg
		$global:LastExitCode = 1
		Write-TaskbarProgressError
		$currentIndex++
		continue
	}
	if ($null -eq $script) {
		Write-Error (($exe21spI18n['NoEmbeddedScript']) -f $currentExePath)
		$global:LastExitCode = 1
		Write-TaskbarProgressError
		$currentIndex++
		continue
	}
	$currentOutFile = $OutFile
	if (-not $currentOutFile -and -not [System.Console]::IsOutputRedirected) {
		$dir = [System.IO.Path]::GetDirectoryName($currentExe)
		$name = [System.IO.Path]::GetFileNameWithoutExtension($currentExe)
		$currentOutFile = [System.IO.Path]::Combine($dir, "$name.ps1")
	}
	if ($currentOutFile) {
		$currentOutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentOutFile)
		[System.IO.File]::WriteAllText($currentOutFile, $script, [System.Text.UTF8Encoding]::new($false))
		Write-Verbose "Written to $currentOutFile"
	} else {
		Write-Output $script
	}
	$currentIndex++
}
Write-TaskbarProgress -Percent 100
Write-TaskbarProgressClear
#_else
#_require ps12exe
#_!!exe21sp @PSBoundParameters
#_endif
