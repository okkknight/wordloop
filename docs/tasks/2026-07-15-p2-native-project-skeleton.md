# P2 原生 iPhone 工程与模块骨架

状态：开发完成，待独立复核

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游课程合同：[`../../content/README.md`](../../content/README.md)

## 目标

在仓库 `ios/` 下建立可由命令行完整重建内容、运行全部本地 Package tests 并编译到 iPhone Simulator 的原生 SwiftUI 工程。此任务只建立依赖注入、环境配置和模块边界，不实现课程、页面视觉、音频、进度或 REPEAT 业务。

## 当前工具链事实

- Xcode `26.6`（build `17F113`）。
- Apple Swift `6.3.3`，目标 Swift Language Mode `6`。
- 可用 iOS Runtime `26.5`；验证 destination 使用 `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5`。
- Deployment target 固定 iOS `17.0`；只支持 iPhone device family。
- 本机没有 `xcodegen`、Tuist、SwiftLint 或 SwiftFormat。P2 不增加这些机器级依赖，提交可直接打开的 `ios/WordLoop.xcodeproj`。

## 范围

### 1. App 工程

建立：

```text
ios/
├── WordLoop.xcodeproj/
├── App/
│   ├── WordLoopApp.swift
│   ├── RootView.swift
│   ├── AppContainer.swift
│   ├── AppEnvironment.swift
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy
│   └── Assets.xcassets/
├── Config/{Shared,Debug,Release}.xcconfig
├── Packages/
└── Tests/{AppIntegrationTests,AppUITests}/
```

要求：

- `WordLoopApp` 只构建 `AppContainer` 并显示无业务 `RootView`。
- `AppEnvironment` 从 Info.plist/build settings 读取 API Base URL、catalog URL 与配置名；Debug/Release 都不得含 Key 或 token。
- Debug 可指向当前本地/VPS HTTPS 配置占位，Release 默认 `https://boringmax.com/wordloop/api`；URL 必须可由 xcconfig 覆盖。
- `Info.plist`、Privacy Manifest 和空 Assets catalog 语法有效。
- 工程明确 `SWIFT_VERSION=6.0`、`IPHONEOS_DEPLOYMENT_TARGET=17.0`、`TARGETED_DEVICE_FAMILY=1`、`SUPPORTS_MACCATALYST=NO`，不创建 iPad/macOS target。
- Scheme 必须共享，命令行不依赖用户态 `xcuserdata`。

### 2. 八个本地 Swift Packages

依次建立：

1. `WordLoopCore`
2. `WordLoopNetworking`
3. `WordLoopContent`
4. `WordLoopDesignSystem`
5. `WordLoopAudio`
6. `WordLoopProgress`
7. `WordLoopRealtime`
8. `WordLoopFeatures`

每个 Package 必须有 `Package.swift`、单一 library product、最小 public API 和 XCTest smoke test；支持 iOS 17。骨架不得提前塞业务模型。

依赖锁定为：

```text
Core
├── Networking
├── Content
├── DesignSystem
└── Audio
Networking + Core ──> Progress
Networking + Core ──> Realtime
Core + Content + DesignSystem + Audio + Progress + Realtime ──> Features
Features ──> App Target
```

禁止 Package 反向依赖 App、Features 或形成环。App 通过 `Features` product 触发整张依赖图编译，不逐个跨层访问底层模块。

### 3. 内容 bootstrap 与统一验证

新增 `scripts/verify_ios.sh`：

1. 执行 `scripts/bootstrap_ios_content.sh`。
2. 对八个本地 Package 逐个执行 `swift test`，使用仓库内被忽略的统一 build/cache 目录。
3. 用实际 destination 执行 `xcodebuild` simulator build，`CODE_SIGNING_ALLOWED=NO`。
4. 输出简洁阶段结果，任一步失败立即非零退出。

P1 产物放到 `ios/Generated/WordLoopContent/`，但本任务不把 30 门课程接入 Package resources；P4 才实现解析。`verify_ios.sh` 必须能在删除 `content/dist/`、`ios/Generated/` 与 DerivedData 后从零通过。

### 4. 工程卫生与测试

- `.gitignore` 覆盖 `ios/.derivedData/`、`.build/`、`xcuserdata`、生成内容和临时测试结果，不忽略共享 scheme、project.pbxproj 或源码。
- 增加静态工程测试，验证 8 个 Package、依赖方向、iOS 17/Swift 6/iPhone-only build settings、无密钥和共享 scheme。
- 保留 Web 测试与 exporter 测试；P2 不修复 Web lint。

## 禁止范围

- 不实现 Design System 组件或最终页面；RootView 只显示明确的 skeleton 标识。
- 不解析课程 manifest，不接 AVFoundation、SwiftData、网络或 WebRTC。
- 不添加第三方 Swift dependency。
- 不创建 iPad、macOS、Catalyst、watchOS 或 visionOS target。
- 不修改 Web UI、课程、音频、API、数据库或部署。
- 不提交 DerivedData、SwiftPM build、用户 Xcode 文件、生成课程或密钥。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build
scripts/verify_ios.sh
npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

退出标准：八个 Package tests 全绿；`WordLoop` 在 iPhone 17 Pro / iOS 26.5 Simulator destination 编译成功；干净重建不依赖残留；Web 38 项测试仍通过；lint 只允许既有 4 errors、0 新 warning；生成目录均 ignored。

## 实施结果

- 已提交可直接打开的 `ios/WordLoop.xcodeproj`、共享 `WordLoop` scheme、App/Integration/UI 三个 target；工程固定 iOS 17、Swift 6、iPhone-only，并关闭 Mac Catalyst。
- 八个本地 Package 已按锁定依赖图建立，App 只通过 `WordLoopFeatures` 接入整张模块图；无远程 Swift dependency。
- `AppEnvironment` 从 build settings 读取环境与 HTTPS URL，Release API 默认指向当前 VPS；仓库内无 API key 或 token。
- `scripts/verify_ios.sh` 可在删除课程生成物、SwiftPM cache 和 DerivedData 后重建课程资源，逐个测试八个 Package，并编译 iPhone 17 Pro / iOS 26.5 Simulator target。
- App integration test 与 UI launch test 已额外通过；UI test 只验证无业务 skeleton 成功启动。
- `npm test` 为 38/38；`npm run lint` 只有既有 `app/page.tsx` 4 errors、0 warnings；课程基线、export/check 与 `git diff --check` 均通过。
- 未修改 Web UI、课程、音频、API、数据库或部署，也未实现任何 P3 之后的业务能力。

## 交接

完成后把状态改为“开发完成，待独立复核”，刷新项目上下文与 handoff，提交 `CP-02 native project skeleton builds`，再由未参与实现的 reviewer 从删除所有生成缓存开始独立验收。P2 PASS 后才生成 P3 Design System 任务卡。
