Add-Type @"
using System;
using System.Collections.Generic;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Drawing;
public class psd {
	public static void SetCompat()
	{
		Application.EnableVisualStyles();
		Application.SetCompatibleTextRenderingDefault(false);
	}
	[System.Runtime.InteropServices.DllImport("user32.dll")]
	public static extern bool SetProcessDPIAware();
	[DllImport("dwmapi.dll")]
	public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
	public static void SetWindowAttribute(IntPtr hwnd, int attr, int attrValue)
	{
		DwmSetWindowAttribute(hwnd, attr, ref attrValue, sizeof(int));
	}
}
"@	-ReferencedAssemblies System.Windows.Forms, System.Drawing, System.Drawing.Primitives, System.Net.Primitives, System.ComponentModel.Primitives, Microsoft.Win32.Primitives
$script:tscale = 1

#region Functions

$vscreen = [System.Windows.Forms.SystemInformation]::VirtualScreen.height
[psd]::SetProcessDPIAware()
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen.height
$script:tscale = ($screen / $vscreen)
[psd]::SetCompat()
function Update-ErrorLog {
	param(
		[System.Management.Automation.ErrorRecord]$ErrorRecord,
		[string]$Message,
		[switch]$Promote
	)

	if ( $Message -ne '' ) { [void][System.Windows.Forms.MessageBox]::Show("$($Message)`r`n`r`nCheck '$($BaseDir)\exceptions.txt' for details.", 'Exception Occurred') }

	$date = Get-Date -Format 'yyyyMMdd HH:mm:ss'
	$ErrorRecord | Out-File "$($BaseDir)\tmpError.txt"

	Add-Content -Path "$($BaseDir)\exceptions.txt" -Value "$($date): $($(Get-Content "$($BaseDir)\tmpError.txt") -replace "\s+"," ")"

	Remove-Item -Path "$($BaseDir)\tmpError.txt"

	if ( $Promote ) { throw $ErrorRecord }
}

function ConvertFrom-WinFormsXML {
	param(
		[Parameter(Mandatory = $true)]$Xml,
		[string]$Reference,
		$ParentControl,
		[switch]$Suppress
	)

try {
if ( $Xml.GetType().Name -eq 'String' ) { $Xml = ([xml]$Xml).ChildNodes }

if ( $Xml.ToString() -ne 'SplitterPanel' ) { $newControl = New-Object System.Windows.Forms.$($Xml.ToString()) }

if ( $ParentControl ) {
#brandoncomputer_ToolStripFix_Export
if ( $Xml.ToString() -eq 'ToolStrip' ) {
$newControl = New-Object System.Windows.Forms.MenuStrip
$ParentControl.Controls.Add($newControl)
}
else {
if ( $Xml.ToString() -match "^ToolStrip" ) {
if ( $ParentControl.GetType().Name -match "^ToolStrip" ) { [void]$ParentControl.DropDownItems.Add($newControl) } else { [void]$ParentControl.Items.Add($newControl) }
}
elseif ( $Xml.ToString() -eq 'ContextMenuStrip' ) { $ParentControl.ContextMenuStrip = $newControl }
elseif ( $Xml.ToString() -eq 'SplitterPanel' ) { $newControl = $ParentControl.$($Xml.Name.Split('_')[-1]) }
else { $ParentControl.Controls.Add($newControl) }
}
}

$Xml.Attributes | ForEach-Object {
$attrib = $_
$attribName = $_.ToString()
$attrib = $_
$attribName = $_.ToString()

if ($attribName -eq 'Size') {

$n = $attrib.Value.split(',')
$n[0] = [math]::round(($n[0] / 1) * $tscale)
$n[1] = [math]::round(($n[1] / 1) * $tscale)
if ("$($n[0]),$($n[1])" -ne ",") {
$attrib.Value = "$($n[0]),$($n[1])"
}
}
if ($attribName -eq 'Location') {
$n = $attrib.Value.split(',')
$n[0] = [math]::round(($n[0] / 1) * $tscale)
$n[1] = [math]::round(($n[1] / 1) * $tscale)
if ("$($n[0]),$($n[1])" -ne ",") {
$attrib.Value = "$($n[0]),$($n[1])"
}
}
if ($attribName -eq 'MaximumSize') {
$n = $attrib.Value.split(',')
$n[0] = [math]::round(($n[0] / 1) * $tscale)
$n[1] = [math]::round(($n[1] / 1) * $tscale)
if ("$($n[0]),$($n[1])" -ne ",") {
$attrib.Value = "$($n[0]),$($n[1])"
}
}
if ($attribName -eq 'MinimumSize') {
$n = $attrib.Value.split(',')
$n[0] = [math]::round(($n[0] / 1) * $tscale)
$n[1] = [math]::round(($n[1] / 1) * $tscale)
if ("$($n[0]),$($n[1])" -ne ",") {
$attrib.Value = "$($n[0]),$($n[1])"
}
}
if ($attribName -eq 'ImageScalingSize') {
$n = $attrib.Value.split(',')
$n[0] = [math]::round(($n[0] / 1) * $tscale)
$n[1] = [math]::round(($n[1] / 1) * $tscale)
if ("$($n[0]),$($n[1])" -ne ",") {
$attrib.Value = "$($n[0]),$($n[1])"
}
}

if ( $Script:specialProps.Array -contains $attribName ) {
if ( $attribName -eq 'Items' ) {
$($_.Value -replace "\|\*BreakPT\*\|", "`n").Split("`n") | ForEach-Object { [void]$newControl.Items.Add($_) }
}
else {
# Other than Items only BoldedDate properties on MonthCalendar control
$methodName = "Add$($attribName)" -replace "s$"

$($_.Value -replace "\|\*BreakPT\*\|", "`n").Split("`n") | ForEach-Object { $newControl.$attribName.$methodName($_) }
}
}
else {
switch ($attribName) {
FlatAppearance {
$attrib.Value.Split('|') | ForEach-Object { $newControl.FlatAppearance.$($_.Split('=')[0]) = $_.Split('=')[1] }
}
default {
if ( $null -ne $newControl.$attribName ) {
if ( $newControl.$attribName.GetType().Name -eq 'Boolean' ) {
if ( $attrib.Value -eq 'True' ) { $value = $true } else { $value = $false }
}
else { $value = $attrib.Value }
}
else { $value = $attrib.Value }
#brandoncomputer_VariousDialogFixesInExport
switch ($xml.ToString()) {
"FolderBrowserDialog" {
if ($xml.Description)
{ $newControl.Description = $xml.Description }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
if ($xml.RootFolder)
{ $newControl.RootFolder = $xml.RootFolder }
if ($xml.SelectedPath)
{ $newControl.SelectedPath = $xml.SelectedPath }
if ($xml.ShowNewFolderButton)
{ $newControl.ShowNewFolderButton = $xml.ShowNewFolderButton }
}
"OpenFileDialog" {
if ($xml.AddExtension)
{ $newControl.AddExtension = $xml.AddExtension }
if ($xml.AutoUpgradeEnabled)
{ $newControl.AutoUpgradeEnabled = $xml.AutoUpgradeEnabled }
if ($xml.CheckFileExists)
{ $newControl.CheckFileExists = $xml.CheckFileExists }
if ($xml.CheckPathExists)
{ $newControl.CheckPathExists = $xml.CheckPathExists }
if ($xml.DefaultExt)
{ $newControl.DefaultExt = $xml.DefaultExt }
if ($xml.DereferenceLinks)
{ $newControl.DereferenceLinks = $xml.DereferenceLinks }
if ($xml.FileName)
{ $newControl.FileName = $xml.FileName }
if ($xml.Filter)
{ $newControl.Filter = $xml.Filter }
if ($xml.FilterIndex)
{ $newControl.FilterIndex = $xml.FilterIndex }
if ($xml.InitialDirectory)
{ $newControl.InitialDirectory = $xml.InitialDirectory }
if ($xml.Multiselect)
{ $newControl.Multiselect = $xml.Multiselect }
if ($xml.ReadOnlyChecked)
{ $newControl.ReadOnlyChecked = $xml.ReadOnlyChecked }
if ($xml.RestoreDirectory)
{ $newControl.RestoreDirectory = $xml.RestoreDirectory }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.ShowReadOnly)
{ $newControl.ShowReadOnly = $xml.ShowReadOnly }
if ($xml.SupportMultiDottedExtensions)
{ $newControl.SupportMultiDottedExtensions = $xml.SupportMultiDottedExtensions }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
if ($xml.Title)
{ $newControl.Title = $xml.Title }
if ($xml.ValidateNames)
{ $newControl.ValidateNames = $xml.ValidateNames }
}
"ColorDialog" {
if ($xml.AllowFullOpen)
{ $newControl.AllowFullOpen = $xml.AllowFullOpen }
if ($xml.AnyColor)
{ $newControl.AnyColor = $xml.AnyColor }
if ($xml.Color)
{ $newControl.Color = $xml.Color }
if ($xml.FullOpen)
{ $newControl.FullOpen = $xml.FullOpen }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.SolidColorOnly)
{ $newControl.SolidColorOnly = $xml.SolidColorOnly }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
}
"FontDialog" {
if ($xml.AllowScriptChange)
{ $newControl.AllowScriptChange = $xml.AllowScriptChange }
if ($xml.AllowSimulations)
{ $newControl.AllowSimulations = $xml.AllowSimulations }
if ($xml.AllowVectorFonts)
{ $newControl.AllowVectorFonts = $xml.AllowVectorFonts }
if ($xml.Color)
{ $newControl.Color = $xml.Color }
if ($xml.FixedPitchOnly)
{ $newControl.FixedPitchOnly = $xml.FixedPitchOnly }
if ($xml.Font)
{ $newControl.Font = $xml.Font }
if ($xml.FontMustExists)
{ $newControl.FontMustExists = $xml.FontMustExists }
if ($xml.MaxSize)
{ $newControl.MaxSize = $xml.MaxSize }
if ($xml.MinSize)
{ $newControl.MinSize = $xml.MinSize }
if ($xml.ScriptsOnly)
{ $newControl.ScriptsOnly = $xml.ScriptsOnly }
if ($xml.ShowApply)
{ $newControl.ShowApply = $xml.ShowApply }
if ($xml.ShowColor)
{ $newControl.ShowColor = $xml.ShowColor }
if ($xml.ShowEffects)
{ $newControl.ShowEffects = $xml.ShowEffects }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
}
"PageSetupDialog" {
if ($xml.AllowMargins)
{ $newControl.AllowMargins = $xml.AllowMargins }
if ($xml.AllowOrientation)
{ $newControl.AllowOrientation = $xml.AllowOrientation }
if ($xml.AllowPaper)
{ $newControl.AllowPaper = $xml.AllowPaper }
if ($xml.Document)
{ $newControl.Document = $xml.Document }
if ($xml.EnableMetric)
{ $newControl.EnableMetric = $xml.EnableMetric }
if ($xml.MinMargins)
{ $newControl.MinMargins = $xml.MinMargins }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.ShowNetwork)
{ $newControl.ShowNetwork = $xml.ShowNetwork }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
}
"PrintDialog" {
if ($xml.AllowCurrentPage)
{ $newControl.AllowCurrentPage = $xml.AllowCurrentPage }
if ($xml.AllowPrintToFile)
{ $newControl.AllowPrintToFile = $xml.AllowPrintToFile }
if ($xml.AllowSelection)
{ $newControl.AllowSelection = $xml.AllowSelection }
if ($xml.AllowSomePages)
{ $newControl.AllowSomePages = $xml.AllowSomePages }
if ($xml.Document)
{ $newControl.Document = $xml.Document }
if ($xml.PrintToFile)
{ $newControl.PrintToFile = $xml.PrintToFile }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.ShowNetwork)
{ $newControl.ShowNetwork = $xml.ShowNetwork }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
if ($xml.UseEXDialog)
{ $newControl.UseEXDialog = $xml.UseEXDialog }
}
"PrintPreviewDialog" {
if ($xml.AutoSizeMode)
{ $newControl.AutoSizeMode = $xml.AutoSizeMode }
if ($xml.Document)
{ $newControl.Document = $xml.Document }
if ($xml.MainMenuStrip)
{ $newControl.MainMenuStrip = $xml.MainMenuStrip }
if ($xml.ShowIcon)
{ $newControl.ShowIcon = $xml.ShowIcon }
if ($xml.UseAntiAlias)
{ $newControl.UseAntiAlias = $xml.UseAntiAlias }
}
"SaveFileDialog" {
if ($xml.AddExtension)
{ $newControl.AddExtension = $xml.AddExtension }
if ($xml.AutoUpgradeEnabled)
{ $newControl.AutoUpgradeEnabled = $xml.AutoUpgradeEnabled }
if ($xml.CheckFileExists)
{ $newControl.CheckFileExists = $xml.CheckFileExists }
if ($xml.CheckPathExists)
{ $newControl.CheckPathExists = $xml.CheckPathExists }
if ($xml.CreatePrompt)
{ $newControl.CreatePrompt = $xml.CreatePrompt }
if ($xml.DefaultExt)
{ $newControl.DefaultExt = $xml.DefaultExt }
if ($xml.DereferenceLinks)
{ $newControl.DereferenceLinks = $xml.DereferenceLinks }
if ($xml.FileName)
{ $newControl.FileName = $xml.FileName }
if ($xml.Filter)
{ $newControl.Filter = $xml.Filter }
if ($xml.FilterIndex)
{ $newControl.FilterIndex = $xml.FilterIndex }
if ($xml.InitialDirectory)
{ $newControl.InitialDirectory = $xml.InitialDirectory }
if ($xml.Multiselect)
{ $newControl.OverwritePrompt = $xml.OverwritePrompt }
if ($xml.RestoreDirectory)
{ $newControl.RestoreDirectory = $xml.RestoreDirectory }
if ($xml.ShowHelp)
{ $newControl.ShowHelp = $xml.ShowHelp }
if ($xml.SupportMultiDottedExtensions)
{ $newControl.SupportMultiDottedExtensions = $xml.SupportMultiDottedExtensions }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
if ($xml.Title)
{ $newControl.Title = $xml.Title }
if ($xml.ValidateNames)
{ $newControl.ValidateNames = $xml.ValidateNames }
}
"Timer" {
if ($xml.Enabled)
{ $newControl.Enabled = $xml.Enabled }
if ($xml.Interval)
{ $newControl.Interval = $xml.Interval }
if ($xml.Tag)
{ $newControl.Tag = $xml.Tag }
}
default {
$newControl.$attribName = $value
}
}
}
}
}



#brandoncomputer_DirectReferenceObjectsExport
if ($newControl.Name) {
New-Variable -Name $newControl.Name -Scope Script -Value $newControl | Out-Null
}
if (( $attrib.ToString() -eq 'Name' ) -and ( $Reference -ne '' )) {
try { $refHashTable = Get-Variable -Name $Reference -Scope Script -ErrorAction Stop }
catch {
New-Variable -Name $Reference -Scope Script -Value @{} | Out-Null
$refHashTable = Get-Variable -Name $Reference -Scope Script -ErrorAction SilentlyContinue
}

$refHashTable.Value.Add($attrib.Value, $newControl)
}
}

if ( $Xml.ChildNodes ) { $Xml.ChildNodes | ForEach-Object { ConvertFrom-WinformsXML -Xml $_ -ParentControl $newControl -Reference $Reference -Suppress } }

if ( $Suppress -eq $false ) { return $newControl }
}
catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered adding $($Xml.ToString()) to $($ParentControl.Name)" }
}

#endregion Functions


#region Environment Setup

try {
	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
}
catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered during Environment Setup." }

#endregion Environment Setup
