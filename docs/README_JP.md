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

## 利用しているプロジェクト

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## インストール

```powershell
Install-Module ps12exe # ps12exe モジュールをインストールする
Set-ps12exeContextMenu # 右クリックメニューを設定する
```

(リポジトリをクローンして `.\ps12exe.ps1` を実行することもできます)

**PS2EXE から ps12exe への移行は難しいですか？ ご安心ください！**  
PS2EXE2ps12exe は PS2EXE の呼び出しを ps12exe にフックできます。PS2EXE をアンインストールして PS2EXE2ps12exe をインストールし、その後は通常通り PS2EXE を使用するだけです。  
あらゆるバージョンの PS2EXE パラメータ（`conHost`、`embedFiles`、旧 `runtime20`/`runtime40` を含む）との最大限の互換性を目指し、ps12exe にない機能はコンパイル時に書き換えて実現します。

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

`ソース.ps1` を `ターゲット.exe` にコンパイルします（`.\ターゲット.exe` を省略した場合は `.\ソース.exe` に出力されます）。

```powershell
'"Hello World!"' | ps12exe
```

`"Hello World!"` を実行ファイルにコンパイルして `.\a.exe` に出力します。

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

インターネットから `Main.ps1` を実行ファイルにコンパイルして `.\Main.exe` に出力します。

### exe から ps1 を復元（exe21sp）

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` は ps12exe が生成した exe（ローカルパスまたは URL）に埋め込まれた PowerShell スクリプトを取り出し、`.ps1` ファイルとして保存するか、標準出力に書き出します。ps12exe と同様に `$LastExitCode` で結果を表します：0 = 成功、1 = 入力/解析エラー（例：ps12exe 生成 exe でない）、2 = 呼び出しエラー（例：リダイレクト時に入力なし）、3 = リソース/内部エラー（例：ファイルなし）。

### パイプラインとリダイレクト

- **ps12exe**：標準出力（または標準入力/標準エラー）がリダイレクトされているとき、ps12exe は生成した exe のパスのみを標準出力に書き、キャプチャできるようにします（例：`$exe = ps12exe .\a.ps1`）。
- **exe21sp**：パイプライン入力で exe のパスまたは URL を受け取れます（例：`Get-ChildItem *.exe | exe21sp` や `".\app.exe" | exe21sp`）。
- **exe21sp**：`-outputFile` を指定せず、標準出力がリダイレクト**されていない**ときは、反コンパイル結果を exe と同じディレクトリ・同じベース名の `.ps1` に保存します。
- **exe21sp**：`-outputFile` を指定せず、標準出力がリダイレクト**されている**ときは、反コンパイル結果を標準出力に書き出します。

### 自己ホスト型 Web サーバー

```powershell
Start-ps12exeWebServer
```

ブラウザなどから PowerShell スクリプトをオンラインでコンパイルできる Web サーバーを起動します。

### VS Code 拡張機能

[ps12exe VS Code 拡張機能](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe)を使うと、エディターを離れずに `.ps1` スクリプトを実行ファイルへコンパイルしたり ps12exeGUI を開いたりでき、前処理ディレクティブ向けの編集支援（シンタックスハイライト、診断、`#_if` の自動クローズ、折りたたみ、定義へ移動、ホバー、補完、フォーマット）も追加されます。

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeContextMenu` が自動でインストールします。`steve02081504.ps12exe` を手動でインストールすることもできます。

## パラメータ

### GUI パラメータ

```powershell
ps12exeGUI [[-ConfigFile] '<設定ファイル>'] [-PS1File '<スクリプトファイル>'] [-Locale '<言語コード>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<スクリプトファイル>'] [-Locale '<言語コード>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : 読み込む設定ファイル。
PS1File    : コンパイルするスクリプトファイル。
Locale     : 使用する言語コード。
UIMode     : 使用するUIモード。
help       : このヘルプ情報を表示します。
```

### コンソールパラメータ

```powershell
[input |] ps12exe [[-inputFile] '<ファイル名|url>' | -Content '<スクリプト>'] [-outputFile '<ファイル名>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true;
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'; Apartment='STA'|'MTA';
        Culture='<カルチャ>'; Options='<オプション>'; KeepSource=$true; Minify={<scriptblock>}; TempDir='<ディレクトリ>'}]
        [-Resources @{Icon='<ファイル名|url>'; Title='<タイトル>'; Description='<説明>'; Company='<会社>';
        Product='<製品>'; Copyright='<著作権>'; Trademark='<商標>'; Version='<バージョン>'}]
        [-Signing @{Certificate='<PFXファイルパス>'; Password='<PFXパスワード>'; Thumbprint='<証明書指紋>'; Timestamp='<時刻同期サーバー>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Locale '<言語コード>'] [-ConfigFile] [-help]
```

```text
input            : PowerShell スクリプトファイルの内容の文字列で、-Content と同じです
inputFile        : 実行可能ファイルに変換したい PowerShell スクリプトファイルのパスまたは URL（ファイルは UTF8 または UTF16 でエンコードされている必要があります）
Content          : 実行可能ファイルに変換したい PowerShell スクリプトの内容
outputFile       : ターゲットの実行可能ファイル名またはディレクトリ。デフォルトは '.exe' 拡張子を持つ inputFile です
App              : 生成されるアプリケーションの動作を記述するハッシュテーブル。サポートされるキー：
                   Windowed         : 生成された実行可能ファイルは、コンソールウィンドウのない Windows Forms アプリケーションになります。
                   Silence          : 抑制する出力ストリームの名前。'Output'、'Verbose'、'Error'、'Warning'、'Debug' のいずれか 1 つ以上、またはすべてを表す '*'。
                   OutputEncoding   : コンソール出力のエンコーディング。'Default'、'UTF8'、'UTF16LE'。
                   VisualStyles     : GUI アプリケーションのビジュアルスタイルを有効にします（既定値 $true）。
                   ExitOnCancel     : Read-Host 入力ボックスで Cancel または 'X' を選択したときにプログラムを終了します。
                   CredentialGUI    : コンソールモードで GUI プロンプトを使用して資格情報を求めます。
                   DpiAware         : コンパイルされた実行可能ファイルを DPI 対応としてマークします。
                   WinFormsDpiAware : WinForms で DPI スケーリングを使用します（Windows 10 および .Net 4.7 以上が必要）。
Os               : OS 統合オプションのハッシュテーブル。サポートされるキー：
                   Admin            : UAC が有効になっている場合、コンパイルされた実行可能ファイルは昇格されたコンテキストでのみ実行可能です（必要に応じて UAC ダイアログが表示されます）。
                   ModernOS         : 最新の Windows バージョンの機能を使用します（[Environment]::OSVersion を実行して違いを確認）。
                   LongPaths        : OS で有効になっている場合、長いパス（260 文字以上）を有効にします（Windows 10 以上にのみ適用）。
                   Virtualize       : アプリケーションの仮想化が有効になっています（x86 ランタイムを強制）。
Build            : ビルド/ツールチェーンオプションのハッシュテーブル。サポートされるキー：
                   Target           : ターゲット ランタイム バージョン、既定値は 'Framework4.0'、'Framework2.0' と 'Core' がサポートされています。'Core' は PowerShell Core (.NET) 実行可能ファイルを生成します（コンパイル機とターゲット機の両方に PowerShell Core と .NET が必要で、成果物は大幅に大きくなります）。
                   Platform         : 特定のランタイムのみのコンパイル。可能な値は 'AnyCpu'、'x64'、'x86' です。
                   Apartment        : 'STA'（シングルスレッドアパートメント）または 'MTA'（マルチスレッドアパートメント）モード。
                   Culture          : コンパイルされた実行可能ファイルのカルチャ。指定されていない場合は、現在のユーザーのカルチャです。
                   Options          : 追加のコンパイラオプション（参照： https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）。
                   KeepSource       : デバッグに役立つ情報を作成します。
                   Minify           : コンパイル前にスクリプトを縮小するスクリプトブロック。
                   TempDir          : 一時ファイルを保存するディレクトリ（デフォルトは %temp% にランダムに生成される一時ディレクトリ）。
Resources        : 実行可能ファイルに埋め込むバージョンリソースのハッシュテーブル（Icon、Title、Description、Company、Product、Copyright、Trademark、Version）。Icon はアイコンファイルのパスまたは URL にできます。
Signing          : コード署名オプションのハッシュテーブル（Certificate、Password、Thumbprint、Timestamp）。Certificate または Thumbprint のいずれかを指定する必要があります。
PreprocessOnly   : 入力スクリプトをプリプロセス処理し、コンパイルせずに返します。
Golf             : コードを短縮化し、一般的な関数を追加します。
Sandbox          : ネイティブ ファイルへのアクセスを防ぐために、スクリプトをコンパイルする際に保護を追加します。
NoUpdateCheck    : ps12exeの新しいバージョンの確認をスキップします。
Locale           : 使用する言語コード。
ConfigFile       : 設定ファイル（<outputfile>.exe.config）を書き込みます。
Help             : このヘルプ情報を表示します。
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

| エラータイプ | `$LastExitCode`値          |
| ------------ | -------------------------- |
| 0            | エラーなし                 |
| 1            | 入力コードエラー           |
| 2            | 呼び出しフォーマットエラー |
| 3            | ps12exe内部エラー          |

### 前処理

<a id="preprocessing-overview"></a>

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

<a id="preprocessing-if"></a>

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

<a id="preprocessing-include"></a>

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

<a id="preprocessing-include-as"></a>

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

<a id="preprocessing-bang"></a>

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

行頭の `#_!!` は取り除かれます。

#### `#_require <モジュールリスト>`

<a id="preprocessing-require"></a>

```powershell
#_require ps12exe
#_pragma App.Windowed
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

<a id="preprocessing-pragma"></a>

pragma プリプロセッシングディレクティブはスクリプトの内容には影響しませんが、コンパイルに使用するパラメータを変更します。  
以下に例を示します。

```powershell
PS C:\Users\steve02081504> '12' | ps12exe
Compiled file written -> 1024 bytes
PS C:\Users\steve02081504> ./a.exe
12
PS C:\Users\steve02081504> '#_pragma App.Windowed
>> 12' | ps12exe
Preprocessed script -> 23 bytes
Compiled file written -> 2560 bytes
```

ご覧のように、コンパイル時に `-App @{Windowed=$true}` を指定しなかったとしても、生成された exe ファイルはウィンドウモードで実行されます。  
pragma コマンドは任意のコンパイルパラメータを設定できます。名前に `.` を使うとネストした値を設定できます。

```powershell
#_pragma App.Windowed # ウィンドウモード
#_pragma App.Windowed $false # コンソールモード
#_pragma Resources.Icon $PSScriptRoot/icon.ico # アイコンの設定
#_pragma Resources.Title "title" # exe のタイトルを設定する
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" # コード署名証明書を設定する
```

文字列型の pragma 値には `$(...)` 部分式を記述でき、プリプロセス時に評価されます（例：`#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`）。許可されるのはホワイトリストに含まれる path 関連コマンド（`Get-Command`、`Join-Path`、`Split-Path`、`Resolve-Path`、`Convert-Path`、`Get-Item`、`Test-Path`、`Get-ChildItem`、および Sandbox 以外での `Get-Content`）、変数（`$env:*`、`$PSScriptRoot`、`$ScriptRoot`、`$HOME`、`$PWD`、`$PSCommandPath`）、および一般的な無害なインスタンスメソッド（例：`ToUpper`、`Trim`、`Split`、`ToString`）のみです。それ以外はコンパイルを中断します。単引用符で囲んだ値は完全にリテラルとして扱われます。

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <exitcode>
#_balus
```

コードがこのポイントに到達すると、プロセスは指定された終了コードで終了し、EXE ファイルを削除します。

### ミニファイ

ps12exe の「コンパイル」はスクリプト内のすべてをそのままリソースとして実行ファイルに埋め込むので、スクリプトに無駄な文字列が多いと、実行ファイルは非常に大きくなります。  
`-Build` の `Minify` キーを使うと、コンパイルの前にスクリプトを前処理するスクリプトブロックを指定することができ、生成される実行ファイルを小さくすることができます。

このようなスクリプトブロックの書き方がわからない場合は、[psminnifyer](https://github.com/steve02081504/psminnifyer) を使ってください。

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | & ./psminnifyer.ps1 }}
```

### 未対応コマンドレット一覧

ps12exe の基本的な入出力コマンドは C# で書き換える必要があります。未対応のものは、コンソールモードでの _`Write-Progress`_ (作業が多すぎる) と _`Start-Transcript`_/_`Stop-Transcript`_ (Microsoft には適切なリファレンス実装がない) です。

### GUI モードの出力形式

デフォルトでは、PowerShell の小さなコマンドの出力形式は 1 行 1 行です（文字列の配列として）。コマンドが 10 行の出力を生成し、GUI を使用して出力される場合、10 個のメッセージボックスが表示され、それぞれが確認されるのを待ちます。これを避けるには、`Out-String` コマンドをコマンドラインに追加します。これにより、出力が 10 行の文字列に変換され、そのすべてが 1 つのメッセージボックスに表示されます（例：`dir C:\ | Out-String`）。

### 設定ファイル

ps12exe は `生成された実行ファイル + ".config"` という名前の設定ファイルを作成できます。ほとんどの場合、これらの設定ファイルは必須ではなく、どの .NET Framework のバージョンを使用するかのリストです。通常は実際の .NET Framework を使用するので、設定ファイルなしで実行ファイルを実行してみてください。

### パラメータ処理

コンパイルされたスクリプトは、元のスクリプトと同様にパラメータを処理します。1 つの制限は Windows 環境に由来します。どの実行可能ファイルでも、コマンドライン引数は最終的に文字列になります。

スクリプトの先頭に `param()` ブロックがある場合、ps12exe は引数の値を PowerShell データ (PSD) として解析します。ハッシュテーブル `@{}`、順序付きハッシュテーブル `[ordered]@{}`、配列 `@()`、および `[int]'5'` や `[hashtable]@{}` のような安全な型へのキャストは、対応するオブジェクトとしてパラメータに渡されるため、手動での変換は不要です。

```powershell
# script: param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

値は引用符で囲む必要があります。引用符のない `@{...}` はシェルによって文字列化され（プログラムは `System.Collections.Hashtable` というテキストしか受け取りません）、データでない値（式やコマンド）は通常の文字列として渡され、決して評価されません。したがって `-Config "@{x=(Get-Date)}"` はコードを実行せず、単にバインドに失敗します。

パイプで渡される値はこれまでどおり文字列です。

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

実行ファイルがあるディレクトリのパスを取得するには `$PSScriptRoot` を使用し、実行ファイル自体のパスを取得するには `$PSCommandPath` を使用します。

### `App.Windowed` モードでのバックグラウンドウィンドウ

`App.Windowed` モードを使用するスクリプト（`Get-Credential` や `cmd.exe` を必要とするコマンドなど）で外部ウィンドウを開くと、ウィンドウがバックグラウンドで開きます。

これは外部ウィンドウを閉じるときに、Windows が親ウィンドウをアクティブにしようとするためです。コンパイルされたスクリプトはウィンドウを持たないため、コンパイルされたスクリプトの親ウィンドウがアクティブになり、通常はエクスプローラや PowerShell のウィンドウがアクティブになります。

これを回避するには、`$Host.UI.RawUI.FlushInputBuffer()` を使って、アクティブにできる不可視のウィンドウを開きます。次に `$Host.UI.RawUI.FlushInputBuffer()` を呼び出すと、このウィンドウは閉じます（以下同様）。

次の例では、`ipconfig | Out-String` を一度だけ呼び出すのとは異なり、バックグラウンドでウィンドウを開かなくなります。

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### 標準入力と `$input`

コンパイルされた exe がリダイレクトされた標準入力を（行単位でパイプライン入力として）読み込むのは、スクリプトが**トップレベル**で `$input` を使用している場合のみです：

- `$input` を使用する場合：PS2EXE と同じ動作で、stdin はパイプライン入力として消費され、元の stdin（`[Console]::In` / `Console.OpenStandardInput()`）はその後 EOF に達します。
- `$input` を使用しない場合：stdin を一切読み込みません。元の標準入力はそのまま保持され、起動時に stdin を待機することもありません（親プロセスがパイプを開いたままでもブロックされません）。また、子プロセスは stdin を継承できます。

判定はスクリプトのトップレベルのみを対象とします。関数、スクリプトブロック、クラス内の `$input` はそれぞれのスコープのパイプライン入力であり、ホストとは無関係で対象外です。

たとえば、スクリプトが `[Console]::In.ReadToEnd()` を呼び出し、`$input` を使用していない場合、コンパイル後に `echo hi | .\tool.exe` で `hi` を取得できます。

### 定数評価

定数のみで副作用のないスクリプトについて、ps12exe はコンパイル時に評価し、その結果を非常に小さな exe（TinySharp パス、通常 1KB 前後）に直接組み込みます。評価がタイムアウトした場合（デフォルト 7 秒）または結果が長すぎる場合は通常のコンパイルにフォールバックします。評価環境が実行時と異なる場合、あるいは完全な PowerShell ホストが必要な場合は、スクリプトに以下のいずれかの pragma を追加してこの最適化を明示的に無効にできます：

- `#_pragma Build.ConstEval.Enabled 0`：このスクリプトは定数ではないと宣言し、定数評価をスキップします。
- `#_pragma Build.ConstEval.Timeout 1`：今回の定数評価はタイムアウト済みと宣言し、タイムアウト時と同じフォールバックを行います。

どちらも前処理時に通常のネストされた pragma として解析されるため、どの行に置いてもかまいません。通常のホストにフォールバックした後は、これらの行は単なるコメントになります。

## 利点

### クイック比較 🏁

| 比較項目                                             | ps12exe                                                                     | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)     |
| ---------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 純スクリプトリポジトリ 📦                            | ✔️画像と同梱の補助 DLL 以外はすべてテキストファイル                         | ❌オープンソースライセンスの `Win-PS2EXE.exe` を同梱                               |
| "Hello World!" を生成するためのコマンド 🌍           | 😎`'"Hello World!"' \| ps12exe`                                             | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                           |
| 生成される定数版 "Hello World" のサイズ 💾           | 🥰1024 バイト（コンパイル時に定数評価）                                     | ❌ 非対応；25088 バイト                                                            |
| 生成される非定数版 "Hello World" のサイズ 💾         | 🥰14848 バイト                                                              | 😨25088 バイト                                                                     |
| コンパイル時の定数評価 ⚡                            | ✔️                                                                          | ❌                                                                                 |
| PowerShell Core（7+）/ クロスプラットフォーム対応 🧬 | ✔️ `Build.Target Core`（Windows / Linux / macOS）                           | ❌ Windows PowerShell 5.1 のみ                                                     |
| GUI の多言語サポート 🌐                              | ✔️（7 言語、ダークモード）                                                  | ❌                                                                                 |
| コンパイル時の構文チェック ✔️                        | ✔️                                                                          | ❌                                                                                 |
| プリプロセッサ機能 🔄                                | ✔️                                                                          | ❌                                                                                 |
| `-extract` などの特殊パラメータ解析 🧹               | 🗑️削除済み（代わりに `exe21sp` ツールを使用）                               | 🥲ソースコードの変更が必要                                                         |
| PR の歓迎度 🤝                                       | 🥰歓迎！                                                                    | 🤷14 件のプルリクエストのうち 13 件がクローズされました                            |
| 政治 / DEI / 立場バイアス 🕊️                         | ✔️ なし。価値ある PR は歓迎——人間、AI、タイプライターを叩くサル、誰からでも | ❌ README が反 AI の立場を掲げる（「人工知能は創造性と私たちの本性を殺している」） |

ps12exe の開発者は、このプロジェクトで政治的・DEI・その他のイデオロギー的立場を宣伝しません——価値ある PR は、人間からでも AI からでも、タイプライターを叩くサルからでも歓迎します。

### サイズと速度のベンチマーク 🔬

Windows 11 + PowerShell 7.6.6（.NET 10）+ Windows PowerShell 5.1 で計測。各項目をウォームアップ後に 20 回実行。プロセス生成の下限（`cmd /c exit`）は約 15 ms。`pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` で再現できます。

| ビルド                                        | 出力サイズ   | ウォーム起動 |
| --------------------------------------------- | ------------ | ------------ |
| Windows PowerShell 5.1 でスクリプトを直接実行 | —            | ~245 ms      |
| ps12exe · 定数 · Framework4.0                 | 1024 バイト  | ~33 ms       |
| ps12exe · 非定数 · Framework4.0               | 14848 バイト | ~210 ms      |
| PS2EXE 1.0.18 · 非定数                        | 25088 バイト | ~223 ms      |
| --------------------------------------------- | ------------ | ------------ |
| pwsh 7 でスクリプトを直接実行                 | —            | ~450 ms      |
| ps12exe · 定数 · Core                         | ~169 KB      | ~70 ms       |
| ps12exe · 非定数 · Core                       | ~185 KB      | ~395 ms      |
| PS2EXE 1.0.18 · 非定数 · Core                 | 非対応       | 非対応       |

定数スクリプトはコンパイル時に評価されるため、exe は 1 KB で PowerShell を起動しません。PS2EXE の hello world より約 24 倍小さく、起動は約 6 倍高速です。非定数 exe も PS2EXE より約 40% 小さく、トップレベル変数を多用するスクリプトでは、スクリプトがグローバルスコープではなく関数内（ローカルスコープ）で実行されるため、実行も速くなります。

コンパイラ自体は PowerShell モジュールとして配布されます：

| コンパイラパッケージ     | 展開後   | 圧縮後  |
| ------------------------ | -------- | ------- |
| ps12exe（現在の master） | ~1.29 MB | ~513 KB |
| PS2EXE 1.0.18            | ~171 KB  | ~46 KB  |

ps12exe のモジュールが大きいのは、依存関係のない純スクリプトコンパイラであり、トリミング済みの [AsmResolver](https://github.com/Washi1337/AsmResolver) バイナリ（1 KB の定数 exe の生成とペイロードの展開に使用）、7 言語のローカライズ、純スクリプト GUI を同梱しているためです。PS2EXE はほとんど同梱せず、Windows 内蔵の .NET Framework コンパイラに依存しています。

### コンパイル済み EXE の実行時動作 🖥️

EXE が起動したネイティブ子プロセスが実際のコンソール TTY を認識できるか（[#59](https://github.com/steve02081504/ps12exe/issues/59)）、スクリプトが生の stdin を読めるか（[#62](https://github.com/steve02081504/ps12exe/issues/62)）、特殊パス変数が解決されるかを、Windows 11 の実際のコンソールウィンドウで検証しました：

| 機能                                                         | ps12exe                                    | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------------------------------ | ------------------------------------------ | ------------------------------------------------------------------------------ |
| ネイティブ子プロセスがコンソール TTY（`isTTY`）を認識        | ✔️                                         | ❌                                                                             |
| 生の stdin（`[Console]::In`）を読み取れる                    | ✔️（スクリプトが `$input` を使わない場合） | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` が解決される              | ✔️（exe パス / exe のディレクトリ）        | ❌                                                                             |
| コマンドライン引数を PSD データとして解析（表/オブジェクト） | ✔️（`-Config "@{...}"`）                   | ❌（文字列のみ）                                                               |

PS2EXE 1.0.18 は常にスクリプト出力を `Out-String` 経由で収集し、スクリプト実行前にリダイレクトされた stdin を最後まで読み切るため、ネイティブ子プロセスはコンソールハンドルを失い、stdin は EOF になります。ps12exe はホスト経由で出力し（`Out-Default`）、スクリプトが実際に `$input` を使うときだけ stdin を読みます。また PS2EXE はコンパイル済みプログラム内で `$PSCommandPath`/`$PSScriptRoot` を空のままにし（独自の `$ScriptRoot` を提供）、ps12exe は両方を生成された exe にマップします。

### 詳細な比較 🔍

[`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) に比べて、このプロジェクトは以下の改善をもたらしています。

| 改善内容                                                                 | 説明                                                                                                   |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| ✔️ コンパイル時の構文チェック                                            | コード品質を向上させるためにコンパイル時に構文チェックを実行                                           |
| ⚡ コンパイル時の定数評価                                                | 副作用のないスクリプトをビルド時に評価し、約 1 KB の exe を生成                                        |
| 🧬 PowerShell Core / クロスプラットフォーム対応                          | `Build.Target Core` で Windows、Linux、macOS 上の PowerShell 7+ を対象とする                           |
| 🔄 強力なプリプロセッサ機能                                              | スクリプトをコンパイル前にプリプロセス処理し、スクリプト全体をコピー＆ペーストすることなく             |
| 🛠️ `Build.Options` パラメータ                                            | 生成された実行可能ファイルをさらにカスタマイズするためのパラメータを追加                               |
| 📦️ `Build.Minify` パラメータ                                             | コンパイル前にスクリプトをプリプロセス処理し、より小さな実行可能ファイルを生成                         |
| 🌐 URL からスクリプトと含まれるファイルをコンパイルするサポート          | アイコンのダウンロードに URL をサポート                                                                |
| 🖥️ `App.Windowed` パラメータの最適化                                     | オプション処理とウィンドウタイトル表示を最適化。カスタムのポップアップウィンドウタイトルを設定できます |
| ✍️ コード署名とアイコンの自動変換                                        | PFX 証明書またはストアの拇印で署名し、アイコンを自動変換                                               |
| 🧰 追加ツール：`exe21sp`、Web サーバー、コンテキストメニュー、対話モード | exe の逆コンパイル、オンラインコンパイル、右クリックコンパイルなど                                     |
| 🧹 exe ファイルの削除                                                    | コードリポジトリから exe ファイルを削除                                                                |
| 🌍 多言語サポート、純スクリプト GUI                                      | より良い多言語サポート、純スクリプト GUI、ダークモード対応                                             |
| 📖 cs ファイルを ps1 ファイルから分離                                    | 読みやすく、保守しやすく                                                                               |
| 🚀その他多数の改善                                                       | and more...                                                                                            |

## 時間経過での星の数 ⭐

[![時間経過での星の数](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
