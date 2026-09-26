[CmdletBinding()]
param (
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
	})]
	[ValidateScript({ Test-Path "$PSScriptRoot\$_.fbs" -ErrorAction Ignore })]
	[string]$Localize = 'zh-CN'
)

# 遍历xml节点
function XmlMapper($Node) {
	# 若节点有Text、Filter、Title属性，则加入到resultContent
	@('Text', 'Filter', 'Title') | ForEach-Object {
		if ($Node.$_) { $Node.$_ }
	}
	# 遍历子节点
	$Node.ChildNodes | ForEach-Object { XmlMapper $_ }
}
# 以xml格式读取目标fbs文件
$resultContent = XmlMapper ([xml](Get-Content "$PSScriptRoot\$Localize.fbs" -Encoding utf8))
(($resultContent -join "`n") + "`n") | Out-File "$PSScriptRoot\$Localize.txt" -Encoding utf8 -NoNewline
