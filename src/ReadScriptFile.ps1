function ReadScriptFile($File) {
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
			if ($_ -match '^\s*.\s+(?<rest>(\"|)\$PSScriptRoot.+)\s*') {
				$file = GetIncludeFilePath $Matches["rest"]
				if ($file) {
					return ReadScriptFile $file
				}
			}
			elseif ($_ -match '^\s*&\s+(?<rest>(\"|)\$PSScriptRoot.+)\s*') {
				$file = GetIncludeFilePath $Matches["rest"]
				if ($file) {
					return @('&{',$(ReadScriptFile $file),'}')
				}
			}
			$_
		}
	}
	$Content -join "`n"
}
