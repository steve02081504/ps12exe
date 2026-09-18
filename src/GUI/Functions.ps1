function Get-UIData {
	@{
		inputFile  = $Script:refs.CompileFileTextBox.Text
		outputFile = $Script:refs.OutputFileTextBox.Text
		App        = @{
			Windowed         = -not $Script:refs.ConsoleAppCheckBox.Checked
			Silence          = @(
				if ($Script:refs.DisableOutputStreamCheckBox.Checked) { 'Output'; 'Verbose' }
				if ($Script:refs.DisableErrorStreamCheckBox.Checked) { 'Error'; 'Warning'; 'Debug' }
			)
			OutputEncoding   = if ($Script:refs.UnicodeEncodingCheckBox.Enabled -and $Script:refs.UnicodeEncodingCheckBox.Checked) { 'UTF16LE' } else { 'Default' }
			VisualStyles     = -not ($Script:refs.IgnoreVisualStylesCheckBox.Enabled -and $Script:refs.IgnoreVisualStylesCheckBox.Checked)
			ExitOnCancel     = $Script:refs.ExitOnCancelCheckBox.Enabled -and $Script:refs.ExitOnCancelCheckBox.Checked
			CredentialGUI    = $Script:refs.CredentialGUICheckBox.Enabled -and $Script:refs.CredentialGUICheckBox.Checked
			DpiAware         = $Script:refs.DPIAwareCheckBox.Enabled -and $Script:refs.DPIAwareCheckBox.Checked
			WinFormsDpiAware = $Script:refs.WinFormsDPIAwareCheckBox.Enabled -and $Script:refs.WinFormsDPIAwareCheckBox.Checked
		}
		Os         = @{
			Admin      = $Script:refs.RequestAdminCheckBox.Checked
			ModernOS   = $Script:refs.MoreOSFeaturesCheckBox.Checked
			LongPaths  = $Script:refs.LongPathSupportCheckBox.Checked
			Virtualize = $Script:refs.EnableVirtualizationCheckBox.Checked
		}
		Build      = @{
			Target     = 'Framework4.0'
			Platform   = if ($Script:refs.x64CheckBox.Checked) { 'x64' } elseif ($Script:refs.x86CheckBox.Checked) { 'x86' } else { 'AnyCpu' }
			Apartment  = if ($Script:refs.SingleThreadCheckBox.Checked) { 'STA' } else { 'MTA' }
			Culture    = $Script:refs.RegionIDTextBox.Text
			Options    = $Script:refs.CompileParamsTextBox.Text
			KeepSource = $Script:refs.DebugInfoCheckBox.Checked
			Minify     = $Script:refs.MinifyScriptTextBox.Text
			TempDir    = $Script:refs.TempDirTextBox.Text
		}
		Resources  = @{
			Icon        = $Script:refs.IconFileTextBox.Text
			Title       = $Script:refs.TitleTextBox.Text
			Description = $Script:refs.DescriptionTextBox.Text
			Company     = $Script:refs.CompanyTextBox.Text
			Product     = $Script:refs.ProductNameTextBox.Text
			Copyright   = $Script:refs.CopyrightInfoTextBox.Text
			Trademark   = $Script:refs.TrademarkInfoTextBox.Text
			Version     = $Script:refs.VersionTextBox.Text
		}
		Signing    = if ($Script:refs.EnableCodeSigningCheckBox.Checked) {
			$signing = @{}
			if ($Script:refs.CertificatePathTextBox.Text) {
				$signing.Certificate = $Script:refs.CertificatePathTextBox.Text
				if ($Script:refs.CertificatePasswordTextBox.Text) {
					$signing.Password = ConvertTo-SecureString $Script:refs.CertificatePasswordTextBox.Text -AsPlainText -Force
				}
			}
			if ($Script:refs.CertificateThumbprintTextBox.Text) {
				$signing.Thumbprint = $Script:refs.CertificateThumbprintTextBox.Text
			}
			if ($Script:refs.TimestampServerTextBox.Text) {
				$signing.Timestamp = $Script:refs.TimestampServerTextBox.Text
			}
			if ($signing.Count -gt 0) { $signing } else { $null }
		}
		else { $null }
		ConfigFile = $Script:refs.ConfigFileCheckBox.Checked
	}
}
function Set-UIData {
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]$UIData
	)
	$Script:refs.CompileFileTextBox.Text = $UIData.inputFile
	$Script:refs.OutputFileTextBox.Text = $UIData.outputFile
	$Script:refs.CompileParamsTextBox.Text = $UIData.Build.Options
	$Script:refs.TempDirTextBox.Text = $UIData.Build.TempDir
	$Script:refs.MinifyScriptTextBox.Text = $UIData.Build.Minify
	$Script:refs.DebugInfoCheckBox.Checked = $UIData.Build.KeepSource
	$Script:refs.x64CheckBox.Checked = $UIData.Build.Platform -eq 'x64'
	$Script:refs.x86CheckBox.Checked = $UIData.Build.Platform -eq 'x86'
	$Script:refs.AnyCPUCheckBox.Checked = $UIData.Build.Platform -notin @('x64', 'x86')
	$Script:refs.RegionIDTextBox.Text = $UIData.Build.Culture
	$Script:refs.SingleThreadCheckBox.Checked = $UIData.Build.Apartment -ne 'MTA'
	$Script:refs.MultiThreadCheckBox.Checked = $UIData.Build.Apartment -eq 'MTA'
	$Script:refs.ConsoleAppCheckBox.Checked = -not $UIData.App.Windowed
	$Script:refs.UnicodeEncodingCheckBox.Checked = $UIData.App.OutputEncoding -eq 'UTF16LE'
	$Script:refs.CredentialGUICheckBox.Checked = $UIData.App.CredentialGUI
	$Script:refs.IconFileTextBox.Text = $UIData.Resources.Icon
	$Script:refs.TitleTextBox.Text = $UIData.Resources.Title
	$Script:refs.DescriptionTextBox.Text = $UIData.Resources.Description
	$Script:refs.CompanyTextBox.Text = $UIData.Resources.Company
	$Script:refs.ProductNameTextBox.Text = $UIData.Resources.Product
	$Script:refs.CopyrightInfoTextBox.Text = $UIData.Resources.Copyright
	$Script:refs.TrademarkInfoTextBox.Text = $UIData.Resources.Trademark
	$Script:refs.VersionTextBox.Text = $UIData.Resources.Version
	$Script:refs.ConfigFileCheckBox.Checked = $UIData.ConfigFile
	$Silence = @($UIData.App.Silence)
	$Script:refs.DisableOutputStreamCheckBox.Checked = ($Silence -contains 'Output') -or ($Silence -contains '*')
	$Script:refs.DisableErrorStreamCheckBox.Checked = ($Silence -contains 'Error') -or ($Silence -contains '*')
	$Script:refs.IgnoreVisualStylesCheckBox.Checked = -not $UIData.App.VisualStyles
	$Script:refs.ExitOnCancelCheckBox.Checked = $UIData.App.ExitOnCancel
	$Script:refs.DPIAwareCheckBox.Checked = $UIData.App.DpiAware
	$Script:refs.WinFormsDPIAwareCheckBox.Checked = $UIData.App.WinFormsDpiAware
	$Script:refs.RequestAdminCheckBox.Checked = $UIData.Os.Admin
	$Script:refs.MoreOSFeaturesCheckBox.Checked = $UIData.Os.ModernOS
	$Script:refs.EnableVirtualizationCheckBox.Checked = $UIData.Os.Virtualize
	$Script:refs.LongPathSupportCheckBox.Checked = $UIData.Os.LongPaths
	if ($UIData.Signing) {
		$Script:refs.EnableCodeSigningCheckBox.Checked = $true
		$Script:refs.CertificatePathTextBox.Text = $UIData.Signing.Certificate
		if ($UIData.Signing.Password) {
			$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($UIData.Signing.Password)
			$Script:refs.CertificatePasswordTextBox.Text = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
			[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
		}
		$Script:refs.CertificateThumbprintTextBox.Text = $UIData.Signing.Thumbprint
		$Script:refs.TimestampServerTextBox.Text = $UIData.Signing.Timestamp
	}
	else {
		$Script:refs.EnableCodeSigningCheckBox.Checked = $false
		$Script:refs.CertificatePathTextBox.Text = ""
		$Script:refs.CertificatePasswordTextBox.Text = ""
		$Script:refs.CertificateThumbprintTextBox.Text = ""
		$Script:refs.TimestampServerTextBox.Text = ""
	}
}

function Get-ps12exeArgs {
	$UIData = Get-UIData
	$result = $UIData.Clone()
	$result.Build.Minify = [System.Management.Automation.Language.Parser]::ParseInput($UIData.Build.Minify, [ref]$null, [ref]$null).GetScriptBlock()
	if ($ConfigFile) {
		# 若 inputFile、outputFile、Build.TempDir 为相对路径，转换为绝对路径
		@('inputFile', 'outputFile') | ForEach-Object {
			if ($UIData.$_ -and -not [System.IO.Path]::IsPathRooted($UIData.$_)) {
				$UIData.$_ = [System.IO.Path]::GetFullPath((Join-Path -Path $ConfigFile -ChildPath $UIData.$_))
			}
		}
		if ($UIData.Build.TempDir -and -not [System.IO.Path]::IsPathRooted($UIData.Build.TempDir)) {
			$UIData.Build.TempDir = [System.IO.Path]::GetFullPath((Join-Path -Path $ConfigFile -ChildPath $UIData.Build.TempDir))
		}
		# 若资源图标为相对路径，转换为绝对路径
		if ($UIData.Resources.Icon -and -not [System.IO.Path]::IsPathRooted($UIData.Resources.Icon)) {
			$UIData.Resources.Icon = [System.IO.Path]::GetFullPath((Join-Path -Path $ConfigFile -ChildPath $UIData.Resources.Icon))
		}
		# 处理 Signing 中 Certificate 的相对路径
		if ($UIData.Signing -and $UIData.Signing.Certificate -and -not [System.IO.Path]::IsPathRooted($UIData.Signing.Certificate)) {
			$UIData.Signing.Certificate = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path $ConfigFile -Parent) -ChildPath $UIData.Signing.Certificate))
		}
	}
	# 清理各对象中的空值
	foreach ($groupName in @('App', 'Os', 'Build', 'Resources', 'Signing')) {
		$group = $result[$groupName]
		if ($group -isnot [hashtable]) { continue }
		@($group.Keys) | ForEach-Object {
			if ($group[$_] -eq '' -or $null -eq $group[$_]) { $group.Remove($_) }
		}
		if ($group.Count -eq 0) { $result.Remove($groupName) }
	}
	$result
}
function SetCfgFile([string]$ConfigFile) {
	$Script:refs.CfgFileLabel.Text = $Script:LocalizeData.CfgFileLabelHead + $ConfigFile
	$script:ConfigFile = $ConfigFile
}
function LoadCfgFile([string]$ConfigFile) {
	if (!$ConfigFile) {
		$OpenCfgFileDialog.ShowDialog() | Out-Null
		$ConfigFile = $OpenCfgFileDialog.FileName
	}
	if ($ConfigFile) {
		SetCfgFile $ConfigFile
		$UIData = Import-Clixml $ConfigFile
		Set-UIData -UIData $UIData
	}
}
function SaveCfgFileAs([string]$ConfigFile) {
	if (!$ConfigFile) {
		$SaveCfgFileDialog.ShowDialog() | Out-Null
		$ConfigFile = $SaveCfgFileDialog.FileName
	}
	if ($ConfigFile) {
		SetCfgFile $ConfigFile
		$UIData = Get-UIData
		$UIData | Export-Clixml $ConfigFile
	}
}
function SaveCfgFile([string]$ConfigFile) {
	if (!$ConfigFile) {
		$ConfigFile = $Script:ConfigFile
	}
	SaveCfgFileAs $ConfigFile
}

function AskSaveCfg {
	[System.Windows.Forms.MessageBox]::Show([string]$Script:LocalizeData.AskSaveCfg, [string]$Script:LocalizeData.AskSaveCfgTitle, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) -eq 'Yes'
}

function PauseMusic {
	[ps12exeGUI.Win32]::mciSendString("pause ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
function ResumeMusic {
	[ps12exeGUI.Win32]::mciSendString("resume ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
