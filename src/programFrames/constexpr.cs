// Simple PowerShell host created by Ingo Karstein (http://blog.karstein-consulting.com)
// Reworked and GUI support by Markus Scholtes

using System;
using System.Collections.Generic;
using System.Text;
using System.Globalization;
using System.Reflection;
#if noConsole
	using System.Windows.Forms;
	using System.Drawing;
#endif
#if conHost
	using System.Runtime.InteropServices;
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
	internal static class PSRunnerEntry {
		#if conHost
			[DllImport("kernel32.dll", SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)]
			private static extern bool AllocConsole();
		#endif
		private static int Main() {
			#if !noOutput
				#if UNICODEEncoding && !noConsole
				System.Console.OutputEncoding = new System.Text.UnicodeEncoding();
				#endif

				#if !noVisualStyles && noConsole
				Application.EnableVisualStyles();
				#endif

				#if noConsole
					// load assembly:AssemblyTitle
					AssemblyTitleAttribute titleAttribute = (AssemblyTitleAttribute) Attribute.GetCustomAttribute(Assembly.GetExecutingAssembly(), typeof(AssemblyTitleAttribute));
					string title;
					if (titleAttribute != null)
						title = titleAttribute.Title;
					else
						title = System.AppDomain.CurrentDomain.FriendlyName;
					// 弹窗输出 \ConstResult
					string[] ConstResult = { "$ConstResult" };
					foreach (string item in ConstResult)
						MessageBox.Show(item, title, MessageBoxButtons.OK);
				#else
					#if conHost
						if (AllocConsole()) {
							Console.SetIn(new System.IO.StreamReader(Console.OpenStandardInput()));

							System.IO.StreamWriter streamWriter = new System.IO.StreamWriter(Console.OpenStandardOutput());
							streamWriter.AutoFlush = true;
							Console.SetOut(streamWriter);

							System.IO.StreamWriter errorWriter = new System.IO.StreamWriter(Console.OpenStandardOutput());
							errorWriter.AutoFlush = true;
							Console.SetError(errorWriter);
						}
						else Console.Error.WriteLine("Creation of conHost failed!");
					#endif
					// 控制台输出 \ConstResult
					System.Console.WriteLine("$ConstResult");
				#endif
			#endif
			return $ConstExitCodeResult;
		}
	}
}
