# P0.1 质量基线

执行日期：2026-07-15

## 环境

- Node：`v25.8.1`
- 本地 dev：vinext / Vite，`http://localhost:3000/`
- 浏览器：Playwright Chromium headed
- 正式截图 viewport：390 × 844 CSS px
- 迁移目标：仅 iPhone，不包含桌面端

## 自动检查

### `npm test`

结果：通过。

- vinext production build 成功。
- 原有 28 项测试与新增 5 项基线测试全部通过，共 33 项。
- build 警告：客户端 chunk 超过 500 kB。

### `npm run lint`

结果：失败，只有 4 个既有错误，均在 `app/page.tsx`；P0.1 新增文件无 lint error 或 warning：

- `1040:35` preserve-manual-memoization
- `1083:105` preserve-manual-memoization
- `1085:47` preserve-manual-memoization
- `1126:124` preserve-manual-memoization

P0.1 不修复这些既有错误；验收要求是不新增 lint 问题。

### `npm run baseline:ios`

结果：通过。

- 30 门注册课程、3 个集合。
- 570 个单词、836 个句子条目。
- 570 个单词音频、836 个句子音频，共 1,406 个 M4A。
- 总 M4A 字节数 32,700,838。
- 当前逐条引用没有 missing、extra 或 duplicate。

### 基线脚本 mutation tests

结果：5 项通过。

- 连续输出确定性一致。
- 默认课程和默认模式从真实源码读取。
- 缺失条目音频必须失败。
- 未注册 manifest 必须失败。
- 冲突和未知 CLI 参数必须失败。

## 浏览器人工基线

已真实打开本地页面并验证：

- iPhone 启动页。
- REPEAT 主界面及失败恢复可观察状态。
- LISTEN 主界面。
- 左侧课程抽屉。
- 右侧进度抽屉。
- 已完成课程的重练对话框。
- LISTEN/REPEAT 切换、抽屉打开关闭、进度列表滚动。

浏览器控制台基线：

- Geist/Geist Mono 开发字体 URL 指向旧的机器绝对缓存路径，产生多条 404。
- `/favicon.ico` 404。
- 本地 Cloudflare `/api/progress` 缺运行绑定时返回 500；UI 按容错路径继续进入。

这些错误是当前本地运行事实，不是 iOS 目标行为。字体截图只能证明布局与层级，P3 必须结合源字体声明和后续真机截图核验字形。API 合同以源码和 VPS Node 实现为基线，不能以本地 500 推断接口不可用。

## 未在 P0.1 修改

- Web UI、状态机、课程和音频。
- D1/Node API 差异。
- 既有 lint 错误和 chunk 警告。
- VPS 生产环境。
