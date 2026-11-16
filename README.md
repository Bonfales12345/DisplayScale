# DisplayScale

DisplayScale is a native macOS utility for changing the built-in display resolution and adding HiDPI “looks like” modes to external displays that macOS does not offer them for by default.

## Build and install

Run `./build.sh` to create `build/DisplayScale.pkg`. By default, the installer places `DisplayScale.app` in `/Applications` and the matching preference pane in `/Library/PreferencePanes`. macOS Installer requests administrator authorization for these system-wide locations.

Use `./build.sh --without-prefpane` to create an app-only installer package. `--with-prefpane` is also available to explicitly include the pane.

For a local app build without an installer, run `./build-app.sh`; it writes `build/DisplayScale.app`.

By default, the app and pane are ad-hoc signed, and the installer package itself is unsigned. For Gatekeeper distribution, provide Developer ID Application and Developer ID Installer identities with `DISPLAY_SCALE_APP_SIGNING_IDENTITY` and `DISPLAY_SCALE_INSTALLER_SIGNING_IDENTITY`; the package must also be notarized. This machine has no Developer ID Installer identity, so its current package is unsigned.

## System Settings pane

DisplayScale appears in System Settings with the same display selector, scale preview, status, and controls as the standalone app. Both use the same `ContentView`, `DisplayScaleViewModel`, and `DisplayModeManager` implementation. The app remains available in `/Applications` as a standalone controller.

## Use

For the built-in display, choose one of the resolutions macOS reports and select **Set Resolution**. This applies the mode directly without installing an override or restarting.

For an external display, choose a UI percentage, select **Add HiDPI modes**, and approve the macOS administrator prompt. Restart once so macOS loads the display override, then reopen DisplayScale and select **Apply _n_% scale**.

DisplayScale reads built-in panel modes from macOS. For external displays, it reads the monitor’s preferred timing from EDID, calculates workspace dimensions from that native pixel size, and adds 2× render modes in 5% increments. External scale choices are clamped to a usable workspace size and a 250% maximum.

The system override is shared by every connected monitor with the same vendor and product ID. When replacing another app’s override, DisplayScale saves it beside the new file with a `.displayscale-backup` suffix and restores it when its modes are removed. Removing modes requires a restart to take effect.

The override format is an undocumented macOS mechanism. macOS can omit modes it considers unsupported, depending on the display, GPU, and operating system version.
