. $PSScriptRoot\GuestUrlGuard.ps1

function GetAssembly($name, $otherinfo) {
	$n = New-Object System.Reflection.AssemblyName(@($name, $otherinfo) -ne $null -join ",")
	try {
		[System.AppDomain]::CurrentDomain.Load($n).Location
	}
	catch {
		$error.RemoveAt(0)
	}
}
$referenceAssembies = if ($targetRuntime -eq 'Framework2.0') {
	#_if PSScript
		powershell -version 2.0 -NoProfile -OutputFormat xml -file $PSScriptRoot/RuntimePwsh2.0/RefDlls.ps1 $(if ($noConsole) { '-noConsole' })
	#_else
		#_include_as_value Pwsh2RefDllsGetterCodeStr $PSScriptRoot/RuntimePwsh2.0/RefDlls.ps1
		#_!! powershell -version 2.0 -NoProfile -OutputFormat xml -Command "&{$Pwsh2RefDllsGetterCodeStr}$(if($noConsole){' -noConsole'})"
	#_endif
}
else {
	if ($PSVersionTable.PSEdition -eq "Core") {
		# Core 走 dotnet publish，不需要引用程序集列表；SMA 只用于 $isPwsh20Sma 判断。
		GetAssembly "System.Management.Automation"
	}
	else {
		# 绝不要直接使用 System.Private.CoreLib.dll，因为它是netlib的内部实现，而不是公共API；[int].Assembly.Location 等基础类型的程序集也是它。
		GetAssembly "mscorlib"
		GetAssembly "System.IO.Compression" "Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
		GetAssembly "System.Management.Automation"

		# 如果 noConsole 为 true，则将 System.Windows.Forms.dll 和 System.Drawing.dll 加入引用程序集列表
		if ($noConsole) {
			GetAssembly "System.Windows.Forms" "Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
			GetAssembly "System.Drawing" "Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"
		}

		GetAssembly "System.Core" "Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
		"System.dll" # 某种魔法
	}
}

$smaRef = @($referenceAssembies) | Where-Object { $_ -and ([IO.Path]::GetFileName($_) -ieq 'System.Management.Automation.dll') } | Select-Object -First 1
$isPwsh20Sma = $smaRef -and [Reflection.AssemblyName]::GetAssemblyName($smaRef).Version.Major -lt 3

# 目标框架版本供 constexpr.cs / default.cs 的 $TargetFramework 替换使用。
if ($isCoreTarget) {
	if ($coreTargetFramework -match '^net(\d+)\.(\d+)$') {
		# 显式指定的 Core TFM（Build.Core.TargetFramework，如 net8.0）。
		$TargetFramework = ".NETCore,Version=v$($Matches[1]).$($Matches[2])"
	}
	else {
		$Info = [System.Environment]::Version
		$TargetFramework = ".NETCore,Version=v$($Info.Major).$($Info.Minor)"
	}
}
elseif ($isPwsh20Sma) {
	$TargetFramework = ".NETFramework,Version=v2.0"
}
else {
	$TargetFramework = ".NETFramework,Version=v4.7"
}

. $PSScriptRoot\BuildFrame.ps1

# 是否在脚本顶层使用了 $input：只有用到时才把重定向的标准输入逐行读成管道输入（issue 62）。只扫描脚本顶层（也就是会被包进 PSEXEMainFunction 的那个 $input）；函数、脚本块、类内部的 $input 是它们各自的管道输入，与宿主无关，不计入。解析失败/无 AST 时保守起见仍读取输入。
$ScriptUsesInput = $true
if ($AST) {
	$ScriptUsesInput = $false
	foreach ($inputVar in $AST.FindAll({
		param($node)
		$node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -eq 'input'
	}, $true)) {
		$parentNode = $inputVar.Parent
		$inNestedScope = $false
		while ($parentNode) {
			if ($parentNode -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
				$parentNode -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -or
				$parentNode -is [System.Management.Automation.Language.TypeDefinitionAst]) {
				$inNestedScope = $true
				break
			}
			$parentNode = $parentNode.Parent
		}
		if (-not $inNestedScope) {
			$ScriptUsesInput = $true
			break
		}
	}
}

[string[]]$Constants = @()

$Constants += $threadingModel
if ($lcid) { $Constants += "culture" }
if ($noError) { $Constants += "noError" }
if ($noConsole) { $Constants += "noConsole" }
if ($noOutput) { $Constants += "noOutput" }
if ($noVerbose) { $Constants += "noVerbose" }
if ($noWarning) { $Constants += "noWarning" }
if ($noDebug) { $Constants += "noDebug" }
if ($resourceParams.version) { $Constants += "version" }
if ($resourceParams.Count) { $Constants += "Resources" }
if ($credentialGUI) { $Constants += "credentialGUI" }
if ($noVisualStyles) { $Constants += "noVisualStyles" }
# DarkMode 只需两个编译符号：Off 剔除暗色代码，On 跳过系统探测，Auto（默认）不定义符号并运行时探测。
if ($darkMode -eq 'Off') { $Constants += "darkModeOff" }
elseif ($darkMode -eq 'On') { $Constants += "darkModeOn" }
if ($isCoreTarget -and $TargetFramework -match '^\.NETCore,Version=v(?<version>\d+\.\d+)$' -and [version]::Parse($Matches.version) -ge [version]'9.0') { $Constants += "ModernWinForms" }
if ($exitOnCancel) { $Constants += "exitOnCancel" }
if ($conHost) { $Constants += "conHost" }
if ($UNICODEEncoding) { $Constants += "UNICODEEncoding" }
if ($UTF8Encoding) { $Constants += "UTF8Encoding" }
if ($winFormsDPIAware) { $Constants += "winFormsDPIAware" }
if ($isPwsh20Sma) { $Constants += "Pwsh20" }
if ($ScriptUsesInput) { $Constants += "ReadInput" }
if ($AST -and $AST.ParamBlock) { $Constants += "ScriptHasParam" }
if ($StartupTiming) { $Constants += "StartupTiming" }

if (-not $TempDir) {
	$AutoTempDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
	$TempDir = $AutoTempDir
	New-Item -Path $AutoTempDir -ItemType Directory | Out-Null
}
$TempDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TempDir)
# 脚本以未压缩的 main.ps1 资源内嵌；打包时整块负载还会再压一遍（gzip/Brotli，必要时 LZMA），这里先压反而不可压。
[byte[]]$scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
$scriptPath = Join-Path $TempDir 'main.ps1'
[System.IO.File]::WriteAllBytes($scriptPath, $scriptBytes)
function Get-IconExtensionFromContentType([string]$ContentType) {
	switch -Regex ($ContentType) {
		"image/png" { return ".png" }
		"image/jpeg|image/jpg" { return ".jpg" }
		"image/gif" { return ".gif" }
		"image/bmp" { return ".bmp" }
		"image/x-icon|image/vnd.microsoft.icon|image/ico" { return ".ico" }
		"image/svg" { return ".svg" }
		default { return ".ico" }
	}
}
# desktop.ini 风格的图标引用 "xxx.exe,0" / "xxx.dll,-16"：从 exe/dll 等 PE 资源里抽第 Index 个图标到临时 .ico。
# 先按 256 像素用 PrivateExtractIcons 取（保留高分辨率），失败再退回 shell32 的 ExtractIconEx 大图标。
$IconExtractorTypeName = 'Ps12exeIconExtractor'
$IconExtractorCode = @'
using System;
using System.Runtime.InteropServices;
public static class Ps12exeIconExtractor {
	[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern uint PrivateExtractIcons(string lpszFile, int nIconIndex, int cxIcon, int cyIcon, IntPtr[] phicon, uint[] piconid, uint nIcons, uint flags);
	[DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern uint ExtractIconEx(string lpszFile, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, uint nIcons);
	[DllImport("user32.dll", SetLastError = true)]
	public static extern bool DestroyIcon(IntPtr hIcon);
}
'@
function Get-IconFileFromPE([string]$PePath, [int]$Index) {
	Add-Type -AssemblyName System.Drawing
	if (-not ($IconExtractorTypeName -as [type])) { Add-Type -TypeDefinition $IconExtractorCode }
	$handle = [IntPtr]::Zero
	$handles = [IntPtr[]]::new(1)
	[void][Ps12exeIconExtractor]::PrivateExtractIcons($PePath, $Index, 256, 256, $handles, $null, 1, 0)
	if ($handles[0] -ne [IntPtr]::Zero) { $handle = $handles[0] }
	else {
		$handles = [IntPtr[]]::new(1)
		[void][Ps12exeIconExtractor]::ExtractIconEx($PePath, $Index, $handles, $null, 1)
		if ($handles[0] -ne [IntPtr]::Zero) { $handle = $handles[0] }
	}
	if ($handle -eq [IntPtr]::Zero) { return $null }
	$icon = [System.Drawing.Icon]::FromHandle($handle)
	try {
		$out = [System.IO.Path]::Combine($TempDir, "extracted_icon_$([Guid]::NewGuid().ToString()).ico")
		$stream = [System.IO.File]::Create($out)
		try { $icon.Save($stream) }
		finally { $stream.Dispose() }
		return $out
	}
	finally {
		$icon.Dispose()
		[void][Ps12exeIconExtractor]::DestroyIcon($handle)
	}
}
# 解析 desktop.ini 风格的资源索引：末尾 ",<负整数>" 是图标索引（负数为资源 ID）。仅本地引用走此约定，URL 里的逗号不解析。
$iconIndex = $null
if ($iconFile -and $iconFile -notmatch "^(https?|ftp)://" -and $iconFile -match '^(?<path>.+),(?<index>-?\d+)$') {
	$iconFile = $Matches['path']
	$iconIndex = [int]$Matches['index']
}
if ($iconFile -match "^(https?|ftp)://") {
	if ($GuestMode) {
		if ($iconFile -match "^ftp://") {
			Write-I18n Error GuestModeFtpNotSupported -Category ReadError
			throw
		}
		if (-not (Test-GuestUrlAllowed $iconFile)) {
			Write-I18n Error GuestModeUrlForbidden $iconFile -Category ReadError
			throw
		}
		$iconResponse = try {
			# 禁用自动重定向并逐跳校验目标（见 GuestUrlGuard），同时按实际下载字节数限流。
			Invoke-GuestHttpRequest -Url $iconFile -MaxBytes 1mb
		}
		catch {
			Write-I18n Error IconFileNotFound $iconFile -Category ReadError
			throw
		}
		if ($iconResponse.Bytes.Length -gt 1mb) {
			Write-I18n Error GuestModeIconFileTooLarge $iconFile -Category LimitsExceeded
			throw
		}
		$urlExtension = [System.IO.Path]::GetExtension([System.Uri]$iconFile).ToLower()
		if (!$urlExtension) { $urlExtension = Get-IconExtensionFromContentType $iconResponse.ContentType }
		$downloadedIconPath = "$TempDir\icon$urlExtension"
		[System.IO.File]::WriteAllBytes($downloadedIconPath, $iconResponse.Bytes)
		$iconFile = $downloadedIconPath
	}
	else {
		try {
			# 首先尝试从URL中获取文件扩展名
			$urlExtension = [System.IO.Path]::GetExtension([System.Uri]$iconFile).ToLower()

			# 如果URL中没有扩展名，尝试从Content-Type获取
			if (!$urlExtension) {
				$headResponse = Invoke-WebRequest $iconFile -Method Head -ErrorAction SilentlyContinue
				if ($headResponse) {
					$contentType = $headResponse.Headers.'Content-Type'
					if ($contentType) { $urlExtension = Get-IconExtensionFromContentType $contentType }
				}
			}

			# 如果仍然没有扩展名，默认使用.ico
			if (!$urlExtension) { $urlExtension = ".ico" }

			$downloadedIconPath = "$TempDir\icon$urlExtension"
			Invoke-WebRequest -ErrorAction Stop -Uri $iconFile -OutFile $downloadedIconPath
			$iconFile = $downloadedIconPath
		}
		catch {
			Write-I18n Error IconFileNotFound $iconFile -Category ReadError
			throw
		}
	}
}
elseif ($iconFile) {
	# 获取绝对路径，无论给出的是相对路径还是绝对路径
	$iconFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($iconFile)
	if ($GuestMode -and -not (Test-GuestLocalFilePathAllowed $iconFile)) {
		# 访客模式只放行 Windows 目录下的系统图片：其余本地路径可任意读用户文件，UNC 会触发 SMB 外连。
		Write-I18n Error GuestModeLocalFileForbidden $iconFile -Category ReadError
		throw
	}

	if (!(Test-Path $iconFile -PathType Leaf)) {
		Write-I18n Error IconFileNotFound $iconFile -Category ReadError
		throw
	}
}

if ($iconFile) {
	$iconExtension = [System.IO.Path]::GetExtension($iconFile).ToLower()
	# exe/dll 等资源容器，或用户显式给了索引且不是图片后缀：从 PE 资源抽图标。
	$iconContainerExtensions = @('.exe', '.dll', '.ocx', '.cpl', '.scr', '.icl', '.bpl', '.dpl', '.drv', '.sys', '.mun')
	$iconImageExtensions = @('.ico', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tif', '.tiff', '.webp')
	if (($iconContainerExtensions -contains $iconExtension) -or ($null -ne $iconIndex -and $iconImageExtensions -notcontains $iconExtension)) {
		if ($null -eq $iconIndex) { $iconIndex = 0 }
		Write-I18n Host ExtractingIconFromFile "$iconFile,$iconIndex"
		$extractedIcon = $null
		try { $extractedIcon = Get-IconFileFromPE $iconFile $iconIndex }
		catch { Write-I18n Warning IconExtractionFailed $iconFile $_.Exception.Message }
		if ($extractedIcon) {
			$iconFile = $extractedIcon
		}
		else {
			Write-I18n Warning IconExtractionFailed $iconFile "no icon at index $iconIndex"
			Write-I18n Warning PleaseUseIcoFile $iconExtension
		}
		$iconExtension = [System.IO.Path]::GetExtension($iconFile).ToLower()
	}
	# 自动图片转换：检测非 .ico 后缀并自动转换
	if ($iconExtension -ne ".ico") {
		Write-I18n Host ConvertingImageToIcon
		$sourceImage = $null
		$iconStream = $null
		$writer = $null

		try {
			Add-Type -AssemblyName System.Drawing

			$sourceImage = [System.Drawing.Image]::FromFile($iconFile)
			$tempIcoPath = [System.IO.Path]::Combine($TempDir, "converted_icon_$([Guid]::NewGuid().ToString()).ico")

			$sizes = @(16, 32, 48, 256)
			$iconStream = New-Object System.IO.MemoryStream
			$writer = New-Object System.IO.BinaryWriter($iconStream)

			$writer.Write([UInt16]0)  # 保留
			$writer.Write([UInt16]1)  # 类型（ICO）
			$writer.Write([UInt16]$sizes.Count)  # 图像数量

			$directoryOffset = $iconStream.Position
			$imageDataOffset = $directoryOffset + (16 * $sizes.Count)

			$imageData = @()
			foreach ($size in $sizes) {
				$bitmap = $null
				$graphics = $null
				$pngStream = $null

				try {
					$bitmap = New-Object System.Drawing.Bitmap($size, $size)
					$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
					$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
					$graphics.DrawImage($sourceImage, 0, 0, $size, $size)

					$pngStream = New-Object System.IO.MemoryStream
					$bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
					$pngBytes = $pngStream.ToArray()

					$imageData += @{
						Size   = $size
						Data   = $pngBytes
						Offset = $imageDataOffset
						Length = $pngBytes.Length
					}
					$imageDataOffset += $pngBytes.Length
				}
				finally {
					if ($graphics) { $graphics.Dispose() }
					if ($pngStream) { $pngStream.Dispose() }
					if ($bitmap) { $bitmap.Dispose() }
				}
			}

			foreach ($imgData in $imageData) {
				$size = $imgData.Size
				$width = if ($size -eq 256) { 0 } else { $size }

				$writer.Write([Byte]$width)
				$writer.Write([Byte]$width)
				$writer.Write([Byte]0)
				$writer.Write([Byte]0)
				$writer.Write([UInt16]1)
				$writer.Write([UInt16]32)
				$writer.Write([UInt32]$imgData.Length)
				$writer.Write([UInt32]$imgData.Offset)
			}

			foreach ($imgData in $imageData) {
				$writer.Write($imgData.Data)
			}

			$writer.Flush()
			[System.IO.File]::WriteAllBytes($tempIcoPath, $iconStream.ToArray())

			$iconFile = $tempIcoPath
			Write-I18n Host ImageConvertedToIcon $iconFile

		}
		catch {
			Write-I18n Warning ImageConversionFailed $_.Exception.Message
			Write-I18n Warning PleaseUseIcoFile $iconExtension
			# 转换失败时继续使用原文件，但可能会在后续步骤中失败
		}
		finally {
			if ($writer) { $writer.Dispose() }
			if ($iconStream) { $iconStream.Dispose() }
			if ($sourceImage) { $sourceImage.Dispose() }
		}
	}
}
