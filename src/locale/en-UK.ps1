@{
	# Right click Menu
	CompileTitle     = "Compile To EXE"
	OpenInGUI        = "Open in ps12exeGUI"
	GUICfgFileDesc   = "ps12exeGUI configuration file"
	# UI
	ErrorHead        = "Oh dear, an error has occurred:"
	CompileResult    = "The result of the compilation, old chap:"
	DefaultResult    = "All done and dusted!"
	AskSaveCfg       = "Would you be so kind as to save the configuration file?"
	AskSaveCfgTitle  = "Save the configuration file, if you please"
	CfgFileLabelHead = "Configuration file, my good sir:"
	# Console
	GUIHelpData      = @{
		title      = "Usage:
ps12exeGUI [[-ConfingFile] '<filename>'] [-Localize '<languagecode>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfingFile = "The configuration file to load."
			Localize    = "The language code to use."
			UIMode      = "The UI mode to use."
			help        = "Show this help message."
		}
	}
	ConsoleHelpData  = @{
		title      = "Usage:
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]"
		PrarmsData = [ordered]@{
			input            = "String of the contents of the powershell script file, same as -Content."
			inputFile        = "Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded)"
			Content          = "Powershell script content that you want to convert to executable"
			outputFile       = "destination executable file name or folder, defaults to inputFile with extension '.exe'"
			CompilerOptions  = "additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)"
			TempDir          = "directory for storing temporary files (default is random generated temp directory in %temp%)"
			minifyer         = "scriptblock to minify the script before compiling"
			lcid             = "location ID for the compiled executable. Current user culture if not specified"
			prepareDebug     = "create helpful information for debugging"
			architecture     = "compile for specific runtime only. Possible values are 'x64' and 'x86' and 'anycpu'"
			threadingModel   = "'Single Thread Apartment' or 'Multi Thread Apartment' mode"
			noConsole        = "the resulting executable will be a Windows Forms app without a console window"
			UNICODEEncoding  = "encode output as UNICODE in console mode"
			credentialGUI    = "use GUI for prompting credentials in console mode"
			resourceParams   = "A hashtable that contains resource parameters for the compiled executable"
			configFile       = "write a config file (<outputfile>.exe.config)"
			noOutput         = "the resulting executable will generate no standard output (includes verbose and information channel)"
			noError          = "the resulting executable will generate no error output (includes warning and debug channel)"
			noVisualStyles   = "disable visual styles for a generated windows GUI application (only with -noConsole)"
			exitOnCancel     = "exits program when Cancel or ""X"" is selected in a Read-Host input box (only with -noConsole)"
			DPIAware         = "if display scaling is activated, GUI controls will be scaled if possible"
			winFormsDPIAware = "if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up)"
			requireAdmin     = "if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)"
			supportOS        = "use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference)"
			virtualize       = "application virtualization is activated (forcing x86 runtime)"
			longPaths        = "enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)"
		}
	}
}
