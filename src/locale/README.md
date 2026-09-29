# Localization

Each `<lang>.ps1` file in this folder is a single PowerShell hashtable holding one language's UI strings and help data. The GUI is generated from `src/GUI/Schema.ps1`, so there are no per-language WinForms layout files anymore.

The loader (`src/LocaleLoader.ps1`) auto-discovers every `*.ps1` file whose name looks like a locale code (for example `en-US`, `zh-CN`, `pt-BR`), so dropping a new file into this folder is enough. Tab completion (`src/LocaleArgCompleter.ps1`) lists the same set.

## File layout

A locale file starts with:

- `LangName` and `LangID`: the display name and the language code. `LangID` must match the file name.
- Flat strings for menus, dialogs, and messages (for example `CompileTitle`, `AskSaveCfg`, `CfgFileLabelHead`).
- `ConsoleHelpData`: the `ps12exe` command-line help. `Usage` is the usage line and `PrarmsData` is an ordered hashtable (possibly nested) of parameter descriptions.
- `GUIHelpData`, `IntegrationHelpData`, `WebServerHelpData`, `exe21spHelpData`: help for the other entry points.
- `CompilingI18nData`, `WebServerI18nData`, `InteractI18nData`, `exe21spInteractI18nData`, `exe21spI18nData`: runtime messages.
- `GUI`: the visible strings used by `ps12exeGUI`.

## GUI strings (`GUI`)

GUI strings live in the nested `GUI` object. Its shape follows the schema in `src/GUI/Schema.ps1`, grouping strings by kind:

- `Page.<Name>`, `Group.<Name>`: page and group titles.
- `Field.<Path>`: label for the field with that parameter path (for example `Field.Build.Core.Trimmed`), plus `Field.Build.DllExports.Label`/`Help`/`FuncName`/`ReturnType`/`Params` for the export editor.
- `Button.*`, `Dialog.*`, `Window.Title`, `Log.*`, `Label.*`: buttons, file dialogs, window title, log lines, and labels.

`Get-GUIText <Key>` walks the dotted key through this object and falls back to the current language, then to `en-US`, then to the raw key, so a missing translation never crashes the GUI. When adding a parameter:

1. Add the field to `src/GUI/Schema.ps1`.
2. Add the matching `Field.<Path>` entry to `GUI` in every locale file.
3. If it is a real `ps12exe` parameter, also update `ConsoleHelpData` (`Usage` and `PrarmsData`) in every locale file and the parameter tables in `docs/README_*.md`.

## Adding a new locale

1. Copy `en-US.ps1` to `<lang>.ps1` (use a locale code such as `pt-BR`).
2. Set `LangName` and `LangID` to the new locale.
3. Translate every value, including all of `GUI`, `ConsoleHelpData`, and the runtime message tables.
4. Make sure the file is saved as UTF-8 with BOM.

`en-US.ps1` is the reference: it must stay complete and idiomatic, because it is also the fallback for every other language.
