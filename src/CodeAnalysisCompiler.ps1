$referenceAssembies = @()

$Mscorlib = [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile(([type] 'object').Assembly.Location)
$referenceAssembies += $Mscorlib

# Add System.dll to the reference assemblies
$systemDllPath = [System.IO.Path]::Combine([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(), "System.dll")
$referenceAssembies += $systemDllPath

# Add System.Globalization.dll to the reference assemblies
$globalizationDllPath = [System.IO.Path]::Combine([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(), "System.Globalization.dll")
if ([System.IO.File]::Exists($globalizationDllPath)) {
	$referenceAssembies += $globalizationDllPath
}

# Check if Microsoft.PowerShell.ConsoleHost.dll exists and add it to the reference assemblies
$consoleHostDllPath = [System.Reflection.Assembly]::GetAssembly([System.Management.Automation.Runspaces.Runspace]).Location
if ([System.IO.File]::Exists($consoleHostDllPath) -and !$noConsole) {
	$referenceAssembies += $consoleHostDllPath
}

# Add System.Management.Automation.dll to the reference assemblies
$automationDllPath = [System.Reflection.Assembly]::GetAssembly([System.Management.Automation.PSObject]).Location
if ([System.IO.File]::Exists($automationDllPath)) {
	$referenceAssembies += $automationDllPath
}

# Add System.Core.dll to the reference assemblies
$coreDllPath = [System.IO.Path]::Combine([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(), "System.Core.dll")
if ([System.IO.File]::Exists($coreDllPath)) {
	$referenceAssembies += $coreDllPath
}

# If noConsole is true, add System.Windows.Forms.dll and System.Drawing.dll to the reference assemblies
$OutputKind = [Microsoft.CodeAnalysis.OutputKind]::ConsoleApplication
if ($noConsole) {
	$formsDllPath = [System.IO.Path]::Combine([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(), "System.Windows.Forms.dll")
	$drawingDllPath = [System.IO.Path]::Combine([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(), "System.Drawing.dll")
	if ([System.IO.File]::Exists($formsDllPath)) {
		$referenceAssembies += $formsDllPath
	}
	if ([System.IO.File]::Exists($drawingDllPath)) {
		$referenceAssembies += $drawingDllPath
	}
	$OutputKind = [Microsoft.CodeAnalysis.OutputKind]::WindowsApplication
}

$references = $referenceAssembies | ForEach-Object { 
	if ([System.IO.File]::Exists($_)) {
		[Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($_) 
	}
}

. $PSScriptRoot\BuildFrame.ps1

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

# Get a default CSharpParseOptions instance
$parseOptions = [Microsoft.CodeAnalysis.CSharp.CSharpParseOptions]::Default

# Set preprocessor symbols
$parseOptions = $parseOptions.WithPreprocessorSymbols($Constants)

$tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($programFrame, $parseOptions)

$compilationOptions = New-Object Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions($OutputKind)

if (-not $TempDir) {
	$TempDir = $TempTempDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
	New-Item -Path $TempTempDir -ItemType Directory | Out-Null
}
$TempDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TempDir)

. $PSScriptRoot\BuildTempFiles.ps1

if ($iconFile) {
	$compilationOptions = $compilationOptions.WithWin32Icon($iconFilePath)
}
if (!$virtualize) {
	$compilationOptions = $compilationOptions.WithPlatform($(
		switch ($architecture) {
			"x86" { [Microsoft.CodeAnalysis.Platform]::X86 }
			"x64" { [Microsoft.CodeAnalysis.Platform]::X64 }
			"anycpu" { [Microsoft.CodeAnalysis.Platform]::AnyCpu }
			default {
				Write-Warning "Invalid platform $architecture, using AnyCpu"
				[Microsoft.CodeAnalysis.Platform]::AnyCpu
			}
		})
	)
}
else {
	Write-Host "Application virtualization is activated, forcing x86 platfom."
	$compilationOptions = $compilationOptions.WithPlatform([Microsoft.CodeAnalysis.Platform.X86])
}

if(!$IsConstProgram) {
	$resourceDescription = New-Object Microsoft.CodeAnalysis.Emit.EmbeddedResource("$TempDir\main.ps1", [Microsoft.CodeAnalysis.ResourceDescriptionKind]::Embedded)
	$compilation = $compilation.AddReferences($resourceDescription)
}

if ($prepareDebug) {
	$compilationOptions = $compilationOptions.WithOptions($compilation.Options.WithOptimizationLevel([Microsoft.CodeAnalysis.OptimizationLevel]::Debug)).WithDebugPlusMode($TRUE)
}

$treeArray = New-Object System.Collections.Generic.List[Microsoft.CodeAnalysis.SyntaxTree]
$treeArray.Add($tree)
$referencesArray = New-Object System.Collections.Generic.List[Microsoft.CodeAnalysis.MetadataReference]
$references | ForEach-Object { $referencesArray.Add($_) }

$compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create(
	"PSRunner",
	$treeArray.ToArray(),
	$referencesArray.ToArray(),
	$compilationOptions
)

# Create a new EmitOptions instance
$emitOptions = New-Object Microsoft.CodeAnalysis.Emit.EmitOptions -ArgumentList @([Microsoft.CodeAnalysis.Emit.DebugInformationFormat]::PortablePdb)

$peStream = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)
$emitResult = $compilation.Emit($peStream, $null, $null, $null, $null, $emitOptions)
$peStream.Close()

Write-Host "Compiling file..."

if ($emitResult.Success) {
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
} else {
	if (Test-Path $outputFile) {
		Remove-Item $outputFile -Verbose:$FALSE
	}
	RollUp
	Write-Host "Compilation failed!" -ForegroundColor Red
	$emitResult.Diagnostics -join "`n" | Write-Error
}
if ($TempTempDir) {
	Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
}
