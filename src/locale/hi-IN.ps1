@{
	# Right click Menu
	CompileTitle		   = "कॉम्पाइल करें EXE में"
	OpenInGUI			   = "ps12exeGUI में खोलें"
	GUICfgFileDesc		   = "ps12exe GUI कॉन्फ़िगरेशन फ़ाइल"
	# Web Server
	ServerStarted		   = "HTTP सर्वर शुरू हो गया है!"
	ServerStopped		   = "HTTP सर्वर बंद हो गया है!"
	ServerStartFailed	   = "HTTP सर्वर शुरू करने में विफल रहा!"
	TryRunAsRoot		   = "कृपया प्रशासक के रूप में चलाने का प्रयास करें।"
	ServerListening		   = "पहुंच का पता:"
	ExitServerTip		   = "आप कभी भी Ctrl+C दबाकर सर्वर को बंद कर सकते हैं"
	# GUI
	ErrorHead			   = "त्रुटि:"
	CompileResult		   = "कॉम्पाइल परिणाम"
	DefaultResult		   = "पूरा हुआ!"
	AskSaveCfg			   = "क्या आप कॉन्फ़िगरेशन फ़ाइल को सहेजना चाहते हैं?"
	AskSaveCfgTitle		   = "कॉन्फ़िगरेशन फ़ाइल सहेजें"
	CfgFileLabelHead	   = "कॉन्फ़िगरेशन फ़ाइल:"
	# Console
	WebServerHelpData	   = @{
		title	   = "उपयोग:"
		Usage	   = "Start-ps12exeWebServer [[-HostUrl] '<url>'] [-MaxCompileThreads '<uint>'] [-MaxCompileTime '<uint>']
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>'] [-CacheDir '<पथ>']
	[-Localize '<भाषा कोड>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "रजिस्टर करने के लिए HTTP सर्वर पता।"
			MaxCompileThreads = "अधिकतम कॉम्पाइल धागों की संख्या।"
			MaxCompileTime	  = "अधिकतम कॉम्पाइल समय (सेकंड)।"
			ReqLimitPerMin	  = "फ़ाइल प्रति मिनट की अनुरोध सीमा।"
			MaxCachedFileSize = "अधिकतम कैश फ़ाइल का आकार।"
			MaxScriptFileSize = "अधिकतम स्क्रिप्ट फ़ाइल का आकार।"
			CacheDir		  = "अधिकतम कैश फ़ाइल का डाइरेक्टरी पथ।"
			Localize		  = "सर्वर साइड रिकॉर्ड करने के लिए उपयोग किए जाने वाले भाषा कोड।"
			help			  = "इस मदद सूचना को दिखाएँ।"
		}
	}
	GUIHelpData			   = @{
		title	   = "उपयोग:"
		Usage	   = "ps12exeGUI [[-ConfigFile] '<कॉन्फ़िगरेशन फ़ाइल>'] [-Localize '<भाषा कोड>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]"
		PrarmsData = [ordered]@{
			ConfigFile	= "लोड करने के लिए कॉन्फ़िगरेशन फ़ाइल।"
			Localize	= "उपयोग किया जाने वाला भाषा कोड।"
			UIMode		= "उपयोग किया जाने वाला उपयोगकर्ता इंटरफेस मोड।"
			help		= "इस मदद सूचना को दिखाएँ।"
		}
	}
	SetContextMenuHelpData = @{
		title	   = "उपयोग:"
		Usage	   = "Set-ps12exeContextMenu [[-action] 'enable'|'disable'|'reset'] [-Localize '<भाषा कोड>'] [-help]"
		PrarmsData = [ordered]@{
			action	 = "क्रिया का कार्यान्वयन।"
			Localize = "उपयोग किए जाने वाले भाषा कोड।"
			help	 = "इस मदद सूचना को दिखाएँ।"
		}
	}
	ConsoleHelpData		   = @{
		title	   = "उपयोग:"
		Usage	   = "[input |] ps12exe [[-inputFile] '<फ़ाइल नाम|url>' | -Content '<स्क्रिप्ट>'] [-outputFile '<फ़ाइल नाम>']
	[-CompilerOptions '<विकल्प>'] [-TempDir '<फ़ोल्डर>'] [-minifyer '<स्क्रिप्टब्लॉक>'] [-noConsole]
	[-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
	[-resourceParams @{iconFile='<फ़ाइल नाम|url>'; title='<शीर्षक>'; description='<सारांश>'; company='<कंपनी>';
	product='<उत्पाद>'; copyright='<कॉपीराइट>'; trademark='<नामकरण>'; version='<संस्करण>'}]
	[-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
	[-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<रनटाइम संस्करण>']
	[-GuestMode] [-Localize '<भाषा कोड>'] [-help]"
		PrarmsData = [ordered]@{
			input			 = "PowerShell स्क्रिप्ट फ़ाइल की सामग्री का स्ट्रिंग,``-Content``के समान।"
			inputFile		 = "जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट फ़ाइल का पथ या URL (फ़ाइल को UTF8 या UTF16 एन्कोड किया गया होना चाहिए)"
			Content			 = "जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट की सामग्री"
			outputFile		 = "लक्षित एक्सीक्यूटेबल फ़ाइल का नाम या फ़ोल्डर, डिफ़ॉल्ट रूप से``inputFile``के साथ``'.exe'``एक्सटेंशन के साथ।"
			CompilerOptions	 = "अतिरिक्त कंपाइलर विकल्प (देखें ``https://msdn.microsoft.com/en-us/library/78f4aasd.aspx``)"
			TempDir			 = "सामयिक फ़ाइलें संग्रहित करने के लिए फ़ोल्डर (डिफ़ॉल्ट रूप से रैंडम फ़ोल्डर में उत्पन्न होने वाला फ़ोल्डर)"
			minifyer		 = "कॉम्पाइल से पहले स्क्रिप्ट को कम करने के लिए स्क्रिप्ट ब्लॉक"
			lcid			 = "कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल का स्थानीयभाषा आईडी। अगर निर्दिष्ट नहीं किया गया है, तो वर्तमान उपयोगकर्ता संस्कृति कोड होगा"
			prepareDebug	 = "डीबगिंग के लिए मददगार जानकारी बनाएं"
			architecture	 = "केवल विशेष रनटाइम के लिए कॉम्पाइल करें। संभावित मान हैं``'x64'``,``'x86'``और``'anycpu'``"
			threadingModel	 = "``'STA'``या``'MTA'``मॉडल"
			noConsole		 = "निर्मित एक्सीक्यूटेबल फ़ाइल एक विंडोज फ़ॉर्म्स एप्लिकेशन होगी जिसमें कोई कंसोल विंडो नहीं होगी"
			UNICODEEncoding	 = "कंसोल मोड में आउटपुट को यूनिकोड में कोड करें"
			credentialGUI	 = "कंसोल मोड में GUI क्रेडेंशल का उपयोग करें"
			resourceParams	 = "कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल के संसाधन पैरामीटर शामिल करें"
			configFile		 = "एक कॉन्फ़िगरेशन फ़ाइल लिखें (``<आउटपुटफ़ाइल>.exe.config``)"
			noOutput		 = "निर्मित एक्सीक्यूटेबल फ़ाइल में स्टैंडर्ड आउटपुट (सहित विस्तारित और सूचना चैनल) नहीं बनेगा"
			noError			 = "निर्मित एक्सीक्यूटेबल फ़ाइल में त्रुटि आउटपुट (सहित चेतावनी और डीबग चैनल) नहीं बनेगा"
			noVisualStyles	 = "निर्मित एक्सीक्यूटेबल फ़ाइल के विजुअल स्टाइल को अक्षम करें (केवल``-noConsole``के साथ उपयोग किए जाने वाला)"
			exitOnCancel	 = '`Read-Host`इनपुट बॉक्स में`Cancel`या`"X"` का चयन करते समय प्रोग्राम से बाहर निकलें (केवल`-noConsole`के साथ उपयोग किए जाने वाला)'
			DPIAware		 = "अगर प्रदर्शन माप शुरू है, तो GUI विजेट्स को जितना संभव हो सकता है स्केल करेगा"
			winFormsDPIAware = "अगर प्रदर्शन माप शुरू है, तो WinForms DPI स्केलिंग का उपयोग करेगा (Windows 10 और.Net 4.7 या इससे ऊपर की आवश्यकता है)"
			requireAdmin	 = "अगर UAC सक्षम है, तो कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल को सिर्फ उच्चाधिकार कांटेक्स्ट में चलाया जा सकेगा (आवश्यकता होने पर, UAC संवाद बॉक्स प्रकट होगा)"
			supportOS		 = "नवीनतम Windows संस्करण की विशेषताओं का उपयोग करें (विभिन्नता देखने के लिए``[Environment]::OSVersion``का चालन करें)"
			virtualize		 = "ऐप्लिकेशन वर्चुअलाईजेशन सक्रिय कर दिया गया है (एक्स86 रनटाइम को प्रयोगशाला माना)"
			longPaths		 = "यदि ऑपरेटिंग सिस्टम पर सक्षम है, तो लंबी पथ (अधिकतम 260 वर्ण) को सक्षम करें (केवल Windows 10 या इससे ऊपर के लिए)"
			targetRuntime	 = "लक्ष्य रनटाइम संस्करण, डिफ़ॉल्ट रूप से 'Framework4.0', 'Framework2.0' समर्थित हैं"
			GuestMode		 = "एक्सट्रा सुरक्षा के साथ स्क्रिप्ट को कॉम्पाइल करें, स्थानीय फ़ाइलों की पहुँच को टालें"
			Localize		 = "स्थानीयकरण भाषा कोड की निर्दिष्टि करें"
			Help			 = "इस मदद सूचना को दिखाएँ"
		}
	}
	CompilingI18nData = @{
		NoneInput = "कोई इनपुट फ़ाइल निर्दिष्ट नहीं है!"
		BothInputAndContentSpecified = "इनपुट फ़ाइल और सामग्री का उपयोग एक साथ नहीं किया जा सकता है!"
		PreprocessDone = "इनपुट स्क्रिप्ट को प्रीप्रोसेस करना पूर्ण हुआ"
		PreprocessedScriptSize = "प्रीप्रोसेस्ड स्क्रिप्ट -> {0} बाइट्स"
		MinifyingScript = "स्क्रिप्ट को छोटा किया जा रहा है..."
		MinifyedScriptSize = "छोटा किया गया स्क्रिप्ट -> {0} बाइट्स"
		MinifyerError = "छोटा करने वाला त्रुटि: {0}"
		MinifyerFailedUsingOriginalScript = "छोटा करने वाला विफल, मूल स्क्रिप्ट का उपयोग करना।"
		TempFileMissing = "अस्थायी फ़ाइल {0} नहीं मिली!"
		CombinedArg_x86_x64 = "-x86 का उपयोग -x64 के साथ नहीं किया जा सकता"
		CombinedArg_Runtime20_Runtime40 = "-runtime20 का उपयोग -runtime40 के साथ नहीं किया जा सकता"
		CombinedArg_Runtime20_LongPaths = "लंबे पथ केवल .Net 4 या उसके बाद के संस्करण के साथ उपलब्ध हैं"
		CombinedArg_Runtime20_winFormsDPIAware = "DPI जागरूकता केवल .Net 4 या उसके बाद के संस्करण के साथ उपलब्ध है"
		CombinedArg_STA_MTA = "-STA का उपयोग -MTA के साथ नहीं किया जा सकता"
		InvalidResourceParam = "पैरामीटर -resourceParams में एक अमान्य कुंजी है: {0}"
		CombinedArg_ConfigFileYes_No = "-configFile का उपयोग -noConfigFile के साथ नहीं किया जा सकता"
		InputSyntaxError = "स्क्रिप्ट में वाक्य रचना त्रुटि: {0}"
		IdenticalInputOutput = "इनपुट फ़ाइल आउटपुट फ़ाइल के समान है!"
		CombinedArg_Virtualize_requireAdmin = "-virtualize का उपयोग -requireAdmin के साथ नहीं किया जा सकता"
		CombinedArg_Virtualize_supportOS = "-virtualize का उपयोग -supportOS के साथ नहीं किया जा सकता"
		CombinedArg_Virtualize_longPaths = "-virtualize का उपयोग -longPaths के साथ नहीं किया जा सकता"
		CombinedArg_NoConfigFile_LongPaths = "एक कॉन्फ़िगरेशन फ़ाइल के निर्माण को मजबूर करना, क्योंकि विकल्प -longPaths को इसकी आवश्यकता होती है"
		CombinedArg_NoConfigFile_winFormsDPIAware = "एक कॉन्फ़िगरेशन फ़ाइल के निर्माण को मजबूर करना, क्योंकि विकल्प -winFormsDPIAware को इसकी आवश्यकता होती है"
		SomeCmdletsMayNotAvailable = "उपयोग किए गए Cmdlets {0} लेकिन रनटाइम में उपलब्ध नहीं हो सकते हैं, सुनिश्चित करें कि आपने उनकी जांच की है!"
		SomeNotFindedCmdlets = "अज्ञात कार्यों {0} का उपयोग किया गया"
		CompilingFile = "संकलन..."
		CompilationFailed = "संकलन विफल!"
		OutputFileNotWritten = "आउटपुट फ़ाइल {0} नहीं लिखी गई"
		CompiledFileSize = "संकलित फ़ाइल लिखी गई -> {0} बाइट्स"
		OppsSomethingWentWrong = "ओह, कुछ गलत हो गया।"
		TryUpgrade = "नवीनतम संस्करण {0} है, इसे अपग्रेड करने का प्रयास करें?"
		EnterToSubmitIssue = "मदद के लिए, कृपया एक समस्या सबमिट करने के लिए Enter दबाएं।"
		GuestModeFileTooLarge = "फ़ाइल {0} पढ़ने के लिए बहुत बड़ी है।"
		GuestModeIconFileTooLarge = "आइकन {0} पढ़ने के लिए बहुत बड़ा है।"
		GuestModeFtpNotSupported = "FTP को GuestMode में समर्थित नहीं किया जाता है।"
		IconFileNotFound = "आइकन फ़ाइल नहीं मिली: {0}"
		ReadFileFailed = "फ़ाइल को पढ़ने में विफल: {0}"
		PreprocessUnknownIfCondition = "अज्ञात स्थिति: {0}`nमान लिया गया फाल्स।"
		PreprocessMissingEndIf = "endif की कमी: {0}"
		ConfigFileCreated = "EXE के लिए कॉन्फ़िगरेशन फ़ाइल बनाई गई"
		SourceFileCopied = "डिबग के लिए स्रोत फ़ाइल नाम कॉपी किया गया: {0}"
		RoslynFailedFallback = "Roslyn CodeAnalysis विफल`nWindows PowerShell के साथ CodeDom का उपयोग करके वापस गिर रहा है...`nआप भविष्य में इस फ़ॉलबैक को छोड़ने के लिए तर्कों में -UseWindowsPowerShell जोड़ना चाह सकते हैं`n...या ps12exe रिपॉजिटरी में PR सबमिट करें इसे ठीक करने के लिए!"
		ReadingScript = "फ़ाइल {0} आकार {1} बाइट्स पढ़ रहा है"
		ForceX86byVirtualization = "अनुप्रयोग वर्चुअलाइजेशन सक्रिय है, x86 प्लेटफ़ॉर्म को मजबूर कर रहा है।"
		TryingTinySharpCompile = "स्थिरांक परिणाम, TinySharp संकलक का प्रयास कर रहा है..."
		TinySharpFailedFallback = "TinySharp संकलक त्रुटि, सामान्य प्रोग्राम फ्रेम पर वापस गिरें"
		OutputPath = "पथ: {0}"
		ReadingScriptDone = "फ़ाइल {0} पढ़ना पूर्ण, प्रीप्रोसेसिंग शुरू करना..."
		PreprocessScriptDone = "पूर्व-प्रक्रिया फ़ाइल {0} पूर्ण हुई"
		ConstEvalStart = "स्थिरांकों का मूल्यांकन..."
		ConstEvalDone = "स्थिरांकों का मूल्यांकन पूर्ण -> {0} बाइट्स"
		ConstEvalTooLongFallback = "स्थिरांक परिणाम बहुत लंबा है, सामान्य प्रोग्राम फ्रेम पर वापस आ रहा है"
		ConstEvalTimeoutFallback = "स्थिरांक मूल्यांकन {0} सेकंड के बाद समय समाप्त हो गया, सामान्य प्रोग्राम फ्रेम पर वापस आ रहा है"
		InvalidArchitecture = "अमान्य प्लेटफ़ॉर्म {0}, AnyCpu का उपयोग करके"
		UnknownPragma = "अज्ञात pragma: {0}"
		UnknownPragmaBadParameterType = "अज्ञात pragma: {0}, प्रकार {1} का विश्लेषण नहीं किया जा सकता है।"
		UnknownPragmaBoolValue = "अज्ञात pragma मान: {0}, इसे बूलियन के रूप में नहीं ले सकता।"
		DllExportDelNoneTypeArg = "{0}: {1} एक गैर-प्रकार का पैरामीटर है, मान लें कि यह एक स्ट्रिंग है।"
		DllExportUsing = "आप #_DllExport का उपयोग कर रहे हैं, यह मैक्रो अभी भी विकास के अधीन है और अभी तक समर्थित नहीं है।"
	}
	WebServerI18nData = @{
		CompilingUserInput = "उपयोगकर्ता इनपुट संकलित कर रहा है: {0}"
		EmptyResponse = "अनुरोध को संभालते समय कोई डेटा नहीं मिला, खाली प्रतिक्रिया लौटा रहा है"
		InputTooLarge413 = "उपयोगकर्ता इनपुट बहुत बड़ा है, 413 त्रुटि लौटा रहा है"
		ReqLimitExceeded429 = "IP {0} ने प्रति मिनट {1} अनुरोधों की सीमा पार कर ली है, 429 त्रुटि लौटा रहा है"
	}
}
