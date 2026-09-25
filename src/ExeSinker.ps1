[CmdletBinding()]
param (
	[string]$inputFile,
	[switch]$removeResources,
	[switch]$removeVersionInfo
)

# AsmResolver 已由 Update-AsmResolver.ps1 裁剪并合并成单个 src/bin/AsmResolver.dll。
try {
	Add-Type -LiteralPath (Join-Path $PSScriptRoot 'bin/AsmResolver.dll') -ErrorVariable $null
}
catch {
	$_.Exception.LoaderExceptions | Out-String | Write-Verbose
	$Error.Remove($_)
}

$file = [AsmResolver.PE.PEImage]::FromFile($inputFile)
if ($removeResources) {
	$file.Resources = $null
}
elseif ($removeVersionInfo) {
	$file.Resources.Entries.Remove(($file.Resources.Entries | Where-Object { $_.Type -eq 'Version' })) | Out-Null
}
$file.DllCharacteristics = $file.DllCharacteristics -band -not [AsmResolver.PE.File.DllCharacteristics]::DynamicBase
$Builder = New-Object AsmResolver.PE.Builder.ManagedPEFileBuilder
$file = $builder.CreateFile($file)
$file.Write($inputFile)
