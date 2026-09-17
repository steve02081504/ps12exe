// Root assembly for IL Linker. It is compiled against the full AsmResolver and never run;
// illink uses the reachable members as the set of AsmResolver APIs ps12exe needs.
using AsmResolver.PE;
using AsmResolver.PE.Builder;
using AsmResolver.PE.File;
using AsmResolver.PE.Win32Resources;

internal static class EntryPoint
{
	static void Main()
	{
		// src/programFrames/TinySharp.cs: const-output exe generation.
		var p = TinySharp.Program.Compile("Framework4.0", "x64", "Hello World!", 0, true, false);
		p.SetWin32Icon("icon.ico");
		p.SetAssemblyInfo("description", "company", "title", "product", "copyright", "trademark", "1.2.3.4");
		p.Build("out.exe");
		TinySharp.Program.Compile("Framework2.0", "anycpu", "unicode 世界", 42, true, true).Build("out2.exe");
		TinySharp.Program.Compile("Framework4.0", "x86", "no output", 0, false, false).Build("out3.exe");

		// src/programFrames/exe21sp.cs: script recovery (exe21sp).
		System.Console.WriteLine(exe21sp.Extractor.ExtractScriptFromExe("target.exe"));

		// src/ExeSinker.ps1 drives AsmResolver directly from PowerShell; those members are not
		// reachable from the C# consumers above, so mirror them here.
		RootExeSinkerUsage();
	}

	static void RootExeSinkerUsage()
	{
		var image = PEImage.FromFile("target.exe");
		image.DllCharacteristics &= ~DllCharacteristics.DynamicBase;
		if (image.Resources != null)
		{
			_ = image.Resources.Type;
			foreach (var entry in image.Resources.Entries)
				_ = entry.Name;
			if (image.Resources.Entries.Count > 0)
				image.Resources.Entries.Remove(image.Resources.Entries[0]);
		}
		image.Resources = null;
		var file = new ManagedPEFileBuilder().CreateFile(image);
		file.Write("out.exe");
	}
}
