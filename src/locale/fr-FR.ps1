@{
	LangName = "Français"
	LangID = "fr-FR"
	# Right click Menu
	CompileTitle		   = "Compiler en EXE"
	OpenInGUI			   = "Ouvrir dans ps12exeGUI"
	GUICfgFileDesc		   = "Fichier de configuration ps12exe GUI"
	# Web Server
	ServerStarted		   = "Serveur HTTP démarré !"
	ServerStopped		   = "Serveur HTTP arrêté !"
	ServerStartFailed	   = "Échec du démarrage du serveur HTTP !"
	TryRunAsRoot		   = "Veuillez essayer d’exécuter en tant qu’administrateur."
	ServerListening		   = "Adresse d’accès :"
	ExitServerTip		   = "Vous pouvez quitter le serveur à tout moment en appuyant sur Ctrl+C"
	# GUI
	ErrorHead			   = "Erreur :"
	CompileResult		   = "Résultat de la compilation"
	DefaultResult		   = "Terminé !"
	AskSaveCfg			   = "Faut-il enregistrer le fichier de configuration ?"
	AskSaveCfgTitle		   = "Enregistrer le fichier de configuration"
	CfgFileLabelHead	   = "Fichier de configuration :"
	# Console
	WebServerHelpData	   = @{
		title	   = "Utilisation :"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<chemin>']
	[-Localize '<code_de_langue>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "Adresse du serveur HTTP à enregistrer."
			MaxCompileThreads = "Nombre maximal de threads de compilation."
			MaxCompileTime	  = "Temps de compilation maximal (secondes)."
			ReqLimitPerMin	  = "Limite de requêtes par minute et par adresse IP."
			MaxCachedFileSize = "Taille maximale du fichier mis en cache."
			MaxScriptFileSize = "Taille maximale du fichier script."
			CacheDir		  = "Répertoire du cache."
			Localize		  = "Code de langue à utiliser pour les journaux du côté serveur."
			help			  = "Affiche cette aide."
		}
	}
	GUIHelpData			   = @{
		title	   = "Utilisation :"
		Usage	   = @"
ps12exeGUI [[-ConfigFile] '<fichier_de_configuration>'] [-PS1File '<fichier_de_script>'] [-Localize '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<fichier_de_script>'] [-Localize '<code_de_langue>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
"@
		PrarmsData = [ordered]@{
			ConfigFile	= "Fichier de configuration à charger."
			PS1File		= "Fichier de script à compiler."
			Localize	= "Code de langue à utiliser."
			UIMode		= "Mode d’interface utilisateur à utiliser."
			help		= "Affiche cette aide."
		}
	}
	SetContextMenuHelpData = @{
		title	   = "Utilisation :"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<code_de_langue>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "Action à exécuter."
			Localize = "Code de langue à utiliser."
			help	 = "Affiche cette aide."
		}
	}
	ConsoleHelpData		   = @{
		title	   = "Utilisation :"
		Usage	   = "[input |] ps12exe [[-inputFile] '<nom_de_fichier|url>' | -Content '<script>'] [-outputFile '<nom_de_fichier>']
	[-CompilerOptions '<options>'] [-TempDir '<dossier>'] [-minifyer '<scriptblock>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<nom_de_fichier|url>'; title='<titre>'; description='<description>'; company='<société>';
	product='<produit>'; copyright='<copyright>'; trademark='<marque_déposée>'; version='<version>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<version_du_runtime>']
	[-SkipVersionCheck] [-GuestMode] [-Localize '<code_de_langue>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "Chaîne de caractères du contenu du fichier de script PowerShell, identique à ``-Content``."
			inputFile		 = "Chemin d’accès ou URL du fichier de script PowerShell que vous voulez convertir en exécutable (le fichier doit être encodé en UTF8 ou UTF16)."
			Content			 = "Contenu du script PowerShell que vous voulez convertir en exécutable."
			outputFile		 = "Nom du fichier exécutable cible ou dossier, par défaut ``inputFile`` avec l’extension ``'.exe'``."
			CompilerOptions	 = "Options de compilation supplémentaires (voir ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)."
			TempDir			 = "Répertoire pour stocker les fichiers temporaires (par défaut, un répertoire temporaire généré de façon aléatoire dans ``%temp%``)."
			minifyer		 = "Bloc de script pour réduire le script avant la compilation."
			lcid			 = "ID de localisation du fichier exécutable compilé. Si non spécifié, la culture de l’utilisateur actuel sera utilisée."
			prepareDebug	 = "Créer des informations utiles pour le débogage."
			architecture	 = "Compiler uniquement pour un environnement d’exécution spécifique. Les valeurs possibles sont ``'x64'``, ``'x86'`` et ``'anycpu'``."
			threadingModel	 = "Mode ``'Appartement à thread unique'`` ou ``'Appartement à threads multiples'``."
			noConsole		 = "Le fichier exécutable généré sera une application Windows Forms sans fenêtre de console."
			UNICODEEncoding	 = "Encoder la sortie en UNICODE en mode console."
			credentialGUI	 = "Utiliser une interface graphique pour demander les informations d’identification en mode console."
			resourceParams	 = "Table de hachage contenant les paramètres de ressource du fichier exécutable compilé."
			configFile		 = "Écrire un fichier de configuration (``<fichier_de_sortie>.exe.config``)."
			noOutput		 = "Le fichier exécutable généré ne produira pas de sortie standard (y compris les flux détaillés et d’informations)."
			noError			 = "Le fichier exécutable généré ne produira pas de sortie d’erreur (y compris les flux d’avertissements et de débogage)."
			noVisualStyles	 = "Désactiver les styles visuels pour les applications GUI Windows générées (utilisé uniquement avec ``-noConsole``)."
			exitOnCancel	 = "Quitter le programme lorsque ``Annuler`` ou ``'X'`` est sélectionné dans la zone de saisie ``Read-Host`` (utilisé uniquement avec ``-noConsole``)."
			DPIAware		 = "Si le mise à l’échelle de l’affichage est activée, les contrôles de l’interface graphique seront mis à l’échelle autant que possible."
			winFormsDPIAware = "Si la mise à l’échelle de l’affichage est activée, WinForms utilisera la mise à l’échelle DPI (nécessite Windows 10 et .Net 4.7 ou version ultérieure)."
			requireAdmin	 = "Si le contrôle de compte d’utilisateur est activé, le fichier exécutable compilé ne peut s’exécuter que dans un contexte élevé (une boîte de dialogue de contrôle de compte d’utilisateur s’affichera si nécessaire)."
			supportOS		 = "Utiliser les fonctionnalités de la dernière version de Windows (exécutez ``[Environment]::OSVersion`` pour voir la différence)."
			virtualize		 = "La virtualisation d’application est activée (force l’environnement d’exécution x86)."
			longPaths		 = "Si activé sur le système d’exploitation, active les chemins longs (> 260 caractères) (uniquement pour Windows 10 ou version ultérieure)."
			targetRuntime	 = "Version de l’environnement d’exécution cible, par défaut ``'Framework4.0'``, prend en charge ``'Framework2.0'``."
			SkipVersionCheck = "Ignorer la vérification de la nouvelle version de ps12exe."
			GuestMode		 = "Compiler le script avec une protection supplémentaire, éviter l’accès aux fichiers natifs."
			Localize		 = "Spécifier la langue de localisation."
			Help			 = "Affiche cette aide."
		}
	}
	CompilingI18nData = @{
		NewVersionAvailable = "Une nouvelle version de ps12exe est disponible : {0} !"
		NoneInput = "Aucune entrée !"
		BothInputAndContentSpecified = "Impossible de spécifier à la fois un fichier et du contenu !"
		PreprocessDone = "Prétraitement du script d’entrée terminé."
		PreprocessedScriptSize = "Script prétraité -> {0} octets."
		MinifyingScript = "Compression du script en cours..."
		MinifyedScriptSize = "Script compressé -> {0} octets."
		MinifyerError = "Erreur du compresseur : {0}"
		MinifyerFailedUsingOriginalScript = "Échec du compresseur, utilisation du script d’origine."
		TempFileMissing = "Fichier temporaire introuvable {0} !"
		CombinedArg_x86_x64 = "-x86 ne peut pas être utilisé avec -x64"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 ne peut pas être utilisé avec -runtime40"
		CombinedArg_Runtime20_LongPaths = "Les chemins longs ne sont pris en charge qu’avec .Net 4 ou version ultérieure."
		CombinedArg_Runtime20_winFormsDPIAware = "La prise en charge de la résolution DPI n’est prise en charge qu’avec .Net 4 ou version ultérieure."
		CombinedArg_STA_MTA = "-STA ne peut pas être utilisé avec -MTA"
		InvalidResourceParam = "Clé non valide pour le paramètre -resourceParams : {0}"
		CombinedArg_ConfigFileYes_No = "-configFile ne peut pas être utilisé avec -noConfigFile"
		InputSyntaxError = "Erreur de syntaxe du script !"
		SyntaxErrorLineStart = "Ligne {0}, colonne {1} :"
		IdenticalInputOutput = "Le fichier d’entrée est identique au fichier de sortie !"
		CombinedArg_Virtualize_requireAdmin = "-virtualize ne peut pas être utilisé avec -requireAdmin"
		CombinedArg_Virtualize_supportOS = "-virtualize ne peut pas être utilisé avec -supportOS"
		CombinedArg_Virtualize_longPaths = "-virtualize ne peut pas être utilisé avec -longPaths"
		CombinedArg_NoConfigFile_LongPaths = "La génération d’un fichier de configuration est forcée, car l’option -longPaths nécessite ce fichier."
		CombinedArg_NoConfigFile_winFormsDPIAware = "La génération d’un fichier de configuration est forcée, car l’option -winFormsDPIAware nécessite ce fichier."
		SomeCmdletsMayNotAvailable = "Des commandes susceptibles de ne pas être disponibles au moment de l’exécution ont été utilisées {0}, assurez-vous de les avoir vérifiées !"
		SomeNotFindedCmdlets = "Les commandes inconnues {0} ont été utilisées."
		SomeTypesMayNotAvailable = "Des types susceptibles de ne pas être disponibles au moment de l’exécution ont été utilisés {0}, assurez-vous de les avoir vérifiés !"
		CompilingFile = "Compilation en cours..."
		CompilationFailed = "Échec de la compilation !"
		OutputFileNotWritten = "Fichier de sortie non écrit {0}"
		CompiledFileSize = "Fichier compilé -> {0} octets"
		OppsSomethingWentWrong = "Oups, quelque chose s’est mal passé."
		TryUpgrade = "La dernière version est {0}, essayer de mettre à niveau ?"
		EnterToSubmitIssue = "Appuyez sur Entrée pour soumettre un problème pour obtenir de l’aide."
		GuestModeFileTooLarge = "Le fichier {0} est trop grand pour être lu."
        GuestModeIconFileTooLarge = "L’icône {0} est trop grande pour être lue."
		GuestModeFtpNotSupported = "FTP n’est pas pris en charge en mode invité."
		IconFileNotFound = "Fichier d’icône introuvable : {0}"
		ReadFileFailed = "Échec de la lecture du fichier : {0}"
		PreprocessUnknownIfCondition = "Condition inconnue : {0}\nSupposé être faux."
		PreprocessMissingEndIf = "Fin de if manquante : {0}"
		ConfigFileCreated = "Fichier de configuration créé pour l’EXE."
		SourceFileCopied = "Nom du fichier source copié pour le débogage : {0}"
        RoslynFailedFallback = "Échec de la compilation de Roslyn\nRetour à l’utilisation de Windows PowerShell avec CodeDom...\nVous voudrez peut-être ajouter -UseWindowsPowerShell aux paramètres à l’avenir pour ignorer ce repli\n... ou soumettre une pull request au référentiel ps12exe pour corriger ce problème !"
		ReadingFile = "Lecture de {0}, {1} octets."
		ForceX86byVirtualization = "La virtualisation d’application est activée, forçant l’utilisation de la plateforme x86."
		TryingTinySharpCompile = "Le résultat est une constante, essayez le compilateur TinySharp..."
		TinySharpFailedFallback = "Erreur du compilateur TinySharp, retour au framework du programme normal."
		OutputPath = "Chemin d’accès : {0}"
		ReadingScriptDone = "Lecture de {0} terminée, début du prétraitement..."
		PreprocessScriptDone = "Prétraitement de {0} terminé."
		ConstEvalStart = "Calcul de la constante en cours..."
		ConstEvalDone = "Calcul de la constante terminé -> {0} octets."
		ConstEvalTooLongFallback = "Le résultat de la constante est trop long, retour au framework de programme normal."
		ConstEvalTimeoutFallback = "Le calcul de la constante a pris {0} secondes, délai dépassé. Retour au framework de programme normal."
		ConstEvalThrowErrorFallback = "Une erreur s’est produite lors du calcul de la constante, retour au framework de programme normal."
		InvalidArchitecture = "Plateforme {0} non valide, utilisation de AnyCpu."
		UnknownPragma = "Pragma inconnu : {0}."
		UnknownPragmaBadParameterType = "Pragma inconnu : {0}, impossible d’analyser le type {1}."
		UnknownPragmaBoolValue = "Valeur pragma inconnue : {0}, impossible de la traiter comme un booléen."
		DllExportDelNoneTypeArg = "{0} : {1} est un argument sans type, on suppose qu’il s’agit d’une chaîne."
		DllExportUsing = "Vous utilisez #_DllExport, cette macro est encore en développement, elle n’est pas encore prise en charge."
	}
	WebServerI18nData = @{
		CompilingUserInput = "Compilation de la saisie utilisateur en cours : {0}"
		EmptyResponse = "Aucune donnée n’a été trouvée lors du traitement de la demande, renvoi d’une réponse vide."
		InputTooLarge413 = "La saisie utilisateur est trop grande, renvoi d’une erreur 413."
		ReqLimitExceeded429 = "L’adresse IP {0} a dépassé la limite de {1} requêtes par minute, renvoi d’une erreur 429."
	}
}
