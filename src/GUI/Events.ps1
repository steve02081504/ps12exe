# GUI 事件绑定：字段联动、浏览按钮、编译按钮与窗体关闭。
# 全部绑定集中在 Register-GUIEvents，dot-source 本文件不产生副作用。

# 弹对应文件/文件夹对话框，确定后把结果写回文本框。
function Show-FieldBrowse {
	param(
		[string]$BrowseKey,
		[System.Windows.Forms.Control]$TextBox
	)
	$dialog = Get-GUIDialog $BrowseKey
	if (-not $dialog) { return }
	if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
	if ($BrowseKey -eq 'Folder') { $TextBox.Text = $dialog.SelectedPath }
	else { $TextBox.Text = $dialog.FileName }
}

function Invoke-GUIUpdate {
	if ($Script:UpdatingUI) { return }
	Update-UIState
}

function Register-GUIEvents {
	$refs = $Script:refs

	# 回车即编译
	$refs.MainForm.AcceptButton = $refs.CompileButton

	# 配置文件的加载/保存/另存为
	$refs.LoadCfgButton.add_Click({ LoadCfgFile })
	$refs.SaveCfgButton.add_Click({ SaveCfgFile })
	$refs.SaveCfg2OtherFileButton.add_Click({ SaveCfgFileAs })

	# 深色模式切换（DarkMode.ps1 已初始化 $Script:DarkMode，并负责给按钮着色图标）
	$refs.DarkModeSetButton.add_Click({
		$Script:DarkModeOverride = $true
		$Script:DarkMode = -not $Script:DarkMode
		Set-DarkMode $Script:DarkMode
	})

	# 首次显示时把窗体拉到前台：隐藏控制台后进程可能拿不到前台权限，窗体会躲在后面不弹出来。
	$refs.MainForm.add_Shown({
		$refs.MainForm.TopMost = $true
		$refs.MainForm.Activate()
		$refs.MainForm.BringToFront()
		[void][ps12exeGUI.Win32]::SetForegroundWindow($refs.MainForm.Handle)
		$refs.MainForm.TopMost = $false
	})

	# 背景音乐开关
	$Script:BGMPlaying = $true
	$refs.BGMSetButton.add_Click({
		if ($Script:BGMPlaying) { PauseMusic }
		else { ResumeMusic }
		$Script:BGMPlaying = -not $Script:BGMPlaying
	})

	# 每个字段的值变化都触发一次界面可用状态刷新
	if ($Script:FieldControls) {
		foreach ($field in Get-GUIAllFields) {
			$control = Get-FieldControl $field.Path
			if (-not $control) { continue }
			switch ($field.Kind) {
				'Bool' { $control.add_CheckedChanged({ Invoke-GUIUpdate }) }
				'Choice' {
					$control.add_SelectedIndexChanged({ Invoke-GUIUpdate })
					$control.add_TextChanged({ Invoke-GUIUpdate })
				}
				'ChoiceEdit' { $control.add_TextChanged({ Invoke-GUIUpdate }) }
				'Flags' {
					foreach ($box in (Get-DescendantControls $control | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })) {
						$box.add_CheckedChanged({ Invoke-GUIUpdate })
					}
				}
				default { $control.add_TextChanged({ Invoke-GUIUpdate }) }
			}
		}
	}

	# Path 字段的浏览按钮与拖放支持
	foreach ($field in Get-GUIAllFields) {
		if ($field.Kind -ne 'Path') { continue }
		$control = Get-FieldControl $field.Path
		if (-not $control) { continue }
		$control.AllowDrop = $true
		$control.add_DragEnter({
			$_.Effect = if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
				[Windows.Forms.DragDropEffects]::Copy
			}
			else {
				[Windows.Forms.DragDropEffects]::None
			}
		})
		$control.add_DragDrop({
			$_.Effect = [Windows.Forms.DragDropEffects]::None
			$files = @($_.Data.GetData([Windows.Forms.DataFormats]::FileDrop))
			if ($files.Count) { $this.Text = $files[0] }
		})
		$browse = Get-FieldBrowseControl $field.Path
		if ($browse) {
			$browseKey = $field.Browse
			$browse.add_Click({
				Show-FieldBrowse -BrowseKey $browseKey -TextBox $control
			}.GetNewClosure())
		}
	}

	# DllExports 表格的增删按钮（Layout 可能不提供）
	if ($refs.AddExportButton) {
		$refs.AddExportButton.add_Click({
			$grid = Get-FieldControl 'Build.DllExports'
			if ($grid) { [void]$grid.Rows.Add() }
		})
	}
	if ($refs.RemoveExportButton) {
		$refs.RemoveExportButton.add_Click({
			$grid = Get-FieldControl 'Build.DllExports'
			if (-not $grid) { return }
			$selected = @($grid.SelectedRows | Where-Object { -not $_.IsNewRow })
			if (-not $selected.Count -and $grid.CurrentRow -and -not $grid.CurrentRow.IsNewRow) { $selected = @($grid.CurrentRow) }
			foreach ($row in $selected) {
				if (-not $row.IsNewRow) { $grid.Rows.Remove($row) }
			}
		})
	}

	# 编译/取消共用一个按钮
	$refs.CompileButton.add_Click({
		if (Test-GUICompileRunning) { Stop-GUICompile }
		else { Start-GUICompile }
	})

	# 关闭窗体：编译中先确认，之后再按需保存配置
	$refs.MainForm.add_FormClosing({
		param($sender, $e)
		if (Test-GUICompileRunning) {
			$answer = [System.Windows.Forms.MessageBox]::Show((Get-GUIText 'Log.Compiling'), (Get-GUIText 'Window.Title'), [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
			if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
				Stop-GUICompile
				$e.Cancel = $true
			}
			return
		}
		if ($Script:ConfigFile) {
			if (Test-UIDirty) { SaveCfgFile }
		}
		elseif ($refs.CompileFileTextBox.Text -and (AskSaveCfg)) {
			SaveCfgFileAs
		}
	})
}
