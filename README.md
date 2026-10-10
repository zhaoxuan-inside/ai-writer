# AI Writer

Local-first, AI-assisted writing client for personal creators.  
Targets Windows / Linux / macOS / iOS / Android (Flutter).

Product docs live under `hs_dev_docs/`. Visual identity: `DESIGN.md`.

## Prerequisites

- Flutter SDK (this repo was bootstrapped with Flutter 3.47+ / Dart 3.13+)
- If Flutter is not on PATH: `E:\tools\flutter\bin` (local clone used during setup)

```powershell
$env:Path = "E:\tools\flutter\bin;" + $env:Path
flutter pub get
flutter test
flutter run -d windows
```

## Status

- Design frozen (PRD / architecture / ports)
- Done: `DocumentStore` + library + Quill WYSIWYG + MarkdownBridge + AI assist
- Next: Sync providers (GitHub / WebDAV·folder / native stub)

**Windows note:** `flutter run` may require enabling Developer Mode (symlinks for plugins): `start ms-settings:developers`
