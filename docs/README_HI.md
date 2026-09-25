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
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)

## इसका उपयोग करने वाले

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## स्थापित करना

```powershell
Install-Module ps12exe #ps12exe मॉड्यूल इंस्टॉल करें
Set-ps12exeIntegration #राइट-क्लिक मेनू, Agent Skill और VS Code एक्सटेंशन सेट करें
```

(आप इस रिपॉजिटरी को क्लोन भी कर सकते हैं और सीधे `.\ps12exe.ps1` चला सकते हैं)

**PS2EXE से ps12exe में अपग्रेड करना कठिन है? कोई समस्या नहीं!**  
PS2EXE2ps12exe PS2EXE के कॉल्स को ps12exe में हुक कर सकता है। आपको बस PS2EXE को अनइंस्टॉल करना है और इसे इंस्टॉल करना है, फिर आप PS2EXE को सामान्य रूप से उपयोग कर सकते हैं।  
यह हर PS2EXE संस्करण के पैरामीटर (`conHost`, `embedFiles` और पुराने `runtime20`/`runtime40` सहित) के साथ अधिकतम अनुकूलता का लक्ष्य रखता है; ps12exe में न मौजूद क्षमताएँ संकलन समय पर फिर से लिखी जाती हैं।

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## निर्देश

### मेनू पर राइट-क्लिक करें

एक बार जब आप `Set-ps12exeIntegration` चला लेते हैं, तो आप किसी भी ps1 फ़ाइल को राइट-क्लिक करके जल्दी से exe में संकलित कर सकते हैं या इस फ़ाइल के लिए ps12exeGUI खोल सकते हैं।  
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

ऐसी वेब सेवा शुरू करें जिससे उपयोगकर्ता ऑनलाइन PowerShell कोड संकलित कर सकें।

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

### VS Code एक्सटेंशन

[ps12exe VS Code एक्सटेंशन](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe) आपको एडिटर छोड़े बिना `.ps1` स्क्रिप्ट को एक्ज़ीक्यूटेबल में कंपाइल करने या ps12exeGUI खोलने देता है, और प्रीप्रोसेसर निर्देशों के लिए एडिटर सहायता (सिंटैक्स हाइलाइटिंग, डायग्नोस्टिक्स, `#_if` ऑटो-क्लोज़, फ़ोल्डिंग, परिभाषा पर जाएँ, हॉवर, पूर्णता और फ़ॉर्मेटिंग) जोड़ता है।

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeIntegration` इसे स्वतः इंस्टॉल कर देता है; आप `steve02081504.ps12exe` को मैन्युअल रूप से भी इंस्टॉल कर सकते हैं।

### Agent Skill

`Set-ps12exeIntegration` `~/.agents/skills` में `ps12exe` का Agent Skill भी लिखता है, ताकि Agent Skill समर्थित कोडिंग एजेंट (opencode, Codex, Cursor, GitHub Copilot, …) PowerShell स्क्रिप्ट को एक्ज़ीक्यूटेबल में कंपाइल करने के लिए ps12exe का उपयोग करें। `Set-ps12exeIntegration -action disable` इसे हटा देता है, और `Set-ps12exeIntegration -Skip AgentSkill` इसे छोड़ देता है।

## पैरामीटर्स

### जीयूआई पैरामीटर

```powershell
ps12exeGUI [[-ConfigFile] '<कॉन्फ़िगरेशन फ़ाइल>'] [-PS1File '<स्क्रिप्ट फ़ाइल>'] [-Locale '<भाषा कोड>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<स्क्रिप्ट फाइल>'] [-Locale '<भाषा कोड>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : लोड करने के लिए कॉन्फ़िगरेशन फ़ाइल।
PS1File    : कंपाइल करने के लिए स्क्रिप्ट फ़ाइल।
Locale     : उपयोग किया जाने वाला भाषा कोड।
UIMode     : उपयोग किया जाने वाला उपयोगकर्ता इंटरफेस मोड।
help       : इस मदद सूचना को दिखाएँ।
```

### कंसोल पैरामीटर

<a id="console-parameters"></a>

```powershell
[input |] ps12exe [[-inputFile] '<फ़ाइल नाम|url>' | -Content '<स्क्रिप्ट>'] [-outputFile '<फ़ाइल नाम>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true;
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true; ConHost=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'|'arm64'; Apartment='STA'|'MTA';
        Culture='<संस्कृति>'; Options='<विकल्प>'; KeepSource=$true; Minify={<स्क्रिप्टब्लॉक>}; TempDir='<फ़ोल्डर>';
        Core=@{Backend='Shared'|'Bundled'; TargetOs='Windows'|'Linux'|'MacOS'; TargetFramework='<net8.0>'; PowerShellVersion='<version>'; SingleFile=$true; SelfContained=$true; Trimmed=$true; TrimMode='partial'|'full'; ReadyToRun=$true; InvariantGlobalization=$true; Aot=$true}}]
        [-Resources @{Icon='<फ़ाइल नाम|url>'; Title='<शीर्षक>'; Description='<सारांश>'; Company='<कंपनी>';
        Product='<उत्पाद>'; Copyright='<कॉपीराइट>'; Trademark='<नामकरण>'; Version='<संस्करण>'}]
        [-Signing @{Certificate='<PFX फ़ाइल पथ>'; Password='<PFX पासवर्ड>'; Thumbprint='<प्रमाणपत्र फ़िंगरप्रिंट>'; Timestamp='<समय चिह्न सर्वर>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Quiet] [-Locale '<भाषा कोड>'] [-ConfigFile] [-help]
```

```text
input            : PowerShell स्क्रिप्ट फ़ाइल की सामग्री का स्ट्रिंग, -Content के समान
inputFile        : जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट फ़ाइल का पथ या URL (फ़ाइल को UTF8 या UTF16 एन्कोड किया गया होना चाहिए)
Content          : जिसे आप एक्सीक्यूटेबल फ़ाइल में परिवर्तित करना चाहते हैं, उस PowerShell स्क्रिप्ट की सामग्री
outputFile       : लक्षित एक्सीक्यूटेबल फ़ाइल का नाम या फ़ोल्डर, डिफ़ॉल्ट रूप से inputFile के साथ '.exe' एक्सटेंशन के साथ
App              : उत्पन्न एप्लिकेशन के व्यवहार का वर्णन करने वाली हैश तालिका। समर्थित कुंजियाँ:
                   Windowed         : निर्मित एक्सीक्यूटेबल फ़ाइल एक विंडोज फ़ॉर्म्स एप्लिकेशन होगी जिसमें कोई कंसोल विंडो नहीं होगी।
                   Silence          : शांत किए जाने वाले आउटपुट स्ट्रीम; 'Output', 'Verbose', 'Error', 'Warning', 'Debug' में से एक या अधिक, या सभी के लिए '*'।
                   OutputEncoding   : कंसोल आउटपुट एन्कोडिंग; 'Default', 'UTF8' या 'UTF16LE'।
                   VisualStyles     : GUI एप्लिकेशन के लिए विजुअल स्टाइल सक्षम करें (डिफ़ॉल्ट $true)।
                   ExitOnCancel     : Read-Host इनपुट बॉक्स में Cancel या 'X' का चयन करते समय प्रोग्राम से बाहर निकलें।
                   CredentialGUI    : कंसोल मोड में क्रेडेंशल के लिए GUI का उपयोग करें।
                   DpiAware         : संकलित एक्सीक्यूटेबल फ़ाइल को DPI aware के रूप में चिह्नित करें।
                   WinFormsDpiAware : WinForms को DPI स्केलिंग का उपयोग करने दें (Windows 10 और .Net 4.7 या इससे ऊपर की आवश्यकता है)।
                   ConHost          : Windows Terminal के बजाय conhost कंसोल को बाध्य करें; इनपुट/आउटपुट/त्रुटि रीडायरेक्शन अक्षम हो जाता है।
Os               : ऑपरेटिंग सिस्टम एकीकरण विकल्पों की हैश तालिका। समर्थित कुंजियाँ:
                   Admin            : अगर UAC सक्षम है, तो कॉम्पाइल की गई एक्सीक्यूटेबल फ़ाइल को सिर्फ उच्चाधिकार कांटेक्स्ट में चलाया जा सकेगा (आवश्यकता होने पर, UAC संवाद बॉक्स प्रकट होगा)।
                   ModernOS         : नवीनतम Windows संस्करण की विशेषताओं का उपयोग करें (विभिन्नता देखने के लिए [Environment]::OSVersion का चालन करें)।
                   LongPaths        : यदि ऑपरेटिंग सिस्टम पर सक्षम है, तो लंबी पथ (अधिकतम 260 वर्ण) को सक्षम करें (केवल Windows 10 या इससे ऊपर के लिए)।
                   Virtualize       : ऐप्लिकेशन वर्चुअलाईजेशन सक्रिय कर दिया गया है (एक्स86 रनटाइम को प्रयोगशाला माना)।
Build            : बिल्ड विकल्पों की हैश तालिका। समर्थित कुंजियाँ:
                   Target           : लक्ष्य रनटाइम संस्करण, डिफ़ॉल्ट रूप से 'Framework4.0', 'Framework2.0' और 'Core' समर्थित हैं। 'Core' PowerShell Core (.NET) निष्पादन योग्य बनाता है (कंपाइल और लक्ष्य मशीन दोनों पर PowerShell Core और .NET आवश्यक; आउटपुट बहुत बड़ा होता है)।
                   Platform         : केवल विशेष रनटाइम के लिए कॉम्पाइल करें। संभावित मान हैं 'AnyCpu', 'x64', 'x86' और 'arm64' (arm64 केवल 'Core' के लिए मान्य है)।
                   Apartment        : 'STA' या 'MTA' मॉडल।
                   Culture          : संकलित एक्सीक्यूटेबल फ़ाइल की संस्कृति। अगर निर्दिष्ट नहीं किया गया है, तो वर्तमान उपयोगकर्ता संस्कृति कोड होगा।
                   Options          : अतिरिक्त कंपाइलर विकल्प (देखें https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)।
                   KeepSource       : डीबगिंग के लिए मददगार जानकारी बनाएं।
                   Minify           : कॉम्पाइल से पहले स्क्रिप्ट को कम करने के लिए स्क्रिप्ट ब्लॉक।
                   TempDir          : सामयिक फ़ाइलें संग्रहित करने के लिए फ़ोल्डर (डिफ़ॉल्ट रूप से %temp% में रैंडम फ़ोल्डर)।
                   Core             : 'Core' लक्ष्य बिल्ड के लिए विकल्प। समर्थित कुंजियाँ:
                                      Backend                : 'Shared' (डिफ़ॉल्ट) लक्ष्य मशीन की pwsh स्थापना से PowerShell प्राप्त करता है और आउटपुट छोटा रखता है; 'Bundled' PowerShell SDK (Microsoft.PowerShell.SDK) को बंडल करता है, इसलिए लक्ष्य मशीन को pwsh की आवश्यकता नहीं होती और SelfContained/Trimmed/ReadyToRun/InvariantGlobalization/Aot उपलब्ध हो जाते हैं, पर आउटपुट बहुत बड़ा हो जाता है।
                                      TargetOs               : लक्ष्य ऑपरेटिंग सिस्टम: 'Windows', 'Linux' या 'MacOS' (डिफ़ॉल्ट: बिल्ड मशीन का OS)। GUI/विंडो आउटपुट के लिए 'Windows' आवश्यक है।
                                      TargetFramework        : लक्ष्य .NET फ्रेमवर्क मॉनिकर (उदाहरण 'net8.0')। डिफ़ॉल्ट रूप से बिल्ड मशीन का रनटाइम (Shared) या PowerShellVersion से मैप किया गया फ्रेमवर्क (Bundled)।
                                      PowerShellVersion      : बंडल किए गए PowerShell SDK का संस्करण (केवल Bundled)। डिफ़ॉल्ट रूप से बिल्ड मशीन का PowerShell संस्करण।
                                      SingleFile             : एकल-फ़ाइल एक्सीक्यूटेबल प्रकाशित करें (डिफ़ॉल्ट $true)। $false होने पर, एक्सीक्यूटेबल और उसकी निर्भरताएँ एक फ़ोल्डर के रूप में लिखी जाती हैं।
                                      SelfContained          : .NET रनटाइम शामिल करें (केवल Bundled; डिफ़ॉल्ट $false)। बहुत बड़ा हो जाता है लेकिन स्थापित रनटाइम की आवश्यकता नहीं होती।
                                      Trimmed                : आकार घटाने के लिए IL ट्रिमिंग सक्षम करें (केवल Bundled; डिफ़ॉल्ट $false)।
                                      TrimMode               : Trimmed सेट होने पर ट्रिमिंग की तीव्रता: 'partial' (डिफ़ॉल्ट, सुरक्षित) या 'full' (आक्रामक, प्रतिबिंब तोड़ सकता है)।
                                      ReadyToRun             : तेज़ स्टार्टअप के लिए असेंबली पूर्व-संकलित करें (केवल Bundled)।
                                      InvariantGlobalization : इनवेरिएंट ग्लोबलाइज़ेशन का उपयोग करें, स्व-निहित बिल्ड से ICU लाइब्रेरी हटाएँ (केवल Bundled)।
                                      Aot                    : प्रायोगिक Native AOT संकलन (केवल Bundled; SelfContained आवश्यक)। PowerShell द्वारा उपयोग किया जाने वाला भारी प्रतिबिंब कुछ स्क्रिप्ट तोड़ सकता है।
Resources        : संकलित एक्सीक्यूटेबल फ़ाइल में एम्बेड की गई संस्करण संसाधनों की हैश तालिका (Icon, Title, Description, Company, Product, Copyright, Trademark, Version)। Icon एक आइकन फ़ाइल पथ या URL हो सकता है। .exe/.dll के लिए ,<index> जोड़कर संसाधन आइकन चुनें (डिफ़ॉल्ट 0), जैसे shell32.dll,3।
Signing          : कोड साइनिंग विकल्पों की हैश तालिका (Certificate, Password, Thumbprint, Timestamp)। Certificate या Thumbprint में से एक निर्दिष्ट करना आवश्यक है।
PreprocessOnly   : इनपुट स्क्रिप्ट को प्रीप्रोसेस करें और इसे संकलित किए बिना वापस करें।
Golf             : गोल्फ मोड सक्षम करें, अधिकतम संख्या और सामान्य फंक्शनों को जोड़ें।
Sandbox          : एक्सट्रा सुरक्षा के साथ स्क्रिप्ट को कॉम्पाइल करें, स्थानीय फ़ाइलों की पहुँच को टालें।
NoUpdateCheck    : ps12exe के नए संस्करण की जाँच छोड़ें।
Quiet            : संकलन के दौरान सूचनात्मक (होस्ट) आउटपुट दबाएँ; त्रुटियाँ और चेतावनियाँ अभी भी दिखाई देंगी।
Locale           : स्थानीयकरण भाषा कोड की निर्दिष्टि करें।
ConfigFile       : एक कॉन्फ़िगरेशन फ़ाइल लिखें (<outputfile>.exe.config)।
Help             : इस मदद सूचना को दिखाएँ।
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

<a id="preprocessing-overview"></a>

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

<a id="preprocessing-if"></a>

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

<a id="preprocessing-include"></a>

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

<a id="preprocessing-include-as"></a>

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

<a id="preprocessing-bang"></a>

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

<a id="preprocessing-require"></a>

```powershell
#_require ps12exe
#_pragma App.Windowed
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

<a id="preprocessing-pragma"></a>

प्राग्मा प्रीप्रोसेसिंग निर्देश का स्क्रिप्ट सामग्री पर कोई प्रभाव नहीं पड़ता है, लेकिन संकलन के लिए उपयोग किए जाने वाले मापदंडों को संशोधित करेगा।  
यहाँ एक उदाहरण है:

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

जैसा कि आप देख सकते हैं, `#_pragma App.Windowed` जेनरेट की गई exe फ़ाइल को विंडो मोड में चलाने का कारण बनता है, भले ही हम संकलन करते समय `-App @{Windowed=$true}` निर्दिष्ट न करें।  
प्राग्मा कमांड कोई भी संकलन पैरामीटर सेट कर सकता है; नाम में `.` का उपयोग करके नेस्टेड मान सेट करें:

```powershell
#_pragma App.Windowed #विंडो मोड
#_pragma App.Windowed $false #कंसोल मोड
#_pragma Resources.Icon $PSScriptRoot/icon.ico #सेट आइकन
#_pragma Resources.Title "title" #एक्सई शीर्षक सेट करें
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" #कोड साइनिंग प्रमाणपत्र सेट करें
```

स्ट्रिंग pragma मानों में `$(...)` उप-अभिव्यक्तियाँ भी हो सकती हैं, जिनका मूल्यांकन प्रीप्रोसेस समय पर किया जाता है, जैसे `#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`। केवल श्वेतसूचीबद्ध पथ-संबंधित कमांड (`Get-Command`, `Join-Path`, `Split-Path`, `Resolve-Path`, `Convert-Path`, `Get-Item`, `Test-Path`, `Get-ChildItem`, और Sandbox के बाहर `Get-Content`), चर (`$env:*` (Sandbox में केवल `$env:windir`/`$env:SystemRoot`), `$PSScriptRoot`, `$ScriptRoot`, `$HOME`, `$PWD`, `$PSCommandPath`) और सामान्य हानिरहित इंस्टेंस विधियाँ (जैसे `ToUpper`, `Trim`, `Split`, `ToString`) की अनुमति है; अन्य कुछ भी संकलन रोक देता है। एकल उद्धरण वाले मान पूरी तरह से शाब्दिक रहते हैं। Sandbox मोड `#_pragma outputFile`, `Build.TempDir`, `Build.Minify`, और `Signing.Certificate` को भी अनदेखा करता है, और केवल उन्हीं http(s) URL को लाता है जो सार्वजनिक पते पर resolve होते हैं (redirect लक्ष्य भी इसी तरह प्रतिबंधित हैं)। स्थानीय `Resources.Icon` पथ केवल Windows निर्देशिका के अंतर्गत अनुमत हैं।

#### `#_DllExport`

<a id="preprocessing-dllexport"></a>

```powershell
#_DllExport int Add(int a, int b)
#_DllExport Add(int a, int b)
#_DllExport DoSomething(int value)

function Add($a, $b) { return $a + $b }
function DoSomething($value) { ... }
```

`#_DllExport` स्क्रिप्ट को एक्ज़ीक्यूटेबल के बजाय नेटिव Win32 DLL में कंपाइल करता है और सूचीबद्ध फ़ंक्शन निर्यात करता है, ताकि नेटिव कॉलर उन्हें सीधे `LoadLibrary`/`GetProcAddress` (या `DllImport`) से कॉल कर सकें। प्रत्येक निर्यातित फ़ंक्शन उसी नाम के PowerShell फ़ंक्शन को अग्रेषित करता है: आर्ग्युमेंट एक सरणी के रूप में भेजे जाते हैं और फ़ंक्शन का आउटपुट रिटर्न मान बनता है। रिटर्न और पैरामीटर प्रकार C# सिंटैक्स में लिखे जाते हैं; रिटर्न प्रकार छोड़ने पर `void`, और बिना प्रकार वाला पैरामीटर `string` माना जाता है।

नेटिव निर्यात के लिए .NET Framework 4.0 लक्ष्य और `x86`/`x64` प्लेटफ़ॉर्म आवश्यक है (`AnyCPU` स्वतः होस्ट बिटनेस पर हल हो जाता है), और डिफ़ॉल्ट आउटपुट `.dll` है। यह सुविधा गेस्ट (सैंडबॉक्स) मोड में उपलब्ध नहीं है। कॉल क्रमबद्ध होती हैं और पहली कॉल PowerShell रनस्पेस शुरू करती है। स्क्रिप्ट में त्रुटि होने पर वह stderr पर लिखी जाती है और कॉल अपवाद को नेटिव सीमा पार करने देने के बजाय घोषित प्रकार का डिफ़ॉल्ट मान लौटाती है।

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <exitcode>
#_balus
```

जब कोड इस बिंदु पर पहुंचता है, तो प्रक्रिया दिए गए निकास कोड के साथ बाहर निकल जाती है और EXE फ़ाइल को हटा देती है।

### मिनिफ़िकेशन

चूँकि ps12exe का "संकलन" स्क्रिप्ट में सब कुछ संसाधनों के रूप में उत्पन्न निष्पादन योग्य शब्दशः में एम्बेड करता है, यदि स्क्रिप्ट में बहुत सारे बेकार तार हैं तो परिणामी निष्पादन योग्य बड़ा होगा।  
आप एक स्क्रिप्ट ब्लॉक को निर्दिष्ट करने के लिए `-Build` की `Minify` कुंजी का उपयोग कर सकते हैं जो एक छोटे जेनरेटेड निष्पादन योग्य प्राप्त करने के लिए संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करेगा।

यदि आप नहीं जानते कि ऐसा स्क्रिप्ट ब्लॉक कैसे लिखना है, तो आप [psminnifyer](https://github.com/steve02081504/psminnifyer) का उपयोग कर सकते हैं।

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | &./psminnifyer.ps1 }}
```

### अकार्यान्वित सीएमडीलेट्स की सूची

PS12exe के लिए मूल इनपुट/आउटपुट कमांड को C# में फिर से लिखना पड़ा। लागू न किए गए लोगों में कंसोल मोड में _`Write-Progress`_ (बहुत अधिक काम) और _`Start-Transcript`_/_`Stop-Transcript`_ (माइक्रोसॉफ्ट के पास उचित संदर्भ कार्यान्वयन नहीं है) शामिल हैं।

### जीयूआई मोड आउटपुट स्वरूप

डिफ़ॉल्ट रूप से, पॉवरशेल में cmdlet आउटपुट को प्रति पंक्ति एक पंक्ति (स्ट्रिंग्स की एक सरणी के रूप में) स्वरूपित किया जाता है। जब कमांड आउटपुट की 10 लाइनें उत्पन्न करता है और जीयूआई आउटपुट का उपयोग करता है, तो 10 संदेश बॉक्स दिखाई देते हैं, प्रत्येक ओके की प्रतीक्षा करते हैं। इससे बचने के लिए, `Out-String` कमांड को कमांड लाइन में आयात करें। यह आउटपुट को 10-लाइन स्ट्रिंग सरणी में परिवर्तित कर देगा, और सभी आउटपुट एक संदेश बॉक्स में प्रदर्शित किया जाएगा (उदाहरण: `dir C:\| Out-String`)।

### विन्यास फाइल

ps12exe `जनरेटेड एक्ज़ीक्यूटेबल + ".config"` नाम से एक कॉन्फ़िगरेशन फ़ाइल बना सकता है। ज्यादातर मामलों में, इन कॉन्फ़िगरेशन फ़ाइलों की आवश्यकता नहीं होती है, वे केवल एक चेकलिस्ट हैं जो आपको बताती हैं कि आपको कौन सा .नेट फ्रेमवर्क संस्करण उपयोग करना चाहिए। चूँकि आप आमतौर पर वास्तविक .Net फ्रेमवर्क का उपयोग कर रहे होंगे, कॉन्फ़िगरेशन फ़ाइल के बिना अपने निष्पादन योग्य को चलाने का प्रयास करें।

### पैरामीटर प्रोसेसिंग

संकलित स्क्रिप्ट मूल स्क्रिप्ट की तरह ही मापदंडों को संभालती है। एक सीमा विंडोज वातावरण से आती है: किसी भी निष्पादन योग्य के लिए, कमांड-लाइन तर्क अंततः स्ट्रिंग होते हैं।

जब स्क्रिप्ट में शीर्ष-स्तरीय `param()` ब्लॉक होता है, तो ps12exe तर्क मानों को PowerShell डेटा (PSD) के रूप में पार्स करता है: हैशटेबल `@{}`, क्रमित हैशटेबल `[ordered]@{}`, सरणियाँ `@()`, और `[int]'5'` या `[hashtable]@{}` जैसे सुरक्षित प्रकारों में रूपांतरण, संबंधित ऑब्जेक्ट के रूप में पैरामीटर को पास किए जाते हैं, इसलिए मैन्युअल रूपांतरण की आवश्यकता नहीं होती:

```powershell
# script: param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

मान को उद्धरण में रखना आवश्यक है: बिना उद्धरण वाले `@{...}` को शेल स्ट्रिंग बना देते हैं (प्रोग्राम को केवल `System.Collections.Hashtable` टेक्स्ट मिलता है)। जो डेटा नहीं है (कोई अभिव्यक्ति या कमांड) उसे सामान्य स्ट्रिंग के रूप में पास किया जाता है और कभी मूल्यांकित नहीं किया जाता, इसलिए `-Config "@{x=(Get-Date)}"` कोड नहीं चलाता — बस बाइंडिंग विफल हो जाती है।

पाइप से भेजे गए मान अभी भी स्ट्रिंग ही रहते हैं।

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

### बैकग्राउंड विंडो `App.Windowed` मोड में

`App.Windowed` मोड (जैसे `Get-Credential` या `cmd.exe` की आवश्यकता वाले कमांड) का उपयोग करके स्क्रिप्ट में एक बाहरी विंडो खोलने पर, पृष्ठभूमि में एक विंडो खोली जाएगी।

इसका कारण यह है कि बाहरी विंडो बंद करते समय, विंडोज़ मूल विंडो को सक्रिय करने का प्रयास करता है। क्योंकि संकलित स्क्रिप्ट में कोई विंडो नहीं है, संकलित स्क्रिप्ट की मूल विंडो सक्रिय होती है, आमतौर पर एक्सप्लोरर या पावरशेल की विंडो।

इस समस्या को हल करने के लिए, आप एक अदृश्य विंडो खोलने के लिए `$Host.UI.RawUI.FlushInputBuffer()` का उपयोग कर सकते हैं जिसे सक्रिय किया जा सकता है। `$Host.UI.RawUI.FlushInputBuffer()` पर बाद में कॉल करने से विंडो बंद हो जाएगी (और इसी तरह)।

केवल एक बार `ipconfig | Out-String` को कॉल करने के विपरीत, निम्न उदाहरण अब पृष्ठभूमि में विंडो नहीं खोलेगा:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### मानक इनपुट और `$input`

संकलित exe केवल तभी रीडायरेक्ट किए गए मानक इनपुट को (पंक्ति-दर-पंक्ति, पाइपलाइन इनपुट के रूप में) पढ़ता है जब स्क्रिप्ट अपने **शीर्ष स्तर** पर `$input` का उपयोग करती है:

- यदि `$input` का उपयोग किया जाता है: व्यवहार PS2EXE जैसा होता है — stdin को पाइपलाइन इनपुट के रूप में उपभोग किया जाता है, इसलिए मूल stdin (`[Console]::In` / `Console.OpenStandardInput()`) बाद में EOF तक पहुँच जाता है।
- यदि `$input` का उपयोग नहीं किया जाता है: stdin बिल्कुल नहीं पढ़ा जाता; मूल मानक इनपुट ज्यों का त्यों रहता है और प्रारंभ होते समय stdin की प्रतीक्षा नहीं करता (पाइप को खुला रखने वाला मूल प्रक्रिया अब इसे ब्लॉक नहीं करता), और चाइल्ड प्रक्रियाएँ अभी भी stdin विरासत में ले सकती हैं।

केवल स्क्रिप्ट का शीर्ष स्तर ही गिना जाता है: फ़ंक्शन, स्क्रिप्ट ब्लॉक या क्लास के अंदर का `$input` उसी स्कोप का अपना पाइपलाइन इनपुट होता है और उसे नज़रअंदाज़ किया जाता है।

उदाहरण के लिए, यदि स्क्रिप्ट `[Console]::In.ReadToEnd()` कहती है और कभी `$input` का उपयोग नहीं करती, तो संकलन के बाद `echo hi | .\tool.exe` को `hi` मिलता है।

### स्थिरांक मूल्यांकन

केवल स्थिरांक वाली और दुष्प्रभाव-रहित स्क्रिप्ट के लिए, ps12exe उन्हें संकलन समय पर मूल्यांकित करता है और परिणाम को सीधे एक बहुत छोटी exe (आमतौर पर लगभग 1KB) में समाहित करता है; मूल्यांकन का समय समाप्त होने (डिफ़ॉल्ट रूप से 7 सेकंड) या परिणाम बहुत लंबा होने पर यह सामान्य संकलन पर वापस आ जाता है। यदि मूल्यांकन वातावरण रनटाइम से भिन्न है, या आप बस पूरा PowerShell होस्ट चाहते हैं, तो उस अनुकूलन को स्पष्ट रूप से छोड़ने के लिए स्क्रिप्ट में नीचे दिए गए किसी एक pragma को जोड़ें:

- `#_pragma Build.ConstEval.Enabled 0`: घोषित करता है कि यह स्क्रिप्ट स्थिरांक नहीं है; स्थिरांक मूल्यांकन छोड़ें।
- `#_pragma Build.ConstEval.Timeout 1`: घोषित करता है कि यह स्थिरांक मूल्यांकन का समय पहले ही समाप्त हो चुका है; समय समाप्त होने की स्थिति जैसा ही फ़ॉलबैक लागू करें।

दोनों को प्रीप्रोसेसिंग के दौरान सामान्य नेस्टेड pragma के रूप में पार्स किया जाता है, इसलिए ये किसी भी पंक्ति में हो सकते हैं; सामान्य होस्ट पर वापस आने के बाद ये केवल सामान्य टिप्पणियाँ होती हैं।

## फायदों की तुलना 🏆

### त्वरित तुलना 🏁

| तुलना सामग्री                                      | ps12exe                                                                                                    | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                      |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| शुद्ध स्क्रिप्ट भंडार 📦                           | ✔️छवियों और साथ दी गई सहायक DLL को छोड़कर, सभी टेक्स्ट फ़ाइलें                                             | ❌ओपन सोर्स लाइसेंस के साथ `Win-PS2EXE.exe` शामिल करता है                                           |
| हेलो वर्ल्ड उत्पन्न करने के लिए आवश्यक कमांड 🌍    | 😎`'"Hello world!"' \| ps12exe`                                                                            | 🤔`echo "Hello world!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                            |
| कॉन्स्टेंट हेलो वर्ल्ड निष्पादन योग्य फ़ाइल 💾     | 🥰1024 बाइट्स (संकलन समय पर मूल्यांकित)                                                                    | ❌समर्थित नहीं; 25088 बाइट्स                                                                        |
| नॉन-कॉन्स्टेंट हेलो वर्ल्ड निष्पादन योग्य फ़ाइल 💾 | 🥰14848 बाइट्स                                                                                             | 😨25088 बाइट्स                                                                                      |
| संकलन-समय कॉन्स्टेंट मूल्यांकन ⚡                  | ✔️                                                                                                         | ❌                                                                                                  |
| PowerShell Core (7+) / क्रॉस-प्लेटफ़ॉर्म लक्ष्य 🧬 | ✔️ `Build.Target Core` (Windows / Linux / macOS)                                                           | ❌केवल Windows PowerShell 5.1                                                                       |
| जीयूआई बहु-भाषा समर्थन 🌐                          | ✔️(7 भाषाएँ, डार्क मोड)                                                                                    | ❌                                                                                                  |
| संकलन-समय सिंटैक्स जाँच ✔️                         | ✔️                                                                                                         | ❌                                                                                                  |
| प्रीप्रोसेसिंग फ़ंक्शन 🔄                          | ✔️                                                                                                         | ❌                                                                                                  |
| `-extract` जैसे विशेष मापदंडों का विश्लेषण 🧹      | 🗑️हटाया गया (`exe21sp` टूल का उपयोग करें)                                                                  | 🥲स्रोत कोड को संशोधित करने की आवश्यकता है                                                          |
| पीआर का स्वागत है 🤝                               | 🥰स्वागत है!                                                                                               | 🤷14 पीआर, उनमें से 13 बंद                                                                          |
| राजनीतिक / DEI / विचारधारात्मक पूर्वाग्रह 🕊️       | ✔️ कोई नहीं; कोई भी मूल्यवान PR स्वागत योग्य है — चाहे वह इंसान से हो, AI से, या टाइपराइटर पर बैठे बंदर से | ❌ README AI-विरोधी रुख अपनाता है ("कृत्रिम बुद्धिमत्ता रचनात्मकता और हमारी प्रकृति को मार रही है") |

ps12exe का डेवलपर इस प्रोजेक्ट का उपयोग राजनीतिक, DEI या किसी अन्य विचारधारात्मक रुख को बढ़ावा देने के लिए नहीं करता — कोई भी मूल्यवान PR स्वागत योग्य है, चाहे वह इंसान से आए, AI से, या टाइपराइटर पर बैठे बंदर से।

### आकार और गति 🔬

Windows 11 पर PowerShell 7.6.6 (.NET 10) और Windows PowerShell 5.1 के साथ मापा गया, प्रत्येक को वार्म-अप के बाद 20 बार चलाया गया। प्रोसेस निर्माण की न्यूनतम सीमा (`cmd /c exit`) लगभग 15 ms है। `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` से दोबारा चलाएँ (नीचे दी गई कंपाइलेशन-गति तालिका के लिए `-Compile` जोड़ें)।

| बिल्ड                                                    | आउटपुट आकार  | वार्म स्टार्टअप |
| -------------------------------------------------------- | ------------ | --------------- |
| Windows PowerShell 5.1 से स्क्रिप्ट सीधे चलाना           | —            | ~406 ms         |
| ps12exe · कॉन्स्टेंट · Framework4.0                      | 1024 बाइट्स  | ~54 ms          |
| ps12exe · नॉन-कॉन्स्टेंट · Framework4.0                  | 14848 बाइट्स | ~365 ms         |
| PS2EXE 1.0.18 · नॉन-कॉन्स्टेंट                           | 25088 बाइट्स | ~398 ms         |
| ps12exe · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट · Framework4.0 | 30208 बाइट   | ~381 ms         |
| PS2EXE 1.0.18 · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट          | ~496 KB      | ~402 ms         |
| -------------------------------------------------------- | ------------ | --------------- |
| pwsh 7 से स्क्रिप्ट सीधे चलाना                           | —            | ~676 ms         |
| ps12exe · कॉन्स्टेंट · Core                              | ~165 KB      | ~104 ms         |
| ps12exe · नॉन-कॉन्स्टेंट · Core                          | ~181 KB      | ~621 ms         |
| ps12exe · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट · Core         | ~187 KB      | ~637 ms         |
| PS2EXE 1.0.18 · नॉन-कॉन्स्टेंट · Core                    | समर्थित नहीं | समर्थित नहीं    |

कॉन्स्टेंट स्क्रिप्ट का मूल्यांकन संकलन समय पर होता है, इसलिए उसकी exe केवल 1 KB की होती है और PowerShell कभी शुरू नहीं होता — PS2EXE के हेलो वर्ल्ड से लगभग 24× छोटी और लॉन्च होने में 6× तेज़। नॉन-कॉन्स्टेंट exe, PS2EXE से ~40% छोटी होती हैं, और टॉप-लेवल वेरिएबल का अधिक उपयोग करने वाली स्क्रिप्ट के लिए वे तेज़ भी चलती हैं, क्योंकि स्क्रिप्ट ग्लोबल स्कोप के बजाय एक फ़ंक्शन (लोकल स्कोप) के अंदर इसके अलावा, नॉन-कॉन्स्टेंट exe हमेशा कंप्रेस होती है और यह लाभ स्क्रिप्ट बड़ी होने पर और बढ़ता है: ~0.5 MB की स्क्रिप्ट भी ~30 KB की Framework exe देती है, जो PS2EXE के ~496 KB का लगभग 1/16 है, क्योंकि PS2EXE अपनी पेलोड को लगभग असंपीड़ित छोड़ देता है और स्क्रिप्ट के साथ फूल जाता है। Core exe छोटी स्क्रिप्ट वाले संस्करण से केवल ~6 KB अधिक होती है, इसलिए बड़ी पेलोड फूलने के बजाय छोटी रहती है।

### कंपाइलेशन गति ⏱️

उसी टूल (`-Compile -IncludeCore`) से मापा गया। प्रत्येक नमूना एक नई होस्ट प्रोसेस है (Framework/PS2EXE के लिए Windows PowerShell 5.1, Core के लिए pwsh 7); "वार्म" पहली के बाद की 5 कंपाइलों का माध्यक है। PS2EXE के आँकड़े स्थानीय रूप से इंस्टॉल किए गए रिलीज़ (इस वातावरण में 1.0.18) से हैं।

| बिल्ड                                                    | वार्म कंपाइल |
| -------------------------------------------------------- | ------------ |
| ps12exe · कॉन्स्टेंट · Framework4.0                      | ~2.3 s       |
| ps12exe · नॉन-कॉन्स्टेंट · Framework4.0                  | ~1.3 s       |
| PS2EXE · नॉन-कॉन्स्टेंट                                  | ~0.9 s       |
| ps12exe · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट · Framework4.0 | ~1.5 s       |
| PS2EXE · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट                 | ~0.7 s       |
| -------------------------------------------------------- | ------------ |
| ps12exe · कॉन्स्टेंट · Core                              | ~4.2 s       |
| ps12exe · नॉन-कॉन्स्टेंट · Core                          | ~5.7 s       |
| ps12exe · नॉन-कॉन्स्टेंट · बड़ी स्क्रिप्ट · Core         | ~5.9 s       |
| PS2EXE · नॉन-कॉन्स्टेंट · Core                           | समर्थित नहीं |

PS2EXE एक hello world को तेज़ी से कंपाइल करता है क्योंकि यह Windows में अंतर्निहित .NET Framework कंपाइलर के चारों ओर एक पतला आवरण मात्र है: यह केवल एक CodeDom पास करता है और कुछ नहीं। ps12exe इसके अतिरिक्त सिंटैक्स जाँच चलाता है, स्क्रिप्ट को वर्गीकृत करता है और (कॉन्स्टेंट स्क्रिप्ट के लिए) उसका मूल्यांकन करता है, तथा प्रोग्राम फ़्रेम को लॉन्चर के भीतर पेलोड के रूप में पैक करता है, इसलिए इसका नॉन-कॉन्स्टेंट कंपाइल PS2EXE का ~1.4× है। इसका प्रतिफल आउटपुट में दिखता है: ps12exe 1024 / 14848 बाइट्स उत्पन्न करता है जबकि PS2EXE 25088, और कॉन्स्टेंट प्रोग्राम लगभग 6× तेज़ लॉन्च होते हैं। Core कंपाइलेशन में `dotnet publish` प्रमुख है; किसी कॉन्फ़िगरेशन की पहली कंपाइल NuGet पैकेज भी रीस्टोर करती है, जिसके बाद ps12exe उत्पन्न प्रोजेक्ट निर्देशिका का पुनः उपयोग करता है और `dotnet publish --no-restore` चलाता है।

कंपाइलर स्वयं एक PowerShell मॉड्यूल के रूप में वितरित होता है:

| कंपाइलर पैकेज            | अनपैक्ड  | संपीड़ित |
| ------------------------ | -------- | -------- |
| ps12exe (वर्तमान master) | ~1.64 MB | ~629 KB  |
| PS2EXE 1.0.18            | ~171 KB  | ~46 KB   |

ps12exe का मॉड्यूल बड़ा है क्योंकि यह बिना किसी निर्भरता वाला शुद्ध-स्क्रिप्ट कंपाइलर है जिसमें ट्रिम किए गए [AsmResolver](https://github.com/Washi1337/AsmResolver) बाइनरी, 7 स्थानीयकरण और एक शुद्ध-स्क्रिप्ट जीयूआई शामिल हैं; PS2EXE लगभग कुछ भी नहीं भेजता और Windows में अंतर्निहित .NET Framework कंपाइलर पर निर्भर करता है।

### नेटिव DLL एक्सपोर्ट 🧩

`#_DllExport` वाली स्क्रिप्ट `LoadLibrary`/`GetProcAddress` से कॉल की जा सकने वाली Win32 DLL में कंपाइल होती है (केवल Framework4.0 + x86/x64; PS2EXE में इसका समतुल्य नहीं है)। निश्चित दो-एक्सपोर्ट स्क्रिप्ट (`Add`, `Greet`):

| बिल्ड                                  | आउटपुट आकार  | वार्म कंपाइल |
| -------------------------------------- | ------------ | ------------ |
| ps12exe · DLL एक्सपोर्ट · Framework4.0 | 28160 बाइट्स | ~2.8 s       |
| PS2EXE 1.0.18 · DLL एक्सपोर्ट          | समर्थित नहीं | समर्थित नहीं |

### संकलित EXE का रनटाइम व्यवहार 🖥️

Windows 11 की वास्तविक कंसोल विंडो में सत्यापित: EXE द्वारा शुरू किए गए नेटिव चाइल्ड प्रोसेस को असली कंसोल TTY दिखता है या नहीं ([#59](https://github.com/steve02081504/ps12exe/issues/59)), स्क्रिप्ट कच्चा stdin पढ़ सकती है या नहीं ([#62](https://github.com/steve02081504/ps12exe/issues/62)), और विशेष पथ वेरिएबल हल होते हैं या नहीं:

| क्षमता                                                        | ps12exe                                   | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------ |
| नेटिव चाइल्ड प्रोसेस को कंसोल TTY (`isTTY`) दिखता है          | ✔️                                        | ❌                                                                             |
| कच्चा stdin (`[Console]::In`) पढ़ा जा सकता है                 | ✔️ (जब स्क्रिप्ट `$input` का उपयोग न करे) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` हल होते हैं                | ✔️ (exe पथ / exe फ़ोल्डर)                 | ❌                                                                             |
| कमांड-लाइन तर्क PSD डेटा के रूप में पार्स (तालिकाएँ/ऑब्जेक्ट) | ✔️ (`-Config "@{...}"`)                   | ❌ (केवल स्ट्रिंग)                                                             |

PS2EXE 1.0.18 स्क्रिप्ट आउटपुट को हमेशा `Out-String` से गुज़ारता है और स्क्रिप्ट चलाने से पहले रीडायरेक्ट किए गए stdin को पूरा पढ़ लेता है, इसलिए नेटिव चाइल्ड प्रोसेस कंसोल हैंडल खो देते हैं और stdin EOF पर पहुँच जाता है; ps12exe होस्ट के ज़रिए लिखता है (`Out-Default`) और stdin तभी पढ़ता है जब स्क्रिप्ट वास्तव में `$input` का उपयोग करे। इसके अलावा PS2EXE संकलित प्रोग्राम के अंदर `$PSCommandPath`/`$PSScriptRoot` को खाली छोड़ देता है (अपना `$ScriptRoot` देता है), जबकि ps12exe दोनों को बनाई गई exe से मैप करता है।

### विस्तृत तुलना 🔍

[`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) की तुलना में, यह प्रोजेक्ट निम्नलिखित सुधार लाता है:

| सुधार                                                                 | विवरण                                                                                                                   |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| ✔️ संकलन समय पर सिंटेक्स जांच                                         | कोड गुणवत्ता में सुधार के लिए संकलन समय पर सिंटेक्स जांच                                                                |
| ⚡ संकलन-समय कॉन्स्टेंट मूल्यांकन                                     | साइड-इफ़ेक्ट रहित स्क्रिप्ट बिल्ड समय पर मूल्यांकित होकर ~1 KB की exe में बदल जाती हैं                                  |
| 🧬 PowerShell Core / क्रॉस-प्लेटफ़ॉर्म लक्ष्य                         | `Build.Target Core` Windows, Linux और macOS पर PowerShell 7+ को लक्षित करता है                                          |
| 🔄 शक्तिशाली प्रीप्रोसेसिंग फ़ंक्शन                                   | संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करें, स्क्रिप्ट में सब कुछ कॉपी और पेस्ट करने की आवश्यकता नहीं है                |
| 🛠️ `Build.Options` पैरामीटर                                           | नए पैरामीटर आपको जेनरेट की गई निष्पादन योग्य फ़ाइल को और अधिक अनुकूलित करने की अनुमति देते हैं                          |
| 📦️ `Build.Minify` पैरामीटर                                            | एक छोटी निष्पादन योग्य फ़ाइल उत्पन्न करने के लिए संकलन से पहले स्क्रिप्ट को प्रीप्रोसेस करें                            |
| 🌐 स्क्रिप्ट संकलित करने में सहायता करें और URL से फ़ाइलें शामिल करें | URL से आइकन डाउनलोड करने में सहायता करें                                                                                |
| 🖥️ `App.Windowed` पैरामीटर अनुकूलन                                    | अनुकूलित विकल्प प्रसंस्करण और विंडो शीर्षक प्रदर्शन, अब आप सेटिंग द्वारा पॉप-अप विंडो के शीर्षक को अनुकूलित कर सकते हैं |
| ✍️ कोड साइनिंग और आइकन स्वतः-रूपांतरण                                 | PFX प्रमाणपत्र या स्टोर थंबप्रिंट से हस्ताक्षर करें, और आइकन स्वतः बदलें                                                |
| 🧰 अतिरिक्त: `exe21sp`, वेब सर्वर, कॉन्टेक्स्ट मेनू, इंटरैक्ट मोड     | exe डीकंपाइल करें, ऑनलाइन संकलित करें, राइट-क्लिक संकलन और बहुत कुछ                                                     |
| 🧹 exe फ़ाइल हटा दी गई                                                | कोड रिपॉजिटरी से exe फ़ाइल हटा दी गई                                                                                    |
| 🌍 बहु-भाषा समर्थन, शुद्ध स्क्रिप्ट जीयूआई                            | बेहतर बहु-भाषा समर्थन, शुद्ध स्क्रिप्ट जीयूआई, डार्क मोड का समर्थन करता है                                              |
| 📖 सीएस फाइलों को पीएस1 फाइलों से अलग करें                            | पढ़ने और बनाए रखने में आसान                                                                                             |
| 🚀 अधिक सुधार                                                         | और अधिक...                                                                                                              |

## समय पर स्टार ⭐

[![समय पर स्टार](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
