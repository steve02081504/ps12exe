# ps12exeGUI 界面 schema：唯一描述「界面上有哪些字段、对应哪个参数路径、用什么控件、默认值是什么」的地方。
#
# 新增/修改 ps12exe 参数时：先改这里，再到 src/locale/<lang>.ps1 的 GUI 里补 Field.<Path> 文案。
# tests/cases/*-gui*.ps1 的 gui.schema-coverage 用例会校验 PrarmsData 的叶子键都被 schema 覆盖。
#
# Field 通用键：
#   Path        参数点号路径（如 'Build.Core.Trimmed'）；'inputFile'/'outputFile' 为顶层。
#               Path='Signing.Enabled' 是合成字段，不对应真实 ps12exe 参数。
#   Kind        控件类型，见下。
#   Label       GUI 文案对象的点号路径；缺省为 "Field.<Path>"。
#   Default     默认值，必须与 ps12exe.ps1 里 Get-Opt 的默认值一致。
#   Choices     Kind=Choice/ChoiceEdit 时的选项数组（显示值即参数值，技术字符串不翻译）。
#   ChoicesWhen 可选 scriptblock($UIData)，返回要显示的子集（如按 Target 过滤 Platform）。
#   Browse      Kind=Path 时的文件对话框键：Compile/Output/Icon/Certificate/Folder。
#   Multiline   Kind=Script 时多行。
#   Rows        Kind=Script 的行数。
#   Options     Kind=Flags 时的选项数组。
#   EnabledWhen 可选 scriptblock($UIData)，返回该控件是否可用。
#   Validate   可选 scriptblock($Value,$UIData)；值非法时返回错误文案（合法返回空），GUI 据此把控件标红并把文案挂到 ToolTip。
#   Help       可选 GUI 文案对象的点号路径；缺省从 ConsoleHelpData.PrarmsData 按 Path 自动取，取不到用 Label。
#
# Kind：
#   Bool        CheckBox
#   Text        TextBox
#   Choice      ComboBox（DropDownList）
#   ChoiceEdit  ComboBox（可编辑）
#   Path        TextBox + 浏览按钮 + 拖放
#   Password    TextBox（PasswordChar）
#   Script      多行 TextBox（脚本块）
#   Flags       一组 CheckBox（多选），值为选中项数组
#   DllExports  原生导出编辑表格
function Get-GUISchema {
	@{
		# PrarmsData 里这些键刻意不放进 GUI（由 CLI/GUI 启动参数或纯编程方式提供）。
		# gui.schema-coverage 用例会校验：PrarmsData 的每个叶子键要么在 schema 里，要么在这里列出。
		ExcludedHelpPaths = @('input', 'Content', 'Locale', 'Help')

		Pages             = @(
			@{
				Key    = 'General'
				Label  = 'Page.General'
				Groups = @(
					@{
						Key    = 'IO'
						Label  = 'Group.IO'
						Fields = @(
							@{ Path = 'inputFile'; Kind = 'Path'; Label = 'Field.inputFile'; Browse = 'Compile'; Default = ''; Validate = { param($Value, $UIData) if (-not (Test-GUIFileExists $Value)) { Get-GUIText 'Log.InvalidFile' } } }
							@{ Path = 'outputFile'; Kind = 'Path'; Label = 'Field.outputFile'; Browse = 'Output'; Default = ''; Validate = { param($Value, $UIData) if (-not (Test-GUIOutputDirExists $Value)) { Get-GUIText 'Log.InvalidDir' } } }
						)
					}
					@{
						Key    = 'Target'
						Label  = 'Group.Target'
						Fields = @(
							@{ Path = 'Build.Target'; Kind = 'Choice'; Choices = @('Framework4.0', 'Framework2.0', 'Core'); Default = 'Framework4.0' }
							@{ Path = 'Build.Platform'; Kind = 'Choice'; Choices = @('AnyCpu', 'x64', 'x86', 'arm64'); ChoicesWhen = { param($UIData) if ($UIData.Build.Target -eq 'Core') { @('AnyCpu', 'x64', 'x86', 'arm64') } else { @('AnyCpu', 'x64', 'x86') } }; Default = 'AnyCpu' }
							@{ Path = 'App.Windowed'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Os.Admin'; Kind = 'Bool'; Default = $false }
							@{ Path = 'ConfigFile'; Kind = 'Bool'; Default = $false }
						)
					}
				)
			}
			@{
				Key    = 'App'
				Label  = 'Page.App'
				Groups = @(
					@{
						Key    = 'Silence'
						Label  = 'Group.Silence'
						Fields = @(
							@{ Path = 'App.Silence'; Kind = 'Flags'; Options = @('Output', 'Verbose', 'Error', 'Warning', 'Debug'); Default = @() }
						)
					}
					@{
						Key    = 'Console'
						Label  = 'Group.Console'
						Fields = @(
							@{ Path = 'App.OutputEncoding'; Kind = 'Choice'; Choices = @('Default', 'UTF8', 'UTF16LE'); Default = 'Default'; EnabledWhen = { param($UIData) -not $UIData.App.Windowed } }
							@{ Path = 'App.CredentialGUI'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) -not $UIData.App.Windowed } }
							@{ Path = 'App.ConHost'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) -not $UIData.App.Windowed } }
						)
					}
					@{
						Key    = 'Windowed'
						Label  = 'Group.Windowed'
						Fields = @(
							@{ Path = 'App.VisualStyles'; Kind = 'Bool'; Default = $true; EnabledWhen = { param($UIData) $UIData.App.Windowed } }
							@{ Path = 'App.DarkMode'; Kind = 'Choice'; Choices = @('Auto', 'On', 'Off'); Default = 'Auto'; EnabledWhen = { param($UIData) $UIData.App.Windowed } }
							@{ Path = 'App.ExitOnCancel'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.App.Windowed } }
							@{ Path = 'App.DpiAware'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.App.Windowed } }
							@{ Path = 'App.WinFormsDpiAware'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.App.Windowed } }
						)
					}
				)
			}
			@{
				Key    = 'OS'
				Label  = 'Page.OS'
				Groups = @(
					@{
						Key    = 'OS'
						Label  = 'Group.OS'
						Fields = @(
							@{ Path = 'Os.ModernOS'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Os.LongPaths'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Os.Virtualize'; Kind = 'Bool'; Default = $false }
						)
					}
				)
			}
			@{
				Key    = 'Build'
				Label  = 'Page.Build'
				Groups = @(
					@{
						Key    = 'Build'
						Label  = 'Group.Build'
						Fields = @(
							@{ Path = 'Build.Apartment'; Kind = 'Choice'; Choices = @('STA', 'MTA'); Default = 'STA' }
							@{ Path = 'Build.Culture'; Kind = 'Text'; Default = '' }
							@{ Path = 'Build.Options'; Kind = 'Text'; Default = '/o+ /debug-' }
							@{ Path = 'Build.KeepSource'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Build.Minify'; Kind = 'Script'; Multiline = $true; Rows = 4; Default = '' }
							@{ Path = 'Build.TempDir'; Kind = 'Path'; Browse = 'Folder'; Default = ''; Validate = { param($Value, $UIData) if (-not (Test-GUIDirectoryExists $Value)) { Get-GUIText 'Log.InvalidDir' } } }
						)
					}
					@{
						Key    = 'ConstEval'
						Label  = 'Group.ConstEval'
						Fields = @(
							@{ Path = 'Build.ConstEval.Enabled'; Kind = 'Bool'; Default = $true }
							@{ Path = 'Build.ConstEval.Timeout'; Kind = 'Bool'; Default = $false }
						)
					}
					@{
						Key    = 'DllExports'
						Label  = 'Group.DllExports'
						Fields = @(
							@{ Path = 'Build.DllExports'; Kind = 'DllExports'; Label = 'Field.Build.DllExports.Label'; Default = @(); Help = 'Field.Build.DllExports.Help'; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Framework4.0' } }
						)
					}
				)
			}
			@{
				Key    = 'Core'
				Label  = 'Page.Core'
				Groups = @(
					@{
						Key    = 'Core'
						Label  = 'Group.Core'
						Fields = @(
							@{ Path = 'Build.Core.Backend'; Kind = 'Choice'; Choices = @('Shared', 'Bundled'); Default = 'Shared'; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' } }
							@{ Path = 'Build.Core.TargetOs'; Kind = 'ChoiceEdit'; Choices = @('', 'Windows', 'Linux', 'MacOS'); Default = ''; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' } }
							@{ Path = 'Build.Core.TargetFramework'; Kind = 'ChoiceEdit'; Choices = @('', 'net8.0', 'net9.0', 'net10.0'); Default = ''; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' }; Validate = { param($Value, $UIData) if ($Value -and $Value -notmatch '^net\d+\.\d+$') { Get-GUIText 'Log.InvalidValue' } } }
							@{ Path = 'Build.Core.PowerShellVersion'; Kind = 'ChoiceEdit'; Choices = @(''); Default = ''; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' } }
							@{ Path = 'Build.Core.SingleFile'; Kind = 'Bool'; Default = $true; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' } }
							@{ Path = 'Build.Core.SelfContained'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' } }
							@{ Path = 'Build.Core.Trimmed'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' } }
							@{ Path = 'Build.Core.TrimMode'; Kind = 'Choice'; Choices = @('partial', 'full'); Default = 'partial'; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' -and $UIData.Build.Core.Trimmed } }
							@{ Path = 'Build.Core.ReadyToRun'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' } }
							@{ Path = 'Build.Core.InvariantGlobalization'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' } }
							@{ Path = 'Build.Core.Aot'; Kind = 'Bool'; Default = $false; EnabledWhen = { param($UIData) $UIData.Build.Target -eq 'Core' -and $UIData.Build.Core.Backend -eq 'Bundled' -and $UIData.Build.Core.SelfContained } }
						)
					}
				)
			}
			@{
				Key    = 'Resources'
				Label  = 'Page.Resources'
				Groups = @(
					@{
						Key    = 'Resources'
						Label  = 'Group.Resources'
						Fields = @(
							@{ Path = 'Resources.Icon'; Kind = 'Path'; Browse = 'Icon'; Default = ''; Validate = { param($Value, $UIData) if (-not (Test-GUIIconExists $Value)) { Get-GUIText 'Log.InvalidFile' } } }
							@{ Path = 'Resources.Title'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Description'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Company'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Product'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Copyright'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Trademark'; Kind = 'Text'; Default = '' }
							@{ Path = 'Resources.Version'; Kind = 'Text'; Default = '' }
						)
					}
				)
			}
			@{
				Key    = 'Signing'
				Label  = 'Page.Signing'
				Groups = @(
					@{
						Key    = 'Signing'
						Label  = 'Group.Signing'
						Fields = @(
							@{ Path = 'Signing.Enabled'; Kind = 'Bool'; Label = 'Field.Signing.Enabled'; Default = $false }
							@{ Path = 'Signing.Certificate'; Kind = 'Path'; Browse = 'Certificate'; Default = ''; EnabledWhen = { param($UIData) $UIData.Signing.Enabled }; Validate = { param($Value, $UIData) if (-not (Test-GUIFileExists $Value)) { Get-GUIText 'Log.InvalidFile' } } }
							@{ Path = 'Signing.Password'; Kind = 'Password'; Default = ''; EnabledWhen = { param($UIData) $UIData.Signing.Enabled } }
							@{ Path = 'Signing.Thumbprint'; Kind = 'Text'; Default = ''; EnabledWhen = { param($UIData) $UIData.Signing.Enabled } }
							@{ Path = 'Signing.Timestamp'; Kind = 'Text'; Default = 'http://timestamp.digicert.com'; EnabledWhen = { param($UIData) $UIData.Signing.Enabled } }
						)
					}
				)
			}
			@{
				Key    = 'Modes'
				Label  = 'Page.Modes'
				Groups = @(
					@{
						Key    = 'Modes'
						Label  = 'Group.Modes'
						Fields = @(
							@{ Path = 'PreprocessOnly'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Golf'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Sandbox'; Kind = 'Bool'; Default = $false }
							@{ Path = 'NoUpdateCheck'; Kind = 'Bool'; Default = $false }
							@{ Path = 'Quiet'; Kind = 'Bool'; Default = $false }
						)
					}
				)
			}
			@{
				Key    = 'About'
				Label  = 'Page.About'
				Type   = 'About'
				Groups = @()
			}
		)
	}
}
