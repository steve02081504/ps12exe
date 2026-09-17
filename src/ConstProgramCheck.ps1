if ($AstAnalyzeResult.IsConst) {
	$timeoutSeconds = 7  # 设置超时限制（秒）

	#   #_pragma noConstEval      显式声明本脚本不是常量，直接跳过常量求值
	#   #_pragma constEvalTimeout 显式声明本次常量求值已超时，按超时回退处理
	$NoConstEvalPragma = $Content -match '(?m)^\s*#_pragma\s+noConstEval\b'
	$ConstEvalTimeoutPragma = $Content -match '(?m)^\s*#_pragma\s+constEvalTimeout\b'

	if ($NoConstEvalPragma) {
		Write-I18n Verbose ConstEvalNotConstFallback
		$AstAnalyzeResult.IsConst = $false
	}
	else {
		Write-I18n Verbose ConstEvalStart

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
"@ *> $null
		$myhost = [ps12exeConstEvalHost]::New()
		$runspace = [runspacefactory]::CreateRunspace($myhost)
		$runspace.Open()
		$pwsh = [System.Management.Automation.PowerShell]::Create()
		$pwsh.Runspace = $runspace
		$runspace.SessionStateProxy.SetVariable("PSEXEScript", $Content)

		$ConstEvalDone = $false
		if ($ConstEvalTimeoutPragma) {
			# 已声明超时：不实际求值，直接走与真实超时相同的回退路径
			Write-I18n Verbose ConstEvalTimeoutFallback $timeoutSeconds
		}
		else {
			$null = $pwsh.AddScript("function PSEXEMainFunction{$Content};PSEXEMainFunction")

			$asyncResult = $pwsh.BeginInvoke()

			$timeoutTicks = [int]($timeoutSeconds * 20)
			for ($i = 0; $i -lt $timeoutTicks; $i++) {
				if ($asyncResult.IsCompleted) {
					break
				}
				Start-Sleep -Milliseconds 50
			}

			if ($asyncResult.IsCompleted) {
				try {
					$RowResult = $pwsh.EndInvoke($asyncResult) | Where-Object { $_ -ne $null }
					$ConstResult = $RowResult | ForEach-Object {
						(($_ | Out-String) -replace '\r\n$', '').Replace('\', '\\').Replace('"', '\"').Replace("`n", "\n").Replace("`r", "\r")
					}
					$ConstResult = $ConstResult -join $(if ($noConsole) { '","' }else { "`n" })
					Write-I18n Verbose ConstEvalDone $(bytesOfString $ConstResult)
					if ($ConstResult.Length -gt 19kb) {
						Write-I18n Verbose ConstEvalTooLongFallback
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
						$ConstEvalDone = $true
					}
				}
				catch {
					Write-I18n Verbose ConstEvalThrowErrorFallback
				}
			}
			else {
				Write-I18n Verbose ConstEvalTimeoutFallback $timeoutSeconds
				$pwsh.Stop()
			}
		}

		# 所有回退路径（超时/超长/异常/显式声明）都汇聚到这一处，避免遗漏 IsConst 复位
		if (-not $ConstEvalDone) {
			$AstAnalyzeResult.IsConst = $false
		}

		$runspace.Close()
		$pwsh.Dispose()
		$runspace.Dispose()
	}
}
