#Requires -Version 3.0

[CmdletBinding()]
Param([STRING]$inputFile = $NULL, [STRING]$outputFile = $NULL, [STRING]$CompilerOptions = '/o+ /debug-',
	[STRING]$TempDir = $NULL, [scriptblock]$minifyer = $null,
	[SWITCH]$SepcArgsHandling, [SWITCH]$prepareDebug, [SWITCH]$x86, [SWITCH]$x64, [int]$lcid, [SWITCH]$STA, [SWITCH]$MTA,
	[SWITCH]$nested, [SWITCH]$noConsole, [SWITCH]$UNICODEEncoding, [SWITCH]$credentialGUI,
	[STRING]$iconFile = $NULL, [STRING]$title, [STRING]$description, [STRING]$company, [STRING]$product, [STRING]$copyright, [STRING]$trademark, [STRING]$version,
	[SWITCH]$configFile, [SWITCH]$noConfigFile, [SWITCH]$noOutput, [SWITCH]$noError, [SWITCH]$noVisualStyles, [SWITCH]$exitOnCancel,
	[SWITCH]$DPIAware, [SWITCH]$winFormsDPIAware, [SWITCH]$requireAdmin, [SWITCH]$supportOS, [SWITCH]$virtualize, [SWITCH]$longPaths,
	[STRING]$Content = $NULL
)
#_if PSScript #在PSEXE中不需要提供函数 直接执行函数体
<#
.SYNOPSIS
Converts powershell scripts to standalone executables.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end Win-PS2EXE for convenience.

Please see Remarks on project page for topics "GUI mode output formatting", "Config files", "Password security",
"Script variables" and "Window in background in -noConsole mode".

With `SepcArgsHandling`, generated executable has the following reserved parameters:

-debug              Forces the executable to be debugged. It calls "System.Diagnostics.Debugger.Launch()".
-extract:<FILENAME> Extracts the powerShell script inside the executable and saves it as FILENAME.
										The script will not be executed.
-wait               At the end of the script execution it writes "Hit any key to exit..." and waits for a
										key to be pressed.
-end                All following options will be passed to the script inside the executable.
										All preceding options are used by the executable itself.
.PARAMETER inputFile
Powershell script to convert to executable (file has to be UTF8 or UTF16 encoded)
.PARAMETER outputFile
destination executable file name or folder, defaults to inputFile with extension '.exe'
.PARAMETER CompilerOptions
additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)
.PARAMETER TempDir
directory for storing temporary files (default is random generated temp directory in %temp%)
.PARAMETER Minifyer
scriptblock to minify the script before compiling
.PARAMETER SepcArgsHandling
handle special arguments -debug, -extract, -wait and -end. They will be passed to the script inside the executable
.PARAMETER prepareDebug
create helpful information for debugging of generated executable. See parameter -debug there
.PARAMETER x86
compile for 32-bit runtime only
.PARAMETER x64
compile for 64-bit runtime only
.PARAMETER lcid
location ID for the compiled executable. Current user culture if not specified
.PARAMETER STA
Single Thread Apartment mode
.PARAMETER MTA
Multi Thread Apartment mode
.PARAMETER nested
internal use
.PARAMETER noConsole
the resulting executable will be a Windows Forms app without a console window.
You might want to pipe your output to Out-String to prevent a message box for every line of output
(example: dir C:\ | Out-String)
.PARAMETER UNICODEEncoding
encode output as UNICODE in console mode, useful to display special encoded chars
.PARAMETER credentialGUI
use GUI for prompting credentials in console mode instead of console input
.PARAMETER iconFile
icon file name for the compiled executable
.PARAMETER title
title information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER description
description information (not displayed, but embedded in executable)
.PARAMETER company
company information (not displayed, but embedded in executable)
.PARAMETER product
product information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER copyright
copyright information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER trademark
trademark information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER version
version information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER configFile
write a config file (<outputfile>.exe.config)
.PARAMETER noConfigFile
compatibility parameter
.PARAMETER noOutput
the resulting executable will generate no standard output (includes verbose and information channel)
.PARAMETER noError
the resulting executable will generate no error output (includes warning and debug channel)
.PARAMETER noVisualStyles
disable visual styles for a generated windows GUI application. Only applicable with parameter -noConsole
.PARAMETER exitOnCancel
exits program when Cancel or "X" is selected in a Read-Host input box. Only applicable with parameter -noConsole
.PARAMETER DPIAware
if display scaling is activated, GUI controls will be scaled if possible.
.PARAMETER winFormsDPIAware
creates an entry in the config file for WinForms to use DPI scaling. Forces -configFile and -supportOS
.PARAMETER requireAdmin
if UAC is enabled, compiled executable will run only in elevated context (UAC dialog appears if required)
.PARAMETER supportOS
use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference)
.PARAMETER virtualize
application virtualization is activated (forcing x86 runtime)
.PARAMETER longPaths
enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)
.EXAMPLE
ps2exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
.EXAMPLE
ps2exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
#>
function ps2exe {
	[CmdletBinding()]
	Param([STRING]$inputFile = $NULL, [STRING]$outputFile = $NULL, [STRING]$CompilerOptions = '/o+ /debug-',
		[STRING]$TempDir = $NULL, [scriptblock]$minifyer = $null,
		[SWITCH]$SepcArgsHandling, [SWITCH]$prepareDebug, [SWITCH]$x86, [SWITCH]$x64, [int]$lcid, [SWITCH]$STA, [SWITCH]$MTA,
		[SWITCH]$nested, [SWITCH]$noConsole, [SWITCH]$UNICODEEncoding, [SWITCH]$credentialGUI,
		[STRING]$iconFile = $NULL, [STRING]$title, [STRING]$description, [STRING]$company, [STRING]$product, [STRING]$copyright, [STRING]$trademark, [STRING]$version,
		[SWITCH]$configFile, [SWITCH]$noConfigFile, [SWITCH]$noOutput, [SWITCH]$noError, [SWITCH]$noVisualStyles, [SWITCH]$exitOnCancel,
		[SWITCH]$DPIAware, [SWITCH]$winFormsDPIAware, [SWITCH]$requireAdmin, [SWITCH]$supportOS, [SWITCH]$virtualize, [SWITCH]$longPaths,
		[STRING]$Content = $NULL
	)
#_endif
	$SavePos = [char]27 + '[s'
	$RestorePos = [char]27 + '[u'
	if ([STRING]::IsNullOrEmpty($inputFile) -and [STRING]::IsNullOrEmpty($Content)) {
		$Content = $input
		if ($inputFile.Count -gt 1) {
			$Content | ForEach-Object { ps2exe -Content $_ @PSBoundParameters }
			return
		}
	}
	if ([STRING]::IsNullOrEmpty($inputFile) -and [STRING]::IsNullOrEmpty($Content)) {
		Write-Host "Usage:`n"
		Write-Host "ps2exe ([-inputFile] '<filename>' | -Content '<script>') [-outputFile '<filename>'] [-CompilerOptions '<options>']"
		Write-Host "       [-TempDir '<directory>'] [-Minifyer '<scriptblock>']"
		Write-Host "       [-SepcArgsHandling] [-prepareDebug] [-x86|-x64] [-lcid <lcid>] [-STA|-MTA] [-noConsole] [-UNICODEEncoding]"
		Write-Host "       [-credentialGUI] [-iconFile '<filename>'] [-title '<title>'] [-description '<description>']"
		Write-Host "       [-company '<company>'] [-product '<product>'] [-copyright '<copyright>'] [-trademark '<trademark>']"
		Write-Host "       [-version '<version>'] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]"
		Write-Host "       [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]`n"
		Write-Host "       inputFile = Powershell script file that you want to convert to executable (file has to be UTF8 or UTF16 encoded)"
		Write-Host "         Content = Powershell script content that you want to convert to executable"
		Write-Host "      outputFile = destination executable file name or folder, defaults to inputFile with extension '.exe'"
		Write-Host " CompilerOptions = additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)"
		Write-Host "         TempDir = directory for storing temporary files (default is random generated temp directory in %temp%)"
		Write-Host "        Minifyer = scriptblock to minify the script before compiling"
		Write-Host "SepcArgsHandling = handle special arguments -debug, -extract, -wait and -end"
		Write-Host "    prepareDebug = create helpful information for debugging"
		Write-Host "      x86 or x64 = compile for 32-bit or 64-bit runtime only"
		Write-Host "            lcid = location ID for the compiled executable. Current user culture if not specified"
		Write-Host "      STA or MTA = 'Single Thread Apartment' or 'Multi Thread Apartment' mode"
		Write-Host "       noConsole = the resulting executable will be a Windows Forms app without a console window"
		Write-Host " UNICODEEncoding = encode output as UNICODE in console mode"
		Write-Host "   credentialGUI = use GUI for prompting credentials in console mode"
		Write-Host "        iconFile = icon file name for the compiled executable"
		Write-Host "           title = title information (displayed in details tab of Windows Explorer's properties dialog)"
		Write-Host "     description = description information (not displayed, but embedded in executable)"
		Write-Host "         company = company information (not displayed, but embedded in executable)"
		Write-Host "         product = product information (displayed in details tab of Windows Explorer's properties dialog)"
		Write-Host "       copyright = copyright information (displayed in details tab of Windows Explorer's properties dialog)"
		Write-Host "       trademark = trademark information (displayed in details tab of Windows Explorer's properties dialog)"
		Write-Host "         version = version information (displayed in details tab of Windows Explorer's properties dialog)"
		Write-Host "      configFile = write a config file (<outputfile>.exe.config)"
		Write-Host "        noOutput = the resulting executable will generate no standard output (includes verbose and information channel)"
		Write-Host "         noError = the resulting executable will generate no error output (includes warning and debug channel)"
		Write-Host "  noVisualStyles = disable visual styles for a generated windows GUI application (only with -noConsole)"
		Write-Host "    exitOnCancel = exits program when Cancel or ""X"" is selected in a Read-Host input box (only with -noConsole)"
		Write-Host "        DPIAware = if display scaling is activated, GUI controls will be scaled if possible"
		Write-Host "winFormsDPIAware = if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up)"
		Write-Host "    requireAdmin = if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)"
		Write-Host "       supportOS = use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference)"
		Write-Host "      virtualize = application virtualization is activated (forcing x86 runtime)"
		Write-Host "       longPaths = enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)`n"
		Write-Host "Input not specified!"
		return
	}
	function bytesOfString($str) {
		[system.Text.Encoding]::UTF8.GetBytes($str).Count
	}
	#_if PSScript #在PSEXE中主机永远是winpwsh，所以不会内嵌
	if (!$nested) {
	#_endif
		if (-not $Content) {
			if (!(Test-Path $inputFile -PathType Leaf)) {
				Write-Error "Input file $($inputfile) not found!"
				return
			}
		}
		elseif ($inputFile) {
			Write-Error "Input file and content cannot be used at the same time!"
			return
		}
		function ReadScriptFile($File) {
			Write-Host "Reading file $([System.IO.Path]::GetFileName($File)) size $((Get-Item $File).Length) bytes"
			$Content = Get-Content -LiteralPath $File -Encoding UTF8 -ErrorAction SilentlyContinue
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
			$ScriptRoot = [System.IO.Path]::GetDirectoryName($FilePath)
			function GetIncludeFilePath($rest) {
				if($rest -match "((\'[^\']*\')+)\s*(?!#.*)") {
					$file = $Matches[1]
					$file = $file.Substring(1, $file.Length - 2).Replace("''", "'")
				}
				elseif($rest -match '((\"[^\"]*\")+)\s*(?!#.*)') {
					$file = $Matches[1]
					$file = $file.Substring(1, $file.Length - 2).Replace('""', '"')
				}
				else{ $file = $rest }
				$file = $file.Replace('$PSScriptRoot', $ScriptRoot)
				# 若是相对路径，则转换为基于$FilePath的绝对路径
				if ($file -notmatch "^[a-zA-Z]:") {
					$file = [System.IO.Path]::Combine($ScriptRoot, $file)
				}
				if (!(Test-Path $file -PathType Leaf)) {
					Write-Error "Include file $file not found!"
					return
				}
				$file
			}
			$Content = $Result |
			# 处理#_!!<line>
			ForEach-Object {
				if($_ -match "^(\s*)#_!!(?<line>.*)") {
					$Matches[1]+$Matches["line"]
				} else{ $_ }
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
					$_
				}
			}
			$Content -join "`n"
		}
		if ($inputFile) {
			$Content = ReadScriptFile $inputFile
			if (!$Content) { return }
			if ((bytesOfString $Content) -ne (Get-Item $inputFile).Length) {
				Write-Host "Preprocessed script -> $(bytesOfString $Content) bytes"
			}
		}
		if ($minifyer) {
			Write-Host "${SavePos}Minifying script..."
			try {
				$MinifyedContent = & $minifyer ($_ = $Content)
				Write-Host "${RestorePos}Minifyed script -> $(bytesOfString $MinifyedContent) bytes"
			}
			catch {
				Write-Error "Minifyer failed: $_"
			}
			if (-not $MinifyedContent) {
				Write-Warning "Minifyer failed, using original script."
			}
			else {
				$Content = $MinifyedContent
			}
		}
	#_if PSScript
	}
	else {
		$Content = Get-Content -Raw -LiteralPath $inputFile -Encoding UTF8 -ErrorAction SilentlyContinue
		if (!$Content) {
			Write-Error "Temp file $($inputfile) not found!"
			return
		}
	}
	#_endif
	# retrieve absolute paths independent if path is given relative oder absolute
	$inputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputFile)
	if ([STRING]::IsNullOrEmpty($outputFile)) {
		$outputFile = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($inputFile), [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + ".exe"))
	}
	else {
		$outputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)
		if ((Test-Path $outputFile -PathType Container)) {
			$outputFile = ([System.IO.Path]::Combine($outputFile, [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + ".exe"))
		}
	}
	#_if PSScript #在PSEXE中主机永远是winpwsh，可省略该部分
	if (!$nested -and ($PSVersionTable.PSEdition -eq "Core")) {
		# starting Windows Powershell
		$Params = ([hashtable]$PSBoundparameters).Clone()
		$Params.Remove("minifyer")
		$Params.Remove("Content")
		$Params.Remove("inputFile")
		$Params.Remove("outputFile")
		$TempFile = [System.IO.Path]::GetTempFileName()
		$Content | Set-Content $TempFile -Encoding UTF8 -NoNewline
		$Params.Add("inputFile", $TempFile)
		$Params.Add("outputFile", $outputFile)
		$CallParam = foreach ($Param in $Params.GetEnumerator()) {
			if ($Param.Value -is [Switch]) {
				"-$($Param.Key):`$$([bool]$Param.Value)"
			}
			elseif ($Param.Value -is [string]) {
				"-$($Param.Key):'$(($Param.Value).Replace("'", "''"))'"
			}
			else {
				"-$($Param.Key):$($Param.Value)"
			}
		}

		powershell -noprofile -Command "&'$PSScriptRoot\ps2exe.ps1' $CallParam -nested" | Out-Host
		return
	}
	#_endif

	if ($inputFile -eq $outputFile) {
		Write-Error "Input file is identical to output file!"
		return
	}

	if (($outputFile -notlike "*.exe") -and ($outputFile -notlike "*.com")) {
		Write-Error "Output file must have extension '.exe' or '.com'!"
		return
	}

	if (!([STRING]::IsNullOrEmpty($iconFile))) {
		# retrieve absolute path independent if path is given relative oder absolute
		$iconFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($iconFile)

		if (!(Test-Path $iconFile -PathType Leaf)) {
			Write-Error "Icon file $($iconFile) not found!"
			return
		}
	}

	if ($winFormsDPIAware) {
		$supportOS = $TRUE
	}

	if ($requireAdmin -and $virtualize) {
		Write-Error "-requireAdmin cannot be combined with -virtualize"
		return
	}
	if ($supportOS -and $virtualize) {
		Write-Error "-supportOS cannot be combined with -virtualize"
		return
	}
	if ($longPaths -and $virtualize) {
		Write-Error "-longPaths cannot be combined with -virtualize"
		return
	}

	$CFGFILE = $FALSE
	if ($configFile) {
		$CFGFILE = $TRUE
		if ($noConfigFile) {
			Write-Error "-configFile cannot be combined with -noConfigFile"
			return
		}
	}
	if (!$CFGFILE -and $longPaths) {
		Write-Warning "Forcing generation of a config file, since the option -longPaths requires this"
		$CFGFILE = $TRUE
	}

	if (!$CFGFILE -and $winFormsDPIAware) {
		Write-Warning "Forcing generation of a config file, since the option -winFormsDPIAware requires this"
		$CFGFILE = $TRUE
	}

	if ($STA -and $MTA) {
		Write-Error "You cannot use switches -STA and -MTA at the same time!"
		return
	}

	if (!$MTA -and !$STA) {
		# Set default apartment mode for powershell version if not set by parameter
		$STA = $TRUE
	}

	# escape escape sequences in version info
	$title = $title -replace "\\", "\\"
	$product = $product -replace "\\", "\\"
	$copyright = $copyright -replace "\\", "\\"
	$trademark = $trademark -replace "\\", "\\"
	$description = $description -replace "\\", "\\"
	$company = $company -replace "\\", "\\"

	if (![STRING]::IsNullOrEmpty($version)) {
		# check for correct version number information
		if ($version -notmatch "(^\d+\.\d+\.\d+\.\d+$)|(^\d+\.\d+\.\d+$)|(^\d+\.\d+$)|(^\d+$)") {
			Write-Error "Version number has to be supplied in the form n.n.n.n, n.n.n, n.n or n (with n as number)!"
			return
		}
	}

	$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
	$type = $type.MakeGenericType( @( ("System.String" -as "Type"), ("system.string" -as "Type") ) )
	$o = [Activator]::CreateInstance($type)
	$o.Add("CompilerVersion", "v4.0")

	$referenceAssembies = @("System.dll")
	if (!$noConsole) {
		if ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "Microsoft.PowerShell.ConsoleHost.dll" }) {
			$referenceAssembies += ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "Microsoft.PowerShell.ConsoleHost.dll" } | Select-Object -First 1).Location
		}
	}
	$referenceAssembies += ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "System.Management.Automation.dll" } | Select-Object -First 1).Location

	$n = New-Object System.Reflection.AssemblyName("System.Core, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
	[System.AppDomain]::CurrentDomain.Load($n) | Out-Null
	$referenceAssembies += ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "System.Core.dll" } | Select-Object -First 1).Location

	if ($noConsole) {
		$n = New-Object System.Reflection.AssemblyName("System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
		[System.AppDomain]::CurrentDomain.Load($n) | Out-Null

		$n = New-Object System.Reflection.AssemblyName("System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")
		[System.AppDomain]::CurrentDomain.Load($n) | Out-Null

		$referenceAssembies += ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "System.Windows.Forms.dll" } | Select-Object -First 1).Location
		$referenceAssembies += ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq "System.Drawing.dll" } | Select-Object -First 1).Location
	}

	$platform = "anycpu"
	if ($x64 -and !$x86) { $platform = "x64" } else { if ($x86 -and !$x64) { $platform = "x86" } }

	$cop = (New-Object Microsoft.CSharp.CSharpCodeProvider($o))
	$cp = New-Object System.CodeDom.Compiler.CompilerParameters($referenceAssembies, $outputFile)
	$cp.GenerateInMemory = $FALSE
	$cp.GenerateExecutable = $TRUE

	$manifestParam = ""
	if ($requireAdmin -or $DPIAware -or $supportOS -or $longPaths) {
		$manifestParam = "`"/win32manifest:$($outputFile+".win32manifest")`""
		$win32manifest = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>`r`n<assembly xmlns=""urn:schemas-microsoft-com:asm.v1"" manifestVersion=""1.0"">`r`n"
		if ($DPIAware -or $longPaths) {
			$win32manifest += "<application xmlns=""urn:schemas-microsoft-com:asm.v3"">`r`n<windowsSettings>`r`n"
			if ($DPIAware) {
				$win32manifest += "<dpiAware xmlns=""http://schemas.microsoft.com/SMI/2005/WindowsSettings"">true</dpiAware>`r`n<dpiAwareness xmlns=""http://schemas.microsoft.com/SMI/2016/WindowsSettings"">PerMonitorV2</dpiAwareness>`r`n"
			}
			if ($longPaths) {
				$win32manifest += "<longPathAware xmlns=""http://schemas.microsoft.com/SMI/2016/WindowsSettings"">true</longPathAware>`r`n"
			}
			$win32manifest += "</windowsSettings>`r`n</application>`r`n"
		}
		if ($requireAdmin) {
			$win32manifest += "<trustInfo xmlns=""urn:schemas-microsoft-com:asm.v2"">`r`n<security>`r`n<requestedPrivileges xmlns=""urn:schemas-microsoft-com:asm.v3"">`r`n<requestedExecutionLevel level=""requireAdministrator"" uiAccess=""false""/>`r`n</requestedPrivileges>`r`n</security>`r`n</trustInfo>`r`n"
		}
		if ($supportOS) {
			$win32manifest += "<compatibility xmlns=""urn:schemas-microsoft-com:compatibility.v1"">`r`n<application>`r`n<supportedOS Id=""{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}""/>`r`n<supportedOS Id=""{1f676c76-80e1-4239-95bb-83d0f6d0da78}""/>`r`n<supportedOS Id=""{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}""/>`r`n<supportedOS Id=""{35138b9a-5d96-4fbd-8e2d-a2440225f93a}""/>`r`n<supportedOS Id=""{e2011457-1546-43c5-a5fe-008deee3d3f0}""/>`r`n</application>`r`n</compatibility>`r`n"
		}
		$win32manifest += "</assembly>"
		$win32manifest | Set-Content ($outputFile + ".win32manifest") -Encoding UTF8
	}

	[string[]]$CompilerOptions = @($CompilerOptions)

	if (!([STRING]::IsNullOrEmpty($iconFile))) {
		$CompilerOptions += "`"/win32icon:$($iconFile)`""
	}

	if (!$virtualize) {
		$CompilerOptions += "/platform:$($platform)"
		$CompilerOptions += "/target:$( if ($noConsole){'winexe'}else{'exe'})"
		$CompilerOptions += $manifestParam 
	}
	else {
		Write-Host "Application virtualization is activated, forcing x86 platfom."
		$CompilerOptions += "/platform:x86"
		$CompilerOptions += "/target:$( if ($noConsole){'winexe'}else{'exe'})"
		$CompilerOptions += "/nowin32manifest"
	}

	$cp.IncludeDebugInformation = $prepareDebug

	if ($prepareDebug) {
		$cp.TempFiles.KeepFiles = $TRUE
	}

	$configFileForEXE3 = "<?xml version=""1.0"" encoding=""utf-8"" ?>`r`n<configuration><startup>$(
		if ($winFormsDPIAware) {'<supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.7" /></startup>'}
		else {'<supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0" /></startup>'})$(
		if ($longPaths) {
			'<runtime><AppContextSwitchOverrides value="Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false" /></runtime>'
		})$(
		if ($winFormsDPIAware) {
			'<System.Windows.Forms.ApplicationConfigurationSection><add key="DpiAwareness" value="PerMonitorV2" /></System.Windows.Forms.ApplicationConfigurationSection>'
		})</configuration>"

	[string[]]$Constants = @() 

	if ($lcid) { $Constants += "culture" }
	if ($noError) { $Constants += "noError" }
	if ($noConsole) { $Constants += "noConsole" }
	if ($noOutput) { $Constants += "noOutput" }
	if ($version) { $Constants += "version" }
	if ($credentialGUI) { $Constants += "credentialGUI" }
	if ($noVisualStyles) { $Constants += "noVisualStyles" }
	if ($exitOnCancel) { $Constants += "exitOnCancel" }
	if ($STA) { $Constants += "STA" }
	if ($MTA) { $Constants += "MTA" }
	if ($UNICODEEncoding) { $Constants += "UNICODEEncoding" }
	if ($winFormsDPIAware) { $Constants += "winFormsDPIAware" }
	if ($SepcArgsHandling) { $Constants += "SepcArgsHandling" }

	$CompilerOptions += "/define:$([string]::Join(";", $Constants))"
	
	$cp.CompilerOptions = [string]::Join(" ", $CompilerOptions)
	
	Write-Verbose "Using Compiler Options: $($cp.CompilerOptions)"

	# Read the program frame from the ps2exe.cs file
	#_if PSEXE #这是该脚本被ps2exe编译时使用的预处理代码
		#_include_as_value programFrame "$PSScriptRoot/ps2exe.cs" #将ps2exe.cs中的内容内嵌到该脚本中
	#_else #否则正常读取cs文件
		[string]$programFrame = Get-Content $PSScriptRoot/ps2exe.cs -Raw -Encoding UTF8
	#_endif

	$programFrame = $programFrame.Replace("`$lcid", $lcid)
	$programFrame = $programFrame.Replace("`$title", $title)
	$programFrame = $programFrame.Replace("`$product", $product)
	$programFrame = $programFrame.Replace("`$copyright", $copyright)
	$programFrame = $programFrame.Replace("`$trademark", $trademark)
	$programFrame = $programFrame.Replace("`$version", $version)
	$programFrame = $programFrame.Replace("`$description", $description)
	$programFrame = $programFrame.Replace("`$company", $company)

	Write-Host "${SavePos}Compiling file..."
	if (-not $TempDir) {
		$TempDir = $TempTempDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
		New-Item -Path $TempTempDir -ItemType Directory | Out-Null
	}
	$TempDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TempDir)
	$Content | Set-Content $TempDir\main.ps1 -Encoding UTF8 -NoNewline
	[VOID]$cp.EmbeddedResources.Add("$TempDir\main.ps1")
	$cr = $cop.CompileAssemblyFromSource($cp, $programFrame)
	if ($TempTempDir) {
		Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
	}
	if ($cr.Errors.Count -gt 0) {
		if (Test-Path $outputFile) {
			Remove-Item $outputFile -Verbose:$FALSE
		}
		Write-Error -ErrorAction Continue "Could not create the PowerShell .exe file because of compilation errors. Use -verbose parameter to see details."
		$cr.Errors | ForEach-Object { Write-Verbose $_ }
	}
	else {
		if (Test-Path $outputFile) {
			Write-Host "${RestorePos}Compiled file written -> $((Get-Item $outputFile).Length) bytes"
			Write-Verbose "Path: $outputFile"

			if ($prepareDebug) {
				$cr.TempFiles | Where-Object { $_ -ilike "*.cs" } | Select-Object -First 1 | ForEach-Object {
					$dstSrc = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($outputFile), [System.IO.Path]::GetFileNameWithoutExtension($outputFile) + ".cs"))
					Write-Host "Source file name for debug copied: $($dstSrc)"
					Copy-Item -Path $_ -Destination $dstSrc -Force
				}
				$cr.TempFiles | Remove-Item -Verbose:$FALSE -Force -ErrorAction SilentlyContinue
			}
			if ($CFGFILE) {
				$configFileForEXE3 | Set-Content ($outputFile + ".config") -Encoding UTF8
				Write-Host "Config file for EXE created"
			}
		}
		else {
			Write-Error -ErrorAction "Continue" "Output file $outputFile not written"
		}
	}

	if ($requireAdmin -or $DPIAware -or $supportOS -or $longPaths) {
		if (Test-Path $($outputFile + ".win32manifest")) {
			Remove-Item $($outputFile + ".win32manifest") -Verbose:$FALSE
		}
	}
#_if PSScript
}

# if this file is called directly, execute the function
if ($PSBoundParameters.Count -gt 0) {
	ps2exe @PSBoundParameters
}
#_endif
