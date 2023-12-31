@{
	# UI
	ErrorHead        = "错误："
	CompileResult    = "编译结果"
	DefaultResult    = "完成！"
	AskSaveCfg       = "需要保存配置文件吗？"
	AskSaveCfgTitle  = "保存配置文件"
	CfgFileLabelHead = "配置文件："
	# Console
	GUIHelpData      = @{
		title      = "用法：
ps12exeGUI [[-ConfingFile] '<配置文件>'] [-Localize '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfingFile = "要加载的配置文件。"
			Localize    = "要使用的语言代码。"
			UIMode      = "要使用的用户界面模式。"
			help        = "显示此帮助信息。"
		}
	}
	ConsoleHelpData  = @{
		title      = "用法：
[input |] ps12exe [[-inputFile] '<文件名|url>' | -Content '<脚本>'] [-outputFile '<文件名>']
        [-CompilerOptions '<选项>'] [-TempDir '<文件夹>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<文件名|url>'; title='<标题>'; description='<简介>'; company='<公司>';
        product='<产品>'; copyright='<版权>'; trademark='<水印>'; version='<版本>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]"
		PrarmsData = [ordered]@{
			input            = "PowerShell脚本文件内容的字符串，与-Content相同。"
			inputFile        = "您想要转换为可执行文件的PowerShell脚本文件路径或URL（文件必须是UTF8或UTF16编码）"
			Content          = "您想要转换为可执行文件的PowerShell脚本内容"
			outputFile       = "目标可执行文件名或文件夹，默认为带有'.exe'扩展名的inputFile"
			CompilerOptions  = "额外的编译器选项（参见https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）"
			TempDir          = "存储临时文件的目录（默认为%temp%中随机生成的临时目录）"
			minifyer         = "在编译之前缩小脚本的脚本块"
			lcid             = "编译的可执行文件的位置ID。如果未指定，则为当前用户文化"
			prepareDebug     = "创建有助于调试的信息"
			architecture     = "仅为特定运行时编译。可能的值为'x64'，'x86'和'anycpu'"
			threadingModel   = "'单线程公寓'或'多线程公寓'模式"
			noConsole        = "生成的可执行文件将是一个没有控制台窗口的Windows Forms应用程序"
			UNICODEEncoding  = "在控制台模式下将输出编码为UNICODE"
			credentialGUI    = "在控制台模式下使用GUI提示凭据"
			resourceParams   = "包含编译的可执行文件的资源参数的哈希表"
			configFile       = "写一个配置文件（<outputfile>.exe.config）"
			noOutput         = "生成的可执行文件将不生成标准输出（包括详细和信息通道）"
			noError          = "生成的可执行文件将不生成错误输出（包括警告和调试通道）"
			noVisualStyles   = "禁用生成的Windows GUI应用程序的视觉样式（仅与-noConsole一起使用）"
			exitOnCancel     = '当在Read-Host输入框中选择Cancel或“X”时退出程序（仅与-noConsole一起使用）'
			DPIAware         = "如果启用了显示缩放，GUI控件将尽可能进行缩放"
			winFormsDPIAware = "如果启用了显示缩放，WinForms将使用DPI缩放（需要Windows 10和.Net 4.7或更高版本）"
			requireAdmin     = "如果启用了UAC，编译的可执行文件只能在提升的上下文中运行（如果需要，会出现UAC对话框）"
			supportOS        = "使用最新Windows版本的功能（执行[Environment]::OSVersion以查看差异）"
			virtualize       = "已激活应用程序虚拟化（强制x86运行时）"
			longPaths        = "如果在OS上启用，启用长路径（> 260个字符）（仅适用于Windows 10或更高版本）"
		}
	}
}
