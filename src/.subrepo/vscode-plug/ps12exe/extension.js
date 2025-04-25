const vscode = require('vscode');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execPromise = promisify(exec);

function activate(context) {
    console.log('Extension "ps12exe" is now active!');

    // Register the 'Compile To Exe' command
    let compileCommand = vscode.commands.registerCommand(
        'ps12exe.compilePs1ToExe',
        async (uri) => {
            // Get the file URI: from context menu (uri) or active editor
            let fileUri = uri;
            if (!fileUri) {
                const editor = vscode.window.activeTextEditor;
                if (editor) {
                    fileUri = editor.document.uri;
                }
            }

            // Ensure we have a file URI and it's a .ps1 file
            if (!fileUri || fileUri.scheme !== 'file') {
                vscode.window.showWarningMessage('Please open or select a file to compile.');
                return;
            }
            if (path.extname(fileUri.fsPath).toLowerCase() !== '.ps1') {
                 vscode.window.showWarningMessage('Selected file is not a PS1 file.');
                 return;
            }

            const ps1FilePath = fileUri.fsPath;
            const outputDir = path.dirname(ps1FilePath);
            const fileNameWithoutExt = path.basename(ps1FilePath, '.ps1');

            // Construct the PowerShell command to run ps12exe
            // We need to launch powershell.exe and execute the command within it
            // Paths with spaces need to be quoted. In PowerShell's -Command string,
            // you need to escape quotes that are part of the command arguments.
            // Using \" inside the -Command string achieves this.
            const command = `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8; ps12exe \\"${ps1FilePath}\\""`;

            vscode.window.showInformationMessage(`Starting compilation of "${path.basename(ps1FilePath)}" to EXE...`);

            try {
                // Execute the command
                const { stdout, stderr } = await execPromise(command);

                // ps12exe often outputs progress/info to stdout, and errors to stderr
                // A non-empty stderr usually indicates an error.
                if (stderr) {
                    vscode.window.showErrorMessage(`Compilation failed: ${stderr.trim()}`);
                    console.error(`ps12exe stderr:\n${stderr}`);
                } else {
                    vscode.window.showInformationMessage(`Successfully compiled "${path.basename(ps1FilePath)}"`);
                    if (stdout) {
                        console.log(`ps12exe stdout:\n${stdout}`);
                    }
                }

            } catch (error) {
                // This catches errors like command not found, or execution issues
                vscode.window.showErrorMessage(`Failed to execute compilation command: ${error.message}`);
                console.error(`Error running ps12exe command: ${error}`);
            }
        }
    );

    // Register the 'ps12exeGUI' command
    let guiCommand = vscode.commands.registerCommand(
        'ps12exe.ps12exeGUI',
        async (uri) => {
             // Get the file URI - though ps12exeGUI can run without a file,
             // the menu is configured for .ps1 files, so we can potentially
             // pass the file path to the GUI if it supports it.
             // Based on the docs "ps12exeGUI" launches the GUI,
             // simplest is just running the command.
             let fileUri = uri;
             if (!fileUri) {
                 const editor = vscode.window.activeTextEditor;
                 if (editor) {
                     fileUri = editor.document.uri;
                 }
             }

             // Although the GUI *can* run without a file, the menu trigger
             // requires a .ps1 file. We might as well check.
             if (!fileUri || fileUri.scheme !== 'file' || path.extname(fileUri.fsPath).toLowerCase() !== '.ps1') {
                 // User might expect the GUI to open anyway, maybe change this to info?
                 // Or remove the when clause from package.json for the GUI command?
                 // Let's stick to the when clause for now and show a warning.
                 vscode.window.showWarningMessage('Please select a PS1 file to launch ps12exeGUI.');
                 return;
            }
            // Note: The ps12exe documentation doesn't explicitly show passing a file
            // path to ps12exeGUI, so we'll just launch the GUI for now.
            // If the GUI supports it, the command might be:
            // const command = `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "ps12exeGUI -file \\"${fileUri.fsPath}\\""`;
            // But let's use the simpler version first:
            const command = `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8; ps12exeGUI -PS1File \\"${fileUri.fsPath}\\""`;


            vscode.window.showInformationMessage('Launching ps12exeGUI...');

            try {
                // Execute the command
                // We don't wait for the GUI process to exit, just check if the launch command succeeded
                exec(command, (error, stdout, stderr) => {
                    if (error) {
                         vscode.window.showErrorMessage(`Failed to launch ps12exeGUI: ${error.message}`);
                         console.error(`Error launching ps12exeGUI: ${error}`);
                    } else if (stderr) {
                         // ps12exeGUI launch might output something to stderr even on success?
                         // Or maybe it indicates a non-fatal issue? Hard to say without testing.
                         // For now, if there's stderr but no primary error, treat it as a potential warning.
                         vscode.log('ps12exeGUI launch stderr:\n' + stderr);
                         // vscode.window.showWarningMessage(`ps12exeGUI launched, but with warnings: ${stderr.trim()}`); // Maybe too noisy
                    } else {
                        // Successfully launched command, GUI should appear in a separate window
                        console.log('ps12exeGUI launch command executed successfully.');
                    }
                });

            } catch (error) {
                // This catch block might be redundant with the exec callback, but good practice
                vscode.window.showErrorMessage(`Failed to execute ps12exeGUI command: ${error.message}`);
                console.error(`Error running ps12exeGUI command: ${error}`);
            }
        }
    );


    // Add commands to the extension's subscriptions so they are disposed of when the extension is deactivated
    context.subscriptions.push(compileCommand);
    context.subscriptions.push(guiCommand);
}

function deactivate() {
    // Any cleanup code goes here
    console.log('Extension "ps12exe" is now deactivated.');
}

module.exports = {
	activate,
	deactivate
};
