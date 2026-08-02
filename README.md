# WordLoop

WordLoop 是一个以原声音频为核心的英语听力与跟读学习应用。它把 IELTS 高频词、影视对白和 VOA Learning English 内容整理成可重复练习的单词或句子单元，并分别记录听力与跟读进度。

## 当前内容

- IELTS 高频词：570 个单词及配套音频
- 《摩登家庭》第一季：前 5 集精选对白课程
- VOA Learning English Level 2：24 节 B1 实用口语课程
- 学习模式：`LISTEN` 听力练习、`REPEAT` 实时跟读
- 掌握规则：每个单元累计练习 3 次，或使用“太简单”直接标记

课程注册入口是 [`app/courses.ts`](app/courses.ts)，最终音频位于 `public/audio/` 和 `public/courses/`。完整项目边界、架构与风险请先阅读 [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md)。原生 iOS 技术栈迁移已形成可执行规格，见 [`docs/IOS_MIGRATION_SPEC.md`](docs/IOS_MIGRATION_SPEC.md)；当前仅完成规划，尚未创建 iOS 工程。

## 技术栈

- React 19、Next.js 16 App Router
- vinext、Vite 8、Node.js
- TypeScript、原生 CSS
- Node.js 内置 SQLite（本地与 VPS 的唯一学习进度真值）
- Cloudflare Workers / D1（仅保留为兼容性对比实现）
- WebRTC + OpenAI Realtime transcription

要求 Node.js `>=22.13.0`。

## 本地开发

```bash
npm install
npm run dev
```

该命令会同时启动本地 Node API（默认 `127.0.0.1:3011`）和前端；前端
`/api/*` 请求会代理到同一份 SQLite 数据。默认数据库为
`data/wordloop.local.sqlite`，可通过 `WORDLOOP_DB_PATH` 覆盖。

Cloudflare 不再是开发或部署入口。如需运行旧的兼容实现，显式使用
`npm run dev:cloudflare` 或 `npm run build:cloudflare`。

需要测试跟读功能时，在本地 `.dev.vars` 中配置：

```text
OPENAI_API_KEY=...
```

不要提交 `.dev.vars`、原始媒体、转写中间文件或 `work/` 目录。

## 验证命令

```bash
npm run lint
npm test
git diff --check
```

`npm test` 是 Node 与 Cloudflare 兼容实现的对比测试，因此会显式构建
Cloudflare 兼容产物；日常生产构建使用 `npm run build`。测试还会检查课程
manifest、逐句音频、时间轴元数据和主要产品流程。lint 仍有 React Compiler
的手动 memoization 错误，详见 [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md#当前风险与开放项)。

## 目录导航

| 路径 | 用途 |
| --- | --- |
| `app/page.tsx` | 主界面、音频控制、学习状态机、离线进度同步 |
| `app/courses.ts` | 课程类型、课程集合与内容注册 |
| `app/data/` | 句子课程 manifest 与高价值表达标记 |
| `app/api/` | Cloudflare/D1 兼容实现，仅用于对比测试 |
| `server/index.mjs` | 本地与 VPS 的唯一 Node + SQLite API |
| `db/`、`drizzle/` | Cloudflare/D1 兼容 schema 与迁移 |
| `public/` | 单词和课程的最终音频资源 |
| `scripts/` | 字幕、转写、对齐、切片与课程验证脚本 |
| `tests/` | 构建产物和内容完整性测试 |
| `docs/` | 内容制作、部署运维与项目接手文档 |

## 课程制作

- 通用及《摩登家庭》课程：[`docs/COURSE_PRODUCTION_GUIDE.md`](docs/COURSE_PRODUCTION_GUIDE.md)
- VOA 课程：[`docs/VOA_COURSE_PRODUCTION_GUIDE.md`](docs/VOA_COURSE_PRODUCTION_GUIDE.md)
- 《摩登家庭》素材审计：[`docs/MODERN_FAMILY_SOURCE_AUDIT.md`](docs/MODERN_FAMILY_SOURCE_AUDIT.md)

课程内容是经过筛选的学习产品，不是完整字幕存档。文字必须与音频严格对齐；Whisper 只用于辅助定位，最终以官方文本、字幕源和人工试听为准。

## 部署

仓库保留 Cloudflare 兼容形态用于测试；本地与真实生产环境统一使用 Node + SQLite：

- 公网路径：`https://boringmax.com/wordloop/`
- Caddy 反向代理
- 前端：`wordloop.service`
- API：`wordloop-api.service`
- 数据：VPS 本机 SQLite

部署、重启、权限和线上验证步骤以 [`docs/WORDLOOP_VPS_RUNBOOK.md`](docs/WORDLOOP_VPS_RUNBOOK.md) 为准。不要仅凭 `.openai/hosting.json` 推断当前生产拓扑。

## 项目接手

按以下顺序阅读：

1. [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md)
2. [`docs/handoff/README.md`](docs/handoff/README.md)
3. 与任务相关的课程制作指南或 VPS 运维手册

`docs/handoff/CHANGELOG.md` 只追加影响后续接手的重要事实，不替代 Git 历史。
