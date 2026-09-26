# ps12exe

> [!CAUTION]
> Ne stockez jamais de mots de passe dans le code source !  
> Consultez [ici](#sécurité-des-mots-de-passe) pour plus de détails.

## Introduction

ps12exe est un module PowerShell qui vous permet de créer des fichiers exécutables à partir de scripts .ps1.

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./README_CN.md)
[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./README_EN_UK.md)
[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./README_EN_US.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## Utilisé par

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## Installation

```powershell
Install-Module ps12exe # Installer le module ps12exe
Set-ps12exeIntegration # Configurer le menu contextuel, l'Agent Skill et l'extension VS Code
```

(Vous pouvez également cloner ce référentiel et exécuter directement `.\ps12exe.ps1`)

**La migration de PS2EXE vers ps12exe est-elle difficile ? Pas de problème !**  
PS2EXE2ps12exe peut relier les appels de PS2EXE à ps12exe. Il vous suffit de désinstaller PS2EXE et d’installer ceci, puis de l’utiliser comme vous le feriez avec PS2EXE.  
Il vise une compatibilité maximale avec toutes les versions de PS2EXE (y compris `conHost`, `embedFiles` et les anciens `runtime20`/`runtime40`) ; les capacités absentes de ps12exe sont réécrites au moment de la compilation.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Utilisation

### Menu contextuel

Une fois que vous avez exécuté `Set-ps12exeIntegration`, vous pouvez cliquer avec le bouton droit sur n'importe quel fichier ps1 pour le compiler rapidement en exe ou ouvrir ps12exeGUI pour ce fichier.  
![Image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### Mode GUI

```powershell
ps12exeGUI
```

### Mode console

```powershell
ps12exe .\source.ps1 .\target.exe
```

Compile `source.ps1` en `target.exe` (si `.\target.exe` est omis, la sortie sera écrite dans `.\source.exe`).

```powershell
'"Bonjour le monde !"' | ps12exe
```

Compile `"Bonjour le monde !"` en exécutable et l’écrit dans `.\a.exe`.

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

Compile `Main.ps1` depuis Internet en exécutable et l’écrit dans `.\Main.exe`.

### Service Web auto-hébergé

```powershell
Start-ps12exeWebServer
```

Démarre un service Web qui permet aux utilisateurs de compiler du code PowerShell en ligne.

### Récupérer le ps1 depuis un exe (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` extrait le script PowerShell contenu dans un exécutable généré par ps12exe et le restitue dans un fichier `.ps1` ou sur la sortie standard. Comme ps12exe, il utilise la convention `$LastExitCode` : 0 = succès, 1 = erreur d’entrée/analyse (ex. exe non généré par ps12exe), 2 = erreur d’appel (ex. pas d’entrée en redirection), 3 = erreur ressource/interne (ex. fichier introuvable).

### Pipeline et redirection

- **ps12exe** : lorsque la sortie standard (ou l’entrée standard / l’erreur standard) est redirigée, ps12exe n’écrit que le chemin de l’exe généré sur la sortie standard pour pouvoir le capturer (ex. `$exe = ps12exe .\a.ps1`).
- **exe21sp** : accepte les chemins ou URL d’exe en entrée de pipeline (ex. `Get-ChildItem *.exe | exe21sp` ou `".\app.exe" | exe21sp`).
- **exe21sp** : si `-outputFile` n’est pas précisé et que la sortie standard n’est **pas** redirigée, le script décompilé est enregistré dans un fichier `.ps1` de même nom que l’exe, dans le même répertoire.
- **exe21sp** : si `-outputFile` n’est pas précisé et que la sortie standard **est** redirigée, le script décompilé est écrit sur la sortie standard.

### Extension VS Code

L'[extension ps12exe pour VS Code](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe) compile un script `.ps1` en exécutable — ou ouvre ps12exeGUI — sans quitter l'éditeur, et ajoute une prise en charge des directives de prétraitement (coloration syntaxique, diagnostics, fermeture automatique des `#_if`, pliage, aller à la définition, survol, complétion et formatage).

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeIntegration` l'installe automatiquement ; vous pouvez aussi installer `steve02081504.ps12exe` manuellement.

### Agent Skill

`Set-ps12exeIntegration` écrit également un Agent Skill `ps12exe` dans `~/.agents/skills`, afin que les agents de codage compatibles (opencode, Codex, Cursor, GitHub Copilot, …) sachent utiliser ps12exe lorsqu'on leur demande de compiler un script PowerShell en exécutable. `Set-ps12exeIntegration -action disable` le supprime, et `Set-ps12exeIntegration -Skip AgentSkill` l'ignore.

## Paramètres

### Paramètres GUI

```powershell
ps12exeGUI [[-ConfigFile] '<fichier_de_configuration>'] [-PS1File '<fichier_de_script>'] [-Locale '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<fichier_de_script>'] [-Locale '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : Fichier de configuration à charger.
PS1File    : Fichier de script à compiler.
Locale     : Code de langue à utiliser.
UIMode     : Mode de l'interface utilisateur à utiliser.
help       : Affiche cette aide.
```

### Paramètres console

<a id="console-parameters"></a>

```powershell
[input |] ps12exe [[-inputFile] '<nom_de_fichier|url>' | -Content '<script>'] [-outputFile '<nom_de_fichier>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true; DarkMode='Auto'|'On'|'Off';
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true; ConHost=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'|'arm64'; Apartment='STA'|'MTA';
        Culture='<culture>'; Options='<options>'; KeepSource=$true; Minify={<scriptblock>}; TempDir='<dossier>';
        Core=@{Backend='Shared'|'Bundled'; TargetOs='Windows'|'Linux'|'MacOS'; TargetFramework='<net8.0>'; PowerShellVersion='<version>'; SingleFile=$true; SelfContained=$true; Trimmed=$true; TrimMode='partial'|'full'; ReadyToRun=$true; InvariantGlobalization=$true; Aot=$true}}]
        [-Resources @{Icon='<nom_de_fichier|url>'; Title='<titre>'; Description='<description>'; Company='<société>';
        Product='<produit>'; Copyright='<copyright>'; Trademark='<marque_déposée>'; Version='<version>'}]
        [-Signing @{Certificate='<chemin du fichier PFX>'; Password='<mot de passe PFX>'; Thumbprint='<empreinte du certificat>'; Timestamp='<serveur d'horodatage>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Quiet] [-Locale '<code_de_langue>'] [-ConfigFile] [-help]
```

```text
input            : Chaîne de caractères du contenu du script PowerShell, identique à -Content.
inputFile        : Chemin d'accès ou URL du fichier de script PowerShell que vous souhaitez convertir en exécutable (le fichier doit être encodé en UTF8 ou UTF16).
Content          : Contenu du script PowerShell que vous souhaitez convertir en exécutable.
outputFile       : Nom de fichier ou dossier de l'exécutable cible, par défaut le nom de inputFile avec l'extension '.exe'.
App              : Table de hachage décrivant le comportement de l'application produite. Clés prises en charge :
                   Windowed         : Le fichier exécutable généré sera une application Windows Forms sans fenêtre de console.
                   Silence          : Noms des flux à rendre silencieux ; un ou plusieurs parmi 'Output', 'Verbose', 'Error', 'Warning', 'Debug', ou '*' pour tous.
                   OutputEncoding   : Encodage de sortie de la console ; 'Default', 'UTF8' ou 'UTF16LE'.
                   VisualStyles     : Active les styles visuels pour les applications GUI (par défaut $true).
                   DarkMode         : Thème sombre pour les fenêtres WinForms des applications GUI ; « 'Auto' » suit le thème du système et « 'On'/'Off' » le force.
                   ExitOnCancel     : Quitte le programme lorsqu'Annuler ou 'X' est sélectionné dans la boîte de dialogue Read-Host.
                   CredentialGUI    : Utilise une invite GUI pour les informations d'identification en mode console.
                   DpiAware         : Marque le fichier exécutable compilé comme compatible DPI.
                   WinFormsDpiAware : Laisse WinForms utiliser la mise à l'échelle DPI (nécessite Windows 10 et .Net 4.7 ou supérieur).
                   ConHost          : Force une console conhost au lieu de Windows Terminal ; désactive la redirection des entrées/sorties/erreurs.
Os               : Table de hachage des options d'intégration au système d'exploitation. Clés prises en charge :
                   Admin            : Si UAC est activé, l'exécutable compilé ne peut s'exécuter que dans un contexte élevé (une boîte de dialogue UAC apparaîtra si nécessaire).
                   ModernOS         : Utilise les fonctionnalités de la dernière version de Windows (exécutez [Environment]::OSVersion pour voir la différence).
                   LongPaths        : Active les chemins longs (> 260 caractères) si activé sur l'OS (ne fonctionne qu'avec Windows 10 ou plus récent).
                   Virtualize       : La virtualisation de l'application est activée (force le runtime x86).
Build            : Table de hachage des options de compilation. Clés prises en charge :
                   Target           : Version du runtime cible, par défaut 'Framework4.0', prend également en charge 'Framework2.0' et 'Core'. 'Core' produit un exécutable PowerShell Core (.NET) (nécessite PowerShell Core et .NET sur les machines de compilation et cible ; le résultat est bien plus volumineux).
                   Platform         : Compile uniquement pour un runtime spécifique. Les valeurs possibles sont 'AnyCpu', 'x64', 'x86' et 'arm64' (arm64 n'est valide que pour 'Core').
                   Apartment        : Mode 'Appartement à un seul thread' ou 'Appartement à plusieurs threads'.
                   Culture          : Culture du fichier exécutable compilé. Si non spécifié, la culture de l'utilisateur actuel sera utilisée.
                   Options          : Options de compilation supplémentaires (voir https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
                   KeepSource       : Crée des informations utiles pour le débogage.
                   Minify           : Bloc de script pour réduire la taille du script avant la compilation.
                   TempDir          : Répertoire pour stocker les fichiers temporaires (par défaut un répertoire temporaire aléatoire généré dans %temp%).
                   Core             : Options pour les builds de la cible 'Core'. Clés prises en charge :
                                      Backend                : 'Shared' (par défaut) résout PowerShell depuis l'installation pwsh de la machine cible et garde la sortie petite ; 'Bundled' embarque le SDK PowerShell (Microsoft.PowerShell.SDK) pour que la machine cible n'ait pas besoin de pwsh et que SelfContained/Trimmed/ReadyToRun/InvariantGlobalization/Aot deviennent disponibles, au prix d'une sortie beaucoup plus volumineuse.
                                      TargetOs               : Système d'exploitation cible : 'Windows', 'Linux' ou 'MacOS' (par défaut : l'OS de la machine de compilation). La sortie GUI/fenêtrée nécessite 'Windows'.
                                      TargetFramework        : Moniker de framework .NET cible (par exemple 'net8.0'). Par défaut, le runtime de la machine de compilation (Shared) ou le framework associé à PowerShellVersion (Bundled).
                                      PowerShellVersion      : Version du SDK PowerShell embarqué (Bundled uniquement). Par défaut, la version de PowerShell de la machine de compilation.
                                      SingleFile             : Publie un exécutable à fichier unique (par défaut $true). Si $false, l'exécutable et ses dépendances sont écrits sous forme de dossier.
                                      SelfContained          : Inclut le runtime .NET (Bundled uniquement ; par défaut $false). Beaucoup plus volumineux mais ne nécessite aucun runtime installé.
                                      Trimmed                : Active le découpage IL pour réduire la taille (Bundled uniquement ; par défaut $false).
                                      TrimMode               : Agressivité du découpage lorsque Trimmed est défini : 'partial' (par défaut, sûr) ou 'full' (agressif, peut casser la réflexion).
                                      ReadyToRun             : Précompile les assemblys pour un démarrage plus rapide (Bundled uniquement).
                                      InvariantGlobalization : Utilise la globalisation invariante, en supprimant les bibliothèques ICU des builds autonomes (Bundled uniquement).
                                      Aot                    : Compilation Native AOT expérimentale (Bundled uniquement ; nécessite SelfContained). La réflexion intensive utilisée par PowerShell peut casser certains scripts.
Resources        : Table de hachage des ressources de version intégrées à l'exécutable (Icon, Title, Description, Company, Product, Copyright, Trademark, Version). Icon peut être un chemin de fichier ou une URL. Pour un .exe/.dll, ajoutez ,<index> pour choisir une icône de ressource (0 par défaut), par ex. shell32.dll,3.
Signing          : Table de hachage des options de signature de code (Certificate, Password, Thumbprint, Timestamp). Vous devez spécifier Certificate ou Thumbprint.
PreprocessOnly   : Prétraite le script d'entrée et le retourne sans compilation.
Golf             : Activer le mode golf, ajoute des abreviations et des fonctions courantes au script.
Sandbox          : Compile le script avec une protection supplémentaire, évite l'accès aux fichiers natifs.
NoUpdateCheck    : Ignore la vérification de la nouvelle version de ps12exe.
Quiet            : Supprime la sortie d'information (hôte) pendant la compilation ; les erreurs et avertissements restent affichés.
Locale           : Spécifie la langue de localisation.
ConfigFile       : Écrit un fichier de configuration (<fichier_de_sortie>.exe.config).
Help             : Affiche cette aide.
```

## Remarques

### Gestion des erreurs

Contrairement à la plupart des fonctions PowerShell, ps12exe définit la variable `$LastExitCode` pour indiquer les erreurs, mais ne garantit pas l'absence totale d'exceptions.  
Vous pouvez utiliser quelque chose comme ceci pour vérifier si des erreurs se sont produites :

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"un peu de code !"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe a échoué avec le code de sortie $LastExitCode"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

Les différentes valeurs de `$LastExitCode` représentent différents types d'erreurs :

| Type d'erreur | Valeur de `$LastExitCode`    |
| ------------- | ---------------------------- |
| 0             | Pas d'erreur                 |
| 1             | Erreur dans le code d'entrée |
| 2             | Erreur de format d'appel     |
| 3             | Erreur interne ps12exe       |

### Prétraitement

<a id="preprocessing-overview"></a>

ps12exe prétraite le script avant la compilation.

```powershell
# Lit le cadre de programme à partir du fichier ps12exe.cs
#_if PSEXE # Ce code de prétraitement est utilisé lorsque ce script est compilé par ps12exe
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" # Inclut le contenu de ps12exe.cs dans ce script
#_else # Sinon, lit le fichier cs normalement
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

Seules les conditions suivantes sont prises en charge pour le moment : `PSEXE` et `PSScript`.  
`PSEXE` est vrai ; `PSScript` est faux.

#### `#_include <nom_de_fichier|url>`/`#_include_as_value <nom_de_valeur> <fichier|url>`

<a id="preprocessing-include"></a>

```powershell
#_include <nom_de_fichier|url>
#_include_as_value <nom_de_valeur> <fichier|url>
```

Inclut le contenu du fichier `<nom_de_fichier|url>` ou `<fichier|url>` dans le script. Le contenu du fichier est inséré à la position de la commande `#_include`/`#_include_as_value`.

Contrairement à l'instruction `#_if`, si vous n'entourez pas le nom de fichier avec des guillemets, les commandes de prétraitement `#_include` considèrent également les espaces de fin et `#` comme faisant partie du nom de fichier.

```powershell
#_include $PSScriptRoot/super #nomdefichierbizarre.ps1
#_include "$PSScriptRoot/nomdefichier.ps1" #commentaire sécurisé !
```

Lors de l'utilisation de `#_include`, le contenu du fichier est prétraité, ce qui vous permet d'inclure plusieurs niveaux de fichiers.

`#_include_as_value` insère le contenu du fichier dans le script en tant que valeur de chaîne. Le contenu du fichier n'est pas prétraité.

Dans la plupart des cas, vous n'avez pas besoin d'utiliser les commandes de prétraitement `#_if` et `#_include` pour que les sous-scripts soient correctement inclus après la conversion du script en exe, ps12exe gérera automatiquement les cas comme ceux qui suivent et considérera que le script cible doit être inclus :

```powershell
. $PSScriptRoot/un_autre.ps1
& $PSScriptRoot/un_autre.ps1
$result = & "$PSScriptRoot/un_autre.ps1" -args
```

#### `#_include_as_(base64|bytes) <nom_de_valeur> <fichier|url>`

<a id="preprocessing-include-as"></a>

```powershell
#_include_as_base64 <nom_de_valeur> <fichier|url>
#_include_as_bytes <nom_de_valeur> <fichier|url>
```

Convertit le contenu du fichier en une chaîne base64 ou un tableau d'octets au cours de l'étape de prétraitement et l'insère dans le script. Le contenu du fichier n'est pas prétraité.

Voici un exemple simple de packer :

```powershell
#_include_as_bytes mesdonnées $PSScriptRoot/données.bin
[System.IO.File]::WriteAllBytes("données.bin", $mesdonnées)
```

L'exe libérera le fichier `données.bin` qui a été incorporé dans le script lors de la compilation une fois exécuté.

#### `#_!!`

<a id="preprocessing-bang"></a>

```powershell
$Script:eshDir =
#_if PSScript #Il ne peut pas y avoir de $EshellUI dans PSEXE
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

Toute ligne commençant par `#_!!` verra son `#_!!` initial supprimé.

#### `#_require <liste_de_modules>`

<a id="preprocessing-require"></a>

```powershell
#_require ps12exe
#_pragma App.Windowed
$Number = [bigint]::Parse('0')
$NextNumber = $Number+1
$NextScript = $PSEXEscript.Replace("Parse('$Number')", "Parse('$NextNumber')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
$Number
```

`#_require` compte les modules nécessaires dans l'ensemble du script et ajoute un script équivalent au code suivant avant le premier `#_require`:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

Il convient de noter que le code généré ne fera qu'installer les modules, et non les importer.  
Veuillez utiliser `Import-Module` en conséquence.

Lorsque vous devez requérir plusieurs modules, vous pouvez utiliser des espaces, des virgules ou des points-virgules, des virgules inversées comme séparateurs, et vous n'avez pas besoin d'écrire plusieurs instructions require.

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

<a id="preprocessing-pragma"></a>

Les directives de prétraitement pragma n'ont aucun effet sur le contenu du script, mais modifient les paramètres utilisés pour la compilation.  
Voici un exemple :

```powershell
PS C:\Users\steve02081504> '12' | ps12exe
Fichier compilé écrit -> 1 024 octets
PS C:\Users\steve02081504> ./a.exe
12
PS C:\Users\steve02081504> '#_pragma App.Windowed
>> 12' | ps12exe
Script prétraité -> 23 octets
Fichier compilé écrit -> 2 560 octets
```

Comme vous pouvez le voir, `#_pragma App.Windowed` fait fonctionner le fichier exe généré en mode fenêtre, même si nous n'avons pas spécifié `-App @{Windowed=$true}` lors de la compilation.  
La commande pragma peut définir tous les paramètres de compilation ; utilisez `.` dans le nom pour définir des valeurs imbriquées :

```powershell
#_pragma App.Windowed # Mode fenêtre
#_pragma App.Windowed $false # Mode console
#_pragma Resources.Icon $PSScriptRoot/icon.ico # Définit l'icône
#_pragma Resources.Title "title" # Définit le titre de l'exe
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" # Définit le certificat de signature de code
```

Les valeurs de pragma de type chaîne peuvent également contenir des sous-expressions `$(...)`, évaluées au moment du prétraitement, par ex. `#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`. Seules les commandes liées aux chemins figurant sur la liste blanche (`Get-Command`, `Join-Path`, `Split-Path`, `Resolve-Path`, `Convert-Path`, `Get-Item`, `Test-Path`, `Get-ChildItem`, plus `Get-Content` hors Sandbox), les variables (`$env:*` (dans Sandbox uniquement `$env:windir`/`$env:SystemRoot`), `$PSScriptRoot`, `$ScriptRoot`, `$HOME`, `$PWD`, `$PSCommandPath`) et les méthodes d’instance inoffensives courantes (par ex. `ToUpper`, `Trim`, `Split`, `ToString`) sont autorisées ; toute autre chose interrompt la compilation. Les valeurs entre guillemets simples restent entièrement littérales. Le mode Sandbox ignore aussi `#_pragma outputFile`, `Build.TempDir`, `Build.Minify` et `Signing.Certificate`, et ne récupère que les URL http(s) résolues vers des adresses publiques (les cibles de redirection sont restreintes de la même façon). Les chemins locaux de `Resources.Icon` ne sont autorisés que sous le répertoire Windows.

#### `#_DllExport`

<a id="preprocessing-dllexport"></a>

```powershell
#_DllExport int Add(int a, int b)
#_DllExport Add(int a, int b)
#_DllExport DoSomething(int value)

function Add($a, $b) { return $a + $b }
function DoSomething($value) { ... }
```

`#_DllExport` compile le script en une DLL Win32 native au lieu d'un exécutable, en exportant les fonctions listées afin que les appelants natifs puissent les utiliser directement via `LoadLibrary`/`GetProcAddress` (ou `DllImport`). Chaque fonction exportée est relayée vers la fonction PowerShell du même nom : les arguments sont passés sous forme de tableau et la sortie de la fonction devient la valeur de retour. Les types de retour et de paramètres s'écrivent en syntaxe C# ; sans type de retour, `void` est utilisé, et un paramètre sans type est traité comme `string`.

L'export natif nécessite une cible .NET Framework 4.0 et une plateforme `x86`/`x64` (`AnyCPU` est résolu automatiquement selon l'architecture de l'hôte) ; la sortie est `.dll` par défaut. La fonctionnalité est indisponible en mode invité (sandbox). Les appels sont sérialisés et le premier démarre l'espace d'exécution PowerShell. Une erreur du script est écrite sur stderr et l'appel renvoie la valeur par défaut du type déclaré plutôt que de laisser l'exception franchir la frontière native.

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <code_de_sortie>
#_balus
```

Lorsque le code est exécuté jusqu'à ce point, il quitte le processus avec le code de sortie donné et supprime le fichier exe.

### Minification

Étant donné que la "compilation" de ps12exe incorpore tout le contenu du script en tant que ressource mot pour mot dans le fichier exécutable généré, si le script contient un grand nombre de chaînes de caractères inutiles, le fichier exécutable généré sera très volumineux.  
Vous pouvez utiliser la clé `Minify` de `-Build` pour spécifier un bloc de script qui prétraitera le script avant la compilation afin d'obtenir un fichier exécutable généré plus petit.

Si vous ne savez pas comment écrire un tel bloc de script, vous pouvez utiliser [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | &./psminnifyer.ps1 }}
```

### Liste des cmdlets non implémentées

Les commandes d'entrée/sortie de base de ps12exe doivent être réécrites en C#. Celles qui ne sont pas implémentées sont _`Write-Progress`_ en mode console (trop de travail) et _`Start-Transcript`_/_`Stop-Transcript`_ (Microsoft n'a pas d'implémentation de référence appropriée).

### Format de sortie du mode GUI

Par défaut, le format de sortie des petites commandes dans PowerShell est une ligne par ligne (en tant que tableaux de chaînes de caractères). Lorsqu'une commande génère 10 lignes de sortie et utilise la sortie GUI, il y aura 10 boîtes de message, chacune attendant d'être confirmée. Pour éviter que cela ne se produise, importez la commande `Out-String` dans la ligne de commande. Cela convertira la sortie en un tableau de chaînes de caractères de 10 lignes, et toutes les sorties seront affichées dans une seule boîte de message (par exemple : `dir C:\| Out-String`).

### Fichier de configuration

ps12exe peut créer des fichiers de configuration, avec le nom de fichier `fichier exécutable généré + ".config"`. Dans la plupart des cas, ces fichiers de configuration ne sont pas nécessaires, ils sont simplement un manifeste qui vous indique quelle version du .Net Framework doit être utilisée. Comme vous utiliserez généralement le .Net Framework réel, essayez d'exécuter votre fichier exécutable sans utiliser de fichier de configuration.

### Gestion des paramètres

Les scripts compilés gèrent les paramètres comme le script d'origine. Une des limitations provient de l'environnement Windows : pour tous les exécutables, les arguments de ligne de commande sont en fin de compte des chaînes de caractères.

Lorsque le script possède un bloc `param()` de niveau supérieur, ps12exe analyse les valeurs des arguments comme des données PowerShell (PSD) : les tables de hachage `@{}`, les tables de hachage ordonnées `[ordered]@{}`, les tableaux `@()` et les conversions vers des types sûrs comme `[int]'5'` ou `[hashtable]@{}` sont transmises au paramètre sous forme d'objet, sans conversion manuelle :

```powershell
# script : param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

La valeur doit être entre guillemets : les shells transforment en chaîne un `@{...}` non cité (le programme ne reçoit que le texte `System.Collections.Hashtable`). Tout ce qui n'est pas une donnée (une expression ou une commande) est transmis comme une simple chaîne et n'est jamais évalué ; ainsi `-Config "@{x=(Get-Date)}"` n'exécute aucun code, il échoue simplement à la liaison.

Les valeurs transmises par canalisation restent des chaînes.

### Sécurité des mots de passe

<a id="password-security-stuff"></a>
Ne stockez jamais de mots de passe dans les scripts compilés !  
L'ensemble du script est facilement visible pour n'importe quel décompilateur .net.  
![Image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Différencier l'environnement par script

Vous pouvez utiliser `$Host.Name` pour déterminer si un script est exécuté dans un exe compilé ou dans un script.

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Un autre hôte" }
```

### Variables de script

Étant donné que ps12exe convertit les scripts en fichiers exécutables, la valeur de la variable `$MyInvocation` est différente de celle du script.

Vous pouvez toujours utiliser `$PSScriptRoot` pour obtenir le chemin d'accès au répertoire où se trouve le fichier exécutable, et utiliser `$PSCommandPath` pour obtenir le chemin d'accès au fichier exécutable lui-même.

### Fenêtre d'arrière-plan en mode `App.Windowed`

Lorsque vous ouvrez une fenêtre externe dans un script qui utilise le mode `App.Windowed` (par exemple `Get-Credential` ou des commandes nécessitant `cmd.exe`), une fenêtre s'ouvrira en arrière-plan.

La raison en est que lorsque vous fermez une fenêtre externe, Windows essaie d'activer la fenêtre parente. Étant donné qu'il n'y a pas de fenêtre pour le script compilé, cela activera la fenêtre parente du script compilé, généralement l'explorateur ou la fenêtre Powershell.

Pour résoudre ce problème, vous pouvez utiliser `$Host.UI.RawUI.FlushInputBuffer()` pour ouvrir une fenêtre invisible qui peut être activée. L'appel suivant à `$Host.UI.RawUI.FlushInputBuffer()` fermera cette fenêtre (et ainsi de suite).

L'exemple suivant n'ouvrira plus la fenêtre en arrière-plan, contrairement au fait d'appeler `ipconfig | Out-String` une seule fois :

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### Entrée standard et `$input`

Un exe compilé ne lit l'entrée standard redirigée (ligne par ligne, comme entrée de pipeline) que lorsque le script utilise `$input` au **niveau supérieur** :

- Si `$input` est utilisé : comportement identique à PS2EXE — stdin est consommé comme entrée de pipeline, de sorte que le stdin brut (`[Console]::In` / `Console.OpenStandardInput()`) atteint EOF ensuite.
- Si `$input` n'est pas utilisé : stdin n'est pas lu du tout ; l'entrée standard brute reste intacte et le démarrage n'attend pas stdin (un parent qui garde le pipe ouvert ne bloque plus le programme), et les processus enfants peuvent toujours hériter de stdin.

Seul le niveau supérieur du script compte : un `$input` dans des fonctions, des blocs de script ou des classes est l'entrée de pipeline propre à cette portée et est ignoré.

Par exemple, si le script appelle `[Console]::In.ReadToEnd()` et n'utilise jamais `$input`, après compilation, `echo hi | .\tool.exe` reçoit `hi`.

### Évaluation des constantes

Pour les scripts uniquement constants et sans effet de bord, ps12exe les évalue à la compilation et intègre le résultat directement dans un exe minuscule (généralement autour de 1 Ko) ; il revient à la compilation normale lorsque l'évaluation dépasse le délai d'attente (7 secondes par défaut) ou que le résultat est trop long. Si l'environnement d'évaluation diffère de l'exécution, ou si vous voulez simplement l'hôte PowerShell complet, ajoutez l'un des pragmas ci-dessous pour refuser explicitement cette optimisation :

- `#_pragma Build.ConstEval.Enabled 0` : déclare que ce script n'est pas une constante ; ignore l'évaluation des constantes.
- `#_pragma Build.ConstEval.Timeout 1` : déclare que cette évaluation de constante a déjà expiré ; applique le même repli qu'en cas de délai dépassé.

Les deux sont analysés comme des pragmas imbriqués ordinaires lors du prétraitement, donc ils peuvent figurer sur n'importe quelle ligne ; après le repli vers l'hôte normal, ces lignes ne sont que des commentaires ordinaires.

## Comparaison des avantages 🏆

### Comparaison rapide 🏁

| Comparaison                                             | ps12exe                                                                                                   | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                                |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Référentiel de script pur 📦                            | ✔️ Tous les fichiers sont des fichiers texte sauf les images et les DLL fournies                          | ❌ Fournit `Win-PS2EXE.exe` sous licence open source                                                          |
| Commande requise pour générer hello world 🌍            | 😎`'"Bonjour le monde !"' \| ps12exe`                                                                     | 🤔`echo "Bonjour le monde !" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                                |
| Exécutable hello world constant 💾                      | 🥰1 024 octets (évalué à la compilation)                                                                  | ❌ Non pris en charge ; 25 088 octets                                                                         |
| Exécutable hello world non constant 💾                  | 🥰14 848 octets                                                                                           | 😨25 088 octets                                                                                               |
| Évaluation constante à la compilation ⚡                | ✔️                                                                                                        | ❌                                                                                                            |
| Cible PowerShell Core (7+) / multiplateforme 🧬         | ✔️ `Build.Target Core` (Windows / Linux / macOS)                                                          | ❌ Windows PowerShell 5.1 uniquement                                                                          |
| Prise en charge multilingue de l'interface graphique 🌐 | ✔️ (7 langues, mode sombre)                                                                               | ❌                                                                                                            |
| Vérification de la syntaxe lors de la compilation ✔️    | ✔️                                                                                                        | ❌                                                                                                            |
| Fonction de prétraitement 🔄                            | ✔️                                                                                                        | ❌                                                                                                            |
| Analyse des paramètres spéciaux tels que `-extract` 🧹  | 🗑️ Supprimé (utilisez l'outil `exe21sp`)                                                                  | 🥲 Nécessite la modification du code source                                                                   |
| Degré d'accueil des PR 🤝                               | 🥰 Bienvenue !                                                                                            | 🤷 14 PR dont 13 fermées                                                                                      |
| Biais politique / DEI / idéologique 🕊️                  | ✔️ Aucun ; toute PR utile est bienvenue — d'un humain, d'une IA ou d'un singe devant une machine à écrire | ❌ Le README affiche une position anti-IA (« l'intelligence artificielle tue la créativité et notre nature ») |

Le développeur de ps12exe n'utilise pas ce projet pour promouvoir une position politique, DEI ou autre : toute PR utile est bienvenue, qu'elle vienne d'un humain, d'une IA ou d'un singe devant une machine à écrire.

### Taille et vitesse 🔬

Mesuré sous Windows 11 avec PowerShell 7.6.6 (.NET 10) et Windows PowerShell 5.1, 20 exécutions à chaud chacune. Le plancher de création de processus (`cmd /c exit`) est d'environ 15 ms. Reproduire avec `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` (ajoutez `-Compile` pour le tableau de vitesse de compilation ci-dessous).

| Build                                                  | Taille de sortie   | Démarrage à chaud  |
| ------------------------------------------------------ | ------------------ | ------------------ |
| Windows PowerShell 5.1 exécutant le script directement | —                  | ~406 ms            |
| ps12exe · constant · Framework4.0                      | 1 024 octets       | ~54 ms             |
| ps12exe · non constant · Framework4.0                  | 14 848 octets      | ~365 ms            |
| PS2EXE 1.0.18 · non constant                           | 25 088 octets      | ~398 ms            |
| ps12exe · non constant · grand script · Framework4.0   | 30 208 octets      | ~381 ms            |
| PS2EXE 1.0.18 · non constant · grand script            | ~496 Ko            | ~402 ms            |
| ------------------------------------------------------ | ------------------ | ------------------ |
| pwsh 7 exécutant le script directement                 | —                  | ~676 ms            |
| ps12exe · constant · Core                              | ~165 Ko            | ~104 ms            |
| ps12exe · non constant · Core                          | ~181 Ko            | ~621 ms            |
| ps12exe · non constant · grand script · Core           | ~187 Ko            | ~637 ms            |
| PS2EXE 1.0.18 · non constant · Core                    | non pris en charge | non pris en charge |

Un script constant est évalué à la compilation : son exe ne fait que 1 Ko et ne démarre jamais PowerShell — environ 24× plus petit et 6× plus rapide à lancer qu'un hello world PS2EXE. Les exe non constants sont ~40 % plus petits que ceux de PS2EXE, et pour les scripts utilisant massivement des variables de portée globale, ils s'exécutent aussi plus vite, car le script s'exécute dans une fonction (portée locale) plutôt qu'au niveau global. Les exe non constants sont toujours compressés, et l'avantage s'accentue avec la taille : un script d'environ 0,5 Mo donne toujours un exe Framework d'environ 30 Ko, soit environ 1/16 des ~496 Ko de PS2EXE, qui laisse sa charge utile quasiment non compressée et gonfle avec la taille du script. L'exe Core ne prend que ~6 Ko de plus que son équivalent pour petit script, donc les grosses charges utiles restent petites au lieu de gonfler.

### Démarrage des applications GUI fenêtrées 🪟

Le benchmark hello world ci-dessus mesure le lancement d'une application console qui se termine immédiatement ; ses résultats sont donc principalement dus au démarrage du processus. Une application GUI reste ouverte pendant l'interaction de l'utilisateur : la mesure pertinente est le délai entre le double-clic et l'apparition de la fenêtre — le coût de démarrage et d'exécution du script, et non la durée de vie du processus. Mesure effectuée avec le même outil (`-Windowed`), à l'aide d'une fenêtre WinForms qui se ferme automatiquement après ~800 ms ; le démarrage à chaud de chaque ligne comprend le démarrage du processus et l'exécution du script (la durée d'affichage est presque identique pour toutes les lignes et le plancher de création de processus d'environ 15 ms est négligeable ici).

| Compilation                                                             | Taille de sortie | Démarrage à chaud |
| ----------------------------------------------------------------------- | ---------------- | ----------------- |
| Windows PowerShell 5.1 exécutant directement le script (fenêtre cachée) | —                | ~1154 ms          |
| ps12exe · fenêtré · DarkMode Auto · Framework4.0                        | 29 184 octets    | ~1128 ms          |
| PS2EXE 1.0.18 · fenêtré · non constant                                  | 33 792 octets    | ~1128 ms          |
| ----------------------------------------------------------------------  | ---------------- | ----------------- |
| pwsh 7 exécutant directement le script (fenêtre cachée)                 | —                | ~1349 ms          |
| ps12exe · fenêtré · DarkMode Auto · Core                                | ~6385 Ko         | ~1317 ms          |

Une application ps12exe fenêtrée démarre presque aussi vite que PS2EXE (~1128 ms), et les deux sont légèrement plus rapides que l'exécution directe du même script par PowerShell : ps12exe supprime les coûts similaires à `-NoProfile` et ne réanalyse pas le script, tout en ajoutant l'enveloppe d'hôte `Silence`/`OutputEncoding` et la prise en charge du mode sombre. L'application Core fenêtrée (~1317 ms) est à peine plus lente que Framework et un peu plus rapide que `pwsh` exécutant directement le script (~1349 ms). La sortie Core d'environ 6,4 Mo est autonome par défaut ; désactivez cette option avec `-Build @{Target='Core';SelfContained=$false}` pour revenir à l'exécutable d'environ 0,2 Mo utilisant un runtime partagé. Le gain de taille de l'application Framework fenêtrée par rapport à PS2EXE (~4,5 Ko) est inférieur à celui des applications console, car les deux doivent intégrer l'amorçage WinForms.

### Vitesse de compilation ⏱️

Mesuré avec le même outil (`-Compile -IncludeCore`). Chaque échantillon est un nouveau processus hôte (Windows PowerShell 5.1 pour Framework/PS2EXE, pwsh 7 pour Core) ; « à chaud » correspond à la médiane de 5 compilations après la première. Les chiffres PS2EXE proviennent de la version installée localement (1.0.18 dans cet environnement).

| Build                                                | Compilation à chaud |
| ---------------------------------------------------- | ------------------- |
| ps12exe · constant · Framework4.0                    | ~2,3 s              |
| ps12exe · non constant · Framework4.0                | ~1,3 s              |
| PS2EXE · non constant                                | ~0,9 s              |
| ps12exe · non constant · grand script · Framework4.0 | ~1,5 s              |
| PS2EXE · non constant · grand script                 | ~0,7 s              |
| ---------------------------------------------------- | ------------------- |
| ps12exe · constant · Core                            | ~4,2 s              |
| ps12exe · non constant · Core                        | ~5,7 s              |
| ps12exe · non constant · grand script · Core         | ~5,9 s              |
| PS2EXE · non constant · Core                         | non pris en charge  |

PS2EXE compile un hello world plus vite car ce n'est qu'une fine surcouche du compilateur .NET Framework intégré à Windows : il effectue une seule passe CodeDom et rien d'autre. ps12exe exécute en plus une vérification de syntaxe, classe le script et (pour les scripts constants) l'évalue, puis emballe la trame de programme comme charge utile dans un lanceur ; sa compilation non constante est donc ~1,4× celle de PS2EXE. Le compromis se voit dans la sortie : ps12exe produit 1 024 / 14 848 octets là où PS2EXE en produit 25 088, et les programmes constants se lancent environ 6× plus vite. La compilation Core est dominée par `dotnet publish` ; la première compilation d'une configuration donnée restaure aussi les paquets NuGet, après quoi ps12exe réutilise le répertoire de projet généré et lance `dotnet publish --no-restore`.

Le compilateur lui-même est distribué sous forme de module PowerShell :

| Paquet du compilateur   | Décompressé | Compressé |
| ----------------------- | ----------- | --------- |
| ps12exe (master actuel) | ~1,64 Mo    | ~629 Ko   |
| PS2EXE 1.0.18           | ~171 Ko     | ~46 Ko    |

Le module ps12exe est plus volumineux car c'est un compilateur en pur script sans dépendance qui embarque des binaires [AsmResolver](https://github.com/Washi1337/AsmResolver) allégés, 7 localisations et une interface graphique en pur script ; PS2EXE ne fournit presque rien et s'appuie sur le compilateur .NET Framework intégré à Windows.

### Export DLL natif 🧩

Un script avec `#_DllExport` est compilé en DLL Win32 appelable via `LoadLibrary`/`GetProcAddress` (Framework4.0 + x86/x64 uniquement ; PS2EXE n'a pas d'équivalent). Script fixe à deux exports (`Add`, `Greet`) :

| Build                               | Taille de sortie   | Compilation à chaud |
| ----------------------------------- | ------------------ | ------------------- |
| ps12exe · export DLL · Framework4.0 | 28 160 octets      | ~2,8 s              |
| PS2EXE 1.0.18 · export DLL          | non pris en charge | non pris en charge  |

### Comportement d'exécution des EXE compilés 🖥️

Vérifié dans une véritable fenêtre de console sous Windows 11 : les processus enfants natifs lancés par l'EXE voient-ils une vraie TTY de console ([#59](https://github.com/steve02081504/ps12exe/issues/59)), le script peut-il lire le stdin brut ([#62](https://github.com/steve02081504/ps12exe/issues/62)), et les variables de chemin spéciales se résolvent-elles ?

| Capacité                                                                  | ps12exe                                 | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------ |
| Le processus enfant natif voit une TTY (`isTTY`)                          | ✔️                                      | ❌                                                                             |
| stdin brut (`[Console]::In`) lisible                                      | ✔️ (sauf si le script utilise `$input`) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` se résolvent                           | ✔️ (chemin / dossier de l'exe)          | ❌                                                                             |
| Arguments en ligne de commande analysés comme données PSD (tables/objets) | ✔️ (`-Config "@{...}"`)                 | ❌ (chaînes uniquement)                                                        |

PS2EXE 1.0.18 fait toujours passer la sortie du script par `Out-String` et draine entièrement le stdin redirigé avant d'exécuter le script : les processus enfants natifs perdent le handle de console et le stdin atteint EOF. ps12exe écrit via l'hôte (`Out-Default`) et ne draine le stdin que si le script utilise réellement `$input`. De plus, PS2EXE laisse `$PSCommandPath`/`$PSScriptRoot` vides dans le programme compilé (il fournit son propre `$ScriptRoot`), tandis que ps12exe mappe les deux vers l'exe généré.

### Comparaison détaillée 🔍

Par rapport à [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615), ce projet apporte les améliorations suivantes :

| Amélioration                                                                                 | Description                                                                                                                                                |
| -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ✔️ Vérification de la syntaxe lors de la compilation                                         | Effectue la vérification de la syntaxe lors de la compilation pour améliorer la qualité du code                                                            |
| ⚡ Évaluation constante à la compilation                                                     | Les scripts sans effet de bord sont évalués à la compilation et générés sous forme d'exe d'environ 1 Ko                                                    |
| 🧬 Cible PowerShell Core / multiplateforme                                                   | `Build.Target Core` cible PowerShell 7+ sous Windows, Linux et macOS                                                                                       |
| 🔄 Puissantes fonctions de prétraitement                                                     | Prétraite les scripts avant la compilation, plus besoin de copier-coller tout le contenu dans le script                                                    |
| 🛠️ Paramètre `Build.Options`                                                                 | Ajout d'un nouveau paramètre qui vous permet de personnaliser davantage le fichier exécutable généré                                                       |
| 📦️ Paramètre `Build.Minify`                                                                  | Prétraite les scripts avant la compilation afin de générer des fichiers exécutables plus petits                                                            |
| 🌐 Prise en charge de la compilation de scripts et de l'inclusion de fichiers depuis des URL | Prise en charge du téléchargement d'icônes depuis une URL                                                                                                  |
| 🖥️ Optimisation du paramètre `App.Windowed`                                                  | Optimisation du traitement des options et de l'affichage du titre de la fenêtre, vous pouvez maintenant définir le titre des fenêtres popup personnalisées |
| ✍️ Signature de code et conversion automatique des icônes                                    | Signez la sortie avec un certificat PFX ou une empreinte du magasin, et convertissez les icônes automatiquement                                            |
| 🧰 Outils supplémentaires : `exe21sp`, serveur web, menu contextuel, mode interactif         | Décompiler des exe, compiler en ligne, compiler par clic droit, et plus encore                                                                             |
| 🧹 Suppression du fichier exe                                                                | Suppression des fichiers exe du référentiel de code                                                                                                        |
| 🌍 Prise en charge multilingue, interface graphique en pur script                            | Meilleure prise en charge multilingue, interface graphique en pur script, prise en charge du mode sombre                                                   |
| 📖 Séparation du fichier cs du fichier ps1                                                   | Plus facile à lire et à entretenir                                                                                                                         |
| 🚀 Plus d'améliorations                                                                      | Et bien plus encore...                                                                                                                                     |

## Points de vue au fil du temps ⭐

[![Points de vue au fil du temps](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
