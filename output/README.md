# output/

hs-dev-skill / spec v2.4 规定的**构建与发布产物目录**（与 `build/` 中间产物分离）。

## 当前产物

| 路径 | 说明 |
|------|------|
| `windows-x64/ai_writer-1.0.0/` | Windows x64 Release 可分发目录（含 `ai_writer.exe`） |

运行：双击或执行 `windows-x64/ai_writer-1.0.0/ai_writer.exe`（需保留同目录 dll 与 `data/`）。

## 重新打包并落盘

```powershell
$env:Path = "E:\HardStone.Flutter\flutter\bin;" + $env:Path
flutter build windows --release
$src = "build\windows\x64\runner\Release"
$dst = "output\windows-x64\ai_writer-1.0.0"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item "$src\*" $dst -Recurse -Force
```

中间产物仍在 `build/`；**对外交付只认 `output/`**。
