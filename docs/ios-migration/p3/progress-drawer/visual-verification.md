# P3.5 进度抽屉视觉验证

执行日期：2026-07-16

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- iPhone 17e：390 × 844 pt，截图 1170 × 2532 px；抽屉宽度为视口 86%，即 335.4 pt。
- iPhone 17 Pro：402 × 874 pt，截图 1206 × 2622 px；抽屉命中 344 pt 上限。
- 所有数据均来自 `ProgressDrawerViewState` 内存 fixture；未读取课程包、P6 Progress、API/outbox、持久化或网络。

## 证据

| 文件 | 状态与 fixture | SHA-256 |
| --- | --- | --- |
| [`iphone-17e-default.png`](iphone-17e-default.png) | sentence baseline；`-wordloop-study-shell -wordloop-progress-drawer` | `7b3f5d02ef1dacd05378e38ff9c0c4ef59dac6e23a5a9720175a82f8ec33d7c1` |
| [`iphone-17e-mixed.png`](iphone-17e-mixed.png) | 0/1/2/3 次与完成标记；`-wordloop-progress-mixed` | `cea9edba8518834aa169b6f0ee6ee9a48eb9fc650d6962daea4e72be61071380` |
| [`iphone-17-pro-word-search.png`](iphone-17-pro-word-search.png) | word fixture、音标/释义与 `kʌmf` 搜索；`-wordloop-progress-word -wordloop-progress-query kʌmf` | `35bbf3cf69015f553103b43be6b3fcbd51c57f5cce9bc14c83c05a847f31c670` |
| [`iphone-17e-accessibility3-reduce-motion.png`](iphone-17e-accessibility3-reduce-motion.png) | mixed、accessibility 3、Reduce Motion；`-wordloop-fixture-accessibility-text -wordloop-fixture-reduce-motion` | `209456145fad8cb78ff91e794f3b7647f67efb5ef70e8676681146de69d93b62` |

## 与 Web 基线核对

- 保留从右进入、黄色 poster 背景、左侧暗色遮罩、`YOUR PROGRESS`、学习次数、当前课程、track、已掌握/学习中、搜索和逐条 0...3 次；没有增加 Tab Bar、iPad 分栏或桌面侧栏。
- 原生页面保留状态栏、Dynamic Island/Home Indicator 与 Safe Area；抽屉内 header、summary 和 search 固定，只有条目列表滚动。
- sentence baseline 精确为 0/273、0 已掌握、91 学习中；mixed 为 6/273、1 已掌握、90 学习中；word fixture 用代表行而非复制 570 条正式课程。
- 进度条的无障碍 value 为“已学习 X 次，共 Y 次”。每个条目合并朗读英文、中文/音标释义与次数，完成行追加“已掌握”，条目不是可点击按钮。

## 对比度与可访问性

- 次要文字与未完成 count 使用 ink 75% 在不透明 drawer background 上真实合成；六 palette 最低 5.068:1。
- 搜索、列表分割线与 track underlay 使用 ink 56% 合成；六 palette 最低 3.097:1。
- track fill 与完成 count 使用 `accessibleAccentText`，至少 4.5:1；canonical accent 只保留为 track 1 pt 线和完成行 3 pt 标记，不单独承担状态语义。
- modal 打开时主学习页从 accessibility/hit-test 路径隔离；关闭时用状态 identity 重建背景节点，UI automation 已连续验证关闭后 `COURSE`/`PROGRESS` 恢复可点击。
- header、左侧遮罩和主导右滑三种关闭入口均由 UI automation 验证；等于 72 pt、向左和纵向主导 drag 由 Store 单测验证不关闭。

## 人工检查

- 17e baseline 首屏可辨 header、summary、search 和至少 8 条句子，无水平裁切；左侧遮罩保留可点击区域。
- mixed 图清晰区分 0/1/2/3 次，完成行同时有珊瑚色装饰条、3/3 文本与“已掌握”语义，不只依赖颜色。
- 17 Pro word search 只显示 comfortable，音标/中文释义和 clear 未挤压或越界。
- accessibility 3 图中 header、课程名、stats 与搜索自适应换行，关闭按钮保持 44 pt，列表仍可纵向滚动。
- 四张均为真实 App 页面，不含键盘、App Switcher、测试 runner 或调试浮层。

P3.5 只验收进度抽屉静态 Shell。正式进度仓库、合并/outbox、同步和恢复属于 P6；远程课程属于 P7。
