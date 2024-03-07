# 创建 HttpListener 对象
$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add("http://localhost:8080/")
$http.Start()

if ($http.IsListening) {
	Write-Host "HTTP 服务器已启动！" -ForegroundColor Black -BackgroundColor Green
	Write-Host "访问地址: $($http.Prefixes)" -ForegroundColor Yellow
}

# 加载ps12exe用于处理编译请求
Import-Module $PSScriptRoot/../../ps12exe.psm1

# 无限循环，用于监听请求
while ($http.IsListening) {
	$context = $http.GetContext()
	if ($context.Request.RawUrl -eq '/compile') {
		# 处理编译请求
		$context = $http.GetContext()

		# 获取用户提交的代码
		$userInput = (New-Object System.IO.StreamReader($context.Request.InputStream)).ReadToEnd()
		# new uuid
		$uuid = [Guid]::NewGuid().ToString()
		$compiledExePath = "$PSScriptRoot/outputs/$uuid.exe"

		# 编译代码
		try {
			$userInput | ps12exe -outputFile $compiledExePath -ErrorAction Stop
			# 返回编译好的 EXE 文件
			$context.Response.ContentType = "application/octet-stream"
			$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
		}
		catch {
			Write-Host "编译失败！" -ForegroundColor Red
			Write-Host $_
			# 给网页返回错误信息
			$context.Response.ContentType = "text/plain"
			$buffer = [System.Text.Encoding]::UTF8.GetBytes("$_")
		}
	}
	elseif ($context.Request.RawUrl -eq '/') {
		$body = Get-Content -LiteralPath "$PSScriptRoot/index.html" -Encoding utf8 -Raw
		$buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
	}
	$context.Response.ContentLength64 = $buffer.Length
	$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
	$context.Response.Close()
}
