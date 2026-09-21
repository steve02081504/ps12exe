# 原生 DLL 导出（#_DllExport / Build.DllExports）实现。
#
# 机制：先用 CodeDom 把程序帧编译成普通 .NET 类库，再用 ildasm 反汇编、在每个导出方法体开头插入
# ILAsm 的 `.export [ordinal] as '名字'` 指令，最后用 ilasm 重新汇编。ilasm 会为该指令生成
# native 导出桩 + CLR vtable fixup，使产物可被 native 的 LoadLibrary/GetProcAddress 直接加载。
# 这正是 RGiesecke.DllExport / 3F DllExport 的做法（不用它们自己的 MSBuild 任务，避免依赖完整工程）。
#
# 工具链（ilasm.exe/ildasm.exe）随模块内置在 src/bin/ILAsm：官方 Microsoft.NETCore.ILAsm/ILDAsm
# 的 win-x64 运行时包（MIT），同一份 x64 工具即可产出 x64 与 x86 产物（靠 /x64 或 /32bit 切换）。
# 注意：不要改用 3F ILAsm 包里的 ilasm——它在 x64 上生成的 CLR 引导桩有问题（exe 会挂起）。

$script:DllExportToolDir = Join-Path $PSScriptRoot 'bin/ILAsm'

# 定位内置的原生导出工具链；返回 @{ IlAsm; IlDasm }。
function Get-DllExportToolchain {
	$ilasmPath = Join-Path $script:DllExportToolDir 'ilasm.exe'
	$ildasmPath = Join-Path $script:DllExportToolDir 'ildasm.exe'
	if (-not ((Test-Path -LiteralPath $ilasmPath) -and (Test-Path -LiteralPath $ildasmPath))) {
		Write-I18n Error DllExportToolchainFailed $script:DllExportToolDir -Category NotInstalled
		throw "native export toolchain is missing: $script:DllExportToolDir"
	}
	return @{ IlAsm = $ilasmPath; IlDasm = $ildasmPath }
}

function Get-DllExportField {
	param($Entry, [string]$Name, [string]$AltName, $Default)
	if ($Entry -is [System.Collections.IDictionary]) {
		if ($Entry.Contains($Name)) { return $Entry[$Name] }
		if ($AltName -and $Entry.Contains($AltName)) { return $Entry[$AltName] }
	}
	else {
		foreach ($n in @($Name, $AltName)) {
			if (-not $n) { continue }
			if ($Entry.PSObject.Properties.Match($n).Count) { return $Entry.$n }
		}
	}
	return $Default
}

# 由导出声明生成 C# 包装方法源码；返回 @{ Code; Map }，Map 为 @(@{ Method; Export }) 供 IL 注入。
function New-DllExportMethods {
	param([object[]]$Exports)
	$sb = [System.Text.StringBuilder]::new()
	$map = @()
	for ($i = 0; $i -lt $Exports.Count; $i++) {
		$entry = $Exports[$i]
		$returnType = "$(Get-DllExportField $entry 'returntype' 'returnType' 'void')".Trim()
		$funcName = "$(Get-DllExportField $entry 'funcname' 'funcName' '')".Trim()
		if (-not $funcName) { throw "第 $($i + 1) 个导出缺少函数名" }
		if ($returnType -match '[\r\n";{}]' -or $funcName -match '[\r\n''"]') { throw "非法的导出声明：$returnType $funcName" }

		$params = @(Get-DllExportField $entry 'params' 'Params' @())
		$csParams = @()
		$csArgs = @()
		for ($p = 0; $p -lt $params.Count; $p++) {
			$paramEntry = $params[$p]
			$pType = "$(Get-DllExportField $paramEntry 'type' 'Type' 'string')".Trim()
			$pName = "$(Get-DllExportField $paramEntry 'name' 'Name' "arg$p")".Trim()
			if ($pName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { $pName = "arg$p" }
			if ($pType -match '[\r\n";{}]') { throw "非法的参数类型：$pType" }
			$csParams += "$pType $pName"
			$csArgs += $pName
		}

		$methodName = "PS12ExeDllExport$i"
		$map += @{ Method = $methodName; Export = $funcName }
		$escapedFunc = $funcName.Replace('\', '\\').Replace('"', '\"')
		$paramList = ($csParams -join ', ')
		$argsList = if ($csArgs.Count) { 'new object[] { ' + ($csArgs -join ', ') + ' }' } else { 'new object[0]' }

		[void]$sb.AppendLine()
		[void]$sb.AppendLine("`t`tpublic static $returnType $methodName($paramList) {")
		if ($returnType -ieq 'void') {
			[void]$sb.AppendLine("`t`t`ttry { DllInitChecker(); InvokePSFunction(`"$escapedFunc`", $argsList); }")
			[void]$sb.AppendLine("`t`t`tcatch (System.Exception ex) { ReportDllExportError(`"$escapedFunc`", ex); }")
		}
		else {
			[void]$sb.AppendLine("`t`t`ttry { DllInitChecker(); return ($returnType)InvokePSFunction(`"$escapedFunc`", $argsList); }")
			[void]$sb.AppendLine("`t`t`tcatch (System.Exception ex) { ReportDllExportError(`"$escapedFunc`", ex); return default($returnType); }")
		}
		[void]$sb.AppendLine("`t`t}")
	}
	return @{ Code = $sb.ToString(); Map = $map }
}

# 在 IL 文本里给指定方法体开头插入 .export 指令（返回新的行数组）。
function Add-DllExportDirective {
	param([string[]]$Lines, [string]$MethodName, [string]$ExportName)
	$namePattern = '\b' + [regex]::Escape($MethodName) + '\b'
	for ($i = 0; $i -lt $Lines.Count; $i++) {
		if ($Lines[$i] -notmatch '^\s*\.method\b') { continue }
		# .method 头可能跨多行；名字与方法体起始的 `{` 之间收集为一个头。
		$j = $i
		while ($j -lt $Lines.Count -and $Lines[$j] -notmatch '\{') { $j++ }
		if ($j -ge $Lines.Count) { break }
		$header = $Lines[$i..$j] -join "`n"
		if ($header -match $namePattern) {
			$result = [System.Collections.Generic.List[string]]::new()
			for ($k = 0; $k -le $j; $k++) { $result.Add($Lines[$k]) }
			$result.Add("`t`t.export $ExportName")
			for ($k = $j + 1; $k -lt $Lines.Count; $k++) { $result.Add($Lines[$k]) }
			return $result.ToArray()
		}
		$i = $j
	}
	Write-I18n Error DllExportMethodNotFound $MethodName -Category InvalidData
	throw "export method not found in IL: $MethodName"
}

# 对已编译的托管类库做 IL 往返，注入原生导出。$Exports 为 New-DllExportMethods 的 Map。
function Add-DllExportsToAssembly {
	param([string]$AssemblyPath, [object[]]$Exports, [string]$Architecture)
	$tool = Get-DllExportToolchain
	$work = Join-Path ([System.IO.Path]::GetDirectoryName($AssemblyPath)) ('ps12exe-dllx-' + [Guid]::NewGuid().ToString('N'))
	New-Item -ItemType Directory -Force -Path $work | Out-Null
	try {
		$ilBase = Join-Path $work 'assembly'
		$ilPath = "$ilBase.il"
		$ilasmOut = Join-Path $work 'out.dll'

		& $tool.IlDasm "/out:$ilPath" $AssemblyPath | Out-Null
		if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ilPath)) { throw "ildasm failed ($LASTEXITCODE)" }

		$lines = [System.IO.File]::ReadAllLines($ilPath)
		for ($i = 0; $i -lt $Exports.Count; $i++) {
			$exportName = "'" + "$($Exports[$i].Export)".Replace("'", "''") + "'"
			$lines = Add-DllExportDirective -Lines $lines -MethodName $Exports[$i].Method -ExportName ("[$($i + 1)] as $exportName")
		}
		[System.IO.File]::WriteAllLines($ilPath, $lines, [System.Text.UTF8Encoding]::new($false))

		$bitness = if ($Architecture -eq 'x86') { '/32bit' } else { '/x64' }
		& $tool.IlAsm /nologo /dll $bitness "/output:$ilasmOut" $ilPath | Out-Null
		if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ilasmOut)) { throw "ilasm failed ($LASTEXITCODE)" }

		Remove-Item -LiteralPath $AssemblyPath -Force
		Move-Item -LiteralPath $ilasmOut -Destination $AssemblyPath -Force
	}
	finally {
		Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
	}
}
