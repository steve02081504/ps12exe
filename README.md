# ps12exe

WARNING: It is strongly advised not to compile scripts from unverified sources using this project due to the following reasons:

1. ps12exe has the capability to indirectly include scripts from URLs. This implies that scripts from any URL can be incorporated into your script.
2. ps12exe, through a set of not-so-stringent rules, determines if all or a part of a script could be a constant program, the content of which can be determined at compile time. If such a determination is made, ps12exe will automatically execute this script in an attempt to obtain the output.

This implies that if you compile a script whose content is unknown to you, there's a high possibility that ps12exe might download and execute a malicious script during the compile time.  
If you're skeptical, try executing `"while(1){}" | ps12exe -Verbose`.  

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./docs/README_CN.md)
[![English](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./docs/README_EN.md)

## Install

```powershell
Install-Module ps12exe
```

(you can also clone this repository and run `./ps12exe.ps1` directly)

## Usage

### GUI mode

```powershell
ps12exeGUI
```

### Console mode

```powershell
ps12exe .\source.ps1 .\target.exe
```

compiles `source.ps1` into the executable target.exe (if `.\target.exe` is omitted, output is written to `.\source.exe`).

```powershell
'"Hello World!"' | ps12exe
```

compiles `"Hello World!"` into the executable `.\a.exe`.

## Comparative Advantages 🏆

### Quick Comparison 🏁

| Comparison Content | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| Pure script repository 📦 | ✔️ All text files except images | ❌ Contains exe files with open source license |
| Command to generate hello world 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; ps2exe a.ps1; rm a.ps1` |
| Size of the generated hello world executable file 💾 | 🥰3584 bytes | 😨25088 bytes |
| GUI multilingual support 🌐 | ✔️ | ❌ |
| Syntax check during compilation ✔️ | ✔️ | ❌ |
| Preprocessing feature 🔄 | ✔️ | ❌ |
| Ability to remove `-extract` and other special parameter parsing 🧹 | ❤️ Disabled by default | 🥲 Requires source code modification |
| PR welcome level 🤝 | 🥰 Welcome! | 🤷 14 PRs, 13 of which were closed |

### Detailed Comparison 🔍

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project brings the following improvements:

| Improvement Content | Description |
| --- | --- |
| ✔️ Syntax check during compilation | Syntax check during compilation to improve code quality |
| 🔄 Powerful preprocessing feature | Preprocess the script before compilation, no need to copy and paste all content into the script |
| ⚙️ `-SepcArgsHandling` parameter | Special parameters are no longer enabled by default, but can be enabled with a new parameter if needed |
| 🛠️ `-CompilerOptions` parameter | New parameter, allowing you to further customize the generated executable file |
| 📦️ `-Minifyer` parameter | Preprocess the script before compilation to generate a smaller executable file |
| 🌐 Support for compiling scripts and included files from URL | Support for downloading icons from URL |
| 🖥️ Optimization of `-noConsole` parameter | Optimized option handling and window title display, you can now set the title of the custom pop-up window |
| 🧹 Removed exe files | Removed exe files from the code repository |
| 🌍 Multilingual support, pure script GUI | Better multilingual support, pure script GUI, support for dark mode |
| 📖 Separated cs files from ps1 files | Easier to read and maintain |
| 🚀 More improvements | And more... |

see [English docs](./docs/README_EN.md) for more details.
