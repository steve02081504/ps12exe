@{
	# Right click Menu
	CompileTitle     = "Compilar a EXE"
	OpenInGUI        = "Abrir en ps12exeGUI"
	GUICfgFileDesc   = "Archivo de configuración de ps12exe GUI"
	# UI
	ErrorHead        = "Error:"
	CompileResult    = "Resultado de la compilación"
	DefaultResult    = "¡Hecho!"
	AskSaveCfg       = "¿Desea guardar el archivo de configuración?"
	AskSaveCfgTitle  = "Guardar archivo de configuración"
	CfgFileLabelHead = "Archivo de configuración:"
	# Console
	GUIHelpData      = @{
		title      = "Uso:"
		Usage      = "ps12exeGUI [[-ConfingFile] '<archivo de configuración>'] [-Localize '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfingFile = "El archivo de configuración que desea cargar."
			Localize    = "El código de idioma que desea usar."
			UIMode      = "El modo de interfaz de usuario que desea usar."
			help        = "Mostrar esta información de ayuda."
		}
	}
	ConsoleHelpData  = @{
		title      = "Uso:"
		Usage      = "[input |] ps12exe [[-inputFile] '<nombre de archivo|url>' | -Content '<script>'] [-outputFile '<nombre de archivo>']
        [-CompilerOptions '<opciones>'] [-TempDir '<carpeta>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<nombre de archivo|url>'; title='<título>'; description='<descripción>'; company='<compañía>';
        product='<producto>'; copyright='<derechos de autor>'; trademark='<marca>'; version='<versión>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]"
		PrarmsData = [ordered]@{
			input            = "La cadena del contenido del archivo de script de PowerShell, igual que ``-Content``."
			inputFile        = "La ruta o URL del archivo de script de PowerShell que desea convertir en un archivo ejecutable (el archivo debe estar codificado en UTF8 o UTF16)"
			Content          = "El contenido del script de PowerShell que desea convertir en un archivo ejecutable"
			outputFile       = "El nombre del archivo o carpeta de destino, por defecto es el inputFile con la extensión ``'.exe'``"
			CompilerOptions  = "Opciones adicionales del compilador (ver ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)"
			TempDir          = "El directorio donde se almacenan los archivos temporales (por defecto es un directorio temporal generado aleatoriamente en ``%temp%``)"
			minifyer         = "Un bloque de script que reduce el tamaño del script antes de la compilación"
			lcid             = "El identificador de ubicación del archivo ejecutable compilado. Si no se especifica, será la cultura del usuario actual"
			prepareDebug     = "Crear información que ayude a la depuración"
			architecture     = "Compilar sólo para un tiempo de ejecución específico. Los valores posibles son ``'x64'``, ``'x86'`` y ``'anycpu'``"
			threadingModel   = "Modo ``'apartamento de un solo hilo'`` o ``'apartamento de varios hilos'``"
			noConsole        = "El archivo ejecutable generado será una aplicación de Windows Forms sin ventana de consola"
			UNICODEEncoding  = "Codificar la salida como UNICODE en el modo de consola"
			credentialGUI    = "Usar un GUI para solicitar credenciales en el modo de consola"
			resourceParams   = "Una tabla hash que contiene los parámetros de recursos del archivo ejecutable compilado"
			configFile       = "Escribir un archivo de configuración (``<outputfile>.exe.config``)"
			noOutput         = "El archivo ejecutable generado no producirá salida estándar (incluyendo los canales detallado e informativo)"
			noError          = "El archivo ejecutable generado no producirá salida de error (incluyendo los canales de advertencia y depuración)"
			noVisualStyles   = "Desactivar los estilos visuales de la aplicación GUI de Windows generada (sólo se usa con ``-noConsole``)"
			exitOnCancel     = 'Salir del programa cuando se elija `Cancelar` o `"X"` en el cuadro de entrada de `Read-Host` (sólo se usa con `-noConsole`)'
			DPIAware         = "Si se habilita el escalado de pantalla, los controles GUI se escalarán lo más posible"
			winFormsDPIAware = "Si se habilita el escalado de pantalla, WinForms usará el escalado DPI (requiere Windows 10 y .Net 4.7 o superior)"
			requireAdmin     = "Si se habilita el UAC, el archivo ejecutable compilado sólo se podrá ejecutar en un contexto elevado (si es necesario, aparecerá el cuadro de diálogo del UAC)"
			supportOS        = "Usar las características de las últimas versiones de Windows (ejecutar ``[Environment]::OSVersion`` para ver las diferencias)"
			virtualize       = "Se ha activado la virtualización de aplicaciones (se fuerza el tiempo de ejecución x86)"
			longPaths        = "Habilitar las rutas largas (> 260 caracteres) si están habilitadas en el sistema operativo (sólo para Windows 10 o superior)"
		}
	}
}
