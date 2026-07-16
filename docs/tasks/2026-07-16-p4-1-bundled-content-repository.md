# P4.1 iPhone 内置课程领域模型与 Bundle Repository

状态：任务卡已锁定，待开发

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游任务：[`2026-07-16-p3-6-completion-dialog-repeat-states.md`](2026-07-16-p3-6-completion-dialog-repeat-states.md)，P0–P3.6 均已独立复核 PASS

课程合同：[`2026-07-15-p1-course-contract-exporter.md`](2026-07-15-p1-course-contract-exporter.md) 与 `content/schema/*.schema.json`

## 目标

完成 CP-09：把 P1 exporter 生成的当前 30 门、1,406 个音频课程包真正作为 `WordLoopContent` 的只读 Swift Package resources 随 iPhone App 打包，在 `WordLoopCore` 落正式课程领域类型，在 `WordLoopContent` 落严格解码、Bundle source、轻量/完整校验与第一版 `CourseRepository`。完成后正式内容必须“可枚举、可打开、可校验、可解析到本地音频 URL”，但现有 P3 Startup、StudyShell、CourseDrawer、ProgressDrawer 与 CompletionDialog 仍完全使用已通过的内存 fixture；本卡不接 UI、不播放音频、不写进度、不访问网络。

## 已锁定机器真值与冲突消解

- 当前唯一内容源仍是 Web 注册表、manifest/highlights 与原始 M4A；`scripts/export_course_packages.mjs` 生成 `content/dist/`，不得在 Swift 中手写第二份课程或数量表。
- exporter 当前真值为 3 个集合、30 门课程、570 个 word entries、836 个 sentence entries、1,406 个 M4A、32,700,838 bytes；默认课程为 `modern-family-s01e01`。
- 当前 1 门 word 课程为 `random`；全部 29 门 sentence 课程为 `sequential`。迁移 spec 中把 Modern Family 示例写成 `random` 是旧示例，本卡以 P1 已通过 schema、exporter 和真实 catalog 为准，不改产物顺序。
- `scripts/bootstrap_ios_content.sh` 目前只复制到被忽略的 `ios/Generated/WordLoopContent/`；`WordLoopContent/Package.swift` 目前没有 resources。P4.1 必须增加 Package target 内的被忽略 resource mirror，并在 SwiftPM/Xcode 解析 Package 之前生成。
- Package resource mirror 只包含 `catalog.json` 和 `courses/`。`validation-report.json` 含 `app/data/...`、source manifest ID 差异和制作审计信息，只用于仓库/CI 等价验证，不进入 App Bundle。
- `content/dist/`、`ios/Generated/` 与 Package resource mirror 都是可重建且不提交的产物。App 产品只允许打包 Package mirror 这一套课程资源；中间生成目录不能作为第二个 App resource 被重复嵌入。
- 继续只交付 iPhone App。各 Swift Package 的 `.macOS(.v14)` 仅用于本机 `swift test` host 构建，不代表 macOS/桌面产品；不得增加 macOS/iPad/Catalyst target、View 或专属交互。

## 正式领域模型

### 1. `WordLoopCore` 强类型 ID 与枚举

把骨架 marker 保留并新增独立文件，至少实现：

- `CourseID`、`EntryID`、`CourseCollectionID`：`RawRepresentable<String>`、`Codable`、`Hashable`、`Sendable`、`CustomStringConvertible`；只有符合 `^[a-z0-9]+(?:-[a-z0-9]+)*$` 的值可构造/解码，非法值 fail closed，不能把标题当 ID。
- `StudyMode`: raw value 只能为 `listen/repeat`。
- `CourseKind`: `word/sentence`。
- `CoursePracticeOrder`: `random/sequential`。
- `CourseAvailability`: `available/hidden/retired`。

`WordLoopCore` 不依赖任何其他业务 Package，不导入 SwiftUI、AVFoundation、Networking、Progress 或 Realtime。

### 2. Catalog 与课程模型

领域类型必须为值语义、`Equatable`、`Sendable`，并按需要支持 `Codable`：

```text
CourseCatalog
  schemaVersion
  generatedAt
  defaultCourseID
  collections: [CourseCollectionDescriptor]
  courses: [CourseDescriptor]

CourseCollectionDescriptor
  id / label / title / subtitle

CourseDescriptor
  id / collectionID / title / subtitle / description
  kind / practiceOrder / contentVersion / minimumAppVersion
  manifestLocation / manifestSHA256 / downloadSize / availability

Course
  descriptor
  entries: [CourseEntry]

CourseEntry
  id / text / translation? / phonetic? / highlights
  audioURL / durationMilliseconds
```

- `CourseEntry.audioURL` 是 source 校验后得到的本地 `file:` URL；Core 不暴露 Bundle 目录规则，P4.2 可直接消费 URL。
- `translation`、`phonetic` 只保留 manifest 的 optional/null 语义；不为 sentence/word 发明 schema 之外的强制字段。
- `highlights` 保留 exporter token 原文，不在 Core 转 Character range；P4.3 才复用现有 `StudyShellItem.highlightRanges` 做展示映射。
- `minimumAppVersion` 保留规范 SemVer 字符串并在 Content 校验；本卡不实现远端兼容/升级 UI。
- 不把 completion count、selected、mastery、palette、当前 index、进度或 transcript 放进内容领域模型。

## Package resources 与 bootstrap

### 1. 唯一生成链

修改 `scripts/bootstrap_ios_content.sh`，顺序固定为：

1. 运行现有 `npm run content:export`，生成/校验 `content/dist/`。
2. 原子刷新 `ios/Generated/WordLoopContent/`，保持 P1/P2 的中间产物约定。
3. 从同一已验证产物原子刷新 `ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent/`。
4. mirror 只物化 `catalog.json` 与完整 `courses/`；优先同卷 hard link，不能 hard link 时复制。不得复制 `validation-report.json`、schema、fixtures、Web 源路径或其他未声明文件。

增加精确 `.gitignore` 规则覆盖 Package mirror。bootstrap 失败不能留下半套 resource tree；不得依赖 Xcode Build Phase 在编译中途才生成资源。

### 2. SwiftPM 声明

`WordLoopContent/Package.swift` 的 target 使用：

```swift
resources: [
    .copy("Resources/WordLoopContent"),
]
```

- 必须使用 `.copy`，不能 `.process`，确保 `courses/<id>/<version>/audio/*.m4a` 目录和相对路径不被扁平化或改写。
- 正式 source 使用 `Bundle.module`，不能使用 `Bundle.main` 或硬编码 DerivedData/App 路径。
- 提供 `resourceRootURL` 注入 initializer 供临时目录 mutation tests；默认 live initializer 只解析 `Bundle.module` 的 `WordLoopContent` 子目录。
- 构建后的 App 内只允许一个 `WordLoopContent_*.bundle`/等价资源 bundle，里面精确 1,406 个 M4A，不允许再把 `ios/Generated` 加到 App target。

## 严格解码、校验与错误

### 1. 严格 DTO 边界

`WordLoopContent` 内部为 catalog/course/integrity 使用私有 wire DTO，再映射到 Core；不能把文件系统路径规则塞进 UI。解码必须覆盖 P1 schema 的实际约束：

- `schemaVersion == 1`；未知 schema 明确失败。
- object 各层拒绝未知 key，不能依赖 `JSONDecoder` 默认忽略 additional properties。
- enum、ISO UTC `generatedAt`、SemVer、64 位小写 SHA-256、正整数 version/bytes/duration/downloadSize 严格校验。
- stable ID、非空必填文字、optional/null 文字、array 唯一性与安全相对路径按 P1 schema fail closed。
- catalog collection/course ID 唯一；default course 必须存在；每门 course 的 collection 必须存在；bundle manifest location 必须是安全相对路径并与 `courses/<id>/<version>/course.json` 一致，不能接受 HTTPS、绝对路径、scheme、反斜杠、percent traversal、`.`、`..` 或 symlink。

### 2. Catalog 轻量校验

首次 `loadCatalog()`：

- 解码并完成 schema、ID、enum、SemVer、默认课程与 collection 引用校验。
- 只枚举 descriptor，不在启动时解码 30 个 manifest 或哈希 1,406 个音频。
- hidden/retired 仍可由 Repository 枚举，P7/P4.3 再决定 UI 可见策略；不能在数据层静默删除。

### 3. 单课程轻量校验

首次 `loadCourse(descriptor:)`：

- 严格解码该课 `course.json` 与 `integrity.json`。
- descriptor、course、integrity 的 ID/version 必须一致；course kind/practiceOrder/collection/title 等规范元数据必须与 descriptor 一致，不能合并矛盾真值。
- entries 至少 1 个、ID 唯一、duration 为正；audio path 安全且每个 entry 引用唯一文件。
- integrity path 唯一，必须精确声明 `course.json` 与全部/仅有 manifest audio；课程目录文件集合必须等于 `course.json + integrity.json + 已声明 audio`，拒绝额外文件、symlink 和非普通文件。
- 校验 `course.json` 实际 bytes/SHA 与 descriptor `manifestSHA256`、integrity 对应记录一致。
- 每个 audio URL 必须留在该课程根目录内、存在、为普通文件且 byte count 与 integrity 一致。
- live 轻量模式不在每次首次打开时读取并 SHA-256 全部音频；Bundle 受 App 签名保护，避免启动/开课 I/O 峰值。

### 4. 完整校验模式

`BundledCourseSource` 支持显式 `.full` validation mode 供 tests/CI 使用；它在相同解析路径上额外哈希全部 audio 并与 integrity 对比。不能另写一套只用于测试的解析器。P7 downloaded source/安装器将复用这一完整校验能力，但本卡不创建下载目录、安装记录或网络客户端。

### 5. 可比较错误

新增公开 `CourseContentError: Error, Equatable, Sendable`（可按文档/path/ID 携带安全上下文），至少能区分：

- malformed JSON / unsupported schema / unknown field；
- invalid or duplicate ID / invalid enum / invalid SemVer / invalid scalar；
- missing default course / unknown collection / unknown course；
- unsafe path / escaped root / symlink / non-regular / missing or extra file；
- descriptor-manifest-integrity mismatch / duplicate integrity path / undeclared audio；
- byte-count mismatch / manifest digest mismatch / audio digest mismatch。

不得 `preconditionFailure`、fatal error、静默跳过坏课程或把底层绝对用户路径显示给产品 UI。

## Source 与 Repository API

第一版 API 固定为单 source、可注入、并发安全：

```swift
public protocol CourseSource: Sendable {
    func loadCatalog() throws -> CourseCatalog
    func loadCourse(descriptor: CourseDescriptor) throws -> Course
}

public enum CourseValidationMode: Sendable {
    case lightweight
    case full
}

public struct BundledCourseSource: CourseSource, Sendable {
    public static func live(validationMode: CourseValidationMode = .lightweight) throws -> Self
    public init(resourceRootURL: URL, validationMode: CourseValidationMode = .lightweight)
}

public actor CourseRepository {
    public init(source: any CourseSource)
    public func catalog() throws -> CourseCatalog
    public func descriptors() throws -> [CourseDescriptor]
    public func course(id: CourseID) throws -> Course
}
```

- Repository 缓存第一次成功解析的 catalog 和已打开课程；失败不缓存为成功，下一次可确定地重试。
- `course(id:)` 只接受 catalog 内 ID；未知 ID 返回 typed error。
- source 注入允许单测记录调用次数，证明同一 catalog/course 只加载一次。
- actor 不持有 UI Store，不使用 `@MainActor`，不发通知，不自动在 init 做磁盘 I/O。
- P7 可在后续增加 downloaded source/优先级；本卡不提前建立 remote source、fallback、SwiftData 或 installer。

## 与 P3 静态 Shell 的边界

本卡不得把 Repository 接入 `AppContainer`、`RootView`、`MainStudyView`、CourseDrawer/ProgressDrawer/CompletionDialog 或任何 P3 Store。现有 25 项 App UI tests、launch arguments、fixture copy、modal 优先级和截图必须原样回归。

已知正式内容与静态 fixture 差异必须保留到 P4.3 映射时显式处理，不能在 P4.1 偷改 UI 基线：

- 静态第 75 条 fixture ID 为 `modern-family-s01e01-75`；exporter 正式第 75 条 ID 为 `s01e01-0381`。
- 静态 highlight 为 `completely comfortable`；当前 exporter 正式 highlight 为 `comfortable with`。
- IELTS manifest 的 phonetic 不带展示斜杠；P4.3 adapter 再格式化，不能污染领域值。
- `StudyShellMode` 暂不替换为 Core `StudyMode`；CourseDrawer 的 String ID、completion count/isSelected、Progress fixture 与 Completion intent 也暂不改类型或数据源。

## 测试矩阵

### Core unit tests

- 三种 stable ID 的有效/无效构造、Codable round trip 与非法 decode。
- `StudyMode`、kind/order/availability raw values 与未知值 fail closed。
- Catalog/descriptor/course/entry 值语义、Codable 与 Sendable 构造；URL 和 optional/null 字段保持。

### Content unit tests

- `.live(.lightweight)` 可读取 3 collections、30 descriptors，默认 `modern-family-s01e01`；1 word/29 sentence、1 random/29 sequential。
- 逐课打开 30 门：570 word + 836 sentence = 1,406 entries；descriptor/course/integrity 一致；全部 audio URL 为 bundle 内 `file:` URL、存在、非 symlink、byte count 正确。
- `.full` 对全部 1,406 audio 复验 SHA；总 bytes 为 32,700,838。
- 抽样 IELTS `abandon`、Modern Family `s01e01-0003` 和至少一门 VOA，锁定 text/translation/phonetic/highlights/order/audio filename，不用静态 P3 fixture 代替正式内容。
- 纯临时目录 mutation tests 覆盖坏 JSON/unknown key/schema、重复 ID、默认课缺失、未知 collection、ID/version/kind/order mismatch、路径逃逸/percent/绝对/scheme、空/重复 entry、缺失/额外/symlink/FIFO audio、重复/未声明 integrity、坏 manifest hash、坏 audio bytes/size/hash。
- fake `CourseSource` 证明 Repository catalog/course 成功缓存、失败可重试、unknown course 不调用 source。

### App/Xcode integration

- `AppIntegrationTests` 通过 `BundledCourseSource.live()` 从 Xcode 构建后的 resource bundle 读取 catalog、打开默认课程并得到存在的 sample audio URL，证明不是只有 macOS `swift test` 能找到 `Bundle.module`。
- 现有 App UI 25/25 原样回归；不新增 Repository UI fixture 或截图。

### Web/static regression

新增 `tests/ios-bundled-content-repository.test.mjs`，至少锁定：

- bootstrap 的两个生成目标、Package `.copy` resource、mirror 精确 ignore，`validation-report.json` 不进 mirror/App。
- resource tree 与 `content/dist` 的 `catalog.json + courses` 文件列表/hash 等价，report counts 与 Repository 固定验收数量一致。
- Generated/mirror 不在 `git ls-files`；App target 不直接引用 `ios/Generated`，构建产物只有一套 Content resource bundle/1,406 个 M4A。
- Core 无业务依赖；Content 无 URLSession/AVFoundation/SwiftData/UserDefaults/Keychain/Realtime/timer；P3 Features/App 未 import/初始化 Repository。

## 禁止范围

- 不实现 P4.2 AVFoundation player、current/next prepared asset、request token、route/lifecycle。
- 不实现 P4.3 StudyStore、真实选课、random/sequential 取项、NEXT、AUTOPLAY、500 ms 等待、文字三态接线或 palette 变化。
- 不实现 P4.4 本地完成/重练；不真实 reset、累计或前进。
- 不读取/写入 Progress、UserDefaults、SwiftData、Keychain、API、outbox；不访问远端 catalog，不下载/更新/删除课程。
- 不请求麦克风，不连接 Realtime/WebRTC，不评分，不创建 timer/后台任务。
- 不修改 Web UI、课程源、音频、API、数据库、VPS 或 P1 schema/exporter 业务语义；仅允许 bootstrap/静态测试为 Swift Package resource 接入做必要调整。
- 不创建 iPad、macOS、Catalyst 产品 target 或桌面布局/快捷键；不新增第三方 Swift Package。

## 验收命令

```bash
rm -rf content/dist ios/Generated ios/.derivedData ios/.build
rm -rf ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent
find ios/Packages -type d -name .build -prune -exec rm -rf '{}' +

scripts/verify_ios.sh

swift test --package-path ios/Packages/WordLoopCore --scratch-path ios/.build/WordLoopCore
swift test --package-path ios/Packages/WordLoopContent --scratch-path ios/.build/WordLoopContent

xcodebuild -project ios/WordLoop.xcodeproj -scheme WordLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath ios/.derivedData CODE_SIGNING_ALLOWED=NO test

npm run baseline:ios
npm test
npm run lint
git diff --check
git status --short --ignored
```

验收还必须从构建后的 `.app`/resource bundle 实查：只有一套 WordLoopContent 资源、精确 1,406 个 M4A、无 `validation-report.json`，并确认所有生成资源均 ignored/untracked。lint 允许且只允许既有 `app/page.tsx` 4 errors、0 warnings。

## 退出与交接

退出标准：30 门课程可从 Bundle catalog 枚举，30 个 manifest/integrity 可打开，1,406 个音频 URL/bytes 与完整 SHA 校验通过；Repository typed error/cache/重试确定；Package host test 和 iPhone Xcode integration 都能定位 `Bundle.module`；App 只打包一套课程且不含审计 report；P3 UI/fixture 全回归、无播放器/进度/网络/下载/Realtime/桌面越界。

开发完成后把状态改为“开发完成，待独立复核”，刷新 `PROJECT_CONTEXT.md` 与 `docs/handoff/CHANGELOG.md`，提交 CP-09 实现并交给未参与实现的 reviewer 冷验证。只有 P4.1 独立复核 PASS 后，才基于真实 Repository/audio URL API 生成 P4.2 AudioPlayer 任务卡。
