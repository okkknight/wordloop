# P3.2 启动页视觉验证

执行日期：2026-07-15

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- 390 × 844 pt 基线设备：iPhone 17e，截图 1170 × 2532 px。
- 标准设备：iPhone 17 Pro，402 × 874 pt，截图 1206 × 2622 px。
- 状态栏固定为 09:41、满电、稳定网络图标；截图等待 App 完成启动过渡后采集。
- rose palette 固定为 `#f8d9df / #4b1934 / #157d6a`。所有状态由内存 fixture 和 launch argument 驱动，不访问网络或持久化。

## 证据

| 文件 | 状态与 fixture | SHA-256 |
| --- | --- | --- |
| [`screenshots/iphone-17e-startup-idle.png`](screenshots/iphone-17e-startup-idle.png) | 390 × 844 pt；idle；`-wordloop-fixture-reduce-motion` | `c36fcea89711eae9e1c38571b17083349c877b4d871163dc90e7e7f5314e3f3a` |
| [`screenshots/iphone-17e-startup-invalid.png`](screenshots/iphone-17e-startup-invalid.png) | 390 × 844 pt；invalid；`-wordloop-startup-invalid -wordloop-fixture-reduce-motion` | `fe813b5652f8363e462dab3c2250adc3a80eba10603f24d490396ca7dfcac833` |
| [`screenshots/iphone-17-pro-startup-syncing.png`](screenshots/iphone-17-pro-startup-syncing.png) | 402 × 874 pt；syncing；`-wordloop-startup-state syncing -wordloop-fixture-reduce-motion` | `0a788388adff3e5d62536590c75b7182aeb032658865d2d05d7c608227c0fdc3` |
| [`screenshots/iphone-17e-startup-accessibility-reduce-motion.png`](screenshots/iphone-17e-startup-accessibility-reduce-motion.png) | 390 × 844 pt；accessibility 3、invalid、Reduce Motion fixture | `830897ea16aef392dc96d21a93517246785d8829e4c56de76fbd119659fdbca3` |

## 与 Web 基线的核对

- 信息层级保持为单线 `USERNAME`、胶囊 `START` 和按需错误/状态文案；没有新增 Logo、欢迎卡、Tab Bar、课程商店或桌面导航。
- 390 pt idle 的表单仍位于视觉中心；输入线宽约 238 pt，按钮约 124 pt 内容宽，间距和 rose 色板与 [`../../baseline/screenshots/iphone-startup.png`](../../baseline/screenshots/iphone-startup.png) 一致。
- Web 截图是 390 × 844 CSS viewport，不带 iOS 状态栏/Home Indicator；原生截图保留系统 Safe Area 与系统栏，这是预期平台差异。
- Web 用浏览器 backdrop blur 覆盖尚未激活的主学习页。P3.2 尚未实现 P3.3 主学习页，因此原生 fixture 使用相同最终 rose 可见色，不伪造不可见的业务页面；接入主学习页时再复核系统材质是否需要保留。
- SwiftUI 使用原生 TextField、键盘、Dynamic Type 和 accessibility tree，字形抗锯齿与浏览器截图会有像素级差异；字体家族仍是已审计的 Geist Sans/Mono。
- 首次独立复核发现 Web 风格的低透明 placeholder/下划线在 rose 上只有 2.071:1/2.822:1。刷新版本保持 canonical palette 不变，改用预合成后的 sRGB 角色：placeholder 为 ink 72% 合成色（约 5.084:1），下划线为 accent 86% 合成色（约 3.157:1）；UI 与单元测试引用同一角色对象。

## 人工检查

- 四张截图均为真实 App 页面，尺寸和 hash 与表格一致，无 App Switcher、键盘调试浮层、启动黑边或 Design System gallery。
- idle、invalid 和 syncing 的输入、按钮、错误、辅助文案没有重叠或横向裁切；busy 按钮除降低透明度外还显示明确文案并在 accessibility tree 中 disabled。
- accessibility 3 下用户名、中文错误和 START 均完整可见；错误未覆盖输入或按钮，页面仍留有充足 Safe Area。
- UI automation 在键盘打开并输入后确认提交按钮仍可点击；Return 提交使用与按钮相同的 `submit()` 路径。
- 根页面、输入、错误、辅助状态和按钮均有稳定 identifier；输入有“可选”和英文字符限制提示，装饰图标从 accessibility tree 隐藏。
- Reduce Motion fixture 让启动内容使用零位移分支；三态和验证结果不依赖颜色或动画表达。

P3.2 只验收启动页静态 Shell。真实匿名 ID、用户名持久化、最近课程/进度恢复、outbox、网络降级进入和主学习页切换留给 P6；当前截图与状态不得解释为这些业务已接通。
