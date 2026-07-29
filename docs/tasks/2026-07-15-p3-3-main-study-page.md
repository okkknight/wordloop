# P3.3 iPhone 主学习页静态 Shell

状态：修复后独立复核 PASS

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

产品基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md) 的 M-02、LISTEN/REPEAT 状态矩阵，以及 [`../ios-migration/baseline/screenshots/iphone-repeat.png`](../ios-migration/baseline/screenshots/iphone-repeat.png)、[`../ios-migration/baseline/screenshots/iphone-listen.png`](../ios-migration/baseline/screenshots/iphone-listen.png)

上游任务：[`2026-07-15-p3-2-startup-page.md`](2026-07-15-p3-2-startup-page.md)，已独立复核 PASS

## 目标

用 SwiftUI 实现只面向 iPhone 的主学习页静态 Shell，对齐顶部导航、LISTEN/REPEAT 切换、课程上下文、超大英文、中文/音标、重点表达、文字可见性、播放/重播 affordance、左下熟练度和右下模式控制。此任务只完成 CP-05 main study page visual shell，所有内容和状态来自内存 fixture，不解析课程包、不播放音频、不保存进度、不建立 Realtime 会话。

## 已锁定机器真值

- 标准移动基线为 390 × 844；主页面自身在标准字号下不滚动，使用 Safe Area 与 20–24 pt 视觉边距。
- 主验收 fixture 使用 sun palette：`background #f5d547`、`ink #282044`、`accent #e85b44`；右上保留大号 accent 圆环。
- 句子固定为：课程 `MODERN FAMILY · S01E01`，序号 `75/91`，英文 `Uh, my dad still isn't completely comfortable with this.`，中文 `我爸对这事还是不太习惯`，重点表达使用点状下划线，不用整段换色。
- 顶栏固定为左 `COURSE`、中 `LISTEN / REPEAT`、右 `PROGRESS`。iPhone 不显示 `PROGRESS · 已完成数/总数` 长文案。
- 句子显示中文；单词 fixture 显示 `/phonetic/` 和中文释义。英文是页面第一视觉层级，中文/音标使用 accent 角色。
- 文字可见性：句子 `full → focus → hidden → full`，单词 `full → hidden → full`；hidden 使用圆点占位但不让隐藏正文继续被 VoiceOver 朗读。
- 左下固定 `{count} / 3` 和“太简单 ✓”；右下 REPEAT 为 `PAUSE / RESUME + NEXT`，LISTEN 为 `AUTOPLAY / AUTOPLAY ON + NEXT`。
- P3.3 的 REPEAT 区只展示一个代表性 `LISTENING / 先听一遍标准发音` 静态态，用于主页面层级和占位；P3.6 才实现/验收全部 REPEAT 卡片状态、transcript、success/failure/paused 和对话框。
- `iphone-listen.png` 中成块黑色区域不对应任何 DOM/CSS 元素，是 420 ms palette/background 过渡期间的历史截图合成伪影；原生页面不得复刻黑块。布局和文案仍以源码、repeat 截图及 listen 可见区域共同为准。

## 实现边界

### 1. Study Shell 展示模型与 Store

在 `WordLoopFeatures` 新增独立 `StudyShell/` 文件组，不把页面继续写入 `WordLoopFeatures.swift` 或 Startup 文件：

- `StudyShellMode`：`listen / repeat`，只表达页面显示模式。
- `StudyTextVisibility`：`full / focus / hidden`，提供句子/单词的确定性 next 规则和无障碍 value。
- `StudyShellItem`：展示所需的稳定 id、kind、英文、音标/中文、highlight ranges 或可验证的 highlight tokens；不得依赖 P4 尚未实现的 `CourseEntry`。
- `StudyShellViewState`：palette id、课程 label/title、index/count、item、mode、visibility、mastery count、autoplay、repeat presentation state 和各控制 disabled 值。
- `StudyShellStore`：`@MainActor @Observable` 内存 fixture Store，只处理 mode/visibility/autoplay/pause 的本地展示切换并记录最后触发的 action；不得记录真实学习次数或模拟异步业务。

所有状态转换必须是可单测的纯规则或 Store 方法；SwiftUI body 不保存隐式业务状态。

### 2. iPhone SwiftUI 页面

- `MainStudyView` 组合 P3.1 的 `PosterBackground`、`ModeSwitch`、`Waveform` 和通用 tokens；页面专属控件放在 StudyShell，不把课程/学习文案塞回 DesignSystem。
- 使用三行结构：Safe Area 顶栏、可伸缩内容舞台、底部控制。标准字号不出现页面滚动、横向裁切或被 Home Indicator 遮挡。
- 英文根据可用宽度和 fixture 类型受控缩放/换行：至少覆盖短词、12+ 字符长词、基线长句和含重点表达的句子；不得按某个固定句子写死字号。
- highlight 必须来自展示模型的可靠 range/token，支持同词多次出现和标点，不能用全局字符串 replace。focus 只保留重点表达，其余以可辨认占位呈现。
- 播放与可见性组合控件保持当前小胶囊视觉，但每个实际命中区域至少 44 × 44 pt；使用 SF Symbols/SwiftUI shape，不复制 Web CSS 伪元素。
- 左下 mastery 与右下 controls 均位于 Safe Area 内。按钮只触发 fixture action，不播放、不前进真实课程、不写进度。
- palette/内容进入动效复用 `WordLoopMotion`；Reduce Motion 下移除大位移和循环波形。颜色、文案和控制状态在无动画时仍完整。

### 3. App fixture 路由

- 默认 App 仍显示 P3.2 Startup；P6 接入真实恢复/身份前，点击 START 不得伪造跳转到已恢复的学习业务。
- 新增显式 `-wordloop-study-shell` launch argument 显示主学习页，配合参数覆盖 listen/repeat、sentence/word、full/focus/hidden、palette、mastery、autoplay 和 accessibility fixture。
- `-wordloop-design-system-gallery` 与 Startup fixtures 继续可用；三者路由优先级固定并由静态/UI tests 锁定。
- `RootView` 仍只 import `WordLoopFeatures`；App 不越层 import DesignSystem、Content、Audio、Progress、Realtime 或 Networking。

### 4. 可访问性与移动端适配

- 根页面、COURSE、mode switch、PROGRESS、英文、中文/音标、播放、可见性、mastery、太简单、REPEAT card 和右下控制均有稳定 identifier。
- COURSE/PROGRESS 是按钮而非装饰文字；mode 暴露 selected 状态；visibility 的 label/value 能说明下一动作和当前可见性；busy/disabled 不只靠颜色。
- 英文/中文作为合理的阅读元素；hidden 时正文从 accessibility tree 隐藏，并提供“学习内容已隐藏”的替代说明。
- 标准控件和正文满足实际 palette 对比度；canonical accent 不达小文字门槛时使用已测试的语义角色，不直接降低 opacity。新增测试必须覆盖页面实际前景/背景组合。
- Dynamic Type 到 accessibility 3 时优先换行、缩放和重排底部控件；如单屏无法容纳，可只在辅助字号启用纵向可达滚动，但标准 390 × 844 仍不得滚动。
- VoiceOver 顺序为顶栏 → 课程上下文/正文 → 学习动作 → REPEAT 展示 → 底部控制；装饰圆环、波形柱和图标不重复朗读。

## Fixture 与测试矩阵

### Unit tests

- mode、sentence/word visibility cycle、autoplay/pause fixture 切换和 action 记录；
- highlight range/token 对标点、重复词和非法范围 fail closed；
- mastery 0...3 边界与按钮 disabled 展示规则；
- 基线句子、短词、超长词、隐藏/焦点展示模型；
- sun palette 页面实际小文字/控制边界颜色组合满足 4.5:1/3:1；
- MainStudyView/Store 可在无业务 service 下构造。

### App UI tests

- 默认启动仍是 Startup；`-wordloop-study-shell` 才显示 study 根页面。
- 顶栏三组控件、基线句子、中文、75/91、左/右底部控制可访问；标准 390 pt 页面不横向滚动。
- LISTEN/REPEAT fixture 的选中态和底部控制文案精确；本地点击只改变 fixture 显示/记录 action。
- full/focus/hidden 可见性顺序与 accessibility tree 正确；sentence 与 word 规则不同。
- 键盘不属于该页面；所有边缘按钮在 iPhone Safe Area 内可点击。
- accessibility 3 + Reduce Motion fixture 可达，无文本/控件裁切；gallery 与 Startup 回归仍通过。

### Screenshot evidence

保存到 `docs/ios-migration/p3/study-shell/`：

- iPhone 17e 390 × 844 pt repeat 基线；
- iPhone 17e 390 × 844 pt listen 基线；
- iPhone 17 Pro 超长词或 focus/hidden 状态；
- iPhone 17e accessibility 3 + Reduce Motion 的长句最坏排版。

`visual-verification.md` 记录 simulator/OS、pt/px、SHA-256、fixture arguments、与 Web 两张基线的差异，以及黑色截图伪影不进入实现的证据。所有截图必须是真实 study shell，不含 Startup、gallery、App Switcher 或调试浮层。

## 禁止范围

- 不解析 `ios/Generated`、catalog/course manifest，不创建 P4 正式 Course/Entry/StudyMode 领域模型。
- 不播放或预加载音频，不接 AVFoundation；不实现真实 NEXT/AUTOPLAY/太简单/学习次数。
- 不读写 UserDefaults/SwiftData/Keychain，不请求或同步进度，不连接 API/outbox。
- 不请求麦克风、不接 WebRTC/Realtime，不实现评分、定时器、后台暂停或完整 REPEAT 状态机。
- 不实现课程抽屉、进度抽屉、完成/重练对话框；P3.4–P3.6 分别处理。
- 不修改 Web UI、`app/page.tsx`、课程、音频、API、数据库、VPS 或课程导出协议。
- 不增加第三方 Swift Package，不创建 iPad、macOS 或 Catalyst 产品 target。

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

退出标准：fixture 覆盖主学习页两种模式、句子/单词和文字可见性；390 × 844 标准态不滚动、不裁切，辅助字号可达；按钮/选中/隐藏语义、44 pt 命中、对比度、VoiceOver、Reduce Motion 通过；P3.1/P3.2 回归保留；无音频、进度、课程解析、Realtime 或持久化副作用；冷构建、App tests 和 Web 40 项不退化；lint 不超过既有 4 errors、0 新 warnings；没有桌面产品支持。

## 交接

先单独提交本任务卡，再实施 CP-05。开发完成后把状态改为“开发完成，待独立复核”，刷新根 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交实现并交给未参与实现的 reviewer。P3.3 PASS 后才根据真实页面 API 生成 P3.4 课程抽屉任务卡。

## 独立复核结果（2026-07-15）

结论：**FAIL**。

已通过的独立证据：

- 从删除 `content/dist`、`ios/Generated`、统一/Package SwiftPM cache 和 DerivedData 的状态执行 `scripts/verify_ios.sh`，课程重建、八个 Package tests 与 iPhone 17 Pro Simulator build 全部通过；Features 独立重跑为 26/26。
- 独立 `xcodebuild test` 通过 App integration 1/1 与 UI 12/12。默认启动仍是 Startup；显式 study fixture、gallery 冲突优先级、LISTEN/REPEAT、sentence/word visibility、底部控制和 accessibility 纵向可达均通过现有自动测试。
- highlight Character range 对重复词、标点和非法范围 fail closed；fixture Store 只切换展示状态和记录 action，没有模拟课程前进或业务进度。StudyShell 未接课程解析、音频、进度、持久化、网络、麦克风或 Realtime；App 仍只 import Features。
- 四张 PNG 的尺寸与 SHA-256 和 `visual-verification.md` 一致，均为真实 study shell。标准 iPhone 17e repeat/listen 和 iPhone 17 Pro hidden 页面没有横向裁切或系统区遮挡；批量原图查看器一度出现的黑块经直接像素检查确认不是 PNG 内容。
- Release 设置实测为 iOS 17、Swift 6、`TARGETED_DEVICE_FAMILY = 1`、`SUPPORTS_MACCATALYST = NO`、`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`。`npm run baseline:ios` 通过，`npm test` 为 41/41；lint 精确保持既有 Web 4 errors、0 warnings；`git diff --check` 通过。

阻塞问题：

- `ModeSwitch` 的未选中文字使用 `ink.opacity(0.72)`，整个胶囊只铺 `ink.opacity(0.1)`；Study 页面又把该控件放在 `PosterBackground` 的 `accent.opacity(0.58)` 圆环上。按截图中的真实层叠顺序，以 sun `background #f5d547 / ink #282044 / accent #e85b44` 在 sRGB 中合成，未选中文字与胶囊背景只有 **3.389973:1**，低于普通小文字 4.5:1。纯 background 区域约 4.615573:1，但不能代表横跨圆环的实际页面。现有测试只断言不透明 `ink/background`，没有覆盖 View 使用的 opacity 与非均匀底层；listen 截图中的 `REPEAT` 已直接显示该低对比组合。
- accessibility 3 截图中，播放与 visibility 按钮的 SF Symbols 随 Dynamic Type 放大，但 `MainStudyView` 只给 `Image` 固定 44 × 44 pt frame，没有固定 symbol 字号或让图形在控件内缩放。结果 speaker 与 eye 图标越出各自圆形边界并明显互相重叠，不满足“accessibility 3 无文本/控件裁切”和控件视觉边界要求。现有 UI test 只验证页面可滚到 `NEXT`，没有检查这两个学习动作的几何关系。

最小修复：让 mode switch 在圆环覆盖与纯背景两种真实底层上都使用至少 4.5:1 的最终文字/背景角色，并新增按 UI 实际 alpha 层叠计算的回归；为两个学习动作固定 Dynamic Type 安全的 symbol 尺寸/缩放与间距，确保图形留在各自至少 44 pt 的命中区域内。修复后刷新受影响的 listen 与 accessibility 3 截图，并从冷缓存重跑全部验收。P3.3 PASS 前不得生成或实施 P3.4。

## 首次复核问题修复（2026-07-15）

- `posterAccent / modeTrack / modeUnselectedText` opacity 已提升为 Design System 共享 token；`WordLoopSRGB.composited` 用与 SwiftUI 相同的 sRGB 层叠顺序计算最终颜色。未选中文字改为不透明 ink，纯背景区域实算约 8.746:1，accent 圆环区域约 5.301:1；单元测试直接引用页面相同 token 并断言两种真实底层均至少 4.5:1。
- speaker 与 visibility SF Symbols 固定为 18 pt semibold，不再随 accessibility Dynamic Type 膨胀；各自继续使用 44 × 44 pt frame。UI test 在 accessibility 3 下断言两个按钮可点击、命中框至少 44 pt 且不相交。
- 四张视觉证据均已用刷新 App 重拍；accessibility 3 中两个图形完整留在各自圆形内且有明确间隔，Listen/Repeat 未选中文字对比可辨。hash 和差异记录已更新。
- 从删除课程生成物、统一/Package SwiftPM cache 与 DerivedData 的状态完成修复后验收：八个 Package tests、iPhone build、DesignSystem 12/12、Features 26/26、App integration 1/1、UI 12/12、Web 41/41 全部通过；lint 精确保持既有 4 errors、0 warnings。仍需未参与修复的 reviewer 重新结论；P3.3 PASS 前不得进入 P3.4。

## 修复后独立复核结果（2026-07-15）

结论：**PASS**。

- reviewer 确认 `PosterBackground`、`ModeSwitch` 与 DesignSystem 回归测试直接引用同一组 `WordLoopLayerOpacity.posterAccent / modeTrack / modeUnselectedText` token，值分别为 `0.58 / 0.10 / 1.0`。按 UI 相同 sRGB 层叠顺序独立复算，sun 纯背景区域为 **8.746483:1**，accent 圆环区域为 **5.300792:1**，均超过小文字 4.5:1；canonical palette 未改变。
- `MainStudyView` 的 speaker 与 visibility SF Symbols 都固定为 18 pt semibold，外层各使用独立 44 × 44 pt frame。accessibility 3 截图中图形完整留在各自圆形内且有明确间隔；相关 UI test 实际验证两个按钮可点击、play 命中框至少 44 pt 且 `play.maxX <= visibility.minX`。
- 四张刷新截图的尺寸和 SHA-256 与 `visual-verification.md` 一致：iPhone 17e repeat/listen/accessibility 3 为 `1170 × 2532 px`，hash 分别为 `0debaccf4a8e141e3932e068362d191fdf33256783c131570d7d12ee092fd0e3`、`841b2e5e13c7c03596894f9c8bd48c00c1f3b8a53665c9e0f4234910d1e7bf53`、`f9323971844cfab7a563b17c05e4d0c159f48cd24be2d69203ea28ffb537ea73`；iPhone 17 Pro hidden 为 `1206 × 2622 px` / `4fd9f33112db8a1e5b4d3d6ac1124a4be224fbdd9cf3a0b181bef3561e4f129b`。人工检查确认均为真实 study shell，未选中文字清晰，图标无越界重叠，也没有 Startup、gallery、App Switcher 或调试浮层。
- 独立重跑 DesignSystem 12/12、Features 26/26、StudyShell 相关 UI 4/4 与 App integration 1/1；修复提交记录的完整冷验收为八个 Package、iPhone build、App UI 12/12，记录与当前源码及测试计数一致。
- `npm run baseline:ios` 与 `npm test` 通过，Web 为 41/41；lint 精确保持既有 4 errors、0 warnings；`git diff --check` 通过，工作区只有 ignored 生成物。修复没有引入课程解析、音频、进度、持久化、网络或 Realtime，也没有扩展桌面/iPad 产品。

P3.3 已满足退出标准。下一步可以根据当前真实页面 API 生成 P3.4 课程抽屉任务卡；本次复核未生成任务卡，也未实施 P3.4。
