@{
	Copyright         = '(c) steve02081504.'
	GUID              = '947fa788-47be-4aca-a7dc-dd7f26efd5fb'
	PrivateData       = @{
		PSData = @{
			ProjectUri = 'https://github.com/steve02081504/ps12exe'
			Tags       = @('Executable', 'Compiler', 'ps2exe', 'exe', 'ps12exe', 'Windows', 'Win-PS2EXE')
			LicenseUri = 'https://github.com/steve02081504/ps12exe/blob/master/LICENSE'
			IconUri    = 'https://raw.githubusercontent.com/steve02081504/ps12exe/master/img/icon.ico'
		}
	}
	FunctionsToExport = @('Invoke-PS2EXE', 'Invoke-WinPS2EXE')
	Author            = 'steve02081504'
	ModuleVersion     = '0.0.2'
	RootModule        = 'PS2EXE2ps12exe.psm1'
	CompanyName       = 'Unknown'
	AliasesToExport   = @('ps2exe', 'ps2exe.ps1', 'Win-PS2EXE', 'Win-PS2EXE.exe')
	Description       = 'Hard to upgrade from PS2EXE to ps12exe? No problem!
This module can hooks PS2EXE calls into ps12exe, All you need is just uninstall PS2EXE and install this, then use PS2EXE as normal.'
}
