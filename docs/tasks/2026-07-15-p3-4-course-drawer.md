# P3.4 iPhone 课程抽屉静态 Shell

状态：独立复核 PASS

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

产品基线：[`../ios-migration/baseline/product-acceptance-matrix.md`](../ios-migration/baseline/product-acceptance-matrix.md) 的 M-03 与 [`../ios-migration/baseline/screenshots/iphone-course-drawer.png`](../ios-migration/baseline/screenshots/iphone-course-drawer.png)

上游任务：[`2026-07-15-p3-3-main-study-page.md`](2026-07-15-p3-3-main-study-page.md)，已第二轮独立复核 PASS

## 目标

在 P3.3 主学习页上实现只面向 iPhone 的课程抽屉静态 Shell，对齐从左进入的遮罩、`COURSE PACKAGES / 选择课程`、搜索、课程集合折叠、课程卡、当前课程、完成次数、空结果和关闭手势。此任务只完成 CP-06 course drawer visual shell，数据来自内存 fixture；不解析 P4 课程包、不切换真实学习内容、不保存最近课程、不下载远程课程。

## 已锁定机器真值

- 抽屉从左进入，宽度为 `min(344 pt, 86% viewport)`；390 pt 设备约 335 pt，右侧保留可点击的暗色遮罩。背景学习页保持原位置并使用系统材质/暗色遮罩表达失焦，不复制 Web 的 DOM backdrop-filter 实现。
- header 固定为 `COURSE PACKAGES`、`选择课程` 和右上关闭按钮；搜索 placeholder 为 `搜索课程`。
- 集合固定展示三类代表性 fixture：`WORD COURSE / IELTS 高频词`、`DIALOGUE COURSE / 摩登家庭 · 第一季`、`DIALOGUE COURSE / VOA · Level 2`。默认展开摩登家庭集合，其余收起；搜索有内容时所有匹配集合按结果展开。
- 摩登家庭 fixture 至少包含 S01E01–S01E05，标题/副标题来自当前 Web 基线；S01E01 为当前课程并使用 canonical accent 边框，至少一个 fixture 显示完成次数 `× N`。
- collection 行显示 label、标题、副标题和 `+ / −`；卡片显示标题、副标题、selected 与 completion count。空结果精确为 `没有匹配的课程`。
- 关闭入口为右上按钮、遮罩点击和抽屉向左横滑超过 72 pt 且横向位移占优；列表纵向滚动不得误触关闭。
- P3.4 的课程点击只记录 fixture action 并关闭抽屉；不得修改 P3.3 当前英文、索引、palette、熟练度或模拟已恢复课程。P4 建立正式课程领域模型，P6 才接最近课程/进度恢复，P7 才接远程 catalog/download。

## 实现边界

### 1. Course Drawer 展示模型与 Store

在 `WordLoopFeatures` 新增独立 `CourseDrawer/` 文件组：

- `CourseDrawerCourse`：稳定 id、title、subtitle、completionCount、isSelected。
- `CourseDrawerCollection`：稳定 id、label、title、subtitle、courses。
- `CourseDrawerViewState`：collections、query、expandedCollectionID、isPresented、last dismissed reason 所需展示字段。
- `CourseDrawerStore`：`@MainActor @Observable` 内存 fixture Store，提供 present/dismiss、updateQuery、toggleCollection、selectCourse 和 `filteredCollections`；搜索 trim 后对 title/subtitle/label 做确定性、大小写不敏感匹配。
- `CourseDrawerAction` / `CourseDrawerDismissReason`：记录 header、backdrop、swipe、selection，不执行真实课程切换。

fixture 只复制本页验收所需的代表性元数据，不复制 30 门正式 catalog。所有过滤、展开和 action 规则必须可单测；不得引用 P4 尚未实现的 `Course`、Content parser 或 Networking。

### 2. SwiftUI Drawer

- 新增 `CourseDrawerView`，组合 P3.1 `SideDrawer(edge: .leading)`、`CourseCard`、typography/tokens；页面专属集合行、搜索和空态留在 CourseDrawer feature。
- panel header 固定在顶部，课程列表是唯一纵向 ScrollView；键盘打开后搜索框、关闭按钮和至少一条结果可达，背景主学习页不得随列表滚动。
- 搜索使用原生 `TextField`，关闭 autocorrection，提供 clear button；输入时不发网络请求，不记录真实偏好。
- selected card 除 accent 边框外还提供 selected trait/value；completion count 有“已完成 N 次”的可访问文案，不只显示 `× N`。
- collection toggle 是至少 44 pt 的 Button，暴露 expanded/collapsed value；加减号为装饰，不重复朗读。
- 抽屉进入/退出使用 `WordLoopMotion.drawer`，Reduce Motion 下无大位移；横滑只在 `abs(x) > abs(y)` 且 `x < -72` 时关闭。
- 遮罩可点击区域、header close、搜索、三个集合、五张基线卡和空态均有稳定 identifier；打开后 VoiceOver 焦点顺序从 header 到 search 再到 list，背景学习控件不可操作。

### 3. MainStudyView 与 fixture 路由

- P3.3 `COURSE` 按钮接到 CourseDrawerStore.present；默认 Startup 路由不变，`-wordloop-study-shell` 仍只显示关闭的主学习页。
- `-wordloop-course-drawer` 必须与 `-wordloop-study-shell` 组合才显示打开抽屉；RootView 不新增对 DesignSystem/Content/Networking 等模块的 import。
- 增加 query、empty、collapsed/expanded、completion 和 Reduce Motion fixture 参数；参数只构造内存展示状态。
- 点击 fixture 课程后抽屉关闭、lastAction 可观察，但主学习页仍显示 `MODERN FAMILY · S01E01 / 75/91`，明确证明没有伪造业务切课。
- P3.3 gallery/Startup/study shell、两种模式、visibility 和 accessibility tests 继续通过。

### 4. iPhone 适配与可访问性

- 390 × 844 pt 标准字号下抽屉宽度、Safe Area、header、搜索、默认集合和至少前三张课程卡可辨；只列表滚动，无水平裁切。
- Dynamic Type 到 accessibility 3 时 header 可换行、搜索和集合行增高，列表仍能滚到结果；关闭按钮固定至少 44 pt，不与标题重叠。
- 搜索 placeholder/边界、collection subtitle、course subtitle、completion count 和 selected border 必须按最终合成背景测试；禁止用未经真实 compositing 验证的低 opacity 小文字。
- modal 期间背景从 accessibility tree/命中测试隔离；关闭后 COURSE 恢复可点击。Reduce Motion、VoiceOver 与键盘不会改变数据或 action 语义。

## Fixture 与测试矩阵

### Unit tests

- 默认三集合、默认展开摩登家庭、S01E01 selected、completion count 和精确文案；
- collection 展开/收起只允许一个 expanded id，搜索时匹配集合自动可见；
- query trim、大小写不敏感、title/subtitle/label 匹配与空结果；
- header/backdrop/swipe/selection dismiss reason 和 last action；纵向或不足 72 pt drag 不关闭；
- selected/未选/完成次数展示模型和真实 drawer 背景上的文本/边界对比度；
- Store/View 可在无 Content、Networking、Progress、Audio、Realtime service 下构造。

### App UI tests

- 默认 Startup 与关闭的 study shell 回归；点击 COURSE 打开，header close 与 backdrop 可关闭。
- `-wordloop-course-drawer` 打开 fixture，标题、搜索、三集合、当前卡和 selected/completion 语义可访问。
- 展开/收起与搜索结果精确；无匹配显示空态，clear 恢复列表。
- 点击非当前 fixture 课程关闭抽屉但主页面课程上下文/75/91 不变。
- 横向左滑超过阈值关闭；课程列表纵向 swipe 仍保持抽屉打开。
- 390 pt 边界、键盘和 accessibility 3 + Reduce Motion 可达；背景 `study.next` 在 modal 打开时不可点击。

### Screenshot evidence

保存到 `docs/ios-migration/p3/course-drawer/`：

- iPhone 17e 390 × 844 pt 默认课程抽屉；
- iPhone 17e 搜索结果或空结果；
- iPhone 17 Pro 收起/完成次数 fixture；
- iPhone 17e accessibility 3 + Reduce Motion 最坏排版。

`visual-verification.md` 记录 simulator/OS、pt/px、SHA-256、fixture arguments、drawer 宽度、与 Web baseline 的平台差异、实际对比组合和 modal/scroll 证据。截图必须是真实 App 抽屉，不含键盘（除非专门标注键盘证据）、App Switcher 或调试浮层。

## 禁止范围

- 不解析/导入 `ios/Generated`、catalog/course/integrity，不复制 30 门正式课程数据到 Swift 源码。
- 不切换真实 StudyShell item/index/palette，不重置完成课程，不实现完成/重练 dialog。
- 不读写 UserDefaults/SwiftData/Keychain，不请求进度或最近课程，不连接 API/outbox。
- 不实现课程下载、更新、删除、失败/重试、磁盘空间或远程 catalog；这些属于 P7。
- 不播放音频、不接麦克风/Realtime，不实现进度抽屉。
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

退出标准：抽屉方向、modal、搜索、集合、课程卡、selected/completion、空态、三种关闭入口、列表独立滚动和辅助字号通过；fixture 点击不改变主学习业务；P3.1–P3.3 回归保留；无正式课程解析、下载、音频、进度、持久化、网络或 Realtime 副作用；冷构建、App tests 和 Web 42 项（含本任务新增结构测试）不退化；lint 不超过既有 4 errors、0 warnings；没有桌面产品支持。

## 交接

先单独提交本任务卡，再实施 CP-06。开发完成后把状态改为“开发完成，待独立复核”，刷新根 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交实现并交给未参与实现的 reviewer。P3.4 PASS 后才根据真实 MainStudyView/SideDrawer API 生成 P3.5 进度抽屉任务卡。

## 独立复核结论（2026-07-15）

结论：PASS。

- reviewer 从删除 `content/dist`、`ios/Generated`、`ios/.derivedData`、`ios/.build` 与各 Package `.build` 的冷状态运行 `scripts/verify_ios.sh`，八个本地 Package 测试、内容 bootstrap 和 iPhone 17 Pro Simulator build 通过。
- DesignSystem 12/12、Features 39/39、App integration 1/1、App UI 16/16、Web 42/42 全部通过；`npm run baseline:ios` 通过，`git diff --check` 通过。`npm run lint` 精确保持 `app/page.tsx` 的既有 4 errors、0 warnings，无新增债务。
- 独立检查确认三集合 fixture、默认展开/搜索/空态、selected/completion 语义、header/backdrop/主导左滑三种关闭、纵向列表滚动和 modal 背景隔离均与任务卡一致；选择 S01E02 后主学习页仍为 S01E01 / 75/91。
- CourseCard 的半透明同色背景实际叠在不透明 drawer background 上，最终合成色与单测使用的真实层顺序一致；六 palette 次要文字/边界门槛和 selected 双边界通过。
- 四张真实 iPhone 截图的 SHA-256 与文档一致，iPhone 17e 为 1170 × 2532 px，iPhone 17 Pro 为 1206 × 2622 px；默认、空态、完成次数与 accessibility 3 + Reduce Motion 人工视觉检查无 blocker。
- 静态边界检查未发现正式课程解析/切换、持久化、网络/下载、音频、进度或 Realtime 越界；工程仍是 iOS 17、Swift 6、`TARGETED_DEVICE_FAMILY = 1` 的 iPhone-only 产品。

P3.4 验收关闭。下一步只能根据当前真实 MainStudyView/SideDrawer/CourseDrawer API 生成 P3.5 进度抽屉任务卡，本次复核不生成也不实施 P3.5。
