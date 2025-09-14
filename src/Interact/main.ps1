param ($Localize)

#_if PSScript
# Load localization data
. "$PSScriptRoot\..\predicate.ps1"
$LocalizeData = . "$PSScriptRoot\..\LocaleLoader.ps1" -Localize $Localize
$I18n = $LocalizeData.InteractI18nData

# Set window title for interactive mode
$OldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "ps12exe - $($I18n.ModeName)"

try {
	# Helper function for colored, internationalized output
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
		$cmdParams = [System.Collections.ArrayList]::new()

		# Input file prompt
		$inputFile = ''
		do {
			Write-I18n "[*]" $I18n.EnterInputFile -SymbolColor Green
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$inputFile = Read-Host
			if (-not $inputFile) {
				Write-I18n "[!]" $I18n.InvalidInputFile -SymbolColor Red
			}
			elseif (-not (Test-Path $inputFile -PathType Leaf)) {
				Write-I18n "[!]" $I18n.FileDoesNotExist -SymbolColor Red
				$inputFile = ''
			}
			elseif ($inputFile -notmatch "\.(ps1|psd1|tmp)$") {
				Write-I18n "[!]" $I18n.InvalidExtension -SymbolColor Red
				$inputFile = ''
			}
		} while (-not $inputFile)
		$cmdParams.Add("-inputFile `"$inputFile`"") | Out-Null

		# Output file prompt
		$outputFile = ''
		Write-I18n "[*]" $I18n.EnterOutputFile -SymbolColor Green
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$outputFile = Read-Host
		if ($outputFile) {
			if ($outputFile -notmatch "\.(exe|com|scr|bin|bat|cmd)$") {
				Write-I18n "[!]" $I18n.OutputFileExtensionError -SymbolColor Red
				$outputFile += ".exe"
			}
			$cmdParams.Add("-outputFile `"$outputFile`"") | Out-Null
		}

		# Additional information prompt
		Write-I18n "[?]" $I18n.AddAdditionalInfo $I18n.AdditionalInfoPrompt -SymbolColor Blue -SequenceColor DarkGray
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			Write-I18n "[~]" $I18n.CollectingInfo -SymbolColor Gray
			$resourceParams = @{}

			# Icon
			Write-I18n "[*]" $I18n.IconPath -SymbolColor Green
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$icon = Read-Host
			if ($icon) {
				if ($icon -notmatch '\.ico$') {
					Write-I18n "[-]" $I18n.InvalidIconExtension -SymbolColor Red
				}
				elseif (-not (Test-Path $icon)) {
					Write-I18n "[-]" $I18n.IconDoesNotExist -SymbolColor Red
				}
				else {
					$resourceParams.iconFile = $icon
				}
			}

			# Other resources
			$resourcePrompts = @{
				title       = $I18n.EnterTitle
				description = $I18n.EnterDescription
				company     = $I18n.EnterCompany
				product     = $I18n.EnterProduct
				copyright   = $I18n.EnterCopyright
				trademark   = $I18n.EnterTrademark
			}
			foreach ($key in $resourcePrompts.Keys) {
				Write-I18n "[*]" ($I18n.EnterResourcePrompt -f $resourcePrompts[$key]) -SymbolColor Green
				Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
				$value = Read-Host
				if ($value) { $resourceParams[$key] = $value }
			}

			# Version
			Write-I18n "[*]" $I18n.Version -SymbolColor Green
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$version = Read-Host
			if ($version) {
				if ($version -notmatch '^\d+(\.\d+){0,3}$') {
					Write-I18n "[-]" $I18n.InvalidVersionFormat -SymbolColor Red
				}
				else {
					$resourceParams.version = $version
				}
			}

			if ($resourceParams.Count -gt 0) {
				$resourceParamsStr = $resourceParams.GetEnumerator() | ForEach-Object { "$($_.Key)='$($_.Value -replace "'", "''")'" } | Join-String -Separator '; '
				$cmdParams.Add("-resourceParams @{$resourceParamsStr}") | Out-Null
			}
		}
		else {
			Write-I18n "[~]" $I18n.SkippingAdditionalInfo -SymbolColor Gray
		}

		# Other options
		Write-I18n "[?]" $I18n.CompileAsGui $I18n.AdditionalInfoPrompt -SymbolColor Blue -SequenceColor DarkGray
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			$cmdParams.Add("-noConsole") | Out-Null
		}

		Write-I18n "[?]" $I18n.RequireAdmin $I18n.AdditionalInfoPrompt -SymbolColor Blue -SequenceColor DarkGray
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			$cmdParams.Add("-requireAdmin") | Out-Null
		}

		# Build and execute command
		Write-I18n "[~]" $I18n.BuildingCommand -SymbolColor Gray
		$scriptPath = Join-Path $PSScriptRoot '..\..\ps12exe.ps1'
		$command = "& `"$scriptPath`" " + ($cmdParams -join ' ')

		Write-I18n "[~]" $I18n.ExecutingCommand -SymbolColor Gray
		Write-Host $command

		try {
			Invoke-Expression $command
			if ($LASTEXITCODE -eq 0) {
				Write-I18n "[+]" $I18n.CompileSuccess -SymbolColor Green
			}
			else {
				Write-I18n "[!]" ($I18n.CompileFailed -f $LASTEXITCODE) -SymbolColor Red
			}
		}
		catch {
			Write-I18n "[!]" ($I18n.CompileFailedException -f $_.Exception.Message) -SymbolColor Red
		}

		Write-I18n "[?" $I18n.CompileAnother $I18n.AdditionalInfoPrompt -SymbolColor Blue -SequenceColor DarkGray
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (-not (IsEnable(Read-Host))) {
			break
		}
	}

	Write-I18n "[/]" $I18n.Exiting -SymbolColor Yellow
	[System.Console]::ReadKey() > $null
}
finally {
	$Host.UI.RawUI.WindowTitle = $OldTitle
}
#_else
#_require ps12exe
#_pragma iconFile $PSScriptRoot/../../img/icon.ico
#_pragma title ps12exe - Interact
#_pragma description 'A super cool tool for compile powershell scripts'
#_!!Enter-ps12exeInteract @PSBoundParameters
#_endif
