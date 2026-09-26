// 由 Ingo Karstein 创建的简单 PowerShell 宿主 (http://blog.karstein-consulting.com)
// 由 Markus Scholtes 重构并添加 GUI 支持

using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.IO;
#if !Pwsh20
	using System.Management.Automation.Language;
#endif
using System.Globalization;
using System.Management.Automation.Host;
using System.Security;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Runtime.InteropServices;
#if noConsole
	using System.Windows.Forms;
	using System.Drawing;
#endif
using System.Runtime.Versioning;

/*__ASSEMBLY_ATTRIBUTES__*/
namespace PSRunnerNS {
	#if noConsole || credentialGUI
	internal class Credential_Form {
		[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
		private struct CREDUI_INFO {
			public int cbSize;
			public IntPtr hwndParent;
			public string pszMessageText;
			public string pszCaptionText;
			public IntPtr hbmBanner;
		}

		[Flags]
		enum CREDUI_FLAGS {
			INCORRECT_PASSWORD = 0x1,
			DO_NOT_PERSIST = 0x2,
			REQUEST_ADMINISTRATOR = 0x4,
			EXCLUDE_CERTIFICATES = 0x8,
			REQUIRE_CERTIFICATE = 0x10,
			SHOW_SAVE_CHECK_BOX = 0x40,
			ALWAYS_SHOW_UI = 0x80,
			REQUIRE_SMARTCARD = 0x100,
			PASSWORD_ONLY_OK = 0x200,
			VALIDATE_USERNAME = 0x400,
			COMPLETE_USERNAME = 0x800,
			PERSIST = 0x1000,
			SERVER_CREDENTIAL = 0x4000,
			EXPECT_CONFIRMATION = 0x20000,
			GENERIC_CREDENTIALS = 0x40000,
			USERNAME_TARGET_CREDENTIALS = 0x80000,
			KEEP_USERNAME = 0x100000,
		}

		public enum CredUI_ReturnCodes {
			NO_ERROR = 0,
			ERROR_CANCELLED = 1223,
			ERROR_NO_SUCH_LOGON_SESSION = 1312,
			ERROR_NOT_FOUND = 1168,
			ERROR_INVALID_ACCOUNT_NAME = 1315,
			ERROR_INSUFFICIENT_BUFFER = 122,
			ERROR_INVALID_PARAMETER = 87,
			ERROR_INVALID_FLAGS = 1004,
		}

		[DllImport("credui", CharSet = CharSet.Unicode)]
		private static extern CredUI_ReturnCodes CredUIPromptForCredentials(ref CREDUI_INFO credinfo,
			string targetName,
			IntPtr reserved1,
			int iError,
			StringBuilder userName,
			int maxUserName,
			StringBuilder password,
			int maxPassword,
			[MarshalAs(UnmanagedType.Bool)] ref bool pfSave,
			CREDUI_FLAGS flags);

		public class User_Pwd {
			public string User = string.Empty;
			public string Password = string.Empty;
			public string Domain = string.Empty;
		}

		internal static User_Pwd PromptForPassword(string caption, string message, string target, string user, PSCredentialTypes credTypes, PSCredentialUIOptions options) {
			// 初始化标志和变量
			StringBuilder userPassword = new StringBuilder("", 128), userID = new StringBuilder(user, 128);
			CREDUI_INFO credUI = new CREDUI_INFO();
			if (!string.IsNullOrEmpty(message)) credUI.pszMessageText = message;
			if (!string.IsNullOrEmpty(caption)) credUI.pszCaptionText = caption;
			credUI.cbSize = Marshal.SizeOf(credUI);
			bool save = false;

			CREDUI_FLAGS flags = CREDUI_FLAGS.DO_NOT_PERSIST;
			if ((credTypes & PSCredentialTypes.Generic) == PSCredentialTypes.Generic) {
				flags |= CREDUI_FLAGS.GENERIC_CREDENTIALS;
				if ((options & PSCredentialUIOptions.AlwaysPrompt) == PSCredentialUIOptions.AlwaysPrompt) {
					flags |= CREDUI_FLAGS.ALWAYS_SHOW_UI;
				}
			}

			// 以图形提示向用户询问密码
			CredUI_ReturnCodes returnCode = CredUIPromptForCredentials(ref credUI, target, IntPtr.Zero, 0, userID, 128, userPassword, 128, ref save, flags);

			if (returnCode == CredUI_ReturnCodes.NO_ERROR) {
				User_Pwd ret = new User_Pwd();
				ret.User = userID.ToString();
				ret.Password = userPassword.ToString();
				ret.Domain = "";
				return ret;
			}

			return null;
		}
	}
	#endif

	internal class PSRunnerRawUI: PSHostRawUserInterface {
		#if noConsole
			// GUI 输出时的控制台颜色会被读取和设置，但目前尚未使用（供将来使用）
			private ConsoleColor _GUIBackgroundColor = ConsoleColor.White;
			private ConsoleColor _GUIForegroundColor = ConsoleColor.Black;

			private string _windowTitleData;
			public PSRunnerRawUI() {
				// DLL 导出模式下没有托管入口程序集，回退到当前程序集。
				Assembly hostAssembly = Assembly.GetEntryAssembly() ?? Assembly.GetExecutingAssembly();
				AssemblyTitleAttribute titleAttribute = (AssemblyTitleAttribute) Attribute.GetCustomAttribute(hostAssembly, typeof(AssemblyTitleAttribute));
				if (titleAttribute != null)
					_windowTitleData = titleAttribute.Title;
				else {
					Assembly entry = Assembly.GetEntryAssembly();
					if (entry == null || string.IsNullOrEmpty(entry.Location))
						_windowTitleData = System.AppDomain.CurrentDomain.FriendlyName;
					else
						_windowTitleData = Path.GetFileNameWithoutExtension(entry.Location);
				}
			}
		#else
			const int STD_OUTPUT_HANDLE = -11;

			//CHAR_INFO 结构体早年是一个 union，因此我们用 LayoutKind.Explicit 尽量贴近它
			[StructLayout(LayoutKind.Explicit)]
			public struct CHAR_INFO {
				[FieldOffset(0)]
				internal char UnicodeChar;
				[FieldOffset(0)]
				internal char AsciiChar;
				[FieldOffset(2)] //2 字节似乎能正常工作
				internal UInt16 Attributes;
			}

			//COORD 结构体
			[StructLayout(LayoutKind.Sequential)]
			public struct COORD {
				public short X;
				public short Y;
			}

			//SMALL_RECT 结构体
			[StructLayout(LayoutKind.Sequential)]
			public struct SMALL_RECT {
				public short Left;
				public short Top;
				public short Right;
				public short Bottom;
			}

			/* 从控制台屏幕缓冲区的矩形字符单元格块读取字符与颜色属性数据，并把数据写入目标缓冲区指定位置的矩形块。 */
			[DllImport("Kernel32.dll", EntryPoint = "ReadConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
			internal static extern bool ReadConsoleOutput(
				IntPtr hConsoleOutput,
				/* 该指针被视为 CHAR_INFO 结构二维数组的原点，数组大小由 dwBufferSize 参数指定。*/
				[MarshalAs(UnmanagedType.LPArray), Out] CHAR_INFO[, ] lpBuffer,
				COORD dwBufferSize,
				COORD dwBufferCoord,
				ref SMALL_RECT lpReadRegion);

			/* 把字符与颜色属性数据写入控制台屏幕缓冲区中指定的矩形字符单元格块。要写入的数据取自源缓冲区指定位置的相应大小矩形块。 */
			[DllImport("Kernel32.dll", EntryPoint = "WriteConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
			internal static extern bool WriteConsoleOutput(
				IntPtr hConsoleOutput,
				/* 该指针被视为 CHAR_INFO 结构二维数组的原点，数组大小由 dwBufferSize 参数指定。*/
				[MarshalAs(UnmanagedType.LPArray), In] CHAR_INFO[, ] lpBuffer,
				COORD dwBufferSize,
				COORD dwBufferCoord,
				ref SMALL_RECT lpWriteRegion);

			/* 在屏幕缓冲区中移动一块数据。移动效果可用裁剪矩形加以限制，裁剪矩形之外的屏幕缓冲区内容保持不变。 */
			[DllImport("Kernel32.dll", SetLastError = true)]
			static extern bool ScrollConsoleScreenBuffer(
				IntPtr hConsoleOutput,
				[In] ref SMALL_RECT lpScrollRectangle,
				[In] ref SMALL_RECT lpClipRectangle,
				COORD dwDestinationOrigin,
				[In] ref CHAR_INFO lpFill);

			[DllImport("Kernel32.dll", SetLastError = true)]
			static extern IntPtr GetStdHandle(int nStdHandle);
		#endif

		public override ConsoleColor BackgroundColor {
			#if !noConsole
				get { return Console.BackgroundColor; }
				set { Console.BackgroundColor = value; }
			#else
				get { return _GUIBackgroundColor; }
				set { _GUIBackgroundColor = value; }
			#endif
		}

		public override System.Management.Automation.Host.Size BufferSize {
			get {
				#if !noConsole
					if (!Console_Info.IsOutputRedirected())
						return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferHeight);
				#endif
				// 返回默认值。如果没有返回有效值，WriteLine 将不会被调用
				return new System.Management.Automation.Host.Size(120, 50);
			}
			set {
				#if !noConsole
					Console.BufferWidth = value.Width;
					Console.BufferHeight = value.Height;
				#endif
			}
		}

		public override Coordinates CursorPosition {
			get {
				return new Coordinates(
				#if !noConsole
					Console.CursorLeft, Console.CursorTop
				#else
					// 为 WinForms 返回一个虚拟值。
					0, 0
				#endif
				);
			}
			set {
				#if !noConsole
					Console.CursorTop = value.Y;
					Console.CursorLeft = value.X;
				#endif
			}
		}

		public override int CursorSize {
			get {
				return
					#if !noConsole
						Console.CursorSize
					#else
						// 为 WinForms 返回一个虚拟值。
						25
					#endif
				;
			}
			set {
				#if !noConsole
					Console.CursorSize = value;
				#endif
			}
		}

		#if noConsole
			private Form Invisible_Form;
		#endif

		public override void FlushInputBuffer() {
			#if !noConsole
			if (!Console_Info.IsInputRedirected()) {
				while (Console.KeyAvailable)
					Console.ReadKey(true);
			}
			#else
			if (Invisible_Form != null) {
				Invisible_Form.Close();
				Invisible_Form = null;
			} else {
				Invisible_Form = new Form();
				Invisible_Form.Opacity = 0;
				Invisible_Form.ShowInTaskbar = false;
				Invisible_Form.Visible = true;
			}
			#endif
		}

		public override ConsoleColor ForegroundColor {
			#if !noConsole
				get { return Console.ForegroundColor; }
				set { Console.ForegroundColor = value; }
			#else
				get { return _GUIForegroundColor; }
				set { _GUIForegroundColor = value; }
			#endif
		}

		public override BufferCell[, ] GetBufferContents(System.Management.Automation.Host.Rectangle rectangle) {
			#if !noConsole
			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			CHAR_INFO[, ] buffer = new CHAR_INFO[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];
			COORD buffer_size = new COORD {
				X = (short)(rectangle.Right - rectangle.Left + 1), Y = (short)(rectangle.Bottom - rectangle.Top + 1)
			};
			COORD buffer_index = new COORD {
				X = 0, Y = 0
			};
			SMALL_RECT screen_rect = new SMALL_RECT {
				Left = (short) rectangle.Left, Top = (short) rectangle.Top, Right = (short) rectangle.Right, Bottom = (short) rectangle.Bottom
			};

			ReadConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);

			System.Management.Automation.Host.BufferCell[, ] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];
			for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)
				for (int x = 0; x <= rectangle.Right - rectangle.Left; x++) {
					ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell(buffer[y, x].AsciiChar, (System.ConsoleColor)(buffer[y, x].Attributes & 0xF), (System.ConsoleColor)((buffer[y, x].Attributes & 0xF0) / 0x10), System.Management.Automation.Host.BufferCellType.Complete);
				}

			return ScreenBuffer;
			#else
			System.Management.Automation.Host.BufferCell[, ] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];

			for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)
				for (int x = 0; x <= rectangle.Right - rectangle.Left; x++) {
					ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell(' ', _GUIForegroundColor, _GUIBackgroundColor, System.Management.Automation.Host.BufferCellType.Complete);
				}

			return ScreenBuffer;
			#endif
		}

		public override bool KeyAvailable {
			get {
				return
					#if !noConsole
						Console.KeyAvailable
					#else
						true
					#endif
				;
			}
		}

		public override System.Management.Automation.Host.Size MaxPhysicalWindowSize {
			get {
				return new System.Management.Automation.Host.Size(
					#if !noConsole
						Console.LargestWindowWidth, Console.LargestWindowHeight
					#else
						// WinForms 的虚拟值
						240, 84
					#endif
				);
			}
		}

		public override System.Management.Automation.Host.Size MaxWindowSize {
			get {
				return new System.Management.Automation.Host.Size(
					#if !noConsole
						Console.BufferWidth, Console.BufferWidth
					#else
						// WinForms 的虚拟值
						120, 84
					#endif
				);
			}
		}

		public override KeyInfo ReadKey(ReadKeyOptions options) {
			#if !noConsole
			ConsoleKeyInfo info = Console.ReadKey((options & ReadKeyOptions.NoEcho) != 0);

			ControlKeyStates state = 0;
			if ((info.Modifiers & ConsoleModifiers.Alt) != 0)
				state |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
			if ((info.Modifiers & ConsoleModifiers.Control) != 0)
				state |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
			if ((info.Modifiers & ConsoleModifiers.Shift) != 0)
				state |= ControlKeyStates.ShiftPressed;
			if (Console.CapsLock)
				state |= ControlKeyStates.CapsLockOn;
			if (Console.NumberLock)
				state |= ControlKeyStates.NumLockOn;

			return new KeyInfo((int) info.Key, info.KeyChar, state, (options & ReadKeyOptions.IncludeKeyDown) != 0);
			#else
			if ((options & ReadKeyOptions.IncludeKeyDown) != 0)
				return ReadKey_Box.Show(_windowTitleData, "", true);
			else
				return ReadKey_Box.Show(_windowTitleData, "", false);
			#endif
		}

		public override void ScrollBufferContents(System.Management.Automation.Host.Rectangle source, Coordinates destination, System.Management.Automation.Host.Rectangle clip, BufferCell fill) { // 未实现目标块裁剪
			#if !noConsole
			// 裁剪区域超出源范围？
			if ((source.Left > clip.Right) || (source.Right < clip.Left) || (source.Top > clip.Bottom) || (source.Bottom < clip.Top)) { // 裁剪超出范围 -> 无需处理
				return;
			}

			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			SMALL_RECT lpScrollRectangle = new SMALL_RECT {
				Left = (short) source.Left, Top = (short) source.Top, Right = (short)(source.Right), Bottom = (short)(source.Bottom)
			};
			SMALL_RECT lpClipRectangle;
			if (clip != null) {
				lpClipRectangle = new SMALL_RECT {
					Left = (short) clip.Left, Top = (short) clip.Top, Right = (short)(clip.Right), Bottom = (short)(clip.Bottom)
				};
			} else {
				lpClipRectangle = new SMALL_RECT {
					Left = (short) 0, Top = (short) 0, Right = (short)(Console.WindowWidth - 1), Bottom = (short)(Console.WindowHeight - 1)
				};
			}
			COORD dwDestinationOrigin = new COORD {
				X = (short)(destination.X), Y = (short)(destination.Y)
			};
			CHAR_INFO lpFill = new CHAR_INFO {
				AsciiChar = fill.Character, Attributes = (ushort)((int)(fill.ForegroundColor) + ((int)(fill.BackgroundColor) * 16))
			};

			ScrollConsoleScreenBuffer(hStdOut, ref lpScrollRectangle, ref lpClipRectangle, dwDestinationOrigin, ref lpFill);
			#endif
		}

		public override void SetBufferContents(System.Management.Automation.Host.Rectangle rectangle, BufferCell fill) {
			#if !noConsole
			// 用一个小技巧：把缓冲区移出屏幕，源区域便会被 fill.Character 字符填充
			if (rectangle.Left >= 0)
				Console.MoveBufferArea(rectangle.Left, rectangle.Top, rectangle.Right - rectangle.Left + 1, rectangle.Bottom - rectangle.Top + 1, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			else { // Clear-Host：把所有内容移出屏幕
				Console.MoveBufferArea(0, 0, BufferSize.Width, BufferSize.Height, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			}
			#endif
		}

		public override void SetBufferContents(Coordinates origin, BufferCell[, ] contents) {
			#if !noConsole
			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			CHAR_INFO[, ] buffer = new CHAR_INFO[contents.GetLength(0), contents.GetLength(1)];
			COORD buffer_size = new COORD {
				X = (short)(contents.GetLength(1)), Y = (short)(contents.GetLength(0))
			};
			COORD buffer_index = new COORD {
				X = 0, Y = 0
			};
			SMALL_RECT screen_rect = new SMALL_RECT {
				Left = (short) origin.X, Top = (short) origin.Y, Right = (short)(origin.X + contents.GetLength(1) - 1), Bottom = (short)(origin.Y + contents.GetLength(0) - 1)
			};

			for (int y = 0; y < contents.GetLength(0); y++)
				for (int x = 0; x < contents.GetLength(1); x++) {
					buffer[y, x] = new CHAR_INFO {
						AsciiChar = contents[y, x].Character, Attributes = (ushort)((int)(contents[y, x].ForegroundColor) + ((int)(contents[y, x].BackgroundColor) * 16))
					};
				}

			WriteConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);
			#endif
		}

		public override Coordinates WindowPosition {
			get {
				return new Coordinates(
					#if !noConsole
						Console.WindowLeft, Console.WindowTop
					#else
						// WinForms 的虚拟值
						0, 0
					#endif
				);
			}
			set {
				#if !noConsole
				Console.WindowLeft = value.X;
				Console.WindowTop = value.Y;
				#endif
			}
		}

		public override System.Management.Automation.Host.Size WindowSize {
			get {
				return new System.Management.Automation.Host.Size(
				#if !noConsole
					Console.WindowWidth, Console.WindowHeight
				#else
					// WinForms 的虚拟值
					120, 50
				#endif
				);
			}
			set {
				#if !noConsole
				Console.WindowWidth = value.Width;
				Console.WindowHeight = value.Height;
				#endif
			}
		}

		public override string WindowTitle {
			get {
				#if !noConsole
					return Console.Title;
				#else
					return _windowTitleData;
				#endif
			}
			set {
				#if !noConsole
					Console.Title = value;
				#else
					_windowTitleData = value;
				#endif
			}
		}
	}

	#if noConsole
	internal static class SystemDialogText {
		[DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
		static extern IntPtr MB_GetString(uint strId);

		public static string GetButtonLabel(uint strId, string fallback) {
			try {
				string value = Marshal.PtrToStringUni(MB_GetString(strId));
				if (!string.IsNullOrEmpty(value)) { return value; }
			} catch { }
			return fallback;
		}
	}

	public class Input_Box {
		// 几何对齐标准 WinForms 输入框参照。深色适配交给 DarkMode 的窗口首帧染色，无需在此处理。
		const int InputMargin = 12;
		const int InputButtonWidth = 75;
		const int InputButtonHeight = 23;

		public static DialogResult Show(string strTitle, string strPrompt, ref string strVal, bool blSecure) {
			// 生成控件
			Form form = new Form();
			form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.None;
			Label label = new Label();
			TextBox textBox = new TextBox();
			Button buttonOk = new Button();
			Button buttonCancel = new Button();

			// 尺寸和位置根据标签确定，必须先完成这个控件
			if (string.IsNullOrEmpty(strPrompt)) {
				if (blSecure)
					strPrompt = "Secure input:";
				else
					strPrompt = "Input:";
			}
			label.Text = strPrompt;
			label.Location = new Point(InputMargin, InputMargin);
			label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - InputMargin * 2, 0);
			label.AutoSize = true;
			// 标签的尺寸要到 Add() 之后才能确定
			form.Controls.Add(label);
			int iClientWidth = System.Math.Max(352, label.Right + InputMargin);

			// 生成文本框
			if (blSecure) textBox.UseSystemPasswordChar = true;
			textBox.Text = strVal;
			textBox.SetBounds(InputMargin, System.Math.Max(38, label.Bottom + 6), iClientWidth - InputMargin * 2, 23);

			buttonOk.Text = SystemDialogText.GetButtonLabel(0, "OK");
			buttonCancel.Text = SystemDialogText.GetButtonLabel(1, "Cancel");

			int iButtonTop = textBox.Bottom + 33;
			buttonOk.DialogResult = DialogResult.OK;
			buttonCancel.DialogResult = DialogResult.Cancel;
			buttonCancel.SetBounds(iClientWidth - InputMargin - InputButtonWidth * 2 - 6, iButtonTop, InputButtonWidth, InputButtonHeight);
			buttonOk.SetBounds(iClientWidth - InputMargin - InputButtonWidth, iButtonTop, InputButtonWidth, InputButtonHeight);

			// 配置窗体
			form.Text = strTitle;
			form.ClientSize = new System.Drawing.Size(iClientWidth, iButtonTop + InputButtonHeight + 17);
			form.Controls.AddRange(new Control[] {
				textBox,
				buttonOk,
				buttonCancel
			});
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.ShowInTaskbar = false;
			form.ShowIcon = false;
			form.AcceptButton = buttonOk;
			form.CancelButton = buttonCancel;
			form.Shown += delegate { textBox.Focus(); };

			// 显示窗体并计算结果
			DialogResult dialogResult = form.ShowDialog();
			strVal = textBox.Text;
			return dialogResult;
		}

		public static DialogResult Show(string strTitle, string strPrompt, ref string strVal) {
			return Show(strTitle, strPrompt, ref strVal, false);
		}
	}

	public class Choice_Box {
		// 几何对齐系统亮色 Choice 参照：客户区宽 360、提示左/上 12/12、单选缩进 29、首项/行距 9/7，按钮右/底留白 12/13。
		// 深色适配交给 DarkMode 的窗口首帧染色。
		const int ChoiceClientWidth = 360;
		const int ChoicePromptLeft = 12;
		const int ChoicePromptTop = 12;
		const int ChoiceFirstRadioGap = 9;
		const int ChoiceRadioGap = 7;
		const int ChoiceButtonGap = 24;
		const int ChoiceBottomMargin = 13;
		const int ChoiceRightMargin = 12;
		#if darkModeOff
		[DllImport("dwmapi.dll")]
		static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

		static void SetLightTitleBar(Form form) {
			int useDarkMode = 0;
			if (DwmSetWindowAttribute(form.Handle, 20, ref useDarkMode, sizeof(int)) != 0)
				DwmSetWindowAttribute(form.Handle, 19, ref useDarkMode, sizeof(int));
		}
		#endif

		public static int Show(System.Collections.ObjectModel.Collection<ChoiceDescription> arrChoice, int intDefault, string strTitle, string strPrompt) {
			// 数组为空则取消
			if (arrChoice == null || arrChoice.Count < 1) return -1;

			// 生成控件
			Form form = new Form();
			form.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
			form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.None;
			form.Font = SystemFonts.DefaultFont;
			RadioButton[] aradioButton = new RadioButton[arrChoice.Count];
			ToolTip toolTip = new ToolTip();
			Button buttonOk = new Button();

			// 尺寸和位置根据标签确定，有提示时必须先完成这个控件
			int iPosY = ChoicePromptTop, iMaxX = 0;
			int iMaxWidth = System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18;
			if (!string.IsNullOrEmpty(strPrompt)) {
				Label label = new Label();
				label.Text = strPrompt;
				label.BackColor = form.BackColor;
				label.ForeColor = form.ForeColor;
				label.Location = new Point(ChoicePromptLeft, ChoicePromptTop);
				label.MaximumSize = new System.Drawing.Size(iMaxWidth, 0);
				label.AutoSize = true;
				// 标签的尺寸要到 Add() 之后才能确定
				form.Controls.Add(label);
				iPosY = label.Bottom + ChoiceFirstRadioGap;
				iMaxX = label.Right;
			}

			// 其余尺寸和位置以单选按钮为基准，因此现在就完成这些控件
			int Counter = 0;
			int tempWidth = iMaxWidth;
			foreach(ChoiceDescription sAuswahl in arrChoice) {
				aradioButton[Counter] = new RadioButton();
				aradioButton[Counter].Text = Regex.Replace(sAuswahl.Label, ".\b", "");
				aradioButton[Counter].BackColor = form.BackColor;
				aradioButton[Counter].ForeColor = form.ForeColor;
				if (Counter == intDefault)
					aradioButton[Counter].Checked = true;
				aradioButton[Counter].Location = new Point(29, iPosY);
				aradioButton[Counter].AutoSize = true;
				// 标签的尺寸要到 Add() 之后才能确定
				form.Controls.Add(aradioButton[Counter]);
				if (aradioButton[Counter].Width > tempWidth) { // 单选按钮对屏幕来说太宽 -> 换成两行
					int tempHeight = aradioButton[Counter].Height;
					aradioButton[Counter].Height = tempHeight * (1 + (aradioButton[Counter].Width - 1) / tempWidth);
					aradioButton[Counter].Width = tempWidth;
					aradioButton[Counter].AutoSize = false;
				}
				iPosY = aradioButton[Counter].Bottom + ChoiceRadioGap;
				if (aradioButton[Counter].Right > iMaxX) {
					iMaxX = aradioButton[Counter].Right;
				}
				if (!string.IsNullOrEmpty(sAuswahl.HelpMessage))
					toolTip.SetToolTip(aradioButton[Counter], sAuswahl.HelpMessage);
				Counter++;
			}

			// 父窗口不活动时也显示工具提示
			toolTip.ShowAlways = true;

			// 创建按钮
			buttonOk.Text = SystemDialogText.GetButtonLabel(0, "OK");
			buttonOk.DialogResult = DialogResult.OK;
			int iButtonTop = iPosY - ChoiceRadioGap + ChoiceButtonGap;
			int iClientWidth = System.Math.Max(ChoiceClientWidth, iMaxX + ChoiceRightMargin);
			buttonOk.SetBounds(iClientWidth - ChoiceRightMargin - 75, iButtonTop, 75, 23);

			// 配置窗体
			form.Text = strTitle;
			form.ClientSize = new System.Drawing.Size(iClientWidth, buttonOk.Bottom + ChoiceBottomMargin);
			form.Controls.Add(buttonOk);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.ShowInTaskbar = false;
			form.ShowIcon = false;
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.AcceptButton = buttonOk;
			#if darkModeOff
			SetLightTitleBar(form);
			#endif

			// 显示并计算窗体
			if (form.ShowDialog() != DialogResult.OK)
				return -1;
			int iRueck = -1;
			for (Counter = 0; Counter < arrChoice.Count; Counter++) {
				if (aradioButton[Counter].Checked == true) {
					iRueck = Counter;
				}
			}
			return iRueck;
		}
	}

	public class ReadKey_Box {
		[DllImport("dwmapi.dll")]
		static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
		[DllImport("user32.dll")]
		public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
			[Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] System.Text.StringBuilder pwszBuff,
			int cchBuff, uint wFlags);

		static string GetCharFromKeys(Keys keys, bool blShift, bool blAltGr) {
			System.Text.StringBuilder buffer = new System.Text.StringBuilder(64);
			byte[] keyboardState = new byte[256];
			if (blShift)
				keyboardState[(int) Keys.ShiftKey] = 0xff;
			if (blAltGr) {
				keyboardState[(int) Keys.ControlKey] = 0xff;
				keyboardState[(int) Keys.Menu] = 0xff;
			}
			if (ToUnicode((uint) keys, 0, keyboardState, buffer, 64, 0) >= 1)
				return buffer.ToString();
			else
				return "\0";
		}

		class Keyboard_Form: Form {
			public Keyboard_Form() {
				this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.None;
				this.Font = SystemFonts.MessageBoxFont;
				this.KeyDown += new KeyEventHandler(Keyboard_Form_KeyDown);
				this.KeyUp += new KeyEventHandler(Keyboard_Form_KeyUp);
			}

			// 检查 KeyDown 还是 KeyUp？
			public bool checkKeyDown = true;
			// 按键的键码
			public KeyInfo keyinfo;

			void Keyboard_Form_KeyDown(object sender, KeyEventArgs kevent) {
				if (checkKeyDown) { // 存储按键信息
					keyinfo.VirtualKeyCode = kevent.KeyValue;
					keyinfo.Character = GetCharFromKeys(kevent.KeyCode, kevent.Shift, kevent.Alt & kevent.Control)[0];
					keyinfo.KeyDown = false;
					keyinfo.ControlKeyState = 0;
					if (kevent.Alt) {
						keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
					}
					if (kevent.Control) {
						keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!kevent.Alt)
							if (kevent.KeyValue > 64 && kevent.KeyValue < 96)
								keyinfo.Character = (char)(kevent.KeyValue - 64);
					}
					if (kevent.Shift) {
						keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed;
					}
					if ((kevent.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn;
					}
					if ((kevent.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn;
					}
					// 然后关闭窗体
					this.Close();
				}
			}

			void Keyboard_Form_KeyUp(object sender, KeyEventArgs kevent) {
				if (!checkKeyDown) { // 存储按键信息
					keyinfo.VirtualKeyCode = kevent.KeyValue;
					keyinfo.Character = GetCharFromKeys(kevent.KeyCode, kevent.Shift, kevent.Alt & kevent.Control)[0];
					keyinfo.KeyDown = true;
					keyinfo.ControlKeyState = 0;
					if (kevent.Alt) {
						keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
					}
					if (kevent.Control) {
						keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!kevent.Alt)
							if (kevent.KeyValue > 64 && kevent.KeyValue < 96)
								keyinfo.Character = (char)(kevent.KeyValue - 64);
					}
					if (kevent.Shift) {
						keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed;
					}
					if ((kevent.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn;
					}
					if ((kevent.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn;
					}
					// 然后关闭窗体
					this.Close();
				}
			}
		}

		// 几何对齐单行提示框（125% DPI）：文本内边距 12/34，按钮 86x26 距右 20。
		const int ReadKeyLabelLeft = 10;
		const int ReadKeyLabelTop = 28;
		const int ReadKeyClientWidth = 138;
		const int ReadKeyClientHeight = 123;
		const int ReadKeyButtonTop = 84;
		const int ReadKeyButtonWidth = 86;
		const int ReadKeyButtonHeight = 26;
		const int ReadKeyButtonRightMargin = 20;
		const int ReadKeyButtonBottomMargin = 11;

		static void ApplyTitleBar(IntPtr hwnd) {
			#if !darkModeOff && !Pwsh20
			DarkMode.DarkTitleBar(hwnd);
			#else
			int light = 0;
			DwmSetWindowAttribute(hwnd, 20, ref light, sizeof(int));
			DwmSetWindowAttribute(hwnd, 19, ref light, sizeof(int));
			#endif
		}

		public static KeyInfo Show(string strTitle, string strPrompt, bool blIncludeKeyDown) {
			// 创建控件
			Keyboard_Form form = new Keyboard_Form();
			form.Text = strTitle;
			form.HandleCreated += delegate { ApplyTitleBar(form.Handle); };
			Label label = new Label();

			// 尺寸和位置以标签为基准，因此先完成这个控件
			if (string.IsNullOrEmpty(strPrompt))
				label.Text = "Press a key";
			else
				label.Text = strPrompt;
			label.Location = new Point(ReadKeyLabelLeft, ReadKeyLabelTop);
			label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);
			label.AutoSize = true;
			// 标签的尺寸要到 Add() 之后才能确定
			form.Controls.Add(label);

			// 与原生 MessageBox 一致的确认按钮（点击即等价于按一下确定键），贴客户区右下角。
			Button buttonOk = new Button();
			buttonOk.Text = SystemDialogText.GetButtonLabel(0, "OK");
			buttonOk.DialogResult = DialogResult.OK;
			buttonOk.Size = new System.Drawing.Size(ReadKeyButtonWidth, ReadKeyButtonHeight);
			buttonOk.Location = new Point(0, ReadKeyButtonTop);
			form.Controls.Add(buttonOk);
			form.AcceptButton = buttonOk;

			// 配置窗体
			int iClientWidth = System.Math.Max(ReadKeyClientWidth, System.Math.Max(label.Right + ReadKeyButtonRightMargin, ReadKeyButtonWidth + ReadKeyButtonRightMargin));
			int iClientHeight = System.Math.Max(ReadKeyClientHeight, buttonOk.Bottom + ReadKeyButtonBottomMargin);
			buttonOk.Location = new Point(iClientWidth - ReadKeyButtonWidth - ReadKeyButtonRightMargin, buttonOk.Top);
			form.ClientSize = new System.Drawing.Size(iClientWidth, iClientHeight);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.ShowIcon = false;
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.ControlBox = true;
			form.ShowInTaskbar = false;
			form.Shown += delegate { ApplyTitleBar(form.Handle); };

			// 显示并计算窗体
			form.checkKeyDown = blIncludeKeyDown;
			form.ShowDialog();
			return form.keyinfo;
		}
	}

	// 自绘进度条：WinForms 的 ProgressBar 是原生控件、OnPaint 不生效，深色下无法控色（主题只暗轨道、填充会断裂），
	// 因此继承 Control 自绘。同时修正浅色下 ProgressBar.ForeColor 被忽略、渲染成绿色的问题。
	public class FlatProgressBar: Control {
		int minimum = 0, maximum = 100, current = 0;

		public FlatProgressBar() {
			SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
		}

		[System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
		public int Minimum { get { return minimum; } set { minimum = value; Invalidate(); } }
		[System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
		public int Maximum { get { return maximum; } set { maximum = value; Invalidate(); } }
		[System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
		public int Value { get { return current; } set { current = System.Math.Max(minimum, System.Math.Min(maximum, value)); Invalidate(); } }

		// 进度条强调色（来自 Progress_Form 的 ConsoleColor 设置）。
		public Color BarColor = Color.FromArgb(0, 120, 215);
		public Color TrackColor = Color.FromArgb(231, 231, 231);
		public Color BorderColor = Color.FromArgb(173, 173, 173);
		public Color BackColorOverride = Color.White;

		static System.Drawing.Drawing2D.GraphicsPath Rounded(System.Drawing.Rectangle rect, int radius) {
			System.Drawing.Drawing2D.GraphicsPath path = new System.Drawing.Drawing2D.GraphicsPath();
			int diameter = radius * 2;
			path.AddArc(rect.Left, rect.Top, diameter, diameter, 180, 90);
			path.AddArc(rect.Right - diameter, rect.Top, diameter, diameter, 270, 90);
			path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
			path.AddArc(rect.Left, rect.Bottom - diameter, diameter, diameter, 90, 90);
			path.CloseFigure();
			return path;
		}

		protected override void OnPaint(PaintEventArgs e) {
			Graphics graphics = e.Graphics;
			graphics.Clear(BackColorOverride);
			graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
			System.Drawing.Rectangle bounds = new System.Drawing.Rectangle(0, 0, Width - 1, Height - 1);
			if (bounds.Width <= 0 || bounds.Height <= 0) { return; }
			using (System.Drawing.Drawing2D.GraphicsPath outer = Rounded(bounds, 3))
			using (SolidBrush trackBrush = new SolidBrush(TrackColor))
			using (Pen borderPen = new Pen(BorderColor)) {
				graphics.FillPath(trackBrush, outer);
				graphics.DrawPath(borderPen, outer);
			}
			double fraction = (maximum - minimum) == 0 ? 0 : (current - minimum) / (double)(maximum - minimum);
			int fillWidth = (int)System.Math.Round((Width - 2) * fraction);
			if (fillWidth > 0) {
				System.Drawing.Rectangle fill = new System.Drawing.Rectangle(1, 1, fillWidth, Height - 2);
				using (System.Drawing.Drawing2D.GraphicsPath inner = Rounded(fill, 3))
				using (SolidBrush fillBrush = new SolidBrush(BarColor)) {
					graphics.FillPath(fillBrush, inner);
				}
			}
		}
	}

	public class Progress_Form: Form {
		const int ProgressFormWidth = 406;
		const int ProgressFormHeight = 196;
		const int ProgressHeaderHeight = 40;
		const int ProgressFooterHeight = 41;
		const int ProgressRowHeight = 104;
		private ConsoleColor ProgressBarColor = ConsoleColor.Green;
		private string WindowTitle = "";

		#if !noVisualStyles
		private System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
		private int _barNumber = -1;
		private int _barValue = -1;
		#endif

		struct Progress_Data {
			internal Label lbActivity;
			internal Label lbStatus;
			internal FlatProgressBar objProgressBar;
			internal Label lbRemainingTime;
			internal Label lbOperation;
			internal int ActivityId;
			internal int ParentActivityId;
			internal int Depth;
		};

		// 配色（Off/Pwsh20 产物固定浅色）。
		static Color WindowBackColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.WindowColor; }
				#endif
				return Color.White;
			}
		}

		static Color FieldBackColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.FieldColor; }
				#endif
				return Color.FromArgb(240, 240, 240);
			}
		}

		static Color BorderLineColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.BorderColor; }
				#endif
				return Color.FromArgb(184, 184, 184);
			}
		}

		static Color ProgressTrackColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.FieldColor; }
				#endif
				return Color.FromArgb(231, 231, 231);
			}
		}

		static Color LabelTextColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.TextColor; }
				#endif
				return SystemColors.ControlText;
			}
		}

		static Color HeaderStartColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return Color.FromArgb(47, 47, 47); }
				#endif
				return Color.FromArgb(218, 228, 243);
			}
		}

		static Color HeaderEndColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.WindowColor; }
				#endif
				return Color.FromArgb(9, 51, 93);
			}
		}

		static Color HeaderMiddleColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return Color.FromArgb(58, 58, 58); }
				#endif
				return Color.FromArgb(156, 192, 227);
			}
		}

		static Color HeaderTextColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.TextColor; }
				#endif
				return SystemColors.ControlText;
			}
		}

		static Color CancelButtonBackColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.FieldColor; }
				#endif
				return Color.White;
			}
		}

		static Color CancelButtonBorderColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (DarkMode.IsDark) { return DarkMode.BorderColor; }
				#endif
				return Color.FromArgb(0, 120, 215);
			}
		}

		private List<Progress_Data> progressDataList = new List<Progress_Data> ();
		private volatile int progressCount;
		private Action cancelPipeline;

		public Progress_Form(string Title, ConsoleColor BarColor, Action CancelPipeline) {
			WindowTitle = Title;
			ProgressBarColor = BarColor;
			cancelPipeline = CancelPipeline;
			System.Threading.ManualResetEvent ready = new System.Threading.ManualResetEvent(false);
			Exception startupError = null;
			System.Threading.Thread uiThread = new System.Threading.Thread(new System.Threading.ThreadStart(delegate {
				try {
					InitializeComponent();
					this.Shown += delegate { ready.Set(); };
					this.FormClosed += delegate {
						#if !noVisualStyles
						timer.Stop();
						timer.Dispose();
						#endif
						Application.ExitThread();
					};
				} catch (Exception exception) {
					startupError = exception;
					ready.Set();
					return;
				}
				Application.Run(this);
			}));
			uiThread.IsBackground = true;
			uiThread.SetApartmentState(System.Threading.ApartmentState.STA);
		uiThread.Start();
		ready.WaitOne();
		if (startupError != null) { throw startupError; }
		}

		protected override void OnPaintBackground(PaintEventArgs e) {
			e.Graphics.Clear(WindowBackColor);
			System.Drawing.Rectangle headerBounds = new System.Drawing.Rectangle(0, 0, ClientSize.Width, ProgressHeaderHeight);
			using (System.Drawing.Drawing2D.LinearGradientBrush header = new System.Drawing.Drawing2D.LinearGradientBrush(headerBounds, HeaderStartColor, HeaderEndColor, 0f)) {
				System.Drawing.Drawing2D.ColorBlend blend = new System.Drawing.Drawing2D.ColorBlend();
				blend.Colors = new[] { HeaderStartColor, HeaderMiddleColor, HeaderEndColor };
				blend.Positions = new[] { 0f, 0.55f, 1f };
				header.InterpolationColors = blend;
				e.Graphics.FillRectangle(header, headerBounds);
			}
			int footerTop = ClientSize.Height - ProgressFooterHeight;
			System.Drawing.Rectangle footerBounds = new System.Drawing.Rectangle(0, footerTop, ClientSize.Width, ProgressFooterHeight);
			using (SolidBrush footer = new SolidBrush(FieldBackColor))
				e.Graphics.FillRectangle(footer, footerBounds);
			using (Pen separator = new Pen(BorderLineColor))
				e.Graphics.DrawLine(separator, 0, footerTop, ClientSize.Width, footerTop);
		}

		private void InitializeComponent() {
			this.SuspendLayout();

			this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
			this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
			this.Font = SystemFonts.MessageBoxFont;

			this.AutoScroll = true;
			this.Text = WindowTitle;
			this.Height = ProgressFormHeight;
			this.Width = ProgressFormWidth;
			this.BackColor = WindowBackColor;
			this.ForeColor = LabelTextColor;
			this.FormBorderStyle = FormBorderStyle.FixedSingle;
			this.MinimizeBox = false;
			this.MaximizeBox = false;
			this.ControlBox = false;
			this.ShowInTaskbar = false;
			this.DoubleBuffered = true;
			this.StartPosition = FormStartPosition.CenterScreen;
			Button cancelButton = new Button();
			cancelButton.Text = SystemDialogText.GetButtonLabel(1, "Cancel");
			cancelButton.Size = new System.Drawing.Size(73, 23);
			cancelButton.Location = new Point(ClientSize.Width - 24 - cancelButton.Width,
				ClientSize.Height - ProgressFooterHeight + (ProgressFooterHeight - cancelButton.Height) / 2);
			cancelButton.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
			cancelButton.FlatStyle = FlatStyle.Flat;
			cancelButton.FlatAppearance.BorderSize = 1;
			cancelButton.FlatAppearance.BorderColor = CancelButtonBorderColor;
			cancelButton.BackColor = CancelButtonBackColor;
			cancelButton.ForeColor = LabelTextColor;
			cancelButton.UseVisualStyleBackColor = false;
			cancelButton.Click += delegate {
				cancelButton.Enabled = false;
				cancelPipeline();
			};
			this.Controls.Add(cancelButton);
			this.ResumeLayout();
			#if !noVisualStyles
			timer.Tick += TimeTick;
			timer.Interval = 50; // 毫秒
			timer.Start();
			#endif
		}

		private Color DrawingColor(ConsoleColor color) { // 把 ConsoleColor 转换为 System.Drawing.Color
			switch (color) {
			case ConsoleColor.DarkYellow:
				return ColorTranslator.FromOle(35723);//#8B8B00
			default:
				return Color.FromName(color.ToString());
			}
		}

		#if !noVisualStyles
		private void TimeTick(object source, EventArgs eventargs) {
			if (_barNumber >= 0) {
				if (_barValue >= 0) {
					progressDataList[_barNumber].objProgressBar.Value = _barValue;
					_barValue = -1;
				}
				progressDataList[_barNumber].objProgressBar.Refresh();
			}
		}
		#endif

		private Label MakeProgressLabel(int left, int top, int width) {
			Label label = new Label();
			label.Left = left;
			label.Top = top;
			label.Width = width;
			label.Height = 16;
			label.BackColor = Color.Transparent;
			label.ForeColor = LabelTextColor;
			return label;
		}

		private int ActivityTop(int position) {
			return position == 0 ? 8 : ProgressHeaderHeight + ProgressRowHeight * position + 10;
		}

		private int StatusTop(int position) {
			return position == 0 ? ProgressHeaderHeight + 10 : ProgressHeaderHeight + ProgressRowHeight * position + 26;
		}

		private int ProgressBarTop(int position) {
			return position == 0 ? ProgressHeaderHeight + 54 : ProgressHeaderHeight + ProgressRowHeight * position + 47;
		}

		private int RemainingTimeTop(int position) {
			return position == 0 ? ProgressHeaderHeight + 76 : ProgressHeaderHeight + ProgressRowHeight * position + 72;
		}

		private int OperationTop(int position) {
			return position == 0 ? ProgressHeaderHeight + 92 : ProgressHeaderHeight + ProgressRowHeight * position + 88;
		}

		private void LayoutProgressRows() {
			int desiredHeight = ProgressFormHeight + System.Math.Max(0, progressDataList.Count - 1) * ProgressRowHeight;
			System.Windows.Forms.Screen screen = System.Windows.Forms.Screen.FromControl(this);
			this.Width = ProgressFormWidth;
			this.Height = System.Math.Min(desiredHeight, screen.Bounds.Height);
			this.Location = new Point((screen.Bounds.Width - this.Width) / 2, (screen.Bounds.Height - this.Height) / 2);
			for (int position = 0; position < progressDataList.Count; position++) {
				Progress_Data progress = progressDataList[position];
				progress.lbActivity.Top = ActivityTop(position);
				progress.lbStatus.Top = StatusTop(position);
				progress.objProgressBar.Top = ProgressBarTop(position);
				progress.lbRemainingTime.Top = RemainingTimeTop(position);
				progress.lbOperation.Top = OperationTop(position);
			}
		}

		private void AddBar(ref Progress_Data pd, int position) {
			// 创建标签
			pd.lbActivity = MakeProgressLabel(19, ActivityTop(position), ProgressFormWidth - 29);
			if (position == 0) {
				pd.lbActivity.Font = new Font(SystemFonts.MessageBoxFont.FontFamily, 12f, FontStyle.Regular);
				pd.lbActivity.Height = 28;
				pd.lbActivity.ForeColor = HeaderTextColor;
			} else {
				pd.lbActivity.Font = new Font(pd.lbActivity.Font, FontStyle.Bold);
			}
			pd.lbActivity.Text = "";
			// 把标签添加到窗体
			this.Controls.Add(pd.lbActivity);

			// 创建标签
			pd.lbStatus = MakeProgressLabel(20, StatusTop(position), ProgressFormWidth - 45);
			pd.lbStatus.Text = "";
			// 把标签添加到窗体
			this.Controls.Add(pd.lbStatus);

			// 创建进度条（自绘，几何对齐原生 msctls_progress32 的细条高度 15）
			pd.objProgressBar = new FlatProgressBar();
			pd.objProgressBar.Value = 0;
			pd.objProgressBar.BarColor = DrawingColor(ProgressBarColor);
			pd.objProgressBar.BackColorOverride = WindowBackColor;
			pd.objProgressBar.TrackColor = ProgressTrackColor;
			pd.objProgressBar.BorderColor = BorderLineColor;
			int indent = System.Math.Min(pd.Depth, 8) * 30;
			pd.objProgressBar.Size = new System.Drawing.Size(ProgressFormWidth - 49 - indent, 15);
			pd.objProgressBar.Left = 21 + indent;
			pd.objProgressBar.Top = ProgressBarTop(position);
			// 把进度条添加到窗体
			this.Controls.Add(pd.objProgressBar);

			// 创建标签
			pd.lbRemainingTime = MakeProgressLabel(5, RemainingTimeTop(position), ProgressFormWidth - 20);
			pd.lbRemainingTime.Text = "";
			pd.lbRemainingTime.Visible = false;
			// 把标签添加到窗体
			this.Controls.Add(pd.lbRemainingTime);

			// 创建标签
			pd.lbOperation = MakeProgressLabel(25, OperationTop(position), ProgressFormWidth - 50);
			pd.lbOperation.Text = "";
			pd.lbOperation.Visible = false;
			// 把标签添加到窗体
			this.Controls.Add(pd.lbOperation);
		}

		public int GetCount() {
			return progressCount;
		}

		public void CloseAfterCancel() {
			if (IsDisposed || Disposing) return;
			try {
				if (InvokeRequired) BeginInvoke((Action)Close);
				else Close();
			} catch (ObjectDisposedException) { }
			catch (InvalidOperationException) { }
		}

		public void Update(ProgressRecord objRecord) {
			if (objRecord == null || IsDisposed || Disposing) return;
			if (InvokeRequired) {
				try { Invoke((Action)delegate { UpdateProgress(objRecord); }); }
				catch (ObjectDisposedException) { }
				catch (InvalidOperationException) { }
				return;
			}
			UpdateProgress(objRecord);
		}

		private void UpdateProgress(ProgressRecord objRecord) {

			int currentProgress = -1;
			for (int i = 0; i < progressDataList.Count; i++) {
				if (progressDataList[i].ActivityId == objRecord.ActivityId) {
					currentProgress = i;
					break;
				}
			}

			if (objRecord.RecordType == ProgressRecordType.Completed) {
				if (currentProgress >= 0) {
					#if !noVisualStyles
					if (_barNumber == currentProgress) _barNumber = -1;
					#endif
					this.Controls.Remove(progressDataList[currentProgress].lbActivity);
					this.Controls.Remove(progressDataList[currentProgress].lbStatus);
					this.Controls.Remove(progressDataList[currentProgress].objProgressBar);
					this.Controls.Remove(progressDataList[currentProgress].lbRemainingTime);
					this.Controls.Remove(progressDataList[currentProgress].lbOperation);

					progressDataList[currentProgress].lbActivity.Dispose();
					progressDataList[currentProgress].lbStatus.Dispose();
					progressDataList[currentProgress].objProgressBar.Dispose();
					progressDataList[currentProgress].lbRemainingTime.Dispose();
					progressDataList[currentProgress].lbOperation.Dispose();

					progressDataList.RemoveAt(currentProgress);
					progressCount = progressDataList.Count;
				}

				if (progressDataList.Count == 0) {
					this.Close();
					return;
				}

				if (currentProgress < 0) return;
				LayoutProgressRows();
				return;
			}

			if (currentProgress < 0) {
				Progress_Data pd = new Progress_Data();
				pd.ActivityId = objRecord.ActivityId;
				pd.ParentActivityId = objRecord.ParentActivityId;
				pd.Depth = 0;

				int nextid = -1;
				int parentid = -1;
				if (pd.ParentActivityId >= 0) {
					for (int i = 0; i < progressDataList.Count; i++) {
						if (progressDataList[i].ActivityId == pd.ParentActivityId) {
							parentid = i;
							break;
						}
					}
				}

				if (parentid >= 0) {
					pd.Depth = progressDataList[parentid].Depth + 1;

					for (int i = parentid + 1; i < progressDataList.Count; i++) {
						if ((progressDataList[i].Depth < pd.Depth) || ((progressDataList[i].Depth == pd.Depth) && (progressDataList[i].ParentActivityId != pd.ParentActivityId))) {
							nextid = i;
							break;
						}
					}
				}

				if (nextid == -1) {
					AddBar(ref pd, progressDataList.Count);
					currentProgress = progressDataList.Count;
					progressDataList.Add(pd);
				} else {
					AddBar(ref pd, nextid);
					currentProgress = nextid;
					progressDataList.Insert(nextid, pd);
				}
				progressCount = progressDataList.Count;
				LayoutProgressRows();
			}

			if (!string.IsNullOrEmpty(objRecord.Activity))
				progressDataList[currentProgress].lbActivity.Text = objRecord.Activity;
			else
				progressDataList[currentProgress].lbActivity.Text = "";

			if (!string.IsNullOrEmpty(objRecord.StatusDescription)) {
				progressDataList[currentProgress].lbStatus.Text = objRecord.PercentComplete >= 0 && objRecord.PercentComplete <= 100
					? string.Format("{0} ({1}%)", objRecord.StatusDescription, objRecord.PercentComplete)
					: objRecord.StatusDescription;
			} else {
				progressDataList[currentProgress].lbStatus.Text = "";
			}

			if ((objRecord.PercentComplete >= 0) && (objRecord.PercentComplete <= 100)) {
				#if !noVisualStyles
				if (objRecord.PercentComplete < 100)
					progressDataList[currentProgress].objProgressBar.Value = objRecord.PercentComplete + 1;
				else
					progressDataList[currentProgress].objProgressBar.Value = 99;
				progressDataList[currentProgress].objProgressBar.Visible = true;
				_barNumber = currentProgress;
				_barValue = objRecord.PercentComplete;
				#else
				progressDataList[currentProgress].objProgressBar.Value = objRecord.PercentComplete;
				progressDataList[currentProgress].objProgressBar.Visible = true;
				#endif
			} else {
				if (objRecord.PercentComplete > 100) {
					progressDataList[currentProgress].objProgressBar.Value = 0;
					progressDataList[currentProgress].objProgressBar.Visible = true;
					#if !noVisualStyles
					_barNumber = currentProgress;
					_barValue = 0;
					#endif
				} else {
					progressDataList[currentProgress].objProgressBar.Visible = false;
					#if !noVisualStyles
					if (_barNumber == currentProgress) _barNumber = -1;
					#endif
				}
			}

			if (objRecord.SecondsRemaining >= 0) {
				System.TimeSpan objTimeSpan = new System.TimeSpan(0, 0, objRecord.SecondsRemaining);
				progressDataList[currentProgress].lbRemainingTime.Text = string.Format("Remaining time: {0:00}:{1:00}:{2:00}", (int) objTimeSpan.TotalHours, objTimeSpan.Minutes, objTimeSpan.Seconds);
			} else
				progressDataList[currentProgress].lbRemainingTime.Text = "";
			progressDataList[currentProgress].lbRemainingTime.Visible = !string.IsNullOrEmpty(progressDataList[currentProgress].lbRemainingTime.Text);

			if (!string.IsNullOrEmpty(objRecord.CurrentOperation))
				progressDataList[currentProgress].lbOperation.Text = objRecord.CurrentOperation;
			else
				progressDataList[currentProgress].lbOperation.Text = "";
			progressDataList[currentProgress].lbOperation.Visible = !string.IsNullOrEmpty(progressDataList[currentProgress].lbOperation.Text);
			LayoutProgressRows();
		}
	}
	#endif

	// 在这里定义 IsInputRedirected()、IsOutputRedirected() 和 IsErrorRedirected()，因为它们最早是在 .NET 4.5 中引入的
	public class Console_Info {
		private enum FileType: uint {
			FILE_TYPE_UNKNOWN = 0x0000,
			FILE_TYPE_DISK = 0x0001,
			FILE_TYPE_CHAR = 0x0002,
			FILE_TYPE_PIPE = 0x0003,
			FILE_TYPE_REMOTE = 0x8000
		}

		private enum STDHandle: uint {
			STD_INPUT_HANDLE = unchecked((uint) - 10),
			STD_OUTPUT_HANDLE = unchecked((uint) - 11),
			STD_ERROR_HANDLE = unchecked((uint) - 12)
		}
		private enum ConsoleMode: uint {
			ENABLE_ECHO_INPUT = 0x0004,
			ENABLE_INSERT_MODE = 0x0020,
			ENABLE_LINE_INPUT = 0x0002,
			ENABLE_MOUSE_INPUT = 0x0010,
			ENABLE_PROCESSED_INPUT = 0x0001,
			ENABLE_QUICK_EDIT_MODE = 0x0040,
			ENABLE_WINDOW_INPUT = 0x0008,
			ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200,

			ENABLE_PROCESSED_OUTPUT = 0x0001,
			ENABLE_WRAP_AT_EOL_OUTPUT = 0x0002,
			ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004,
			DISABLE_NEWLINE_AUTO_RETURN = 0x0008,
			ENABLE_LVB_GRID_WORLDWIDE = 0x0010
		}

		[DllImport("Kernel32.dll")]
		static private extern UIntPtr GetStdHandle(STDHandle stdHandle);

		[DllImport("Kernel32.dll")]
		static private extern FileType GetFileType(UIntPtr hFile);
		[DllImport("Kernel32.dll")]
		static private extern bool GetConsoleMode(UIntPtr hConsoleHandle, out ConsoleMode lpConsoleMode);
		[DllImport("Kernel32.dll")]
		static private extern bool SetConsoleMode(UIntPtr hConsoleHandle, ConsoleMode dwMode);

		static public bool IsInputRedirected() {
			UIntPtr hInput = GetStdHandle(STDHandle.STD_INPUT_HANDLE);
			FileType fileType = GetFileType(hInput);
			return fileType != FileType.FILE_TYPE_CHAR && fileType != FileType.FILE_TYPE_UNKNOWN;
		}

		static public bool IsOutputRedirected() {
			UIntPtr hOutput = GetStdHandle(STDHandle.STD_OUTPUT_HANDLE);
			FileType fileType = GetFileType(hOutput);
			return fileType != FileType.FILE_TYPE_CHAR && fileType != FileType.FILE_TYPE_UNKNOWN;
		}

		static public bool IsErrorRedirected() {
			UIntPtr hError = GetStdHandle(STDHandle.STD_ERROR_HANDLE);
			FileType fileType = GetFileType(hError);
			return fileType != FileType.FILE_TYPE_CHAR && fileType != FileType.FILE_TYPE_UNKNOWN;
		}
		static public bool IsVirtualTerminalSupported() {
			UIntPtr hOutput = GetStdHandle(STDHandle.STD_OUTPUT_HANDLE);
			ConsoleMode consoleMode;
			if(!GetConsoleMode(hOutput, out consoleMode))
				return false;
			return (consoleMode & ConsoleMode.ENABLE_VIRTUAL_TERMINAL_PROCESSING) != 0;
		}
	}

	#if noConsole
	// 消息框在亮/暗主题下都使用同一套 WinForms 控件与布局，仅切换调色板。
	internal static class MessageBoxHelper {
		[DllImport("dwmapi.dll")]
		static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

		internal static bool UsesNativeMessageBox {
			get {
				#if darkModeOff
				return true;
				#else
				return false;
				#endif
			}
		}

		static bool IsDark {
			get {
				#if !darkModeOff && !Pwsh20
				return DarkMode.IsDark;
				#else
				return false;
				#endif
			}
		}
		static Color WindowColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (IsDark) { return DarkMode.WindowColor; }
				#endif
				return Color.White;
			}
		}
		static Color FieldColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (IsDark) { return DarkMode.FieldColor; }
				#endif
				return Color.FromArgb(240, 240, 240);
			}
		}
		static Color BorderColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (IsDark) { return DarkMode.BorderColor; }
				#endif
				return Color.FromArgb(173, 173, 173);
			}
		}
		static Color TextColor {
			get {
				#if !darkModeOff && !Pwsh20
				if (IsDark) { return DarkMode.TextColor; }
				#endif
				return SystemColors.ControlText;
			}
		}

		static void ApplyTitleBar(IntPtr hwnd) {
			#if !darkModeOff && !Pwsh20
			DarkMode.DarkTitleBar(hwnd);
			#else
			int light = 0;
			DwmSetWindowAttribute(hwnd, 20, ref light, sizeof(int));
			DwmSetWindowAttribute(hwnd, 19, ref light, sizeof(int));
			#endif
		}

		public static void Show(string text, string caption) {
			Show(text, caption, MessageBoxButtons.OK, MessageBoxIcon.None);
		}

		public static DialogResult Show(string text, string caption, MessageBoxButtons buttons, MessageBoxIcon icon) {
			return Show(text, caption, buttons, icon, MessageBoxDefaultButton.Button1);
		}

		// 与原生 MessageBox 一致的按钮文案（MB_GetString 序号：0=OK 1=Cancel 2=Abort 3=Retry 4=Ignore 5=Yes 6=No）。
		static string[] ButtonLabels(MessageBoxButtons kind) {
			switch (kind) {
				case MessageBoxButtons.OKCancel: return new[] { SystemDialogText.GetButtonLabel(0, "OK"), SystemDialogText.GetButtonLabel(1, "Cancel") };
				case MessageBoxButtons.YesNo: return new[] { SystemDialogText.GetButtonLabel(5, "Yes"), SystemDialogText.GetButtonLabel(6, "No") };
				case MessageBoxButtons.YesNoCancel: return new[] { SystemDialogText.GetButtonLabel(5, "Yes"), SystemDialogText.GetButtonLabel(6, "No"), SystemDialogText.GetButtonLabel(1, "Cancel") };
				case MessageBoxButtons.RetryCancel: return new[] { SystemDialogText.GetButtonLabel(3, "Retry"), SystemDialogText.GetButtonLabel(1, "Cancel") };
				case MessageBoxButtons.AbortRetryIgnore: return new[] { SystemDialogText.GetButtonLabel(2, "Abort"), SystemDialogText.GetButtonLabel(3, "Retry"), SystemDialogText.GetButtonLabel(4, "Ignore") };
				default: return new[] { SystemDialogText.GetButtonLabel(0, "OK") };
			}
		}

		static DialogResult[] ButtonResults(MessageBoxButtons kind) {
			switch (kind) {
				case MessageBoxButtons.OKCancel: return new[] { DialogResult.OK, DialogResult.Cancel };
				case MessageBoxButtons.YesNo: return new[] { DialogResult.Yes, DialogResult.No };
				case MessageBoxButtons.YesNoCancel: return new[] { DialogResult.Yes, DialogResult.No, DialogResult.Cancel };
				case MessageBoxButtons.RetryCancel: return new[] { DialogResult.Retry, DialogResult.Cancel };
				case MessageBoxButtons.AbortRetryIgnore: return new[] { DialogResult.Abort, DialogResult.Retry, DialogResult.Ignore };
				default: return new[] { DialogResult.OK };
			}
		}

		// 96 DPI 逻辑几何（由 125% 原生截图反推）：消息区上下内边距 27、文本左边距 14、图标左边距 25/尺寸 32、
		// 图标到文本 8、右边距 22、底部按钮面板 47、按钮最小 80x28、按钮间距 8、按钮距右 20。
		const int MsgVPad = 27;
		const int MsgIconLeft = 25;
		const int MsgIconSize = 32;
		const int MsgButtonGap = 8;
		const int MsgButtonRightPad = 20;

		internal static DialogResult Show(string text, string caption, MessageBoxButtons buttons, MessageBoxIcon icon, MessageBoxDefaultButton defaultButton) {
			#if darkModeOff
			return MessageBox.Show(text, caption, buttons, icon, defaultButton);
			#else
			if (text == null) { text = ""; }
			using (Form form = new Form()) {
				form.Text = caption;
				form.FormBorderStyle = FormBorderStyle.FixedDialog;
				form.StartPosition = FormStartPosition.CenterScreen;
				form.MinimizeBox = false;
				form.MaximizeBox = false;
				form.ShowIcon = true;
				form.ShowInTaskbar = false;
				form.AutoScaleMode = AutoScaleMode.None;
				form.Font = SystemFonts.MessageBoxFont;
				form.KeyPreview = true;
				form.BackColor = WindowColor;
				form.ForeColor = TextColor;

				float scale;
				using (Graphics graphics = form.CreateGraphics()) { scale = graphics.DpiX / 96f; }
				System.Func<int, int> Scale = delegate(int value) { return (int)System.Math.Round(value * scale); };

				bool hasIcon = icon != MessageBoxIcon.None;
				int textMax = Scale(hasIcon ? 346 : 397); // 原生窗口宽度上限约 445 逻辑像素
				System.Drawing.Size wrapped = TextRenderer.MeasureText(text, form.Font, new System.Drawing.Size(textMax, int.MaxValue),
					TextFormatFlags.WordBreak | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);
				int maxTextHeight = Screen.FromPoint(Cursor.Position).WorkingArea.Height - Scale(220);
				Control content;
				int contentWidth, contentHeight;
				if (wrapped.Height > maxTextHeight && maxTextHeight > Scale(40)) {
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
					content = box;
					contentWidth = textMax;
					contentHeight = maxTextHeight;
				} else {
					Label label = new Label();
					label.AutoSize = true;
					label.MaximumSize = new System.Drawing.Size(textMax, 0);
					label.Text = text;
					label.BackColor = WindowColor;
					label.ForeColor = TextColor;
					label.UseMnemonic = false;
					content = label;
					contentWidth = wrapped.Width;
					contentHeight = wrapped.Height;
				}

				PictureBox iconBox = null;
				if (hasIcon) {
					iconBox = new PictureBox();
					iconBox.SizeMode = PictureBoxSizeMode.StretchImage;
					iconBox.Size = new System.Drawing.Size(Scale(MsgIconSize), Scale(MsgIconSize));
					iconBox.Image = new Icon(MessageBoxIconImage(icon), Scale(MsgIconSize), Scale(MsgIconSize)).ToBitmap();
					iconBox.BackColor = WindowColor;
				}

				string[] labels = ButtonLabels(buttons);
				DialogResult[] results = ButtonResults(buttons);
				Button[] buttonList = new Button[labels.Length];
				int active = System.Math.Max(0, (int)defaultButton - 1);
				if (active >= buttonList.Length) { active = 0; }
				for (int buttonIndex = 0; buttonIndex < labels.Length; buttonIndex++) {
					Button button = new Button();
					button.Text = labels[buttonIndex];
					button.DialogResult = results[buttonIndex];
					button.AutoSize = true;
					button.AutoSizeMode = AutoSizeMode.GrowAndShrink;
					button.MinimumSize = new System.Drawing.Size(Scale(80), Scale(28));
					button.FlatStyle = FlatStyle.Flat;
					button.FlatAppearance.BorderSize = 1;
					button.FlatAppearance.BorderColor = BorderColor;
					button.BackColor = FieldColor;
					button.ForeColor = TextColor;
					button.UseVisualStyleBackColor = false;
					button.TabIndex = buttonIndex == active ? 0 : buttonIndex + 1;
					buttonList[buttonIndex] = button;
				}
				int buttonRowWidth = 0;
				for (int buttonIndex = 0; buttonIndex < buttonList.Length; buttonIndex++) { buttonRowWidth += buttonList[buttonIndex].Width + Scale(MsgButtonGap); }
				if (buttonList.Length > 0) { buttonRowWidth -= Scale(MsgButtonGap); }

				int iconHeight = iconBox != null ? Scale(MsgIconSize) : 0;
				int blockHeight = System.Math.Max(contentHeight, iconHeight);
				int messageTop = Scale(MsgVPad);
				int textTop = messageTop + (iconHeight > contentHeight ? (iconHeight - contentHeight) / 2 : 0);
				int panelTop = messageTop + blockHeight + Scale(MsgVPad);
				int textLeft = iconBox != null ? Scale(MsgIconLeft) + iconHeight + Scale(8) : Scale(14);
				int clientWidth = System.Math.Max(textLeft + contentWidth, Scale(MsgButtonRightPad) + buttonRowWidth) + Scale(22);
				int clientHeight = panelTop + Scale(47);

				if (iconBox != null) { iconBox.Location = new Point(Scale(MsgIconLeft), messageTop); }
				content.Location = new Point(textLeft, textTop);
				content.Size = new System.Drawing.Size(contentWidth, contentHeight);

				Panel panel = new Panel();
				panel.BackColor = FieldColor;
				Label separator = new Label();
				separator.BackColor = BorderColor;
				separator.Bounds = new System.Drawing.Rectangle(0, 0, clientWidth, System.Math.Max(1, Scale(1)));
				panel.Controls.Add(separator);
				panel.Location = new Point(0, panelTop);
				panel.Size = new System.Drawing.Size(clientWidth, clientHeight - panelTop);

				form.ClientSize = new System.Drawing.Size(clientWidth, clientHeight);
				if (iconBox != null) { form.Controls.Add(iconBox); }
				form.Controls.Add(content);
				form.Controls.Add(panel);

				int separatorHeight = System.Math.Max(1, Scale(1));
				int buttonX = clientWidth - Scale(MsgButtonRightPad) - buttonRowWidth;
				for (int buttonIndex = 0; buttonIndex < buttonList.Length; buttonIndex++) {
					int buttonY = separatorHeight + (panel.Height - separatorHeight - buttonList[buttonIndex].Height) / 2;
					buttonList[buttonIndex].Location = new Point(buttonX, buttonY);
					buttonX += buttonList[buttonIndex].Width + Scale(MsgButtonGap);
					panel.Controls.Add(buttonList[buttonIndex]);
				}

				form.AcceptButton = buttonList[active];
				form.ActiveControl = buttonList[active];

				form.HandleCreated += delegate {
					ApplyTitleBar(form.Handle);
				};

				return form.ShowDialog();
			}
			#endif
		}

		static Icon MessageBoxIconImage(MessageBoxIcon icon) {
			switch (icon) {
				case MessageBoxIcon.Error: return SystemIcons.Error;
				case MessageBoxIcon.Warning: return SystemIcons.Warning;
				case MessageBoxIcon.Information: return SystemIcons.Information;
				case MessageBoxIcon.Question: return SystemIcons.Question;
				default: return SystemIcons.Application;
			}
		}
	}
	#endif

	internal class PSRunnerUI: PSHostUserInterface {
		public PSRunnerRawUI rawUI;

		public ConsoleColor ErrorForegroundColor = ConsoleColor.Red;
		public ConsoleColor ErrorBackgroundColor = ConsoleColor.Black;

		public ConsoleColor WarningForegroundColor = ConsoleColor.Yellow;
		public ConsoleColor WarningBackgroundColor = ConsoleColor.Black;

		public ConsoleColor DebugForegroundColor = ConsoleColor.Yellow;
		public ConsoleColor DebugBackgroundColor = ConsoleColor.Black;

		public ConsoleColor VerboseForegroundColor = ConsoleColor.Yellow;
		public ConsoleColor VerboseBackgroundColor = ConsoleColor.Black;

		public ConsoleColor ProgressForegroundColor =
		#if !noConsole
			ConsoleColor.Yellow
		#else
			ConsoleColor.Green
		#endif
		;
		public ConsoleColor ProgressBackgroundColor = ConsoleColor.DarkCyan;

		public PSRunnerUI() {
			rawUI = new PSRunnerRawUI();
			#if !noConsole
				rawUI.ForegroundColor = Console.ForegroundColor;
				rawUI.BackgroundColor = Console.BackgroundColor;
			#endif
		}

		#if !Pwsh20
			public override bool SupportsVirtualTerminal { get { return Console_Info.IsVirtualTerminalSupported(); } }
		#endif

		public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions) {
			#if !noConsole
				if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
				if (!string.IsNullOrEmpty(message)) WriteLine(message);
			#else
				if ((!string.IsNullOrEmpty(caption)) || (!string.IsNullOrEmpty(message))) {
					string sTitle = rawUI.WindowTitle, sMeldung = "";

					if (!string.IsNullOrEmpty(caption)) sTitle = caption;
					if (!string.IsNullOrEmpty(message)) sMeldung = message;
					MessageBoxHelper.Show(sMeldung, sTitle);
				}

				// 重置 Input_Box 的标签文本
				_ib_message = "";
			#endif
			Dictionary<string, PSObject> ret = new Dictionary<string, PSObject> ();
			foreach(FieldDescription cd in descriptions) {
				Type type;
				if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))
					type = typeof(string);
				else
					type = Type.GetType(cd.ParameterAssemblyFullName);

				if (type.IsArray) {
					Type elementType = type.GetElementType();
					Type genericListType = Type.GetType("System.Collections.Generic.List\x60\x31");
					genericListType = genericListType.MakeGenericType(new [] {
						elementType
					});
					ConstructorInfo constructor = genericListType.GetConstructor(BindingFlags.CreateInstance | BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null);
					object resultList = constructor.Invoke(null);

					int index = 0;
					string data;
					do {
						if (!string.IsNullOrEmpty(cd.Name))
							#if !noConsole
								Write(string.Format("{0}[{1}]: ", cd.Name, index));
							#else
								_ib_message = string.Format("{0}[{1}]: ", cd.Name, index);
							#endif
						data = ReadLine();
						if (string.IsNullOrEmpty(data))
							break;
						object obj = System.Convert.ChangeType(data, elementType);
						genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new [] {
							obj
						});
						index++;
					} while (true);

					System.Array retArray = (System.Array) genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);
					ret.Add(cd.Name, new PSObject(retArray));
				} else {
					object obj=null;
					string line;
					if (type != typeof(System.Security.SecureString)) {
						if (type != typeof(System.Management.Automation.PSCredential)) {
							#if !noConsole
							if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);
							if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");
							if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");
							#else
							if (!string.IsNullOrEmpty(cd.Name)) _ib_message = FormatInputPrompt(cd.Name);
							if (!string.IsNullOrEmpty(cd.HelpMessage)) _ib_message += "\n(Type !? for help.)";
							#endif
							do {
								line = ReadLine();
								if (line == "!?")
									WriteLine(cd.HelpMessage);
								else {
									if (string.IsNullOrEmpty(line)) obj = cd.DefaultValue;
									if (obj == null) {
										try {
											obj = System.Convert.ChangeType(line, type);
										} catch {
											Write("Wrong format, please repeat input: ");
											line = "!?";
										}
									}
								}
							} while (line == "!?");
						} else
							obj = PromptForCredential("", "", "", "");
					} else {
						if (!string.IsNullOrEmpty(cd.Name))
							#if !noConsole
								Write(string.Format("{0}: ", cd.Name));
							#else
								_ib_message = FormatInputPrompt(cd.Name);
							#endif

						obj = ReadLineAsSecureString();
					}

					ret.Add(cd.Name, new PSObject(obj));
				}
			}
			#if noConsole
			// 重置 Input_Box 的标签文本
			_ib_message = "";
			#endif
			return ret;
		}

		public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice) {
			#if noConsole
			if (string.IsNullOrEmpty(caption)) caption = rawUI.WindowTitle;
			int iReturn = Choice_Box.Show(choices, defaultChoice, caption, message);
			if (iReturn == -1)
				iReturn = defaultChoice;
			return iReturn;
			#else
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			WriteLine(message);
			do {
				int idx = 0;
				SortedList<string, int> res = new SortedList<string, int> ();
				string defkey = "";
				foreach(ChoiceDescription cd in choices) {
					string lkey = cd.Label.Substring(0, 1), ltext = cd.Label;
					int pos = cd.Label.IndexOf('&');
					if (pos > -1) {
						lkey = cd.Label.Substring(pos + 1, 1).ToUpper();
						if (pos > 0)
							ltext = cd.Label.Substring(0, pos) + cd.Label.Substring(pos + 1);
						else
							ltext = cd.Label.Substring(1);
					}
					res.Add(lkey.ToLower(), idx);

					if (idx > 0) Write("  ");
					ConsoleColor fg = rawUI.ForegroundColor, bg = rawUI.BackgroundColor;
					if (idx == defaultChoice) {
						fg = VerboseForegroundColor;
						defkey = lkey;
					}
					Write(fg, bg, string.Format("[{0}] {1}", lkey, ltext));
					idx++;
				}
				Write(rawUI.ForegroundColor, rawUI.BackgroundColor, string.Format("  [?] Help (default is \"{0}\"): ", defkey));

				string inpkey = "";
				try {
					inpkey = Console.ReadLine().ToLower();
					if (res.ContainsKey(inpkey)) return res[inpkey];
					if (string.IsNullOrEmpty(inpkey)) return defaultChoice;
				} catch {/* 忽略部分读取错误 */}
				if (inpkey == "?") {
					foreach(ChoiceDescription cd in choices) {
						string lkey = cd.Label.Substring(0, 1);
						int pos = cd.Label.IndexOf('&');
						if (pos > -1) lkey = cd.Label.Substring(pos + 1, 1).ToUpper();
						if (!string.IsNullOrEmpty(cd.HelpMessage))
							WriteLine(rawUI.ForegroundColor, rawUI.BackgroundColor, string.Format("{0} - {1}", lkey, cd.HelpMessage));
						else
							WriteLine(rawUI.ForegroundColor, rawUI.BackgroundColor, string.Format("{0} -", lkey));
					}
				}
			} while (true);
			#endif
		}

		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options) {
			#if !(noConsole || credentialGUI)
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			WriteLine(message);

			string UserName;
			Write("User name: ");
			if ((string.IsNullOrEmpty(userName)) || ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0))
				UserName = ReadLine();
			else {
				if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");
				WriteLine(userName);
				UserName = userName;
			}
			Write("Password: ");
			SecureString password = ReadLineAsSecureString();

			if (string.IsNullOrEmpty(UserName)) UserName = "<NOUSER>";
			if (!string.IsNullOrEmpty(targetName))
				if (UserName.IndexOf('\\') < 0)
					UserName = targetName + "\\" + UserName;

			return new PSCredential(UserName, password);
			#else
			Credential_Form.User_Pwd cred = Credential_Form.PromptForPassword(caption, message, targetName, userName, allowedCredentialTypes, options);
			if (cred != null) {
				System.Security.SecureString x = new System.Security.SecureString();
				foreach(char c in cred.Password.ToCharArray())
					x.AppendChar(c);

				return new PSCredential(cred.User, x);
			}
			return null;
			#endif
		}

		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName) {
			#if !(noConsole || credentialGUI)
				if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
				WriteLine(message);

				string un;
				Write("User name: ");
				if (string.IsNullOrEmpty(userName))
					un = ReadLine();
				else {
					if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");
					WriteLine(userName);
					un = userName;
				}
				SecureString pwd;
				Write("Password: ");
				pwd = ReadLineAsSecureString();

				if (string.IsNullOrEmpty(un)) un = "<NOUSER>";
				if (!string.IsNullOrEmpty(targetName)) {
					if (un.IndexOf('\\') < 0)
						un = targetName + "\\" + un;
				}

				PSCredential c2 = new PSCredential(un, pwd);
				return c2;
			#else
				Credential_Form.User_Pwd cred = Credential_Form.PromptForPassword(caption, message, targetName, userName, PSCredentialTypes.Default, PSCredentialUIOptions.Default);
				if (cred != null) {
					System.Security.SecureString x = new System.Security.SecureString();
					foreach(char c in cred.Password.ToCharArray())
					x.AppendChar(c);

					return new PSCredential(cred.User, x);
				}
				return null;
			#endif
		}

		public override PSHostRawUserInterface RawUI {
			get { return rawUI; }
		}

		#if noConsole
		private string _ib_message;
		static string FormatInputPrompt(string prompt) {
			return prompt + (prompt.EndsWith(":", StringComparison.Ordinal) ? " " : ": ");
		}
		#endif

		public override string ReadLine() {
			#if !noConsole
				return Console.ReadLine();
			#else
				string sWert = "";
				if (Input_Box.Show(rawUI.WindowTitle, _ib_message, ref sWert) == DialogResult.OK)
					return sWert;
				#if exitOnCancel
					Environment.Exit(1);
				#endif
				return "";
			#endif
		}

		private System.Security.SecureString getPassword() {
			System.Security.SecureString pwd = new System.Security.SecureString();
			while (true) {
				ConsoleKeyInfo i = Console.ReadKey(true);
				if (i.Key == ConsoleKey.Enter) {
					Console.WriteLine();
					break;
				} else if (i.Key == ConsoleKey.Backspace) {
					if (pwd.Length > 0) {
						pwd.RemoveAt(pwd.Length - 1);
						Console.Write("\b \b");
					}
				} else if (i.KeyChar != '\u0000') {
					pwd.AppendChar(i.KeyChar);
					Console.Write("*");
				}
			}
			return pwd;
		}

		public override System.Security.SecureString ReadLineAsSecureString() {
			System.Security.SecureString secstr;
			#if !noConsole
				secstr = getPassword();
			#else
				secstr = new System.Security.SecureString();
				string sWert = "";

				if (Input_Box.Show(rawUI.WindowTitle, _ib_message, ref sWert, true) == DialogResult.OK) {
					foreach(char ch in sWert)
					secstr.AppendChar(ch);
				}
				#if exitOnCancel
				else
					Environment.Exit(1);
				#endif
			#endif
			return secstr;
		}

		// 由 Write-Host 调用
		public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			#if !noOutput
			#if !noConsole
				ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
				Console.ForegroundColor = foregroundColor;
				Console.BackgroundColor = backgroundColor;
				Console.Write(value);
				Console.ForegroundColor = fgc;
				Console.BackgroundColor = bgc;
			#else
				if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
					MessageBoxHelper.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		public override void Write(string value) {
			#if !noOutput
			#if !noConsole
				Console.Write(value);
			#else
				if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
					MessageBoxHelper.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		// 由 Write-Debug 调用
		public override void WriteDebugLine(string message) {
			#if !noDebug
			#if !noConsole
				WriteLineInternal(DebugForegroundColor, DebugBackgroundColor, string.Format("DEBUG: {0}", message));
			#else
				MessageBoxHelper.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Information);
			#endif
			#endif
		}

		// 由 Write-Error 调用
		public override void WriteErrorLine(string value) {
			#if !noError
			#if !noConsole
				if (Console_Info.IsErrorRedirected())
					Console.Error.WriteLine(string.Format("ERROR: {0}", value));
				else
					WriteLineInternal(ErrorForegroundColor, ErrorBackgroundColor, string.Format("ERROR: {0}", value));
			#else
				MessageBoxHelper.Show(value, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
			#endif
			#endif
		}

		internal void WriteErrorRecord(ErrorRecord errorItem) {
			// 特殊处理原生stderr导致的异常
			var remoteException = errorItem.Exception as System.Management.Automation.RemoteException;
			if (remoteException != null && remoteException.SerializedRemoteException == null)
				Console.Error.WriteLine(errorItem.Exception.Message);
			else
				WriteErrorLine(errorItem.ToString());
		}

		public override void WriteLine() {
			#if !noOutput
			#if !noConsole
				Console.WriteLine();
			#else
				MessageBoxHelper.Show("", rawUI.WindowTitle);
			#endif
			#endif
		}

		public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			#if !noOutput
			#if !noConsole
				// 上色本身可能因宿主控制台状态异常而抛错（比如句柄暂时无效）；上色失败也不能让这行内容干脆不出现。
				try {
					ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
					Console.ForegroundColor = foregroundColor;
					Console.BackgroundColor = backgroundColor;
					Console.WriteLine(value);
					Console.ForegroundColor = fgc;
					Console.BackgroundColor = bgc;
				}
				catch {
					Console.WriteLine(value);
				}
			#else
				if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
					MessageBoxHelper.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		#if !noConsole
		private void WriteLineInternal(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			// 同上：ERROR/WARNING/DEBUG 走这条路，上色失败绝不能让失败原因本身消失（issue 60）。
			try {
				ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
				Console.ForegroundColor = foregroundColor;
				Console.BackgroundColor = backgroundColor;
				Console.WriteLine(value);
				Console.ForegroundColor = fgc;
				Console.BackgroundColor = bgc;
			}
			catch {
				Console.WriteLine(value);
			}
		}
		#endif

		// 由 Write-Output 调用
		public override void WriteLine(string value) {
			#if !noOutput
			#if !noConsole
				Console.WriteLine(value);
			#else
				if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
					MessageBoxHelper.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		#if noConsole
		public Progress_Form pf;
		public Action CancelPipeline;
		#endif
		public override void WriteProgress(long sourceId, ProgressRecord record) {
			#if noConsole
			if (pf == null) {
				if (record.RecordType == ProgressRecordType.Completed) return;
				pf = new Progress_Form(rawUI.WindowTitle, ProgressForegroundColor, CancelPipeline);
			}
			pf.Update(record);
			if (record.RecordType == ProgressRecordType.Completed) {
				if (pf.GetCount() == 0) pf = null;
			}
			#else
			if (!Console_Info.IsOutputRedirected()) {// 标准输出被重定向时不写进度条。
				// 用于开启进度指示器的 OSC 序列
				// https://github.com/microsoft/terminal/issues/6700
				if(Console_Info.IsVirtualTerminalSupported()){
					if (record.RecordType == ProgressRecordType.Completed)//结束进度指示器
						Console.Write("\x1b]9;4;0\x1b\\");
					else {
						int percentComplete = record.PercentComplete;
						// Write-Progress 允许负数完成百分比，但不得大于 100，而 OSC 序列限制在 0 到 100。
						if (percentComplete < 0)
							percentComplete = 0;
						Console.Write(string.Format("\x1b]9;4;1;{0}\x1b\\", percentComplete));
					}
				}
			}
			#endif
		}

		// 由 Write-Verbose 调用
		public override void WriteVerboseLine(string message) {
			#if !noVerbose
			#if !noConsole
			WriteLineInternal(VerboseForegroundColor, VerboseBackgroundColor, string.Format("VERBOSE: {0}", message));
			#else
			MessageBoxHelper.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Information);
			#endif
			#endif
		}

		// 由 Write-Warning 调用
		public override void WriteWarningLine(string message) {
			#if !noWarning
				#if !noConsole
					WriteLineInternal(WarningForegroundColor, WarningBackgroundColor, string.Format("WARNING: {0}", message));
				#else
					MessageBoxHelper.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
				#endif
			#endif
		}
	}

	internal class PSRunnerHost: PSHost {
		private readonly PSRunnerInterface parent;
		private readonly PSRunnerUI _ui;

		private readonly CultureInfo originalCultureInfo = System.Threading.Thread.CurrentThread.CurrentCulture;

		private readonly CultureInfo originalUICultureInfo = System.Threading.Thread.CurrentThread.CurrentUICulture;

		private Guid _myId = Guid.NewGuid();

		public PSRunnerHost(PSRunnerInterface app, PSRunnerUI ui) {
			this.parent = app;
			this._ui = ui;
		}

		public class ConsoleColorProxy {
			private readonly PSRunnerUI _ui;

			public ConsoleColorProxy(PSRunnerUI ui) {
				if (ui == null) throw new ArgumentNullException("ui");
				_ui = ui;
			}

			public ConsoleColor ErrorForegroundColor {
				get { return _ui.ErrorForegroundColor; }
				set { _ui.ErrorForegroundColor = value; }
			}

			public ConsoleColor ErrorBackgroundColor {
				get { return _ui.ErrorBackgroundColor; }
				set { _ui.ErrorBackgroundColor = value; }
			}

			public ConsoleColor WarningForegroundColor {
				get { return _ui.WarningForegroundColor; }
				set { _ui.WarningForegroundColor = value; }
			}

			public ConsoleColor WarningBackgroundColor {
				get { return _ui.WarningBackgroundColor; }
				set { _ui.WarningBackgroundColor = value; }
			}

			public ConsoleColor DebugForegroundColor {
				get { return _ui.DebugForegroundColor; }
				set { _ui.DebugForegroundColor = value; }
			}

			public ConsoleColor DebugBackgroundColor {
				get { return _ui.DebugBackgroundColor; }
				set { _ui.DebugBackgroundColor = value; }
			}

			public ConsoleColor VerboseForegroundColor {
				get { return _ui.VerboseForegroundColor; }
				set { _ui.VerboseForegroundColor = value; }
			}

			public ConsoleColor VerboseBackgroundColor {
				get { return _ui.VerboseBackgroundColor; }
				set { _ui.VerboseBackgroundColor = value; }
			}

			public ConsoleColor ProgressForegroundColor {
				get { return _ui.ProgressForegroundColor; }
				set { _ui.ProgressForegroundColor = value; }
			}

			public ConsoleColor ProgressBackgroundColor {
				get { return _ui.ProgressBackgroundColor; }
				set { _ui.ProgressBackgroundColor = value; }
			}
		}

		public override PSObject PrivateData {
			get {
				if (_ui == null) return null;
				return _consoleColorProxy ?? (_consoleColorProxy = PSObject.AsPSObject(new ConsoleColorProxy(_ui)));
			}
		}

		private PSObject _consoleColorProxy;

		public override System.Globalization.CultureInfo CurrentCulture {
			get { return this.originalCultureInfo; }
		}

		public override System.Globalization.CultureInfo CurrentUICulture {
			get { return this.originalUICultureInfo; }
		}

		public override Guid InstanceId {
			get { return this._myId; }
		}

		public override string Name {
			get { return "PSEXE"; }
		}

		public override PSHostUserInterface UI {
			get { return _ui; }
		}

		public override Version Version {
			get { return new Version(0, 0, 0, 0); }
		}

		public override void EnterNestedPrompt() {}

		public override void ExitNestedPrompt() {}

		public override void NotifyBeginApplication() {}

		public override void NotifyEndApplication() {}

		public override void SetShouldExit(int exitCode) {
			this.parent.ShouldExit = true;
			this.parent.ExitCode = exitCode;
		}
	}

	internal interface PSRunnerInterface {
		bool ShouldExit {get;set;}
		int ExitCode {get;set;}
	}

	internal class PSRunner: PSRunnerInterface {
		// 启动计时。需要计时时用 ps12exe -StartupTiming 编译，计时输出走 stderr。
		#if StartupTiming
		internal static System.Diagnostics.Stopwatch TimerSw = System.Diagnostics.Stopwatch.StartNew();
		#endif
		[System.Diagnostics.Conditional("StartupTiming")]
		internal static void TimerMark(string s) {
			#if StartupTiming
				System.Console.Error.WriteLine("[timing] " + s + ": " + TimerSw.Elapsed.TotalMilliseconds.ToString("F1") + " ms");
			#endif
		}

		private bool shouldExit;
		public volatile bool CancelRequested;

		private int exitCode;

		public bool ShouldExit {
			get { return this.shouldExit; }
			set { this.shouldExit = value; }
		}

		public int ExitCode {
			get { return this.exitCode; }
			set { this.exitCode = value; }
		}

		public PSRunnerUI ui;
		public PSRunnerHost host;
		public Runspace PSRunSpace;
		public PowerShell pwsh;

		public PSRunner() {
			TimerMark("ctor:enter");
			this.shouldExit = false;
			this.exitCode = 0;
			this.ui = new PSRunnerUI();
			TimerMark("ctor:ui");
			this.host = new PSRunnerHost(this, ui);
			#if Pwsh20
				this.PSRunSpace = RunspaceFactory.CreateRunspace(host);
			#else
				// 完整默认 ISS（含 Utility/Management 等内置管理单元）：自身创建稍慢，但首个 cmdlet 调用不必再走模块自动发现。CreateDefault2 的轻量 ISS 会把这份开销推迟到第一管道命令，对 hello world 实测反而慢约 70ms（见 tools/Benchmark）。
				InitialSessionState iss = InitialSessionState.CreateDefault();
				this.PSRunSpace = RunspaceFactory.CreateRunspace(host, iss);
			#endif
			TimerMark("ctor:runspace-create");
			this.PSRunSpace.ApartmentState = System.Threading.ApartmentState.$threadingModel;
			this.PSRunSpace.Open();
			TimerMark("ctor:runspace-open");
			this.pwsh = PowerShell.Create();
			this.pwsh.Runspace = PSRunSpace;
			TimerMark("ctor:pwsh-create");
			#if CoreHost
				string exepath = System.Environment.ProcessPath;
			#else
				// DLL 导出模式下 GetEntryAssembly 可能为 null（native 宿主），回退到当前程序集。
				Assembly entryAssembly = Assembly.GetEntryAssembly();
				string exepath = (entryAssembly != null && !string.IsNullOrEmpty(entryAssembly.Location))
					? entryAssembly.Location
					: Assembly.GetExecutingAssembly().Location;
			#endif
			Assembly executingAssembly = Assembly.GetExecutingAssembly();
			string script;
			// 脚本以 main.ps1 资源内嵌在负载程序集里；负载本身在打包时会被整体压缩。
			using (Stream scriptstream = executingAssembly.GetManifestResourceStream("main.ps1")) {
				using (var scriptreader = new StreamReader(scriptstream, Encoding.UTF8)) {
					script = scriptreader.ReadToEnd();
					this.PSRunSpace.SessionStateProxy.SetVariable("PSEXEscript", script);
				}
			}
			TimerMark("ctor:read-script");
			#if noConsole && !darkModeOff && !Pwsh20
			// 把暗色 hook 的初始化交给脚本线程执行（在用户脚本之前），保证 hook 窗口与脚本创建的窗口同线程。
			this.PSRunSpace.SessionStateProxy.SetVariable("PSEXEDarkModeSetup", (Action)DarkMode.StartOnCurrentThread);
			#endif
			script = "function PSEXEMainFunction{"+script+"}";
			#if Pwsh20
				this.pwsh.AddScript(script);
			#else
			{
				Token[] tokens;
				ParseError[] errors;
				ScriptBlockAst AST = Parser.ParseInput(script, exepath, out tokens, out errors);
				TimerMark("ctor:parse");
				this.PSRunSpace.SessionStateProxy.SetVariable("PSEXEIniter", AST.GetScriptBlock());
				TimerMark("ctor:getscriptblock");
				if(errors.Length > 0)
					throw new System.InvalidProgramException(errors[0].Message);
				this.pwsh.AddScript(".$PSEXEIniter");
			}
			#endif
			TimerMark("ctor:done");
		}
		public void Dispose() {
			if (pwsh != null) pwsh.Dispose();
			if (PSRunSpace != null) {
				PSRunSpace.Close();
				PSRunSpace.Dispose();
			}
			host = null;
			ui = null;

			GC.SuppressFinalize(this);
		}
		//基础初始化
		public static void BaseInit() {
			#if UNICODEEncoding && !noConsole
			System.Console.OutputEncoding = new System.Text.UnicodeEncoding();
			#endif
			#if UTF8Encoding && !noConsole
			System.Console.OutputEncoding = new System.Text.UTF8Encoding();
			#endif

			#if culture
			System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.GetCultureInfo("$lcid");
			System.Threading.Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.GetCultureInfo("$lcid");
			#endif

			#if !noVisualStyles && noConsole
			Application.EnableVisualStyles();
			#endif

			#if noConsole && !darkModeOff && !Pwsh20
			DarkMode.Init();
			#endif

			FixModulePath();
		}

		// 把自己的模块目录前置；这里做同样的事，保证轻量 ISS 下命令仍能正确自动加载（issue 61）。
		static void FixModulePath() {
			try {
				string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
				string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
				string systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
				string[] preferred = new string[] {
					string.IsNullOrEmpty(docs) ? null : Path.Combine(Path.Combine(docs, "WindowsPowerShell"), "Modules"),
					string.IsNullOrEmpty(programFiles) ? null : Path.Combine(Path.Combine(programFiles, "WindowsPowerShell"), "Modules"),
					string.IsNullOrEmpty(systemRoot) ? null : Path.Combine(Path.Combine(systemRoot, Path.Combine("System32", Path.Combine("WindowsPowerShell", Path.Combine("v1.0", "Modules"))))),
				};
				List<string> parts = new List<string>();
				foreach (string path in preferred) {
					if (!string.IsNullOrEmpty(path) && !parts.Contains(path)) parts.Add(path);
				}
				string existing = Environment.GetEnvironmentVariable("PSModulePath");
				if (!string.IsNullOrEmpty(existing)) {
					foreach (string path in existing.Split(';')) {
						if (!string.IsNullOrEmpty(path) && !parts.Contains(path)) parts.Add(path);
					}
				}
				Environment.SetEnvironmentVariable("PSModulePath", string.Join(";", parts.ToArray()));
			} catch {
				// 模块路径修正失败不应影响启动
			}
		}
	}

	#if noConsole && !darkModeOff && !Pwsh20
	// App.DarkMode：windowed 产物的 WinForms 暗色适配。默认 Auto 跟随系统，On/Off 强制（Off 时整段不编译）。
	// 进程级用 uxtheme 未公开序号开启暗色；.NET 9+ / Win11 走官方 Application.SetColorMode，
	// 其余运行时用 shell hook 在本进程窗口首次绘制前挂 subclass，把 WinForms 控件逐个染暗并给标题栏挂 DWM 暗色属性。
	public static class DarkMode {
		delegate int SetPreferredAppModeDel(int mode);
		delegate void FlushMenuThemesDel();
		delegate bool AllowDarkModeForWindowDel(IntPtr hwnd, bool allow);
		delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr param);

		[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
		static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
		[DllImport("dwmapi.dll")]
		static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
		[DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
		static extern IntPtr GetModuleHandle(string name);
		[DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
		static extern IntPtr GetProcAddress(IntPtr hModule, IntPtr procName);
		[DllImport("user32.dll")]
		static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);
		[DllImport("user32.dll")]
		static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
		[DllImport("user32.dll")]
		static extern bool RegisterShellHookWindow(IntPtr hwnd);
		[DllImport("user32.dll", CharSet = CharSet.Unicode)]
		static extern uint RegisterWindowMessage(string lpString);
		[DllImport("comctl32.dll", SetLastError = true)]
		static extern bool SetWindowSubclass(IntPtr hWnd, SubclassProc pfnSubclass, UIntPtr uIdSubclass, IntPtr dwRefData);
		[DllImport("comctl32.dll")]
		static extern bool RemoveWindowSubclass(IntPtr hWnd, SubclassProc pfnSubclass, UIntPtr uIdSubclass);
		[DllImport("comctl32.dll")]
		static extern IntPtr DefSubclassProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

		delegate IntPtr SubclassProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam, UIntPtr uSubclassId, IntPtr dwRefData);
		const int HSHELL_WINDOWCREATED = 1;
		const uint WM_PAINT = 0x000F;
		const uint WM_ERASEBKGND = 0x0014;
		const uint WM_SETTINGCHANGE = 0x001A;
		static SubclassProc subclassProc;
		static uint shellHookMessage;
		static NativeWindow shellHookWindow;
		static bool manualTheming;

		// Auto 模式下监听系统主题变化（WM_SETTINGCHANGE + "ImmersiveColorSet"）：消息窗口建在 UI 线程上，收到通知即重新探测并让所有窗口跟随。
		static NativeWindow themeChangeWindow;
		static SetPreferredAppModeDel setPreferredAppMode;
		static FlushMenuThemesDel flushMenuThemes;
		static AllowDarkModeForWindowDel allowDarkModeForWindow;
		static System.Threading.Timer pollTimer;

		public static readonly Color WindowColor = Color.FromArgb(32, 32, 32);
		public static readonly Color FieldColor = Color.FromArgb(45, 45, 45);
		public static readonly Color BorderColor = Color.FromArgb(64, 64, 64);
		public static readonly Color TextColor = Color.FromArgb(245, 245, 245);
		public static readonly Color DisabledTextColor = Color.FromArgb(130, 130, 130);

		public static bool IsDark { get; private set; }

		static readonly object initLock = new object();
		sealed class ControlOriginalColors {
			public Color BackColor;
			public Color ForeColor;
			public FlatStyle RadioButtonFlatStyle;
			public bool RadioButtonUseVisualStyleBackColor;
			public bool AppliedDark; // 最近一次应用到的深浅状态，避免轮询重复染色
			public bool HasApplied;
		}
		// 记录控件被改动前的原始颜色，以便系统由深转浅时精确还原。
		static readonly System.Runtime.CompilerServices.ConditionalWeakTable<Control, ControlOriginalColors> themed = new System.Runtime.CompilerServices.ConditionalWeakTable<Control, ControlOriginalColors>();
		static bool started;

		public static void Init() {
			lock (initLock) {
				if (started) { return; }
				started = true;
				#if darkModeOn
				IsDark = true; // 编译期强制暗色，不做探测
				#else
				IsDark = SystemPrefersDark(); // Auto：跟随系统
				#endif
				EnableProcessDarkMode();
				if (!IsDark) { return; }
				// .NET 9+ 且 Win11：官方 SetColorMode 会接管控件与标题栏，无需逐控件处理。
				if (ApplyNativeColorMode()) { return; }
				EnsureManualPipeline();
			}
		}

		// 手动染色管线（旧运行时）：安装深色 ToolStrip 渲染器与窗口发现轮询。幂等。
		static void EnsureManualPipeline() {
			if (manualTheming) { return; }
			manualTheming = true;
			try { ToolStripManager.Renderer = new DarkToolStripRenderer(); } catch { }
			if (pollTimer == null) {
				pollTimer = new System.Threading.Timer(delegate { DiscoverWindows(); }, null, 2000, 2000);
			}
		}

		// Auto 模式：切换深浅。On 编译期强制暗色、不做运行时切换。
		public static void ApplySystemDark(bool dark) {
			lock (initLock) {
				if (IsDark == dark) { return; }
				IsDark = dark;
				EnableProcessDarkMode();
				// .NET 9+ 且 Win11：官方 SetColorMode 会重绘所有窗口。
				if (ApplyNativeColorMode()) { return; }
				// 手动路径：确保管线就绪，再重新遍历本进程窗口，按新值重绘（深色时染色、浅色时还原原始颜色）。
				if (IsDark) { EnsureManualPipeline(); }
				RefreshOpenForms();
			}
		}

		static void RefreshOpenForms() {
			try {
				EnumWindows(delegate(IntPtr hwnd, IntPtr param) {
					uint processId;
					GetWindowThreadProcessId(hwnd, out processId);
					if (processId != (uint)System.Diagnostics.Process.GetCurrentProcess().Id) { return true; }
					try {
						Form form = Control.FromHandle(hwnd) as Form;
						if (form != null && !form.IsDisposed) {
							form.BeginInvoke((Action)delegate { ThemeForm(form); });
						}
					} catch { }
					return true;
				}, IntPtr.Zero);
			} catch { }
		}

		// 在脚本线程（会创建 WinForms 窗口的那个线程）上创建 shell hook / 主题变化监听窗口。shell hook 的建窗通知会排进该线程
		// 消息队列，于首个 WM_PAINT 之前被处理，从而同步挂 subclass、在首次绘制前完成染色，消除亮色闪帧。
		public static void StartOnCurrentThread() {
			lock (initLock) {
				if (manualTheming && shellHookWindow == null) {
					try {
						subclassProc = ThemeOnFirstPaint;
						shellHookMessage = RegisterWindowMessage("SHELLHOOK");
						shellHookWindow = new ShellHookWindow();
						RegisterShellHookWindow(shellHookWindow.Handle);
					} catch { }
				}
				#if !darkModeOn
				if (themeChangeWindow == null) {
					try { themeChangeWindow = new ThemeChangeWindow(); } catch { }
				}
				#endif
			}
		}

		#if !darkModeOn
		// Auto 模式下监听 WM_SETTINGCHANGE：lParam 指向 "ImmersiveColorSet" 时说明系统深浅色变化，重新探测并让所有窗口跟随。
		// 广播消息可能带 lParam=0（系统不在进程内封送字符串），此时保守地重新探测一次。
		sealed class ThemeChangeWindow : NativeWindow {
			public ThemeChangeWindow() {
				CreateHandle(new CreateParams { Caption = "", X = 0, Y = 0, Width = 0, Height = 0, Style = 0, ExStyle = 0, ClassName = "STATIC" });
			}

			protected override void WndProc(ref Message m) {
				if (m.Msg == (int)WM_SETTINGCHANGE && IsImmersiveColorSet(m.LParam)) {
					try { ApplySystemDark(SystemPrefersDark()); } catch { }
				}
				base.WndProc(ref m);
			}

			// WM_SETTINGCHANGE 的 lParam 是进程内地址的宽字符指针；lParam=0 时无法判断具体项，按「可能变过」处理。
			static bool IsImmersiveColorSet(IntPtr lParam) {
				if (lParam == IntPtr.Zero) { return true; }
				try {
					string value = Marshal.PtrToStringUni(lParam);
					return string.IsNullOrEmpty(value) || value.IndexOf("ImmersiveColorSet", StringComparison.OrdinalIgnoreCase) >= 0;
				} catch { return true; }
			}
		}
		#endif

		// 只用于接收 SHELLHOOK 消息的隐藏原生窗口。
		sealed class ShellHookWindow : NativeWindow {
			public ShellHookWindow() {
				CreateHandle(new CreateParams { Caption = "", X = 0, Y = 0, Width = 0, Height = 0, Style = 0, ExStyle = 0, ClassName = "STATIC" });
			}
			protected override void WndProc(ref Message m) {
				if (shellHookMessage != 0 && m.Msg == (int)shellHookMessage && m.WParam.ToInt32() == HSHELL_WINDOWCREATED) {
					try {
						uint processId;
						GetWindowThreadProcessId(m.LParam, out processId);
						if (processId == (uint)System.Diagnostics.Process.GetCurrentProcess().Id) {
							SetWindowSubclass(m.LParam, subclassProc, (UIntPtr)1, IntPtr.Zero);
						}
					} catch { }
				}
				base.WndProc(ref m);
			}
		}

		static IntPtr ThemeOnFirstPaint(IntPtr hwnd, uint uMsg, IntPtr wParam, IntPtr lParam, UIntPtr uIdSubclass, IntPtr dwRefData) {
			if (uMsg == WM_PAINT || uMsg == WM_ERASEBKGND) {
				try {
					Control control = Control.FromHandle(hwnd);
					Form form = control as Form;
					if (form != null) { ThemeForm(form); }
					else if (control != null) { ThemeControl(control); }
				} catch { }
				try { RemoveWindowSubclass(hwnd, subclassProc, uIdSubclass); } catch { }
			}
			return DefSubclassProc(hwnd, uMsg, wParam, lParam);
		}

		static void ThemeWhenControlReady(IntPtr hwnd) {
			try {
				Form form = Control.FromHandle(hwnd) as Form;
				if (form == null) { return; }
				form.BeginInvoke((Action)delegate { ThemeWhenReady(form); });
			} catch { }
		}

		#if !darkModeOn
		static bool SystemPrefersDark() {
			try {
				object value = Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1);
				return value != null && Convert.ToInt32(value) == 0;
			} catch { return false; }
		}
		#endif

		static void EnableProcessDarkMode() {
			// uxtheme 未公开序号（见 ysc3839/win32-darkmode）：132=ShouldAppsUseDarkMode，133=AllowDarkModeForWindow，
			// 135=SetPreferredAppMode(build>=18362)/AllowDarkModeForApp(<18362)，136=FlushMenuThemes，104=RefreshImmersiveColorPolicyState。
			IntPtr uxtheme = GetModuleHandle("uxtheme.dll");
			if (uxtheme != IntPtr.Zero) {
				setPreferredAppMode = Bind<SetPreferredAppModeDel>(uxtheme, 135);
				flushMenuThemes = Bind<FlushMenuThemesDel>(uxtheme, 136);
				allowDarkModeForWindow = Bind<AllowDarkModeForWindowDel>(uxtheme, 133);
			}
			// 1=AllowDark 3=ForceLight
			if (setPreferredAppMode != null) setPreferredAppMode(IsDark ? 1 : 3);
			if (flushMenuThemes != null) flushMenuThemes();
		}

		static T Bind<T>(IntPtr module, int ordinal) where T : class {
			IntPtr proc = GetProcAddress(module, (IntPtr)ordinal);
			return proc == IntPtr.Zero ? null : (T)(object)Marshal.GetDelegateForFunctionPointer(proc, typeof(T));
		}

		static bool ApplyNativeColorMode() {
			try {
				if (Environment.OSVersion.Version.Build < 22000) { return false; } // 暗色仅 Win11 支持
				MethodInfo method = typeof(Application).GetMethod("SetColorMode", BindingFlags.Public | BindingFlags.Static);
				if (method == null) { return false; }
				ParameterInfo[] parameters = method.GetParameters();
				if (parameters.Length != 1 || !parameters[0].ParameterType.IsEnum) { return false; }
				object value = Enum.Parse(parameters[0].ParameterType, IsDark ? "Dark" : "Classic");
				method.Invoke(null, new object[] { value });
				return true;
			} catch { return false; }
		}

		// 轮询本进程顶层窗口；WinForms 的 Application.OpenForms 按线程隔离，跨线程拿不到，故用 EnumWindows + Control.FromHandle。
		static void DiscoverWindows() {
			try {
				uint currentProcessId = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
				EnumWindows(delegate(IntPtr hwnd, IntPtr param) {
					uint processId;
					GetWindowThreadProcessId(hwnd, out processId);
					if (processId != currentProcessId) { return true; }
					ThemeWhenControlReady(hwnd);
					return true;
				}, IntPtr.Zero);
			} catch { }
		}

		// 首次遇到控件时记录其原始颜色（只记一次）；之后每次重绘都基于原始值判断，避免把已染色的颜色误当成系统色。
		static ControlOriginalColors OriginalColorsOf(Control control) {
			ControlOriginalColors original;
			if (themed.TryGetValue(control, out original)) { return original; }
			original = new ControlOriginalColors();
			original.BackColor = control.BackColor;
			original.ForeColor = control.ForeColor;
			RadioButton radioButton = control as RadioButton;
			if (radioButton != null) {
				original.RadioButtonFlatStyle = radioButton.FlatStyle;
				original.RadioButtonUseVisualStyleBackColor = radioButton.UseVisualStyleBackColor;
			}
			try { themed.Add(control, original); } catch { }
			return original;
		}

		static void ThemeForm(Form form) {
			if (form == null || form.IsDisposed) { return; }
			try {
				// 关键：改窗体 BackColor 会传播给「仍用系统色」的子控件（WinForms 行为），若先改窗体再记录子控件原始色，
				// 记录到的就是被污染的值，浅色还原会失效。故先遍历整棵树记录原始色，再统一应用。
				CaptureOriginalColors(form);
				// 先改颜色再动 DWM/主题：设置标题栏会触发重绘，若晚于颜色设置，首帧仍是亮色。
				form.BackColor = IsDark ? WindowColor : OriginalColorsOf(form).BackColor;
				form.ForeColor = IsDark ? TextColor : OriginalColorsOf(form).ForeColor;
				DarkTitleBar(form.Handle);
				form.ControlAdded -= OnControlAdded;
				form.ControlAdded += OnControlAdded;
				ThemeChildren(form);
				ControlOriginalColors original = OriginalColorsOf(form);
				original.AppliedDark = IsDark;
				original.HasApplied = true;
			} catch { }
		}

		static void CaptureOriginalColors(Control parent) {
			OriginalColorsOf(parent);
			foreach (Control child in parent.Controls) { CaptureOriginalColors(child); }
		}

		// 轮询/首帧路径：只在深浅状态或控件尚未染色时才真正重绘。
		static void ThemeWhenReady(Form form) {
			if (form == null || form.IsDisposed) { return; }
			try {
				ControlOriginalColors original = OriginalColorsOf(form);
				if (original.HasApplied && original.AppliedDark == IsDark) { return; }
			} catch { }
			ThemeForm(form);
		}

		static void OnControlAdded(object sender, ControlEventArgs e) {
			ThemeControl(e.Control);
		}

		static void ThemeChildren(Control parent) {
			foreach (Control child in parent.Controls) {
				ThemeControl(child);
				ThemeChildren(child);
			}
		}

		static void ThemeControl(Control control) {
			if (control == null || control.IsDisposed) { return; }
			try {
				ApplyControlColors(control);
				control.ControlAdded -= OnControlAdded;
				control.ControlAdded += OnControlAdded;
			} catch { }
		}

		// 只改「仍是系统色」的控件：脚本自定义的颜色在深色下保留原色，浅色时精确还原原始值。
		static Color DarkBack(ControlOriginalColors original, Color dark) {
			if (!IsDark) { return original.BackColor; }
			return IsSystemBack(original.BackColor) ? dark : original.BackColor;
		}

		static Color DarkFore(ControlOriginalColors original) {
			if (!IsDark) { return original.ForeColor; }
			return IsSystemText(original.ForeColor) ? TextColor : original.ForeColor;
		}

		static void ApplyControlColors(Control control) {
			ControlOriginalColors original = OriginalColorsOf(control);
			RadioButton radioButton = control as RadioButton;
			if (radioButton != null) {
				radioButton.ForeColor = DarkFore(original);
				radioButton.BackColor = DarkBack(original, WindowColor);
				if (IsDark) {
					radioButton.FlatStyle = FlatStyle.Flat;
					radioButton.UseVisualStyleBackColor = false;
					SetWindowTheme(radioButton.Handle, "DarkMode_Explorer", null);
				} else {
					radioButton.FlatStyle = original.RadioButtonFlatStyle;
					radioButton.UseVisualStyleBackColor = original.RadioButtonUseVisualStyleBackColor;
					SetWindowTheme(radioButton.Handle, null, null);
				}
				return;
			}

			Button button = control as Button;
			if (button != null) {
				button.ForeColor = DarkFore(original);
				button.BackColor = DarkBack(original, FieldColor);
				if (IsDark) {
					button.FlatStyle = FlatStyle.Flat;
					button.FlatAppearance.BorderSize = 1;
					button.FlatAppearance.BorderColor = BorderColor;
					button.UseVisualStyleBackColor = false;
				} else {
					button.UseVisualStyleBackColor = original.BackColor == SystemColors.Control;
				}
				return;
			}

			if (IsFieldControl(control)) {
				control.ForeColor = DarkFore(original);
				control.BackColor = DarkBack(original, FieldColor);
				if (control is TextBoxBase) { ((TextBoxBase)control).BorderStyle = IsDark ? BorderStyle.FixedSingle : BorderStyle.Fixed3D; }
				if (control is ListBox) { ((ListBox)control).BorderStyle = IsDark ? BorderStyle.FixedSingle : BorderStyle.Fixed3D; }
				ComboBox combo = control as ComboBox;
				if (combo != null) {
					combo.FlatStyle = IsDark ? FlatStyle.Flat : FlatStyle.Standard;
					SetWindowTheme(combo.Handle, IsDark ? "DarkMode_CFD" : null, null);
				}
				return;
			}

			if (IsWindowControl(control)) {
				control.ForeColor = DarkFore(original);
				control.BackColor = DarkBack(original, WindowColor);
				return;
			}

			if (control is Label || control is LinkLabel) {
				control.ForeColor = DarkFore(original);
				control.BackColor = original.BackColor == Color.Transparent ? Color.Transparent : (IsDark ? (control.Parent != null ? control.Parent.BackColor : WindowColor) : original.BackColor);
				return;
			}

			control.ForeColor = DarkFore(original);
			control.BackColor = DarkBack(original, WindowColor);
		}

		static bool IsFieldControl(Control control) {
			TextBoxBase text = control as TextBoxBase;
			if (text != null) {
				text.BorderStyle = BorderStyle.FixedSingle;
				SetWindowTheme(text.Handle, IsDark ? "DarkMode_CFD" : null, null);
				if (IsSystemBack(text.BackColor)) { text.BackColor = FieldColor; }
				return true;
			}
			ListBox list = control as ListBox;
			if (list != null) {
				list.BorderStyle = BorderStyle.FixedSingle;
				if (IsSystemBack(list.BackColor)) { list.BackColor = FieldColor; }
				return true;
			}
			if (control is NumericUpDown || control is DomainUpDown) {
				if (IsSystemBack(control.BackColor)) { control.BackColor = FieldColor; }
				return true;
			}
			ComboBox combo = control as ComboBox;
			if (combo != null) {
				combo.FlatStyle = FlatStyle.Flat;
				SetWindowTheme(combo.Handle, "DarkMode_CFD", null);
				if (IsSystemBack(combo.BackColor)) { combo.BackColor = FieldColor; }
				return true;
			}
			return false;
		}

		static bool IsWindowControl(Control control) {
			ListView listView = control as ListView;
			if (listView != null) { SetWindowTheme(listView.Handle, "DarkMode_Explorer", null); return true; }
			TreeView treeView = control as TreeView;
			if (treeView != null) { SetWindowTheme(treeView.Handle, "DarkMode_Explorer", null); return true; }
			DataGridView grid = control as DataGridView;
			if (grid != null) {
				grid.BackgroundColor = WindowColor;
				grid.GridColor = BorderColor;
				grid.EnableHeadersVisualStyles = false;
				grid.DefaultCellStyle.BackColor = WindowColor;
				grid.DefaultCellStyle.ForeColor = TextColor;
				grid.DefaultCellStyle.SelectionBackColor = FieldColor;
				grid.DefaultCellStyle.SelectionForeColor = TextColor;
				grid.ColumnHeadersDefaultCellStyle.BackColor = FieldColor;
				grid.ColumnHeadersDefaultCellStyle.ForeColor = TextColor;
				grid.RowHeadersDefaultCellStyle.BackColor = FieldColor;
				grid.RowHeadersDefaultCellStyle.ForeColor = TextColor;
				return true;
			}
			return false;
		}

		static bool IsSystemBack(Color color) {
			return color == SystemColors.Control || color == SystemColors.Window || color == Color.Transparent;
		}

		static bool IsSystemText(Color color) {
			return color == SystemColors.ControlText || color == SystemColors.WindowText;
		}

		public static void DarkTitleBar(IntPtr hwnd) {
			if (allowDarkModeForWindow != null) { allowDarkModeForWindow(hwnd, IsDark); }
			SetWindowTheme(hwnd, IsDark ? "DarkMode_Explorer" : null, null);
			int on = IsDark ? 1 : 0;
			DwmSetWindowAttribute(hwnd, 20, ref on, sizeof(int)); // DWMWA_USE_IMMERSIVE_DARK_MODE
			DwmSetWindowAttribute(hwnd, 19, ref on, sizeof(int)); // 旧 build
		}

		sealed class DarkColorTable : ProfessionalColorTable {
			public override Color ToolStripGradientBegin { get { return WindowColor; } }
			public override Color ToolStripGradientMiddle { get { return WindowColor; } }
			public override Color ToolStripGradientEnd { get { return WindowColor; } }
			public override Color ToolStripBorder { get { return BorderColor; } }
			public override Color ToolStripDropDownBackground { get { return FieldColor; } }
			public override Color ImageMarginGradientBegin { get { return FieldColor; } }
			public override Color ImageMarginGradientMiddle { get { return FieldColor; } }
			public override Color ImageMarginGradientEnd { get { return FieldColor; } }
			public override Color MenuBorder { get { return BorderColor; } }
			public override Color MenuItemBorder { get { return BorderColor; } }
			public override Color MenuItemSelected { get { return FieldColor; } }
			public override Color MenuItemSelectedGradientBegin { get { return FieldColor; } }
			public override Color MenuItemSelectedGradientEnd { get { return FieldColor; } }
			public override Color MenuItemPressedGradientBegin { get { return FieldColor; } }
			public override Color MenuItemPressedGradientEnd { get { return FieldColor; } }
			public override Color SeparatorDark { get { return BorderColor; } }
			public override Color SeparatorLight { get { return BorderColor; } }
			public override Color ButtonSelectedHighlight { get { return FieldColor; } }
			public override Color ButtonPressedHighlight { get { return FieldColor; } }
			public override Color CheckBackground { get { return FieldColor; } }
			public override Color CheckSelectedBackground { get { return FieldColor; } }
			public override Color StatusStripGradientBegin { get { return WindowColor; } }
			public override Color StatusStripGradientEnd { get { return WindowColor; } }
			public override Color RaftingContainerGradientBegin { get { return WindowColor; } }
			public override Color RaftingContainerGradientEnd { get { return WindowColor; } }
			public override Color OverflowButtonGradientBegin { get { return WindowColor; } }
			public override Color OverflowButtonGradientMiddle { get { return WindowColor; } }
			public override Color OverflowButtonGradientEnd { get { return WindowColor; } }
		}

		sealed class DarkToolStripRenderer : ToolStripProfessionalRenderer {
			public DarkToolStripRenderer() : base(new DarkColorTable()) { RoundedEdges = false; }
			protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
				e.TextColor = e.Item.Enabled ? TextColor : DisabledTextColor;
				base.OnRenderItemText(e);
			}
			protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e) {
				e.ArrowColor = e.Item.Enabled ? TextColor : DisabledTextColor;
				base.OnRenderArrow(e);
			}
		}
	}
	#endif

	static partial class PSRunnerEntry {
		static PSRunner runner;

		#if ScriptHasParam
		// 把命令行参数当 PowerShell 数据(PSD)解析：只接受字面量（字符串/数字/bool/null/数组/哈希表），
		// 任何表达式或命令都视为普通字符串。解析出的对象直接通过变量传入，不再作为文本进入命令行，
		// 因此参数内容不会被当作 PowerShell 脚本求值。
		// 例外：允许到安全类型的安全转换（如 [int]'5'、[hashtable]@{}、[ordered]@{}）。
		static readonly Dictionary<string, Type> PsdSafeCastTypes = new Dictionary<string, Type>(StringComparer.OrdinalIgnoreCase) {
			{ "int", typeof(int) }, { "int32", typeof(int) }, { "system.int32", typeof(int) },
			{ "long", typeof(long) }, { "int64", typeof(long) }, { "system.int64", typeof(long) },
			{ "short", typeof(short) }, { "int16", typeof(short) },
			{ "byte", typeof(byte) }, { "sbyte", typeof(sbyte) },
			{ "uint", typeof(uint) }, { "uint32", typeof(uint) },
			{ "ulong", typeof(ulong) }, { "uint64", typeof(ulong) }, { "ushort", typeof(ushort) },
			{ "single", typeof(float) }, { "float", typeof(float) },
			{ "double", typeof(double) }, { "system.double", typeof(double) },
			{ "decimal", typeof(decimal) },
			{ "string", typeof(string) }, { "system.string", typeof(string) }, { "char", typeof(char) },
			{ "bool", typeof(bool) }, { "boolean", typeof(bool) },
			{ "hashtable", typeof(System.Collections.Hashtable) }, { "system.collections.hashtable", typeof(System.Collections.Hashtable) },
			{ "array", typeof(object[]) }, { "object[]", typeof(object[]) }
		};
		static bool TryParsePsdValue(ExpressionAst expression, out object value) {
			value = null;
			if (expression is StringConstantExpressionAst) {
				value = ((StringConstantExpressionAst)expression).Value;
				return true;
			}
			if (expression is ConstantExpressionAst) {
				value = ((ConstantExpressionAst)expression).Value;
				return true;
			}
			ConvertExpressionAst convert = expression as ConvertExpressionAst;
			if (convert != null) {
				if (convert.Child == null || convert.Type == null || convert.Type.TypeName == null) return false;
				string castName = convert.Type.TypeName.Name;
				if (castName == null) return false;
				// [ordered]@{}：与 PowerShell 一样保留键顺序
				if (castName.Equals("ordered", StringComparison.OrdinalIgnoreCase) ||
					castName.Equals("ordereddictionary", StringComparison.OrdinalIgnoreCase) ||
					castName.Equals("System.Collections.Specialized.OrderedDictionary", StringComparison.OrdinalIgnoreCase)) {
					HashtableAst orderedSource = convert.Child as HashtableAst;
					if (orderedSource == null) return false;
					System.Collections.Specialized.OrderedDictionary ordered = new System.Collections.Specialized.OrderedDictionary(StringComparer.OrdinalIgnoreCase);
					foreach (var pair in orderedSource.KeyValuePairs) {
						object key, item;
						string keyText;
						if (!TryParsePsdValue(pair.Item1, out key) || (keyText = key as string) == null) return false;
						if (!TryParsePsdStatement(pair.Item2, out item)) return false;
						ordered[keyText] = item;
					}
					value = ordered;
					return true;
				}
				Type castType;
				if (!PsdSafeCastTypes.TryGetValue(castName, out castType)) return false;
				object converted;
				if (!TryParsePsdValue(convert.Child, out converted)) return false;
				try {
					value = LanguagePrimitives.ConvertTo(converted, castType, CultureInfo.InvariantCulture);
					return true;
				}
				catch {
					return false;
				}
			}
			VariableExpressionAst variable = expression as VariableExpressionAst;
			if (variable != null) {
				switch (variable.VariablePath.UserPath) {
					case "true": value = true; return true;
					case "false": value = false; return true;
					case "null": return true;
				}
				return false;
			}
			UnaryExpressionAst unary = expression as UnaryExpressionAst;
			if (unary != null && unary.TokenKind == TokenKind.Minus) {
				object inner;
				if (!TryParsePsdValue(unary.Child, out inner)) return false;
				if (inner is int) { value = -(int)inner; return true; }
				if (inner is long) { value = -(long)inner; return true; }
				if (inner is double) { value = -(double)inner; return true; }
				if (inner is decimal) { value = -(decimal)inner; return true; }
				return false;
			}
			ArrayLiteralAst arrayLiteral = expression as ArrayLiteralAst;
			if (arrayLiteral != null) {
				List<object> items = new List<object>();
				foreach (ExpressionAst element in arrayLiteral.Elements) {
					object item;
					if (!TryParsePsdValue(element, out item)) return false;
					items.Add(item);
				}
				value = items.ToArray();
				return true;
			}
			ArrayExpressionAst arrayExpression = expression as ArrayExpressionAst;
			if (arrayExpression != null) {
				if (arrayExpression.SubExpression == null || arrayExpression.SubExpression.Statements.Count != 1) return false;
				return TryParsePsdStatement(arrayExpression.SubExpression.Statements[0], out value);
			}
			HashtableAst hashtable = expression as HashtableAst;
			if (hashtable != null) {
				System.Collections.Hashtable result = new System.Collections.Hashtable(StringComparer.OrdinalIgnoreCase);
				foreach (var pair in hashtable.KeyValuePairs) {
					object key, item;
					string keyText;
					if (!TryParsePsdValue(pair.Item1, out key) || (keyText = key as string) == null) return false;
					if (!TryParsePsdStatement(pair.Item2, out item)) return false;
					result[keyText] = item;
				}
				value = result;
				return true;
			}
			return false;
		}
		// 哈希表的值在 AST 里是语句（PipelineAst），取其中的表达式再按 PSD 解析
		static bool TryParsePsdStatement(StatementAst statement, out object value) {
			value = null;
			PipelineAst pipeline = statement as PipelineAst;
			if (pipeline == null || pipeline.PipelineElements.Count != 1)
				return false;
			CommandExpressionAst expression = pipeline.PipelineElements[0] as CommandExpressionAst;
			if (expression == null)
				return false;
			return TryParsePsdValue(expression.Expression, out value);
		}
		static bool TryParsePsd(string text, out object value, out bool explicitCast) {
			value = null;
			explicitCast = false;
			Token[] tokens;
			ParseError[] errors;
			ScriptBlockAst ast = Parser.ParseInput(text, out tokens, out errors);
			if (errors.Length > 0 || ast.EndBlock == null || ast.EndBlock.Statements.Count != 1)
				return false;
			PipelineAst pipeline = ast.EndBlock.Statements[0] as PipelineAst;
			if (pipeline == null || pipeline.PipelineElements.Count != 1)
				return false;
			CommandExpressionAst commandExpression = pipeline.PipelineElements[0] as CommandExpressionAst;
			if (commandExpression == null)
				return false;
			explicitCast = commandExpression.Expression is ConvertExpressionAst;
			return TryParsePsdValue(commandExpression.Expression, out value);
		}
		#endif

		// EXE 主入口
		#if conHost
		// App.ConHost：产物的 launcher 以 winexe 启动（未附加控制台），这里显式分配一个 conhost 控制台再接上标准流，
		// 从而避免挂到 Windows Terminal。若已有控制台（如未走 pack 的直编路径）则跳过，不重复分配。
		[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
		[return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
		private static extern bool AllocConsole();
		[System.Runtime.InteropServices.DllImport("kernel32.dll")]
		private static extern System.IntPtr GetConsoleWindow();
		#endif

		[$threadingModelThread]
		private static int Main(string[] args) {
			#if conHost
			if (GetConsoleWindow() == System.IntPtr.Zero) {
				AllocConsole();
				System.Console.SetIn(new System.IO.StreamReader(System.Console.OpenStandardInput()));
				System.IO.StreamWriter conOut = new System.IO.StreamWriter(System.Console.OpenStandardOutput());
				conOut.AutoFlush = true;
				System.Console.SetOut(conOut);
				System.IO.StreamWriter conErr = new System.IO.StreamWriter(System.Console.OpenStandardError());
				conErr.AutoFlush = true;
				System.Console.SetError(conErr);
			}
			#endif
			#if StartupTiming
				PSRunner.TimerSw.Restart();
			#endif
			PSRunner.TimerMark("main:enter");
			PSRunner.BaseInit();
			PSRunner.TimerMark("main:baseinit");
			runner = new PSRunner();
			PSRunner.TimerMark("main:ctor-done");
			System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);
			#if noConsole
			runner.ui.CancelPipeline = delegate {
				runner.CancelRequested = true;
				Progress_Form progressForm = runner.ui.pf;
				System.Threading.ThreadPool.QueueUserWorkItem(delegate {
					try {
						runner.pwsh.BeginStop((_) => {
							if (progressForm != null) progressForm.CloseAfterCancel();
							mre.Set();
						}, null);
					} catch {
						if (progressForm != null) progressForm.CloseAfterCancel();
						mre.Set();
					}
				});
			};
			#endif

			try {
				#if !noConsole
				Console.CancelKeyPress += (object sender, ConsoleCancelEventArgs eventargs) => {
					try {
						runner.pwsh.BeginStop((_) => {
							mre.Set();
							eventargs.Cancel = true;
						}, null);
					} catch {
						// 忽略，因为正在关闭
					}
				};
				#endif

				#if ScriptHasParam
				int psdIndex = 0;
				#endif
				for(int i = 0; i < args.Length; i++) {
					if (Regex.IsMatch(args[i], @"^(-|\$)\w*$"))
						continue;
					#if ScriptHasParam
					// 脚本有 param 块时，显式安全转换或表/数组类参数值按 PSD 数据解析成对象，再用变量传入，
					// 避免作为文本被求值；其余值仍按字符串传递，保持数字/字符串的原有绑定行为。
					object psdValue;
					bool explicitCast;
					if (TryParsePsd(args[i], out psdValue, out explicitCast) &&
						(explicitCast || psdValue is System.Collections.IDictionary || psdValue is System.Array)) {
						string psdVar = "PSEXEArg" + (psdIndex++);
						runner.pwsh.Runspace.SessionStateProxy.SetVariable(psdVar, psdValue);
						args[i] = "$" + psdVar;
						continue;
					}
					#endif
					args[i] = "\'"+args[i].Replace("'", "''")+"\'";
				}

				#if ReadInput
					// 仅当编译期检测到脚本顶层使用 $input 时（ReadInput）才读取重定向的标准输入：否则保留原始 stdin，且不在启动时等待 stdin（issue 62）。
					PSDataCollection<string> colInput = new PSDataCollection<string> ();
					if (Console_Info.IsInputRedirected()) { // 读取标准输入
						string sItem;
						while ((sItem = Console.ReadLine()) != null) { // 添加到 powershell 管道
							colInput.Add(sItem);
						}
					}
					colInput.Complete();

					runner.pwsh.Runspace.SessionStateProxy.SetVariable("PSEXEInput", colInput);
					#if noConsole && !darkModeOff && !Pwsh20
					runner.pwsh.AddScript("$PSEXEDarkModeSetup.Invoke(); $PSEXEInput|PSEXEMainFunction "+String.Join(" ", args));
					#else
					runner.pwsh.AddScript("$PSEXEInput|PSEXEMainFunction "+String.Join(" ", args));
					#endif
				#else
					// 脚本顶层不用 $input：完全不带管道输入，也不设置 $PSEXEInput
					#if noConsole && !darkModeOff && !Pwsh20
					runner.pwsh.AddScript("$PSEXEDarkModeSetup.Invoke(); PSEXEMainFunction "+String.Join(" ", args));
					#else
					runner.pwsh.AddScript("PSEXEMainFunction "+String.Join(" ", args));
					#endif
				#endif
				// Out-Default 走 host UI；勿用 Out-String/输出收集，否则 native 子进程 stdout 会变成管道（非 TTY）
				runner.pwsh.AddCommand("Out-Default");
				runner.pwsh.Streams.Error.DataAdded += (sender, eventargs) => {
					runner.ui.WriteErrorRecord(((PSDataCollection<ErrorRecord>)sender)[eventargs.Index]);
				};
				IAsyncResult asyncResult = runner.pwsh.BeginInvoke();
				PSRunner.TimerMark("main:begininvoke");

				System.Threading.WaitHandle[] waitHandles = new System.Threading.WaitHandle[] { mre, asyncResult.AsyncWaitHandle };
				while (System.Threading.WaitHandle.WaitAny(waitHandles, 10) == System.Threading.WaitHandle.WaitTimeout) {
					if (runner.ShouldExit) break;
				}

				PSRunner.TimerMark("main:pipeline-completed");
				runner.pwsh.EndInvoke(asyncResult);
				PSRunner.TimerMark("main:endinvoke");
				if (runner.pwsh.InvocationStateInfo.State != PSInvocationState.Stopped) runner.pwsh.Stop();
				PSRunner.TimerMark("main:stop");

				if (runner.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
					runner.ui.WriteErrorLine(runner.pwsh.InvocationStateInfo.Reason.Message);
			}
			catch (Exception ex) {
				#if !noError
					if (!runner.CancelRequested) runner.ui.WriteErrorLine(ex.Message);
				#endif
				runner.ExitCode = 1;
			}
			finally {
				#if noConsole
				if (runner.CancelRequested && runner.ui.pf != null) runner.ui.pf.CloseAfterCancel();
				#endif
				#if !Pwsh20 // bro wtf
					mre.Dispose();
				#endif
				runner.pwsh.Dispose();
			}

			return runner.ExitCode;
		}
	}
}
