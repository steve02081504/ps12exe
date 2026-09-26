// 由 Ingo Karstein 创建的简单 PowerShell 主机（http://blog.karstein-consulting.com），由 Markus Scholtes 重构并支持 GUI。

using System;
using System.Collections.Generic;
using System.Text;
using System.Globalization;
using System.Reflection;
#if noConsole
	using System.Windows.Forms;
	using System.Drawing;
	using System.Runtime.InteropServices;
#endif
using System.Runtime.Versioning;

/*__ASSEMBLY_ATTRIBUTES__*/
namespace PSRunnerNS {
	#if noConsole
	// 常量工程的窗口化输出使用同一套 WinForms 消息框，仅根据 App.DarkMode 与系统主题切换调色板。
	internal static class ConstMessageBox {
		[DllImport("dwmapi.dll")]
		static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
		[DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
		static extern IntPtr MB_GetString(uint strId);
		#if !darkModeOff && !Pwsh20
		[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
		static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
		[DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
		static extern IntPtr GetModuleHandle(string name);
		[DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
		static extern IntPtr GetProcAddress(IntPtr hModule, IntPtr procName);
		delegate int SetPreferredAppModeDel(int mode);
		delegate void FlushMenuThemesDel();

		static readonly Color DarkWindowColor = Color.FromArgb(32, 32, 32);
		static readonly Color DarkFieldColor = Color.FromArgb(45, 45, 45);
		static readonly Color DarkBorderColor = Color.FromArgb(64, 64, 64);
		static readonly Color DarkTextColor = Color.FromArgb(245, 245, 245);
		static bool resolved;
		static bool isDark;
		public static bool IsDark {
			get {
				if (!resolved) {
					resolved = true;
					#if darkModeOn
					isDark = true; // 编译期强制暗色，不做探测
					#elif darkModeOff || Pwsh20
					isDark = false;
					#else
					try {
						object value = Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1);
						isDark = value != null && Convert.ToInt32(value) == 0;
					} catch { isDark = false; }
					#endif
					Enable();
				}
				return isDark;
			}
		}
		public static Color WindowColor { get { return IsDark ? DarkWindowColor : Color.White; } }
		public static Color FieldColor { get { return IsDark ? DarkFieldColor : Color.FromArgb(240, 240, 240); } }
		public static Color BorderColor { get { return IsDark ? DarkBorderColor : Color.FromArgb(173, 173, 173); } }
		public static Color TextColor { get { return IsDark ? DarkTextColor : SystemColors.ControlText; } }

		static void Enable() {
			try {
				// uxtheme 未公开序号：135=SetPreferredAppMode，136=FlushMenuThemes（见 ysc3839/win32-darkmode）。
				IntPtr uxtheme = GetModuleHandle("uxtheme.dll");
				if (uxtheme == IntPtr.Zero) { return; }
				IntPtr proc = GetProcAddress(uxtheme, (IntPtr)135); // SetPreferredAppMode
				if (proc != IntPtr.Zero) { ((SetPreferredAppModeDel)Marshal.GetDelegateForFunctionPointer(proc, typeof(SetPreferredAppModeDel)))(isDark ? 1 : 3); }
				proc = GetProcAddress(uxtheme, (IntPtr)136); // FlushMenuThemes
				if (proc != IntPtr.Zero) { ((FlushMenuThemesDel)Marshal.GetDelegateForFunctionPointer(proc, typeof(FlushMenuThemesDel)))(); }
			} catch { }
		}

		public static void ApplyTitleBar(IntPtr hwnd) {
			try {
				SetWindowTheme(hwnd, isDark ? "DarkMode_Explorer" : null, null);
				int on = isDark ? 1 : 0;
				DwmSetWindowAttribute(hwnd, 20, ref on, sizeof(int)); // DWMWA_USE_IMMERSIVE_DARK_MODE
				DwmSetWindowAttribute(hwnd, 19, ref on, sizeof(int)); // 旧 build
			} catch { }
		}
		#else
		public static bool IsDark { get { return false; } }
		public static Color WindowColor { get { return Color.White; } }
		public static Color FieldColor { get { return Color.FromArgb(240, 240, 240); } }
		public static Color BorderColor { get { return Color.FromArgb(173, 173, 173); } }
		public static Color TextColor { get { return SystemColors.ControlText; } }

		public static void ApplyTitleBar(IntPtr hwnd) {
			int light = 0;
			DwmSetWindowAttribute(hwnd, 20, ref light, sizeof(int));
			DwmSetWindowAttribute(hwnd, 19, ref light, sizeof(int));
		}
		#endif

		// 本地化 "确定" 按钮文案；取不到时回退英文。
		static string LocalizedOk() {
			try {
				string value = Marshal.PtrToStringUni(MB_GetString(0));
				if (!string.IsNullOrEmpty(value)) { return value; }
			} catch { }
			return "OK";
		}

		// 对齐原生 MessageBox(Information) 的观感：左侧 32@96dpi 信息图标、文本区自动换行、
		// 底部 80x28 本地化确认按钮，整套几何按 DPI 缩放。
		public static bool TryShow(string text, string title) {
			if (text == null) { text = ""; }
			using (Form form = new Form()) {
				form.Text = title;
				form.FormBorderStyle = FormBorderStyle.FixedDialog;
				form.StartPosition = FormStartPosition.CenterScreen;
				form.MinimizeBox = false;
				form.MaximizeBox = false;
				form.ShowIcon = true;
				form.AutoScaleMode = AutoScaleMode.None;
				form.BackColor = WindowColor;
				form.ForeColor = TextColor;
				form.Font = SystemFonts.MessageBoxFont;

				int dpi = (int)form.CreateGraphics().DpiX;
				int marginLeft = dpi * 22 / 96, marginTop = dpi * 28 / 96, gapIconText = dpi * 10 / 96;
				int marginRight = dpi * 18 / 96, marginBottom = dpi * 14 / 96, gapTextButton = dpi * 36 / 96;
				int buttonWidth = dpi * 80 / 96, buttonHeight = dpi * 28 / 96;
				Size iconSize = SystemInformation.IconSize;

				int workingWidth = Screen.FromControl(form).WorkingArea.Width;
				int cap = workingWidth * 5 / 8 - dpi * 18 / 96;
				cap = System.Math.Min(cap, workingWidth / 4);

				Label content = new Label();
				content.AutoSize = true;
				content.UseMnemonic = false;
				content.MaximumSize = new Size(cap, 0);
				content.Font = form.Font;
				content.ForeColor = TextColor;
				content.BackColor = WindowColor;
				content.Text = text;

				// 超长文本兜底：改用只读多行 TextBox 限高可滚动（原生也会尽量长高，这里保证不超出屏幕）。
				int maxHeight = Screen.FromControl(form).WorkingArea.Height - dpi * 220 / 96;

				Control contentControl;
				int contentWidth, contentHeight;
				Size wrapped = TextRenderer.MeasureText(text, form.Font, new Size(cap, int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);
				if (wrapped.Height > maxHeight && maxHeight > dpi * 40 / 96) {
					TextBox box = new TextBox();
					box.Multiline = true;
					box.ReadOnly = true;
					box.WordWrap = true;
					box.ScrollBars = ScrollBars.Vertical;
					box.BorderStyle = BorderStyle.FixedSingle;
					box.TabStop = false;
					box.Cursor = Cursors.Arrow;
					box.BackColor = WindowColor;
					box.ForeColor = TextColor;
					box.Font = form.Font;
					box.Text = text;
					contentControl = box;
					contentWidth = cap;
					contentHeight = maxHeight;
				} else {
					contentControl = content;
					contentWidth = wrapped.Width;
					contentHeight = wrapped.Height;
				}

				int textLeft = marginLeft + iconSize.Width + gapIconText;
				int bodyHeight = System.Math.Max(iconSize.Height, contentHeight);
				int clientWidth = System.Math.Max(textLeft + contentWidth + marginRight, marginLeft + buttonWidth + marginRight);
				int buttonTop = marginTop + bodyHeight + gapTextButton;
				int clientHeight = buttonTop + buttonHeight + marginBottom;
				form.ClientSize = new Size(clientWidth, clientHeight);

				PictureBox icon = new PictureBox();
				icon.Size = iconSize;
				icon.BackColor = WindowColor;
				icon.SizeMode = PictureBoxSizeMode.StretchImage;
				icon.Image = new Icon(SystemIcons.Information, iconSize).ToBitmap();
				icon.Location = new Point(marginLeft, marginTop);
				form.Controls.Add(icon);

				// 短文本相对图标垂直居中，长文本与图标顶对齐。
				int textTop = contentHeight < iconSize.Height ? marginTop + (iconSize.Height - contentHeight) / 2 : marginTop;
				contentControl.Location = new Point(textLeft, textTop);
				contentControl.Size = new Size(contentWidth, contentHeight);
				form.Controls.Add(contentControl);

				Button ok = new Button();
				ok.Text = LocalizedOk();
				ok.DialogResult = DialogResult.OK;
				ok.FlatStyle = FlatStyle.Flat;
				ok.FlatAppearance.BorderSize = 1;
				ok.FlatAppearance.BorderColor = BorderColor;
				ok.BackColor = FieldColor;
				ok.ForeColor = TextColor;
				ok.UseVisualStyleBackColor = false;
				ok.Size = new Size(buttonWidth, buttonHeight);
				ok.Location = new Point(clientWidth - marginRight - buttonWidth, buttonTop);
				form.Controls.Add(ok);

				form.AcceptButton = ok;
				form.ActiveControl = ok;
				form.HandleCreated += delegate(object sender, EventArgs e) {
					ApplyTitleBar(form.Handle);
					TextBox box = contentControl as TextBox;
					#if !darkModeOff && !Pwsh20
					if (box != null && IsDark) { SetWindowTheme(box.Handle, "DarkMode_CFD", null); } // 暗化滚动条
					#endif
				};
				form.ShowDialog();
			}
			return true;
		}
	}
	#endif

	internal static class PSRunnerEntry {
		private static int Main() {
			#if !noOutput
				#if UNICODEEncoding && !noConsole
				System.Console.OutputEncoding = new System.Text.UnicodeEncoding();
				#endif
				#if UTF8Encoding && !noConsole
				System.Console.OutputEncoding = new System.Text.UTF8Encoding();
				#endif

				#if !noVisualStyles && noConsole
				Application.EnableVisualStyles();
				#endif

				#if noConsole
					// 加载 assembly:AssemblyTitle
					AssemblyTitleAttribute titleAttribute = (AssemblyTitleAttribute) Attribute.GetCustomAttribute(Assembly.GetExecutingAssembly(), typeof(AssemblyTitleAttribute));
					string title;
					if (titleAttribute != null)
						title = titleAttribute.Title;
					else
						title = System.AppDomain.CurrentDomain.FriendlyName;
					// 弹窗输出 \ConstResult
					string[] ConstResult = { "$ConstResult" };
					foreach (string item in ConstResult) {
						ConstMessageBox.TryShow(item, title);
					}
				#else
					// 控制台输出 \ConstResult
					System.Console.WriteLine("$ConstResult");
				#endif
			#endif
			return $ConstExitCodeResult;
		}
	}
}
