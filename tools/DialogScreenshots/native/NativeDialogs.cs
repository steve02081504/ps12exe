// 原生对话框参照程序：供 tools/DialogScreenshots/Compare-Dialogs.ps1 截取「系统原生亮色」图。
// 通过环境变量 NATIVE_DIALOG 选择场景（msgbox/input/choice/readkey/constexpr/progress），NATIVE_TITLE 指定窗口标题。
// 仅用于截图对照，不属于 ps12exe 运行时产物。
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

internal static class NativeDialogs {
	[DllImport("user32.dll", CharSet = CharSet.Unicode)]
	static extern int MessageBoxW(IntPtr hwnd, string text, string caption, uint type);

	const uint MB_OK = 0x0;
	const uint MB_ICONWARNING = 0x30;
	const uint MB_ICONINFORMATION = 0x40;

	[ComImport, Guid("EBBC7C04-315E-11d2-B62F-006097DF5BD4"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	interface IProgressDialog {
		void StartProgressDialog(IntPtr hwndParent, [MarshalAs(UnmanagedType.IUnknown)] object punkEnableModless, uint dwFlags, IntPtr pvResevered);
		void StopProgressDialog();
		void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pwzTitle);
		void SetAnimation(IntPtr hInst, uint uID);
		[PreserveSig] bool HasUserCancelled();
		void SetProgress(uint dwCompleted, uint dwTotal);
		void SetProgress64(ulong ullCompleted, ulong ullTotal);
		void SetLine(uint dwLineNum, [MarshalAs(UnmanagedType.LPWStr)] string pwzString, [MarshalAs(UnmanagedType.Bool)] bool fCompactPath, IntPtr pvResevered);
		void SetCancelMsg([MarshalAs(UnmanagedType.LPWStr)] string pwzCancelMsg, IntPtr pvResevered);
		void Timer(uint dwTimerAction, IntPtr pvResevered);
	}
	[ComImport, Guid("F8383852-FCD3-11d1-A6B9-006097DF5BD4")]
	class ProgressDialogClass { }
	const uint PROGDLG_NORMAL = 0x00000000;

	[STAThread]
	static void Main() {
		Application.EnableVisualStyles();
		Application.SetCompatibleTextRenderingDefault(false);
		string dialog = Environment.GetEnvironmentVariable("NATIVE_DIALOG") ?? "msgbox";
		string title = Environment.GetEnvironmentVariable("NATIVE_TITLE") ?? "Native Reference";

		switch (dialog) {
			case "input":
				ShowInput(title);
				return;
			case "choice":
				ShowChoice(title);
				return;
			case "readkey":
				MessageBoxW(IntPtr.Zero, "Press a key", title, MB_OK);
				return;
			case "constexpr":
				MessageBoxW(IntPtr.Zero, "const-hello from ps12exe", title, MB_OK | MB_ICONINFORMATION);
				return;
			case "progress":
				ShowProgress(title);
				return;
			default:
				MessageBoxW(IntPtr.Zero, "This is a warning message", title, MB_OK | MB_ICONWARNING);
				return;
		}
	}

	static void ShowInput(string title) {
		Form form = CreateDialog(title, 352, 132);
		Label label = new Label();
		label.AutoSize = true;
		label.Text = "Input:";
		label.SetBounds(12, 12, 320, 20);
		TextBox input = new TextBox();
		input.SetBounds(12, 38, 328, 23);
		Button ok = CreateButton("OK", 75, 23);
		ok.SetBounds(265, 94, 75, 23);
		ok.DialogResult = DialogResult.OK;
		Button cancel = CreateButton("Cancel", 75, 23);
		cancel.SetBounds(184, 94, 75, 23);
		cancel.DialogResult = DialogResult.Cancel;
		form.AcceptButton = ok;
		form.CancelButton = cancel;
		form.Controls.AddRange(new Control[] { label, input, cancel, ok });
		form.Shown += delegate { input.Focus(); };
		Application.Run(form);
	}

	static void ShowChoice(string title) {
		Form form = CreateDialog(title, 360, 166);
		Label label = new Label();
		label.AutoSize = true;
		label.Text = "Pick one please";
		label.SetBounds(12, 12, 330, 20);
		RadioButton[] choices = new RadioButton[3];
		string[] labels = { "One", "Two", "Three" };
		for (int i = 0; i < choices.Length; i++) {
			choices[i] = new RadioButton();
			choices[i].Text = labels[i];
			choices[i].SetBounds(29, 38 + (i * 25), 300, 20);
			choices[i].Checked = i == 0;
			form.Controls.Add(choices[i]);
		}
		Button ok = CreateButton("OK", 75, 23);
		ok.SetBounds(273, 131, 75, 23);
		ok.DialogResult = DialogResult.OK;
		form.AcceptButton = ok;
		form.Controls.AddRange(new Control[] { label, ok });
		Application.Run(form);
	}

	static Form CreateDialog(string title, int width, int height) {
		Form form = new Form();
		form.Text = title;
		form.ClientSize = new System.Drawing.Size(width, height);
		form.FormBorderStyle = FormBorderStyle.FixedDialog;
		form.MaximizeBox = false;
		form.MinimizeBox = false;
		form.ShowInTaskbar = false;
		form.StartPosition = FormStartPosition.CenterScreen;
		form.AutoScaleMode = AutoScaleMode.None;
		return form;
	}

	static Button CreateButton(string text, int width, int height) {
		Button button = new Button();
		button.Text = text;
		button.Size = new System.Drawing.Size(width, height);
		return button;
	}

	static void ShowProgress(string title) {
		IProgressDialog dialog = (IProgressDialog)new ProgressDialogClass();
		dialog.StartProgressDialog(IntPtr.Zero, null, PROGDLG_NORMAL, IntPtr.Zero);
		dialog.SetTitle(title);
		dialog.SetLine(1, "Working", false, IntPtr.Zero);
		dialog.SetLine(2, "Step 1 (37%)", false, IntPtr.Zero);
		dialog.SetProgress(2410, 6500);
		System.Threading.Thread.Sleep(30000);
		dialog.StopProgressDialog();
	}
}
