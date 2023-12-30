if($UIMode -eq 'Auto' -or -not $UIMode) {
	$DarkMode = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
	$DarkMode = $DarkMode -eq 0
}
else {
	$DarkMode = $UIMode -eq 'Dark'
}

if ($DarkMode) {
	$Script:refs['MainForm'].BackColor = [System.Drawing.ColorTranslator]::FromHtml('#333333')
	$Script:refs['MainForm'].ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')
	$Script:refs.Values | Where-Object { $_.GetType().Name -eq 'TextBox' } | ForEach-Object {
		$_.BackColor = 'WindowFrame'
		$_.ForeColor = 'Window'
		$_.BorderStyle = 'FixedSingle'
	}
	$Script:refs.Values | Where-Object { $_.GetType().Name -eq 'Button' } | ForEach-Object {
		$_.BackColor = 'WindowFrame'
		$_.FlatStyle = 'Flat'
	}
	$Script:refs.Values | Where-Object { $_.GetType().Name -eq 'CheckBox' } | ForEach-Object {
		$_.ForeColor = 'Window'
		$_.FlatStyle = 'Flat'
	}
	$Script:refs.Values | Where-Object { $_.GetType().Name -eq 'GroupBox' } | ForEach-Object {
		$_.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')
	}
	# DWMWA_USE_IMMERSIVE_DARK_MODE
	[psd]::SetWindowAttribute($Script:refs['MainForm'].Handle, 20, 1)
	# DWMWA_MICA_EFFECT
	[psd]::SetWindowAttribute($Script:refs['MainForm'].Handle, 1029 , 1)
	# DWMWA_BORDER_COLOR
	$color = 0x181818
	$color = (($color -band 0xff) -shl 16) + ($color -band 0xff00) + (($color -shr 16) -band 0xff)
	[psd]::SetWindowAttribute($Script:refs['MainForm'].Handle, 34, $color)
}
