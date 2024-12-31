# ps12exe

> [!CAUTION]
> ソースコードにパスワードを直接埋め込まないでください！  
> 詳細については、[パスワード管理のセキュリティ](#パスワード管理のセキュリティ)を参照してください。  

## 概要

ps12exe は、PowerShell スクリプト（.ps1）から実行可能ファイル（.exe）を作成できる PowerShell モジュールです。  

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery ダウンロード数](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![コーダシー・バッジ](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![コードファクター](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PR歓迎](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./README_CN.md)
[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./README_EN_UK.md)
[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./README_EN_US.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## インストール

```powershell
Install-Module ps12exe # ps12exe モジュールをインストールする
Set-ps12exeContextMenu # 右クリックメニューを設定する
```

(リポジトリをクローンして `.\ps12exe.ps1` を実行することもできます)

**PS2EXE から ps12exe への移行は難しいですか？ ご安心ください！**  
PS2EXE2ps12exe は PS2EXE の呼び出しを ps12exe にフックできます。PS2EXE をアンインストールして PS2EXE2ps12exe をインストールし、その後は通常通り PS2EXE を使用するだけです。

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## 使用方法

### 右クリックメニュー

`Set-ps12exeContextMenu` を一度実行すれば、任意の ps1 ファイルを右クリックして、exe への変換や ps12exeGUI の起動が可能になります。  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### GUI モード

```powershell
ps12exeGUI
```

### コンソールモード

```powershell
ps12exe .\ソース.ps1 .\ターゲット.exe
```

`ソース.ps1` を `ターゲット.exe` にコンパイルします（`.\ソース.ps1` を省略した場合は `.\ソース.exe` に出力されます）。

```powershell
'"Hello World!"' | ps12exe
```

`"Hello World!"` を実行ファイルにコンパイルして `.\a.exe` に出力します。

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

インターネットから `Main.ps1` を実行ファイルにコンパイルして `.\Main.exe` に出力します。

### 自己ホスティング型ウェブサービス

```powershell
Start-ps12exeWebServer
```

ユーザーがオンラインで PowerShell コードをコンパイルできるようにする Web サービスを開始します。

## パラメータ

### GUI パラメータ

```powershell
ps12exeGUI [[-ConfigFile] '<設定ファイル>'] [-PS1File '<スクリプトファイル>'] [-Localize '<言語コード>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<スクリプトファイル>'] [-Localize '<言語コード>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : 読み込む設定ファイル。
PS1File    : コンパイルするスクリプトファイル。
Localize   : 使用する言語コード。
UIMode     : 使用するUIモード。
help       : このヘルプ情報を表示します。
```

### コンソールパラメータ

```powershell
[input |] ps12exe [[-inputFile] '<ファイル名|url>' | -Content '<スクリプト>'] [-outputFile '<ファイル名>']
        [-CompilerOptions '<オプション>'] [-TempDir '<ディレクトリ>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<ファイル名|url>'; title='<タイトル>'; description='<説明>'; company='<会社>';
        product='<製品>'; copyright='<著作権>'; trademark='<商標>'; version='<バージョン>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<ランタイムバージョン>']
        [-SkipVersionCheck] [-GuestMode] [-Localize '<言語コード>'] [-help]
```

```text
input            : PowerShell スクリプトファイルの内容の文字列で、-Content と同じです
inputFile        : 実行可能ファイルに変換したい PowerShell スクリプトファイルのパスまたは URL（ファイルは UTF8 または UTF16 でエンコードされている必要があります）
Content          : 実行可能ファイルに変換したい PowerShell スクリプトの内容
outputFile       : ターゲットの実行可能ファイル名またはディレクトリ。デフォルトは '.exe' 拡張子を持つ inputFile です
CompilerOptions  : 追加のコンパイラオプション（参照： https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）
TempDir          : 一時ファイルを保存するディレクトリ（デフォルトは %temp% にランダムに生成される一時ディレクトリ）
minifyer         : コンパイル前にスクリプトを縮小するスクリプトブロック
lcid             : コンパイルされた実行可能ファイルのロケール ID。指定されていない場合は、現在のユーザーのカルチャです
prepareDebug     : デバッグに役立つ情報を作成します
architecture     : 特定のランタイムのみのコンパイル。可能な値は 'x64'、'x86'、'anycpu' です
threadingModel   : 'STA'（シングルスレッドアパートメント）または 'MTA'（マルチスレッドアパートメント）モード
noConsole        : 生成された実行可能ファイルは、コンソールウィンドウのない Windows Forms アプリケーションになります
UNICODEEncoding  : コンソールモードで出力を UNICODE でエンコードします
credentialGUI    : コンソールモードで GUI プロンプトを使用して資格情報を求めます
resourceParams   : コンパイルされた実行可能ファイルのリソースパラメータを含むハッシュテーブル
configFile       : 設定ファイル（<outputfile>.exe.config）を書き込みます
noOutput         : 生成された実行可能ファイルは、標準出力（詳細情報や情報チャネルを含む）を生成しません
noError          : 生成された実行可能ファイルは、エラー出力（警告情報やデバッグ情報を含む）を生成しません
noVisualStyles   : 生成された Windows GUI アプリケーションのビジュアルスタイルを無効にします（-noConsole と共に使用）
exitOnCancel     : Read-Host 入力ボックスで Cancel または 'X' を選択したときにプログラムを終了します（-noConsole と共に使用）
DPIAware         : 表示スケーリングが有効になっている場合、GUI コントロールは可能な限りスケーリングされます
winFormsDPIAware : 表示スケーリングが有効になっている場合、WinForms は DPI スケーリングを使用します（Windows 10 および .Net 4.7 以上が必要）
requireAdmin     : UAC が有効になっている場合、コンパイルされた実行可能ファイルは昇格されたコンテキストでのみ実行可能です（必要に応じて UAC ダイアログが表示されます）
supportOS        : 最新の Windows バージョンの機能を使用します（[Environment]::OSVersion を実行して違いを確認）
virtualize       : アプリケーションの仮想化が有効になっています（x86 ランタイムを強制）
longPaths        : OS で有効になっている場合、長いパス（260 文字以上）を有効にします（Windows 10 以上にのみ適用）
targetRuntime    : ターゲット ランタイム バージョン、既定値は 'Framework4.0'、'Framework2.0' がサポートされています
SkipVersionCheck : ps12exeの新しいバージョンの確認をスキップします
GuestMode        : ネイティブ ファイルへのアクセスを防ぐために、スクリプトをコンパイルする際に保護を追加します
Localize         : 使用する言語コード
Help             : このヘルプ情報を表示します
```

## 備考

### エラー処理

ほとんどのPowerShell関数とは異なり、ps12exeはエラーを示すために`$LastExitCode`変数を設定しますが、例外がまったく発生しないことを保証するものではありません。  
次のような方法でエラーが発生したかどうかを確認できます。

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exeが終了コード $LastExitCode で失敗しました"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

`$LastExitCode`の値が異なれば、異なるエラータイプを表します。

| エラータイプ | `$LastExitCode`値 |
|---------|------------------|
| 0 | エラーなし |
| 1 | 入力コードエラー |
| 2 | 呼び出しフォーマットエラー |
| 3 | ps12exe内部エラー |

### 前処理

ps12exe はコンパイル前にスクリプトを前処理します。  

```powershell
# ps12exe.csファイルからプログラムフレームを読み込む
#_if PSEXE # これは ps12exe によってスクリプトがコンパイルされるときに使用される前処理コードです。
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #ps12exe.csの内容をこのスクリプトに挿入する。
#_else #そうでなければ、csファイルを普通に読み込む
	[string]$programFrame = Get-Content $PSScriptRoot/ps12exe.cs -Raw -Encoding UTF8
#_endif
```

#### `#_if <condition>`/`#_else`/`#_endif`

```powershell
$LocalizeData =
	#_if PSScript
		. $PSScriptRoot\src\LocaleLoader.ps1
	#_else
		#_include "$PSScriptRoot/src/locale/en-UK.psd1"
	#_endif
```

`PSEXE` と `PSScript` は以下の条件でのみサポートされるようになりました。  
`PSEXE` は真、`PSScript` は偽。  

#### `#_include <ファイル名|url>`/`#_include_as_value <値> <ファイル名|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

ファイル `<filename|url>` または `<file|url>` の内容をスクリプトに含めます。ファイルの内容は `#_include`/`#_include_as_value` コマンドで指定した場所に挿入されます。

前処理コマンドの `#_include` 系列は、`#_if` ステートメントとは異なり、ファイル名を引用符で囲まない場合、末尾のスペース `#` もファイル名の一部として扱います。  

```powershell
#_include $PSScriptRoot/super #変なファイル名.ps1
#_include "$PSScriptRoot/filename.ps1" #安全なコメント！
```

`#_include` を使うと、ファイルの内容が前処理されるので、複数のレベルのファイルをインクルードすることができます。`#_include_as_value` を使用すると、ファイルの内容が文字列の値としてスクリプトに挿入されます。ファイルの内容は前処理されません。

ほとんどの場合、`#_if` と `#_include` の前処理コマンドを使わなくても、exe に変換した後のスクリプトにサブスクリプトを正しくインクルードすることができます。

```powershell
. PSScriptRoot/another.ps1
& $PSScriptRoot/another.ps1
$result = & "$PSScriptRoot/another.ps1" -args
```

#### `#_include_as_(base64|bytes) <valuename> <file|url>`

```powershell
#_include_as_base64 <valuename> <file|url>
#_include_as_bytes <valuename> <file|url>
```

ファイルを Base64 文字列またはバイト配列としてプリプロセス時にスクリプトに挿入します。ファイルの内容自体はプリプロセスされません。

簡単なパッカーの例を示します。

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

この EXE は、実行時にコンパイル時にスクリプトに埋め込まれた data.bin ファイルを抽出します。

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript #$EshellUIをPSEXEに入れることはできない
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

`#_!!` 行そのものは削除されます。

#### `#_require <モジュールリスト>`

```powershell
#_require ps12exe
#_pragma Console 0
$Number = [bigint]::Parse('0')
$NextNumber = $Number+1
$NextScript = $PSEXEscript.Replace("Parse('$Number')", "Parse('$NextNumber')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
番号
```

`#_require` スクリプト全体で必要なモジュールを数え、最初の `#_require` の前に以下のコードと同等のスクリプトを追加します。

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

このコードが生成するのはモジュールのインストールだけで、インポートではないことに注意してください。  
適宜 `Import-Module` を使用してください。

複数のモジュールを require する必要がある場合は、複数行の require 文を書く代わりに、区切り文字としてスペース、カンマ、セミコロンと全角カンマを使うことができます。

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

pragma プリプロセッシングディレクティブはスクリプトの内容には影響しませんが、コンパイルに使用するパラメータを変更します。  
以下に例を示します。

```powershell
PS C:\Users\steve02081504> '12' | ps12exe
Compiled file written -> 1024 bytes
PS C:\Users\steve02081504> ./a.exe
12
PS C:\Users\steve02081504> '#_pragma Console no
>> 12' | ps12exe
Preprocessed script -> 23 bytes
Compiled file written -> 2560 bytes
```

ご覧のように、コンパイル時に `#_pragma Console no` を指定しなかったとしても、生成された exe ファイルはウィンドウモードで実行されます。  
pragma コマンドは任意のコンパイルパラメータを設定できます。

```powershell
#_pragma noConsole # ウィンドウモード
#_pragma Console # コンソールモード
#_pragma Console no # ウィンドウモード
#_pragma Console true # コンソールモード
#_pragma icon $PSScriptRoot/icon.ico # アイコンの設定
#_pragma title "title" # exe のタイトルを設定する
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

コードがこのポイントに到達すると、プロセスは指定された終了コードで終了し、EXE ファイルを削除します。  

### ミニファイア

ps12exe の「コンパイル」はスクリプト内のすべてをそのままリソースとして実行ファイルに埋め込むので、スクリプトに無駄な文字列が多いと、実行ファイルは非常に大きくなります。  
`-Minifyer` パラメータを使うと、コンパイルの前にスクリプトを前処理するスクリプトブロックを指定することができ、生成される実行ファイルを小さくすることができます。  

このようなスクリプトブロックの書き方がわからない場合は、[psminnifyer](https://github.com/steve02081504/psminnifyer) を使ってください。

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | & ./psminnifyer.ps1 }
```

### 未対応コマンドレット一覧

ps12exe の基本的な入出力コマンドは C# で書き換える必要があります。未対応のものは、コンソールモードでの *`Write-Progress`* (作業が多すぎる) と *`Start-Transcript`*/*`Stop-Transcript`* (Microsoft には適切なリファレンス実装がない) です。

### GUI モードの出力形式

デフォルトでは、PowerShell の小さなコマンドの出力形式は 1 行 1 行です（文字列の配列として）。コマンドが 10 行の出力を生成し、GUI を使用して出力される場合、10 個のメッセージボックスが表示され、それぞれが確認されるのを待ちます。これを避けるには、`Out-String` コマンドをコマンドラインに追加します。これにより、出力が 10 行の文字列に変換され、そのすべてが 1 つのメッセージボックスに表示されます（例：`dir C:\ | Out-String`）。

### 設定ファイル

ps12exe は `生成された実行ファイル + ".config"` という名前の設定ファイルを作成できます。ほとんどの場合、これらの設定ファイルは必須ではなく、どの .NET Framework のバージョンを使用するかのリストです。通常は実際の .NET Framework を使用するので、設定ファイルなしで実行ファイルを実行してみてください。

### パラメータ処理

コンパイルされたスクリプトは、元のスクリプトと同様にパラメータを処理します。すべての実行可能ファイルでは、すべてのパラメータは String 型であり、パラメータ型が暗黙的に変換されない場合は、スクリプト内で明示的に変換する必要があります。実行可能ファイルにコンテンツをパイプすることもできますが、同じ制限（パイプされた値はすべて String 型）があります。

### パスワード管理のセキュリティ

<a id="password-security-stuff"></a>
コンパイル済みスクリプトには、絶対にパスワードを保存しないでください！  
スクリプト全体は、.NET デコンパイラで簡単に見ることができます。  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### スクリプトによって環境を区別する  

スクリプトがコンパイルされた exe で実行されているのか、スクリプトで実行されているのかは、`$Host.Name` で判別できます。

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "他のホスト" }
```

### スクリプト変数

ps12exe はスクリプトを実行ファイルに変換するので、変数 `$MyInvocation` の値はスクリプトの値とは異なります。

実行ファイルがあるディレクトリのパスを取得するには `$PSScriptRoot` を使用し、実行ファイル自体のパスを取得するには新しい `$PSEXEpath` を使用します。

### -noConsole モードでのバックグラウンドウィンドウ

`-noConsole` モードを使用するスクリプト（`Get-Credential` や `cmd.exe` を必要とするコマンドなど）で外部ウィンドウを開くと、ウィンドウがバックグラウンドで開きます。

これは外部ウィンドウを閉じるときに、Windows が親ウィンドウをアクティブにしようとするためです。コンパイルされたスクリプトはウィンドウを持たないため、コンパイルされたスクリプトの親ウィンドウがアクティブになり、通常はエクスプローラや PowerShell のウィンドウがアクティブになります。

これを回避するには、`$Host.UI.RawUI.FlushInputBuffer()` を使って、アクティブにできる不可視のウィンドウを開きます。次に `$Host.UI.RawUI.FlushInputBuffer()` を呼び出すと、このウィンドウは閉じます（以下同様）。

次の例では、`ipconfig | Out-String` を一度だけ呼び出すのとは異なり、バックグラウンドでウィンドウを開かなくなります。

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

## 利点

### クイック比較 🏁

| 比較項目 | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| 純スクリプトリポジトリ 📦 | ✔️画像と依存関係以外はすべてテキストファイル | ❌オープンソースライセンスが適用された exe ファイルを含む |
| "Hello World!" を生成するためのコマンド 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1` |
| 生成された "Hello World" の実行可能ファイルのサイズ 💾 | 🥰1024 バイト | 😨25088 バイト |
| GUI の多言語サポート 🌐 | ✔️ | ❌ |
| コンパイル時の構文チェック ✔️ | ✔️ | ❌ |
| プリプロセッサ機能 🔄 | ✔️ | ❌ |
| `-extract` などの特殊パラメータ解析 🧹 | 🗑️削除済み | 🥲ソースコードの変更が必要 |
| PR の歓迎度 🤝 | 🥰歓迎！ | 🤷14 件のプルリクエストのうち 13 件がクローズされました |

### 詳細な比較 🔍

[`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) に比べて、このプロジェクトは以下の改善をもたらしています。

| 改善内容 | 説明 |
| --- | --- |
| ✔️ コンパイル時の構文チェック | コード品質を向上させるためにコンパイル時に構文チェックを実行 |
| 🔄 強力なプリプロセッサ機能 | スクリプトをコンパイル前にプリプロセス処理し、スクリプト全体をコピー＆ペーストすることなく |
| 🛠️ `-CompilerOptions` パラメータ | 生成された実行可能ファイルをさらにカスタマイズするためのパラメータを追加 |
| 📦️ `-Minifyer` パラメータ | コンパイル前にスクリプトをプリプロセス処理し、より小さな実行可能ファイルを生成 |
| 🌐 URL からスクリプトと含まれるファイルをコンパイルするサポート | アイコンのダウンロードに URL をサポート |
| 🖥️ `-noConsole` パラメータの最適化 | オプション処理とウィンドウタイトル表示を最適化。カスタムのポップアップウィンドウタイトルを設定できます |
| 🧹 exe ファイルの削除 | コードリポジトリから exe ファイルを削除 |
| 🌍 多言語サポート、純スクリプト GUI | より良い多言語サポート、純スクリプト GUI、ダークモード対応 |
| 📖 cs ファイルを ps1 ファイルから分離 | 読みやすく、保守しやすく |
| 🚀その他多数の改善 | and more... |
