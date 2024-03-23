#Requires -Version 5.0

<#
.SYNOPSIS
run a web server to allow users to compile powershell scripts
.DESCRIPTION
run a web server to allow users to compile powershell scripts
.PARAMETER HostUrl
The url of the web server
.PARAMETER MaxCompileThreads
The maximum number of compile threads
.PARAMETER ReqLimitPerMin
The maximum number of requests per minute per IP
.PARAMETER MaxCachedFileSize
The maximum size of the cached file
.PARAMETER MaxScriptFileSize
The maximum size of the script file
.PARAMETER Localize
The language code to be used for server-side logging
.PARAMETER help
Display help message
.EXAMPLE
Start-ps12exeWebServer
.EXAMPLE
Start-ps12exeWebServer -HostUrl 'http://localhost:80/'
#>
[CmdletBinding()]
param (
	$HostUrl = 'http://localhost:8080/',
	$MaxCompileThreads = 8,
	$ReqLimitPerMin = 5,
	$MaxCachedFileSize = 32mb,
	$MaxScriptFileSize = 2mb,
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
	})]
	[string]$Localize,
	[switch]$help
)

$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Localize $Localize

if ($help) {
	$MyHelp = $LocalizeData.WebServerHelpData
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Out-Host
	return
}

# 创建 HttpListener 对象
$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add($HostUrl)
$http.Start()

if ($http.IsListening) {
	Write-Host $LocalizeData.ServerStarted -ForegroundColor Black -BackgroundColor Green
	Write-Host "$($LocalizeData.ServerListening) $($http.Prefixes)" -ForegroundColor Yellow
}
else {
	Write-Host $LocalizeData.ServerFailed -ForegroundColor Black -BackgroundColor Red
	return
}

# Set Console Window Title
$BackUpTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "ps12exe Web Server"

Write-Host $LocalizeData.ExitServerTip -ForegroundColor Yellow

# Define a hashtable to track request counts per IP
$ipRequestCount = @{}
# 两个队列用于装载$AsyncResult和$Runspace，直到$AsyncResult结束我们才能对$Runspace进行Dispose。。。
$AsyncResultArray = New-Object System.Collections.ArrayList
$RunspaceArray = New-Object System.Collections.ArrayList
# Create a runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxCompileThreads)
$runspacePool.Open()

function HandleRequest($context) {
	switch ($context.Request.RawUrl) {
		'/compile' {
			$Reader = New-Object System.IO.StreamReader($context.Request.InputStream)
			$userInput = $Reader.ReadToEnd()
			$Reader.Close()
			$Reader.Dispose()
			Write-Verbose "Compiling User Input: $userInput"
			if (!$userInput) {
				Write-Verbose "No data found when Handling Request, returning empty response"
				break
			}
			if ($userInput.Length -gt $MaxScriptFileSize) {
				Write-Verbose "User Input is too large, returning 413 error"
				$context.Response.StatusCode = 413
				$context.Response.ContentType = "text/plain"
				$buffer = [System.Text.Encoding]::UTF8.GetBytes('File too large')
				break
			}
			$clientIP = $context.Request.RemoteEndPoint.Address.ToString()
			$ipRequestCount[$clientIP]++

			# Check if the IP has exceeded the limit (e.g., 5 requests per minute)
			if ($ipRequestCount[$clientIP] -gt $ReqLimitPerMin -and $clientIP -ne '127.0.0.1') {
				Write-Verbose "IP $clientIP has exceeded the limit of $ReqLimitPerMin requests per minute, returning 429 error"
				$context.Response.StatusCode = 429
				$context.Response.ContentType = "text/plain"
				$buffer = [System.Text.Encoding]::UTF8.GetBytes('Too many requests')
				break
			}
			# hash of user input
			$userInputHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($userInput))
			$userInputHashStr = ''
			foreach ($byte in $userInputHash) {
				$userInputHashStr += $byte.ToString('x2')
			}
			$compiledExePath = "$PSScriptRoot/outputs/$userInputHashStr.bin"
			#if match cached file
			if (Test-Path -Path $compiledExePath -ErrorAction Ignore) {
				$context.Response.ContentType = "application/octet-stream"
				$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
				break
			}
			$runspace = [powershell]::Create()
			$runspace.RunspacePool = $runspacePool
			$AsyncResult = $runspace.AddScript({
					param ($userInput, $Response, $ScriptRoot, $compiledExePath, $clientIP)

					# 加载ps12exe用于处理编译请求
					Import-Module $ScriptRoot/../../ps12exe.psm1 -ErrorAction Stop

					New-Item -Path $ScriptRoot/outputs -ItemType Directory -Force | Out-Null

					# 编译代码
					try {
						$userInput | ps12exe -outputFile $compiledExePath -GuestMode:$($clientIP -ne '127.0.0.1') -ErrorAction Stop
						$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
						$Response.ContentType = "application/octet-stream"
					}
					catch {
						# 若ErrorId不是ParseError则写入日志
						if ($_.ErrorId -ine "ParseError") {
							Write-Host "${clientIP}:" -ForegroundColor Red
							Write-Host $_ -ForegroundColor Red
						}
						$Response.ContentType = "text/plain"
						$buffer = [System.Text.Encoding]::UTF8.GetBytes("$_")
					}

					$Response.ContentLength64 = $buffer.Length
					if ($buffer) {
						$Response.OutputStream.Write($buffer, 0, $buffer.Length)
					}
					$Response.Close()
				}).
			AddArgument($userInput).AddArgument($context.Response).
			AddArgument($PSScriptRoot).AddArgument($compiledExePath).AddArgument($clientIP).
			BeginInvoke()
			$AsyncResultArray.Add($AsyncResult) | Out-Null
			$RunspaceArray.Add($runspace) | Out-Null
			return
		}
		'/bgm' {
			# midi file
			$context.Response.ContentType = "audio/midi"
			$buffer = [System.IO.File]::ReadAllBytes("$PSScriptRoot/../bin/Unravel.mid")
		}
		'/favicon.ico' {
			$context.Response.ContentType = "image/x-icon"
			$buffer = [System.IO.File]::ReadAllBytes("$PSScriptRoot/../../img/icon.ico")
		}
		'/' {
			$body = Get-Content -LiteralPath "$PSScriptRoot/index.html" -Encoding utf8 -Raw
			$buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
		}
		default {
			$context.Response.StatusCode = 404
			$context.Response.ContentType = "text/plain"
			$buffer = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
		}
	}
	$context.Response.ContentLength64 = $buffer.Length
	if ($buffer) {
		$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
	}
	$context.Response.Close()
}

try {
	# 无限循环，用于监听请求 直到用户按下 Ctrl+C
	# 变量用于一分钟计时
	$Timer = 0
	while ($http.IsListening) {
		$Async = $http.BeginGetContext($null, $null)
		while (-not $Async.AsyncWaitHandle.WaitOne(500)) {
			$Timer++
			if ($Timer -ge 120) {
				$ipRequestCount = @{}
				$Cache = Get-ChildItem -Path $PSScriptRoot/outputs -ErrorAction Ignore
				if ($MaxCachedFileSize -lt ($Cache | Measure-Object -Property Length -Sum).Sum) {
					$Cache | Sort-Object -Property LastAccessTime -Descending |
					Select-Object -First $([math]::Floor($Cache.Count / 2)) |
					Remove-Item -Force -ErrorAction Ignore
				}
				$Timer = 0
			}
			while ($AsyncResultArray[0].IsCompleted) {
				$RunspaceArray[0].Dispose()
				$AsyncResultArray.RemoveAt(0)
				$RunspaceArray.RemoveAt(0)
			}
		}
		HandleRequest($http.EndGetContext($Async))
	}
}
finally {
	# 关闭 HttpListener
	$http.Stop()
	while ($RunspaceArray.Count) {
		$RunspaceArray[0].Stop()
		$RunspaceArray[0].Dispose()
		$RunspaceArray.RemoveAt(0)
	}
	$runspacePool.Close()
	$runspacePool.Dispose()
	Write-Host $LocalizeData.ServerStopped -ForegroundColor Yellow
	# Restore Console Window Title
	$Host.UI.RawUI.WindowTitle = $BackUpTitle
	# 清空缓存
	Remove-Item $PSScriptRoot/outputs/* -Recurse -Force -ErrorAction Ignore
}
