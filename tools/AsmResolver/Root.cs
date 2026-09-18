// IL Linker 的根程序集。它针对完整的 AsmResolver 编译，但从不运行；illink 把可达成员作为 ps12exe 所需的 AsmResolver API 集合。
using AsmResolver.PE;
using AsmResolver.PE.Builder;
using AsmResolver.PE.File;
using AsmResolver.PE.Win32Resources;

internal static class EntryPoint
{
	static void Main()
	{
		// src/programFrames/TinySharp.cs：常量输出 exe 生成。
		var p = TinySharp.Program.Compile("Framework4.0", "x64", "Hello World!", 0, true, false);
		p.SetWin32Icon("icon.ico");
		p.SetAssemblyInfo("description", "company", "title", "product", "copyright", "trademark", "1.2.3.4");
		p.Build("out.exe");
		TinySharp.Program.Compile("Framework2.0", "anycpu", "unicode 世界", 42, true, true).Build("out2.exe");
		TinySharp.Program.Compile("Framework4.0", "x86", "no output", 0, false, false).Build("out3.exe");

		// src/programFrames/exe21sp.cs：脚本恢复（exe21sp）。
		System.Console.WriteLine(exe21sp.Extractor.ExtractScriptFromExe("target.exe"));
		// src/programFrames/exe21sp.cs：Win32 图标恢复（exe21sp 为 #_pragma icon 释放 <output>.ico）。
		_ = exe21sp.Extractor.ExtractIconFromExe("target.exe");

		// src/ExeSinker.ps1 直接从 PowerShell 驱动 AsmResolver；这些成员无法从上方 C# 使用方到达，故在此镜像。
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
