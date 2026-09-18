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
Set-ps12exeContextMenu # Définir le menu contextuel du clic droit
```

(Vous pouvez également cloner ce référentiel et exécuter directement `.\ps12exe.ps1`)

**La migration de PS2EXE vers ps12exe est-elle difficile ? Pas de problème !**  
PS2EXE2ps12exe peut relier les appels de PS2EXE à ps12exe. Il vous suffit de désinstaller PS2EXE et d’installer ceci, puis de l’utiliser comme vous le feriez avec PS2EXE.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Utilisation

### Menu contextuel

Une fois que vous avez défini `Set-ps12exeContextMenu`, vous pouvez cliquer avec le bouton droit sur n'importe quel fichier ps1 pour le compiler rapidement en exe ou ouvrir ps12exeGUI pour ce fichier.  
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

## Paramètres

### Paramètres GUI

```powershell
ps12exeGUI [[-ConfigFile] '<fichier_de_configuration>'] [-PS1File '<fichier_de_script>'] [-Localize '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<fichier_de_script>'] [-Localize '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : Fichier de configuration à charger.
PS1File    : Fichier de script à compiler.
Localize   : Code de langue à utiliser.
UIMode     : Mode de l'interface utilisateur à utiliser.
help       : Affiche cette aide.
```

### Paramètres console

```powershell
[input |] ps12exe [[-inputFile] '<nom_de_fichier|url>' | -Content '<script>'] [-outputFile '<nom_de_fichier>']
        [-CompilerOptions '<options>'] [-TempDir '<dossier>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<nom_de_fichier|url>'; title='<titre>'; description='<description>'; company='<société>';
        product='<produit>'; copyright='<copyright>'; trademark='<marque_déposée>'; version='<version>'}]
        [-CodeSigning @{Path='<chemin du fichier PFX>'; Password='<mot de passe PFX>'; Thumbprint='<empreinte du certificat>'; TimestampServer='<serveur d'horodatage>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<version_du_runtime>']
        [-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<code_de_langue>'] [-help]
```

```text
input            : Chaîne de caractères du contenu du script PowerShell, identique à -Content.
inputFile        : Chemin d'accès ou URL du fichier de script PowerShell que vous souhaitez convertir en exécutable (le fichier doit être encodé en UTF8 ou UTF16).
Content          : Contenu du script PowerShell que vous souhaitez convertir en exécutable.
outputFile       : Nom de fichier ou dossier de l'exécutable cible, par défaut le nom de inputFile avec l'extension '.exe'.
CompilerOptions  : Options de compilation supplémentaires (voir https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
TempDir          : Répertoire pour stocker les fichiers temporaires (par défaut un répertoire temporaire aléatoire généré dans %temp%).
minifyer         : Bloc de script pour réduire la taille du script avant la compilation.
lcid             : ID de localisation du fichier exécutable compilé. Si non spécifié, la culture de l'utilisateur actuel sera utilisée.
prepareDebug     : Crée des informations utiles pour le débogage.
architecture     : Compile uniquement pour un runtime spécifique. Les valeurs possibles sont 'x64', 'x86' et 'anycpu'.
threadingModel   : Mode 'Appartement à un seul thread' ou 'Appartement à plusieurs threads'.
noConsole        : Le fichier exécutable généré sera une application Windows Forms sans fenêtre de console.
UNICODEEncoding  : Encode la sortie en UNICODE en mode console.
credentialGUI    : Utilise une invite GUI pour les informations d'identification en mode console.
resourceParams   : Table de hachage contenant les paramètres de ressource du fichier exécutable compilé.
CodeSigning      : Table de hachage contenant les paramètres de signature de code pour le fichier exécutable compilé.
configFile       : Écrit un fichier de configuration (<fichier_de_sortie>.exe.config).
noOutput         : Le fichier exécutable généré ne produira pas de sortie standard (y compris les flux détaillés et d'informations).
noError          : Le fichier exécutable généré ne produira pas de sortie d'erreur (y compris les flux d'avertissement et de débogage).
noVisualStyles   : Désactive les styles visuels pour les applications Windows GUI générées (utilisé uniquement avec -noConsole).
exitOnCancel     : Quitte le programme lorsqu'Annuler ou 'X' est sélectionné dans la boîte de dialogue Read-Host (utilisé uniquement avec -noConsole).
DPIAware         : Les contrôles GUI seront mis à l'échelle autant que possible si le mise à l'échelle de l'affichage est activée.
winFormsDPIAware : WinForms utilisera la mise à l'échelle DPI si la mise à l'échelle de l'affichage est activée (nécessite Windows 10 et .Net 4.7 ou supérieur).
requireAdmin     : Si UAC est activé, l'exécutable compilé ne peut s'exécuter que dans un contexte élevé (une boîte de dialogue UAC apparaîtra si nécessaire).
supportOS        : Utilise les fonctionnalités de la dernière version de Windows (exécutez [Environment]::OSVersion pour voir la différence).
virtualize       : La virtualisation de l'application est activée (force le runtime x86).
longPaths        : Active les chemins longs (> 260 caractères) si activé sur l'OS (ne fonctionne qu'avec Windows 10 ou plus récent).
targetRuntime    : Version du runtime cible, par défaut 'Framework4.0', prend également en charge 'Framework2.0' et 'Core'. 'Core' produit un exécutable PowerShell Core (.NET) (nécessite PowerShell Core et .NET sur les machines de compilation et cible ; le résultat est bien plus volumineux).
SkipVersionCheck : Ignore la vérification de la nouvelle version de ps12exe.
GuestMode        : Compile le script avec une protection supplémentaire, évite l'accès aux fichiers natifs.
PreprocessOnly   : Prétraite le script d'entrée et le retourne sans compilation.
GolfMode         : Activer le mode golf, ajoute des abreviations et des fonctions courantes au script.
Localize         : Spécifie la langue de localisation.
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
#_pragma Console 0
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
PS C:\Users\steve02081504> '#_pragma Console no
>> 12' | ps12exe
Script prétraité -> 23 octets
Fichier compilé écrit -> 2 560 octets
```

Comme vous pouvez le voir, `#_pragma Console no` fait fonctionner le fichier exe généré en mode fenêtre, même si nous n'avons pas spécifié `-noConsole` lors de la compilation.  
La commande pragma peut définir tous les paramètres de compilation :

```powershell
#_pragma noConsole # Mode fenêtre
#_pragma Console # Mode console
#_pragma Console no # Mode fenêtre
#_pragma Console true # Mode console
#_pragma icon $PSScriptRoot/icon.ico # Définit l'icône
#_pragma title "title" # Définit le titre de l'exe
```

Les valeurs de pragma de type chaîne peuvent également contenir des sous-expressions `$(...)`, évaluées au moment du prétraitement, par ex. `#_pragma icon $(Join-Path $env:USERPROFILE 'foo.ico')`. Seules les commandes liées aux chemins figurant sur la liste blanche (`Get-Command`, `Join-Path`, `Split-Path`, `Resolve-Path`, `Convert-Path`, `Get-Item`, `Test-Path`, `Get-ChildItem`, plus `Get-Content` hors mode invité), les variables (`$env:*`, `$PSScriptRoot`, `$ScriptRoot`, `$HOME`, `$PWD`, `$PSCommandPath`) et les méthodes d’instance inoffensives courantes (par ex. `ToUpper`, `Trim`, `Split`, `ToString`) sont autorisées ; toute autre chose interrompt la compilation. Les valeurs entre guillemets simples restent entièrement littérales.

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <code_de_sortie>
#_balus
```

Lorsque le code est exécuté jusqu'à ce point, il quitte le processus avec le code de sortie donné et supprime le fichier exe.

### Minifier

Étant donné que la "compilation" de ps12exe incorpore tout le contenu du script en tant que ressource mot pour mot dans le fichier exécutable généré, si le script contient un grand nombre de chaînes de caractères inutiles, le fichier exécutable généré sera très volumineux.  
Vous pouvez utiliser le paramètre `-Minifyer` pour spécifier un bloc de script qui prétraitera le script avant la compilation afin d'obtenir un fichier exécutable généré plus petit.

Si vous ne savez pas comment écrire un tel bloc de script, vous pouvez utiliser [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### Liste des cmdlets non implémentées

Les commandes d'entrée/sortie de base de ps12exe doivent être réécrites en C#. Celles qui ne sont pas implémentées sont _`Write-Progress`_ en mode console (trop de travail) et _`Start-Transcript`_/_`Stop-Transcript`_ (Microsoft n'a pas d'implémentation de référence appropriée).

### Format de sortie du mode GUI

Par défaut, le format de sortie des petites commandes dans PowerShell est une ligne par ligne (en tant que tableaux de chaînes de caractères). Lorsqu'une commande génère 10 lignes de sortie et utilise la sortie GUI, il y aura 10 boîtes de message, chacune attendant d'être confirmée. Pour éviter que cela ne se produise, importez la commande `Out-String` dans la ligne de commande. Cela convertira la sortie en un tableau de chaînes de caractères de 10 lignes, et toutes les sorties seront affichées dans une seule boîte de message (par exemple : `dir C:\| Out-String`).

### Fichier de configuration

ps12exe peut créer des fichiers de configuration, avec le nom de fichier `fichier exécutable généré + ".config"`. Dans la plupart des cas, ces fichiers de configuration ne sont pas nécessaires, ils sont simplement un manifeste qui vous indique quelle version du .Net Framework doit être utilisée. Comme vous utiliserez généralement le .Net Framework réel, essayez d'exécuter votre fichier exécutable sans utiliser de fichier de configuration.

### Gestion des paramètres

Les scripts compilés gèrent les paramètres comme le script d'origine. Une des limitations provient de l'environnement Windows : pour tous les exécutables, tous les types de paramètres sont des chaînes de caractères, et si le type de paramètre n'est pas implicitement converti, il doit être explicitement converti dans le script. Vous pouvez même transmettre le contenu par canalisation à un fichier exécutable, mais avec les mêmes limitations (toutes les valeurs transmises par canalisation sont de type chaîne de caractères).

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

### Fenêtre d'arrière-plan en mode -noConsole

Lorsque vous ouvrez une fenêtre externe dans un script qui utilise le mode `-noConsole` (par exemple `Get-Credential` ou des commandes nécessitant `cmd.exe`), une fenêtre s'ouvrira en arrière-plan.

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

Pour les scripts uniquement constants et sans effet de bord, ps12exe les évalue à la compilation et intègre le résultat directement dans un exe minuscule (le chemin TinySharp, généralement autour de 1 Ko) ; il revient à la compilation normale lorsque l'évaluation dépasse le délai d'attente (7 secondes par défaut) ou que le résultat est trop long. Si l'environnement d'évaluation diffère de l'exécution, ou si vous voulez simplement l'hôte PowerShell complet, ajoutez l'un des pragmas ci-dessous pour refuser explicitement cette optimisation :

- `#_pragma noConstEval` : déclare que ce script n'est pas une constante ; ignore l'évaluation des constantes.
- `#_pragma constEvalTimeout` : déclare que cette évaluation de constante a déjà expiré ; applique le même repli qu'en cas de délai dépassé.

Les deux sont mis en correspondance par mot-clé dans le script à la compilation, donc ils peuvent figurer sur n'importe quelle ligne ; après le repli vers l'hôte normal, ces lignes ne sont que des commentaires ordinaires.

## Comparaison des avantages 🏆

### Comparaison rapide 🏁

| Comparaison                                             | ps12exe                                                                                                   | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                                |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Référentiel de script pur 📦                            | ✔️ Tous les fichiers sont des fichiers texte sauf les images et les DLL fournies                          | ❌ Fournit `Win-PS2EXE.exe` sous licence open source                                                          |
| Commande requise pour générer hello world 🌍            | 😎`'"Bonjour le monde !"' \| ps12exe`                                                                     | 🤔`echo "Bonjour le monde !" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                                |
| Exécutable hello world constant 💾                      | 🥰1 024 octets (évalué à la compilation)                                                                  | ❌ Non pris en charge ; 25 088 octets                                                                         |
| Exécutable hello world non constant 💾                  | 🥰14 848 octets                                                                                           | 😨25 088 octets                                                                                               |
| Évaluation constante à la compilation ⚡                | ✔️                                                                                                        | ❌                                                                                                            |
| Cible PowerShell Core (7+) / multiplateforme 🧬         | ✔️ `-targetRuntime Core` (Windows / Linux / macOS)                                                        | ❌ Windows PowerShell 5.1 uniquement                                                                          |
| Prise en charge multilingue de l'interface graphique 🌐 | ✔️ (7 langues, mode sombre)                                                                               | ❌                                                                                                            |
| Vérification de la syntaxe lors de la compilation ✔️    | ✔️                                                                                                        | ❌                                                                                                            |
| Fonction de prétraitement 🔄                            | ✔️                                                                                                        | ❌                                                                                                            |
| Analyse des paramètres spéciaux tels que `-extract` 🧹  | 🗑️ Supprimé (utilisez l'outil `exe21sp`)                                                                  | 🥲 Nécessite la modification du code source                                                                   |
| Degré d'accueil des PR 🤝                               | 🥰 Bienvenue !                                                                                            | 🤷 14 PR dont 13 fermées                                                                                      |
| Biais politique / DEI / idéologique 🕊️                  | ✔️ Aucun ; toute PR utile est bienvenue — d'un humain, d'une IA ou d'un singe devant une machine à écrire | ❌ Le README affiche une position anti-IA (« l'intelligence artificielle tue la créativité et notre nature ») |

Le développeur de ps12exe n'utilise pas ce projet pour promouvoir une position politique, DEI ou autre : toute PR utile est bienvenue, qu'elle vienne d'un humain, d'une IA ou d'un singe devant une machine à écrire.

### Taille et vitesse 🔬

Mesuré sous Windows 11 avec PowerShell 7.6.6 (.NET 10) et Windows PowerShell 5.1, 20 exécutions à chaud chacune. Le plancher de création de processus (`cmd /c exit`) est d'environ 15 ms. Reproduire avec `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore`.

| Build                                                  | Taille de sortie   | Démarrage à chaud  |
| ------------------------------------------------------ | ------------------ | ------------------ |
| Windows PowerShell 5.1 exécutant le script directement | —                  | ~245 ms            |
| ps12exe · constant · Framework4.0                      | 1 024 octets       | ~33 ms             |
| ps12exe · non constant · Framework4.0                  | 14 848 octets      | ~210 ms            |
| PS2EXE 1.0.18 · non constant                           | 25 088 octets      | ~223 ms            |
| ------------------------------------------------------ | ------------------ | ------------------ |
| pwsh 7 exécutant le script directement                 | —                  | ~450 ms            |
| ps12exe · constant · Core                              | ~169 Ko            | ~70 ms             |
| ps12exe · non constant · Core                          | ~185 Ko            | ~395 ms            |
| PS2EXE 1.0.18 · non constant · Core                    | non pris en charge | non pris en charge |

Un script constant est évalué à la compilation : son exe ne fait que 1 Ko et ne démarre jamais PowerShell — environ 24× plus petit et 6× plus rapide à lancer qu'un hello world PS2EXE. Les exe non constants sont ~40 % plus petits que ceux de PS2EXE, et pour les scripts utilisant massivement des variables de portée globale, ils s'exécutent aussi plus vite, car le script s'exécute dans une fonction (portée locale) plutôt qu'au niveau global.

Le compilateur lui-même est distribué sous forme de module PowerShell :

| Paquet du compilateur   | Décompressé | Compressé |
| ----------------------- | ----------- | --------- |
| ps12exe (master actuel) | ~1,29 Mo    | ~513 Ko   |
| PS2EXE 1.0.18           | ~171 Ko     | ~46 Ko    |

Le module ps12exe est plus volumineux car c'est un compilateur en pur script sans dépendance qui embarque des binaires [AsmResolver](https://github.com/Washi1337/AsmResolver) allégés (utilisés pour produire les exe constants de 1 Ko et décompresser les charges utiles), 7 localisations et une interface graphique en pur script ; PS2EXE ne fournit presque rien et s'appuie sur le compilateur .NET Framework intégré à Windows.

### Comportement d'exécution des EXE compilés 🖥️

Vérifié dans une véritable fenêtre de console sous Windows 11 : les processus enfants natifs lancés par l'EXE voient-ils une vraie TTY de console ([#59](https://github.com/steve02081504/ps12exe/issues/59)), le script peut-il lire le stdin brut ([#62](https://github.com/steve02081504/ps12exe/issues/62)), et les variables de chemin spéciales se résolvent-elles ?

| Capacité                                         | ps12exe                                 | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------------------ | --------------------------------------- | ------------------------------------------------------------------------------ |
| Le processus enfant natif voit une TTY (`isTTY`) | ✔️                                      | ❌                                                                             |
| stdin brut (`[Console]::In`) lisible             | ✔️ (sauf si le script utilise `$input`) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` se résolvent  | ✔️ (chemin / dossier de l'exe)          | ❌                                                                             |

PS2EXE 1.0.18 fait toujours passer la sortie du script par `Out-String` et draine entièrement le stdin redirigé avant d'exécuter le script : les processus enfants natifs perdent le handle de console et le stdin atteint EOF. ps12exe écrit via l'hôte (`Out-Default`) et ne draine le stdin que si le script utilise réellement `$input`. De plus, PS2EXE laisse `$PSCommandPath`/`$PSScriptRoot` vides dans le programme compilé (il fournit son propre `$ScriptRoot`), tandis que ps12exe mappe les deux vers l'exe généré.

### Comparaison détaillée 🔍

Par rapport à [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615), ce projet apporte les améliorations suivantes :

| Amélioration                                                                                 | Description                                                                                                                                                |
| -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ✔️ Vérification de la syntaxe lors de la compilation                                         | Effectue la vérification de la syntaxe lors de la compilation pour améliorer la qualité du code                                                            |
| ⚡ Évaluation constante à la compilation                                                     | Les scripts sans effet de bord sont évalués à la compilation et générés sous forme d'exe d'environ 1 Ko                                                    |
| 🧬 Cible PowerShell Core / multiplateforme                                                   | `-targetRuntime Core` cible PowerShell 7+ sous Windows, Linux et macOS                                                                                     |
| 🔄 Puissantes fonctions de prétraitement                                                     | Prétraite les scripts avant la compilation, plus besoin de copier-coller tout le contenu dans le script                                                    |
| 🛠️ Paramètre `-CompilerOptions`                                                              | Ajout d'un nouveau paramètre qui vous permet de personnaliser davantage le fichier exécutable généré                                                       |
| 📦️ Paramètre `-Minifyer`                                                                     | Prétraite les scripts avant la compilation afin de générer des fichiers exécutables plus petits                                                            |
| 🌐 Prise en charge de la compilation de scripts et de l'inclusion de fichiers depuis des URL | Prise en charge du téléchargement d'icônes depuis une URL                                                                                                  |
| 🖥️ Optimisation du paramètre `-noConsole`                                                    | Optimisation du traitement des options et de l'affichage du titre de la fenêtre, vous pouvez maintenant définir le titre des fenêtres popup personnalisées |
| ✍️ Signature de code et conversion automatique des icônes                                    | Signez la sortie avec un certificat PFX ou une empreinte du magasin, et convertissez les icônes automatiquement                                            |
| 🧰 Outils supplémentaires : `exe21sp`, serveur web, menu contextuel, mode interactif         | Décompiler des exe, compiler en ligne, compiler par clic droit, et plus encore                                                                             |
| 🧹 Suppression du fichier exe                                                                | Suppression des fichiers exe du référentiel de code                                                                                                        |
| 🌍 Prise en charge multilingue, interface graphique en pur script                            | Meilleure prise en charge multilingue, interface graphique en pur script, prise en charge du mode sombre                                                   |
| 📖 Séparation du fichier cs du fichier ps1                                                   | Plus facile à lire et à entretenir                                                                                                                         |
| 🚀 Plus d'améliorations                                                                      | Et bien plus encore...                                                                                                                                     |

## Points de vue au fil du temps ⭐

[![Points de vue au fil du temps](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
