# 接口详设：核心端口（Ai / Sync / Document）

- **关联架构**：`_03_architecture_design/arch_design_ai_writer.md`
- **日期**：2026-10-10
- **状态**：APPROVED（阶段 3 冻结 · 2026-10-10）

---

## 1. DocumentStore

```text
list(root, path?) -> DocumentEntry[]
read(root, relativePath) -> DocumentContent   # utf8 markdown
write(root, relativePath, markdown) -> void
create(root, relativePath, initialMarkdown?) -> void
delete(root, relativePath) -> void
```

| 规则 | 说明 |
|------|------|
| 路径 | `relativePath` 必须规范化且落在 `root` 内；否则 `PathEscapeError` |
| 权威 | 磁盘 Markdown 为权威；调用方负责先经 MarkdownBridge 编码 |
| 错误 | `NotFound` / `IoError` / `PathEscapeError` |

**DocumentEntry**: `{ relativePath, name, kind: file|dir, modifiedAt? }`  
**DocumentContent**: `{ relativePath, markdown, modifiedAt? }`

---

## 2. MarkdownBridge

```text
fromMarkdown(markdown) -> EditorDocument   # Quill Document/Delta 等实现态
toMarkdown(editorDocument) -> string
```

| 规则 | 说明 |
|------|------|
| MVP 保真 | 标题 H1–H3、段落、粗/斜、有序/无序列表、引用、代码块 |
| 失败 | 无法解析时不静默丢正文；返回错误或保守纯文本段落 |

---

## 3. AiProvider

```text
complete(request: AiCompleteRequest) -> AiCompleteResult
```

**AiCompleteRequest**:
- `mode`: `continue | rewrite | expand | polish`
- `selectionMarkdown` | `cursorContext`（前后文窗口）
- `documentTitle?`
- `model?` / 使用 settings 默认

**AiCompleteResult**:
- `suggestionMarkdown`
- `raw?`（调试，勿默认展示）

| 规则 | 说明 |
|------|------|
| 无 Key | `NotConfigured` — UI 引导去 settings，编辑器不崩 |
| 网络/上游错 | `ProviderError` — 可重试；不自动写盘 |
| 超时 | 可配置；默认失败同上 |

OpenAI 兼容 Adapter：`baseUrl` + `apiKey` + `model` → Chat Completions。

---

## 4. SyncProvider

```text
id -> string
displayName -> string
configure(config) -> void          # 校验并持久化非密钥字段；密钥走 SecureStorage
isConfigured() -> bool
requiresAccount() -> bool          # 仅原生云真实现为 true；stub=false
push(root, selection: SyncSelection) -> SyncResult
pull(root, selection: SyncSelection) -> SyncResult
```

**SyncSelection**: `{ paths: relativePath[] }` 或 `{ entireLibrary: true }`（MVP 可先整库/单文件，实现期定）  
**SyncResult**: `{ ok, message?, bytesOrFiles? }`

| Provider | MVP | requiresAccount | 备注 |
|----------|-----|-----------------|------|
| `github` | 真 | false（用 PAT/OAuth token，非产品账号） | 推送到指定 repo/path |
| `webdav_or_folder` | 真 | false | WebDAV URL 或本地/同步文件夹路径 |
| `native_cloud` | stub | false（stub）；真后端时 true | 未启用返回明确消息 |

**覆盖语义**：push 用本地覆盖远端选定对象；pull 用远端覆盖本地。无合并、无冲突副本。

---

## 5. 六元组方法（用例级）

| method | 场景 | 主路径 | 补偿/降级 |
|--------|------|--------|-----------|
| `OpenOrCreateDocument` | UC_001 | DocumentStore.read/create → Bridge.fromMarkdown → 进入 editor | IoError 提示 |
| `SaveDocument` | UC_003 | Bridge.toMarkdown → DocumentStore.write | 写失败保留编辑态 |
| `RequestAiAssist` | UC_002 | AiProvider.complete → 展示建议 | ProviderError；可继续写 |
| `AcceptAiSuggestion` | UC_002 | 建议写入 editor 态；可随后 Save | 拒绝则丢弃建议 |
| `SyncPush` | UC_004 | 确认覆盖 → SyncProvider.push | 失败不改本地 |
| `SyncPull` | UC_004 | 确认覆盖 → SyncProvider.pull → 若当前文件被覆盖则重新 Open | 失败不改本地 |
| `NativeCloudSync` | UC_005 | stub 消息或未来 login→push/pull | 不影响本地 |

---

## 6. 本地「库」形态（非 DB 表）

无服务端库。等价 schema：

```text
{library_root}/
  **/*.md                 # 用户组织的任意目录树
app_support/              # 平台应用支持目录（非库内）
  preferences.json        # 最近 library_root、默认 model、provider 选择
  # secrets → Keychain / flutter_secure_storage（不进库目录、不同步）
```
