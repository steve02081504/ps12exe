function BaseReadFile($File) {
	$Content = if ($File -match "^(https?|ftp)://") {
		if($GuestMode) {
			if((Invoke-WebRequest $File -Method Head -ErrorAction SilentlyContinue).Headers.'Content-Length' -gt 1mb){
				Write-Error "The file is too large to read." -ErrorAction Stop
			}
			if($File -match "^ftp://") {
				Write-Error "FTP is not supported in GuestMode." -ErrorAction Stop
			}
		}
		(Invoke-WebRequest -Uri $File -ErrorAction SilentlyContinue).Content -replace '^[^\u0000-\u007F]+', ''
	}
	elseif(-not $GuestMode) {
		Get-Content -LiteralPath $File -Encoding UTF8 -ErrorAction SilentlyContinue -Raw
	}
	Write-Host "Reading file $([System.IO.Path]::GetFileName($File)) size $($Content.Length) bytes"
	if (-not $Content) {
		Write-Error "No data found. May be read error or file protected." -ErrorAction Stop
	}
	$Content
}
function ReadScriptFile($File) {
	$Content = BaseReadFile $File
	$Content = $Content -join "`n" -split '\r?\n'
	Write-Verbose "Done reading file $([System.IO.Path]::GetFileName($File)), starting preprocess..."
	Preprocessor $Content $File
	Write-Verbose "Done preprocess file $([System.IO.Path]::GetFileName($File))"
}
. $PSScriptRoot\predicate.ps1
. $PSScriptRoot\PSObjectToString.ps1
function Preprocessor($Content, $FilePath) {
	$Result = @()
	$requiredModules = @()
	$requireFlag = $False
	# 处理#_if <PSEXE/PSScript>、#_else、#_endif
	for ($index = 0; $index -lt $Content.Count; $index++) {
		$Line = $Content[$index]
		if ($Line -match "^\s*#_if\s+(?<condition>\S+)\s*(?!#.*)") {
			$condition = $Matches["condition"]
			$condition = switch ($condition) {
				'PSEXE' { $TRUE }
				'PSScript' { $False }
				default { Write-Error "Unknown condition: $condition`nassuming false."; $False }
			}
			while ($index -lt $Content.Count) {
				$index++
				$Line = $Content[$index]
				if ($Line -match "^\s*#_endif\s*(?!#.*)") {
					break
				}
				if ($condition) { $Result += $Line }
				if ($Line -match "^\s*#_else\s*(?!#.*)") {
					$condition = -not $condition
				}
			}
			if ($Line -notmatch "^\s*#_endif\s*(?!#.*)") {
				Write-Error "Missing #_endif"
				return
			}
		}
		else {
			$Result += $Line
		}
	}
	$ScriptRoot = $FilePath.Substring(0, $FilePath.LastIndexOfAny(@('\', '/')))
	function GetIncludeFilePath($rest) {
		if ($rest -match "((\'[^\']*\')+)\s*(?!#.*)") {
			$file = $Matches[1]
			$file = $file.Substring(1, $file.Length - 2).Replace("''", "'")
		}
		elseif ($rest -match '((\"[^\"]*\")+)\s*(?!#.*)') {
			$file = $Matches[1]
			$file = $file.Substring(1, $file.Length - 2).Replace('""', '"')
		}
		else { $file = $rest }
		$file = $file.Replace('$PSScriptRoot', $ScriptRoot)
		# 若是相对路径，则转换为基于$FilePath的绝对路径
		if ($file -notmatch "^[a-zA-Z]:" -and $file -notmatch "^(https|ftp)://") {
			$file = "$ScriptRoot/$file"
		}
		if (!(Test-Path $file -PathType Leaf)) {
			return
		}
		$file
	}
	$Content = $Result |
	# 处理#_pragma
	ForEach-Object {
		$_ # 对于#_pragma，我们不在预处理时移除它：考虑到它可能被用于$PSEXEscript中
		if ($_ -match "^\s*#_pragma\s+(?<pragmaname>[a-zA-Z_][a-zA-Z_0-9]+)\s*(?!#.*)$") {
			$pragmaname = $Matches["pragmaname"]
			$value = $true
			if ($pragmaname.StartsWith("no")) {
				$pragmaname = $pragmaname.Substring(2)
				$value = $false
			}
			if ($ParamList[$pragmaname].ParameterType -eq [Switch]) {
				$Params[$pragmaname] = [Switch]$value
				return
			}
			if ($ParamList["no$pragmaname"].ParameterType -eq [Switch]) {
				$Params["no$pragmaname"] = [Switch]-not $value
				return
			}
			Write-Warning "Unknown pragma: $($Matches["pragmaname"])"
		}
		elseif ($_ -match "^\s*#_pragma\s+(?<pragmaname>[a-zA-Z_][a-zA-Z_0-9]+)\s+(?<rest>.+)\s*$") {
			$pragmaname = $Matches["pragmaname"]
			$value = $Matches["rest"]
			if ($ParamList[$pragmaname].ParameterType -eq [Switch] -or $ParamList["no$pragmaname"].ParameterType -eq [Switch]) {
				if ($value.IndexOf("#") -ge 0) {
					$value = $value.Substring(0, $value.IndexOf("#"))
				}
				$value = $value.Trim()
				if (IsEnable $value) {
					$value = $true
				}
				elseif (IsDisable $value) {
					$value = $false
				}
				else {
					Write-Warning "Unknown pragma value: $value, cannot take is as a boolean."
					return
				}
				if ($pragmaname.StartsWith("no")) {
					$pragmaname = $pragmaname.Substring(2)
					$value = -not $value
				}
				if ($ParamList[$pragmaname].ParameterType -eq [Switch]) {
					$Params[$pragmaname] = [Switch]$value
				}
				if ($ParamList["no$pragmaname"].ParameterType -eq [Switch]) {
					$Params["no$pragmaname"] = [Switch]-not $value
				}
			}
			elseif ($ParamList[$pragmaname].ParameterType -eq [string]) {
				if ($value -match '^\"(?<value>[^\"]*)\"\s*(?!#.*)') {
					$value = $Matches["value"].Replace('$PSScriptRoot', $ScriptRoot)
				}
				elseif ($value -match "^\'(?<value>[^\']*)\'\s*(?!#.*)") {
					$value = $Matches["value"]
				}
				else {
					$value = $value.Replace('$PSScriptRoot', $ScriptRoot)
				}
				$Params[$pragmaname] = $value
			}
			elseif($ParamList[$pragmaname].ParameterType) {
				Write-Warning "Unknown pragma: $pragmaname, as type $($ParamList[$pragmaname].ParameterType) can't analyze."
			}
			else {
				Write-Warning "Unknown pragma: $pragmaname"
			}
		}
	} |
	# 处理#_require
	ForEach-Object {
		if ($_ -match "^(\s*)#_require\s+(?<moduleList>[^#]+)\s*(?!#.*)") {
			$requiredModules += $Matches["moduleList"].Split(', |;、　') | Where-Object { $_.Trim('"''') -ne '' }
			if (!$requireFlag) {
				$requireFlag = $true
				[bigint]::Parse('72')
			}
		}
		else { $_ }
	} |
	# 处理#_!!<line>
	ForEach-Object {
		if ($_ -match "^(\s*)#_!!(?<line>.*)") {
			$Matches[1] + $Matches["line"]
		}
		else { $_ }
	} |
	# 处理#_include <file>、#_include_as_value <valuename> <file>
	ForEach-Object {
		if ($_ -match "^\s*#_include\s+(?<rest>.+)\s*") {
			$file = GetIncludeFilePath $Matches["rest"]
			ReadScriptFile $file
		}
		elseif ($_ -match "^\s*#_include_as_value\s+(?<valuename>[a-zA-Z_][a-zA-Z_0-9]+)\s+(?<rest>.+)\s*") {
			$valuename = $Matches["valuename"]
			$file = GetIncludeFilePath $Matches["rest"]
			$IncludeContent = BaseReadFile $file
			$IncludeContent = $IncludeContent -join "`n"
			$IncludeContent = $IncludeContent.Replace("'", "''")
			"`$$valuename = '$IncludeContent'"
		}
		else {
			if ($_ -match '^\s*(?<assign>\$\w+\s*\=\s*)?(?<callopt>\.|&)\s*(?<rest>(\"|)\$PSScriptRoot.+)\s*') {
				$assign = $Matches["assign"]
				$rest = $Matches["rest"]
				$callopt = $Matches["callopt"]
				if ($rest -match "^(?<file>\`"[^\`"]*\`")(?<args>.+)") {
					$callargs = $Matches["args"]
					$rest = $Matches["file"]
				}
				elseif ($rest.IndexOf(' ') -gt 0) {
					$callargs = $rest.Substring($rest.IndexOf(' ') + 1)
					$rest = $rest.Substring(0, $rest.IndexOf(' '))
				}
				$file = GetIncludeFilePath $rest
				if ($file) {
					if (!$callargs -and !$assign -and $callopt -eq '.') {
						return ReadScriptFile $file
					}
					return @("$assign$callopt{", $(ReadScriptFile $file), "}$callargs")
				}
			}
			$_
		}
	}
	$LoadModuleScript = if ($requiredModules.Count -gt 1) {
		(PSObjectToString $requiredModules -OneLine) + '|ForEach-Object{if(!(gmo $_ -ListAvailable -ea SilentlyContinue)){Install-Module $_ -Scope CurrentUser -Force -ea Stop}}'
	}
	elseif ($requiredModules.Count -eq 1) {
		"if(!(gmo $requiredModules -ListAvailable -ea SilentlyContinue)){Install-Module $requiredModules -Scope CurrentUser -Force -ea Stop}"
	}
	if ($LoadModuleScript) {
		$Content = $Content | ForEach-Object {
			# 在第一次#_require的前方加入$LoadModuleScript
			if ($_ -is [bigint]) {
				$LoadModuleScript
			} else { $_ }
		}
	}
	$Content -join "`n"
}
