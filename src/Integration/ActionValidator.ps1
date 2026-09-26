# 集成脚本 $action 参数的校验（由各脚本的 ValidateScript 点源调用）。
param([string]$Action)
. "$PSScriptRoot\..\predicate.ps1"
(IsEnable $Action) -or (IsDisable $Action) -or ($Action -eq 'reset')
