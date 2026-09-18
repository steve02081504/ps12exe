# 断言库：失败即抛异常，由 worker 捕获并写入结果文件。
$ErrorActionPreference = 'Stop'

$script:AssertionCount = 0

function Get-AssertionCount { return $script:AssertionCount }

function Assert-True {
	param([bool]$Condition, [string]$Message = 'assertion failed')
	$script:AssertionCount++
	if (-not $Condition) { throw "Assert-True failed: $Message" }
}

function Assert-False {
	param([bool]$Condition, [string]$Message = 'assertion failed')
	$script:AssertionCount++
	if ($Condition) { throw "Assert-False failed: $Message" }
}

function Assert-Equal {
	param($Expected, $Actual, [string]$Message = 'value mismatch')
	$script:AssertionCount++
	if ("$Expected" -ne "$Actual") { throw "Assert-Equal failed: $Message, expected [$Expected] got [$Actual]" }
}

function Assert-Match {
	param([string]$Text, [string]$Pattern, [string]$Message = 'pattern mismatch')
	$script:AssertionCount++
	if ($Text -notmatch $Pattern) { throw "Assert-Match failed: $Message, pattern [$Pattern] not found in [$Text]" }
}

function Assert-NotMatch {
	param([string]$Text, [string]$Pattern, [string]$Message = 'pattern unexpectedly matched')
	$script:AssertionCount++
	if ($Text -match $Pattern) { throw "Assert-NotMatch failed: $Message, pattern [$Pattern] found in [$Text]" }
}

function Assert-FileExists {
	param([string]$Path, [string]$Message = 'file not found')
	$script:AssertionCount++
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Assert-FileExists failed: $Message, path [$Path]" }
}

function Assert-PathExists {
	param([string]$Path, [string]$Message = 'path not found')
	$script:AssertionCount++
	if (-not (Test-Path -LiteralPath $Path)) { throw "Assert-PathExists failed: $Message, path [$Path]" }
}
