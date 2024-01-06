$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
$type = $type.MakeGenericType( @( ("System.String" -as "Type"), ("system.string" -as "Type") ) )
$o = [Activator]::CreateInstance($type)
$o.Add("CompilerVersion", "v4.0")

$referenceAssembies = @("System.dll")
function GetAssembie($name,$otherinfo) {
	$n = New-Object System.Reflection.AssemblyName(@($name,$otherinfo)-ne$null-join",")
	try {
		[System.AppDomain]::CurrentDomain.Load($n).Location
	}
	catch {
		$Error.Remove(0)
	}
}
$referenceAssembies += GetAssembie "System.Core" "Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
$referenceAssembies += GetAssembie "System.Management.Automation"

# If noConsole is true, add System.Windows.Forms.dll and System.Drawing.dll to the reference assemblies
if ($noConsole) {
	$referenceAssembies += GetAssembie "System.Windows.Forms"
	$referenceAssembies += GetAssembie "System.Drawing"
}
else{
	$referenceAssembies += GetAssembie "mscorlib"
	$referenceAssembies += GetAssembie "System.Console"
	$referenceAssembies += GetAssembie "Microsoft.PowerShell.ConsoleHost"
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

. $PSScriptRoot\BuildFrame.ps1

if (-not $TempDir) {
	$TempDir = $TempTempDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
	New-Item -Path $TempTempDir -ItemType Directory | Out-Null
}
$TempDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TempDir)
$cp.TempFiles = New-Object System.CodeDom.Compiler.TempFileCollection($TempDir)

. $PSScriptRoot\BuildTempFiles.ps1

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

if(!$IsConstProgram) {
	[VOID]$cp.EmbeddedResources.Add("$TempDir\main.ps1")
}
$cr = $cop.CompileAssemblyFromSource($cp, $programFrame)
if ($cr.Errors.Count -gt 0) {
	if (Test-Path $outputFile) {
		Remove-Item $outputFile -Verbose:$FALSE
	}
	RollUp
	Write-Host "Compilation failed!" -ForegroundColor Red
	$cr.Errors -join "`n" | Write-Error
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
if ($TempTempDir) {
	Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($requireAdmin -or $DPIAware -or $supportOS -or $longPaths) {
	if (Test-Path $($outputFile + ".win32manifest")) {
		Remove-Item $($outputFile + ".win32manifest") -Verbose:$FALSE
	}
}
