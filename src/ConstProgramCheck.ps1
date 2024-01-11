. $PSScriptRoot\IsConstAst.ps1
$IsConstProgram = IsConstAst $Ast
if ($IsConstProgram) {
	$timeoutSeconds = 7  # 设置超时限制（秒）

	Write-Verbose "constant program, using constexpr program frame"
	Write-Verbose "Evaluation of constants..."

	$pwsh = [System.Management.Automation.PowerShell]::Create()
	$null = $pwsh.AddScript($Content)

	$asyncResult = $pwsh.BeginInvoke()

	$timeoutSeconds *= 20
	for ($i = 0; $i -lt $timeoutSeconds; $i++) {
		if ($asyncResult.IsCompleted) {
			break
		}
		Start-Sleep -Milliseconds 50
	}
	$timeoutSeconds /= 20

	if ($asyncResult.IsCompleted) {
		$ConstResult = $pwsh.EndInvoke($asyncResult) -join "`n"
		Write-Verbose "Done evaluation of constants -> $(bytesOfString $ConstResult) bytes"
		if ($ConstResult.Length -gt 19968) {
			Write-Verbose "Const result is too long, fail back to normal program frame"
		}
		else {
			#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
				#_include_as_value programFrame "$PSScriptRoot/programFrames/constexpr.cs" #将constexpr.cs中的内容内嵌到该脚本中
			#_else #否则正常读取cs文件
				[string]$programFrame = Get-Content $PSScriptRoot/programFrames/constexpr.cs -Raw -Encoding UTF8
			#_endif
			$programFrame = $programFrame.Replace("`$ConstResult", $ConstResult.Replace('\', '\\').Replace('"', '\"').Replace("`n", "\n").Replace("`r", "\r"))
		}
	}
	else {
		Write-Verbose "Evaluation timed out after $timeoutSeconds seconds, fail back to normal program frame"
		$pwsh.Stop()
	}

	$pwsh.Dispose()
}
