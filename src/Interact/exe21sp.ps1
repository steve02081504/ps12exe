# Interactive loop for exe21sp (invoked when exe21sp is run with no arguments and console is not redirected).
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$exe21spScript = Join-Path $repoRoot 'exe21sp.ps1'

while ($true) {
	$exe = Read-Host "Enter path to ps12exe-generated exe (blank to quit)"
	if (-not $exe) { break }
	$out = Read-Host "Enter output ps1 path (blank to use <exe>.ps1 in the same folder)"
	try {
		if (Get-Command exe21sp -ErrorAction SilentlyContinue) {
			exe21sp -ExePath $exe -OutFile $out
		} else {
			& $exe21spScript -ExePath $exe -OutFile $out
		}
	} catch {
		Write-Error $_
	}
	$cont = Read-Host "Convert another exe? [Y/N]"
	if ($cont -notin @('Y', 'y')) { break }
}
