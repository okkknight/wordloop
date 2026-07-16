# WordLoop 项目上下文

更新日期：2026-07-16

## 项目是什么

WordLoop 是一个单页英语学习产品，通过短音频单元形成“听原音—理解—跟读—重复掌握”的练习闭环。内容分为单词课程和句子课程，当前包括 IELTS 高频词、《摩登家庭》精选对白和 VOA Learning English Level 2。

产品目前有两种模式：

- `LISTEN`：播放当前音频，可手动切换或自动连续播放。
- `REPEAT`：播放原音，打开麦克风接收跟读，通过实时转写和浏览器端文字匹配判断通过或重试。

每个单元在每种模式下独立累计进度，达到 3 次视为掌握。用户也可以使用“太简单”直接标记掌握。

## 项目不是什么

- 不是完整影视字幕播放器；影视课程只保留有学习价值且音画文本可核验的句子。
- 不是专业音素级发音测评；当前判断基于 Realtime 英文转写、字符串相似度和句子词覆盖率。
- 不是完整账号系统；用户名只是进度标识，没有密码、OAuth 或所有权验证。
- 当前生产环境不是纯静态站，也不是以 Cloudflare D1 为唯一数据源。

## 当前产品状态

- 30 门课程：1 门 IELTS、5 门《摩登家庭》、24 门 VOA Level 2。
- 1,406 个最终音频片段：570 个单词音频和 836 个句子音频。
- 默认课程：`modern-family-s01e01`。
- 默认模式：`repeat`。
- 当前迁移分支：`codex/ios-migration`。
- `npm test`：构建通过，47 项测试通过（既有 44 项 + P4.1 Bundle Repository/resource chain 3 项）。
- `npm run lint`：未通过，存在 4 个 `react-hooks/preserve-manual-memoization` 错误。
- 构建会提示客户端 chunk 超过 500 kB。

## 最新任务

任务：执行 iOS 迁移 Plan；P4.1 iPhone 内置课程领域模型与 Bundle Repository 已独立复核 PASS，下一检查点为 P4.2 AudioPlayer。

执行状态：P0.1、P1、P2、P3.1–P3.6、P4.1 均已独立复核 PASS。下一步根据已验证的 `CourseEntry.audioURL`、Content bundle 与现有静态 StudyShell 边界生成 P4.2 AudioPlayer 任务卡；任务卡提交前不实施播放器。

P0.1 新增机器可重复生成的内容清单、iPhone 截图、产品验收矩阵、API 合同和基线测试；不改变 Web 产品代码、课程内容、数据库、部署配置或线上服务。

P1 已建立 catalog/course/integrity JSON Schema 和唯一 exporter。规范产物从真实课程注册表生成，先把已哈希字节写入临时树并逐文件复验，再替换 `content/dist/`；该目录与 iOS Generated resources 均被 Git 忽略，Web 仍读取原数据源。运行时注册 ID 是规范 ID，S01E01 的历史 manifest ID 差异和未命中 highlights 会写入 validation report。

P2 已建立 iOS 17、Swift 6、仅 iPhone 的 SwiftUI 工程，以及 Core、Networking、Content、DesignSystem、Audio、Progress、Realtime、Features 八个本地 Swift Package。App 通过 Features 接入依赖图；课程生成物、SwiftPM cache、DerivedData 和 Xcode 用户文件均被忽略，可由统一脚本从空缓存重建并编译。

P2 首次复核发现的常规 SwiftPM `ios/Packages/*/.build/` 忽略缺口已修复并通过真实 package-local 命令与静态回归。重新 reviewer 确认冷启动重建、八个 Package tests、iPhone Simulator build、App integration/UI tests 和 Web 38 项回归全部通过，结论为 PASS。

P3.1 已建立不依赖业务 Package 的 Design System：六套 palette、tokens、Geist Sans/Mono、OFL 许可、基础组件、触觉/Reduce Motion/可访问性边界和无业务 fixture gallery。当前 RootView 临时显示 gallery 供 CP-03 验收；它不是已完成的产品页面，P3.2 会用启动页替换。

P3.1 首次 reviewer 发现的 `ConfirmDialog` 五套 palette 关键按钮低对比度及 accessibility 3 标签/装饰重叠已通过角色色、真实组合测试和布局隔离修复。修复后 reviewer 确认六套实际按钮组合为 8.764–10.784:1，刷新截图无重叠，并从冷缓存重跑 Package/App/UI/Web tests 全部通过，结论为 PASS。

P3.2 已把默认 App 路由从 fixture gallery 切为原生启动页，并将 state、submission、纯用户名 validator、内存 fixture Store 与 SwiftUI View 拆入独立 Startup feature 文件。页面覆盖匿名/命名提交、32 字符、ASCII 英文字母校验、三段按钮状态、中文辅助文案、键盘、Dynamic Type、VoiceOver 语义与 Reduce Motion；不接身份持久化、课程、进度、网络、音频或 Realtime。首次 reviewer 发现 placeholder 约 2.071:1、输入下划线约 2.822:1；修复保持 canonical palette 不变，改为 UI 与测试共用的预合成角色色。修复后 reviewer 实算为 5.083759:1/3.157488:1，并从冷缓存确认八 Package/iPhone build、Features 13/13、App integration 1/1、UI 8/8、Web 40/40、四张视觉证据和 iPhone-only 设置全部通过，结论为 PASS。

P3.3 已新增独立 StudyShell 展示模型、Character-offset highlight 校验、句子/单词文字可见性规则、`@MainActor @Observable` 内存 fixture Store 和 SwiftUI 主学习页。默认仍是 Startup，只有 `-wordloop-study-shell` 显式进入页面；Gallery 优先级由 UI test 锁定。页面覆盖 LISTEN/REPEAT、full/focus/hidden、课程上下文、英文/中文/音标、学习动作、代表性 repeat card、熟练度和底部控制；它不解析课程、不播放音频、不写进度、不连接网络、麦克风或 Realtime。首次 reviewer 发现的 mode switch 圆环区 3.389973:1 对比度和 accessibility 3 SF Symbols 越界重叠已修复。第二轮 reviewer 确认 UI/测试共用 opacity token，纯背景/圆环区实算为 8.746483:1/5.300792:1，两个图标固定 18 pt、44 pt 命中框不相交，四张截图与 DesignSystem 12、Features 26、相关 UI 4、App integration 1、Web 41 项均通过，结论为 PASS。

P3.4 已新增独立 CourseDrawer 展示模型、三集合内存 fixture、确定性搜索/折叠、dismiss reason/action、SwiftUI 左侧抽屉和主学习页接线。页面覆盖 selected/completion、空态、header/backdrop/主导左滑关闭、列表独立滚动、accessibility 3 与 Reduce Motion；课程点击只关闭抽屉，主学习上下文仍为 S01E01 / 75/91。CourseCard 次要文字和边界改为跨六 palette 真实合成至少 4.5:1/3:1 的共享 token，selected 同时保留 canonical accent 外框与语义 ink 内框。当前不解析/切换正式课程，不持久化，不访问网络，不下载课程，不播放音频，不接进度或 Realtime。

P3.4 独立 reviewer 已从删除生成物、SwiftPM cache 和 DerivedData 的冷状态确认八 Package/iPhone build，并复验 DesignSystem 12/12、Features 39/39、App integration 1/1、UI 16/16、Web 42/42、四张截图 hash/尺寸、真实合成对比度、modal/手势/选择不切课语义与 iPhone-only 设置，结论为 PASS。lint 精确保持既有 4 errors、0 warnings。

P3.5 已新增独立 ProgressDrawer entry/summary/view state/fixture/store 与 SwiftUI 右侧抽屉。基线精确展示 `YOUR PROGRESS`、0/273、S01E01、0 已掌握/91 学习中、10 条代表句；另覆盖 word、mixed、complete、query 和 empty fixture。课程/进度抽屉互斥且冲突参数保持课程优先；三种关闭入口、列表独立滚动、搜索、完成语义、accessibility 3 与 Reduce Motion 已由 App UI test 覆盖。ProgressTrack 和条目边界使用真实合成可达标角色，canonical accent 只保留装饰；不读取 P6 Progress、不访问网络或持久化，也不改变主学习上下文。

P3.5 独立 reviewer 已从删除生成物、SwiftPM cache 和 DerivedData 的冷状态确认八 Package/iPhone build，并复验 DesignSystem 12/12、Features 51/51、App integration 1/1、UI 20/20、Web 43/43、四张截图 hash/尺寸/视觉、六 palette 真实合成对比度、双抽屉互斥与课程优先、三种关闭、背景恢复、学习状态不变、无 P4/P6/P7 越界和 iPhone-only 设置，结论为 PASS。lint 精确保持既有 4 errors、0 warnings。

P3.6 已新增独立 CompletionDialog kind/state/action/store/view，接入不可点关闭的原生 modal backdrop，并把 StudyShell 的 REPEAT 卡扩展为 11 个确定性展示态。选择课程只打开既有 CourseDrawer，重练只记录 intent；没有真实 reset、进度变化、音频、麦克风、评分、Realtime、网络或 timer。DesignSystem 的 dialog 小字/边界/次按钮与成功失败视觉使用六 palette 实际合成达标角色。

独立 reviewer 从删除生成物、统一/Package SwiftPM cache 和 DerivedData 的冷状态确认 `scripts/verify_ios.sh`，并复验 DesignSystem 13/13、Features 65/65、App integration 1/1、UI 25/25、Web 44/44、iOS baseline、五张真实 iPhone 截图、六 palette 实际合成、禁止业务越界和 iPhone-only 设置全部通过；lint 精确保持既有 4 errors、0 warnings，P3.6 结论为 PASS。

P4.1 已在 Core 新增强类型课程/条目/集合 ID、课程 catalog/descriptor/entry 与业务枚举；Content 使用 `Bundle.module` 严格解码 catalog/course/integrity，拒绝未知字段、坏 schema/标量/路径/文件集合，并提供轻量校验、全量音频 SHA 校验和成功缓存/失败重试的 actor `CourseRepository`。bootstrap 原子生成中间目录与 Package `.copy` resource mirror，只打包 `catalog.json + courses/`，不把 `validation-report.json` 带进 App。

开发侧已通过 Core 9/9、Content 12/12（30 门、1,406 entries/M4A、32,700,838 bytes 与全 SHA）、App integration 2/2、原有 UI 25/25、Web 47/47、baseline 和统一 iPhone 构建；主 App 根资源实查只有一套 Content bundle、1,406 个 M4A、无审计 report。P3 UI/fixture 未接 Repository，未实现播放器、网络、下载、进度或桌面产品。

独立 reviewer 从删除全部生成物、SwiftPM cache 与 DerivedData 的冷状态复验以上矩阵，并额外注入 Package 第二目标切换失败，确认第一目标旧树 digest 不变且无 stage/previous 残留；Release 仍为 iOS 17、Swift 6、iPhone device family 1、Catalyst/Designed for Mac 关闭。P4.1 结论为 PASS。

## 架构与数据流

### 浏览器端

`app/page.tsx` 是主控制面，目前同时承担：

1. 用户名或匿名 ID 初始化；
2. 最近课程和服务端进度恢复；
3. 课程选择、搜索与完成后重练；
4. 当前音频播放及下一片段预加载；
5. `LISTEN` 自动播放；
6. `REPEAT` WebRTC 会话和阶段状态机；
7. 本地待同步事件队列及联网重试；
8. 进度面板和主要界面渲染。

当前音频按片段懒加载：播放当前片段，并预加载下一片段；不会一次加载整门课程或全部课程。

### 跟读状态流

内部主流程：

```text
playing -> speak -> speaking -> scoring -> passed / retry
```

- 浏览器通过 WebRTC 把麦克风音频传给 OpenAI Realtime。
- API 只负责使用服务端密钥建立 transcription 会话，不把密钥交给浏览器。
- `gpt-4o-mini-transcribe` 返回英文转写。
- 客户端使用 turn ID、armed 状态、Realtime item ID 和分阶段定时器隔离迟到事件。
- 单词以规范化字符串相似度为主；句子额外要求至少 60% 单词覆盖率。

### 进度同步

- `listen` 和 `repeat` 进度完全分开。
- 单词按 `user + mode + word` 保存。
- 句子按 `user + mode + course + item` 保存。
- 浏览器只在 `localStorage` 保存尚未确认的操作事件。
- 每个事件带 `clientEventId`，后端先写 `progress_events` 去重，再累计进度。
- 页面以服务端进度为基准，再叠加本地未确认事件，网络恢复后自动重试。

### 两套服务端实现

仓库必须同时关注两条路径：

| 场景 | API 实现 | 数据库 |
| --- | --- | --- |
| Sites/Cloudflare | `app/api/*` | D1 + Drizzle migrations |
| 当前 VPS 生产环境 | `server/index.mjs` | Node.js 内置 SQLite |

修改进度、课程偏好、完成次数或 Realtime 会话协议时，必须同步检查两套实现，避免行为漂移。

## 当前生产运行事实

以下事实来自仓库内 2026-07-12 的 VPS 实机运维记录；执行部署任务前仍应重新核验线上状态：

- 公网入口：`https://boringmax.com/wordloop/`
- Caddy 将页面请求转发到 `127.0.0.1:3010`。
- Caddy 将 `/wordloop/api*` 去除 base path 后转发到 `127.0.0.1:3011`。
- `wordloop.service` 运行 vinext 前端。
- `wordloop-api.service` 运行 `server/index.mjs`。
- SQLite 位于 `/opt/boringmax/wordloop/data/wordloop.sqlite`。
- `OPENAI_API_KEY` 位于 VPS 环境文件，不在仓库中。

具体命令与权限修复只参考 `docs/WORDLOOP_VPS_RUNBOOK.md`。

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `app/page.tsx` | 产品主界面、学习状态、音频、Realtime、同步 |
| `app/globals.css` | 完整视觉和响应式样式 |
| `app/courses.ts` | 课程类型、集合、注册与音频路径映射 |
| `app/words.ts` | 570 个 IELTS 高频词 |
| `app/data/*` | 句子 manifest 和表达 highlights |
| `app/api/progress/route.ts` | D1 进度 API |
| `app/api/pronunciation-session/route.ts` | Cloudflare Realtime 会话 API |
| `server/index.mjs` | VPS 进度和 Realtime API |
| `db/schema.ts`、`drizzle/*` | D1 schema 与迁移历史 |
| `scripts/*` | 课程内容生产和验证工具 |
| `tests/rendered-html.test.mjs` | 构建、内容数量、音频和流程契约测试 |
| `docs/ios-migration/baseline/*` | iPhone 迁移的机器内容清单、截图、行为和 API 合同 |
| `scripts/capture_ios_migration_baseline.mjs` | 生成并校验迁移内容基线 |
| `tests/ios-migration-baseline.test.mjs` | 基线确定性和错误注入测试 |
| `content/schema/*`、`content/fixtures/*` | 跨平台课程包合同与成功/失败样本 |
| `scripts/export_course_packages.mjs` | 确定性生成 catalog、课程 manifest、integrity 与音频树 |
| `scripts/bootstrap_ios_content.sh` | 为后续 iOS Package 生成被忽略的 Bundle resources |
| `tests/course-export.test.mjs` | Schema、等价、确定性、原子替换与 mutation tests |
| `ios/WordLoop.xcodeproj` | iPhone-only SwiftUI App、integration test 与 UI test 工程 |
| `ios/Packages/*` | 八个本地 Swift Package 与单向依赖边界 |
| `ios/Packages/WordLoopCore/Sources/WordLoopCore/Course*.swift` | 正式课程强类型 ID、枚举、catalog、descriptor、course 与 entry 领域模型 |
| `ios/Packages/WordLoopContent/Sources/WordLoopContent` | 严格 Bundle source、wire 校验、typed error 与 actor CourseRepository |
| `scripts/verify_ios.sh` | 从空缓存重建课程资源、测试 Packages 并编译 Simulator |
| `tests/ios-project-structure.test.mjs` | iOS 17/Swift 6/iPhone-only、模块图和工程卫生静态检查 |
| `ios/Packages/WordLoopDesignSystem` | 原生 palette、tokens、字体、基础组件、动效与触觉边界 |
| `docs/ios-migration/p3/design-system/*` | Geist 字体审计与 iPhone 视觉截图证据 |
| `tests/ios-design-system.test.mjs` | 字体 hash/许可、tokens、组件边界和 App 不越层静态检查 |
| `ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Startup` | 启动状态、用户名校验、fixture Store 与 iPhone SwiftUI 页面 |
| `docs/ios-migration/p3/startup/*` | 启动页 390 × 844 / iPhone 17 Pro 视觉截图与差异证据 |
| `tests/ios-startup-page.test.mjs` | 启动页固定文案、输入边界、fixture 路由和 App 模块边界检查 |
| `ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell` | 主学习页展示模型、内存 Store、文字 range/visibility 规则与 SwiftUI 页面 |
| `docs/ios-migration/p3/study-shell/*` | Listen/Repeat、隐藏态与辅助字号真实 iPhone 视觉证据 |
| `tests/ios-study-shell.test.mjs` | 主学习页 fixture 边界、稳定标识、模块隔离和禁用业务运行时静态检查 |
| `ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/CourseDrawer` | 课程抽屉展示模型、内存 fixture Store、搜索/折叠/关闭规则与 SwiftUI 页面 |
| `docs/ios-migration/p3/course-drawer/*` | 默认、空态、完成次数、辅助字号真实 iPhone 视觉证据 |
| `tests/ios-course-drawer.test.mjs` | 课程抽屉 fixture、稳定标识、模块隔离和禁用业务运行时静态检查 |
| `ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/CompletionDialog` | 完成对话框展示模型、内存 Store、原生 modal 与重练 intent |
| `docs/ios-migration/p3/completion-repeat/*` | 两类完成对话框与 speaking/passed/retry 辅助字号真实 iPhone 证据 |
| `tests/ios-completion-repeat.test.mjs` | 对话框/11 个 REPEAT fixture、模态优先级与禁止业务副作用静态检查 |
| `tests/ios-bundled-content-repository.test.mjs` | Package resource mirror、唯一 App 资源所有权与 P3/P4.1 隔离检查 |
| `docs/WORDLOOP_VPS_RUNBOOK.md` | 真实 VPS 拓扑和部署运维手册 |

## 验证与运行

安装和本地开发：

```bash
npm install
npm run dev
```

标准检查：

```bash
npm run lint
npm test
git diff --check
```

注意：`npm test` 会执行一次完整 build。课程变更还必须按对应制作指南执行脚本验证和人工抽听，自动测试不能证明音频内容真的与文本完全对齐。

## 工作规则

1. 以当前代码和实机检查为准，不以旧 README、历史数量或部署印象为准。
2. 修改 `LISTEN`、`REPEAT`、课程切换或自动前进时，先画清状态和事件边界，不做只改显示文案的流程修补。
3. Realtime 迟到事件必须经过当前 turn、armed 状态和 item ID 校验。
4. 新课程必须同时提交 manifest、highlights、逐句音频、`app/courses.ts` 注册和测试。
5. 音频与文字必须逐条对齐；Whisper 是定位工具，不是最终文本权威。
6. `work/`、原始媒体、网页、转写中间文件和密钥不能提交。
7. 修改 API 契约或数据库行为时，同时更新 D1 和 VPS Node 两套实现及迁移。
8. 发布到 VPS 后要验证页面、至少一个音频资源和真实进度 API，不能只看 systemd active。
9. 不覆盖用户工作区中的无关改动；提交课程时只纳入当前课程的最终资产。

## 当前风险与开放项

### 已确认的工程风险

- `app/page.tsx` 超过 2,100 行，多种状态和副作用集中，修改时容易产生跨流程回归。
- D1 API 与 VPS Node API 存在重复业务逻辑，缺少统一契约测试。
- 当前 lint 因 React Compiler 无法保持部分 `useCallback` memoization 而失败。
- 前端主 chunk 超过 500 kB，尚未做代码拆分。
- `db/schema.ts` 没有完整表达 VPS 专用的 `study_users` 表；运行时事实不能只看 Drizzle schema。
- 根布局的 metadata 仍偏向“570 IELTS words”，没有覆盖现有句子课程产品定位。

### 需要产品确认的开放项

- 跟读通过标准是否要维持当前宽松的文字匹配，还是升级为更严格的口语评估。
- 是否继续支持无认证的共享用户名，或引入真正账号体系。
- 长期生产目标是继续 VPS，迁移到 Sites/Cloudflare，还是明确双部署支持。

## 文档地图

- 项目入口：`README.md`
- 原生 iOS 迁移：`docs/IOS_MIGRATION_SPEC.md`
- iOS 实施 Plan：`docs/plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`
- 已复核基线：`docs/tasks/2026-07-15-p0-1-baseline-freeze.md`
- 已复核课程合同：`docs/tasks/2026-07-15-p1-course-contract-exporter.md`
- 已复核原生骨架：`docs/tasks/2026-07-15-p2-native-project-skeleton.md`
- 当前任务卡：`docs/tasks/2026-07-16-p4-1-bundled-content-repository.md`
- 接手索引：`docs/handoff/README.md`
- 接手变更：`docs/handoff/CHANGELOG.md`
- 通用课程制作：`docs/COURSE_PRODUCTION_GUIDE.md`
- VOA 课程制作：`docs/VOA_COURSE_PRODUCTION_GUIDE.md`
- 素材审计：`docs/MODERN_FAMILY_SOURCE_AUDIT.md`
- VPS 运维：`docs/WORDLOOP_VPS_RUNBOOK.md`
