#Requires -Version 5.1
<#
.SYNOPSIS
	Restore equivalent ps1 from exe built by ps12exe (exe -> ps1).

.DESCRIPTION
	Uses AsmResolver to read script payload from exe:
	- For exe built with the standard program frame: reads the embedded .NET manifest resource "main.ps1" as UTF-8 to get the original script. Packed exes first unwrap the compressed "main" launcher payload and look inside it (gzip for Windows PowerShell builds, Brotli for Core builds).
	  Brotli is not available on .NET Framework, so under Windows PowerShell a Core exe is handed off to pwsh (PowerShell 7); if pwsh is missing, an error is reported.
	- For minimal exe compiled with TinySharp: parses its CIL and PE image, restores the output string and exit code captured by TinySharp,
	  and generates a minimal ps1 containing only that string (and optional exit statement) to equivalently reproduce the behavior.
	The recovered script is post-preprocessed (the #_!! escape is already stripped), so every surviving
	#_ preprocessor directive gets a #_!! escape back and stays inert if the output is recompiled; only the
	safe directives exe21sp derives from the exe itself (App.Windowed / Build.Target / Build.Platform / Os.Admin /
	Resources.* / restored #_require / #_balus) stay active.

.PARAMETER inputFile
	Path or URL to the .exe file to decompile.

.PARAMETER outputFile
	Optional path for the output ps1 file. If not specified, writes to stdout when redirected, otherwise writes to <exe>.ps1 in the same directory as the input.

.EXAMPLE
	exe21sp -inputFile .\myapp.exe
	exe21sp -inputFile .\myapp.exe -outputFile .\myapp.ps1
.EXAMPLE
	Get-ChildItem *.exe | exe21sp
	".\app.exe" | exe21sp
#>
[CmdletBinding()]
param(
	[Parameter(ValueFromPipeline = $true)]
	[string[]]$inputFile,
	[string]$outputFile,
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\src\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Locale,
	[switch]$help
)

#_if PSScript
	$global:LastExitCode = 0
	$LocalizeData = . $PSScriptRoot\src\LocaleLoader.ps1 -Locale $Locale
	. $PSScriptRoot\src\WriteI18n.ps1
	Set-I18nData -I18nData $LocalizeData.exe21spI18nData
	function Show-exe21spHelp {
		. $PSScriptRoot\src\HelpShower.ps1 -HelpData $LocalizeData.exe21spHelpData | Write-Host
	}

	if ($help) {
		Show-exe21spHelp
		return
	}

	$inputItemsToProcess = @($inputFile) + @($input) | Where-Object { $_ }
	if ($outputFile -and ($outputFile = $outputFile.Trim()) -and $outputFile -notmatch '\.ps1$') {
		$outputFile = $outputFile + '.ps1'
	}
	if ($inputItemsToProcess.Count -eq 0) {
		Show-exe21spHelp
		Write-Host
		Write-I18n Error NoneInput -Category InvalidArgument
		if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
			$global:LastExitCode = 2
			return
		}
		& $PSScriptRoot\src\Interact\exe21sp.ps1 -Locale $Locale
		return
	}

	function Resolve-ExeInputPath {
		param([string]$PathOrUrl)
		if ($PathOrUrl -match "^(https?|ftp)://") {
			$tempFile = [System.IO.Path]::GetTempFileName()
			try {
				Invoke-WebRequest -Uri $PathOrUrl -OutFile $tempFile -ErrorAction Stop
				return [PSCustomObject]@{ Path = $tempFile; IsTemp = $true }
			}
			catch {
				Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
				throw
			}
		}
		$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PathOrUrl)
		return [PSCustomObject]@{ Path = $resolved; IsTemp = $false }
	}

	# Windows PowerShell（.NET Framework）没有 BrotliStream：Core 产物的 Brotli 负载解压转交 pwsh 完成。主处理流程仅在脚本/模块模式运行（exe 版只是 #_require ps12exe 后转发），故直接用同目录脚本，无需模块导入。
	function Invoke-ExtractionInPwsh([string]$ExePath) {
		$pwsh = Get-Command pwsh -ErrorAction Ignore
		if (-not $pwsh) { throw 'pwsh not installed' }
		$tempOut = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.ps1')
		try {
			& $pwsh.Source -NoProfile -File "$PSScriptRoot\exe21sp.ps1" -inputFile $ExePath -outputFile $tempOut | Out-Null
			if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempOut)) { throw "pwsh extraction failed (exit $LASTEXITCODE)" }
			return [System.IO.File]::ReadAllText($tempOut, [System.Text.Encoding]::UTF8)
		}
		finally {
			Remove-Item -LiteralPath $tempOut -Force -ErrorAction Ignore
		}
	}

	# exe21sp 会从产物重新推导这些 pragma（窗口化 / 资源 / 图标）。往返时若保留脚本里的同名旧行，
	# 就会「转义旧行 + 追加新行」反复累积（多次往返膨胀）；因此先把同名行整行删掉（不论是否已转义），
	# 之后只由产物补唯一一份规范行。
	function Remove-DerivablePragmaLines([string]$Script) {
		if ([string]::IsNullOrEmpty($Script)) { return $Script }
		$Names = 'App\.Windowed|Resources\.(?:Title|Description|Company|Product|Copyright|Trademark|Version|Icon)|Build\.Target|Build\.Platform|Os\.Admin'
		return [regex]::Replace($Script, "(?im)^[ \t]*(?:#_!!)?#_pragma\s+(?:$Names)(?=\s|$)[^\r\n]*\r?\n?", '')
	}

	# 把值转成 #_pragma 用的单引号字面量：去掉换行，单引号双写。
	function ConvertTo-PragmaValue([string]$Value) {
		($Value -replace '\r?\n', ' ').Replace("'", "''")
	}

	# 还原 #_require 预处理生成的头代码。ps12exe 编译时把 #_require <模块> 展开成模块安装引导写入脚本，
	# 反编译时若某行与该展开结果逐字符一致（完全匹配），则还原为原来的 #_require 行；否则原样保留。
	function Restore-RequiredModulePragma([string]$Script) {
		if ([string]::IsNullOrEmpty($Script)) { return $Script }
		# 与 src/ReadScriptFile.ps1 里的 $NuGetIniter 保持一致；两处任一改动都会让完全匹配失效（安全地不还原）。
		$NuGetIniter = 'try{Import-PackageProvider NuGet}catch{Install-PackageProvider NuGet -Scope CurrentUser -Force -ea Ignore;Import-PackageProvider NuGet -ea Ignore}'
		$Nu = [regex]::Escape($NuGetIniter)

		# 单模块：#_require <模块> 展开为 if(!(gmo <模块> -ListAvailable -ea SilentlyContinue)){<NuGet>;Install-Module <模块> -Scope CurrentUser -Force -ea Stop}
		$SinglePattern = "(?m)^if\(!\(gmo (?<a>[^\r\n]+?) -ListAvailable -ea SilentlyContinue\)\)\{$Nu;Install-Module (?<b>[^\r\n]+?) -Scope CurrentUser -Force -ea Stop\}\r?$"
		$Script = [regex]::Replace($Script, $SinglePattern, {
			param($m)
			if ($m.Groups['a'].Value.Length -gt 0 -and $m.Groups['a'].Value -ceq $m.Groups['b'].Value) {
				"#_require $($m.Groups['a'].Value)"
			}
			else { $m.Value }
		})

		# 多模块（来自多行 #_require）：展开为 @('m1', 'm2')|%{if(!(gmo $_ -ListAvailable -ea SilentlyContinue)){<NuGet>;Install-Module $_ -Scope CurrentUser -Force -ea Stop}}
		$MultiPattern = '(?m)^(?<list>@\(.*?\))\|%\{if\(!\(gmo \$_ -ListAvailable -ea SilentlyContinue\)\)\{' + $Nu + ';Install-Module \$_ -Scope CurrentUser -Force -ea Stop\}\}\r?$'
		$Script = [regex]::Replace($Script, $MultiPattern, {
			param($m)
			$Names = @([regex]::Matches($m.Groups['list'].Value, "'(?<v>(?:[^']|'')*)'") | ForEach-Object { $_.Groups['v'].Value.Replace("''", "'") })
			if ($Names.Count -eq 0) { return $m.Value }
			# 重新拼出规范形式，要求与原文本逐字符一致，确保是 ps12exe 的原始展开而非用户手写。
			$Canonical = '@(' + (($Names | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ', ') + ')'
			if ($Canonical -cne $m.Groups['list'].Value) { return $m.Value }
			($Names | ForEach-Object { "#_require $_" }) -join "`n"
		})

		$Script
	}

	# 产物内嵌的是「预处理后」的脚本：`#_!!` 已被剥掉，所有以 `#_` 开头的指令行都会以注释形式残留。
	# 若原样输出，重新编译时它们会被重新解释，从而在往返中改变有效内容：`#_pragma Build.Minify` 执行
	# 编译期脚本、`#_pragma outputFile` 劫持输出路径、`#_if/#_require/#_balus/#_DllExport` 改写产物……
	# 目标是「任意 exe 往返一次后有效内容不变，注释可以改变」：把所有残留 `#_` 指令统一补回 `#_!!`
	# （`#_` 后是字母才算指令，已转义的 `#_!!` 跳过），使它们重新编译时只作为注释原样留存。
	# 之后 exe21sp 再从产物元数据补回与产物一致的安全指令（App.Windowed / Resources.*），并还原 `#_require`；
	# 这些是唯一保持活动的内容，且只依赖产物、不受脚本里可能的攻击者指令影响。
	# 注：`#_include` 在源里被 `#_!!` 转义也仍会被读取（其处理在 `#_!!` 剥离之后），但被展开的 include
	# 不会残留在产物中，故这里只会碰到惰性的畸形 include，补 `#_!!` 无害。
	function Escape-PreprocessorDirectives([string]$Script) {
		if ([string]::IsNullOrEmpty($Script)) { return $Script }
		return [regex]::Replace($Script, '(?m)^(?<indent>[ \t]*)#_(?=[A-Za-z])', '${indent}#_!!#_')
	}

	# `#_balus` 预处理会展开成一段「延迟自删除并退出」的固定代码。反编译时把这段展开代码还原回 `#_balus <exitcode>`：
	# 便于阅读，且重编译会生成逐字符相同的代码。该还原在 Escape 之后执行，保持 `#_balus` 为活动指令。
	function Restore-BalusPragma([string]$Script) {
		if ([string]::IsNullOrEmpty($Script)) { return $Script }
		$Pattern = '(?im)^(?<indent>[ \t]*)Start-Process powershell @\("-NoProfile";"-c";"sleep 1;rm `"\$PSCommandPath`""\) -WindowStyle hidden;exit (?<code>\S+)[ \t]*$'
		return [regex]::Replace($Script, $Pattern, { param($m) $m.Groups['indent'].Value + '#_balus ' + $m.Groups['code'].Value })
	}

	# 从产物的 Win32 版本资源里取回资源参数，转成从产物补回的 #_pragma 行（同名旧行已在 Remove-DerivablePragmaLines 中先删除）。
	# $Target 决定默认值语义：只有 Core（.NET SDK）会把未指定的标题/公司/产品默认成程序集名，需要按默认名过滤；
	# Framework 目标未指定时这些字段为空，任何非空值都是用户显式配置，必须原样补回，否则显式设成产物同名的
	# Product/Title 会在往返中被静默丢弃。
	function Get-ResourcePragmaLines {
		param(
			[string]$ExePath,
			[string]$Target
		)
		$Lines = [System.Collections.Generic.List[string]]::new()
		try { $VersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath) }
		catch { return $Lines }
		$Map = [ordered]@{
			'Resources.Title'       = 'FileDescription'
			'Resources.Description' = 'Comments'
			'Resources.Company'     = 'CompanyName'
			'Resources.Product'     = 'ProductName'
			'Resources.Copyright'   = 'LegalCopyright'
			'Resources.Trademark'   = 'LegalTrademarks'
			'Resources.Version'     = 'FileVersion'
		}
		# .NET SDK（Core 目标）会把未指定的标题/公司/产品默认成程序集名、版本默认成 1.0.0.0，这些不是用户配置，别当成资源参数补回。
		$ExeBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath)
		$DefaultNames = @($ExeBaseName, ($ExeBaseName -replace '[^\w\.\-]', '_')) |
		Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }
		$DefaultVersions = @('1.0.0.0', '1.0.0', '0.0.0.0')
		$IsCore = $Target -eq 'Core'
		foreach ($Key in $Map.Keys) {
			$Value = $VersionInfo.($Map[$Key])
			if ([string]::IsNullOrWhiteSpace($Value)) { continue }
			if ($IsCore -and $Key -in @('Resources.Title', 'Resources.Company', 'Resources.Product') -and $DefaultNames -contains $Value.ToLowerInvariant()) { continue }
			if ($Key -eq 'Resources.Version' -and $DefaultVersions -contains $Value) { continue }
			$Lines.Add("#_pragma $Key '$(ConvertTo-PragmaValue $Value)'")
		}
		$Lines
	}

	$Refs = @(
		'System',
		'System.Core',
		'System.IO.Compression',
		'netstandard, Version=2.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'
	)
	Get-ChildItem -LiteralPath $PSScriptRoot\src\bin\AsmResolver -Recurse -Filter *.dll | ForEach-Object {
		$Refs += $_.FullName
		try {
			Add-Type -LiteralPath $_.FullName -ErrorVariable $null
		}
		catch {
			$_.Exception.LoaderExceptions | Out-String | Write-Verbose
			$Error.Remove($_)
		}
	}
	# exe21sp.cs 用到 LzmaCodec（解压 LZMA 负载），与 LzmaDecode.cs 一起编译（多源文件用 -Path）。
	Add-Type -Path @(
		(Join-Path $PSScriptRoot 'src\programFrames\exe21sp.cs'),
		(Join-Path $PSScriptRoot 'src\programFrames\LzmaDecode.cs')
	) -ReferencedAssemblies $Refs -IgnoreWarnings

	. $PSScriptRoot\src\TaskbarProgress.ps1
	$total = $inputItemsToProcess.Count
	$currentIndex = 0
	foreach ($currentInput in $inputItemsToProcess) {
		Write-TaskbarProgress -Percent ([Math]::Min(100, [int](($currentIndex / $total) * 100)))
		$resolved = $null
		try {
			$resolved = Resolve-ExeInputPath -PathOrUrl $currentInput
		}
		catch {
			if ($currentInput -match "^(https?|ftp)://") {
				Write-I18n Error InputUrlFailed $currentInput
			}
			else {
				Write-I18n Error FileNotFound $currentInput
			}
			$global:LastExitCode = 3
			Write-TaskbarProgressError
			$currentIndex++
			continue
		}
		$currentExe = $resolved.Path
		if (-not (Test-Path -LiteralPath $currentExe -PathType Leaf)) {
			Write-I18n Error FileNotFound $currentInput
			$global:LastExitCode = 3
			Write-TaskbarProgressError
			if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
			$currentIndex++
			continue
		}
		try {
			$script = [exe21sp.Extractor]::ExtractScriptFromExe($currentExe)
		}
		catch [exe21sp.BrotliUnavailableException] {
			# 当前是 Windows PowerShell，Core 的 Brotli 负载交给 pwsh 解压。
			try {
				$script = Invoke-ExtractionInPwsh -ExePath $currentExe
			}
			catch {
				Write-I18n Error CoreExtractNeedsPwsh
				$global:LastExitCode = 1
				Write-TaskbarProgressError
				if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
				$currentIndex++
				continue
			}
		}
		catch {
			$msg = $_.Exception.Message
			if ($LocalizeData.exe21spI18nData.ContainsKey($msg)) {
				Write-I18n Error $msg
			}
			else {
				Write-Error $msg
			}
			$global:LastExitCode = 1
			Write-TaskbarProgressError
			if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
			$currentIndex++
			continue
		}
		if ($null -eq $script) {
			Write-I18n Error NoEmbeddedScript $currentInput
			$global:LastExitCode = 1
			Write-TaskbarProgressError
			if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }
			$currentIndex++
			continue
		}

		# 先删掉产物会重新推导的 pragma 行（窗口化 / 资源 / 图标，不论是否已转义），避免往返累积。
		$script = Remove-DerivablePragmaLines $script

		# 再给其余残留的 `#_` 指令补回 `#_!!`，使它们重新编译时只作为注释留存。
		$script = Escape-PreprocessorDirectives $script

		# 还原编译期由 #_require 展开的模块安装引导头代码（仅完全匹配时）；在转义之后补回，保持活动。
		$script = Restore-RequiredModulePragma $script

		# 把 #_balus 展开出的自删除代码还原回 `#_balus <exitcode>`（在转义之后，保持活动）。
		$script = Restore-BalusPragma $script

		# 从产物重新推导 windowed / Win32 资源 / 构建目标与平台 / 管理员权限 / 图标：这些是唯一保持活动的指令，
		# 只依赖产物而不受脚本里可能的攻击者指令影响；图标释放到输出目录并用 #_pragma Resources.Icon 引用。
		$PrefixLines = [System.Collections.Generic.List[string]]::new()
		if ([exe21sp.Extractor]::IsWindowedExe($currentExe)) {
			$PrefixLines.Add('#_pragma App.Windowed')
		}
		$Target = [exe21sp.Extractor]::GetTarget($currentExe)
		if ($Target) {
			$PrefixLines.Add("#_pragma Build.Target '$Target'")
		}
		$Platform = [exe21sp.Extractor]::GetPlatform($currentExe)
		if ($Platform -and $Platform -ne 'anycpu') {
			$PrefixLines.Add("#_pragma Build.Platform '$Platform'")
		}
		if ([exe21sp.Extractor]::IsAdminExe($currentExe)) {
			$PrefixLines.Add('#_pragma Os.Admin')
		}
		foreach ($Line in (Get-ResourcePragmaLines -ExePath $currentExe -Target $Target)) {
			$PrefixLines.Add($Line)
		}
		$IconBytes = [exe21sp.Extractor]::ExtractIconFromExe($currentExe)

		$isRedirected = [System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected
		$inputBaseName = if ($currentInput -match "^(https?|ftp)://") {
			[System.IO.Path]::GetFileNameWithoutExtension([System.Uri]::new($currentInput).Segments[-1])
		}
		else {
			[System.IO.Path]::GetFileNameWithoutExtension($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentInput))
		}
		$currentOutFile = $outputFile
		if (-not $currentOutFile -and -not $isRedirected) {
			$dir = if ($currentInput -match "^(https?|ftp)://") { $PWD.Path } else { [System.IO.Path]::GetDirectoryName($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentInput)) }
			$currentOutFile = [System.IO.Path]::Combine($dir, "$inputBaseName.ps1")
		}
		$releaseDir = $PWD.Path
		$releaseBaseName = $inputBaseName
		if ($currentOutFile) {
			$currentOutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($currentOutFile)
			$releaseDir = [System.IO.Path]::GetDirectoryName($currentOutFile)
			$releaseBaseName = [System.IO.Path]::GetFileNameWithoutExtension($currentOutFile)
		}

		if ($null -ne $IconBytes -and $IconBytes.Length -gt 0) {
			if (-not (Test-Path -LiteralPath $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null }
			$iconName = "$releaseBaseName.ico"
			$iconPath = [System.IO.Path]::Combine($releaseDir, $iconName)
			[System.IO.File]::WriteAllBytes($iconPath, $IconBytes)
			Write-Verbose "Released resource file to $iconPath"
			$PrefixLines.Add("#_pragma Resources.Icon `"`$PSScriptRoot/$iconName`"")
		}

		if ($PrefixLines.Count -gt 0) {
			# 去掉脚本开头的空行再拼接，否则上一轮留下的分隔空行会随每次往返累积（膨胀）。
			$script = $script -replace '^[\r\n]+', ''
			$script = (($PrefixLines -join "`n") + "`n`n" + $script)
		}

		if ($resolved.IsTemp) { Remove-Item -LiteralPath $currentExe -Force -ErrorAction SilentlyContinue }

		if ($currentOutFile) {
			[System.IO.File]::WriteAllText($currentOutFile, $script, [System.Text.UTF8Encoding]::new($false))
			Write-Verbose "Written to $currentOutFile"
			if ($isRedirected) {
				Write-Output $currentOutFile
			}
		}
		else {
			Write-Output $script
		}
		$currentIndex++
	}
	Write-TaskbarProgress -Percent 100
	Write-TaskbarProgressClear
#_else
	#_require ps12exe
	#_!!exe21sp @PSBoundParameters
#_endif
