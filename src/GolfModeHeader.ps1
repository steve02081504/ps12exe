#region Input/Output (输入/输出)

function rl { Read-Host }

function pr([Parameter(ValueFromPipeline = $true)] [object[]]$input) {
	process {
		Write-Host -NoNewline ($input -join '')
	}
}

function pn([Parameter(ValueFromPipeline = $true)] [object[]]$input) {
	process {
		Write-Host ($input -join '')
	}
}

function rla {
	[System.IO.File]::ReadAllLines($MyInvocation.MyCommand.Path)
}

function rlat {
	[System.IO.File]::ReadAllText($MyInvocation.MyCommand.Path)
}

function py { pr 'Y' }
function pn { pr 'N' }

function pyn {
	if ($input) {
		pr "Yes"
	}
	else {
		pr "No"
	}
}

#endregion

#region String Operations (字符串操作)

function ch([int]$index) {
	$input[$index]
}

function rpl([string]$old, [string]$new = '') {
	$input -replace $old, $new
}

function spc {
	$input.ToCharArray()
}

function padl([int]$width, [char]$char = ' ') {
	$input.PadLeft($width, $char)
}

function padr([int]$width, [char]$char = ' ') {
	$input.PadRight($width, $char)
}

function sub([int]$start = 0, [int]$length) {
	if ($length -eq $null) {
		$length = $input.Length - $start
	}
	$input.Substring($start, [System.Math]::Min($length, $input.Length - $start))
}

function rev {
	$input -join '' -split '' | ForEach-Object {
		$a = $_
		$b = $a + $b
	}
	$b
}

function occ([char]$char) {
    ($input.ToCharArray() | Where-Object { $_ -eq $char } | Measure-Object).Count
}

function delc([char[]]$chars) {
	$input -replace "[$($chars -join '')]"
}

function getnums {
	[regex]::Matches($input, '\d').Value -join ''
}

function chcodes([string]$separator = '') {
	$input.ToCharArray() | ForEach-Object { [int]$_ } -join $separator
}

function suball {
	$s = $input
	1..$s.Length | ForEach-Object {
		$len = $_
		0..($s.Length - $len) | ForEach-Object {
			$s.Substring($_, $len)
		}
	}
}

#endregion

#region Number Operations (数字操作)

function mod([int]$divisor) {
	$input % $divisor
}

function idiv([int]$divisor) {
	[int]($input / $divisor)
}

function sgn {
	[Math]::Sign($input)
}

function even {
    ($input % 2) -eq 0
}

function odd {
    ($input % 2) -ne 0
}

function gcd([int]$a, [int]$b) {
	if ($b -eq 0) {
		$a
	}
	else {
		gcd $b ($a % $b)
	}
}

function lcm([int]$a, [int]$b) {
    ($a * $b) / (gcd $a $b)
}

function fac([int]$n) {
	if ($n -le 1) {
		1
	}
	else {
		$n * (fac ($n - 1))
	}
}

function qpow([int]$base, [int]$exponent) {
	$result = 1
	while ($exponent -gt 0) {
		if ($exponent -band 1) {
			$result *= $input
		}
		$input = $input * $input
		$exponent = $exponent -shr 1
	}
	$result
}

function fib([int]$n) {
	$a, $b = 0, 1
	for ($i = 0; $i -lt $n; $i++) {
		$a, $b = $b, ($a + $b)
	}
	$a
}

function fibs([int]$n) {
	$a, $b = 0, 1
	$result = @()
	for ($i = 0; $i -lt $n; $i++) {
		$result += $a
		$a, $b = $b, ($a + $b)
	}
	$result
}

function isprime([int]$n) {
	if ($n -le 1) {
		return $false
	}
	if ($n -le 3) {
		return $true
	}
	if ($n % 2 -eq 0 -or $n % 3 -eq 0) {
		return $false
	}
	for ($i = 5; $i * $i -le $n; $i += 6) {
		if ($n % $i -eq 0 -or $n % ($i + 2) -eq 0) {
			return $false
		}
	}
	return $true
}

function factors([int]$n) {
	1..[math]::Sqrt($n) | ForEach-Object {
		if ($n % $_ -eq 0) {
			$_
			if ($_ -ne ($n / $_)) {
				$n / $_
			}
		}
	}
}

#endregion

#region Array/Collection Operations (数组/集合操作)

function hd {
	$input[0]
}

function tl {
	$input[-1]
}

function rest {
	$input[1..($input.Length - 1)]
}

function take([int]$n) {
	$input[0..($n - 1)]
}

function drop([int]$n) {
	$input[$n..($input.Length - 1)]
}

function sum {
    ($input | Measure-Object -Sum).Sum
}

function avg {
    ($input | Measure-Object -Average).Average
}

function min {
    ($input | Measure-Object -Minimum).Minimum
}

function max {
    ($input | Measure-Object -Maximum).Maximum
}

function uniq {
	$input | Select-Object -Unique
}

function srt {
	$input | Sort-Object
}

function rvs {
	[array]::Reverse($input)
	$input
}

function flat {
	$input | ForEach-Object {
		if ($_ -is [System.Collections.IEnumerable] -and $_ -isnot [string]) {
			flat $_
		}
		else {
			$_
		}
	}
}

function gpby([string]$property) {
	$input | Group-Object -Property $property
}

function ct {
	$input.Count
}

function flt([scriptblock]$scriptblock) {
	$input | Where-Object -FilterScript $scriptblock
}

function intersect([object[]]$arr2) {
	Compare-Object $input $arr2 -IncludeEqual -ExcludeDifferent |
	Where-Object { $_.SideIndicator -eq '==' } |
	ForEach-Object { $_.InputObject }
}

function diff([object[]]$arr2) {
	Compare-Object $input $arr2 -ExcludeDifferent |
	Where-Object { $_.SideIndicator -eq '<=' } |
	ForEach-Object { $_.InputObject }
}
function perm([System.Collections.ArrayList]$arr) {
	if ($arr.Count -le 1) {
		, $arr
		return
	}

	for ($i = 0; $i -lt $arr.Count; $i++) {
		$copy = [System.Collections.ArrayList]::new($arr)
		$first = $copy[$i]
		$copy.RemoveAt($i)
		$subPerms = perm $copy
		foreach ($subPerm in $subPerms) {
			[System.Collections.ArrayList]$newPerm = [System.Collections.ArrayList]::new($subPerm)
			$newPerm.Insert(0, $first)
			, $newPerm
		}
	}
}

function comb([int]$k, [System.Collections.ArrayList]$arr) {
	if ($k -eq 0) {
		, @()
		return
	}
	if ($arr.Count -lt $k) {
		return
	}
	if ($arr.Count -eq $k) {
		, $arr
		return
	}
	$first = $arr[0]
	$rest = [System.Collections.ArrayList]::new($arr)
	$rest.RemoveAt(0)
	$combsWithFirst = comb ($k - 1) $rest | ForEach-Object {
		[System.Collections.ArrayList]$newComb = [System.Collections.ArrayList]::new($_)
		$newComb.Insert(0, $first)
		, $newComb
	}
	$combsWithoutFirst = comb $k $rest
	$combsWithFirst + $combsWithoutFirst
}

function transpose {
	if ($input -isnot [System.Array] -or $input[0] -isnot [System.Collections.IEnumerable]) {
		Write-Error "输入必须是二维数组"
		return
	}

	$rows = $input.Length
	$cols = $input[0].Length
	$result = @()

	for ($j = 0; $j -lt $cols; $j++) {
		$newRow = @()
		for ($i = 0; $i -lt $rows; $i++) {
			$newRow += $input[$i][$j]
		}
		$result += , $newRow
	}

	$result
}

function tohash {
	$h = @{}
	$input | ForEach-Object {
		$h[$_[0]] = $_[1]
	}
	$h
}

#endregion

#region Logical Operations (逻辑操作)

function all([scriptblock]$scriptblock) {
	if ($scriptblock) {
		!($input | Where-Object -FilterScript $scriptblock | Measure-Object).Count
	}
	else {
		!($input | Where-Object -FilterScript { -not $_ } | Measure-Object).Count
	}
}

function any([scriptblock]$scriptblock) {
	if ($scriptblock) {
        ($input | Where-Object -FilterScript $scriptblock | Measure-Object).Count
	}
	else {
        ($input | Where-Object -FilterScript { $_ } | Measure-Object).Count
	}
}

function iif([bool]$condition, [scriptblock]$trueBlock, [scriptblock]$falseBlock) {
	if ($condition) {
		& $trueBlock
	}
	else {
		& $falseBlock
	}
}

function rep([int]$n, [scriptblock]$block) {
	1..$n | ForEach-Object $block
}

function map([scriptblock]$block) {
	$input | ForEach-Object $block
}

function reduce([scriptblock]$block, $init = $null) {
	$result = $init
	if ($result -eq $null) {
		$result = $input[0]
		$input = $input | drop 1
	}
	foreach ($i in $input) {
		$result = & $block $result $i
	}
	$result
}

#endregion

#region Other Utilities (其他实用工具)

function rng([int]$start, [int]$end) {
	$start..$end
}

function time([scriptblock]$scriptblock) {
	Measure-Command -Expression $scriptblock
}

function exit {
	exit
}

function up {
	$input.ToUpper()
}

function low {
	$input.ToLower()
}

function len {
	$input.Length
}

function trim {
	$input.Trim()
}

function int {
	[int]$input
}

function chr {
	[char]$input
}

function ord {
	[int][char]$input
}

function jo([string]$separator = '') {
	$input -join $separator
}

function sp([string]$separator = ' ') {
	$input -split $separator
}

function randstr([int]$length = 8, [string]$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
	-join (1..$length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function sleep([int]$ms) {
	Start-Sleep -Milliseconds $ms
}

function dbg([object]$input) {
	Write-Debug ($input | Out-String)
}

function try_parse_int([string]$str, [ref]$result) {
	$success = [int]::TryParse($str, [ref]$result.Value)
	return $success
}

function safe_int([string]$s) {
	if ($s -match "^\d+$") {
		[int]$s
	}
	else {
		0
	}
}

function b64e([string]$text) {
	[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($text))
}

function b64d([string]$base64Text) {
	[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64Text))
}
#endregion

#region Aliases (别名)
Set-Alias -Name mo -Value Measure-Object
Set-Alias -Name se -Value Select-Object
Set-Alias -Name read -Value Read-Host  # 保留 read，因为有些时候需要交互式输入
#endregion

#region 输入参数的简写
$I = $Input
$SI = "$I"
$CI = [CHAR[]]$SI
$A = $Args
$SA = "$A"
$CA = [CHAR[]]$SA

if ($A -and (try_parse_int $A[0] ([ref]$null))) {
	$N = [int]$A[0]
}

if ($A -and ($A | ForEach-Object { $_ -match '^\d+$' } | & {
			process { $r = $true }
			begin { $r = $true }
			end { $r -and $_ }
		})) {
	$NA = $A -as [int[]]
}
function a_map([scriptblock]$block) {
	$A | ForEach-Object $block
}

#endregion

#region 数学运算

function pow($exp = 2) {
	$input | ForEach-Object {
		[Math]::Pow($_, $exp)
	}
}

function sqrt {
	$input | ForEach-Object {
		[Math]::Sqrt($_)
	}
}

function floor {
	$input | ForEach-Object {
		[Math]::Floor($_)
	}
}

function ceil {
	$input | ForEach-Object {
		[Math]::Ceiling($_)
	}
}

function round {
	$input | ForEach-Object {
		[Math]::Round($_)
	}
}

function abs {
	$input | ForEach-Object {
		[Math]::Abs($_)
	}
}

#endregion

#region 扩展

function deepflat {
	$input | ForEach-Object {
		if ($_ -is [System.Collections.IEnumerable] -and $_ -isnot [string]) {
			deepflat $_
		}
		else {
			$_
		}
	}
}

function issorted([int]$direction = 1) {
	if ($input.Length -le 1) {
		return $true
	}
	for ($i = 1; $i -lt $input.Length; $i++) {
		if ($direction -gt 0 -and $input[$i - 1] -gt $input[$i]) {
			return $false
		}
		elseif ($direction -lt 0 -and $input[$i - 1] -lt $input[$i]) {
			return $false
		}
	}
	return $true
}

function readj {
	Get-Content -Raw $MyInvocation.MyCommand.Path | ConvertFrom-Json
}

function uniqo {
	$seen = @{}
	$input | Where-Object {
		$key = $_
		if ($key -is [System.Collections.IStructuralEquatable]) {
			$key = $_.GetHashCode()  # 对于复杂对象使用哈希
		}
		if (-not $seen.ContainsKey($key)) {
			$seen[$key] = $true
			$true  #输出
		}
	}
}

function counts {
	$input | Group-Object -NoElement | ForEach-Object {
        ($_.Name, $_.Count)
	} | tohash
}

#endregion
