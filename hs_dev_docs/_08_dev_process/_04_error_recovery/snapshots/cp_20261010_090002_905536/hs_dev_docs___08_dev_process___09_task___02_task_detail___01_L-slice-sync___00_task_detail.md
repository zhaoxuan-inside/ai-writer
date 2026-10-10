# 任务详细设计与执行记录：L-slice-sync

- **任务名称**：SyncProvider GitHub Folder NativeStub
- **变更分级**：`L`
- **当前状态**：`IN_PROGRESS`
- **优先级**：P0
- **负责人**：agent
- **开始时间**：`2026-10-10T08:26:50Z`
- **最后更新**：`2026-10-10T08:27:03Z`

---

## 1. 任务背景与目标
SyncProvider seam with Folder, GitHub Contents API, Native stub; manual push/pull overwrite confirm; no conflict UI

---

## 2. 验收标准
Unit tests for folder push/pull overwrite; GitHub adapter with mocked Dio; stub returns not-enabled; settings can select provider

---

## 3. 执行步骤 (Checklist)
- [ ] 1. 完善设计文档与接口定义
- [ ] 2. 同步 DB 迁移脚本（V/U）
- [ ] 3. 编写/修改核心六元组业务逻辑
- [ ] 4. 编写全覆盖单测与契约测试
- [ ] 5. 本地质量门禁与提交前自检

---

## 4. 涉及文件修改清单 (Diff Tracking)
```text
(待更新)
```

---

## 5. 验证与门禁记录
- 单测覆盖率：`0%`
- 契约比对：`PENDING`
