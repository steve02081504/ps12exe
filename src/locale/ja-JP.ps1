@{
	LangName = "日本語"
	LangID = "ja-JP"
	# 右クリックメニュー
	CompileTitle		   = "EXEにコンパイル"
	OpenInGUI			   = "ps12exeGUIで開く"
	GUICfgFileDesc		   = "ps12exe GUI設定ファイル"
	# Webサーバー
	ServerStarted		   = "HTTPサーバーが起動しました！"
	ServerStopped		   = "HTTPサーバーが停止しました！"
	ServerStartFailed	   = "HTTPサーバーの起動に失敗しました！"
	TryRunAsRoot		   = "ルート権限で実行してください。"
	ServerListening		   = "アクセスアドレス："
	ExitServerTip		   = "いつでもCtrl+Cを押してサーバーを終了できます"
	# GUI
	ErrorHead			   = "エラー："
	CompileResult		   = "コンパイル結果"
	DefaultResult		   = "完了！"
	AskSaveCfg			   = "設定ファイルを保存しますか？"
	AskSaveCfgTitle		   = "設定ファイルの保存"
	CfgFileLabelHead	   = "設定ファイル："
	# コンソール
	WebServerHelpData	   = @{
		title	   = "使用方法："
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<パス>']
	[-Localize '<言語コード>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "登録するHTTPサーバーのアドレス。"
			MaxCompileThreads = "最大コンパイルスレッド数。"
			MaxCompileTime	  = "最大コンパイル時間（秒）。"
			ReqLimitPerMin	  = "IPアドレスごとの1分間のリクエスト制限。"
			MaxCachedFileSize = "最大キャッシュファイルサイズ。"
			MaxScriptFileSize = "最大スクリプトファイルサイズ。"
			CacheDir		  = "キャッシュディレクトリ。"
			Localize		  = "サーバー側の記録に使用する言語コード。"
			help			  = "このヘルプ情報を表示します。"
		}
	}
	GUIHelpData			   = @{
		title	   = "使用方法："
		Usage	   = "ps12exeGUI [[-ConfigFile] '<設定ファイル>'] [-Localize '<言語コード>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfigFile	= "読み込む設定ファイル。"
			Localize	= "使用する言語コード。"
			UIMode		= "使用するユーザーインターフェースモード。"
			help		= "このヘルプ情報を表示します。"
		}
	}
	SetContextMenuHelpData = @{
		title	   = "使用方法："
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<言語コード>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "実行するアクション。"
			Localize = "使用する言語コード。"
			help	 = "このヘルプ情報を表示します。"
		}
	}
	ConsoleHelpData		   = @{
		title	   = "使用方法："
		Usage	   = "[input |] ps12exe [[-inputFile] '<ファイル名|url>' | -Content '<スクリプト>'] [-outputFile '<ファイル名>']
	[-CompilerOptions '<オプション>'] [-TempDir '<ディレクトリ>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<ファイル名|url>'; title='<タイトル>'; description='<説明>'; company='<会社>';
	product='<製品>'; copyright='<著作権>'; trademark='<商標>'; version='<バージョン>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<ランタイムバージョン>']
	[-GuestMode] [-Localize '<言語コード>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "PowerShellスクリプトファイルの内容の文字列で、``-Content``と同じです"
			inputFile		 = "実行可能ファイルに変換したいPowerShellスクリプトファイルのパスまたはURL（ファイルはUTF8またはUTF16でエンコードされている必要があります）"
			Content			 = "実行可能ファイルに変換したいPowerShellスクリプトの内容"
			outputFile		 = "ターゲットの実行可能ファイル名またはディレクトリで、デフォルトは``'.exe'``拡張子を持つ``inputFile``です"
			CompilerOptions	 = "追加のコンパイラオプション（参照： ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``）"
			TempDir			 = "一時ファイルを保存するディレクトリ（デフォルトは``%temp%``にランダムに生成される一時ディレクトリ）"
			minifyer		 = "コンパイル前にスクリプトを縮小するスクリプトブロック"
			lcid			 = "コンパイルされた実行可能ファイルのロケールID。指定されていない場合は、現在のユーザーのカルチャーです"
			prepareDebug	 = "デバッグに役立つ情報を作成します"
			architecture	 = "特定のランタイムのみのコンパイル。可能な値は``'x64'``、``'x86'``、``'anycpu'``です"
			threadingModel	 = "``'STA'``（シングルスレッドアパートメント）または``'MTA'``（マルチスレッドアパートメント）モード"
			noConsole		 = "生成された実行可能ファイルは、コンソールウィンドウのないWindows Formsアプリケーションになります"
			UNICODEEncoding	 = "コンソールモードで出力をUNICODEでエンコードします"
			credentialGUI	 = "コンソールモードでGUIプロンプトを使用して資格情報を求めます"
			resourceParams	 = "コンパイルされた実行可能ファイルのリソースパラメータを含むハッシュテーブル"
			configFile		 = "設定ファイル（``<outputfile>.exe.config``）を書きます"
			noOutput		 = "生成された実行可能ファイルは、標準出力（詳細および情報チャネルを含む）を生成しません"
			noError			 = "生成された実行可能ファイルは、エラー出力（警告およびデバッグチャネルを含む）を生成しません"
			noVisualStyles	 = "生成されたWindows GUIアプリケーションのビジュアルスタイルを無効にします（``-noConsole``と共に使用）"
			exitOnCancel	 = '`Read-Host`入力ボックスで`Cancel`または`\"X\"`を選択したときにプログラムを終了します（``-noConsole``と共に使用）'
			DPIAware		 = "表示スケーリングが有効になっている場合、GUIコントロールは可能な限りスケーリングされます"
			winFormsDPIAware = "表示スケーリングが有効になっている場合、WinFormsはDPIスケーリングを使用します（Windows 10および.Net 4.7以上が必要）"
			requireAdmin	 = "UACが有効になっている場合、コンパイルされた実行可能ファイルは昇格されたコンテキストでのみ実行可能です（必要に応じてUACダイアログが表示されます）"
			supportOS		 = "最新のWindowsバージョンの機能を使用します（``[Environment]::OSVersion``を実行して違いを確認）"
			virtualize		 = "アプリケーションの仮想化が有効になっています（x86ランタイムを強制）"
			longPaths		 = "OSで有効になっている場合、長いパス（260文字以上）を有効にします（Windows 10以上にのみ適用）"
			targetRuntime	 = "ターゲット ランタイム バージョン、既定値は 'Framework4.0'、'Framework2.0' がサポートされています"
			GuestMode		 = "ネイティブ ファイルへのアクセスを防ぐために、スクリプトをコンパイルする際に保護を追加します"
			Localize		 = "使用する言語コード"
			Help			 = "このヘルプ情報を表示します"
		}
	}
	CompilingI18nData = @{
		NoneInput = "入力ファイルが指定されていません！"
		BothInputAndContentSpecified = "入力ファイルとコンテンツを同時に使用することはできません！"
		PreprocessDone = "入力スクリプトの前処理が完了しました"
		PreprocessedScriptSize = "前処理済みスクリプト -> {0}バイト"
		MinifyingScript = "スクリプトを圧縮しています..."
		MinifyedScriptSize = "圧縮済みスクリプト -> {0}バイト"
		MinifyerError = "圧縮エラー：{0}"
		MinifyerFailedUsingOriginalScript = "圧縮に失敗しました。元のスクリプトを使用します。"
		TempFileMissing = "一時ファイル {0} が見つかりません！"
		CombinedArg_x86_x64 = "-x86 は -x64 と組み合わせることはできません"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 は -runtime40 と組み合わせることはできません"
		CombinedArg_Runtime20_LongPaths = "長パスは .Net 4 以降でのみ利用可能です"
		CombinedArg_Runtime20_winFormsDPIAware = "DPI 認識は .Net 4 以降でのみ利用可能です"
		CombinedArg_STA_MTA = "-STA は -MTA と組み合わせることはできません"
		InvalidResourceParam = "パラメーター -resourceParams に無効なキーがあります：{0}"
		CombinedArg_ConfigFileYes_No = "-configFile は -noConfigFile と組み合わせることはできません"
		InputSyntaxError = "スクリプトに構文エラーがあります！"
		SyntaxErrorLineStart = "行 {0} 列 {1}："
		IdenticalInputOutput = "入力ファイルと出力ファイルが同じです！"
		CombinedArg_Virtualize_requireAdmin = "-virtualize は -requireAdmin と組み合わせることはできません"
		CombinedArg_Virtualize_supportOS = "-virtualize は -supportOS と組み合わせることはできません"
		CombinedArg_Virtualize_longPaths = "-virtualize は -longPaths と組み合わせることはできません"
		CombinedArg_NoConfigFile_LongPaths = "オプション -longPaths はこの設定ファイルを必要とするため、設定ファイルの生成を強制します"
		CombinedArg_NoConfigFile_winFormsDPIAware = "オプション -winFormsDPIAware はこの設定ファイルを必要とするため、設定ファイルの生成を強制します"
		SomeCmdletsMayNotAvailable = "実行時に利用できない可能性のあるコマンドレット {0} が使用されています。確認してください！"
		SomeNotFindedCmdlets = "未知の命令 {0} が使用されています"
		CompilingFile = "コンパイル中..."
		CompilationFailed = "コンパイルに失敗しました！"
		OutputFileNotWritten = "出力ファイル {0} が書き込まれませんでした"
		CompiledFileSize = "コンパイル済みファイル -> {0}バイト"
		OppsSomethingWentWrong = "エラーが発生しました。"
		TryUpgrade = "最新バージョンは {0} です。アップグレードを試みますか？"
		EnterToSubmitIssue = "ヘルプが必要な場合は、Enterキーを押して問題を報告してください。"
		GuestModeFileTooLarge = "ファイル {0} は大きすぎて読み取れません。"
		GuestModeIconFileTooLarge = "アイコン {0} は大きすぎて読み取れません。"
		GuestModeFtpNotSupported = "ゲストモードでは FTP はサポートされていません。"
		IconFileNotFound = "アイコンファイルが見つかりません：{0}"
		ReadFileFailed = "ファイルの読み取りに失敗しました：{0}"
		PreprocessUnknownIfCondition = "未知の条件：{0}`nfalse と仮定します。"
		PreprocessMissingEndIf = "endif がありません：{0}"
		ConfigFileCreated = "EXE の設定ファイルが作成されました"
		SourceFileCopied = "デバッグ用のソースファイル名がコピーされました：{0}"
		RoslynFailedFallback = "Roslyn CodeAnalysis に失敗しました`nWindows PowerShell with CodeDom を使用してフォールバックします...`n将来このフォールバックを回避するには、-UseWindowsPowerShell を引数に追加してください`n...または、ps12exe リポジトリに PR を送信してこの問題を修正してください！"
		ReadingScript = "ファイル {0} を読み取っています ({1}バイト)"
		ForceX86byVirtualization = "アプリケーション仮想化が有効化されているため、x86 プラットフォームを強制します。"
		TryingTinySharpCompile = "結果が定数であるため、TinySharp コンパイラを試します..."
		TinySharpFailedFallback = "TinySharp コンパイラエラー。通常のプログラムフレームにフォールバックします"
		OutputPath = "パス：{0}"
		ReadingScriptDone = "{0} の読み取りが完了しました。前処理を開始します..."
		PreprocessScriptDone = "{0} の前処理が完了しました"
		ConstEvalStart = "定数の評価中..."
		ConstEvalDone = "定数の評価が完了しました -> {0}バイト"
		ConstEvalTooLongFallback = "定数結果が長すぎるため、通常のプログラムフレームにフォールバックします"
		ConstEvalTimeoutFallback = "定数の評価が {0} 秒後にタイムアウトしました。通常のプログラムフレームにフォールバックします"
		InvalidArchitecture = "無効なプラットフォーム {0} です。AnyCpu を使用します"
		UnknownPragma = "未知の pragma：{0}"
		UnknownPragmaBadParameterType = "未知の pragma：{0}。型 {1} は分析できません。"
		UnknownPragmaBoolValue = "未知の pragma 値：{0}。ブール値として解釈できません。"
		DllExportDelNoneTypeArg = "{0}：{1} は無型パラメーターです。文字列として扱います。"
		DllExportUsing = "#_DllExport を使用しています。このマクロはまだ開発中であり、サポートされていません。"
	}
	WebServerI18nData = @{
		CompilingUserInput = "ユーザー入力をコンパイルしています：{0}"
		EmptyResponse = "要求を処理中にデータが見つかりませんでした。空の応答を返します"
		InputTooLarge413 = "ユーザー入力が大きすぎるため、413 エラーを返します"
		ReqLimitExceeded429 = "IP {0} は、1 分あたりのリクエスト数 {1} の制限を超えたため、429 エラーを返します"
	}
}
