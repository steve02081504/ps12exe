[CmdletBinding()]
param ([switch]$noConsole)

function GetAssemblyLocation($assemblyName) {
	([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.ManifestModule.Name -ieq $assemblyName } | Select-Object -First 1).Location
}
function LoadAssemblyAndGetLocation($verinfo) {
	$n = New-Object System.Reflection.AssemblyName($verinfo)
	[System.AppDomain]::CurrentDomain.Load($n).Location
}
$referenceAssembies = @((GetAssemblyLocation "System.dll"))
if (!$noConsole) { $referenceAssembies += GetAssemblyLocation "Microsoft.PowerShell.ConsoleHost.dll" }
$referenceAssembies += GetAssemblyLocation "System.Management.Automation.dll"

if ($noConsole) {
	$referenceAssembies += LoadAssemblyAndGetLocation "System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
	$referenceAssembies += LoadAssemblyAndGetLocation "System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"
}

$referenceAssembies -ne $null
