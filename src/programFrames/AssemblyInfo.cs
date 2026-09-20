// ps12exe 在“最外层”程序集上编译时附加的资源/版本属性（见 src/BuildFrame.ps1 的 $resourceAttributes）。
// 这些元数据只对最终 exe 有意义：打包时由 launcher(pack.cs) 携带，直编时由自身(default.cs/constexpr.cs)携带；
// 内存负载 payload 把帧里的标记替换为空，所以帧本身不随资源参数变化。$placeholder 由 ps12exe 替换。
// 注意：本片段会被插入到各帧 using 之后，因此这里不写 using、属性一律用全限定名。
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
