# P1 统一课程协议与确定性 Exporter

状态：开发完成，待独立复核

实现结果：JSON Schema、三类成功 fixtures、失败 fixtures、确定性 exporter、原子替换、iOS content bootstrap 与 4 项合同/exporter 测试均已落地。`npm test` 37/37 通过；lint 仍精确只有 P0 的 4 个既有错误且新增文件 0 warning；Web 业务源码与课程资源未修改。

上游 Plan：[`../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md`](../plans/2026-07-15-wordloop-ios-migration-implementation-plan.md)

上游基线：[`../ios-migration/baseline/README.md`](../ios-migration/baseline/README.md)

## 目标

把当前 Web 运行时使用的 30 门课程转换为唯一、平台无关、可重复生成和严格校验的课程包协议，为后续 iPhone Bundle 与远程下载复用。此任务建立合同和 exporter，不创建 iOS 工程，也不改变 Web 运行时数据入口。

## 已确认事实与决策

- 规范课程 ID 以 `app/courses.ts` 的运行时注册表 ID 为真值。
- `modern-family-s01e01.json` 中历史 `courseId=modern-family-s01` 只作为 validation report 的 source ID 差异记录；规范 `course.json.id` 必须为 `modern-family-s01e01`，不得静默把历史 ID 传播到 iOS。
- Web 第一阶段继续读取当前源文件；只用等价测试保证 exporter 不漂移，不修改 `app/page.tsx` 数据入口。
- `content/dist/` 和 iOS Generated resources 是可重建产物，不提交 Git；课程源和现有音频仍只维护一份。
- 目标平台仍仅为 iPhone；本任务没有桌面/iPad/macOS 产品工作。

## 范围

### 1. 协议与 fixtures

新增：

```text
content/schema/catalog.schema.json
content/schema/course.schema.json
content/schema/integrity.schema.json
content/fixtures/valid/
content/fixtures/invalid/
```

协议至少锁定：

- `schemaVersion=1`、稳定 course/entry ID、`contentVersion>=1`、SemVer `minimumAppVersion`。
- `kind=word|sentence`、`practiceOrder=random|sequential`、catalog `status=available|hidden|retired`。
- catalog descriptor、course manifest 和 integrity 的 course ID/version 必须相互一致。
- entry 至少 1 个且 ID 在课程内唯一；文字、音频相对路径和正整数时长必填。
- word 可带 phonetic/translation；sentence 可带 translation/highlights；不能把原始素材、审计路径或可执行内容写进课程包。
- 所有相对路径拒绝空段、`.`、`..`、反斜杠、URL scheme、绝对路径和 percent-encoded traversal。
- integrity 声明 `course.json` 与所有 M4A 的相对路径、字节数和小写 64 位 SHA-256；拒绝未声明文件、重复路径和软链接。

valid fixtures 覆盖 IELTS 随机单词、Modern Family 顺序句子和 VOA 顺序句子；invalid fixtures 至少覆盖坏 hash、重复 course/entry/collection ID、路径逃逸、绝对路径、schema 不兼容、ID/version 不一致、未知枚举和空 entries。这里以真实运行时注册表为准：当前全部 29 门句子课都是 `sequential`。

使用正式 JSON Schema validator 跑 schema tests；依赖必须锁入 `package-lock.json`。

### 2. Exporter

新增建议结构：

```text
scripts/export_course_packages.mjs
scripts/lib/course-export/
scripts/bootstrap_ios_content.sh
content/dist/                  # ignored generated output
tests/course-export.test.mjs
```

Exporter 必须：

- 从 TypeScript AST/真实注册表读取 `COURSE_PACKAGES`、`COURSE_COLLECTIONS`、`DEFAULT_COURSE`，读取 `app/words.ts`、manifest JSON 和 highlights；禁止再硬编码 30/570/836 作为产物来源。
- 显式拒绝重复 collection ID、重复注册 course ID、未知 collection、未注册且含 entries 的 manifest。
- 合并注册表 title/subtitle/description/kind/practiceOrder、稳定 ID、可学习 entries、highlights 和实际音频路径。
- 输出 `catalog.json`、每课 `course.json`、`integrity.json`、`validation-report.json`；report 显式列出源 manifest ID 与规范 ID 的差异。
- 读取 M4A 实际字节，至少验证容器可识别且非空，记录 byte count 与 SHA-256；每个引用必须唯一存在，拒绝 missing/extra/duplicate/symlink。
- 只在临时目录完整生成并校验成功后原子替换 `content/dist/`；失败不能破坏上次有效产物。
- 产物 JSON 使用稳定键序、稳定数组序和固定换行。`generatedAt` 取受控 `SOURCE_DATE_EPOCH`；未设置时取当前 Git `HEAD` 的提交时间，不能直接使用墙钟导致连续输出漂移。
- CLI 至少支持互斥的 `--write`、`--check`、`--output <dir>`；未知、缺值或冲突参数返回非零。

`scripts/bootstrap_ios_content.sh` 在后续 Package tests/Xcode build 前调用 exporter，把规范 manifest 和音频硬链接或复制到一个被忽略的 Generated 目录；现在即使 `ios/` 尚不存在，也必须能在空目录完成生成并给出清晰目标路径。

### 3. 等价与失败测试

测试必须独立证明：

- 连续两次生成的目录树、文件列表和每文件 SHA-256 完全一致。
- 30 门课程、3 个集合、570 个单词、836 个句子、1,406 个 M4A 与 P0 machine baseline 一致。
- IELTS、Modern Family、VOA 三类抽样字段、顺序、highlight 与音频哈希正确。
- 所有 catalog/manifest/integrity 通过 schema；所有 invalid fixtures 被拒绝。
- mutation tests 会拒绝：重复 collection ID、缺失/游离音频、未注册 manifest、坏 hash、路径逃逸、ID/version 不一致和 symlink。
- `--check` 在源码不变时通过，在产物缺失或被改写时失败。
- 失败生成保留上次有效 `content/dist/`。

## 禁止范围

- 不创建 Xcode 工程或 Swift Package。
- 不修改 Web UI、学习状态、课程文案、条目筛选、音频、API 或数据库。
- 不让 Web 改读 `content/dist/`。
- 不提交 `content/dist/` 或第二份 M4A。
- 不修复 `app/page.tsx` 的既有 lint 错误。
- 不实现远程 catalog 服务或下载 UI。

## 验收命令

```bash
npm run baseline:ios
npm run content:export
npm run content:check
npm test
npm run lint
git diff --check
git status --short
```

验收时 `npm test` 必须全绿；lint 允许且只允许 P0 记录的 4 个既有 `app/page.tsx` 错误，新增文件不得有 error/warning。`git status` 不得出现 `content/dist/` 或重复音频。

## 退出与交接

完成后：

1. 状态改为“开发完成，待独立复核”。
2. 刷新 `PROJECT_CONTEXT.md` 和 handoff changelog。
3. 提交 `CP-01 course contract and deterministic exporter`。
4. 由未参与实现的 reviewer 重新跑全部验收并给出 PASS/FAIL。
5. 只有 PASS 后才能基于真实 exporter/bootstrap 结果生成 P2 iOS 工程骨架任务卡。
