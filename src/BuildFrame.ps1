. $PSScriptRoot\ConstProgramCheck.ps1
if (!$programFrame) {
	#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
		#_include_as_value programFrame "$PSScriptRoot/programFrames/default.cs" #将default.cs中的内容内嵌到该脚本中
	#_else #否则正常读取cs文件
		[string]$programFrame = Get-Content $PSScriptRoot/programFrames/default.cs -Raw -Encoding UTF8
	#_endif
}

# 资源/版本属性抽到公共片段（AssemblyInfo.cs），编译时替换帧里的 /*__ASSEMBLY_ATTRIBUTES__*/ 标记。
# 只有“最外层”程序集（launcher / 直编帧）替换成属性；payload 替换为空，因此帧本身与资源参数无关。
if (!$resourceAttributes) {
	#_if PSEXE
		#_include_as_value resourceAttributes "$PSScriptRoot/programFrames/AssemblyInfo.cs"
	#_else
		[string]$resourceAttributes = Get-Content $PSScriptRoot/programFrames/AssemblyInfo.cs -Raw -Encoding UTF8
	#_endif
}

$programFrame = $programFrame.Replace("`$lcid", $lcid)
$programFrame = $programFrame.Replace("`$threadingModel", $threadingModel)
$programFrame = $programFrame.Replace("`$TargetFramework", $TargetFramework)

$resourceAttributes = $resourceAttributes.Replace("`$TargetFramework", $TargetFramework)
$resourceParamKeys | ForEach-Object {
	$resourceAttributes = $resourceAttributes.Replace("`$$_", $resourceParams[$_])
}
