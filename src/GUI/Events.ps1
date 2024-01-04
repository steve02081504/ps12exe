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


$Script:refs.CompileFileButton.add_Click({
		$OpenCompileFileDialog.ShowDialog() | Out-Null
		$Script:refs.CompileFileTextBox.Text = $OpenCompileFileDialog.FileName
	})
$Script:refs.OutputFileButton.add_Click({
		$OpenOutputFileDialog.ShowDialog() | Out-Null
		$Script:refs.OutputFileTextBox.Text = $OpenOutputFileDialog.FileName
	})
$Script:refs.IconFileButton.add_Click({
		$OpenIconFileDialog.ShowDialog() | Out-Null
		$Script:refs.IconFileTextBox.Text = $OpenIconFileDialog.FileName
	})
# 允许将文件拖放到文本框中
$Script:refs.CompileFileTextBox.add_DragEnter({
		if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
			$_.Effect = [Windows.Forms.DragDropEffects]::Copy
		}
		else {
			$_.Effect = [Windows.Forms.DragDropEffects]::None
		}
	})
$Script:refs.CompileFileTextBox.add_DragDrop({
		$_.Effect = [Windows.Forms.DragDropEffects]::None
		$Script:refs.CompileFileTextBox.Text = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
	})
$Script:refs.OutputFileTextBox.add_DragEnter({
		if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
			$_.Effect = [Windows.Forms.DragDropEffects]::Copy
		}
		else {
			$_.Effect = [Windows.Forms.DragDropEffects]::None
		}
	})
$Script:refs.OutputFileTextBox.add_DragDrop({
		$_.Effect = [Windows.Forms.DragDropEffects]::None
		$Script:refs.OutputFileTextBox.Text = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
	})
$Script:refs.IconFileTextBox.add_DragEnter({
		if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
			$_.Effect = [Windows.Forms.DragDropEffects]::Copy
		}
		else {
			$_.Effect = [Windows.Forms.DragDropEffects]::None
		}
	})
$Script:refs.IconFileTextBox.add_DragDrop({
		$_.Effect = [Windows.Forms.DragDropEffects]::None
		$Script:refs.IconFileTextBox.Text = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
	})

$Script:refs.ConsoleAppCheckBox.add_CheckedChanged({
		# 禁用控制台应用选项或窗口应用选项
		if ($Script:refs.ConsoleAppCheckBox.Checked) {
			$Script:refs.UnicodeEncodingCheckBox.Enabled = $true
			$Script:refs.CredentialGUICheckBox.Enabled = $true
			$Script:refs.IgnoreVisualStylesCheckBox.Enabled = $false
			$Script:refs.ExitOnCancelCheckBox.Enabled = $false
			$Script:refs.DPIAwareCheckBox.Enabled = $false
			$Script:refs.WinFormsDPIAwareCheckBox.Enabled = $false
		}
		else {
			$Script:refs.UnicodeEncodingCheckBox.Enabled = $false
			$Script:refs.CredentialGUICheckBox.Enabled = $false
			$Script:refs.IgnoreVisualStylesCheckBox.Enabled = $true
			$Script:refs.ExitOnCancelCheckBox.Enabled = $true
			$Script:refs.DPIAwareCheckBox.Enabled = $true
			$Script:refs.WinFormsDPIAwareCheckBox.Enabled = $true
		}
	})
# cpu架构选项只能选一个
$Script:refs.x64CheckBox.add_CheckedChanged({
		if ($Script:refs.x64CheckBox.Checked) {
			$Script:refs.x86CheckBox.Checked = $false
			$Script:refs.AnyCPUCheckBox.Checked = $false
			$Script:refs.x64CheckBox.AutoCheck = $false
		}
		else {
			$Script:refs.x64CheckBox.AutoCheck = $true
		}
	})
$Script:refs.x86CheckBox.add_CheckedChanged({
		if ($Script:refs.x86CheckBox.Checked) {
			$Script:refs.x64CheckBox.Checked = $false
			$Script:refs.AnyCPUCheckBox.Checked = $false
			$Script:refs.x86CheckBox.AutoCheck = $false
		}
		else {
			$Script:refs.x86CheckBox.AutoCheck = $true
		}
	})
$Script:refs.AnyCPUCheckBox.add_CheckedChanged({
		if ($Script:refs.AnyCPUCheckBox.Checked) {
			$Script:refs.x64CheckBox.Checked = $false
			$Script:refs.x86CheckBox.Checked = $false
			$Script:refs.AnyCPUCheckBox.AutoCheck = $false
		}
		else {
			$Script:refs.AnyCPUCheckBox.AutoCheck = $true
		}
	})
# 线程模型选项只能选一个
$Script:refs.SingleThreadCheckBox.add_CheckedChanged({
		if ($Script:refs.SingleThreadCheckBox.Checked) {
			$Script:refs.MultiThreadCheckBox.Checked = $false
			$Script:refs.SingleThreadCheckBox.AutoCheck = $false
		}
		else {
			$Script:refs.SingleThreadCheckBox.AutoCheck = $true
		}
	})
$Script:refs.MultiThreadCheckBox.add_CheckedChanged({
		if ($Script:refs.MultiThreadCheckBox.Checked) {
			$Script:refs.SingleThreadCheckBox.Checked = $false
			$Script:refs.MultiThreadCheckBox.AutoCheck = $false
		}
		else {
			$Script:refs.MultiThreadCheckBox.AutoCheck = $true
		}
	})
$Script:refs.CompileButton.add_Click({
		$Params = Get-ps12exeArgs
		$result = $null
		try {
			$result = ps12exe @Params | Out-String
		}
		catch {
			[System.Windows.Forms.MessageBox]::Show("$($Script:LocalizeData.ErrorHead) $($_.Exception.Message)", $Script:LocalizeData.CompileResult, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
			return
		}
		if (!$result) {
			$result = $Script:LocalizeData.DefaultResult
		}
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
$Script:refs.MainForm.add_FormClosing({
		if ($script:ConfingFile) {
			LoadCfgFile $script:ConfingFile
		}
		elseif ($Script:refs.CompileFileTextBox.Text) {
			[System.Windows.Forms.MessageBox]::Show($Script:LocalizeData.AskSaveCfg, $Script:LocalizeData.AskSaveCfgTitle, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) | Out-Null
			if ($_.Result -eq 'Yes') {
				SaveCfgFileAs
			}
		}
	})
