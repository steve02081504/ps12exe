<#
function ShowAst($Ast) {
	function Mapper($Ast) {
		$Ast.GetType().Name | Out-Host
		$Ast | Out-Host
		return $false
	}
	$Ast.Find($function:Mapper, $true)
}
function ShowAstOfExpr($Expr) {
	$Ast = [System.Management.Automation.Language.Parser]::ParseInput($Expr, [ref]$null, [ref]$null)
	ShowAst $Ast
}
#>
function AstAnalyze($Ast) {
	$script:ConstCommands = @('Write-Host', 'echo', 'Write-Output', 'Write-Debug', 'Write-Information', 'ConvertFrom-Json', 'ConvertTo-Json', 'Out-Host')
	$script:ConstVariables = @('?', '^', '$', 'Error', 'false', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'null', 'true', 'PSEXEScript', 'Out-Host')
	$script:ConstTypes = @('Boolean', 'Char', 'DateTime', 'Decimal', 'Double', 'Int16', 'Int32', 'Int64', 'Int8', 'Single', 'String', 'UInt16', 'UInt32', 'UInt64', 'UInt8', 'Void', 'Regex', 'System.Text.RegularExpressions.RegexOptions')
	$script:EffectVariables = @('ConfirmPreference', 'DebugPreference', 'EnabledExperimentalFeatures', 'ErrorActionPreference', 'ErrorView', 'ExecutionContext', 'FormatEnumerationLimit', 'HOME', 'Host', 'InformationPreference', 'input', 'MaximumHistoryCount', 'MyInvocation', 'NestedPromptLevel', 'OutputEncoding', 'PID', 'PROFILE', 'ProgressPreference', 'PSBoundParameters', 'PSCommandPath', 'PSCulture', 'PSDefaultParameterValues', 'PSEdition', 'PSEmailServer', 'PSGetAPI', 'PSHOME', 'PSNativeCommandArgumentPassing', 'PSNativeCommandUseErrorActionPreference', 'PSScriptRoot', 'PSSessionApplicationName', 'PSSessionConfigurationName', 'PSSessionOption', 'PSStyle', 'PSUICulture', 'PSVersionTable', 'PWD', 'ShellId', 'StackTrace', 'VerbosePreference', 'WarningPreference', 'WhatIfPreference')
	$script:AnalyzeResult = @{
		IsConst                  = $true
		ImporttedExternalScripts = $false
		UsedNonConstVariables    = @()
		UsedNonConstFunctions    = @()
	}
	function AstMapper($Ast) {
		if ($Ast -is [System.Management.Automation.Language.CommandAst]) {
			if ($script:ConstCommands -notcontains $Ast.CommandElements[0].Value) {
				$script:AnalyzeResult.IsConst = $false
				$script:AnalyzeResult.UsedNonConstFunctions += $Ast.CommandElements[0].Value
			}
			if ($Ast.InvocationOperator -eq 'Dot' -or $Ast.InvocationOperator -eq 'Ampersand') {
				$script:AnalyzeResult.ImporttedExternalScripts = $true
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
			if ($script:EffectVariables -contains $Ast.VariablePath.UserPath) {
				$script:AnalyzeResult.IsConst = $false
				$script:AnalyzeResult.UsedNonConstVariables += $Ast.VariablePath.UserPath
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.TypeDefinitionAst]) {
			$script:ConstTypes += $Ast.Name
		}
		elseif ($Ast -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
			if ($script:ConstTypes -notcontains $Ast.Expression.TypeName) {
				if($Ast.Expression.TypeName) {
					$script:AnalyzeResult.IsConst = $false
					$script:AnalyzeResult.UsedNonConstFunctions += "[$($Ast.Expression.TypeName)]::$($Ast.Member.Value)"
				}
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.TypeExpressionAst]) {
			if ($script:ConstTypes -notcontains $Ast.TypeName) {
				$script:AnalyzeResult.IsConst = $false
				$script:AnalyzeResult.UsedNonConstVariables += "[$($Ast.TypeName)]"
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
			$script:ConstCommands += $Ast.Name
			$script:ConstVariables += "function:$($Ast.Name)"
		}
		elseif ($Ast -is [System.Management.Automation.Language.AssignmentStatementAst]) {
			if ($script:EffectVariables -notcontains $Ast.Left.VariablePath) {
				$script:ConstVariables += $Ast.Left.VariablePath.UserPath
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.NamedBlockAst]) {
			$ConstCommandsBackup = $script:ConstCommands
			$ConstVariablesBackup = $script:ConstVariables
			$script:ConstVariables += 'args'
			foreach ($Statement in $Ast.Statements) {
				$Statement.Find($function:AstMapper, $true)
			}
			$script:ConstCommands = $ConstCommandsBackup
			$script:ConstVariables = $ConstVariablesBackup
		}
		return $false
	}
	[void]$Ast.Find($function:AstMapper, $true)
	$script:AnalyzeResult.UsedNonConstVariables = $script:AnalyzeResult.UsedNonConstVariables | Sort-Object -Unique | Where-Object { $_ }
	$script:AnalyzeResult.UsedNonConstFunctions = $script:AnalyzeResult.UsedNonConstFunctions | Sort-Object -Unique | Where-Object { $_ }
	$local:AnalyzeResult = $script:AnalyzeResult
	Remove-Variable -Name @('ConstCommands', 'ConstVariables', 'ConstTypes', 'EffectVariables', 'AnalyzeResult') -Scope Script
	return $local:AnalyzeResult
}
