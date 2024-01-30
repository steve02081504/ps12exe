if ($UIMode -eq 'Auto' -or -not $UIMode) {
	$DarkMode = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
	$DarkMode = $DarkMode -eq 0
}
else {
	$DarkMode = $UIMode -eq 'Dark'
}

if ($DarkMode) {
	$Script:refs.MainForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#333333')
	$Script:refs.MainForm.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')
	function ForEachControl($Control, $RunScriptBlock) {
		$Script:refs.Values | Where-Object { $_.GetType().Name -eq $Control } | ForEach-Object $RunScriptBlock
	}
	ForEachControl 'TextBox' {
		$_.BackColor = 'WindowFrame'
		$_.ForeColor = 'Window'
		$_.BorderStyle = 'FixedSingle'
	}
	ForEachControl 'Button' {
		$_.BackColor = 'WindowFrame'
		$_.FlatStyle = 'Flat'
	}
	ForEachControl 'CheckBox' {
		$_.ForeColor = 'Window'
		$_.FlatStyle = 'Flat'
	}
	ForEachControl 'GroupBox' {
		$_.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')
	}
	# DWMWA_USE_IMMERSIVE_DARK_MODE
	[Dwm]::SetWindowAttribute($Script:refs.MainForm.Handle, 20, 1)
	# DWMWA_MICA_EFFECT
	[Dwm]::SetWindowAttribute($Script:refs.MainForm.Handle, 1029 , 1)
	# DWMWA_BORDER_COLOR
	$color = 0x181818
	$color = (($color -band 0xff) -shl 16) + ($color -band 0xff00) + (($color -shr 16) -band 0xff)
	[Dwm]::SetWindowAttribute($Script:refs.MainForm.Handle, 34, $color)
}
