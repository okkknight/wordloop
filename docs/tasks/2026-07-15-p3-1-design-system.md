# P3.1 iPhone Design System 基础层

状态：开发完成，待独立复核

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

视觉基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md)

上游工程：[`2026-07-15-p2-native-project-skeleton.md`](2026-07-15-p2-native-project-skeleton.md)

## 目标

在 `WordLoopDesignSystem` 内建立后续所有原生页面唯一使用的视觉 tokens、字体、基础组件、动效和触觉边界，并用不连接业务的 fixture gallery 在真实 iPhone Simulator 上验收。此任务只完成 CP-03 Design System；不实现启动页、学习页、抽屉、音频、进度、Realtime 或下载。

## 已锁定事实

- 产品只支持 iPhone；不新增 iPad、macOS、Catalyst、watchOS 或 visionOS 产品 target。
- iOS 17、Swift 6、SwiftUI；App 仍只通过 `WordLoopFeatures` 访问模块图，不从 App 越层 import DesignSystem。
- Web 机器真值是六组 `background / ink / accent` 色板、20–24 pt iPhone 安全视觉边距、44 × 44 pt 最小命中区域，以及 420/520/260/240/880 ms 动效节奏。
- 当前 Web 使用 Geist Sans 与 Geist Mono。官方 `vercel/geist-font` 的 Font Software 使用 SIL Open Font License 1.1，允许随软件嵌入，但分发物必须保留 copyright 与 license。
- 字体版本固定到官方 tag `1.8.0` / commit `91158e012bdc4abd59fa066d0eae9fc11c2c9f24`；只纳入 App 实际需要的 variable Sans/Mono 文件和原始 `LICENSE.txt`，记录文件 SHA-256 与包体增量，不引入字体下载脚本作为运行时依赖。

## 范围

### 1. Tokens

在 `WordLoopDesignSystem` 建立类型安全、可测试的公开 API：

- `PosterPalette`：六套固定色板，稳定 ID/order，提供相邻条目不重复的纯函数选择器；颜色使用明确 sRGB 值。
- `WordLoopSpacing`：4/8/12/16/20/24/32/44 等语义间距与最小命中尺寸。
- `WordLoopRadius`、`WordLoopBorder`、`WordLoopShadow`：胶囊、卡片、16 pt dialog、细边框和低强度投影。
- `WordLoopMotion`：palette 420 ms、content enter 520 ms、drawer 260 ms、exit 240 ms、waveform 880 ms；统一根据 `accessibilityReduceMotion` 返回立即变化或低位移淡入，不散落 magic number。
- `WordLoopTypography`：Geist Sans/Mono 的语义样式；正文与标签响应 Dynamic Type，超大 poster title 使用可读范围缩放而非截断。中文 fallback 交给系统字体链，不用 Geist 强行覆盖 CJK。
- `WordLoopHaptics` 协议与 no-op/test implementation；真正 UIKit feedback generator 只通过条件编译的 iOS adapter 暴露，不让测试依赖真实振动。

禁止把课程、学习模式、网络状态或业务文案放进 tokens。

### 2. 字体资源与许可

- 将固定版本的 Geist Sans/Mono variable font 放入 `WordLoopDesignSystem` Package resources，并提供一次性、幂等、失败可观察的注册入口。
- 将上游 `LICENSE.txt` 随资源分发，并在仓库补一份来源/version/SHA-256/包体说明；不得只复制字体而遗漏许可。
- Package 在 macOS host 的 `swift test` 仍须可编译；iOS 专属 API 使用 `#if os(iOS)` 隔离。macOS 声明只服务 package tests，不产生桌面 App。
- 测试验证资源存在、hash 固定、字体注册不崩溃、字体名可解析；失败时 UI 必须明确回落系统 Sans/Monospaced，不出现空白文本。

### 3. 无业务基础组件

在 DesignSystem Package 实现可组合的纯视觉组件：

- `PosterBackground` 与装饰圆环。
- `MonoLabel`。
- `ModeSwitch`（仅接收字符串选项和 selection binding，不知道 LISTEN/REPEAT 状态机）。
- `PosterButton` 与 icon/text 变体，视觉高度可保持基线但命中区域不少于 44 pt。
- `CourseCard` visual shell。
- `SideDrawer` visual container：left/right edge、遮罩、Safe Area、VoiceOver modal 语义与关闭 affordance；P3.1 不接真实手势阈值和课程列表。
- `ProgressTrack`。
- `ConfirmDialog` visual shell，最大宽 320 pt、外边距 24 pt、圆角 16 pt。
- `Waveform` 的 idle/active/success/failure 静态与可降级动画表现。

组件只能接受展示模型、Binding、closure 和 accessibility 文案；不得 import Content、Audio、Progress、Realtime、Networking 或 Features。

### 4. Fixture gallery 与 App 接线

- 在 `WordLoopFeatures` 增加仅供当前阶段启动的 `DesignSystemGalleryView`，展示六色板、Sans/Mono、按钮、switch、card、progress、dialog、drawer 容器和 waveform 状态。
- `RootView` 仍只通过 `WordLoopFeatures` 显示 gallery，不连接课程包、网络、存储、音频或麦克风。
- gallery 必须有稳定 accessibility identifiers，支持 UI test 定位；不把 gallery 命名或外观伪装成已完成产品页面。
- 在 390 × 844 对应的 iPhone Simulator 上保存截图证据到 `docs/ios-migration/p3/design-system/`。另覆盖一个最窄可用 iPhone destination 和一组 accessibility text size / Reduce Motion 验证；如本机没有精确型号，记录实际 destination。

### 5. 测试

- `WordLoopDesignSystem` unit tests：色板值/order/不重复选择、token 常量、motion reduce 分支、字体资源/hash/注册、组件展示模型边界。
- `WordLoopFeatures` smoke test：gallery 可构造且不依赖业务 service。
- App UI test：gallery 根节点存在、六色板和关键组件可访问；截图由确定性 launch argument 固定状态。
- 静态 Node test：字体/许可文件被提交，Package resources 声明存在，DesignSystem 不依赖其他业务 Package，App 仍不越层 import。

## 可访问性与移动端要求

- 所有交互命中区域至少 44 × 44 pt。
- 标签、按钮、switch、drawer/dialog 有明确 VoiceOver label/value/traits；纯装饰圆环隐藏。
- 正文和控制支持 Dynamic Type；超大标题在辅助字号下优先缩放/换行，不横向裁切。
- Reduce Motion 下停止 waveform 无限动画并消除 drawer/poster 大位移；颜色和内容仍可理解。
- 颜色验收至少覆盖六套 palette 的正文/关键控制对比度；若基线色值无法满足正文可访问性，只能调整具体文字角色，不能静默改机器真值色板。

## 禁止范围

- 不实现 P3.2 启动页或任何业务页面。
- 不解析 `ios/Generated`，不创建 Course/Study/Progress/Repeat model。
- 不接 URLSession、AVFoundation、SwiftData、WebRTC、权限或下载。
- 不实现左右抽屉的完整产品列表/搜索/72 pt 关闭手势。
- 不修改 Web UI、`app/page.tsx`、课程、音频、API、数据库或 VPS。
- 不增加第三方 Swift Package。
- 不创建桌面/iPad target 或为大屏单独设计布局。

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

退出标准：字体来源、版本、hash、许可和包体增量可审计；DesignSystem/Features tests 与 App UI tests 通过；gallery 在 iPhone 上可访问且截图证据完整；六色板和基础组件可供后续页面复用；Web 38 项回归不退化；lint 不超过既有 4 errors、0 新 warnings；没有业务越界或桌面产品支持。

## 实施结果

- `WordLoopDesignSystem` 已移除对 Core 的无用依赖，成为不依赖任何业务 Package 的底层 SwiftUI library。
- 六套 palette、间距/圆角/边框/投影、动效/Reduce Motion、字体、触觉协议和九类无业务视觉组件已实现；palette 顺序与 sRGB 原值由测试锁定。
- 六套 ink/background 和小文字角色至少 4.5:1；装饰 accent 原值不变，accent 不足时只让小文字角色回退 ink。
- 官方 Geist 1.8.0 的 Sans/Mono variable TTF 与原始 OFL 1.1 license 已作为 Package resources 提交；来源、commit、逐文件 SHA-256 和 344,268 bytes 未压缩增量见 [`../ios-migration/p3/design-system/font-audit.md`](../ios-migration/p3/design-system/font-audit.md)。
- `WordLoopFeatures` 提供明确标注为无业务 fixture 的 gallery；App 仍只 import Features，没有接课程、网络、进度、音频、Realtime 或下载。
- iPhone 17 Pro、390 × 844 pt iPhone 17e、accessibility 3 + Reduce Motion 三组截图和人工检查见 [`../ios-migration/p3/design-system/visual-verification.md`](../ios-migration/p3/design-system/visual-verification.md)。
- DesignSystem 11 tests、Features 2 tests、App integration 1 test、App UI 3 tests 均通过；`npm test` 为 39/39，lint 仍只有既有 Web 4 errors、0 warnings。
- 未修改 Web UI、课程、音频、API、数据库或部署；未创建 iPad、macOS 或 Catalyst 产品 target。

## 交接

完成后把状态改为“开发完成，待独立复核”，刷新 `PROJECT_CONTEXT.md` 与 handoff，提交 `CP-03 design system`，再由未参与实现的 reviewer 独立复核。P3.1 PASS 后才根据真实组件 API 生成 P3.2 启动页任务卡。
