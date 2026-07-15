# WordLoop Handoff Changelog

此文件只追加影响后续接手的耐久事实。最新记录放在最上方，不改写旧记录。

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
