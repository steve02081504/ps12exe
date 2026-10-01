# ps12exe 的临时缓存公共逻辑。统一根为 %TEMP%\ps12exe\：更新检查的 txt 直接放根下，各后端的编译缓存放
# cache\<name>\（如 cache\codedom、cache\core）。这里只放与后端无关的东西：缓存根定位、内容哈希、
# 定长占位桶、原子读写，以及托管 PE 内嵌资源的定位与原地补丁。

# 临时根（不创建目录）。
function Get-TempRoot {
	return (Join-Path ([System.IO.Path]::GetTempPath()) 'ps12exe')
}

# 指定后端（codedom/core）的缓存目录，确保存在后返回。
function Get-CacheRoot([string]$Name) {
	$root = Join-Path (Join-Path (Get-TempRoot) 'cache') $Name
	New-Item -ItemType Directory -Force -Path $root | Out-Null
	return $root
}

# 删除长期未用的缓存项（活跃文件刚被 touch，不会命中）。
function Clear-StaleCache([string]$Root, [int]$Days = 14) {
	$cutoff = [DateTime]::UtcNow.AddDays(-$Days)
	Get-ChildItem -LiteralPath $Root -Force -ErrorAction Ignore |
		Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
		ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Ignore }
}

function Get-Sha256Hex([byte[]]$Bytes) {
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try { return [System.BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '') }
	finally { $sha.Dispose() }
}
function Get-TextHash([string]$Text) {
	Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($Text))
}
# 找 >= Needed 的定长占位桶（64B 粒度）。占位桶决定帧模板里托管资源槽的大小，进而决定产物大小：
# 粒度太粗会让「实际资源远小于槽」的产物白白多出最多一个粒度的填充。64B 粒度把额外体积压到 <64B，
# 同时模板按内容寻址、不同大小各存一份，条目数上界仍是不同脚本大小的数量级。
# 超过 64MB 返回 0，表示放弃缓存走直编。
function Get-CacheBucket([long]$Needed) {
	if ($Needed -gt 67108864) { return 0 }
	[long]$b = [math]::Ceiling($Needed / 64.0) * 64
	if ($b -lt 64) { $b = 64 }
	return [int]$b
}
# 编译管线源码指纹，作为产物结果缓存的失效键：入口 ps12exe.ps1 + src 顶层脚本 + 程序帧 + 运行时芯，
# 任一内容变化即失效（用 src/*.ps1 通配而非逐文件清单，新增顶层脚本自动纳入）。
# 目录缺失（例如被 ps12exe 自编译成 exe、运行时没有源文件）时返回 $null，调用方据此禁用缓存。
$script:CompilerSourceFingerprint = $null
$script:CompilerSourceFingerprintRepo = $null
function Get-CompilerSourceFingerprint([string]$RepoRoot) {
	if ($script:CompilerSourceFingerprint -and $script:CompilerSourceFingerprintRepo -eq $RepoRoot) {
		return $script:CompilerSourceFingerprint
	}
	$entry = Join-Path $RepoRoot 'ps12exe.ps1'
	if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { return $null }
	$files = [System.Collections.Generic.List[string]]::new()
	$files.Add($entry)
	foreach ($pattern in @('src/*.ps1', 'src/programFrames/*.cs', 'src/RuntimePwsh2.0/*.ps1')) {
		$dir = Join-Path $RepoRoot (Split-Path -Path $pattern -Parent)
		if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
		Get-ChildItem -LiteralPath $dir -File -Filter (Split-Path -Path $pattern -Leaf) -ErrorAction Ignore |
			ForEach-Object { $files.Add($_.FullName) }
	}
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$sb = [System.Text.StringBuilder]::new()
		foreach ($f in @($files | Sort-Object)) {
			$rel = $f.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
			$h = [System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($f))).Replace('-', '')
			[void]$sb.Append($rel).Append(':').Append($h).Append("`n")
		}
		$fp = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))).Replace('-', '').Substring(0, 32)
		$script:CompilerSourceFingerprint = $fp
		$script:CompilerSourceFingerprintRepo = $RepoRoot
		return $fp
	}
	finally { $sha.Dispose() }
}

function Get-CachedBytes([string]$Path) {
	if (-not (Test-Path -LiteralPath $Path)) { return $null }
	# 触碰 mtime 以躲开 Clear-StaleCache（14 天）：只在明显陈旧时才写回，省掉每次命中的元数据写入。
	$item = Get-Item -LiteralPath $Path
	if ($item.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddHours(-1)) { $item.LastWriteTimeUtc = [DateTime]::UtcNow }
	# 前置逗号阻止 PowerShell 展开字节数组（否则会被拆成 Object[]，原地修改会丢在副本上）。
	return , ([System.IO.File]::ReadAllBytes($Path))
}
function Set-CachedBytes([string]$Path, [byte[]]$Bytes) {
	# 先写临时文件再原子替换，避免并发编译读到半截缓存。
	$tmp = "$Path." + [Guid]::NewGuid().ToString('N') + '.tmp'
	[System.IO.File]::WriteAllBytes($tmp, $Bytes)
	Move-Item -LiteralPath $tmp -Destination $Path -Force
}
function Convert-RvaToOffset([byte[]]$Image, [int]$SectionCount, [int]$SectionsBase, [uint32]$Rva) {
	for ($sectionIndex = 0; $sectionIndex -lt $SectionCount; $sectionIndex++) {
		$sectionOffset = $SectionsBase + $sectionIndex * 40
		$va = [System.BitConverter]::ToUInt32($Image, $sectionOffset + 12)
		$vs = [System.BitConverter]::ToUInt32($Image, $sectionOffset + 8)
		$raw = [System.BitConverter]::ToUInt32($Image, $sectionOffset + 16)
		$ptr = [System.BitConverter]::ToUInt32($Image, $sectionOffset + 20)
		if ($Rva -ge $va -and $Rva -lt ($va + [math]::Max($vs, $raw))) { return [int]($ptr + ($Rva - $va)) }
	}
	return -1
}
# 定位托管程序集里那份唯一内嵌资源：[Int32 长度][数据] 的长度前缀文件偏移，以及 CLI 头（其 +28 是资源目录大小）。
function Get-FrameLayout([byte[]]$Image) {
	$pe = [System.BitConverter]::ToInt32($Image, 0x3c)
	if ($pe -le 0 -or $pe + 24 -gt $Image.Length) { throw '模板不是 PE' }
	$sectionCount = [System.BitConverter]::ToUInt16($Image, $pe + 6)
	$optSize = [System.BitConverter]::ToUInt16($Image, $pe + 20)
	$magic = [System.BitConverter]::ToUInt16($Image, $pe + 24)
	$ddOff = if ($magic -eq 0x20b) { $pe + 24 + 112 } else { $pe + 24 + 96 }
	$sectionsBase = $pe + 24 + $optSize
	$clrRva = [System.BitConverter]::ToUInt32($Image, $ddOff + 14 * 8)
	$cliOffset = Convert-RvaToOffset $Image $sectionCount $sectionsBase $clrRva
	if ($cliOffset -lt 0) { throw '模板缺少 CLI 头' }
	$resRva = [System.BitConverter]::ToUInt32($Image, $cliOffset + 24)
	$resOffset = Convert-RvaToOffset $Image $sectionCount $sectionsBase $resRva
	if ($resOffset -lt 0) { throw '模板缺少托管资源' }
	return [pscustomobject]@{ CliOffset = $cliOffset; ResourceOffset = $resOffset }
}
# 把 [Int32 长度][数据] 原地写进托管 PE 的内嵌资源（数据不超过占位桶），并同步 CLI 资源目录大小；不重排 PE。
function Set-FrameResource([byte[]]$Template, [byte[]]$Data) {
	$layout = Get-FrameLayout $Template
	$capacity = [System.BitConverter]::ToInt32($Template, $layout.ResourceOffset)
	if ($Data.Length -gt $capacity) { throw "帧模板占位不足（$($Data.Length) > $capacity）" }
	[System.Array]::Copy([System.BitConverter]::GetBytes([int]$Data.Length), 0, $Template, $layout.ResourceOffset, 4)
	[System.Array]::Copy($Data, 0, $Template, $layout.ResourceOffset + 4, $Data.Length)
	[System.Array]::Copy([System.BitConverter]::GetBytes([int](4 + $Data.Length)), 0, $Template, $layout.CliOffset + 28, 4)
	# 前置逗号阻止 PowerShell 展开字节数组（否则被拆成 Object[]，大脚本会因逐字节装箱显著变慢）。
	return , $Template
}

# 仅用于本项目生成、无 PDB/签名的 CodeDom 镜像。csc 的随机 MVID 与 PE 时间戳
# 会让冷缓存/不同机器的同一帧产生不同负载；归零后由完整内容派生新的 MVID。
# 不改变表、资源、程序集名称或布局；调试产物在调用方跳过，以保留 PDB 身份。
function Set-DeterministicPeIdentity([byte[]]$Image) {
	$pe = [BitConverter]::ToInt32($Image, 0x3c)
	if ($pe -lt 0 -or $pe + 24 -gt $Image.Length -or [BitConverter]::ToUInt32($Image, $pe) -ne 0x4550) { throw 'Invalid generated PE image' }
	$sectionCount = [BitConverter]::ToUInt16($Image, $pe + 6)
	$optSize = [BitConverter]::ToUInt16($Image, $pe + 20)
	$optional = $pe + 24
	$magic = [BitConverter]::ToUInt16($Image, $optional)
	$dd = if ($magic -eq 0x20b) { $optional + 112 } elseif ($magic -eq 0x10b) { $optional + 96 } else { throw 'Unsupported generated PE format' }
	$sections = $optional + $optSize
	$cli = Convert-RvaToOffset $Image $sectionCount $sections ([BitConverter]::ToUInt32($Image, $dd + 112))
	if ($cli -lt 0) { throw 'Generated PE has no CLI header' }
	$metadata = Convert-RvaToOffset $Image $sectionCount $sections ([BitConverter]::ToUInt32($Image, $cli + 8))
	if ($metadata -lt 0 -or [BitConverter]::ToUInt32($Image, $metadata) -ne 0x424a5342) { throw 'Invalid generated CLI metadata' }
	$streams = $metadata + 16 + [BitConverter]::ToUInt32($Image, $metadata + 12)
	$streams = [int](($streams + 3) -band -4)
	$count = [BitConverter]::ToUInt16($Image, $streams + 2)
	$cursor = $streams + 4
	$guidOffset = -1
	for ($i = 0; $i -lt $count; $i++) {
		$offset = [BitConverter]::ToUInt32($Image, $cursor)
		$size = [BitConverter]::ToUInt32($Image, $cursor + 4)
		$nameStart = $cursor + 8
		$end = $nameStart
		while ($end -lt $Image.Length -and $Image[$end] -ne 0) { $end++ }
		$name = [Text.Encoding]::ASCII.GetString($Image, $nameStart, $end - $nameStart)
		if ($name -eq '#GUID') {
			# 非增量 csc 产物只有 Module.Mvid 一个 GUID；不要改写其他 GUID/EnC 身份。
			if ($size -ne 16) { throw 'Unexpected GUID heap in generated CodeDom image' }
			$guidOffset = $metadata + $offset
		}
		$cursor = [int](($end + 4) -band -4)
	}
	if ($guidOffset -lt 0) { throw 'Generated CodeDom image has no MVID' }
	[Array]::Clear($Image, $guidOffset, 16)
	[Array]::Clear($Image, $pe + 8, 4) # COFF TimeDateStamp
	[Array]::Clear($Image, $optional + 64, 4) # checksum, recalculated by signing if requested
	# Native resource directories and DLL export headers also have timestamps.
	$resource = Convert-RvaToOffset $Image $sectionCount $sections ([BitConverter]::ToUInt32($Image, $dd + 16))
	if ($resource -ge 0) {
		$pending = [Collections.Generic.Stack[int]]::new()
		$pending.Push(0)
		while ($pending.Count) {
			$directory = $resource + $pending.Pop()
			[Array]::Clear($Image, $directory + 4, 4)
			$entries = [int][BitConverter]::ToUInt16($Image, $directory + 12) + [int][BitConverter]::ToUInt16($Image, $directory + 14)
			for ($entry = 0; $entry -lt $entries; $entry++) {
				$child = [BitConverter]::ToUInt32($Image, $directory + 20 + 8 * $entry)
				if ($child -band 0x80000000L) { $pending.Push([int]($child -band 0x7fffffff)) }
			}
		}
	}
	$export = Convert-RvaToOffset $Image $sectionCount $sections ([BitConverter]::ToUInt32($Image, $dd))
	if ($export -ge 0) { [Array]::Clear($Image, $export + 4, 4) }
	$sha = [Security.Cryptography.SHA256]::Create()
	try { $hash = $sha.ComputeHash($Image); [Array]::Copy($hash, 0, $Image, $guidOffset, 16) }
	finally { $sha.Dispose() }
	return , $Image
}
