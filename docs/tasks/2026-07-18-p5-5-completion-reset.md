# P5.5 完成、次数与重练

状态：PASS

## 范围

- completion 先写 `CourseCompletionEvent`，以稳定 `clientEventId` 向 VPS 重试，确认后更新 `CourseCompletionRecord`。
- resetCourse 作为 progress outbox 的有序事件持久化；本地投影立即归零，联网后同步 VPS。
- 启动/进入课程时恢复服务端完成次数，同时合并本地 pending completion。
- 删除 live runtime 的 P4 `TemporaryProgressRepository` fallback，使条目、完成与重练全部使用 SwiftData。

## 验收

- completion timeout/500 后重试复用同一 ID，不重复计次。
- reset 仅清除指定 user/mode/course，LISTEN/REPEAT 保持隔离，reset 后的新学习事件顺序正确。
- 强杀重开后 pending completion/reset 仍可投影并同步。
- StudyStore 完成弹窗、次数和重练行为保持 P4.4 交互。

## 最终结果（2026-07-18）

- `PersistentProgressRepository` 现在统一管理 item、reset 和 completion：reset 使用同一 progress outbox 的有序事件，本地投影立即清空；completion 使用 `CourseCompletionEvent`，pending 次数与 confirmed record 合并。
- completion transport 失败后恢复 pending，磁盘重开仍保留原 `clientEventId`；VPS 幂等确认后更新 completion record 并删除事件。
- reset 只清理指定 user/mode/course，随后产生的新学习事件排在 reset 后；LISTEN/REPEAT 仍隔离。reset VPS 请求本身为幂等操作。
- live runtime 的 `StudyProgressClient` 已全部接入 persistent repository，不再使用 completion/reset fallback。原 temporary repository 只保留给明确命名的 local integration fixture，不属于 App live runtime。
- 验证：Networking 10/10、Progress 24/24、Features 104/104、Web/Node 63/63、统一 iOS verify、AppIntegration 与真实 LISTEN UI route、baseline、diff check 全部通过。
