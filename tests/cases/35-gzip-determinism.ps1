Add-Test @{
	Name  = 'ps12exe.gzip.deterministic-roundtrip'
	Group = 'ps12exe'
	Deps  = @('src/Gzip.ps1', 'src/programFrames/GzipEncode.cs', 'src/programFrames/GzipWrapper.cs', 'src/Cache.ps1', 'src/Lzma.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/Cache.ps1')
		. (Join-Path $ctx.RepoRoot 'src/Lzma.ps1')
		. (Join-Path $ctx.RepoRoot 'src/Gzip.ps1')
		function Expand-TestGzip([byte[]]$Packed) {
			$inputStream = [IO.MemoryStream]::new($Packed, $false)
			$decoder = [IO.Compression.GZipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress)
			$outputStream = [IO.MemoryStream]::new()
			try { $decoder.CopyTo($outputStream); return , $outputStream.ToArray() }
			finally { $outputStream.Dispose(); $decoder.Dispose(); $inputStream.Dispose() }
		}
		$data = [IO.File]::ReadAllBytes((Join-Path $ctx.RepoRoot 'src/programFrames/default.cs'))
		$random = [byte[]]::new(131073)
		[Random]::new(1234).NextBytes($random)
		foreach ($bytes in @([byte[]]@(), [byte[]]@(0, 255, 1), $data, $random, [byte[]]::new(65536))) {
			$packed = Compress-Gzip $bytes
			Assert-Equal (Get-Sha256Hex $bytes) (Get-Sha256Hex (Expand-TestGzip $packed)) 'gzip roundtrip including block boundaries and incompressible data'
			Assert-Equal ([Convert]::ToBase64String($packed)) ([Convert]::ToBase64String((Compress-Gzip $bytes))) 'Repeated encoding must be byte-identical'
			Assert-Equal '1F-8B-08-00-00-00-00-00-02-FF' ([BitConverter]::ToString($packed[0..9])) 'Fixed gzip header'
		}
		Assert-Equal 'H4sIAAAAAAAC/8tIzcnJV0AiAYCI+eURAAAA' ([Convert]::ToBase64String((Compress-Gzip ([Text.Encoding]::UTF8.GetBytes('hello hello hello'))))) 'Pinned encoder golden vector'
		$before = [Convert]::ToBase64String((Compress-Gzip $data))
		$savedPath = $env:PATH
		try {
			$env:PATH = ''
			Assert-Equal $before ([Convert]::ToBase64String((Compress-Gzip $data))) 'Bundled encoder works with empty PATH'
		}
		finally { $env:PATH = $savedPath }
		# Golden streams were compared byte-for-byte against the pinned native
		# 7-Zip core (9/258/15), covering stored blocks, tree wrapping and splitting.
		$pattern = [byte[]]::new(65536)
		for ($i = 0; $i -lt $pattern.Length; $i++) { $pattern[$i] = ($i * 13 + [math]::Floor($i / 257)) % 256 }
		$functions = [Text.Encoding]::UTF8.GetBytes(((1..1500 | ForEach-Object { "function F$_ { param(`$x) Write-Output (`$x + $_) }" }) -join "`n"))
		foreach ($vector in @(
			@{ Data = [byte[]]::new(65536); Hash = 'EB4DDD8BB4EDF16771B14EF8FCB0A7D59E1528B52FE6F8A25F9D411564BE748F' },
			@{ Data = $random; Hash = '8C1A5FD5C9F5232C23093AFA07A133926F70CF965C42851EE7DFF629A072BB60' },
			@{ Data = $pattern; Hash = '063CBE9DF7A8CB4F65809201FAC164E1E0C9283118E909C2E6454731F3E20094' },
			@{ Data = $functions; Hash = 'DF8F5741127CF89CC36E03F719D2C1864CB50E163C15F6B58793B5767112BDA4' }
		)) {
			Assert-Equal $vector.Hash (Get-Sha256Hex (Compress-Gzip $vector.Data)) 'Managed encoder retains the native maximum-profile stream'
		}
		$inputPath = Join-Path $ctx.WorkDir 'gzip-input.bin'
		[IO.File]::WriteAllBytes($inputPath, $data)
		$probe = Join-Path $ctx.WorkDir 'gzip-probe.ps1'
		[IO.File]::WriteAllText($probe, @'
param($RepoRoot, $InputPath)
. (Join-Path $RepoRoot 'src/Cache.ps1')
. (Join-Path $RepoRoot 'src/Lzma.ps1')
. (Join-Path $RepoRoot 'src/Gzip.ps1')
[Convert]::ToBase64String((Compress-Gzip ([IO.File]::ReadAllBytes($InputPath))))
'@, [Text.UTF8Encoding]::new($true))
		$expected = [Convert]::ToBase64String((Compress-Gzip $data))
		foreach ($shell in @('powershell.exe', 'pwsh.exe', (Join-Path $env:WINDIR 'SysWOW64/WindowsPowerShell/v1.0/powershell.exe'))) {
			$actual = & $shell -NoProfile -File $probe $ctx.RepoRoot $inputPath
			Assert-Equal 0 $LASTEXITCODE "Encoder works in $shell"
			Assert-Equal $expected ($actual -join '') "Fresh $shell process must produce identical gzip bytes"
		}
	}
}

Add-Test @{
	Name  = 'ps12exe.pack.deterministic-cold-caches'
	Group = 'ps12exe'
	Deps  = $script:CoreCompileDeps
	Run   = {
		param($ctx)
		$probe = Join-Path $ctx.WorkDir 'compile-probe.ps1'
		[IO.File]::WriteAllText($probe, @'
param($RepoRoot, $CacheRoot, $InputPath, $OutputPath)
$ErrorActionPreference = 'Stop'
$env:TEMP = $CacheRoot
$env:TMP = $CacheRoot
Import-Module (Join-Path $RepoRoot 'ps12exe.psd1') -Force
ps12exe -InputFile $InputPath -OutputFile $OutputPath -Build @{ConstEval=@{Enabled=$false}} -NoUpdateCheck -Quiet -Locale en-US | Out-Null
if (-not (Test-Path -LiteralPath $OutputPath)) { throw 'Compiler did not produce an exe' }
(Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
'@, [Text.UTF8Encoding]::new($true))
		$inputPath = Join-Path $ctx.WorkDir 'input.ps1'
		[IO.File]::WriteAllText($inputPath, 'param($Name="World"); Write-Output "Hello $Name"', [Text.UTF8Encoding]::new($true))
		$hashes = foreach ($name in @('first', 'second')) {
			$directory = Join-Path $ctx.WorkDir $name
			$cache = Join-Path $directory 'cache'
			New-Item -ItemType Directory -Path $cache -Force | Out-Null
			$output = Join-Path $directory 'output.exe'
			$hash = & powershell.exe -NoProfile -File $probe $ctx.RepoRoot $cache $inputPath $output
			Assert-Equal 0 $LASTEXITCODE 'Compile with an isolated cold cache'
			$hash -join ''
		}
		Assert-Equal $hashes[0] $hashes[1] 'Independent cold builds must produce byte-identical complete executables'
		. (Join-Path $ctx.RepoRoot 'src/Cache.ps1')
		$output = Join-Path $ctx.WorkDir 'first/output.exe'
		$bytes = [IO.File]::ReadAllBytes($output)
		Assert-Equal (Get-Sha256Hex $bytes) (Get-Sha256Hex (Set-DeterministicPeIdentity ([byte[]]$bytes.Clone()))) 'PE normalization is idempotent'
		$result = Invoke-ExeCaptureMergedOutput -ExePath $output
		Assert-Equal 0 $result.ExitCode 'Normalized executable runs'
		Assert-Equal 'Hello World' $result.Output.Trim() 'Normalization preserves runtime behavior'
	}
}
