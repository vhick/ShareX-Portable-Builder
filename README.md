# ShareX True Portable Builder v1.0 (community build)

A **manual GitHub Actions builder** for the official **stable ShareX Windows x64 portable ZIP**. No installer, no `.paf.exe`, no application source compilation, and no automatic cleaning or uploading.

**Official upstream:** https://github.com/ShareX/ShareX/releases

## Build (no command-line tools needed)

1. Create a new GitHub repository named `ShareX-Portable-Builder`.
2. Download and extract the builder ZIP, then copy **all** its files (including `.github`) into the repository through GitHub Desktop.
3. Commit and push.
4. Open **Actions > Build ShareX Portable (Manual) > Run workflow**.
5. Leave `release_tag` set to `latest` to use the latest official stable release, or enter an explicit stable tag such as `v21.0.0`.
6. After the green checkmark, download the `ShareXPortable-Windows-x64` GitHub artifact.
7. Extract the *inner* `ShareXPortable-VERSION-x64.zip` directly into your `X:\PortableApps\` directory.
8. Launch `X:\PortableApps\ShareXPortable\ShareXPortable.exe`, then **Apps > Refresh App Icons** if the PortableApps menu was already running.

## Resulting structure

```text
ShareXPortable/
  ShareXPortable.exe            <- use this
  App/
    AppInfo/
      appinfo.ini               <- PortableApps Menu detection
      appicon.ico               <- official FULL multi-resolution ICO
      appicon_*.png
    ShareX/
      ShareX.exe                <- official binary, do not launch directly
      ... bundled ShareX files
  Data/
    ShareX/                    <- settings, hotkeys, history, recordings,
                                  screenshots, logs, uploader credentials
  Other/
    build-manifest.txt
    TESTING.txt
  START-HERE.txt
```

The ZIP preserves the **single `ShareXPortable` parent folder** used by PortableApps Menu.

## How portable mode works

Official ShareX normally finds its personal folder based on the `-portable` flag, a file named `Portable`, registry entries, or `PersonalPath.cfg`. The default official portable ZIP would save application data beside ShareX.exe. This launcher instead writes **`App/ShareX/PersonalPath.cfg`** with the *current* full path to `Data/ShareX` on every launch, so drive letter changes are handled automatically. It removes the upstream `Portable` sentinel during packaging.

**If an existing installed ShareX has a higher-priority personal path** (registry or legacy LocalAppData setting), the launcher switches to ShareX's official `-portable` mode. During that one session it moves `Data/ShareX` beside the binary, and moves it back after ShareX fully exits. It won't touch or delete the installed ShareX's settings. Avoid killing the launcher or replacing `App` while ShareX is running. A crash leaves recoverable session data beside the binary; launching again recovers it. If two conflicting folders are found, the launcher refuses to overwrite either.

The launcher never redirects global `APPDATA`, changes the registry, installs services, creates scheduled tasks, or automatically uploads screenshots. **User-enabled ShareX features** (Explorer integration, Windows startup, external tools, recording dependencies) can still interact with Windows. Settings may include paths that no longer exist on another PC.

## Updating

1. Close ShareX **from the tray icon** and confirm it has exited.
2. Re-run the builder for `latest`.
3. Extract the updated package, replace only `ShareXPortable.exe`, `App/`, `Other/` and `START-HERE.txt`.
4. **KEEP THE WHOLE `Data/` FOLDER**. This may contain both sensitive credentials and valuable screenshots.

### Verification and security

- Downloads **only** an exact official `ShareX-VERSION-portable-x64.zip` GitHub release asset.
- Requires an official upstream-published SHA-256 digest before trusting the download.
- Downloads original multi-resolution ShareX ICO from `https://getsharex.com/img/ShareX_Icon_Full.ico`.
- Validates expected executable, icon signature, metadata, and finished ZIP.
- Compiles a small community launcher using the Windows .NET Framework 4.x compiler.
- The GitHub workflow does **not** receive or upload your `Data/` folder.
- ShareX upload destination configuration may include access tokens. Never publish your `Data/ShareX` folder.
- Full Windows interactive launch, Portability / trace and recording tests must be done on your PC; a green workflow alone is **not** proof of zero traces.

**Upstream license/source:** https://github.com/ShareX/ShareX. Community launcher is not endorsed by the ShareX team or PortableApps.com.
