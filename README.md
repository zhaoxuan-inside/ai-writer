# AI Writer

Local-first, AI-assisted writing client for personal creators.  
Targets Windows / Linux / macOS / iOS / Android (Flutter).

Product docs live under `hs_dev_docs/`. Visual identity: `DESIGN.md`.

## Prerequisites

- Flutter SDK (bootstrapped with Flutter 3.47+ / Dart 3.13+)
- Windows desktop: Visual Studio 2022 Build Tools with C++ desktop workload
- Local Flutter used here: `E:\HardStone.Flutter\flutter\bin`

```powershell
$env:Path = "E:\HardStone.Flutter\flutter\bin;" + $env:Path
flutter pub get
flutter test
flutter run -d windows
```

## Package (Windows release)

按 hs-dev-skill（spec v2.4）：**交付产物落在 `output/`**，不是 `build/`。

```powershell
flutter build windows --release
$src = "build\windows\x64\runner\Release"
$dst = "output\windows-x64\ai_writer-1.0.0"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item "$src\*" $dst -Recurse -Force
# Deliverable:
#   output\windows-x64\ai_writer-1.0.0\ai_writer.exe
# Ship the whole folder (exe + flutter_windows.dll + data\ + plugins).
```

已落盘：`output/windows-x64/ai_writer-1.0.0/`（≈31 MB / 14 files）；exe 冒烟通过。详见 `output/README.md`。

## E2E / verification

```powershell
flutter test
# Includes test/e2e/mvp_draft_ai_persist_test.dart
#   draft → AI rewrite accept → persist → reopen
#   AI NotConfigured does not block local save
#   folder sync push/pull overwrite
```

Latest gate: **37** automated tests green + Windows release build + exe smoke launch.

## Status

- Design frozen (PRD / architecture / ports)
- MVP slices done: DocumentStore, library, Quill WYSIWYG, AI assist, Sync (Folder/GitHub/NativeStub)
- Secrets (API key / GitHub PAT) use app-private `SharedPreferences` via `SecretStore` so Windows builds without VS ATL (`flutter_secure_storage` C++ plugin removed)

**Windows note:** Developer Mode may be required for plugin symlinks during `flutter run`: `start ms-settings:developers`
