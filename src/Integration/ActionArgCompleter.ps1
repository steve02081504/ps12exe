# 集成脚本 $action 参数的补全（由各脚本的 ArgumentCompleter 点源调用）。
Param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
. "$PSScriptRoot\..\predicate.ps1"
if (-not $WordToComplete) {
	'enable', 'disable', 'reset'
}
else {
	@($DisablePredicates; $EnablePredicates; 'reset') | Where-Object { $_ -like "$WordToComplete*" }
}
