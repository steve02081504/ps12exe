@{
	LangName                     = "English (United States)"
	LangID                       = "en-US"
	# Right click Menu
	CompileTitle                 = "Compile to EXE"
	OpenInGUI                    = "Open in ps12exeGUI"
	GUICfgFileDesc               = "ps12exeGUI config file"
	VSCodeExtensionInstalling    = "Installing the ps12exe extension for {0} ..."
	VSCodeExtensionInstallFailed = "Failed to install the ps12exe extension for {0} (it may not be published yet): {1}"
	VSCodeExtensionUninstalling  = "Uninstalling the ps12exe extension for {0} ..."
	VSCodeExtensionUninstallFailed = "Failed to uninstall the ps12exe extension for {0}: {1}"
	# Web Server
	ErrorHead                    = "An error occurred:"
	CompileResult                = "Compile result:"
	DefaultResult                = "Done."
	AskSaveCfg                   = "Save the configuration file?"
	AskSaveCfgTitle              = "Save configuration file"
	CfgFileLabelHead             = "Configuration file:"
	# Console
	ServerStarted                = "HTTP server started."
	ServerStopped                = "HTTP server stopped."
	ServerStartFailed            = "Failed to start the HTTP server."
	TryRunAsRoot                 = "Try running as administrator."
	ServerListening              = "Access URL:"
	ExitServerTip                = "Press Ctrl+C to stop the server."
	# GUI
	ConsoleHelpData              = @{
		title      = "Usage:"
		Usage      = "[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
	[-App @{Windowed=`$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default';
	VisualStyles=`$true; ExitOnCancel=`$true; CredentialGUI=`$true; DpiAware=`$true; WinFormsDpiAware=`$true}]
	[-Os @{Admin=`$true; ModernOS=`$true; LongPaths=`$true; Virtualize=`$true}]
	[-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'; Apartment='STA'|'MTA';
	Culture='<culture>'; Options='<options>'; KeepSource=`$true; Minify={<scriptblock>}; TempDir='<directory>'}]
	[-Resources @{Icon='<filename|url>'; Title='<title>'; Description='<description>'; Company='<company>';
	Product='<product>'; Copyright='<copyright>'; Trademark='<trademark>'; Version='<version>'}]
	[-Signing @{Certificate='<PFX file path>'; Password='<PFX password>'; Thumbprint='<certificate thumbprint>'; Timestamp='<timestamp server>'}]
	[-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Locale '<language code>'] [-ConfigFile] [-help]"
		PrarmsData = [ordered]@{
			input            = "String contents of the PowerShell script (same as ``-Content``)."
			inputFile        = "Path or URL of the PowerShell script to convert (file must be UTF-8 or UTF-16 encoded)."
			Content          = "PowerShell script text to convert to an executable."
			outputFile       = "Output executable path or folder; defaults to the input file path with a ``.exe`` extension."
			App              = [ordered]@{
				Windowed         = "Build a Windows Forms application without a console window."
				Silence          = "Stream names to suppress; one or more of ``'Output'``, ``'Verbose'``, ``'Error'``, ``'Warning'``, ``'Debug'``, or ``'*'``."
				OutputEncoding   = "Console output encoding; ``'Default'``, ``'UTF8'`` or ``'UTF16LE'``."
				VisualStyles     = "Enable visual styles for GUI applications (default `` `$true ``)."
				ExitOnCancel     = "Exit when Cancel or ``'X'`` is selected in a ``Read-Host`` input box."
				CredentialGUI    = "Use a GUI for prompting credentials in console mode."
				DpiAware         = "Mark the compiled executable as DPI aware."
				WinFormsDpiAware = "Let WinForms use DPI scaling (requires Windows 10 and .NET 4.7 or up)."
			}
			Os               = [ordered]@{
				Admin      = "If UAC is enabled, the compiled executable runs only in an elevated context (UAC dialog appears)."
				ModernOS   = "Use functions of the newest Windows versions (run ``[Environment]::OSVersion`` to see the difference)."
				LongPaths  = "Enable long paths (``> 260`` characters) if enabled on the OS (Windows 10 or up)."
				Virtualize = "App virtualization is activated (forcing x86 runtime)."
			}
			Build            = [ordered]@{
				Target     = "Target runtime version, ``'Framework4.0'`` by default; ``'Framework2.0'`` and ``'Core'`` are supported. ``'Core'`` builds a PowerShell Core (.NET) executable (needs PowerShell Core and .NET on both build and target machines; the output is much larger)."
				Platform   = "Compile for a specific runtime. Possible values are ``'AnyCpu'``, ``'x64'``, and ``'x86'``."
				Apartment  = "``'STA'`` (Single Thread Apartment) or ``'MTA'`` (Multi Thread Apartment) mode."
				Culture    = "Locale for the compiled executable. Uses the current user culture if omitted."
				Options    = "Additional compiler options (see ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)."
				KeepSource = "Creates info to help with debugging."
				Minify     = "Scriptblock to minify the script before compiling."
				TempDir    = "Directory for temporary files (default: a random folder under ``%temp%``)."
			}
			Resources        = [ordered]@{
				Icon        = "Icon of the executable; can be a file path or URL."
				Title       = "Title (file description) of the executable."
				Description = "Short description of the executable."
				Company     = "Company name of the executable."
				Product     = "Product name of the executable."
				Copyright   = "Copyright notice of the executable."
				Trademark   = "Trademark information of the executable."
				Version     = "Version number of the executable (for example ``'1.0.0.0'``)."
			}
			Signing          = [ordered]@{
				Certificate = "Path to the PFX certificate file; either ``Certificate`` or ``Thumbprint`` must be specified."
				Password    = "Password of the PFX certificate."
				Thumbprint  = "Certificate thumbprint; either ``Certificate`` or ``Thumbprint`` must be specified."
				Timestamp   = "URL of the timestamp server used for code signing."
			}
			PreprocessOnly   = "Preprocess the input script and return it without compiling."
			Golf             = "Enable golf mode, adding abbreviations and common functions."
			Sandbox          = "Compile scripts with extra protection, preventing access to native files."
			NoUpdateCheck    = "Skip checking for new versions of ps12exe."
			Locale           = "Language code for localized messages."
			ConfigFile       = "Write a config file (``<outputfile>.exe.config``)."
			Help             = "Show this help message."
		}
	}
	GUIHelpData                  = @{
		title      = "Usage:"
		Usage      = @"
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Locale '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Locale '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
"@
		PrarmsData = [ordered]@{
			ConfigFile	= "Configuration file to load."
			PS1File    = "Script file to compile."
			Locale     = "Language code to use."
			UIMode     = "UI mode."
			help       = "Show this help message."
		}
	}
	SetContextMenuHelpData       = @{
		title      = "Usage:"
		Usage      = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Locale '<language code>'] [-SkipEditorExtension] [-help]"
		PrarmsData = [ordered]@{
			action              = "Action to execute."
			Locale              = "Language code."
			SkipEditorExtension	= "Skip installing or uninstalling the ps12exe VS Code extension in detected editors."
			help                = "Show this help message."
		}
	}
	WebServerHelpData            = @{
		title      = "Usage:"
		Usage      = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<path>']
	[-Locale '<language code>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl           = "The HTTP server address."
			MaxCompileThreads = "Max number of compile threads."
			MaxCompileTime    = "Max compile time in seconds."
			ReqLimitPerMin    = "Max number of requests per minute per IP."
			MaxCachedFileSize = "Max size of cached files."
			MaxScriptFileSize = "Max size of script files."
			CacheDir          = "Directory to store cached files."
			Locale            = "Language code for server-side messages."
			help              = "Show this help message."
		}
	}
	exe21spHelpData              = @{
		title      = "Usage:"
		Usage      = "[input |] exe21sp [[-inputFile] '<path or url to exe>'] [-outputFile '<path to output .ps1>'] [-help]"
		PrarmsData = [ordered]@{
			input      = "Path or URL to the ps12exe-generated exe to decompile, same as ``-inputFile``."
			inputFile  = "Path or URL to the ps12exe-generated exe to decompile."
			outputFile = "Optional; path to write the recovered script. If omitted, output goes to stdout when redirected, otherwise writes to ``<exe>.ps1`` in the same folder."
			help       = "Show this help message."
		}
	}
	CompilingI18nData            = @{
		NewVersionAvailable                       = "There's a new version of ps12exe available: {0}!"
		NoneInput                                 = "No input file specified!"
		BothInputAndContentSpecified              = "Input file and content can't be used at the same time."
		PreprocessDone                            = "Done pre-processing the input script!"
		PreprocessedScriptSize                    = "Preprocessed script -> {0} bytes."
		MinifyingScript                           = "Minifying the script..."
		MinifyedScriptSize                        = "Minified script -> {0} bytes."
		MinifyerError                             = "Minifyer error: {0}"
		MinifyerFailedUsingOriginalScript         = "Minifyer failed, using the original script."
		TempFileMissing                           = "Temporary file {0} not found."
		PreprocessOnlyDone                        = "Done pre-processing the input script."
		InvalidResourceParam                      = "Parameter -Resources has an invalid key: {0}"
		InputSyntaxError                          = "Syntax error in the script."
		SyntaxErrorLineStart                      = "At line {0}, Col {1}:"
		IdenticalInputOutput                      = "Input file is the same as the output file."
		CombinedArg_Virtualize_requireAdmin       = "-Os @{Virtualize=`$true} can't be combined with -Os @{Admin=`$true}."
		CombinedArg_Virtualize_supportOS          = "-Os @{Virtualize=`$true} can't be combined with -Os @{ModernOS=`$true}."
		CombinedArg_Virtualize_longPaths          = "-Os @{Virtualize=`$true} can't be combined with -Os @{LongPaths=`$true}."
		CombinedArg_NoConfigFile_LongPaths        = "Forcing config file generation, since -Os @{LongPaths=`$true} needs it."
		CombinedArg_NoConfigFile_winFormsDPIAware = "Forcing config file generation, since -App @{WinFormsDpiAware=`$true} needs it."
		SomeCmdletsMayNotAvailable                = "Cmdlets {0} are used but might not be available."
		SomeNotFoundCmdlets                       = "Unknown functions {0} are used."
		SomeTypesMayNotAvailable                  = "Types {0} are used but might not be available at runtime."
		CompilingFile                             = "Compiling file..."
		CompilationFailed                         = "Compilation failed!"
		OutputFileNotWritten                      = "Output file {0} not written."
		CompiledFileSize                          = "Compiled file written -> {0} bytes."
		OopsSomethingWentWrong                    = "Something went wrong."
		TryUpgrade                                = "A newer version is available: {0}. Consider upgrading."
		EnterToSubmitIssue                        = "For help, submit an issue by pressing Enter."
		GuestModeFileTooLarge                     = "File {0} is too large to read."
		GuestModeIconFileTooLarge                 = "Icon {0} is too large to read."
		GuestModeFtpNotSupported                  = "FTP is not supported in Sandbox mode."
		IconFileNotFound                          = "Icon file not found: {0}"
		ConvertingImageToIcon                     = "Converting image to icon format..."
		ImageConvertedToIcon                      = "Image converted to icon: {0}"
		ImageConversionFailed                     = "Image conversion failed: {0}"
		PleaseUseIcoFile                          = "Please use a .ico file instead of {0}"
		SigningExecutable                         = "Signing executable..."
		ExecutableSignedSuccessfully              = "Executable signed successfully."
		SigningStatusNotValid                     = "Signing status not valid: {0} - {1}"
		CertificateNotFoundOrInvalidPassword      = "Certificate not found or invalid password."
		SigningFailed                             = "Signing failed: {0}"
		ReadFileFailed                            = "Failed to read file: {0}"
		PreprocessUnknownIfCondition              = "Unknown condition: {0}; assuming false."
		PreprocessNestedIfDeadCode                = "Nested #_if {0} inside #_if {1}: the enclosing condition already fixes this branch, so one side is dead code."
		PreprocessMissingEndIf                    = "Missing end of if statement: {0}"
		ConfigFileCreated                         = "Config file for the EXE created."
		SourceFileCopied                          = "Source file name for debugging copied: {0}"
		CoreCompilePublishing                     = "Publishing single-file executable with the .NET SDK..."
		CoreCompileNeedDotnet                     = "PowerShell Core compilation requires the .NET SDK (dotnet). Install it, or pass -Build @{Target='Framework4.0'}."
		CoreCompileUnsupported                    = "These options are not supported by the PowerShell Core compiler yet: {0}"
		CoreCompileNeedPwsh                       = "This is Windows PowerShell; -Build @{Target='Core'} needs PowerShell Core (pwsh) installed and on PATH."
		CoreCompileNeedWindowsPowerShell          = "Windows PowerShell was not found; pass -Build @{Target='Core'} to compile a PowerShell Core executable."
		CoreCompileNeedPwshHost                   = "The compiled ps12exe executable cannot build PowerShell Core executables; run ps12exe from the script/module under pwsh instead."
		CoreCompileHint                           = "If this is a PowerShell Core-only script, pass -Build @{Target='Core'} (requires PowerShell Core and .NET on the build and target machines; the resulting exe is much larger)."
		ReadingFile                               = "Reading file {0}, size {1} bytes."
		ForceX86byVirtualization                  = "App virtualization activated, forcing x86 platform."
		TryingTinySharpCompile                    = "Const result, trying TinySharp Compiler..."
		TinySharpFailedFallback                   = "TinySharp Compiler error, falling back to the normal program frame."
		OutputPath                                = "Path: {0}"
		ReadingScriptDone                         = "Finished reading {0}; starting preprocessing..."
		PreprocessScriptDone                      = "Done preprocessing file {0}."
		ConstEvalStart                            = "Evaluation of constants..."
		ConstEvalDone                             = "Done evaluating constants -> {0} bytes."
		ConstEvalTooLongFallback                  = "Constant result too long, falling back to the normal program frame."
		ConstEvalTimeoutFallback                  = "Evaluation timed out after {0} seconds, falling back to the normal program frame."
		ConstEvalThrowErrorFallback               = "Constant result throws an error, falling back to the normal program frame."
		ConstEvalNotConstFallback                 = "Script declared itself non-const, falling back to the normal program frame."
		InvalidArchitecture                       = "Invalid platform {0}, using AnyCpu."
		UnknownPragma                             = "Unknown pragma: {0}"
		UnknownPragmaBadParameterType             = "Unknown pragma: {0}, type {1} can't be analyzed."
		UnknownPragmaBoolValue                    = "Unknown pragma value: {0}, can't use that as a boolean."
		PragmaUnsafeExpression                    = "Unsafe expression in pragma {0}: {1}"
		DllExportDelNoneTypeArg                   = "{0}: {1} is a none type parameter, assuming it's a string."
		DllExportUsing                            = "You're using #_DllExport, this macro is in dev and not supported yet."
	}
	WebServerI18nData            = @{
		CompilingUserInput  = "Compiling User Input: {0}"
		EmptyResponse       = "No data found when handling the request, returning an empty response."
		InputTooLarge413    = "User input is too large, returning a 413 error."
		ReqLimitExceeded429 = "IP {0} has exceeded the limit of {1} requests per minute, returning 429."
	}
	InteractI18nData             = @{
		ModeName                    = "Interactive"
		Welcome                     = "ps12exe interactive mode. Press Ctrl+C to exit."
		EnterInputFile              = "Input script path or URL:"
		Prompt                      = " >> "
		ExitMessage                 = "Exited interactive mode."
		InvalidInputFile            = "Not a valid PowerShell script path."
		FileDoesNotExist            = "File not found."
		InvalidExtension            = "Use a '.ps1', '.psd1', or '.tmp' file."
		EnterOutputFile             = "Output file path (leave blank for <name>.exe next to the script):"
		OutputFileExtensionError    = "Output must use the '.exe' extension; it was added automatically."
		AddAdditionalInfo           = "Add optional metadata (icon, version, and so on)?"
		AdditionalInfoPrompt        = "[Y/N]"
		CollectingInfo              = "Enter metadata (leave blank to skip a field)."
		IconPath                    = "Icon path or URL (.ico, .png, .jpg, .jpeg, .bmp; blank to skip):"
		InvalidIconExtension        = "Icon must be .ico for this step; entry ignored."
		IconDoesNotExist            = "Icon file not found; try again."
		EnterTitle                  = "Title"
		EnterDescription            = "Description"
		EnterCompany                = "Company Name"
		EnterProduct                = "Product Name"
		EnterCopyright              = "Copyright"
		EnterTrademark              = "Trademark"
		EnterResourcePrompt         = "Enter {0}:"
		Version                     = "Version (e.g. 1.0.0.0):"
		InvalidVersionFormat        = "Invalid version format; entry ignored."
		SkippingAdditionalInfo      = "Skipping optional metadata."
		CompileAsGui                = "Build as a GUI application (no console window)?"
		RequireAdmin                = "Require administrator privileges?"
		EnableCodeSigning           = "Enable code signing?"
		EnterCertificatePath        = "Certificate path or URL (.pfx; blank to skip):"
		InvalidCertificateExtension = "Certificate must be .pfx; try again."
		CertificateDoesNotExist     = "Certificate file not found; try again."
		EnterCertificatePassword    = "Certificate password (blank to skip):"
		EnterCertificateThumbprint  = "Certificate thumbprint (blank to skip):"
		EnterTimestampServer        = "Timestamp server (blank for default):"
		SkippingCodeSigning         = "Skipping code signing."
		BuildingCommand             = "Building command line..."
		ExecutingCommand            = "Running compiler..."
		CompileSuccess              = "Compilation finished successfully."
		CompileFailed               = "Compilation failed; exit code {0}"
		CompileFailedException      = "Error: {0}"
		CompileAnother              = "Compile another file?"
		Exiting                     = "Exiting interactive mode."
	}
	exe21spInteractI18nData      = @{
		ModeName                 = "Interactive"
		Welcome                  = "exe21sp interactive mode. Press Ctrl+C to exit."
		EnterInputFile           = "Input .exe path or URL:"
		Prompt                   = " >> "
		ExitMessage              = "Exited interactive mode."
		InvalidInputFile         = "Not a valid .exe path or URL."
		FileDoesNotExist         = "File not found."
		EnterOutputFile          = "Output .ps1 path (leave blank for <name>.ps1 next to the .exe):"
		OutputFileExtensionError	= "Output must use the '.ps1' extension; it was added automatically."
		AdditionalInfoPrompt     = "[Y/N]"
		ConvertAnother           = "Decompile another file?"
		Exiting                  = "Exiting interactive mode."
	}
	exe21spI18nData              = @{
		NoneInput                    = "No input file specified!"
		TinySharpNoTextSection       = "The executable is a .NET assembly but does not match the TinySharp layout (no .text section)."
		TinySharpTextSectionEmpty    = "The executable is a .NET assembly but does not match the TinySharp layout (.text section is empty)."
		TinySharpCannotReadText      = "The executable is a .NET assembly but does not match the TinySharp layout (cannot read .text)."
		TinySharpPayloadNotRecovered	= "The executable is a .NET assembly but does not match the TinySharp layout; script payload cannot be recovered."
		NoEmbeddedScript             = "No embedded script found in '{0}' (not a ps12exe-built exe, or payload cannot be recovered)."
		CoreExtractNeedsPwsh         = "This exe's payload is Brotli-compressed (a PowerShell Core build). Install PowerShell 7 (pwsh) so exe21sp can decompress it."
		FileNotFound                 = "File not found: {0}"
		InputUrlFailed               = "Failed to read from URL: {0}"
	}
}
