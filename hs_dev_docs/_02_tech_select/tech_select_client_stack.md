# 技术选型与评估方案：AI Writer 客户端栈

- **评估领域**：跨平台客户端 / 编辑器 / 本地存储 / 同步与 AI 集成
- **评估日期**：2026-10-10
- **负责人**：hardstone
- **约束（来自已冻结 PRD）**：五端（含 **Linux**）· WYSIWYG · 用户目录为库根 · GitHub + WebDAV/文件夹同步 · SyncProvider 可插拔 · 免注册默认 · iA Writer 气质

---

## 1. 业务特征与技术诉求

| 维度 | 取值 |
|---|---|
| **产品规模** | 小（单人～小团队） |
| **变更档** | L |
| **产品类型** | 标准写作工具客户端（本地优先，非复杂多域 B2B） |
| **复杂度信号** | 五端 UI 一致；编辑器质量；多 Sync/AI 适配器；无实时协作 |
| **选定范式（预告）** | 客户端模块化单体 + 端口适配器（Sync/AI）；**不上 DDD/微服务**。前端 **F2 按业务 Feature**；集成边界偏 **B3 端口**，领域规则保持薄（B1～B2） |

核心指标：五端可达、编辑体验、`.md` 文件互通、适配器可测、交付速度。

---

## 2. 备选技术方案对比

### 2.1 跨平台框架（硬约束：必须含 Linux 桌面）

| 评估维度 | A: Flutter | B: .NET MAUI | C: Kotlin CMP |
|---|---|---|---|
| Win/macOS/iOS/Android | 成熟 | 成熟（无 Linux） | 成熟度上升 |
| **Linux 桌面** | **一等支持** | **无官方目标** | 有（JVM/CMP），成本高于 Flutter |
| UI 一致性（iA 气质） | 自绘引擎，易统一 | 原生控件，五端观感分叉 | CMP 可共享 UI，生态仍薄于 Flutter |
| 长文编辑器生态 | Quill / Super Editor / AppFlowy Editor | 弱于 Flutter | 更弱 |
| 综合（对本 PRD） | **首选** | 淘汰（缺 Linux） | 备选（团队强 Kotlin 时） |

对标依据：公开对比一致指出 MAUI 无一流 Linux；Flutter 覆盖本 PRD 五端最省。

### 2.2 WYSIWYG 编辑器（Flutter 生态内）

| 评估维度 | A: flutter_quill (~2.9k★) | B: super_editor (~1.9k★) | C: appflowy_editor (~0.7k★) |
|---|---|---|---|
| 成熟度 / 星数 | 最高 | 高，文档型 toolkit | 中，产品级编辑器 |
| Markdown 文件权威 | 需 Delta↔Markdown 编解码 | 有 markdown 配套包，API 仍在演进 | 笔记产品同款，导入导出成熟 |
| 五端 | 宣称全平台 | 全平台导向 | Flutter 全平台 |
| 风险 | 工具条偏「Office」需克制做 iA 风 | 发布节奏/API 变动 | 星数较少但场景贴合 |
| 综合 | **MVP 默认** | 中期可评估切换 | 强备选 |

**MVP 推荐**：`flutter_quill` + Markdown 编解码；UI 层弱化默认工具条，做成 iA 风轻铬。若 Quill↔Markdown 保真不达标，切换窗口优先评估 `appflowy_editor`。

### 2.3 配套库（工程自决，记入选型）

| 用途 | 选型 |
|---|---|
| 状态 | `riverpod` |
| 本地设置 / Key | `flutter_secure_storage` + 普通 prefs |
| HTTP（OpenAI 兼容） | `dio` |
| 路径 / 文件 | `path` / `path_provider` + 用户选定目录（file_picker / 平台目录 API） |
| WebDAV | 成熟 Dart WebDAV client（实现期锁定具体包） |
| GitHub 同步 | GitHub Contents/Git API 或嵌入式 git 策略（架构阶段定端口，实现期选一种） |
| 测试 | `flutter_test` + `integration_test`；Sync/AI 用假实现打 seam |

---

## 3. 选型结论与决策理由

**推荐采纳：Flutter + flutter_quill（Markdown 编解码）+ Riverpod + SyncProvider/AiProvider 端口。**

理由：
1. **唯一低摩擦覆盖 PRD 五端（含 Linux）** 的成熟单码基方案。  
2. 编辑器生态可选，且可把 **磁盘 `.md` 当权威** 对齐用户目录与 GitHub/文件夹同步。  
3. AI / 同步自然落成 **端口 + 适配器**，原生云 stub 不污染编辑器核心。  
4. 小团队不引入 DDD/微服务；Feature 模块足够。

---

## 4. 关联 ADR

- `hs_dev_docs/_00_project/_05_decision_record/ADR_001_client_stack.md`
- `hs_dev_docs/_00_project/_05_decision_record/ADR_002_dev_paradigm.md`
