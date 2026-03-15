# Interactive loop for exe21sp (invoked when exe21sp is run with no arguments and console is not redirected).
param($Localize)

#_if PSScript
. "$PSScriptRoot\..\predicate.ps1"
$LocalizeData = . "$PSScriptRoot\..\LocaleLoader.ps1" -Localize $Localize
$I18n = $LocalizeData.exe21spInteractI18nData

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$exe21spScript = Join-Path $repoRoot 'exe21sp.ps1'

$OldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "exe21sp - $($I18n.ModeName)"

try {
	function Write-I18n {
		param(
			[string]$Symbol,
			[string]$Message,
			[string]$Sequence,
			[ConsoleColor]$SymbolColor,
			[ConsoleColor]$MessageColor = 'White',
			[ConsoleColor]$SequenceColor = 'White'
		)
		Write-Host -NoNewline " "
		Write-Host -ForegroundColor $SymbolColor $Symbol -NoNewline
		Write-Host -ForegroundColor $MessageColor " $Message" -NoNewline
		Write-Host -ForegroundColor $SequenceColor " $Sequence"
	}

	Write-I18n "[*]" $I18n.Welcome -SymbolColor Cyan

	while ($true) {
		$exe21spArgs = @{}
		Write-I18n "[*]" $I18n.EnterExePath -SymbolColor Green
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$exe21spArgs.ExePath = Read-Host
		if (-not $exe21spArgs.ExePath) { break }

		Write-I18n "[*]" $I18n.EnterOutputPs1Path -SymbolColor Green
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$exe21spArgs.OutFile = Read-Host

		try {
			if (Get-Command exe21sp -ErrorAction SilentlyContinue) {
				exe21sp @exe21spArgs
			} else {
				& $exe21spScript @exe21spArgs
			}
		} catch {
			Write-Error $_
		}

		Write-I18n "[?]" $I18n.ConvertAnother $I18n.AdditionalInfoPrompt -SymbolColor Blue -SequenceColor DarkGray
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (-not (IsEnable(Read-Host))) { break }
	}

	Write-I18n "[/]" $I18n.Exiting -SymbolColor Yellow
}
finally {
	$Host.UI.RawUI.WindowTitle = $OldTitle
}
#_else
#_require exe21sp
#_!!Enter-Exe21SpInteract @PSBoundParameters
#_endif
