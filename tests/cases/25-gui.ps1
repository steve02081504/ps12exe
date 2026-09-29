# GUI 测试：schema 与 GUI 文案/帮助数据一致、窗体布局不截断不重叠、UIData↔参数/路径、后台编译。
# 纯 Run，无构建；WinForms 操作统一走 Invoke-GUIScriptBlock 的 STA runspace。
Add-Test @{
	Name  = 'gui.schema-coverage'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/GUI/Schema.ps1')
		$schema = Get-GUISchema

		$fieldPaths = @()
		foreach ($page in $schema.Pages) {
			foreach ($group in $page.Groups) {
				foreach ($field in $group.Fields) { $fieldPaths += [string]$field.Path }
			}
		}
		$excluded = @($schema.ExcludedHelpPaths | ForEach-Object { [string]$_ })

		# 把嵌套哈希表摊平成 点号路径 → 叶子值，用于校验各语言文案键完整性。
		function Get-LeafValues($table, $prefix) {
			$out = @{}
			foreach ($key in $table.Keys) {
				$path = if ($prefix) { "$prefix.$key" } else { [string]$key }
				if ($table[$key] -is [System.Collections.IDictionary]) { $out += Get-LeafValues $table[$key] $path }
				else { $out[$path] = $table[$key] }
			}
			return $out
		}

		$localeDir = Join-Path $ctx.RepoRoot 'src/locale'
		$files = @(Get-ChildItem -LiteralPath $localeDir -Filter '??-??.ps1' -File | Sort-Object Name)
		Assert-True ($files.Count -ge 6) "locale 文件过少：$($files.Count)"

		$locales = @{}
		foreach ($file in $files) {
			$data = & $file.FullName
			$locales[$file.BaseName] = $data
			$offenders = @()
			foreach ($leaf in (Get-LeafValues $data.ConsoleHelpData.PrarmsData '').Keys) {
				if ($leaf -notin $fieldPaths -and $leaf -notin $excluded) { $offenders += $leaf }
			}
			Assert-True ($offenders.Count -eq 0) "$($file.BaseName) 的帮助数据键未被 schema 覆盖：$($offenders -join ', ')"
		}
		Assert-True $locales.ContainsKey('en-US') 'en-US locale 缺失'
		Assert-True $locales.ContainsKey('zh-CN') 'zh-CN locale 缺失'

		# schema 推导出的必需 GUI 键 + 固定键。
		$required = @()
		foreach ($page in $schema.Pages) {
			$required += [string]$page.Label
			foreach ($group in $page.Groups) {
				$required += [string]$group.Label
				foreach ($field in $group.Fields) {
					$required += if ($field.Label) { [string]$field.Label } else { "Field.$([string]$field.Path)" }
				}
			}
		}
		$required += @(
			'Button.Compile', 'Button.Cancel', 'Button.LoadCfg', 'Button.SaveCfg', 'Button.SaveAsCfg', 'Button.Browse',
			'Button.DarkMode', 'Button.BGM', 'Button.AddExport', 'Button.EditExport', 'Button.RemoveExport',
			'Dialog.Compile.Title', 'Dialog.Compile.Filter', 'Dialog.Output.Title', 'Dialog.Output.Filter',
			'Dialog.Icon.Title', 'Dialog.Icon.Filter', 'Dialog.Certificate.Title', 'Dialog.Certificate.Filter',
			'Dialog.OpenCfg.Title', 'Dialog.OpenCfg.Filter', 'Dialog.SaveCfg.Title', 'Dialog.SaveCfg.Filter',
			'Dialog.Folder.Title',
			'Window.Title', 'Log.Ready', 'Log.Compiling', 'Log.Cancelled', 'Log.Done', 'Log.CfgLoadFailed', 'Label.CfgFileHead'
		)
		$required = @($required | Select-Object -Unique)

		foreach ($name in $locales.Keys) {
			$text = Get-LeafValues $locales[$name].GUI ''
			$missing = @($required | Where-Object { -not $text.ContainsKey($_) })
			Assert-True ($missing.Count -eq 0) "$name 的 GUI 缺少键：$($missing -join ', ')"
			Assert-Equal ([string]$locales[$name].CfgFileLabelHead) ([string]$text['Label.CfgFileHead']) "$name 的 Label.CfgFileHead 与 CfgFileLabelHead 不一致"
		}
	}
}

Add-Test @{
	Name  = 'gui.layout'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		$results = Invoke-GUIScriptBlock -Variables @{ RepoRoot = $ctx.RepoRoot } -Script {
			$gui = Join-Path $RepoRoot 'src/GUI'
			. (Join-Path $gui 'UItools.ps1')
			. (Join-Path $gui 'Schema.ps1')
			. (Join-Path $gui 'Functions.ps1')
			. (Join-Path $gui 'Layout.ps1')
			. (Join-Path $gui 'Events.ps1')
			$Script:GUISchema = Get-GUISchema

			function Get-GUIDescendants($control) {
				foreach ($child in $control.Controls) {
					$child
					if ($child.HasChildren) { Get-GUIDescendants $child }
				}
			}

			$results = @()
			foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'src/locale') -Filter '??-??.ps1' -File | Sort-Object Name)) {
				$Script:LocalizeData = & $file.FullName
				$Script:refs = @{}
				$Script:FieldControls = @{}
				$Script:FieldBrowse = @{}
				$form = New-GUIForm
				$form.ClientSize = New-Object System.Drawing.Size(1100, 820)
				# 不显示窗体 WinForms 不会做完整布局；挪到屏幕外 Show/Hide 一次即可，且不会闪窗。
				$form.StartPosition = 'Manual'
				$form.Location = New-Object System.Drawing.Point(-10000, -10000)
				$form.Show()
				$form.Hide()

				$controls = @(Get-GUIDescendants $form)

				# 文本截断：AutoSize 控件的实际尺寸应能容纳首选尺寸。FlowLayoutPanel 里允许换行的标签除外。
				$clip = @()
				foreach ($control in $controls) {
					if ($control -isnot [System.Windows.Forms.Label] -and $control -isnot [System.Windows.Forms.CheckBox] -and $control -isnot [System.Windows.Forms.Button]) { continue }
					if (-not $control.AutoSize) { continue }
					if ($control.Parent -is [System.Windows.Forms.FlowLayoutPanel] -and $control.Parent.WrapContents) { continue }
					$preferred = $control.PreferredSize
					if ($preferred.Width -gt $control.Width + 2 -or $preferred.Height -gt $control.Height + 2) {
						$clip += "$($control.GetType().Name)[$($control.Text)] pref=$($preferred.Width)x$($preferred.Height) size=$($control.Width)x$($control.Height)"
					}
				}

				# 兄弟重叠：取 TableLayoutPanel 的直接子控件两两比较（同父系，Bounds 坐标系一致）。
				$overlap = @()
				foreach ($panel in @($controls | Where-Object { $_ -is [System.Windows.Forms.TableLayoutPanel] })) {
					$siblings = @($panel.Controls | Where-Object { $_.Width -gt 0 -and $_.Height -gt 0 })
					for ($i = 0; $i -lt $siblings.Count; $i++) {
						for ($j = $i + 1; $j -lt $siblings.Count; $j++) {
							$a = $siblings[$i]; $b = $siblings[$j]
							if ($a.Parent -ne $b.Parent) { continue }
							if ($a.Bounds.IntersectsWith($b.Bounds)) {
								$overlap += "$($a.GetType().Name)[$($a.Text)] 与 $($b.GetType().Name)[$($b.Text)]"
							}
						}
					}
				}

				# 控件塌陷：每个字段控件必须有正尺寸且完整落在其所属 GroupBox 的可见区内。
				# 回归点：GroupBox.AutoSize 会忽略 Dock=Fill 的子控件，届时所有分组塌成标题高、字段高度为 0。
				$collapse = @()
				foreach ($fieldPath in $Script:FieldControls.Keys) {
					$control = $Script:FieldControls[$fieldPath]
					if ($control.Width -le 0 -or $control.Height -le 0) {
						$collapse += "字段 $fieldPath 尺寸为 $($control.Width)x$($control.Height)"
						continue
					}
					$ancestor = $control.Parent
					while ($ancestor -and $ancestor -isnot [System.Windows.Forms.GroupBox]) { $ancestor = $ancestor.Parent }
					if (-not $ancestor) {
						$collapse += "字段 $fieldPath 不在 GroupBox 内"
						continue
					}
					if ($control.Top -lt 0 -or ($control.Top + $control.Height) -gt $ancestor.ClientSize.Height + 1) {
						$collapse += "字段 $fieldPath 超出分组可见区：top=$($control.Top) bottom=$($control.Top + $control.Height) groupClient=$($ancestor.ClientSize.Height)"
					}
				}
				$groupBoxes = @($controls | Where-Object { $_ -is [System.Windows.Forms.GroupBox] })
				foreach ($groupBox in $groupBoxes) {
					if ($groupBox.ClientSize.Height -le 0) { $collapse += "分组 [$($groupBox.Text)] 高度为 0" }
				}

				# 分组可达：每页内容必须放在 AutoScroll 的 Panel 里、由 AutoSize 表格随内容长高。
				# 回归点：TableLayoutPanel 的 AutoScroll 不计入 AutoSize 分组，靠下的分组（DLL 导出表格）会被裁掉且滚不到。
				$unreachable = @()
				foreach ($tabPage in @($Script:refs.TabsControl.TabPages)) {
					$scrollPanel = @($tabPage.Controls | Where-Object { $_ -is [System.Windows.Forms.Panel] -and $_.AutoScroll } | Select-Object -First 1)
					if (-not $scrollPanel -or $scrollPanel -is [System.Windows.Forms.TableLayoutPanel]) {
						$unreachable += "页 [$($tabPage.Text)] 缺少可滚动的 Panel 宿主"
						continue
					}
					$contentGrid = @($scrollPanel.Controls | Where-Object { $_ -is [System.Windows.Forms.TableLayoutPanel] } | Select-Object -First 1)
					if (-not $contentGrid -or -not $contentGrid.AutoSize -or $contentGrid.Dock -ne 'Top') {
						$unreachable += "页 [$($tabPage.Text)] 内容表格未 AutoSize+Dock=Top"
					}
				}

				# 分组归属：每一页实际包含的 GroupBox 文案应与 schema 该页的分组一致（按集合比较，避免受子控件顺序影响）。
				$pageMismatch = @()
				$tabPages = @($Script:refs.TabsControl.TabPages)
				for ($tabIndex = 0; $tabIndex -lt $tabPages.Count; $tabIndex++) {
					$expected = @($Script:GUISchema.Pages[$tabIndex].Groups | ForEach-Object { Get-GUIText $_.Label } | Sort-Object)
					$actual = @(Get-GUIDescendants $tabPages[$tabIndex] | Where-Object { $_ -is [System.Windows.Forms.GroupBox] } | ForEach-Object { $_.Text } | Sort-Object)
					if (($expected -join '|') -ne ($actual -join '|')) {
						$pageMismatch += "页 $tabIndex [$($tabPages[$tabIndex].Text)]：期望 [$($expected -join ', ')] 实际 [$($actual -join ', ')]"
					}
				}

				$results += @{
					Locale      = $file.BaseName
					TabPages    = $Script:refs.TabsControl.TabPages.Count
					Fields      = $Script:FieldControls.Count
					Groups      = $groupBoxes.Count
					Clip        = $clip
					Overlap     = $overlap
					Collapse    = $collapse
					Unreachable = $unreachable
					PageMismatch = $pageMismatch
				}
				$form.Dispose()
			}
			$results
		}

		. (Join-Path $ctx.RepoRoot 'src/GUI/Schema.ps1')
		$schema = Get-GUISchema
		$expectedGroups = ($schema.Pages | ForEach-Object { $_.Groups.Count } | Measure-Object -Sum).Sum

		Assert-True ($results.Count -ge 6) "未遍历到足够 locale：$($results.Count)"
		foreach ($result in $results) {
			Assert-Equal 8 $result.TabPages "$($result.Locale) 的 TabPage 数不符"
			Assert-Equal 57 $result.Fields "$($result.Locale) 的字段控件数不符"
			Assert-Equal $expectedGroups $result.Groups "$($result.Locale) 的 GroupBox 数不符"
			Assert-True ($result.Clip.Count -eq 0) "$($result.Locale) 文本被截断：`n" + ($result.Clip -join "`n")
			Assert-True ($result.Overlap.Count -eq 0) "$($result.Locale) 控件重叠：`n" + ($result.Overlap -join "`n")
			Assert-True ($result.Collapse.Count -eq 0) "$($result.Locale) 控件塌陷/超出分组：`n" + ($result.Collapse -join "`n")
			Assert-True ($result.Unreachable.Count -eq 0) "$($result.Locale) 分组超出可滚动区、无法操作：`n" + ($result.Unreachable -join "`n")
			Assert-True ($result.PageMismatch.Count -eq 0) "$($result.Locale) 分组未落在正确页：`n" + ($result.PageMismatch -join "`n")
		}
	}
}

# 主题：亮/暗调色板分别落到窗体、输入框、日志框与强调按钮上，标签页走自绘。
Add-Test @{
	Name  = 'gui.theme'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		$result = Invoke-GUIScriptBlock -Variables @{ RepoRoot = $ctx.RepoRoot } -Script {
			$gui = Join-Path $RepoRoot 'src/GUI'
			. (Join-Path $gui 'UItools.ps1')
			. (Join-Path $gui 'Schema.ps1')
			. (Join-Path $gui 'Functions.ps1')
			. (Join-Path $gui 'Layout.ps1')
			$UIMode = 'Light'
			. (Join-Path $gui 'DarkMode.ps1')
			$Script:GUISchema = Get-GUISchema
			$Script:LocalizeData = & (Join-Path $RepoRoot 'src/locale/en-US.ps1')
			$Script:refs = @{}
			$Script:FieldControls = @{}
			$Script:FieldBrowse = @{}
			$form = New-GUIForm

			$themes = @{}
			foreach ($dark in @($true, $false)) {
				$Script:DarkMode = $dark
				Set-DarkMode $dark
				$palette = Get-GUIThemePalette -Dark $dark
				$key = if ($dark) { 'Dark' } else { 'Light' }
				$themes[$key] = @{
					FormBack   = $form.BackColor.ToArgb()
					WindowBack = (ConvertTo-GUIColor $palette.WindowBack).ToArgb()
					LogBack    = $Script:refs.LogTextBox.BackColor.ToArgb()
					PaletteLog = (ConvertTo-GUIColor $palette.LogBack).ToArgb()
					InputBack  = (Get-FieldControl 'inputFile').BackColor.ToArgb()
					Accent     = (ConvertTo-GUIColor $palette.Accent).ToArgb()
					CompileBack = $Script:refs.CompileButton.BackColor.ToArgb()
					DrawMode   = $Script:refs.TabsControl.DrawMode.ToString()
				}
			}
			$form.Dispose()
			$themes
		}

		foreach ($key in @('Dark', 'Light')) {
			$theme = $result[$key]
			Assert-Equal $theme.WindowBack $theme.FormBack "$key 窗体底色未跟随调色板"
			Assert-Equal $theme.PaletteLog $theme.LogBack "$key 日志框底色未跟随调色板"
			Assert-Equal $theme.Accent $theme.CompileBack "$key 编译按钮未使用强调色"
			Assert-Equal 'OwnerDrawFixed' $theme.DrawMode "$key 标签页未自绘"
			Assert-True ($theme.InputBack -ne $theme.FormBack) "$key 输入框与窗体底色相同，缺少层次"
		}
		Assert-True ($result.Dark.FormBack -ne $result.Light.FormBack) '亮/暗窗体底色相同'
	}
}

Add-Test @{
	Name  = 'gui.darkmode-follow'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		$result = Invoke-GUIScriptBlock -Variables @{ RepoRoot = $ctx.RepoRoot } -Script {
			$gui = Join-Path $RepoRoot 'src/GUI'
			. (Join-Path $gui 'UItools.ps1')
			. (Join-Path $gui 'Schema.ps1')
			. (Join-Path $gui 'Functions.ps1')
			. (Join-Path $gui 'Layout.ps1')
			$UIMode = 'Auto'
			. (Join-Path $gui 'DarkMode.ps1')

			# 系统为深色，初始跟随。
			$Script:SystemDarkMode = $true
			$Script:DarkMode = $true
			$Script:DarkModeOverride = $false

			# 用户手动切到浅色：系统未变时定时器不应切回（回归点：手动切换 2s 后被自动跟随改回去）。
			$Script:DarkModeOverride = $true
			$Script:DarkMode = $false
			Sync-GUIDarkMode -SystemDark $true
			$afterManualSameSystem = $Script:DarkMode
			$overrideAfterManual = $Script:DarkModeOverride
			Sync-GUIDarkMode -SystemDark $true
			$afterSecondTick = $Script:DarkMode

			# 系统本身变为浅色：自动跟随重新接管。
			Sync-GUIDarkMode -SystemDark $false
			$afterSystemChange = $Script:DarkMode
			$overrideAfterSystemChange = $Script:DarkModeOverride

			# 系统再变回深色：继续跟随。
			Sync-GUIDarkMode -SystemDark $true
			$afterSystemBack = $Script:DarkMode

			@{
				AfterManualSameSystem   = $afterManualSameSystem
				OverrideAfterManual     = $overrideAfterManual
				AfterSecondTick         = $afterSecondTick
				AfterSystemChange       = $afterSystemChange
				OverrideAfterSystemChange = $overrideAfterSystemChange
				AfterSystemBack         = $afterSystemBack
			}
		}

		Assert-False ([bool]$result.AfterManualSameSystem) '手动切到浅色后，系统未变时定时器不应自动切回深色'
		Assert-True ([bool]$result.OverrideAfterManual) '手动切换后未置位覆盖标志'
		Assert-False ([bool]$result.AfterSecondTick) '再次 tick 仍不应切回'
		Assert-False ([bool]$result.AfterSystemChange) '系统切到浅色后应自动跟随为浅色'
		Assert-False ([bool]$result.OverrideAfterSystemChange) '系统变化后应清除手动覆盖'
		Assert-True ([bool]$result.AfterSystemBack) '系统再变回深色后应自动跟随为深色'
	}
}

Add-Test @{
	Name  = 'gui.uidata-args'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1')
	Run   = {
		param($ctx)
		$data = Invoke-GUIScriptBlock -Variables @{ RepoRoot = $ctx.RepoRoot; WorkDir = $ctx.WorkDir } -Script {
			$gui = Join-Path $RepoRoot 'src/GUI'
			. (Join-Path $gui 'UItools.ps1')
			. (Join-Path $gui 'Schema.ps1')
			. (Join-Path $gui 'Functions.ps1')
			. (Join-Path $gui 'Layout.ps1')
			$Script:GUISchema = Get-GUISchema
			$Script:LocalizeData = & (Join-Path $RepoRoot 'src/locale/en-US.ps1')
			$Script:refs = @{}
			$Script:FieldControls = @{}
			$Script:FieldBrowse = @{}
			$form = New-GUIForm

			$sample = @{
				inputFile  = 'sub\a.ps1'
				outputFile = 'out\a.exe'
				App        = @{ Windowed = $true }
				Build      = @{
					Target     = 'Core'
					Minify     = '{ $_ }'
					DllExports = @(@{ funcName = 'F'; returnType = 'int'; params = @(@{ type = 'int'; name = 'x' }) })
					Core       = @{ Backend = 'Bundled'; SelfContained = $true; Aot = $true }
				}
				Resources  = @{ Icon = 'shell32.dll,3' }
			}
			Set-UIData -UIData $sample

			$result = @{}
			$result.UIData = Get-UIData
			$result.Args = Get-ps12exeArgs

			# 设定配置文件后，相对路径以配置文件目录为基准转绝对。
			$projDir = Join-Path $WorkDir 'proj'
			New-Item -ItemType Directory -Path $projDir -Force | Out-Null
			$cfg = Join-Path $projDir 'proj.psccfg'
			[System.IO.File]::WriteAllText($cfg, '', [System.Text.UTF8Encoding]::new($false))
			$Script:ConfigFile = $cfg
			$result.ProjDir = $projDir
			$result.ArgsCfg = Get-ps12exeArgs

			# URL 原样透传。
			Set-UIData -UIData @{ inputFile = 'https://example.com/a.ps1'; Build = @{ Target = 'Core' } }
			$result.ArgsUrl = Get-ps12exeArgs

			# DllExports 仅在 Framework4.0 + x86/x64 下可用；切到该组合后应输出数组。
			Set-UIData -UIData @{ Build = @{ Target = 'Framework4.0'; Platform = 'x64'; DllExports = @(@{ funcName = 'F'; returnType = 'int'; params = @(@{ type = 'int'; name = 'x' }) }) } }
			$result.ArgsExports = Get-ps12exeArgs

			# Target 切回 Framework4.0 后 Core 组不应输出。
			Set-UIData -UIData @{ Build = @{ Target = 'Framework4.0' }; Signing = @{ Enabled = $false } }
			$result.ArgsFramework = Get-ps12exeArgs

			# Signing 打开后输出 Thumbprint，密码转 SecureString。
			Set-UIData -UIData @{ Build = @{ Target = 'Framework4.0' }; Signing = @{ Enabled = $true; Thumbprint = 'ABC'; Password = 'secret' } }
			$result.ArgsSigning = Get-ps12exeArgs

			# Get-RelativePath ↔ Resolve-ProjectPath 往返。
			$abs = Join-Path $RepoRoot 'src\locale\en-US.ps1'
			$result.RelRoundTrip = Resolve-ProjectPath (Get-RelativePath $abs $RepoRoot) $RepoRoot
			$result.RelExpected = [System.IO.Path]::GetFullPath($abs)

			$form.Dispose()
			$result
		}

		# UIData 往返
		Assert-Equal 'sub\a.ps1' $data.UIData.inputFile 'inputFile 未往返'
		Assert-Equal 'out\a.exe' $data.UIData.outputFile 'outputFile 未往返'
		Assert-True ([bool]$data.UIData.App.Windowed) 'App.Windowed 未往返'
		Assert-Equal 'Core' $data.UIData.Build.Target 'Build.Target 未往返'
		Assert-Equal 'Bundled' $data.UIData.Build.Core.Backend 'Build.Core.Backend 未往返'
		Assert-True ([bool]$data.UIData.Build.Core.SelfContained) 'Build.Core.SelfContained 未往返'
		Assert-True ([bool]$data.UIData.Build.Core.Aot) 'Build.Core.Aot 未往返'
		Assert-Equal '{ $_ }' $data.UIData.Build.Minify 'Build.Minify 未往返'
		Assert-Equal 'shell32.dll,3' $data.UIData.Resources.Icon 'Resources.Icon 未往返'
		Assert-Equal 1 @($data.UIData.Build.DllExports).Count 'Build.DllExports 数量不符'
		Assert-Equal 'F' @($data.UIData.Build.DllExports)[0].funcName 'Build.DllExports.funcName 未往返'

		# Get-ps12exeArgs：对象式参数与默认值裁剪
		Assert-Equal 'Core' $data.Args.Build.Target 'Args 缺少 Build.Target'
		Assert-True ([bool]$data.Args.Build.Core.Aot) 'Args 缺少 Build.Core.Aot'
		Assert-True ([bool]$data.Args.App.Windowed) 'Args 缺少 App.Windowed'
		Assert-False ($data.Args.App.ContainsKey('VisualStyles')) '默认 App.VisualStyles 不应输出'
		Assert-True ($data.Args.Build.Minify -is [scriptblock]) 'Build.Minify 应为 scriptblock'
		Assert-False ($data.Args.Build.ContainsKey('DllExports')) 'Core 目标下 DllExports 不可用，不应输出'

		# 配置文件基准目录
		Assert-True ([System.IO.Path]::IsPathRooted([string]$data.ArgsCfg.inputFile)) 'ArgsCfg.inputFile 未转绝对'
		Assert-True ([System.IO.Path]::IsPathRooted([string]$data.ArgsCfg.outputFile)) 'ArgsCfg.outputFile 未转绝对'
		Assert-True ([string]$data.ArgsCfg.inputFile).StartsWith($data.ProjDir, [System.StringComparison]::OrdinalIgnoreCase) 'ArgsCfg.inputFile 不在配置文件目录下'
		Assert-True ([string]$data.ArgsCfg.outputFile).StartsWith($data.ProjDir, [System.StringComparison]::OrdinalIgnoreCase) 'ArgsCfg.outputFile 不在配置文件目录下'
		# 无配置文件时图标索引原样保留；有配置文件时只把路径部分绝对化，仍保留 ,N 后缀。
		Assert-Equal 'shell32.dll,3' ([string]$data.Args.Resources.Icon) 'Args 改动了图标索引'
		$cfgIcon = [string]$data.ArgsCfg.Resources.Icon
		Assert-True $cfgIcon.StartsWith($data.ProjDir, [System.StringComparison]::OrdinalIgnoreCase) 'ArgsCfg.Resources.Icon 未绝对化'
		Assert-True $cfgIcon.EndsWith(',3') 'ArgsCfg.Resources.Icon 丢失图标索引后缀'

		# URL 透传
		Assert-Equal 'https://example.com/a.ps1' ([string]$data.ArgsUrl.inputFile) 'URL 被改写'

		# DllExports：启用后应输出数组及条目
		Assert-True $data.ArgsExports.ContainsKey('Build') 'ArgsExports 缺少 Build'
		Assert-True $data.ArgsExports.Build.ContainsKey('DllExports') 'ArgsExports 缺少 Build.DllExports'
		Assert-Equal 1 @($data.ArgsExports.Build.DllExports).Count 'ArgsExports 的 Build.DllExports 数量不符'
		Assert-Equal 'F' @($data.ArgsExports.Build.DllExports)[0].funcName 'ArgsExports 的 Build.DllExports.funcName 不符'

		# Target 切换 / Signing
		$hasCore = $data.ArgsFramework.ContainsKey('Build') -and $data.ArgsFramework.Build.ContainsKey('Core')
		Assert-False $hasCore 'Framework4.0 下不应输出 Build.Core'
		Assert-True $data.ArgsSigning.ContainsKey('Signing') 'Signing 开启后未输出'
		Assert-Equal 'ABC' ([string]$data.ArgsSigning.Signing.Thumbprint) 'Signing.Thumbprint 不符'
		Assert-True ($data.ArgsSigning.Signing.Password -is [System.Security.SecureString]) 'Signing.Password 应为 SecureString'

		# 路径往返
		Assert-Equal $data.RelExpected $data.RelRoundTrip '相对路径往返失败'
	}
}

Add-Test @{
	Name  = 'gui.compile'
	Group = 'gui'
	Deps  = @('src/GUI/', 'src/locale/', 'src/LocaleLoader.ps1', 'ps12exe.psm1', 'ps12exe.ps1')
	Run   = {
		param($ctx)
		$result = Invoke-GUIScriptBlock -Variables @{ RepoRoot = $ctx.RepoRoot; WorkDir = $ctx.WorkDir } -Script {
			$gui = Join-Path $RepoRoot 'src/GUI'
			. (Join-Path $gui 'UItools.ps1')
			. (Join-Path $gui 'Schema.ps1')
			. (Join-Path $gui 'Functions.ps1')
			. (Join-Path $gui 'Layout.ps1')
			. (Join-Path $gui 'Compile.ps1')
			. (Join-Path $gui 'Events.ps1')
			$Script:GUISchema = Get-GUISchema
			$Script:LocalizeData = & (Join-Path $RepoRoot 'src/locale/en-US.ps1')
			$Script:refs = @{}
			$Script:FieldControls = @{}
			$Script:FieldBrowse = @{}
			$form = New-GUIForm
			$Script:GUISuppressDialogs = $true
			Initialize-GUICompiler

			function Wait-GUICompile([int]$TimeoutSeconds) {
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				while ((Test-GUICompileRunning) -and $stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
					Update-GUICompile
					Start-Sleep -Milliseconds 50
				}
				Update-GUICompile
				return -not (Test-GUICompileRunning)
			}

			$inputFile = Join-Path $WorkDir 'compile-input.ps1'
			[System.IO.File]::WriteAllText($inputFile, "'hello'", [System.Text.UTF8Encoding]::new($true))
			Start-GUICompile -Params @{ inputFile = $inputFile; PreprocessOnly = $true; Quiet = $true; NoUpdateCheck = $true }
			$finished = Wait-GUICompile 150

			$badFile = Join-Path $WorkDir 'bad-input.ps1'
			[System.IO.File]::WriteAllText($badFile, 'function {', [System.Text.UTF8Encoding]::new($true))
			Start-GUICompile -Params @{ inputFile = $badFile; PreprocessOnly = $true; Quiet = $true; NoUpdateCheck = $true }
			$badFinished = Wait-GUICompile 150

			$output = @{
				Finished    = $finished
				Log         = [string]$Script:refs.LogTextBox.Text
				Message     = [string]$Script:CompileMessage
				BadFinished = $badFinished
			}
			$form.Dispose()
			$output
		}

		Assert-True ([bool]$result.Finished) 'PreprocessOnly 编译超时未结束'
		Assert-True ($result.Log.Length -gt 0) '编译日志为空'
		Assert-True ($result.Message.Length -gt 0) '编译结果消息为空'
		Assert-True ([bool]$result.BadFinished) '非法脚本编译超时未结束（对话框应被抑制而不阻塞）'
	}
}
