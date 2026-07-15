# WordLoop 接手索引

这套 handoff 文档刻意保持精简，避免项目状态散落在多个互相冲突的说明中。

## 阅读顺序

1. 根目录 [`PROJECT_CONTEXT.md`](../../PROJECT_CONTEXT.md)：项目事实、架构、当前状态、风险和工作规则。
2. [`CHANGELOG.md`](CHANGELOG.md)：只追加会影响未来接手的重要变化。
3. 根据任务阅读专项文档：
   - 原生 iOS 迁移：[`../IOS_MIGRATION_SPEC.md`](../IOS_MIGRATION_SPEC.md)
   - iOS 实施 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)
   - 当前 P3.1 任务卡：[`../tasks/2026-07-15-p3-1-design-system.md`](../tasks/2026-07-15-p3-1-design-system.md)
   - 已复核 P2 任务卡：[`../tasks/2026-07-15-p2-native-project-skeleton.md`](../tasks/2026-07-15-p2-native-project-skeleton.md)
   - 已复核 P1 课程合同：[`../tasks/2026-07-15-p1-course-contract-exporter.md`](../tasks/2026-07-15-p1-course-contract-exporter.md)
   - 已复核 P0 基线：[`../tasks/2026-07-15-p0-1-baseline-freeze.md`](../tasks/2026-07-15-p0-1-baseline-freeze.md)
   - 课程制作：[`../COURSE_PRODUCTION_GUIDE.md`](../COURSE_PRODUCTION_GUIDE.md)
   - VOA 课程：[`../VOA_COURSE_PRODUCTION_GUIDE.md`](../VOA_COURSE_PRODUCTION_GUIDE.md)
   - VPS 发布运维：[`../WORDLOOP_VPS_RUNBOOK.md`](../WORDLOOP_VPS_RUNBOOK.md)

## 维护规则

- `PROJECT_CONTEXT.md` 是唯一的项目上下文事实源；项目边界、架构或当前风险变化时直接更新它。
- `CHANGELOG.md` 只追加有长期接手价值的变化，不记录每次小修小改，也不复制 Git log。
- 专项步骤留在专项指南，不在 handoff 文档中重复维护。
- 生产环境信息在每次部署前重新实机验证；文档中的日期表示最后确认时间，不代表永久有效。
