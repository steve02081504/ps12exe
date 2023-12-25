# Load modules manually for security reasons
. "$PSScriptRoot/ps12exe.ps1"

# Export functions
Export-ModuleMember -Function @('ps12exe')
