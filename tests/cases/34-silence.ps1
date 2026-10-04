Add-Test @{
	Name  = 'ps12exe.host.silence-diagnostic-streams'
	Group = 'ps12exe'
	Deps  = $script:CoreCompileDeps
	Build = @{
		Name      = 'silenced'
		InputText = @'
Write-Output 'visible-output'
$Host.UI.WriteDebugLine('hidden-debug')
$Host.UI.WriteErrorLine('hidden-error')
$Host.UI.WriteVerboseLine('hidden-verbose')
$Host.UI.WriteWarningLine('hidden-warning')
'@
		Params    = @{ App = @{ Silence = @('Debug', 'Error', 'Verbose', 'Warning') } }
	}
	Run   = {
		param($ctx)
		$result = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['silenced']
		Assert-Equal 0 $result.ExitCode 'Silenced host still exits successfully'
		Assert-Equal 'visible-output' $result.Output.Trim() 'Silence preserves output and suppresses diagnostic streams'
	}
}
