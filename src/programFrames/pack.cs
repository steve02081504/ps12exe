// Launcher for the default (compressed) non-const build.
// ps12exe 把真正的托管程序集 gzip 后作为 "main" 资源塞进这个 launcher，
// launcher 启动时在内存里解压、Assembly.Load 后调用负载的入口点，负载不落盘。
// 版本/标题等资源参数由 ps12exe 替换下面的 $placeholder（见 CodeDomCompiler.ps1），
// 常量 Resources / version / winFormsDPIAware 与 default.cs 保持一致。
#if Resources
[assembly: System.Reflection.AssemblyDescription("$description")]
[assembly: System.Reflection.AssemblyCompany("$company")]
[assembly: System.Reflection.AssemblyTitle("$title")]
[assembly: System.Reflection.AssemblyProduct("$product")]
[assembly: System.Reflection.AssemblyCopyright("$copyright")]
[assembly: System.Reflection.AssemblyTrademark("$trademark")]
#endif
#if version
[assembly: System.Reflection.AssemblyVersion("$version")]
[assembly: System.Reflection.AssemblyFileVersion("$version")]
#endif
#if winFormsDPIAware
[assembly: System.Runtime.Versioning.TargetFrameworkAttribute("$TargetFramework,Profile=Client")]
#endif
internal static class PS12ExeLauncher {
	[System.STAThread]
	private static int Main(string[] args) {
		using (System.IO.Stream stream = typeof(PS12ExeLauncher).Assembly.GetManifestResourceStream("main"))
		using (System.IO.Stream gzip = new System.IO.Compression.GZipStream(stream, System.IO.Compression.CompressionMode.Decompress))
		using (System.IO.MemoryStream buffer = new System.IO.MemoryStream()) {
			gzip.CopyTo(buffer);
			System.Reflection.Assembly payload = System.Reflection.Assembly.Load(buffer.ToArray());
			object result = payload.EntryPoint.Invoke(null, new object[] { args });
			return result is int ? (int)result : 0;
		}
	}
}
