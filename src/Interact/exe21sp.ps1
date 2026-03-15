# Interactive loop for exe21sp (invoked when exe21sp is run with no arguments and console is not redirected).
param($Localize)

#_if PSScript
. "$PSScriptRoot\..\predicate.ps1"
. "$PSScriptRoot\..\TaskbarProgress.ps1"
. "$PSScriptRoot\..\WriteI18n.ps1"
$LocalizeData = . "$PSScriptRoot\..\LocaleLoader.ps1" -Localize $Localize
Set-I18nData -I18nData $LocalizeData.exe21spInteractI18nData
$I18n = $LocalizeData.exe21spInteractI18nData

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$exe21spScript = Join-Path $repoRoot 'exe21sp.ps1'

$OldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "exe21sp - $($I18n.ModeName)"

try {
	Write-SymboledWelcomeI18n Welcome

	while ($true) {
		Write-TaskbarProgress -Percent 0
		$exe21spArgs = @{}
		$inputFile = ''
		do {
			Write-SymboledInfoI18n EnterInputFile
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$inputFile = Read-Host
			if (-not $inputFile) {
				Write-SymboledErrorI18n InvalidInputFile
			}
			elseif ($inputFile -match "^(https?|ftp)://") {
				try {
					$null = Invoke-WebRequest -Uri $inputFile -Method Head -ErrorAction Stop
				}
				catch {
					Write-SymboledErrorI18n FileDoesNotExist
					$inputFile = ''
				}
			}
			else {
				if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) {
					Write-SymboledErrorI18n FileDoesNotExist
					$inputFile = ''
				}
			}
		} while (-not $inputFile)
		$exe21spArgs.inputFile = $inputFile
		Write-TaskbarProgress -Percent 25

		Write-SymboledInfoI18n EnterOutputFile
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$outputFile = Read-Host
		if ($outputFile) {
			if ($outputFile -notmatch "\.ps1$") {
				Write-SymboledErrorI18n OutputFileExtensionError
				$outputFile += ".ps1"
			}
			$exe21spArgs.outputFile = $outputFile
		}
		Write-TaskbarProgress -Percent 50

		try {
			Write-TaskbarProgress -Percent 75
			if (Get-Command exe21sp -ErrorAction SilentlyContinue) {
				exe21sp @exe21spArgs
			}
			else {
				& $exe21spScript @exe21spArgs
			}
			Write-TaskbarProgress -Percent 100
			Write-TaskbarProgressClear
		}
		catch {
			Write-TaskbarProgressError
			Write-Error $_
		}

		Write-SymboledQuestionI18n ConvertAnother AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (-not (IsEnable(Read-Host))) { break }
	}

	Write-SymboledExitI18n ExitMessage
}
finally {
	Write-TaskbarProgressClear
	$Host.UI.RawUI.WindowTitle = $OldTitle
}
#_else
#_require exe21sp
#_!!Enter-Exe21SpInteract @PSBoundParameters
#_endif
