$script:TaskbarProgressEnabled = $false
if ($Host.UI.SupportsVirtualTerminal -and -not [System.Console]::IsOutputRedirected) {
	$script:TaskbarProgressEnabled = $true
}

function Write-TaskbarProgress {
	param([int]$Percent)
	if (-not $script:TaskbarProgressEnabled) { return }
	if ($PSBoundParameters.ContainsKey('Percent')) {
		$p = [Math]::Max(0, [Math]::Min(100, $Percent))
		Write-Host -NoNewline "`e]9;4;1;$p`e\"
	}
	else {
		Write-Host -NoNewline "`e]9;4;3;0`e\"
	}
}

function Write-TaskbarProgressClear {
	if ($script:TaskbarProgressEnabled) {
		Write-Host -NoNewline "`e]9;4;0;0`e\"
	}
}

function Write-TaskbarProgressError {
	if ($script:TaskbarProgressEnabled) {
		Write-Host -NoNewline "`e]9;4;2;100`e\"
	}
}
