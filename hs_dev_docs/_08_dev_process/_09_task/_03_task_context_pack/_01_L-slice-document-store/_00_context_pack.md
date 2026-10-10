# 上下文装载包 (Context Pack)：L-slice-document-store

- **change_size**：`L`
- **任务 ID**：`L-slice-document-store`
- **生成时间**：`2026-10-10T07:53:52Z`
- **状态**：`IN_PROGRESS`
- **work_mode**：`IMPLEMENT`
- **装载纪律**：必须物化切片正文；禁止只写路径。

---

## 0. Seam 确认（测试面）

| Seam | 观察什么 | 抓住什么 | 抓不住什么 |
|------|----------|----------|------------|
| `DocumentStore` | list/read/write/create/delete 行为与错误 | 路径逃逸拒绝；Markdown 往返；目录列表 | UI、Quill、同步 |

---

## 1. 需求与目标（物化）

来自 PRD DoD：
- 五端：在用户指定工作目录内新建/编辑/本地保存/再打开一致。
- 文档组织：用户指定 library_root；文件夹层级即组织方式。

本切片只做：**DocumentStore 端口 + Memory/Filesystem Adapter + 单测绿**。

---

## 2. 数据模型切片（物化）

来自 `ports_ai_sync_document.md`：
```text
{library_root}/**/*.md
DocumentEntry: { relativePath, name, kind: file|dir, modifiedAt? }
DocumentContent: { relativePath, markdown, modifiedAt? }
```
无服务端 DB。

---

## 3. 接口与六元组签名（物化）

```text
list(root, path?) -> DocumentEntry[]
read(root, relativePath) -> DocumentContent
write(root, relativePath, markdown) -> void
create(root, relativePath, initialMarkdown?) -> void
delete(root, relativePath) -> void
```
错误：`NotFound` / `IoError` / `PathEscapeError`  
用例：`OpenOrCreateDocument` / `SaveDocument` 依赖本 seam。

---

## 4. 调用链与 Mock 契约（物化）

- Adapter：`FilesystemDocumentStore`、`MemoryDocumentStore`（测）
- 路径必须 normalize 且 `isWithinRoot`
- 不依赖 Flutter UI；优先纯 Dart 可测

---

## 5. 查询轨迹（降 Token）

- 已读：`testing.md`、`ports_ai_sync_document.md`、`arch_design_ai_writer.md`
- Flutter SDK：本机安装中（choco）
