@{
	# 与此清单关联的脚本模块或二进制模块文件。
	RootModule             = 'ps12exe.psm1'

	# 此模块的版本号。
	ModuleVersion          = '0.0.0'

	# 支持的 PSEditions
	# CompatiblePSEditions = @()

	# 用于唯一标识此模块的 ID
	GUID                   = '0bdadd0c-4365-422a-b7d4-62c2ea6d2d14'

	# 此模块的作者
	Author                 = 'steve02081504'

	# 此模块的公司或供应商
	CompanyName            = 'Unknown'

	# 此模块的版权声明
	Copyright              = '(c) steve02081504.'

	# 此模块所提供功能的说明
	Description            = @'
better pwsh code 2 exe repo:
- Use `ps12exe a.ps1` to convert `a.ps1` into `a.exe`;
- Use `ps12exeGUI` for a graphical interface that simplifies compilation;
- Use `Set-ps12exeContextMenu` to add a context menu item for quick compilation or GUI access on `.ps1` files;
- Use `Start-ps12exeWebServer` to launch a web server that allows users to compile scripts online;
- Use `Enter-ps12exeInteract` to enter an interactive mode for compiling scripts without parameters;
- Use `exe21sp` to extract the PowerShell script from a ps12exe-generated executable back into a `.ps1` script.
All commands in this module support the `-help` option for detailed assistance in your language.
'@

	# 此模块所需的 PowerShell 引擎最低版本
	PowerShellVersion      = '5.0'

	# 此模块所需的 PowerShell 主机名称
	# PowerShellHostName = ''

	# 此模块所需的 PowerShell 主机最低版本
	# PowerShellHostVersion = ''

	# 此模块所需的 Microsoft .NET Framework 最低版本。此外先决条件仅对 PowerShell Desktop 版有效。
	DotNetFrameworkVersion = '4.0'

	# 此模块所需的公共语言运行时 (CLR) 最低版本。此外先决条件仅对 PowerShell Desktop 版有效。
	# ClrVersion = ''

	# 此模块所需的处理器架构（None、X86、Amd64）
	# ProcessorArchitecture = ''

	# 导入此模块前必须先导入到全局环境的模块
	# RequiredModules = @()

	# 导入此模块前必须加载的程序集
	# RequiredAssemblies = @()

	# 导入此模块前在调用方环境中运行的脚本文件 (.ps1)。
	# ScriptsToProcess = @()

	# 导入此模块时要加载的类型文件 (.ps1xml)
	# TypesToProcess = @()

	# 导入此模块时要加载的格式文件 (.ps1xml)
	# FormatsToProcess = @()

	# 作为 RootModule/ModuleToProcess 所指定模块的嵌套模块导入的模块
	# NestedModules = @()

	# 从此模块导出的函数；为获得最佳性能，请勿使用通配符，也不要删除该项；如果没有要导出的函数，请使用空数组。
	FunctionsToExport      = @('ps12exe', 'ps12exeGUI', 'Set-ps12exeContextMenu', 'Start-ps12exeWebServer', 'Enter-ps12exeInteract', 'exe21sp')

	# 从此模块导出的 Cmdlet；为获得最佳性能，请勿使用通配符，也不要删除该项；如果没有要导出的 Cmdlet，请使用空数组。
	# CmdletsToExport = @()

	# 从此模块导出的变量
	# VariablesToExport = @()

	# 从此模块导出的别名；为获得最佳性能，请勿使用通配符，也不要删除该项；如果没有要导出的别名，请使用空数组。
	# AliasesToExport = @()

	# 从此模块导出的 DSC 资源
	# DscResourcesToExport = @()

	# 与此模块一起打包的所有模块的列表
	# ModuleList = @()

	# 传递给 RootModule/ModuleToProcess 所指定模块的私有数据。其中还可包含一个 PSData 哈希表，带有供 PowerShell 使用的其他模块元数据。
	PrivateData            = @{
		PSData = @{
			# 应用于此模块的标记。这些标记有助于在在线库中发现模块。
			Tags       = @('Executable', 'Compiler', 'ps2exe', 'exe', 'ps12exe', 'Windows')

			# 此模块许可证的 URL。
			LicenseUri = 'https://github.com/steve02081504/ps12exe/blob/master/LICENSE'

			# 此项目主网站的 URL。
			ProjectUri = 'https://github.com/steve02081504/ps12exe'

			# 表示此模块的图标的 URL。
			IconUri    = 'https://raw.githubusercontent.com/steve02081504/ps12exe/master/img/icon.ico'

			# 此模块的发行说明
			# ReleaseNotes = ''

			# 此模块的预发布字符串
			# Prerelease = ''

			# 指示此模块在安装/更新/保存时是否需要用户明确接受的标志
			# RequireLicenseAcceptance = $false

			# 此模块的外部依赖模块
			# ExternalModuleDependencies = @()
		}
	}

	# 此模块的 HelpInfo URI
	# HelpInfoURI = ''

	# 从此模块导出的命令的默认前缀。可使用 Import-Module -Prefix 覆盖默认前缀。
	# DefaultCommandPrefix = ''
}
