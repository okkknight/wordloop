# WordLoop 项目上下文

## 产品

WordLoop 是一款以句子跟读、听力和学习进度为核心的英语学习产品：Web 运行在 VPS，iOS 为原生 SwiftUI 客户端。首发课程只包含 36 门 AI 原创日常英语会话课；Modern Family、VOA 和 IELTS 不属于当前 App Store 发布内容。

它不是通用聊天产品、账号系统或在线翻译服务。默认以游客身份学习；学习数据在设备与 VPS 进度服务之间同步。

## 当前状态

- Git 基线：`main`，当前 HEAD 包含 iOS 本地化、多语言课程和模拟器验收提交；发布前需确认工作树干净并推送到远端。
- App Store 状态：首发 `1.0 (build 4)` 已发布；当前准备多语言更新 `1.1 (build 5)`。本项目不在此处执行上传或提交审核。
- 执行状态：多语言课程与 iOS 界面本地化已完成，已通过严格完整性检查和代表性模拟器验收；待 Release archive、TestFlight 真机验收及 App Store Connect 人工操作。
- 首发边界：`scripts/lib/course-export/app-store-release.mjs` 固定 36 门、576 个句子；`ai-polite-boundaries` 是注册但不在首发清单内的旧课，不能混入翻译或导出验收。
- 当前覆盖（由 `node scripts/check_mother_tongue_translations.mjs` 实测）：15 个目标 locale 均为 576/576，缺失 0。
- 本轮没有调用翻译 API；发布准备不得读取或调用 `.env.local` 的 `OPENAI_API_KEY` 做翻译。

## 本轮本地化实现

- `app/data/ai-*.json` 的每个 entry 新增可选 `translations` 映射，旧 `translation` 保留为兼容旧课程包的简中回退。
- `CourseEntry.translation(for:)` 根据系统首选 BCP-47 locale 选取母语文本；繁中对 `zh-Hant`、`zh-TW`、`zh-HK`、`zh-MO` 有回退；若未翻译则暂回退旧简中字段。
- `CourseWireModels`、`BundledCourseSource`、schema 与 exporter 已透传并校验该字段；课程包导出后 iOS 和 Web 使用同一份内容来源。
- `ios/App/Info.plist` 已声明 15 个 App 本地化语言；课程译文和当前 iOS UI 文案均已接入对应 locale copy。
- `scripts/check_mother_tongue_translations.mjs` 只检查固定首发清单。`npm run content:check-mother-tongue` 为严格门禁，所有 15 种本地化字段缺任一条都会失败。

## 架构与关键文件

- Web 课程注册表：`app/courses.ts`；源 manifest：`app/data/*.json`；课程导出：`scripts/lib/course-export/{source,exporter}.mjs`。
- 首发筛选：`scripts/lib/course-export/app-store-release.mjs`。任何批处理都必须先导入这个固定列表，而不是按 `ai-practice` collection 或扫描 `app/data`。
- iOS 值模型与 locale 回退：`ios/Packages/WordLoopCore/Sources/WordLoopCore/CourseModels.swift`。
- iOS 内容 decode/验证：`ios/Packages/WordLoopContent/Sources/WordLoopContent/{CourseWireModels,BundledCourseSource,CourseContentValidation}.swift`。
- iOS 学习页投影：`ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Study/StudyProjection.swift`；学习页、侧栏、进度及完成提示的固定 UI 文案仍散在 `StudyShell/MainStudyView.swift`、`CourseDrawer/CourseDrawerView.swift`、`ProgressDrawer/ProgressDrawerView.swift`、`CompletionDialog/`，需要集中本地化后逐一替换。
- VPS 运行与发布边界：`docs/WORDLOOP_VPS_RUNBOOK.md`。VPS 没有 Git 工作树；部署只能同步运行时 Web/API、`app/data/`、课程音频和生成的 catalog，保留远端 `data/`、`tmp/` 和环境文件。

## 已验证

- `swift test --package-path ios/Packages/WordLoopCore`：本轮修改后 10/10 通过。
- `node --check scripts/check_mother_tongue_translations.mjs`：通过。
- `node scripts/check_mother_tongue_translations.mjs`：正确报告固定 36 门、576 句及上述覆盖数。
- `git diff --check`：在本轮最后一次检查通过。

尚未验证：所有 Swift package、App 编译、真实设备切换语言、Web 运行时语言显示、完整导出以及 VPS。任何人不得把这些未验证项写成已发布。

## 接续顺序

1. 复跑 `npm run content:check-mother-tongue`、`npm run content:check:app-store`，确认 36 门 / 576 句 / 15 locale 无回退。
2. 用 Release 配置编译并 Archive，检查版本 `1.1`、build `5`、Bundle ID、签名、API/catalog 生产地址、Privacy Manifest 和包内容。
3. TestFlight 真机验收至少覆盖 LISTEN、REPEAT 麦克风授权/拒绝、进度同步/删除、离线启动和代表性非中文语言；截图和审核备注不得出现未发布课程。
4. 由账户持有人在 App Store Connect 上传 build 5、填写更新说明、完成隐私/出口合规问卷并提交审核；本地不保存 Apple 凭据或 API key。

## 工作规则与风险

- 用户要求不使用 API key 来做翻译；不得把译文任务交给 `OPENAI_API_KEY`、第三方翻译 API 或未说明的外部服务。
- 译文规模很大，完整性校验只能证明数量，不能证明母语质量；每个语言至少应抽检礼貌、否定、问句、数字/地址和多句上下文。
- fallback 到简中是过渡兼容行为；发布非中文母语版本前，不能让缺失译文依赖它。
- 本轮触及 Web 源 manifest、课程 exporter 和 iOS bundle decode，可能影响 Web 课程加载、iOS 内置/下载课程解码及远端 catalog 兼容性；需 coordinated verification。
- 保留现有未提交工作；不要 `git reset --hard`、`git checkout --` 或删除 `stash@{0}`。
