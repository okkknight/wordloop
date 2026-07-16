# P4.2 iPhone 本地音频播放器与系统中断隔离

状态：开发完成，待独立复核

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：[`2026-07-16-p4-1-bundled-content-repository.md`](2026-07-16-p4-1-bundled-content-repository.md)，P0–P4.1 均已独立复核 PASS

## 目标

完成 CP-10：在空的 `WordLoopAudio` 骨架内实现只播放已校验本地 file URL 的 AVFoundation 播放器原语，具备 current/next 双槽预备、明确状态与事件、每次播放 request token、迟到完成/失败隔离，以及 iPhone Audio Session 中断、耳机拔出、后台和 media services reset 处理。完成后 P4.3 可以把 P4.1 `CourseEntry.audioURL` 映射进播放器，而不需要认识 AVFoundation 或系统通知。

本卡不接现有 P3 StudyShell/Store，不读取 Repository，不选课，不自动前进，不实现 AUTOPLAY/500 ms/进度，也不播放 REPEAT 录音提示。既有 UI、交互与截图必须原样回归。

## 已锁定现状与冲突消解

- `WordLoopAudio` 当前只有 module marker 与 1 项 smoke test；Package 只依赖 `WordLoopCore`。P4.2 只修改 Audio、它的 tests、必要的 App integration/static tests 与交接文档。
- P4.1 已保证 `CourseEntry.audioURL` 是 Bundle 内已校验的本地普通文件。Audio 不 import Content，不了解 Bundle/下载目录/课程 schema；P7 下载课未来也只能交付校验后的本地 URL。
- Web `playWord` 每轮新建 `HTMLAudioElement`、从 0 播放、先暂停旧 current，finish/error 单次 settle；next 只暖浏览器缓存，不预载整课。原生必须保留“每轮从 0”和 current+next 上限，不复用带旧播放位置的 mutable player state。
- Web 没有 request token；已排队的 LISTEN 500 ms timer 还可能在切课/切模式后迟到推进。这是历史实现缺口，不复制到 iOS。P4.2 token 只隔离音频回调；P4.3 还必须有 Listen session generation 去隔离业务 timer。
- 冻结验收矩阵要求音频失败关闭 AUTOPLAY，但 Web `playListenItem` 当前没有传 error handler。以冻结产品目标为 iOS 标准，P4.3 落失败后关闭 AUTOPLAY；P4.2 只发 typed failed event。
- Web 对 LISTEN 没有后台处理；iOS Audio Session、route 和 lifecycle 是原生平台责任。按安全策略暂停且不自动恢复，避免耳机拔出或回前台后意外外放。
- 继续只交付 iPhone。`.macOS(.v14)` 仅支持 host fake tests；不得增加 macOS/iPad/Catalyst 产品或桌面交互。

## 公共 API

保留 marker，并新增独立值类型与 actor。公开面固定为等价于：

```swift
public struct PlaybackRequestID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID
}

public enum AudioPlaybackPhase: Equatable, Sendable {
    case idle
    case prepared
    case playing
    case paused
    case stopped
    case finished
    case failed
}

public enum AudioPauseReason: Equatable, Sendable {
    case user
    case interruption
    case oldDeviceUnavailable
    case background
}

public enum AudioPlayerError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case invalidLocalURL
    case fileMissing
    case nonRegularFile
    case couldNotPrepare
    case sessionActivationFailed
    case playbackStartFailed
    case decodeFailed
    case mediaServicesReset
    case invalidState
}

public struct AudioPlaybackSnapshot: Equatable, Sendable {
    public let phase: AudioPlaybackPhase
    public let currentURL: URL?
    public let nextURL: URL?
    public let requestID: PlaybackRequestID?
    public let pauseReason: AudioPauseReason?
    public let error: AudioPlayerError?
}

public enum AudioPlayerEvent: Equatable, Sendable {
    case stateChanged(AudioPlaybackSnapshot)
    case preloadFailed(URL, AudioPlayerError)
}

public actor AudioPlayer {
    public static func live() throws -> AudioPlayer
    public func prepare(current: URL, next: URL?) async throws
    @discardableResult public func play() async throws -> PlaybackRequestID
    public func pause() async
    public func stop() async
    public func snapshot() async -> AudioPlaybackSnapshot
    public func events() async -> AsyncStream<AudioPlayerEvent>
}
```

- 可以在实现中对 initializer、engine/session/event source protocols 使用 internal 注入；不能扩大 public API 到 AVFoundation 类型。
- Audio 不接受 `CourseID`、`EntryID`、practice order 或业务 session。event 中的 request ID + URL 足以让 P4.3 做 request↔course/entry/generation 映射。
- error 不携带底层 NSError 文案或绝对用户路径；日志若需要底层错误，只能在内部 debug 路径，不进入 public snapshot/event。
- `events()` 是多订阅广播；订阅取消后移除 continuation，不能因 Store 重建泄漏。snapshot 是恢复订阅前当前真值，不要求 UI 从事件重放状态。

## 状态与命令语义

### prepare

- 只接受 `file:` URL；拒绝 HTTP(S)、其他 scheme、缺失、symlink 和非普通文件。对 URL 做标准化/根路径安全不属于 Audio，Content/installer 负责来源边界。
- `prepare` 不激活 Audio Session、不产生声音。current 必须成功创建 engine 并 `prepareToPlay()`；失败则清旧 slots、失效 active token、进入 `.failed` 并抛 typed error。
- next 是优化，不应阻塞可播放 current。next 失败时 current 仍为 `.prepared`、next slot 为 nil，并发一次 `.preloadFailed`。
- 任意时刻最多持有两个 engine：current + next。new next 替换时释放旧 next；next 为 nil 时立即释放 preload。
- 若新 current URL 等于旧 next URL，晋升已 prepared next engine，归零播放位置，再只创建新的 following next；证明 preload 真正被复用。
- 若重新 prepare 与当前相同 URL，它仍是新学习轮次：旧 active token 失效，current 从 0；不得继承 paused/finished 的旧位置。
- prepare/替换/晋升不发 finish，不自动 play，不修改 UI/进度。

### play / pause / stop / finish / fail

- `play()` 只允许 `.prepared/.paused/.finished`。每次调用都生成新的 `PlaybackRequestID`；paused resume 可保留位置，finished replay 必须先归零。
- play 先配置并激活 session，再调用 engine。session activation 或 engine start 失败进入 `.failed`，不遗留 active token。
- 自然结束只对当前 engine + 当前 token 生效，至多一次进入 `.finished`；player 自身不晋升 next、不等待 500 ms、不调用 NEXT。
- decode/error callback 只对当前 engine + 当前 token 生效，至多一次进入 `.failed`。
- `pause(.user)` 保留 current/next 与当前位置，失效 token、进入 `.paused`、deactivate session；迟到 finish/fail 静默。公开 `pause()` 使用 `.user`，系统 pause reason 由内部事件路径设置。
- `stop()` 失效 token、停止并归零/释放 current 与 next、deactivate session，snapshot 为 `.stopped` 且 URL/token/reason/error 全 nil；下次必须重新 prepare。
- 对 A→B→C 快速 prepare/play，A/B 的 late ready/end/fail、系统通知后排队的 delegate callback 都不能改变 C，也不能向订阅者发业务可见事件。

## AVFoundation 与 Swift 6 隔离

- live adapter 使用 `AVAudioPlayer(contentsOf:)` + `prepareToPlay()`；本地短 M4A 不需要 AVPlayer streaming/KVO，也不引入第三方库。
- `AudioPlayer` 为 actor；`AVAudioPlayer`、slot、session 和 observer token 不跨 actor。`AVAudioPlayerDelegate` 使用小型 `@MainActor` bridge，只回投 Sendable engine identity/request token，不把非 Sendable player 传入 actor。
- 内部至少有 `AudioEngine`、`AudioEngineFactory`、`AudioSessionControlling`、`AudioSystemEventSource` seams。host tests 全部使用 fake；不能依赖本机扬声器、真实通知或 wall-clock sleep。
- callback bridge 必须捕获产生 callback 时的 engine identity + request token。仅在 actor 内同时匹配 current engine 和 active token后 settle。
- 若 Swift 6 对某个 AVFoundation 类型的隔离注解与上述桥接冲突，以“AV 对象不跨域、回投纯 Sendable identity、测试可证明顺序”为不变约束调整内部形态，不能用全局 `@unchecked Sendable` 包住播放器蒙混通过。

## Audio Session、路由与生命周期

- live iPhone session 首次 play 前配置 `.playback` + `.spokenAudio`，不启用 mix/duck/background/remote-control options；prepare 阶段不打断其他 App 音频。
- interruption `.began`：若正在 playing，pause，reason `.interruption`，失效 token并 deactivate。`.ended` 即使带 shouldResume 也不自动播放；用户/P4.3 显式 play 才恢复。
- route `.oldDeviceUnavailable`：若正在 playing，pause，reason `.oldDeviceUnavailable`，防止耳机拔出后外放。new device/override/category change 等其他 reason 不暂停、不当作 finish，也不自动播放。
- App 进入 background：playing 时 pause，reason `.background`，失效 token、deactivate。inactive 不因系统短暂覆盖误停；回 active 只保持可操作 snapshot，不自动恢复。
- media services reset：释放 orphaned engines、清 slots/token、进入 `.failed(.mediaServicesReset)`；只能显式 re-prepare。
- 系统 notification 可能不在同一线程；统一通过 event source 正规化后回投 actor。
- 锁屏/控制中心、Now Playing、Remote Command、后台音频 entitlement 均不是首发范围。App `Info.plist`/entitlements 不新增 audio background mode。
- P6 REPEAT 需要 `.playAndRecord` 时必须演进为共享 session coordinator；本卡不请求麦克风、不提前让 Audio 和 Realtime 各自竞争 singleton。

Apple 平台依据：

- [AVAudioPlayerDelegate](https://developer.apple.com/documentation/avfaudio/avaudioplayerdelegate) 提供自然结束与解码失败回调。
- [Responding to Interruptions](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html) 要求 interruption 后保存/恢复状态并在需要时重新激活；本产品明确选择不自动恢复。
- [Responding to Route Changes](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html) 明确媒体播放在 old device unavailable 时应暂停，而 override 不应误停。
- [routeChangeNotification](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification) 可能从次级线程投递，因此不能直接修改 actor 状态。

## 测试矩阵

### Audio unit tests

使用 fake engine/session/system source，至少覆盖：

- 初始 idle；current+next prepare；next nil；替换 next；next 晋升复用且归零；same-current 新轮次归零；engine 存活上限 2。
- current prepare fail；next prepare fail 不阻断 current；remote/missing/symlink/FIFO 拒绝。
- prepared→playing→finished；decode/start/session activation failure；finish/fail exactly once。
- user pause 不 finish、位置保留、resume 新 token；finished replay 新 token且从 0；stop 释放双槽并进入无 URL 的 stopped。
- A/B/C 快速替换后 A/B late finish/fail 全静默；pause/stop/prepare 后旧 callback 静默。
- interruption、old-device route、background 各自 pause + 正确 reason + no auto resume；其他 route/inactive/active 不误播、不误停。
- media reset fail closed并释放双槽。
- 多订阅者得到相同顺序，取消订阅清理 continuation；snapshot 可单独读取最终真值。
- session 调用顺序为 configure→activate→play，pause/finish/fail/stop 后 deactivate；prepare 不 activate。

### iPhone App integration

- `AppIntegrationTests` 通过 P4.1 `BundledCourseSource.live()` 取默认课程前两条 file URL，创建 live `AudioPlayer`，prepare current+next，断言 `.prepared` 与两个 URL 后立即 stop，断言 `.stopped` 且双槽释放。
- integration 不等待自然播放、不依赖扬声器或时长，避免 Simulator flaky；真实播放结束与错误由 fake unit tests确定验证。
- 既有 App integration 2 项与 UI 25 项原样回归；P3 App/Features 不实例化 AudioPlayer，不新增音频 UI fixture/截图。

### Web/static regression

新增 `tests/ios-audio-player.test.mjs`，至少锁定：

- Audio production 只依赖 Core/AVFoundation/Foundation；不 import Content/Features/SwiftUI/Progress/Realtime/Networking。
- 存在 actor、token、current/next、engine/session/event seams 与 route/interruption/background/reset 处理。
- Audio 中没有 AUTOPLAY、500 ms/NEXT/course selection/progress/microphone/WebRTC/URLSession/timer/remote URL streaming。
- App/Features 尚未构造 `AudioPlayer.live()` 或接入 Repository；P3 fixture、launch arguments 和截图文件无改动。
- project 仍为 iPhone-only、无 background audio mode、无新远端 Swift dependency。

## 禁止范围

- 不创建 StudyStore/ListenSessionController，不选择 current/next 业务 entry，不实现 random/sequential。
- 不实现重播按钮、手动 NEXT、画布点击、AUTOPLAY、500 ms waiting、失败关闭 autoplay、完成弹窗、学习计数或 palette 变化；全部属于 P4.3。
- 不接 CourseDrawer/ProgressDrawer/CompletionDialog，不修改 P3 Store、View、fixture、launch argument 或截图。
- 不读 catalog/Repository，不 import WordLoopContent；不写 Progress/UserDefaults/SwiftData/Keychain/outbox。
- 不播放远端 URL、不下载课程、不访问 URLSession/网络。
- 不请求麦克风，不做 REPEAT、Realtime/WebRTC、评分、waveform、提示/成功失败音。
- 不做 Now Playing、锁屏/控制中心、remote command、后台播放、AirPlay 专属 UI。
- 不创建 iPad、macOS、Catalyst 产品 target/View/布局；不增加第三方 Package。
- 不修改 Web UI、课程源/schema/exporter、API、数据库、VPS 或 App Store metadata。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build
rm -rf ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent
find ios/Packages -type d -name .build -prune -exec rm -rf '{}' +

scripts/verify_ios.sh

swift test --package-path ios/Packages/WordLoopAudio --scratch-path ios/.build/WordLoopAudio

xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath ios/.derivedData CODE_SIGNING_ALLOWED=NO test

npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

退出验收还必须确认：Audio fake 状态矩阵无 wall-clock/flaky test；Xcode integration 能用真实 Bundle M4A prepare/stop；App UI 25/25 原样；Web test 预期增至 50；lint 仍精确为既有 4 errors、0 warnings；Release build settings 为 iOS 17/Swift 6/device family 1/Catalyst 与 Designed for Mac 关闭；App 无 audio background mode；生成内容仍 ignored/untracked。

## 退出与交接

退出标准：iPhone live player 能 prepare 已验证的本地 current+next；双槽、token、状态、单次 settle、pause/resume/replay/stop、迟到 callback、interruption、耳机拔出、background、media reset 都由确定性 tests 证明；不自动恢复、不自动前进、不接 UI/业务/网络/录音/桌面产品。

开发完成后把状态改为“开发完成，待独立复核”，刷新 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交 CP-10 实现并交给未参与实现的 reviewer 冷验证。只有 P4.2 独立复核 PASS 后，才根据真实 AudioPlayer API 与 P4.1 Repository API 生成 P4.3 StudyStore/LISTEN 任务卡。
