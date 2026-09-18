#Requires -Version 5.0

#_if PSScript
<#
.SYNOPSIS
运行一个 Web 服务器，允许用户编译 PowerShell 脚本
.DESCRIPTION
运行一个 Web 服务器，允许用户编译 PowerShell 脚本
.PARAMETER HostUrl
Web 服务器的 URL
.PARAMETER MaxCompileThreads
最大编译线程数
.PARAMETER MaxCompileTime
单次编译的最大时长（秒）
.PARAMETER ReqLimitPerMin
每个 IP 每分钟的最大请求数
.PARAMETER MaxCachedFileSize
缓存文件的最大大小
.PARAMETER MaxScriptFileSize
脚本文件的最大大小
.PARAMETER CacheDir
存放缓存文件的目录
.PARAMETER Locale
用于服务器端日志记录的语言代码
.PARAMETER help
显示帮助信息
.EXAMPLE
Start-ps12exeWebServer
.EXAMPLE
Start-ps12exeWebServer -HostUrl 'http://localhost:80/'
#>
[CmdletBinding()]
#_endif
param (
	$HostUrl = 'http://localhost:8080/',
	$MaxCompileThreads = 8,
	$MaxCompileTime = 20,
	$ReqLimitPerMin = 5,
	$MaxCachedFileSize = 32mb,
	$MaxScriptFileSize = 2mb,
	$CacheDir = "$PSScriptRoot/outputs",
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Locale,
	[switch]$help
)

#_if PSScript
	$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Locale $Locale

	if ($help) {
		$MyHelp = $LocalizeData.WebServerHelpData
		. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Write-Host
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
		if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
			Write-Host $LocalizeData.TryRunAsRoot -ForegroundColor Yellow
		}
		Write-Host $LocalizeData.ServerStartFailed -ForegroundColor Black -BackgroundColor Red
		return
	}

	# 设置控制台窗口标题
	$BackUpTitle = $Host.UI.RawUI.WindowTitle
	$Host.UI.RawUI.WindowTitle = "ps12exe Web Server"

	Write-Host $LocalizeData.ExitServerTip -ForegroundColor Yellow
	$LocalizeData = $LocalizeData.WebServerI18nData

	# 定义一个哈希表来跟踪每个 IP 的请求数
	$ipRequestCount = @{}
	# 一个队列用于装载$AsyncResult和$Runspace以及其他信息，直到$AsyncResult结束我们才能对$Runspace进行Dispose。。。
	$AsyncResultArray = New-Object System.Collections.ArrayList
	# 创建 Runspace 池
	$runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxCompileThreads)
	$runspacePool.Open()

	function HandleWebCompileRequest($userInput, $context, $Locale) {
		Write-Verbose ($LocalizeData.CompilingUserInput -f $userInput)
		if (!$userInput) {
			Write-Verbose $LocalizeData.EmptyResponse
			return
		}
		$clientIP = $context.Request.RemoteEndPoint.Address.ToString()
		if ($userInput.Length -gt $MaxScriptFileSize -and $clientIP -ne '127.0.0.1') {
			Write-Verbose $LocalizeData.InputTooLarge413
			$context.Response.StatusCode = 413
			$context.Response.ContentType = "text/plain"
			$buffer = [System.Text.Encoding]::UTF8.GetBytes('File too large')
			return
		}
		$ipRequestCount[$clientIP]++

		# 检查该 IP 是否已超过限制（例如每分钟 5 个请求）
		if ($ipRequestCount[$clientIP] -gt $ReqLimitPerMin -and $clientIP -ne '127.0.0.1') {
			Write-Verbose ($LocalizeData.ReqLimitExceeded429 -f @($clientIP, $ReqLimitPerMin))
			$context.Response.StatusCode = 429
			$context.Response.ContentType = "text/plain"
			$buffer = [System.Text.Encoding]::UTF8.GetBytes('Too many requests')
			return
		}
		# 用户输入的哈希
		$userInputHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($userInput))
		$userInputHashStr = ''
		foreach ($byte in $userInputHash) {
			$userInputHashStr += $byte.ToString('x2')
		}
		$compiledExePath = "$CacheDir/$userInputHashStr.bin"
		#if match cached file
		if (Test-Path -Path $compiledExePath -ErrorAction Ignore) {
			$context.Response.ContentType = "application/octet-stream"
			$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
			return
		}
		$runspace = [powershell]::Create()
		$runspace.RunspacePool = $runspacePool
		$AsyncResult = $runspace.AddScript({
			param ($userInput, $Response, $ScriptRoot, $CacheDir, $compiledExePath, $clientIP, $Locale)

			# 加载ps12exe用于处理编译请求
			Import-Module $ScriptRoot/../../ps12exe.psm1 -ErrorAction Stop

			New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null

			# 编译代码
			try {
				$userInput | ps12exe -outputFile $compiledExePath -Sandbox:$($clientIP -ne '127.0.0.1') -ErrorAction Stop -Locale $Locale
			}
			catch { $LastExitCode = 1 }
			if ($LastExitCode) {
				# 若ErrorId不是ParserError则写入日志
				$e = $Error[0]
				if ($e.CategoryInfo.Category -ine "ParserError") {
					Write-Host "${clientIP}:" -ForegroundColor Red
					Write-Host $e -ForegroundColor Red
				}
				$Response.ContentType = "text/plain"
				$buffer = [System.Text.Encoding]::UTF8.GetBytes(($e, $e.TargetObject.Text -join "`n"))
			}
			else {
				$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
				$Response.ContentType = "application/octet-stream"
			}

			$Response.ContentLength64 = $buffer.Length
			if ($buffer) {
				$Response.OutputStream.Write($buffer, 0, $buffer.Length)
			}
			$Response.Close()
		}).
		AddArgument($userInput).AddArgument($context.Response).
		AddArgument($PSScriptRoot).AddArgument($CacheDir).
		AddArgument($compiledExePath).AddArgument($clientIP).AddArgument($Locale).
		BeginInvoke()
		$AsyncResultArray.Add(@{
			AsyncHandle = $AsyncResult
			Runspace    = $runspace
			Time        = Get-Date
			IP          = $clientIP
		}) | Out-Null
	}
	$HostSubUrl = $HostUrl.Substring($HostUrl.IndexOf('://') + 3)
	$HostSubUrl = $HostSubUrl.Substring($HostSubUrl.IndexOf('/')).TrimEnd('\/')
	function HandleRequest($context) {
		$RequestUrl = $context.Request.RawUrl
		if (-not $RequestUrl.StartsWith($HostSubUrl)) {
			return # 无效，不属于ps12exe Web Server的请求
		}
		$RequestUrl = $RequestUrl.Substring($HostSubUrl.Length)
		switch ($RequestUrl) {
			'/api/compile' {
				$Reader = New-Object System.IO.StreamReader($context.Request.InputStream)
				$userInput = $Reader.ReadToEnd()
				$Reader.Close()
				$Reader.Dispose()
				try {
					$userInput = $userInput | ConvertFrom-Json
				}
				catch {
					$context.Response.StatusCode = 400
					$context.Response.ContentType = "text/plain"
					$buffer = [System.Text.Encoding]::UTF8.GetBytes('Invalid JSON')
					return
				}
				HandleWebCompileRequest $userInput.content $context $userInput.locale
				return
			}
			'/bgm.mid' {
				# midi 文件
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
	function AutoCacheClear {
		$Cache = Get-ChildItem -Path $CacheDir -ErrorAction Ignore
		if ($MaxCachedFileSize -lt ($Cache | Measure-Object -Property Length -Sum).Sum) {
			$Cache | Sort-Object -Property LastAccessTime -Descending |
			Select-Object -First $([math]::Floor($Cache.Count / 2)) |
			Remove-Item -Force -ErrorAction Ignore
		}
	}
	function AutoRunspaceRecycle {
		while ($AsyncResultArray[0].AsyncHandle.IsCompleted) {
			$AsyncResultArray[0].Runspace.Dispose()
			$AsyncResultArray.RemoveAt(0)
		}
		$TimeNow = Get-Date
		while ($AsyncResultArray[0] -and ($TimeNow - $AsyncResultArray[0].Time).Seconds -ge $MaxCompileTime) {
			if ($AsyncResultArray[0].IP -eq '127.0.0.1') { break }
			$AsyncResultArray[0].Runspace.Stop()
			$AsyncResultArray[0].Runspace.Dispose()
			$AsyncResultArray.RemoveAt(0)
		}
	}

	try {
		# 无限循环，用于监听请求直到用户按下 Ctrl+C；$Timer 变量用于一分钟计时
		$Timer = 0
		while ($http.IsListening) {
			$Async = $http.BeginGetContext($null, $null)
			while (-not $Async.AsyncWaitHandle.WaitOne(500)) {
				$Timer++
				if ($Timer -ge 120) {
					$ipRequestCount = @{}
					AutoCacheClear
					$Timer = 0
				}
				AutoRunspaceRecycle
			}
			HandleRequest($http.EndGetContext($Async))
		}
	}
	finally {
		# 关闭 HttpListener
		$http.Stop()
		while ($AsyncResultArray.Count) {
			$AsyncResultArray[0].Runspace.Stop()
			$AsyncResultArray[0].Runspace.Dispose()
			$AsyncResultArray.RemoveAt(0)
		}
		$runspacePool.Close()
		$runspacePool.Dispose()
		Write-Host $LocalizeData.ServerStopped -ForegroundColor Yellow
		# 恢复控制台窗口标题
		$Host.UI.RawUI.WindowTitle = $BackUpTitle
		# 清空缓存
		Remove-Item $CacheDir/* -Recurse -Force -ErrorAction Ignore
	}
#_else
	#_require ps12exe
	#_pragma Resources.iconFile $PSScriptRoot/../../img/icon.ico
	#_pragma Resources.title ps12exeWebServer
	#_pragma Resources.description 'A webserver runner for compile powershell scripts online'
	#_!!Start-ps12exeWebServer @PSBoundParameters
#_endif
