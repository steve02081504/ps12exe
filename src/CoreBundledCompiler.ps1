# PowerShell SDK 打包后端（Build.Core.Backend='Bundled'）。
# 与 Shared 后端「从目标机 $PSHOME 解析 SMA」不同，这里把 PowerShell 以 NuGet 包 Microsoft.PowerShell.SDK
# 直接编进产物，因此目标机无需安装 pwsh，且可以 SelfContained / Trimmed / ReadyToRun / InvariantGlobalization / AOT。
# 产物显著更大（几十 MB 起步）。常量脚本不依赖 PowerShell，仍用 constexpr.cs 且不引用 SDK，只是套用发布属性。
#
# 由 CoreCompiler.ps1 点源调用（那里已备好 $dotnet 与工程辅助），调用方提供：$tfm / $rid / $assemblyName /
# $isConst / $programFrame / $outputFile / $TempDir / $resourceElements / $versionElements / $iconElement /
# $defineConstants / $debugType / $prepareDebug / $noConsole / $conHost / $coreTargetFramework /
# $powerShellVersion / $selfContained / $trimmed / $trimMode / $readyToRun / $invariantGlobalization /
# $aot / $singleFile。

# PowerShell 版本 → 最低 .NET TFM（只按 major.minor 匹配）。
$psDotnetMap = @{
	'7.2' = 'net6.0'
	'7.3' = 'net7.0'
	'7.4' = 'net8.0'
	'7.5' = 'net9.0'
	'7.6' = 'net10.0'
	'7.7' = 'net11.0'
}

$psSdkVersion = if ($powerShellVersion) { $powerShellVersion } else { $PSVersionTable.PSVersion.ToString() }
$psVersionObject = $null
try { $psVersionObject = [version]$psSdkVersion } catch {}
if (-not $psVersionObject) {
	Write-I18n Error InvalidCorePowerShellVersion $psSdkVersion -Category InvalidArgument
	throw 'ps12exe:core-bundled-bad-psver'
}
$psKey = "$($psVersionObject.Major).$($psVersionObject.Minor)"
$mappedTfm = $psDotnetMap[$psKey]
if (-not $mappedTfm) {
	$runtimeVersion = [System.Environment]::Version
	$mappedTfm = "net$($runtimeVersion.Major).$($runtimeVersion.Minor)"
	Write-I18n Warning CoreVersionNoMapping $psSdkVersion $mappedTfm
}
$tfmBase = if ($coreTargetFramework) { $coreTargetFramework } else { $mappedTfm }
$tfmBaseMajor = if ($tfmBase -match '^net(\d+)\.') { [int]$Matches[1] } else { $null }
$mappedMajor = if ($mappedTfm -match '^net(\d+)\.') { [int]$Matches[1] } else { $null }
if ($tfmBaseMajor -and $mappedMajor -and $tfmBaseMajor -lt $mappedMajor) {
	Write-I18n Error CoreTargetFrameworkTooLow $tfmBase $mappedTfm -Category InvalidArgument
	throw 'ps12exe:core-bundled-tfm-too-low'
}
$tfm = $tfmBase

# GUI 框架检测：console 应用默认不引用 WindowsDesktop 框架，脚本用到 WinForms/WPF 时按需打开（PS2EXE.Core #6），
# 并据此让 TFM 带 -windows。常量脚本只用预定义类型，不可能用到 GUI。
$guiUsage = if ($isConst) { @{ WinForms = $false; Wpf = $false } } else { Get-GuiFrameworkUsage $Content }
$useWinForms = $guiUsage.WinForms -and $rid -like 'win-*'
$useWpf = $guiUsage.Wpf -and $rid -like 'win-*'
if (($noConsole -or $useWinForms -or $useWpf) -and $tfm -notmatch '-windows$') { $tfm += '-windows' }

$bundleOutputType = if ($noConsole -or ($conHost -and -not $isConst)) { 'WinExe' } else { 'Exe' }
$bundleWinForms = ''
if ($noConsole -or $useWinForms) { $bundleWinForms += '<UseWindowsForms>true</UseWindowsForms>' }
if ($useWpf) { $bundleWinForms += '<UseWPF>true</UseWPF>' }
# 非常量帧用 CoreHost 定义选择 Environment.ProcessPath（单文件发布下 Assembly.Location 为空）。
$bundleConstants = if ($isConst) { $defineConstants } else { (($coreConstants + 'CoreHost') | Sort-Object -Unique) -join ';' }

$selfContainedStr = $selfContained.ToString().ToLowerInvariant()
$singleFileStr = $singleFile.ToString().ToLowerInvariant()
$trimmedStr = $trimmed.ToString().ToLowerInvariant()
$r2rStr = $readyToRun.ToString().ToLowerInvariant()
$invariantStr = $invariantGlobalization.ToString().ToLowerInvariant()
$aotStr = $aot.ToString().ToLowerInvariant()

$bundleTrimItems = ''
if ($trimmed) {
	# TrimMode 只在启用裁剪时才写入；AOT 会隐式裁剪。
	$trimModeElement = "<TrimMode>$trimMode</TrimMode>"
	$bundleTrimItems = @"
		<TrimmerRootAssembly Include="System.Management.Automation" />
		<TrimmerRootAssembly Include="Microsoft.PowerShell.Commands.Diagnostics" />
		<TrimmerRootAssembly Include="Microsoft.PowerShell.Commands.Management" />
		<TrimmerRootAssembly Include="Microsoft.PowerShell.Commands.Utility" />
		<TrimmerRootAssembly Include="Microsoft.PowerShell.ConsoleHost" />
		<TrimmerRootAssembly Include="Microsoft.PowerShell.Security" />
		<TrimmerRootAssembly Include="Microsoft.WSMan.Management" />
"@
}
else { $trimModeElement = '' }
$bundleAotItems = ''
if ($aot -and $tfmBase -match '^net(\d+)\.' -and [int]$Matches[1] -ge 8) {
	$bundleAotItems = '		<PackageReference Include="System.Formats.Nrbf" Version="10.*" />'
}
$bundleSdkReference = if ($isConst) { '' } else { "		<PackageReference Include=`"Microsoft.PowerShell.SDK`" Version=`"$psSdkVersion`" />" }
$bundleScriptItem = if ($isConst) { '' } else { '		<EmbeddedResource Include="main.ps1" LogicalName="main.ps1" />' }

# ---------- 工程缓存 ----------
$smaVersion = if ($isConst) { 'const' } else { $psSdkVersion }
$bundleInvariant = @(
	"tfm=$tfm", "tfmBase=$tfmBase", "rid=$rid", "outputType=$bundleOutputType", "debugType=$debugType"
	"assemblyName=$assemblyName", "winForms=$bundleWinForms", "icon=$iconElement"
	"resources=$resourceElements", "version=$versionElements"
	"define=$bundleConstants", "isConst=$isConst", "sdk=$smaVersion"
	"selfContained=$selfContainedStr", "singleFile=$singleFileStr", "trimmed=$trimmedStr"
	"trimMode=$trimMode", "r2r=$r2rStr", "invariant=$invariantStr", "aot=$aotStr"
)
$bundleBuildKey = Get-CoreBuildKey $bundleInvariant

$bundleProject = Enter-CoreProject -CacheTag 'corebundle' -BuildKey $bundleBuildKey -TempDir $TempDir
$projectDir = $bundleProject.ProjectDir

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

$publishDir = Join-Path $projectDir 'publish'

try {
	[System.IO.File]::WriteAllText((Join-Path $projectDir 'frame.cs'), $programFrame, [System.Text.UTF8Encoding]::new($false))
	if (-not $isConst) {
		Copy-Item -LiteralPath (Join-Path $TempDir 'main.ps1') -Destination (Join-Path $projectDir 'main.ps1') -Force
	}

	# TrimMode 与裁剪根项一起写入（裁剪器根项必须保留，故并入同一个条件块）。
	$bundleCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
	<PropertyGroup>
		<OutputType>$bundleOutputType</OutputType>
		<TargetFramework>$tfm</TargetFramework>
		<RuntimeIdentifier>$rid</RuntimeIdentifier>
		<SelfContained>$selfContainedStr</SelfContained>
		<PublishSingleFile>$singleFileStr</PublishSingleFile>
		<IncludeNativeLibrariesForSelfExtract>$singleFileStr</IncludeNativeLibrariesForSelfExtract>
		<IncludeAllContentForSelfExtract>$singleFileStr</IncludeAllContentForSelfExtract>
		<PublishTrimmed>$trimmedStr</PublishTrimmed>
		$trimModeElement
		<PublishReadyToRun>$r2rStr</PublishReadyToRun>
		<InvariantGlobalization>$invariantStr</InvariantGlobalization>
		<PublishAot>$aotStr</PublishAot>
		<NoWarn>`$(NoWarn);CA1416;IL3000;IL2026;IL3050;CS8073</NoWarn>
		<EnableDefaultCompileItems>false</EnableDefaultCompileItems>
		<AssemblyName>$assemblyName</AssemblyName>
		<Nullable>disable</Nullable>
		<ImplicitUsings>disable</ImplicitUsings>
		<DebugType>$debugType</DebugType>
		<GenerateDocumentationFile>false</GenerateDocumentationFile>
		<SatelliteResourceLanguages>en</SatelliteResourceLanguages>
		<AllowUnsafeBlocks>true</AllowUnsafeBlocks>
		<EnableWindowsTargeting>true</EnableWindowsTargeting>
		<DefineConstants>$([System.Security.SecurityElement]::Escape($bundleConstants))</DefineConstants>
		$bundleWinForms
		$iconElement
		$resourceElements
		$versionElements
	</PropertyGroup>
	<ItemGroup>
$bundleSdkReference
$bundleAotItems
$bundleTrimItems
	</ItemGroup>
	<ItemGroup>
		<Compile Include="frame.cs" />
$bundleScriptItem
	</ItemGroup>
</Project>
"@
	[System.IO.File]::WriteAllText((Join-Path $projectDir 'bundle.csproj'), $bundleCsproj, [System.Text.UTF8Encoding]::new($false))

	Write-I18n Host CoreCompilePublishing
	Write-Debug "Core bundled compiler: dotnet publish (tfm=$tfm, rid=$rid, sdk=$psSdkVersion, selfContained=$selfContainedStr, aot=$aotStr)"
	Remove-Item -LiteralPath $publishDir -Recurse -Force -ErrorAction Ignore
	$null = Invoke-CoreDotnet -DotnetArgs @('publish', (Join-Path $projectDir 'bundle.csproj'), '-c', 'Release', '-o', $publishDir) -AssetsPath (Join-Path $projectDir 'obj/project.assets.json') -DotnetPath $dotnet.Source

	Copy-CorePublishOutput -PublishDir $publishDir -AssemblyName $assemblyName -OutputFile $outputFile -SingleFile $singleFile -PrepareDebug $prepareDebug
}
finally {
	Exit-CoreProject $bundleProject
}
