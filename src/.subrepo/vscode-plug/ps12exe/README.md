# ps12exe VS Code Extension

This extension provides a convenient way to compile your PowerShell (`.ps1`) scripts into executable files (`.exe`) directly within Visual Studio Code, leveraging the power of the `ps12exe` PowerShell module. It adds context menu items and an editor title button for quick access to the compilation feature and the `ps12exe` GUI.

## Features

This extension integrates with VS Code to offer the following features for `.ps1` files:

- **Compile via Editor Title Button:** A dedicated button appears in the top-right corner of the editor window when a `.ps1` file is active, allowing you to trigger compilation with a single click.
  ![Editor Title Button - Placeholder](images/editor-button-placeholder.png)
  _(Note: Replace `images/editor-button-placeholder.png` with an actual screenshot of the button in VS Code.)_

- **Compile via Editor Context Menu:** Right-click anywhere within an open `.ps1` file's editor, and you'll find a "Compile To Exe" option in the context menu.
  ![Editor Context Menu - Placeholder](images/editor-context-placeholder.png)
  _(Note: Replace `images/editor-context-placeholder.png` with an actual screenshot of the context menu.)_

- **Compile via Explorer Context Menu:** Right-click on a `.ps1` file in the VS Code File Explorer, and you'll find a "Compile To Exe" option.
  ![Explorer Context Menu - Placeholder](images/explorer-compile-context-placeholder.png)
  _(Note: Replace `images/explorer-compile-context-placeholder.png` with an actual screenshot of the explorer context menu for compilation.)_

- **Launch ps12exe GUI:** Right-click on a `.ps1` file in the VS Code File Explorer, and you can select "ps12exeGUI" to launch the graphical interface of the `ps12exe` module for more advanced compilation options.
  ![Explorer GUI Context Menu - Placeholder](images/explorer-gui-context-placeholder.png)
  _(Note: Replace `images/explorer-gui-context-placeholder.png` with an actual screenshot of the explorer context menu for the GUI.)_

- **Integrated Notifications:** Get feedback on compilation success or failure directly through VS Code notifications.

## Requirements

To use this extension, you need:

- **Visual Studio Code** (version 1.99.0 or higher).
- **PowerShell:** You need either Windows PowerShell 5.1+ or PowerShell Core (pwsh) installed. The extension primarily targets Windows due to the nature of compiling to `.exe` files, and the current implementation explicitly calls `powershell.exe`.
- The **`ps12exe` PowerShell Module:** This extension is just an interface; the actual compilation is done by the `ps12exe` module. You must install it in your PowerShell environment. Open PowerShell and run:

  ```powershell
  Install-Module -Name ps12exe -Scope CurrentUser # Or -Scope AllUsers
  ```

  For more details on `ps12exe` itself, its features, and advanced usage, please refer to the [official ps12exe GitHub repository](https://github.com/steve02081504/ps12exe).

## Extension Settings

This extension currently does not contribute any user-configurable settings through VS Code's settings interface. Compilation uses the default `ps12exe` parameters (`-file <input> -output <output>`). For advanced options, please use the integrated `ps12exeGUI` command or run `ps12exe` manually in a terminal.

## Known Issues

- The extension relies on the `ps12exe` PowerShell module being correctly installed and discoverable in your PowerShell environment. If compilation fails, verify the `ps12exe` module is installed and accessible by running `Get-Command ps12exe` in PowerShell.
- The default compilation command is basic. For features like adding icons, including extra files, selecting platform/architecture, etc., you must use the `ps12exeGUI` or run the `ps12exe` command manually with parameters.
- Detailed error messages from `ps12exe` itself might only appear in the VS Code output console or notifications, and may require referring to the `ps12exe` documentation for interpretation.
- Primarily tested on Windows environments. Compatibility with PowerShell Core on other operating systems might vary based on `ps12exe`'s capabilities there.

## Release Notes

### 0.0.1

- Initial release of the ps12exe VS Code Extension.
- Adds "Compile To Exe" command accessible via editor title button, editor context menu, and explorer context menu for `.ps1` files.
- Adds "ps12exeGUI" command accessible via explorer context menu for `.ps1` files.
- Provides basic success/failure notifications for compilation.

---

## Working with Markdown

You can author your README using Visual Studio Code. Here are some useful editor keyboard shortcuts:

- Split the editor (`Cmd+\` on macOS or `Ctrl+\` on Windows and Linux)
- Toggle preview (`Shift+Cmd+V` on macOS or `Shift+Ctrl+V` on Windows and Linux)
- Press `Ctrl+Space` (Windows, Linux, macOS) to see a list of Markdown snippets

For more information:

- [Visual Studio Code's Markdown Support](https://code.visualstudio.com/docs/languages/markdown)
- [Markdown Syntax Reference](https://docs.github.com/en/get-started/writing-on-github/getting-startedwith-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)

**Enjoy simplifying your PowerShell script compilation!**
