param([string]$WorkDir = (Join-Path ([IO.Path]::GetTempPath()) "ps12exe-self-$([guid]::NewGuid().ToString('N'))"))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'MacOS' } else { 'Linux' }
$extension = if ($IsWindows) { '.exe' } else { '.bin' }
$self = Join-Path $WorkDir "ps12exe-self$extension"
& (Join-Path $repo 'ps12exe.ps1') -inputFile (Join-Path $repo 'ps12exe.ps1') -outputFile $self -Build @{ Target = 'Core'; Core = @{ TargetOs = $os } } -NoUpdateCheck -Quiet
if (-not (Test-Path $self)) { throw 'Self compilation produced no apphost' }
function Enable-AppHost([string]$Path) {
	if (-not $IsWindows) {
		& chmod +x $Path
		if ($LASTEXITCODE) { throw "chmod failed: $Path" }
	}
}
Enable-AppHost $self
Push-Location $WorkDir
try {
	$helpText = & $self -help 2>&1 | Out-String
	if ($LASTEXITCODE -ne 0 -or $helpText -notmatch 'Build') { throw "Self apphost help failed: $helpText" }
	$source = Join-Path $WorkDir 'probe.ps1'
	[IO.File]::WriteAllText($source, @'
Add-Type -TypeDefinition 'public static class SelfProbe { public static string Value() { return "native-self-ok"; } }'
Get-Date | Out-Null
Write-Output ([SelfProbe]::Value())
'@, [Text.UTF8Encoding]::new($true))
	$native = Join-Path $WorkDir "native$extension"
	& $self $source $native -Build "@{Target='Core';Core=@{TargetOs='$os'}}" -NoUpdateCheck -Quiet
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path $native)) { throw 'Second native compilation failed' }
	Enable-AppHost $native
	$output = & $native 2>&1 | Out-String
	if ($LASTEXITCODE -ne 0 -or $output -notmatch 'native-self-ok') { throw "Native apphost failed: $output" }
	$windows = Join-Path $WorkDir 'windows.exe'
	& $self $source $windows -Build "@{Target='Core';Platform='x64';Core=@{TargetOs='Windows'}}" -NoUpdateCheck -Quiet
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path $windows)) { throw 'Windows cross compilation failed' }
	$bytes = [IO.File]::ReadAllBytes($windows)
	if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw 'Windows output is not a PE apphost' }
	Write-Host "PASS: $os self compilation, native execution, Windows cross compilation"
}
finally { Pop-Location }
