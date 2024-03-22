# ps12exe

## Introducción


[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./docs/README_CN.md)
[![English](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./docs/README_EN.md)
[![日本](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./docs/README_JP.md)

## Instalación

```powershell
Install-Module ps12exe ## Instala el módulo ps12exe
Set-ps12exeContextMenu ## Configura el menú contextual
```

(También puede clonar el repositorio y ejecutar `.\ps12exe.ps1`)

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
ps12exeGUI [[-ConfigFile] '<archivo de configuración>'] [-Localize '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```Texto
ConfigFile : El archivo de configuración que desea cargar.
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
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]
```

```Texto
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
exitOnCancel     : Salir del programa cuando se elija Cancelar o "X" en el cuadro de entrada de Read-Host (sólo se usa con -noConsole)
DPIAware         : Si se habilita el escalado de pantalla, los controles GUI se escalarán lo más posible
winFormsDPIAware : Si se habilita el escalado de pantalla, WinForms usará el escalado DPI (requiere Windows 10 y .Net 4.7 o superior)
requireAdmin     : Si se habilita el UAC, el archivo ejecutable compilado sólo se podrá ejecutar en un contexto elevado (si es necesario, aparecerá el cuadro de diálogo del UAC)
supportOS        : Usar las características de las últimas versiones de Windows (ejecutar [Environment]::OSVersion para ver las diferencias)
virtualize       : Se ha activado la virtualización de aplicaciones (se fuerza el tiempo de ejecución x86)
longPaths        : Habilitar las rutas largas (> 260 caracteres) si están habilitadas en el sistema operativo (sólo para Windows 10 o superior)
```

### Observaciones

### Preprocesamiento

ps12exe preprocesa el script antes de compilarlo.  

```powershell
# Lee el marco del programa desde el archivo ps12exe.cs
#_if PSEXE # Este es el código de preprocesamiento usado cuando el script es compilado por ps12exe.
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #Insertar el contenido de ps12exe.cs en este script.
#_else #De lo contrario, lea el archivo cs normalmente
	[cadena]$programFrame = Get-Content $PSScriptRoot/ps12exe.cs -Raw -Encoding UTF8
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
#_include <nombre_de_archivo|url>/`#_include_as_value <valuename> <file|url>``
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

#### `#_!!!`

```powershell
$Script:eshDir =
#_if PSScript #No es posible tener $EshellUI en PSEXE con un $PSScriptRoot inválido
if (Test-Path "$($EshellUI.Sources.Path)/ruta/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/... /ruta/esh) { "$PSScriptRoot/..." }
} elseif
#_else
	¡#_! Si
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

¡¡¡Cualquier línea que empiece por `#_!!! ¡¡¡` al principio de una línea con `#_!!! ` será eliminada.

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
	¡si(! (Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

Vale la pena señalar que el código que genera sólo instalará módulos, no los importará.
Por favor, utilice `Import-Module` cuando sea apropiado.

Cuando necesites requerir más de un módulo, puedes usar espacios, comas, o punto y coma como separadores en lugar de escribir sentencias require de varias líneas.

```powershell
#_require módulo1 módulo2;módulo3,módulo4,módulo5
```

#### `#_pragma`

La directiva de preprocesamiento pragma no tiene efecto sobre el contenido del script, pero modifica los parámetros utilizados para la compilación.  
He aquí un ejemplo:

```powershell
PS C:³\sers\steve02081504> '12' | ps12exe
Archivo compilado escrito -> 1024 bytes
PS C:³Users\steve02081504> . /a.exe
12
PS C:@Users\steve02081504> '#_pragma Console no
>> 12' | ps12exe
Script preprocesado -> 23 bytes
Archivo compilado escrito -> 2560 bytes
```

Como puede ver, `#_pragma Console no` hace que el archivo exe generado se ejecute en modo ventana, incluso si no especificamos `-noConsole` en tiempo de compilación.
El comando pragma puede establecer cualquier parámetro de compilación:

```powershell
#_pragma noConsole #Modo ventana
#_pragma Console #Modo consola
#Console no Modo ventana
#Console true Modo consola
#_pragma icon $PSScriptRoot/icon.ico #Configurar icono
#_pragma title "title" #Establecer título del exe
```

### Minifyer

Dado que la "compilación" de ps12exe incrusta todo en el script textualmente como un recurso en el ejecutable resultante, si el script tiene muchas cadenas inútiles, el ejecutable resultante será muy grande.  
Puede utilizar el parámetro `-Minifyer` para especificar un bloque de script que preprocesará el script antes de la compilación para obtener un ejecutable generado más pequeño.  

Si no sabe cómo escribir un bloque de script de este tipo, puede utilizar [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | & . /psminnifyer.ps1 }
```

### Lista de cmdlets no implementados

Los comandos básicos de entrada/salida de ps12exe deben ser reescritos en C#. Los no implementados son *`Write-Progress`* en modo consola (demasiado trabajo) y *`Start-Transcript`*/*`Stop-Transcript`* (Microsoft no tiene una implementación de referencia adecuada).

### Formato de salida en modo GUI

Por defecto, el formato de salida para comandos pequeños en powershell es una línea por línea (como un array de cadenas). Cuando un comando genera 10 líneas de salida y se le da salida usando la GUI, aparecen 10 cajas de mensajes, cada una esperando ser determinada. Para evitar esto, importe el comando `Out-String` a la línea de comandos. Esto convertirá la salida en una matriz de cadenas de 10 líneas, todas las cuales se mostrarán en un cuadro de mensaje (por ejemplo, `dir C:|| Out-String`).

### Ficheros de configuración

ps12exe puede crear ficheros de configuración con el nombre `ejecutable generado + ".config"`. En la mayoría de los casos, estos ficheros de configuración no son necesarios, son sólo una lista de qué versión de .Net Framework debe utilizar. Dado que normalmente utilizará el .Net Framework actual, intente ejecutar su ejecutable sin los archivos de configuración.

### Manejo de parámetros

El script compilado manejará los parámetros igual que el script original. Una limitación proviene del entorno Windows: para todos los ejecutables, todos los parámetros son de tipo String, y si el tipo de parámetro no se convierte implícitamente, debe convertirse explícitamente en el script. Incluso puede canalizar contenido al ejecutable, pero con la misma limitación (todos los valores canalizados son de tipo String).

### Seguridad de contraseñas

Nunca almacene contraseñas en scripts compilados.  
Todo el script es fácilmente visible para cualquier descompilador .net.  
¡![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguir entornos por script  

Puedes saber si un script se está ejecutando en un exe compilado o en un script por ``$Host.Name``. 

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

### Comparación ventajosa 🏆

### Comparación rápida 🏁

| Comparar contenido | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| Repositorio puro de scripts 📦 | ✔️ son todos archivos de texto excepto imágenes y dependencias | ❌ contiene archivos exe con acuerdos de código abierto |
| Comandos necesarios para generar hola mundo 🌍 | 😎 ``"¡Hola Mundo!"'' || ps12exe` | 🤔 ``echo "¡Hola Mundo!" *> a.ps1; PS2EXE a.ps1; rm a. ps1` |
| tamaño del ejecutable generado de hola mundo 💾 | 🥰1024 bytes | 😨25088 bytes |
| Soporte multilingüe de la interfaz gráfica de usuario 🌐 ✔️
| Comprobación de sintaxis en tiempo de compilación ✔️ | ✔️ | ❌ |
| Características de preprocesamiento 🔄 ✔️
| Análisis sintáctico de parámetros especiales como `-extract` 🧹 | 🗑️ eliminado | 🥲 Requiere modificación del código fuente |
| PR welcome 🤝 | 🥰 ¡Bienvenido! | 🤷14 PRs, 13 de ellos cerrados |

### Comparación detallada 🔍

En comparación con [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), este proyecto aporta las siguientes mejoras:

| Mejoras | Descripción |
| --- | --- |
| ✔️ Comprobación de sintaxis en tiempo de compilación | Comprobación de sintaxis en tiempo de compilación para mejorar la calidad del código | ✔️
| 🔄 Potente preprocesamiento | Preprocesamiento de scripts antes de compilar, sin necesidad de copiar y pegar todo en los scripts | | 🔄 Potente preprocesamiento.
| 🛠️ `-Parámetro CompilerOptions` | Nuevo parámetro que permite personalizar aún más el ejecutable generado | |
| 📦️ `-Minifyer` parameter | Preprocesa los scripts antes de la compilación para producir ejecutables más pequeños |
| 🌐 Soporte para compilar scripts y archivos de inclusión desde URLs | Soporte para descargar iconos desde URLs |
| 🖥️ Optimización del parámetro `-noConsole` | Optimizado el manejo de opciones y la visualización del título de la ventana, ahora puede personalizar el título de la ventana emergente a través de la configuración | 🖥️
| Eliminados archivos exe Eliminados archivos exe del repositorio de código.
| 🌍 Soporte multi-lenguaje, GUI sólo script | Mejor soporte multi-lenguaje, GUI sólo script con soporte de modo oscuro | 🌍 Soporte multi-lenguaje, GUI sólo script con soporte de modo oscuro
| 📖 Separar archivos cs de archivos ps1 | | más fácil de leer y mantener | | más fácil de leer y mantener.
| 🚀 Más mejoras | y más... |
