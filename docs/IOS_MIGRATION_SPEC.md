# WordLoop 原生 iOS 迁移规格

状态：已确认，实施 Plan 已建立

更新日期：2026-07-15

适用仓库：`/Users/linpeiwen/knightspace/wordloop`

目标平台：iPhone，iOS 17 及以上

实施路线图：[`plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

## 1. 目的与约束

本文是 WordLoop 从当前 Web 技术栈迁移到原生 iOS 技术栈的实现依据。迁移不是产品重做：现有课程、学习规则、交互节奏、视觉风格和服务端能力必须保留；只有远程课程包属于为后续扩展新增的产品能力。

实现人员不得把当前 `app/page.tsx` 的集中式状态原样搬进单个 SwiftUI View，也不得借技术迁移重新设计学习流程。遇到本文未定义且会影响产品行为的选择，应先补充规格并确认，再编码。

## 2. 已锁定决策

1. iOS 工程放在当前仓库的 `ios/` 下，Web、课程生产脚本、服务端与 iOS 共存。
2. 使用原生 SwiftUI、Swift 6、Swift Concurrency、SwiftData、AVFoundation、URLSession 和 WebRTC；不使用 WebView、React Native、Flutter 或过渡壳。
3. 使用完整的本地 Swift Package 模块化结构，不把业务继续堆在 App Target。
4. 首发效果包内置当前全部 30 门课程，包括 5 门《摩登家庭》、24 门 VOA 和 IELTS 高频词。
5. 课程采用混合架构：首发内容内置；新增或更新课程由远端发布，用户下载后离线使用。
6. Web 与 iOS 不维护两份人工课程数据。根目录内容生产流程输出平台无关产物，再由两端消费。
7. 正式 App Store 上线前单独执行内容权利检查；该检查不阻塞当前技术迁移，但属于 Release Gate。
8. 当前 VPS Node API + SQLite 继续作为第一阶段真实后端；Cloudflare/D1 实现保留并做契约一致性验证。

## 3. 范围

### 3.1 必须保持一致

| 现有能力 | iOS 要求 |
| --- | --- |
| 启动用户名 | 保留用户名进入、最近课程恢复和进度同步；本次不引入账号密码或 OAuth |
| 课程选择 | 保留集合折叠、搜索、当前课程、完成次数和完成后重练 |
| `LISTEN` | 保留当前片段播放、下一片段预备、手动前进和自动连续播放 |
| `REPEAT` | 保留“播放原音 → 等待跟读 → 识别 → 通过/重试 → 自动前进” |
| 文字显示 | 保留全文、重点表达和隐藏三种显示方式 |
| 学习进度 | `listen` 与 `repeat` 分开，每项累计 3 次掌握，支持“太简单” |
| 离线进度 | 本地先写、联网后用幂等事件同步，杀进程或切网不丢失 |
| 视觉 | 保留海报式全屏构图、动态配色、超大英文、衬色圆环、细边框和克制动效 |
| 无障碍 | 补齐 Dynamic Type、VoiceOver、Reduce Motion 和足够触控区域 |

### 3.2 允许新增

- 远程课程目录刷新。
- 课程下载、进度、失败重试、更新、删除和磁盘空间提示。
- App 进入后台后继续下载；再次启动后恢复任务或准确显示失败。
- 下载课程的本地版本、校验状态和空间管理。

### 3.3 不在本轮范围

- iPad 专属布局、macOS、watchOS、visionOS。
- 订阅、内购、付费课程。
- 新账号体系或音素级发音评分；通过阈值仅采用已确认的 Web、VPS 与 iOS 统一 15 分决定，不继续扩展评分规则。
- 从远端下发 Swift、JavaScript、HTML 小程序或其他可执行逻辑。
- 重写现有 Web；Web 只做共享课程产物所需的最小适配。

## 4. 当前基线

`app/page.tsx` 超过 2,100 行，同时管理课程选择、播放、跟读、定时器、WebRTC、进度、离线事件、面板和主界面；约第 460 行开始集中声明状态。这是迁移时必须拆开的核心，不是可照搬的架构。

- 30 门课程，1,406 个 M4A 音频，`public/` 总体约 34 MB。
- 默认课程 `modern-family-s01e01`，默认模式 `repeat`。
- 音频按片段加载，只预备下一片段，不一次加载整门或全部课程。
- 跟读主状态为 `playing → speak → speaking → scoring → passed/retry`，并用 turn ID、armed 状态和 Realtime item ID 隔离迟到事件。
- 课程数据分散在 JSON、`app/words.ts`、`app/courses.ts` 和 highlights TypeScript 文件。
- VPS 真实 API 是 `/api/progress` 与 `/api/pronunciation-session`。

## 5. 目标架构

```text
课程制作脚本
    ▼
规范化课程产物（catalog + manifest + M4A + checksums）
    ├── Web 构建读取
    ├── BundledCourseSource（首发内置）
    └── 远端静态目录/CDN
             ▼
       RemoteCatalogClient
             ▼
       CourseDownloadManager
             ▼
       DownloadedCourseSource ──┐
                               ▼
BundledCourseSource ─────> CourseRepository ──> Feature Stores ──> SwiftUI
                               ├── AudioPlayer
                               ├── ProgressRepository ──> VPS API
                               └── PronunciationSession ──> VPS API/OpenAI Realtime
```

边界原则：

- View 只渲染状态并发送用户意图，不直接访问文件、网络、SwiftData、音频播放器或 WebRTC。
- Feature Store 负责单一页面或流程，不拼接远端 URL。
- Repository 统一数据来源；上层不知道课程来自 Bundle 还是下载目录。
- Service 只负责一种基础能力，不持有跨功能 UI 状态。
- 课程内容只能改变数据，不能改变原生功能和导航。

## 6. 工程与模块

```text
ios/
├── WordLoop.xcodeproj
├── App/
│   ├── WordLoopApp.swift
│   ├── AppContainer.swift
│   ├── AppEnvironment.swift
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy
│   └── Assets.xcassets
├── Config/{Debug,Release,Shared}.xcconfig
├── Packages/
│   ├── WordLoopCore/
│   ├── WordLoopContent/
│   ├── WordLoopDesignSystem/
│   ├── WordLoopAudio/
│   ├── WordLoopNetworking/
│   ├── WordLoopProgress/
│   ├── WordLoopRealtime/
│   └── WordLoopFeatures/
└── Tests/{AppIntegrationTests,AppUITests}/
```

| 模块 | 职责 |
| --- | --- |
| `Core` | Course、CourseEntry、StudyMode、稳定 ID、错误、纯评分逻辑 |
| `Content` | 课程源、catalog、manifest 校验、下载、SwiftData 安装记录 |
| `DesignSystem` | 色板、字体、间距、按钮、面板、卡片、波形、动效 |
| `Audio` | 当前片段播放、下一片段预备、播放事件、Audio Session |
| `Networking` | APIClient、DTO、重试、环境配置 |
| `Progress` | 本地进度、Outbox、幂等同步、服务端合并 |
| `Realtime` | 麦克风、WebRTC、转写、turn 隔离和超时 |
| `Features` | 启动、学习、课程抽屉、进度抽屉、完成/重练的 Store 与 View |
| App Target | 依赖注入、生命周期、配置、根导航 |

依赖只能向下：`Features → Content/Audio/Progress/Realtime/DesignSystem → Networking/Core`。`Core` 不依赖业务 Package；功能模块不能相互导入成环。

## 7. `app/page.tsx` 拆分映射

| 当前责任 | 目标组件 | 核心状态 |
| --- | --- | --- |
| 用户名、启动恢复 | `StartupStore`、`StartupView` | idle/restoring/syncing/ready/error |
| 当前课程与条目 | `StudyStore`、`CourseRepository` | courseID/itemID/mode/textVisibility |
| LISTEN | `ListenSessionController`、`AudioPlayer` | idle/loading/playing/paused/failed |
| REPEAT | `RepeatSessionController` | 第 11 节状态机 |
| 课程面板 | `CourseLibraryStore`、`CourseDrawer` | 集合、搜索、安装状态 |
| 远程课程 | `RemoteCatalogClient`、`CourseDownloadManager` | 第 10 节状态机 |
| 进度面板 | `ProgressStore`、`ProgressDrawer` | 确认值 + 待同步值 |
| 离线队列 | `ProgressOutbox` | queued/sending/acknowledged/failed |
| 完成与重练 | `CourseCompletionStore` | completion count/reset request |
| 视觉 | `PosterTheme`、Design tokens | background/ink/accent/reduceMotion |

禁止创建持有全部状态的 `HomeViewModel`；根 `AppStore` 只持有生命周期和子 Store 引用。

## 8. 统一课程协议

### 8.1 生成目录

```text
content/dist/
├── catalog.json
├── courses/<course-id>/<content-version>/
│   ├── course.json
│   ├── integrity.json
│   └── audio/*.m4a
└── validation-report.json
```

`content/dist/` 是脚本产物，不作为人工编辑源。新增 exporter 把 `app/words.ts`、课程 JSON、highlights 和注册元数据合并为规范化产物。

### 8.2 Catalog 合同

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-15T00:00:00Z",
  "courses": [{
    "id": "modern-family-s01e01",
    "collectionId": "modern-family",
    "title": "Modern Family · S01E01",
    "subtitle": "Pilot",
    "description": "...",
    "kind": "sentence",
    "practiceOrder": "random",
    "contentVersion": 1,
    "minimumAppVersion": "1.0.0",
    "manifestURL": "https://example/courses/modern-family-s01e01/1/course.json",
    "manifestSHA256": "...",
    "downloadSize": 12345678,
    "status": "available"
  }]
}
```

- `id` 创建后永久稳定，不能用标题替代。
- `contentVersion` 只递增；同版本文件不可原地替换。
- App 版本过低时显示“需要更新 App”，不得尝试解析。
- 不支持的 catalog schema 安全失败，继续使用内置和已安装课程。
- `status` 第一版只允许 `available/hidden/retired`；`retired` 不强删已安装内容。

### 8.3 Course 合同

```json
{
  "schemaVersion": 1,
  "id": "modern-family-s01e01",
  "collectionId": "modern-family",
  "contentVersion": 1,
  "title": "Modern Family · S01E01",
  "subtitle": "Pilot",
  "description": "...",
  "kind": "sentence",
  "practiceOrder": "random",
  "entries": [{
    "id": "s01e01-0003",
    "text": "Phil, would you get them?",
    "translation": "菲尔 把他们叫下来好吗",
    "phonetic": null,
    "highlights": ["get them"],
    "audio": "audio/s01e01-0003.m4a",
    "durationMilliseconds": 1700
  }]
}
```

运行时只带可学习条目；原始素材路径、未入选字幕和制作审计字段不进入 App。`entry.id` 在课程内永久稳定，更新文字或音频不得改变进度身份。

### 8.4 完整性

`integrity.json` 记录 `course.json` 和每个音频的相对路径、字节数与 SHA-256。拒绝 `..`、绝对路径、软链接和未声明文件。安装成功必须同时满足：schema 可解析；课程 ID/版本一致；音频引用全部声明；大小和哈希匹配；至少一个条目；ID 唯一且时长为正。

## 9. 混合存储

### 内置课程

- 当前全部课程作为 `WordLoopContent` Package resources 随 App 安装。
- Bundle 只读、不可删除、不依赖首次联网。
- 内置和下载内容使用同一 manifest 与解析逻辑。
- UI 显示 `BUILT IN`，不提供删除。

### 下载课程

- 正式目录：`Application Support/WordLoop/Courses/<id>/<version>/`。
- 暂存目录：`Application Support/WordLoop/Staging/<download-id>/`。
- 不放 `Documents`；课程目录排除 iCloud/iTunes 备份。
- SwiftData 只存 catalog 快照、版本、状态、路径、大小和时间，不存 M4A 二进制。
- 安装采用“暂存 → 校验 → 原子切换”；更新失败继续使用旧版本。
- 删除文件和安装记录，不删除学习进度。

`CourseRepository` 优先选择兼容且版本更高的下载内容，否则使用 Bundle。下载文件损坏则标记 `corrupted` 并回退内置版本；catalog 不可用不影响已安装内容。

## 10. 远程课程下载

### 10.1 状态机

```text
bundled
remoteAvailable → preparing → downloading → verifying → installed
      ▲                │             │            │
      └── retry ←── failed ←─────────┴────────────┘

installed → updateAvailable → downloading → installed
installed → remove → remoteAvailable
```

持久化状态仅为 `notInstalled/downloading/installed/failed/corrupted`。App 重启后必须关联 URLSession 后台任务；关联不到的 `downloading` 转为诚实、可重试的失败状态。

### 10.2 算法

1. 拉取 catalog 并校验 schema。
2. 用户明确点击下载；蜂窝网络或空间不足时先提示。
3. 下载并校验 `course.json`、`integrity.json`。
4. 可用空间至少是剩余下载量的 1.5 倍，并额外保留 50 MB。
5. 后台 `URLSession` 下载音频，最大并发 3；已校验文件可复用。
6. 按总字节持久化进度。
7. 全量 SHA-256 通过后写安装记录并原子切换版本。
8. 清理暂存和不用的旧版本；更新失败保留旧版。

第一阶段静态 catalog、manifest 和音频可由当前 VPS/Caddy 承载；客户端只依赖 HTTPS URL，未来切换对象存储/CDN 不改 App 协议。catalog 支持 `ETag/If-None-Match`，启动后后台刷新但不阻塞学习。

### 10.3 新交互

远程课程复用现有左侧 `CourseDrawer`，不新增商店 Tab，不改变主海报学习页。

| 状态 | 卡片显示 | 行为 |
| --- | --- | --- |
| 内置 | `BUILT IN` | 立即切换 |
| 已下载 | `DOWNLOADED` | 立即切换 |
| 可下载 | `DOWNLOAD · 12 MB`，accent 下载图标 | 展开底部确认区，不立即耗流量 |
| 下载中 | 2 px accent 进度条；`DOWNLOADING · 42%` | 后台继续；`CANCEL` 二次确认 |
| 校验中 | `PREPARING…`，完成态进度条轻微呼吸 | 暂不可进入，可关闭抽屉 |
| 可更新 | `UPDATE · 6 MB` | 主卡进旧版，独立按钮更新 |
| 离线未下载 | `OFFLINE`，连接网络后可下载 | 不弹通用错误框 |
| 失败 | accent 色 `TRY AGAIN` + 短原因 | 重试，详细错误只写日志 |
| 空间不足 | `FREE UP SPACE` | 同风格对话框说明所需空间 |
| App 过低 | `UPDATE APP` | 说明所需版本 |

视觉规则：

- 继续使用 `background/ink/accent`，不引入系统蓝作为主色。
- 状态为等宽 9–10 pt、较大字距、全大写。
- 沿用 13 pt 圆角课程卡、1 px 淡边框；选中态用 accent 边框和浅外圈。
- 下载/删除确认沿用现有重练对话框：模糊遮罩、16 pt 圆角、短文案、描边次按钮、accent 实底主按钮。
- 关闭抽屉后后台下载，不在学习页放持续悬浮条。
- 下载完成只给轻触觉反馈，不抢占当前课程。
- Reduce Motion 下取消呼吸和滑入动画。
- `REMOVE DOWNLOAD` 为低强调度操作；删除前说明大小和“学习进度会保留”。内置课程无删除入口。

删除当前正在学习的下载课程时，先退出该课程并选择最近可用课程，再删文件，避免播放器引用已删除 URL。

## 11. 学习状态机

### LISTEN

```text
idle → loading → playing → completed → waiting(500 ms) → next
              ↘ paused
loading/playing → failed → retry/manual next
```

- `AudioPlayer` 只持有当前和下一条，保持 Web 的懒加载。
- 下载课程只播放本地 URL，不边播边下载。
- 切课、切模式、后台或删除课程必须取消旧完成回调。
- 锁屏/控制中心不是首发必需，若新增需单独确认。

### REPEAT

```text
idle → connecting → ready → playing → armed → speaking → scoring
                                       ├──────────────→ retry
                                       └──────────────→ passed → next
任一活动态 → paused
任一权限/网络错误 → recoverableError
```

| 内部状态 | 标签 | 提示 |
| --- | --- | --- |
| connecting | `CONNECTING` | 正在准备麦克风 |
| ready | `READY` | 听完示范后开始跟读 |
| playing | `LISTENING` | 先听一遍标准发音 |
| armed/speaking | `SPEAKING` | 请清晰地跟读 / 正在听你发音 |
| scoring | `CHECKING` | 正在分析这次发音 |
| passed | `GREAT` | 这次发音通过了 |
| retry/error | `TRY AGAIN` | 请再读一次 |
| paused | `PAUSED` | 准备好后继续练习 |

每次生成递增 `turnID`。播放结束后才 armed；转写必须同时匹配当前 `turnID`、Realtime item ID 和 armed 状态。切课、切模式、暂停、后台和重试都使旧 turn 失效。评分以纯 Swift 等价迁移和 golden fixtures 为基础；按 2026-07-24 产品决定，Web、VPS 与 iOS 的通过阈值统一为 15 分，句子 60% 覆盖率不变。

首次进入 REPEAT 且用户主动开始时才请求麦克风。拒绝后页面保持可读，显示 `OPEN SETTINGS`；LISTEN 仍可用。Release 必须包含用途说明和 Privacy Manifest 检查。

## 12. 进度与离线同步

SwiftData 至少包含：`StudyIdentity`、`ProgressRecord`、`ProgressEvent`、`CourseCompletionRecord/Event`、`CoursePreference`、`CourseInstallation`、`CatalogSnapshot`。

- UI 值 = 服务端确认值 + 本地未确认幂等事件，上限 3。
- 先持久化事件，再更新 UI。
- 同步重试复用同一个 UUID；超时不能生成新事件。
- `listen` 与 `repeat` 永远分开。
- 课程删除、更新或暂时不可用时保留进度。
- 第一阶段保持当前 API，新增 DTO 契约测试同时跑 Node 与 Cloudflare 路由。

账号体系不在本次改变；同名用户名恢复继续被视为便捷标识，不视为安全身份。

## 13. 视觉与原生适配

首版迁移六组色板：

```text
#F3F0E8 / #1E3A34 / #D4562B
#F5D547 / #282044 / #E85B44
#DFECFF / #183565 / #F06449
#F8D9DF / #4B1934 / #157D6A
#D8EEE3 / #173B33 / #C84E34
#26233E / #F4EAD7 / #F3BD4F
```

- 大标题与等宽状态字体优先打包匹配当前 Geist 的字体资源；若授权或包体不允许，先截图对比再选系统替代。
- 保持全屏背景、装饰圆环、顶部 `COURSE / mode / PROGRESS`、底部控制关系。
- 课程与进度保留左右抽屉，支持滑动/遮罩关闭和 VoiceOver modal 语义。
- Dynamic Type 下正文、对话框和中文释义缩放；超大英文用范围缩放而非截断。

每页/每面板保存同尺寸 Web 与 iOS 截图，对比信息层级、字体换行、色板、边框阴影、动效方向、LISTEN/REPEAT 状态、小屏、VoiceOver 和 Reduce Motion。

## 14. 网络、安全与配置

- Debug/Staging/Release 用 `.xcconfig` 注入 API Base URL、catalog URL 和 flags。
- 正式环境只走 HTTPS，Release 不允许任意 ATS 例外。
- OpenAI API Key 只在服务端，绝不进 Bundle、日志或课程包。
- 远端课程按 schema 白名单解析，不允许远端 UI 配置、脚本或 URL Scheme。
- 首版限制单课程 250 MB、单音频 20 MB；超限视为 catalog 错误。
- 日志只记课程 ID、版本、HTTP 状态和错误类别，不记用户名、转写全文或签名 URL 参数。

## 15. 实施阶段与退出标准

### Phase 0：基线与 exporter

交付 iOS 骨架、Package 图、schema、exporter、30 门课程导出物。

退出：30 门/1,406 音频数量一致；manifest、highlight、路径、哈希通过；Web 测试不退化；没有第二份人工课程数据。

### Phase 1：Design System 与静态 Shell

交付启动页、主海报、课程/进度抽屉和对话框的原生静态实现。

退出：六套色板、iPhone 截图、抽屉手势、Dynamic Type、VoiceOver、Reduce Motion 人工验收；fixture 不伪装为业务完成。

### Phase 2：内置课程与 LISTEN

交付 Bundle source、Repository、AudioPlayer、选课、文字三态、手动/自动播放。

退出：全部内置课程离线可开；当前/下一片段行为一致；切课/切模式无迟到播放。

### Phase 3：进度与同步

交付 SwiftData、Outbox、VPS adapter、用户名恢复、完成次数和重练。

退出：飞行模式、强杀、恢复网络和重复响应不丢失或重复累计；两套 API 契约一致。

### Phase 4：REPEAT

交付 Audio Session、权限、WebRTC、Realtime、转写聚合、评分和状态机。

退出：权限拒绝、中断、后台、断网、迟到事件、快速切课和重试有测试；golden fixtures 与 Web 一致。

### Phase 5：远程课程

交付 catalog、安装记录、后台下载、校验、安装、更新、删除和抽屉状态。

退出：无需发 App 即可新增课程；杀进程后恢复或诚实失败；断网/404/校验失败/空间不足/版本不兼容不破坏旧内容；删除保留进度；新增交互通过视觉和无障碍检查。

### Phase 6：回归与 App Store

交付 UI 自动化、性能基线、隐私清单、权限文案、图标、版本、发布清单和 TestFlight。

退出：产品矩阵通过；主线程无文件哈希或大 JSON 卡顿；Release 不含密钥、原始媒体、中间文件或 Debug URL；正式上线内容权利决策完成。

## 16. 测试

- 单元：schema、版本、路径安全、SHA-256、Repository、LISTEN/REPEAT/Outbox 状态机、评分 golden fixtures。
- 集成：Bundle 与下载课程等价、URLProtocol 断网/404/304/坏哈希、SwiftData 强杀恢复、staging API 冒烟。
- UI：启动恢复、模式切换、文字三态、课程搜索、完成重练、下载/更新/删除/离线/空间不足、麦克风拒绝。

命令形态（模拟器名称实施时实查）：

```bash
swift test --package-path ios/Packages/<PackageName>
xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/.derivedData build
xcodebuild test -project ios/WordLoop.xcodeproj -scheme WordLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 17. 课程发布与 Release Gate

课程发布：按现有指南制作与抽听 → exporter → CI 校验 → 上传不可变版本 → staging 真机下载/离线/REPEAT 冒烟 → 更新 production catalog。故障时隐藏 catalog 项或回退 descriptor，不覆盖同版本文件。

App Store Gate：

- 权利与来源清单，尤其影视内容。
- App Privacy、Privacy Manifest、麦克风用途文案。
- 年龄分级、出口合规、支持 URL、隐私政策、审核备注。
- 首发内置体积与蜂窝下载提示。
- 证明远端 catalog 只提供内容，不下发原生功能代码。

## 18. 完成定义

1. 全部可发布课程和功能在真机原生运行，不依赖 WebView。
2. 逐页面/逐状态视觉与交互验收通过，不只是编译成功。
3. `app/page.tsx` 的责任已模块化，不形成新的巨型 SwiftUI 文件或全局 Store。
4. 内置课程离线可用，远程课程可下载、更新、删除并离线使用。
5. 进度在离线、强杀和重试下幂等一致。
6. REPEAT 的权限、中断、迟到事件和恢复经测试。
7. Web 与 iOS 使用同一规范化课程产物。
8. TestFlight 真机验收完成，Release Gate 没有未记录阻塞项。

## 19. 分阶段确认项

这些不阻塞 Phase 0–4，也不改变混合架构：

- Phase 5 前确认 production catalog 最终域名；首阶段可用当前 VPS。
- Phase 6 确认 Bundle ID、App 名称、开发者团队和隐私政策 URL。
- App Store 正式包前确认《摩登家庭》等内容的权利处理。
- 锁屏/控制中心后台音频是独立产品决策，不能从“后台下载”自动推导。
