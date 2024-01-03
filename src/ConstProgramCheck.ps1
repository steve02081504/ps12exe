. $PSScriptRoot\IsConstAst.ps1
$IsConstProgram = IsConstAst $AST
if (!$SepcArgsHandling -and $IsConstProgram) {
	$timeoutSeconds = 7  # 设置超时限制（秒）

	Write-Verbose "constant program, using constexpr program frame"
	Write-Verbose "${SavePos}Evaluation of constants..."
	$pwshBase = if (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' }
	elseif (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' }
	$pwshCommand = $Content.Replace('"', '""""')

	$job = Start-Job -ScriptBlock {
		param($pwshBase, $pwshCommand, $Content)
		if ($pwshBase) {
			&$pwshBase -NoProfile -NoLogo -NonInteractive -Command "`"$pwshCommand`""
		}
		else {
			(Invoke-Expression $Content) -join "`n"
		}
	} -ArgumentList $pwshBase, $pwshCommand, $Content

	Wait-Job -Job $job -Timeout $timeoutSeconds | Out-Null
	Stop-Job -Job $job | Out-Null
	$ConstResult = Receive-Job -Job $job
	if ($Verbose) { RollUp -InVerbose }
	if ($job.State -eq "Completed") {
		Write-Verbose "Done evaluation of constants -> $(bytesOfString $ConstResult) bytes"
		if ($ConstResult.Length -gt 19968) {
			Write-Verbose "Const result is too long, fail back to normal program frame"
		}
		else {
			#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
			#_include_as_value programFrame "$PSScriptRoot/src/programFrames/constexpr.cs" #将constexpr.cs中的内容内嵌到该脚本中
			#_else #否则正常读取cs文件
			[string]$programFrame = Get-Content $PSScriptRoot/src/programFrames/constexpr.cs -Raw -Encoding UTF8
			#_endif
			$programFrame = $programFrame.Replace("`$ConstResult", $ConstResult.Replace('\', '\\').Replace('"', '\"').Replace("`n", "\n").Replace("`r", "\r"))
		}
	}
 else {
		Write-Verbose "Evaluation timed out after $timeoutSeconds seconds, fail back to normal program frame"
	}
	Remove-Job -Job $job
}
