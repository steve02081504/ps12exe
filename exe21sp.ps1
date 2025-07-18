param (
    [Parameter(Mandatory = $true)]
    [string]$inputFile
)

try {
    if (-not (Test-Path -Path $inputFile -PathType Leaf)) {
        Write-Error "Input file not found or is not a file: $inputFile"
        return
    }

    Get-ChildItem $PSScriptRoot/src/bin/AsmResolver -Recurse -Filter AsmResolver.PE*.dll | ForEach-Object {
        try {
            Add-Type -LiteralPath $_.FullName -ErrorVariable err
        } catch {
            $_.Exception.LoaderExceptions | Out-String | Write-Verbose
            $Error.Remove($_)
        }
    }

    $file = [AsmResolver.PE.PEImage]::FromFile($inputFile)
	$file.Resources.Entries
    $resource = $file.Resources.Entries | Where-Object { $_.Name -eq 'main.ps1' }

    if ($resource) {
        $resourceStream = $resource.EmbeddedData.GetReader().AsStream()
        $reader = New-Object System.IO.StreamReader($resourceStream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $resourceStream.Close()

        Set-Content -Path "main.ps1" -Value $content -Encoding UTF8
        Write-Host "Successfully extracted main.ps1"
    } else {
        Write-Error "Could not find resource 'main.ps1' in the executable."
    }
}
catch {
    Write-Error "An error occurred: $_"
}
