# WordLoop 课程协议

本目录保存 Web 与原生 iPhone 共用的课程包合同。人工维护源仍在 `app/words.ts`、`app/courses.ts`、`app/data/` 和 `public/`；不要在这里或 Swift 中手抄第二份课程。

## 目录

- `schema/`：catalog、course manifest 和 integrity 的 JSON Schema 2020-12 合同。
- `fixtures/`：三类成功合同与路径、枚举、重复 ID、版本不一致等失败合同。
- `dist/`：被 Git 忽略的生成产物，可随时删除并重建。

## 生成与检查

```bash
npm run content:export
npm run content:check
scripts/bootstrap_ios_content.sh
```

`content:export` 从真实运行时注册表读取 30 门课程，以注册表 course ID 为规范 ID，验证所有条目与 M4A 一一对应，在临时目录完成 schema、哈希和路径检查后再替换 `content/dist/`。`content:check` 重新生成到临时目录并比较整个文件树，不修改当前产物。

`generatedAt` 默认使用 Git `HEAD` 提交时间，CI 可通过 `SOURCE_DATE_EPOCH` 固定。相同源和相同时间输入必须得到完全相同的文件列表与 SHA-256。

Bootstrap 默认复制生成树到被忽略的 `ios/Generated/WordLoopContent/`；P2 建立 Swift Package 后从该目录接入 Bundle resources。可用 `WORDLOOP_IOS_CONTENT_OUTPUT` 指定临时目标进行验证。

## 规范边界

- Catalog 保留 3 个课程集合、默认课程和运行时顺序。
- 课程包只含可学习条目、运行时文案、highlight、规范相对音频路径和时长。
- 制作来源、原始媒体路径、时间轴审计和 `reviewReasons` 不进入 App。
- 规范 ID 以 `app/courses.ts` 为准；历史 manifest ID 差异与未命中 highlight 写入 `validation-report.json`。
- 包内拒绝绝对路径、`..`、反斜杠、percent traversal、软链接、缺失/游离音频、重复 ID 和不兼容 schema。
- `content/dist/` 及 `ios/Generated/` 不提交 Git，也不形成第二份人工音频资产。
