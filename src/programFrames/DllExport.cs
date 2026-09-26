using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

// 原生 DLL 导出层：与 default.cs 的 PSRunnerEntry 组成同一个 partial 类。
// 工具（src/DllExportCompiler.ps1）会把每个 #_DllExport 声明生成一个包装方法，并注入到本文件末尾的
// 导出方法标记处；编译成类库后再由 AsmResolver 给这些方法设置 UnmanagedExportInfo，写出原生导出表。
namespace PSRunnerNS {
	static partial class PSRunnerEntry {
		private static readonly object dllLock = new object();
		private static bool dllInitialized = false;

		// 首次导出调用时惰性初始化：运行脚本（在全局作用域，确保其函数定义持久可用），
		// 之后各导出方法就能按名字调用这些函数。多线程调用由 dllLock 串行化。
		private static void DllInitChecker() {
			lock (dllLock) {
				if (dllInitialized) return;
				PSRunner.BaseInit();
				runner = new PSRunner();
				try {
					runner.pwsh.Streams.Error.Clear();
					runner.pwsh.Commands.Clear();
					// 顶层运行脚本而不是调用 PSEXEMainFunction：函数定义在函数体内是局部的，
					// 只有顶层（或点源）定义才会留在 runspace 的全局作用域里供导出调用。
					runner.pwsh.AddScript(". ([scriptblock]::Create($PSEXEscript))");
					System.Collections.ObjectModel.Collection<PSObject> initOutput = runner.pwsh.Invoke();
					foreach (PSObject outputItem in initOutput)
						System.Console.WriteLine(outputItem == null ? "" : outputItem.ToString());
					foreach (ErrorRecord errorItem in runner.pwsh.Streams.Error)
						runner.ui.WriteErrorRecord(errorItem);
					runner.pwsh.Streams.Error.Clear();
					if (runner.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
						throw new InvalidOperationException("PowerShell script init failed: " + runner.pwsh.InvocationStateInfo.Reason.Message);
				}
				catch (Exception ex) {
					ReportDllExportError("<init>", ex);
				}
				dllInitialized = true;
			}
		}

		// 以 PSEXEDLLCallIngParameters 数组为参数调用脚本里的函数，返回其输出。
		private static object InvokePSFunction(string exportName, object[] args) {
			lock (dllLock) {
				if (!dllInitialized || runner == null) throw new InvalidOperationException("PSRunner is not initialized.");
				if (runner.ShouldExit) throw new InvalidOperationException("PSRunner is exiting.");
				runner.PSRunSpace.SessionStateProxy.SetVariable("PSEXEDLLCallIngParameters", new ArrayList(args));
				runner.PSRunSpace.SessionStateProxy.SetVariable("PSEXEDLLExportName", exportName);
				runner.pwsh.Streams.Error.Clear();
				runner.pwsh.Commands.Clear();
				runner.pwsh.AddScript("& $PSEXEDLLExportName @PSEXEDLLCallIngParameters");
				System.Collections.ObjectModel.Collection<PSObject> output = runner.pwsh.Invoke();
				foreach (ErrorRecord errorItem in runner.pwsh.Streams.Error)
					runner.ui.WriteErrorRecord(errorItem);
				runner.pwsh.Streams.Error.Clear();
				if (runner.pwsh.InvocationStateInfo.State == PSInvocationState.Failed)
					throw new InvalidOperationException("PowerShell function '" + exportName + "' failed: " + runner.pwsh.InvocationStateInfo.Reason.Message);
				if (output.Count == 0) return null;
				if (output.Count == 1) return output[0] == null ? null : output[0].BaseObject;
				object[] results = new object[output.Count];
				for (int i = 0; i < output.Count; i++)
					results[i] = output[i] == null ? null : output[i].BaseObject;
				return results;
			}
		}

		// 异常不能穿过 native 边界（会变成进程级崩溃），这里记录到 stderr 后由包装方法返回默认值。
		private static void ReportDllExportError(string exportName, Exception ex) {
			try { System.Console.Error.WriteLine("PS12exe DllExport '" + exportName + "': " + ex.Message); }
			catch { }
		}
		/*__PS12EXE_DLL_EXPORTS__*/
	}
}
