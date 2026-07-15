# WordLoop Handoff Changelog

此文件只追加影响后续接手的耐久事实。最新记录放在最上方，不改写旧记录。

## 2026-07-15

- 用真实产品说明替换根目录 vinext starter README。
- 建立 `PROJECT_CONTEXT.md` 作为项目边界、架构、运行事实、风险和工作规则的唯一上下文入口。
- 明确当前生产环境是 VPS Node API + SQLite，同时仓库仍保留 Sites/Cloudflare D1 实现。
- 记录当前质量基线：build 和 28 项测试通过，lint 因 4 个 React Compiler memoization 错误未通过。
- 本次仅修改文档，对现有产品功能和生产运行没有直接影响。
