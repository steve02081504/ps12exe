# GDI+ 绘制类型（Graphics/Pen/Font/GraphicsPath）在 .NET Core 下位于 System.Drawing.Common（.NET 10 起再拆出 System.Private.Windows.*），Framework 下并进 System.Drawing。
try { Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing } catch { }
$GUICSharpReferences = @('System.Windows.Forms', 'System.Drawing', 'System.Drawing.Primitives', 'System.Net.Primitives', 'System.ComponentModel.Primitives', 'Microsoft.Win32.Primitives')
if ($PSVersionTable.PSEdition -eq 'Core') {
	foreach ($optionalReference in @('System.Drawing.Common', 'System.Private.Windows.Core', 'System.Private.Windows.GdiPlus')) {
		try { [void][System.Reflection.Assembly]::Load($optionalReference); $GUICSharpReferences += $optionalReference } catch { }
	}
}

Add-Type @"
using System;
using System.Text;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Runtime.InteropServices;
namespace ps12exeGUI {
	// 扁平圆角分组卡片：系统 GroupBox 的 3D 边框在深色下会露出亮线且无法换色，这里自绘边框与标题。
	public class FlatGroupBox : GroupBox {
		private Color borderColor = Color.FromArgb(0xD6, 0xD6, 0xD6);
		private Color titleColor = Color.FromArgb(0x5F, 0x5F, 0x5F);
		private int cornerRadius = 6;

		public Color BorderColor {
			get { return borderColor; }
			set { borderColor = value; Invalidate(); }
		}
		public Color TitleColor {
			get { return titleColor; }
			set { titleColor = value; Invalidate(); }
		}
		public int CornerRadius {
			get { return cornerRadius; }
			set { cornerRadius = value; Invalidate(); }
		}

		public FlatGroupBox() {
			SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
		}

		private static GraphicsPath RoundedRect(Rectangle bounds, int radius) {
			int diameter = radius * 2;
			GraphicsPath path = new GraphicsPath();
			if (diameter <= 0) {
				path.AddRectangle(bounds);
				return path;
			}
			path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
			path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
			path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
			path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
			path.CloseFigure();
			return path;
		}

		protected override void OnPaint(PaintEventArgs e) {
			Graphics g = e.Graphics;
			g.SmoothingMode = SmoothingMode.AntiAlias;
			g.Clear(BackColor);

			int caption = Font.Height;
			int top = caption / 2;
			Rectangle rect = new Rectangle(0, top, Width - 1, Height - top - 1);
			if (rect.Width > 0 && rect.Height > 0) {
				using (GraphicsPath path = RoundedRect(rect, cornerRadius))
				using (Pen pen = new Pen(borderColor)) {
					g.DrawPath(pen, path);
				}
			}

			using (Font titleFont = new Font(Font, FontStyle.Bold)) {
				TextRenderer.DrawText(g, Text, titleFont, new Point(12, 0), titleColor, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
			}
		}
	}

	public class Dwm {
		[DllImport("dwmapi.dll")]
		public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
		public static void SetWindowAttribute(IntPtr hwnd, int attr, int attrValue)
		{
			DwmSetWindowAttribute(hwnd, attr, ref attrValue, sizeof(int));
		}
	}
	public class Win32 {
		[DllImport("Kernel32.dll", ExactSpelling = true)]
		public static extern IntPtr GetConsoleWindow();
		[DllImport("user32.dll")]
		public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
		[DllImport("user32.dll")]
		public static extern bool SetForegroundWindow(IntPtr hWnd);
		[DllImport("winmm.dll")]
		public static extern Int32 mciSendString(String command, StringBuilder buffer, Int32 bufferSize, IntPtr hwndCallback);
		[DllImport("uxtheme.dll", CharSet=CharSet.Unicode)]
		public static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);

		[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
		private class MMDeviceEnumerator {}

		private enum EDataFlow { eRender, eCapture, eAll }
		private enum ERole { eConsole, eMultimedia, eCommunications }

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
		private interface IMMDeviceEnumerator {
			void NotNeeded();
			IMMDevice GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role);
		}

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("D666063F-1587-4E43-81F1-B948E807363F")]
		private interface IMMDevice {
			[return: MarshalAs(UnmanagedType.IUnknown)]
			object Activate([MarshalAs(UnmanagedType.LPStruct)] Guid iid, int dwClsCtx, IntPtr pActivationParams);
		}

		[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")]
		private interface IAudioMeterInformation {
			float GetPeakValue();
		}

		public static bool IsPlayingSound() {
			IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
			IMMDevice speakers = enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia);
			IAudioMeterInformation meter = (IAudioMeterInformation)speakers.Activate(typeof(IAudioMeterInformation).GUID, 0, IntPtr.Zero);
			float value = meter.GetPeakValue();
			return value > 1E-08;
		}
	}
}
"@	-ReferencedAssemblies $GUICSharpReferences

#region Functions

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

#endregion Functions


#region Environment Setup

try {
	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
	[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
	[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

	# 必须在创建任何控件之前调用。
	[System.Windows.Forms.Application]::EnableVisualStyles()
	[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
}
catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered during Environment Setup." }

#endregion Environment Setup
