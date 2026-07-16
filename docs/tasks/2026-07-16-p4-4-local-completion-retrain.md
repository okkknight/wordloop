# P4.4 完成与重练纯本地流程

状态：已实现，完整 UI 回归待重跑

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：P0–P4.3 已 PASS；P4.3 提供真实离线 LISTEN、会话期进度、正式课程投影和已验收 CompletionDialog 展示层。

## 目标

完成 P4 最后一段纯本地闭环：LISTEN 中所有条目达到 3 次时只结算一次课程完成、显示自然完成对话框；选择已完成课程时先显示重练确认；用户可选择其他课程或清空当前模式进度并立即开始新一轮。所有数据仍限当前 App 会话，P5 将整体替换临时 adapter。

## 已锁定产品语义

- 完成次数按课程共用，不按 LISTEN/REPEAT 分区；当前模式进度仍严格分区。
- 自然完成从“未完成”首次转为“全部 3/3”时完成次数加一并显示 `.courseCompleted`；迟到 NEXT、重复点击和旧 async completion 不得重复计数。
- 自然完成对话框：“选择课程”只打开既有 CourseDrawer；“再练一次”清空当前课程当前模式进度并开始新一轮。
- 选择当前模式已经全部掌握的课程时不切换主页面、不播放、不计次，先显示 `.restartCompletedCourse`；“取消”保持原课程，“重新开始”执行 reset 后才切课并开始新一轮。
- reset 只清 `(courseID, current StudyMode)` 的条目进度；不会减少历史完成次数。
- reset 失败保留对话框并显示既有固定错误“暂时无法重置进度，请稍后重试。”，允许重试或取消。
- 默认 REPEAT 仍是静态展示；P4.4 不增加录音、评分或 REPEAT 进度。

## 实现边界

- 扩展 `TemporaryProgressRepository`：当前模式 reset、按课程 completion count、幂等 completion 结算；仍禁止持久化和网络。
- 扩展 consumer-owned `StudyProgressClient`，不要把 temporary 类型暴露给 View。
- `StudyStore` 负责 completion/reset 的 generation、course/mode 绑定和唯一业务状态；`CompletionDialogStore` 保持展示 Store，不直接调用 Progress。
- 为 `StudyViewActions` 增加 live completion callbacks，fixture initializer 和 P3 UI 行为保持不变。
- CourseDrawer 投影带真实 completion badge；ProgressDrawer reset 后立即归零。
- reset 或 completion 的任何 await 恢复前必须校验 generation、course 和 mode；切课、切模式、后台或新 reset 使旧结果静默。

## 测试矩阵

- TemporaryProgress：mode-scoped reset、completion count 跨 mode 可见、同一 completion identity 幂等、reset 不减少完成次数。
- StudyStore：最后一项 2→3 只完成一次；重复 NEXT/太简单/旧回调不重复完成；自然完成两按钮；已完成课程选择的取消/确认；reset 成功后从首个 eligible 开始并计 1；reset failure 固定错误且可重试。
- 并发：suspended complete/reset 后切课、切模式、后台或第二次 intent，旧结果不得覆盖新会话。
- 投影：课程卡 `× N` 与当前 completion counts 一致，reset 后 ProgressDrawer 当前模式归零。
- App integration/UI：真实内置单条可控 fixture 或注入 client 验证自然完成、选择课程、再练一次和已完成课程确认；既有 26 项 UI 与 P3 fixture 全保留。
- 静态边界：无 UserDefaults/SwiftData/文件/URLSession/outbox；无 P5/P6/P7、iPad、macOS、Catalyst 或后台音频越界。

## 验收

运行 P4.3 的完整 Package、App integration/UI、Web、baseline、lint 和 diff 门禁，并记录新精确计数。额外确认：飞行模式完成/重练可用；completion count 不因 reset 消失；App 重启后临时数据消失是 P4 已知边界；P5 任务必须删除 temporary completion/reset adapter。

## 禁止范围

- 不实现身份、最近课程、SwiftData、outbox、API DTO 或服务端同步。
- 不修改 Node/Cloudflare API、Web UI、数据库和 VPS。
- 不实现 REPEAT、麦克风、Realtime、远程课程下载或 App Store 元数据。

## 当前实现结果（2026-07-16）

- `TemporaryProgressRepository` 已增加当前 mode reset、课程级 completion count 和 completion identity 幂等；reset 不清历史完成次数，仍无持久化或网络。
- `StudyStore` 已接自然完成唯一结算、真实 completion badge、已完成课程选择确认、成功重练与固定失败错误；所有 reset UI 回写绑定 generation/course/mode。
- live CompletionDialog confirm 接异步 reset，P3 fixture 保持原展示 Store 行为。首次完整 UI 回归由此发现 fixture confirm 不关闭，改为仅 live 注入可选 callback 后，失败用例单独复验通过。
- 当前通过 Progress 9/9、Features 100/100（StudyStore 25/25）、Web 53/53、baseline、统一 iOS verify、AppIntegration 5/5；lint 精确保持既有 4 errors/0 warnings。
- 完整 26 项 UI 套件在首个 fixture 失败后被中止；修复后仅重跑该失败用例 1/1。P4.4 PASS 前必须重新完整跑 26 项 UI，并补 reset/complete suspension 边界审计。
