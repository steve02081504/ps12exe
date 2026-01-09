# 重新构建编译内容
$ConstResult = $RowResult | ForEach-Object {
	(($_ | Out-String) -replace '\r\n$', '')
}
$ConstResult = $ConstResult -join "`n"

# 对于$PSScriptRoot\bin\AsmResolver下的所有dll文件
$Refs = @(
	'System',
	'System.Core',
	'netstandard, Version=2.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'
)
Get-ChildItem $PSScriptRoot\bin\AsmResolver -Recurse -Filter *.dll | ForEach-Object {
	$Refs += $_.FullName
	try {
		Add-Type -LiteralPath $_.FullName -ErrorVariable $null
	}
	catch {
		$_.Exception.LoaderExceptions | Out-String | Write-Verbose
		$Error.Remove($_)
	}
}

# 添加c#代码
$TinySharpCode = Get-Content $PSScriptRoot/programFrames/TinySharp.cs -Raw -Encoding UTF8
Add-Type $TinySharpCode -ReferencedAssemblies $Refs

# 编译
$file = [TinySharp.Program]::Compile($targetRuntime, $architecture, $ConstResult, [ps12exeConstEvalHost]::LastExitCode, -not $noOutput)
if ($iconFile) {
	$file.SetWin32Icon($iconFile)
}
if ($description -or $company -or $title -or $product -or $copyright -or $trademark -or $version) {
	$file.SetAssemblyInfo($description, $company, $title, $product, $copyright, $trademark, $version)
}
$file.Build($outputFile)
