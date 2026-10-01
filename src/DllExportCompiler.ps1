# 原生 DLL 导出（#_DllExport / Build.DllExports）实现。
#
# 产物是两层：CodeDom 先把程序帧编成普通托管类库 payload（内含真正的导出实现），gzip 后内嵌进一个
# 极小的 launcher（DllExportPack.cs）；launcher 的静态构造在首次导出调用前解压 Assembly.Load 出 payload，
# 导出包装直接静态转发过去，所以每个导出调用没有额外检查/加锁（见 src/CodeDomCompiler.ps1 的 DllExport 分支）。
#
# 本文件负责：生成 payload 侧包装（初始化宿主并调用脚本函数）、生成 launcher 侧转发包装，以及用 AsmResolver
# 给 launcher 的导出包装设置 UnmanagedExportInfo，由托管 PE 写出器生成 native 导出桩 + CLR vtable fixup
# （VTableFromUnmanaged），使产物可被 native 的 LoadLibrary/GetProcAddress 直接加载。
# 这正是 ilasm 对 `.export` 指令所做的事，但省掉了 ildasm→文本→ilasm 的往返与外部进程。
#
# 导出名指针表必须按字典序升序，Windows 才能二分查找：Get-SortedDllExports 让元数据方法顺序有序，作为
# AsmResolver 未修复时的脚本层兜底（issue #792；当前 src/bin 的特供版内部已排序）。
#
# AsmResolver 与 ExeSinker 共用 src/bin 下 illink 裁剪并合并过的单个 AsmResolver.dll；本路径额外用到
# DotNet 层的 module 写出器，相关 API 必须镜像在 tools/AsmResolver/Root.cs 中（见该文件）。

# 惰性加载 AsmResolver（含 DotNet 层）。返回是否可用。
function Import-DllExportAssemblies {
	if ('AsmResolver.DotNet.ModuleDefinition' -as [type]) { return $true }
	try {
		Add-Type -LiteralPath (Join-Path $PSScriptRoot 'bin/AsmResolver.dll') -ErrorVariable $null
	}
	catch {
		$_.Exception.LoaderExceptions | Out-String | Write-Verbose
		$Error.Remove($_)
	}
	return [bool]('AsmResolver.DotNet.ModuleDefinition' -as [type])
}

# 取导出声明里的字段（哈希表与 PSCustomObject 都支持；两者查找都不区分大小写）。
function Get-DllExportField {
	param($Entry, [string]$Name, $Default)
	if ($Entry -is [System.Collections.IDictionary]) {
		if ($Entry.Contains($Name)) { return $Entry[$Name] }
	}
	elseif ($Entry.PSObject.Properties.Match($Name).Count) { return $Entry.$Name }
	return $Default
}

# 按导出函数名以序数、区分大小写排序。PE 导出名指针表必须按字典序升序，Windows 才能二分查找（GetProcAddress）。
# 当前 AsmResolver 特供版内部已排序；这里排好元数据方法顺序，使未修复的上游版本也能正确产出（issue #792 的脚本层兜底）。
function Get-SortedDllExports {
	param([object[]]$Exports)
	$sorted = @($Exports)
	[Array]::Sort($sorted, [System.Comparison[object]] {
		param($a, $b)
		[string]::CompareOrdinal("$(Get-DllExportField $a 'funcname' '')".Trim(), "$(Get-DllExportField $b 'funcname' '')".Trim())
	})
	return , $sorted
}

# 由导出声明生成 C# 包装方法源码；返回 @{ Code; Map }，Map 为 @(@{ Method; Export }) 供 AsmResolver 注入。
# 默认生成 payload 侧包装（初始化宿主并调用脚本函数）；-Forward 生成 launcher 侧包装（直接静态转发到 payload 的同名方法）。
function New-DllExportMethods {
	param([object[]]$Exports, [switch]$Forward)
	$Exports = Get-SortedDllExports $Exports
	$sb = [System.Text.StringBuilder]::new()
	$map = @()
	for ($i = 0; $i -lt $Exports.Count; $i++) {
		$entry = $Exports[$i]
		$returnType = "$(Get-DllExportField $entry 'returntype' 'void')".Trim()
		$funcName = "$(Get-DllExportField $entry 'funcname' '')".Trim()
		if (-not $funcName) { throw "第 $($i + 1) 个导出缺少函数名" }
		if ($returnType -match '[\r\n";{}]' -or $funcName -match '[\r\n''"]') { throw "非法的导出声明：$returnType $funcName" }

		$params = @(Get-DllExportField $entry 'params' @())
		$csParams = @()
		$csArgs = @()
		for ($p = 0; $p -lt $params.Count; $p++) {
			$paramEntry = $params[$p]
			$pType = "$(Get-DllExportField $paramEntry 'type' 'string')".Trim()
			$pName = "$(Get-DllExportField $paramEntry 'name' "arg$p")".Trim()
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
		if ($Forward) {
			# launcher 的导出包装：直接静态调用 payload 里的同名包装（payload 侧已吞掉异常并返回默认值）。
			$forwardCall = "PSRunnerEntry.$methodName($($csArgs -join ', '))"
			if ($returnType -ieq 'void') { [void]$sb.AppendLine("`t`t`t$forwardCall;") }
			else { [void]$sb.AppendLine("`t`t`treturn $forwardCall;") }
		}
		elseif ($returnType -ieq 'void') {
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

# 在所有类型（含嵌套）里按名字找方法定义。
function Get-DllExportMethodDefinition {
	param($Module, [string]$MethodName)
	foreach ($type in $Module.GetAllTypes()) {
		foreach ($method in $type.Methods) {
			if ($method.Name.ToString() -eq $MethodName) { return $method }
		}
	}
	return $null
}

# 给已编译的托管类库注入原生导出。$Exports 为 New-DllExportMethods 的 Map。
function Add-DllExportsToAssembly {
	param([string]$AssemblyPath, [object[]]$Exports, [string]$Architecture)
	if (-not (Import-DllExportAssemblies)) {
		Write-I18n Error DllExportToolchainFailed 'src/bin/AsmResolver.dll' -Category NotInstalled
		throw "AsmResolver is unavailable: $PSScriptRoot\bin\AsmResolver.dll"
	}

	$module = [AsmResolver.DotNet.ModuleDefinition]::FromFile($AssemblyPath)
	# x86 用 32 位 vtable 项，x64 用 64 位；二者都配 COR_VTABLE_FROM_UNMANAGED 让 CLR 生成 native 入口桩。
	$vtableEnum = [AsmResolver.PE.DotNet.VTableFixups.VTableType]
	$bitValue = if ($Architecture -eq 'x86') { [int]$vtableEnum::VTable32Bit } else { [int]$vtableEnum::VTable64Bit }
	$vtableType = [AsmResolver.PE.DotNet.VTableFixups.VTableType]($bitValue -bor [int]$vtableEnum::VTableFromUnmanaged)

	foreach ($export in $Exports) {
		$method = Get-DllExportMethodDefinition -Module $module -MethodName $export.Method
		if (-not $method) {
			Write-I18n Error DllExportMethodNotFound $export.Method -Category InvalidData
			throw "export method not found in assembly: $($export.Method)"
		}
		$method.ExportInfo = [AsmResolver.DotNet.UnmanagedExportInfo]::new("$($export.Export)", $vtableType)
	}

	# 原生导出依赖 mscoree 的 CLR 引导桩：必须去掉 ILOnly，否则 AsmResolver 不会写出 _CorDllMain 导入。
	$ilOnly = [int][AsmResolver.PE.DotNet.DotNetDirectoryFlags]::ILOnly
	$module.Attributes = [AsmResolver.PE.DotNet.DotNetDirectoryFlags](([int]$module.Attributes) -band (-bnot $ilOnly))

	$tmp = $AssemblyPath + '.asmresolver.tmp'
	try {
		$module.Write($tmp)
		Remove-Item -LiteralPath $AssemblyPath -Force
		Move-Item -LiteralPath $tmp -Destination $AssemblyPath -Force
	}
	finally {
		Remove-Item -LiteralPath $tmp -Force -ErrorAction Ignore
	}
}
