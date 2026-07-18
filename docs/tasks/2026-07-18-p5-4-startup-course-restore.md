# P5.4 Startup 与课程恢复

状态：PASS

## 范围

- SwiftData 持久化并恢复当前身份；命名用户使用 `name:<lowercase>`，匿名用户使用稳定 UUID。
- 本地保存最近课程，启动时优先恢复；服务端最近课程可覆盖本地已知值。
- 启动状态覆盖 `restoring/syncing/ready/error`，断网时使用本地身份、内置课程和 outbox 继续进入 App。
- 将 StudyStore 的条目进度切到 P5.3 persistent outbox；完成次数和 reset 暂由 P4 adapter 承担，P5.5 删除。
- production API base URL 继续来自 App 配置，当前目标为 VPS `https://boringmax.com/wordloop/api`。

## 验收

- 命名与匿名身份跨容器重开保持稳定。
- 本地/远端最近课程恢复均有确定性测试，未知课程回退 bundle 默认课程。
- 网络失败不阻塞进入学习页，待同步条目进度不丢失。
- fixture 启动页保持可独立构造。

## 最终结果（2026-07-18）

- `StudySessionRepository` 使用 SwiftData 持久化 active identity 与 `CoursePreference`；匿名 UUID 可跨磁盘重开复用，命名身份规范为 `name:<lowercase>`。
- `ProgressAPIClient` 已补齐 overview GET 与 select-course POST，仍从 App 注入 VPS base URL；远端 recent course 成功时覆盖本地，失败时回退本地课程。
- App live runtime 已接入 P5.3 persistent outbox；StudyStore 支持校验并恢复 preferred course，手动切课同时本地保存并尝试发布 VPS preference。
- Startup 具备 restoring/syncing/ready/error 状态；已知身份启动自动恢复，断网不阻塞 bundle 课程。`-wordloop-ui-fresh-start` 仅用于 UI 测试隔离，不改变产品持久化。
- P5.4 仍保留窄化的 completion/reset temporary fallback，明确由 P5.5 删除。
- 验证：Networking 9/9、Progress 22/22、Features 104/104、Web/Node 62/62、统一 `scripts/verify_ios.sh`、content baseline、diff check 通过；启动提交相关 UI 2/2 与跨启动恢复 UI 1/1 通过。首次 UI 重跑曾遇到 Simulator `Busy`，重启 simulator 后通过，非产品失败。
