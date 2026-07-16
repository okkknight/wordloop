# P4.3 iPhone StudyStore 与离线 LISTEN 主链路

状态：任务卡已锁定，待开发

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：P0–P4.2 均已独立复核 PASS；P4.1 提供正式 Bundle `CourseRepository`，P4.2 提供已验证本地 URL 的 `AudioPlayer`。

## 目标

完成 CP-11：在 iPhone 上用新的真实 `StudyStore` 将内置 30 门课程、P3 已验收的学习页/课程抽屉/进度抽屉和 P4.2 AudioPlayer 接成可达的离线 LISTEN 主链路。用户从默认启动页点击 START 后可进入真实默认课程，可重播、手动前进、点击画布前进、开关 AUTOPLAY、在 500 ms 后自动前进、切换课程与文字可见性，并在当前 App 会话内看到真实学习计数。

本卡必须保持 P3 整体 UI、交互、布局、palette、可访问性和 fixture 截图风格。业务状态不塞回既有展示 Store，也不在单个 View 里编排 Repository、Audio、timer 和进度。

## 产品决策与 Web 冲突消解

- 默认课程仍为 `modern-family-s01e01`，默认模式仍为 REPEAT。P4.3 只实现 LISTEN 业务；切到 REPEAT 时必须停止 LISTEN 并展示已验收的 P3 静态 REPEAT 表达，不请求麦克风或 Realtime。
- word 与 random sentence 课在未掌握条目中用可测随机源选择；sequential sentence 初次从第一个未掌握条目开始，后续向后取下一个并回绕。Web 对 sequential 的初始随机是历史不一致，iOS 服从 `CoursePracticeOrder`。
- 选择优先排除 current；但若除 current 外已无未掌握条目且 current 仍小于 3 次，允许开始 current 的新学习轮。不复制 Web “最后一条 1/3 时 NEXT 死锁”。
- 每次进入新 LISTEN 学习轮立即记 1 次，上限 3；启动、切课、切入 LISTEN、NEXT 和画布前进均可开始新轮。speaker 只从头重播当前条目，不计次。
- AUTOPLAY 仅在当前音频自然结束且结算 token/session 仍有效时进入 `.waiting`；等待精确 500 ms 后再次校验 generation/course/item/token 才 NEXT。
- current 播放失败时关闭 AUTOPLAY、取消 waiting、保留当前条目及手动重播/NEXT；next preload 失败不影响 current。以冻结验收矩阵为准，不复制 Web 未处理 audio error 的缺口。
- 中断、耳机拔出、进后台或在 waiting 时失活都取消旧会话，不自动恢复。用户可用 speaker 从头重播，不新增 LISTEN PAUSE 控件。
- sentence 保留 full→focus→hidden，word 保留 full→hidden。沿用已验收的 iPhone P3 语义：hidden 时同时隐藏音标和翻译；不回退到 Web 在 hidden 仍显示翻译的不一致。
- 课程抽屉只展示 `.available` descriptor；Repository 仍保留 hidden/retired 真值。不读远程 catalog，不删除内置课。
- 桌面空格键、hover、键盘快捷操作不迁移。本产品只交付 iPhone 触控界面。

## 架构与文件边界

### 保留 P3 展示层

- 保留 `StudyShellStore`、`CourseDrawerStore`、`ProgressDrawerStore`、`CompletionDialogStore` 为 presentation/fixture store。它们的既有 public initializer、launch arguments、action-only 测试和截图必须继续通过。
- 新增 `LiveStudyView`，内部继续渲染 `MainStudyView`，不复制学习页 UI。
- 为 `MainStudyView` 新增 module-internal `StudyViewActions` closure bundle 或等价 live initializer；既有 public initializer 继续走 P3 Store action 路径。live path 只转发 play/selectMode/visibility/autoplay/next/tooEasy/course selection。
- `CourseDrawerView` 可新增 internal `onSelectCourse`，既有 public path 保持原行为。completion callbacks 与真实 reset 留给 P4.4。

### 新增真实业务协调层

在 `WordLoopFeatures/Sources/WordLoopFeatures/Study/` 按职责拆分，不得合并成新的超大文件：

- `StudyState.swift`：`StudyPhase`、`ListenPhase`、只读业务状态与 `ListenSessionGeneration`。
- `StudyStore.swift`：`@MainActor @Observable` 唯一业务协调器与用户 intent。
- `StudyClients.swift`：consumer-owned closure clients 与 live adapter；不扩大 Content/Audio 的 internal fake API。
- `ListenSession.swift`：audio event/token/generation/wait task 编排。
- `StudySelection.swift`：eligible/random/sequential/palette 纯函数。
- `StudyProjection.swift`：Core Course/Catalog/Entry 到 P3 child view states 的唯一映射。
- `LiveStudyView.swift`：组装现有 View，观察 `scenePhase`，不实现业务状态机。

`StudyStore` 至少拥有等价状态：

```swift
enum StudyPhase { case idle, loading, ready, failed }
enum ListenPhase { case idle, preparing, playing, paused, waiting, failed }

selectedCourseID: CourseID?
currentEntryID: EntryID?
nextEntryID: EntryID?
isAutoplayEnabled: Bool
listenGeneration: ListenSessionGeneration
activePlaybackRequestID: PlaybackRequestID?
```

公开 intent 至少为等价于：`start()`、`playCurrent()`、`selectCourse(_:)`、`selectMode(_:)`、`cycleVisibility()`、`next()`、`toggleAutoplay()`、`markTooEasy()`、`setApplicationActive(_:)`。clients、generation binding、selector、projection 与 temporary adapter 细节保持 internal，tests 通过 `@testable` 注入。

### consumer-owned clients

- `StudyCourseClient`：`catalog/course` async closure，live 适配 P4.1 `CourseRepository`。
- `StudyAudioClient`：`prepare/play/pause/stop/snapshot/events` async closure，live 适配 P4.2 `AudioPlayer`。
- `StudyClock`：可取消 `sleep(Duration)`；live 为 500 ms，tests 不使用 wall clock。
- `StudyRandomClient`：可确定选 eligible index 与不同 palette。
- `StudyProgressClient`：只定义 `snapshot/record/master` consumer contract；reset 在 P4.4 根据完成/重练状态机再演进，不在本卡预留伪实现。

### 临时进度 adapter

- 在 `WordLoopProgress` 新增明确命名的 `TemporaryProgressRepository`，为 actor 内存实现。key 必须至少是 `(CourseID, StudyMode, EntryID)`，LISTEN/REPEAT 与课程之间不串数据，count clamp 到 `0...3`。
- 不写 UserDefaults/SwiftData/Keychain/文件，不访问网络，不构造 outbox 或“已同步”。App 重启丢失计数是本卡已知临时边界。
- P5 必须整体替换并删除 temporary adapter；不得在上面继续叠加生产持久化。

## 启动与路由

新增可单测的 `AppRouteResolver`，优先级锁定为：

1. `-wordloop-design-system-gallery`；
2. `-wordloop-study-shell` 及全部 P3 fixture arguments；
3. `-wordloop-live-study` 真实 Repository + Audio 路由；
4. 默认 Startup。

- 既有 gallery 压过 study fixture、completion > course > progress 和 course/progress 互斥规则原样保留。
- 默认冷启仍先显示 Startup；合法用户名或匿名 START 成功后进入 live study 并调用 `StudyStore.start()`。P4.3 不持久化身份、用户名或最近课程；P5 接管。
- `-wordloop-live-study` 仅用于确定性 integration/UI tests 直达真实主链，不是第二套产品 UI。
- `AppContainer` 只组装一份 live `CourseRepository`、`AudioPlayer` 和 temporary progress actor，不在 View 内重复构造。不将 AVFoundation 或 Bundle 路径暴露给 App/UI。

## LISTEN 会话与并发规则

- `start`、切课、切模式、手动 NEXT、太简单后前进、AUTOPLAY 取消 waiting、App 失活/后台和 Store deinit 都必须 bump generation 且取消旧 wait task。
- 每个 async course load、audio prepare/play/event、clock wake 回写前同时校验 generation + course ID + entry ID；audio finish/fail 还必须校验 `PlaybackRequestID`。
- 快速 A→B→C 切课、NEXT×N、waiting 时手动 NEXT、切模式、切课、关 AUTOPLAY、退后台都不得让旧 finish/fail/timer 改变新会话。
- 进入一个新学习轮时，从同一 progress snapshot 原子选择 current/next、写入当前计数并投影 UI；不先选条目再异步合并旧进度。
- Audio `.finished` 仅进 waiting，不计次且不直接晋升 next；500 ms 后调用与手动 NEXT 相同的新学习轮路径。
- App 在 audio playing 或 waiting 时进后台均进 paused/idle-safe 状态并关闭自动前进会话；回 active 不播放。scene lifecycle 必须在 StudyStore 层同时守住 waiting，不只依赖 AudioPlayer 的 playing pause。

## 正式内容到 UI 的唯一投影

- Catalog collection/descriptor 投影为 CourseDrawer 数据，只显示 available course；selection/completion/mastery 由 Study/Progress 状态补全，不从 Content 伪造。
- `CourseEntry.text/translation/phonetic` 诚实映射；word phonetic 的 `/.../` 是展示格式，不改 Core 真值。nil translation/phonetic 保持无内容，不造文案。
- highlights 通过现有 Character-offset 规则投影；未命中 token 不得产生非法 range 或改写正文。
- 课程 label/title、current/total、mastery 0...3、palette 和文字 visibility 从同一 StudyStore snapshot 投影，不得出现旧课 title + 新课 entry 的混合帧。
- ProgressDrawer 在 P4.3 显示当前课程内存计数。completion count 、重练 reset 与完成对话框业务留 P4.4。

## 测试矩阵

### 纯函数与 Progress

- Core→Study/CourseDrawer/ProgressDrawer 投影；word/sentence、nil 字段、phonetic 格式和 highlight ranges。
- available 过滤、default course、random 可确定、sequential first/next/wrap、排除 current 与只剩 current 回退。
- temporary progress 按 course/mode/entry 分区，record 上限 3，master 置 3，snapshot 互不污染，无持久化/网络调用。

### StudyStore 确定性 tests

- start 读 catalog/default course，原子选 current/next，prepare current+next，进 LISTEN 时记当前 1 次；load/prepare/play 失败 typed 投影且可重试。
- speaker 每次从 0 重播但不计次；manual NEXT/画布点击进新轮、计次、prepare 新 current+next；太简单置 3 后前进。
- matching finish + autoplay 进 waiting，controlled clock 500 ms 后恰好前进一次；AUTOPLAY off 取消，再开启不凭空跳过未播当前项。
- current failure 关 AUTOPLAY 但保留 retry/NEXT；preload failure 不中断 current。
- A/B/C 快速切换、NEXT×N、manual NEXT during waiting、autoplay off during waiting、切课/切模式 during play/wait、旧 course load、旧 token finish/fail、旧 clock wake 全静默。
- interruption/old-device/background 在 playing 时 paused，background/inactive 在 waiting 时也取消，active 不自动恢复。
- 单剩 current 从 1/3→2/3→3/3 可完成；全部达 3 发出 `courseExhausted` intent，本卡不弹完成框。
- 切 REPEAT 停 Audio/取消 LISTEN generation 且不触发麦克风、Realtime 或自动计次；切回 LISTEN 显式开新轮。

### iPhone integration/UI 与回归

- 从冷生成资源用真实 Repository 加载 default course 的 91 entries，用真实 AudioPlayer prepare 前两个 M4A，确认投影与 stop。
- 遍历 30 门 available bundled course，每门可 select/load/project current+next，不将整课音频解码进内存。
- `-wordloop-live-study` 真实 UI 验证默认课程内容、LISTEN 重播/NEXT/AUTOPLAY 标签、真实 30 门课抽屉与选课、进度计数，不依赖网络。
- 默认 Startup 及 START→live 路由有 UI test；高优先级 gallery/P3 fixture 路由原样。既有 P3 fixture、launch arguments、25 项 UI 覆盖和截图文件不删除；如需调整既有 START 用例，必须保持启动页视觉验收并新增进入真实学习页的断言。
- 回归 Core 9/9、Content 12/12、Audio 21/21、DesignSystem/Features/其他 Package、App integration、全部 UI、Web、baseline、lint 既有 4 errors/0 warnings。实施后在交接文档记录精确新计数。

## 静态边界检查

新增 `tests/ios-study-store-listen.test.mjs` 至少锁定：

- Study 按文件职责拆分，View 无 Repository/Audio/timer/progress 状态机，P3 fixture Store 无业务侧效。
- generation + request token + controlled clock 存在，live 500 ms 不是零延迟或分散 magic number。
- Features 通过 clients 消费 Content/Audio/Progress，App/View 不 import AVFoundation，Audio 不 import Features/Content。
- 无 URLSession/remote catalog/download/SwiftData/UserDefaults 进度/outbox/microphone/WebRTC/Realtime 业务、background audio/Remote Command。
- 无 iPad/macOS/Catalyst/Designed for Mac target、View 或交互。Package `.macOS(.v14)` 仅保留 host fake tests。
- 现有 P3 fixture routes/screenshots 存在，新 live route 不视为 fixture 的替代品。

## 禁止范围

- 不实现 P4.4 完成对话框的真实选课/重练/reset/completion count；只发出 `courseExhausted` intent。
- 不实现 P5 用户身份持久化、最近课程恢复、SwiftData、outbox、API 同步、服务端 reset。
- 不实现 P6 REPEAT 录音、Audio Session coordinator、Realtime/WebRTC、转写、评分、提示音或 waveform 动画。
- 不实现 P7 远程 catalog、课程包下载/更新/删除/安装、空间管理或远程音频流。
- 不实现 Now Playing、锁屏/控制中心、Remote Command、后台播放、AirPlay 专属 UI。
- 不删除/改写正式课程、P3 fixture 内容、Web UI/API/数据库/VPS、exporter schema 或 App Store metadata。
- 不新增桌面端、iPad 专用端、Catalyst 或 Designed for Mac 产品。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build
rm -rf ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent
find ios/Packages -type d -name .build -prune -exec rm -rf '{}' +

scripts/verify_ios.sh

swift test --package-path ios/Packages/WordLoopCore --scratch-path ios/.build/WordLoopCore
swift test --package-path ios/Packages/WordLoopContent --scratch-path ios/.build/WordLoopContent
swift test --package-path ios/Packages/WordLoopAudio --scratch-path ios/.build/WordLoopAudio
swift test --package-path ios/Packages/WordLoopProgress --scratch-path ios/.build/WordLoopProgress
swift test --package-path ios/Packages/WordLoopFeatures --scratch-path ios/.build/WordLoopFeatures

xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath ios/.derivedData CODE_SIGNING_ALLOWED=NO test

npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

退出时还必须确认：从冷状态可在飞行模式加载/选择 30 门内置课；App 同时最多准备 current+next；真实学习路由与全部 fixture 路由都可达；无 wall-clock/flaky store test；UI 仍为 iPhone-only；App 无 background audio mode；生成资源仍 ignored/untracked。

## 退出与交接

退出标准：真实离线 LISTEN 主链路已在原有 iPhone UI 上可达；正式课程、current/next、计次、重播、NEXT、画布点击、AUTOPLAY/500 ms、音频失败、系统暂停、切课/切模式和所有迟到事件均由确定性 tests 证明；无 P4.4/P5/P6/P7 或桌面产品越界。

开发完成后把本卡状态改为“开发完成，待独立复核”，刷新 `PROJECT_CONTEXT.md`、Plan 和 `docs/handoff/CHANGELOG.md`，提交 CP-11 实现并交给未参与实现的 reviewer 冷验证。只有 P4.3 独立复核 PASS 后才生成 P4.4 完成/重练任务卡。
