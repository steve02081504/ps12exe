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
using RGiesecke.DllExport;
using System.Runtime.Versioning;

namespace PSRunnerNS {
	partial static class PSRunnerEntry {
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
					me.ui.WriteLine(((PSDataCollection<PSObject>) sender)[e.Index].ToString());
				};

				me.pwsh.AddScript("PSEXEMainFunction|Out-String -Stream");

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
				throw new System.TypeUnloadedException(me.pwsh.InvocationStateInfo.Reason.Message);
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
				throw new System.InternalErrorException(me.pwsh.InvocationStateInfo.Reason.Message);

			//if only one object is in colOutput, return it
			if(colOutput.Count == 1)
				return colOutput[0];
			//else return the whole collection
			return colOutput;
		}
	}
}
