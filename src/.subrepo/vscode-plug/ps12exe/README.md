# ps12exe VS Code Extension

Compile PowerShell scripts (`.ps1`) into standalone executables and open **ps12exeGUI**, directly from Visual Studio Code. The extension is a thin, native front-end for the [ps12exe](https://github.com/steve02081504/ps12exe) PowerShell module: compiling from VS Code behaves exactly like running `ps12exe <your-script.ps1>` in a terminal.

## Features

- **Compile to EXE** — right-click a `.ps1` file in the Explorer, right-click inside the editor, or use the editor title button. The script is passed to `ps12exe` unchanged, so it produces the same output as the command line.
- **Open in ps12exeGUI** — right-click a `.ps1` file to launch the graphical front-end for advanced options (icon, version info, architecture, code signing, …).
- **Output channel** — the full ps12exe console output is streamed to the `ps12exe` output channel.
- **Progress & cancellation** — long compilations show a progress notification and can be cancelled; the whole process tree is terminated cleanly.
- **Reveal output** — on success, jump straight to the generated `.exe`.
- **Automatic language selection** — the extension follows the VS Code display language and forwards it to ps12exe/ps12exeGUI via `-Localize`.
- **Robust process handling** — script paths are passed through PowerShell's `-EncodedCommand`, so quotes, spaces and non-ASCII characters never break the invocation.

## Preprocessor support

The ps12exe preprocessor directives (`#_if` / `#_else` / `#_endif`, `#_include*`, `#_pragma`, `#_require`, `#_!!`, …) get first-class editor support:

- **Syntax highlighting** — an injected TextMate grammar colors the directives, their conditions (`PSEXE` / `PSScript`) and pragma names. The `#_!!` payload and `$( … )` sub-expressions inside `#_pragma` are highlighted as embedded PowerShell.
- **Diagnostics** — unclosed `#_if`, nested (dead-code) `#_if`, unknown conditions, stray or duplicate `#_else` / `#_endif` are reported as you type. Directives followed by a trailing comment (e.g. `#_if PSEXE #why`) are handled exactly like ps12exe does.
- **Auto-close** — finishing a `#_if …` line with Enter inserts the matching `#_endif` on the next line, with the cursor left on the block body. Disable with `ps12exe.autoCloseIf`.
- **Folding** — every `#_if … #_endif` block folds, nested blocks included, and the `#_endif` stays visible (like the `}` of an `if`). These ranges are additive: VS Code merges them with the PowerShell extension's own AST-based folding, so no provider is disabled. In the `#_if PSScript` + `if (!$nested) {` idiom the real `if` opens on the block's only body line, so both fold markers appear; that is a display overlap, not a broken fold.
- **`#_!!` toggle** — the **ps12exe: Toggle `#_!!` Escape Markers** editor context-menu command adds `#_!!` to every plain line of the selection (or of the whole file when nothing is selected) and removes it from the lines that already carry it. Other preprocessor directives, here-string bodies and block comments are left untouched, so no directive is ever turned into a comment.
- **Go to definition** — Ctrl+click / F12 on the path of an `#_include*` directive or of `#_pragma iconFile` jumps to the referenced file (`$PSScriptRoot` and relative paths are resolved).
- **Formatting** — the extension registers a `powershell` formatter that runs the official PowerShell formatter first (via the PowerShell extension) and then indents the preprocessor blocks. A block covering at least 90% of the file is left un-indented (only the largest such block). A block whose body is not a complete PowerShell unit — for example an `if` opened inside the block and closed after its `#_endif` — is left un-indented too, using the real PowerShell parser. If the PowerShell extension is missing, you are offered to install it. The formatter is available through *Format Document*, format-on-save and the **ps12exe: Format Preprocessor Blocks** code action.

## Localization

The extension UI is localized into every language ps12exe ships. It activates automatically when VS Code runs in one of these languages:

| Language | Locale |
| --- | --- |
| English (United States) | `en`, `en-US` |
| English (United Kingdom) | `en-gb` |
| 简体中文 | `zh-cn` |
| 日本語 | `ja` |
| Français | `fr` |
| Español | `es` |
| हिंदी | `hi` |

Command titles, notifications and the `-Localize` value passed to ps12exe are all derived from the VS Code language.

## Requirements

- **Visual Studio Code** 1.100.0 or newer (the extension is a native ES module extension).
- **PowerShell** — Windows PowerShell 5.1+ or PowerShell 7+ (`pwsh`). The extension probes `pwsh` first and falls back to `powershell`.
- **ps12exe PowerShell module** — you normally don't have to do anything: the extension installs the latest version automatically when the module is missing and keeps it updated on startup. You can also install it manually at any time:

  ```powershell
  Install-Module ps12exe -Scope CurrentUser
  ```

  Set `ps12exe.autoUpdate` to `false` to opt out of the automatic install/update.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| `ps12exe.autoUpdate` | `true` | Automatically install the ps12exe module when missing and update it to the latest PSGallery version on startup. |
| `ps12exe.autoCloseIf` | `true` | Insert the matching `#_endif` when a `#_if …` line is completed with Enter. |

The old, manually maintained development build (`0.0.0`) is never overwritten by the auto-update.

## Usage

1. Install the `ps12exe` module (see above).
2. Open a `.ps1` file.
3. Compile it with any of:
   - Explorer: right-click the file → **Compile to EXE**
   - Editor: right-click → **Compile to EXE**
   - Editor title bar: click the package icon
   - Command palette: **ps12exe: Compile to EXE**
4. The executable is written next to the script (`<name>.exe`) unless the script uses a configuration file.
5. To tweak options such as the icon or version, choose **Open in ps12exeGUI** instead.

For advanced command-line options, see the [ps12exe documentation](https://github.com/steve02081504/ps12exe#usage).

## Troubleshooting

- **ps12exe could not be installed automatically** — the extension offers to open a terminal and run `Install-Module ps12exe -Scope CurrentUser`; you can also run it yourself. Note that Windows PowerShell and PowerShell 7 use different per-user module paths; the extension prefers a host that already has the module.
- **"No PowerShell host was found"** — install [PowerShell 7](https://aka.ms/powershell) or make sure `powershell.exe` is on `PATH`.
- **Compilation errors** — open the `ps12exe` output channel (the notification also links to it) for the full log.

## Related

- [ps12exe repository](https://github.com/steve02081504/ps12exe)
- [Localized readme](https://steve02081504.github.io/ps12exe/readme)
- [PS2EXE2ps12exe](https://github.com/steve02081504/ps12exe/tree/master/src/.subrepo/PS2EXE2ps12exe)

## Development

```powershell
npm install
npm test
```

The extension is written as native ES modules (`"type": "module"`, `.mjs` entry and modules), which requires VS Code 1.100+. `npm test` reuses the VS Code installed on this machine; it is located through `@steve02081504/exec`'s `where_command`, and `PS12EXE_VSCODE_EXECUTABLE_PATH` can point it at a specific executable. When the install lives on another Windows drive, a junction is created under `.vscode-test/` because `@vscode/test-electron` silently skips tests for cross-drive installs. Without a local install a VS Code copy is downloaded once into `.vscode-test/` and cached.

Notes for maintainers (all localized through `l10n/` and `package.nls.*.json`):

- PowerShell is always invoked with `-EncodedCommand` (Base64 UTF-16LE). This sidesteps every Windows command line quoting pitfall for paths with spaces, quotes or non-ASCII characters.
- Formatter completeness check: each preprocessor block's branch bodies are parsed in one batched call with `[System.Management.Automation.Language.Parser]::ParseInput`; bodies that produce parse errors are never pushed one level deeper. A bare attribute body (`[ArgumentCompleter({…})]`) is retried with a trailing dummy statement so it is not mistaken for an incomplete block. Results are cached per document text.
- The formatter must leave `ps12exe.ps1` byte-for-byte unchanged. `test/officialFormatter.mjs` emulates the official PowerShell formatter by mirroring PowerShell Editor Services' `powershell.codeFormatting.*` → PSScriptAnalyzer mapping, and `test/formatting.test.mjs` asserts the whole pipeline is a no-op (and idempotent) on the repository's script. The repository `.vscode/settings.json` pins tab indentation and `powershell.codeFormatting.newLineAfterOpenBrace: false`; `restoreAttributeIndentation` (in `lib/preprocessor.mjs`) undoes PSScriptAnalyzer's extra indent around `[Attr({` scriptblocks.
- `-OutputFormat Text` is mandatory; without it a redirected `pwsh`/`powershell` serializes every `Write-Host` call to stderr as a CLIXML blob (`#< CLIXML …`).
- The wrapper script sets `$global:LASTEXITCODE = 0` before calling `ps12exe` and ends with `exit $LASTEXITCODE`, because ps12exe reports failures through `$LASTEXITCODE` rather than a terminating error.
- Add a new UI string by calling `vscode.l10n.t('…')` and adding the exact same English string as a key to every `l10n/bundle.l10n.<locale>.json`.

## License

[LGPL-3.0-only](https://github.com/steve02081504/ps12exe/blob/master/LICENSE.md)
