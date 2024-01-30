param(
	[Parameter(ValueFromRemainingArguments)]
	[string]$ver
)
# 获取git未提交的文件，如果有 显示提示并退出
$gitStatus = git diff --name-only
if ($gitStatus) {
	Write-Host "commit your changes first before creating a new version!"
	return
}
#如果没ver前缀，自动加上
if ($ver -notmatch "^v") {
	$ver = "v" + $ver
}
git tag $ver
git push --tags
