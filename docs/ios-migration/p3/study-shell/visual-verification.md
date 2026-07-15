# P3.3 主学习页视觉验证

执行日期：2026-07-15

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- 390 × 844 pt 基线设备：iPhone 17e，截图 1170 × 2532 px。
- 标准设备：iPhone 17 Pro，402 × 874 pt，截图 1206 × 2622 px。
- sun palette 固定为 `#f5d547 / #282044 / #e85b44`；所有页面状态来自内存 fixture，不读取课程包、不播放音频、不写进度。
- 标准截图使用系统 Medium 内容字号；辅助字号截图由 `-wordloop-fixture-accessibility-text` 固定到 SwiftUI accessibility 3，并同时启用 Reduce Motion fixture。

## 证据

| 文件 | 状态与 fixture | SHA-256 |
| --- | --- | --- |
| [`iphone-17e-repeat.png`](iphone-17e-repeat.png) | 390 × 844 pt；sentence / repeat / full；`-wordloop-study-shell -wordloop-study-mode repeat -wordloop-fixture-reduce-motion` | `0ca31b88122fef3a211f3facf50bc7eda047ce486513b9bbfc08fae8c23cb39d` |
| [`iphone-17e-listen.png`](iphone-17e-listen.png) | 390 × 844 pt；sentence / listen / full；`-wordloop-study-shell -wordloop-study-mode listen -wordloop-fixture-reduce-motion` | `05d11f885772feefad9b0565e39410c9a907218565c08f38514a6ec6e6ed7bb8` |
| [`iphone-17-pro-long-word-hidden.png`](iphone-17-pro-long-word-hidden.png) | 402 × 874 pt；long-word / listen / hidden；`-wordloop-study-item long-word -wordloop-study-visibility hidden` | `1fa713f0577b209805c3bdd2a34d37c33d07e8ed5f32a7102bf8aaf379b5bb26` |
| [`iphone-17e-accessibility3-reduce-motion.png`](iphone-17e-accessibility3-reduce-motion.png) | 390 × 844 pt；sentence / repeat / accessibility 3 / Reduce Motion；页面启用纵向可达滚动 | `f241daa70ecc6b5df4b99cd860b13c19361aef12c4e32c35b697fc09b15553b0` |

## 与 Web 基线核对

- 保留顶部 `COURSE / LISTEN-REPEAT / PROGRESS`、课程上下文、`75/91`、超大英文、中文、两个学习动作、左下熟练度和右下模式控制；没有增加 Tab Bar、桌面侧栏或 iPad 分栏。
- repeat 基线保留独立 `LISTENING / 先听一遍标准发音` 卡片和波形层级；P3.3 只有这个展示态，不能解释为录音或完整 REPEAT 状态机已经接通。
- Listen 模式移除 repeat 卡片并把主控制切为 `AUTOPLAY`；页面仍使用相同学习内容和进度布局。
- Web 390 × 844 截图不带系统栏；原生截图保留状态栏、Home Indicator 和 Safe Area，内容没有进入系统遮挡区。
- [`../../baseline/screenshots/iphone-listen.png`](../../baseline/screenshots/iphone-listen.png) 中的黑色矩形不对应 DOM/CSS 控件，是 420 ms palette/background 过渡期间的历史捕获伪影。原生证据明确没有复制黑块；装饰层只有 sun accent 圆环。
- Web 使用 CSS 点状重点下划线；SwiftUI 当前使用可访问的实线 underline，range 来自 Character offset 展示模型，重复词、标点和非法范围由单测覆盖，不执行全局字符串替换。

## 人工检查

- 两张 iPhone 17e 标准字号页面均为真实 390 × 844 pt App 截图；顶栏、正文、repeat card 和底部控制完整显示，没有横向滚动、裁切、Home Indicator 覆盖或调试浮层。
- 英文保持第一视觉层级，课程与序号不与右上装饰圆争抢阅读；中文和控制使用通过对比测试的 ink/semantic role，没有把低对比 accent 直接用于小字。
- long-word hidden fixture 只显示圆点替代并移除隐藏正文、音标和释义的 accessibility 元素；visibility 控件仍说明当前状态和下一动作。
- accessibility 3 将顶栏重排为两行、底部控制重排为两组，并只在辅助字号启用纵向 ScrollView。截图显示初始阅读区，UI test 继续向上滚动并确认 `NEXT` 可点击，证明底部控制可达而非被裁掉。
- 所有命中控件至少使用 `WordLoopSpacing.minimumHit = 44`；UI automation 实际点击 mode、visibility、AUTOPLAY/PAUSE，并检查边缘按钮仍在设备水平边界内。
- Reduce Motion fixture 清零内容进入位移与 palette 动画，并让 waveform 停止循环；页面颜色、选中态和文案不依赖动画表达。

P3.3 只验收主学习页静态 Shell。课程/进度抽屉、完成弹窗和完整 REPEAT 卡片状态分别留给 P3.4–P3.6；课程解析、真实播放、持久进度、网络同步、麦克风与 Realtime 均未实现。
