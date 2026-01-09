@{
	# Script module or binary module file associated with this manifest.
	RootModule             = 'ps12exe.psm1'

	# Version number of this module.
	ModuleVersion          = '0.0.0'

	# Supported PSEditions
	# CompatiblePSEditions = @()

	# ID used to uniquely identify this module
	GUID                   = '0bdadd0c-4365-422a-b7d4-62c2ea6d2d14'

	# Author of this module
	Author                 = 'steve02081504'

	# Company or vendor of this module
	CompanyName            = 'Unknown'

	# Copyright statement for this module
	Copyright              = '(c) steve02081504.'

	# Description of the functionality provided by this module
	Description            = @'
better pwsh code 2 exe repo:
- Use `ps12exe a.ps1` to convert `a.ps1` into `a.exe`;
- Use `ps12exeGUI` for a graphical interface that simplifies compilation;
- Use `Set-ps12exeContextMenu` to add a context menu item for quick compilation or GUI access on `.ps1` files;
- Use `Start-ps12exeWebServer` to launch a web server that allows users to compile scripts online;
- Use `Enter-ps12exeInteract` to enter an interactive mode for compiling scripts without parameters.
All commands in this module support the `-help` option for detailed assistance in your language.
'@

	# Minimum version of the PowerShell engine required by this module
	PowerShellVersion      = '5.0'

	# Name of the PowerShell host required by this module
	# PowerShellHostName = ''

	# Minimum version of the PowerShell host required by this module
	# PowerShellHostVersion = ''

	# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	DotNetFrameworkVersion = '4.0'

	# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	# ClrVersion = ''

	# Processor architecture (None, X86, Amd64) required by this module
	# ProcessorArchitecture = ''

	# Modules that must be imported into the global environment prior to importing this module
	# RequiredModules = @()

	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @()

	# Script files (.ps1) that are run in the caller's environment prior to importing this module.
	# ScriptsToProcess = @()

	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @()

	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @()

	# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
	# NestedModules = @()

	# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
	FunctionsToExport      = @('ps12exe', 'ps12exeGUI', 'Set-ps12exeContextMenu', 'Start-ps12exeWebServer', 'Enter-ps12exeInteract')

	# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
	# CmdletsToExport = @()

	# Variables to export from this module
	# VariablesToExport = @()

	# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
	# AliasesToExport = @()

	# DSC resources to export from this module
	# DscResourcesToExport = @()

	# List of all modules packaged with this module
	# ModuleList = @()

	# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData            = @{
		PSData = @{
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags       = @('Executable', 'Compiler', 'ps2exe', 'exe', 'ps12exe', 'Windows')

			# A URL to the license for this module.
			LicenseUri = 'https://github.com/steve02081504/ps12exe/blob/master/LICENSE'

			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/steve02081504/ps12exe'

			# A URL to an icon representing this module.
			IconUri    = 'https://raw.githubusercontent.com/steve02081504/ps12exe/master/img/icon.ico'

			# ReleaseNotes of this module
			# ReleaseNotes = ''

			# Prerelease string of this module
			# Prerelease = ''

			# Flag to indicate whether the module requires explicit user acceptance for install/update/save
			# RequireLicenseAcceptance = $false

			# External dependent modules of this module
			# ExternalModuleDependencies = @()
		}
	}

	# HelpInfo URI of this module
	# HelpInfoURI = ''

	# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
	# DefaultCommandPrefix = ''
}
