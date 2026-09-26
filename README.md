# ps12exe

> [!CAUTION]
> Do not store passwords in source code!  
> See the [localized readme](https://steve02081504.github.io/ps12exe/readme#password-security-stuff) for more details.

## Introduction

ps12exe is a PowerShell module that allows you to create an executable file from a .ps1 script.

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./docs/README_CN.md)
[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./docs/README_EN_UK.md)
[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./docs/README_EN_US.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./docs/README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./docs/README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./docs/README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./docs/README_HI.md)

## Used by

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## Install

```powershell
Install-Module ps12exe #Install ps12exe module
Set-ps12exeIntegration #Set up right-click menu, Agent Skill and VS Code extension
```

(you can also clone this repository and run `./ps12exe.ps1` directly)

**Hard to upgrade from PS2EXE to ps12exe? No problem!**  
PS2EXE2ps12exe hooks PS2EXE calls into ps12exe. Uninstall PS2EXE, install this module, then use PS2EXE as usual.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Usage

### Right-click menu

Once you have run `Set-ps12exeIntegration`, you can quickly compile any ps1 file into an exe or open ps12exeGUI on this file by right-clicking on it.  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

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

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

compiles `Main.ps1` from the internet into the executable `.\Main.exe`.

### Recover ps1 from exe (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` extracts the original PowerShell script from a ps12exe-generated executable (local path or URL) and writes it to a `.ps1` file or standard output. It uses the same `$LastExitCode` convention as ps12exe: 0 = success, 1 = input/parse error (e.g. not a ps12exe exe), 2 = invocation error (e.g. no input when redirected), 3 = resource/internal error (e.g. file not found).

### Pipeline and redirection

- **ps12exe**: When stdout (or stdin/stderr) is redirected, ps12exe writes only the path of the generated exe to stdout so you can capture it (e.g. `$exe = ps12exe .\a.ps1`).
- **exe21sp**: Accepts exe paths or URLs from pipeline input (e.g. `Get-ChildItem *.exe | exe21sp` or `".\app.exe" | exe21sp`).
- **exe21sp**: If `-outputFile` is not specified and stdout is **not** redirected, the decompiled script is saved to a `.ps1` file with the same base name as the exe in the same directory.
- **exe21sp**: If `-outputFile` is not specified and stdout **is** redirected, the decompiled script is written to stdout.

### Self-Host WebServer

```powershell
Start-ps12exeWebServer
```

Starts a web server that can be used to compile PowerShell scripts online.

### VS Code Extension

The [ps12exe VS Code extension](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe) compiles a `.ps1` script into an executable — or opens ps12exeGUI — without leaving the editor, and adds editor support for the preprocessor directives (syntax highlighting, diagnostics, `#_if` auto-close, folding, go-to-definition, hover, completion and formatting).

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeIntegration` installs it automatically; you can also install `steve02081504.ps12exe` manually.

### Agent Skill

`Set-ps12exeIntegration` also writes a `ps12exe` Agent Skill to `~/.agents/skills`, so skill-aware coding agents (opencode, Codex, Cursor, GitHub Copilot, …) know to use ps12exe when asked to compile a PowerShell script into an executable. `Set-ps12exeIntegration -action disable` removes it again, and `Set-ps12exeIntegration -Skip AgentSkill` leaves it untouched.

### Integration command

`Set-ps12exeIntegration` accepts `[-action] 'enable'|'disable'|'reset'`, `-Locale`, `-help`, and `-Skip` with any of `'ContextMenu'`, `'AgentSkill'` and `'VSCodeExtension'` to leave those parts alone.

## Comparative Advantages 🏆

### Quick Comparison 🏁

| Comparison Content                                | ps12exe                                                                                | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                     |
| ------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Pure script repository 📦                         | ✔️ All text files except images & bundled helper DLLs                                  | ❌ Ships `Win-PS2EXE.exe` with an open source license                                              |
| Command to generate hello world 🌍                | 😎`'"Hello World!"' \| ps12exe`                                                        | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                           |
| Constant hello world executable 💾                | 🥰1024 bytes (constant-evaluated at compile time)                                      | ❌ Not supported; 25088 bytes                                                                      |
| Non-constant hello world executable 💾            | 🥰14848 bytes                                                                          | 😨25088 bytes                                                                                      |
| Compile-time constant evaluation ⚡               | ✔️                                                                                     | ❌                                                                                                 |
| PowerShell Core (7+) / cross-platform target 🧬   | ✔️ `-Build @{Target='Core'}` (Windows / Linux / macOS)                                 | ❌ Windows PowerShell 5.1 only                                                                     |
| GUI multilingual support 🌐                       | ✔️ (7 languages, dark mode)                                                            | ❌                                                                                                 |
| Syntax check during compilation ✔️                | ✔️                                                                                     | ❌                                                                                                 |
| Preprocessing feature 🔄                          | ✔️                                                                                     | ❌                                                                                                 |
| `-extract` and other special parameter parsing 🧹 | 🗑️ Removed (use the `exe21sp` tool instead)                                            | 🥲 Requires source code modification                                                               |
| PR welcome level 🤝                               | 🥰 Welcome!                                                                            | 🤷 14 PRs, 13 of which were closed                                                                 |
| Political / DEI / stance bias 🕊️                  | ✔️ None; any valuable PR is welcome — from a human, an AI, or a monkey at a typewriter | ❌ Readme takes an anti-AI stance ("artificial intelligence is killing creativity and our nature") |

ps12exe's developer does not use this project to promote a political, DEI or other ideological stance — any valuable PR is welcome, whether it comes from a human, an AI, or a monkey at a typewriter.

### Size & Speed Benchmark 🔬

Measured on Windows 11 with PowerShell 7.6.6 (.NET 10) and Windows PowerShell 5.1, 20 warm runs each. The process-creation floor (`cmd /c exit`) is ~15 ms. Reproduce with `pwsh -File ./tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` (add `-Compile` for the compilation-speed table below).

| Build                                                | Output size | Warm startup |
| ---------------------------------------------------- | ----------- | ------------ |
| Windows PowerShell 5.1 running the script directly   | —           | ~406 ms      |
| ps12exe · constant · Framework4.0                    | 1024 bytes  | ~54 ms       |
| ps12exe · non-constant · Framework4.0                | 14848 bytes | ~365 ms      |
| PS2EXE 1.0.18 · non-constant                         | 25088 bytes | ~398 ms      |
| ps12exe · non-constant · large script · Framework4.0 | 30208 bytes | ~381 ms      |
| PS2EXE 1.0.18 · non-constant · large script          | ~496 KB     | ~402 ms      |
| ---------------------------------------------------- | ----------- | ------------ |
| pwsh 7 running the script directly                   | —           | ~676 ms      |
| ps12exe · constant · Core                            | ~165 KB     | ~104 ms      |
| ps12exe · non-constant · Core                        | ~181 KB     | ~621 ms      |
| ps12exe · non-constant · large script · Core         | ~187 KB     | ~637 ms      |
| PS2EXE 1.0.18 · non-constant · Core                  | not support | not support  |

A constant script is evaluated at compile time, so its exe is 1 KB and never starts PowerShell — about 24× smaller and 6× faster to launch than a PS2EXE hello world. Non-constant exes are ~40% smaller than PS2EXE's, and for top-level-variable-heavy scripts they also run faster, because the script executes inside a function (local scope) rather than at global scope. Non-constant exes are always compressed, and the compression scales with the payload: a ~0.5 MB script still produces a ~30 KB Framework exe, about 1/16 of PS2EXE's ~496 KB output, while PS2EXE leaves its payload essentially uncompressed and balloons with script size. The Core exe adds only ~6 KB over its small-script counterpart, so large payloads stay small instead of ballooning.

### Windowed GUI Startup 🪟

The hello-world benchmark above measures the launch of a console app that exits immediately, so its numbers are dominated by process startup. A GUI app stays alive while the user interacts, so the meaningful figure there is the time between double-clicking and the window appearing — the startup and script-execution overhead, not the process lifetime. Measured with the same tool (`-Windowed`), using a WinForms window that closes itself after ~800 ms; each row's warm startup includes process startup and script execution (the window lifetime is nearly identical across rows, and the ~15 ms process-creation floor is negligible here).

| Build                                                              | Output size | Warm startup |
| ------------------------------------------------------------------ | ----------- | ------------ |
| Windows PowerShell 5.1 running the script directly (hidden window) | —           | ~1154 ms     |
| ps12exe · windowed · DarkMode Auto · Framework4.0                  | 29184 bytes | ~1128 ms     |
| PS2EXE 1.0.18 · windowed · non-constant                            | 33792 bytes | ~1128 ms     |
| ------------------------------------------------------------------ | ----------- | ------------ |
| pwsh 7 running the script directly (hidden window)                 | —           | ~1349 ms     |
| ps12exe · windowed · DarkMode Auto · Core                          | ~6385 KB    | ~1317 ms     |

A windowed ps12exe app starts about as fast as PS2EXE's (~1128 ms), and both are a hair faster than running the same script through PowerShell directly — ps12exe strips `-NoProfile`-style overhead and never re-parses, while still adding a `Silence`/`OutputEncoding` host wrapper and dark-mode support. The Core windowed app (~1317 ms) is only slightly slower than the Framework one and a bit faster than `pwsh` running the script directly (~1349 ms). The ~6.4 MB Core output is self-contained by default; disable it with `-Build @{Target='Core'; SelfContained=$false}` to fall back to the ~0.2 MB shared-runtime exe. The size gain of the Framework windowed app over PS2EXE's (~4.5 KB) is smaller than for console apps because both must embed the WinForms bootstrap.

### Compilation Speed ⏱️

Measured with the same tool (`-Compile -IncludeCore`). Each sample is a fresh host process (Windows PowerShell 5.1 for Framework/PS2EXE, pwsh 7 for Core); "warm" is the median of 5 compiles after the first. PS2EXE numbers use the locally installed release (1.0.18 in this environment).

| Build                                                | Warm compile |
| ---------------------------------------------------- | ------------ |
| ps12exe · constant · Framework4.0                    | ~2.3 s       |
| ps12exe · non-constant · Framework4.0                | ~1.3 s       |
| PS2EXE · non-constant                                | ~0.9 s       |
| ps12exe · non-constant · large script · Framework4.0 | ~1.5 s       |
| PS2EXE · non-constant · large script                 | ~0.7 s       |
| ---------------------------------------------------- | ------------ |
| ps12exe · constant · Core                            | ~4.2 s       |
| ps12exe · non-constant · Core                        | ~5.7 s       |
| ps12exe · non-constant · large script · Core         | ~5.9 s       |
| PS2EXE · non-constant · Core                         | not support  |

PS2EXE compiles a hello world faster because it is a thin wrapper around the .NET Framework compiler built into Windows: it performs a single CodeDom pass and nothing else. ps12exe additionally runs a syntax check, classifies the script and (for constant scripts) evaluates it, and packs the program frame as a payload inside a launcher, so its non-constant compile is ~1.4× PS2EXE's. The trade-off shows up in the output: ps12exe emits 1024 / 14848 bytes where PS2EXE emits 25088, and constant programs launch about 6× faster. Core compilation is dominated by `dotnet publish`; the first compile for a given configuration also restores NuGet packages, after which ps12exe reuses the generated project directory and runs `dotnet publish --no-restore`.

The compiler itself is installed as a PowerShell module:

| Compiler package         | Unpacked | Compressed |
| ------------------------ | -------- | ---------- |
| ps12exe (current master) | ~1.64 MB | ~629 KB    |
| PS2EXE 1.0.18            | ~171 KB  | ~46 KB     |

ps12exe's module is larger because it is a dependency-free, pure-script compiler that bundles trimmed [AsmResolver](https://github.com/Washi1337/AsmResolver) binaries, 7 localizations and a pure-script GUI; PS2EXE ships almost nothing and relies on the .NET Framework compiler built into Windows.

### Native DLL Export 🧩

A script with `#_DllExport` is compiled into a Win32 DLL callable through `LoadLibrary`/`GetProcAddress` (Framework4.0 + x86/x64 only; PS2EXE has no equivalent). Fixed two-export script (`Add`, `Greet`):

| Build                               | Output size | Warm compile |
| ----------------------------------- | ----------- | ------------ |
| ps12exe · DLL export · Framework4.0 | 28160 bytes | ~2.8 s       |
| PS2EXE 1.0.18 · DLL export          | not support | not support  |

### Compiled-EXE Runtime Behaviour 🖥️

Whether native child processes started by the EXE see a real console TTY ([#59](https://github.com/steve02081504/ps12exe/issues/59)), whether the script can read raw stdin ([#62](https://github.com/steve02081504/ps12exe/issues/62)), and whether the special path variables resolve — all verified from a real console window on Windows 11:

| Capability                                        | ps12exe                              | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------ |
| Native child process sees a console TTY (`isTTY`) | ✔️                                   | ❌                                                                             |
| Raw stdin (`[Console]::In`) readable              | ✔️ (unless the script uses `$input`) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` resolve        | ✔️ (exe path / exe directory)        | ❌                                                                             |

PS2EXE 1.0.18 always pipes script output through `Out-String` and eagerly drains redirected stdin before the script runs, so native children lose the console handle and stdin reaches EOF; ps12exe runs the script through the host (`Out-Default`) and only drains stdin when the script actually uses `$input`. PS2EXE also leaves `$PSCommandPath`/`$PSScriptRoot` empty inside the compiled program (it offers its own `$ScriptRoot` instead), while ps12exe maps both to the generated exe.

### Detailed Comparison 🔍

Compared to [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615), this project brings the following improvements:

| Improvement Content                                           | Description                                                                                        |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| ✔️ Syntax check during compilation                            | Syntax check during compilation to improve code quality                                            |
| ⚡ Compile-time constant evaluation                           | Side-effect-free scripts are evaluated at build time and emitted as ~1 KB exes                     |
| 🧬 PowerShell Core / cross-platform target                    | `-Build @{Target='Core'}` targets PowerShell 7+ on Windows, Linux and macOS                        |
| 🔄 Powerful preprocessing feature                             | Preprocess the script before compilation, no need to copy and paste all content into the script    |
| 🛠️ `-Build @{Options=…}` parameter                            | New parameter, allowing you to further customize the generated executable file                     |
| 📦️ `-Build @{Minify=…}` parameter                             | Preprocess the script before compilation to generate a smaller executable file                     |
| 🌐 Support for compiling scripts and included files from URL  | Support for downloading icons from URL                                                             |
| 🖥️ Optimization of `App.Windowed` parameter                   | Optimized option handling and window title display, you can now set the title of the custom pop-up |
| ✍️ Code signing and icon auto-conversion                      | Sign output with a PFX certificate or a store thumbprint, and convert icons automatically          |
| 🧰 Extras: `exe21sp`, web server, context menu, interact mode | Decompile exes, compile online, right-click compile and more                                       |
| 🧹 Removed exe files                                          | Removed exe files from the code repository                                                         |
| 🌍 Multilingual support, pure script GUI                      | Better multilingual support, pure script GUI, support for dark mode                                |
| 📖 Separated cs files from ps1 files                          | Easier to read and maintain                                                                        |
| 🚀 More improvements                                          | And more...                                                                                        |

See the [localized readme](https://steve02081504.github.io/ps12exe/readme) for more details.

## Stargazers over time ⭐

[![Stargazers over time](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
