# P5.3 Persistent Progress Repository 与 VPS Outbox

状态：READY

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：P0–P5.2 已 PASS。P5.1 固定 VPS `/api/progress` DTO/合同，P5.2 提供 SwiftData v1 schema。P5.3 实现条目进度 repository/outbox，但不接 Startup/StudyStore，也不迁移 completion/reset/preference。

## 目标

建立持久化 `ProgressRepository`：离线学习先把幂等事件保存到 SwiftData，再向调用方返回“服务端确认值 + pending events”的投影；联网 flush 始终复用原 `clientEventId` 发往 VPS，成功后合并服务端 count 并归档/删除事件，失败保留可重试事件。LISTEN/REPEAT 永久分区。

## VPS Transport

- `WordLoopNetworking` 增加 consumer-owned `ProgressAPIClient`，初始化时接收 App 的 `WORDLOOP_API_BASE_URL`；当前 Debug/Release 真值均为 `https://boringmax.com/wordloop/api`，client 只追加 `progress`。
- 使用 ephemeral/default-injected `URLSession`，请求/响应只用 P5.1 DTO；非 2xx 解码 error DTO 后抛出结构化错误，坏 JSON、无 HTTP response 和 transport error 分开。
- 不在 Package 内硬编码 Cloudflare、生产域名或 secret；URLProtocol/closure transport 注入用于断网、超时、重复响应和状态码测试。
- 本阶段只发送/读取 course-item progress；select/reset/complete 留给 P5.4/P5.5。

## Repository 真值

- `ProgressRecord.studyCount` 表示最后服务端确认值；本地学习不提前改 confirmed count。
- UI 投影 = confirmed count 应用同 user/mode/course/entry 的 pending/sending events，increment 逐次 +1、master 直接 3，始终 clamp `0...3`。
- `record`/`master` 在单个 ModelContext save 中先插入新的 `ProgressEvent`；save 成功后才返回投影。save 失败不得发布成功值。
- client event ID 由注入 generator 生成并持久化一次；任何 flush 重试复用该 ID，绝不因 timeout/cancel 新建事件。
- 服务端返回 count 后，在同一 save 中 upsert confirmed record 并删除已确认 event；删除前失败则保留 event，之后可用同 ID 安全重试。
- 恢复时把遗留 `sending` 视为 pending；未知 kind/state fail closed 并报告 repository error，不静默丢事件。

## Flush 与并发

- `flush(trigger:)` 支持 `.networkRecovered`、`.appBecameActive`、`.manualRetry`；P5.3 提供入口和可注入 scheduler，不在本阶段改 App lifecycle/UI。
- 同一 user + mode 的 flush 只允许一个在途；重复 trigger 合并，不能并发发送冲突事件。不同 partition 可不保证并行。
- 每个 partition 按 createdAt + clientEventId 稳定顺序发送；某事件失败后停止该 partition，保持后续顺序。
- 每次尝试先把 state=`sending`、attemptCount+1、lastAttemptAt 写盘；成功确认删除，失败/cancel 恢复 `pending` 并保留 attempt 数据。
- `refresh` GET 指定 course，把服务端 rows upsert 为 confirmed records；随后投影仍合并本地 pending。远端缺失条目按 confirmed 0 处理，但不得删除其他 mode/course。

## 测试矩阵

- 离线 record/master：事件先落盘、confirmed 不变、投影为 1/3；强制重开 container 后投影不丢。
- count 合并：confirmed 2 + pending increment = 3；多个 increment clamp 3；pending master = 3；mode/course/user 隔离。
- flush 成功：精确 VPS URL/method/body、原 UUID、attempt 元数据、response upsert、event 删除。
- timeout/500/坏 JSON/cancel：event 留存 pending；重试 body 的 UUID 不变；后续 event 不越过失败事件。
- 遗留 sending 恢复；未知 raw value fail closed。
- 同 partition 并发 trigger 只发一次；不同触发来源均能启动同一 flush 入口。
- refresh 合并服务端 + pending，且只影响请求 partition/course。
- 磁盘关闭重开与无网络均可学习；不接 Startup/StudyStore/Completion。

## 禁止范围

- 不替换 `TemporaryProgressRepository`，不修改 Feature/App/UI；P5.4/P5.5 才接线。
- 不实现 identity 创建/恢复、recent course、select/reset/complete、completion outbox。
- 不实现 Network framework monitor、scenePhase wiring 或后台任务；这里只提供三个触发入口，宿主接线后续完成。
- 不使用 Cloudflare base URL，不改 VPS/Cloudflare API、DB schema、Web UI 或部署。

## 验收

- Networking transport tests 与 Progress repository/outbox 的内存、磁盘、并发、失败矩阵全绿。
- `scripts/verify_ios.sh`、相关 Node 静态边界、baseline、lint 精确基线与 diff check 通过；只有 App/Feature 接线发生时才跑 UI。
- 源码审计证明线上 target 来自注入的 VPS `WORDLOOP_API_BASE_URL`，event ID 重试不变，confirmed/pending 没有双计数。

## 退出条件

飞行模式下条目学习能持久化并在进程重启后恢复投影；联网/手动/App-active 触发的 flush 使用相同 UUID 幂等同步 VPS，失败可重试且同 partition 不乱序。完成后进入 P5.4 Startup 与课程恢复。
