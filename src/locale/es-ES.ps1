@{
	LangName = "Español (España)"
	LangID = "es-ES"
	# Right click Menu
	CompileTitle		   = "Compilar a EXE"
	OpenInGUI			   = "Abrir en ps12exeGUI"
	GUICfgFileDesc		   = "Archivo de configuración de ps12exe GUI"
	# Web Server
	ServerStarted		   = "¡Servidor HTTP iniciado!"
	ServerStopped		   = "¡Servidor HTTP detenido!"
	ServerStartFailed	   = "Error al iniciar el servidor HTTP."
	TryRunAsRoot		   = "Vuelva a intentarlo como usuario root."
	ServerListening		   = "Dirección de acceso:"
	ExitServerTip		   = "Puede presionar Ctrl+C para salir del servidor en cualquier momento."
	# GUI
	ErrorHead			   = "Error:"
	CompileResult		   = "Resultado de la compilación"
	DefaultResult		   = "¡Hecho!"
	AskSaveCfg			   = "¿Desea guardar el archivo de configuración?"
	AskSaveCfgTitle		   = "Guardar archivo de configuración"
	CfgFileLabelHead	   = "Archivo de configuración:"
	# Console
	WebServerHelpData	   = @{
		title	   = "Uso:"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<donde>']
	[-Localize '<código de idioma>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "La dirección del servidor HTTP que se registrará."
			MaxCompileThreads = "El número maximo de hilos de compilación."
			MaxCompileTime	  = "El tiempo maximo de compilación (segundos)."
			ReqLimitPerMin	  = "El número de solicitudes por minuto para cada IP."
			MaxCachedFileSize = "El tamaño maximo de archivo caché."
			MaxScriptFileSize = "El tamaño maximo de archivo de código."
			CacheDir		  = "El directorio donde se almacenan los archivos caché."
			Localize		  = "El código de idioma para el registro en el lado del servidor."
			help			  = "Mostrar esta información de ayuda."
		}
	}
	GUIHelpData			   = @{
		title	   = "Uso:"
		Usage	   = "ps12exeGUI [[-ConfigFile] '<archivo de configuración>'] [-Localize '<código de idioma>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfigFile	= "El archivo de configuración que desea cargar."
			Localize	= "El código de idioma que desea usar."
			UIMode		= "El modo de interfaz de usuario que desea usar."
			help		= "Mostrar esta información de ayuda."
		}
	}
	SetContextMenuHelpData = @{
		title	   = "Uso:"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<código de idioma>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "El método que desea ejecutar."
			Localize = "El código de idioma que desea usar."
			help	 = "Mostrar esta información de ayuda."
		}
	}
	ConsoleHelpData		   = @{
		title	   = "Uso:"
		Usage	   = "[input |] ps12exe [[-inputFile] '<nombre de archivo|url>' | -Content '<script>'] [-outputFile '<nombre de archivo>']
	[-CompilerOptions '<opciones>'] [-TempDir '<carpeta>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<nombre de archivo|url>'; title='<título>'; description='<descripción>'; company='<compañía>';
	product='<producto>'; copyright='<derechos de autor>'; trademark='<marca>'; version='<versión>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Versión de tiempo de ejecución>']
	[-GuestMode] [-Localize '<código de idioma>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "La cadena del contenido del archivo de script de PowerShell, igual que ``-Content``."
			inputFile		 = "La ruta o URL del archivo de script de PowerShell que desea convertir en un archivo ejecutable (el archivo debe estar codificado en UTF8 o UTF16)"
			Content			 = "El contenido del script de PowerShell que desea convertir en un archivo ejecutable"
			outputFile		 = "El nombre del archivo o carpeta de destino, por defecto es el inputFile con la extensión ``'.exe'``"
			CompilerOptions	 = "Opciones adicionales del compilador (ver ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)"
			TempDir			 = "El directorio donde se almacenan los archivos temporales (por defecto es un directorio temporal generado aleatoriamente en ``%temp%``)"
			minifyer		 = "Un bloque de script que reduce el tamaño del script antes de la compilación"
			lcid			 = "El identificador de ubicación del archivo ejecutable compilado. Si no se especifica, será la cultura del usuario actual"
			prepareDebug	 = "Crear información que ayude a la depuración"
			architecture	 = "Compilar sólo para un tiempo de ejecución específico. Los valores posibles son ``'x64'``, ``'x86'`` y ``'anycpu'``"
			threadingModel	 = "Modo ``'apartamento de un solo hilo'`` o ``'apartamento de varios hilos'``"
			noConsole		 = "El archivo ejecutable generado será una aplicación de Windows Forms sin ventana de consola"
			UNICODEEncoding	 = "Codificar la salida como UNICODE en el modo de consola"
			credentialGUI	 = "Usar un GUI para solicitar credenciales en el modo de consola"
			resourceParams	 = "Una tabla hash que contiene los parámetros de recursos del archivo ejecutable compilado"
			configFile		 = "Escribir un archivo de configuración (``<outputfile>.exe.config``)"
			noOutput		 = "El archivo ejecutable generado no producirá salida estándar (incluyendo los canales detallado e informativo)"
			noError			 = "El archivo ejecutable generado no producirá salida de error (incluyendo los canales de advertencia y depuración)"
			noVisualStyles	 = "Desactivar los estilos visuales de la aplicación GUI de Windows generada (sólo se usa con ``-noConsole``)"
			exitOnCancel	 = 'Salir del programa cuando se elija `Cancelar` o `"X"` en el cuadro de entrada de `Read-Host` (sólo se usa con `-noConsole`)'
			DPIAware		 = "Si se habilita el escalado de pantalla, los controles GUI se escalarán lo más posible"
			winFormsDPIAware = "Si se habilita el escalado de pantalla, WinForms usará el escalado DPI (requiere Windows 10 y .Net 4.7 o superior)"
			requireAdmin	 = "Si se habilita el UAC, el archivo ejecutable compilado sólo se podrá ejecutar en un contexto elevado (si es necesario, aparecerá el cuadro de diálogo del UAC)"
			supportOS		 = "Usar las características de las últimas versiones de Windows (ejecutar ``[Environment]::OSVersion`` para ver las diferencias)"
			virtualize		 = "Se ha activado la virtualización de aplicaciones (se fuerza el tiempo de ejecución x86)"
			longPaths		 = "Habilitar las rutas largas (> 260 caracteres) si están habilitadas en el sistema operativo (sólo para Windows 10 o superior)"
			targetRuntime	 = "Versión de tiempo de ejecución de destino, 'Framework4.0' por defecto, se admiten 'Framework2.0'"
			GuestMode		 = "Compilación de scripts con protección adicional frente al acceso a archivos nativos"
			Localize		 = "El código de idioma que desea usar"
			Help			 = "Mostrar esta información de ayuda"
		}
	}
	CompilingI18nData = @{
		NoneInput = "¡Sin entrada!"
		BothInputAndContentSpecified = "¡No se puede usar el archivo de entrada y el contenido al mismo tiempo!"
		PreprocessDone = "Finalización de la preprocesación del script de entrada"
		PreprocessedScriptSize = "Script preprocesado -> {0} bytes"
		MinifyingScript = "Minificando script..."
		MinifyedScriptSize = "Script minificado -> {0} bytes"
		MinifyerError = "Error del minificador: {0}"
		MinifyerFailedUsingOriginalScript = "Falló el minificador, utilizando el script original."
		TempFileMissing = "¡No se encontró el archivo temporal {0}!"
		CombinedArg_x86_x64 = "-x86 no se puede usar con -x64"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 no se puede usar con -runtime40"
		CombinedArg_Runtime20_LongPaths = "Las rutas largas solo están disponibles con .Net 4 o superior"
		CombinedArg_Runtime20_winFormsDPIAware = "DPI aware solo está disponible con .Net 4 o superior"
		CombinedArg_STA_MTA = "-STA no se puede usar con -MTA"
		InvalidResourceParam = "Parámetro -resourceParams con una clave inválida: {0}"
		CombinedArg_ConfigFileYes_No = "-configFile no se puede usar con -noConfigFile"
		InputSyntaxError = "¡Error de sintaxis en el script!"
		SyntaxErrorLineStart = "En la línea {0}, Col {1}:"
		IdenticalInputOutput = "¡El archivo de entrada es idéntico al archivo de salida!"
		CombinedArg_Virtualize_requireAdmin = "-virtualize no se puede usar con -requireAdmin"
		CombinedArg_Virtualize_supportOS = "-virtualize no se puede usar con -supportOS"
		CombinedArg_Virtualize_longPaths = "-virtualize no se puede usar con -longPaths"
		CombinedArg_NoConfigFile_LongPaths = "Forzando la generación de un archivo de configuración, ya que la opción -longPaths lo requiere"
		CombinedArg_NoConfigFile_winFormsDPIAware = "Forzando la generación de un archivo de configuración, ya que la opción -winFormsDPIAware lo requiere"
		SomeCmdletsMayNotAvailable = "¡Se usaron cmdlets {0} pero pueden no estar disponibles en tiempo de ejecución, asegúrese de haberlos verificado!"
		SomeNotFindedCmdlets = "Se usaron funciones desconocidas {0}"
		CompilingFile = "Compilando archivo..."
		CompilationFailed = "¡Falló la compilación!"
		OutputFileNotWritten = "No se escribió el archivo de salida {0}"
		CompiledFileSize = "Archivo compilado escrito -> {0} bytes"
		OppsSomethingWentWrong = "Vaya, algo salió mal."
		TryUpgrade = "¿La última versión es {0}, intenta actualizarla?"
		EnterToSubmitIssue = "Para obtener ayuda, envíe un problema presionando Enter."
		GuestModeFileTooLarge = "El archivo {0} es demasiado grande para leerlo."
		GuestModeIconFileTooLarge = "El icono {0} es demasiado grande para leerlo."
		GuestModeFtpNotSupported = "FTP no es compatible en modo invitado."
		IconFileNotFound = "No se encontró el archivo de icono: {0}"
		ReadFileFailed = "Falló la lectura del archivo: {0}"
		PreprocessUnknownIfCondition = "Condición desconocida: {0}`nSe asume que es falso."
		PreprocessMissingEndIf = "Falta el final de la declaración if: {0}"
		ConfigFileCreated = "Se creó el archivo de configuración para EXE"
		SourceFileCopied = "Nombre de archivo fuente copiado para depuración: {0}"
		RoslynFailedFallback = "Falló Roslyn CodeAnalysis`nRetrocediendo a Usar Windows PowerShell con CodeDom...`nEs posible que desee agregar -UseWindowsPowerShell a los argumentos para omitir este retroceso en el futuro.`n...o envíe un PR al repositorio ps12exe para solucionarlo!"
		ReadingScript = "Leyendo {0}, tamaño {1} bytes"
		ForceX86byVirtualization = "Se activó la virtualización de aplicaciones, forzando la plataforma x86."
		TryingTinySharpCompile = "Resultado constante, intentando el compilador TinySharp..."
		TinySharpFailedFallback = "Error del compilador TinySharp, retroceso al marco de programa normal"
		OutputPath = "Ruta: {0}"
		ReadingScriptDone = "Finalización de la lectura de {0}, inicio de la preprocesación..."
		PreprocessScriptDone = "Finalización de la preprocesación del archivo {0}"
		ConstEvalStart = "Evaluación de constantes..."
		ConstEvalDone = "Finalización de la evaluación de constantes -> {0} bytes"
		ConstEvalTooLongFallback = "El resultado de la constante es demasiado largo, retroceso al marco de programa normal"
		ConstEvalTimeoutFallback = "La evaluación de la constante se agotó después de {0} segundos, retroceso al marco de programa normal"
		InvalidArchitecture = "Plataforma inválida {0}, utilizando AnyCpu"
		UnknownPragma = "Pragma desconocido: {0}"
		UnknownPragmaBadParameterType = "Pragma desconocido: {0}, no se puede analizar el tipo {1}."
		UnknownPragmaBoolValue = "Valor de pragma desconocido: {0}, no se puede tomar como booleano."
		DllExportDelNoneTypeArg = "{0}: {1} es un parámetro de tipo nulo, se asume que es una cadena."
		DllExportUsing = "Está utilizando #_DllExport, esta macro está en desarrollo y aún no es compatible."
	}
	WebServerI18nData = @{
		CompilingUserInput = "Compilando entrada de usuario: {0}"
		EmptyResponse = "No se encontraron datos al manejar la solicitud, se devuelve una respuesta vacía"
		InputTooLarge413 = "La entrada del usuario es demasiado grande, se devuelve un error 413"
		ReqLimitExceeded429 = "La IP {0} ha superado el límite de {1} solicitudes por minuto, se devuelve un error 429"
	}
}
