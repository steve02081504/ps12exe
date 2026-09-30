# 按 schema 动态生成窗体与文件对话框。New-GUIForm 只构建、不显示，便于无头测试。

# 按点号路径在嵌套哈希表里取字符串叶子；缺键、中途不是表或叶子不是字符串时返回 $null。
function Resolve-NestedText {
	param($Data, [string]$Key)
	$current = $Data
	foreach ($part in ($Key -split '\.')) {
		if ($current -isnot [System.Collections.IDictionary] -or -not $current.Contains($part)) { return $null }
		$current = $current[$part]
	}
	if ($current -is [string]) { return $current }
	return $null
}

# GUI 文案三级回退：当前语言 GUI → en-US GUI → 键名本身。$Script:LocalizeData 缺失时也不崩。
function Get-GUIText {
	param([string]$Key)
	if ($Script:LocalizeData) {
		$text = Resolve-NestedText $Script:LocalizeData.GUI $Key
		if ($null -ne $text) { return $text }
	}
	if ($null -eq $Script:GUIFallback) {
		$Script:GUIFallback = @{}
		try {
			$en = & "$PSScriptRoot/../locale/en-US.ps1"
			if ($en -and $en.GUI) { $Script:GUIFallback = $en.GUI }
		}
		catch { }
	}
	$fallback = Resolve-NestedText $Script:GUIFallback $Key
	if ($null -ne $fallback) { return $fallback }
	return $Key
}

# 沿 ConsoleHelpData.PrarmsData 的点号路径取帮助文本，去掉 markdown 反引号。
function Get-ParamHelp {
	param([string]$Path)
	if (-not $Path -or -not $Script:LocalizeData) { return '' }
	$help = Resolve-NestedText $Script:LocalizeData.ConsoleHelpData.PrarmsData $Path
	if ($null -eq $help) { return '' }
	return ($help -replace '`', '').Trim()
}

# 字段帮助文案：schema 显式指定 Help 时取 GUI 文案，否则按 Path 从参数帮助取。
function Get-FieldHelp {
	param($Field)
	if ($Field.Help) { return Get-GUIText $Field.Help }
	return Get-ParamHelp $Field.Path
}

function New-GUIRowStyle {
	return New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)
}

function New-GUIPercentRowStyle {
	param([float]$Percent = 100)
	return New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, $Percent)
}

function New-GUIButton {
	param([string]$Text)
	$button = New-Object System.Windows.Forms.Button
	$button.Text = $Text
	$button.AutoSize = $true
	$button.AutoSizeMode = 'GrowAndShrink'
	$button.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)
	$button.Margin = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)
	$button.MinimumSize = New-Object System.Drawing.Size(0, 25)
	return $button
}

# 跨两列的字段组标题（Flags/DllExports 这类整块控件用）。
function New-GUISectionLabel {
	param([string]$Text, [System.Windows.Forms.TableLayoutPanel]$Grid, [int]$Row)
	$label = New-Object System.Windows.Forms.Label
	$label.Text = $Text
	$label.AutoSize = $true
	$label.Anchor = [System.Windows.Forms.AnchorStyles]::Left
	$label.TextAlign = 'MiddleLeft'
	$label.Margin = New-Object System.Windows.Forms.Padding(4, 4, 4, 0)
	$Grid.Controls.Add($label, 0, $Row)
	$Grid.SetColumnSpan($label, 2)
	return $label
}

function New-GUIOptionFlow {
	$flow = New-Object System.Windows.Forms.FlowLayoutPanel
	$flow.AutoSize = $true
	$flow.Dock = 'Top'
	$flow.FlowDirection = 'LeftToRight'
	$flow.Margin = New-Object System.Windows.Forms.Padding(2, 0, 4, 4)
	return $flow
}

# 生成一个字段对应的控件；返回占用的表格行数。
function New-GUIFieldRow {
	param(
		$Field,
		[System.Windows.Forms.TableLayoutPanel]$Grid,
		[int]$Row
	)
	$path = $Field.Path
	$labelKey = if ($Field.Label) { $Field.Label } else { "Field.$path" }
	$labelText = Get-GUIText $labelKey
	$help = Get-FieldHelp $Field
	$toolTip = $Script:GUIToolTip

	switch ($Field.Kind) {
		'Bool' {
			$box = New-Object System.Windows.Forms.CheckBox
			$box.Text = $labelText
			$box.AutoSize = $true
			$box.Checked = [bool]$Field.Default
			$box.Margin = New-Object System.Windows.Forms.Padding(4, 5, 4, 5)
			$Grid.Controls.Add($box, 0, $Row)
			$Grid.SetColumnSpan($box, 2)
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			$toolTip.SetToolTip($box, $help)
			$Script:FieldControls[$path] = $box
			return 1
		}
		'Flags' {
			$label = New-GUISectionLabel $labelText $Grid $Row
			$flow = New-GUIOptionFlow
			$selected = @($Field.Default | ForEach-Object { [string]$_ })
			foreach ($option in $Field.Options) {
				$box = New-Object System.Windows.Forms.CheckBox
				$box.Text = [string]$option
				$box.AutoSize = $true
				$box.Checked = $selected -contains [string]$option
				$box.Margin = New-Object System.Windows.Forms.Padding(2, 2, 8, 2)
				$flow.Controls.Add($box)
			}
			$Grid.Controls.Add($flow, 0, $Row + 1)
			$Grid.SetColumnSpan($flow, 2)
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			$toolTip.SetToolTip($label, $help)
			$toolTip.SetToolTip($flow, $help)
			$Script:FieldControls[$path] = $flow
			return 2
		}
		'DllExports' {
			$label = New-GUISectionLabel $labelText $Grid $Row
			$flow = New-GUIOptionFlow
			$addButton = New-GUIButton (Get-GUIText 'Button.AddExport')
			$removeButton = New-GUIButton (Get-GUIText 'Button.RemoveExport')
			$helpLabel = New-Object System.Windows.Forms.Label
			$helpLabel.Text = $help
			$helpLabel.AutoSize = $true
			$helpLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left
			$helpLabel.TextAlign = 'MiddleLeft'
			$helpLabel.Margin = New-Object System.Windows.Forms.Padding(8, 6, 4, 0)
			$flow.Controls.Add($addButton)
			$flow.Controls.Add($removeButton)
			$flow.Controls.Add($helpLabel)
			$Grid.Controls.Add($flow, 0, $Row + 1)
			$Grid.SetColumnSpan($flow, 2)

			$gridView = New-Object System.Windows.Forms.DataGridView
			$gridView.AutoSizeColumnsMode = 'Fill'
			$gridView.AllowUserToAddRows = $true
			$gridView.AllowUserToResizeRows = $false
			$gridView.Dock = 'Fill'
			$gridView.Margin = New-Object System.Windows.Forms.Padding(4, 0, 4, 4)
			$gridView.RowHeadersVisible = $false
			$gridView.SelectionMode = 'FullRowSelect'
			$gridView.ColumnHeadersHeightSizeMode = 'DisableResizing'
			$gridView.ColumnHeadersHeight = 30
			$gridView.RowTemplate.Height = 26
			$gridView.BorderStyle = 'FixedSingle'
			$gridView.MinimumSize = New-Object System.Drawing.Size(0, 130)
			foreach ($column in @(
					@{ Name = 'FuncName'; Header = 'Field.Build.DllExports.FuncName' }
					@{ Name = 'ReturnType'; Header = 'Field.Build.DllExports.ReturnType' }
					@{ Name = 'Params'; Header = 'Field.Build.DllExports.Params' }
				)) {
				$columnControl = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
				$columnControl.Name = $column.Name
				$columnControl.HeaderText = Get-GUIText $column.Header
				[void]$gridView.Columns.Add($columnControl)
			}
			$Grid.Controls.Add($gridView, 0, $Row + 2)
			$Grid.SetColumnSpan($gridView, 2)
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			$toolTip.SetToolTip($label, $help)
			$toolTip.SetToolTip($gridView, $help)
			$Script:refs.AddExportButton = $addButton
			$Script:refs.RemoveExportButton = $removeButton
			$Script:FieldControls[$path] = $gridView
			return 3
		}
		default {
			$label = New-Object System.Windows.Forms.Label
			$label.Text = $labelText
			$label.AutoSize = $true
			$label.Anchor = [System.Windows.Forms.AnchorStyles]::Left
			$label.TextAlign = 'MiddleLeft'
			$label.Margin = New-Object System.Windows.Forms.Padding(4, 6, 12, 6)
			$Grid.Controls.Add($label, 0, $Row)

			$control = $null
			$browseButton = $null
			switch ($Field.Kind) {
				'Choice' {
					$control = New-Object System.Windows.Forms.ComboBox
					$control.DropDownStyle = 'DropDownList'
					foreach ($choice in $Field.Choices) { [void]$control.Items.Add([string]$choice) }
					$default = [string]$Field.Default
					if (@($control.Items | ForEach-Object { [string]$_ }) -contains $default) { $control.SelectedItem = $default }
					elseif ($control.Items.Count -gt 0) { $control.SelectedIndex = 0 }
				}
				'ChoiceEdit' {
					$control = New-Object System.Windows.Forms.ComboBox
					$control.DropDownStyle = 'DropDown'
					foreach ($choice in $Field.Choices) { [void]$control.Items.Add([string]$choice) }
					$control.Text = [string]$Field.Default
				}
				'Password' {
					$control = New-Object System.Windows.Forms.TextBox
					$control.PasswordChar = '*'
					$control.Text = [string]$Field.Default
				}
				'Script' {
					$control = New-Object System.Windows.Forms.TextBox
					$control.Multiline = $true
					$control.AcceptsReturn = $true
					$control.ScrollBars = 'Vertical'
					$rows = if ($Field.Rows) { [int]$Field.Rows } else { 3 }
					$lineHeight = [int](($control.Font.Height * $rows) + 8)
					$control.MinimumSize = New-Object System.Drawing.Size -ArgumentList 0, $lineHeight
					$control.Text = [string]$Field.Default
				}
				'Path' {
					$pathPanel = New-Object System.Windows.Forms.TableLayoutPanel
					$pathPanel.Dock = 'Fill'
					$pathPanel.AutoSize = $true
					$pathPanel.AutoSizeMode = 'GrowAndShrink'
					$pathPanel.ColumnCount = 2
					$pathPanel.RowCount = 1
					[void]$pathPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
					[void]$pathPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
					[void]$pathPanel.RowStyles.Add((New-GUIRowStyle))

					$control = New-Object System.Windows.Forms.TextBox
					$control.Dock = 'Fill'
					$control.AllowDrop = $true
					$control.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
					$control.Text = [string]$Field.Default

					$browseButton = New-GUIButton (Get-GUIText 'Button.Browse')
					$browseButton.Margin = New-Object System.Windows.Forms.Padding(0)
					if ($browseButton.Text -eq 'Button.Browse') { $browseButton.Text = '...' }

					$pathPanel.Controls.Add($control, 0, 0)
					$pathPanel.Controls.Add($browseButton, 1, 0)
					$textControl = $control
					$inputControl = $pathPanel
				}
				default {
					$control = New-Object System.Windows.Forms.TextBox
					$control.Text = [string]$Field.Default
				}
			}

			if (-not $inputControl) { $inputControl = $control; $textControl = $control }
			$inputControl.Dock = 'Fill'
			$inputControl.Margin = New-Object System.Windows.Forms.Padding(0, 4, 4, 4)
			$Grid.Controls.Add($inputControl, 1, $Row)
			[void]$Grid.RowStyles.Add((New-GUIRowStyle))
			if ($browseButton) { $Script:FieldBrowse[$path] = $browseButton }

			$toolTip.SetToolTip($label, $help)
			$toolTip.SetToolTip($textControl, $help)
			if ($browseButton) { $toolTip.SetToolTip($browseButton, $help) }
			$Script:FieldControls[$path] = $textControl
			return 1
		}
	}
}

# 可点击链接：整段文字作为 LinkData 区域，点击用系统浏览器打开。
function New-GUILinkLabel {
	param([string]$Text, [string]$Url)
	$link = New-Object System.Windows.Forms.LinkLabel
	$link.Text = $Text
	$link.AutoSize = $true
	[void]$link.Links.Add(0, $Text.Length, $Url)
	$link.add_LinkClicked({ param($sender, $e) Open-GUIUrl ([string]$e.Link.LinkData) })
	return $link
}

# 关于页：应用名（含版本）+ 描述 + 仓库/Issue/文档链接，无参数字段。
# 沿用其它页的「AutoScroll 宿主 Panel + AutoSize 内容表格」约定（见 gui.layout 的可达性校验）。
function New-GUIAboutPanel {
	$panel = New-Object System.Windows.Forms.Panel
	$panel.Dock = 'Fill'
	$panel.AutoScroll = $true

	$grid = New-Object System.Windows.Forms.TableLayoutPanel
	$grid.Dock = 'Top'
	$grid.AutoSize = $true
	$grid.AutoSizeMode = 'GrowAndShrink'
	$grid.Padding = New-Object System.Windows.Forms.Padding(20, 16, 20, 16)
	$grid.ColumnCount = 1
	[void]$grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
	$panel.Controls.Add($grid)

	# 单列表格，每个控件占一行；行号即已有控件数。
	function Add-GUIAboutRow($Control) {
		$Control.AutoSize = $true
		$Control.Anchor = [System.Windows.Forms.AnchorStyles]::Left
		$Control.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 0)
		$grid.Controls.Add($Control, 0, $grid.Controls.Count)
		[void]$grid.RowStyles.Add((New-GUIRowStyle))
	}

	$title = New-Object System.Windows.Forms.Label
	$title.Text = Get-GUIText 'About.Title'
	try { $title.Font = New-Object System.Drawing.Font($Script:refs.MainForm.Font.FontFamily, 16, [System.Drawing.FontStyle]::Bold) } catch { }
	Add-GUIAboutRow $title

	$version = Get-ps12exeVersion
	if ($version) {
		$versionLabel = New-Object System.Windows.Forms.Label
		$versionLabel.Text = "$(Get-GUIText 'About.Version') $version"
		Add-GUIAboutRow $versionLabel
	}

	$description = New-Object System.Windows.Forms.Label
	$description.Text = Get-GUIText 'About.Description'
	$description.MaximumSize = New-Object System.Drawing.Size(640, 0)
	Add-GUIAboutRow $description

	foreach ($link in @(
			@{ Text = 'About.Repository'; Url = 'https://github.com/steve02081504/ps12exe' }
			@{ Text = 'About.Issues'; Url = 'https://github.com/steve02081504/ps12exe/issues' }
			@{ Text = 'About.Documentation'; Url = 'https://github.com/steve02081504/ps12exe#readme' }
		)) {
		Add-GUIAboutRow (New-GUILinkLabel -Text (Get-GUIText $link.Text) -Url $link.Url)
	}

	return $panel
}

function New-GUIForm {
	$Script:refs = @{}
	$Script:FieldControls = @{}
	$Script:FieldBrowse = @{}
	$Script:GUIToolTip = New-Object System.Windows.Forms.ToolTip

	$form = New-Object System.Windows.Forms.Form
	$form.Text = Get-GUIText 'Window.Title'
	$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
	$form.ClientSize = New-Object System.Drawing.Size(1040, 780)
	$form.MinimumSize = New-Object System.Drawing.Size(900, 660)
	try { $form.Font = New-Object System.Drawing.Font('Segoe UI', 9) } catch { }
	$Script:refs.MainForm = $form

	$root = New-Object System.Windows.Forms.TableLayoutPanel
	$root.Dock = 'Fill'
	$root.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 10)
	$root.ColumnCount = 1
	$root.RowCount = 3
	[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
	[void]$root.RowStyles.Add((New-GUIPercentRowStyle 100))
	[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 130)))
	[void]$root.RowStyles.Add((New-GUIRowStyle))
	$form.Controls.Add($root)

	$tabs = New-Object System.Windows.Forms.TabControl
	$tabs.Dock = 'Fill'
	$root.Controls.Add($tabs, 0, 0)
	$Script:refs.TabsControl = $tabs

	foreach ($page in $Script:GUISchema.Pages) {
		$tabPage = New-Object System.Windows.Forms.TabPage
		$tabPage.Text = Get-GUIText $page.Label

		if ($page.Type -eq 'About') {
			$tabPage.Controls.Add((New-GUIAboutPanel))
			$tabs.TabPages.Add($tabPage)
			continue
		}

		# TableLayoutPanel 的 AutoScroll 在 Dock=Fill + Percent 行的组合下不会为 AutoSize 分组撑出滚动条，
		# 导致靠下的分组（如 DLL 导出）被裁掉且无法滚动到。改为外层 Panel 负责滚动、内层 AutoSize 表格随内容长高。
		$pageScroll = New-Object System.Windows.Forms.Panel
		$pageScroll.Dock = 'Fill'
		$pageScroll.AutoScroll = $true
		$tabPage.Controls.Add($pageScroll)

		$pageGrid = New-Object System.Windows.Forms.TableLayoutPanel
		$pageGrid.Dock = 'Top'
		$pageGrid.AutoSize = $true
		$pageGrid.AutoSizeMode = 'GrowAndShrink'
		$pageGrid.Padding = New-Object System.Windows.Forms.Padding(8)
		$pageGrid.ColumnCount = 1
		[void]$pageGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
		$pageScroll.Controls.Add($pageGrid)
		$tabs.TabPages.Add($tabPage)

		$groupRow = 0
		foreach ($group in $page.Groups) {
			$groupBox = New-Object ps12exeGUI.FlatGroupBox
			$groupBox.Text = Get-GUIText $group.Label
			$groupBox.AutoSize = $true
			$groupBox.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 12)
			$groupBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
			$groupBox.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)

			# GroupBox.AutoSize 只看子控件的 PreferredSize；Dock=Fill 的子控件会被忽略而让分组塌成标题高。
			# 让 fieldGrid 自身 AutoSize + Dock=Top，分组才能撑到内容高度，同时宽度随分组拉伸。
			$fieldGrid = New-Object System.Windows.Forms.TableLayoutPanel
			$fieldGrid.AutoSize = $true
			$fieldGrid.AutoSizeMode = 'GrowAndShrink'
			$fieldGrid.Dock = 'Top'
			$fieldGrid.ColumnCount = 2
			[void]$fieldGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
			[void]$fieldGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
			$groupBox.Controls.Add($fieldGrid)

			$fieldRow = 0
			foreach ($field in $group.Fields) {
				$fieldRow += New-GUIFieldRow -Field $field -Grid $fieldGrid -Row $fieldRow
			}

			[void]$pageGrid.RowStyles.Add((New-GUIRowStyle))
			$pageGrid.Controls.Add($groupBox, 0, $groupRow)
			$groupRow++
		}
	}

	$log = New-Object System.Windows.Forms.TextBox
	$log.Multiline = $true
	$log.ReadOnly = $true
	$log.ScrollBars = 'Vertical'
	$log.Dock = 'Fill'
	$log.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 8)
	try { $log.Font = New-Object System.Drawing.Font('Consolas', 9) } catch { }
	$root.Controls.Add($log, 0, 1)
	$Script:refs.LogTextBox = $log

	$bottom = New-Object System.Windows.Forms.TableLayoutPanel
	$bottom.Dock = 'Fill'
	$bottom.ColumnCount = 2
	$bottom.RowCount = 1
	[void]$bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
	[void]$bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
	[void]$bottom.RowStyles.Add((New-GUIRowStyle))

	$cfgFileLabel = New-Object System.Windows.Forms.Label
	$cfgFileLabel.Text = Get-GUIText 'Label.CfgFileHead'
	$cfgFileLabel.Dock = 'Fill'
	$cfgFileLabel.AutoSize = $false
	$cfgFileLabel.TextAlign = 'MiddleLeft'
	$bottom.Controls.Add($cfgFileLabel, 0, 0)
	$Script:refs.CfgFileLabel = $cfgFileLabel

	$rightFlow = New-Object System.Windows.Forms.FlowLayoutPanel
	$rightFlow.AutoSize = $true
	$rightFlow.AutoSizeMode = 'GrowAndShrink'
	$rightFlow.WrapContents = $false
	$rightFlow.FlowDirection = 'LeftToRight'
	$rightFlow.Anchor = [System.Windows.Forms.AnchorStyles]::Right

	$loadCfgButton = New-GUIButton (Get-GUIText 'Button.LoadCfg')
	$saveCfgButton = New-GUIButton (Get-GUIText 'Button.SaveCfg')
	$saveCfg2OtherFileButton = New-GUIButton (Get-GUIText 'Button.SaveAsCfg')
	$darkModeSetButton = New-GUIButton (Get-GUIText 'Button.DarkMode')
	$bgmSetButton = New-GUIButton (Get-GUIText 'Button.BGM')
	# 图标在 DarkMode.ps1 里按主题着色后挂到 Image 上，这里只负责排布。
	$darkModeSetButton.TextImageRelation = 'ImageBeforeText'
	$bgmSetButton.TextImageRelation = 'ImageBeforeText'
	$compileButton = New-GUIButton (Get-GUIText 'Button.Compile')
	$compileButton.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
	$compileButton.Margin = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
	$compileButton.MinimumSize = New-Object System.Drawing.Size(110, 30)

	$rightFlow.Controls.Add($loadCfgButton)
	$rightFlow.Controls.Add($saveCfgButton)
	$rightFlow.Controls.Add($saveCfg2OtherFileButton)
	$rightFlow.Controls.Add($darkModeSetButton)
	$rightFlow.Controls.Add($bgmSetButton)
	$rightFlow.Controls.Add($compileButton)
	$bottom.Controls.Add($rightFlow, 1, 0)
	$root.Controls.Add($bottom, 0, 2)

	$Script:refs.LoadCfgButton = $loadCfgButton
	$Script:refs.SaveCfgButton = $saveCfgButton
	$Script:refs.SaveCfg2OtherFileButton = $saveCfg2OtherFileButton
	$Script:refs.DarkModeSetButton = $darkModeSetButton
	$Script:refs.BGMSetButton = $bgmSetButton
	$Script:refs.CompileButton = $compileButton

	$cancelButton = New-Object System.Windows.Forms.Button
	$cancelButton.Visible = $false
	$form.Controls.Add($cancelButton)
	$form.CancelButton = $cancelButton
	$Script:refs.CancelButton = $cancelButton

	$Script:refs.CompileFileTextBox = $Script:FieldControls['inputFile']
	$Script:refs.OutputFileTextBox = $Script:FieldControls['outputFile']

	return $form
}

function New-GUIDialogs {
	# 仅在 GUI 文案提供了合法的过滤器语法（"描述|模式"）时才设置，避免缺翻译时崩。
	function Set-GUIDialogFilter($dialog, [string]$key) {
		$filter = Get-GUIText $key
		if ($filter -like '*|*') { $dialog.Filter = $filter }
	}

	$dialogs = @{}
	$dialogs.Compile = New-Object System.Windows.Forms.OpenFileDialog
	$dialogs.Compile.Title = Get-GUIText 'Dialog.Compile.Title'
	Set-GUIDialogFilter $dialogs.Compile 'Dialog.Compile.Filter'
	$dialogs.Compile.DefaultExt = 'ps1'

	$dialogs.Output = New-Object System.Windows.Forms.SaveFileDialog
	$dialogs.Output.Title = Get-GUIText 'Dialog.Output.Title'
	Set-GUIDialogFilter $dialogs.Output 'Dialog.Output.Filter'
	$dialogs.Output.DefaultExt = 'exe'

	$dialogs.Icon = New-Object System.Windows.Forms.OpenFileDialog
	$dialogs.Icon.Title = Get-GUIText 'Dialog.Icon.Title'
	Set-GUIDialogFilter $dialogs.Icon 'Dialog.Icon.Filter'
	$dialogs.Icon.DefaultExt = 'ico'

	$dialogs.Certificate = New-Object System.Windows.Forms.OpenFileDialog
	$dialogs.Certificate.Title = Get-GUIText 'Dialog.Certificate.Title'
	Set-GUIDialogFilter $dialogs.Certificate 'Dialog.Certificate.Filter'
	$dialogs.Certificate.DefaultExt = 'pfx'

	$dialogs.Folder = New-Object System.Windows.Forms.FolderBrowserDialog
	$dialogs.Folder.Description = Get-GUIText 'Dialog.Folder.Title'

	$dialogs.OpenCfg = New-Object System.Windows.Forms.OpenFileDialog
	$dialogs.OpenCfg.Title = Get-GUIText 'Dialog.OpenCfg.Title'
	Set-GUIDialogFilter $dialogs.OpenCfg 'Dialog.OpenCfg.Filter'

	$dialogs.SaveCfg = New-Object System.Windows.Forms.SaveFileDialog
	$dialogs.SaveCfg.Title = Get-GUIText 'Dialog.SaveCfg.Title'
	Set-GUIDialogFilter $dialogs.SaveCfg 'Dialog.SaveCfg.Filter'

	$Script:dialogs = $dialogs

	return $dialogs
}
