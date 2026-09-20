# ps12exe VS Code Extension

Compile PowerShell scripts (`.ps1`) into standalone executables and open **ps12exeGUI**, directly from Visual Studio Code.

## Features

- **Compile to EXE** — right-click a `.ps1` file in the Explorer or editor, use the editor title button, or run **ps12exe: Compile to EXE** from the command palette. The executable is written next to the script.
- **Open in ps12exeGUI** — launch the graphical front-end for advanced options such as icon, version info, architecture and code signing.
- **Output channel** — all ps12exe console output is streamed to the `ps12exe` output channel.
- **Progress & cancellation** — long compilations show a progress notification and can be cancelled.
- **Reveal output** — on success, jump straight to the generated `.exe`.
- **Automatic language selection** — the extension follows the VS Code display language.
- **Automatic ps12exe install/update** — the ps12exe module is installed when missing and kept up to date; opt out with `ps12exe.autoUpdate`.
- **Agent skill** — a bundled `ps12exe` Agent Skill tells the agent how to use `ps12exe` and `PS2EXE2ps12exe`.
- **Embedded-exe source editor** — open a compiled `.exe` to view and edit the embedded script.

## Preprocessor support

The ps12exe preprocessor directives (`#_if` / `#_else` / `#_endif`, `#_include*`, `#_pragma`, `#_require`, `#_!!`, …) get first-class editor support:

- **Syntax highlighting** — directives, conditions and pragma names are coloured.
- **Diagnostics & quick fixes** — reports unbalanced blocks and unknown conditions; offers one-click migration of deprecated PS2EXE calls to the ps12exe object API, rewrites module installs to `#_require`, and replaces a deprecated `#_require PS2EXE` with `#_require ps12exe`. Silence any warning with `# use_ps12exe:ignore`.
- **Auto-close** — completing a `#_if …` line with Enter inserts the matching `#_endif`. Disable with `ps12exe.autoCloseIf`.
- **Folding** — every `#_if … #_endif` block folds, nested blocks included.
- **`#_!!` toggle** — **ps12exe: Toggle `#_!!` Escape Markers** adds or removes the marker on the selection (or the whole file).
- **Go to definition** — open the file referenced by an `#_include*` path or `#_pragma Resources.Icon`.
- **Hover** — shows a localized summary and a README link for a directive; a module name in `#_require` shows its PowerShell Gallery info.
- **Completion** — suggests directives, conditions and `#_pragma` parameters, each with a localized hint.
- **Formatting** — formats preprocessor blocks through _Format Document_, format-on-save or the **ps12exe: Format Preprocessor Blocks** action. Requires the PowerShell extension (see [Requirements](#requirements)).

## Localization

The extension UI is localized into every language ps12exe ships. It activates automatically when VS Code runs in one of these languages:

| Language                 | Locale        |
| ------------------------ | ------------- |
| English (United States)  | `en`, `en-US` |
| English (United Kingdom) | `en-gb`       |
| 简体中文                 | `zh-cn`       |
| 日本語                   | `ja`          |
| Français                 | `fr`          |
| Español                  | `es`          |
| हिंदी                    | `hi`          |

Command titles and notifications follow the VS Code display language.

## Requirements

- **Visual Studio Code** 1.100.0 or newer.
- **PowerShell** — Windows PowerShell 5.1+ or PowerShell 7+ (`pwsh`).
- **ps12exe PowerShell module** — installed and updated automatically when missing. You can also install it manually at any time:

  ```powershell
  Install-Module ps12exe -Scope CurrentUser
  ```

- **PowerShell extension** (`ms-vscode.powershell`) — needed for the formatter.

## Settings

| Setting               | Default | Description                                                                                                     |
| --------------------- | ------- | --------------------------------------------------------------------------------------------------------------- |
| `ps12exe.autoUpdate`  | `true`  | Automatically install the ps12exe module when missing and update it to the latest PSGallery version on startup. |
| `ps12exe.autoCloseIf` | `true`  | Insert the matching `#_endif` when a `#_if …` line is completed with Enter.                                     |

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

- **ps12exe could not be installed automatically** — open a terminal and run `Install-Module ps12exe -Scope CurrentUser`.
- **"No PowerShell host was found"** — install [PowerShell 7](https://aka.ms/powershell) or make sure `powershell.exe` is on `PATH`.
- **Compilation errors** — open the `ps12exe` output channel for the full log.

## Related

- [ps12exe repository](https://github.com/steve02081504/ps12exe)
- [Localized readme](https://steve02081504.github.io/ps12exe/readme)
- [PS2EXE2ps12exe](https://github.com/steve02081504/ps12exe/tree/master/src/.subrepo/PS2EXE2ps12exe)

## Development

```powershell
npm install   # once
npm test      # run the test suite
npm run build # package the extension and install it locally
```

See `AGENTS.md` for the maintainer notes.

## License

[LGPL-3.0-only](https://github.com/steve02081504/ps12exe/blob/master/LICENSE.md)
