# ps12exe

> [!CAUTION]
> ¡No almacene contraseñas en el código fuente!  
> Consulte [aquí](#seguridad-de-contraseñas) para obtener más detalles.

## Introducción

ps12exe es un módulo de PowerShell que permite crear ejecutables a partir de scripts .ps1.

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
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## Utilizado por

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## Instalación

```powershell
Install-Module ps12exe # Instala el módulo ps12exe
Set-ps12exeContextMenu # Configura el menú contextual
```

(También puede clonar el repositorio y ejecutar `.\ps12exe.ps1`)

**¿Le cuesta pasar de PS2EXE a ps12exe? No hay problema.**  
PS2EXE2ps12exe redirige las llamadas de PS2EXE a ps12exe. Desinstale PS2EXE, instale este módulo y siga usando PS2EXE como siempre.  
Busca la máxima compatibilidad con todas las versiones de PS2EXE (incluidos `conHost`, `embedFiles` y los antiguos `runtime20`/`runtime40`); las capacidades que ps12exe no tiene se reescriben en tiempo de compilación.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Cómo usar

### Menú contextual

Una vez configurado `Set-ps12exeContextMenu`, puede compilar rápidamente cualquier archivo `.ps1` a exe o abrir ps12exeGUI con clic derecho sobre el archivo.  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### Modo GUI

```powershell
ps12exeGUI
```

### Modo Consola

```powershell
ps12exe .\source.ps1 .\target.exe
```

Compila `source.ps1` en `target.exe` (si omite `.\target.exe`, la salida se escribirá en `.\source.exe`).

```powershell
'"¡Hola Mundo!"' | ps12exe
```

Compila `"¡Hola Mundo!"` en un archivo ejecutable para ser enviado a `.\a.exe`.

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

Compila `Main.ps1` desde Internet en un archivo ejecutable para su salida en `.\Main.exe`.

### Servicio web autoalojado

```powershell
Start-ps12exeWebServer
```

Inicia un servicio web que permite compilar código PowerShell en línea.

### Recuperar ps1 desde un exe (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` extrae el script de PowerShell incrustado en un exe generado por ps12exe y lo guarda como archivo `.ps1` o lo escribe en la salida estándar. Usa la misma convención `$LastExitCode` que ps12exe: 0 = éxito, 1 = error de entrada/análisis (p. ej. exe no generado por ps12exe), 2 = error de invocación (p. ej. sin entrada al redirigir), 3 = error de recurso/interno (p. ej. archivo no encontrado).

### Pipeline y redirección

- **ps12exe**: cuando la salida estándar (o la entrada o el error estándar) está redirigida, ps12exe escribe solo la ruta del exe generado en la salida estándar para poder capturarla (ej. `$exe = ps12exe .\a.ps1`).
- **exe21sp**: acepta rutas o URL de exe por la canalización (p. ej. `Get-ChildItem *.exe | exe21sp` o `".\app.exe" | exe21sp`).
- **exe21sp**: si no se especifica `-outputFile` y la salida estándar **no** está redirigida, el script descompilado se guarda en un `.ps1` con el mismo nombre base que el exe en el mismo directorio.
- **exe21sp**: si no se especifica `-outputFile` y la salida estándar **sí** está redirigida, el script descompilado se escribe en la salida estándar.

### Extensión de VS Code

La [extensión de ps12exe para VS Code](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe) compila un script `.ps1` en un ejecutable —o abre ps12exeGUI— sin salir del editor, y añade soporte de edición para las directivas de preprocesamiento (resaltado de sintaxis, diagnósticos, cierre automático de `#_if`, plegado, ir a la definición, información emergente, autocompletado y formato).

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeContextMenu` la instala automáticamente; también puedes instalar `steve02081504.ps12exe` manualmente.

## Parámetros

### Parámetros GUI

```powershell
ps12exeGUI [[-ConfigFile] '<archivo de configuración>'] [-PS1File '<archivo de código>'] [-Locale '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<archivo de código>'] [-Locale '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : El archivo de configuración que desea cargar.
PS1File    : El archivo de script a compilar.
Locale     : El código de idioma que desea usar.
UIMode     : El modo de interfaz de usuario que desea usar.
help       : Mostrar esta información de ayuda.
```

### Parámetros de la consola

```powershell
[input |] ps12exe [[-inputFile] '<nombre de archivo|url>' | -Content '<script>'] [-outputFile '<nombre de archivo>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true;
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'; Apartment='STA'|'MTA';
        Culture='<cultura>'; Options='<opciones>'; KeepSource=$true; Minify={<scriptblock>}; TempDir='<carpeta>'}]
        [-Resources @{Icon='<nombre de archivo|url>'; Title='<título>'; Description='<descripción>'; Company='<compañía>';
        Product='<producto>'; Copyright='<derechos de autor>'; Trademark='<marca>'; Version='<versión>'}]
        [-Signing @{Certificate='<ruta del archivo PFX>'; Password='<contraseña PFX>'; Thumbprint='<huella digital del certificado>'; Timestamp='<servidor de marca de tiempo>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Locale '<código de idioma>'] [-ConfigFile] [-help]
```

```text
input            : La cadena del contenido del archivo de script de PowerShell, igual que -Content.
inputFile        : La ruta o URL del archivo de script de PowerShell que desea convertir en un archivo ejecutable (el archivo debe estar codificado en UTF8 o UTF16)
Content          : El contenido del script de PowerShell que desea convertir en un archivo ejecutable
outputFile       : El nombre del archivo o carpeta de destino, por defecto es el inputFile con la extensión '.exe'
App              : Una tabla hash que describe el comportamiento de la aplicación producida. Claves admitidas:
                   Windowed         : El archivo ejecutable generado será una aplicación de Windows Forms sin ventana de consola.
                   Silence          : Nombres de flujos a silenciar; uno o varios de 'Output', 'Verbose', 'Error', 'Warning', 'Debug', o '*' para todos.
                   OutputEncoding   : Codificación de salida de la consola; 'Default', 'UTF8' o 'UTF16LE'.
                   VisualStyles     : Habilitar los estilos visuales para las aplicaciones GUI (por defecto $true).
                   ExitOnCancel     : Salir del programa cuando se elija Cancelar o 'X' en el cuadro de entrada de Read-Host.
                   CredentialGUI    : Usar una GUI para solicitar credenciales en el modo de consola.
                   DpiAware         : Marcar el archivo ejecutable compilado como DPI aware.
                   WinFormsDpiAware : Permitir que WinForms use el escalado DPI (requiere Windows 10 y .Net 4.7 o superior).
Os               : Una tabla hash de opciones de integración con el sistema operativo. Claves admitidas:
                   Admin            : Si se habilita el UAC, el archivo ejecutable compilado sólo se podrá ejecutar en un contexto elevado (si es necesario, aparecerá el cuadro de diálogo del UAC).
                   ModernOS         : Usar las características de las últimas versiones de Windows (ejecutar [Environment]::OSVersion para ver las diferencias).
                   LongPaths        : Habilitar las rutas largas (> 260 caracteres) si están habilitadas en el sistema operativo (sólo para Windows 10 o superior).
                   Virtualize       : Se ha activado la virtualización de aplicaciones (se fuerza el tiempo de ejecución x86).
Build            : Una tabla hash de opciones de compilación/cadena de herramientas. Claves admitidas:
                   Target           : Versión de tiempo de ejecución de destino, 'Framework4.0' por defecto; se admiten 'Framework2.0' y 'Core'. 'Core' genera un ejecutable de PowerShell Core (.NET) (requiere PowerShell Core y .NET en las máquinas de compilación y de destino; el resultado es mucho mayor).
                   Platform         : Compilar sólo para un tiempo de ejecución específico. Los valores posibles son 'AnyCpu', 'x64' y 'x86'.
                   Apartment        : Modo 'apartamento de un solo hilo' o 'apartamento de varios hilos'.
                   Culture          : Referencia cultural del archivo ejecutable compilado. Si no se especifica, será la cultura del usuario actual.
                   Options          : Opciones adicionales del compilador (ver https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
                   KeepSource       : Crear información que ayude a la depuración.
                   Minify           : Bloque de script que reduce el tamaño del script antes de la compilación.
                   TempDir          : El directorio donde se almacenan los archivos temporales (por defecto es un directorio temporal generado aleatoriamente en %temp%).
Resources        : Una tabla hash de recursos de versión incrustados en el ejecutable (Icon, Title, Description, Company, Product, Copyright, Trademark, Version). Icon puede ser una ruta de archivo o URL. En .exe/.dll, añada ,<índice> para elegir un icono de recurso (por defecto 0), p. ej. shell32.dll,3.
Signing          : Una tabla hash de opciones de firma de código (Certificate, Password, Thumbprint, Timestamp). Se debe especificar Certificate o Thumbprint.
PreprocessOnly   : Preprocesa el script de entrada y devuélvelo sin compilar.
Golf             : Activar el modo golf, agregando abreviaturas y funciones comunes.
Sandbox          : Compilación de scripts con protección adicional frente al acceso a archivos nativos.
NoUpdateCheck    : Omitir la comprobación de nuevas versiones de ps12exe.
Locale           : El código de idioma que desea usar.
ConfigFile       : Escribir un archivo de configuración (<outputfile>.exe.config).
Help             : Mostrar esta información de ayuda.
```

## Observaciones

### Manejo de Errores

A diferencia de la mayoría de las funciones de PowerShell, ps12exe establece la variable `$LastExitCode` para indicar errores, pero no garantiza que no se produzcan excepciones en absoluto.  
Puedes comprobar si se ha producido un error utilizando algo similar a lo siguiente:

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe falló con el código de salida $LastExitCode"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

Los diferentes valores de `$LastExitCode` representan diferentes tipos de errores:

| Tipo de Error | Valor de `$LastExitCode`       |
| ------------- | ------------------------------ |
| 0             | Sin error                      |
| 1             | Error en el código de entrada  |
| 2             | Error en el formato de llamada |
| 3             | Error interno de ps12exe       |

### Preprocesamiento

<a id="preprocessing-overview"></a>

ps12exe preprocesa el script antes de compilarlo.

```powershell
# Lee el marco del programa desde el archivo ps12exe.cs
#_if PSEXE # Este es el código de preprocesamiento usado cuando el script es compilado por ps12exe.
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #Insertar el contenido de ps12exe.cs en este script.
#_else #De lo contrario, lea el archivo cs normalmente
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

Ahora sólo se soportan las siguientes condiciones: `PSEXE` y `PSScript`.  
`PSEXE` es verdadero; `PSScript` es falso.

#### `#_include <nombre_archivo|url>`/`#_include_as_value <valuename> <archivo|url>`

<a id="preprocessing-include"></a>

```powershell
#_include <nombre_archivo|url>
#_include_as_value <nombre_valor> <archivo|url>
```

Incluye el contenido del archivo `<nombre_archivo|url>` o `<archivo|url>` en el script. El contenido del archivo se inserta en la ubicación del comando `#_include`/`#_include_as_value`.

A diferencia de la sentencia `#_if`, si no encierra el nombre del archivo entre comillas, la familia de comandos de preprocesamiento `#_include` trata el espacio final, `#`, como parte del nombre del archivo.

```powershell
#_include $PSScriptRoot/super #nombrearchivoextraño.ps1
#_include "$PSScriptRoot/filename.ps1" #¡comentario seguro!
```

Cuando se utiliza `#_include`, el contenido del fichero se preprocesa, lo que permite incluir ficheros a varios niveles.

`#_include_as_value` inserta el contenido del archivo en el script como un valor de cadena. El contenido del archivo no se preprocesa.

En la mayoría de los casos no necesita usar los comandos de preprocesamiento `#_if` y `#_include` para hacer que los scripts incluyan correctamente los sub-scripts después de la conversión a exe. ps12exe maneja automáticamente casos como los siguientes y asume que el script destino debe ser incluido:

```powershell
. $PSScriptRoot/otro.ps1
& $PSScriptRoot/otro.ps1
$resultado = & "$PSScriptRoot/otro.ps1" -args
```

#### `#_include_as_(base64|bytes) <valuename> <file|url>`

<a id="preprocessing-include-as"></a>

```powershell
#_include_as_base64 <valuename> <file|url>
#_include_as_bytes <valuename> <file|url>
```

Incluye el contenido de un archivo como una cadena base64 o una matriz de bytes en el script en el momento del preprocesamiento. El contenido del archivo en sí no se preprocesa.

Aquí hay un ejemplo simple de empaquetador:

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

Este EXE, al ejecutarse, extraerá el archivo `data.bin` incrustado en el script durante la compilación.

#### `#_!!`

<a id="preprocessing-bang"></a>

```powershell
$Script:eshDir =
#_if PSScript #No es posible tener $EshellUI en PSEXE
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

Cualquier línea que empiece por `#_!!` al principio de una línea con `#_!!` será eliminada.

#### `#_require <modulesList>`

<a id="preprocessing-require"></a>

```powershell
#_require ps12exe
#_pragma App.Windowed
$Número = [bigint]::Parse('0')
$NúmeroSiguiente = $Número+1
$NextScript = $PSEXEscript.Replace("Parse('$Número')", "Parse('$NúmeroSiguiente')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
$Número
```

`#_require` Cuenta los módulos necesarios a lo largo del script y añade el equivalente en script del siguiente código antes del primer `#_require`:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

Vale la pena señalar que el código que genera sólo instalará módulos, no los importará.
Por favor, utilice `Import-Module` cuando sea apropiado.

Cuando necesites requerir más de un módulo, puedes usar espacios, comas, o punto y coma como separadores en lugar de escribir sentencias require de varias líneas.

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

<a id="preprocessing-pragma"></a>

La directiva de preprocesamiento pragma no tiene efecto sobre el contenido del script, pero modifica los parámetros utilizados para la compilación.  
He aquí un ejemplo:

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

Como puede ver, `#_pragma App.Windowed` hace que el archivo exe generado se ejecute en modo ventana, incluso si no especificamos `-App @{Windowed=$true}` en tiempo de compilación.
El comando pragma puede establecer cualquier parámetro de compilación; usa `.` en el nombre para establecer valores anidados:

```powershell
#_pragma App.Windowed #Modo ventana
#_pragma App.Windowed $false #Modo consola
#_pragma Resources.Icon $PSScriptRoot/icon.ico #Configurar icono
#_pragma Resources.Title "title" #Establecer título del exe
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" #Establecer el certificado de firma de código
```

Los valores de pragma de tipo cadena también pueden contener subexpresiones `$(...)`, que se evalúan en tiempo de preprocesamiento, p. ej. `#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`. Solo se permiten comandos relacionados con rutas en la lista blanca (`Get-Command`, `Join-Path`, `Split-Path`, `Resolve-Path`, `Convert-Path`, `Get-Item`, `Test-Path`, `Get-ChildItem`, más `Get-Content` fuera de Sandbox), variables (`$env:*` (dentro de Sandbox solo `$env:windir`/`$env:SystemRoot`), `$PSScriptRoot`, `$ScriptRoot`, `$HOME`, `$PWD`, `$PSCommandPath`) y métodos de instancia inofensivos comunes (p. ej. `ToUpper`, `Trim`, `Split`, `ToString`); cualquier otra cosa aborta la compilación. Los valores entre comillas simples permanecen completamente literales. El modo Sandbox también ignora `#_pragma outputFile`, `Build.TempDir`, `Build.Minify` y `Signing.Certificate`, y solo descarga URL http(s) que resuelven a direcciones públicas (los destinos de redirección se restringen igual). Las rutas locales de `Resources.Icon` solo se permiten bajo el directorio de Windows.

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <exitcode>
#_balus
```

Cuando el código llega a este punto, el proceso sale con el código de salida dado y elimina el archivo EXE.

### Minificación

Dado que la "compilación" de ps12exe incrusta todo en el script textualmente como un recurso en el ejecutable resultante, si el script tiene muchas cadenas inútiles, el ejecutable resultante será muy grande.  
Puede utilizar la clave `Minify` de `-Build` para especificar un bloque de script que preprocesará el script antes de la compilación para obtener un ejecutable generado más pequeño.

Si no sabe cómo escribir un bloque de script de este tipo, puede utilizar [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | & ./psminnifyer.ps1 }}
```

### Lista de cmdlets no implementados

Los comandos básicos de entrada/salida de ps12exe deben ser reescritos en C#. Los no implementados son _`Write-Progress`_ en modo consola (demasiado trabajo) y _`Start-Transcript`_/_`Stop-Transcript`_ (Microsoft no tiene una implementación de referencia adecuada).

### Formato de salida en modo GUI

Por defecto, el formato de salida para comandos pequeños en powershell es una línea por línea (como un array de cadenas). Cuando un comando genera 10 líneas de salida y se le da salida usando la GUI, aparecen 10 cajas de mensajes, cada una esperando ser determinada. Para evitar esto, importe el comando `Out-String` a la línea de comandos. Esto convertirá la salida en una matriz de cadenas de 10 líneas, todas las cuales se mostrarán en un cuadro de mensaje (por ejemplo, `dir C:\ | Out-String`).

### Ficheros de configuración

ps12exe puede crear ficheros de configuración con el nombre `ejecutable generado + ".config"`. En la mayoría de los casos, estos ficheros de configuración no son necesarios, son sólo una lista de qué versión de .Net Framework debe utilizar. Dado que normalmente utilizará el .Net Framework actual, intente ejecutar su ejecutable sin los archivos de configuración.

### Manejo de parámetros

El script compilado manejará los parámetros igual que el script original. Una limitación proviene del entorno Windows: para todos los ejecutables, los argumentos de línea de comandos son en última instancia cadenas.

Cuando el script tiene un bloque `param()` de nivel superior, ps12exe analiza los valores de los argumentos como datos de PowerShell (PSD): las tablas hash `@{}`, las tablas hash ordenadas `[ordered]@{}`, los arreglos `@()` y las conversiones a tipos seguros como `[int]'5'` o `[hashtable]@{}` se pasan al parámetro como el objeto correspondiente, sin necesidad de conversión manual:

```powershell
# script: param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

El valor debe ir entre comillas: los shells convierten a cadena un `@{...}` sin comillas (el programa solo recibe el texto `System.Collections.Hashtable`). Todo lo que no sean datos (una expresión o un comando) se pasa como cadena normal y nunca se evalúa, así que `-Config "@{x=(Get-Date)}"` no ejecuta código: simplemente falla al enlazar.

Los valores canalizados por tubería siguen siendo cadenas.

### Seguridad de contraseñas

<a id="password-security-stuff"></a>
Nunca almacene contraseñas en scripts compilados.  
Todo el script es fácilmente visible para cualquier descompilador .net.  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguir entornos por script

Puedes saber si un script se está ejecutando en un exe compilado o en un script por `$Host.Name`.

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Algún otro host" }
```

### Variables del script

Dado que ps12exe convierte los scripts en ejecutables, el valor de la variable `$MyInvocation` es diferente del valor en el script.

Todavía puede usar `$PSScriptRoot` para obtener la ruta al directorio donde se encuentra el ejecutable, y `$PSCommandPath` para obtener la ruta al ejecutable en sí.

### Ventanas de fondo en modo `App.Windowed`

Cuando se abre una ventana externa en un script que utiliza el modo `App.Windowed` (por ejemplo `Get-Credential` o un comando que requiere `cmd.exe`), se abrirá una ventana en segundo plano.

La razón de esto es que cuando se cierra una ventana externa, windows intenta activar la ventana padre. Dado que los scripts compilados no tienen ventanas, esto activa la ventana padre del script compilado, que suele ser una ventana de Explorer o Powershell.

Para evitar esto, puede utilizar `$Host.UI.RawUI.FlushInputBuffer()` para abrir una ventana invisible que pueda ser activada. La siguiente llamada a `$Host.UI.RawUI.FlushInputBuffer()` cerrará esta ventana (y así sucesivamente).

El siguiente ejemplo ya no abrirá la ventana en segundo plano, a diferencia de llamar a `ipconfig | Out-String` sólo una vez:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### Entrada estándar y `$input`

Un exe compilado solo lee la entrada estándar redirigida (línea por línea, como entrada de canalización) cuando el script usa `$input` en su **nivel superior**:

- Si se usa `$input`: se comporta como PS2EXE — stdin se consume como entrada de canalización, por lo que la stdin sin procesar (`[Console]::In` / `Console.OpenStandardInput()`) alcanza EOF después.
- Si no se usa `$input`: no se lee stdin en absoluto; la entrada estándar sin procesar se deja intacta y el inicio no espera a stdin (un proceso padre que mantiene la tubería abierta ya no lo bloquea), y los procesos hijos todavía pueden heredar stdin.

Solo cuenta el nivel superior del script: un `$input` dentro de funciones, bloques de script o clases es la entrada de canalización de ese ámbito y se ignora.

Por ejemplo, si el script llama a `[Console]::In.ReadToEnd()` y nunca usa `$input`, tras compilar, `echo hi | .\tool.exe` recibe `hi`.

### Evaluación de constantes

Para scripts que solo contienen constantes y no tienen efectos secundarios, ps12exe los evalúa en tiempo de compilación e integra el resultado directamente en un exe diminuto (la ruta TinySharp, normalmente alrededor de 1 KB); vuelve a la compilación normal cuando la evaluación agota el tiempo de espera (7 segundos por defecto) o el resultado es demasiado largo. Si el entorno de evaluación difiere del de ejecución, o simplemente quiere el host completo de PowerShell, añada cualquiera de los siguientes pragmas para renunciar explícitamente a esa optimización:

- `#_pragma Build.ConstEval.Enabled 0`: declara que este script no es una constante; omite la evaluación de constantes.
- `#_pragma Build.ConstEval.Timeout 1`: declara que esta evaluación de constantes ya agotó el tiempo; aplica el mismo retroceso que en caso de tiempo de espera.

Ambos se analizan como pragmas anidados normales durante el preprocesamiento, por lo que pueden ir en cualquier línea; tras el retroceso al host normal, esas líneas son solo comentarios normales.

## Comparación de Ventajas 🏆

### Comparación Rápida 🏁

| Aspecto                                              | ps12exe                                                                                                          | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                                          |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Repositorio de solo scripts 📦                       | ✔️ Solo archivos de texto, excepto imágenes y DLL auxiliares                                                     | ❌ Incluye `Win-PS2EXE.exe` con licencia de código abierto                                                              |
| Comando para generar "Hello World" 🌍                | 😎`'"Hello World!"' \| ps12exe`                                                                                  | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                                                |
| Ejecutable "Hello World" constante 💾                | 🥰1024 bytes (evaluado en tiempo de compilación)                                                                 | ❌ No compatible; 25088 bytes                                                                                           |
| Ejecutable "Hello World" no constante 💾             | 🥰14848 bytes                                                                                                    | 😨25088 bytes                                                                                                           |
| Evaluación constante en tiempo de compilación ⚡     | ✔️                                                                                                               | ❌                                                                                                                      |
| Destino PowerShell Core (7+) / multiplataforma 🧬    | ✔️ `Build.Target Core` (Windows / Linux / macOS)                                                                 | ❌ Solo Windows PowerShell 5.1                                                                                          |
| Soporte multilingüe en la GUI 🌐                     | ✔️ (7 idiomas, modo oscuro)                                                                                      | ❌                                                                                                                      |
| Verificación de sintaxis en tiempo de compilación ✔️ | ✔️                                                                                                               | ❌                                                                                                                      |
| Función de preprocesamiento 🔄                       | ✔️                                                                                                               | ❌                                                                                                                      |
| `-extract` y otros parámetros especiales 🧹          | 🗑️ Eliminado (usa la herramienta `exe21sp`)                                                                      | 🥲 Requiere modificación del código fuente                                                                              |
| PR welcome level 🤝                                  | 🥰 ¡Bienvenido!                                                                                                  | 🤷 14 PRs, 13 de los cuales fueron cerrados                                                                             |
| Sesgo político / DEI / ideológico 🕊️                 | ✔️ Ninguno; cualquier PR valiosa es bienvenida — de un humano, una IA o un mono frente a una máquina de escribir | ❌ El README adopta una postura anti-IA («la inteligencia artificial está matando la creatividad y nuestra naturaleza») |

El desarrollador de ps12exe no usa este proyecto para promover una postura política, DEI o de otro tipo: cualquier PR valiosa es bienvenida, venga de un humano, una IA o un mono frente a una máquina de escribir.

### Tamaño y Velocidad 🔬

Medido en Windows 11 con PowerShell 7.6.6 (.NET 10) y Windows PowerShell 5.1, 20 ejecuciones en caliente cada uno. El mínimo de creación de procesos (`cmd /c exit`) es de ~15 ms. Reproducir con `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` (añade `-Compile` para la tabla de velocidad de compilación de abajo).

| Compilación                                              | Tamaño de salida | Arranque en caliente |
| -------------------------------------------------------- | ---------------- | -------------------- |
| Windows PowerShell 5.1 ejecutando el script directamente | —                | ~330 ms              |
| ps12exe · constante · Framework4.0                       | 1024 bytes       | ~43 ms               |
| ps12exe · no constante · Framework4.0                    | 14848 bytes      | ~254 ms              |
| PS2EXE 1.0.18 · no constante                             | 25088 bytes      | ~223 ms              |
| -------------------------------------------------------- | ---------------- | -------------------- |
| pwsh 7 ejecutando el script directamente                 | —                | ~640 ms              |
| ps12exe · constante · Core                               | ~165 KB          | ~80 ms               |
| ps12exe · no constante · Core                            | ~181 KB          | ~500 ms              |
| PS2EXE 1.0.18 · no constante · Core                      | no compatible    | no compatible        |

Un script constante se evalúa en tiempo de compilación, por lo que su exe pesa 1 KB y nunca inicia PowerShell: es unas 24× más pequeño y 6× más rápido de lanzar que un hello world de PS2EXE. Los exe no constantes son ~40 % más pequeños que los de PS2EXE y, para scripts con muchas variables de ámbito global, también se ejecutan más rápido, porque el script se ejecuta dentro de una función (ámbito local) en lugar del ámbito global.

### Velocidad de compilación ⏱️

Medido con la misma herramienta (`-Compile -IncludeCore`). Cada muestra es un proceso anfitrión nuevo (Windows PowerShell 5.1 para Framework/PS2EXE, pwsh 7 para Core); «en caliente» es la mediana de 5 compilaciones después de la primera. Los datos de PS2EXE usan la versión instalada localmente (1.0.13 en este entorno).

| Compilación                           | Compilación en caliente |
| ------------------------------------- | ----------------------- |
| ps12exe · constante · Framework4.0    | ~2,6 s                  |
| ps12exe · no constante · Framework4.0 | ~1,4 s                  |
| PS2EXE · no constante                 | ~1,0 s                  |
| ------------------------------------- | ----------------------- |
| ps12exe · constante · Core            | ~4,3 s                  |
| ps12exe · no constante · Core         | ~3,8 s                  |
| PS2EXE · no constante · Core          | no compatible           |

PS2EXE compila un hello world más rápido porque no es más que una fina envoltura del compilador de .NET Framework integrado en Windows: realiza una sola pasada de CodeDom y nada más. ps12exe además ejecuta una comprobación de sintaxis, clasifica el script y (para scripts constantes) lo evalúa, y empaqueta el marco del programa como carga útil dentro de un lanzador, por lo que su compilación no constante es ~1,4× la de PS2EXE. La contrapartida se ve en la salida: ps12exe genera 1024 / 14848 bytes donde PS2EXE genera 25088, y los programas constantes se lanzan unas 6× más rápido. La compilación Core está dominada por `dotnet publish`; la primera compilación de una configuración también restaura los paquetes NuGet, tras lo cual ps12exe reutiliza el directorio de proyecto generado y ejecuta `dotnet publish --no-restore`.

El compilador en sí se distribuye como módulo de PowerShell:

| Paquete del compilador  | Descomprimido | Comprimido |
| ----------------------- | ------------- | ---------- |
| ps12exe (master actual) | ~1,86 MB      | ~765 KB    |
| PS2EXE 1.0.18           | ~171 KB       | ~46 KB     |

El módulo de ps12exe es más grande porque es un compilador de script puro y sin dependencias que incluye binarios [AsmResolver](https://github.com/Washi1337/AsmResolver) recortados (usados para emitir los exe constantes de 1 KB y desempaquetar las cargas), 7 localizaciones y una GUI de script puro; PS2EXE casi no incluye nada y se apoya en el compilador de .NET Framework integrado en Windows.

### Comportamiento en tiempo de ejecución de los EXE compilados 🖥️

Verificado en una ventana de consola real de Windows 11: si los procesos hijos nativos lanzados por el EXE ven una TTY de consola real ([#59](https://github.com/steve02081504/ps12exe/issues/59)), si el script puede leer stdin sin procesar ([#62](https://github.com/steve02081504/ps12exe/issues/62)) y si las variables de ruta especiales se resuelven:

| Capacidad                                                                  | ps12exe                              | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| -------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------ |
| El proceso hijo nativo ve una TTY (`isTTY`)                                | ✔️                                   | ❌                                                                             |
| stdin sin procesar (`[Console]::In`) legible                               | ✔️ (salvo si el script usa `$input`) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` se resuelven                            | ✔️ (ruta / carpeta del exe)          | ❌                                                                             |
| Argumentos de línea de comandos analizados como datos PSD (tablas/objetos) | ✔️ (`-Config "@{...}"`)              | ❌ (solo cadenas)                                                              |

PS2EXE 1.0.18 siempre hace pasar la salida del script por `Out-String` y drena por completo el stdin redirigido antes de ejecutar el script, así que los procesos hijos nativos pierden el handle de consola y el stdin llega a EOF; ps12exe escribe a través del host (`Out-Default`) y solo drena stdin cuando el script usa realmente `$input`. Además, PS2EXE deja `$PSCommandPath`/`$PSScriptRoot` vacías dentro del programa compilado (ofrece su propio `$ScriptRoot`), mientras que ps12exe asigna ambas a la ruta del exe generado.

### Comparación Compleja 🔍

En comparación con [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615), este proyecto presenta las siguientes mejoras:

| Mejoras                                                               | Descripción                                                                                                                            |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| ✔️ Verificación de sintaxis en tiempo de compilación                  | Realiza una verificación de sintaxis durante la compilación para mejorar la calidad del código                                         |
| ⚡ Evaluación constante en tiempo de compilación                      | Los scripts sin efectos secundarios se evalúan en la compilación y se emiten como exe de ~1 KB                                         |
| 🧬 Destino PowerShell Core / multiplataforma                          | `Build.Target Core` apunta a PowerShell 7+ en Windows, Linux y macOS                                                                   |
| 🔄 Potente función de preprocesamiento                                | Realiza un preprocesamiento del script antes de la compilación, evitando la necesidad de copiar y pegar todo el contenido en el script |
| 🛠️ Parámetro `Build.Options`                                          | Permite una mayor personalización del archivo ejecutable generado                                                                      |
| 📦️ Parámetro `Build.Minify`                                           | Realiza un preprocesamiento antes de la compilación para generar un archivo ejecutable más pequeño                                     |
| 🌐 Soporte para compilar scripts y archivos de inclusión desde URL    | Admite la descarga de iconos desde una URL                                                                                             |
| 🖥️ Optimización del parámetro `App.Windowed`                          | Mejora el manejo de opciones y la visualización del título de la ventana emergente personalizada                                       |
| ✍️ Firma de código y conversión automática de iconos                  | Firma la salida con un certificado PFX o una huella del almacén, y convierte iconos automáticamente                                    |
| 🧰 Extras: `exe21sp`, servidor web, menú contextual, modo interactivo | Descompilar exe, compilar en línea, compilar con clic derecho y más                                                                    |
| 🧹 Eliminación del archivo exe                                        | Se eliminó el archivo exe del repositorio de código                                                                                    |
| 🌍 Soporte multilingüe y GUI de solo script                           | Mejora el soporte multilingüe y la GUI de solo script, incluyendo el modo oscuro                                                       |
| 📖 Separación de archivos cs de archivos ps1                          | Facilita la lectura y el mantenimiento                                                                                                 |
| 🚀 Otras mejoras                                                      | ¡Y muchas más!                                                                                                                         |

## Puntos de estrellas a lo largo del tiempo ⭐

[![Puntos de estrellas a lo largo del tiempo](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
