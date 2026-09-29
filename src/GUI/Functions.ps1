# GUI 的 UIData ↔ 控件双向映射、点号路径工具、配置文件读写与 ps12exe 参数组装。

# 遍历 schema 的所有字段并缓存，避免每次调用都重新展开。
function Get-GUIAllFields {
	if (-not $Script:GUISchemaFieldList) {
		$list = New-Object System.Collections.ArrayList
		$map = @{}
		foreach ($page in (Get-GUISchema).Pages) {
			foreach ($group in $page.Groups) {
				foreach ($field in $group.Fields) {
					[void]$list.Add($field)
					$map[$field.Path] = $field
				}
			}
		}
		$Script:GUISchemaFieldList = $list
		$Script:GUISchemaFieldMap = $map
	}
	return $Script:GUISchemaFieldList
}

function Get-GUIField {
	param([string]$Path)
	[void](Get-GUIAllFields)
	return $Script:GUISchemaFieldMap[$Path]
}

# 点号路径读写嵌套哈希：中间层不存在则创建（只支持哈希表，不支持数组下标）。
function Get-NestedValue {
	param(
		[System.Collections.IDictionary]$UIData,
		[string]$Path
	)
	$current = $UIData
	foreach ($part in ($Path -split '\.')) {
		if ($current -isnot [System.Collections.IDictionary]) { return $null }
		if (-not $current.Contains($part)) { return $null }
		$current = $current[$part]
	}
	return $current
}

function Set-NestedValue {
	param(
		[System.Collections.IDictionary]$UIData,
		[string]$Path,
		$Value
	)
	$parts = $Path -split '\.'
	$current = $UIData
	for ($i = 0; $i -lt $parts.Count - 1; $i++) {
		$part = $parts[$i]
		if (-not $current.Contains($part) -or $current[$part] -isnot [System.Collections.IDictionary]) {
			$current[$part] = @{}
		}
		$current = $current[$part]
	}
	$current[$parts[-1]] = $Value
}

# 从以点号路径/键名为索引的哈希取引用，未就绪时安全返回 $null。
function Get-GUIRef {
	param($Table, [string]$Key)
	if ($Table -is [System.Collections.IDictionary] -and $Table.Contains($Key)) { return $Table[$Key] }
	return $null
}

function Get-FieldControl {
	param([string]$Path)
	return Get-GUIRef $Script:FieldControls $Path
}

function Get-FieldBrowseControl {
	param([string]$Path)
	return Get-GUIRef $Script:FieldBrowse $Path
}

# 递归枚举某个容器下的所有子控件（Flags 的选项 CheckBox 可能嵌在面板里）。
function Get-DescendantControls {
	param([System.Windows.Forms.Control]$Control)
	foreach ($child in $Control.Controls) {
		$child
		if ($child.HasChildren) { Get-DescendantControls $child }
	}
}

function Get-FlagValues {
	param($Container)
	@(Get-DescendantControls $Container | Where-Object { $_ -is [System.Windows.Forms.CheckBox] -and $_.Checked } | ForEach-Object { $_.Text })
}

function Get-DllExportCellText {
	param($Row, [string]$ColumnName)
	return [string]$Row.Cells[$Row.DataGridView.Columns[$ColumnName].Index].Value
}

# DataGridView → DllExports 数组。Params 为逗号分隔的 "type name"，缺名字时自动 argN。
function Get-DllExportsValue {
	param($Grid)
	$result = @()
	foreach ($row in $Grid.Rows) {
		if ($row.IsNewRow) { continue }
		$funcName = Get-DllExportCellText $row 'FuncName'
		if (-not $funcName) { continue }
		$returnType = Get-DllExportCellText $row 'ReturnType'
		$paramsText = Get-DllExportCellText $row 'Params'
		$params = @()
		$index = 0
		foreach ($item in ($paramsText -split ',')) {
			$item = $item.Trim()
			if (-not $item) { continue }
			$index++
			$tokens = @($item -split '\s+' | Where-Object { $_ })
			if ($tokens.Count -ge 2) {
				$type = $tokens[0]
				$name = ($tokens[1..($tokens.Count - 1)] -join ' ')
			}
			else {
				$type = $tokens[0]
				$name = "arg$index"
			}
			$params += @{ type = $type; name = $name }
		}
		$result += @{ funcName = $funcName; returnType = $returnType; params = $params }
	}
	return $result
}

function Get-FieldValue {
	param($Field, $Control)
	if (-not $Control) { return $Field.Default }
	switch ($Field.Kind) {
		'Bool' { return [bool]$Control.Checked }
		'Choice' {
			if ($null -ne $Control.SelectedItem) { return [string]$Control.SelectedItem }
			return [string]$Control.Text
		}
		'Flags' { return @(Get-FlagValues $Control) }
		'DllExports' { return @(Get-DllExportsValue $Control) }
		default { return [string]$Control.Text }
	}
}

function Set-DllExportsValue {
	param($Grid, $Exports)
	$Grid.Rows.Clear()
	foreach ($export in $Exports) {
		$paramsText = (@($export.params) | ForEach-Object { "$($_.type) $($_.name)".Trim() }) -join ', '
		[void]$Grid.Rows.Add($export.funcName, $export.returnType, $paramsText)
	}
}

function Set-FieldValue {
	param($Field, $Value)
	$control = Get-FieldControl $Field.Path
	if (-not $control) { return }
	switch ($Field.Kind) {
		'Bool' { $control.Checked = [bool]$Value }
		'Choice' {
			$text = [string]$Value
			$items = @($control.Items | ForEach-Object { [string]$_ })
			if ($items -contains $text) { $control.SelectedItem = $text }
			else { $control.Text = $text }
		}
		'Flags' {
			$selected = @($Value | ForEach-Object { [string]$_ })
			foreach ($box in (Get-DescendantControls $control | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })) {
				$box.Checked = $selected -contains $box.Text
			}
		}
		'DllExports' { Set-DllExportsValue $control @($Value) }
		default { $control.Text = [string]$Value }
	}
}

# 按 schema 默认值构造完整的 UIData（含被禁用字段）。
function Get-DefaultUIData {
	$data = @{ inputFile = ''; outputFile = ''; SchemaVersion = 2 }
	foreach ($field in Get-GUIAllFields) {
		Set-NestedValue $data $field.Path $field.Default
	}
	return $data
}

# 从控件读值，得到完整 UIData。
function Get-UIData {
	$data = @{ inputFile = ''; outputFile = ''; SchemaVersion = 2 }
	foreach ($field in Get-GUIAllFields) {
		$control = Get-FieldControl $field.Path
		Set-NestedValue $data $field.Path (Get-FieldValue $field $control)
	}
	return $data
}

# 把 UIData 写回控件（缺失键用 schema 默认值），随后刷新界面可用状态。
function Set-UIData {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$UIData
	)
	foreach ($field in Get-GUIAllFields) {
		$value = Get-NestedValue $UIData $field.Path
		if ($null -eq $value) { $value = $field.Default }
		Set-FieldValue $field $value
	}
	Update-UIState
}

function Update-ChoiceItems {
	param($Control, $Choices)
	$currentItems = @($Control.Items | ForEach-Object { [string]$_ })
	$same = $currentItems.Count -eq $Choices.Count
	if ($same) {
		for ($i = 0; $i -lt $Choices.Count; $i++) {
			if ($currentItems[$i] -ne $Choices[$i]) { $same = $false; break }
		}
	}
	if (-not $same) {
		$Control.BeginUpdate()
		try {
			$Control.Items.Clear()
			foreach ($choice in $Choices) { [void]$Control.Items.Add($choice) }
		}
		finally { $Control.EndUpdate() }
	}
	$current = if ($null -ne $Control.SelectedItem) { [string]$Control.SelectedItem } else { [string]$Control.Text }
	if ($Choices -contains $current) { $Control.SelectedItem = $current }
	elseif ($Control.Items.Count -gt 0) { $Control.SelectedIndex = 0 }
}

# 按 EnabledWhen 刷新每个字段的 Enabled；Choice 字段按 ChoicesWhen 重建选项。
function Update-UIState {
	if ($Script:UpdatingUI) { return }
	$Script:UpdatingUI = $true
	try {
		$data = Get-UIData
		foreach ($field in Get-GUIAllFields) {
			$control = Get-FieldControl $field.Path
			if (-not $control) { continue }
			$enabled = $true
			if ($field.EnabledWhen) { $enabled = [bool](& $field.EnabledWhen $data) }
			$control.Enabled = $enabled
			$browse = Get-FieldBrowseControl $field.Path
			if ($browse) { $browse.Enabled = $enabled }
			if ($field.Kind -eq 'Choice' -and $field.ChoicesWhen -and $enabled) {
				if (-not $control.Focused) {
					$choices = @(& $field.ChoicesWhen $data | ForEach-Object { [string]$_ })
					Update-ChoiceItems $control $choices
				}
			}
		}
	}
	finally {
		$Script:UpdatingUI = $false
	}
}

# URL 原样返回；',N' 资源索引只解析文件部分；相对路径以 BaseDir 为基准转绝对路径。
function Resolve-ProjectPath {
	param([string]$Path, [string]$BaseDir)
	if (-not $Path) { return '' }
	if ($Path -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') { return $Path }
	if (-not $BaseDir) { return $Path }
	$suffix = ''
	if ($Path -match '^(.*?)(,\d+)$') {
		$Path = $Matches[1]
		$suffix = $Matches[2]
	}
	if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) + $suffix }
	return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $Path)) + $suffix
}

# 用 Uri.MakeRelativeUri 实现，兼容 Windows PowerShell 5.1。
function Get-RelativePath {
	param([string]$Path, [string]$BaseDir)
	if (-not $Path) { return '' }
	if (-not $BaseDir) { return $Path }
	$baseFull = [System.IO.Path]::GetFullPath($BaseDir).TrimEnd('\') + '\'
	$baseUri = [System.Uri]::new($baseFull)
	$fileUri = [System.Uri]::new([System.IO.Path]::GetFullPath($Path))
	$relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fileUri).ToString())
	return ($relative -replace '/', '\')
}

function Test-ValueChanged {
	param($Value, $Default)
	if ($null -eq $Value) { return $false }
	if ($Value -is [array] -or $Default -is [array]) {
		return (ConvertTo-Json -InputObject @($Value) -Depth 16 -Compress) -ne (ConvertTo-Json -InputObject @($Default) -Depth 16 -Compress)
	}
	if ($Default -is [bool]) { return [bool]$Value -ne [bool]$Default }
	return [string]$Value -ne [string]$Default
}

# 只输出「字段可用且值与默认不同」的项，组装成 ps12exe 对象式 API。
function Get-ps12exeArgs {
	$data = Get-UIData
	$result = @{}
	$baseDir = ''
	if ($Script:ConfigFile) { $baseDir = Split-Path -Path $Script:ConfigFile -Parent }

	foreach ($field in Get-GUIAllFields) {
		$path = $field.Path
		# Signing 是合成组，单独处理。
		if ($path -like 'Signing.*') { continue }

		$enabled = $true
		if ($field.EnabledWhen) { $enabled = [bool](& $field.EnabledWhen $data) }
		if (-not $enabled) { continue }

		$value = Get-NestedValue $data $path
		if (-not (Test-ValueChanged $value $field.Default)) { continue }

		if ($path -eq 'Build.DllExports') {
			Set-NestedValue $result $path @($value)
			continue
		}
		if ($path -eq 'Build.Minify') {
			$value = [System.Management.Automation.Language.Parser]::ParseInput([string]$value, [ref]$null, [ref]$null).GetScriptBlock()
		}
		elseif ($path -in @('inputFile', 'outputFile', 'Build.TempDir', 'Resources.Icon')) {
			$value = Resolve-ProjectPath ([string]$value) $baseDir
		}
		Set-NestedValue $result $path $value
	}

	# Signing 合成组：Enabled 为假时整体不输出。
	if ([bool](Get-NestedValue $data 'Signing.Enabled')) {
		$signing = @{}
		foreach ($path in @('Signing.Certificate', 'Signing.Password', 'Signing.Thumbprint', 'Signing.Timestamp')) {
			$field = Get-GUIField $path
			if (-not $field) { continue }
			$enabled = $true
			if ($field.EnabledWhen) { $enabled = [bool](& $field.EnabledWhen $data) }
			if (-not $enabled) { continue }
			$value = Get-NestedValue $data $path
			if (-not (Test-ValueChanged $value $field.Default)) { continue }
			if ($path -eq 'Signing.Password') {
				$value = ConvertTo-SecureString ([string]$value) -AsPlainText -Force
			}
			elseif ($path -eq 'Signing.Certificate') {
				$value = Resolve-ProjectPath ([string]$value) $baseDir
			}
			Set-NestedValue $signing ($path -replace '^Signing\.', '') $value
		}
		$result.Signing = $signing
	}

	return $result
}

# 取 Layout 建好的文件/文件夹对话框（New-GUIDialogs 写入 $Script:dialogs）。
function Get-GUIDialog {
	param([string]$Key)
	return Get-GUIRef $Script:dialogs $Key
}

function SetCfgFile {
	param([string]$ConfigFile)
	$Script:ConfigFile = $ConfigFile
	if ($Script:refs -and $Script:refs.CfgFileLabel) {
		$Script:refs.CfgFileLabel.Text = (Get-GUIText 'Label.CfgFileHead') + $ConfigFile
	}
}

function LoadCfgFile {
	param([string]$ConfigFile)
	if (-not $ConfigFile) {
		$dialog = Get-GUIDialog 'OpenCfg'
		if (-not $dialog) { return }
		$previous = $dialog.FileName
		if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
		$ConfigFile = $dialog.FileName
		if (-not $ConfigFile -or $ConfigFile -eq $previous) { return }
	}
	try {
		$UIData = Import-Clixml -LiteralPath $ConfigFile
	}
	catch {
		[System.Windows.Forms.MessageBox]::Show((Get-GUIText 'Log.CfgLoadFailed') + $_.Exception.Message, (Get-GUIText 'Window.Title'), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
		return
	}
	SetCfgFile $ConfigFile
	Set-UIData -UIData $UIData
	$Script:SavedSnapshot = Get-UIData
}

function SaveCfgFileAs {
	param([string]$ConfigFile)
	if (-not $ConfigFile) {
		$dialog = Get-GUIDialog 'SaveCfg'
		if (-not $dialog) { return }
		$previous = $dialog.FileName
		if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
		$ConfigFile = $dialog.FileName
		if (-not $ConfigFile -or $ConfigFile -eq $previous) { return }
	}
	Get-UIData | Export-Clixml -LiteralPath $ConfigFile
	SetCfgFile $ConfigFile
	$Script:SavedSnapshot = Get-UIData
}

function SaveCfgFile {
	param([string]$ConfigFile)
	if (-not $ConfigFile) { $ConfigFile = $Script:ConfigFile }
	if (-not $ConfigFile) { SaveCfgFileAs; return }
	SaveCfgFileAs $ConfigFile
}

function AskSaveCfg {
	$localize = $Script:LocalizeData
	return [System.Windows.Forms.MessageBox]::Show([string]$localize.AskSaveCfg, [string]$localize.AskSaveCfgTitle, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) -eq [System.Windows.Forms.DialogResult]::Yes
}

function Test-UIDirty {
	if ($null -eq $Script:SavedSnapshot) { return $false }
	$current = ConvertTo-Json -InputObject (Get-UIData) -Depth 16 -Compress
	$saved = ConvertTo-Json -InputObject $Script:SavedSnapshot -Depth 16 -Compress
	return $current -ne $saved
}

function Write-GUILog {
	param([string]$Text)
	$box = $Script:refs.LogTextBox
	if (-not $box) { return }
	$box.Text += "$Text`r`n"
	$box.SelectionStart = $box.Text.Length
	$box.ScrollToCaret()
}

function PauseMusic {
	[ps12exeGUI.Win32]::mciSendString("pause ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
function ResumeMusic {
	[ps12exeGUI.Win32]::mciSendString("resume ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
