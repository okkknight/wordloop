# P3.5 iPhone 进度抽屉静态 Shell

状态：独立复核 PASS

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

产品基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md) 的 M-04 与 [`../ios-migration/baseline/screenshots/iphone-progress-drawer.png`](../ios-migration/baseline/screenshots/iphone-progress-drawer.png)

上游任务：[`2026-07-15-p3-4-course-drawer.md`](2026-07-15-p3-4-course-drawer.md)，已独立复核 PASS

## 目标

在 P3.4 已通过的 iPhone 主学习页上实现从右进入的进度抽屉静态 Shell，对齐 `YOUR PROGRESS`、学习次数汇总、当前课程、进度条、已掌握/学习中统计、搜索、进度条目和完成色。此任务只完成 CP-07 progress drawer visual shell，数据来自内存 fixture；不读取 P6 进度仓库、不请求 API、不合并 outbox、不重置课程，也不改变当前学习条目。

## 已锁定机器真值

- 抽屉从右进入，宽度与课程抽屉一致为 `min(344 pt, 86% viewport)`；390 pt 设备约 335 pt，左侧保留可点击暗色遮罩。使用原生 modal/阴影表达，不复制 Web 的 DOM backdrop-filter。
- header 精确展示 `YOUR PROGRESS`、`0 / 273`、`Modern Family · S01E01` 和右上关闭按钮。273 来自 91 条 × 每条 3 次，不代表 P6 已载入真实进度。
- 默认统计为 `0 / 已掌握`、`91 / 学习中`；进度条为 0%。mixed fixture 使用同一 91 条总数，提供 0/1/2/3 次代表行、非零总学习次数和至少一个完成行。
- 默认句子搜索 placeholder 为 `搜索句子或中文翻译`；word fixture 为 `搜索单词或中文释义`。匹配 trim 后对英文、中文以及 word 音标做大小写不敏感过滤。
- 基线句子列表使用 Web 截图中的代表行，至少包括 `Phil, would you get them? / 菲尔 把他们叫下来好吗`、`Kids? Get down here! / 孩子们 快下来`、`Why are you guys yelling at us when we're way upstairs? / 我们远在楼上 你们喊也没用`，并补足至少 10 行用于滚动验收；右侧精确为 `{count} / 3`。
- word fixture 至少包含三个代表词，显示英文、`/音标/ · 中文释义` 与 `{count} / 3`。P3.5 不复制 570 个单词或 91 个句子到 Swift 源码。
- 完成行 count 为 3。canonical accent 只保留为完成标记/下划线；count 文本使用通过 4.5:1 的 `accessibleAccentText` 角色，同时提供“已掌握”可访问语义。sun 等低对比 palette 不得直接把 canonical accent 用作小文字；0/1/2 行使用达标的 ink 语义色，不能只靠颜色区分状态。
- 关闭入口为右上按钮、左侧遮罩和抽屉向右横滑超过 72 pt 且横向位移占优；列表纵向滚动不得误触关闭。

## 实现边界

### 1. Progress Drawer 展示模型与 Store

在 `WordLoopFeatures` 新增独立 `ProgressDrawer/` 文件组：

- `ProgressDrawerEntry`：稳定 id、kind(sentence/word)、primaryText、secondaryText、studyCount；构造时把 count 限制在 0...3，并提供 `countLabel`、完成语义和确定性搜索字段。
- `ProgressDrawerSummary`：courseTitle、totalItemCount、maxStudyCount 固定 3、entries 的 fixture 总学习次数/已掌握/学习中；拒绝分母为 0、负数和大于总条目数的统计。
- `ProgressDrawerViewState`：summary、entries、query、isPresented、lastDismissReason；filteredEntries 与空结果展示由纯规则决定。
- `ProgressDrawerStore`：`@MainActor @Observable` 内存 fixture Store，提供 present/dismiss、updateQuery、handleDrag；`lastAction` 只记录展示动作，不写业务进度。
- `ProgressDrawerAction` / `ProgressDrawerDismissReason`：记录 header、backdrop、swipe，不增加 reset、mark mastered、sync 或 selection action。

fixture 只复制本页验收需要的代表性元数据。summary 可以表达 91 条课程总量，但 entries 仅是视觉样本；必须明确区分，不能把样本数量误当完整课程数量。

### 2. SwiftUI Progress Drawer

- 新增 `ProgressDrawerView`，复用 P3.1/P3.4 已落地的 `SideDrawer(edge: .trailing)`、`ProgressTrack`、typography、spacing、modal 组合方式与右/左遮罩 accessibility 方案。
- header、track、两张 stats card 和 search 固定在顶部；只有条目列表是纵向 `ScrollView`。键盘打开后关闭按钮、搜索和至少一条结果可达。
- stats card、track underlay、搜索边界/placeholder、secondary text、未完成 count、完成 accent count 和列表分割线必须按实际 drawer background 的最终合成层测试；不得复用 Web 中未验证的 14%/18% 低透明边界。
- progress track 提供“已学习 X 次，共 Y 次”的 accessibility value；两张 stats card 分别朗读数量与标签。
- 每一行合并为一个静态 accessibility element，依次朗读英文、中文/音标释义、`已学习 N 次，共 3 次`；完成行追加“已掌握”。行不是 Button，P3.5 不支持点选跳转。
- 没有匹配项时显示固定原生空态 `没有匹配的学习记录` 并使用稳定 identifier；clear 后恢复 fixture 列表。
- 进入/退出使用 `WordLoopMotion.drawer`；Reduce Motion 下不做大位移。抽屉手势只在 `x > 72 && abs(x) > abs(y)` 时关闭。

### 3. MainStudyView、双抽屉协调与 fixture 路由

- P3.3 `PROGRESS` 按钮接到 ProgressDrawerStore.present；默认 Startup、gallery、关闭的 study shell 和 P3.4 COURSE 行为保持不变。
- `MainStudyView` 新增可注入 ProgressDrawerStore 的 initializer，同时保留现有初始化兼容。RootView 仍只 import `WordLoopFeatures`。
- course/progress 两个 modal 不得同时渲染。正常按钮打开新抽屉前先关闭另一抽屉；若 launch arguments 同时请求两者，为保护既有 P3.4 fixture，课程抽屉优先，progress fixture 保持关闭。该优先级必须单测/UI test 锁定。
- `-wordloop-progress-drawer` 只与 `-wordloop-study-shell` 组合时显示打开抽屉；增加 sentence/word、mixed、complete、query、empty 和 Reduce Motion fixture 参数。
- 打开/搜索/关闭进度抽屉不得修改 `StudyShellStore` 的 mode、item、index、palette、visibility、mastery 或 autoplay/pause presentation state；关闭后 `PROGRESS` 恢复可点击。

### 4. iPhone 适配与可访问性

- iPhone 17e 390 × 844 pt 标准字号下 header、track、两张 stats card、搜索和至少 6 条列表行可辨；只列表滚动，无水平裁切。
- Dynamic Type 到 accessibility 3 时 header 可换行，stats card 改为纵向或自适应排列，primary/secondary text 不截断为不可理解内容；列表仍能滚到后续行，close/search 命中区至少 44 pt。
- modal 打开时背景学习页与课程抽屉不在 accessibility tree/命中路径中；关闭后主学习页恢复。VoiceOver 顺序为 header → track → stats → search → list → empty。
- 继续只支持 iPhone；不得新增 iPad、macOS、Catalyst 或桌面自适应布局。

## Fixture 与测试矩阵

### Unit tests

- sentence baseline 精确为 0/273、0 mastered、91 learning、course title、10 条代表行与固定文案；word fixture 的音标/释义格式正确。
- mixed fixture 的 totalStudies、mastered、learning、track fraction 与各 count 0...3 一致；负数/超过 3 被限制，0 denominator 安全返回 0%。
- query trim、大小写不敏感、英文/中文/音标匹配、空结果与 clear 恢复。
- header/backdrop/swipe dismiss reason 和 lastAction；向左、纵向、等于 72 pt 或不足阈值的 drag 不关闭。
- summary/track、stats、搜索、row text/count、完成 accent/boundary按六 palette 真实层顺序达到文本 4.5:1、非文本边界 3:1。
- Store/View 可在无 Content、Networking、Progress、Audio、Realtime service 下构造。

### App UI tests

- 默认 Startup、gallery、关闭的 study shell 和 P3.4 COURSE 回归；点击 PROGRESS 打开，header close 与 backdrop 可关闭。
- progress fixture 显示 `YOUR PROGRESS / 0 / 273 / Modern Family · S01E01`、stats、search、代表行和 0/3 语义。
- mixed/complete fixture 显示非零 track、1/2/3 count，完成行同时有 canonical accent 装饰标记、达标 count 文本与“已掌握”语义。
- sentence 与 word 搜索精确；空结果显示固定文案，clear 恢复列表。
- 主导右滑关闭；列表纵向 swipe 后抽屉仍打开。
- course/progress 冲突参数只显示课程抽屉；progress modal 期间背景 `study.next` 不可点击，关闭后可恢复。
- accessibility 3 + Reduce Motion 下 close/search/stats/list 可达、命中框不重叠且无水平越界。

### Screenshot evidence

保存到 `docs/ios-migration/p3/progress-drawer/`：

- iPhone 17e 390 × 844 pt sentence baseline；
- iPhone 17e mixed/complete progress；
- iPhone 17 Pro word fixture 或搜索结果；
- iPhone 17e accessibility 3 + Reduce Motion 最坏排版。

`visual-verification.md` 记录 simulator/OS、pt/px、SHA-256、fixture arguments、drawer 宽度、实际合成对比组合、track 比例、与 Web baseline 的平台差异、modal/scroll 证据。截图必须是真实 App 进度抽屉，不含键盘、App Switcher、测试 runner 或调试浮层。

## 禁止范围

- 不解析/导入 `ios/Generated`、catalog、course 或 integrity，不复制完整课程到 Swift 源码。
- 不读取/写入 Progress Package、UserDefaults、SwiftData、Keychain、文件数据库、API 或 pending outbox；不模拟同步成功/失败。
- 不修改真实 study count、当前 index、mastery、完成次数、最近课程，不实现行点击跳转、重置、完成/重练 dialog。
- 不播放音频、不接麦克风/Realtime，不实现课程下载/更新/删除或远程 catalog。
- 不修改 Web UI、课程、音频、API、数据库、VPS、P1 exporter 或 schema。
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

退出标准：右侧方向、modal、汇总/track/stats、sentence/word 搜索、代表条目、0...3/完成语义、空态、三种关闭入口、列表独立滚动、双抽屉互斥和辅助字号通过；不改变主学习业务；P3.1–P3.4 回归保留；无正式课程解析、进度持久化/同步、网络、下载、音频或 Realtime 副作用；冷构建、App tests 和 Web 结构测试不退化；lint 不超过既有 4 errors、0 warnings；没有桌面产品支持。

## 交接

先单独提交本任务卡，再实施 CP-07。开发完成后把状态改为“开发完成，待独立复核”，刷新根 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交实现并交给未参与实现的 reviewer。P3.5 PASS 后才根据真实双抽屉协调 API 生成 P3.6 对话框与 REPEAT 静态态任务卡。

## 独立复核结论（2026-07-16）

结论：PASS。

- reviewer 从删除 `content/dist`、`ios/Generated`、`ios/.derivedData`、`ios/.build` 与所有 Package `.build` 的冷状态运行 `scripts/verify_ios.sh`，八个 Package tests、课程资源 bootstrap 和 iPhone 17 Pro Simulator build 通过。
- iPhone 17 Pro / iOS 26.5 完整 `xcodebuild test` 正常结束并显示 `TEST SUCCEEDED`；xcresult 汇总 21/21，即 App integration 1/1 与 UI 20/20，0 failure。DesignSystem 12/12、Features 51/51、Web 43/43 全部通过，`npm run baseline:ios` 与 `git diff --check` 通过。
- `npm run lint` 精确保持 `app/page.tsx` 的既有 4 errors、0 warnings，没有新增债务。ignore hygiene 通过，冷验收生成物及 cache 仍为 ignored，无意外 tracked 文件。
- 独立代码与 UI 复核确认右侧 `min(344 pt, 86% viewport)` 抽屉、header/backdrop/主导右滑三种关闭、列表纵向滚动、sentence/word/mixed/complete/query/empty fixture、完成语义、关闭后背景恢复均通过；课程/进度抽屉互斥，冲突参数保持课程抽屉优先。
- 进度抽屉只记录展示 action，打开、搜索与关闭未修改 StudyShell mode/item/index/palette/visibility/mastery 或 autoplay/pause 展示状态；UI 仍显示 S01E01 第 75/91 条。
- 六 palette 按实际不透明 drawer background 层顺序独立复算：75% ink 次要文字最低 5.068:1，56% ink 边界/track underlay 最低 3.097:1，`accessibleAccentText` 最低 8.764:1；canonical accent 只作装饰，不单独承担状态语义。
- 四张真实 App 截图的 SHA-256 与文档一致，iPhone 17e 为 1170 × 2532 px，iPhone 17 Pro 为 1206 × 2622 px；逐张人工检查右侧方向、左侧遮罩、文案、0...3 进度、word 搜索与 accessibility 3 + Reduce Motion 无裁切、重叠或调试浮层。
- 静态边界检查未发现 P4 正式课程解析、P6 进度持久化/同步、P7 远程课程/下载，也无网络、音频或 Realtime 越界。Release 设置仍为 iOS 17、Swift 6、`TARGETED_DEVICE_FAMILY = 1`，Catalyst 与 Designed for iPhone on Mac 均关闭。

P3.5 验收关闭。下一步只能根据当前真实双抽屉协调 API 生成 P3.6 任务卡，本次复核不生成也不实施 P3.6。
