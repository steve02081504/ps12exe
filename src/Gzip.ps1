# 固定版本的内置纯 C# 7-Zip Deflate 编码器，仅编译期使用；不依赖原生程序或宿主压缩实现。
$script:GzipPackCodecType = $null
#_if PSEXE
	#_include_as_value gzipEncoderSource "$PSScriptRoot/programFrames/GzipEncode.cs"
	#_include_as_value gzipWrapperSource "$PSScriptRoot/programFrames/GzipWrapper.cs"
#_else
	[string]$gzipEncoderSource = Get-Content -LiteralPath "$PSScriptRoot/programFrames/GzipEncode.cs" -Raw -Encoding UTF8
	[string]$gzipWrapperSource = Get-Content -LiteralPath "$PSScriptRoot/programFrames/GzipWrapper.cs" -Raw -Encoding UTF8
#_endif

$gzipCodecKey = Get-TextHash ("$gzipEncoderSource|$gzipWrapperSource")

function Get-GzipPackCodecType {
	if ($script:GzipPackCodecType) { return $script:GzipPackCodecType }
	$key = $gzipCodecKey
	$typeName = "GzipPackCodec_$key"
	$loaded = Find-LoadedType $typeName
	if ($loaded) { $script:GzipPackCodecType = $loaded; return $loaded }
	[string]$cacheRoot = Get-CacheRoot 'gzip'
	Clear-StaleCache $cacheRoot
	# 编码流只由源码决定，DLL 缓存还区分宿主运行时。
	$runtimeKey = Get-TextHash ("$($PSVersionTable.PSEdition)|$($PSVersionTable.PSVersion)|$key")
	$encoderPath = Join-Path $cacheRoot "GzipEncode_$runtimeKey.cs"
	$wrapperPath = Join-Path $cacheRoot "GzipWrapper_$runtimeKey.cs"
	$dllPath = Join-Path $cacheRoot "gzip_$runtimeKey.dll"
	$mutex = [System.Threading.Mutex]::new($false, "ps12exe-gzip-$runtimeKey")
	$locked = $false
	try {
		try { $locked = $mutex.WaitOne(120000) } catch [System.Threading.AbandonedMutexException] { $locked = $true }
		if (-not $locked) { throw 'Timed out waiting for the bundled gzip encoder cache' }
		if (-not (Test-Path -LiteralPath $dllPath)) {
			[IO.File]::WriteAllText($encoderPath, $gzipEncoderSource, [Text.UTF8Encoding]::new($true))

			[IO.File]::WriteAllText($wrapperPath, ($gzipWrapperSource.Replace('GzipPackCodec', $typeName)), [Text.UTF8Encoding]::new($true))
			# 不回退到机器相关的编码器；加载失败必须显式失败。
			try { Add-Type -Path @($encoderPath, $wrapperPath) -OutputAssembly $dllPath -OutputType Library -ErrorAction Stop }
			catch { Remove-Item -LiteralPath $dllPath -Force -ErrorAction Ignore; throw }
		}
		[void][Reflection.Assembly]::LoadFrom($dllPath)
		$script:GzipPackCodecType = Find-LoadedType $typeName
		if (-not $script:GzipPackCodecType) { throw 'Bundled gzip encoder type was not loaded' }
		return $script:GzipPackCodecType
	}
	finally {
		if ($locked) { $mutex.ReleaseMutex() }
		$mutex.Dispose()
	}
}

function Compress-Gzip([byte[]]$Data) {
	$codec = Get-GzipPackCodecType
	return , ($codec.GetMethod('Compress').Invoke($null, @(, $Data)))
}
