@{
	# 右クリックメニュー
	CompileTitle		   = "EXEにコンパイル"
	OpenInGUI			   = "ps12exeGUIで開く"
	GUICfgFileDesc		   = "ps12exe GUI設定ファイル"
	# Webサーバー
	ServerStarted		   = "HTTPサーバーが起動しました！"
	ServerStopped		   = "HTTPサーバーが停止しました！"
	ServerStartFailed	   = "HTTPサーバーの起動に失敗しました！"
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
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-ReqLimitPerMin '<uint>']
	[-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-Localize '<言語コード>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "登録するHTTPサーバーのアドレス。"
			MaxCompileThreads = "最大コンパイルスレッド数。"
			ReqLimitPerMin	  = "IPアドレスごとの1分間のリクエスト制限。"
			MaxCachedFileSize = "最大キャッシュファイルサイズ。"
			MaxScriptFileSize = "最大スクリプトファイルサイズ。"
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
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]"
		PrarmsData = [ordered]@{
			input			 = "PowerShellスクリプトファイルの内容の文字列で、``-Content``と同じです。"
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
		}
	}
}
