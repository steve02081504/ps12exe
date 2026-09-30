using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;

/*__ASSEMBLY_ATTRIBUTES__*/
namespace PSRunnerNS {
	// 压缩版原生 DLL 导出的 launcher（见 src/DllExportCompiler.ps1 与 docs/dev/compiler-internals.md#dllexport）。
	// 内嵌 gzip(payload) 作为 "main" 资源：静态构造在任何导出方法执行前由 CLR 保证只跑一次，此时在内存里解压并
	// Assembly.Load 出真正的实现程序集，再挂 AssemblyResolve 让下面生成的转发包装直接静态调用它。
	// 因此每个导出调用没有任何额外检查/加锁，只有一次 native→managed 跳转。
	public static class PS12ExeDllPack {
		static PS12ExeDllPack() {
			Assembly payload;
			using (Stream stream = typeof(PS12ExeDllPack).Assembly.GetManifestResourceStream("main"))
			using (Stream decompressed = new GZipStream(stream, CompressionMode.Decompress))
			using (MemoryStream buffer = new MemoryStream()) {
				decompressed.CopyTo(buffer);
				payload = Assembly.Load(buffer.ToArray());
			}
			string payloadName = payload.GetName().Name;
			AppDomain.CurrentDomain.AssemblyResolve += delegate(object sender, ResolveEventArgs e) {
				return (e.Name == payloadName || e.Name.StartsWith(payloadName + ",", StringComparison.OrdinalIgnoreCase)) ? payload : null;
			};
		}
		/*__PS12EXE_DLL_EXPORTS__*/
	}
}
