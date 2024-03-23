if ($AstAnalyzeResult.IsConst) {
	$timeoutSeconds = 7  # 设置超时限制（秒）

	Write-Verbose "constant program, using constexpr program frame"
	Write-Verbose "Evaluation of constants..."

	# 一个自定义host以便挂钩SetShouldExit
	Add-Type @"
using System;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;

public class ps12exeConstEvalHost : PSHost {
    public static int LastExitCode = 0;
    public override void SetShouldExit(int exitCode) {
        LastExitCode = exitCode;
    }
    public override PSHostUserInterface UI { get { return null; } }
    public override string Name { get { return "ps12exeConstEvalHost"; } }
    public override Version Version { get { return new Version("72.7"); } }
    public override Guid InstanceId { get { return Guid.NewGuid(); } }
    public override CultureInfo CurrentCulture { get { return new CultureInfo(72); } }
    public override CultureInfo CurrentUICulture { get { return new CultureInfo(72); } }
    public override void EnterNestedPrompt() { }
    public override void ExitNestedPrompt() { }
    public override void NotifyBeginApplication() { }
    public override void NotifyEndApplication() { }
}
"@
	$myhost = [ps12exeConstEvalHost]::New()
	$runspace = [runspacefactory]::CreateRunspace($myhost)
	$runspace.Open()
	$pwsh = [System.Management.Automation.PowerShell]::Create()
	$pwsh.Runspace = $runspace
	$runspace.SessionStateProxy.SetVariable("PSEXEScript", $Content)
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
		$RowResult = $pwsh.EndInvoke($asyncResult) | Where-Object { $_ -ne $null }
		$ConstResult = $RowResult | ForEach-Object {
			(($_ | Out-String) -replace '\r\n$', '').Replace('\', '\\').Replace('"', '\"').Replace("`n", "\n").Replace("`r", "\r")
		}
		$ConstResult = $ConstResult -join $(if($noConsole){'","'}else{"`n"})
		Write-Verbose "Done evaluation of constants -> $(bytesOfString $ConstResult) bytes"
		if ($ConstResult.Length -gt 19kb) {
			Write-Verbose "Const result is too long, fail back to normal program frame"
		}
		else {
			#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
				#_include_as_value programFrame "$PSScriptRoot/programFrames/constexpr.cs" #将constexpr.cs中的内容内嵌到该脚本中
			#_else #否则正常读取cs文件
				[string]$programFrame = Get-Content $PSScriptRoot/programFrames/constexpr.cs -Raw -Encoding UTF8
			#_endif
			$programFrame = $programFrame.Replace("`$ConstResult", $ConstResult)
			$programFrame = $programFrame.Replace("`$ConstExitCodeResult", [ps12exeConstEvalHost]::LastExitCode)
			if ($RowResult.Count -eq 0) {
				$noOutput = $true
			}
		}
	}
	else {
		Write-Verbose "Evaluation timed out after $timeoutSeconds seconds, fail back to normal program frame"
		$pwsh.Stop()
	}

	$runspace.Close()
	$pwsh.Dispose()
	$runspace.Dispose()
}
