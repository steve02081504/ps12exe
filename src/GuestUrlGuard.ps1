# 访客（Sandbox）模式下的 URL 抓取策略：禁止本机/内网/链路本地地址，避免 SSRF。
# 只做纯判定，不读全局状态；调用方自行决定是否处于 GuestMode。
function Test-GuestPrivateIPAddress([System.Net.IPAddress]$IP) {
	if ($null -eq $IP) { return $true }
	if ([System.Net.IPAddress]::IsLoopback($IP)) { return $true }
	$bytes = $IP.GetAddressBytes()
	if ($IP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
		if ($bytes[0] -eq 0) { return $true }                                            # 0.0.0.0/8
		if ($bytes[0] -eq 10) { return $true }                                           # 10/8
		if ($bytes[0] -eq 100 -and $bytes[1] -ge 64 -and $bytes[1] -le 127) { return $true } # 100.64/10 CGNAT
		if ($bytes[0] -eq 127) { return $true }                                          # 127/8
		if ($bytes[0] -eq 169 -and $bytes[1] -eq 254) { return $true }                   # 169.254/16（含云元数据 169.254.169.254）
		if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) { return $true } # 172.16/12
		if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0) { return $true }    # 192.0.0/24
		if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 2) { return $true }    # 192.0.2/24 TEST-NET-1
		if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) { return $true }                   # 192.168/16
		if ($bytes[0] -eq 198 -and $bytes[1] -ge 18 -and $bytes[1] -le 19) { return $true }  # 198.18/15 基准测试
		if ($bytes[0] -eq 198 -and $bytes[1] -eq 51 -and $bytes[2] -eq 100) { return $true } # 198.51.100/24 TEST-NET-2
		if ($bytes[0] -eq 203 -and $bytes[1] -eq 0 -and $bytes[2] -eq 113) { return $true }  # 203.0.113/24 TEST-NET-3
		if ($bytes[0] -ge 224) { return $true }                                          # 组播/保留
		return $false
	}
	# IPv6
	if ($IP.IsIPv6Multicast -or $IP.IsIPv6LinkLocal -or $IP.IsIPv6SiteLocal) { return $true }
	if (($bytes[0] -band 0xFE) -eq 0xFC) { return $true }                                # fc00::/7 唯一本地
	$isMapped = $true
	for ($i = 0; $i -lt 10; $i++) { if ($bytes[$i] -ne 0) { $isMapped = $false; break } }
	if ($isMapped -and $bytes[10] -eq 0xFF -and $bytes[11] -eq 0xFF) { # ::ffff:a.b.c.d
		$v4 = [System.Net.IPAddress]::new([byte[]]@($bytes[12], $bytes[13], $bytes[14], $bytes[15]))
		return (Test-GuestPrivateIPAddress $v4)
	}
	$firstTwelveZero = $true
	for ($i = 0; $i -lt 12; $i++) { if ($bytes[$i] -ne 0) { $firstTwelveZero = $false; break } }
	if ($firstTwelveZero) { # ::a.b.c.d（IPv4 兼容，含 ::）
		$v4 = [System.Net.IPAddress]::new([byte[]]@($bytes[12], $bytes[13], $bytes[14], $bytes[15]))
		return (Test-GuestPrivateIPAddress $v4)
	}
	if ($bytes[0] -eq 0x20 -and $bytes[1] -eq 0x02) { # 2002::/16 6to4（内嵌 IPv4）
		$v4 = [System.Net.IPAddress]::new([byte[]]@($bytes[2], $bytes[3], $bytes[4], $bytes[5]))
		return (Test-GuestPrivateIPAddress $v4)
	}
	if ($bytes[0] -eq 0x20 -and $bytes[1] -eq 0x01 -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) { return $true } # 2001:0::/32 Teredo
	if ($bytes[0] -eq 0 -and $bytes[1] -eq 0x64 -and $bytes[2] -eq 0xFF -and $bytes[3] -eq 0x9B) { return $true } # 64:ff9b::/96 NAT64
	return $false
}

# 返回 $true 表示访客模式允许抓取该 URL。非 http(s)、无法解析、或解析到本机/内网地址一律拒绝。
function Test-GuestUrlAllowed([string]$Url) {
	if ($Url -notmatch '(?i)^https?://') { return $false }
	try { $Uri = [uri]$Url } catch { return $false }
	if (-not $Uri.Host) { return $false }
	$HostName = $Uri.Host.Trim('[', ']')
	if ($HostName -ieq 'localhost' -or $HostName -like '*.localhost') { return $false }
	$Parsed = $null
	if ([System.Net.IPAddress]::TryParse($HostName, [ref]$Parsed)) {
		$Addresses = @($Parsed)
	}
	else {
		try { $Addresses = @([System.Net.Dns]::GetHostAddresses($HostName)) }
		catch { return $false }
	}
	if (-not $Addresses.Count) { return $false }
	foreach ($addr in $Addresses) {
		if (Test-GuestPrivateIPAddress $addr) { return $false }
	}
	return $true
}

# 返回 $true 表示访客模式允许读取该本地文件路径。只放行 Windows 目录（$env:windir / $env:SystemRoot）下的文件：
# 系统自带的图片资源无害，可满足「用系统 ico」这类正常需求；其余本地路径与 UNC 会任意读用户文件或触发 SMB 外连，一律拒绝。
function Test-GuestLocalFilePathAllowed([string]$Path) {
	if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
	if ($Path.StartsWith('\\') -or $Path.StartsWith('//')) { return $false }
	try { $Full = [System.IO.Path]::GetFullPath($Path) } catch { return $false }
	foreach ($root in @($env:windir, $env:SystemRoot)) {
		if ([string]::IsNullOrWhiteSpace($root)) { continue }
		try { $RootFull = [System.IO.Path]::GetFullPath($root) } catch { continue }
		$RootFull = $RootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
		if ($Full.StartsWith($RootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
	}
	return $false
}

# 解析 HTTP 重定向目标：相对地址按 BaseUrl 归一化，并强制用 Test-GuestUrlAllowed 校验。不允许返回 $null。
# 这是防 SSRF 的关键：Invoke-WebRequest 默认自动跟随 3xx，可被公网主机重定向到内网/云元数据。
function Resolve-GuestRedirectLocation([string]$BaseUrl, [string]$Location) {
	if ([string]::IsNullOrWhiteSpace($Location)) { return $null }
	try { $Target = [System.Uri]::new([System.Uri]$BaseUrl, $Location) }
	catch { return $null }
	if (-not (Test-GuestUrlAllowed $Target.AbsoluteUri)) { return $null }
	$Target.AbsoluteUri
}

# 访客模式下的受控 HTTP 请求：禁用自动重定向，逐跳校验 Location；按 MaxBytes 限制实际读取字节数（0 表示不限），
# 避免超大响应被整体读进内存。Validator 可注入以便测试，默认即 Test-GuestUrlAllowed。
function Invoke-GuestHttpRequest {
	param(
		[Parameter(Mandatory)][string]$Url,
		[ValidateSet('GET', 'HEAD')][string]$Method = 'GET',
		[int]$MaxRedirects = 5,
		[int64]$MaxBytes = 0,
		[scriptblock]$Validator
	)
	if (-not $Validator) { $Validator = { param($u) Test-GuestUrlAllowed $u } }
	$current = $Url
	for ($hop = 0; $hop -le $MaxRedirects; $hop++) {
		if (-not (& $Validator $current)) { throw "URL not allowed: $current" }
		$request = [System.Net.HttpWebRequest]::Create($current)
		$request.Method = $Method
		$request.AllowAutoRedirect = $false
		$request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
		$request.UserAgent = 'ps12exe-sandbox'
		$response = $null
		try { $response = $request.GetResponse() }
		catch [System.Net.WebException] {
			if ($_.Exception.Response) { $response = $_.Exception.Response } else { throw }
		}
		try {
			$status = [int]$response.StatusCode
			if ($status -ge 300 -and $status -lt 400) {
				$location = $response.Headers['Location']
				$resolved = Resolve-GuestRedirectLocation $current $location
				if (-not $resolved) { throw "Blocked redirect target: $location" }
				$current = $resolved
				continue
			}
			if ($status -ge 400) { throw "HTTP $status for $current" }
			$bytes = [byte[]]@()
			if ($Method -eq 'GET') {
				$stream = $response.GetResponseStream()
				$memory = [System.IO.MemoryStream]::new()
				$buffer = [byte[]]::new(8192)
				try {
					while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
						$memory.Write($buffer, 0, $read)
						if ($MaxBytes -gt 0 -and $memory.Length -gt $MaxBytes) { break }
					}
				}
				finally { $stream.Dispose() }
				$bytes = $memory.ToArray()
				$memory.Dispose()
			}
			$charset = $response.CharacterSet
			$encoding = if ($charset) {
				try { [System.Text.Encoding]::GetEncoding($charset) } catch { [System.Text.Encoding]::UTF8 }
			}
			else { [System.Text.Encoding]::UTF8 }
			return [pscustomobject]@{
				StatusCode  = $status
				ContentType = $response.ContentType
				Bytes       = $bytes
				Text        = if ($Method -eq 'GET') { $encoding.GetString($bytes) } else { '' }
				FinalUri    = $current
			}
		}
		finally { $response.Close() }
	}
	throw "Too many redirects: $Url"
}
