# 工具
function CallAndUse([scriptblock]$Scriptblock) {
	. $Scriptblock
	$Scriptblock
}
# enter和esc键绑定
$Script:refs.CancelButton = New-Object Windows.Forms.Button
$Script:refs.MainForm.CancelButton = $Script:refs.CancelButton
$Script:refs.CancelButton.add_Click({
	$Script:refs.MainForm.Close()
})
$Script:refs.MainForm.AcceptButton = $Script:refs.CompileButton

# 自动适应窗口大小
$Script:refs.MainForm.add_Load({
	$Script:refs.MainFormResizeHeight = $Script:refs.MainForm.Height
	$Script:refs.MainFormResizeWidth = $Script:refs.MainForm.Width
	# 使窗口暂时弹出在最前
	$Script:refs.MainForm.TopMost = $true
	$Script:refs.MainForm.TopMost = $false
})
$Script:refs.MainForm.add_SizeChanged({
	$widthRatio = $Script:refs.MainForm.Width / $Script:refs.MainFormResizeWidth
	$heightRatio = $Script:refs.MainForm.Height / $Script:refs.MainFormResizeHeight
	$Scale = New-Object System.Drawing.SizeF($widthRatio, $heightRatio)
	$Script:refs.MainFormResizeHeight = $Script:refs.MainForm.Height
	$Script:refs.MainFormResizeWidth = $Script:refs.MainForm.Width
	foreach ($Control in $Script:refs.MainForm.Controls) {
		$Fscale = ($heightRatio + $widthRatio) / 2
		$Fsize = $Control.Font.Size | ForEach-Object { $Fscale * $_ }
		$Control.Font = New-Object System.Drawing.Font($Control.Font.FontFamily, $Fsize, $Control.Font.Style)
		$Control.Scale($Scale)
	}
})

AutoFixer $Script:refs.MainForm.Controls

@(
	@{
		Button  = $Script:refs.CompileFileButton
		Dialog  = $OpenCompileFileDialog
		Control = $Script:refs.CompileFileTextBox
	},
	@{
		Button  = $Script:refs.OutputFileButton
		Dialog  = $OpenOutputFileDialog
		Control = $Script:refs.OutputFileTextBox
	},
	@{
		Button  = $Script:refs.IconFileButton
		Dialog  = $OpenIconFileDialog
		Control = $Script:refs.IconFileTextBox
	},
	@{
		Button  = $Script:refs.CertificatePathButton
		Dialog  = $OpenCertificateFileDialog
		Control = $Script:refs.CertificatePathTextBox
	}
) | ForEach-Object {
	$Button = $_.Button; $Dialog = $_.Dialog; $Control = $_.Control
	$Button.add_Click({
		$Dialog.ShowDialog() | Out-Null
		$Control.Text = $Dialog.FileName
	}.GetNewClosure())
}
# 允许将文件拖放到文本框中
@($Script:refs.CompileFileTextBox, $Script:refs.OutputFileTextBox, $Script:refs.IconFileTextBox, $Script:refs.CertificatePathTextBox) | ForEach-Object {
	$_.add_DragEnter({
		if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
			$_.Effect = [Windows.Forms.DragDropEffects]::Copy
		}
		else {
			$_.Effect = [Windows.Forms.DragDropEffects]::None
		}
	})
	$_.add_DragDrop({
		$_.Effect = [Windows.Forms.DragDropEffects]::None
		$this.Text = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
	})
}

$Script:refs.ConsoleAppCheckBox.add_CheckedChanged((CallAndUse {
	# 禁用控制台应用选项或窗口应用选项
	$Script:refs.ConsoleOptionsSplitterPanel.Controls | ForEach-Object {
		$_.Enabled = $Script:refs.ConsoleAppCheckBox.Checked
	}
	$Script:refs.WindowsOptionsSplitterPanel.Controls | ForEach-Object {
		$_.Enabled = !$Script:refs.ConsoleAppCheckBox.Checked
	}
}))
# cpu架构选项只能选一个
$ArchCheckBoxs = @($Script:refs.x64CheckBox, $Script:refs.x86CheckBox, $Script:refs.AnyCPUCheckBox)
$ArchCheckBoxs | ForEach-Object {
	$_.add_CheckStateChanged({
		if ($this.Checked) {
			$ArchCheckBoxs | ForEach-Object {
				if ($_ -ne $this) { $_.Checked = $false }
				else { $_.AutoCheck = $false }
			}
		}
		else {
			$this.AutoCheck = $true
		}
	})
}
# 线程模型选项只能选一个
$ThreadCheckBoxs = @($Script:refs.SingleThreadCheckBox, $Script:refs.MultiThreadCheckBox)
$ThreadCheckBoxs | ForEach-Object {
	$_.add_CheckStateChanged({
		if ($this.Checked) {
			$ThreadCheckBoxs | ForEach-Object {
				if ($_ -ne $this) { $_.Checked = $false }
				else { $_.AutoCheck = $false }
			}
		}
		else {
			$this.AutoCheck = $true
		}
	})
}
# 代码签名启用/禁用逻辑
$Script:refs.EnableCodeSigningCheckBox.add_CheckedChanged((CallAndUse {
	$enabled = $Script:refs.EnableCodeSigningCheckBox.Checked
	$Script:refs.CertificatePathTextBox.Enabled = $enabled
	$Script:refs.CertificatePathButton.Enabled = $enabled
	$Script:refs.CertificatePasswordTextBox.Enabled = $enabled
	$Script:refs.CertificateThumbprintTextBox.Enabled = $enabled
	$Script:refs.TimestampServerTextBox.Enabled = $enabled
}))
$Script:refs.CompileButton.add_Click({
	$Params = Get-ps12exeArgs
	if ($Script:ConfigFile) {
		$PathNow = Get-Location
		$projDir = Split-Path $Script:ConfigFile -Parent
		Set-Location $projDir
	}
	$result = try {
		ps12exe @Params -Localize $Localize -ErrorAction Stop | Out-String
	}
	catch { $LastExitCode = 1 }
	if ($Script:ConfigFile) { Set-Location $PathNow }
	if ($LastExitCode) {
		$e = $Error[0]
		$Message = if ($e.CategoryInfo.Category -ine "ParserError") {
			"$($Script:LocalizeData.ErrorHead) $($e.Exception.Message)"
		}
		else {
			($e, $e.TargetObject.Text) -join "`n"
		}
		[System.Windows.Forms.MessageBox]::Show([string]$Message, $Script:LocalizeData.CompileResult, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
		return
	}
	if (!$result) { $result = $Script:LocalizeData.DefaultResult }
	[System.Windows.Forms.MessageBox]::Show($result, $Script:LocalizeData.CompileResult, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$Script:refs.LoadCfgButton.add_Click({
	LoadCfgFile
})

$Script:refs.SaveCfgButton.add_Click({
	SaveCfgFile
})

$Script:refs.SaveCfg2OtherFileButton.add_Click({
	SaveCfgFileAs
})
$Script:DarkMode = $DarkMode
$Script:refs.DarkModeSetButton.BackGroundImage = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\..\img\darklight.png")
$Script:refs.DarkModeSetButton.add_Click({
	$Script:DarkMode = !$Script:DarkMode
	Set-DarkMode $Script:DarkMode
})
$Script:BGMPlaying = $true
$Script:refs.BGMSetButton.BackGroundImage = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\..\img\music.png")
$Script:refs.BGMSetButton.add_Click({
	if ($Script:BGMPlaying) { PauseMusic }
	else { ResumeMusic }
	$Script:BGMPlaying = !$Script:BGMPlaying
})
$Script:refs.MainForm.add_FormClosing({
	if ($script:ConfigFile) {
		if (!(Test-Path $script:ConfigFile)) {
			if (-not (AskSaveCfg)) { return }
		}
		SaveCfgFile $script:ConfigFile
	}
	elseif ($Script:refs.CompileFileTextBox.Text) {
		if (AskSaveCfg) {
			SaveCfgFileAs
		}
	}
})
