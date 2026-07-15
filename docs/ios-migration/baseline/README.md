# WordLoop iPhone 迁移基线

状态：P0.1 基线证据

本目录冻结当前 Web 产品需要由原生 iPhone App 保持的内容、页面、状态、文案、视觉和 API 合同。它不是 iOS 设计稿，也不要求迁移桌面浏览器输入方式。

## 证据入口

- [`content-inventory.json`](content-inventory.json)：由真实课程注册表、manifest 与音频目录生成的机器基线。
- [`product-acceptance-matrix.md`](product-acceptance-matrix.md)：iPhone 页面、手势、状态与桌面排除项。
- [`api-contracts.md`](api-contracts.md)：D1 与 VPS Node API 的精确合同和已知差异。
- [`quality-baseline.md`](quality-baseline.md)：构建、测试、lint 和浏览器运行基线。
- [`screenshots/`](screenshots/)：390 × 844 CSS px 的当前移动 Web 截图。

## 截图索引

| 画面 | 文件 | 说明 |
| --- | --- | --- |
| 启动 | [`iphone-startup.png`](screenshots/iphone-startup.png) | 用户名输入、START、全屏遮罩 |
| REPEAT | [`iphone-repeat.png`](screenshots/iphone-repeat.png) | 海报学习页、状态卡和底部控制 |
| LISTEN | [`iphone-listen.png`](screenshots/iphone-listen.png) | 模式切换、AUTOPLAY 和 NEXT |
| 课程抽屉 | [`iphone-course-drawer.png`](screenshots/iphone-course-drawer.png) | 左侧抽屉、集合和课程卡 |
| 进度抽屉 | [`iphone-progress-drawer.png`](screenshots/iphone-progress-drawer.png) | 右侧抽屉、统计、搜索和列表 |
| 重练对话框 | [`iphone-restart-dialog.png`](screenshots/iphone-restart-dialog.png) | 完成课程的确认对话框 |

截图用于冻结信息层级、位置、配色和移动端比例。当前本地 vinext dev 存在字体资源 404，字体字形不能只以截图作为唯一证据；字体声明仍以 `app/layout.tsx` 的 Geist/Geist Mono 和 `app/globals.css` 为准。

## 重建与验证

```bash
npm run baseline:ios:write
npm run baseline:ios
node --test tests/ios-migration-baseline.test.mjs
```

`content-inventory.json` 是生成物，不应人工编辑。生成脚本会从 TypeScript AST 读取运行时课程注册、默认课程与默认模式，并验证：

- 注册课程与含 entries 的 manifest 一一对应；
- 每个可学习条目引用真实且唯一的 M4A；
- 没有游离课程音频或单词音频；
- 课程、集合、单词和条目 ID 满足唯一性；
- Startup/Repeat 文案和关键时长仍与源码一致。

## 平台边界

迁移只面向 iPhone。空格键、R 键、hover、鼠标、桌面大字号、桌面 footer 横排和宽屏布局不进入 iOS 验收范围。iOS 使用原生 Safe Area、触摸、VoiceOver、Dynamic Type、Reduce Motion、SwiftData、AVFoundation 与原生网络组件实现等价结果。
