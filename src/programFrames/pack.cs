// 默认（压缩）非 const 构建的 launcher。ps12exe 把真正的托管程序集压缩后作为 "main" 资源塞进这个 launcher，launcher 启动时在内存里解压、Assembly.Load 后调用负载的入口点，负载不落盘。Windows PowerShell（CodeDom）下负载用 gzip，PowerShell Core 下用 Brotli（.NET Framework 不提供 BrotliStream）；打包时若 LZMA 能显著压得更小（并算上自带解码器的体积后仍更小），则改用 CodecLzma 分支（LzmaCodec 随 LzmaDecode.cs 一起编入）。资源/版本属性在打包时由本 launcher 携带（公共源 src/programFrames/AssemblyInfo.cs，见 CodeDomCompiler.ps1 / Core 的 csproj）。
/*__ASSEMBLY_ATTRIBUTES__*/
internal static class Launcher {
	[System.STAThread]
	static int Main(string[] args) {
		using (System.IO.Stream stream = typeof(Launcher).Assembly.GetManifestResourceStream("main"))
		#if CodecLzma
			using (System.IO.Stream decompressed = LzmaCodec.DecompressStream(stream))
		#elif CoreHost
			using (System.IO.Stream decompressed = new System.IO.Compression.BrotliStream(stream, System.IO.Compression.CompressionMode.Decompress))
		#else
			using (System.IO.Stream decompressed = new System.IO.Compression.GZipStream(stream, System.IO.Compression.CompressionMode.Decompress))
		#endif
		using (System.IO.MemoryStream buffer = new System.IO.MemoryStream()) {
			decompressed.CopyTo(buffer);
			System.Reflection.Assembly payload = System.Reflection.Assembly.Load(buffer.ToArray());
			object result = payload.EntryPoint.Invoke(null, new object[] { args });
			return result is int ? (int)result : 0;
		}
	}
}
