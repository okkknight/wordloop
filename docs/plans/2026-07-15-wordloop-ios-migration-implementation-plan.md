# WordLoop 原生 iOS 迁移实施 Plan

状态：执行中；P0–P2、P3.1–P3.5 已 PASS，P3.6 任务卡已锁定待开发

制定日期：2026-07-15

上游规格：[`../IOS_MIGRATION_SPEC.md`](../IOS_MIGRATION_SPEC.md)

实施范围：当前仓库新增 `ios/`，保留并最小适配现有 Web、课程生产和 VPS 服务

## 1. Plan 的作用

本文把已经确认的迁移规格展开为可顺序执行的工程路线图，定义每个阶段的依赖、修改范围、验证方式和提交检查点。

本文不是编码任务卡。正式执行时一次只生成并执行一张任务卡；下一张任务卡必须基于上一张的实际结果，而不是假设前一步完美完成。未经阶段验收，不跨阶段并行铺功能。

## 2. 最终目标

完成后，仓库同时包含：

- 继续可运行的现有 Web 产品与 VPS 服务。
- 平台无关、可验证的统一课程产物。
- 纯原生 SwiftUI iPhone App。
- 当前 30 门内置课程的完整 LISTEN/REPEAT/进度体验。
- 后续课程的远端发现、下载、更新、删除和离线学习能力。
- TestFlight 可安装包和 App Store 发布检查清单。

技术迁移过程中不调整当前学习规则、发音阈值、账号边界或课程内容。Web 的 `app/page.tsx` 作为行为基线保留；本轮不额外发起 Web 端组件重构，只允许为统一课程产物做最小适配。

## 3. 执行原则

1. **行为先冻结**：每个功能迁移前先从当前 Web 提取可重复的状态、输入和输出。
2. **内容协议先于页面**：原生端不能直接解析 `courses.ts`；先建立规范化产物。
3. **逐页对齐**：启动页、主学习页、课程抽屉、进度抽屉、对话框分别实现、截图和验收。
4. **逐状态对齐**：LISTEN 和 REPEAT 不以“能播放/能录音”为完成，必须覆盖成功、暂停、失败、切课和迟到事件。
5. **新旧来源同模型**：Bundle 与下载课程必须进入同一个 `CourseRepository`。
6. **本地先落盘**：进度事件和下载状态先持久化，再更新 UI。
7. **一次一个检查点**：每个检查点独立 build/test/commit；失败不叠加后续工作。
8. **不破坏现网**：除明确标注的 API 或静态课程发布步骤外，不部署 VPS，不改变 Web 生产行为。

## 4. 阶段依赖

```text
P0 基线冻结
 └─ P1 内容协议与 exporter
     └─ P2 iOS 工程与模块骨架
         └─ P3 Design System 与逐页 Shell
             └─ P4 内置课程与 LISTEN
                 └─ P5 进度、身份与离线同步
                     └─ P6 REPEAT
                         └─ P7 远程课程下载
                             └─ P8 全量回归与 TestFlight
                                 └─ P9 App Store Release Gate
```

P1 的 schema 与 fixtures 稳定后，P2 的纯模块骨架可开始；除此之外按关键路径顺序执行。P7 不提前混入 P4，以免基础播放问题和下载问题互相干扰。

## 5. 提交与验收约定

建议实施分支：`codex/ios-migration`。每个 `CP-*` 检查点对应一个可独立回滚的提交，提交前必须：

```bash
git diff --check
npm test
```

涉及 iOS 后增加：

```bash
swift test --package-path ios/Packages/<changed-package>
xcodebuild -project ios/WordLoop.xcodeproj \
  -scheme WordLoop \
  -destination '<verified-simulator-destination>' \
  -derivedDataPath ios/.derivedData build
```

`npm run lint` 当前已知有 4 个 React Compiler memoization 错误。迁移提交不得增加错误数量；除非任务明确要求，不把修复既有 Web lint 混入 iOS 提交。

每个 UI 检查点附带：Web 基准截图、iOS 同尺寸截图、差异记录、VoiceOver/Reduce Motion 手工结果。截图产物放到任务约定的 QA 目录，不进入 App Bundle。

## 6. P0：当前行为基线冻结

目标：把“保持当前实现”转成可以验证的清单，避免后续凭印象对齐。

### P0.1 建立基线报告

修改范围：

- 新增 `docs/ios-migration/baseline/`。
- 从 `app/page.tsx`、`app/globals.css`、`app/courses.ts` 和 API 提取事实，不改业务代码。

产物：

- 页面/面板清单：启动、主学习、课程抽屉、进度抽屉、完成/重练对话框。
- 状态清单：LISTEN、REPEAT、启动同步、课程完成、离线同步。
- 当前文案、六组色板、关键尺寸和动效时长。
- 当前 API 请求/响应 fixtures，删除用户名等不必要数据。
- 30 门课程、570 个单词、836 个句子、1,406 个音频的机器可读统计。

验证：`npm test`；对 `LISTEN` 和 `REPEAT` 各走一次完整人工流程。

退出条件：所有后续“保持一致”项能指向一个截图、fixture、测试或明确文字规则。

检查点：`CP-00 baseline evidence captured`。

## 7. P1：统一课程协议与 exporter

目标：让 Web 与 iOS 消费同一份生成数据，不在 Swift 中手抄课程。

### P1.1 固化 schema 与 fixtures

新增建议路径：

```text
content/schema/catalog.schema.json
content/schema/course.schema.json
content/schema/integrity.schema.json
content/fixtures/
```

工作：

- 将迁移规格中的 catalog/course/integrity 字段写成 JSON Schema。
- 固定稳定 ID、`contentVersion`、`minimumAppVersion`、状态枚举和路径安全规则。
- 准备一个单词课程、一个影视句子课程、一个 VOA 顺序课程 fixture。
- 准备坏哈希、重复 ID、路径逃逸、不兼容 schema 等失败 fixture。

验证：Schema 测试覆盖所有成功和失败 fixture。

### P1.2 实现 exporter

新增建议路径：

```text
scripts/export_course_packages.mjs
scripts/lib/course-export/
content/dist/                 # 生成目录
```

工作：

- 读取 `app/words.ts`、`app/courses.ts`、`app/data/*.json` 和 highlights。
- 合并运行时才有的 title、collection、practice order、audio path、highlight。
- 只输出可学习条目；排除原始素材路径与审计字段。
- 计算文件字节数、M4A 可读性和 SHA-256。
- 输出 catalog、课程 manifest、integrity 和 validation report。
- 使用临时目录生成，验证通过后再替换 `content/dist/`。

`content/dist/` 及 iOS 的 Generated resources 不提交 Git，避免把现有音频再保存一份。`scripts/bootstrap_ios_content.sh` 在 Package tests、Xcode build 和 CI 之前运行 exporter，再把规范化 manifest 与音频复制/硬链接到 `WordLoopContent` 的忽略目录。`scripts/verify_ios.sh` 必须先调用 bootstrap，保证全新 clone 的构建步骤确定且不会依赖开发者机器残留文件；不能依靠 Xcode 编译中途才生成 Package resources。

边界：不改现有课程文案、条目筛选或音频；exporter 只做确定性转换。

验证：连续运行两次产物哈希一致；30/570/836/1,406 数量一致；随机抽查 IELTS、Modern Family、VOA。

### P1.3 Web 最小适配决策点

先比较两种方式：

- Web 继续读取当前源，CI 只验证 exporter 产物等价。
- Web 改读规范化产物。

第一阶段默认选择风险较低的前者：不改 `page.tsx` 数据入口，只通过等价测试防止两份运行数据漂移。只有等价测试稳定后，才单独决定是否让 Web 读取 `content/dist`。

退出条件：规范化产物可由空目录一条命令重建；没有人工维护的 iOS 课程副本。

检查点：`CP-01 course contract and deterministic exporter`。

## 8. P2：iOS 工程与模块骨架

目标：建立可编译、可测试、依赖方向正确的原生工程。

### P2.1 核验本机工具链

- 实查 `xcodebuild -version`、`swift --version` 和可用模拟器。
- 把实际 destination 写入本地脚本或 CI 配置，不硬编码文档示例。
- 确认 deployment target 为 iOS 17，Swift Language Mode 为 Swift 6。

### P2.2 创建工程

创建迁移规格定义的 `ios/App`、`ios/Config`、`ios/Packages` 和 Tests。

App Target 只完成：

- `WordLoopApp` 启动。
- Debug/Release 配置读取。
- `AppContainer` 依赖注入。
- 一个无业务的 RootView。

### P2.3 创建本地 Packages

按顺序创建并测试：

1. `WordLoopCore`
2. `WordLoopNetworking`
3. `WordLoopContent`
4. `WordLoopDesignSystem`
5. `WordLoopAudio`
6. `WordLoopProgress`
7. `WordLoopRealtime`
8. `WordLoopFeatures`

每个 Package 首次提交只包含 manifest、最小 public API、依赖验证和 smoke test，不提前塞业务。

### P2.4 工程卫生

- 忽略 `.derivedData`、用户态 Xcode 文件、临时下载和生成缓存。
- `xcconfig` 不放密钥；Release API URL 可配置。
- 建立 `scripts/verify_ios.sh` 统一 Package tests + simulator build。

退出条件：全新 clone 在已安装 Xcode 环境中可以运行 exporter、Package tests 和模拟器 build；依赖图无环。

检查点：`CP-02 native project skeleton builds`。

## 9. P3：Design System 与逐页静态 Shell

目标：先完成视觉和交互容器，再接入业务状态。页面严格逐个验收。

### P3.1 Tokens 与基础组件

实现：`PosterPalette` 六套色板、字体、间距、边框、圆角、阴影、模糊、动效时长、触觉接口、Reduce Motion。

基础组件：Poster background/ring、MonoLabel、ModeSwitch、PosterButton、CourseCard、SideDrawer、ProgressTrack、ConfirmDialog、Waveform。

字体决策：先核验 Geist 字体许可和 App Bundle 体积；不能使用时输出截图比较并记录替代，不静默更换。

### P3.2 启动页

对齐用户名输入、START、PREPARING/SYNCING、错误位置、键盘和安全区。此步使用 fixture Store，不连接真实 API。

### P3.3 主学习页

对齐顶部导航、超大英文、中文/音标、重点表达、三态文字、底部控制和六色轮换。先覆盖短词、超长词、长句和中文换行。

### P3.4 课程抽屉

对齐从左进入、集合折叠、搜索、课程卡、当前态、完成次数、遮罩/滑动关闭。远程下载状态先用 fixture 展示，但不实现下载。

### P3.5 进度抽屉

对齐从右进入、课程上下文、统计、进度条、搜索和条目列表。

### P3.6 对话框与 REPEAT 卡片静态态

对齐完成、重练、错误确认；展示 REPEAT 所有静态视觉状态和文案。

每个子步骤单独截图验收；上一步未通过不进入下一页。

退出条件：静态 fixture 能展示所有页面和状态；小屏、Dynamic Type、VoiceOver、Reduce Motion 通过；无网络和音频依赖。

检查点：`CP-03 design system`，随后 `CP-04` 至 `CP-08` 每页一个提交。

## 10. P4：领域模型、内置课程与 LISTEN

目标：用首发内置课程完成离线学习主链路。

### P4.1 Core 模型与 Bundle source

- 实现 `CourseID`、`EntryID`、`CourseDescriptor`、`Course`、`CourseEntry`、`StudyMode`。
- 把 exporter 产物作为 `WordLoopContent` resources；不人工复制 JSON。
- 实现 manifest/integrity 解码和启动期轻量校验。
- 实现 `BundledCourseSource` 与 `CourseRepository` 第一版。

验证：30 门课程可枚举；抽样音频 URL 存在；内置数据与 exporter report 一致。

### P4.2 AudioPlayer

- 基于 AVFoundation 实现 load/play/pause/stop/finish/fail。
- 只持有当前和下一条的 prepared asset。
- 每次播放有 request token；迟到 completion 不能影响新条目。
- 正确处理 route change、耳机拔出和 App lifecycle。

### P4.3 StudyStore 与 LISTEN

- 课程选择、条目选择、random/sequential、文字三态。
- 手动前进、自动播放、500 ms 等待、错误重试。
- 切课/切模式取消旧播放并准备新条目。
- 此阶段用本地临时进度 adapter，P5 再替换真实 ProgressRepository。

### P4.4 完成与重练纯本地流程

先完成 UI 和状态流，不伪造服务端成功。所有临时 adapter 明确标注并在 P5 删除。

退出条件：飞行模式下 30 门内置课程均可打开；当前/下一片段行为与 Web 一致；快速切课、切模式、暂停和音频失败无串课。

检查点：`CP-09 bundled content repository`、`CP-10 audio player`、`CP-11 listen parity`。

## 11. P5：身份、进度与离线同步

目标：替换临时 adapter，接入当前 VPS 契约并保证离线幂等。

### P5.1 API DTO 与契约 fixtures

- 在 `WordLoopNetworking` 定义 progress GET/POST、select/reset/complete DTO。
- 用 P0 fixtures 测试解码/编码。
- 增加 Node 与 Cloudflare 路由的共享契约测试；不先改 API 形状。

### P5.2 SwiftData schema

实现 `StudyIdentity`、`ProgressRecord`、`ProgressEvent`、`CourseCompletionRecord/Event`、`CoursePreference`。定义 schema version 和迁移测试入口。

### P5.3 Progress Outbox

- 本地事务先写 event，再向 UI 发布派生值。
- 同一个 UUID 重试；服务端确认后归档/删除。
- 网络恢复、App active、用户手动重试触发 flush。
- 不并发发送同一用户/模式的冲突事件。
- 服务端值与 pending events 合并，上限 3。

### P5.4 Startup 与课程恢复

接入用户名规范化、最近课程、启动 restoring/syncing/ready/error。网络失败时允许使用本地已知身份和内置课程，不阻塞进入 App。

### P5.5 完成、次数与重练

接入 `clientEventId`、完成次数、resetCourse 和 pending 状态；删除 P4 临时 adapter。

退出条件：飞行模式学习 → 强杀 → 重开 → 联网同步不丢失、不重复；LISTEN/REPEAT 数据完全分离；Node/Cloudflare 契约一致。

检查点：`CP-12 progress contracts`、`CP-13 local persistence and outbox`、`CP-14 startup and completion parity`。

## 12. P6：REPEAT 原生迁移

目标：等价迁移当前稳定跟读状态机，不趁机调整评分。

### P6.1 评分 golden fixtures

- 从 Web 的 normalize、候选窗口、Levenshtein、句子 60% 覆盖规则提取匿名 fixture。
- 实现纯 Swift scorer。
- 要求 Swift 与 TypeScript 对每条 fixture 的 passed、score、matched 一致。

### P6.2 Realtime transport

- 用户主动进入 REPEAT 后请求麦克风权限。
- 用服务端 `/api/pronunciation-session` 建立会话，Key 不进 App。
- 解析 transcription lifecycle 和 item IDs。
- 隔离 transport event 与 UI state。

WebRTC iOS 依赖的具体引入方式在此任务开始前写 ADR：优先官方/可审计的预编译产物或锁定版本依赖；不得把未锁版本的二进制直接拖入工程。

### P6.3 RepeatSessionController

实现 `idle/connecting/ready/playing/armed/speaking/scoring/passed/retry/paused/recoverableError`。

硬性安全条件：

- 每 turn 递增 `turnID`。
- 播放结束前不能 armed。
- 事件同时匹配 turn、item ID 和 armed。
- 切课、切模式、暂停、后台、重试使旧 turn 失效。
- 每阶段独立超时；恢复不能复用旧 transcript。

### P6.4 UI 与系统中断

接入波形、提示、成功/失败音、暂停、设置跳转。覆盖权限拒绝、Audio Session 中断、耳机变化、网络断开、后台和回前台。

退出条件：固定 fixture 与 Web 一致；快速切课无自动误过关；至少两台真机完成弱网、权限和连续 20 turn 测试。

检查点：`CP-15 scoring parity`、`CP-16 realtime transport`、`CP-17 repeat state machine and UI`。

## 13. P7：远程课程与下载交互

目标：在不更新 App 的前提下发布兼容课程，并下载后离线学习。

### P7.1 本地/staging catalog 服务

- 先用本地 HTTP fixture server 验证协议。
- 再在 VPS 建 staging 静态目录和 catalog，不直接改 production catalog。
- 支持 HTTPS、ETag、不可变版本路径、正确 Content-Type 和 Range 请求。
- 部署步骤补充到 VPS runbook；验证 catalog、manifest 和一个音频的 HTTP 状态与缓存头。

阶段门：此处确认 production catalog 最终域名。未确认时只做 staging。

### P7.2 RemoteCatalogClient

- 后台刷新、ETag/304、本地 snapshot、schema 和 minimumAppVersion。
- 网络失败继续返回 Bundle + 已安装课程。
- available/hidden/retired 合并规则。

### P7.3 CourseInstallation 持久化

实现安装版本、路径、大小、状态、校验时间、catalog ETag 和后台 task identifier。启动时做任务与记录 reconciliation。

### P7.4 CourseDownloadManager

- 用户确认、蜂窝/空间提示。
- staging 目录、最大并发 3、总字节进度、后台恢复。
- 路径安全、大小、SHA-256、原子安装。
- 更新失败保留旧版；删除保留进度；排除备份。
- 删除当前课程前先切换到安全课程并停止播放器。

### P7.5 课程抽屉状态接入

按规格逐项接入：`BUILT IN`、`DOWNLOADED`、`DOWNLOAD`、`DOWNLOADING`、`PREPARING`、`UPDATE`、`OFFLINE`、`TRY AGAIN`、`FREE UP SPACE`、`UPDATE APP`。

下载完成不抢占当前学习；关闭抽屉后继续下载；Reduce Motion 和 VoiceOver 同步验收。

### P7.6 发布流水线

- exporter validation 通过才允许上传。
- 先上传不可变版本，再原子更新 catalog。
- staging 真机冒烟后才更新 production。
- 回滚通过 hidden/descriptor 版本处理，不覆盖同版本文件。

退出条件：远端新增课程无需新 App；断网、404、坏哈希、空间不足、版本过低、强杀恢复、更新失败和删除全部通过；已安装课程离线 LISTEN/REPEAT 可用。

检查点：`CP-18 staging content service`、`CP-19 catalog and installations`、`CP-20 downloader`、`CP-21 download UX`、`CP-22 publishing pipeline`。

## 14. P8：全量回归与 TestFlight

目标：把“功能完成”推进到“可真实试用”。

### P8.1 自动回归

- 所有 Package unit tests。
- App integration tests。
- UI tests：启动、LISTEN、REPEAT、课程/进度抽屉、完成重练、下载更新删除。
- Web `npm test` 和 API contract tests。

### P8.2 视觉与无障碍回归

- 支持的最小/主流/大屏 iPhone。
- 默认与最大 Dynamic Type。
- VoiceOver 顺序、modal focus、按钮语义。
- Reduce Motion、深色配色组、中文换行。
- 每个页面和关键状态与 P0 Web 基准对比。

### P8.3 性能与稳定性

记录冷启动、打开课程抽屉、切课、首音频、下载和校验的真机指标。哈希和大 JSON 解析不得阻塞主线程。执行长时 LISTEN、连续 REPEAT、后台下载和低存储测试。

### P8.4 TestFlight

- 配置 Bundle ID、Team、签名、版本、图标、用途说明和 Privacy Manifest。
- Archive Release，检查 Bundle 不含密钥、原始媒体、中间文件、staging URL。
- 内部 TestFlight 验收并记录设备、系统版本和问题。

退出条件：迁移规格完成定义 1–7 全部满足；仅剩正式内容权利和 App Store 元数据门槛。

检查点：`CP-23 regression baseline`、`CP-24 TestFlight candidate`。

## 15. P9：App Store Release Gate

此阶段不是技术迁移默认自动执行，开始前需要正式发布授权。

确认：

- 《摩登家庭》等内容是否进入正式 Bundle/catalog。
- App 名称、Bundle ID、开发者团队、版本号。
- 隐私政策、支持 URL、年龄分级、审核备注。
- App Privacy、麦克风、数据保留和账号说明。
- Production API/catalog、监控和回滚联系人。

若某内容未通过权利检查，通过生成配置从 Release Bundle/catalog 排除，不改学习业务代码。完成 App Store Connect 上传后，保留提交版本、审核材料和回滚记录。

检查点：`CP-25 App Store submission candidate`。

## 16. 关键风险与控制

| 风险 | 控制 |
| --- | --- |
| SwiftUI 再次形成巨型页面 | Package 边界、子 Store、单页检查点、禁止全局 HomeViewModel |
| Web/iOS 课程漂移 | 确定性 exporter、数量/哈希报告、无人工 iOS 副本 |
| 音频迟到回调串课 | playback token、切换时取消、状态机测试 |
| Realtime 迟到事件误过关 | turnID + itemID + armed 三重门控 |
| 离线重试重复累计 | 本地事务、稳定 UUID、服务端幂等、超时复用事件 |
| 下载损坏旧课程 | staging、全量哈希、原子安装、更新失败保留旧版 |
| 远端不可用阻塞启动 | catalog 后台刷新、snapshot、Bundle/installed fallback |
| VPS 与 D1 契约漂移 | 共享 DTO fixtures 和双实现契约测试 |
| 新交互破坏风格 | 复用 CourseDrawer/tokens、逐状态截图、无新商店页 |
| 正式内容权利未定 | Release 生成配置与独立 Gate，不耦合业务代码 |

## 17. 人工确认门

实施过程中只在以下节点停下确认：

1. `CP-03` 前：字体许可或替代方案的视觉对比。
2. `CP-18` 前：staging/production catalog 域名和 VPS 静态目录。
3. `CP-24` 前：Bundle ID、Team、App 名称与 TestFlight 权限。
4. `CP-25` 前：正式首发内容权利、隐私和商店元数据。

其余已经在迁移规格中锁定的决策，不在实施中反复询问。

## 18. 第一张任务卡边界

Plan 获得确认后，只生成第一张任务卡：**P0.1 当前行为与内容基线冻结**。

第一张任务卡不得创建 iOS 工程或修改业务逻辑，只负责：

- 建立基线目录和报告格式。
- 自动统计课程、条目、音频、色板和状态文案。
- 记录现有 build/test/lint 结果。
- 产出 LISTEN/REPEAT 与页面/面板验收矩阵。
- 更新 handoff 并独立提交文档与基线工具。

下一张 P1 任务卡必须根据 P0 实际发现的字段、数量和行为生成。
