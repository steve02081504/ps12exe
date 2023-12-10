# Load modules manually for security reasons
. "$PSScriptRoot/ps2exe.ps1"

# Export functions
Export-ModuleMember -Function @('PS2EXE')
