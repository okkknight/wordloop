# P3.6 完成对话框与 REPEAT 静态状态视觉验证

执行日期：2026-07-16

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- iPhone 17e：390 × 844 pt，截图 1170 × 2532 px；对话框最大内容宽度 320 pt、页面外边距 24 pt、内容内边距 24 pt。
- iPhone 17 Pro：402 × 874 pt，截图 1206 × 2622 px。
- 所有完成状态、错误、transcript 与 REPEAT 状态均来自内存 fixture；未重置/累计进度，未读取课程包，未播放音频，未请求麦克风，未连接 Realtime、API、网络或持久化。

## 证据

| 文件 | 状态与 fixture | SHA-256 |
| --- | --- | --- |
| [`iphone-17e-restart-dialog.png`](iphone-17e-restart-dialog.png) | 已完成课程；`-wordloop-study-shell -wordloop-completion-dialog restart` | `c522156caa02ec386d0ba44f231c1642317d54f6519f5f1b097deb00ec71cdde` |
| [`iphone-17e-complete-error.png`](iphone-17e-complete-error.png) | 自然完成与固定错误；`-wordloop-completion-dialog complete -wordloop-completion-error` | `17725e567a736922bad5aff774b133bf7e34e3187ecd658341d16ca7d87ec8ac` |
| [`iphone-17e-speaking.png`](iphone-17e-speaking.png) | `speaking` 强调波形；`-wordloop-study-repeat -wordloop-repeat-state speaking` | `a41fa0f77a845616bb12ec0569fc9e190c9165f16e7cd4c2b816729d360f22cd` |
| [`iphone-17-pro-passed.png`](iphone-17-pro-passed.png) | `passed` 成功勾号；`-wordloop-study-repeat -wordloop-repeat-state passed` | `c2e4b660182a1e5572e17cbf01e3703013b93d7b6882ea37598f762620c6e899` |
| [`iphone-17e-retry-accessibility3.png`](iphone-17e-retry-accessibility3.png) | `retry`、长 transcript、accessibility 3、Reduce Motion；XCTest 真实上滑后截图 | `9b0a12e218cc7978375bfd3fa8558fa4486262a114cb3a8e76860108798bbcf4` |

## 与 Web 基线核对

- 两类 `COURSE COMPLETE` 对话框保留冻结标题、正文和按钮文案；原生层使用 `.ultraThinMaterial` 与不可点击的暗色遮罩表达 Web 8 px blur，没有复制 DOM filter。
- restart 的次按钮为可见描边按钮，主按钮保持暗底高对比角色；natural completion 同样保留“选择课程 / 再练一次”，固定错误属于 dialog state，不是 toast。
- completion dialog 优先于 CourseDrawer 和 ProgressDrawer。选择课程是唯一会主动打开既有课程抽屉的入口；重新开始/再练一次只发出 presentation intent 并关闭，不显示成功、不清零 S01E01、75/91 或 1/3。
- REPEAT 完整映射为 `idle / connecting / ready / playing / speak / speaking / scoring / passed / paused / retry / error`；默认 `playing` 仍显示既有 `LISTENING / 先听一遍标准发音`，没有改变 P3.3 基线。
- `passed` 使用圆形勾号而非波形；只有 `retry/error` 显示 `YOU SAID` transcript。当前仍是静态 Shell，不代表音频、录音、评分或自动状态迁移已接通。

## 对比度与可访问性

- dialog 小正文使用 ink 75% 在不透明 dialog background 上真实合成，六 palette 最低 5.068:1；dialog/次按钮边界使用 ink 56%，最低 3.097:1。
- 主按钮与错误使用 `accessibleAccentText`，六 palette 最低 8.764:1。canonical accent 只保留为主按钮细边框或装饰，不单独承担小字语义。
- `speaking` 强调波形使用可达标角色，最低 8.764:1；成功与失败视觉在各 palette 上自动回退，最低分别 3.162:1 与 3.112:1。标题、提示和 accessibility label 同时表达状态，不依赖颜色或波形。
- dialog 具备 modal trait，显示时主学习页与两个抽屉从 hit-test/accessibility 路径隔离；遮罩点击不关闭。两个明确按钮在 accessibility 3 下纵向排列且命中高度至少 44 pt。
- accessibility 3 的 retry 首屏保持阅读顺序，页面可纵向滚动。证据图由 UI test 上滑到 transcript 与底部控制后直接留存，完整长文本、PAUSE 和 NEXT 同屏，NEXT 实测可点击且无水平越界。
- `-wordloop-fixture-reduce-motion` 下 waveform 不重复动画；dialog 只使用淡入淡出，不做大位移。

## 人工检查

- 两张 iPhone 17e dialog 图均为干净的真实 App 全屏：系统状态栏、Safe Area 和 Home Indicator 正常，没有黑边、键盘、App Switcher、测试 runner 或调试浮层。
- restart 与 complete/error 图在 390 pt 宽度下完整显示 kicker、标题、正文、错误和两个按钮；320 pt 最大内容宽度、24 pt 外边距/内边距和 16 pt 圆角可辨。
- speaking 图保持 P3.3 的 poster 层级并增加高强度波形；passed 图用清晰圆形勾号替换波形，没有横向越界。
- retry 辅助字号图明确展示滚动后的完整 transcript 与底部操作，证明内容可达；顶部内容离开视口是用户滚动结果，不是裁切。

P3.6 只验收完成对话框与 REPEAT 纯展示态。课程解析/真实 LISTEN 属于 P4，服务端重练属于 P5，持久进度属于 P6，麦克风/Realtime 状态机属于 P6 后续卡，远程课程属于 P7。
