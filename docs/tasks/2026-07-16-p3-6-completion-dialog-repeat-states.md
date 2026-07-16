# P3.6 iPhone 完成对话框与 REPEAT 静态状态

状态：独立复核 PASS

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

产品基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md) 的 M-05 与 REPEAT 状态矩阵，以及 [`../ios-migration/baseline/screenshots/iphone-restart-dialog.png`](../ios-migration/baseline/screenshots/iphone-restart-dialog.png)、[`../ios-migration/baseline/screenshots/iphone-repeat.png`](../ios-migration/baseline/screenshots/iphone-repeat.png)

上游任务：[`2026-07-15-p3-5-progress-drawer.md`](2026-07-15-p3-5-progress-drawer.md)，已独立复核 PASS

## 目标

完成 P3 静态 Shell 的最后一个 CP-08：在当前 iPhone 主学习页上实现“选择已完成课程”和“自然完成课程”两类原生模态对话框、固定重置失败文案，并把现有单一 `LISTENING` REPEAT 卡扩展为 Web 冻结的 11 个可确定展示状态。此任务只实现展示模型、内存 fixture、presentation intent 和 SwiftUI 视觉；不播放音频、不请求麦克风、不建立 Realtime、不评分、不累计/重置进度、不自动前进，也不伪造服务端成功。

## 已锁定机器真值

### 完成与重练对话框

- 选择已完成课程：kicker `COURSE COMPLETE`；标题“这门课程已经完成”；正文“要重新开始练习吗？现有练习进度将被清零。”；按钮“取消”“重新开始”。
- 自然完成：kicker `COURSE COMPLETE`；标题“这门课程学完了”；正文“太棒了。你可以从头再练一遍，或者挑选下一门课程继续学习。”；按钮“选择课程”“再练一次”。
- 两类均可显示固定错误“暂时无法重置进度，请稍后重试。”；错误属于当前 dialog state，不是 toast，不自动消失。
- 对话框最大内容宽度 320 pt、外边距 24 pt、内边距 24–25 pt、圆角 16 pt。背景使用原生 material/暗色遮罩表达 Web 的 8 px blur，不复制 DOM filter。
- 主按钮的视觉与语义必须使用可达标角色，canonical accent 只作边框/装饰；小正文、错误、边界和按钮按六 palette 的最终合成层测试。不能延续未验证的 65% 小字或 22% 边界。
- 遮罩点击不关闭，避免误触丢失完成选择；只有两个明确按钮处理 presentation。取消只关闭；选择课程只关闭 dialog 并打开已经通过的课程抽屉；重新开始/再练一次只记录 `requestedRestart(courseID)` intent 并关闭，不清空任何 StudyShell/Progress/Course fixture，不显示“重置成功”。

### REPEAT 静态状态

| fixture raw value | 标题 | 提示 | 视觉 |
| --- | --- | --- | --- |
| `idle` | `STANDBY` | 跟读模式已准备好 | 静止低强度波形 |
| `connecting` | `CONNECTING` | 正在准备麦克风 | 活动波形 |
| `ready` | `READY` | 听完示范后开始跟读 | 静止低强度波形 |
| `playing` | `LISTENING` | 先听一遍标准发音 | 活动波形 |
| `speak` | `SPEAKING` | 请清晰地跟读 | 活动波形 |
| `speaking` | `SPEAKING` | 正在听你发音 | 可达标强调活动波形 |
| `scoring` | `CHECKING` | 正在分析这次发音 | 活动波形 |
| `passed` | `GREAT` | 这次发音通过了 | 绿色圆形勾号，不显示波形 |
| `paused` | `PAUSED` | 准备好后继续练习 | 静止低强度波形，主控制为 `RESUME` |
| `retry` | `TRY AGAIN` | 请再读一次 | 静止 failure 波形，可显示 `You said` transcript |
| `error` | `TRY AGAIN` | 请再读一次 | 静止 failure 波形，可显示 `You said` transcript |

- 默认 P3.3 repeat fixture 从旧内部名 `.listening` 迁移为 raw `playing`，可见结果仍是 `LISTENING / 先听一遍标准发音`，既有 P3.3 截图与行为不退化。
- 只有 `retry/error` 显示 transcript；固定 label 为 `You said`，fixture transcript 由 launch argument 提供，空字符串不渲染 transcript 区。
- 活动波形继续复用 `Waveform` 和 880 ms 动效；Reduce Motion 时完全静止。`speaking` 的强调不能使用低于 3:1 的 canonical accent 作为唯一非文本信息，状态同时由标题/提示朗读。
- `passed` 的勾号使用固定成功语义色并按实际背景达到至少 3:1；`retry/error` failure 视觉也必须达到至少 3:1，且标题/提示确保不依赖颜色。
- 卡片继续使用 P3.3 已通过的 iPhone 横向信息结构、44 pt 控件和页面边距；Dynamic Type accessibility 3 时改为纵向/自适应，标题、提示、transcript 不截断，底部 PAUSE/RESUME 与 NEXT 可滚动到并可点击。

## 实现边界

### 1. CompletionDialog 展示模型与 Store

在 `WordLoopFeatures` 新增独立 `CompletionDialog/` 文件组：

- `CompletionDialogKind`：`restartCompletedCourse` / `courseCompleted`，集中提供上述精确文案、按钮文案和 accessibility label。
- `CompletionDialogViewState`：kind、courseID、errorMessage、isPresented；fixture 只用 `modern-family-s01e01`，错误只接受固定文案。
- `CompletionDialogAction`：`presented(kind)`、`cancelled`、`selectedCourse`、`requestedRestart(courseID)`；不得增加 reset succeeded、progress cleared 或 network action。
- `CompletionDialogStore`：`@MainActor @Observable` 内存 Store；cancel/choose/restart 只改变 presentation 与 `lastAction`，保留原 StudyShell/Course/Progress state。
- launch args：`-wordloop-completion-dialog restart|complete`；可组合 `-wordloop-completion-error`。只有同时存在 `-wordloop-study-shell` 才进入学习页。

### 2. ConfirmDialog 与产品 View

- 扩展现有 Design System `ConfirmDialog`，支持可选 error message、dialog/cancel/confirm identifier，同时保持 gallery 现有 initializer 源兼容。
- 新增 `CompletionDialogView` 复用 `ConfirmDialog`，外层提供不可点击关闭的原生 modal backdrop。稳定 identifier：`completion-dialog.page`、`.title`、`.message`、`.error`、`.cancel`、`.confirm`。
- modal 优先级为 completion dialog > course drawer > progress drawer。fixture 同时请求 dialog/drawer 时，两抽屉保持关闭；dialog 关闭后不会自动恢复冲突 fixture。选择课程按钮是唯一例外：主动关闭 dialog 并打开 CourseDrawer。
- dialog 打开时主学习页与两抽屉从 accessibility/hit-test 路径隔离；关闭后背景 identity 重建并恢复。VoiceOver 顺序为 kicker → title → message → error（若有）→ secondary → primary。

### 3. REPEAT presentation model 与 MainStudyView

- 把 `StudyRepeatPresentationState` 扩展为表中的 11 个纯展示 case，集中提供 title、instruction、visual kind、showsTranscript、accessibility label；不新增 timer、turn ID、armed、Realtime item ID 或状态迁移方法。
- `StudyShellViewState.fixture(arguments:)` 支持 `-wordloop-repeat-state <raw>`、`-wordloop-repeat-transcript <text>`；非法值 fail closed 到 `playing`。非 repeat 模式忽略可见 repeat card；paused fixture 同步 `isRepeatPaused = true`，其他状态不伪造运行时动作。
- 重构 `MainStudyView.repeatCard` 以展示所有视觉类型、passed 勾号和 retry/error transcript。稳定 identifier：`study.repeat-card`、`study.repeat-state.<raw>`、`study.repeat-result`、`study.repeat-transcript`。
- 打开/关闭 dialog、查看任意 REPEAT fixture、点击取消/选择课程/重练 intent 都不得修改 mode、item、index、palette、visibility、mastery、autoplay、CourseDrawer collections 或 ProgressDrawer entries。

### 4. iPhone 适配与可访问性

- 只支持 iPhone 17+ target；不新增 iPad、macOS、Catalyst 或桌面布局/快捷键。
- 390 × 844 pt 标准字号下 dialog 全部内容和两按钮可见；REPEAT 卡、主文本与底部控制无水平越界。
- accessibility 3 下 dialog 可在 Safe Area 内纵向滚动或自适应，两个按钮可换行但命中区至少 44 pt；REPEAT 卡的 visual/text/transcript 不重叠。
- modal 具备 `.isModal`；动态状态由文本朗读，waveform/勾号为辅助视觉。Reduce Motion 下 waveform 不重复动画，dialog 不做大位移。

## Fixture 与测试矩阵

### Unit tests

- 两种 dialog 精确文案、按钮、固定错误、courseID；非法/空 fixture fail closed。
- cancel/select/restart action、lastAction 和 presentation；restart 只发 intent，三个既有 store 的快照不变。
- 11 个 REPEAT raw value、title/instruction/visual/showsTranscript 映射完整且唯一；非法 state 回到 playing，paused 与按钮一致。
- retry/error transcript 规则，其他 9 状态即使传 transcript 也不展示。
- 六 palette 的 dialog secondary/error/boundary/primary button、success/failure visual 按真实层顺序满足文本 4.5:1、非文本 3:1。
- Store/View 在无 Networking、Content、Audio、Progress、Realtime service 下可构造。

### App UI tests

- 既有 Startup/gallery/study/course/progress 全回归；两类 dialog fixture 的精确内容、按钮和背景隔离。
- cancel 关闭并恢复学习页；选择课程关闭 dialog 后打开课程抽屉；restart/retrain 只关闭且 S01E01、75/91、1/3 保持。
- error fixture 显示固定错误，遮罩点击不关闭；dialog + drawer 冲突只显示 dialog。
- 逐个 launch 11 个 raw state，至少对 idle/playing/speaking/passed/paused/retry/error 检查可见 title、提示、visual、transcript 与 PAUSE/RESUME；不存在自动状态变化。
- accessibility 3 + Reduce Motion 下 dialog 与最坏 retry transcript、buttons/NEXT 均可达、44 pt、无水平越界。

### Screenshot evidence

保存到 `docs/ios-migration/p3/completion-repeat/`：

- iPhone 17e 已完成课程 restart dialog；
- iPhone 17e 自然完成 dialog + error；
- iPhone 17e speaking 状态；
- iPhone 17 Pro passed 状态；
- iPhone 17e retry + transcript + accessibility 3 + Reduce Motion。

`visual-verification.md` 记录 simulator/OS、pt/px、SHA-256、fixture arguments、dialog 320/24 pt 边界、state 映射、实际合成对比、与 Web 的原生差异及 modal/Reduce Motion 证据。截图必须是真实 App，不含键盘、App Switcher、测试 runner 或调试浮层。

## 禁止范围

- 不解析/切换正式课程，不读取 `ios/Generated`、catalog、course、integrity 或正式音频。
- 不读取/写入 Progress Package、UserDefaults、SwiftData、Keychain、API 或 outbox；不真实 reset、累计、完成或同步。
- 不播放/预加载音频，不请求麦克风权限，不打开 Settings，不创建 WebRTC/Realtime session，不评分、不实现 turn/armed/item ID、不使用 timer 自动迁移状态。
- 不实现 P4 LISTEN、本地完成流程，P5 服务端重练，P6 REPEAT 状态机，P7 远程课程或 P8 发布配置。
- 不修改 Web UI、课程、音频、API、数据库、VPS、exporter 或 schema；不新增第三方 Swift Package。
- 不创建 iPad、macOS、Catalyst 产品 target 或桌面专属适配。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build
find ios/Packages -type d -name .build -prune -exec rm -rf '{}' +
scripts/verify_ios.sh
xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath ios/.derivedData CODE_SIGNING_ALLOWED=NO test
npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

退出标准：两类对话框、固定错误、明确按钮 intent、模态优先级、11 个 REPEAT 静态态、passed/retry transcript、Dynamic Type、VoiceOver、Reduce Motion 和 iPhone 小屏通过；P3.1–P3.5 回归保留；没有课程/进度/音频/麦克风/Realtime/网络/持久化副作用；冷构建、App tests 和 Web 结构测试不退化；lint 不超过既有 4 errors、0 warnings；没有桌面产品支持。

## 交接

先单独提交本任务卡，再实施 CP-08。开发完成后把状态改为“开发完成，待独立复核”，刷新根 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交实现并交给未参与实现的 reviewer。P3.6 PASS 后才根据实际静态 Shell/API 生成 P4.1 领域模型与 Repository 任务卡。
