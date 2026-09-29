# GUI 用例辅助：把 WinForms 操作放进全新 STA runspace 执行（worker 线程可能是 MTA）。
$ErrorActionPreference = 'Stop'

# 在新 STA runspace 中执行脚本块，$Variables 的键以同名变量注入。
# 返回脚本块输出（本地 runspace，对象是 live 引用；顶层 PSObject 会被拆包）。
# runspace 的错误流非空时抛出异常，便于断言失败定位。
function Invoke-GUIScriptBlock {
	param(
		[Parameter(Mandatory)][scriptblock]$Script,
		[hashtable]$Variables = @{}
	)
	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.ApartmentState = 'STA'
	$runspace.ThreadOptions = 'ReuseThread'
	$runspace.Open()
	$shell = $null
	try {
		foreach ($name in $Variables.Keys) { $runspace.SessionStateProxy.SetVariable($name, $Variables[$name]) }
		$shell = [System.Management.Automation.PowerShell]::Create()
		$shell.Runspace = $runspace
		[void]$shell.AddScript($Script.ToString())
		$raw = @($shell.Invoke())
		if ($shell.HadErrors) {
			$messages = @($shell.Streams.Error | ForEach-Object { $_.ToString() })
			throw ("STA runspace 出错：`n" + ($messages -join "`n"))
		}
		$output = @(foreach ($item in $raw) {
				if ($item -is [System.Management.Automation.PSObject]) { $item.PSObject.BaseObject } else { $item }
			})
		return $output
	}
	finally {
		if ($shell) { $shell.Dispose() }
		$runspace.Dispose()
	}
}
