$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
$type = $type.MakeGenericType(@([String], [String]) )
$o = [Activator]::CreateInstance($type)
if ($isPwsh20Sma) {
	$o.Add("CompilerVersion", "v3.5")
}
else { $o.Add("CompilerVersion", "v4.0") }

$cop = (New-Object Microsoft.CSharp.CSharpCodeProvider($o))
[string[]]$BaseCompilerOptions = @($CompilerOptions)

$manifestParam = if ($DllExportList) {
	# 原生导出产物是 DLL，没有入口点，也不需要管理员/DPI 清单。
	"/nowin32manifest"
}
elseif (($AstAnalyzeResult.IsConst -or $virtualize) -and -not $requireAdmin) {
	"/nowin32manifest"
}
elseif ($requireAdmin -or $DPIAware -or $supportOS -or $longPaths) {
	"`"/win32manifest:$($outputFile+".win32manifest")`""
	@"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
$(if ($DPIAware -or $longPaths) {@"
	<application xmlns="urn:schemas-microsoft-com:asm.v3">
		<windowsSettings>
	$(if ($DPIAware) {@"
			<dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true</dpiAware>
			<dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
"@})$(if ($longPaths) {@"
			<longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>
"@})
		</windowsSettings>
	</application>
"@})$(if ($requireAdmin) {@"
	<trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
		<security>
			<requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
				<requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
			</requestedPrivileges>
		</security>
	</trustInfo>
"@})$(if ($supportOS) {@"
	<compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
		<application>
			<supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
			<supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
			<supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
			<supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
			<supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/>
		</application>
	</compatibility>
"@})
</assembly>
"@ | Set-Content ($outputFile + ".win32manifest") -Encoding UTF8
}

[string[]]$CompilerOptions = $BaseCompilerOptions

if ($virtualize) {
	Write-I18n Host ForceX86byVirtualization
	$architecture = "x86"
}
$CompilerOptions += "/platform:$architecture"
if ($DllExportList) {
	$CompilerOptions += "/target:library"
}
else {
	$CompilerOptions += "/target:$( if ($noConsole){'winexe'}else{'exe'})"
}
$CompilerOptions += $manifestParam

$configFileForEXE3 = @"
<?xml version="1.0" encoding="utf-8" ?>
<configuration>
	<startup>
		$(if ($winFormsDPIAware) {'<supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.7"/>'}
		else {'<supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0"/>'})
	</startup>
$(if ($longPaths) {@'
	<runtime>
		<AppContextSwitchOverrides value="Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false"/>
	</runtime>
'@})$(
	if ($winFormsDPIAware) {@'
	<System.Windows.Forms.ApplicationConfigurationSection>
		<add key="DpiAwareness" value="PerMonitorV2"/>
	</System.Windows.Forms.ApplicationConfigurationSection>
'@})
</configuration>
"@

if ($iconFile) {
	$CompilerOptions += "`"/win32icon:$iconFile`""
}

$CompilerOptions += "/define:$($Constants -join ';')"

function New-CompilerParameters([string]$outFile, [string[]]$opts, [bool]$debug, [bool]$executable = $TRUE) {
	$p = New-Object System.CodeDom.Compiler.CompilerParameters($referenceAssembies, $outFile)
	$p.GenerateInMemory = $FALSE
	$p.GenerateExecutable = $executable
	$p.IncludeDebugInformation = $debug
	$p.CompilerOptions = ($opts -ne '') -join ' '
	$p.TempFiles = New-Object System.CodeDom.Compiler.TempFileCollection($TempDir)
	if ($debug) { $p.TempFiles.KeepFiles = $TRUE }
	Write-Debug "Using Compiler Options: $($p.CompilerOptions)"
	return $p
}

# ---------- 程序帧模板缓存 ----------
# 打包路径要把「帧 + 脚本」编成 payload、再把 gzip(payload) 塞进 launcher，每次跑两次 csc；但帧的 IL
# 只由「帧源码 + 编译选项 + 引用 + 编译器版本」决定，脚本 / gz 都只是内嵌资源。于是把帧预编成模板缓存：
# 模板里嵌一个 bucket 大小的占位资源，每次编译用 Set-FrameResource 原地覆写 [Int32 长度][数据] 并
# 更新 CLI 资源目录大小（不重排 PE），随后照旧走 ExeSinker——产物大小与不缓存时一致。模板键哈希帧源码、
# 选项、引用、资源/版本源与占位桶等全部编译输入，所以任何输入变化都会自动生成新模板。
# 公共缓存/PE 逻辑在 src/Cache.ps1，缓存目录 %TEMP%\ps12exe\cache\codedom。
$script:CacheRoot = Get-CacheRoot 'codedom'
Clear-StaleCache $script:CacheRoot
# 取帧模板字节；缺失则在命名互斥量保护下用 csc 编一次并缓存。模板只含占位资源，生成后不再改动。
# AssemblyName 决定 csc 的 assembly name（payload 与 launcher 都用固定名，不随输出名变化，以便跨输出名复用模板）。
function Get-FrameTemplate([string]$Key, [int]$Bucket, [string[]]$Options, [string[]]$Source, [string]$ResourceName, [string]$AssemblyName) {
	$cachePath = Join-Path $script:CacheRoot "frame_$Key.exe"
	$bytes = Get-CachedBytes $cachePath
	if ($bytes) { return , $bytes }
	$mutex = [System.Threading.Mutex]::new($false, "ps12exe-frame-$Key")
	$locked = $mutex.WaitOne(120000)
	try {
		if (-not $locked) { return $null }
		$bytes = Get-CachedBytes $cachePath
		if ($bytes) { return , $bytes }
		$buildDir = Join-Path $script:CacheRoot ("build_" + [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
		try {
			$phPath = Join-Path $buildDir $ResourceName
			[System.IO.File]::WriteAllBytes($phPath, [byte[]]::new($Bucket))
			$templateOut = Join-Path $buildDir $AssemblyName
			$p = New-CompilerParameters $templateOut $Options $FALSE
			[VOID]$p.EmbeddedResources.Add($phPath)
			$r = $cop.CompileAssemblyFromSource($p, $Source)
			if ($r.Errors.Count -gt 0) { throw ($r.Errors -join "`n") }
			$bytes = [System.IO.File]::ReadAllBytes($templateOut)
			Set-CachedBytes $cachePath $bytes
			return , $bytes
		}
		finally {
			Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction Ignore
		}
	}
	finally {
		if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
		$mutex.Dispose()
	}
}

# 默认路径：先编出普通托管程序集作为负载，gzip 后塞进一个极小的 launcher 里。launcher 启动时在内存中解压并用 Assembly.Load 载入负载，因此负载不会落到磁盘。仅当无法打包时才退化为普通编译（Build.KeepSource 需要负载源码/PDB、Build.DllExports、真实 PS2 SMA）。常量脚本的 constexpr.cs 入口是无参 Main()，与 pack launcher 的 Main(string[]) 调用约定不符，故不走 pack。
$packEnabled = (
	-not $prepareDebug -and
	-not $isPwsh20Sma -and
	-not $DllExportList -and
	-not $AstAnalyzeResult.IsConst -and
	$TempDir
)

# 帧里的资源/版本属性片段占位标记：payload 编译替换为空，launcher/直编替换为 $resourceAttributes（见 BuildFrame.ps1）。
$assemblyAttributesMarker = '/*__ASSEMBLY_ATTRIBUTES__*/'

# 原生 DLL 导出：default.cs 与 DllExport.cs 是同一个 PSRunnerEntry partial 类，按导出声明生成包装方法后一起编译。
$dllExportMethods = $null
$dllExportFrame = $null
if ($DllExportList) {
	Write-I18n Host DllExportCompiling
	$dllExportMethods = New-DllExportMethods $DllExportList
	$dllExportFrame = (Get-Content "$PSScriptRoot/programFrames/DllExport.cs" -Raw -Encoding UTF8).Replace('/*__PS12EXE_DLL_EXPORTS__*/', $dllExportMethods.Code)
}

if ($packEnabled) {
	$payloadSource = $programFrame.Replace($assemblyAttributesMarker, '')
	$payloadOptions = @($BaseCompilerOptions) + @(
		"/platform:$architecture",
		"/target:exe",
		"/nowin32manifest",
		"/define:$($Constants -join ';')"
	)
	$exeSinker = Join-Path $PSScriptRoot 'ExeSinker.ps1'
	[byte[]]$scriptBytes = [System.IO.File]::ReadAllBytes("$TempDir\main.ps1")
	$payloadPath = Join-Path $TempDir 'payload.exe'

	# payload：优先用帧模板补丁（模板不随脚本内容失效），不可用时直编。
	[byte[]]$payloadBytes = $null
	$versionKey = if ($isPwsh20Sma) { 'v3.5' } else { 'v4.0' }
	$payloadBucket = Get-CacheBucket $scriptBytes.Length
	if ($payloadBucket) {
		$payloadKey = Get-TextHash (@(
				$payloadSource, ($payloadOptions -join "`n"),
				(($referenceAssembies | Where-Object { $_ }) -join ';'), "c=$versionKey", "b=$payloadBucket"
			) -join "`n")
		try {
			$template = Get-FrameTemplate $payloadKey $payloadBucket $payloadOptions $payloadSource 'main.ps1' "payload.exe"
			$template = Set-FrameResource $template $scriptBytes
			[System.IO.File]::WriteAllBytes($payloadPath, $template)
			$payloadBytes = $template
		}
		catch { Write-Debug "CodeDom compiler: payload frame template failed: $_" }
	}
	if (-not $payloadBytes) {
		Write-Debug 'CodeDom compiler: payload frame template miss, compiling'
		$pcp = New-CompilerParameters $payloadPath $payloadOptions $FALSE
		[VOID]$pcp.EmbeddedResources.Add("$TempDir\main.ps1")
		$pcr = $cop.CompileAssemblyFromSource($pcp, $payloadSource)
		if ($pcr.Errors.Count -gt 0) {
			throw $pcr.Errors -join "`n"
		}
	}

	# csc 默认会塞进 manifest/版本信息资源；负载用不到这些，先剥掉再压缩省一点。
	if (Test-Path $exeSinker) {
		& $exeSinker $payloadPath -removeResources
	}
	$payloadBytes = [System.IO.File]::ReadAllBytes($payloadPath)

	# 负载压缩：默认 gzip；大负载（默认压缩对大文本的长距重复抓不住）再试 LZMA。是否采用不靠估算，
	# 而是把两种流的 launcher 都生成出来、比实际产物大小取小者（LZMA 自带解码器，固定更重，小脚本必然不划算）。
	$gzMs = New-Object System.IO.MemoryStream
	$gzip = New-Object System.IO.Compression.GZipStream($gzMs, [System.IO.Compression.CompressionMode]::Compress, $true)
	try { $gzip.Write($payloadBytes, 0, $payloadBytes.Length) }
	finally { $gzip.Dispose() }
	[byte[]]$gzBytes = $gzMs.ToArray()
	$gzMs.Dispose()
	[byte[]]$lzmaBytes = if ($payloadBytes.Length -ge $LzmaPackMinBytes) { Compress-Lzma $payloadBytes } else { $null }

	# 和 default.cs 一样：编译进 ps12exe.exe 时内嵌 pack.cs，脚本模式从磁盘读取。
	#_if PSEXE
		#_include_as_value launcherSource "$PSScriptRoot/programFrames/pack.cs"
	#_else
		[string]$launcherSource = Get-Content $PSScriptRoot/programFrames/pack.cs -Raw -Encoding UTF8
	#_endif
	# pack.cs 保持纯 C#；把帧里的标记替换为资源/版本属性片段，由 launcher 携带这些元数据。
	$launcherSource = $launcherSource.Replace($assemblyAttributesMarker, $resourceAttributes)
	[string[]]$LauncherCompilerOptions = $CompilerOptions
	# conHost 要求 launcher 以 winexe 启动（无控制台），再经 conhost.exe 重启，避免挂到 Windows Terminal。
	if ($conHost) {
		$LauncherCompilerOptions = $LauncherCompilerOptions -replace '/target:exe', '/target:winexe'
	}
	if (-not $manifestParam) {
		# 没有自定义清单需求时，launcher 也不需要默认清单。
		$LauncherCompilerOptions += "/nowin32manifest"
	}
	# 生成指定编码的 launcher 镜像：优先用帧模板原地补丁（模板不随脚本内容失效；清单/图标走内容哈希入键），
	# 模板不可用时退回直编。Gzip 走 pack.cs 原分支；Lzma 额外拼入解码器源码并定义 CodecLzma。
	function Get-LauncherImage([string]$Codec, [byte[]]$Resource) {
		[string[]]$sources = @($launcherSource)
		[string[]]$options = $LauncherCompilerOptions
		if ($Codec -eq 'Lzma') {
			$sources = @($launcherSource, $lzmaDecodeSource)
			$options = $LauncherCompilerOptions + '/define:CodecLzma'
		}
		$bucket = Get-CacheBucket $Resource.Length
		if ($bucket) {
			$iconHash = if ($iconFile -and (Test-Path -LiteralPath $iconFile)) { Get-Sha256Hex ([System.IO.File]::ReadAllBytes($iconFile)) } else { '' }
			$manifestPath = $outputFile + '.win32manifest'
			$manifestHash = if ($manifestParam -and (Test-Path -LiteralPath $manifestPath)) { Get-Sha256Hex ([System.IO.File]::ReadAllBytes($manifestPath)) } else { '' }
			# 清单/图标路径随 outputFile 变化但不影响编译结果：键里抹掉路径、改用内容哈希。
			$optionsForKey = ($options | ForEach-Object {
				($_ -replace '(?i)(?<=/win32manifest:)[^"]*', '<m>') -replace '(?i)(?<=/win32icon:)[^"]*', '<i>'
			}) -join "`n"
			# 内部程序集名固定为 output，不随输出名变化：控制台下 $PSCommandPath 取自 exe 路径；
			# 窗口化标题在运行期回退到 exe 文件名（见 default.cs），因此产物可跨输出名复用同一模板。
			$key = Get-TextHash (@(
					($sources -join "`n"), $optionsForKey,
					(($referenceAssembies | Where-Object { $_ }) -join ';'),
					"m=$manifestHash", "i=$iconHash", "b=$bucket"
				) -join "`n")
			try {
				$template = Get-FrameTemplate $key $bucket $options $sources 'main' "output.exe"
				return , (Set-FrameResource $template $Resource)
			}
			catch { Write-Debug "CodeDom compiler: $Codec launcher frame template failed: $_" }
		}
		Write-Debug "CodeDom compiler: $Codec launcher frame template miss, compiling"
		$variantDir = Join-Path $TempDir "launcher_$Codec"
		New-Item -ItemType Directory -Path $variantDir -Force | Out-Null
		$out = Join-Path $variantDir ([System.IO.Path]::GetFileName($outputFile))
		$resPath = Join-Path $variantDir 'main'
		[System.IO.File]::WriteAllBytes($resPath, $Resource)
		$lcp = New-CompilerParameters $out $options $FALSE
		[VOID]$lcp.EmbeddedResources.Add($resPath)
		$cr = $cop.CompileAssemblyFromSource($lcp, $sources)
		if ($cr.Errors.Count -gt 0) { throw $cr.Errors -join "`n" }
		return , [System.IO.File]::ReadAllBytes($out)
	}
	[byte[]]$launcherImage = Get-LauncherImage 'Gzip' $gzBytes
	if ($lzmaBytes) {
		[byte[]]$lzmaImage = Get-LauncherImage 'Lzma' $lzmaBytes
		if ($lzmaImage.Length -lt $launcherImage.Length) {
			Write-Debug "CodeDom compiler: LZMA launcher wins ($($lzmaImage.Length) < $($launcherImage.Length))"
			$launcherImage = $lzmaImage
		}
	}
	[System.IO.File]::WriteAllBytes($outputFile, $launcherImage)
}
else {
	$cp = New-CompilerParameters $outputFile $CompilerOptions $prepareDebug (-not $DllExportList)
	if (!$AstAnalyzeResult.IsConst) {
		[VOID]$cp.EmbeddedResources.Add("$TempDir\main.ps1")
	}
	$frameSource = $programFrame.Replace($assemblyAttributesMarker, $resourceAttributes)
	[string[]]$sources = if ($DllExportList) { @($frameSource, $dllExportFrame) } else { @($frameSource) }
	$cr = $cop.CompileAssemblyFromSource($cp, $sources)
	if ($cr.Errors.Count -gt 0) {
		throw $cr.Errors -join "`n"
	}
	if ($DllExportList) {
		Add-DllExportsToAssembly -AssemblyPath $outputFile -Exports $dllExportMethods.Map -Architecture $architecture
	}
}

if (
	#_if PSEXE
		#_!! $AstAnalyzeResult.IsConst -or
	#_endif
	$requireAdmin -or $DPIAware -or $supportOS -or $longPaths
) {
	if (Test-Path $($outputFile + ".win32manifest")) {
		Remove-Item $($outputFile + ".win32manifest") -Verbose:$FALSE
	}
}
