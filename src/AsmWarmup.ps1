# 后台预热 ExeSinker/AsmResolver：首次装载 + JIT 约 0.4~0.5s，和随后的帧组装 / payload 构建并行跑，
# 等主线程真正解析、重建 PE 时方法已经 JIT 好（.NET JIT 是进程级的）。没有可用样本或预热失败都不影响编译。

# 起一个后台 runspace 跑一次 ExeSinker（拿 codedom 缓存里现成的帧模板当样本），返回该 runspace 供收尾。
function Start-AsmWarmup([string]$RepoRoot) {
	if ($env:PS12EXE_NO_ASM_WARMUP) { return $null }
	try {
		$warmup = [System.Management.Automation.PowerShell]::Create()
		$null = $warmup.AddScript({
				param($RepoRoot, $CodedomRoot)
				try {
					$sample = Get-ChildItem -LiteralPath $CodedomRoot -Filter 'frame_*.exe' -ErrorAction Ignore | Select-Object -First 1
					if (-not $sample) { return }
					$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ps12exe-warm-" + [Guid]::NewGuid().ToString('N') + '.exe')
					Copy-Item -LiteralPath $sample.FullName -Destination $tmp -Force
					try { & (Join-Path $RepoRoot 'src/ExeSinker.ps1') $tmp -removeResources }
					catch {}
					Remove-Item -LiteralPath $tmp -Force -ErrorAction Ignore
				}
				catch {}
			}).AddArgument($RepoRoot).AddArgument((Get-CacheRoot 'codedom'))
		$null = $warmup.BeginInvoke()
		return $warmup
	}
	catch { return $null }
}

function Stop-AsmWarmup($Warmup) {
	if (-not $Warmup) { return }
	try { $Warmup.Stop() } catch {}
	try { $Warmup.Dispose() } catch {}
}
