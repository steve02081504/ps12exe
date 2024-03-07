#Requires -Version 5.0

<#
.SYNOPSIS
run a web server to allow users to compile powershell scripts
.DESCRIPTION
run a web server to allow users to compile powershell scripts
.PARAMETER HostUrl
The url of the web server
.PARAMETER Localize
The language code to be used for server-side logging
.PARAMETER help
Display help message
.EXAMPLE
Start-ps12exeWebServer
.EXAMPLE
Start-ps12exeWebServer -HostUrl 'http://localhost:8080/'
#>
[CmdletBinding()]
param (
	$HostUrl = 'http://localhost:8080/',
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

# 加载ps12exe用于处理编译请求
Import-Module $PSScriptRoot/../../ps12exe.psm1 -ErrorAction Stop

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

Write-Host $LocalizeData.UnsafeWarning -ForegroundColor Yellow
Write-Host $LocalizeData.ExitServerTip -ForegroundColor Yellow

function HandleRequest($context) {
	if ($context.Request.RawUrl -eq '/compile') {
		# 处理编译请求
		$context = $http.GetContext()

		# 获取用户提交的代码
		$Reader = New-Object System.IO.StreamReader($context.Request.InputStream)
		$userInput = $Reader.ReadToEnd()
		$Reader.Close()
		$Reader.Dispose()
		if (!$userInput) {
			$context.Response.ContentType = "text/plain"
			$context.Response.ContentLength64 = 0
			$context.Response.Close()
			return
		}
		# new uuid
		$uuid = [Guid]::NewGuid().ToString()
		$compiledExePath = "$PSScriptRoot/outputs/$uuid.exe"

		New-Item -Path $PSScriptRoot/outputs -ItemType Directory -Force | Out-Null

		# 编译代码
		try {
			$userInput | ps12exe -outputFile $compiledExePath -ErrorAction Stop
			$context.Response.ContentType = "application/octet-stream"
			$buffer = [System.IO.File]::ReadAllBytes($compiledExePath)
			Remove-Item $compiledExePath -Force
		}
		catch {
			# 若ErrorId不是ParseError则写入日志
			if ($_.ErrorId -ine "ParseError") {
				Write-Host $_ -ForegroundColor Red
			}
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

try {
	# 无限循环，用于监听请求 直到用户按下 Ctrl+C
	while ($http.IsListening) {
		$Async = $http.BeginGetContext($null, $null)
		while (-not $Async.AsyncWaitHandle.WaitOne(100)) { }
		HandleRequest($http.EndGetContext($Async))
	}
}
finally {
	# 关闭 HttpListener
	$http.Stop()
	Write-Host $LocalizeData.ServerStopped -ForegroundColor Yellow
	# Restore Console Window Title
	$Host.UI.RawUI.WindowTitle = $BackUpTitle
	# 清空缓存
	Remove-Item $PSScriptRoot/outputs/* -Recurse -Force
}
