---
name: ps12exe
description: Compile PowerShell scripts (.ps1) into standalone executables with ps12exe, and migrate legacy PS2EXE calls. Use when compiling a .ps1 file to .exe, when a script calls ps2exe / Invoke-PS2EXE / Win-PS2EXE, or when using ps12exe preprocessor directives (#_pragma, #_require, #_if, #_include).
---

# ps12exe

ps12exe compiles PowerShell scripts into executables. It improves on PS2EXE in many ways (smaller and faster output, in-script build directives, constant evaluation, more targets); the `README.md` shipped with the module has the details.

Install what is missing, then import:

```powershell
Install-Module ps12exe, PS2EXE2ps12exe -Scope CurrentUser
Import-Module ps12exe
```

## Read the sources instead of recalling

- `ps12exe -help` is the authoritative parameter list (the `-App`, `-Os`, `-Build`, `-Resources` and `-Signing` hashtables).
- For a PS2EXE call, read `Invoke-ps2exe` in the installed `PS2EXE2ps12exe` module (`Get-Module -ListAvailable PS2EXE2ps12exe`, then its `.psm1`). Rewrite the command name and every parameter following that mapping, and confirm the target keys with `ps12exe -help`.
- The `README.md` next to the installed ps12exe module documents the preprocessor directives.

## Do the work

1. Compile with `ps12exe -inputFile <script.ps1> [-outputFile <app.exe>] [...]`; `#_pragma` / `#_require` inside the script also set parameters.
2. Port `ps2exe` / `Invoke-PS2EXE` / `Win-PS2EXE` calls with the mapping read above.
