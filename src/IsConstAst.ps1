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
function IsConstAst {
	param(
		[Parameter(Mandatory = $true)]
		$Ast
	)
	$script:ConstCommands = @('Write-Host', 'echo', 'Write-Output', 'Write-Debug', 'Write-Information')
	$script:ConstVariables = @('?', '^', '$', 'args', 'Error', 'false', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'null', 'true', 'PSEXEScript')
	$script:EffectVariables = @('ConfirmPreference', 'DebugPreference', 'EnabledExperimentalFeatures', 'ErrorActionPreference', 'ErrorView', 'ExecutionContext', 'FormatEnumerationLimit', 'HOME', 'Host', 'InformationPreference', 'input', 'MaximumHistoryCount', 'MyInvocation', 'NestedPromptLevel', 'OutputEncoding', 'PID', 'PROFILE', 'ProgressPreference', 'PSBoundParameters', 'PSCommandPath', 'PSCulture', 'PSDefaultParameterValues', 'PSEdition', 'PSEmailServer', 'PSGetAPI', 'PSHOME', 'PSNativeCommandArgumentPassing', 'PSNativeCommandUseErrorActionPreference', 'PSScriptRoot', 'PSSessionApplicationName', 'PSSessionConfigurationName', 'PSSessionOption', 'PSStyle', 'PSUICulture', 'PSVersionTable', 'PWD', 'ShellId', 'StackTrace', 'VerbosePreference', 'WarningPreference', 'WhatIfPreference', 'WhatIfPreference')
	function IsNotConstAstNode($Ast) {
		if($Ast -is [System.Management.Automation.Language.CommandAst]) {
			if($script:ConstCommands -notcontains $Ast.CommandElements[0].Value) {
				return $true
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
			if($script:ConstVariables -notcontains $Ast.VariablePath.UserPath) {
				return $true
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
			$script:ConstCommands += $Ast.Name
			$script:ConstVariables += "function:$($Ast.Name)"
		}
		elseif ($Ast -is [System.Management.Automation.Language.AssignmentStatementAst]) {
			if($script:EffectVariables -notcontains $Ast.Left.VariablePath) {
				$script:ConstVariables += $Ast.Left.VariablePath.UserPath
			}
		}
		elseif ($Ast -is [System.Management.Automation.Language.NamedBlockAst]) {
			$ConstCommandsBackup = $script:ConstCommands
			$ConstVariablesBackup = $script:ConstVariables
			foreach ($Statement in $Ast.Statements) {
				if($null -ne $Statement.Find($function:IsNotConstAstNode, $true)) {
					return $true
				}
			}
			$script:ConstCommands = $ConstCommandsBackup
			$script:ConstVariables = $ConstVariablesBackup
		}
		return $false
	}
	$result=$null -eq $Ast.Find($function:IsNotConstAstNode, $true)
	Remove-Variable -Name @('ConstCommands', 'ConstVariables', 'EffectVariables') -Scope Script
	return $result
}
