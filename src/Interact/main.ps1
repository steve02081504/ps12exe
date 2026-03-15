param ($Localize)

#_if PSScript
# Load localization data
. "$PSScriptRoot\..\predicate.ps1"
. "$PSScriptRoot\..\TaskbarProgress.ps1"
. "$PSScriptRoot\..\WriteI18n.ps1"
$LocalizeData = . "$PSScriptRoot\..\LocaleLoader.ps1" -Localize $Localize
Set-I18nData -I18nData $LocalizeData.InteractI18nData
$I18n = $LocalizeData.InteractI18nData

# Set window title for interactive mode
$OldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "ps12exe - $($I18n.ModeName)"

try {
	Write-SymboledWelcomeI18n Welcome

	while ($true) {
		$cmdParams = [System.Collections.ArrayList]::new()
		Write-TaskbarProgress -Percent 0

		# Input file prompt
		$inputFile = ''
		do {
			Write-SymboledInfoI18n EnterInputFile
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$inputFile = Read-Host
			if (-not $inputFile) {
				Write-SymboledErrorI18n InvalidInputFile
			}
			elseif ($inputFile -match "^(https?|ftp)://") {
				# URL: Use HEAD request to verify file exists
				try {
					$null = Invoke-WebRequest -Uri $inputFile -Method Head -ErrorAction Stop
					# For URLs, extension check is optional (URL may not have extension)
					# But if it has extension before query string or fragment, it should be valid
					$urlWithoutQuery = $inputFile -replace '[?#].*$', ''
					if ($urlWithoutQuery -match "\.(ps1|psd1|tmp)$") {
						# Valid URL with valid extension
					}
					elseif ($urlWithoutQuery -match "\.[^./]+$") {
						# URL has extension but not valid
						Write-SymboledErrorI18n InvalidExtension
						$inputFile = ''
					}
					# If no extension, accept it (URL might work without extension)
				}
				catch {
					Write-SymboledErrorI18n FileDoesNotExist
					$inputFile = ''
				}
			}
			else {
				# Local file path
				if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) {
					Write-SymboledErrorI18n FileDoesNotExist
					$inputFile = ''
				}
				elseif ($inputFile -notmatch "\.(ps1|psd1|tmp)$") {
					Write-SymboledErrorI18n InvalidExtension
					$inputFile = ''
				}
			}
		} while (-not $inputFile)
		$cmdParams.Add("-inputFile `"$inputFile`"") | Out-Null
		Write-TaskbarProgress -Percent 15

		# Output file prompt
		$outputFile = ''
		Write-SymboledInfoI18n EnterOutputFile
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		$outputFile = Read-Host
		if ($outputFile) {
			if ($outputFile -notmatch "\.(exe|com|scr|bin|bat|cmd)$") {
				Write-SymboledErrorI18n OutputFileExtensionError
				$outputFile += ".exe"
			}
			$cmdParams.Add("-outputFile `"$outputFile`"") | Out-Null
		}
		Write-TaskbarProgress -Percent 30

		# Additional information prompt
		Write-SymboledQuestionI18n AddAdditionalInfo AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			Write-SymboledProgressI18n CollectingInfo
			$resourceParams = @{}

			# Icon
			$icon = ''
			do {
				Write-SymboledInfoI18n IconPath
				Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
				$iconInput = Read-Host
				if ($iconInput) {
					$isValid = $false
					if ($iconInput -match "^(https?|ftp)://") {
						# URL: Use HEAD request to verify file exists
						try {
							$null = Invoke-WebRequest -Uri $iconInput -Method Head -ErrorAction Stop
							$isValid = $true
						}
						catch {
							Write-SymboledErrorI18n IconDoesNotExist
						}
					}
					else {
						# Local file path
						if (Test-Path -LiteralPath $iconInput -PathType Leaf) {
							$isValid = $true
						}
						else {
							Write-SymboledErrorI18n IconDoesNotExist
						}
					}

					if ($isValid) {
						$icon = $iconInput
						$resourceParams.iconFile = $icon
						break
					}
				}
				else {
					# User chose to skip icon by leaving blank
					break
				}
			} while ($true)

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
				Write-SymboledInfoI18n EnterResourcePrompt -MessageFormatArgs $resourcePrompts[$key]
				Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
				$value = Read-Host
				if ($value) { $resourceParams[$key] = $value }
			}

			# Version
			Write-SymboledInfoI18n Version
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$version = Read-Host
			if ($version) {
				if ($version -notmatch '^\d+(\.\d+){0,3}$') {
					Write-SymboledInvalidI18n InvalidVersionFormat
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
			Write-SymboledProgressI18n SkippingAdditionalInfo
		}
		Write-TaskbarProgress -Percent 50

		# Other options
		Write-SymboledQuestionI18n CompileAsGui AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			$cmdParams.Add("-noConsole") | Out-Null
		}
		Write-TaskbarProgress -Percent 60

		Write-SymboledQuestionI18n RequireAdmin AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			$cmdParams.Add("-requireAdmin") | Out-Null
		}
		Write-TaskbarProgress -Percent 70

		# Code signing
		Write-SymboledQuestionI18n EnableCodeSigning AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (IsEnable(Read-Host)) {
			$codeSigningParams = @{}

			# Certificate Path
			$certPath = ''
			do {
				Write-SymboledInfoI18n EnterCertificatePath
				Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
				$certPathInput = Read-Host
				if ($certPathInput) {
					$isValid = $false
					if ($certPathInput -notmatch '\.pfx$') {
						Write-SymboledErrorI18n InvalidCertificateExtension
					}
					elseif ($certPathInput -match "^(https?|ftp)://") {
						# URL: Use HEAD request to verify file exists
						try {
							$null = Invoke-WebRequest -Uri $certPathInput -Method Head -ErrorAction Stop
							$isValid = $true
						}
						catch {
							Write-SymboledErrorI18n CertificateDoesNotExist
						}
					}
					else {
						# Local file path
						if (Test-Path -LiteralPath $certPathInput -PathType Leaf) {
							$isValid = $true
						}
						else {
							Write-SymboledErrorI18n CertificateDoesNotExist
						}
					}

					if ($isValid) {
						$certPath = $certPathInput
						$codeSigningParams.Path = $certPath

						# Certificate Password
						Write-SymboledInfoI18n EnterCertificatePassword
						Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
						$certPassword = Read-Host -AsSecureString
						if ($certPassword) {
							$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($certPassword)
							$codeSigningParams.Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
							[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
						}
						break
					}
				}
				else {
					# User chose to skip certificate path by leaving blank
					break
				}
			} while ($true)

			# Certificate Thumbprint
			Write-SymboledInfoI18n EnterCertificateThumbprint
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$thumbprint = Read-Host
			if ($thumbprint) {
				$codeSigningParams.Thumbprint = $thumbprint
			}

			# Timestamp Server
			Write-SymboledInfoI18n EnterTimestampServer
			Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
			$timestampServer = Read-Host
			if ($timestampServer) {
				$codeSigningParams.TimestampServer = $timestampServer
			}
			else {
				# Use default timestamp server
				$codeSigningParams.TimestampServer = "http://timestamp.digicert.com"
			}

			if ($codeSigningParams.Count -gt 0) {
				$codeSigningParamsStr = $codeSigningParams.GetEnumerator() | ForEach-Object {
					if ($_.Key -eq 'Password') {
						"$($_.Key)='$($_.Value -replace "'", "''")'"
					}
					else {
						"$($_.Key)='$($_.Value -replace "'", "''")'"
					}
				} | Join-String -Separator '; '
				$cmdParams.Add("-CodeSigning @{$codeSigningParamsStr}") | Out-Null
			}
		}
		else {
			Write-SymboledProgressI18n SkippingCodeSigning
		}
		Write-TaskbarProgress -Percent 85

		# Build and execute command
		Write-SymboledProgressI18n BuildingCommand
		if (Get-Command ps12exe -ErrorAction SilentlyContinue) {
			$command = "ps12exe " + ($cmdParams -join ' ')
		}
		else {
			$scriptPath = Join-Path $PSScriptRoot '..\..\ps12exe.ps1'
			$command = "& `"$scriptPath`" " + ($cmdParams -join ' ')
		}

		Write-SymboledProgressI18n ExecutingCommand
		Write-Host $command
		Write-TaskbarProgress -Percent 90

		try {
			Write-TaskbarProgress
			Invoke-Expression $command
			if ($LASTEXITCODE -eq 0) {
				Write-TaskbarProgressClear
				Write-SymboledSuccessI18n CompileSuccess
			}
			else {
				Write-TaskbarProgressError
				Write-SymboledErrorI18n CompileFailed -MessageFormatArgs $LASTEXITCODE
			}
		}
		catch {
			Write-TaskbarProgressError
			Write-SymboledErrorI18n CompileFailedException -MessageFormatArgs $_.Exception.Message
		}

		Write-SymboledQuestionI18n CompileAnother AdditionalInfoPrompt
		Write-Host -ForegroundColor Gray $I18n.Prompt -NoNewline
		if (-not (IsEnable(Read-Host))) {
			break
		}
	}

	Write-SymboledExitI18n ExitMessage
}
finally {
	Write-TaskbarProgressClear
	$Host.UI.RawUI.WindowTitle = $OldTitle
}
#_else
#_require ps12exe
#_pragma iconFile $PSScriptRoot/../../img/icon.ico
#_pragma title ps12exe - Interact
#_pragma description 'A super cool tool for compile powershell scripts'
#_!!Enter-ps12exeInteract @PSBoundParameters
#_endif
