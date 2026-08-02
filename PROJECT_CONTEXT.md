# WordLoop 项目上下文

## 产品

WordLoop 是一款以句子跟读、听力和学习进度为核心的英语学习产品：Web 运行在 VPS，iOS 为原生 SwiftUI 客户端。首发课程只包含 36 门 AI 原创日常英语会话课；Modern Family、VOA 和 IELTS 不属于当前 App Store 发布内容。

它不是通用聊天产品、账号系统或在线翻译服务。默认以游客身份学习；学习数据在设备与 VPS 进度服务之间同步。

## 当前状态

- Git 基线：`main`，最新已提交变更为 `f9ae7165`（iOS migration 合并）。本地工作树有一批**未提交**的本地化改动。
- 当前任务：14 个目标母语的课程译文与界面文案。
- 执行状态：**已执行待验收**，尚未完成，禁止提交、部署或提交新的 App Store 构建。
- 首发边界：`scripts/lib/course-export/app-store-release.mjs` 固定 36 门、576 个句子；`ai-polite-boundaries` 是注册但不在首发清单内的旧课，不能混入翻译或导出验收。
- 当前覆盖（由 `node scripts/check_mother_tongue_translations.mjs` 实测）：`zh-Hans` 576/576，`ja` 64/576，`zh-Hant`、`ko`、`es`、`pt-BR`、`fr`、`de`、`it`、`ru`、`ar`、`id`、`th`、`vi`、`tr` 都是 0/576。尚缺 8,000 个字段。
- 本轮没有调用翻译 API。此前生成器和 API 写入结果已撤回；不要恢复或重建该脚本，也不要读取/调用 `.env.local` 的 `OPENAI_API_KEY` 做翻译。

## 本轮本地化实现

- `app/data/ai-*.json` 的每个 entry 新增可选 `translations` 映射，旧 `translation` 保留为兼容旧课程包的简中回退。
- `CourseEntry.translation(for:)` 根据系统首选 BCP-47 locale 选取母语文本；繁中对 `zh-Hant`、`zh-TW`、`zh-HK`、`zh-MO` 有回退；若未翻译则暂回退旧简中字段。
- `CourseWireModels`、`BundledCourseSource`、schema 与 exporter 已透传并校验该字段；课程包导出后 iOS 和 Web 使用同一份内容来源。
- `ios/App/Info.plist` 已声明 15 个 App 本地化语言。**这只是声明，不代表所有界面已翻译。**
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

1. 先实现集中化的 iOS UI 文案表，覆盖主学习页、课程抽屉、进度抽屉、完成对话框、加载/错误/权限状态和 accessibility labels；每个 15 语言值必须是母语文案而非英语占位。
2. 逐课补齐 14 个目标母语。每次写入只修改 `APP_STORE_RELEASE_COURSE_IDS` 指向的 manifest；按 course ID 绑定，避免宽泛文本替换。
3. 逐语言运行严格门禁；完成后运行 `npm run content:check-mother-tongue`、`npm run content:check:app-store`、所有相关 Swift package 测试与 App 编译，再在至少一个非中文系统语言的模拟器验收。
4. 只有上述完成后才导出、提交、推送、部署 VPS 或创建新的 App Store build。

## 工作规则与风险

- 用户要求不使用 API key 来做翻译；不得把译文任务交给 `OPENAI_API_KEY`、第三方翻译 API 或未说明的外部服务。
- 译文规模很大，完整性校验只能证明数量，不能证明母语质量；每个语言至少应抽检礼貌、否定、问句、数字/地址和多句上下文。
- fallback 到简中是过渡兼容行为；发布非中文母语版本前，不能让缺失译文依赖它。
- 本轮触及 Web 源 manifest、课程 exporter 和 iOS bundle decode，可能影响 Web 课程加载、iOS 内置/下载课程解码及远端 catalog 兼容性；需 coordinated verification。
- 保留现有未提交工作；不要 `git reset --hard`、`git checkout --` 或删除 `stash@{0}`。
