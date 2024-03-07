param (
	[hashtable]$HelpData
)
. $PSScriptRoot/VirtualTerminal.ps1
function Showuseage($Usage) {
	$Usage -replace '(?<!\w)\-(\w+)', "$($VirtualTerminal.Colors.BrightYellow)-`$1$($VirtualTerminal.Colors.Reset)"`
	-replace "'([^']+)'", "$($VirtualTerminal.Colors.BrightMagenta)'`$1'$($VirtualTerminal.Colors.Reset)"`
	-replace '(\w+)=', "$($VirtualTerminal.Colors.BrightGreen)`$1$($VirtualTerminal.Colors.Reset)="`
	-replace '\[([a-zA-Z]+)', "[$($VirtualTerminal.Colors.BrightGreen)`$1$($VirtualTerminal.Colors.Reset)"`
}
function ShowParamsHelp($ParamsHelpData) {
	# 对于所有的键
	$MaxKeyLength = $ParamsHelpData.Keys.Length | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

	$ParamsHelpData.Keys | ForEach-Object {
		$Key = $_
		$Value = $ParamsHelpData[$Key]

		# 在Vlaue中寻找``包裹的内容，对其进行色彩化
		while ($Value -match '`(?<coloringstr>[^\`]+)`') {
			$str = $Matches['coloringstr']
			$newstr = $str
			$color = $VirtualTerminal.Colors.BrightBlue
			if (($str.StartsWith('"') -and $str.EndsWith('"')) -or ($str.StartsWith("'") -and $str.EndsWith("'"))) {
				# 字符串，淡紫色渲染
				$color = $VirtualTerminal.Colors.BrightMagenta
			}
			elseif ($str.IndexOf('::') -ge 0) {
				$newstr = $str.Replace('::', "$($VirtualTerminal.ResetAll)::$($VirtualTerminal.Colors.BrightYellow)")
			}
			elseif ($str.StartsWith('-') -or $ParamsHelpData.Keys -ccontains $str) {
				# 选项，淡黄色渲染
				$color = $VirtualTerminal.Colors.BrightYellow
			}
			elseif ($str.IndexOf('://') -ge 0) {
				# URL，淡蓝色渲染+下划线
				$color += $VirtualTerminal.Styles.Underline
			}
			elseif ($str -match '^%\w+%$') {
				# 环境变量，绿色渲染
				$color = $VirtualTerminal.Colors.BrightGreen
			}
			elseif (Get-Command $str -ErrorAction Ignore) {
				# 命令，黄色渲染
				$color = $VirtualTerminal.Colors.BrightYellow
			}
			$Value = $Value.Replace("``$str``", "$color$newstr$($VirtualTerminal.ResetAll)")
		}

		$Spaces = ' ' * ($MaxKeyLength - $Key.Length)
		"$($VirtualTerminal.Colors.BrightYellow)$Key$Spaces$($VirtualTerminal.Colors.Reset) : $Value"
	}
}
$HelpData.title
Showuseage $HelpData.Usage
ShowParamsHelp $HelpData.PrarmsData
