# 上下文装载包 (Context Pack)：L-ai-writer-mvp

- **change_size**：`L`
- **任务 ID**：`L-ai-writer-mvp`
- **生成时间**：`2026-10-10T09:13:40Z`
- **状态**：`DONE`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **work_mode**：`IMPLEMENT`

---

## 1. 需求与目标（物化）

Local-first writing client: desktop draft + AI rewrite + local save。

PRD DoD（§5）关键冻结项：
- WYSIWYG 新建/编辑/本地保存/再打开
- AI 续写或改写至少一种，预览后可接受写回
- AI 不可用时本地写作仍可用
- 可配置并保存 API Key
- GitHub 或 Folder 至少一种手动 push/pull 覆盖
- Native stub 可切换；未登录可用

子切片状态：document-store / library-save / wysiwyg / ai / sync → 全部 `COMPLETED`。

本步缺口：父任务缺一条跨 seam 的 desktop E2E（draft→AI accept→persist→reopen）。

---

## 2. Seam 表（父任务收口）

| Seam | 观察什么 | 抓住什么 |
|------|----------|----------|
| LibrarySession + FS store | 磁盘 markdown | 持久化往返 |
| FakeAiProvider.complete | suggestionMarkdown | rewrite 可接受写回 |
| QuillMarkdownBridge | round-trip 文本 | 保真不丢正文 |
| FolderSyncProvider | push/pull 内容 | 覆盖语义 |

---

## 3. 验收驱动测试

`test/e2e/mvp_draft_ai_persist_test.dart`
- draft → AI rewrite accept → save → reopen
- AI NotConfigured 不阻断本地 save
- folder sync push/pull overwrite

---

## 4. 查询轨迹

- resume-scan → `L-ai-writer-mvp` READY@S2 → IN_PROGRESS
- PRD：`prd_ai_writer_mvp.md` §5 DoD
- 子切片 archive：L-slice-* COMPLETED
