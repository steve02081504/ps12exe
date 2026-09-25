# LZMA1 打包支持。打包负载默认走 gzip（Framework）/ Brotli（Core），但这两者的窗口/建模对大脚本的长距重复不够好；
# 这里把 7-Zip LZMA SDK 的 C# 源码（public domain，见 programFrames/LzmaDecode.cs 与 LzmaEncode.cs）在打包时按需
# 编进宿主进程并缓存 DLL，供 Compress-Lzma 使用。解码器则随产物 launcher 一起编译（pack.cs 的 CodecLzma 分支）。
# 是否启用交给调用方按「压完产物是否更小」决定，见 CodeDomCompiler.ps1 / CoreCompiler.ps1。
#
# 注意编码侧类型名是 LzmaPackCodec（而非解码侧的 LzmaCodec）：ps12exe 自身被编成 exe 且该 exe 的 launcher 走 LZMA 时，
# 产物里会带一个只有解码器的 LzmaCodec；按名字找编码器若用 LzmaCodec 会误命中它。
# 低于该字节数的负载，LZMA 相对 gzip/Brotli 省下的必然不及解码器的固定开销，直接跳过以免白算。
$LzmaPackMinBytes = 32768
$script:LzmaPackCodecType = $null

#_if PSEXE
	#_include_as_value lzmaDecodeSource "$PSScriptRoot/programFrames/LzmaDecode.cs"
	#_include_as_value lzmaEncodeSource "$PSScriptRoot/programFrames/LzmaEncode.cs"
#_else
	[string]$lzmaDecodeSource = Get-Content -LiteralPath "$PSScriptRoot/programFrames/LzmaDecode.cs" -Raw -Encoding UTF8
	[string]$lzmaEncodeSource = Get-Content -LiteralPath "$PSScriptRoot/programFrames/LzmaEncode.cs" -Raw -Encoding UTF8
#_endif

# 在已加载程序集里按名字找类型并转成 [type]。编译成 exe 的宿主（PSEXE）下 `'X' -as [type]` 不一定能解析动态加载的
# 程序集，用反射更稳；返回的是 Type 对象而非类型字面量，调用方走反射。
function Find-LoadedType([string]$Name) {
	foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
		try {
			$type = $assembly.GetType($Name, $false, $false)
			if ($type) { return $type }
		}
		catch {}
	}
	return $null
}

# 取得（必要时编译并缓存）包含 LzmaPackCodec 的宿主程序集 Type。按宿主 PSEdition/版本与源码内容分键，跨进程复用。
# 失败（例如宿主缺少 csc/Roslyn）返回 $null，Compress-Lzma 据此回退到 gzip/Brotli。
function Get-LzmaPackCodecType {
	if ($script:LzmaPackCodecType) { return $script:LzmaPackCodecType }
	$loaded = Find-LoadedType 'LzmaPackCodec'
	if ($loaded) { $script:LzmaPackCodecType = $loaded; return $loaded }
	$cacheRoot = Get-CacheRoot 'lzma'
	Clear-StaleCache $cacheRoot
	$key = Get-TextHash ("$($PSVersionTable.PSEdition)|$($PSVersionTable.PSVersion)|$lzmaDecodeSource|$lzmaEncodeSource")
	$decPath = Join-Path $cacheRoot "LzmaDecode_$key.cs"
	$encPath = Join-Path $cacheRoot "LzmaEncode_$key.cs"
	$dllPath = Join-Path $cacheRoot "lzma_$key.dll"
	$mutex = [System.Threading.Mutex]::new($false, "ps12exe-lzma-$key")
	$locked = $false
	try {
		try { $locked = $mutex.WaitOne(120000) } catch { $locked = $false }
		if (Test-Path -LiteralPath $dllPath) {
			[void][System.Reflection.Assembly]::LoadFrom($dllPath)
		}
		else {
			[System.IO.File]::WriteAllText($decPath, $lzmaDecodeSource, [System.Text.UTF8Encoding]::new($true))
			[System.IO.File]::WriteAllText($encPath, $lzmaEncodeSource, [System.Text.UTF8Encoding]::new($true))
			Add-Type -Path @($decPath, $encPath) -OutputAssembly $dllPath -OutputType Library
			[void][System.Reflection.Assembly]::LoadFrom($dllPath)
		}
	}
	finally {
		if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
		$mutex.Dispose()
	}
	$script:LzmaPackCodecType = Find-LoadedType 'LzmaPackCodec'
	return $script:LzmaPackCodecType
}

# 用 LZMA 压缩字节；任何环节失败都返回 $null，让调用方回退到默认压缩。
function Compress-Lzma([byte[]]$Data) {
	try {
		$codec = Get-LzmaPackCodecType
		if (-not $codec) { return $null }
		return , ($codec.GetMethod('Compress').Invoke($null, @(, $Data)))
	}
	catch {
		Write-Debug "LZMA 打包不可用，回退默认压缩：$_"
		return $null
	}
}
