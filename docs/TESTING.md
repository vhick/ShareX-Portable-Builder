SHAREX PORTABLE - WINDOWS VALIDATION

1. Extract ShareXPortable-VERSION-x64.zip into X:\PortableApps\ .
2. Confirm X:\PortableApps\ShareXPortable\ShareXPortable.exe and App\AppInfo\appinfo.ini exist.
3. Start ShareXPortable.exe (first launch requires no setup).
4. Under ShareX Application settings > Paths, check the personal folder is inside Data\ShareX.
5. Change a hotkey or other harmless setting and quit ShareX using the tray icon.
6. Reopen and confirm it survived. Take a test screenshot; confirm Screenshots or history is in Data\ShareX.
7. Exit completely. Check that App\ShareX\ShareX is absent; if it exists, stop and inspect before upgrading.
8. Do not enable Start with Windows, right-click Explorer integration, file associations or scheduled tasks.
9. Refresh PortableApps menu icons and confirm ShareX Portable is listed.
10. Try again after changing the drive letter (without modifying Data\).
11. Repeat with an existing regular ShareX installation, if applicable. In this case the launcher
    may temporarily run ShareX native -portable mode from App and MOVE its data back into Data
    after ShareX fully exits. Never update App or kill the launcher while ShareX is open.
12. Use Process Monitor to inspect application-owned files and registry operations if checking
    strict portability. Windows may generate OS-owned caches, compatibility traces or logs.

IMPORTANT:
- Test screenshot capture, OCR, recording, destination credentials (after adding your own),
  FFmpeg/recorder download paths, task logs and output directory preferences.
- User-configured absolute paths, external tools and upload credentials can be machine-specific.
- ShareX may have single-instance/hotkey conflicts with an installed copy. Exit that copy first.
- The builder does not enable automatic uploads, but ShareX workflows can upload data if configured.
- Do not share Data\ShareX or unredacted logs: they may contain secrets and screenshots.
- Never delete other programs' AppData, registry keys or Windows history to chase "zero traces".
