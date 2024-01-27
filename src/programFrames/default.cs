// Simple PowerShell host created by Ingo Karstein (http://blog.karstein-consulting.com)
// Reworked and GUI support by Markus Scholtes

using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Management.Automation.Language;
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
#if DllExport
	using RGiesecke.DllExport;
#endif
using System.Runtime.Versioning;

// not displayed in details tab of properties dialog, but embedded to file
#if Resources
	[assembly: AssemblyDescription("$description")]
	[assembly: AssemblyCompany("$company")]
	[assembly: AssemblyTitle("$title")]
	[assembly: AssemblyProduct("$product")]
	[assembly: AssemblyCopyright("$copyright")]
	[assembly: AssemblyTrademark("$trademark")]
#endif
#if version
	[assembly: AssemblyVersion("$version")]
	[assembly: AssemblyFileVersion("$version")]
#endif
#if winFormsDPIAware
	[assembly: TargetFrameworkAttribute("$TargetFramework,Profile=Client")]
#endif

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
			// Flags und Variablen initialisieren
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

			// den Benutzer nach Kennwort fragen, grafischer Prompt
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
			// Speicher für Konsolenfarben bei GUI-Output werden gelesen und gesetzt, aber im Moment nicht genutzt (for future use)
			private ConsoleColor GUIBackgroundColor = ConsoleColor.White;
			private ConsoleColor GUIForegroundColor = ConsoleColor.Black;

			#if noConsole
			private string _windowTitleData;
			public PSRunnerRawUI() {
				// load assembly:AssemblyTitle
				AssemblyTitleAttribute titleAttribute = (AssemblyTitleAttribute) Attribute.GetCustomAttribute(Assembly.GetExecutingAssembly(), typeof (AssemblyTitleAttribute));
				if (titleAttribute != null)
					_windowTitleData = titleAttribute.Title;
				else
					_windowTitleData = System.AppDomain.CurrentDomain.FriendlyName;
			}
			#endif
		#else
			const int STD_OUTPUT_HANDLE = -11;

			//CHAR_INFO struct, which was a union in the old days
			// so we want to use LayoutKind.Explicit to mimic it as closely
			// as we can
			[StructLayout(LayoutKind.Explicit)]
			public struct CHAR_INFO {
				[FieldOffset(0)]
				internal char UnicodeChar;
				[FieldOffset(0)]
				internal char AsciiChar;
				[FieldOffset(2)] //2 bytes seems to work properly
				internal UInt16 Attributes;
			}

			//COORD struct
			[StructLayout(LayoutKind.Sequential)]
			public struct COORD {
				public short X;
				public short Y;
			}

			//SMALL_RECT struct
			[StructLayout(LayoutKind.Sequential)]
			public struct SMALL_RECT {
				public short Left;
				public short Top;
				public short Right;
				public short Bottom;
			}

			/* Reads character and color attribute data from a rectangular block of character cells in a console screen buffer,
				and the function writes the data to a rectangular block at a specified location in the destination buffer. */
			[DllImport("kernel32.dll", EntryPoint = "ReadConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
			internal static extern bool ReadConsoleOutput(
				IntPtr hConsoleOutput,
				/* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures
				whose size is specified by the dwBufferSize parameter.*/
				[MarshalAs(UnmanagedType.LPArray), Out] CHAR_INFO[, ] lpBuffer,
				COORD dwBufferSize,
				COORD dwBufferCoord,
				ref SMALL_RECT lpReadRegion);

			/* Writes character and color attribute data to a specified rectangular block of character cells in a console screen buffer.
				The data to be written is taken from a correspondingly sized rectangular block at a specified location in the source buffer */
			[DllImport("kernel32.dll", EntryPoint = "WriteConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
			internal static extern bool WriteConsoleOutput(
				IntPtr hConsoleOutput,
				/* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures
				whose size is specified by the dwBufferSize parameter.*/
				[MarshalAs(UnmanagedType.LPArray), In] CHAR_INFO[, ] lpBuffer,
				COORD dwBufferSize,
				COORD dwBufferCoord,
				ref SMALL_RECT lpWriteRegion);

			/* Moves a block of data in a screen buffer. The effects of the move can be limited by specifying a clipping rectangle, so
				the contents of the console screen buffer outside the clipping rectangle are unchanged. */
			[DllImport("kernel32.dll", SetLastError = true)]
			static extern bool ScrollConsoleScreenBuffer(
				IntPtr hConsoleOutput,
				[In] ref SMALL_RECT lpScrollRectangle,
				[In] ref SMALL_RECT lpClipRectangle,
				COORD dwDestinationOrigin,
				[In] ref CHAR_INFO lpFill);

			[DllImport("kernel32.dll", SetLastError = true)]
			static extern IntPtr GetStdHandle(int nStdHandle);
		#endif

		public override ConsoleColor BackgroundColor {
			#if!noConsole
				get { return Console.BackgroundColor; }
				set { Console.BackgroundColor = value; }
			#else
				get { return GUIBackgroundColor; }
				set { GUIBackgroundColor = value; }
			#endif
		}

		public override System.Management.Automation.Host.Size BufferSize {
			get {
				#if!noConsole
					if (!Console_Info.IsOutputRedirected())
						return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferHeight);
				#endif
				// return default value. If no valid value is returned WriteLine will not be called
				return new System.Management.Automation.Host.Size(120, 50);
			}
			set {
				#if!noConsole
					Console.BufferWidth = value.Width;
					Console.BufferHeight = value.Height;
				#endif
			}
		}

		public override Coordinates CursorPosition {
			get {
				return new Coordinates(
				#if!noConsole
					Console.CursorLeft, Console.CursorTop
				#else
					// Dummywert für Winforms zurückgeben.
					0, 0
				#endif
				);
			}
			set {
				#if!noConsole
					Console.CursorTop = value.Y;
					Console.CursorLeft = value.X;
				#endif
			}
		}

		public override int CursorSize {
			get {
				return
					#if!noConsole
						Console.CursorSize
					#else
						// Dummywert für Winforms zurückgeben.
						25
					#endif
				;
			}
			set {
				#if!noConsole
					Console.CursorSize = value;
				#endif
			}
		}

		#if noConsole
			private Form Invisible_Form;
		#endif

		public override void FlushInputBuffer() {
			#if!noConsole
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
			#if!noConsole
				get { return Console.ForegroundColor; }
				set { Console.ForegroundColor = value; }
			#else
				get { return GUIForegroundColor; }
				set { GUIForegroundColor = value; }
			#endif
		}

		public override BufferCell[, ] GetBufferContents(System.Management.Automation.Host.Rectangle rectangle) {
			#if!noConsole
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
					ScreenBuffer[y, x] = new System.Management.Automation.Host.BufferCell(' ', GUIForegroundColor, GUIBackgroundColor, System.Management.Automation.Host.BufferCellType.Complete);
				}

			return ScreenBuffer;
			#endif
		}

		public override bool KeyAvailable {
			get {
				return
					#if!noConsole
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
					#if!noConsole
						Console.LargestWindowWidth, Console.LargestWindowHeight
					#else
						// Dummy-Wert für Winforms
						240, 84
					#endif
				);
			}
		}

		public override System.Management.Automation.Host.Size MaxWindowSize {
			get {
				return new System.Management.Automation.Host.Size(
					#if!noConsole
						Console.BufferWidth, Console.BufferWidth
					#else
						// Dummy-Wert für Winforms
						120, 84
					#endif
				);
			}
		}

		public override KeyInfo ReadKey(ReadKeyOptions options) {
			#if!noConsole
			ConsoleKeyInfo cki = Console.ReadKey((options & ReadKeyOptions.NoEcho) != 0);

			ControlKeyStates cks = 0;
			if ((cki.Modifiers & ConsoleModifiers.Alt) != 0)
				cks |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
			if ((cki.Modifiers & ConsoleModifiers.Control) != 0)
				cks |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
			if ((cki.Modifiers & ConsoleModifiers.Shift) != 0)
				cks |= ControlKeyStates.ShiftPressed;
			if (Console.CapsLock)
				cks |= ControlKeyStates.CapsLockOn;
			if (Console.NumberLock)
				cks |= ControlKeyStates.NumLockOn;

			return new KeyInfo((int) cki.Key, cki.KeyChar, cks, (options & ReadKeyOptions.IncludeKeyDown) != 0);
			#else
			if ((options & ReadKeyOptions.IncludeKeyDown) != 0)
				return ReadKey_Box.Show("", "", true);
			else
				return ReadKey_Box.Show("", "", false);
			#endif
		}

		public override void ScrollBufferContents(System.Management.Automation.Host.Rectangle source, Coordinates destination, System.Management.Automation.Host.Rectangle clip, BufferCell fill) { // no destination block clipping implemented
			#if!noConsole
			// clip area out of source range?
			if ((source.Left > clip.Right) || (source.Right < clip.Left) || (source.Top > clip.Bottom) || (source.Bottom < clip.Top)) { // clipping out of range -> nothing to do
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
				AsciiChar = fill.Character, Attributes = (ushort)((int)(fill.ForegroundColor) + (int)(fill.BackgroundColor) * 16)
			};

			ScrollConsoleScreenBuffer(hStdOut, ref lpScrollRectangle, ref lpClipRectangle, dwDestinationOrigin, ref lpFill);
			#endif
		}

		public override void SetBufferContents(System.Management.Automation.Host.Rectangle rectangle, BufferCell fill) {
			#if!noConsole
			// using a trick: move the buffer out of the screen, the source area gets filled with the char fill.Character
			if (rectangle.Left >= 0)
				Console.MoveBufferArea(rectangle.Left, rectangle.Top, rectangle.Right - rectangle.Left + 1, rectangle.Bottom - rectangle.Top + 1, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			else { // Clear-Host: move all content off the screen
				Console.MoveBufferArea(0, 0, BufferSize.Width, BufferSize.Height, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			}
			#endif
		}

		public override void SetBufferContents(Coordinates origin, BufferCell[, ] contents) {
			#if!noConsole
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
						AsciiChar = contents[y, x].Character, Attributes = (ushort)((int)(contents[y, x].ForegroundColor) + (int)(contents[y, x].BackgroundColor) * 16)
					};
				}

			WriteConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);
			#endif
		}

		public override Coordinates WindowPosition {
			get {
				return new Coordinates(
					#if!noConsole
						Console.WindowLeft, Console.WindowTop
					#else
						// Dummy-Wert für Winforms
						0, 0
					#endif
				);
			}
			set {
				#if!noConsole
				Console.WindowLeft = value.X;
				Console.WindowTop = value.Y;
				#endif
			}
		}

		public override System.Management.Automation.Host.Size WindowSize {
			get {
				return new System.Management.Automation.Host.Size(
				#if!noConsole
					Console.WindowWidth, Console.WindowHeight
				#else
					// Dummy-Wert für Winforms
					120, 50
				#endif
				);
			}
			set {
				#if!noConsole
				Console.WindowWidth = value.Width;
				Console.WindowHeight = value.Height;
				#endif
			}
		}

		public override string WindowTitle {
			get {
				return
				#if!noConsole
				Console.Title
				#else
				_windowTitleData
				#endif
				;
			}
			set {
				#if!noConsole
				Console.Title
				#else
				_windowTitleData
				#endif
				= value;
			}
		}
	}

	#if noConsole
	public class Input_Box {
		[DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
		private static extern IntPtr MB_GetString(uint strId);

		public static DialogResult Show(string strTitle, string strPrompt, ref string strVal, bool blSecure) {
			// Generate controls
			Form form = new Form();
			form.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
			form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
			Label label = new Label();
			TextBox textBox = new TextBox();
			Button buttonOk = new Button();
			Button buttonCancel = new Button();

			// Sizes and positions are defined according to the label
			// This control has to be finished first
			if (string.IsNullOrEmpty(strPrompt)) {
				if (blSecure)
					strPrompt = "Secure input:";
				else
					strPrompt = "Input:";
			}
			label.Text = strPrompt.PadRight(16);
			label.Location = new Point(9, 19);
			label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);
			label.AutoSize = true;
			// Size of the label is defined not before Add()
			form.Controls.Add(label);

			// Generate textbox
			if (blSecure) textBox.UseSystemPasswordChar = true;
			textBox.Text = strVal;
			textBox.SetBounds(12, label.Bottom, label.Right - 12, 20);

			// Generate buttons
			// get localized "OK"-string
			string sTextOK = Marshal.PtrToStringUni(MB_GetString(0));
			if (string.IsNullOrEmpty(sTextOK))
				buttonOk.Text = "OK";
			else
				buttonOk.Text = sTextOK;

			// get localized "Cancel"-string
			string sTextCancel = Marshal.PtrToStringUni(MB_GetString(1));
			if (string.IsNullOrEmpty(sTextCancel))
				buttonCancel.Text = "Cancel";
			else
				buttonCancel.Text = sTextCancel;

			buttonOk.DialogResult = DialogResult.OK;
			buttonCancel.DialogResult = DialogResult.Cancel;
			buttonOk.SetBounds(System.Math.Max(12, label.Right - 158), label.Bottom + 36, 75, 23);
			buttonCancel.SetBounds(System.Math.Max(93, label.Right - 77), label.Bottom + 36, 75, 23);

			// Configure form
			if (string.IsNullOrEmpty(strTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = strTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 71);
			form.Controls.AddRange(new Control[] {
				textBox,
				buttonOk,
				buttonCancel
			});
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			try {
				form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
			} catch {}
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.AcceptButton = buttonOk;
			form.CancelButton = buttonCancel;

			// Show form and compute results
			DialogResult dialogResult = form.ShowDialog();
			strVal = textBox.Text;
			return dialogResult;
		}

		public static DialogResult Show(string strTitle, string strPrompt, ref string strVal) {
			return Show(strTitle, strPrompt, ref strVal, false);
		}
	}

	public class Choice_Box {
		public static int Show(System.Collections.ObjectModel.Collection<ChoiceDescription> arrChoice, int intDefault, string strTitle, string strPrompt) {
			// cancel if array is empty
			if (arrChoice == null) return -1;
			if (arrChoice.Count < 1) return -1;

			// Generate controls
			Form form = new Form();
			form.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
			form.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
			RadioButton[] aradioButton = new RadioButton[arrChoice.Count];
			ToolTip toolTip = new ToolTip();
			Button buttonOk = new Button();

			// Sizes and positions are defined according to the label
			// This control has to be finished first when a prompt is available
			int iPosY = 19, iMaxX = 0;
			if (!string.IsNullOrEmpty(strPrompt)) {
				Label label = new Label();
				label.Text = strPrompt;
				label.Location = new Point(9, 19);
				label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);
				label.AutoSize = true;
				// erst durch Add() wird die Größe des Labels ermittelt
				form.Controls.Add(label);
				iPosY = label.Bottom;
				iMaxX = label.Right;
			}

			// An den Radiobuttons orientieren sich die weiteren Größen und Positionen
			// Diese Controls also jetzt fertigstellen
			int Counter = 0;
			int tempWidth = System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18;
			foreach(ChoiceDescription sAuswahl in arrChoice) {
				aradioButton[Counter] = new RadioButton();
				string ltext = sAuswahl.Label;
				// back space (\b) handling
				while (ltext.IndexOf('\b') > -1) {
					int pos = ltext.IndexOf('\b');
					if (pos > 0)
						ltext = ltext.Substring(0, pos - 1) + ltext.Substring(pos + 1);
					else
						ltext = ltext.Substring(1);
				}
				aradioButton[Counter].Text = ltext;
				if (Counter == intDefault)
					aradioButton[Counter].Checked = true;
				aradioButton[Counter].Location = new Point(9, iPosY);
				aradioButton[Counter].AutoSize = true;
				// erst durch Add() wird die Größe des Labels ermittelt
				form.Controls.Add(aradioButton[Counter]);
				if (aradioButton[Counter].Width > tempWidth) { // radio field to wide for screen -> make two lines
					int tempHeight = aradioButton[Counter].Height;
					aradioButton[Counter].Height = tempHeight * (1 + (aradioButton[Counter].Width - 1) / tempWidth);
					aradioButton[Counter].Width = tempWidth;
					aradioButton[Counter].AutoSize = false;
				}
				iPosY = aradioButton[Counter].Bottom;
				if (aradioButton[Counter].Right > iMaxX) {
					iMaxX = aradioButton[Counter].Right;
				}
				if (!string.IsNullOrEmpty(sAuswahl.HelpMessage))
					toolTip.SetToolTip(aradioButton[Counter], sAuswahl.HelpMessage);
				Counter++;
			}

			// Tooltip auch anzeigen, wenn Parent-Fenster inaktiv ist
			toolTip.ShowAlways = true;

			// Button erzeugen
			buttonOk.Text = "OK";
			buttonOk.DialogResult = DialogResult.OK;
			buttonOk.SetBounds(System.Math.Max(12, iMaxX - 77), iPosY + 36, 75, 23);

			// configure form
			if (string.IsNullOrEmpty(strTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = strTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, iMaxX + 10), iPosY + 71);
			form.Controls.Add(buttonOk);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			try {
				form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
			} catch {}
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.AcceptButton = buttonOk;

			// show and compute form
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
		[DllImport("user32.dll")]
		public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
			[Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] System.Text.StringBuilder pwszBuff,
			int cchBuff, uint wFlags);

		static string GetCharFromKeys(Keys keys, bool blShift, bool blAltGr) {
			System.Text.StringBuilder buffer = new System.Text.StringBuilder(64);
			byte[] keyboardState = new byte[256];
			if (blShift) {
				keyboardState[(int) Keys.ShiftKey] = 0xff;
			}
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
				this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
				this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
				this.KeyDown += new KeyEventHandler(Keyboard_Form_KeyDown);
				this.KeyUp += new KeyEventHandler(Keyboard_Form_KeyUp);
			}

			// check for KeyDown or KeyUp?
			public bool checkKeyDown = true;
			// key code for pressed key
			public KeyInfo keyinfo;

			void Keyboard_Form_KeyDown(object sender, KeyEventArgs e) {
				if (checkKeyDown) { // store key info
					keyinfo.VirtualKeyCode = e.KeyValue;
					keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];
					keyinfo.KeyDown = false;
					keyinfo.ControlKeyState = 0;
					if (e.Alt) {
						keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
					}
					if (e.Control) {
						keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!e.Alt) {
							if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64);
						}
					}
					if (e.Shift) {
						keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed;
					}
					if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn;
					}
					if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn;
					}
					// and close the form
					this.Close();
				}
			}

			void Keyboard_Form_KeyUp(object sender, KeyEventArgs e) {
				if (!checkKeyDown) { // store key info
					keyinfo.VirtualKeyCode = e.KeyValue;
					keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];
					keyinfo.KeyDown = true;
					keyinfo.ControlKeyState = 0;
					if (e.Alt) {
						keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
					}
					if (e.Control) {
						keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!e.Alt) {
							if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64);
						}
					}
					if (e.Shift) {
						keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed;
					}
					if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn;
					}
					if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) {
						keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn;
					}
					// and close the form
					this.Close();
				}
			}
		}

		public static KeyInfo Show(string strTitle, string strPrompt, bool blIncludeKeyDown) {
			// Controls erzeugen
			Keyboard_Form form = new Keyboard_Form();
			Label label = new Label();

			// Am Label orientieren sich die Größen und Positionen
			// Dieses Control also zuerst fertigstellen
			if (string.IsNullOrEmpty(strPrompt))
				label.Text = "Press a key";
			else
				label.Text = strPrompt;
			label.Location = new Point(9, 19);
			label.MaximumSize = new System.Drawing.Size(System.Windows.Forms.Screen.FromControl(form).Bounds.Width * 5 / 8 - 18, 0);
			label.AutoSize = true;
			// erst durch Add() wird die Größe des Labels ermittelt
			form.Controls.Add(label);

			// configure form
			if (string.IsNullOrEmpty(strTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = strTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 55);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			try {
				form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
			} catch {}
			form.MinimizeBox = false;
			form.MaximizeBox = false;

			// show and compute form
			form.checkKeyDown = blIncludeKeyDown;
			form.ShowDialog();
			return form.keyinfo;
		}
	}

	public class Progress_Form: Form {
		private ConsoleColor ProgressBarColor = ConsoleColor.DarkCyan;

		#if!noVisualStyles
		private System.Timers.Timer timer = new System.Timers.Timer();
		private int barNumber = -1;
		private int barValue = -1;
		private bool inTick = false;
		#endif

		struct Progress_Data {
			internal Label lbActivity;
			internal Label lbStatus;
			internal ProgressBar objProgressBar;
			internal Label lbRemainingTime;
			internal Label lbOperation;
			internal int ActivityId;
			internal int ParentActivityId;
			internal int Depth;
		};

		private List<Progress_Data> progressDataList = new List<Progress_Data> ();

		private Color DrawingColor(ConsoleColor color) { // convert ConsoleColor to System.Drawing.Color
			switch (color) {
			case ConsoleColor.Black:
				return Color.Black;
			case ConsoleColor.Blue:
				return Color.Blue;
			case ConsoleColor.Cyan:
				return Color.Cyan;
			case ConsoleColor.DarkBlue:
				return ColorTranslator.FromHtml("#000080");
			case ConsoleColor.DarkGray:
				return ColorTranslator.FromHtml("#808080");
			case ConsoleColor.DarkGreen:
				return ColorTranslator.FromHtml("#008000");
			case ConsoleColor.DarkCyan:
				return ColorTranslator.FromHtml("#008080");
			case ConsoleColor.DarkMagenta:
				return ColorTranslator.FromHtml("#800080");
			case ConsoleColor.DarkRed:
				return ColorTranslator.FromHtml("#800000");
			case ConsoleColor.DarkYellow:
				return ColorTranslator.FromHtml("#808000");
			case ConsoleColor.Gray:
				return ColorTranslator.FromHtml("#C0C0C0");
			case ConsoleColor.Green:
				return ColorTranslator.FromHtml("#00FF00");
			case ConsoleColor.Magenta:
				return Color.Magenta;
			case ConsoleColor.Red:
				return Color.Red;
			case ConsoleColor.White:
				return Color.White;
			default:
				return Color.Yellow;
			}
		}

		private void InitializeComponent() {
			this.SuspendLayout();

			this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
			this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;

			this.AutoScroll = true;
			this.Text = System.AppDomain.CurrentDomain.FriendlyName;
			this.Height = 147;
			this.Width = 800;
			this.BackColor = Color.White;
			this.FormBorderStyle = FormBorderStyle.FixedSingle;
			this.MinimizeBox = false;
			this.MaximizeBox = false;
			this.ControlBox = false;
			this.StartPosition = FormStartPosition.CenterScreen;

			this.ResumeLayout();
			#if!noVisualStyles
			timer.Elapsed += new System.Timers.ElapsedEventHandler(TimeTick);
			timer.Interval = 50; // milliseconds
			timer.AutoReset = true;
			timer.Start();
			#endif
		}
		#if!noVisualStyles
		private void TimeTick(object source, System.Timers.ElapsedEventArgs e) { // worker function that is called by timer event

			if (inTick) return;
			inTick = true;
			if (barNumber >= 0) {
				if (barValue >= 0) {
					progressDataList[barNumber].objProgressBar.Value = barValue;
					barValue = -1;
				}
				progressDataList[barNumber].objProgressBar.Refresh();
			}
			inTick = false;
		}
		#endif

		private void AddBar(ref Progress_Data pd, int position) {
			// Create Label
			pd.lbActivity = new Label();
			pd.lbActivity.Left = 5;
			pd.lbActivity.Top = 104 * position + 10;
			pd.lbActivity.Width = 800 - 20;
			pd.lbActivity.Height = 16;
			pd.lbActivity.Font = new Font(pd.lbActivity.Font, FontStyle.Bold);
			pd.lbActivity.Text = "";
			// Add Label to Form
			this.Controls.Add(pd.lbActivity);

			// Create Label
			pd.lbStatus = new Label();
			pd.lbStatus.Left = 25;
			pd.lbStatus.Top = 104 * position + 26;
			pd.lbStatus.Width = 800 - 40;
			pd.lbStatus.Height = 16;
			pd.lbStatus.Text = "";
			// Add Label to Form
			this.Controls.Add(pd.lbStatus);

			// Create ProgressBar
			pd.objProgressBar = new ProgressBar();
			pd.objProgressBar.Value = 0;
			pd.objProgressBar.Style =
				#if noVisualStyles
					ProgressBarStyle.Continuous
				#else
					ProgressBarStyle.Blocks
				#endif
			;
			pd.objProgressBar.ForeColor = DrawingColor(ProgressBarColor);
			if (pd.Depth < 15) {
				pd.objProgressBar.Size = new System.Drawing.Size(800 - 60 - 30 * pd.Depth, 20);
				pd.objProgressBar.Left = 25 + 30 * pd.Depth;
			} else {
				pd.objProgressBar.Size = new System.Drawing.Size(800 - 60 - 450, 20);
				pd.objProgressBar.Left = 25 + 450;
			}
			pd.objProgressBar.Top = 104 * position + 47;
			// Add ProgressBar to Form
			this.Controls.Add(pd.objProgressBar);

			// Create Label
			pd.lbRemainingTime = new Label();
			pd.lbRemainingTime.Left = 5;
			pd.lbRemainingTime.Top = 104 * position + 72;
			pd.lbRemainingTime.Width = 800 - 20;
			pd.lbRemainingTime.Height = 16;
			pd.lbRemainingTime.Text = "";
			// Add Label to Form
			this.Controls.Add(pd.lbRemainingTime);

			// Create Label
			pd.lbOperation = new Label();
			pd.lbOperation.Left = 25;
			pd.lbOperation.Top = 104 * position + 88;
			pd.lbOperation.Width = 800 - 40;
			pd.lbOperation.Height = 16;
			pd.lbOperation.Text = "";
			// Add Label to Form
			this.Controls.Add(pd.lbOperation);
		}

		public int GetCount() {
			return progressDataList.Count;
		}

		public Progress_Form() {
			InitializeComponent();
		}

		public Progress_Form(ConsoleColor BarColor) {
			ProgressBarColor = BarColor;
			InitializeComponent();
		}

		public void Update(ProgressRecord objRecord) {
			if (objRecord == null)
				return;

			int currentProgress = -1;
			for (int i = 0; i < progressDataList.Count; i++) {
				if (progressDataList[i].ActivityId == objRecord.ActivityId) {
					currentProgress = i;
					break;
				}
			}

			if (objRecord.RecordType == ProgressRecordType.Completed) {
				if (currentProgress >= 0) {
					#if!noVisualStyles
					if (barNumber == currentProgress) barNumber = -1;
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
				}

				if (progressDataList.Count == 0) {
					#if!noVisualStyles
					timer.Stop();
					timer.Dispose();
					#endif
					this.Close();
					return;
				}

				if (currentProgress < 0) return;

				for (int i = currentProgress; i < progressDataList.Count; i++) {
					progressDataList[i].lbActivity.Top = 104 * i + 10;
					progressDataList[i].lbStatus.Top = 104 * i + 26;
					progressDataList[i].objProgressBar.Top = 104 * i + 47;
					progressDataList[i].lbRemainingTime.Top = 104 * i + 72;
					progressDataList[i].lbOperation.Top = 104 * i + 88;
				}

				if (104 * progressDataList.Count + 43 <= System.Windows.Forms.Screen.FromControl(this).Bounds.Height) {
					this.Height = 104 * progressDataList.Count + 43;
					this.Location = new Point((System.Windows.Forms.Screen.FromControl(this).Bounds.Width - this.Width) / 2, (System.Windows.Forms.Screen.FromControl(this).Bounds.Height - this.Height) / 2);
				} else {
					this.Height = System.Windows.Forms.Screen.FromControl(this).Bounds.Height;
					this.Location = new Point((System.Windows.Forms.Screen.FromControl(this).Bounds.Width - this.Width) / 2, 0);
				}

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

					for (int i = currentProgress + 1; i < progressDataList.Count; i++) {
						progressDataList[i].lbActivity.Top = 104 * i + 10;
						progressDataList[i].lbStatus.Top = 104 * i + 26;
						progressDataList[i].objProgressBar.Top = 104 * i + 47;
						progressDataList[i].lbRemainingTime.Top = 104 * i + 72;
						progressDataList[i].lbOperation.Top = 104 * i + 88;
					}
				}
				if (104 * progressDataList.Count + 43 <= System.Windows.Forms.Screen.FromControl(this).Bounds.Height) {
					this.Height = 104 * progressDataList.Count + 43;
					this.Location = new Point((System.Windows.Forms.Screen.FromControl(this).Bounds.Width - this.Width) / 2, (System.Windows.Forms.Screen.FromControl(this).Bounds.Height - this.Height) / 2);
				} else {
					this.Height = System.Windows.Forms.Screen.FromControl(this).Bounds.Height;
					this.Location = new Point((System.Windows.Forms.Screen.FromControl(this).Bounds.Width - this.Width) / 2, 0);
				}
			}

			if (!string.IsNullOrEmpty(objRecord.Activity))
				progressDataList[currentProgress].lbActivity.Text = objRecord.Activity;
			else
				progressDataList[currentProgress].lbActivity.Text = "";

			if (!string.IsNullOrEmpty(objRecord.StatusDescription))
				progressDataList[currentProgress].lbStatus.Text = objRecord.StatusDescription;
			else
				progressDataList[currentProgress].lbStatus.Text = "";

			if ((objRecord.PercentComplete >= 0) && (objRecord.PercentComplete <= 100)) {
				#if!noVisualStyles
				if (objRecord.PercentComplete < 100)
					progressDataList[currentProgress].objProgressBar.Value = objRecord.PercentComplete + 1;
				else
					progressDataList[currentProgress].objProgressBar.Value = 99;
				progressDataList[currentProgress].objProgressBar.Visible = true;
				barNumber = currentProgress;
				barValue = objRecord.PercentComplete;
				#else
				progressDataList[currentProgress].objProgressBar.Value = objRecord.PercentComplete;
				progressDataList[currentProgress].objProgressBar.Visible = true;
				#endif
			} else {
				if (objRecord.PercentComplete > 100) {
					progressDataList[currentProgress].objProgressBar.Value = 0;
					progressDataList[currentProgress].objProgressBar.Visible = true;
					#if!noVisualStyles
					barNumber = currentProgress;
					barValue = 0;
					#endif
				} else {
					progressDataList[currentProgress].objProgressBar.Visible = false;
					#if!noVisualStyles
					if (barNumber == currentProgress) barNumber = -1;
					#endif
				}
			}

			if (objRecord.SecondsRemaining >= 0) {
				System.TimeSpan objTimeSpan = new System.TimeSpan(0, 0, objRecord.SecondsRemaining);
				progressDataList[currentProgress].lbRemainingTime.Text = string.Format("Remaining time: {0:00}:{1:00}:{2:00}", (int) objTimeSpan.TotalHours, objTimeSpan.Minutes, objTimeSpan.Seconds);
			} else
				progressDataList[currentProgress].lbRemainingTime.Text = "";

			if (!string.IsNullOrEmpty(objRecord.CurrentOperation))
				progressDataList[currentProgress].lbOperation.Text = objRecord.CurrentOperation;
			else
				progressDataList[currentProgress].lbOperation.Text = "";

			Application.DoEvents();
		}
	}
	#endif

	// define IsInputRedirected(), IsOutputRedirected() and IsErrorRedirected() here since they were introduced first with .Net 4.5
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

		[DllImport("Kernel32.dll")]
		static private extern UIntPtr GetStdHandle(STDHandle stdHandle);

		[DllImport("Kernel32.dll")]
		static private extern FileType GetFileType(UIntPtr hFile);

		static public bool IsInputRedirected() {
			UIntPtr hInput = GetStdHandle(STDHandle.STD_INPUT_HANDLE);
			FileType fileType = GetFileType(hInput);
			if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))
				return false;
			return true;
		}

		static public bool IsOutputRedirected() {
			UIntPtr hOutput = GetStdHandle(STDHandle.STD_OUTPUT_HANDLE);
			FileType fileType = GetFileType(hOutput);
			if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))
				return false;
			return true;
		}

		static public bool IsErrorRedirected() {
			UIntPtr hError = GetStdHandle(STDHandle.STD_ERROR_HANDLE);
			FileType fileType = GetFileType(hError);
			if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))
				return false;
			return true;
		}
	}

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
		#if!noConsole
			ConsoleColor.Yellow
		#else
			ConsoleColor.DarkCyan
		#endif
		;
		public ConsoleColor ProgressBackgroundColor = ConsoleColor.DarkCyan;

		public PSRunnerUI() {
			rawUI = new PSRunnerRawUI();
			#if!noConsole
				rawUI.ForegroundColor = Console.ForegroundColor;
				rawUI.BackgroundColor = Console.BackgroundColor;
			#endif
		}

		public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions) {
			#if!noConsole
				if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
				if (!string.IsNullOrEmpty(message)) WriteLine(message);
			#else
				if ((!string.IsNullOrEmpty(caption)) || (!string.IsNullOrEmpty(message))) {
					string sTitel = rawUI.WindowTitle, sMeldung = "";

					if (!string.IsNullOrEmpty(caption)) sTitel = caption;
					if (!string.IsNullOrEmpty(message)) sMeldung = message;
					MessageBox.Show(sMeldung, sTitel);
				}

				// Titel und Labeltext für Input_Box zurücksetzen
				ib_caption = "";
				ib_message = "";
			#endif
			Dictionary<string, PSObject> ret = new Dictionary<string, PSObject> ();
			foreach(FieldDescription cd in descriptions) {
				Type t;
				if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))
					t = typeof (string);
				else
					t = Type.GetType(cd.ParameterAssemblyFullName);

				if (t.IsArray) {
					Type elementType = t.GetElementType();
					Type genericListType = Type.GetType("System.Collections.Generic.List\x60\x31");
					genericListType = genericListType.MakeGenericType(new [] {
						elementType
					});
					ConstructorInfo constructor = genericListType.GetConstructor(BindingFlags.CreateInstance | BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null);
					object resultList = constructor.Invoke(null);

					int index = 0;
					string data = "";
					do {
						if (!string.IsNullOrEmpty(cd.Name))
							#if!noConsole
								Write(string.Format("{0}[{1}]: ", cd.Name, index));
							#else
								ib_message = string.Format("{0}[{1}]: ", cd.Name, index);
							#endif
						data = ReadLine();
						if (string.IsNullOrEmpty(data))
							break;
						object o = System.Convert.ChangeType(data, elementType);
						genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new [] {
							o
						});
						index++;
					} while (true);

					System.Array retArray = (System.Array) genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);
					ret.Add(cd.Name, new PSObject(retArray));
				} else {
					object o=null;
					string l;
					if (t != typeof (System.Security.SecureString)) {
						if (t != typeof (System.Management.Automation.PSCredential)) {
							#if!noConsole
							if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);
							if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");
							if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");
							#else
							if (!string.IsNullOrEmpty(cd.Name)) ib_message = string.Format("{0}: ", cd.Name);
							if (!string.IsNullOrEmpty(cd.HelpMessage)) ib_message += "\n(Type !? for help.)";
							#endif
							do {
								l = ReadLine();
								if (l == "!?")
									WriteLine(cd.HelpMessage);
								else {
									if (string.IsNullOrEmpty(l)) o = cd.DefaultValue;
									if (o == null) {
										try {
											o = System.Convert.ChangeType(l, t);
										} catch {
											Write("Wrong format, please repeat input: ");
											l = "!?";
										}
									}
								}
							} while (l == "!?");
						} else
							o = PromptForCredential("", "", "", "");
					} else {
						if (!string.IsNullOrEmpty(cd.Name))
							#if!noConsole
								Write(string.Format("{0}: ", cd.Name));
							#else
								ib_message = string.Format("{0}: ", cd.Name);
							#endif

						o = ReadLineAsSecureString();
					}

					ret.Add(cd.Name, new PSObject(o));
				}
			}
			#if noConsole
			// Titel und Labeltext für Input_Box zurücksetzen
			ib_caption = "";
			ib_message = "";
			#endif
			return ret;
		}

		public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice) {
			#if noConsole
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
				} catch {/* ignore some read errors */}
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
			#if!(noConsole || credentialGUI)
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			WriteLine(message);

			string un;
			Write("User name: ");
			if ((string.IsNullOrEmpty(userName)) || ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0)) {
				un = ReadLine();
			} else {
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
			#if!(noConsole || credentialGUI)
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
		private string ib_caption;
		private string ib_message;
		#endif

		public override string ReadLine() {
			#if!noConsole
				return Console.ReadLine();
			#else
				string sWert = "";
				if (Input_Box.Show(ib_caption, ib_message, ref sWert) == DialogResult.OK)
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
			#if!noConsole
				secstr = getPassword();
			#else
				secstr = new System.Security.SecureString();
				string sWert = "";

				if (Input_Box.Show(ib_caption, ib_message, ref sWert, true) == DialogResult.OK) {
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

		// called by Write-Host
		public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			#if!noOutput
			#if!noConsole
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.Write(value);
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
			#else
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		public override void Write(string value) {
			#if!noOutput
			#if!noConsole
			Console.Write(value);
			#else
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		// called by Write-Debug
		public override void WriteDebugLine(string message) {
			#if!noError
			#if!noConsole
			WriteLineInternal(DebugForegroundColor, DebugBackgroundColor, string.Format("DEBUG: {0}", message));
			#else
			MessageBox.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Information);
			#endif
			#endif
		}

		// called by Write-Error
		public override void WriteErrorLine(string value) {
			#if!noError
			#if!noConsole
			if (Console_Info.IsErrorRedirected())
				Console.Error.WriteLine(string.Format("ERROR: {0}", value));
			else
				WriteLineInternal(ErrorForegroundColor, ErrorBackgroundColor, string.Format("ERROR: {0}", value));
			#else
			MessageBox.Show(value, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
			#endif
			#endif
		}

		public override void WriteLine() {
			#if!noOutput
			#if!noConsole
			Console.WriteLine();
			#else
			MessageBox.Show("", rawUI.WindowTitle);
			#endif
			#endif
		}

		public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			#if!noOutput
			#if!noConsole
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.WriteLine(value);
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
			#else
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		#if!(noError || noConsole)
		private void WriteLineInternal(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) {
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.WriteLine(value);
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
		}
		#endif

		// called by Write-Output
		public override void WriteLine(string value) {
			#if!noOutput
			#if!noConsole
			Console.WriteLine(value);
			#else
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, rawUI.WindowTitle);
			#endif
			#endif
		}

		#if noConsole
		public Progress_Form pf;
		#endif
		public override void WriteProgress(long sourceId, ProgressRecord record) {
			#if noConsole
			if (pf == null) {
				if (record.RecordType == ProgressRecordType.Completed) return;
				pf = new Progress_Form(ProgressForegroundColor);
				pf.Show();
			}
			pf.Update(record);
			if (record.RecordType == ProgressRecordType.Completed) {
				if (pf.GetCount() == 0) pf = null;
			}
			#else
			if (record.RecordType == ProgressRecordType.Completed) {
				Console.WriteLine();
				return;
			}
			throw new NotImplementedException();
			#endif
		}

		// called by Write-Verbose
		public override void WriteVerboseLine(string message) {
			#if!noOutput
			#if!noConsole
			WriteLine(VerboseForegroundColor, VerboseBackgroundColor, string.Format("VERBOSE: {0}", message));
			#else
			MessageBox.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Information);
			#endif
			#endif
		}

		// called by Write-Warning
		public override void WriteWarningLine(string message) {
			#if!noError
				#if!noConsole
					WriteLineInternal(WarningForegroundColor, WarningBackgroundColor, string.Format("WARNING: {0}", message));
				#else
					MessageBox.Show(message, rawUI.WindowTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
				#endif
			#endif
		}
	}

	internal class PSRunnerHost: PSHost {
		private readonly PSRunnerInterface parent;
		private readonly PSRunnerUI _ui;

		private readonly CultureInfo originalCultureInfo = System.Threading.Thread.CurrentThread.CurrentCulture;

		private readonly CultureInfo originalUICultureInfo = System.Threading.Thread.CurrentThread.CurrentUICulture;

		private Guid myId = Guid.NewGuid();

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
			get { return this.myId; }
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
		private bool shouldExit;

		private int exitCode;
		public bool Inited;

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
			this.shouldExit = false;
			this.exitCode = 0;
			this.ui = new PSRunnerUI();
			this.host = new PSRunnerHost(this, ui);
			this.PSRunSpace = RunspaceFactory.CreateRunspace(host);
			this.PSRunSpace.ApartmentState = System.Threading.ApartmentState.$threadingModel;
			this.PSRunSpace.Open();
			this.pwsh = PowerShell.Create();
			this.pwsh.Runspace = PSRunSpace;
			string exepath = System.Reflection.Assembly.GetExecutingAssembly().Location;
			this.pwsh.Runspace.SessionStateProxy.SetVariable("PSEXEpath", exepath);
			Assembly executingAssembly = Assembly.GetExecutingAssembly();
			string script;
			using(System.IO.Stream scriptstream = executingAssembly.GetManifestResourceStream("main.ps1")) {
				using(System.IO.StreamReader scriptreader = new System.IO.StreamReader(scriptstream, System.Text.Encoding.UTF8)) {
					script = scriptreader.ReadToEnd();
					this.PSRunSpace.SessionStateProxy.SetVariable("PSEXEscript", script);
				}
			}
			{
				Token[] tokens;
				ParseError[] errors;
				ScriptBlockAst AST = Parser.ParseInput(script, exepath, out tokens, out errors);
				this.PSRunSpace.SessionStateProxy.SetVariable("PSEXECodeBlock", AST.GetScriptBlock());
				if(errors.Length > 0)
					throw new System.Exception(errors[0].Message);
			}
		}
		~PSRunner() {
			this.pwsh.Dispose();
			this.PSRunSpace.Close();
			this.PSRunSpace.Dispose();
			this.host = null;
			this.ui = null;
		}

		//base init
		public static void BaseInit() {
			#if UNICODEEncoding && !noConsole
			System.Console.OutputEncoding = new System.Text.UnicodeEncoding();
			#endif

			#if culture
			System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.GetCultureInfo("$lcid");
			System.Threading.Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.GetCultureInfo("$lcid");
			#endif

			#if!noVisualStyles && noConsole
			Application.EnableVisualStyles();
			#endif
		}
	}
	class PSRunnerEntry {
		static PSRunner me;

		// EXEMain
		[$threadingModelThread]
		private static int Main(string[] args) {
			PSRunner.BaseInit();
			me = new PSRunner();
			System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);

			try {
				#if!noConsole
				Console.CancelKeyPress += (object sender, ConsoleCancelEventArgs e) => {
					try {
						me.pwsh.BeginStop((_) => {
							mre.Set();
							e.Cancel = true;
						}, null);
					} catch {
						// ignore because we are shutting down
					}
				};
				#endif

				me.pwsh.Streams.Error.DataAdded += (object sender, DataAddedEventArgs e) => {
					me.ui.WriteErrorLine(((PSDataCollection<ErrorRecord> ) sender)[e.Index].Exception.Message);
				};

				PSDataCollection<string> colInput = new PSDataCollection<string> ();
				if (Console_Info.IsInputRedirected()) { // read standard input
					string sItem = "";
					while ((sItem = Console.ReadLine()) != null) { // add to powershell pipeline
						colInput.Add(sItem);
					}
				}
				colInput.Complete();

				PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject> ();
				colOutput.DataAdded += (object sender, DataAddedEventArgs e) => {
					me.ui.WriteLine(((PSDataCollection<PSObject> ) sender)[e.Index].ToString());
				};

				for(int i = 0; i < args.Length; i++) {
					if (Regex.IsMatch(args[i], @"^(-|\$)\w*$"));
					else
						args[i] = "\'"+args[i].Replace("'", "''")+"\'";
				}

				me.pwsh.AddScript(".$PSEXECodeBlock "+String.Join(" ", args)+"|Out-String -Stream");

				me.pwsh.BeginInvoke<string, PSObject> (colInput, colOutput, null, (IAsyncResult ar) => {
					if (ar.IsCompleted)
						mre.Set();
				}, null);

				while (!mre.WaitOne(100))
					if (me.ShouldExit) break;

				me.Inited = true;
				me.pwsh.Stop();

				if (me.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
					me.ui.WriteErrorLine(me.pwsh.InvocationStateInfo.Reason.Message);
			}
			catch (Exception ex) {
				#if!noError
					me.ui.WriteErrorLine(ex.Message);
				#endif
				me.ExitCode = 1;
			}
			finally {
				mre.Dispose();
			}

			return me.ExitCode;
		}

		#if DllExport
		// DllInitChecker
		[$threadingModelThread]
		public static void DllInitChecker() {
			if(!Inited) {
				PSRunner.BaseInit();
				// run pwsh code
				System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);

				PSDataCollection<string> colInput = new PSDataCollection<string> ();
				colInput.Complete();

				PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject> ();
				colOutput.DataAdded += (object sender, DataAddedEventArgs e) => {
					me.ui.WriteLine(((PSDataCollection<PSObject> ) sender)[e.Index].ToString());
				};

				me.pwsh.AddScript(".$PSEXECodeBlock|Out-String -Stream");

				me.pwsh.BeginInvoke<string, PSObject> (colInput, colOutput, null, (IAsyncResult ar) => {
					if (ar.IsCompleted)
						mre.Set();
				}, null);

				while (!mre.WaitOne(100))
					if (me.ShouldExit) break;

				Inited = true;

				if(me.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
					me.ui.WriteErrorLine(me.pwsh.InvocationStateInfo.Reason.Message);

				mre.Dispose();
			}
		}
		[DllExport("DllExportExample", CallingConvention = CallingConvention.StdCall)]
		public static int DllExportExample(int a, int b) {
			DllInitChecker();
			if(me.ShouldExit)
				throw new System.Exception(me.pwsh.InvocationStateInfo.Reason.Message);
			//set parameters as variables in psrunspace
			me.PSRunSpace.SessionStateProxy.SetVariable("PSEXEDLLCallIngParameters", new System.Collections.ArrayList{a, b});
			me.pwsh.AddScript("DllExportExample @PSEXEDLLCallIngParameters");
			System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);

			PSDataCollection<string> colInput = new PSDataCollection<string> ();
			colInput.Complete();

			PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject> ();
			//output as return value
			colOutput.Complete();

			me.pwsh.BeginInvoke<string, PSObject> (colInput, colOutput, null, (IAsyncResult ar) => {
				if (ar.IsCompleted)
					mre.Set();
			}, null);

			while (!mre.WaitOne(100))
				if (me.ShouldExit) break;

			if(me.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
				throw new System.Exception(me.pwsh.InvocationStateInfo.Reason.Message);
			if(me.ShouldExit)
				throw new System.Exception(me.pwsh.InvocationStateInfo.Reason.Message);

			//if only one object is in colOutput, return it
			if(colOutput.Count == 1)
				return colOutput[0];
			//else return the whole collection
			return colOutput;
		}
		#endif
	}
}
