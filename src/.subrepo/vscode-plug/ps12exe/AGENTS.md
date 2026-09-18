# AGENTS.md — ps12exe VS Code extension

This directory is the `steve02081504.ps12exe` extension (packaged from
`src/.subrepo/vscode-plug/ps12exe` in the main repository). It is also the
`defaultFormatter` for PowerShell files in that repository, so the formatter has
to leave the repository's own scripts untouched.

## Commands

```powershell
npm install   # once
npm test      # @vscode/test-cli, reuses the local VS Code install
npm run build # package the VSIX and install it into the local VS Code
```

## Formatter invariants

- **Formatting the repository's `ps12exe.ps1` must be a byte-for-byte no-op**
  (after normalizing the BOM). This is enforced by
  `test/formatting.test.mjs`; keep it passing when touching anything below.
- The extension runs the official PowerShell formatter (`ms-vscode.powershell`,
  i.e. PowerShell Editor Services → PSScriptAnalyzer `Invoke-Formatter`) first
  and then applies the preprocessor indentation
  (`lib/format.mjs#formatPreprocessedText`).
- `test/officialFormatter.mjs` emulates that official formatter by mirroring the
  PSES `powershell.codeFormatting.*` → PSScriptAnalyzer mapping
  (`LanguageServerSettings.cs`) and running `Invoke-Formatter` through a
  PowerShell host. When the official extension changes its mapping, update this
  file.
- The repository `.vscode/settings.json` pins the style the formatter expects:
  tab indentation for `[powershell]` and
  `powershell.codeFormatting.newLineAfterOpenBrace: false`.

## Upstream bugs we work around

Keep these linked next to the code so they can be removed once upstream fixes
them. Record new workarounds the same way (issue URL + what to delete).

| Issue | Symptom | Workaround |
| --- | --- | --- |
| [PSScriptAnalyzer#2216](https://github.com/PowerShell/PSScriptAnalyzer/issues/2216) | `PSUseConsistentIndentation` double-indents the body of an attribute that opens a scriptblock (`[ArgumentCompleter({ … })]`): body at opener+2, closing `})]` at opener+1. Reproduces on 1.24.0/1.25.0 in both pwsh and Windows PowerShell; #2173 fixed the sibling `#2159` case but not this one. | `restoreAttributeIndentation` in `lib/preprocessor.mjs` detects the exact signature (body at opener+2, closing at opener+1) and pulls the region back one level. Delete the function, its export and the `repairs the official formatter attribute/scriptblock indentation` test once upstream ships a fix. |

## Notes

- **Find files with `rg --files` (or the Glob tool); never `Get-ChildItem -Recurse`.**
  The repository vendors `node_modules/` and `.vscode-test/` (a whole VS Code
  install), so a recursive listing explodes and gets truncated. Filter during the
  walk (`rg --files -g '!**/node_modules/**'`, or Glob's `path`/`pattern`);
  `-Exclude` only matches the leaf file name and a `Where-Object` at the end of
  the pipeline does not stop the traversal. Beware that `rg`/Glob skip
  dot-directories by default, so this extension's own
  `src/.subrepo/vscode-plug/ps12exe` needs `--hidden` (or `-uu`) to show up.
- PowerShell is always invoked with `-EncodedCommand` (Base64 UTF-16LE) to avoid
  every Windows command-line quoting pitfall.
- `-OutputFormat Text` is mandatory, otherwise a redirected host serializes
  `Write-Host` to stderr as a CLIXML blob.
- New UI strings go through `vscode.l10n.t('…')` and must be added verbatim to
  every `l10n/bundle.l10n.<locale>.json` (guarded by `test/l10n.test.mjs`).
