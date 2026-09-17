#Requires -Version 5.1
<#
.SYNOPSIS
	Restore equivalent ps1 from exe built by ps12exe (exe -> ps1).

.DESCRIPTION
	Uses AsmResolver to read script payload from exe:
	- For exe built with the standard program frame: reads the embedded .NET manifest resource "main.ps1" as UTF-8 to get the original script. Packed exes first unwrap the compressed "main" launcher payload and look inside it (gzip for Windows PowerShell builds, Brotli for Core builds).
	  Brotli is not available on .NET Framework, so under Windows PowerShell a Core exe is handed off to pwsh (PowerShell 7); if pwsh is missing, an error is reported.
	- For minimal exe compiled with TinySharp: parses its CIL and PE image, restores the output string and exit code captured by TinySharp,
	  and generates a minimal ps1 containing only that string (and optional exit statement) to equivalently reproduce the behavior.

.PARAMETER inputFile
	Path or URL to the .exe file to decompile.

.PARAMETER outputFile
	Optional path for the output ps1 file. If not specified, writes to stdout when redirected, otherwise writes to <exe>.ps1 in the same directory as the input.

.EXAMPLE
	exe21sp -inputFile .\myapp.exe
	exe21sp -inputFile .\myapp.exe -outputFile .\myapp.ps1
.EXAMPLE
	Get-ChildItem *.exe | exe21sp
	".\app.exe" | exe21sp
#>
[CmdletBinding()]
param(
	[Parameter(ValueFromPipeline=$true)]
	[string[]]$inputFile,
	[string]$outputFile,
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
. $PSScriptRoot\src\WriteI18n.ps1
Set-I18nData -I18nData $LocalizeData.exe21spI18nData
function Show-exe21spHelp {
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $LocalizeData.exe21spHelpData | Write-Host
}

if ($help) {
	Show-exe21spHelp
	return
}

$inputItemsToProcess = @($inputFile) + @($input) | Where-Object { $_ }
if ($outputFile -and ($outputFile = $outputFile.Trim()) -and $outputFile -notmatch '\.ps1$') {
	$outputFile = $outputFile + '.ps1'
}
if ($inputItemsToProcess.Count -eq 0) {
	Show-exe21spHelp
	Write-Host
	Write-I18n Error NoneInput -Category InvalidArgument
	if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
		$global:LastExitCode = 2
		return
	}
	& $PSScriptRoot\src\Interact\exe21sp.ps1 -Localize $Localize
	return
}

function Resolve-ExeInputPath {
	param([string]$PathOrUrl)
	if ($PathOrUrl -match "^(https?|ftp)://") {
		$tempFile = [System.IO.Path]::GetTempFileName()
		try {
			Invoke-WebRequest -Uri $PathOrUrl -OutFile $tempFile -ErrorAction Stop
			return [PSCustomObject]@{ Path = $tempFile; IsTemp = $true }
		} catch {
			Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
			throw
		}
	}
	$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PathOrUrl)
	return [PSCustomObject]@{ Path = $resolved; IsTemp = $false }
}

# Windows PowerShell（.NET Framework）没有 BrotliStream：Core 产物的 Brotli 负载解压转交 pwsh 完成。
# 主处理流程仅在脚本/模块模式运行（exe 版只是 #_require ps12exe 后转发），故直接用同目录脚本，无需模块导入。
function Invoke-ExtractionInPwsh([string]$ExePath) {
	$pwsh = Get-Command pwsh -ErrorAction Ignore
	if (-not $pwsh) { throw 'pwsh not installed' }
	$tempOut = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.ps1')
	try {
		& $pwsh.Source -NoProfile -File "$PSScriptRoot\exe21sp.ps1" -inputFile $ExePath -outputFile $tempOut | Out-Null
		if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempOut)) { throw "pwsh extraction failed (exit $LASTEXITCODE)" }
		return [System.IO.File]::ReadAllText($tempOut, [System.Text.Encoding]::UTF8)
	}
	finally {
		Remove-Item -LiteralPath $tempOut -Force -ErrorAction Ignore
	}
}

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
$total = $inputItemsToProcess.Count
$currentIndex = 0
foreach ($currentInput in $inputItemsToProcess) {
	Write-TaskbarProgress -Percent ([Math]::Min(100, [int](($currentIndex / $total) * 100)))
	$resolved = $null
	try {
		$resolved = Resolve-ExeInputPath -PathOrUrl $currentInput
	} catch {
		if ($currentInput -match "^(https?|ftp)://") {
			Write-I18n Error InputUrlFailed $currentInput
		} else {
			Write-I18n Error FileNotFound $currentInput
		}
		$global:LastExitCode = 3
		Write-TaskbarProgressError
		$currentIndex++
		continue
	}
	$currentExe = $resolved.Path
	if (-not (Test-Path -LiteralPath $currentExe -PathType Leaf)) {
		Write-I18n Error FileNotFound $currentInput
		$global:LastExitCode = 3
		Write-TaskbarProgressError
		if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
		$currentIndex++
		continue
	}
	try {
		$script = [exe21sp.Extractor]::ExtractScriptFromExe($currentExe)
	} catch [exe21sp.BrotliUnavailableException] {
		# 当前是 Windows PowerShell，Core 的 Brotli 负载交给 pwsh 解压。
		try {
			$script = Invoke-ExtractionInPwsh -ExePath $currentExe
		} catch {
			Write-I18n Error CoreExtractNeedsPwsh
			$global:LastExitCode = 1
			Write-TaskbarProgressError
			if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
			$currentIndex++
			continue
		}
	} catch {
		$msg = $_.Exception.Message
		if ($LocalizeData.exe21spI18nData.ContainsKey($msg)) {
			Write-I18n Error $msg
		} else {
			Write-Error $msg
		}
		$global:LastExitCode = 1
		Write-TaskbarProgressError
		if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
		$currentIndex++
		continue
	}
	if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
	if ($null -eq $script) {
		Write-I18n Error NoEmbeddedScript $currentInput
		$global:LastExitCode = 1
		Write-TaskbarProgressError
		$currentIndex++
		continue
	}
	$currentOutFile = $outputFile
	if (-not $currentOutFile -and -not ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected)) {
		$baseName = if ($currentInput -match "^(https?|ftp)://") {
			[System.IO.Path]::GetFileNameWithoutExtension([System.Uri]::new($currentInput).Segments[-1])
		} else {
			[System.IO.Path]::GetFileNameWithoutExtension($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentInput))
		}
		$dir = if ($currentInput -match "^(https?|ftp)://") { $PWD.Path } else { [System.IO.Path]::GetDirectoryName($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentInput)) }
		$currentOutFile = [System.IO.Path]::Combine($dir, "$baseName.ps1")
	}
	if ($currentOutFile) {
		$currentOutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentOutFile)
		[System.IO.File]::WriteAllText($currentOutFile, $script, [System.Text.UTF8Encoding]::new($false))
		Write-Verbose "Written to $currentOutFile"
		if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
			Write-Output $currentOutFile
		}
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
