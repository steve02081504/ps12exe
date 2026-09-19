# locale 测试：各语言数据键一致、可加载；帮助渲染覆盖所有参数键。
Add-Test @{
	Name  = 'locale.data-consistency'
	Group = 'locale'
	Deps  = @('src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		function Get-KeyTree($ht, $prefix) {
			$out = @()
			foreach ($k in $ht.Keys) {
				$path = if ($prefix) { "$prefix.$k" } else { "$k" }
				if ($ht[$k] -is [System.Collections.IDictionary]) { $out += Get-KeyTree $ht[$k] $path }
				else { $out += $path }
			}
			return $out
		}
		$localeDir = Join-Path $ctx.RepoRoot 'src/locale'
		$files = @(Get-ChildItem -LiteralPath $localeDir -Filter '??-??.ps1' -File)
		Assert-True ($files.Count -ge 6) "locale 文件过少：$($files.Count)"
		$dataMap = @{}
		foreach ($f in $files) { $dataMap[$f.BaseName] = & $f.FullName }
		Assert-True $dataMap.ContainsKey('en-US') 'en-US locale 缺失'
		$ref = $dataMap['en-US']
		$refTop = @($ref.Keys)
		$refHelp = @(Get-KeyTree $ref.ConsoleHelpData.PrarmsData '')
		foreach ($name in $dataMap.Keys) {
			$d = $dataMap[$name]
			Assert-Equal $name $d.LangID "LangID 应为文件名"
			Assert-True ($d.ContainsKey('ConsoleHelpData')) "$name 缺少 ConsoleHelpData"
			foreach ($key in $refTop) { Assert-True ($d.ContainsKey($key)) "$name 缺少顶层键 $key" }
			$curHelp = @(Get-KeyTree $d.ConsoleHelpData.PrarmsData '')
			$missing = @($refHelp | Where-Object { $_ -notin $curHelp })
			$extra = @($curHelp | Where-Object { $_ -notin $refHelp })
			Assert-True ($missing.Count -eq 0) "$name 缺少帮助键：$($missing -join ',')"
			Assert-True ($extra.Count -eq 0) "$name 多出帮助键：$($extra -join ',')"
			Assert-True ([bool]$d.ConsoleHelpData.Usage) "$name 的 Usage 为空"
		}
	}
}

Add-Test @{
	Name  = 'locale.path-traversal-blocked'
	Group = 'locale'
	Deps  = @('src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		$loader = Join-Path $ctx.RepoRoot 'src/LocaleLoader.ps1'
		# 正常名字仍可加载
		$en = & $loader -Locale 'en-US' 3>$null
		Assert-Equal 'en-US' $en.LangID '合法 locale 未被加载'

		# locale 目录外的 .ps1 不得被执行
		$marker = Join-Path $ctx.WorkDir 'locale-pwned.txt'
		Remove-Item -LiteralPath $marker -ErrorAction Ignore
		$payloadDir = Join-Path $ctx.WorkDir 'locale-payload'
		New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
		[System.IO.File]::WriteAllText((Join-Path $payloadDir 'pwn.ps1'), "Set-Content -LiteralPath '$marker' -Value pwned", [System.Text.UTF8Encoding]::new($true))
		$localeDir = Join-Path $ctx.RepoRoot 'src/locale'
		$rel = [System.IO.Path]::GetRelativePath($localeDir, $payloadDir) + [System.IO.Path]::DirectorySeparatorChar + 'pwn'
		$data = & $loader -Locale $rel 3>$null
		Assert-False (Test-Path -LiteralPath $marker) "LocaleLoader 执行了 locale 目录外的脚本：$rel"
		Assert-True ([bool]$data.LangID) 'locale 穿越未回退到有效语言'
	}
}

Add-Test @{
	Name  = 'locale.help-renders'
	Group = 'locale'
	Deps  = @('src/locale/', 'src/HelpShower.ps1', 'src/VirtualTerminal.ps1')
	Run   = {
		param($ctx)
		$localeDir = Join-Path $ctx.RepoRoot 'src/locale'
		$shower = Join-Path $ctx.RepoRoot 'src/HelpShower.ps1'
		foreach ($f in (Get-ChildItem -LiteralPath $localeDir -Filter '??-??.ps1' -File)) {
			$data = & $f.FullName
			$helpData = $data.ConsoleHelpData
			$out = (. $shower -HelpData $helpData) -join "`n"
			Assert-True ($out.Length -gt 200) "$($f.BaseName) 帮助渲染过短"
			foreach ($key in $helpData.PrarmsData.Keys) {
				Assert-Match $out ([regex]::Escape([string]$key)) "$($f.BaseName) 帮助缺少参数 $key"
			}
		}
	}
}
