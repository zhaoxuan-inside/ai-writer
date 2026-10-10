# 架构决策记录 (ADR)：客户端技术栈

- **编号**：ADR-001
- **状态**：ACCEPTED
- **日期**：2026-10-10
- **作者**：hardstone

---

## 1. 背景与问题阐述 (Context)

已冻结 PRD 要求：Windows / Linux / macOS / iOS / Android 同进；WYSIWYG；用户指定工作目录；GitHub + WebDAV/文件夹同步；原生云 SyncProvider stub；默认免注册；视觉对标 iA Writer。需要选定单一主客户端栈与编辑器，避免多套 UI 码基。

---

## 2. 备选方案权衡 (Options Considered)

| 方案 | 优势 | 劣势 | 成本与风险 |
|---|---|---|---|
| **A：Flutter + flutter_quill** | 五端含 Linux；编辑器星数最高；适配器易测 | Quill↔Markdown 需自建保真；默认 UI 偏重需克制 | 中（编解码测试债） |
| **B：.NET MAUI** | C# 桌面+移动 | **无官方 Linux**；编辑器生态弱 | 高（违背 PRD） |
| **C：Kotlin Compose Multiplatform** | 可共享 UI；Kotlin 生态 | 长文编辑器与五端交付成熟度低于 Flutter | 中高 |
| **D：Flutter + super_editor** | 文档 toolkit、Markdown 配套 | API/发布仍在演进 | 中（进度风险） |

详表见 `hs_dev_docs/_02_tech_select/tech_select_client_stack.md`。

---

## 3. 决策结果 (Decision)

**拟采纳方案 A：Flutter（稳定当前频道）+ flutter_quill + Markdown 编解码 + Riverpod。**

配套：`flutter_secure_storage`、`dio`、用户目录文件 I/O、`SyncProvider` / `AiProvider` 端口；GitHub 与 WebDAV/文件夹为真适配器；原生云为 stub。

切换条件：若 Markdown 往返保真或长文性能不达标 → 评估 `appflowy_editor`，其次 `super_editor`。

---

## 4. 影响与后续行动 (Consequences)

- **正面**：一码五端；同步/AI 可替换；与「用户目录 + `.md`」模型对齐。  
- **技术债**：Markdown↔Delta 测试矩阵；iA 风需压制 Quill 默认工具铬。  
- **后续**：阶段 2 架构（模块图 + Sync/AI 端口）；`DESIGN.md` 落 iA 气质；脚手架与垂直切片测试。
