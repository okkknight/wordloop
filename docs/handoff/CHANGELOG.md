# WordLoop Handoff Changelog

此文件只追加影响后续接手的耐久事实。最新记录放在最上方，不改写旧记录。

## 2026-07-15 · iOS implementation plan

- 新增 [`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)，把迁移规格展开为 P0–P9 顺序路线图和 CP-00–CP-25 提交检查点。
- 实施顺序锁定为：行为基线 → 课程协议/exporter → 原生骨架 → 逐页视觉 Shell → 内置 LISTEN → 进度同步 → REPEAT → 远程下载 → TestFlight → App Store Gate。
- 明确 Plan 不是任务卡；后续一次只根据实际结果生成一张任务卡，第一张边界为 P0.1 基线冻结。
- 明确 Web `app/page.tsx` 不作为本轮独立重构目标；其责任在 iOS 原生模块中拆分，Web 只做共享课程产物所需最小适配。

## 2026-07-15 · iOS migration spec

- 锁定原生 SwiftUI、Swift 6、iOS 17+ 和本地 Swift Package 的完整模块化方向，iOS 工程放在当前仓库 `ios/` 下。
- 锁定混合课程架构：当前 30 门课程随首发效果包内置，后续课程可由远端 catalog 发布、按需下载并离线学习。
- 新增 [`../IOS_MIGRATION_SPEC.md`](../IOS_MIGRATION_SPEC.md)，定义课程 schema、校验与原子安装、下载状态与交互、`app/page.tsx` 拆分、阶段退出标准和 App Store Release Gate。
- 下载交互复用现有课程左侧抽屉和视觉 tokens，不新增课程商店或改变主学习页风格。
- 本次仍只修改文档，尚未创建 iOS 工程或改变 Web/服务端行为。

## 2026-07-15

- 用真实产品说明替换根目录 vinext starter README。
- 建立 `PROJECT_CONTEXT.md` 作为项目边界、架构、运行事实、风险和工作规则的唯一上下文入口。
- 明确当前生产环境是 VPS Node API + SQLite，同时仓库仍保留 Sites/Cloudflare D1 实现。
- 记录当前质量基线：build 和 28 项测试通过，lint 因 4 个 React Compiler memoization 错误未通过。
- 本次仅修改文档，对现有产品功能和生产运行没有直接影响。
