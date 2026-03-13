#Requires -Version 5.1
<#
.SYNOPSIS
	从 ps12exe 生成的 exe 中还原出等价的 ps1（exe -> ps1）。

.DESCRIPTION
	使用 AsmResolver 读取 exe 中的脚本负载：
	- 对于标准程序框架（CodeDom/CodeAnalysis）生成的 exe：读取嵌入的 .NET 清单资源 "main.par"，GZip 解压并按 UTF-8 解码，得到原始脚本。
	- 对于 TinySharp 编译的极小 exe：解析其 CIL 和 PE 映像，还原 TinySharp 捕获的输出字符串和退出码，
	  生成一个只包含该字符串（及可选 exit 语句）的极简 ps1，以在行为上等价复现。

.PARAMETER ExePath
	要反编译的 .exe 文件路径。

.PARAMETER OutFile
	可选，要写出的 ps1 文件路径。不指定时输出到标准输出。

.EXAMPLE
	exe21sp -ExePath .\myapp.exe
	exe21sp -ExePath .\myapp.exe -OutFile .\myapp.ps1
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $false, Position = 0)]
	[string]$ExePath,

	[Parameter(Mandatory = $false)]
	[string]$OutFile,

	[Parameter(Mandatory = $false)]
	[switch]$help
)

function Show-Exe21spHelp {
	$LocalizeData = . $PSScriptRoot\src\LocaleLoader.ps1
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $LocalizeData.exe21spHelpData | Write-Host
}

if ($help -or $ExePath -eq '-help' -or $ExePath -eq '--help') {
	Show-Exe21spHelp
	return
}

if (-not $PSBoundParameters.Count -and -not $args.Count) {
	Show-Exe21spHelp
	if ([System.Console]::IsOutputRedirected -or [System.Console]::IsInputRedirected -or [System.Console]::IsErrorRedirected) {
		return
	}
	& $PSScriptRoot\src\Interact\exe21sp.ps1
	return
}

if (-not $ExePath) {
	Write-Error "exe21sp: -ExePath is required. Use -help for usage."
	exit 1
}

$ErrorActionPreference = 'Stop'
$ExePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
	Write-Error "File not found: $ExePath"
	exit 1
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
	} catch {
		$_.Exception.LoaderExceptions | Out-String | Write-Verbose
		$Error.Remove($_)
	}
}

$ExtractorCode = Get-Content -LiteralPath $PSScriptRoot\src\programFrames\exe21sp.cs -Raw -Encoding UTF8
Add-Type -TypeDefinition $ExtractorCode -ReferencedAssemblies $Refs -IgnoreWarnings

$script = [exe21sp.Extractor]::ExtractScriptFromExe($ExePath)
if ($null -eq $script) {
	Write-Error "No embedded script found in '$ExePath' (not a ps12exe-built exe, or payload cannot be recovered)."
	exit 1
}

if (-not $OutFile -and -not [System.Console]::IsOutputRedirected) {
	$dir = [System.IO.Path]::GetDirectoryName($ExePath)
	$name = [System.IO.Path]::GetFileNameWithoutExtension($ExePath)
	$OutFile = [System.IO.Path]::Combine($dir, "$name.ps1")
}

if ($OutFile) {
	$OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
	[System.IO.File]::WriteAllText($OutFile, $script, [System.Text.UTF8Encoding]::new($false))
	Write-Verbose "Written to $OutFile"
} else {
	Write-Output $script
}
