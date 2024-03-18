Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace ps12exeGUI {
	public class Dwm {
		[DllImport("dwmapi.dll")]
		public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
		public static void SetWindowAttribute(IntPtr hwnd, int attr, int attrValue)
		{
			DwmSetWindowAttribute(hwnd, attr, ref attrValue, sizeof(int));
		}
	}
	public class Win32 {
		[DllImport("kernel32.dll", ExactSpelling = true)]
		public static extern IntPtr GetConsoleWindow();
		[DllImport("user32.dll")]
		public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
		[DllImport("winmm.dll")]
		public static extern Int32 mciSendString(String command, StringBuilder buffer, Int32 bufferSize, IntPtr hwndCallback);
	}
}
"@	-ReferencedAssemblies System.Windows.Forms, System.Drawing, System.Drawing.Primitives, System.Net.Primitives, System.ComponentModel.Primitives, Microsoft.Win32.Primitives
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function Update-ErrorLog {
	param(
		[System.Management.Automation.ErrorRecord]$ErrorRecord,
		[string]$Message,
		[switch]$Promote
	)

	if ( $Message -ne '' ) { [void][System.Windows.Forms.MessageBox]::Show($Message + $($ErrorRecord | Out-String), 'Exception Occurred') }

	Write-Error $ErrorRecord

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
			switch ($Xml.ToString()) {
				'ContextMenuStrip' { $ParentControl.ContextMenuStrip = $newControl }
				'SplitterPanel' { $newControl = $ParentControl.$($Xml.Name.Split('_')[-1]) }
				default { $ParentControl.Controls.Add($newControl) }
			}
		}

		$Xml.Attributes | ForEach-Object {
			$attrib = $_
			$attribName = $_.ToString()

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
			elseif ( $null -ne $newControl.$attribName ) {
				$value = $attrib.Value
				if ( $newControl.$attribName.GetType().Name -eq 'Boolean' ) {
					$value = $attrib.Value -eq 'True'
				}
				$newControl.$attribName = $value
			}

			if (( $attrib.ToString() -eq 'Name' ) -and ( $Reference -ne '' )) {
				if (-not (Test-Path variable:Script:$Reference)) {
					New-Variable -Name $Reference -Scope Script -Value @{} | Out-Null
				}
				$refHashTable = Get-Variable -Name $Reference -Scope Script

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
