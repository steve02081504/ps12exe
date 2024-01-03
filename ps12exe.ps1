#Requires -Version 5.0

<#
.SYNOPSIS
Converts powershell scripts to standalone executables.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end Win-ps12exe for convenience.

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
Powershell script file path or url to convert to executable (file has to be UTF8 or UTF16 encoded)

.PARAMETER Content
The content of the PowerShell script to convert to executable

.PARAMETER outputFile
destination executable file name or folder, defaults to inputFile with extension '.exe'

.PARAMETER CompilerOptions
additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)

.PARAMETER TempDir
directory for storing temporary files (default is random generated temp directory in %temp%)

.PARAMETER minifyer
scriptblock to minify the script before compiling

.PARAMETER SepcArgsHandling
the resulting executable will handle special arguments -debug, -extract, -wait and -end.

.PARAMETER noConsole
the resulting executable will be a Windows Forms app without a console window.
You might want to pipe your output to Out-String to prevent a message box for every line of output
(example: dir C:\ | Out-String)

.PARAMETER prepareDebug
create helpful information for debugging of generated executable. See parameter -debug there

.PARAMETER architecture
compile for specific runtime only. Possible values are 'x64' and 'x86' and 'anycpu'

.PARAMETER threadingModel
Threading model for the compiled executable. Possible values are 'STA' and 'MTA'

.PARAMETER resourceParams
A hashtable that contains resource parameters for the compiled executable. Possible keys are 'iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version'
iconFile can be a file path or url to an icon file. All other values are strings.
see https://msdn.microsoft.com/en-us/library/system.reflection.assemblytitleattribute(v=vs.110).aspx for details

.PARAMETER lcid
location ID for the compiled executable. Current user culture if not specified

.PARAMETER UNICODEEncoding
encode output as UNICODE in console mode, useful to display special encoded chars

.PARAMETER credentialGUI
use GUI for prompting credentials in console mode instead of console input

.PARAMETER configFile
write a config file (<outputfile>.exe.config)

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
ps12exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
.EXAMPLE
ps12exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
#>
[CmdletBinding(DefaultParameterSetName = 'InputFile')]
Param(
	[Parameter(ParameterSetName = 'InputFile', Position = 0)]
	[ValidatePattern("^(https?|ftp)://.*|.*\.(ps1|psd1|tmp)$")]
	[String]$inputFile,
	[Parameter(ParameterSetName = 'ContentArg', Position = 0, Mandatory)]
	[Parameter(ParameterSetName = 'ContentPipe', ValueFromPipeline = $TRUE)]
	[String]$Content,
	[Parameter(ParameterSetName = 'InputFile', Position = 1)]
	[Parameter(ParameterSetName = 'ContentArg', Position = 1)]
	[Parameter(ParameterSetName = 'ContentPipe', Position = 0)]
	[ValidatePattern(".*\.(exe|com)$")]
	[String]$outputFile = $NULL, [String]$CompilerOptions = '/o+ /debug-', [String]$TempDir = $NULL,
	[scriptblock]$minifyer = $null, [Switch]$noConsole, [Switch]$SepcArgsHandling, [Switch]$prepareDebug,
	[ValidateSet('x64', 'x86', 'anycpu')]
	[String]$architecture = 'anycpu',
	[ValidateSet('STA', 'MTA')]
	[String]$threadingModel = 'STA',
	[HashTable]$resourceParams = @{},
	[int]$lcid,
	[Switch]$UNICODEEncoding,
	[Switch]$credentialGUI,
	[Switch]$configFile,
	[Switch]$noOutput,
	[Switch]$noError,
	[Switch]$noVisualStyles,
	[Switch]$exitOnCancel,
	[Switch]$DPIAware,
	[Switch]$winFormsDPIAware,
	[Switch]$requireAdmin,
	[Switch]$supportOS,
	[Switch]$virtualize,
	[Switch]$longPaths,
	# 兼容旧版参数列表，不进入文档
	[Parameter(DontShow)]
	[Switch]$noConfigFile,
	[Parameter(DontShow)]
	[Switch]$x86,
	[Parameter(DontShow)]
	[Switch]$x64,
	[Parameter(DontShow)]
	[Switch]$STA,
	[Parameter(DontShow)]
	[Switch]$MTA,
	[Parameter(DontShow)]
	[String]$iconFile,
	[Parameter(DontShow)]
	[String]$title,
	[Parameter(DontShow)]
	[String]$description,
	[Parameter(DontShow)]
	[String]$company,
	[Parameter(DontShow)]
	[String]$product,
	[Parameter(DontShow)]
	[String]$copyright,
	[Parameter(DontShow)]
	[String]$trademark,
	[Parameter(DontShow)]
	[String]$version,
	# 内部参数，不进入文档
	[Parameter(DontShow)]
	[Switch]$nested
)
$Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
function RollUp {
	param ($num=1,[switch]$InVerbose)
	$CousorPos = $Host.UI.RawUI.CursorPosition
	try{
		if(-not $Verbose -or $InVerbose) {
			if($nested){ throw }
			$CousorPos.Y = $CousorPos.Y - $num
			$Host.UI.RawUI.CursorPosition = $CousorPos
		}
	}
	catch {
		Write-Host $([char]27 + '[' + $num + 'A') -NoNewline
	}
}
if (-not ($inputFile -or $Content)) {
	Write-Host "Usage:`n"
	Write-Host "[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']"
	Write-Host "        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]"
	Write-Host "        [-SepcArgsHandling] [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug]"
	Write-Host "        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';"
	Write-Host "        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]"
	Write-Host "        [-lcid <lcid>] [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]"
	Write-Host "        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]"
	Write-Host
	Write-Host "           input = String of the contents of the powershell script file, same as -Content."
	Write-Host "       inputFile = Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded)"
	Write-Host "         Content = Powershell script content that you want to convert to executable"
	Write-Host "      outputFile = destination executable file name or folder, defaults to inputFile with extension '.exe'"
	Write-Host " CompilerOptions = additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)"
	Write-Host "         TempDir = directory for storing temporary files (default is random generated temp directory in %temp%)"
	Write-Host "        minifyer = scriptblock to minify the script before compiling"
	Write-Host "SepcArgsHandling = the resulting executable will handle special arguments -debug, -extract, -wait and -end"
	Write-Host "    prepareDebug = create helpful information for debugging"
	Write-Host "    architecture = compile for specific runtime only. Possible values are 'x64' and 'x86' and 'anycpu'"
	Write-Host "            lcid = location ID for the compiled executable. Current user culture if not specified"
	Write-Host "  threadingModel = 'Single Thread Apartment' or 'Multi Thread Apartment' mode"
	Write-Host "       noConsole = the resulting executable will be a Windows Forms app without a console window"
	Write-Host " UNICODEEncoding = encode output as UNICODE in console mode"
	Write-Host "   credentialGUI = use GUI for prompting credentials in console mode"
	Write-Host "  resourceParams = A hashtable that contains resource parameters for the compiled executable"
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
# 处理兼容旧版参数列表
if ($x86 -and $x64) {
	Write-Error "-x86 cannot be combined with -x64"
	return
}
if ($x86) { $architecture = 'x86' }
if ($x64) { $architecture = 'x64' }
if ($STA -and $MTA) {
	Write-Error "-STA cannot be combined with -MTA"
	return
}
if ($STA) { $threadingModel = 'STA' }
if ($MTA) { $threadingModel = 'MTA' }
$resourceParamKeys = @('iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version')
$resourceParamKeys | ForEach-Object {
	if ($PSBoundParameters.ContainsKey($_)) {
		$resourceParams[$_] = $PSBoundParameters[$_]
	}
}
$resourceParams.GetEnumerator() | ForEach-Object {
	if (-not $resourceParamKeys.Contains($_.Key)) {
		Write-Warning "Parameter -resourceParams has an invalid key: $($_.Key)"
	}
}
if ($configFile -and $noConfigFile) {
	Write-Error "-configFile cannot be combined with -noConfigFile"
	return
}
if ($noConfigFile) { $configFile = $FALSE }
# 由于其他的resourceParams参数需要转义，iconFile参数不需要转义，所以提取出来单独处理
$iconFile = $resourceParams['iconFile']
$resourceParams.Remove('iconFile')
function bytesOfString($str) {
	[system.Text.Encoding]::UTF8.GetBytes($str).Count
}
#_if PSScript #在PSEXE中主机永远是winpwsh，所以不会内嵌
if (!$nested) {
#_endif
	if ($inputFile -and $Content) {
		Write-Error "Input file and content cannot be used at the same time!"
		return
	}
	. $PSScriptRoot\src\ReadScriptFile.ps1
	if ($inputFile) {
		$Content = ReadScriptFile $inputFile
		if (!$Content) { return }
		if ((bytesOfString $Content) -ne (Get-Item $inputFile -ErrorAction Ignore).Length) {
			Write-Host "Preprocessed script -> $(bytesOfString $Content) bytes"
		}
	}
	if ($minifyer) {
		Write-Host "Minifying script..."
		try {
			$MinifyedContent = $Content | ForEach-Object $minifyer
			RollUp
			Write-Host "Minifyed script -> $(bytesOfString $MinifyedContent) bytes"
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
		Write-Error "Temp file $inputfile not found!"
		return
	}
	if(!$TempDir) {
		Remove-Item $inputFile -ErrorAction SilentlyContinue
	}
}
#_endif

# 语法检查
$SyntaxErrors = $null
$Tokens = $null
$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$SyntaxErrors)
if ($SyntaxErrors) {
	Write-Error "Syntax error in script: $SyntaxErrors"
	return
}
$Content = $AST.ToString()

# retrieve absolute paths independent if path is given relative oder absolute
if (-not $inputFile) {
	$inputFile = '.\a.ps1'
}
if ($inputFile -notmatch "^(https?|ftp)://") {
	$inputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputFile)
}
if (-not $outputFile) {
	if ($inputFile -match "^https?://") {
		$outputFile = ([System.IO.Path]::Combine($PWD, [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + ".exe"))
	}
	else {
		$outputFile = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($inputFile), [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + ".exe"))
	}
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
	$Params.Remove("resourceParams") #使用旧版参数列表传递hashtable参数更为保险
	$Params.Remove("x86"); $Params.Remove("x64")
	$Params.Remove("STA"); $Params.Remove("MTA")
	$TempFile = if($TempDir) {
		[System.IO.Path]::Combine($TempDir, 'main.ps1')
	} else { [System.IO.Path]::GetTempFileName() }
	$Content | Set-Content $TempFile -Encoding UTF8 -NoNewline
	$Params.Add("outputFile", $outputFile)
	$Params.Add("inputFile", $TempFile)
	$resourceParamKeys | ForEach-Object {
		if ($resourceParams.ContainsKey($_) -and $resourceParams[$_]) {
			$Params[$_] = $PSBoundParameters[$_]
		}
	}
	if ($iconFile) {
		$Params['iconFile'] = $iconFile
	}
	$CallParam = foreach ($Param in $Params.GetEnumerator()) {
		if ($Param.Value -is [Switch]) {
			"-$($Param.Key):`$$([bool]$Param.Value)"
		}
		elseif ($Param.Value -is [string] -and $Param.Value) {
			"-$($Param.Key):'$(($Param.Value).Replace("'", "''"))'"
		}
		else {
			"-$($Param.Key):$($Param.Value)"
		}
	}

	Write-Verbose "Starting WinPowershell ps12exe with parameters: $CallParam"

	powershell -noprofile -Command "&'$PSScriptRoot\ps12exe.ps1' $CallParam -nested" | Out-Host
	return
}
#_endif

if ($inputFile -eq $outputFile) {
	Write-Error "Input file is identical to output file!"
	return
}

if ($iconFile) {
	# retrieve absolute path independent if path is given relative oder absolute
	$iconFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($iconFile)

	if (!(Test-Path $iconFile -PathType Leaf)) {
		Write-Error "Icon file $iconFile not found!"
		return
	}
}

if ($winFormsDPIAware) {
	$supportOS = $TRUE
}

if ($virtualize) {
	$checkList = @("requireAdmin", "supportOS", "longPaths")
	foreach ($_ in $checkList) {
		if ($PSBoundParameters[$_]) {
			Write-Error "-virtualize cannot be combined with -$_"
			return
		}
	}
}
if ($longPaths -and $virtualize) {
	Write-Error "-longPaths cannot be combined with -virtualize"
	return
}
if ($longPaths -and $virtualize) {
	Write-Error "-longPaths cannot be combined with -virtualize"
	return
}

$CFGFILE = [bool]$configFile
if (!$CFGFILE -and $longPaths) {
	Write-Warning "Forcing generation of a config file, since the option -longPaths requires this"
	$CFGFILE = $TRUE
}

if (!$CFGFILE -and $winFormsDPIAware) {
	Write-Warning "Forcing generation of a config file, since the option -winFormsDPIAware requires this"
	$CFGFILE = $TRUE
}

# escape escape sequences in version info
$resourceParamKeys | ForEach-Object {
	if ($resourceParams.ContainsKey($_)) {
		$resourceParams[$_] = $resourceParams[$_] -replace "\\", "\\"
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

if (!$virtualize) {
	$CompilerOptions += "/platform:$architecture"
	$CompilerOptions += "/target:$( if ($noConsole){'winexe'}else{'exe'})"
	$CompilerOptions += $manifestParam 
}
else {
	Write-Host "Application virtualization is activated, forcing x86 platfom."
	$CompilerOptions += "/platform:x86"
	$CompilerOptions += "/target:$( if ($noConsole){'winexe'}else{'exe'})"
	$CompilerOptions += "/nowin32manifest"
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

$Constants += $threadingModel
if ($lcid) { $Constants += "culture" }
if ($noError) { $Constants += "noError" }
if ($noConsole) { $Constants += "noConsole" }
if ($noOutput) { $Constants += "noOutput" }
if ($resourceParams.version) { $Constants += "version" }
if ($resourceParams.Count) { $Constants += "Resources" }
if ($credentialGUI) { $Constants += "credentialGUI" }
if ($noVisualStyles) { $Constants += "noVisualStyles" }
if ($exitOnCancel) { $Constants += "exitOnCancel" }
if ($UNICODEEncoding) { $Constants += "UNICODEEncoding" }
if ($winFormsDPIAware) { $Constants += "winFormsDPIAware" }
if ($SepcArgsHandling) { $Constants += "SepcArgsHandling" }

. $PSScriptRoot\src\ConstProgramCheck.ps1
if(!$programFrame) {
	#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
		#_include_as_value programFrame "$PSScriptRoot/src/programFrames/default.cs" #将default.cs中的内容内嵌到该脚本中
	#_else #否则正常读取cs文件
		[string]$programFrame = Get-Content $PSScriptRoot/src/programFrames/default.cs -Raw -Encoding UTF8
	#_endif
}

$programFrame = $programFrame.Replace("`$lcid", $lcid)
$programFrame = $programFrame.Replace("`$threadingModel", $threadingModel)
$resourceParamKeys | ForEach-Object {
	$programFrame = $programFrame.Replace("`$$_", $resourceParams[$_])
}

if (-not $TempDir) {
	$TempDir = $TempTempDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
	New-Item -Path $TempTempDir -ItemType Directory | Out-Null
}
$TempDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TempDir)
$cp.TempFiles = New-Object System.CodeDom.Compiler.TempFileCollection($TempDir)

$Content | Set-Content $TempDir\main.ps1 -Encoding UTF8 -NoNewline
if ($iconFile -match "^(https?|ftp)://") {
	Invoke-WebRequest -Uri $iconFile -OutFile $TempDir\icon.ico
	if (!(Test-Path $TempDir\icon.ico -PathType Leaf)) {
		Write-Error "Icon file $iconFile failed to download!"
		return
	}
	$iconFile = "$TempDir\icon.ico"
}

if ($iconFile) {
	$CompilerOptions += "`"/win32icon:$iconFile`""
}

$cp.IncludeDebugInformation = $prepareDebug

if ($prepareDebug) {
	$cp.TempFiles.KeepFiles = $TRUE
}

Write-Host "Compiling file..."

$CompilerOptions += "/define:$($Constants -join ';')"
$cp.CompilerOptions = $CompilerOptions -ne '' -join ' '
Write-Verbose "Using Compiler Options: $($cp.CompilerOptions)"

if(!$IsConstProgram -or $SepcArgsHandling) {
	[VOID]$cp.EmbeddedResources.Add("$TempDir\main.ps1")
}
$cr = $cop.CompileAssemblyFromSource($cp, $programFrame)
if ($TempTempDir) {
	Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($cr.Errors.Count -gt 0) {
	if (Test-Path $outputFile) {
		Remove-Item $outputFile -Verbose:$FALSE
	}
	RollUp
	Write-Host "Compilation failed!" -ForegroundColor Red
	Write-Error -ErrorAction Continue "Could not create the PowerShell .exe file because of compilation errors. Use -verbose parameter to see details."
	$cr.Errors | ForEach-Object { Write-Verbose $_ }
}
else {
	if (Test-Path $outputFile) {
		RollUp
		Write-Host "Compiled file written -> $((Get-Item $outputFile).Length) bytes"
		Write-Verbose "Path: $outputFile"

		if ($prepareDebug) {
			$cr.TempFiles | Where-Object { $_ -ilike "*.cs" } | Select-Object -First 1 | ForEach-Object {
				$dstSrc = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($outputFile), [System.IO.Path]::GetFileNameWithoutExtension($outputFile) + ".cs"))
				Write-Host "Source file name for debug copied: $dstSrc"
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
