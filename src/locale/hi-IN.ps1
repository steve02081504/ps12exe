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
	[-ReqLimitPerMin '<uint>'] [-MaxCachedFileSize '<uint>'] [-MaxScriptFileSize '<uint>']
	[-Localize '<भाषा कोड>'] [-help]"
		PrarmsData = [ordered]@{
			HostUrl			  = "रजिस्टर करने के लिए HTTP सर्वर पता।"
			MaxCompileThreads = "अधिकतम कॉम्पाइल धागों की संख्या।"
			MaxCompileTime	  = "अधिकतम कॉम्पाइल समय (सेकंड)।"
			ReqLimitPerMin	  = "फ़ाइल प्रति मिनट की अनुरोध सीमा।"
			MaxCachedFileSize = "अधिकतम कैश फ़ाइल का आकार।"
			MaxScriptFileSize = "अधिकतम स्क्रिप्ट फ़ाइल का आकार।"
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
}
