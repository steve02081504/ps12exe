[CmdletBinding()]
param (
	[string]$inputFile,
	[switch]$removeResources
)

Get-ChildItem $PSScriptRoot\bin\AsmResolver -Recurse -Filter *.dll | ForEach-Object {
	Write-Verbose "Load $($_.FullName)"
	try{
		Add-Type -Path $_.FullName -ErrorAction Stop
	}
	catch {
		Write-Error $_.InnerException.LoaderExceptions -ErrorAction Ignore
	}
}

$file = [AsmResolver.PE.PEImage]::FromFile($inputFile)
if ($removeResources) {
	$file.Resources = $null
}
$Builder = New-Object AsmResolver.PE.DotNet.Builder.ManagedPEFileBuilder
$file = $builder.CreateFile($file)
$file.Write($inputFile)
