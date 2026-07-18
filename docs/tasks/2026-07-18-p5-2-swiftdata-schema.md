# P5.2 SwiftData v1 Schema

状态：READY

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：P0–P5.1 已 PASS。P5.1 冻结了以 VPS Node 为主的 progress wire contract；P5.2 只建立本地持久化模型和迁移入口，不发送 API 请求、不替换 P4 adapter。

## 目标

在 `WordLoopProgress` 建立 iOS 17/macOS 14 可编译的 SwiftData v1 schema，完整表达身份、按 mode 的条目进度、待同步学习事件、跨 mode 完成次数/事件和最近课程偏好。模型必须能用内存与磁盘 `ModelContainer` 独立验证，并为后续版本提供显式 migration plan 入口。

## v1 模型

- `StudyIdentity`：唯一 `identityID`、VPS `userID`、可选规范化 username、created/updated 时间。v1 只定义存储，不负责生成、恢复或切换身份。
- `ProgressRecord`：唯一复合 `recordID`，并显式存 user、mode、course、entry、`studyCount`、updated 时间；LISTEN/REPEAT 严格分区。count 的业务 clamp 由 P5.3 repository 保证，schema 不使用隐式 setter 修正数据。
- `ProgressEvent`：唯一 VPS `clientEventId`，存 user、mode、course/entry、事件 kind（increment/master）、outbox state、created/attempt/ack 时间与 attempt count。v1 枚举以稳定 raw string 存储，未知值由 repository fail closed。
- `CourseCompletionRecord`：唯一 user + course，存跨 mode 共用 completion count 与 updated 时间。
- `CourseCompletionEvent`：唯一 `clientEventId`，存 user/course、outbox state 与时间/attempt 字段；不存 mode，保持 VPS 合同。
- `CoursePreference`：唯一 user，存 recent course 与 updated 时间；不按 mode 分区。

所有模型使用持久化友好的 scalar/raw string/Date，不持久化 Core struct、DTO、URL、闭包或 actor；不建立会造成级联误删的隐式 relationship。复合唯一键由稳定、无歧义的 length-prefixed key builder 生成，避免简单分隔符碰撞。

## Schema 与迁移

- 定义 `WordLoopProgressSchemaV1: VersionedSchema`，版本 `1.0.0`，明确列出六个模型。
- 定义 `WordLoopProgressMigrationPlan: SchemaMigrationPlan`；v1 初始 stages 为空，但真实 container 必须通过该 plan 构造，后续版本只能追加 schema/stage。
- 提供 `WordLoopProgressContainer` factory，支持默认磁盘 store 与测试用 in-memory/store URL；不在此阶段创建 repository singleton 或 App wiring。

## 测试矩阵

- schema version、模型集合和 migration plan 入口固定。
- 每种模型插入/保存/获取，字段与稳定 key 精确一致。
- 相同业务标识不会形成两条逻辑记录；不同 mode、course、entry 或 user 不碰撞。
- completion record/event 不按 mode；preference 只按 user。
- in-memory 隔离；磁盘 container 关闭后重开仍能恢复所有模型。
- event raw kind/state、attempt 和 timestamps 可 round-trip；无 transport side effect。
- 静态边界确认 P4 temporary adapter 仍存在，P5.2 没有 URLSession、网络监听、flush/outbox processor 或 Feature/UI 接线。

## 禁止范围

- 不实现 ProgressRepository 读写事务、派生合并、event enqueue/flush/retry 或网络恢复触发。
- 不实现 VPS HTTP client/base URL、鉴权、URLSession、staging smoke 或部署。
- 不修改 Startup/StudyStore/视图，不删除 `TemporaryProgressRepository`。
- 不实现 P5.3+、P6/P7、CourseInstallation/CatalogSnapshot（后者属于 P7）。

## 验收

- `swift test --package-path ios/Packages/WordLoopProgress` 的 SwiftData schema/磁盘恢复测试全绿。
- `scripts/verify_ios.sh`、Web、baseline、AppIntegration/UI、lint 精确基线和 diff check 全部通过。
- 审计 schema 与 VPS P5.1 合同：progress 按 mode，completion/preference 跨 mode，event identity 为字符串且可幂等重试。

## 退出条件

六个 v1 模型、显式版本、迁移 plan 和 container factory 已被真实内存/磁盘 SwiftData 测试证明；没有提前实现 transport/outbox processor/UI。完成后进入 P5.3 Progress Outbox。
