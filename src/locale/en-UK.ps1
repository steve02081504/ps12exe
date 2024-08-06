@{
	LangName = "English (United Kingdom)"
	LangID = "en-UK"
	# Right click Menu
	CompileTitle		   = "Compile To EXE"
	OpenInGUI			   = "Open in ps12exeGUI"
	GUICfgFileDesc		   = "ps12exeGUI configuration file"
	# Web Server
	ServerStarted		   = "HTTP server started!"
	ServerStopped		   = "HTTP server stopped!"
	ServerStartFailed	   = "Failed to start HTTP server!"
	TryRunAsRoot		   = "Please try again as root."
	ServerListening		   = "Access address:"
	ExitServerTip		   = "You can press Ctrl+C to exit the server at any time."
	# GUI
	ErrorHead			   = "Oh dear, an error has occurred:"
	CompileResult		   = "The result of the compilation, old chap:"
	DefaultResult		   = "All done and dusted!"
	AskSaveCfg			   = "Would you be so kind as to save the configuration file?"
	AskSaveCfgTitle		   = "Save the configuration file, if you please"
	CfgFileLabelHead	   = "Configuration file, my good sir:"
	# Console
	WebServerHelpData	   = @{
		title	   = "Usage:"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<path>']
	[-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "The HTTP server address to register."
			MaxCompileThreads = "The maximum number of compile threads."
			MaxCompileTime	  = "The maximum compile time in seconds."
			ReqLimitPerMin	  = "The maximum number of requests per minute per IP."
			MaxCachedFileSize = "The maximum size of the cached file."
			MaxScriptFileSize = "The maximum size of the script file."
			CacheDir		  = "The directory to store the cached files."
			Localize		  = "The language code to be used for server-side logging."
			help			  = "Display this help information."
		}
	}
	GUIHelpData			   = @{
		title	   = "Usage:"
		Usage	   = "ps12exeGUI [[-ConfigFile] '<filename>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfigFile	= "The configuration file to load."
			Localize	= "The language code to use."
			UIMode		= "The UI mode to use."
			help		= "Show this help message."
		}
	}
	SetContextMenuHelpData = @{
		title	   = "Usage:"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<语言代码>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "The action to execute."
			Localize = "The language code to use."
			help	 = "Show this help message."
		}
	}
	ConsoleHelpData		   = @{
		title	   = "Usage:"
		Usage	   = "[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
	[-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
	product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Runtime>']
	[-GuestMode] [-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "String of the contents of the powershell script file, same as ``-Content``."
			inputFile		 = "Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded)"
			Content			 = "Powershell script content that you want to convert to executable"
			outputFile		 = "destination executable file name or folder, defaults to inputFile with extension ``'.exe'``"
			CompilerOptions	 = "additional compiler options (see ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)"
			TempDir			 = "directory for storing temporary files (default is random generated temp directory in ``%temp%``)"
			minifyer		 = "scriptblock to minify the script before compiling"
			lcid			 = "location ID for the compiled executable. Current user culture if not specified"
			prepareDebug	 = "create helpful information for debugging"
			architecture	 = "compile for specific runtime only. Possible values are ``'x64'`` and ``'x86'`` and ``'anycpu'``"
			threadingModel	 = "``'Single Thread Apartment'`` or ``'Multi Thread Apartment'`` mode"
			noConsole		 = "the resulting executable will be a Windows Forms app without a console window"
			UNICODEEncoding	 = "encode output as UNICODE in console mode"
			credentialGUI	 = "use GUI for prompting credentials in console mode"
			resourceParams	 = "A hashtable that contains resource parameters for the compiled executable"
			configFile		 = "write a config file (``<outputfile>.exe.config``)"
			noOutput		 = "the resulting executable will generate no standard output (includes verbose and information channel)"
			noError			 = "the resulting executable will generate no error output (includes warning and debug channel)"
			noVisualStyles	 = "disable visual styles for a generated windows GUI application (only with ``-noConsole``)"
			exitOnCancel	 = "exits program when ``Cancel`` or ``""X""`` is selected in a ``Read-Host`` input box (only with ``-noConsole``)"
			DPIAware		 = "if display scaling is activated, GUI controls will be scaled if possible"
			winFormsDPIAware = "if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up)"
			requireAdmin	 = "if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)"
			supportOS		 = "use functions of newest Windows versions (execute ``[Environment]::OSVersion`` to see the difference)"
			virtualize		 = "application virtualization is activated (forcing x86 runtime)"
			longPaths		 = "enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)"
			targetRuntime	 = "target runtime version, 'Framework4.0' by default, 'Framework2.0' are supported"
			GuestMode		 = "Compile scripts with additional protection, prevent native files from being accessed"
			Localize		 = "The language code to use"
			Help			 = "Show this help message"
		}
	}
	CompilingI18nData = @{
		NoneInput = "No input file specified!"
		BothInputAndContentSpecified = "Input file and content cannot be used at the same time!"
		PreprocessDone = "Done preprocess input script"
		PreprocessedScriptSize = "Preprocessed script -> {0} bytes"
		MinifyingScript = "Minifying script..."
		MinifyedScriptSize = "Minified script -> {0} bytes"
		MinifyerError = "Minifyer error: {0}"
		MinifyerFailedUsingOriginalScript = "Minifyer failed, using original script."
		TempFileMissing = "Temporary file {0} not found!"
		CombinedArg_x86_x64 = "-x86 cannot be combined with -x64"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 cannot be combined with -runtime40"
		CombinedArg_Runtime20_LongPaths = "Long paths are only available with .Net 4 or above"
		CombinedArg_Runtime20_winFormsDPIAware = "DPI aware is only available with .Net 4 or above"
		CombinedArg_STA_MTA = "-STA cannot be combined with -MTA"
		InvalidResourceParam = "Parameter -resourceParams has an invalid key: {0}"
		CombinedArg_ConfigFileYes_No = "-configFile cannot be combined with -noConfigFile"
		InputSyntaxError = "Syntax error in script!"
		SyntaxErrorLineStart = "At line {0}, Col {1}:"
		IdenticalInputOutput = "Input file is identical to output file!"
		CombinedArg_Virtualize_requireAdmin = "-virtualize cannot be combined with -requireAdmin"
		CombinedArg_Virtualize_supportOS = "-virtualize cannot be combined with -supportOS"
		CombinedArg_Virtualize_longPaths = "-virtualize cannot be combined with -longPaths"
		CombinedArg_NoConfigFile_LongPaths = "Forcing generation of a config file, since the option -longPaths requires this"
		CombinedArg_NoConfigFile_winFormsDPIAware = "Forcing generation of a config file, since the option -winFormsDPIAware requires this"
		SomeCmdletsMayNotAvailable = "Cmdlets {0} used but may not available in runtime, make sure you've checked it!"
		SomeNotFindedCmdlets = "Unknown functions {0} used"
		SomeTypesMayNotAvailable = "Types {0} used but may not available in runtime, make sure you've checked it!"
		CompilingFile = "Compiling file..."
		CompilationFailed = "Compilation failed!"
		OutputFileNotWritten = "Output file {0} not written"
		CompiledFileSize = "Compiled file written -> {0} bytes"
		OppsSomethingWentWrong = "Opps, something went wrong."
		TryUpgrade = "Latest version is {0}, try upgrading to it?"
		EnterToSubmitIssue = "For help, please submit an issue by pressing Enter."
		GuestModeFileTooLarge = "The file {0} is too large to read."
		GuestModeIconFileTooLarge = "The icon {0} is too large to read."
		GuestModeFtpNotSupported = "FTP is not supported in GuestMode."
		IconFileNotFound = "Icon file not found: {0}"
		ReadFileFailed = "Failed to read file: {0}"
		PreprocessUnknownIfCondition = "Unknown condition: {0}`nassuming false."
		PreprocessMissingEndIf = "Missing end of if statement: {0}"
		ConfigFileCreated = "Config file for EXE created"
		SourceFileCopied = "Source file name for debug copied: {0}"
		RoslynFailedFallback = "Roslyn CodeAnalysis failed`nFalling back to Use Windows Powershell with CodeDom...`nYou may want to add -UseWindowsPowerShell to args to skip this fallback in future.`n...or submit a PR to ps12exe repo to fix this!"
		ReadingFile = "Reading file {0} size {1} bytes"
		ForceX86byVirtualization = "Application virtualization is activated, forcing x86 platfom."
		TryingTinySharpCompile = "Const result, trying TinySharp Compiler..."
		TinySharpFailedFallback = "TinySharp Compiler error, fail back to normal program frame"
		OutputPath = "Path: {0}"
		ReadingScriptDone = "Done reading file {0}, starting preprocess..."
		PreprocessScriptDone = "Done preprocess file {0}"
		ConstEvalStart = "Evaluation of constants..."
		ConstEvalDone = "Done evaluation of constants -> {0} bytes"
		ConstEvalTooLongFallback = "Const result is too long, fail back to normal program frame"
		ConstEvalTimeoutFallback = "Evaluation timed out after {0} seconds, fail back to normal program frame"
		InvalidArchitecture = "Invalid platform {0}, using AnyCpu"
		UnknownPragma = "Unknown pragma: {0}"
		UnknownPragmaBadParameterType = "Unknown pragma: {0}, as type {1} can't analyze."
		UnknownPragmaBoolValue = "Unknown pragma value: {0}, cannot take is as a boolean."
		DllExportDelNoneTypeArg = "{0}: {1} is none type parameter, assume it's string."
		DllExportUsing = "You are using #_DllExport, this marco is in dev and not support yet."
	}
	WebServerI18nData = @{
		CompilingUserInput = "Compiling User Input: {0}"
		EmptyResponse = "No data found when Handling Request, returning empty response"
		InputTooLarge413 = "User Input is too large, returning 413 error"
		ReqLimitExceeded429 = "IP {0} has exceeded the limit of {1} requests per minute, returning 429 error"
	}
}
