# P5.1 Progress API DTO 与契约 fixtures

状态：READY

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：P0–P4.4 已 PASS；P4.4 仍使用会话期 `TemporaryProgressRepository`。P5.1 只冻结传输合同，不替换该 adapter。

## 目标

把真实 VPS `/api/progress` 合同表达为 `WordLoopNetworking` 的 Swift 6 `Codable` DTO 和仓库共用 JSON fixtures，并以请求级回归确认 Node 与 Cloudflare 对相同输入给出相同状态码和 JSON 形状。P5.2 以后才能持久化，P5.3 以后才能发送或重试网络事件。

## 合同真值与差异决策

- [`../ios-migration/baseline/api-contracts.md`](../ios-migration/baseline/api-contracts.md) 与当前 VPS Node `server/index.mjs` 是 P5.1 输入真值；路径仍只有 GET/POST `/api/progress`。
- 保留现有字段与 POST 分支优先级：`selectCourse → resetCourse → completeCourse → normal progress`，不新增 version envelope，不重命名服务端字段。
- Cloudflare 对齐 Node 的请求校验和错误：非法 mode 返回 `invalid study mode`；课程/条目必须是非空 string；单词只要求非空 string。Node 的 `study_users` side effect 不属于响应合同，P5.1 不要求 D1 仿造。
- event ID 继续是 8–128 位 `[a-z0-9-]`；Swift DTO 使用字符串承载，UUID 生成和 outbox 唯一性由 P5.3 负责。
- `recentCourseId` 保持可省略；completion 跨 mode，progress 按 mode；count DTO 解码时不擅自 clamp，业务层在 P5.3 合并时处理上限 3。

## Swift DTO 范围

在 `WordLoopNetworking` 定义：

- wire mode：`listen` / `repeat`。
- GET query：用户、mode、可选 course；query items 百分号编码由 Foundation 负责。
- GET 响应：word progress、course item progress、completion summary、可选 recent course。由于服务端两种 GET 形状不同，使用两个显式 response DTO，不用 `[String: Any]` 或含混联合对象。
- POST 请求：word progress、course item progress、select、reset、complete 五种显式 DTO；只有 normal/complete 携带 `clientEventId`，只有 mastered 请求编码 `markMastered: true`，绝不编码 false。
- POST 响应：word/item count、selection、reset、completion 和 error DTO。
- DTO 只依赖 Foundation/Core 标识符可安全转换的 raw value；不引用 Features、Progress、SwiftData、URLSession 或 UI。

## 共用 fixtures 与请求级验证

- 新增一组仓库级 JSON fixtures，至少覆盖两种 GET 成功响应、五种 POST 请求/响应、可选 recent course 缺失、固定 400 errors、重复 event 幂等和分支优先级。
- Swift tests 从同一 fixture 文件解码并重编码，断言字段名、可选字段省略和显式 true 标志完全一致。
- Node 与 Cloudflare 测试必须调用真实 handler 边界并使用隔离的临时数据库/fake D1；不可只用源码正则。相同 fixture 比较状态码与 JSON 深相等，并验证：跨 mode completion、mode-scoped reset、select 幂等、normal/complete event 幂等、count 上限 3。
- 保留现有 Web 53 项与 baseline；新增静态边界防止 P5.1 提前出现 URLSession、SwiftData、outbox 或对 `TemporaryProgressRepository` 的替换。

## 禁止范围

- 不实现 HTTP client、base URL、鉴权 header、重试、网络监听或请求发送。
- 不实现 SwiftData schema、身份恢复、pending event/outbox、冲突合并或 UI 接线。
- 不删除或替换 P4 temporary progress/completion/reset adapter。
- 不改数据库 schema、API 路径、成功响应字段、课程内容、Web UI、Pronunciation API、VPS 部署或 P6/P7。

## 验收

- `swift test --package-path ios/Packages/WordLoopNetworking`：DTO/fixture 精确计数全绿。
- Node 与 Cloudflare 请求级契约测试全绿，且现有 `npm test` 全绿。
- `scripts/verify_ios.sh`、AppIntegration 5/5、App UI 26/26、`npm run baseline:ios`、lint 精确基线和 `git diff --check` 通过。
- 源码审计确认 P5.1 没有 transport、persistence、outbox、UI 或临时 adapter 替换越界。

## 退出条件

Swift、Node、Cloudflare 三方对同一 fixtures 的 JSON 合同一致；已记录的 D1/Node 响应差异被消除或由测试明确排除。完成后进入 P5.2 SwiftData schema，不提前接 P5.3 网络同步。
