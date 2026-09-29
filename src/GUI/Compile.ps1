# 后台 runspace 编译：执行 ps12exe 并把各输出流回写到日志框。
# 编译不在 UI 线程运行，避免界面卡死。

# 建立 MTA runspace 并导入模块；模块只导入一次，后续复用同一 runspace。
function Initialize-GUICompiler {
	if ($Script:CompileRunspace -and $Script:CompileRunspace.RunspaceStateInfo.State -eq 'Opened') { return }
	$runspace = [RunspaceFactory]::CreateRunspace()
	$runspace.ApartmentState = 'MTA'
	$runspace.ThreadOptions = 'ReuseThread'
	$runspace.Open()
	$init = [PowerShell]::Create()
	$init.RunSpace = $runspace
	[void]$init.AddScript('param($ModulePath) Import-Module $ModulePath -Force -ErrorAction Stop').AddArgument("$PSScriptRoot/../../ps12exe.psm1")
	$null = $init.Invoke()
	if ($init.HadErrors) {
		foreach ($err in $init.Streams.Error) { Write-GUILog ("Failed to import ps12exe: " + $err.ToString()) }
	}
	$Script:CompileRunspace = $runspace
	$Script:CompilePowerShell = $init
}

# 本轮编译使用的 Locale 即当前加载语言的 LangID。
function Get-GUICompileLocale {
	return $Script:LocalizeData.LangID
}

# 把自上次轮询以来新产生的输出写入日志框。
function Write-GUICompileStreams {
	$ps = $Script:CompilePowerShell
	if (-not $ps) { return }
	$counts = $Script:CompileStreamCounts
	if (-not $counts) { return }
	foreach ($streamName in @('Output', 'Information', 'Warning', 'Error')) {
		$collection = $ps.Streams.$streamName
		for ($i = [int]$counts[$streamName]; $i -lt $collection.Count; $i++) {
			Write-GUILog ([string]$collection[$i])
		}
		$counts[$streamName] = $collection.Count
	}
}

# Timer 轮询：输出流实时回写，结束时收尾并弹结果框。
function Update-GUICompile {
	$ps = $Script:CompilePowerShell
	if (-not $ps) { return }
	Write-GUICompileStreams
	$state = $ps.InvocationStateInfo.State
	if ($state -notin @('Completed', 'Failed', 'Stopped')) { return }

	if ($Script:CompileTimer) {
		$Script:CompileTimer.Stop()
		$Script:CompileTimer.Dispose()
		$Script:CompileTimer = $null
	}
	$Script:CompileRunning = $false
	if ($Script:refs.CompileButton) { $Script:refs.CompileButton.Text = Get-GUIText 'Button.Compile' }

	$output = ''
	try { $output = ($ps.Streams.Output | Out-String).Trim() } catch { }
	$exitCode = $null
	try { $exitCode = $ps.Runspace.SessionStateProxy.GetVariable('LastExitCode') } catch { }
	$errorRecord = $null
	if ($ps.Streams.Error.Count -gt 0) { $errorRecord = $ps.Streams.Error[0] }

	$title = if ($Script:LocalizeData) { [string]$Script:LocalizeData.CompileResult } else { Get-GUIText 'Window.Title' }
	# state=Stopped 时用户主动取消，Stop-GUICompile 已写日志，这里不再弹窗。
	if ($state -eq 'Stopped') { return }
	if ($state -eq 'Failed' -or $exitCode) {
		$message = ''
		if ($errorRecord) {
			if ($errorRecord.CategoryInfo.Category -ine 'ParserError') {
				$head = if ($Script:LocalizeData) { [string]$Script:LocalizeData.ErrorHead } else { '' }
				$message = "$head $($errorRecord.Exception.Message)"
			}
			else {
				$target = if ($errorRecord.TargetObject) { [string]$errorRecord.TargetObject.Text } else { '' }
				$message = (@($errorRecord, $target) -join "`n")
			}
		}
		elseif ($ps.InvocationStateInfo.Reason) {
			$message = $ps.InvocationStateInfo.Reason.Message
		}
		$Script:CompileMessage = $message
		if (-not $Script:GUISuppressDialogs) { [System.Windows.Forms.MessageBox]::Show([string]$message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) }
	}
	else {
		if (-not $output) { $output = if ($Script:LocalizeData) { [string]$Script:LocalizeData.DefaultResult } else { Get-GUIText 'Log.Done' } }
		$Script:CompileMessage = $output
		if (-not $Script:GUISuppressDialogs) { [System.Windows.Forms.MessageBox]::Show([string]$output, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) }
	}
}

function Start-GUICompile {
	param([hashtable]$Params = $null)
	if ($Script:CompileRunning) { return }
	if (-not $Params) { $Params = Get-ps12exeArgs }
	Initialize-GUICompiler

	$Script:CompileRunning = $true
	if ($Script:refs.CompileButton) { $Script:refs.CompileButton.Text = Get-GUIText 'Button.Cancel' }
	Write-GUILog (Get-GUIText 'Log.Compiling')

	$locale = Get-GUICompileLocale
	$ps = [PowerShell]::Create()
	$ps.RunSpace = $Script:CompileRunspace
	[void]$ps.AddScript('param($Params, $Locale) ps12exe @Params -Locale $Locale | Out-String').AddArgument($Params).AddArgument($locale)
	$Script:CompilePowerShell = $ps
	$Script:CompileStreamCounts = @{ Output = 0; Information = 0; Warning = 0; Error = 0 }
	[void]$ps.BeginInvoke()

	if ($Script:CompileTimer) {
		$Script:CompileTimer.Stop()
		$Script:CompileTimer.Dispose()
	}
	$Script:CompileTimer = New-Object System.Windows.Forms.Timer
	$Script:CompileTimer.Interval = 100
	$Script:CompileTimer.add_Tick({ Update-GUICompile })
	$Script:CompileTimer.Start()
}

function Stop-GUICompile {
	$ps = $Script:CompilePowerShell
	if ($ps -and $Script:CompileRunning) {
		try { $ps.Stop() } catch { }
	}
	Write-GUILog (Get-GUIText 'Log.Cancelled')
}

function Test-GUICompileRunning {
	return [bool]$Script:CompileRunning
}
