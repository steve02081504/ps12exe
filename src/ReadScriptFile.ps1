﻿function ReadScriptFile($File) {
	$Content = if ($File -match "^(https?|ftp)://") {
		(Invoke-WebRequest -Uri $File -ErrorAction SilentlyContinue).Content
	}
	else {
		Get-Content -LiteralPath $File -Encoding UTF8 -ErrorAction SilentlyContinue -Raw
	}
	Write-Host "Reading file $([System.IO.Path]::GetFileName($File)) size $($Content.Length) bytes"
	$Content = $Content -join "`n" -split '\r?\n'
	if (-not $Content) {
		Write-Error "No data found. May be read error or file protected."
		return
	}
	Write-Verbose "Done reading file $([System.IO.Path]::GetFileName($File)), starting preprocess..."
	Preprocessor $Content $File
	Write-Verbose "Done preprocess file $([System.IO.Path]::GetFileName($File))"
}
. $PSScriptRoot\predicate.ps1
function Preprocessor($Content, $FilePath) {
	$Result = @()
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
				if ($Line -match "^\s*#_else\s*(?!#.*)") {
					$condition = -not $condition
				}
				if ($Line -match "^\s*#_endif\s*(?!#.*)") {
					break
				}
				if ($condition) {
					$Result += $Line
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
		if ($file -notmatch "^[a-zA-Z]:") {
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
			elseif($Params[$pragmaname] -is [string]) {
				if ($value -match '^\"(?<value>[^\"]*)\"\s*(?!#.*)') {
					$value = $Matches["value"]
					$value.Replace('$PSScriptRoot', $ScriptRoot)
				}
				elseif ($value -match "^\'(?<value>[^\']*)\'\s*(?!#.*)") {
					$value = $Matches["value"]
				}
				$Params[$pragmaname] = $value
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
			if (!$file) { return }
			ReadScriptFile $file
		}
		elseif ($_ -match "^\s*#_include_as_value\s+(?<valuename>[a-zA-Z_][a-zA-Z_0-9]+)\s+(?<rest>.+)\s*") {
			$valuename = $Matches["valuename"]
			$file = GetIncludeFilePath $Matches["rest"]
			if (!$file) { return }
			Write-Host "Reading file $([System.IO.Path]::GetFileName($File)) size $((Get-Item $File).Length) bytes"
			$IncludeContent = Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction SilentlyContinue
			if (-not $IncludeContent) {
				Write-Error "No data found. May be read error or file protected."
				return
			}
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
	$Content -join "`n"
}
