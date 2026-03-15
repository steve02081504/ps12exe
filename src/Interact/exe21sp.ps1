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
		Write-SymboledInfoI18n EnterExePath
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$exe21spArgs.ExePath = Read-Host
		if (-not $exe21spArgs.ExePath) { break }
		Write-TaskbarProgress -Percent 25

		Write-SymboledInfoI18n EnterOutputPs1Path
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$exe21spArgs.OutFile = Read-Host
		Write-TaskbarProgress -Percent 50

		try {
			Write-TaskbarProgress -Percent 75
			if (Get-Command exe21sp -ErrorAction SilentlyContinue) {
				exe21sp @exe21spArgs
			} else {
				& $exe21spScript @exe21spArgs
			}
			Write-TaskbarProgress -Percent 100
			Write-TaskbarProgressClear
		} catch {
			Write-TaskbarProgressError
			Write-Error $_
		}

		Write-SymboledQuestionI18n ConvertAnother AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (-not (IsEnable(Read-Host))) { break }
	}

	Write-SymboledExitI18n Exiting
}
finally {
	Write-TaskbarProgressClear
	$Host.UI.RawUI.WindowTitle = $OldTitle
}
#_else
#_require exe21sp
#_!!Enter-Exe21SpInteract @PSBoundParameters
#_endif
