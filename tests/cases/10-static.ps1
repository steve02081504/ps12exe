# 静态检查：全部 PowerShell 源可解析、编码约定（.ps1/.cs 带 BOM，其它无 BOM）。
Add-Test @{
	Name  = 'static.powershell-parses'
	Group = 'static'
	Deps  = @()
	Run   = {
		param($ctx)
		$files = @(Get-RepoFiles -RepoRoot $ctx.RepoRoot -Extensions @('.ps1', '.psm1', '.psd1'))
		Assert-True ($files.Count -gt 20) "预期扫描到多个 PowerShell 文件，实际 $($files.Count)"
		$failures = @()
		foreach ($f in $files) {
			$errors = $null
			[void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
			if ($errors.Count -gt 0) {
				$failures += "$($f.FullName): " + (($errors | ForEach-Object { $_.Message }) -join '; ')
			}
		}
		Assert-True ($failures.Count -eq 0) ("解析失败：`n" + ($failures -join "`n"))
	}
}

Add-Test @{
	Name  = 'static.encoding-bom'
	Group = 'static'
	Deps  = @()
	Run   = {
		param($ctx)
		$missing = @()
		foreach ($f in (Get-RepoFiles -RepoRoot $ctx.RepoRoot -Extensions @('.ps1', '.psm1', '.psd1', '.cs'))) {
			$b = [System.IO.File]::ReadAllBytes($f.FullName)
			if ($b.Length -lt 3 -or $b[0] -ne 0xEF -or $b[1] -ne 0xBB -or $b[2] -ne 0xBF) {
				$missing += $f.FullName.Substring($ctx.RepoRoot.Length + 1)
			}
		}
		Assert-True ($missing.Count -eq 0) ("PowerShell/C# 源缺少 UTF-8 BOM：`n" + ($missing -join "`n"))

		$unexpected = @()
		foreach ($f in (Get-RepoFiles -RepoRoot $ctx.RepoRoot -Extensions @('.md', '.json', '.yaml', '.yml', '.fbs', '.txt', '.html'))) {
			$b = [System.IO.File]::ReadAllBytes($f.FullName)
			if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
				$unexpected += $f.FullName.Substring($ctx.RepoRoot.Length + 1)
			}
		}
		Assert-True ($unexpected.Count -eq 0) ("非脚本文件带上了 BOM：`n" + ($unexpected -join "`n"))
	}
}
