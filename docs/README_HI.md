# ps12exe

> [!CAUTION]
> सोर्स कोड में पासवर्ड स्टोर न करें!  
> अधिक जानकारी के लिए [यहाँ](#पासवर्ड-सुरक्षा) देखें।

## परिचय

ps12exe एक PowerShell मॉड्यूल है जो आपको .ps1 स्क्रिप्ट से निष्पादन योग्य फ़ाइलें बनाने की अनुमति देता है।

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![रेपो img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./README_CN.md)
[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./README_EN_UK.md)
[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./README_EN_US.md)
[![日本语](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)

## स्थापित करना

```powershell
Install-Module ps12exe #ps12exe मॉड्यूल इंस्टॉल करें
Set-ps12exeContextMenu #राइट-क्लिक मेनू सेट करें
```

(आप इस रिपॉजिटरी को क्लोन भी कर सकते हैं और सीधे `.\ps12exe.ps1` चला सकते हैं)

**PS2EXE से ps12exe में अपग्रेड करना कठिन है? कोई समस्या नहीं!**  
PS2EXE2ps12exe PS2EXE के कॉल्स को ps12exe में हुक कर सकता है। आपको बस PS2EXE को अनइंस्टॉल करना है और इसे इंस्टॉल करना है, फिर आप PS2EXE को सामान्य रूप से उपयोग कर सकते हैं।

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## निर्देश

### मेनू पर राइट-क्लिक करें

एक बार जब आप `Set-ps12exeContextMenu` सेट कर लेते हैं, तो आप किसी भी ps1 फ़ाइल को राइट-क्लिक करके जल्दी से exe में संकलित कर सकते हैं या इस फ़ाइल के लिए ps12exeGUI खोल सकते हैं।  
![चित्र](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### जीयूआई मोड

```powershell
ps12exeGUI
```

### कंसोल मोड

```powershell
ps12exe .\source.ps1 .\target.exe
```

`source.ps1` को `target.exe` पर संकलित करें (यदि `.\target.exe` को छोड़ दिया गया है, तो आउटपुट `.\source.exe` पर लिखा जाएगा)।

```powershell
'"Hello World!"' | ps12exe
```

`"Hello World!"` को एक निष्पादन योग्य फ़ाइल में संकलित करें और इसे `.\a.exe` पर आउटपुट करें।

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

इंटरनेट से `Main.ps1` को एक निष्पादन योग्य फ़ाइल में संकलित करें और इसे `.\Main.exe` पर आउटपुट करें।

### स्व-होस्टेड वेब सेवा

```powershell
Start-ps12exeWebServer
```

एक वेब सेवा प्रारंभ करें जो उपयोगकर्ताओं को पॉवरशेल कोड को ऑनलाइन संकलित करने की अनुमति देती है।

### exe से ps1 पुनर्प्राप्त करें (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` ps12exe द्वारा बनाए गए exe के अंदर से PowerShell स्क्रिप्ट निकालकर उसे `.ps1` फ़ाइल के रूप में या मानक आउटपुट पर वापस लिख देता है। ps12exe की तरह यह भी `$LastExitCode` इस्तेमाल करता है: 0 = सफलता, 1 = इनपुट/पार्स त्रुटि (जैसे ps12exe exe नहीं), 2 = इनवोकेशन त्रुटि (जैसे रीडायरेक्ट होने पर इनपुट नहीं), 3 = रिसोर्स/आंतरिक त्रुटि (जैसे फ़ाइल नहीं मिली)।

### पाइपलाइन और रीडायरेक्शन

- **ps12exe**: जब stdout (या stdin/stderr) रीडायरेक्ट होता है, तो ps12exe केवल जनरेट किए गए exe का पथ stdout पर लिखता है ताकि आप उसे कैप्चर कर सकें (जैसे `$exe = ps12exe .\a.ps1`)।
- **exe21sp**: पाइपलाइन इनपुट से exe पथ स्वीकार करता है (जैसे `Get-ChildItem *.exe | exe21sp` या `".\app.exe" | exe21sp`)।
- **exe21sp**: यदि `-outputFile` निर्दिष्ट नहीं है और stdout रीडायरेक्ट **नहीं** है, तो डीकंपाइल स्क्रिप्ट exe के समान नाम की `.ps1` फ़ाइल में उसी फ़ोल्डर में सहेजी जाती है।
- **exe21sp**: यदि `-outputFile` निर्दिष्ट नहीं है और stdout रीडायरेक्ट **है**, तो डीकंपाइल स्क्रिप्ट stdout पर लिखी जाती है।

## पैरामीटर्स

### जीयूआई पैरामीटर

```powershell
ps12exeGUI [[-ConfigFile] '<कॉन्फ़िगरेशन फ़ाइल>'] [-PS1File '<स्क्रिप्ट फ़ाइल>'] [-Localize '<भाषा कोड>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<स्क्रिप्ट फाइल>'] [-Localize '<भाषा कोड>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : लोड करने के लिए कॉन्फ़िगरेशन फ़ाइल।
PS1File    : कंपाइल करने के लिए स्क्रिप्ट फ़ाइल।
Localize   : उपयोग किया जाने वाला भाषा कोड।
UIMode     : उपयोग किया जाने वाला उपयोगकर्ता इंटरफेस मोड।
help       : इस मदद सूचना को दिखाएँ।
```

### कंसोल पैरामीटर

```powershell
[input |] ps12exe [[-inputFile] '<फ़ाइल नाम|url>' | -Content '<स्क्रिप्ट>'] [-outputFile '<फ़ाइल नाम>']
        [-CompilerOptions '<विकल्प>'] [-TempDir '<फ़ोल्डर>'] [-minifyer '<स्क्रिप्टब्लॉक>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<फ़ाइल नाम|url>'; title='<शीर्षक>'; description='<सारांश>'; company='<कंपनी>';
        product='<उत्पाद>'; copyright='<कॉपीराइट>'; trademark='<नामकरण>'; version='<संस्करण>'}]
        [-CodeSigning @{Path='<PFX फ़ाइल पथ>'; Password='<PFX पासवर्ड>'; Thumbprint='<प्रमाणपत्र फ़िंगरप्रिंट>'; TimestampServer='<समय चिह्न सर्वर>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<रनटाइम संस्करण>']
        [-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<भाषा कोड>'] [-help]
```

```text
input            : PowerShell स्क्रिप्ट फ़ाइल की सामग्री का स्ट्रिंग, -Content के समान
inputFile        : जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट फ़ाइल का पथ या URL (फ़ाइल को UTF8 या UTF16 एन्कोड किया गया होना चाहिए)
Content          : जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट की सामग्री
outputFile       : लक्षित एक्सीक्यूटेबल फ़ाइल का नाम या फ़ोल्डर, डिफ़ॉल्ट रूप से inputFile के साथ '.exe' एक्सटेंशन के साथ
CompilerOptions  : अतिरिक्त कंपाइलर विकल्प (देखें https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)
TempDir          : सामयिक फ़ाइलें संग्रहित करने के लिए फ़ोल्डर (डिफ़ॉल्ट रूप से रैंडम फ़ोल्डर में उत्पन्न होने वाला फ़ोल्डर)
minifyer         : कॉम्पाइल से पहले स्क्रिप्ट को कम करने के लिए स्क्रिप्ट ब्लॉक
lcid             : कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल का स्थानीयभाषा आईडी। अगर निर्दिष्ट नहीं किया गया है, तो वर्तमान उपयोगकर्ता संस्कृति कोड होगा
prepareDebug     : डीबगिंग के लिए मददगार जानकारी बनाएं
architecture     : केवल विशेष रनटाइम के लिए कॉम्पाइल करें। संभावित मान हैं 'x64', 'x86' और 'anycpu'
threadingModel   : 'STA' या 'MTA' मॉडल
noConsole        : निर्मित एक्सीक्यूटेबल फ़ाइल एक विंडोज फ़ॉर्म्स एप्लिकेशन होगी जिसमें कोई कंसोल विंडो नहीं होगी
UNICODEEncoding  : कंसोल मोड में आउटपुट को यूनिकोड में कोड करें
credentialGUI    : कंसोल मोड में GUI क्रेडेंशल का उपयोग करें
resourceParams   : कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल के संसाधन पैरामीटर शामिल करें
CodeSigning      : संकलित निष्पादन योग्य फ़ाइल के लिए कोड हस्ताक्षर विकल्प शामिल करने वाली हैश तालिका
configFile       : एक कॉन्फ़िगरेशन फ़ाइल लिखें (<आउटपुटफ़ाइल>.exe.config)
noOutput         : निर्मित एक्सीक्यूटेबल फ़ाइल में स्टैंडर्ड आउटपुट (सहित विस्तारित और सूचना चैनल) नहीं बनेगा
noError          : निर्मित एक्सीक्यूटेबल फ़ाइल में त्रुटि आउटपुट (सहित चेतावनी और डीबग चैनल) नहीं बनेगा
noVisualStyles   : निर्मित एक्सीक्यूटेबल फ़ाइल के विजुअल स्टाइल को अक्षम करें (केवल -noConsole के साथ उपयोग किए जाने वाला)
exitOnCancel     : Read-Host इनपुट बॉक्स में Cancel या 'X' का चयन करते समय प्रोग्राम से बाहर निकलें (केवल -noConsole के साथ उपयोग किए जाने वाला)
DPIAware         : अगर प्रदर्शन माप शुरू है, तो GUI विजेट्स को जितना संभव हो सकता है स्केल करेगा
winFormsDPIAware : अगर प्रदर्शन माप शुरू है, तो WinForms DPI स्केलिंग का उपयोग करेगा (Windows 10 और.Net 4.7 या इससे ऊपर की आवश्यकता है)
requireAdmin     : अगर UAC सक्षम है, तो कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल को सिर्फ उच्चाधिकार कांटेक्स्ट में चलाया जा सकेगा (आवश्यकता होने पर, UAC संवाद बॉक्स प्रकट होगा)
supportOS        : नवीनतम Windows संस्करण की विशेषताओं का उपयोग करें (विभिन्नता देखने के लिए [Environment]::OSVersion का चालन करें)
virtualize       : ऐप्लिकेशन वर्चुअलाईजेशन सक्रिय कर दिया गया है (एक्स86 रनटाइम को प्रयोगशाला माना)
longPaths        : यदि ऑपरेटिंग सिस्टम पर सक्षम है, तो लंबी पथ (अधिकतम 260 वर्ण) को सक्षम करें (केवल Windows 10 या इससे ऊपर के लिए)
targetRuntime    : लक्ष्य रनटाइम संस्करण, डिफ़ॉल्ट रूप से 'Framework4.0', 'Framework2.0' समर्थित हैं
SkipVersionCheck : ps12exe के नए संस्करण की जाँच छोड़ें
GuestMode        : एक्सट्रा सुरक्षा के साथ स्क्रिप्ट को कॉम्पाइल करें, स्थानीय फ़ाइलों की पहुँच को टालें
PreprocessOnly   : इनपुट स्क्रिप्ट को प्रीप्रोसेस करें और इसे संकलित किए बिना वापस करें।
GolfMode         : गोल्फ मोड सक्षम करें, अधिकतम संख्या और सामान्य फंक्शनों को जोड़ें
Localize         : स्थानीयकरण भाषा कोड की निर्दिष्टि करें
Help             : इस मदद सूचना को दिखाएँ
```

## टिप्पणी

### त्रुटि प्रबंधन

अधिकांश PowerShell फ़ंक्शंस के विपरीत, ps12exe त्रुटियों को इंगित करने के लिए `$LastExitCode` चर सेट करता है, लेकिन यह गारंटी नहीं देता है कि कोई अपवाद बिल्कुल नहीं फेंका जाएगा।  
आप त्रुटि हुई है या नहीं, यह जांचने के लिए निम्न के समान उपयोग कर सकते हैं:

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe निकास कोड $LastExitCode के साथ विफल रहा"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

विभिन्न `$LastExitCode` मान विभिन्न प्रकार की त्रुटियों का प्रतिनिधित्व करते हैं:

| त्रुटि प्रकार | `$LastExitCode` मान   |
| ------------- | --------------------- |
| 0             | कोई त्रुटि नहीं       |
| 1             | इनपुट कोड त्रुटि      |
| 2             | कॉल स्वरूप त्रुटि     |
| 3             | ps12exe आंतरिक त्रुटि |

### प्रीप्रोसेसिंग

ps12exe संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करेगा।

```powershell
# Read the program frame from the ps12exe.cs file
#_if PSEXE #यह प्रीप्रोसेसिंग कोड है जिसका उपयोग तब किया जाता है जब स्क्रिप्ट को ps12exe द्वारा संकलित किया जाता है
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #ps12exe.cs में सामग्री को स्क्रिप्ट में एम्बेड करें
#_else #अन्यथा सीएस फ़ाइल को सामान्य रूप से पढ़ें
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

वर्तमान में केवल निम्नलिखित स्थितियाँ समर्थित हैं: `PSEXE` और `PSScript`।  
`PSEXE` के लिए सही; `PSScript` के लिए गलत।

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

स्क्रिप्ट में फ़ाइल `<filename|url>` या `<file|url>` की सामग्री शामिल करें। फ़ाइल की सामग्री `#_include`/`#_include_as_value` कमांड के स्थान पर डाली गई है।

`#_if` कथन के विपरीत, यदि आप फ़ाइल नाम संलग्न करने के लिए उद्धरण चिह्नों का उपयोग नहीं करते हैं, तो प्रीप्रोसेसिंग कमांड की `#_include` श्रृंखला अनुगामी रिक्त स्थान और `#` को फ़ाइल नाम के भाग के रूप में मानेगी।

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #सुरक्षित टिप्पणी!
```

`#_include` का उपयोग करते समय, फ़ाइल सामग्री पूर्व-संसाधित होती है, जिससे आप कई स्तरों पर फ़ाइलें शामिल कर सकते हैं।

`#_include_as_value` फ़ाइल सामग्री को स्ट्रिंग मान के रूप में स्क्रिप्ट में सम्मिलित करेगा। फ़ाइल सामग्री पूर्व-संसाधित नहीं की जाएगी.

ज्यादातर मामलों में आपको स्क्रिप्ट को exe में परिवर्तित करने के बाद सबस्क्रिप्ट को सही ढंग से शामिल करने के लिए `#_if` और `#_include` प्रीप्रोसेसिंग कमांड का उपयोग करने की आवश्यकता नहीं है। ps12exe स्वचालित रूप से निम्नलिखित स्थितियों को संभाल लेगा और लक्ष्य स्क्रिप्ट पर विचार करेगा इससे निपटने के लिए शामिल किया जाना चाहिए:

```powershell
. $PSScriptRoot/another.ps1
& $PSScriptRoot/another.ps1
$result = & "$PSScriptRoot/another.ps1" -args
```

#### `#_include_as_(base64|bytes) <valuename> <file|url>`

```powershell
#_include_as_base64 <valuename> <file|url>
#_include_as_bytes <valuename> <file|url>
```

प्रीप्रोसेसर समय पर एक फ़ाइल की सामग्री को बेस64 स्ट्रिंग या बाइट सरणी के रूप में स्क्रिप्ट में शामिल करता है। फ़ाइल सामग्री स्वयं प्रीप्रोसेस नहीं की जाती है।

यहाँ एक साधारण पैकर उदाहरण दिया गया है:

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

यह EXE निष्पादन पर संकलन के दौरान स्क्रिप्ट में एम्बेडेड `data.bin` फ़ाइल को निकालेगा।

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript #PSEXE में $EshellUI का होना असंभव है
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

`#_!!` से शुरू होने वाली किसी भी पंक्ति से अग्रणी `#_!!` हटा दिया जाएगा।

#### `#_require <modulesList>`

```powershell
#_require ps12exe
#_pragma Console 0
$Number = [bigint]::Parse('0')
$NextNumber = $Number+1
$NextScript = $PSEXEscript.Replace("Parse('$Number')", "Parse('$NextNumber')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
$Number
```

`#_require` संपूर्ण स्क्रिप्ट में आवश्यक मॉड्यूल की गणना करता है, और पहले `#_require` से पहले निम्नलिखित कोड के बराबर एक स्क्रिप्ट जोड़ता है:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

यह ध्यान देने योग्य है कि यह जो कोड उत्पन्न करता है वह केवल मॉड्यूल स्थापित करेगा, इसे आयात नहीं करेगा।  
कृपया उपयुक्त के रूप में `Import-Module` का उपयोग करें।

जब आपको कई मॉड्यूल की आवश्यकता होती है, तो आप आवश्यक कथनों की कई पंक्तियों को लिखने के बजाय विभाजक के रूप में रिक्त स्थान, अल्पविराम, अर्धविराम और अल्पविराम का उपयोग कर सकते हैं।

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

प्राग्मा प्रीप्रोसेसिंग निर्देश का स्क्रिप्ट सामग्री पर कोई प्रभाव नहीं पड़ता है, लेकिन संकलन के लिए उपयोग किए जाने वाले मापदंडों को संशोधित करेगा।  
यहाँ एक उदाहरण है:

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

जैसा कि आप देख सकते हैं, `#_pragma Console no` जेनरेट की गई exe फ़ाइल को विंडो मोड में चलाने का कारण बनता है, भले ही हम संकलन करते समय `-noConsole` निर्दिष्ट न करें।  
प्राग्मा कमांड कोई भी संकलन पैरामीटर सेट कर सकता है:

```powershell
#_pragma noConsole #विंडो मोड
#_pragma Console #कंसोल मोड
#_pragma Console no #विंडो मोड
#_pragma Console true #कंसोल मोड
#_pragma icon $PSScriptRoot/icon.ico #सेट आइकन
#_pragma title "title" #एक्सई शीर्षक सेट करें
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

जब कोड इस बिंदु पर पहुंचता है, तो प्रक्रिया दिए गए निकास कोड के साथ बाहर निकल जाती है और EXE फ़ाइल को हटा देती है।

### मिनिफ़ायर

चूँकि ps12exe का "संकलन" स्क्रिप्ट में सब कुछ संसाधनों के रूप में उत्पन्न निष्पादन योग्य शब्दशः में एम्बेड करता है, यदि स्क्रिप्ट में बहुत सारे बेकार तार हैं तो परिणामी निष्पादन योग्य बड़ा होगा।  
आप एक स्क्रिप्ट ब्लॉक को निर्दिष्ट करने के लिए `-Minifyer` पैरामीटर का उपयोग कर सकते हैं जो एक छोटे जेनरेटेड निष्पादन योग्य प्राप्त करने के लिए संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करेगा।

यदि आप नहीं जानते कि ऐसा स्क्रिप्ट ब्लॉक कैसे लिखना है, तो आप [psminnifyer](https://github.com/steve02081504/psminnifyer) का उपयोग कर सकते हैं।

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### अकार्यान्वित सीएमडीलेट्स की सूची

PS12exe के लिए मूल इनपुट/आउटपुट कमांड को C# में फिर से लिखना पड़ा। लागू न किए गए लोगों में कंसोल मोड में _`Write-Progress`_ (बहुत अधिक काम) और _`Start-Transcript`_/_`Stop-Transcript`_ (माइक्रोसॉफ्ट के पास उचित संदर्भ कार्यान्वयन नहीं है) शामिल हैं।

### जीयूआई मोड आउटपुट स्वरूप

डिफ़ॉल्ट रूप से, पॉवरशेल में cmdlet आउटपुट को प्रति पंक्ति एक पंक्ति (स्ट्रिंग्स की एक सरणी के रूप में) स्वरूपित किया जाता है। जब कमांड आउटपुट की 10 लाइनें उत्पन्न करता है और जीयूआई आउटपुट का उपयोग करता है, तो 10 संदेश बॉक्स दिखाई देते हैं, प्रत्येक ओके की प्रतीक्षा करते हैं। इससे बचने के लिए, `Out-String` कमांड को कमांड लाइन में आयात करें। यह आउटपुट को 10-लाइन स्ट्रिंग सरणी में परिवर्तित कर देगा, और सभी आउटपुट एक संदेश बॉक्स में प्रदर्शित किया जाएगा (उदाहरण: `dir C:\| Out-String`)।

### विन्यास फाइल

ps12exe `जनरेटेड एक्ज़ीक्यूटेबल + ".config"` नाम से एक कॉन्फ़िगरेशन फ़ाइल बना सकता है। ज्यादातर मामलों में, इन कॉन्फ़िगरेशन फ़ाइलों की आवश्यकता नहीं होती है, वे केवल एक चेकलिस्ट हैं जो आपको बताती हैं कि आपको कौन सा .नेट फ्रेमवर्क संस्करण उपयोग करना चाहिए। चूँकि आप आमतौर पर वास्तविक .Net फ्रेमवर्क का उपयोग कर रहे होंगे, कॉन्फ़िगरेशन फ़ाइल के बिना अपने निष्पादन योग्य को चलाने का प्रयास करें।

### पैरामीटर प्रोसेसिंग

संकलित स्क्रिप्ट मूल स्क्रिप्ट की तरह ही मापदंडों को संभालती है। एक सीमा विंडोज वातावरण से आती है: सभी निष्पादन योग्य के लिए, सभी पैरामीटर स्ट्रिंग प्रकार के होते हैं, और यदि पैरामीटर प्रकार को अंतर्निहित रूप से परिवर्तित नहीं किया जाता है, तो इसे स्क्रिप्ट में स्पष्ट रूप से परिवर्तित किया जाना चाहिए। आप सामग्री को निष्पादन योग्य में भी पाइप कर सकते हैं, लेकिन समान सीमाओं के साथ (सभी पाइप किए गए मान स्ट्रिंग प्रकार के हैं)।

### पासवर्ड सुरक्षा

<a id="password-security-stuff"></a>
कभी भी संकलित स्क्रिप्ट में पासवर्ड संग्रहीत न करें!  
संपूर्ण स्क्रिप्ट किसी भी .net डिकंपाइलर को आसानी से दिखाई देती है।  
![चित्र](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### स्क्रिप्ट के आधार पर वातावरण में अंतर करें

आप `$Host.Name` द्वारा बता सकते हैं कि स्क्रिप्ट संकलित exe में चल रही है या स्क्रिप्ट में।

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### स्क्रिप्ट चर

चूँकि ps12exe स्क्रिप्ट को एक निष्पादन योग्य फ़ाइल में परिवर्तित करता है, वेरिएबल `$MyInvocation` का मान स्क्रिप्ट में मौजूद मान से भिन्न होता है।

आप अभी भी उस निर्देशिका का पथ प्राप्त करने के लिए `$PSScriptRoot` का उपयोग कर सकते हैं जहां निष्पादन योग्य स्थित है, और निष्पादन योग्य का पथ प्राप्त करने के लिए `$PSCommandPath` का उपयोग कर सकते हैं।

### बैकग्राउंड विंडो -नोकंसोल मोड में

`-noConsole` मोड (जैसे `Get-Credential` या `cmd.exe` की आवश्यकता वाले कमांड) का उपयोग करके स्क्रिप्ट में एक बाहरी विंडो खोलने पर, पृष्ठभूमि में एक विंडो खोली जाएगी।

इसका कारण यह है कि बाहरी विंडो बंद करते समय, विंडोज़ मूल विंडो को सक्रिय करने का प्रयास करता है। क्योंकि संकलित स्क्रिप्ट में कोई विंडो नहीं है, संकलित स्क्रिप्ट की मूल विंडो सक्रिय होती है, आमतौर पर एक्सप्लोरर या पावरशेल की विंडो।

इस समस्या को हल करने के लिए, आप एक अदृश्य विंडो खोलने के लिए `$Host.UI.RawUI.FlushInputBuffer()` का उपयोग कर सकते हैं जिसे सक्रिय किया जा सकता है। `$Host.UI.RawUI.FlushInputBuffer()` पर बाद में कॉल करने से विंडो बंद हो जाएगी (और इसी तरह)।

केवल एक बार `ipconfig | Out-String` को कॉल करने के विपरीत, निम्न उदाहरण अब पृष्ठभूमि में विंडो नहीं खोलेगा:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

## फायदों की तुलना 🏆

### त्वरित तुलना 🏁

| तुलना सामग्री                                       | ps12exe                                                   | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --------------------------------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| शुद्ध स्क्रिप्ट भंडार 📦                            | ✔️छवियों और निर्भरताओं को छोड़कर, सभी टेक्स्ट फ़ाइलें हैं | ❌ओपन सोर्स लाइसेंस के साथ exe फ़ाइलें शामिल हैं                                                                |
| हेलो वर्ल्ड उत्पन्न करने के लिए आवश्यक कमांड 🌍     | 😎`'"Hello world!"' \| ps12exe`                           | 🤔`echo "Hello world!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                                        |
| उत्पन्न हैलो वर्ल्ड निष्पादन योग्य फ़ाइल का आकार 💾 | 🥰1024 बाइट्स                                             | 😨25088 बाइट्स                                                                                                  |
| जीयूआई बहु-भाषा समर्थन 🌐                           | ✔️                                                        | ❌                                                                                                              |
| संकलन-समय सिंटैक्स जाँच ✔️                          | ✔️                                                        | ❌                                                                                                              |
| प्रीप्रोसेसिंग फ़ंक्शन 🔄                           | ✔️                                                        | ❌                                                                                                              |
| `-extract` जैसे विशेष मापदंडों का विश्लेषण 🧹       | 🗑️हटाया गया                                               | 🥲स्रोत कोड को संशोधित करने की आवश्यकता है                                                                      |
| पीआर का स्वागत है 🤝                                | 🥰स्वागत है!                                              | 🤷14 पीआर, उनमें से 13 बंद                                                                                      |

### विस्तृत तुलना 🔍

[`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) की तुलना में, यह प्रोजेक्ट निम्नलिखित सुधार लाता है:

| सुधार                                                                 | विवरण                                                                                                                   |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| ✔️ संकलन समय पर सिंटेक्स जांच                                         | कोड गुणवत्ता में सुधार के लिए संकलन समय पर सिंटेक्स जांच                                                                |
| 🔄 शक्तिशाली प्रीप्रोसेसिंग फ़ंक्शन                                   | संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करें, स्क्रिप्ट में सब कुछ कॉपी और पेस्ट करने की आवश्यकता नहीं है                |
| 🛠️ `-CompilerOptions` पैरामीटर                                        | नए पैरामीटर आपको जेनरेट की गई निष्पादन योग्य फ़ाइल को और अधिक अनुकूलित करने की अनुमति देते हैं                          |
| 📦️ `-मिनिफ़ायर` पैरामीटर                                             | एक छोटी निष्पादन योग्य फ़ाइल उत्पन्न करने के लिए संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करें                            |
| 🌐 स्क्रिप्ट संकलित करने में सहायता करें और URL से फ़ाइलें शामिल करें | URL से आइकन डाउनलोड करने में सहायता करें                                                                                |
| 🖥️ `-noConsole` पैरामीटर अनुकूलन                                      | अनुकूलित विकल्प प्रसंस्करण और विंडो शीर्षक प्रदर्शन, अब आप सेटिंग द्वारा पॉप-अप विंडो के शीर्षक को अनुकूलित कर सकते हैं |
| 🧹 exe फ़ाइल हटा दी गई                                                | कोड रिपॉजिटरी से exe फ़ाइल हटा दी गई                                                                                    |
| 🌍 बहु-भाषा समर्थन, शुद्ध स्क्रिप्ट जीयूआई                            | बेहतर बहु-भाषा समर्थन, शुद्ध स्क्रिप्ट जीयूआई, डार्क मोड का समर्थन करता है                                              |
| 📖 सीएस फाइलों को पीएस1 फाइलों से अलग करें                            | पढ़ने और बनाए रखने में आसान                                                                                             |
| 🚀 अधिक सुधार                                                         | और अधिक...                                                                                                              |
