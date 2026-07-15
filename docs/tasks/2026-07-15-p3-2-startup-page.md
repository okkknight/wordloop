# P3.2 iPhone 启动页静态 Shell

状态：首次独立复核 FAIL；对比度已修复，待重新复核

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

产品基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md) 的 M-01 与 [`../ios-migration/baseline/screenshots/iphone-startup.png`](../ios-migration/baseline/screenshots/iphone-startup.png)

上游任务：[`2026-07-15-p3-1-design-system.md`](2026-07-15-p3-1-design-system.md)，已独立复核 PASS

## 目标

用 SwiftUI 实现仅面向 iPhone 的启动页静态 Shell，逐项对齐当前 Web 的用户名输入、匿名进入、错误、`START / PREPARING… / SYNCING…` 状态、辅助文案、键盘和安全区表现。此任务只完成 CP-04 startup page visual shell，使用内存 fixture Store 驱动状态，不连接真实身份、持久化、课程、进度或 API。

## 已锁定机器真值

- 基线 viewport 为 390 × 844；全屏使用 rose palette：`background #f8d9df`、`ink #4b1934`、`accent #157d6a`。
- 页面只有居中的单线用户名输入、错误位置、胶囊 START 按钮与必要状态辅助文案；不增加桌面导航、Tab Bar、欢迎卡、Logo、课程商店或说明长文。
- 输入 placeholder 为 `USERNAME`，最多 32 字符，不自动大写、不启用拼写检查；留空合法，非空仅允许 `A–Z / a–z`。
- 提交时先 trim；合法非空用户名归一化为小写。P3.2 只把归一化结果作为 fixture output 暴露给测试，不写 UserDefaults/Keychain，不生成真实匿名 ID。
- 非英文输入显示固定错误 `用户名只能使用英文字母`；编辑内容后清除旧错误。
- 主按钮固定三态：`START`、`PREPARING…`、`SYNCING…`；后两态不可重复提交并带 busy 语义。
- 辅助状态固定为 `正在恢复上次课程` 或 `正在同步学习进度`。idle 默认不新增课程说明；因为主学习页/真实课程尚未进入 P3.3/P4，不用虚构业务信息。
- Web 对恢复、最近课程、远端进度和约 650 ms 降级进入的真实行为留到 P6；本任务不得用延时伪装成已接通同步。

## 实现边界

### 1. Startup feature API

在 `WordLoopFeatures` 内新增独立 startup feature 目录/文件，不继续扩大单个 `WordLoopFeatures.swift`：

- `StartupState`：`idle / preparing / syncing`，提供固定按钮标题、辅助文案和 busy 状态。
- `StartupSubmission`：只表达 `.anonymous` 或 `.named(String)`，named value 已 trim、校验并 lowercased。
- `StartupStore`：`@MainActor`、可观察的内存 fixture Store，持有 `username`、`state`、`validationMessage` 与最后一次合法 submission；输入变化、提交和 fixture 状态切换使用明确方法。
- `StartupView`：只接收 Store 和提交 closure/fixture 行为，不依赖 AppEnvironment、URLSession、Content、Progress、Audio、Realtime 或持久化实现。

验证规则必须写成可单测的纯函数或 Store 方法；不能把正则和状态判断只塞进 SwiftUI body。

### 2. 移动端 SwiftUI 页面

- 使用 `PosterBackground` 与 P3.1 的 rose `PosterPalette`，但启动页内容需要独立的、稳定的 accessibility identifiers。
- 表单视觉中心对齐 390 × 844 基线；输入空态为透明背景、accent 单线下边框、居中 Mono 文本；按钮为 ink 轮廓胶囊，播放三角使用 accent。
- 输入使用适合用户名的键盘/文本设置：不自动修正、不自动大写、关闭智能引号/破折号和拼写；Return 键可提交。
- 键盘出现时保持输入和按钮可见，使用系统键盘安全区/滚动避让；不得用固定屏幕高度或桌面断点。隐藏键盘后恢复视觉中心，不产生持久位移。
- 内容遵守 iPhone Safe Area 和 20–24 pt 水平边距；交互命中区域至少 44 × 44 pt；不添加 iPad/桌面分支。
- 进入动效复用 `WordLoopMotion.contentEnter`；Reduce Motion 下不做大位移。页面不得引入无限动画或纯装饰 loading spinner。

### 3. Fixture 路由

- 正常 App 启动改为显示 `StartupView`，不再默认展示 Design System gallery。
- gallery 保留为显式 UI-test/debug launch argument（例如 `-wordloop-design-system-gallery`），便于后续回归 P3.1；不得在产品 UI 中放入口。
- 为确定性截图/测试提供 launch arguments，至少覆盖 idle、invalid、preparing、syncing、accessibility text + Reduce Motion。fixture argument 只能改变本地展示状态，不发网络请求、不写持久化。
- `RootView` 仍只 import `WordLoopFeatures`；App 不越层 import DesignSystem 或业务 Package。

### 4. 可访问性

- 根页面、用户名输入、错误、主按钮、辅助状态使用稳定 identifier。
- 输入 accessibility label 清楚表达用户名可选；错误与输入关联，并在出现时使用可被读出的 live/announcement 语义。
- 按钮 label/value 与当前状态一致；busy 时 disabled，不能只靠透明度表达。
- Dynamic Type 下文字不裁切，按钮标题完整；错误可换行且不覆盖输入或按钮。至少验证 accessibility 3。
- 纯装饰圆环和播放三角不重复进入 accessibility tree；颜色不是错误/busy 状态的唯一线索。

## 测试与视觉证据

### Unit tests

在 `WordLoopFeaturesTests` 覆盖：

- 空白和纯空格提交得到 anonymous；
- ` Alice ` 得到 `.named("alice")`；
- 数字、空格夹在名字中、中文、重音字母、符号被拒绝，错误文案精确；
- 最多 32 字符边界与第 33 字符输入约束；
- 编辑后清错；busy 状态不重复提交；三态文案和辅助文案精确；
- StartupView/Store 可构造且不需要真实服务。

### App UI tests

- 默认启动进入 startup 根页面，placeholder、输入和 `START` 可访问；Design System gallery 不在默认树中。
- 空白提交与合法用户名提交可由确定性 fixture 观察；非法输入显示固定中文错误并可在编辑后清除。
- Return 和按钮均可提交；preparing/syncing fixture 的文案、disabled/busy 语义正确。
- 显示键盘后输入、错误和按钮仍在可见可交互区域。
- gallery launch argument 仍可打开 P3.1 页面，防止阶段迁移破坏基础组件验收。

### Screenshot evidence

保存到 `docs/ios-migration/p3/startup/`：

- 390 × 844 pt idle，与 Web 基线并排人工核对；
- 390 × 844 pt invalid/error；
- iPhone 17 Pro preparing 或 syncing；
- 390 × 844 pt accessibility 3 + Reduce Motion（有错误或状态文案，覆盖最坏排版）。

`visual-verification.md` 必须记录真实 simulator 名称/OS、pt 与 px 尺寸、每张 SHA-256、fixture argument、与 Web 基线的已知原生差异。截图不得包含 App Switcher、键盘调试浮层或 gallery。

## 禁止范围

- 不实现或模拟真实 localStorage/UserDefaults/Keychain 匿名 ID、最近课程恢复、服务端进度、outbox 或 650 ms 超时；这些属于 P6。
- 不解析课程包，不显示真实课程描述，不连接 P4 内容仓库。
- 不接 URLSession、数据库、音频、麦克风、Realtime、下载或权限。
- 不实现 P3.3 主学习页、抽屉、对话框或 REPEAT 卡片。
- 不修改 Web UI、`app/page.tsx`、课程、音频、API、数据库、VPS 或共享课程导出协议。
- 不添加第三方 Swift Package，不创建 iPad、macOS 或 Catalyst 产品 target。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build ios/Packages/*/.build
scripts/verify_ios.sh
xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath ios/.derivedData CODE_SIGNING_ALLOWED=NO test
npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

退出标准：默认 App 启动是 iPhone startup page；fixture Store 覆盖全部显示状态且无业务副作用；用户名规则、三态文案、键盘、Safe Area、Dynamic Type、VoiceOver 和 Reduce Motion 通过；截图证据完整；P3.1 gallery 仍可通过测试参数回归；Web 39 项不退化；lint 不超过既有 4 errors、0 新 warnings；无桌面产品、业务越界或网络依赖。

## 实施结果

- `WordLoopFeatures/Startup` 已按文件拆出 state、submission、纯 validator、`@MainActor @Observable` fixture Store 和 SwiftUI View，没有继续扩大原有 `WordLoopFeatures.swift`。
- 默认 App 路由已切为启动页；Design System gallery 只通过 `-wordloop-design-system-gallery` 暴露给调试/UI 回归，产品页面没有入口。App 仍只 import Features。
- 用户名支持留空匿名、trim、ASCII 英文字母校验、小写归一化和 32 字符输入约束；没有 UserDefaults、Keychain、网络、课程、进度、音频或 Realtime 副作用。
- `START / PREPARING… / SYNCING…`、两条中文辅助状态、busy 禁用、编辑清错、按钮与 Return 提交均由同一 Store 路径驱动。
- 页面使用 rose palette、Geist、原生 TextField/键盘、Safe Area、44 pt 命中区和 Reduce Motion 分支；accessibility 3 下错误与按钮无重叠或裁切。
- 视觉证据与 Web 差异说明见 [`../ios-migration/p3/startup/visual-verification.md`](../ios-migration/p3/startup/visual-verification.md)，包含 390 × 844 idle/invalid/accessibility 与 iPhone 17 Pro syncing 四张真机截图及 SHA-256。
- 从删除课程生成物、统一/Package cache 和 DerivedData 的状态执行 `scripts/verify_ios.sh` 通过：八个 Package tests 与 iPhone build 全部成功。修复前 Features 为 11 tests；补入真实颜色角色回归后为 13 tests。App integration 1 test、UI 8 tests 全部通过。
- `npm run baseline:ios` 通过，`npm test` 为 40/40；lint 精确保持既有 Web 4 errors、0 warnings；`git diff --check` 通过。

## 交接

先单独提交本任务卡，再实施 CP-04。开发完成后把状态改为“开发完成，待独立复核”，刷新根 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交实现；由未参与实现的 reviewer 独立复核。P3.2 PASS 后才根据真实 startup/Design System API 生成 P3.3 主学习页任务卡。

## 独立复核结果（2026-07-15）

结论：**FAIL**。

已通过的独立证据：

- 从删除 `content/dist`、`ios/Generated`、统一/Package SwiftPM cache 和 DerivedData 的状态执行 `scripts/verify_ios.sh`，课程重建、八个 Package tests 与 iPhone 17 Pro Simulator build 全部通过；单独重跑 Features 为 11/11。
- 独立 `xcodebuild test` 通过 App integration 1 项与 UI 8 项。默认启动为 Startup，gallery 只能通过 launch argument 打开；匿名/命名提交、trim/lowercase、Return `Go`、按钮提交、非法输入、编辑清错、busy 三态和键盘打开后的按钮操作均通过。
- 四张截图尺寸与文档 SHA-256 一致，都是实际 Startup 页面，不是 App Switcher、gallery、空白或键盘调试画面；390 × 844、iPhone 17 Pro 与 accessibility 3 均无文字重叠或横向裁切。
- Startup 源码未接持久化、网络、课程、进度、音频或 Realtime；App 仍只 import Features。Release build settings 为 iOS 17、`TARGETED_DEVICE_FAMILY = 1`，Catalyst 与 Designed for iPhone on Mac 均关闭。
- `npm run baseline:ios` 通过，`npm test` 为 40/40；lint 精确保持既有 Web 4 errors、0 warnings；没有 Web 或共享课程合同修改，`git diff --check` 通过。

阻塞问题：

- `StartupView.swift` 的空态 `USERNAME` placeholder 使用 rose accent 的 `0.56` opacity。把 `#157d6a` 按该 alpha 合成到 rose background `#f8d9df` 后，对比度只有约 **2.071:1**；这是 10 pt 的必要输入文字，低于普通文本至少 4.5:1，idle 截图也可直接看到它明显偏淡。
- 同一输入唯一可见边界使用 accent 的 `0.78` opacity，合成后约 **2.822:1**，低于非文本输入控件视觉边界 3:1。当前 Startup unit/UI/Node tests 均未锁定这两个实际 alpha 合成后的颜色组合，因此所有自动测试会在该问题存在时继续通过。

最小修复：不改变 canonical rose palette；为 placeholder 选用对 background 至少 4.5:1 的文字角色，为输入下划线使用至少 3:1 的边界角色（例如移除会降到阈值以下的透明度，或使用经过计算的语义角色），并增加按实际 alpha 合成计算的回归测试。修复后重拍受影响截图并从冷缓存重新执行本任务全部验收。P3.2 PASS 前不得生成或实现 P3.3。

## 首次复核问题修复

- canonical rose palette 未修改。新增 `StartupVisualRoles`，在 sRGB 中预合成最终 UI 颜色，避免测试 alpha 与 SwiftUI 实际接线脱节。
- placeholder 使用 ink 72% 对 background 的预合成色，实算约 **5.084:1**；输入下划线使用 accent 86% 的预合成色，实算约 **3.157:1**。
- `StartupView` 直接使用这两个最终角色色，不再调用被 reviewer 指出的 `accent.opacity(0.56/0.78)`。
- Features 增加两项测试，直接对 UI 使用的同一 `StartupVisualRole` 断言 4.5:1 与 3:1；Node 静态测试同时锁定 View 接线和禁止旧 opacity 回归。
- 四张受影响截图已全部刷新，尺寸不变，新 hash 记录在 startup visual verification。修复提交后必须重新执行冷验收与独立复核，PASS 前仍不进入 P3.3。
