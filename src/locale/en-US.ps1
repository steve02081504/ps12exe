@{
	LangName = "English (United States)"
	LangID = "en-US"
	# Right click Menu
	CompileTitle		   = "Compile to EXE"
	OpenInGUI			   = "Open in ps12exeGUI"
	GUICfgFileDesc		   = "ps12exeGUI config file"
	# Web Server
	ServerStarted		   = "HTTP server's up and runnin'!"
	ServerStopped		   = "HTTP server's shut down."
	ServerStartFailed	   = "Failed to start the HTTP server!"
	TryRunAsRoot		   = "Try runnin' it as root."
	ServerListening		   = "Address for access:"
	ExitServerTip		   = "You can hit Ctrl+C to shut down the server anytime."
	# GUI
	ErrorHead			   = "Whoa, we got an error:"
	CompileResult		   = "Compile result:"
	DefaultResult		   = "All done!"
	AskSaveCfg			   = "Save the config file?"
	AskSaveCfgTitle		   = "Save config file"
	CfgFileLabelHead	   = "Configuration file:"
	# Console
	WebServerHelpData	   = @{
		title	   = "Usage:"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<path>']
	[-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "The HTTP server address."
			MaxCompileThreads = "Max number of compile threads."
			MaxCompileTime	  = "Max compile time in seconds."
			ReqLimitPerMin	  = "Max number of requests per minute per IP."
			MaxCachedFileSize = "Max size of cached files."
			MaxScriptFileSize = "Max size of script files."
			CacheDir		  = "Directory to store cached files."
			Localize		  = "Language code for server-side loggin'."
			help			  = "Show this here help info."
		}
	}
	GUIHelpData			   = @{
		title	   = "Usage:"
		Usage	   = @"
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
"@
		PrarmsData = [ordered]@{
			ConfigFile	= "Configuration file to load."
			PS1File		= "Script file to compile."
			Localize	= "Language code to use."
			UIMode		= "UI mode, dark or light."
			help		= "Show this help message."
		}
	}
	SetContextMenuHelpData = @{
		title	   = "Usage:"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "Action to execute."
			Localize = "Language code."
			help	 = "Show this here help."
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
	[-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "String of the PowerShell script file's contents, same as ``-Content``."
			inputFile		 = "PowerShell script file path or URL you wanna convert to an executable (file must be UTF8 or UTF16 encoded)."
			Content			 = "PowerShell script content you wanna convert to an executable."
			outputFile		 = "Destination executable file name or folder, defaults to ``inputFile`` with ``'.exe'`` added on."
			CompilerOptions	 = "Extra compiler options (see ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)."
			TempDir			 = "Directory for temp files (default is a randomly generated temp directory in ``%temp%``)."
			minifyer		 = "Scriptblock to minify the script before compiling."
			lcid			 = "Location ID for the compiled executable. Current user culture if nothin's specified."
			prepareDebug	 = "Creates info to help with debugging."
			architecture	 = "Compile for a specific runtime. Possible values are ``'x64'``, ``'x86'``, and ``'anycpu'``."
			threadingModel	 = "``'Single Thread Apartment'`` or ``'Multi Thread Apartment'`` mode."
			noConsole		 = "The resulting executable will be a Windows Forms app without a console window."
			UNICODEEncoding	 = "Encode output as UNICODE in console mode."
			credentialGUI	 = "Use a GUI to prompt for credentials in console mode."
			resourceParams	 = "A hashtable with resource parameters for the executable."
			configFile		 = "Write a config file (``<outputfile>.exe.config``)."
			noOutput		 = "The resulting executable won't generate standard output (verbose and info included)."
			noError			 = "The resulting executable won't generate error output (warnings and debug included)."
			noVisualStyles	 = "Disable visual styles for a generated GUI app (only with ``-noConsole``)."
			exitOnCancel	 = "Exits the program when ``Cancel`` or ``'X'`` is selected in a ``Read-Host`` input box (only with ``-noConsole``)."
			DPIAware		 = "If display scaling is on, GUI controls will be scaled if possible."
			winFormsDPIAware = "If display scaling is on, WinForms uses DPI scaling (requires Windows 10 and .NET 4.7 or up)."
			requireAdmin	 = "If UAC is enabled, the compiled executable runs only in an elevated context (UAC dialog appears)."
			supportOS		 = "Use functions of the newest Windows versions (run ``[Environment]::OSVersion`` to see the difference)."
			virtualize		 = "App virtualization is activated (forcing x86 runtime)."
			longPaths		 = "Enable long paths ( > 260 characters) if enabled on the OS (Windows 10 or up)."
			targetRuntime	 = "Target runtime version, ``'Framework4.0'`` by default, ``'Framework2.0'`` is supported."
			SkipVersionCheck = "Skip the check for new versions of ps12exe"
			GuestMode		 = "Compile scripts with extra protection, preventin' native files from being accessed."
			PreprocessOnly	 = "Preprocess the input script and return it without compiling."
			GolfMode		 = "Enable golf mode, adding abbreviations and common functions."
			Localize		 = "Language code."
			Help			 = "Show this here help message."
		}
	}
	CompilingI18nData = @{
		NewVersionAvailable = "There's a new version of ps12exe available: {0}!"
		NoneInput = "No input file specified!"
		BothInputAndContentSpecified = "Input file and content can't be used at the same time."
		PreprocessDone = "Done pre-processing the input script!"
		PreprocessedScriptSize = "Preprocessed script -> {0} bytes."
		MinifyingScript = "Minifying the script..."
		MinifyedScriptSize = "Minified script -> {0} bytes."
		MinifyerError = "Minifyer error: {0}"
		MinifyerFailedUsingOriginalScript = "Minifyer failed, using the original script."
		TempFileMissing = "Temporary file {0} not found."
		PreprocessOnlyDone = "Done pre-processing the input script."
		CombinedArg_x86_x64 = "-x86 can't be combined with -x64."
		CombinedArg_Runtime20_Runtime40 = "-runtime20 can't be combined with -runtime40."
		CombinedArg_Runtime20_LongPaths = "Long paths are only available with .NET 4 or above."
		CombinedArg_Runtime20_winFormsDPIAware = "DPI awareness is only available with .NET 4 or above."
		CombinedArg_STA_MTA = "-STA can't be combined with -MTA."
		InvalidResourceParam = "Parameter -resourceParams has an invalid key: {0}"
		CombinedArg_ConfigFileYes_No = "-configFile can't be combined with -noConfigFile."
		InputSyntaxError = "Syntax error in the script."
		SyntaxErrorLineStart = "At line {0}, Col {1}:"
		IdenticalInputOutput = "Input file is the same as the output file."
		CombinedArg_Virtualize_requireAdmin = "-virtualize can't be combined with -requireAdmin."
		CombinedArg_Virtualize_supportOS = "-virtualize can't be combined with -supportOS."
		CombinedArg_Virtualize_longPaths = "-virtualize can't be combined with -longPaths."
		CombinedArg_NoConfigFile_LongPaths = "Forcing config file generation, since -longPaths needs it."
		CombinedArg_NoConfigFile_winFormsDPIAware = "Forcing config file generation, since -winFormsDPIAware needs it."
		SomeCmdletsMayNotAvailable = "Cmdlets {0} are used but might not be available."
		SomeNotFindedCmdlets = "Unknown functions {0} are used."
		SomeTypesMayNotAvailable = "Types {0} are used but might not be available at runtime."
		CompilingFile = "Compiling file..."
		CompilationFailed = "Compilation failed!"
		OutputFileNotWritten = "Output file {0} not written."
		CompiledFileSize = "Compiled file written -> {0} bytes."
		OppsSomethingWentWrong = "Whoops, somethin' went wrong."
		TryUpgrade = "Latest version is {0}, try upgradin'."
		EnterToSubmitIssue = "For help, submit an issue by pressing Enter."
		GuestModeFileTooLarge = "File {0} is too large to read."
		GuestModeIconFileTooLarge = "Icon {0} is too large to read."
		GuestModeFtpNotSupported = "FTP ain't supported in GuestMode."
		IconFileNotFound = "Icon file not found: {0}"
		ReadFileFailed = "Failed to read file: {0}"
		PreprocessUnknownIfCondition = "Unknown condition: {0}; assuming false."
		PreprocessMissingEndIf = "Missing end of if statement: {0}"
		ConfigFileCreated = "Config file for the EXE created."
		SourceFileCopied = "Source file name for debugging copied: {0}"
		RoslynFailedFallback = "Roslyn CodeAnalysis failed. Fallin' back to using Windows PowerShell with CodeDom...\nYou might wanna add -UseWindowsPowerShell to args to skip this fallback in the future.\n... or submit a PR to the ps12exe repo to fix it!"
		ReadingFile = "Reading file {0}, size {1} bytes."
		ForceX86byVirtualization = "App virtualization activated, forcing x86 platform."
		TryingTinySharpCompile = "Const result, trying TinySharp Compiler..."
		TinySharpFailedFallback = "TinySharp Compiler error, falling back to the normal program frame."
		OutputPath = "Path: {0}"
		ReadingScriptDone = "Done reading file {0}, startin' preprocessing..."
		PreprocessScriptDone = "Done preprocessing file {0}."
		ConstEvalStart = "Evaluation of constants..."
		ConstEvalDone = "Done evaluating constants -> {0} bytes."
		ConstEvalTooLongFallback = "Constant result too long, falling back to the normal program frame."
		ConstEvalTimeoutFallback = "Evaluation timed out after {0} seconds, falling back to the normal program frame."
		ConstEvalThrowErrorFallback = "Constant result throws an error, falling back to the normal program frame."
		InvalidArchitecture = "Invalid platform {0}, using AnyCpu."
		UnknownPragma = "Unknown pragma: {0}"
		UnknownPragmaBadParameterType = "Unknown pragma: {0}, type {1} can't be analyzed."
		UnknownPragmaBoolValue = "Unknown pragma value: {0}, can't use that as a boolean."
		DllExportDelNoneTypeArg = "{0}: {1} is a none type parameter, assuming it's a string."
		DllExportUsing = "You're using #_DllExport, this macro is in dev and not supported yet."
	}
	WebServerI18nData = @{
		CompilingUserInput = "Compiling User Input: {0}"
		EmptyResponse = "No data found when handling the request, returning an empty response."
		InputTooLarge413 = "User input is too large, returning a 413 error."
		ReqLimitExceeded429 = "IP {0} has exceeded the limit of {1} requests per minute, returning 429."
	}
}
