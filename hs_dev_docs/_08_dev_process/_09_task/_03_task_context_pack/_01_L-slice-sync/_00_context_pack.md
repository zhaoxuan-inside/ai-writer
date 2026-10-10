# 上下文装载包 (Context Pack)：L-slice-sync

- **change_size**：`L`
- **任务 ID**：`L-slice-sync`
- **生成时间**：`2026-10-10T08:57:00Z`
- **状态**：`DONE`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **work_mode**：`IMPLEMENT`

---

## 1. 需求与目标（物化）

SyncProvider seam：Folder / GitHub Contents API / Native stub；手动 push/pull 覆盖确认；无冲突 UI。

验收（均已满足）：
- Folder push/pull overwrite 单测
- GitHub adapter + mocked Dio
- stub 抛 `SyncNotEnabledError`
- Settings 可选 provider
- Library Push/Pull 覆盖确认对话框

---

## 2. Seam 表

| Seam | 观察什么 | 抓住什么 | 抓不住什么 |
|------|----------|----------|------------|
| `FolderSyncProvider.push/pull` | 远端/本地文件内容与 `filesTouched` | 覆盖语义、未配置错误 | UI 文案 |
| `GitHubSyncProvider.push/pull` | Dio 请求路径/body；本地写出 | Contents API 覆盖写 | 真实 GitHub |
| `NativeCloudStubSyncProvider` | 抛 `SyncNotEnabledError` | stub 降级 | 真云实现 |
| Library SyncPush/Pull | 确认后调用 active provider | 覆盖确认门闩 | 设置页布局细节 |

---

## 3. 接口签名（物化 · ports §4）

```text
id / displayName / configure→ctor+SyncSettingsStore / isConfigured / requiresAccount
push(root, SyncSelection) -> SyncResult
pull(root, SyncSelection) -> SyncResult
```

覆盖：push 本地盖远端；pull 远端盖本地。无合并。

---

## 4. 缺口（续做发现）

- ~~`library_page` 仅 import sync，无 push/pull~~ → 已加确认对话框 + Push/Pull actions
- ~~`test/core/sync/` 不存在~~ → `sync_provider_test.dart` 8 cases 绿
- Settings provider 选择 + Folder/GitHub 配置已接线

---

## 5. 查询轨迹

- `process_log resume-scan` → `L-slice-sync` IN_PROGRESS @ S2 → S3/S4
- ports: `hs_dev_docs/_05_interface_design/ports_ai_sync_document.md` §4–5
- skill L2: `process_continuity.md`；IMPLEMENT: `testing.md`
- 验证：`flutter test` 32 绿；`verify_consistency` PASS
