# 读取系统「应用」深浅色；读不到时按浅色处理。
function Get-SystemDarkMode {
	$light = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
	return $light -eq 0
}

$Script:SystemDarkMode = Get-SystemDarkMode
if ($UIMode -eq 'Auto' -or -not $UIMode) {
	$Script:DarkMode = $Script:SystemDarkMode
}
else {
	$Script:DarkMode = $UIMode -eq 'Dark'
}
# 用户手动点过深色按钮后置位；仅当系统设置本身发生变化时才让自动跟随重新接管。
$Script:DarkModeOverride = $false

# 亮/暗共用一套语义调色板，深色走现代扁平风：窗体底色最暗、分组卡片略亮、输入控件内凹。
# 颜色一律以 #RRGGBB 字符串存放，应用时再转 Color，避免脚本里散落硬编码。
function Get-GUIThemePalette {
	param([bool]$Dark)
	if ($Dark) {
		return @{
			WindowBack   = '#1e1e1e'
			SurfaceBack  = '#252526'
			SurfaceAlt   = '#2d2d30'
			InputBack    = '#1b1b1c'
			Border       = '#3f3f46'
			Text         = '#e6e6e6'
			MutedText    = '#9d9d9d'
			Accent       = '#0a84ff'
			AccentText   = '#ffffff'
			ButtonBack   = '#333337'
			ButtonHover  = '#3f3f46'
			ButtonDown   = '#474750'
			ButtonBorder = '#4a4a52'
			TabHover     = '#2d2d30'
			TabActive    = '#1e1e1e'
			LogBack      = '#141415'
			LogText      = '#c8c8c8'
			GridLine     = '#3f3f46'
			BorderRgb    = 0x1e1e1e
		}
	}
	return @{
		WindowBack   = '#f3f3f3'
		SurfaceBack  = '#ffffff'
		SurfaceAlt   = '#fafafa'
		InputBack    = '#ffffff'
		Border       = '#d6d6d6'
		Text         = '#1f1f1f'
		MutedText    = '#5f5f5f'
		Accent       = '#0067c0'
		AccentText   = '#ffffff'
		ButtonBack   = '#fdfdfd'
		ButtonHover  = '#f0f0f0'
		ButtonDown   = '#e5e5e5'
		ButtonBorder = '#cccccc'
		TabHover     = '#e8e8e8'
		TabActive    = '#f3f3f3'
		LogBack      = '#ffffff'
		LogText      = '#1f1f1f'
		GridLine     = '#d6d6d6'
		BorderRgb    = 0xf3f3f3
	}
}

function ConvertTo-GUIColor {
	param([string]$Html)
	return [System.Drawing.ColorTranslator]::FromHtml($Html)
}

# 图标源图是纯白透明 PNG，直接当 BackgroundImage 会被裁成 256px 的一角。
# 缩到 16px 并按主题前景色着色后挂到 Button.Image 上，亮/暗下都清晰。
function Set-GUIButtonIcon {
	param(
		[System.Windows.Forms.Button]$Button,
		[string]$SourcePath,
		[System.Drawing.Color]$Color
	)
	if (-not $Button) { return }
	if ($Button.Image) {
		$previous = $Button.Image
		$Button.Image = $null
		$previous.Dispose()
	}
	if (-not (Test-Path -LiteralPath $SourcePath)) { return }
	$source = [System.Drawing.Image]::FromFile($SourcePath)
	try {
		$size = 16
		$bitmap = New-Object System.Drawing.Bitmap($size, $size)
		$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
		try {
			$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
			$matrix = New-Object System.Drawing.Imaging.ColorMatrix
			$matrix.Matrix00 = $Color.R / 255
			$matrix.Matrix11 = $Color.G / 255
			$matrix.Matrix22 = $Color.B / 255
			$matrix.Matrix33 = 1
			$matrix.Matrix44 = 1
			$attributes = New-Object System.Drawing.Imaging.ImageAttributes
			$attributes.SetColorMatrix($matrix)
			$dest = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
			$graphics.DrawImage($source, $dest, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
			$attributes.Dispose()
		}
		finally { $graphics.Dispose() }
		$Button.Image = $bitmap
	}
	finally { $source.Dispose() }
}

# 自绘标签页：WinForms 的 TabControl 跟不了深色，手动画成扁平样式（选中项加一条强调色下划线）。
# 只需挂钩一次，之后换肤靠 $Script:GUITheme 重绘。
function Initialize-GUITabTheme {
	param([System.Windows.Forms.TabControl]$Tabs)
	if ($Script:GUIThemeTabsHooked) { return }
	$Script:GUIThemeTabsHooked = $true
	$Tabs.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
	$Tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Normal
	$Tabs.ItemSize = New-Object System.Drawing.Size(0, [int]($Tabs.Font.Height + 16))
	$Tabs.add_DrawItem({
		param($sender, $e)
		$palette = $Script:GUITheme
		if (-not $palette -or $e.Index -lt 0 -or $e.Index -ge $sender.TabPages.Count) { return }
		$graphics = $e.Graphics
		$bounds = $e.Bounds
		$selected = ($e.Index -eq $sender.SelectedIndex)
		$hot = (($e.State -band [System.Windows.Forms.DrawItemState]::HotLight) -eq [System.Windows.Forms.DrawItemState]::HotLight)
		$backHtml = if ($selected) { $palette.TabActive } elseif ($hot) { $palette.TabHover } else { $palette.WindowBack }
		$brush = New-Object System.Drawing.SolidBrush((ConvertTo-GUIColor $backHtml))
		try { $graphics.FillRectangle($brush, $bounds) } finally { $brush.Dispose() }
		if ($selected) {
			$barBrush = New-Object System.Drawing.SolidBrush((ConvertTo-GUIColor $palette.Accent))
			try { $graphics.FillRectangle($barBrush, [int]$bounds.X, [int]($bounds.Bottom - 3), [int]$bounds.Width, 3) } finally { $barBrush.Dispose() }
		}
		$textColor = ConvertTo-GUIColor $(if ($selected) { $palette.Text } else { $palette.MutedText })
		$textRect = New-Object System.Drawing.Rectangle([int]$bounds.X, [int]$bounds.Y, [int]$bounds.Width, [int]($bounds.Height - 2))
		$flags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis
		[System.Windows.Forms.TextRenderer]::DrawText($graphics, [string]$sender.TabPages[$e.Index].Text, $sender.Font, $textRect, $textColor, $flags)
	})
}

function Set-DarkMode {
	param($set)

	if (-not $Script:refs -or -not $Script:refs.MainForm) { return }
	$mainForm = $Script:refs.MainForm
	$dark = [bool]$set
	$palette = Get-GUIThemePalette -Dark $dark
	$Script:GUITheme = $palette

	$windowBack = ConvertTo-GUIColor $palette.WindowBack
	$surfaceBack = ConvertTo-GUIColor $palette.SurfaceBack
	$surfaceAlt = ConvertTo-GUIColor $palette.SurfaceAlt
	$inputBack = ConvertTo-GUIColor $palette.InputBack
	$text = ConvertTo-GUIColor $palette.Text
	$mutedText = ConvertTo-GUIColor $palette.MutedText
	$accent = ConvertTo-GUIColor $palette.Accent
	$accentText = ConvertTo-GUIColor $palette.AccentText
	$buttonBack = ConvertTo-GUIColor $palette.ButtonBack
	$buttonHover = ConvertTo-GUIColor $palette.ButtonHover
	$buttonDown = ConvertTo-GUIColor $palette.ButtonDown
	$buttonBorder = ConvertTo-GUIColor $palette.ButtonBorder
	$logBack = ConvertTo-GUIColor $palette.LogBack
	$logText = ConvertTo-GUIColor $palette.LogText

	function Set-ControlWindowTheme($control, [bool]$isDark) {
		try {
			if ($isDark) { [void][ps12exeGUI.Win32]::SetWindowTheme($control.Handle, 'DarkMode_Explorer', $null) }
			else { [void][ps12exeGUI.Win32]::SetWindowTheme($control.Handle, $null, $null) }
		}
		catch { }
	}

	function Set-ControlTheme($control) {
		$parentBack = if ($control.Parent) { $control.Parent.BackColor } else { $windowBack }

		if ($control -is [System.Windows.Forms.TextBoxBase]) {
			$isLog = ($control -eq $Script:refs.LogTextBox)
			$control.BackColor = if ($isLog) { $logBack } else { $inputBack }
			$control.ForeColor = if ($isLog) { $logText } else { $text }
			$control.BorderStyle = 'FixedSingle'
			Set-ControlWindowTheme $control $dark
		}
		elseif ($control -is [System.Windows.Forms.DataGridView]) {
			$control.EnableHeadersVisualStyles = $false
			$control.BackgroundColor = $surfaceBack
			$control.ForeColor = $text
			$control.GridColor = ConvertTo-GUIColor $palette.GridLine
			$control.BorderStyle = 'FixedSingle'
			$control.DefaultCellStyle.BackColor = $inputBack
			$control.DefaultCellStyle.ForeColor = $text
			$control.DefaultCellStyle.SelectionBackColor = $accent
			$control.DefaultCellStyle.SelectionForeColor = $accentText
			$control.ColumnHeadersDefaultCellStyle.BackColor = $surfaceAlt
			$control.ColumnHeadersDefaultCellStyle.ForeColor = $mutedText
			$control.ColumnHeadersDefaultCellStyle.SelectionBackColor = $surfaceAlt
			$control.ColumnHeadersDefaultCellStyle.SelectionForeColor = $mutedText
			$control.RowHeadersDefaultCellStyle.BackColor = $surfaceBack
			$control.RowHeadersDefaultCellStyle.ForeColor = $text
			Set-ControlWindowTheme $control $dark
		}
		elseif ($control -is [System.Windows.Forms.ComboBox] -or $control -is [System.Windows.Forms.ListBox]) {
			$control.BackColor = $inputBack
			$control.ForeColor = $text
			$control.FlatStyle = 'Flat'
			Set-ControlWindowTheme $control $dark
		}
		elseif ($control -is [System.Windows.Forms.Button]) {
			$control.FlatStyle = 'Flat'
			$control.UseVisualStyleBackColor = $false
			$flat = $control.FlatAppearance
			if ($control -eq $Script:refs.CompileButton -or $control -eq $Script:refs.CancelButton) {
				$control.BackColor = $accent
				$control.ForeColor = $accentText
				$flat.BorderSize = 0
				$flat.MouseOverBackColor = [System.Windows.Forms.ControlPaint]::Light($accent, 0.15)
				$flat.MouseDownBackColor = [System.Windows.Forms.ControlPaint]::Dark($accent, 0.12)
			}
			else {
				$control.BackColor = $buttonBack
				$control.ForeColor = $text
				$flat.BorderSize = 1
				$flat.BorderColor = $buttonBorder
				$flat.MouseOverBackColor = $buttonHover
				$flat.MouseDownBackColor = $buttonDown
			}
		}
		elseif ($control -is [System.Windows.Forms.CheckBox] -or $control -is [System.Windows.Forms.RadioButton]) {
			$control.ForeColor = $text
			$control.FlatStyle = 'Flat'
			$control.UseVisualStyleBackColor = $false
			$control.BackColor = [System.Drawing.Color]::Transparent
		}
		elseif ($control -is [System.Windows.Forms.GroupBox]) {
			$control.ForeColor = $mutedText
			$control.BackColor = $surfaceBack
			if ($control -is [ps12exeGUI.FlatGroupBox]) {
				$control.BorderColor = ConvertTo-GUIColor $palette.Border
				$control.TitleColor = $mutedText
			}
		}
		elseif ($control -is [System.Windows.Forms.Label]) {
			$control.ForeColor = $text
			$control.BackColor = [System.Drawing.Color]::Transparent
		}
		elseif ($control -is [System.Windows.Forms.TabControl]) {
			$control.BackColor = $windowBack
			Initialize-GUITabTheme $control
		}
		elseif ($control -is [System.Windows.Forms.TabPage]) {
			$control.BackColor = $windowBack
			$control.ForeColor = $text
		}
		elseif ($control -is [System.Windows.Forms.Panel]) {
			$control.BackColor = $parentBack
		}

		if ($control.HasChildren) {
			foreach ($child in $control.Controls) { Set-ControlTheme $child }
		}
	}

	$mainForm.BackColor = $windowBack
	$mainForm.ForeColor = $text
	Set-ControlTheme $mainForm

	# 提示框跟主题走，否则深色下是一块扎眼的浅色。
	if ($Script:GUIToolTip) {
		$Script:GUIToolTip.BackColor = $surfaceBack
		$Script:GUIToolTip.ForeColor = $text
	}

	if ($Script:refs.TabsControl) { $Script:refs.TabsControl.Invalidate() }

	# 图标按钮的图标随主题前景色重新着色。
	Set-GUIButtonIcon $Script:refs.DarkModeSetButton "$PSScriptRoot\..\..\img\darklight.png" $text
	Set-GUIButtonIcon $Script:refs.BGMSetButton "$PSScriptRoot\..\..\img\music.png" $text

	# DWMWA_USE_IMMERSIVE_DARK_MODE
	[ps12exeGUI.Dwm]::SetWindowAttribute($mainForm.Handle, 20, [int]$dark)
	# DWMWA_BORDER_COLOR（颜色通道需要从 RGB 转成 BGR）
	$borderRgb = [int]$palette.BorderRgb
	$color = (($borderRgb -band 0xff) -shl 16) + ($borderRgb -band 0xff00) + (($borderRgb -shr 16) -band 0xff)
	[ps12exeGUI.Dwm]::SetWindowAttribute($mainForm.Handle, 34, $color)
}

# 跟随系统深浅色：只有系统设置本身发生变化才算「系统切换」，用户手动覆盖在此期间保持不变，系统再变则自动跟随接管。
# -SystemDark 仅供测试注入，缺省读注册表。
function Sync-GUIDarkMode {
	param([bool]$SystemDark)
	if (-not $PSBoundParameters.ContainsKey('SystemDark')) { $SystemDark = Get-SystemDarkMode }
	if ($SystemDark -ne $Script:SystemDarkMode) {
		$Script:SystemDarkMode = $SystemDark
		$Script:DarkModeOverride = $false
		if ($SystemDark -ne $Script:DarkMode) {
			$Script:DarkMode = $SystemDark
			Set-DarkMode $SystemDark
		}
	}
}

# UIMode 为 Auto（或未指定）时，定时跟随系统深浅色切换。
if ($UIMode -eq 'Auto' -or -not $UIMode) {
	if (-not $Script:DarkModeTimer) {
		$Script:DarkModeTimer = New-Object System.Windows.Forms.Timer
		$Script:DarkModeTimer.Interval = 2000
		$Script:DarkModeTimer.add_Tick({ Sync-GUIDarkMode })
		$Script:DarkModeTimer.Start()
	}
}
