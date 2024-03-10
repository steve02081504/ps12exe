[CmdletBinding()]
param (
	[string]$inputFile,
	[switch]$removeResources
)

Get-ChildItem $PSScriptRoot\bin\AsmResolver -Recurse -Filter AsmResolver.PE*.dll | ForEach-Object {
	try{
		Add-Type -LiteralPath $_.FullName -ErrorVariable $null
	} catch {
		$_.Exception.LoaderExceptions | Out-String | Write-Verbose
		$Error.Remove($_)
	}
}

$file = [AsmResolver.PE.PEImage]::FromFile($inputFile)
if ($removeResources) {
	$file.Resources = $null
}
$file.DllCharacteristics = $file.DllCharacteristics -band -not [AsmResolver.PE.File.Headers.DllCharacteristics]::DynamicBase;
$Builder = New-Object AsmResolver.PE.DotNet.Builder.ManagedPEFileBuilder
$file = $builder.CreateFile($file)
$file.Write($inputFile)
