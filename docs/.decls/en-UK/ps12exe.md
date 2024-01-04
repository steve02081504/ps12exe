---
external help file: ps12exe-help.xml
Module Name: ps12exe
online version:
schema: 2.0.0
---

# ps12exe

## SYNOPSIS
Converts powershell scripts to standalone executables.

## SYNTAX

### InputFile (Default)
```
ps12exe [[-inputFile] <String>] [[-outputFile] <String>] [-CompilerOptions <String>] [-TempDir <String>]
 [-minifyer <ScriptBlock>] [-noConsole] [-SepcArgsHandling] [-prepareDebug] [-architecture <String>]
 [-threadingModel <String>] [-resourceParams <Hashtable>] [-lcid <Int32>] [-UNICODEEncoding] [-credentialGUI]
 [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel] [-DPIAware] [-winFormsDPIAware]
 [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-help] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ContentPipe
```
ps12exe [-Content <String>] [[-outputFile] <String>] [-CompilerOptions <String>] [-TempDir <String>]
 [-minifyer <ScriptBlock>] [-noConsole] [-SepcArgsHandling] [-prepareDebug] [-architecture <String>]
 [-threadingModel <String>] [-resourceParams <Hashtable>] [-lcid <Int32>] [-UNICODEEncoding] [-credentialGUI]
 [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel] [-DPIAware] [-winFormsDPIAware]
 [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-help] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ContentArg
```
ps12exe -Content <String> [[-outputFile] <String>] [-CompilerOptions <String>] [-TempDir <String>]
 [-minifyer <ScriptBlock>] [-noConsole] [-SepcArgsHandling] [-prepareDebug] [-architecture <String>]
 [-threadingModel <String>] [-resourceParams <Hashtable>] [-lcid <Int32>] [-UNICODEEncoding] [-credentialGUI]
 [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel] [-DPIAware] [-winFormsDPIAware]
 [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-help] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Converts powershell scripts to standalone executables.
GUI output and input is activated with one switch,
real windows executables are generated.
You may use the graphical front end Win-ps12exe for convenience.

Please see Remarks on project page for topics "GUI mode output formatting", "Config files", "Password security",
"Script variables" and "Window in background in -noConsole mode".

With \`SepcArgsHandling\`, generated executable has the following reserved parameters:

-debug              Forces the executable to be debugged.
It calls "System.Diagnostics.Debugger.Launch()".
-extract:\<FILENAME\> Extracts the powerShell script inside the executable and saves it as FILENAME.
										The script will not be executed.
-wait               At the end of the script execution it writes "Hit any key to exit..." and waits for a
										key to be pressed.
-end                All following options will be passed to the script inside the executable.
										All preceding options are used by the executable itself.

## EXAMPLES

### EXAMPLE 1
```
ps12exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
```

### EXAMPLE 2
```
ps12exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
```

## PARAMETERS

### -inputFile
Powershell script file path or url to convert to executable (file has to be UTF8 or UTF16 encoded)

```yaml
Type: String
Parameter Sets: InputFile
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Content
The content of the PowerShell script to convert to executable

```yaml
Type: String
Parameter Sets: ContentPipe
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: ContentArg
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -outputFile
destination executable file name or folder, defaults to inputFile with extension '.exe'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CompilerOptions
additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: /o+ /debug-
Accept pipeline input: False
Accept wildcard characters: False
```

### -TempDir
directory for storing temporary files (default is random generated temp directory in %temp%)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -minifyer
scriptblock to minify the script before compiling

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -noConsole
the resulting executable will be a Windows Forms app without a console window.
You might want to pipe your output to Out-String to prevent a message box for every line of output
(example: dir C:\ | Out-String)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SepcArgsHandling
the resulting executable will handle special arguments -debug, -extract, -wait and -end.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -prepareDebug
create helpful information for debugging of generated executable.
See parameter -debug there

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -architecture
compile for specific runtime only.
Possible values are 'x64' and 'x86' and 'anycpu'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Anycpu
Accept pipeline input: False
Accept wildcard characters: False
```

### -threadingModel
Threading model for the compiled executable.
Possible values are 'STA' and 'MTA'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: STA
Accept pipeline input: False
Accept wildcard characters: False
```

### -resourceParams
A hashtable that contains resource parameters for the compiled executable.
Possible keys are 'iconFile', 'title', 'description', 'company', 'product', 'copyright', 'trademark', 'version'
iconFile can be a file path or url to an icon file.
All other values are strings.
see https://msdn.microsoft.com/en-us/library/system.reflection.assemblytitleattribute(v=vs.110).aspx for details

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @{}
Accept pipeline input: False
Accept wildcard characters: False
```

### -lcid
location ID for the compiled executable.
Current user culture if not specified

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -UNICODEEncoding
encode output as UNICODE in console mode, useful to display special encoded chars

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -credentialGUI
use GUI for prompting credentials in console mode instead of console input

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -configFile
write a config file (\<outputfile\>.exe.config)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -noOutput
the resulting executable will generate no standard output (includes verbose and information channel)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -noError
the resulting executable will generate no error output (includes warning and debug channel)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -noVisualStyles
disable visual styles for a generated windows GUI application.
Only applicable with parameter -noConsole

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -exitOnCancel
exits program when Cancel or "X" is selected in a Read-Host input box.
Only applicable with parameter -noConsole

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DPIAware
if display scaling is activated, GUI controls will be scaled if possible.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -winFormsDPIAware
creates an entry in the config file for WinForms to use DPI scaling.
Forces -configFile and -supportOS

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -requireAdmin
if UAC is enabled, compiled executable will run only in elevated context (UAC dialog appears if required)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -supportOS
use functions of newest Windows versions (execute \[Environment\]::OSVersion to see the difference)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -virtualize
application virtualization is activated (forcing x86 runtime)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -longPaths
enable long paths ( \> 260 characters) if enabled on OS (works only with Windows 10 or up)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -help
{{ Fill help Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
