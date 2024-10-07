@{
	LangName = "English (United Kingdom)"
	LangID = "en-UK"
	# Right click Menu
	CompileTitle		   = "Compile To EXE"
	OpenInGUI			   = "Open in ps12exeGUI"
	GUICfgFileDesc		   = "ps12exeGUI configuration file"
	# Web Server, by Jove!
	ServerStarted		   = "HTTP server started! Jolly good!"
	ServerStopped		   = "HTTP server stopped! Right then."
	ServerStartFailed	   = "Failed to start HTTP server! Blimey!"
	TryRunAsRoot		   = "Please try again as root, old bean."
	ServerListening		   = "Access address, my good fellow:"
	ExitServerTip		   = "You can press Ctrl+C to exit the server at any time, a rather handy feature."
	# GUI, top-hole!
	ErrorHead			   = "Oh dear, I say, an error has occurred, how frightfully inconvenient:"
	CompileResult		   = "The result of the compilation, old chap, rather impressive:"
	DefaultResult		   = "All done and dusted! Splendid!"
	AskSaveCfg			   = "Would you be so kind as to save the configuration file, terribly important, you see."
	AskSaveCfgTitle		   = "Save the configuration file, if you please, wouldn't want to lose it, what?"
	CfgFileLabelHead	   = "Configuration file, my good sir, here you are:"
	# Console, old fruit
	WebServerHelpData	   = @{
		title	   = "Usage, my dear fellow:"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<path>']
	[-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "The HTTP server address to register, if you please."
			MaxCompileThreads = "The maximum number of compile threads, rather a technical term."
			MaxCompileTime	  = "The maximum compile time in seconds, time is of the essence, you see."
			ReqLimitPerMin	  = "The maximum number of requests per minute per IP, mustn't overdo it, old boy."
			MaxCachedFileSize = "The maximum size of the cached file, wouldn't want to clutter things up."
			MaxScriptFileSize = "The maximum size of the script file, keep it concise, I say."
			CacheDir		  = "The directory to store the cached files, a bit like a filing cabinet."
			Localize		  = "The language code to be used for server-side logging, terribly important for international relations."
			help			  = "Display this help information, should you require assistance."
		}
	}
	GUIHelpData			   = @{
		title	   = "Usage, my good sir:"
		Usage	   = @"
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
"@
		PrarmsData = [ordered]@{
			ConfigFile	= "The configuration file to load, terribly important, you know."
			PS1File		= "The script file to be compiled, the heart of the matter."
			Localize	= "The language code to use, for all you polyglots out there."
			UIMode		= "The UI mode to use, a matter of personal preference."
			help		= "Show this help message, should you get lost in the jungle of options."
		}
	}
	SetContextMenuHelpData = @{
		title	   = "Usage, chap:"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<language code>'] [-help], right then, let's get on with it."
		PrarmsData = [ordered]@{
			action	 = "The action to execute, terribly decisive."
			Localize = "The language code to use, for our international friends."
			help	 = "Show this help message, a helping hand, if you will."
		}
	}
	ConsoleHelpData		   = @{
		title	   = "Usage, my esteemed colleague:"
		Usage	   = "[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
	[-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
	product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Runtime>']
	[-GuestMode] [-Localize '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "String of the contents of the powershell script file, same as ``-Content``, rather straightforward."
			inputFile		 = "Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded), the raw materials, so to speak."
			Content			 = "Powershell script content that you want to convert to executable, the essence of the script."
			outputFile		 = "destination executable file name or folder, defaults to inputFile with extension ``'.exe'``, the finished product."
			CompilerOptions	 = "additional compiler options (see ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``), for the technically inclined."
			TempDir			 = "directory for storing temporary files (default is random generated temp directory in ``%temp%``), a bit like a scratchpad."
			minifyer		 = "scriptblock to minify the script before compiling, making it lean and mean."
			lcid			 = "location ID for the compiled executable. Current user culture if not specified, for our international clientele."
			prepareDebug	 = "create helpful information for debugging, should things go awry."
			architecture	 = "compile for specific runtime only. Possible values are ``'x64'`` and ``'x86'`` and ``'anycpu'``, a bit of technical jargon."
			threadingModel	 = "``'Single Thread Apartment'`` or ``'Multi Thread Apartment'`` mode, for the multi-tasking enthusiast."
			noConsole		 = "the resulting executable will be a Windows Forms app without a console window, a bit more discreet."
			UNICODEEncoding	 = "encode output as UNICODE in console mode, for those who appreciate a wider range of characters."
			credentialGUI	 = "use GUI for prompting credentials in console mode, a bit more user-friendly."
			resourceParams	 = "A hashtable that contains resource parameters for the compiled executable, adding a touch of personality."
			configFile		 = "write a config file (``<outputfile>.exe.config``), a bit like an instruction manual."
			noOutput		 = "the resulting executable will generate no standard output (includes verbose and information channel), keeping things quiet."
			noError			 = "the resulting executable will generate no error output (includes warning and debug channel), a bit like sweeping things under the rug."
			noVisualStyles	 = "disable visual styles for a generated windows GUI application (only with ``-noConsole``), a bit more spartan."
			exitOnCancel	 = "exits program when ``Cancel`` or ``""X""`` is selected in a ``Read-Host`` input box (only with ``-noConsole``), a bit more decisive."
			DPIAware		 = "if display scaling is activated, GUI controls will be scaled if possible, ensuring things look their best."
			winFormsDPIAware = "if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up), keeping things sharp."
			requireAdmin	 = "if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required), for those who like to be in control."
			supportOS		 = "use functions of newest Windows versions (execute ``[Environment]::OSVersion`` to see the difference), keeping up with the times."
			virtualize		 = "application virtualization is activated (forcing x86 runtime), a bit like living in a bubble."
			longPaths		 = "enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up), for those with lengthy filenames."
			targetRuntime	 = "target runtime version, 'Framework4.0' by default, 'Framework2.0' are supported, catering to different needs."
			GuestMode		 = "Compile scripts with additional protection, prevent native files from being accessed, keeping things secure."
			Localize		 = "The language code to use, for our international audience."
			Help			 = "Show this help message, should you require further elucidation."
		}
	}
	CompilingI18nData = @{
		NoneInput = "No input file specified, dash it all!"
		BothInputAndContentSpecified = "Input file and content cannot be used at the same time, terribly inconvenient!"
		PreprocessDone = "Done preprocess input script, spiffing!"
		PreprocessedScriptSize = "Preprocessed script -> {0} bytes, rather a lot, what?"
		MinifyingScript = "Minifying script..., making it nice and compact."
		MinifyedScriptSize = "Minified script -> {0} bytes, much better, eh?"
		MinifyerError = "Minifyer error: {0}, oh dear, something's gone wrong."
		MinifyerFailedUsingOriginalScript = "Minifyer failed, using original script, back to square one."
		TempFileMissing = "Temporary file {0} not found, most perplexing!"
		CombinedArg_x86_x64 = "-x86 cannot be combined with -x64, can't have it both ways, old boy."
		CombinedArg_Runtime20_Runtime40 = "-runtime20 cannot be combined with -runtime40, one or the other, I'm afraid."
		CombinedArg_Runtime20_LongPaths = "Long paths are only available with .Net 4 or above, a bit more modern, you see."
		CombinedArg_Runtime20_winFormsDPIAware = "DPI aware is only available with .Net 4 or above, keeping things sharp."
		CombinedArg_STA_MTA = "-STA cannot be combined with -MTA, a bit like oil and water."
		InvalidResourceParam = "Parameter -resourceParams has an invalid key: {0}, terribly careless."
		CombinedArg_ConfigFileYes_No = "-configFile cannot be combined with -noConfigFile, make up your mind, old chap."
		InputSyntaxError = "Syntax error in script, oh dear, a grammatical faux pas."
		SyntaxErrorLineStart = "At line {0}, Col {1}:, right there, you see."
		IdenticalInputOutput = "Input file is identical to output file, rather redundant, wouldn't you say?"
		CombinedArg_Virtualize_requireAdmin = "-virtualize cannot be combined with -requireAdmin, a bit of a contradiction."
		CombinedArg_Virtualize_supportOS = "-virtualize cannot be combined with -supportOS, can't have it both ways."
		CombinedArg_Virtualize_longPaths = "-virtualize cannot be combined with -longPaths, a bit of a limitation."
		CombinedArg_NoConfigFile_LongPaths = "Forcing generation of a config file, since the option -longPaths requires this, a necessary evil."
		CombinedArg_NoConfigFile_winFormsDPIAware = "Forcing generation of a config file, since the option -winFormsDPIAware requires this, for the sake of appearances."
		SomeCmdletsMayNotAvailable = "Cmdlets {0} used but may not available in runtime, make sure you've checked it, wouldn't want any nasty surprises."
		SomeNotFindedCmdlets = "Unknown functions {0} used, a bit mysterious, aren't they?"
		SomeTypesMayNotAvailable = "Types {0} used but may not available in runtime, make sure you've checked it, wouldn't want any type errors."
		CompilingFile = "Compiling file..., putting it all together."
		CompilationFailed = "Compilation failed, blast!"
		OutputFileNotWritten = "Output file {0} not written, most frustrating!"
		CompiledFileSize = "Compiled file written -> {0} bytes, quite a substantial size."
		OppsSomethingWentWrong = "Opps, something went wrong, how terribly unfortunate."
		TryUpgrade = "Latest version is {0}, try upgrading to it, might do the trick."
		EnterToSubmitIssue = "For help, please submit an issue by pressing Enter, a bit of a bother, I know."
		GuestModeFileTooLarge = "The file {0} is too large to read, a bit of a whopper."
		GuestModeIconFileTooLarge = "The icon {0} is too large to read, a bit too grand."
		GuestModeFtpNotSupported = "FTP is not supported in GuestMode, a bit of a restriction."
		IconFileNotFound = "Icon file not found: {0}, where has it gone?"
		ReadFileFailed = "Failed to read file: {0}, most peculiar."
		PreprocessUnknownIfCondition = "Unknown condition: {0}`nassuming false, better safe than sorry."
		PreprocessMissingEndIf = "Missing end of if statement: {0}, a bit incomplete."
		ConfigFileCreated = "Config file for EXE created, all set up."
		SourceFileCopied = "Source file name for debug copied: {0}, just in case."
		RoslynFailedFallback = "Roslyn CodeAnalysis failed`nFalling back to Use Windows Powershell with CodeDom...`nYou may want to add -UseWindowsPowerShell to args to skip this fallback in future.`n...or submit a PR to ps12exe repo to fix this!, a bit of a workaround."
		ReadingFile = "Reading file {0} size {1} bytes, rather a large file."
		ForceX86byVirtualization = "Application virtualization is activated, forcing x86 platfom, a bit restrictive."
		TryingTinySharpCompile = "Const result, trying TinySharp Compiler..., a different approach."
		TinySharpFailedFallback = "TinySharp Compiler error, fail back to normal program frame, back to the drawing board."
		OutputPath = "Path: {0}, right over there."
		ReadingScriptDone = "Done reading file {0}, starting preprocess..., almost there."
		PreprocessScriptDone = "Done preprocess file {0}, cracking on."
		ConstEvalStart = "Evaluation of constants..., crunching the numbers."
		ConstEvalDone = "Done evaluation of constants -> {0} bytes, all done."
		ConstEvalTooLongFallback = "Const result is too long, fail back to normal program frame, a bit too much."
		ConstEvalTimeoutFallback = "Evaluation timed out after {0} seconds, fail back to normal program frame, time's up."
		InvalidArchitecture = "Invalid platform {0}, using AnyCpu, a safe bet."
		UnknownPragma = "Unknown pragma: {0}, a bit of a mystery."
		UnknownPragmaBadParameterType = "Unknown pragma: {0}, as type {1} can't analyze, a bit too complex."
		UnknownPragmaBoolValue = "Unknown pragma value: {0}, cannot take is as a boolean, a bit of a contradiction."
		DllExportDelNoneTypeArg = "{0}: {1} is none type parameter, assume it's string, making an assumption."
		DllExportUsing = "You are using #_DllExport, this marco is in dev and not support yet, coming soon."
	}
	WebServerI18nData = @{
		CompilingUserInput = "Compiling User Input: {0}, processing the request."
		EmptyResponse = "No data found when Handling Request, returning empty response, nothing to see here."
		InputTooLarge413 = "User Input is too large, returning 413 error, a bit too much to handle."
		ReqLimitExceeded429 = "IP {0} has exceeded the limit of {1} requests per minute, returning 429 error, slow down, old chap."
	}
}
