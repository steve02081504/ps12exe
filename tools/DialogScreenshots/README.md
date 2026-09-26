# Dialog screenshot comparison

Run `pwsh -File tools/DialogScreenshots/Compare-Dialogs.ps1` from the repository root to capture the built-in `msgbox`, `input`, `choice`, `readkey`, `constexpr`, and `progress` dialogs in three states: a system-light reference, a ps12exe light build (`App.DarkMode='Off'`), and a ps12exe dark build (`App.DarkMode='On'`). The script generates pixel-difference percentages and red-highlighted diff images, embeds them in an HTML report under the user temp directory, and opens the report when finished.

Use `-Scenario msgbox,choice` to limit the run; supported names are `msgbox`, `input`, `choice`, `readkey`, `constexpr`, and `progress`. The report and screenshots remain in the printed temp directory.

The script temporarily sets the current user's `AppsUseLightTheme` registry value to capture light references, switches it to dark for the dark builds, broadcasts `ImmersiveColorSet`, then restores the original value in `finally`. It requires a Windows interactive desktop session and writes only to the current user's theme setting. The MessageBox and progress references use Windows APIs; input and choice have no directly equivalent shell dialog, so their references use standard WinForms controls with system visual styles.

Pixel difference counts a pixel as different when the summed RGB channel difference exceeds 72 (24 per channel); size mismatches are counted as differences too.

The native screenshots are appearance references only. Verify that `OursLight` and `OursDark` use the same dialog implementation and geometry; their pixel differences are expected because their palettes differ. Do not switch a product dialog to a native Windows API just to reduce its diff against the reference.
