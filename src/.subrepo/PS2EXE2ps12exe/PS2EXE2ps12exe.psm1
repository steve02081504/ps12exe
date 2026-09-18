<#
.SYNOPSIS
PS2EXE2ps12exe is a module to hook all PS2EXE calls into ps12exe.
#>

<#
.SYNOPSIS
Converts powershell scripts to standalone executables.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end Win-PS2EXE for convenience.

PS2EXE2ps12exe is a compatibility layer: it forwards and rewrites every PS2EXE call into ps12exe.
Features that ps12exe does not provide natively (conHost, embedFiles) are emulated by rewriting the
script at compile time, so PS2EXE scripts keep working unchanged.

Please see Remarks on project page for topics "GUI mode output formatting", "Config files", "Password security",
"Script variables" and "Window in background in -noConsole mode".

.PARAMETER inputFile
Powershell script to convert to executable (file has to be UTF8 or UTF16 encoded)
.PARAMETER outputFile
destination executable file name or folder, defaults to inputFile with extension '.exe'
.PARAMETER prepareDebug
create helpful information for debugging of generated executable. See parameter -debug there
.PARAMETER runtime20
legacy: this switch forces the generated executable to target .NET Framework 2.0/3.x for PowerShell 2.0
.PARAMETER runtime40
legacy: this switch forces the generated executable to target .NET Framework 4.x for PowerShell 3.0 or higher
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
.PARAMETER conHost
force start with conhost as console instead of Windows Terminal. If necessary a new console window
will appear. ps12exe has no native equivalent, so PS2EXE2ps12exe restarts the executable inside conhost.
.PARAMETER UNICODEEncoding
encode output as UNICODE in console mode, useful to display special encoded chars
.PARAMETER credentialGUI
use GUI for prompting credentials in console mode instead of console input
.PARAMETER iconFile
icon file name for the compiled executable
.PARAMETER embedFiles
paths to files to embed given as hash table, will be extracted at runtime to the keys of the hashes, source
file names must be unique, e.g. -embedFiles @{'Targetfilepath'='Sourcefilepath'}.
Absolute and relative paths are allowed. For target paths a relative path beginning with '.\' is interpreted
as relative to the executable, without the leading '.\' as relative to the current path at runtime.
Directories are created automatically on startup if necessary.
In the target path environment variables in cmd.exe notation like %TEMP% or %APPDATA% are expanded at runtime.
ps12exe has no native equivalent, so PS2EXE2ps12exe embeds the files at compile time and extracts them at startup.
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
Invoke-ps2exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
.EXAMPLE
ps2exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
.EXAMPLE
Win-PS2EXE
Start graphical front end to Invoke-ps2exe
#>
function Invoke-ps2exe {
	[CmdletBinding()]
	Param([STRING]$inputFile = $NULL, [STRING]$outputFile = $NULL, [SWITCH]$prepareDebug, [SWITCH]$runtime20, [SWITCH]$runtime40, [SWITCH]$x86, [SWITCH]$x64, [int]$lcid,
		[SWITCH]$STA, [SWITCH]$MTA, [SWITCH]$nested, [SWITCH]$noConsole, [SWITCH]$conHost, [SWITCH]$UNICODEEncoding, [SWITCH]$credentialGUI, [STRING]$iconFile = $NULL,
		[Hashtable]$embedFiles = @{}, [STRING]$title, [STRING]$description, [STRING]$company, [STRING]$product, [STRING]$copyright, [STRING]$trademark, [STRING]$version,
		[SWITCH]$configFile, [SWITCH]$noConfigFile, [SWITCH]$noOutput, [SWITCH]$noError, [SWITCH]$noVisualStyles, [SWITCH]$exitOnCancel,
		[SWITCH]$DPIAware, [SWITCH]$winFormsDPIAware, [SWITCH]$requireAdmin, [SWITCH]$supportOS, [SWITCH]$virtualize, [SWITCH]$longPaths)

	# 复刻 PS2EXE 的参数校验
	if ($x86 -and $x64) { throw "-x86 can't be combined with -x64." }
	if ($STA -and $MTA) { throw "-STA can't be combined with -MTA." }
	if ($noConsole -and $conHost) { throw "-noConsole cannot be combined with -conHost" }
	if ($configFile -and $noConfigFile) { throw "-configFile cannot be combined with -noConfigFile" }
	if ($runtime20 -and $runtime40) { throw "-runtime20 can't be combined with -runtime40." }
	if ($runtime20 -and $longPaths) { throw "Long paths are only available with .NET 4 or above." }
	if ($runtime20 -and $winFormsDPIAware) { throw "DPI awareness is only available with .NET 4 or above." }

	if (!(Get-Module -Name ps12exe -ListAvailable)) {
		Install-Module -Name ps12exe -Scope CurrentUser -Force
	}
	Import-Module -Name ps12exe

	# 转发到 ps12exe 的对象 API
	$psParams = @{}
	foreach ($name in @('inputFile', 'outputFile', 'configFile')) {
		if ($PSBoundParameters.ContainsKey($name)) { $psParams[$name] = $PSBoundParameters[$name] }
	}
	# App
	$app = @{}
	if ($PSBoundParameters.ContainsKey('noConsole')) { $app.Windowed = [bool]$noConsole }
	if ($PSBoundParameters.ContainsKey('UNICODEEncoding')) { $app.OutputEncoding = if ($UNICODEEncoding) { 'UTF16LE' } else { 'Default' } }
	if ($PSBoundParameters.ContainsKey('credentialGUI')) { $app.CredentialGUI = [bool]$credentialGUI }
	if ($PSBoundParameters.ContainsKey('noVisualStyles')) { $app.VisualStyles = -not [bool]$noVisualStyles }
	if ($PSBoundParameters.ContainsKey('exitOnCancel')) { $app.ExitOnCancel = [bool]$exitOnCancel }
	if ($PSBoundParameters.ContainsKey('DPIAware')) { $app.DpiAware = [bool]$DPIAware }
	if ($PSBoundParameters.ContainsKey('winFormsDPIAware')) { $app.WinFormsDpiAware = [bool]$winFormsDPIAware }
	$silence = @()
	if ($noOutput) { $silence += @('Output', 'Verbose') }
	if ($noError) { $silence += @('Error', 'Warning', 'Debug') }
	if ($silence.Count) { $app.Silence = $silence }
	if ($app.Count) { $psParams.App = $app }
	# Os
	$os = @{}
	if ($PSBoundParameters.ContainsKey('requireAdmin')) { $os.Admin = [bool]$requireAdmin }
	if ($PSBoundParameters.ContainsKey('supportOS')) { $os.ModernOS = [bool]$supportOS }
	if ($PSBoundParameters.ContainsKey('virtualize')) { $os.Virtualize = [bool]$virtualize }
	if ($PSBoundParameters.ContainsKey('longPaths')) { $os.LongPaths = [bool]$longPaths }
	if ($os.Count) { $psParams.Os = $os }
	# Build
	$build = @{}
	if ($PSBoundParameters.ContainsKey('prepareDebug')) { $build.KeepSource = [bool]$prepareDebug }
	if ($PSBoundParameters.ContainsKey('lcid')) { $build.Culture = "$lcid" }
	if ($x86) { $build.Platform = 'x86' }
	elseif ($x64) { $build.Platform = 'x64' }
	if ($STA) { $build.Apartment = 'STA' }
	elseif ($MTA) { $build.Apartment = 'MTA' }
	if ($runtime20) { $build.Target = 'Framework2.0' }
	elseif ($runtime40) { $build.Target = 'Framework4.0' }
	# noConfigFile 是 PS2EXE 的兼容占位参数，直接忽略

	# 资源参数合并为 Resources 哈希表
	$resourceKeyMap = @{
		iconFile = 'Icon'; title = 'Title'; description = 'Description'; company = 'Company'
		product = 'Product'; copyright = 'Copyright'; trademark = 'Trademark'; version = 'Version'
	}
	$resources = @{}
	foreach ($name in @('iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version')) {
		if ($PSBoundParameters.ContainsKey($name) -and $PSBoundParameters[$name]) { $resources[$resourceKeyMap[$name]] = $PSBoundParameters[$name] }
	}
	if ($resources.Count) { $psParams.Resources = $resources }

	# 收集 embedFiles 的二进制内容，供编译期注入
	$embedEntries = @()
	if ($embedFiles) {
		foreach ($target in $embedFiles.Keys) {
			$source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string]$embedFiles[$target])
			if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Embed file not found: $($embedFiles[$target])" }
			$embedEntries += @{
				Target = [string]$target
				Base64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($source))
			}
		}
	}

	# ps12exe 缺少 conHost / embedFiles，且不提供 PS2EXE 的 $ScriptRoot；用 minifyer 在预处理后注入。
	# 需要转写时总会走这里，未命中任何注入点时原样返回。
	$rewriteState = @{
		ConHost = [bool]$conHost
		Embeds  = $embedEntries
	}
	$build.Minify = {
		$text = $_
		if (-not $text) { return $text }
		$ast = $null
		try { $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null) }
		catch { $ast = $null }
		if (-not $ast) { return $text }

		$inject = [System.Collections.Generic.List[string]]::new()
		if ($rewriteState.ConHost) {
			$inject.Add(@'
& {
	if (-not $env:__PSEXE_CONHOST__) {
		$env:__PSEXE_CONHOST__ = '1'
		$PSEXEProcess = Start-Process conhost.exe -ArgumentList @('cmd', '/c', [System.Environment]::CommandLine) -PassThru -Wait
		exit $PSEXEProcess.ExitCode
	}
}
'@)
		}
		foreach ($embed in $rewriteState.Embeds) {
			$targetLiteral = $embed.Target.Replace("'", "''")
			$inject.Add(@"
& {
	`$__PSEXE_Target = [System.Environment]::ExpandEnvironmentVariables('$targetLiteral')
	if (`$__PSEXE_Target.StartsWith('.\')) { `$__PSEXE_Target = [System.IO.Path]::Combine(`$PSScriptRoot, `$__PSEXE_Target.Substring(2)) }
	`$__PSEXE_Dir = [System.IO.Path]::GetDirectoryName(`$__PSEXE_Target)
	if (`$__PSEXE_Dir) { [System.IO.Directory]::CreateDirectory(`$__PSEXE_Dir) | Out-Null }
	[System.IO.File]::WriteAllBytes(`$__PSEXE_Target, [System.Convert]::FromBase64String('$($embed.Base64)'))
}
"@)
		}
		# PS2EXE 会在运行空间里设置 $ScriptRoot；脚本用到时才补上
		$scriptRootUsed = $ast.FindAll({
				param($node)
				$node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -eq 'ScriptRoot'
			}, $true)
		if ($scriptRootUsed.Count -gt 0) {
			$inject.Add('$global:ScriptRoot = $PSScriptRoot')
		}

		if ($inject.Count -eq 0) { return $text }
		$insertAt = if ($ast.ParamBlock) { $ast.ParamBlock.Extent.EndOffset } else { 0 }
		$text.Substring(0, $insertAt) + "`n" + ($inject -join "`n") + "`n" + $text.Substring($insertAt)
	}.GetNewClosure()
	$psParams.Build = $build

	ps12exe @psParams
}

function Invoke-WinPS2EXE {
	if (!(Get-Module -Name ps12exe -ListAvailable)) {
		Install-Module -Name ps12exe -Scope CurrentUser -Force
	}
	Import-Module -Name ps12exe
	ps12exeGUI
}

Set-Alias ps2exe Invoke-ps2exe -Scope Global
Set-Alias ps2exe.ps1 Invoke-ps2exe -Scope Global
Set-Alias Win-PS2EXE Invoke-WinPS2EXE -Scope Global
Set-Alias Win-PS2EXE.exe Invoke-WinPS2EXE -Scope Global

Export-ModuleMember -Function @('Invoke-PS2EXE', 'Invoke-WinPS2EXE')
Export-ModuleMember -Alias @('ps2exe', 'ps2exe.ps1', 'Win-PS2EXE', 'Win-PS2EXE.exe')
