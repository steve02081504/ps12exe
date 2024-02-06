$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
$type = $type.MakeGenericType( @( ("System.String" -as "Type"), ("system.string" -as "Type") ) )
$o = [Activator]::CreateInstance($type)
$o.Add("CompilerVersion", "v4.0")

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

$cp.TempFiles = New-Object System.CodeDom.Compiler.TempFileCollection($TempDir)

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

if (!$AstAnalyzeResult.IsConst) {
	[VOID]$cp.EmbeddedResources.Add("$TempDir\main.ps1")
}
$cr = $cop.CompileAssemblyFromSource($cp, $programFrame)
if ($cr.Errors.Count -gt 0) {
	throw $cr.Errors -join "`n"
}

if ($requireAdmin -or $DPIAware -or $supportOS -or $longPaths) {
	if (Test-Path $($outputFile + ".win32manifest")) {
		Remove-Item $($outputFile + ".win32manifest") -Verbose:$FALSE
	}
}
