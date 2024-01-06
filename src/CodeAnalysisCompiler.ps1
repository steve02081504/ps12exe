function GetAssembie($name, $otherinfo) {
	$n = New-Object System.Reflection.AssemblyName(@($name, $otherinfo) -ne $null -join ",")
	try {
		[System.AppDomain]::CurrentDomain.Load($n).Location
	}
	catch {
		$Error.Remove(0)
	}
}
$referenceAssembies = @()
# 绝不要直接使用 System.Private.CoreLib.dll，因为它是netlib的内部实现，而不是公共API
# [int].Assembly.Location 等基础类型的程序集也是它。
$referenceAssembies += GetAssembie "mscorlib"
$referenceAssembies += GetAssembie "System.Runtime" "PublicKeyToken=b03f5f7f11d50a3a"
$referenceAssembies += GetAssembie "System.Management.Automation"

# If noConsole is true, add System.Windows.Forms.dll and System.Drawing.dll to the reference assemblies
$OutputKind = if ($noConsole) {
	$referenceAssembies += GetAssembie "System.Windows.Forms"
	$referenceAssembies += GetAssembie "System.Drawing"
	[Microsoft.CodeAnalysis.OutputKind]::WindowsApplication
}
else {
	$referenceAssembies += GetAssembie "System.Console"
	$referenceAssembies += GetAssembie "Microsoft.PowerShell.ConsoleHost"
	[Microsoft.CodeAnalysis.OutputKind]::ConsoleApplication
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
$compilationOptions = $compilationOptions.WithOptimizationLevel($(
		if ($prepareDebug) {
			[Microsoft.CodeAnalysis.OptimizationLevel]::Debug
		}
		else {
			[Microsoft.CodeAnalysis.OptimizationLevel]::Release
		}
	))

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

if (!$IsConstProgram) {
	$resourceDescription = New-Object Microsoft.CodeAnalysis.Emit.EmbeddedResource("$TempDir\main.ps1", [Microsoft.CodeAnalysis.ResourceDescriptionKind]::Embedded)
	$compilation = $compilation.AddReferences($resourceDescription)
}

# Create a new EmitOptions instance
$emitOptions = New-Object Microsoft.CodeAnalysis.Emit.EmitOptions -ArgumentList @([Microsoft.CodeAnalysis.Emit.DebugInformationFormat]::PortablePdb)
$emitOptions = $emitOptions.WithRuntimeMetadataVersion("$($PSVersionTable.PSVersion.Major).0")
$emitOptions = $emitOptions.WithEmitMetadataOnly($false)

$peStream = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)
$pdbStream = if ($prepareDebug) {
	New-Object System.IO.FileStream(($outputFile -replace '\.exe$', '.pdb'), [System.IO.FileMode]::Create)
}
$emitResult = $compilation.Emit($peStream, $pdbStream, $null, $null, $null, $emitOptions)
$peStream.Close()
if ($prepareDebug) {
	$pdbStream.Close()
}

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
}
else {
	throw $emitResult.Diagnostics -join "`n"
}
if ($TempTempDir) {
	Remove-Item $TempTempDir -Recurse -Force -ErrorAction SilentlyContinue
}
