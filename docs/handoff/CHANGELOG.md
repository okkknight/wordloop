# WordLoop Handoff Changelog

此文件只追加影响后续接手的耐久事实。最新记录放在最上方，不改写旧记录。

## 2026-07-18 · P6.2 Realtime transport PARTIAL

- `WordLoopRealtime` 已有 VPS SDP client、转写 lifecycle/item ID decoder 和仅在 REPEAT 用户意图后可调用的麦克风授权边界；Info.plist 已有用途说明，App 中不含 OpenAI key。
- ADR 0001 固定 Google 官方 WebRTC 源码 revision `848836f85d4036def631df0ed6eeb001b5c0c174`，要求以官方脚本构建、记录 SHA-256/Xcode，并禁止未锁定 binary。
- 官方构建被本机 depot_tools CIPD bootstrap 的临时目录错误阻断；未将二进制写入仓库，P6.2 不得标 PASS。接手先取得可校验的不可变 XCFramework artifact，再接 binary target、peer connection adapter 和 P6.3 state machine。

## 2026-07-18 · P5.3 persistent progress outbox PASS

- 新增注入 base URL 的 VPS ProgressAPIClient，以及 event-first SwiftData PersistentProgressRepository；confirmed + pending 投影、UUID 重试、稳定顺序、attempt、同 partition 合并、refresh/recovery 已覆盖。
- Networking 8/8、Progress 20/20（outbox 6/6）、相关 Node 11/11、统一 iOS verify、baseline、diff check 通过；无 App/UI 改动，未跑无关 UI。
- live Feature 仍用 P4 temporary adapter；P5.3 PASS，进入 P5.4 identity/startup/recent-course 与接线。

## 2026-07-18 · P5.3 VPS progress outbox task ready

- 锁定 Persistent ProgressRepository：confirmed record + pending event 投影、先落盘再发布、相同 UUID 重试、同 user/mode 串行与稳定顺序。
- Networking transport 只接收 App 注入的 VPS `WORDLOOP_API_BASE_URL` 并追加 `progress`；Cloudflare 不是线上 target。
- P5.3 不接 App/Feature，不实现 identity/preference/reset/completion 或 lifecycle/network monitor；只提供 network/app-active/manual 三种 flush 入口。

## 2026-07-18 · P5.2 SwiftData schema PASS

- WordLoopProgress 新增六个 SwiftData v1 模型、length-prefixed 唯一键、VersionedSchema/MigrationPlan 和内存/磁盘 container factory。
- Progress 14/14（schema 5/5）、相关 Node 5/5、统一 iOS verify、baseline、diff check 通过；lint 保持既有 4 errors/0 warnings。无 App/UI 改动，按用户要求未重跑无关 UI。
- P4 temporary adapter 保留；没有 transport/outbox processor/UI 越界。P5.2 PASS，进入 P5.3。

## 2026-07-18 · P5.2 SwiftData schema task ready

- 新增 P5.2 任务卡：六个本地模型、SwiftData v1 VersionedSchema、MigrationPlan 和内存/磁盘 container factory。
- progress record/event 按 user/mode/course/entry 分区；completion record/event 和 preference 跨 mode；复合唯一键使用 length-prefixed builder。
- P5.2 禁止 repository/outbox processor、URLSession、VPS 请求、Startup/StudyStore/UI 接线和删除 P4 temporary adapter。

## 2026-07-18 · P5.1 progress contracts PASS

- Swift DTO 与共享 fixtures 已完成；真实请求级测试启动隔离 VPS Node 和构建后 Worker/D1，覆盖五种 POST、两种 GET、固定错误、分支优先级、幂等、上限 3、跨 mode completion 与 mode-scoped reset。
- 测试发现并修复 D1 progress event 漏写 `created_at` 导致事件静默丢弃；Cloudflare 校验对齐 VPS Node。线上/后续 transport 仍以 VPS 为目标，未改部署。
- Networking 4/4、请求合同 1/1、Web 57/57、统一 iOS verify、AppIntegration 5/5、App UI 26/26、baseline、diff check 全绿；lint 保持既有 4 errors/0 warnings。P5.1 PASS，进入 P5.2。

## 2026-07-18 · P5.1 progress contract task ready

- 新增 P5.1 任务卡：以真实 VPS Node 与 P0 API baseline 为合同真值，Swift 增加显式 Codable DTO，共用 JSON fixtures 同时驱动 Swift round-trip 与 Node/Cloudflare 请求级测试。
- 锁定 Cloudflare 对齐 Node 的 mode error、非空 course/item/word 校验；不改变路径、成功字段、数据库 schema 或 POST 分支优先级。
- P5.1 禁止 transport、SwiftData、outbox、UI 接线和替换 P4 temporary adapter；完成后才进入 P5.2。

## 2026-07-18 · P4.4 completion and retrain PASS

- reset 不再占用 course-loading phase；新增可控 suspension 测试，确认旧 reset 在新切课/切模式后、旧 completion 在新切课后都不能回写新会话。
- Progress 9/9、Features 103/103（StudyStore 28/28）、AppIntegration 5/5、App UI 26/26、Web 53/53、baseline、统一 iOS verify 与 diff check 全部通过；lint 精确保持既有 4 errors/0 warnings。
- P4.4 结论为 PASS。当前进入 P5.1 API DTO 与契约 fixtures；P5.1 不提前实现 SwiftData、outbox、身份恢复或正式同步。

## 2026-07-16 · P4.4 local completion and retrain implemented

- 临时进度 actor 新增 mode-scoped reset、课程 completion count 和 completion identity 幂等；StudyStore 接通自然完成、课程徽标、已完成课程确认、重练和固定错误。
- live dialog 使用可选 restart callback，fixture 仍走 P3 presentation Store；完整 UI 首轮发现并修复 fixture confirm 退化，目标用例复验 1/1 通过。
- Progress 9/9、Features 100/100、Web 53/53、baseline、统一 iOS verify 和 AppIntegration 5/5 通过；完整 UI 26 项与 completion/reset suspension 仍待复验，P4.4 尚未 PASS。

## 2026-07-16 · P4.3 passed, P4.4 task ready

- 用户取消后续 coder/reviewer 双流要求；P4.3 以本轮直接源码审查、确定性并发回归和完整门禁作为 PASS 证据。
- 新增 P4.4 任务卡，只实现会话期完成计数、自然完成对话框、已完成课程重练确认和当前模式 reset；P5 再替换临时 adapter，不提前持久化或同步。

## 2026-07-16 · P4.3 second-review blockers fixed, third review pending

- 修复旧 mode intent 在 suspended stop 后覆盖新 mode、旧 background pause 覆盖新 playback session、loading 被 lifecycle/mode 留成悬空态，以及 Audio engine start failure 丢 request token 四项第二轮 P1 阻断。
- loading 期间 mode intent 明确拒绝；后台取消 loading 落到可重试失败态。所有 stop/pause 恢复写入绑定 generation，Audio 已分配 token 后的 start failure 保留 token。
- 新增 4 条可控 suspension/loading StudyStore tests 和 1 个 Audio token 断言；Audio 21/21、Progress 7/7、Features 97/97（StudyStore 22/22）、AppIntegration 5/5、App UI 26/26、Web 53/53、baseline 与统一 iPhone verify 通过，lint 精确保持既有 4 errors/0 warnings。
- 本轮环境策略拒绝外层 `rm -rf` 冷清理，第三轮 reviewer 需从完整冷状态复核；P4.3 仍为开发完成待独立复核，PASS 前不生成 P4.4。

## 2026-07-16 · P4.3 second review failed after implementation commit 0bbc0ca

- 第二轮 reviewer 冷验收确认 `scripts/verify_ios.sh`、Audio 21/21、Progress 7/7、Features 93/93、App integration 5/5、UI 26/26、Web 53/53、baseline 全部通过，lint 精确保持既有 4 errors/0 warnings；但源码审查结论仍为 FAIL。
- 阻断为：旧 `selectMode` 可在 suspended stop 后覆盖新 mode UI；旧 background intent 可在 suspended pause 后覆盖新会话；start/select loading 可被 lifecycle/mode generation 静默取消并永久悬空；engine start failure 已生成 token 却发布无 token terminal failure。
- 用户要求转交其他线程，当前不继续修复。接手者先读 P4.3 任务卡末尾的第二轮复核交接，补三组 suspension 测试和 play-start token 断言，再修复、跑全门禁并启动新的独立 reviewer。P4.3 PASS 前不得生成 P4.4。

## 2026-07-16 · P4.3 first review failed, race fixes developed

- 第一轮 reviewer 在全部既有门禁通过时仍判定 FAIL：旧 NEXT/太简单可能因 actor reentrancy 覆盖新切课，nil request failure 可污染新会话，任务卡并发/失败矩阵缺测，选课 load failure 的重试按钮实际无效。
- 修复将 generation 提前到用户 intent 的首次 await 之前，所有异步恢复绑定 generation/course/entry；Audio media reset 保留 request token，StudyStore 拒绝无 token 的迟到失败；retry 记录并重新加载实际请求课程。
- 新增可控 progress/course/audio suspension 与 counted barrier，确定性覆盖旧 NEXT、旧太简单、并发 NEXT×3、A→B→C 旧 load、nil/preload failure、load/prepare/play retry、waiting 中手动 NEXT/切 REPEAT。冷门禁通过 Audio 21/21、Progress 7/7、Features 93/93、App integration 5/5、UI 26/26、Web 53/53、baseline 与统一 iPhone build/test；待修复提交和第二轮独立冷复核。

## 2026-07-16 · P4.3 StudyStore/LISTEN developed, pending review

- 新增真实 `StudyStore`、typed clients、selection/projection、Listen session generation、controlled 500 ms clock、临时内存进度 actor 与 live iPhone route；启动提交进入真实默认课程，P3 fixture 路由和公共入口保持可达。
- LISTEN 已接内置 30 门课程、AudioPlayer current+next、重播、NEXT、太简单、AUTOPLAY、切课、文字可见性与当前会话进度；REPEAT 保持静态且不录音、不计次。旧 token/timer/切课回调静默，失败关闭 AUTOPLAY，后台不自动恢复。
- 开发侧门禁通过：Progress 7/7、Features 85/85、App integration 5/5、UI 26/26、Web 53/53、baseline、统一 iPhone build/test 与 diff check；lint 精确保持既有 4 errors、0 warnings。
- 当前待未参与实现的 reviewer 从提交 SHA 冷复核；P4.3 PASS 前不生成 P4.4，且没有 P4.4/P5/P6/P7、iPad、macOS、Catalyst 或 Designed for Mac 越界。

## 2026-07-16 · P4.3 StudyStore/LISTEN task ready

- P4.2 独立复核 PASS 后新增 [`../tasks/2026-07-16-p4-3-study-store-listen.md`](../tasks/2026-07-16-p4-3-study-store-listen.md)；本提交只锁定 CP-11 任务卡，不实施业务代码。
- 保留 P3 presentation/fixture stores，新增按文件拆分的真实 `StudyStore`、consumer-owned clients、controlled clock/random 和临时内存 Progress adapter；不把 Repository/Audio/timer 塞回 View。
- LISTEN 以 generation + request token 同时隔离音频事件和 500 ms wait；修正 Web stale timer、音频失败不关 autoplay、sequential 初始随机和最后一条死锁等历史缺口。
- 默认 Startup 合法 START 后进入真实学习页，同时新增确定性 live test route；既有 gallery/P3 fixture 路由、UI 与截图保留。
- P4.3 仅交付 iPhone 内置课 LISTEN。完成/重练属 P4.4，身份/持久化/同步属 P5，REPEAT 属 P6，课程下载属 P7；P4.3 PASS 前不生成 P4.4。

## 2026-07-16 · P4.2 native audio player independently reviewed PASS

- 独立 reviewer 从提交 `f6c2f51` 删除全部生成物、统一/Package SwiftPM cache 和 DerivedData 后冷重建，确认 Audio 21/21、真实 Bundle M4A App integration 3/3、原有 UI 25/25、Web 50/50、baseline 和 iPhone build 全部通过；lint 精确保持既有 4 errors、0 warnings。
- 独立代码审计确认本地普通文件限制、current/next 双槽复用、每次 play token、finish/decode 保留结算 token 但先失效 active token、engine+token 双匹配、exactly-once 与迟到 callback 隔离。
- interruption、耳机拔出、background 不自动恢复，media reset fail closed；P3 未接 Audio，无 P4.3 编排、网络、录音、后台音频、Remote Command、iPad/macOS/Catalyst/Designed for Mac 产品。
- P4.2 结论为 PASS。下一步可基于已验证的 Repository、AudioPlayer 和 P3 Shell 生成 P4.3 StudyStore/LISTEN 任务卡。

## 2026-07-16 · P4.2 native audio player developed, pending review

- `WordLoopAudio` 已实现只播放已验证本地 file URL 的 actor `AudioPlayer`：current/next 双槽、每次 play request token、typed snapshot/event/error 与迟到 callback 隔离。
- live adapter 使用 AVAudioPlayer 和 playback/spokenAudio session；interruption、耳机拔出、background 暂停且不自动恢复，media reset fail closed。不启用后台音频、Now Playing、Remote Command、麦克风或桌面产品。
- 开发侧已通过 Audio 21/21、真实 Bundle M4A App integration 3/3、原有 UI 25/25、Web 50/50、baseline 和统一 iPhone 构建；lint 精确保持既有 4 errors、0 warnings。
- P3 App/Features 尚未构造 AudioPlayer；课程/条目选择、AUTOPLAY、500 ms/NEXT 与 Listen session generation 属于 P4.3。P4.2 独立复核 PASS 前不得生成或实施 P4.3。

## 2026-07-16 · P4.1 reviewed, P4.2 AudioPlayer task ready

- P4.1 独立复核 PASS 后新增 [`../tasks/2026-07-16-p4-2-audio-player.md`](../tasks/2026-07-16-p4-2-audio-player.md)；本提交只锁定 CP-10 任务卡，不实现播放器。
- P4.2 固定本地 file URL、AVAudioPlayer current/next 双槽、每次 play request token、actor 状态/多播事件、单次 finish/fail 与迟到 callback 隔离；Audio 不认识 course/entry/autoplay。
- interruption、耳机拔出和 background 均暂停并失效 token，回前台/中断结束不自动恢复；media reset fail closed。无 background audio、Now Playing、Remote Command、麦克风或桌面产品。
- Web 当前没有音频 token，且已排队的 500 ms timer 有切课/切模式迟到风险；P4.2 只解决 audio callback，P4.3 必须再用 Listen session generation 解决 AUTOPLAY/NEXT 业务 timer。
- P4.2 PASS 前不得接 StudyShell/Repository，不得生成或实施 P4.3。

## 2026-07-16 · P4.1 bundled repository independently reviewed PASS

- 独立 reviewer 从提交 `58f9101` 删除 `content/dist`、两个 iOS resource 目标、统一/Package SwiftPM cache 与 DerivedData 后冷重建，确认 Core 9/9、Content 12/12、App integration 2/2、既有 UI 25/25、Web 47/47 与 baseline 全部通过；lint 精确保持既有 4 errors、0 warnings。
- 完整模式复验 30 门、570 word + 836 sentence、1,406 个音频 SHA 与 32,700,838 bytes；mutation、typed error、Repository 成功缓存/失败重试/unknown course 均通过。
- 正式 App 根目录只有一套 Content bundle，含 1,406 M4A、30 course manifests、30 integrity、1 catalog、0 audit report；XCTest 插件中的测试依赖副本不属于正式产品资源。
- reviewer 额外注入 Package 第二目标 rename 失败，确认第一目标旧树 digest 不变、失败退出且无 stage/previous 残留。Release 继续是 iOS 17、Swift 6、iPhone-only，无 Catalyst、Designed for Mac、iPad 或桌面产品。
- P4.1 结论为 PASS。下一步只能基于已验证的 Repository/audio URL API 生成 P4.2 AudioPlayer 任务卡，不能提前实施 P4.3 LISTEN 接线。

## 2026-07-16 · P4.1 bundled repository developed, pending review

- Core 已新增 fail-closed stable ID、课程枚举与 catalog/descriptor/course/entry 值模型；Content 已新增严格 wire DTO、typed error、`BundledCourseSource` 轻量/完整校验和成功缓存/失败重试的 actor `CourseRepository`。
- bootstrap 从同一 exporter 产物原子刷新 `ios/Generated` 与 Package resource mirror；SwiftPM 使用 `.copy` 保留目录，App 只接 `catalog.json + courses/`，明确排除 `validation-report.json`。生成目录保持 ignored/untracked。
- 开发侧已确认 Core 9/9、Content 12/12、30 门/1,406 entries 与 M4A/32,700,838 bytes/全部 SHA、App integration 2/2、原有 UI 25/25、Web 47/47、baseline、统一 iPhone 构建和 diff hygiene；lint 精确保持既有 4 errors、0 warnings。
- 主 App 根目录实查只有一个 `WordLoopContent_WordLoopContent.bundle`，含精确 1,406 个 M4A 且无审计 report；XCTest 插件按测试依赖另嵌资源，不属于正式 App 根资源。P3 UI/fixture 未接 Repository，无播放器、进度、网络、下载、Realtime 或桌面越界。
- P4.1 当前开发完成待独立 reviewer 冷验证；PASS 前不得生成或实施 P4.2 AudioPlayer。

## 2026-07-16 · P3 complete, P4.1 bundled repository task ready

- P3.6 独立复核 PASS 后新增 [`../tasks/2026-07-16-p4-1-bundled-content-repository.md`](../tasks/2026-07-16-p4-1-bundled-content-repository.md)；本提交只锁定 CP-09 任务卡，不实现 Core/Content。
- P4.1 固定 Core 强类型 ID/catalog/course/entry/StudyMode、严格 wire DTO、`BundledCourseSource`、轻量/完整 integrity 校验与 actor `CourseRepository`；正式内容暂不接入任何 P3 UI/Store。
- bootstrap 必须在 Package 解析前生成被忽略的 target resource mirror，使用 `.copy` 保留目录；App 只打包 `catalog.json + courses/` 与 1,406 个 M4A，明确排除含 Web 源审计路径的 `validation-report.json` 和第二套资源。
- 当前 1 random word + 29 sequential sentence 是机器真值；P4.1 不修静态 fixture 与正式 ID/highlight/phonetic 的已知差异，不实现播放器、LISTEN、进度、网络、下载、Realtime 或桌面产品。P4.1 PASS 前不得生成或实施 P4.2。

## 2026-07-16 · P3.6 independently reviewed PASS

- 独立 reviewer 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的冷状态确认 `scripts/verify_ios.sh`，并复验 DesignSystem 13/13、Features 65/65、App integration 1/1、UI 25/25、Web 44/44、baseline、diff/ignore hygiene；lint 精确保持既有 4 errors、0 warnings。
- 两类 dialog、固定错误、不可点遮罩、completion > course > progress、选择课程唯一打开 CourseDrawer、restart intent 不改状态、11 个 REPEAT 展示态、retry transcript、accessibility 3 与 Reduce Motion 全部通过；无课程解析、音频、麦克风、Realtime、网络、持久化或 timer 越界。
- 六 palette 独立实算最低为 secondary 5.068:1、boundary 3.097:1、primary/error 8.764:1、success 3.162:1、failure 3.112:1；五张真实 iPhone 截图 hash、尺寸和逐张视觉均通过。
- reviewer 首次把提交内干净截图与临时损坏帧判反；按两个精确 SHA 原始分辨率复验后撤销误报，确认提交内 `17725e…8ac` 完整无黑条，最终结论为 PASS。下一步只基于当前真实静态 Shell/API 生成 P4.1 任务卡。

## 2026-07-16 · P3.6 completion dialog and REPEAT states developed, pending review

- 新增两类 `COURSE COMPLETE` 原生对话框、固定错误、不可点击关闭的 material backdrop 和 completion > course > progress 的模态优先级；选择课程打开既有 CourseDrawer，重新开始/再练一次只记录 intent，不改变 S01E01、75/91、1/3 或任何进度。
- REPEAT 卡新增 11 个确定性纯展示态、passed 圆形勾号及 retry/error transcript；accessibility 3 纵向自适应/可滚动，Reduce Motion 停止 waveform。没有音频、麦克风、评分、Realtime、网络、持久化、timer 或正式课程解析越界。
- dialog 次要文字/边界/次按钮、强调波形与成功/失败视觉已按六 palette 实际层叠测试，最低分别为 5.068:1、3.097:1、8.764:1、3.162:1、3.112:1。
- 开发侧已通过冷构建、DesignSystem 13/13、Features 65/65、App integration 1/1、UI 25/25、Web 44/44、baseline、五张真实 iPhone 截图和 diff hygiene；lint 精确保持既有 4 errors、0 warnings。
- P3.6 当前开发完成待独立复核；PASS 前不得生成或实施 P4.1。

## 2026-07-16 · P3.5 reviewed, P3.6 task ready

- P3.5 独立复核 PASS 后新增 [`../tasks/2026-07-16-p3-6-completion-dialog-repeat-states.md`](../tasks/2026-07-16-p3-6-completion-dialog-repeat-states.md)；本提交只锁定 CP-08 任务卡，不实现对话框或新增 REPEAT 状态。
- P3.6 固定两类 `COURSE COMPLETE` 对话框、重置失败文案、不可点遮罩、取消/选择课程/restart intent，以及 `idle/connecting/ready/playing/speak/speaking/scoring/passed/paused/retry/error` 11 个纯展示态。
- completion dialog 优先于两个抽屉；restart intent 不重置任何数据。REPEAT 只展示 waveform/check/transcript，不播放音频、不请求麦克风、不接 Realtime/评分/timer；继续只面向 iPhone。
- P3.6 PASS 前不得生成或实施 P4.1。

## 2026-07-16 · P3.5 progress drawer independently reviewed PASS

- 独立 reviewer 确认右侧 344/86vw 抽屉、summary/track/stats、sentence/word/mixed/complete/query/empty fixture、0...3 与完成语义、header/backdrop/主导右滑关闭、列表独立滚动、modal 背景隔离与关闭后恢复均符合任务卡。
- 课程/进度抽屉互斥，冲突 launch arguments 保持课程抽屉优先；进度 action 未改变 StudyShell，主学习上下文仍为 S01E01 第 75/91 条。无 P4 课程解析、P6 持久化/同步、P7 远程课程/下载或网络、音频、Realtime 越界。
- 六 palette 实际合成独立复算最低为次要文字 5.068:1、边界 3.097:1、语义填充 8.764:1。四张真实 iPhone 截图的 hash、尺寸与逐张人工视觉检查一致。
- 从删除生成物、统一/Package SwiftPM cache 与 DerivedData 的冷状态重跑：八 Package tests/iPhone build、DesignSystem 12/12、Features 51/51、App integration 1/1、UI 20/20、Web 43/43 全部通过；lint 精确保持既有 4 errors、0 warnings，diff/ignore hygiene 通过。
- iOS 17、Swift 6、iPhone-only 设置保持，Catalyst/Designed for iPhone on Mac 关闭。P3.5 结论为 PASS，下一步只生成 P3.6 任务卡，本次不生成或实施。

## 2026-07-16 · P3.5 progress drawer developed, pending review

- 新增 ProgressDrawer entry/summary/state/fixtures/store 与 SwiftUI 右侧抽屉；基线为 0/273、0 已掌握/91 学习中和 10 条 S01E01 代表句，并提供 word、mixed、complete、query、empty fixture。
- `PROGRESS` 已接入主学习页；课程/进度抽屉互斥，冲突 launch arguments 保持课程抽屉优先。header、backdrop、主导右滑关闭、搜索/clear、列表纵向滚动、完成语义和背景恢复均有 UI automation。
- `ProgressTrack` 使用可达标语义 fill 与 56% ink underlay，canonical accent 只作 1 pt 装饰；次要文字 75% ink、边界 56% ink 按真实 sRGB 合成测试，六 palette 分别至少 4.5:1/3:1。
- 四张真实 iPhone 17e/17 Pro 截图覆盖 sentence baseline、mixed、word search、accessibility 3 + Reduce Motion；验证记录见 [`../ios-migration/p3/progress-drawer/visual-verification.md`](../ios-migration/p3/progress-drawer/visual-verification.md)。
- 开发侧已确认 Features 51/51、Web 43/43，lint 仍为既有 4 errors、0 warnings；完整冷构建与 App 20 项 UI 矩阵交由独立 reviewer 复验。P3.5 当前待复核，PASS 前不得生成或实施 P3.6。

## 2026-07-15 · P3.4 reviewed, P3.5 task ready

- P3.4 独立复核 PASS 后新增 [`../tasks/2026-07-15-p3-5-progress-drawer.md`](../tasks/2026-07-15-p3-5-progress-drawer.md)；本提交只锁定 CP-07 任务卡，不实现进度抽屉。
- P3.5 以 M-04 和真实 390 × 844 Web 截图为基线：右侧 344/86vw 抽屉、`YOUR PROGRESS`、0/273、当前课程、track、已掌握/学习中、sentence/word 搜索、0...3 列表和三种关闭。
- fixture 只含代表行和独立 summary 总量，不复制 91/570 条完整内容；不得读取 P6 Progress、API/outbox 或模拟同步。Course/Progress 双抽屉必须互斥，冲突 fixture 保护既有课程抽屉优先级。
- 继续只面向 iPhone；P3.5 PASS 前不得生成或实施 P3.6。

## 2026-07-15 · P3.4 course drawer independently reviewed PASS

- 独立 reviewer 确认三集合 fixture、搜索/空态/折叠、selected/completion、header/backdrop/主导左滑关闭、纵向列表滚动、modal 背景隔离和 accessibility 3 + Reduce Motion 均符合任务卡；点击 S01E02 后主学习页仍为 S01E01 / 75/91。
- CourseCard 真实层顺序为半透明同色卡片背景叠在不透明 drawer background 上，与测试层顺序一致；六 palette 次要文字/边界和 selected 双边界均通过。四张真实 iPhone 截图的 hash、尺寸和人工视觉检查一致。
- 从删除生成物、统一/Package SwiftPM cache 与 DerivedData 的冷状态重跑：八 Package tests 与 iPhone build、DesignSystem 12/12、Features 39/39、App integration 1/1、UI 16/16、Web 42/42 全部通过；lint 精确保持既有 4 errors、0 warnings，diff check 通过。
- 无正式课程解析/切换、持久化、网络/下载、音频、进度或 Realtime 越界；iOS 17、Swift 6、iPhone-only 设置保持。P3.4 结论为 PASS，下一步只生成 P3.5 任务卡，本次不生成或实施。

## 2026-07-15 · P3.4 course drawer developed, pending review

- 新增 CourseDrawer 展示模型、三集合 fixture、确定性搜索/折叠、dismiss reason/action、`@MainActor @Observable` 内存 Store 和 SwiftUI 左侧抽屉；P3.3 `COURSE` 已接入，默认 Startup 与关闭的 study shell 路由不变。
- 抽屉覆盖 selected/completion、空态、header/backdrop/主导左滑关闭、列表独立滚动、modal 背景隔离和 accessibility 3 + Reduce Motion；点击 S01E02 后仍验证主学习页为 S01E01 / 75/91，不模拟真实切课。
- `SideDrawer` 支持可选 kicker、关闭 identifier 与由组合容器承载 modal trait；右侧遮罩作为同一 modal accessibility tree 的稳定按钮暴露。CourseCard 次要文字/边界改为共享 75%/56% 合成 token，六 palette 最低 5.068:1/3.097:1；selected 保留 canonical accent 外框和语义 ink 内框。
- 四张真实 iPhone 17e/17 Pro 截图已保存并人工核对，覆盖默认、空态、`× 12` 完成次数和辅助字号收起态；尺寸、fixture、hash 与平台差异见课程抽屉视觉验证。
- 从删除生成物、SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、DesignSystem 12/12、Features 39/39、App integration 1/1、UI 16/16、Web 42/42 全部通过；lint 精确保持既有 4 errors、0 warnings，diff check 与 ignore hygiene 通过。
- P3.4 当前开发完成待独立复核；PASS 前不得生成或实施 P3.5 进度抽屉。

## 2026-07-15 · P3.3 re-reviewed PASS

- 修复后独立 reviewer 确认 PosterBackground、ModeSwitch 与测试共用 `posterAccent / modeTrack / modeUnselectedText = 0.58 / 0.10 / 1.0`；sun 纯背景与 accent 圆环区域按真实 sRGB 层叠分别为 8.746483:1 与 5.300792:1，均超过 4.5:1。
- speaker/visibility SF Symbols 均固定为 18 pt semibold、各处于独立 44 pt frame；accessibility 3 截图无越界重叠，UI test 验证按钮可点击、命中框至少 44 pt 且不相交。
- 四张刷新截图的 hash/尺寸与文档一致，均为真实 study shell。DesignSystem 12/12、Features 26/26、相关 UI 4/4、App integration 1/1、Web 41/41 全部通过；lint 精确保持既有 4 errors、0 warnings。
- P3.3 修复后独立复核结论为 PASS。下一步只根据当前真实主学习页 API 生成 P3.4 课程抽屉任务卡，不提前实施。

## 2026-07-15 · P3.3 visual blockers fixed, re-review pending

- Design System 新增实际 sRGB layer compositing 和共享 `posterAccent / modeTrack / modeUnselectedText` opacity token；ModeSwitch 未选中文字改用不透明 ink，纯背景和 accent 圆环下实算约 8.746:1/5.301:1，同一 UI token 的单元测试锁定两种底层至少 4.5:1。
- 主学习页 speaker/visibility SF Symbols 固定为 18 pt semibold，不再被 accessibility Dynamic Type 放大出 44 pt 圆形；UI test 验证两个按钮可点击、各至少 44 pt 且 frame 不相交。
- 四张 study shell 截图全部从刷新 App 重拍并更新 hash；辅助字号图标边界与模式文字对比均已人工核对。
- 修复后从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、DesignSystem 12/12、Features 26/26、App integration 1/1、UI 12/12、Web 41/41 全部通过；lint 精确保持既有 4 errors、0 warnings。仍需重新独立复核；P3.3 PASS 前不得生成或实施 P3.4。

## 2026-07-15 · P3.3 review failed on actual contrast and accessibility controls

- 独立 reviewer 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、Features 26/26、App integration 1/1、UI 12/12、Web 41/41 全部通过；lint 精确保持既有 4 errors、0 warnings。
- 默认 Startup、gallery/study fixture 优先级、highlight/visibility/Store 纯规则、四张截图 hash/尺寸、无业务运行时依赖和 iPhone-only 设置均通过；标准 390 × 844 repeat/listen 页面完整。
- 阻塞一：sun ModeSwitch 的未选中文字跨在 accent 58% 圆环上，继续叠加 track ink 10% 与 text ink 72% 后实际仅 3.389973:1，低于小文字 4.5:1；现有测试只测不透明 ink/background，没有覆盖页面真实 alpha 层叠。
- 阻塞二：accessibility 3 下播放/visibility SF Symbols 随字号放大并越出各自 44 pt 圆形、互相重叠；现有 UI test 只证明 `NEXT` 可滚动到达，没有检查学习动作几何。
- P3.3 结论为 FAIL。修复真实层叠对比度和 Dynamic Type 图标尺寸/间距、刷新 listen/accessibility 截图并冷验收后重新复核；PASS 前不得生成或实施 P3.4。

## 2026-07-15 · P3.3 main study shell developed, pending review

- 新增 StudyShell 展示模型、Character-offset highlight range、句子/单词 visibility cycle、`@MainActor @Observable` 内存 fixture Store 和独立 `MainStudyView`；没有依赖正式课程领域模型，也没有模拟业务进度。
- App 默认仍是 Startup；仅 `-wordloop-study-shell` 显式进入主学习页，Design System gallery 在冲突参数下优先。Listen/Repeat、sentence/word/long-word、full/focus/hidden、palette、mastery 和 autoplay fixture 可组合。
- 390 × 844 pt 标准 Listen/Repeat 保持顶部导航、课程上下文、超大英文、中文、学习动作和底部控制完整；accessibility 3 将顶/底控制重排并启用纵向可达滚动。黑色 Web 截图过渡伪影未进入原生实现。
- 四张真实 iPhone 截图、尺寸、fixture、hash 和与 Web 的差异已记录；sun 小文字使用通过测试的 ink/semantic role，标准控件至少 44 pt，Reduce Motion 停止大位移和循环波形。
- 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、Features 26/26、App integration 1/1、UI 12/12、Web 41/41 全部通过；lint 精确保持既有 4 errors、0 warnings。
- P3.3 当前是开发完成待独立复核；PASS 前不得生成或实施 P3.4 课程抽屉。

## 2026-07-15 · P3.2 re-reviewed PASS

- 修复后独立 reviewer 确认 canonical rose palette 未改变，StartupView 与测试使用同一最终 sRGB 角色；placeholder 和输入边界实算分别为 5.083759:1 与 3.157488:1，达到 4.5:1/3:1 门槛，Node 静态测试锁定接线并禁止旧 opacity 回归。
- 四张刷新截图的 hash/尺寸与文档一致，均为真实 Startup 页面；iPhone 17 Pro、390 × 844 pt iPhone 17e 和 accessibility 3 + Reduce Motion 无裁切、重叠或调试画面。
- 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、Features 13/13、App integration 1/1、UI 8/8、Web 40/40 全部通过；lint 精确保持既有 4 errors、0 warnings。
- Release 设置实测为 iOS 17、Swift 6、iPhone device family，Catalyst 与 Designed for iPhone on Mac 均关闭；Startup 仍无越层业务依赖。P3.2 结论为 PASS，下一步只生成 P3.3 主学习页任务卡，不提前实施。

## 2026-07-15 · P3.2 startup input contrast fixed, re-review pending

- canonical rose palette 保持不变；新增预合成 `StartupVisualRoles`，placeholder 使用 ink 72% 合成色约 5.084:1，下划线使用 accent 86% 合成色约 3.157:1，分别超过文本 4.5:1 和控件边界 3:1。
- StartupView 直接引用最终 sRGB 角色，不再使用首次 review 指出的 0.56/0.78 accent opacity；Features 两项测试断言同一角色对象，Node 静态测试锁定接线并禁止旧值回归。
- 四张 startup 截图已在原设备/fixture 下重拍并更新 hash；需从冷缓存重跑完整验收并重新独立复核，PASS 前仍不生成或实现 P3.3。

## 2026-07-15 · P3.2 review failed on startup input contrast

- 独立 reviewer 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、Features 11/11、iPhone build、App integration 1 项、UI 8 项、Web 40/40 全部通过；lint 精确保持既有 4 errors、0 warnings。
- 默认 Startup、gallery launch-argument 边界、用户名规则、按钮/Return、busy 三态、键盘操作、Dynamic Type/Reduce Motion、业务隔离、App 只 import Features 与 iPhone-only 设置均通过；四张截图 hash/尺寸匹配且为真实无裁切页面。
- 阻塞问题：rose accent `#157d6a` 的 56% placeholder 合成到 `#f8d9df` 后仅约 2.071:1，低于普通文字 4.5:1；78% 输入下划线约 2.822:1，低于输入控件视觉边界 3:1。现有测试没有覆盖实际 alpha 合成组合。
- P3.2 结论为 FAIL。保持 canonical palette 不变，改用达标的 placeholder/边界角色并补真实合成对比测试、刷新截图后重新独立复核；PASS 前不得生成或实现 P3.3。

## 2026-07-15 · P3.2 startup page developed, pending review

- 默认 iPhone App 已从 Design System gallery 切到原生启动页；gallery 只保留 `-wordloop-design-system-gallery` 测试入口，App 仍只 import Features，没有桌面/iPad 产品分支。
- Startup feature 已拆为 state、submission、纯 ASCII 用户名 validator、`@MainActor @Observable` 内存 fixture Store 和 SwiftUI View；留空匿名、trim/lowercase、32 字符、固定错误、编辑清错和 busy 防重入均有 Package tests。
- 页面覆盖 `START / PREPARING… / SYNCING…`、两条中文辅助状态、按钮与 Return 提交、原生键盘避让、44 pt 命中区、accessibility identifiers、辅助字号和 Reduce Motion；未接持久化、课程、进度、网络、音频或 Realtime。
- iPhone 17e 390 × 844 pt 的 idle/invalid/accessibility 3 及 iPhone 17 Pro syncing 四张截图已保存并人工核对；无裁切、重叠、启动黑边或 gallery，平台差异和 hash 见 startup visual verification。
- 从删除课程生成物、统一/Package SwiftPM cache 和 DerivedData 的状态重跑：八个 Package tests、iPhone build、App integration 1、UI 8、Web 40/40 全部通过；lint 精确保持既有 4 errors、0 warnings。
- P3.2 当前是开发完成待独立复核；PASS 前不得生成或实现 P3.3 主学习页。

## 2026-07-15 · P3.1 re-reviewed PASS

- 修复后独立 reviewer 确认 `ConfirmDialog` 使用的真实 `background text / accessible role fill` 组合在六套 palette 下为 8.764–10.784:1，全部超过 4.5:1；单元测试覆盖同一组合，组件接线与测试角色一致。
- 三张刷新截图 hash 与文档一致；iPhone 17 Pro、390 × 844 pt iPhone 17e 和 accessibility 3 + Reduce Motion 均为真实 gallery，辅助字号 palette 标签与右上装饰圆不再重叠或裁切。
- 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑：八个 Package tests、iPhone build、App integration 1 项、UI 3 项、Web 39/39 全部通过；lint 精确保持既有 4 errors、0 warnings。
- P3.1 修复后独立复核结论为 PASS。下一步只根据当前真实 Design System API 生成 P3.2 启动页任务卡，不提前实现后续页面。

## 2026-07-15 · P3.1 contrast and accessibility layout fixed, re-review pending

- ConfirmDialog 主按钮不再直接使用低对比 canonical accent 填充；改用每套 palette 已通过 4.5:1 的角色色作为填充，background 作为文字，同时用 canonical accent 细边框保留产品色彩语义。
- DesignSystem tests 新增六套实际 `button text / selected fill` 对比组合，关闭首次 review 漏测。
- gallery palette 装饰圆移到右上独立区域并从 accessibility tree 隐藏；标签固定左下、单行受控缩放，避免 accessibility 3 下相互覆盖。
- 需重拍标准/最窄/辅助字号截图并重新独立复核；P3.1 PASS 前不进入 P3.2。

## 2026-07-15 · P3.1 review failed on critical-control contrast

- 独立 reviewer 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态重跑验收；八个 Package tests、iPhone build、App integration 1 项、UI 3 项、Web 39/39 与既有 lint 基线均通过。
- 官方 Geist tag/commit 与三份上游资产重新核验通过；两份 TTF 和原始 OFL license 均以预期 hash 进入最终 `WordLoop.app`。模块边界、App 只 import Features 和 iPhone-only 设置也通过。
- 阻塞问题：`ConfirmDialog` 主按钮使用 palette background 文字叠在 canonical accent 上，paper/sun/sky/rose/mint 的对比度仅 3.570/2.411/2.654/3.829/3.756:1，五套未达到关键控制小文字 4.5:1；现有单元测试没有覆盖这一真实组合。
- accessibility 3 截图还显示 palette 标签与装饰 accent 圆局部重叠。先增加 accent-filled control 前景角色及六 palette 回归，并让辅助字号文字避开装饰层，再从冷状态重新复核；P3.1 结论为 FAIL，PASS 前不得进入 P3.2。

## 2026-07-15 · P3.1 developed, pending review

- `WordLoopDesignSystem` 已实现六套 palette、tokens、Geist Sans/Mono、字体注册/系统回退、触觉协议、Reduce Motion 和九类无业务 SwiftUI 组件；自身不再依赖任何业务 Package。
- Geist 1.8.0 两个 variable TTF 与原始 OFL 1.1 license 已提交并核验上游字节；含许可未压缩增量 344,268 bytes，逐文件 hash 见字体审计。
- 六套 ink/background 与小文字角色对比度由单元测试锁定至少 4.5:1；机器真值 accent 不改，只有不合格的小文字角色回退 ink。
- Features fixture gallery 已在 iPhone 17 Pro、390 × 844 pt iPhone 17e 和 accessibility 3 + Reduce Motion 三组状态截图；App 仍只 import Features，gallery 不连接业务。
- 冷启动 verify、DesignSystem 11 tests、Features 2 tests、App integration 1 test、App UI 3 tests、Web 39/39 全部通过；lint 仍精确为既有 4 errors、0 warnings。
- P3.1 仍需未参与实现的 reviewer 复核；PASS 后才能生成 P3.2 启动页任务卡。

## 2026-07-15 · P2 reviewed, P3.1 task ready

- P2 修复后独立复核 PASS：真实 package-local SwiftPM cache 已被 ignore，冷启动 verify、八个 Package tests、iPhone build、App integration/UI tests、Web 38/38 和工程卫生均通过。
- 新增 [`../tasks/2026-07-15-p3-1-design-system.md`](../tasks/2026-07-15-p3-1-design-system.md)，只实现 Design System tokens、字体、基础组件和无业务 fixture gallery，不提前进入启动页或学习业务。
- Geist 固定到官方 `vercel/geist-font` tag `1.8.0` / commit `91158e0`；按 OFL 1.1 随 App 嵌入时必须提交并分发原始许可文本，同时记录字体 SHA-256 和包体增量。
- 迁移继续只面向 iPhone；Package 的 macOS host 支持仅用于 `swift test`，不得扩展成桌面产品。

## 2026-07-15 · P2 re-reviewed PASS

- 独立 reviewer 执行常规 package-local `swift test --package-path ios/Packages/WordLoopCore`；生成的 `.build/` 被递归规则忽略，`git status --short` 无缓存污染，新增静态 ignore 回归通过。
- 从删除课程生成物、统一/Package 本地缓存和 DerivedData 的状态重跑验收；八个 Package tests、iPhone 17 Pro / iOS 26.5 Simulator build、App integration/UI tests 全部通过。
- `npm run baseline:ios` 通过，`npm test` 38/38；lint 精确保持既有 4 errors、0 warnings；没有 Web 业务或 iOS App/Package 实现变更。
- P2 重新独立复核结论为 PASS。下一步根据当前真实工程生成 P3 Design System 与逐页静态 Shell 任务卡，不得跨阶段实现。

## 2026-07-15 · P2 Package cache hygiene fixed, re-review pending

- `.gitignore` 从只覆盖 `ios/.build/` 改为递归覆盖所有 `.build/`，因此统一验证目录和 `ios/Packages/<Package>/.build/` 标准 SwiftPM 缓存都不会污染工作区。
- 工程结构测试新增 package-local `.build/debug.yaml` ignore 回归，避免后续退化。
- 首次 reviewer 的其余冷启动构建、Package tests、App integration/UI tests、Web 38/38、lint、iPhone-only、密钥与边界检查均已通过；修复提交后必须重新独立复核，PASS 前仍不进入 P3。

## 2026-07-15 · P2 review failed on Package cache hygiene

- 独立 reviewer 从删除课程生成物、SwiftPM cache 和 DerivedData 的状态执行完整验收；`scripts/verify_ios.sh` 成功重建内容、通过八个 Package tests 并编译 iPhone 17 Pro / iOS 26.5 Simulator。
- 独立 `xcodebuild test` 确认 App integration test 与 UI skeleton launch test 均通过；Release build settings 和实际 App 产物均只声明 iPhone device family，Catalyst 与 Designed for iPhone on Mac 关闭。
- `npm run baseline:ios` 通过，`npm test` 38/38；lint 仍精确为 4 个既有 Web errors、0 warnings；无 Web 业务修改、远程 Swift dependency、密钥或已提交的生成物。
- 阻塞问题：当前 `.gitignore` 只覆盖 `/ios/.build/`，不覆盖每个 Package 的 `ios/Packages/<Package>/.build/`。执行 Plan 中的常规 Package 命令后会出现未跟踪缓存，不满足“`.build/` 与生成目录均 ignored”的验收标准。
- P2 结论为 FAIL。先补充 Package 本地 `.build/` 忽略规则和对应静态回归测试，再重新独立复核；PASS 前不进入 P3。

## 2026-07-15 · P2 developed, pending review

- 新增可直接打开的 iPhone-only SwiftUI 工程、共享 scheme、App integration/UI test targets；固定 iOS 17、Swift 6、`TARGETED_DEVICE_FAMILY=1`，不支持 iPad、macOS 或 Catalyst。
- 建立 Core、Networking、Content、DesignSystem、Audio、Progress、Realtime、Features 八个本地 Swift Package，App 只通过 Features 接入完整单向依赖图，没有第三方 Swift dependency。
- 新增统一 iOS 验证脚本和工程结构测试；从删除课程生成物、SwiftPM cache 与 DerivedData 的状态可重建内容、通过八个 Package tests 并编译 iPhone 17 Pro / iOS 26.5 Simulator。
- App integration test 和 UI skeleton launch test 已通过；`npm test` 为 38/38，课程基线/export/check 和 diff check 通过；lint 仍只有 4 个既有 Web errors、0 warnings。
- 当前 RootView 仅为无业务 skeleton，未提前实现课程解析、视觉页面、音频、进度、Realtime 或下载。必须独立复核 P2 后才生成 P3 Design System 任务卡。

## 2026-07-15 · P1 reviewed, P2 task ready

- 第三次独立 reviewer 对 `1806a26 + f8b7b2f + 2fc4120` 给出 PASS；竞态、篡改、额外文件、symlink 与 FIFO 注入均在 swap 前拒绝并保留旧目标。
- 实查 Xcode 26.6、Swift 6.3.3 和 iPhone 17 Pro / iOS 26.5 Simulator 可用；本机无 XcodeGen/Tuist，P2 使用已提交 `.xcodeproj`，不增加机器级生成器依赖。
- 新增 [`../tasks/2026-07-15-p2-native-project-skeleton.md`](../tasks/2026-07-15-p2-native-project-skeleton.md)，锁定 iOS 17、Swift 6、iPhone-only、八个本地 Package 和从空缓存验证。
- P7 运行时课程安装仍必须用 immutable version directory + 原子指针/目录切换，不得照搬 P1 可重建开发产物的双 rename。

## 2026-07-15 · P1 undeclared-file gap fixed, re-review pending

- 第二轮独立复核确认源竞态修复有效，但发现临时树只验证 expected 文件、未拒绝额外文件，因此仍为 FAIL。
- 临时树验证已改为递归枚举整个生成根，实际文件集合必须严格等于 catalog、report、每课 course/integrity 和全部声明音频；同时拒绝 symlink 与非普通文件。
- 新增 `afterMaterialize` 注入未声明 M4A 的回归，必须失败且旧目标 digest 不变。
- 双 rename 的强杀空窗由 reviewer 判定不阻塞可重建的 P1 开发产物；P7 App 安装器仍必须使用 immutable version directory + 原子指针/目录切换满足运行时零空窗。

## 2026-07-15 · P1 integrity race fixed, re-review pending

- 独立 reviewer 对首个 CP-01 提交给出 FAIL：音频在 build 读取/哈希后、materialize 硬链接前被并发改写时，临时树可能与 `integrity.json` 不一致。
- Exporter 已改为把内存中已哈希的 bytes 写入临时树，再按每课 integrity 逐文件复验 bytes/SHA/regular-file；复验成功后才替换目标。
- 新增两个竞态回归：build 后源变化仍输出一致快照；materialize 后临时文件被篡改必须失败且保留上次有效目标。
- 修复后 `npm test` 仍为 37/37，新增文件 lint 0 warning；必须由独立 reviewer 重新复核后才能通过 P1。

## 2026-07-15 · P1 developed, pending review

- 新增 `content/schema/`、成功/失败 fixtures 和 AST 驱动 exporter；30 门课程可由当前唯一源确定性生成 catalog/course/integrity 与 1,406 个 M4A 引用。
- 规范 ID 以运行时注册表为真值；validation report 显式记录 S01E01 历史 source ID 差异和 47 个当前被 Web 忽略的 stale highlight key。
- 全部 29 门句子课按真实注册表保持 `sequential`，只有 IELTS 为 `random`；已修正 P1 任务卡原先的错误表述。
- `content/dist/` 和 `ios/Generated/` 被 Git 忽略；bootstrap 可从空目录重建，不提交第二份课程或音频。
- `npm test` 构建成功且 37/37 通过；lint 只有 4 个既有 `app/page.tsx` errors、0 warnings；Web UI、课程、音频、API 和数据库未修改。

## 2026-07-15 · P0.1 reviewed, P1 task ready

- 独立 reviewer 对 `42b2486` 给出 PASS：33/33 测试通过、基线与 diff 检查通过、仅保留 4 个既有 lint error，业务源码和资源无修改。
- Reviewer 确认 S01E01 manifest/运行时 ID 历史差异与 collection ID 唯一性校验是 P1 必须处理的风险。
- 新增 [`../tasks/2026-07-15-p1-course-contract-exporter.md`](../tasks/2026-07-15-p1-course-contract-exporter.md)，明确运行时注册 ID 是规范 ID、Web 暂不改数据入口、生成产物与重复音频不入 Git。

## 2026-07-15 · P0.1 developed, pending review

- 冻结仅面向 iPhone 的当前产品基线；桌面端、iPad 和 macOS 不在迁移验收范围。
- 新增 [`../ios-migration/baseline/README.md`](../ios-migration/baseline/README.md) 及 6 张 390 × 844 移动 Web 证据截图、产品验收矩阵、D1/Node API 合同和质量基线。
- 新增 AST 驱动的内容清单工具与 5 项 mutation tests，验证真实注册表、30 门课程、570 个单词、836 个句子、1,406 个 M4A 和引用完整性。
- `npm test` 构建成功且 33 项通过；lint 仍只有 `app/page.tsx` 的 4 个既有 memoization 错误，P0.1 新增文件无 error/warning。
- Web UI、学习状态、课程、音频、API 和数据库均未修改。下一步必须先独立复核 CP-00，再生成 P1 任务卡。

## 2026-07-15 · P0.1 started

- 在 `codex/ios-migration` 分支开始执行完整迁移 Plan。
- 建立 [`../tasks/2026-07-15-p0-1-baseline-freeze.md`](../tasks/2026-07-15-p0-1-baseline-freeze.md)；当前只冻结 Web 行为、视觉、内容和 API 基线，不创建 iOS 工程或修改业务。
- P0.1 完成并独立复核前不得生成或执行 P1 实现任务。

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
