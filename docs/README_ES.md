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
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## Instalación

```powershell
Install-Module ps12exe ## Instala el módulo ps12exe
Set-ps12exeContextMenu ## Configura el menú contextual
```

(También puede clonar el repositorio y ejecutar `.\ps12exe.ps1`)

**¿Difícil de actualizar desde PS2EXE a ps12exe? ¡No hay problema!**  
PS2EXE2ps12exe puede enganchar las llamadas de PS2EXE en ps12exe. Todo lo que necesitas hacer es desinstalar PS2EXE e instalar esto, luego usar PS2EXE como de costumbre.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Cómo usar

### Menú contextual

Una vez que haya configurado `Set-ps12exeContextMenu`, puede compilar rápidamente cualquier archivo ps1 a un exe o abrir ps12exeGUI haciendo click derecho sobre él.  
¡! [image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

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

Compila ``Main.ps1`` desde Internet en un archivo ejecutable para su salida en `.\Main.exe`.

### Servicio web autoalojado

```powershell
Start-ps12exeWebServer
```

Inicia un servicio web que permite a los usuarios compilar código powershell en línea.

## Parámetros

### Parámetros GUI

```powershell
ps12exeGUI [[-ConfigFile] '<archivo de configuración>'] [-PS1File '<archivo de código>'] [-Localize '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<archivo de código>'] [-Localize '<código de idioma>'] [-UIMode
 'Dark'|'Light'|'Auto'] [-help]
```

```Texto
ConfigFile : El archivo de configuración que desea cargar.
PS1File    : El archivo de script a compilar.
Localize   : El código de idioma que desea usar.
UIMode     : El modo de interfaz de usuario que desea usar.
help       : Mostrar esta información de ayuda.
```

### Parámetros de la consola

```powershell
[input |] ps12exe [[-inputFile] '<nombre de archivo|url>' | -Content '<script>'] [-outputFile '<nombre de archivo>']
        [-CompilerOptions '<opciones>'] [-TempDir '<carpeta>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<nombre de archivo|url>'; title='<título>'; description='<descripción>'; company='<compañía>';
        product='<producto>'; copyright='<derechos de autor>'; trademark='<marca>'; version='<versión>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Versión de tiempo de ejecución>']
        [-SkipVersionCheck] [-GuestMode] [-Localize '<código de idioma>'] [-help]
```

```text
input            : La cadena del contenido del archivo de script de PowerShell, igual que -Content.
inputFile        : La ruta o URL del archivo de script de PowerShell que desea convertir en un archivo ejecutable (el archivo debe estar codificado en UTF8 o UTF16)
Content          : El contenido del script de PowerShell que desea convertir en un archivo ejecutable
outputFile       : El nombre del archivo o carpeta de destino, por defecto es el inputFile con la extensión '.exe'
CompilerOptions  : Opciones adicionales del compilador (ver https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)
TempDir          : El directorio donde se almacenan los archivos temporales (por defecto es un directorio temporal generado aleatoriamente en %temp%)
minifyer         : Un bloque de script que reduce el tamaño del script antes de la compilación
lcid             : El identificador de ubicación del archivo ejecutable compilado. Si no se especifica, será la cultura del usuario actual
prepareDebug     : Crear información que ayude a la depuración
architecture     : Compilar sólo para un tiempo de ejecución específico. Los valores posibles son 'x64', 'x86' y 'anycpu'
threadingModel   : Modo 'apartamento de un solo hilo' o 'apartamento de varios hilos'
noConsole        : El archivo ejecutable generado será una aplicación de Windows Forms sin ventana de consola
UNICODEEncoding  : Codificar la salida como UNICODE en el modo de consola
credentialGUI    : Usar un GUI para solicitar credenciales en el modo de consola
resourceParams   : Una tabla hash que contiene los parámetros de recursos del archivo ejecutable compilado
configFile       : Escribir un archivo de configuración (<outputfile>.exe.config)
noOutput         : El archivo ejecutable generado no producirá salida estándar (incluyendo los canales detallado e informativo)
noError          : El archivo ejecutable generado no producirá salida de error (incluyendo los canales de advertencia y depuración)
noVisualStyles   : Desactivar los estilos visuales de la aplicación GUI de Windows generada (sólo se usa con -noConsole)
exitOnCancel     : Salir del programa cuando se elija Cancelar o 'X' en el cuadro de entrada de Read-Host (sólo se usa con -noConsole)
DPIAware         : Si se habilita el escalado de pantalla, los controles GUI se escalarán lo más posible
winFormsDPIAware : Si se habilita el escalado de pantalla, WinForms usará el escalado DPI (requiere Windows 10 y .Net 4.7 o superior)
requireAdmin     : Si se habilita el UAC, el archivo ejecutable compilado sólo se podrá ejecutar en un contexto elevado (si es necesario, aparecerá el cuadro de diálogo del UAC)
supportOS        : Usar las características de las últimas versiones de Windows (ejecutar [Environment]::OSVersion para ver las diferencias)
virtualize       : Se ha activado la virtualización de aplicaciones (se fuerza el tiempo de ejecución x86)
longPaths        : Habilitar las rutas largas (> 260 caracteres) si están habilitadas en el sistema operativo (sólo para Windows 10 o superior)
targetRuntime    : Versión de tiempo de ejecución de destino, 'Framework4.0' por defecto, se admiten 'Framework2.0'
SkipVersionCheck : Omitir la comprobación de nuevas versiones de ps12exe
GuestMode        : Compilación de scripts con protección adicional frente al acceso a archivos nativos
Localize         : El código de idioma que desea usar
Help             : Mostrar esta información de ayuda
```

### Observaciones

### Preprocesamiento

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

```powershell
#_include <nombre_archivo|url>
#_include_as_value <nombre_valor> <archivo|url>
```

Incluye el contenido del archivo `<nombre_archivo|url>` o `<archivo|url>` en el script. El contenido del archivo se inserta en la ubicación del comando `#_include`/`#_include_as_value`.  

A diferencia de la sentencia `#_if`, si no encierra el nombre del archivo entre comillas, la familia de comandos de preprocesamiento `#_include` trata el espacio final, `#`, como parte del nombre del archivo.  

```powershell.
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

```powershell
#_require ps12exe
#_pragma Console 0
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

La directiva de preprocesamiento pragma no tiene efecto sobre el contenido del script, pero modifica los parámetros utilizados para la compilación.  
He aquí un ejemplo:

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

Como puede ver, `#_pragma Console no` hace que el archivo exe generado se ejecute en modo ventana, incluso si no especificamos `-noConsole` en tiempo de compilación.
El comando pragma puede establecer cualquier parámetro de compilación:

```powershell
#_pragma noConsole #Modo ventana
#_pragma Console #Modo consola
#_pragma Console no #Modo ventana
#_pragma Console true #Modo consola
#_pragma icon $PSScriptRoot/icon.ico #Configurar icono
#_pragma title "title" #Establecer título del exe
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

Cuando el código llega a este punto, el proceso sale con el código de salida dado y elimina el archivo EXE.

### Minifyer

Dado que la "compilación" de ps12exe incrusta todo en el script textualmente como un recurso en el ejecutable resultante, si el script tiene muchas cadenas inútiles, el ejecutable resultante será muy grande.  
Puede utilizar el parámetro `-Minifyer` para especificar un bloque de script que preprocesará el script antes de la compilación para obtener un ejecutable generado más pequeño.  

Si no sabe cómo escribir un bloque de script de este tipo, puede utilizar [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | & ./psminnifyer.ps1 }
```

### Lista de cmdlets no implementados

Los comandos básicos de entrada/salida de ps12exe deben ser reescritos en C#. Los no implementados son *`Write-Progress`* en modo consola (demasiado trabajo) y *`Start-Transcript`*/*`Stop-Transcript`* (Microsoft no tiene una implementación de referencia adecuada).

### Formato de salida en modo GUI

Por defecto, el formato de salida para comandos pequeños en powershell es una línea por línea (como un array de cadenas). Cuando un comando genera 10 líneas de salida y se le da salida usando la GUI, aparecen 10 cajas de mensajes, cada una esperando ser determinada. Para evitar esto, importe el comando `Out-String` a la línea de comandos. Esto convertirá la salida en una matriz de cadenas de 10 líneas, todas las cuales se mostrarán en un cuadro de mensaje (por ejemplo, `dir C:\ | Out-String`).

### Ficheros de configuración

ps12exe puede crear ficheros de configuración con el nombre `ejecutable generado + ".config"`. En la mayoría de los casos, estos ficheros de configuración no son necesarios, son sólo una lista de qué versión de .Net Framework debe utilizar. Dado que normalmente utilizará el .Net Framework actual, intente ejecutar su ejecutable sin los archivos de configuración.

### Manejo de parámetros

El script compilado manejará los parámetros igual que el script original. Una limitación proviene del entorno Windows: para todos los ejecutables, todos los parámetros son de tipo String, y si el tipo de parámetro no se convierte implícitamente, debe convertirse explícitamente en el script. Incluso puede canalizar contenido al ejecutable, pero con la misma limitación (todos los valores canalizados son de tipo String).

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

Todavía puede usar `$PSScriptRoot` para obtener la ruta al directorio donde se encuentra el ejecutable, y el nuevo `$PSEXEpath` para obtener la ruta al ejecutable en sí.

### Ventanas de fondo en modo -noConsole

Cuando se abre una ventana externa en un script que utiliza el modo `-noConsole` (por ejemplo `Get-Credential` o un comando que requiere `cmd.exe`), se abrirá una ventana en segundo plano.

La razón de esto es que cuando se cierra una ventana externa, windows intenta activar la ventana padre. Dado que los scripts compilados no tienen ventanas, esto activa la ventana padre del script compilado, que suele ser una ventana de Explorer o Powershell.

Para evitar esto, puede utilizar `$Host.UI.RawUI.FlushInputBuffer()` para abrir una ventana invisible que pueda ser activada. La siguiente llamada a `$Host.UI.RawUI.FlushInputBuffer()` cerrará esta ventana (y así sucesivamente).

El siguiente ejemplo ya no abrirá la ventana en segundo plano, a diferencia de llamar a `ipconfig | Out-String` sólo una vez:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

## Comparación de Ventajas 🏆

### Comparación Rápida 🏁

| Aspecto | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| Repositorio de solo scripts 📦 | ✔️ Solo archivos de texto, excepto imágenes y dependencias | ❌ Contiene archivos ejecutables con licencia de código abierto |
| Comando para generar "Hello World" 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1` |
| Tamaño del archivo ejecutable "Hello World" 💾 | 🥰 1024 bytes | 😨 25088 bytes |
| Soporte multilingüe en la GUI 🌐 | ✔️ | ❌ |
| Verificación de sintaxis en tiempo de compilación ✔️ | ✔️ | ❌ |
| Función de preprocesamiento 🔄 | ✔️ | ❌ |
| `-extract` y otros parámetros especiales de análisis sintáctico 🧹 | 🗑️ Eliminado | 🥲 Requiere modificación del código fuente |
| PR welcome level 🤝 | 🥰 ¡Bienvenido! | 🤷 14 PRs, 13 de los cuales fueron cerrados |

### Comparación Compleja 🔍

En comparación con [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), este proyecto presenta las siguientes mejoras:

| Mejoras | Descripción |
| --- | --- |
| ✔️ Verificación de sintaxis en tiempo de compilación | Realiza una verificación de sintaxis durante la compilación para mejorar la calidad del código |
| 🔄 Potente función de preprocesamiento | Realiza un preprocesamiento del script antes de la compilación, evitando la necesidad de copiar y pegar todo el contenido en el script |
| 🛠️ Parámetro `-CompilerOptions` | Permite una mayor personalización del archivo ejecutable generado |
| 📦️ Parámetro `-Minifyer` | Realiza un preprocesamiento antes de la compilación para generar un archivo ejecutable más pequeño |
| 🌐 Soporte para compilar scripts y archivos de inclusión desde URL | Admite la descarga de iconos desde una URL |
| 🖥️ Optimización del parámetro `-noConsole` | Mejora el manejo de opciones y la visualización del título de la ventana emergente personalizada |
| 🧹 Eliminación del archivo exe | Se eliminó el archivo exe del repositorio de código |
| 🌍 Soporte multilingüe y GUI de solo script | Mejora el soporte multilingüe y la GUI de solo script, incluyendo el modo oscuro |
| 📖 Separación de archivos cs de archivos ps1 | Facilita la lectura y el mantenimiento |
| 🚀 Otras mejoras | ¡Y muchas más! |
