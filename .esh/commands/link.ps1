# 获取模块文件夹
$PROFILE_DIR = Split-Path -Path $PROFILE -Parent
$ModulesDir = "$PROFILE_DIR\Modules"
New-Item $ModulesDir -ItemType Directory -Force -ErrorAction Ignore | Out-Null
try{
	Remove-Item "$ModulesDir\ps12exe" -Recurse -Force -Confirm
}
catch{}
cmd /c mklink /j "$ModulesDir\ps12exe" "$PSScriptRoot\..\.."
