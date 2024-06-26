#Requires -Version 5.0

<#
.SYNOPSIS
Converts powershell scripts to standalone executables.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end ps12exeGUI for convenience.

Please see Remarks on project page for topics "GUI mode output formatting", "Config files", "Password security",
"Script variables" and "Window in background in -noConsole mode".

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

.PARAMETER lcid
location ID for the compiled executable. Current user culture if not specified

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

.PARAMETER targetRuntime
the target runtime to compile for. Possible values are 'Framework4.0' or 'Framework2.0', default is 'Framework4.0'

.PARAMETER GuestMode
Compile scripts with additional protection, prevent native files from being accessed

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
	[Parameter(ParameterSetName = 'Content', ValueFromPipeline = $TRUE)]
	[String]$Content,
	[Parameter(ParameterSetName = 'InputFile', Position = 1)]
	[Parameter(ParameterSetName = 'Content', Position = 0)]
	[ValidatePattern(".*\.(exe|com|bin)$")]
	[String]$outputFile = $NULL, [String]$CompilerOptions = '/o+ /debug-', [String]$TempDir = $NULL,
	[scriptblock]$minifyer = $null, [Switch]$noConsole, [Switch]$prepareDebug, [int]$lcid,
	[ValidateSet('x64', 'x86', 'anycpu')]
	[String]$architecture = 'anycpu',
	[ValidateSet('STA', 'MTA')]
	[String]$threadingModel = 'STA',
	[HashTable]$resourceParams = @{},
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
	[ValidateSet('Framework2.0', 'Framework4.0')]
	[String]$targetRuntime = 'Framework4.0',
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\src\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[Switch]$GuestMode,
	[string]$Localize,
	[Switch]$help,
	# TODO，不进入文档
	[Parameter(DontShow)]
	[switch]$UseWindowsPowerShell = $true,
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
	[Parameter(DontShow)]
	[Switch]$runtime20,
	[Parameter(DontShow)]
	[Switch]$runtime40,
	# 内部参数，不进入文档
	[Parameter(DontShow)]
	[Switch]$nested,
	[Parameter(DontShow)]
	[string]$DllExportList
)
$Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
function RollUp {
	param ($num = 1, [switch]$InVerbose)
	if (-not $Verbose -or $InVerbose) {
		if ($Host.UI.SupportsVirtualTerminal) {
			Write-Host $([char]27 + '[' + $num + 'A') -NoNewline
		}
		elseif (-not $nested) {
			$CousorPos = $Host.UI.RawUI.CursorPosition
			try {
				$CousorPos.Y = $CousorPos.Y - $num
				$Host.UI.RawUI.CursorPosition = $CousorPos
			} catch { $Error.RemoveAt(0) }
		}
	}
}
function Show-Help {
	$LocalizeData =
	#_if PSScript
		. $PSScriptRoot\src\LocaleLoader.ps1 -Localize $Localize
	#_else
		#_include "$PSScriptRoot/src/locale/en-UK.ps1"
	#_endif
	$MyHelp = $LocalizeData.ConsoleHelpData
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $MyHelp
}
if ($help) {
	Show-Help | Write-Host
	return
}
if (-not ($inputFile -or $Content)) {
	Show-Help | Write-Host
	Write-Host
	Write-Error "Input not specified!"
	return
}

$Params = $PSBoundParameters
$ParamList = $MyInvocation.MyCommand.Parameters
$Params.Remove('Content') | Out-Null #防止回滚覆盖
$Params.Remove('DllExportList') | Out-Null

function bytesOfString($str) {
	if ($str) { [system.Text.Encoding]::UTF8.GetBytes($str).Count } else { 0 }
}
#_if PSScript #在PSEXE中主机永远是winpwsh，所以不会内嵌
if (!$nested) {
#_endif
	[System.Collections.ArrayList]$DllExportList = @()
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
	else {
		$NewContent = Preprocessor ($Content -split '\r?\n') "$PWD\a.ps1"
		Write-Verbose "Done preprocess input script"
		if ((bytesOfString $NewContent) -ne (bytesOfString $Content)) {
			Write-Host "Preprocessed script -> $(bytesOfString $NewContent) bytes"
		}
		$Content = $NewContent
	}
	if ($minifyer) {
		Write-Host "Minifying script..."
		try {
			# get caller's stackframe
			$Stack = Get-PSCallStack
			$Frame = $Stack[1]
			$Variables = $Frame.GetFrameVariables()
			$Variables._ = [System.Management.Automation.PSVariable]::New('_', $Content)
			$MinifyedContent = $minifyer.InvokeWithContext(@{}, $Variables.Values, $Variables.args.Value)
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
	if (!$TempDir) {
		Remove-Item $inputFile -ErrorAction SilentlyContinue
	}
	if ($DllExportList) {
		[System.Collections.ArrayList]$DllExportList = $DllExportList | ConvertFrom-Json
	}
}
#_endif

# pragma预处理命令可能会修改参数，所以现在开始参数更新
$Params.GetEnumerator() | ForEach-Object {
	Set-Variable -Name $_.Key -Value $_.Value
}

# 处理兼容旧版参数列表
if ($x86 -and $x64) {
	Write-Error "-x86 cannot be combined with -x64"
	return
}
if ($x86) { $architecture = 'x86' }
if ($x64) { $architecture = 'x64' }
$Params.architecture = $architecture
[void]$Params.Remove("x86"); [void]$Params.Remove("x64")
if ($runtime20) {
	if ($runtime40) {
		Write-Error "You cannot use switches -runtime20 and -runtime40 at the same time!"
		return
	}
	if ($longPaths) {
		Write-Error "Long paths are only available with .Net 4 or above"
		return
	}
	if ($winFormsDPIAware) {
		Write-Error "DPI awareness of Windows Forms is only available with .Net 4 or above"
		return
	}
}
if ($runtime20) { $targetRuntime = 'Framework2.0' }
if ($runtime40) { $targetRuntime = 'Framework4.0' }
$Params.targetRuntime = $targetRuntime
[void]$Params.Remove("runtime20"); [void]$Params.Remove("runtime40")
if ($STA -and $MTA) {
	Write-Error "-STA cannot be combined with -MTA"
	return
}
if ($STA) { $threadingModel = 'STA' }
if ($MTA) { $threadingModel = 'MTA' }
$Params.threadingModel = $threadingModel
[void]$Params.Remove("STA"); [void]$Params.Remove("MTA")
$resourceParamKeys = @('iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version')
$resourceParamKeys | ForEach-Object {
	if ($Params.ContainsKey($_)) {
		$resourceParams[$_] = $Params[$_]
	}
	[void]$Params.Remove($_)
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
$NoResource = -not $resourceParams.Count
# 由于其他的resourceParams参数需要转义，iconFile参数不需要转义，所以提取出来单独处理
$iconFile = $resourceParams['iconFile']
$resourceParams.Remove('iconFile')

# 语法检查
$SyntaxErrors = if ($targetRuntime -eq 'Framework2.0') {
	#_if PSScript
		powershell -version 2.0 -OutputFormat xml -file $PSScriptRoot/src/RuntimePwsh2.0/CodeChecker.ps1 -scriptText $Content
	#_else
		#_include_as_value Pwsh2CodeCheckerCodeStr $PSScriptRoot/src/RuntimePwsh2.0/CodeChecker.ps1
		#_!! powershell -version 2.0 -OutputFormat xml -Command "&{$Pwsh2CodeCheckerCodeStr} -scriptText '$($Content -replace "'","''")'"
	#_endif
}
if (!$SyntaxErrors) {
	$Tokens = $null
	$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$SyntaxErrors)
}
if ($SyntaxErrors) {
	Write-Error "Syntax error in script: $SyntaxErrors" -Category 'ParserError' -ErrorId 'ParseError' -TargetObject $SyntaxErrors
	return
}

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
. $PSScriptRoot/src/PSObjectToString.ps1
function UsingWinPowershell($Boundparameters) {
	# starting Windows Powershell
	$Params = ([hashtable]$Boundparameters).Clone()
	$Params.Remove("minifyer")
	$Params.Remove("Content")
	$Params.Remove("inputFile")
	$Params.Remove("outputFile")
	$Params.Remove("resourceParams") #使用旧版参数列表传递hashtable参数更为保险
	$TempFile = if ($TempDir) {
		[System.IO.Path]::Combine($TempDir, 'main.ps1')
	} else { [System.IO.Path]::GetTempFileName() }
	$Content | Set-Content $TempFile -Encoding UTF8 -NoNewline
	$Params.Add("outputFile", $outputFile)
	$Params.Add("inputFile", $TempFile)
	if ($TempDir) { $Params.TempDir = $TempDir }
	$resourceParamKeys | ForEach-Object {
		if ($resourceParams.ContainsKey($_) -and $resourceParams[$_]) {
			$Params[$_] = $resourceParams[$_]
		}
	}
	if ($iconFile) { $Params.iconFile = $iconFile }
	if ($DllExportList.Length) { $Params.DllExportList = ConvertTo-Json -depth 7 -Compress -InputObject $DllExportList }
	$CallParam = Get-ArgsString $Params

	Write-Verbose "Starting WinPowershell ps12exe with parameters: $CallParam"

	powershell -noprofile -Command "&'$PSScriptRoot\ps12exe.ps1' $CallParam -nested" | Write-Host
	return
}
if (!$nested -and ($PSVersionTable.PSEdition -eq "Core") -and $UseWindowsPowerShell -and (Get-Command powershell -ErrorAction Ignore)) {
	UsingWinPowershell $Params
	return
}
#_endif

if ($inputFile -eq $outputFile) {
	Write-Error "Input file is identical to output file!"
	return
}

if ($winFormsDPIAware) {
	$supportOS = $TRUE
}

if ($virtualize) {
	$checkList = @("requireAdmin", "supportOS", "longPaths")
	foreach ($_ in $checkList) {
		if ($Params[$_]) {
			Write-Error "-virtualize cannot be combined with -$_"
			return
		}
	}
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

. $PSScriptRoot\src\AstAnalyze.ps1
$AstAnalyzeResult = AstAnalyze $Ast
Write-Verbose "AstAnalyzeResult: $($AstAnalyzeResult|Format-List|Out-String)"
$CommandNames = (Get-Command).Name + (Get-Alias).Name
$FindedCmdlets = @()
$NotFindedCmdlets = @()
$AstAnalyzeResult.UsedNonConstFunctions | ForEach-Object {
	if ($_ -match '\$' -or -not $_) { return }
	if ($CommandNames -notcontains $_) {
		if ($_ -match '^[\w\-_]+$' -and (Get-Command $_ -ErrorAction Ignore)) {
			$FindedCmdlets += $_
		}
		# 跳过成员函数，因为解析Add-Type太过复杂
		elseif (-not $_.Contains(']::')) {
			$NotFindedCmdlets += $_
		}
	}
}
if ($FindedCmdlets) {
	Write-Warning "Cmdlets $($FindedCmdlets -join '、') used but may not available in runtime, make sure you've checked it!"
}
if ($NotFindedCmdlets) {
	Write-Warning "Unknown functions $($NotFindedCmdlets -join '、') used"
}
try {
	. $PSScriptRoot\src\InitCompileThings.ps1
	#_if PSScript
	if (-not $noConsole -and $AstAnalyzeResult.IsConst -and -not $iconFile) {
		# TODO: GUI（MassageBoxW）、icon
		Write-Verbose "Const result, trying TinySharp Compiler..."
		Write-Host "Compiling file..."

		try {
			. $PSScriptRoot\src\TinySharpCompiler.ps1
			$TinySharpSuccess = $TRUE
		}
		catch {
			RollUp
			Write-Verbose "TinySharp Compiler error, fail back to normal program frame"
			Write-Error $_
		}
	}
	#_endif
	try {
		if (!$TinySharpSuccess) {
			Write-Host "Compiling file..."
		}
		if ($TinySharpSuccess) {}
		else {
			if ($targetRuntime -eq 'Framework2.0') { $TargetFramework = ".NETFramework,Version=v2.0" }
			if ($PSVersionTable.PSEdition -eq "Core") {
				# unfinished!
				if (!$TargetFramework) {
					$Info = [System.Environment]::Version
					$TargetFramework = ".NETCore,Version=v$($Info.Major).$($Info.Minor)"
				}
				. $PSScriptRoot\src\CodeAnalysisCompiler.ps1
			}
			else {
				if (!$TargetFramework) {
					$TargetFramework = ".NETFramework,Version=v4.7"
				}
				. $PSScriptRoot\src\CodeDomCompiler.ps1
			}
		}
		RollUp
	}
	catch {
		RollUp
		Write-Host "Compilation failed!" -ForegroundColor Red
		throw $_
	}

	if (!(Test-Path $outputFile)) {
		Write-Error "Output file $outputFile not written" -ErrorAction Stop
	}
	else {
		#_if PSScript
		if (-not $TinySharpSuccess) {
			& $PSScriptRoot\src\ExeSinker.ps1 $outputFile -removeResources:$(
				$NoResource -and $AstAnalyzeResult.IsConst
			) -removeVersionInfo:$($resourceParams.Count -eq 0)
		}
		#_endif
		Write-Host "Compiled file written -> $((Get-Item $outputFile).Length) bytes"
		Write-Verbose "Path: $outputFile"
		if ($CFGFILE) {
			$configFileForEXE3 | Set-Content ($outputFile + ".config") -Encoding UTF8
			Write-Host "Config file for EXE created"
		}
		if ($prepareDebug) {
			$cr.TempFiles | Where-Object { $_ -ilike "*.cs" } | Select-Object -First 1 | ForEach-Object {
				$dstSrc = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($outputFile), [System.IO.Path]::GetFileNameWithoutExtension($outputFile) + ".cs"))
				Write-Host "Source file name for debug copied: $dstSrc"
				Copy-Item -Path $_ -Destination $dstSrc -Force
			}
			$cr.TempFiles | Remove-Item -Verbose:$FALSE -Force -ErrorAction SilentlyContinue
		}
	}
}
catch {
	if (Test-Path $outputFile) {
		Remove-Item $outputFile -Verbose:$FALSE
	}
	if ($PSVersionTable.PSEdition -eq "Core" -and (Get-Command powershell -ErrorAction Ignore)) {
		$_ | Write-Error
		Write-Host "Roslyn CodeAnalysis failed`nFalling back to Use Windows Powershell with CodeDom...`nYou may want to add -UseWindowsPowerShell to args to skip this fallback in future.`n...or submit a PR to ps12exe repo to fix this!" -ForegroundColor Yellow
		UsingWinPowershell $Params
	}
	else {
		$_ | Write-Error
		$githubfeedback = "https://github.com/steve02081504/ps12exe/issues/new?assignees=steve02081504&labels=bug&projects=&template=bug-report.yaml"
		$urlParams = @{
			title                = "$_"
			"latest-release"     = if (Get-Module -ListAvailable ps12exe) { "true" } else { "false" }
			"bug-description"    = 'Compilation failed'
			"expected-behavior"  = 'Compilation should succeed'
			"additional-context" = @"
Version infos:
``````
$($PSVersionTable | Format-List | Out-String)
``````
Error message:
``````
$($_ | Format-List | Out-String)
``````
"@
		}
		foreach ($key in $urlParams.Keys) {
			$githubfeedback += "&$key=$([system.uri]::EscapeDataString($urlParams[$key]))"
		}
		Write-Host "Opps, something went wrong." -ForegroundColor Yellow
		$versionNow = Get-Module -ListAvailable ps12exe | Sort-Object -Property Version -Descending | Select-Object -First 1
		$versionOnline = Find-Module ps12exe | Sort-Object -Property Version -Descending | Select-Object -First 1
		if ("$($versionNow.Version)" -ne "$($versionOnline.Version)") {
			Write-Host "Latest version is $($versionOnline.Version), try upgrading to it?" -ForegroundColor Yellow
		}
		else {
			Write-Host "For help, please submit an issue by pressing Enter." -ForegroundColor Yellow
			Read-Host | Out-Null
			Start-Process $githubfeedback
		}
	}
}
finally {
	if ($TempTempDir) {
		Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}
