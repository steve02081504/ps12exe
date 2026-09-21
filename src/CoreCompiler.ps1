# PowerShell Core / .NET 编译路径。非常量：把程序框架编成托管负载程序集（payload.dll，内含 main.ps1 资源），Brotli 压缩成 "main" 资源塞进 launcher（pack.cs + CoreHost.cs 引导），dotnet publish 成单文件 exe；SMA 不打包，运行时由 CoreHost 从 $PSHOME 解析。常量：constexpr.cs 自包含、不引用 SMA，直接 publish 成单文件 exe，不走 payload/launcher。产物是框架依赖：目标机器需要有 PowerShell Core（提供引擎与模块）以及匹配的 .NET 运行时。

# 只有 pwsh 宿主才能正确推导 Core 的目标框架、$PSHOME 与 RID；Windows PowerShell 下应先交接给 pwsh。
if ($PSVersionTable.PSEdition -ne 'Core') {
	Write-I18n Error CoreCompileNeedPwshHost -Category InvalidOperation
	throw 'ps12exe:core-host'
}

. $PSScriptRoot\CoreProject.ps1

$dotnet = Get-CoreDotnet

$unsupported = @()
foreach ($a in @('requireAdmin', 'DPIAware', 'supportOS', 'longPaths', 'virtualize', 'winFormsDPIAware')) {
	if ((Get-Variable -Name $a -ValueOnly -ErrorAction Ignore)) { $unsupported += $a }
}
if ($DllExportList) { $unsupported += 'Build.DllExports' }
if ($unsupported.Count) {
	Write-I18n Error CoreCompileUnsupported ($unsupported -join ', ') -Category InvalidArgument
	throw 'ps12exe:core-unsupported'
}

# 目标框架版本：显式 Build.Core.TargetFramework 优先，否则跟随当前 PowerShell 所用的 .NET 运行时。
if ($coreTargetFramework) {
	$tfm = $coreTargetFramework
}
else {
	$runtimeVersion = [System.Environment]::Version
	$tfm = "net$($runtimeVersion.Major).$($runtimeVersion.Minor)"
}

# 目标平台：Build.Core.TargetOs 优先，否则用宿主 OS；架构来自 Build.Platform。
$ridOs = switch ($coreTargetOs) {
	'Windows' { 'win' }
	'Linux' { 'linux' }
	'MacOS' { 'osx' }
	default { if ($IsWindows) { 'win' } elseif ($IsMacOS) { 'osx' } else { 'linux' } }
}
$ridArch = $architecture
if ($ridArch -eq 'anycpu') {
	$ridArch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
		'X64' { 'x64' }
		'X86' { 'x86' }
		'Arm64' { 'arm64' }
		default { 'x64' }
	}
}
# 32 位运行时只在 Windows 目标上提供。
if ($ridOs -ne 'win' -and $ridArch -eq 'x86') { $ridArch = 'x64' }
# 非 Windows 目标不支持 conhost / 窗口化（已在 ps12exe.ps1 校验，这里防御）。
if ($ridOs -ne 'win' -and $conHost) { throw 'ps12exe:conhost-not-windows' }
$rid = "$ridOs-$ridArch"

# GUI 框架检测（PS2EXE.Core #6）：WPF 在宿主应用里会错误解析到 .NET Framework 的 GAC 版本，
# 必须显式打开 UseWPF 并让 TFM 带 -windows；WinForms 在 Shared 下由 CoreHost 从 $PSHOME 解析，
# 无需额外框架引用（只补 noConsole 自身用到的那份）。常量脚本只用预定义类型，不可能用到 GUI。
$guiUsage = if ($AstAnalyzeResult.IsConst) { @{ Wpf = $false } } else { Get-GuiFrameworkUsage $Content }
$useWpf = $guiUsage.Wpf -and $ridOs -eq 'win'
if (($noConsole -or $useWpf) -and $tfm -notmatch '-windows$') { $tfm += '-windows' }

$assemblyName = [System.IO.Path]::GetFileNameWithoutExtension($outputFile)
$assemblyName = ($assemblyName -replace '[^\w\.\-]', '_')
if (-not $assemblyName) { $assemblyName = 'output' }

$isConst = $AstAnalyzeResult.IsConst
# conHost 只对非常量帧有意义（pack.cs 的 launcher 负责重启）；常量产物是无交互的预计算结果，忽略它。
$launcherWinExe = $noConsole -or ($conHost -and -not $isConst)
$outputType = if ($launcherWinExe) { 'WinExe' } else { 'Exe' }
$debugType = if ($prepareDebug) { 'portable' } else { 'none' }
$iconElement = if ($iconFile) { "<ApplicationIcon>$([System.Security.SecurityElement]::Escape($iconFile))</ApplicationIcon>" } else { '' }
$winForms = if ($noConsole) { '<UseWindowsForms>true</UseWindowsForms>' } else { '' }
if ($useWpf) { $winForms += '<UseWPF>true</UseWPF>' }

# Add-Type 的编译路径（-TypeDefinition / -MemberDefinition / -Path *.cs）需要 $PSHOME\ref 下的引用程序集，
# 但宿主应用里 Add-Type 会去「入口程序集所在目录\ref」找（PS2EXE.Core #24）：把 ref 作为内容一起发布，
# 单文件下再让内容自解压即可命中。没用到 Add-Type 就不带（ref 约 6MB，Shared 的卖点是小）。
$needsRefAssemblies = (-not $isConst) -and ($Content -match '(?i)\bAdd-Type\b') -and (Test-Path -LiteralPath (Join-Path $PSHOME 'ref'))
$selfExtractElement = if ($needsRefAssemblies -and $singleFile) { '<IncludeAllContentForSelfExtract>true</IncludeAllContentForSelfExtract>' } else { '' }

# 资源/版本元数据由 SDK 生成，因此 DefineConstants 里剔除 Resources/version。
$coreConstants = @($Constants | Where-Object { $_ -and $_ -ne 'Resources' -and $_ -ne 'version' })
$defineConstants = ($coreConstants | Sort-Object -Unique) -join ';'

$resourceMap = @{
	title       = 'AssemblyTitle'
	description = 'Description'
	company     = 'Company'
	product     = 'Product'
	copyright   = 'Copyright'
	trademark   = 'Trademark'
}
$resourceElements = ($resourceMap.Keys | Where-Object { $resourceParams.ContainsKey($_) -and $resourceParams[$_] } | ForEach-Object {
	"<$($resourceMap[$_])>$([System.Security.SecurityElement]::Escape($resourceParams[$_]))</$($resourceMap[$_])>"
}) -join "`n`t`t"
$versionElements = if ($resourceParams.version) {
	$v = [System.Security.SecurityElement]::Escape($resourceParams.version)
	"<Version>$v</Version>`n`t`t<FileVersion>$v</FileVersion>`n`t`t<AssemblyVersion>$v</AssemblyVersion>"
}
else { '' }

# Bundled 后端：打包 PowerShell SDK，可 self-contained/trim/AOT，产物更大且目标机无需安装 pwsh。
if ($coreBackend -eq 'Bundled') {
	. $PSScriptRoot\CoreBundledCompiler.ps1
	return
}

# 常量帧与 launcher 两个发布项目共用的属性；DefineConstants 由调用处替换。
$publishedProps = @"
		<OutputType>$outputType</OutputType>
		<TargetFramework>$tfm</TargetFramework>
		<RuntimeIdentifier>$rid</RuntimeIdentifier>
		<SelfContained>false</SelfContained>
		<PublishSingleFile>$($singleFile.ToString().ToLowerInvariant())</PublishSingleFile>
		$selfExtractElement
		<NoWarn>`$(NoWarn);CA1416;IL3000;CS8073</NoWarn>
		<EnableDefaultCompileItems>false</EnableDefaultCompileItems>
		<AssemblyName>$assemblyName</AssemblyName>
		<Nullable>disable</Nullable>
		<ImplicitUsings>disable</ImplicitUsings>
		<DebugType>$debugType</DebugType>
		<GenerateDocumentationFile>false</GenerateDocumentationFile>
		<SatelliteResourceLanguages>en</SatelliteResourceLanguages>
		<AllowUnsafeBlocks>true</AllowUnsafeBlocks>
		<EnableWindowsTargeting>true</EnableWindowsTargeting>
		<DefineConstants>__DefineConstants__</DefineConstants>
		$winForms
		$iconElement
		$resourceElements
		$versionElements
"@

$payloadDefineConstants = (($coreConstants + 'CoreHost') | Sort-Object -Unique) -join ';'

# ---------- 编译工程缓存 ----------
# dotnet publish 的成本大头是 NuGet 还原 + MSBuild/SDK 求值；工程本身由选项唯一决定，
# 与脚本文本无关。把工程目录按「还原输入」缓存下来，后续编译只重编 frame.cs/main.ps1 并
# 叠加 --no-restore，可省掉每次约 0.8~0.9s 的还原。用命名互斥量串行化同一 key 的并发编译。
$smaPath = Join-Path $PSHOME 'System.Management.Automation.dll'
$coreBuildKey = Get-CoreBuildKey @(
	"tfm=$tfm", "rid=$rid", "outputType=$outputType", "debugType=$debugType"
	"assemblyName=$assemblyName", "winForms=$winForms", "icon=$iconElement"
	"resources=$resourceElements", "version=$versionElements"
	"define=$defineConstants"
	"payloadDefine=$payloadDefineConstants", "isConst=$isConst"
	"singleFile=$singleFile", "conHost=$conHost", "needsRef=$needsRefAssemblies"
	"sma=$smaPath", "edition=$($PSVersionTable.PSEdition)", "psver=$($PSVersionTable.PSVersion)"
)
$coreProject = Enter-CoreProject -CacheTag 'core' -BuildKey $coreBuildKey -TempDir $TempDir -MutexTimeoutMs 180000
$projectDir = $coreProject.ProjectDir

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

$publishDir = Join-Path $projectDir 'publish'

try {
	if ($isConst) {
		# ---------- 常量：constexpr.cs 直接 publish ----------
		[System.IO.File]::WriteAllText((Join-Path $projectDir 'frame.cs'), $programFrame, [System.Text.UTF8Encoding]::new($false))
		$constCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
	<PropertyGroup>
$($publishedProps.Replace('__DefineConstants__', [System.Security.SecurityElement]::Escape($defineConstants)))
	</PropertyGroup>
	<ItemGroup>
		<Compile Include="frame.cs" />
	</ItemGroup>
</Project>
"@
		[System.IO.File]::WriteAllText((Join-Path $projectDir 'const.csproj'), $constCsproj, [System.Text.UTF8Encoding]::new($false))
		Write-I18n Host CoreCompilePublishing
		Write-Debug "Core compiler: dotnet publish const frame (tfm=$tfm, rid=$rid)"
		Remove-Item -LiteralPath $publishDir -Recurse -Force -ErrorAction Ignore
		$null = Invoke-CoreDotnet -DotnetArgs @('publish', (Join-Path $projectDir 'const.csproj'), '-c', 'Release', '-o', $publishDir) -AssetsPath (Join-Path $projectDir 'obj/project.assets.json') -DotnetPath $dotnet.Source
	}
	else {
		# ---------- 非常量：payload 程序集 → Brotli → launcher ----------
		$payloadDir = Join-Path $projectDir 'payload'
		New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
		[System.IO.File]::WriteAllText((Join-Path $payloadDir 'frame.cs'), $programFrame, [System.Text.UTF8Encoding]::new($false))
		Copy-Item -LiteralPath (Join-Path $TempDir 'main.ps1') -Destination (Join-Path $payloadDir 'main.ps1') -Force

		$payloadCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
	<PropertyGroup>
		<OutputType>Exe</OutputType>
		<TargetFramework>$tfm</TargetFramework>
		<RuntimeIdentifier>$rid</RuntimeIdentifier>
		<SelfContained>false</SelfContained>
		<UseAppHost>false</UseAppHost>
		<NoWarn>`$(NoWarn);CA1416;IL3000;CS8073</NoWarn>
		<EnableDefaultCompileItems>false</EnableDefaultCompileItems>
		<AssemblyName>$assemblyName</AssemblyName>
		<Nullable>disable</Nullable>
		<ImplicitUsings>disable</ImplicitUsings>
		<DebugType>none</DebugType>
		<GenerateDocumentationFile>false</GenerateDocumentationFile>
		<SatelliteResourceLanguages>en</SatelliteResourceLanguages>
		<AllowUnsafeBlocks>true</AllowUnsafeBlocks>
		<EnableWindowsTargeting>true</EnableWindowsTargeting>
		<DefineConstants>$([System.Security.SecurityElement]::Escape($payloadDefineConstants))</DefineConstants>
		$winForms
	</PropertyGroup>
	<ItemGroup>
		<Compile Include="frame.cs" />
		<EmbeddedResource Include="main.ps1" LogicalName="main.ps1" />
		<Reference Include="System.Management.Automation">
			<HintPath>$([System.Security.SecurityElement]::Escape($smaPath))</HintPath>
			<Private>false</Private>
		</Reference>
	</ItemGroup>
</Project>
"@
		[System.IO.File]::WriteAllText((Join-Path $payloadDir 'payload.csproj'), $payloadCsproj, [System.Text.UTF8Encoding]::new($false))

		$payloadOut = Join-Path $projectDir 'payloadout'
		Write-Debug "Core compiler: dotnet build payload (tfm=$tfm, rid=$rid)"
		Remove-Item -LiteralPath $payloadOut -Recurse -Force -ErrorAction Ignore
		$buildOutput = Invoke-CoreDotnet -DotnetArgs @('build', (Join-Path $payloadDir 'payload.csproj'), '-c', 'Release', '-o', $payloadOut) -AssetsPath (Join-Path $payloadDir 'obj/project.assets.json') -DotnetPath $dotnet.Source
		$payloadDll = Join-Path $payloadOut "$assemblyName.dll"
		if (-not (Test-Path -LiteralPath $payloadDll)) {
			throw "ps12exe: core payload not built: $payloadDll`n$($buildOutput -join "`n")"
		}

		# 负载整体 Brotli 压缩成 launcher 的 "main" 资源（Core 的 launcher 走 pack.cs 的 Brotli 分支）。
		$mainPath = Join-Path $projectDir 'main'
		$inStream = [System.IO.File]::OpenRead($payloadDll)
		$outStream = [System.IO.File]::Create($mainPath)
		$brotli = [System.IO.Compression.BrotliStream]::new($outStream, [System.IO.Compression.CompressionLevel]::SmallestSize, $true)
		try {
			$inStream.CopyTo($brotli)
		}
		finally {
			$brotli.Dispose(); $outStream.Dispose(); $inStream.Dispose()
		}

		# CoreHost.cs 是 launcher 侧引导：探测 $PSHOME、接 PSModulePath、挂 AssemblyResolve。和 pack.cs 一样，编译进 ps12exe.exe 时内嵌，脚本模式从磁盘读取。
		#_if PSEXE
			#_include_as_value bootstrapSource "$PSScriptRoot/programFrames/CoreHost.cs"
		#_else
			[string]$bootstrapSource = Get-Content $PSScriptRoot/programFrames/CoreHost.cs -Raw -Encoding UTF8
		#_endif
		[System.IO.File]::WriteAllText((Join-Path $projectDir 'CoreHost.cs'), $bootstrapSource, [System.Text.UTF8Encoding]::new($false))

		# 复用 WinPS pack 用的 pack.cs；CoreHost 定义让它走 Brotli 分支。
		#_if PSEXE
			#_include_as_value launcherSource "$PSScriptRoot/programFrames/pack.cs"
		#_else
			[string]$launcherSource = Get-Content $PSScriptRoot/programFrames/pack.cs -Raw -Encoding UTF8
		#_endif
		$threadingAttr = if ($threadingModel -eq 'MTA') { '[System.MTAThread]' } else { '[System.STAThread]' }
		$launcherSource = $launcherSource.Replace('[System.STAThread]', $threadingAttr)
		[System.IO.File]::WriteAllText((Join-Path $projectDir 'launcher.cs'), $launcherSource, [System.Text.UTF8Encoding]::new($false))

		# launcher 需要 noConsole，CoreHost 才能用 MessageBox 报错而不是写不存在的控制台；conHost 让 pack.cs 走 conhost 重启。
		$launcherDefineConstants = 'CoreHost'
		if ($noConsole) { $launcherDefineConstants += ';noConsole' }
		if ($conHost) { $launcherDefineConstants += ';conHost' }
		$refContentItem = if ($needsRefAssemblies) {
			$refDir = [System.Security.SecurityElement]::Escape((Join-Path $PSHOME 'ref'))
			@"
		<Content Include="$refDir\*.dll">
			<Link>ref\%(Filename)%(Extension)</Link>
			<CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
		</Content>
"@
		}
		else { '' }
		$launcherCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
	<PropertyGroup>
$($publishedProps.Replace('__DefineConstants__', $launcherDefineConstants))
	</PropertyGroup>
	<ItemGroup>
		<Compile Include="launcher.cs" />
		<Compile Include="CoreHost.cs" />
		<EmbeddedResource Include="main" LogicalName="main" />
$refContentItem
	</ItemGroup>
</Project>
"@
		[System.IO.File]::WriteAllText((Join-Path $projectDir 'launcher.csproj'), $launcherCsproj, [System.Text.UTF8Encoding]::new($false))

		Write-I18n Host CoreCompilePublishing
		Write-Debug "Core compiler: dotnet publish launcher (tfm=$tfm, rid=$rid)"
		Remove-Item -LiteralPath $publishDir -Recurse -Force -ErrorAction Ignore
		$null = Invoke-CoreDotnet -DotnetArgs @('publish', (Join-Path $projectDir 'launcher.csproj'), '-c', 'Release', '-o', $publishDir) -AssetsPath (Join-Path $projectDir 'obj/project.assets.json') -DotnetPath $dotnet.Source
	}

	Copy-CorePublishOutput -PublishDir $publishDir -AssemblyName $assemblyName -OutputFile $outputFile -SingleFile $singleFile -PrepareDebug $prepareDebug
}
finally {
	Exit-CoreProject $coreProject
}
