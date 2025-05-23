﻿@{
	LangName = "简体中文"
	LangID = "zh-CN"
	# Right click Menu
	CompileTitle		   = "编译到 EXE"
	OpenInGUI			   = "在 ps12exeGUI 中打开"
	GUICfgFileDesc		   = "ps12exe GUI 配置文件"
	# Web Server
	ServerStarted		   = "HTTP 服务器已启动！"
	ServerStopped		   = "HTTP 服务器已停止！"
	ServerStartFailed	   = "HTTP 服务器启动失败！"
	TryRunAsRoot		   = "请尝试以管理员身份运行。"
	ServerListening		   = "访问地址："
	ExitServerTip		   = "您随时可以按 Ctrl+C 退出服务器"
	# GUI
	ErrorHead			   = "错误："
	CompileResult		   = "编译结果"
	DefaultResult		   = "完成！"
	AskSaveCfg			   = "需要保存配置文件吗？"
	AskSaveCfgTitle		   = "保存配置文件"
	CfgFileLabelHead	   = "配置文件："
	# Console
	WebServerHelpData	   = @{
		title	   = "用法："
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<路径>']
	[-Localize '<语言代码>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "要注册的 HTTP 服务器地址。"
			MaxCompileThreads = "最大编译线程数。"
			MaxCompileTime	  = "最大编译时间（秒）。"
			ReqLimitPerMin	  = "每个IP每分钟的请求限制。"
			MaxCachedFileSize = "最大缓存文件大小。"
			MaxScriptFileSize = "最大脚本文件大小。"
			CacheDir		  = "缓存目录。"
			Localize		  = "服务器端记录要使用的语言代码。"
			help			  = "显示此帮助信息。"
		}
	}
	GUIHelpData			   = @{
		title	   = "用法："
		Usage	   = @"
ps12exeGUI [[-ConfigFile] '<配置文件>'] [-PS1File '<脚本文件>'] [-Localize '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<脚本文件>'] [-Localize '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
"@
		PrarmsData = [ordered]@{
			ConfigFile	= "要加载的配置文件。"
			PS1File		= "要编译的脚本文件。"
			Localize	= "要使用的语言代码。"
			UIMode		= "要使用的用户界面模式。"
			help		= "显示此帮助信息。"
		}
	}
	SetContextMenuHelpData = @{
		title	   = "用法："
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<语言代码>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "要执行的操作。"
			Localize = "要使用的语言代码。"
			help	 = "显示此帮助信息。"
		}
	}
	ConsoleHelpData		   = @{
		title	   = "用法："
		Usage	   = "[input |] ps12exe [[-inputFile] '<文件名|url>' | -Content '<脚本>'] [-outputFile '<文件名>']
	[-CompilerOptions '<选项>'] [-TempDir '<文件夹>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<文件名|url>'; title='<标题>'; description='<简介>'; company='<公司>';
	product='<产品>'; copyright='<版权>'; trademark='<水印>'; version='<版本>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<运行时版本>']
	[-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<语言代码>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "PowerShell脚本文件内容的字符串，与``-Content``相同。"
			inputFile		 = "您想要转换为可执行文件的PowerShell脚本文件路径或URL（文件必须是UTF8或UTF16编码）"
			Content			 = "您想要转换为可执行文件的PowerShell脚本内容"
			outputFile		 = "目标可执行文件名或文件夹，默认为带有``'.exe'``扩展名的``inputFile``"
			CompilerOptions	 = "额外的编译器选项（参见 ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``）"
			TempDir			 = "存储临时文件的目录（默认为``%temp%``中随机生成的临时目录）"
			minifyer		 = "在编译之前缩小脚本的脚本块"
			lcid			 = "编译的可执行文件的位置ID。如果未指定，则为当前用户文化"
			prepareDebug	 = "创建有助于调试的信息"
			architecture	 = "仅为特定运行时编译。可能的值为``'x64'``，``'x86'``和``'anycpu'``"
			threadingModel	 = "``'单线程单元'``或``'多线程单元'``模式"
			noConsole		 = "生成的可执行文件将是一个没有控制台窗口的Windows Forms应用程序"
			UNICODEEncoding	 = "在控制台模式下将输出编码为UNICODE"
			credentialGUI	 = "在控制台模式下使用GUI提示凭据"
			resourceParams	 = "包含编译的可执行文件的资源参数的哈希表"
			configFile		 = "写一个配置文件（``<outputfile>.exe.config``）"
			noOutput		 = "生成的可执行文件将不生成标准输出（包括详细和信息通道）"
			noError			 = "生成的可执行文件将不生成错误输出（包括警告和调试通道）"
			noVisualStyles	 = "禁用生成的Windows GUI应用程序的视觉样式（仅与``-noConsole``一起使用）"
			exitOnCancel	 = "当在``Read-Host``输入框中选择``Cancel``或``'X'``时退出程序（仅与``-noConsole``一起使用）"
			DPIAware		 = "如果启用了显示缩放，GUI控件将尽可能进行缩放"
			winFormsDPIAware = "如果启用了显示缩放，WinForms将使用DPI缩放（需要Windows 10和.Net 4.7或更高版本）"
			requireAdmin	 = "如果启用了UAC，编译的可执行文件只能在提升的上下文中运行（如果需要，会出现UAC对话框）"
			supportOS		 = "使用最新Windows版本的功能（执行``[Environment]::OSVersion``以查看差异）"
			virtualize		 = "已激活应用程序虚拟化（强制x86运行时）"
			longPaths		 = "如果在OS上启用，启用长路径（> 260个字符）（仅适用于Windows 10或更高版本）"
			targetRuntime	 = "目标运行时版本，默认为 ``'Framework4.0'``，支持 ``'Framework2.0'``"
			SkipVersionCheck = "跳过ps12exe的新版本检查"
			GuestMode		 = "在额外的保护下编译脚本，避免本机文件被访问"
			PreprocessOnly	 = "预处理输入脚本并在不编译的情况下返回它"
			GolfMode		 = "启用golf模式，添加缩写和常用函数"
			Localize		 = "指定本地化语言"
			Help			 = "显示此帮助信息"
		}
	}
	CompilingI18nData = @{
		NewVersionAvailable = "ps12exe有了新版本：{0}！"
		NoneInput = "无输入！"
		BothInputAndContentSpecified = "不能同时输入文件和内容！"
		PreprocessDone = "预处理输入脚本完成"
		PreprocessedScriptSize = "预处理脚本 -> {0}字节"
		MinifyingScript = "正在压缩脚本..."
		MinifyedScriptSize = "压缩脚本 -> {0}字节"
		MinifyerError = "压缩器错误：{0}"
		MinifyerFailedUsingOriginalScript = "压缩器失败，使用原始脚本。"
		TempFileMissing = "找不到临时文件{0}！"
		PreprocessOnlyDone = "预处理完成"
		CombinedArg_x86_x64 = "-x86 不能与 -x64 一起使用"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 不能与 -runtime40 一起使用"
		CombinedArg_Runtime20_LongPaths = ".Net 4 或更高版本才支持长路径"
		CombinedArg_Runtime20_winFormsDPIAware = ".Net 4 或更高版本才支持 DPI 识别"
		CombinedArg_STA_MTA = "-STA 不能与 -MTA 一起使用"
		InvalidResourceParam = "参数 -resourceParams 的无效Key：{0}"
		CombinedArg_ConfigFileYes_No = "-configFile 不能与 -noConfigFile 一起使用"
		InputSyntaxError = "脚本语法错误！"
		SyntaxErrorLineStart = "第{0}行 第{1}列："
		IdenticalInputOutput = "输入文件与输出文件相同！"
		CombinedArg_Virtualize_requireAdmin = "-virtualize 不能与 -requireAdmin 一起使用"
		CombinedArg_Virtualize_supportOS = "-virtualize 不能与 -supportOS 一起使用"
		CombinedArg_Virtualize_longPaths = "-virtualize 不能与 -longPaths 一起使用"
		CombinedArg_NoConfigFile_LongPaths = "强制生成配置文件，因为选项 -longPaths 需要此配置文件"
		CombinedArg_NoConfigFile_winFormsDPIAware = "强制生成配置文件，因为选项 -winFormsDPIAware 需要此配置文件"
		SomeCmdletsMayNotAvailable = "使用了可能会在运行时不可用的命令 {0}，确保已检查它们！"
		SomeNotFindedCmdlets = "使用了未知的命令 {0}"
		SomeTypesMayNotAvailable = "使用了可能会在运行时不可用的类型 {0}，确保已检查它们！"
		CompilingFile = "编译中..."
		CompilationFailed = "编译失败！"
		OutputFileNotWritten = "未写入输出文件 {0}"
		CompiledFileSize = "已编译文件 -> {0}字节"
		OppsSomethingWentWrong = "我去，出错了。"
		TryUpgrade = "最新版本是{0}，尝试升级?"
		EnterToSubmitIssue = "如需帮助，按回车提交issue。"
		GuestModeFileTooLarge = "文件{0}太大，无法读取。"
		GuestModeIconFileTooLarge = "图标{0}太大，无法读取。"
		GuestModeFtpNotSupported = "访客模式不支持FTP。"
		IconFileNotFound = "找不到图标文件：{0}"
		ReadFileFailed = "读取文件失败：{0}"
		PreprocessUnknownIfCondition = "未知条件：{0}`n假定为 false."
		PreprocessMissingEndIf = "缺少endif：{0}"
		ConfigFileCreated = "创建了 EXE 的配置文件"
		SourceFileCopied = "已复制用于调试的源文件名：{0}"
		RoslynFailedFallback = "Roslyn编译失败`n正在回退到使用带有CodeDom的Windows PowerShell...`n你可能想要在将来将 -UseWindowsPowerShell 添加到参数中以跳过此回退`n...或提交 PR 到 ps12exe 仓库来修复此问题！"
		ReadingFile = "正在读取{0}，{1}字节"
		ForceX86byVirtualization = "已激活应用程序虚拟化，强制使用x86平台。"
		TryingTinySharpCompile = "结果为常量，尝试 TinySharp 编译器..."
		TinySharpFailedFallback = "TinySharp 编译器错误，退回正常程序框架"
		OutputPath = "路径：{0}"
		ReadingScriptDone = "读取{0}完成，正在开始预处理..."
		PreprocessScriptDone = "预处理{0}完成"
		ConstEvalStart = "正在计算常量..."
		ConstEvalDone = "计算常量完成 -> {0}字节"
		ConstEvalTooLongFallback = "常量结果太长，退回正常程序框架"
		ConstEvalTimeoutFallback = "常量计算{0}秒，超时。退回正常程序框架"
		ConstEvalThrowErrorFallback = "常量计算抛出错误，退回正常程序框架"
		InvalidArchitecture = "无效的平台 {0}，使用 AnyCpu"
		UnknownPragma = "未知的 pragma：{0}"
		UnknownPragmaBadParameterType = "未知的pragma：{0}，无法分析类型{1}。"
		UnknownPragmaBoolValue = "未知的pragma值：{0}，无法将其视为bool。"
		DllExportDelNoneTypeArg = "{0}：{1}是无类型参数，假设它是字符串。"
		DllExportUsing = "您正在使用 #_DllExport，此宏尚在开发中，尚未支持。"
	}
	WebServerI18nData = @{
		CompilingUserInput = "正在编译用户输入：{0}"
		EmptyResponse = "处理请求时未找到数据，返回空响应"
		InputTooLarge413 = "用户输入太大，返回413错误"
		ReqLimitExceeded429 = "IP {0} 超过每分钟{1}次请求的限制，返回429错误"
	}
}
