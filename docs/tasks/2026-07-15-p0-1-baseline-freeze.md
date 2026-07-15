# P0.1 当前行为与内容基线冻结

状态：执行中

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

## 目标

把当前 Web 产品中必须由原生 iOS 保持的页面、视觉、学习状态、内容数量与 API 契约固化成可重复验证的基线。此任务只采集证据和增加基线工具，不改变业务行为。

## 范围

- 建立 `docs/ios-migration/baseline/`。
- 自动统计课程、集合、条目、M4A、色板和核心状态文案。
- 记录当前 build、test、lint 基线，保留已知失败而不借机修复。
- 为 Startup、Study、Course Drawer、Progress Drawer、Dialog 建立页面验收矩阵。
- 为 LISTEN、REPEAT、离线进度、课程完成建立状态验收矩阵。
- 保存桌面与 iPhone 尺寸的当前 Web 截图；敏感数据不得进入截图或 fixture。
- 保存匿名的 progress 与 pronunciation-session API 请求/响应示例或精确合同。

## 禁止范围

- 不创建 iOS 工程。
- 不修改 `app/page.tsx`、样式、课程、API 或数据库行为。
- 不修改评分阈值、用户身份规则或课程筛选。
- 不修复现有 lint 错误。
- 不部署 VPS。

## 预期产物

```text
docs/ios-migration/baseline/
├── README.md
├── content-inventory.json
├── product-acceptance-matrix.md
├── api-contracts.md
├── quality-baseline.md
└── screenshots/
scripts/capture_ios_migration_baseline.mjs
```

## 验收标准

1. 机器统计证明当前有 30 门课程、570 个单词、836 个句子和 1,406 个 M4A。
2. 六套色板、Startup/Repeat 状态文案和主要延时常量有代码出处。
3. 每个页面和关键状态都有明确 iOS 对齐要求与证据位置。
4. LISTEN/REPEAT 的前进、暂停、错误、切课和迟到事件边界被记录。
5. API 合同覆盖 progress GET/POST、select/reset/complete 和 pronunciation session。
6. `npm test` 结果被重新执行并记录；`npm run lint` 结果被重新执行并记录。
7. `git diff --check` 通过，现有业务文件无修改。

## 验证命令

```bash
node scripts/capture_ios_migration_baseline.mjs --check
npm test
npm run lint
git diff --check
```

## 交接要求

完成后把任务状态更新为“开发完成，待独立复核”，刷新 `PROJECT_CONTEXT.md` 与 handoff changelog，并提交为 `CP-00 baseline evidence captured`。P1 任务卡只能基于实际基线产物生成。
