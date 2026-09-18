#Requires -Version 5.0

<#
.SYNOPSIS
Converts powershell scripts to standalone executables or preprocesses PowerShell scripts.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end ps12exeGUI for convenience.
Alternatively, preprocesses a PowerShell script, handling directives like `#_if`, `#_else`, `#_endif`, and `#_include`.

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
the target runtime to compile for. Possible values are 'Framework4.0', 'Framework2.0' or 'Core', default is 'Framework4.0'.
'Core' compiles a PowerShell Core (.NET) executable: both the build machine and the target machine must have
PowerShell Core and a matching .NET runtime installed, and the generated executable is much larger.

.PARAMETER GuestMode
Compile scripts with additional protection, prevent native files from being accessed

.PARAMETER Localize
The language code to be used for server-side logging

.PARAMETER SkipVersionCheck
Do not check for updates

.PARAMETER help
Display localized help message

.PARAMETER PreprocessOnly
only preprocesses the input PowerShell script and outputs the preprocessed code. No executable is generated.

.PARAMETER GolfMode
Enables golf mode, adding abbreviations and common functions to the script.

.PARAMETER CodeSigning
A hashtable containing code signing options for the compiled executable. Supported keys:
- Path: Path to PFX certificate file
- Password: SecureString password for the PFX file
- Thumbprint: Certificate thumbprint from Windows Certificate Store
- TimestampServer: Timestamp server URL (default: http://timestamp.digicert.com)

Either Path or Thumbprint must be specified.

.EXAMPLE
ps12exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
.EXAMPLE
ps12exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -resourceParams @{iconFile='C:\Data\Icon.ico'; title='MyScript'; version='0.0.0.1'} -noConsole
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
.EXAMPLE
ps12exe -inputFile C:\Data\MyScript.ps1 -PreprocessOnly
Preprocesses C:\Data\MyScript.ps1 and outputs the preprocessed code.
.EXAMPLE
ps12exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScript.exe -CodeSigning @{Path="C:\Cert\mycert.pfx"; Password=(ConvertTo-SecureString "password" -AsPlainText -Force); TimestampServer="http://timestamp.digicert.com"}
Compiles C:\Data\MyScript.ps1 and signs it with a PFX certificate.
.EXAMPLE
ps12exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScript.exe -CodeSigning @{Thumbprint="ABC123DEF456"}
Compiles C:\Data\MyScript.ps1 and signs it with a certificate from Windows Certificate Store.
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
	[ValidatePattern(".*\.(exe|com|scr|bin|bat|cmd)$")]
	[String]$outputFile = $NULL, [String]$CompilerOptions = '/o+ /debug-', [String]$TempDir = $NULL,
	[scriptblock]$minifyer = $null, [Switch]$noConsole, [Switch]$prepareDebug, [int]$lcid,
	[ValidateSet('x64', 'x86', 'anycpu')]
	[String]$architecture = 'anycpu',
	[ValidateSet('STA', 'MTA')]
	[String]$threadingModel = 'STA',
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		$validKeys = @('iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version')
		if (-not $wordToComplete) { return "@{}" }
		$wordToComplete = $wordToComplete.Trim('"', "'", ' ', '`t', '{', '}')
		if ($wordToComplete -match '=') { return }
		$validKeys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { "$_=" }
	})]
	[HashTable]$resourceParams = @{},
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		if (-not $wordToComplete) { return "@{}" }
		$validKeys = @('Path', 'Password', 'Thumbprint', 'TimestampServer')
		$wordToComplete = $wordToComplete.Trim('"', "'", ' ', '`t', '{', '}')
		if ($wordToComplete -match '=') { return }
		$validKeys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { "$_=" }
	})]
	[Hashtable]$CodeSigning,
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
	[ValidateSet('Framework2.0', 'Framework4.0', 'Core')]
	[String]$targetRuntime = 'Framework4.0',
	[Switch]$SkipVersionCheck,
	[Switch]$GuestMode,
	[Switch]$PreprocessOnly,
	[Switch]$GolfMode,
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\src\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Localize,
	[Switch]$help,
	# 内部使用。除非你清楚自己在做什么，否则不要使用。
	[Parameter(DontShow)]
	[Switch]$nested,
	# 内部使用。除非你清楚自己在做什么，否则不要使用。
	[Parameter(DontShow)]
	[string]$DllExportList,
	# 开发用。除非你清楚自己在做什么，否则不要使用。
	[Parameter(DontShow)]
	[Switch]$StartupTiming
)
$global:LastExitCode = 0 # 无错误
$Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
$Debug = $DebugPreference -ne 'SilentlyContinue'
$UICultureBackup = [cultureinfo]::CurrentUICulture
function RollUp {
	param ($num = 1, [switch]$InVerbose)
	if (-not ($Verbose -or $InVerbose -or $Debug)) {
		if ($Host.UI.SupportsVirtualTerminal) {
			Write-Host $([char]27 + '[' + $num + 'A') -NoNewline
		}
		elseif (-not $nested) {
			if ($CousorPos = $Host.UI.RawUI.CursorPosition) {
				try {
					$CousorPos.Y = $CousorPos.Y - $num
					$Host.UI.RawUI.CursorPosition = $CousorPos
				}
				catch { $Error.RemoveAt(0) }
			}
		}
	}
}
if ($Debug) { $DebugPreference = 'Continue' } # 修复 -debug 会把它设为 'Inquire' 的问题
#_if PSScript
	$LocaleLoaderArg = @{ Localize = $Localize }
	if ($nested) { $LocaleLoaderArg.FailedLoadLocaleData = {} }
#_endif
$LocalizeData =
#_if PSScript
	. $PSScriptRoot\src\LocaleLoader.ps1 @LocaleLoaderArg
#_else
	#_include "$PSScriptRoot/src/locale/en-UK.ps1"
#_endif
. $PSScriptRoot\src\WriteI18n.ps1
Set-I18nData -I18nData $LocalizeData.CompilingI18nData
function Show-Help {
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $LocalizeData.ConsoleHelpData | Write-Host
}
#_if PSScript
	$versionNow = (Get-Module -ListAvailable ps12exe | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
	if ($versionNow -ne '0.0.0') { # 非开发版本
		if (Test-Path $env:TEMP/ps12exe_version.txt) {
			$versionOnline = Get-Content $env:TEMP/ps12exe_version.txt -Encoding utf8 | Select-Object -First 1
			if ((-not $nested) -and (-not $SkipVersionCheck) -and ($versionNow -ne $versionOnline)) {
				try {
					$ForegroundColor = try { $Host.UI.RawUI.ForegroundColor } catch { 'White' }
					$Host.UI.RawUI.ForegroundColor = "Yellow"
				}
				catch {}
				Write-I18n Host NewVersionAvailable $versionOnline
				try { $Host.UI.RawUI.ForegroundColor = $ForegroundColor } catch {}
			}
		}
		if ((-not $nested) -and (-not $SkipVersionCheck) -and -not (Get-Job -Name ps12exe_version_check -ErrorAction Ignore)) {
			Start-Job {
				$versionOnline = (Find-Module ps12exe | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
				Set-Content $env:TEMP/ps12exe_version.txt -Value $versionOnline -Encoding utf8
			} -Name ps12exe_version_check | Out-Null
		}
	}
#_endif
if ($help) {
	Show-Help
	return
}
if (-not ($inputFile -or $Content)) {
	Show-Help
	Write-Host
	Write-I18n Error NoneInput -Category InvalidArgument
	if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
		$global:LastExitCode = 2 # 调用格式错误
	}
	else {
		& "$PSScriptRoot\src\Interact\main.ps1" -Localize $Localize # 没有输入时启动交互模式
	}
	return
}

$Params = $PSBoundParameters
$ParamList = $MyInvocation.MyCommand.Parameters
$Params.Remove('Content') | Out-Null #防止回滚覆盖
$Params.Remove('DllExportList') | Out-Null
$Params.Remove('PreprocessOnly') | Out-Null # 从参数中移除 PreprocessOnly，供编译步骤使用

function bytesOfString([string]$str) {
	if ($str) { [system.Text.Encoding]::UTF8.GetBytes($str).Count } else { 0 }
}
function Test-StdoutRedirected {
	# 控制台重定向（管道 / 1>文件）。在交互式 ConsoleHost 中，`$exe = ps12exe` 会在不设置 IsOutputRedirected 的情况下捕获 stdout——仍属 stdout 捕获，而非 stderr（仅 2>$null）。
	if ([System.Console]::IsOutputRedirected) { return $true }
	$line = (Get-PSCallStack)[1].InvocationInfo.Line
	return $line -match '\$\w+\s*='
}
#_if PSScript #在PSEXE中主机永远是winpwsh，所以不会内嵌
if (!$nested) {
#_endif
	[System.Collections.ArrayList]$DllExportList = @()
	if ($inputFile -and $Content) {
		Write-I18n Error BothInputAndContentSpecified -Category InvalidArgument
		$global:LastExitCode = 2 # 调用格式错误
		return
	}
	. $PSScriptRoot\src\ReadScriptFile.ps1
	try {
		if ($inputFile) {
			$Content = ReadScriptFile $inputFile
			if ((bytesOfString $Content) -ne (Get-Item $inputFile -ErrorAction Ignore).Length) {
				Write-I18n Host PreprocessedScriptSize $(bytesOfString $Content)
			}
		}
		else {
			$NewContent = Preprocessor ($Content -split '\r?\n') "$PWD\a.ps1"
			Write-I18n Verbose PreprocessDone
			if ((bytesOfString $NewContent) -ne (bytesOfString $Content)) {
				Write-I18n Host PreprocessedScriptSize $(bytesOfString $NewContent)
			}
			$Content = $NewContent
		}
		$isGolf = $true
		if ($Content -match '^C\|') { $Content = '$CI' + $Content.Substring(1) }
		elseif ($Content -match '^S\|') { $Content = '$SI' + $Content.Substring(1) }
		elseif ($Content -match '^N\|') { $Content = '$NI' + $Content.Substring(1) }
		elseif ($Content -match '^\|') { $Content = '$I' + $Content }
		elseif ($Content -match '^C%') { $Content = '$CA|' + $Content.Substring(2) }
		elseif ($Content -match '^S%') { $Content = '$SA|' + $Content.Substring(2) }
		elseif ($Content -match '^N%') { $Content = '$NA|' + $Content.Substring(2) }
		elseif ($Content -match '^%') { $Content = '$A|' + $Content.Substring(1) }
		elseif (!$GolfMode) { $isGolf = $false }
		if ($isGolf) {
			#_if PSScript
				$GolfModeHeader = Get-Content $PSScriptRoot\src\GolfModeHeader.ps1 -Encoding UTF8 -Raw
			#_else
				#_include_as_value GolfModeHeader $PSScriptRoot\src\GolfModeHeader.ps1
			#_endif
			$Content = $GolfModeHeader + "`n" + $Content
		}
	}
	catch {
		$global:LastExitCode = 1 # 脚本预处理失败
		if ($_.Exception.Message -ne 'ScriptHalted') { Write-Error $_.Exception }
		return
	}
	if ($minifyer -is [string]) {
		if (Get-Command $minifyer -ErrorAction Ignore) {
			$minifyer = "$minifyer `$_"
		}
		$minifyer = [scriptblock]::Create($minifyer)
	}
	if ($minifyer) {
		Write-I18n Host MinifyingScript
		try {
			# 获取调用方的堆栈帧
			$Stack = Get-PSCallStack
			$Frame = $Stack[1]
			$Variables = $Frame.GetFrameVariables()
			$Variables._ = [System.Management.Automation.PSVariable]::New('_', $Content)
			$MinifyedContent = $minifyer.InvokeWithContext(@{}, $Variables.Values, $Variables.args.Value)
			RollUp
			Write-I18n Host MinifyedScriptSize $(bytesOfString $MinifyedContent)
		}
		catch {
			Write-I18n Error MinifyerError $_ -Exception $_.Exception
		}
		if (-not $MinifyedContent -and $Content) {
			Write-I18n Warning MinifyerFailedUsingOriginalScript
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
		Write-I18n Error TempFileMissing $inputFile -Category ResourceUnavailable
		$global:LastExitCode = 3 # 资源丢失
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

if ($PreprocessOnly) {
	Write-I18n Host PreprocessOnlyDone
	$global:LastExitCode = 0
	return $Content
}

# pragma预处理命令可能会修改参数，所以现在开始参数更新
$Params.GetEnumerator() | ForEach-Object {
	Set-Variable -Name $_.Key -Value $_.Value
}

# 把默认值与 pragma 结果一起写回 $Params，供跨宿主编译与后续步骤使用
$Params.architecture = $architecture
$Params.threadingModel = $threadingModel
$Params.targetRuntime = $targetRuntime
$isCoreTarget = $targetRuntime -eq 'Core'
$resourceParamKeys = @('iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version')
$resourceParams.GetEnumerator() | ForEach-Object {
	if (-not $resourceParamKeys.Contains($_.Key)) {
		Write-I18n Warning InvalidResourceParam $_.Key
	}
}
$NoResource = -not $resourceParams.Count
# 由于其他的resourceParams参数需要转义，iconFile参数不需要转义，所以提取出来单独处理
$iconFile = $resourceParams['iconFile']
$resourceParams.Remove('iconFile')

# 无论给定的是相对路径还是绝对路径，都获取绝对路径
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
	function UsingHost($Boundparameters, $HostExe) {
		# 写临时脚本，把参数串成命令行交给另一个 PowerShell 宿主编译，再等它退出。
		$Params = ([hashtable]$Boundparameters).Clone()
		$Params.Remove("minifyer")
		$Params.Remove("Content")
		$Params.Remove("inputFile")
		$Params.Remove("outputFile")
		$TempFile = if ($TempDir) {
			New-Item -ItemType Directory -Path $TempDir -ErrorAction SilentlyContinue | Out-Null
			[System.IO.Path]::Combine($TempDir, 'main.ps1')
		}
		else { [System.IO.Path]::GetTempFileName() }
		$Content | Set-Content $TempFile -Encoding UTF8 -NoNewline
		$Params.Add("outputFile", $outputFile)
		$Params.Add("inputFile", $TempFile)
		if ($TempDir) { $Params.TempDir = $TempDir }
		# resourceParams 以哈希表整体序列化给子宿主；iconFile 已单独提取，这里补回去
		$UsingResourceParams = @{}
		$resourceParams.GetEnumerator() | ForEach-Object { $UsingResourceParams[$_.Key] = $_.Value }
		if ($iconFile) { $UsingResourceParams.iconFile = $iconFile }
		if ($UsingResourceParams.Count) { $Params.resourceParams = $UsingResourceParams }
		else { $Params.Remove("resourceParams") }
		if ($DllExportList.Length) { $Params.DllExportList = ConvertTo-Json -depth 7 -Compress -InputObject $DllExportList }
		$CallParam = Get-ArgsString $Params

		Write-Debug "Starting $HostExe ps12exe with parameters: $CallParam"

		& $HostExe -NoProfile -Command "&'$PSScriptRoot\ps12exe.ps1' $CallParam -nested; exit `$LastExitCode" | Write-Host
		$global:LastExitCode = $LASTEXITCODE
	}
	# Windows PowerShell 解析不了 Core 语法，因此 Core 目标必须在解析前交接给 pwsh。
	if (!$nested -and $isCoreTarget -and ($PSVersionTable.PSEdition -ne "Core")) {
		if (Get-Command pwsh -ErrorAction Ignore) {
			UsingHost $Params 'pwsh'
			if ((Test-Path -LiteralPath $outputFile) -and (Test-StdoutRedirected)) {
				Write-Output $outputFile
			}
			return
		}
		Write-I18n Error CoreCompileNeedPwsh -Category NotInstalled
		$global:LastExitCode = 2 # 调用格式错误
		return
	}
#_endif

# 语法检查
if ($targetRuntime -eq 'Framework2.0') {
	#_if PSScript
		$SyntaxErrors = powershell -version 2.0 -NoProfile -OutputFormat xml -file $PSScriptRoot/src/RuntimePwsh2.0/CodeChecker.ps1 -scriptText $Content
	#_else
		#_include_as_value Pwsh2CodeCheckerCodeStr $PSScriptRoot/src/RuntimePwsh2.0/CodeChecker.ps1
		#_!! powershell -version 2.0 -NoProfile -OutputFormat xml -Command "&{$Pwsh2CodeCheckerCodeStr} -scriptText '$($Content -replace "'","''")'"
	#_endif
}
else {
	[cultureinfo]::CurrentUICulture = $LocalizeData.LangID
	$SyntaxErrors = $Tokens = $null
	$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$SyntaxErrors)
	[cultureinfo]::CurrentUICulture = $UICultureBackup
}
if ($SyntaxErrors) {
	$errorData = & $PSScriptRoot/src/SyntaxErrorI18nDataBuilder.ps1 -SyntaxErrors $SyntaxErrors -CodeContent $Content -Localize:$LocalizeData.LangID
	$lastFullText = $null
	$ErrMessage = @()
	foreach ($errinfo in $errorData) {
		$fullText = ($errinfo.SpoceText + $errinfo.Text) -join "`n"
		if ($fullText -ne $lastFullText) {
			$lastFullText = $fullText
			if (!$errinfo.SpoceText.contains($null)) {
				$StartLine = Write-I18n Output SyntaxErrorLineStart $errinfo.SpoceText
			}
			$ErrMessage += [ordered]@{
				Split         = ''
				StartLine     = $StartLine
				ScriptLine    = $errinfo.Text
				HighlightLine = (" " * ([Math]::Max(0, $errinfo.Spoce.Column - 1)) + '^' * ([Math]::Max($errinfo.Spoce.ColumnEnd - $errinfo.Spoce.Column, 1)))
				Messages      = @()
			}
		}
		$ErrMessage[-1].Messages += $errinfo.Message
	}
	Write-I18n Error -Category ParserError -TargetObject @{
		Errors      = $SyntaxErrors
		Text        = ($ErrMessage | ForEach-Object { $_.GetEnumerator() | ForEach-Object { $_.Value } }) -join "`n"
		MessageTree = $ErrMessage
	} InputSyntaxError
	$ErrMessage | ForEach-Object {
		Write-Host $_.Split
		if ($_.StartLine) { Write-Host $_.StartLine -ForegroundColor Cyan }
		if ($_.ScriptLine) {
			Write-Host $_.ScriptLine
			Write-Host $_.HighlightLine -ForegroundColor Red
		}
		Write-Host ($_.Messages -join "`n")
	}
	if (-not $isCoreTarget) {
		Write-I18n Host CoreCompileHint -ForegroundColor Yellow
	}
	$global:LastExitCode = 1 # 脚本语法错误
	return
}
elseif (!$AST) {
	$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$null, [ref]$null)
}

#_if PSScript #在PSEXE中主机永远是winpwsh，可省略该部分
	# pwsh 下默认交给 Windows PowerShell + CodeDom；若没有 WinPS，只能报错让用户显式选 Core。
	if (!$nested -and -not $isCoreTarget -and ($PSVersionTable.PSEdition -eq "Core")) {
		if (Get-Command powershell -ErrorAction Ignore) {
			UsingHost $Params 'powershell'
			if ((Test-Path -LiteralPath $outputFile) -and (Test-StdoutRedirected)) {
				Write-Output $outputFile
			}
			return
		}
		Write-I18n Error CoreCompileNeedWindowsPowerShell -Category NotInstalled
		$global:LastExitCode = 2 # 调用格式错误
		return
	}
#_endif

if ($inputFile -eq $outputFile) {
	Write-I18n Error IdenticalInputOutput -Category InvalidArgument
	$global:LastExitCode = 2 # 调用格式错误
	return
}

if ($winFormsDPIAware) {
	$supportOS = $TRUE
}

if ($virtualize) {
	foreach ($a in @("requireAdmin", "supportOS", "longPaths")) {
		if ($Params[$a]) {
			Write-I18n Error "CombinedArg_Virtualize_$a" -Category InvalidArgument
			$global:LastExitCode = 2 # 调用格式错误
			return
		}
	}
}

if (!$configFile) {
	foreach ($a in @("longPaths", "winFormsDPIAware")) {
		if ($Params[$a]) {
			Write-I18n Warning "CombinedArg_NoConfigFile_$a" -Category InvalidArgument
			$configFile = $true
		}
	}
}

# 转义版本信息中的转义序列
$resourceParamKeys | ForEach-Object {
	if ($resourceParams.ContainsKey($_)) {
		$resourceParams[$_] = $resourceParams[$_] -replace "\\", "\\"
	}
}


. $PSScriptRoot\src\AstAnalyze.ps1
. $PSScriptRoot\src\TaskbarProgress.ps1
$AstAnalyzeResult = AstAnalyze $Ast
Write-Debug "AstAnalyzeResult: $(($AstAnalyzeResult|ConvertTo-Json) -split "\r?\n" -ne '' -join "`n")"
$CommandNames = (Get-Command).Name + (Get-Alias).Name
$FoundCmdlets = @()
$NotFoundCmdlets = @()
$AstAnalyzeResult.UsedNonConstFunctions | ForEach-Object {
	if ($_ -match '\$' -or -not $_) { return }
	if ($CommandNames -notcontains $_) {
		if ($_ -match '^[\w\-_]+$' -and (Get-Command $_ -ErrorAction Ignore)) {
			$FoundCmdlets += $_
		}
		# 跳过成员函数，因为解析Add-Type太过复杂
		elseif (-not $_.Contains(']::')) {
			$NotFoundCmdlets += $_
		}
	}
}
if ($AST.ParamBlock) { $AstAnalyzeResult.IsConst = $false }
$NotFoundTypes = @()
$AstAnalyzeResult.UsedNonConstTypes | ForEach-Object {
	if (!($_ -as [Type])) {
		$NotFoundTypes += $_
	}
}
if ($FoundCmdlets) {
	Write-I18n Warning SomeCmdletsMayNotAvailable $($FoundCmdlets -join '、')
}
if ($NotFoundCmdlets) {
	Write-I18n Warning SomeNotFoundCmdlets $($NotFoundCmdlets -join '、')
}
if ($NotFoundTypes) {
	Write-I18n Warning SomeTypesMayNotAvailable $($NotFoundTypes -join '、')
}
if ($TempDir) {
	New-Item -ItemType Directory -Path $TempDir -ErrorAction SilentlyContinue | Out-Null
}
try {
	Write-TaskbarProgress -Percent 0
	. $PSScriptRoot\src\InitCompileThings.ps1
	Write-TaskbarProgress -Percent 10
	#_if PSScript
		# 常量脚本优先生成 TinySharp 壳（体积 ~1KB）；产物是 .NET Framework 托管 PE，Core 目标跳过它改走 CoreCompiler。
		if ($AstAnalyzeResult.IsConst -and -not $requireAdmin -and -not $isCoreTarget) {
			Write-I18n Verbose TryingTinySharpCompile
			Write-I18n Host CompilingFile
			Write-TaskbarProgress -Percent 20

			try {
				. $PSScriptRoot\src\TinySharpCompiler.ps1
				$TinySharpSuccess = $TRUE
			}
			catch {
				RollUp
				Write-I18n Verbose TinySharpFailedFallback
				Write-Error $_
			}
		}
	#_endif
	try {
		if (!$TinySharpSuccess) {
			Write-I18n Host CompilingFile
			Write-TaskbarProgress -Percent 25
			if ($isCoreTarget) {
				. $PSScriptRoot\src\CoreCompiler.ps1
			}
			else {
				. $PSScriptRoot\src\CodeDomCompiler.ps1
			}
		}
		RollUp
		Write-TaskbarProgress -Percent 70
	}
	catch {
		RollUp
		Write-TaskbarProgressError
		Write-I18n Host CompilationFailed -ForegroundColor Red
		throw $_
	}

	if (!(Test-Path $outputFile)) {
		Write-I18n Error OutputFileNotWritten -Category WriteError
		$global:LastExitCode = 3 # 无输出文件
		return
	}
	else {
		#_if PSScript
			if (-not $TinySharpSuccess -and -not $isCoreTarget) {
				Write-TaskbarProgress -Percent 75
				& $PSScriptRoot\src\ExeSinker.ps1 $outputFile -removeResources:$(
					$NoResource -and $AstAnalyzeResult.IsConst -and -not $requireAdmin
				) -removeVersionInfo:$($resourceParams.Count -eq 0)
			}
		#_endif
		Write-TaskbarProgressClear
		Write-I18n Host CompiledFileSize $((Get-Item $outputFile).Length)
		Write-I18n Verbose OutputPath $outputFile
		if ($configFile -and -not $isCoreTarget) {
			$configFileForEXE3 | Set-Content ($outputFile + ".config") -Encoding UTF8
			Write-I18n Host ConfigFileCreated
		}
		if ($prepareDebug -and -not $isCoreTarget) {
			$cr.TempFiles | Where-Object { $_ -ilike "*.cs" } | Select-Object -First 1 | ForEach-Object {
				$dstSrc = ([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($outputFile), [System.IO.Path]::GetFileNameWithoutExtension($outputFile) + ".cs"))
				Write-I18n Host SourceFileCopied $dstSrc
				Copy-Item -Path $_ -Destination $dstSrc -Force
			}
			$cr.TempFiles | Remove-Item -Verbose:$FALSE -Force -ErrorAction SilentlyContinue
		}

		# 代码签名逻辑
		if ($CodeSigning) {
			Write-I18n Host SigningExecutable
			try {
				$cert = $null
				$timestampServer = if ($CodeSigning.TimestampServer) { $CodeSigning.TimestampServer } else { "http://timestamp.digicert.com" }

				if ($CodeSigning.Path) {
					if ($CodeSigning.Password) {
						$cert = Get-PfxCertificate -FilePath $CodeSigning.Path -Password $CodeSigning.Password
					}
					else {
						$cert = Get-PfxCertificate -FilePath $CodeSigning.Path
					}
				}
				elseif ($CodeSigning.Thumbprint) {
					$cert = Get-Item "Cert:\CurrentUser\My\$($CodeSigning.Thumbprint)" -ErrorAction SilentlyContinue
					if (!$cert) {
						$cert = Get-Item "Cert:\LocalMachine\My\$($CodeSigning.Thumbprint)" -ErrorAction SilentlyContinue
					}
				}

				if ($cert) {
					$signature = Set-AuthenticodeSignature -FilePath $outputFile -Certificate $cert -TimestampServer $timestampServer -HashAlgorithm SHA256
					if ($signature.Status -eq 'Valid') {
						Write-I18n Host ExecutableSignedSuccessfully
					}
					else {
						Write-I18n Warning SigningStatusNotValid $signature.Status $signature.StatusMessage
					}
				}
				else {
					Write-I18n Error CertificateNotFoundOrInvalidPassword
				}
			}
			catch {
				Write-TaskbarProgressError
				Write-I18n Error SigningFailed $_.Exception.Message
			}
		}
	}
	if (!$nested -and (Test-StdoutRedirected)) {
		Write-Output $outputFile
	}
}
catch {
	Write-TaskbarProgressError
	if (Test-Path $outputFile) {
		Remove-Item $outputFile -Verbose:$FALSE
	}
	$_ | Write-Error -ErrorAction Continue
	if ($_.CategoryInfo.Category -eq 'ReadError') {
		$global:LastExitCode = 1 # 读取错误
		return
	}
	#_if PSScript
		if (!$GuestMode) {
			$global:LastExitCode = 3 # 内部未知错误
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
			Write-I18n Host OopsSomethingWentWrong -ForegroundColor Yellow
			if ($versionNow -eq '0.0.0') {} # 开发版本，什么也不做
			elseif ($versionNow -ne $versionOnline) {
				Write-I18n Host TryUpgrade $versionOnline -ForegroundColor Yellow
			}
			elseif (-not (Test-StdoutRedirected)) {
				Write-I18n Host EnterToSubmitIssue -ForegroundColor Yellow
				Read-Host | Out-Null
				Start-Process $githubfeedback
			}
		}
	#_endif
}
finally {
	Write-TaskbarProgressClear
	if ($TempTempDir) {
		Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}
#_if PSEXE
	#_!! exit $LastExitCode
#_endif
