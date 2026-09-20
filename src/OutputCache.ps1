# 产物结果缓存（%TEMP%\ps12exe\cache\output）。
# 非常量 Framework 编译的内容寻址缓存：键由「最终脚本文本 + 序列化后的具名参数 + 编译器源码指纹」决定，
# 命中即直接拷贝产物、跳过 CodeDom/AsmResolver 等全部编译开销。产物内部程序集名固定为 output，运行时
# 行为只依赖 exe 路径/文件名（见 default.cs），因此键里不含输出名，同一份产物可跨输出名复用。
# 命中只读不写，新条目只来自真正编译，所以清理放在写入处即可覆盖增长来源。

# 缓存开关：Core 交给独立编译器；图标会下载/抽取/转换；写 config、KeepSource、代码签名、DllExports
# 都让产物或流程偏离这份缓存所能描述的输入。开关读取调用方（ps12exe 编译流程）的脚本级变量。
function Test-OutputCacheEnabled {
	return -not ($isCoreTarget -or $iconFile -or $configFile -or $prepareDebug -or $CodeSigning -or $DllExportList)
}

# 计算缓存键；缓存不可用（拿不到编译器源文件）返回 $null。
function Get-OutputCacheKey([string]$RepoRoot, [System.Collections.IDictionary]$BoundParams) {
	# 编译器源码指纹：ps12exe.ps1 + src 顶层脚本 + 程序帧 + 运行时芯任一变化即失效
	# （自编译产物拿不到源文件则返回 $null，直接禁用缓存）。
	$compilerFp = Get-CompilerSourceFingerprint $RepoRoot
	if (-not $compilerFp) { return $null }
	# 参数序列化：$BoundParams 是 ps12exe 收到的具名参数，已被预处理/pragma 改写，直接序列化它就覆盖了
	# 全部有效选项，不必逐项列内部规范变量。递归按键排序，保证同一组参数得到稳定字符串。
	function ConvertTo-CanonicalParam([object]$value) {
		if ($null -eq $value) { return '' }
		if ($value -is [System.Collections.IDictionary]) {
			$keys = @($value.Keys | ForEach-Object { "$_" } | Sort-Object)
			return '{' + (($keys | ForEach-Object { $_ + '=' + (ConvertTo-CanonicalParam $value[$_]) }) -join ';') + '}'
		}
		if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
			return '[' + (($value | ForEach-Object { ConvertTo-CanonicalParam $_ }) -join ',') + ']'
		}
		return "$value"
	}
	$paramParts = @($BoundParams.Keys | Where-Object { $_ -ne 'inputFile' -and $_ -ne 'outputFile' } | Sort-Object | ForEach-Object {
		$_ + '=' + (ConvertTo-CanonicalParam $BoundParams[$_])
	})
	return (Get-TextHash (@(
				"content=$(Get-TextHash $Content)"
				"params=$($paramParts -join ';')"
				"compiler=$compilerFp"
			) -join "`n"))
}

# 查缓存：命中则把产物写入 $OutputFile 并返回 $true，未命中返回 $false。
function Test-OutputCacheHit([string]$OutputFile, [string]$Key) {
	$cachedExe = Join-Path (Get-CacheRoot 'output') "$Key.exe"
	if (-not (Test-Path -LiteralPath $cachedExe)) { return $false }
	try {
		$cachedBytes = Get-CachedBytes $cachedExe
		[System.IO.File]::WriteAllBytes($OutputFile, $cachedBytes)
		Write-I18n Host CompiledFileSize $cachedBytes.Length
		Write-I18n Verbose OutputPath $OutputFile
		return $true
	}
	catch {
		Write-Debug "ps12exe output cache hit failed, recompiling: $_"
		Remove-Item -LiteralPath $OutputFile -Force -ErrorAction Ignore
		return $false
	}
}

# 编译成功且最终产物已落盘（含 ExeSinker/签名）后回填产物，并顺带清理长期未用的条目。
function Save-OutputCache([string]$Key, [string]$OutputFile) {
	if (-not $Key) { return }
	$dir = Get-CacheRoot 'output'
	try { Set-CachedBytes (Join-Path $dir "$Key.exe") ([System.IO.File]::ReadAllBytes($OutputFile)) }
	catch { Write-Debug "ps12exe output cache store failed: $_" }
	Clear-StaleCache $dir
}
