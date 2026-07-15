# P3.1 Design System 视觉验证

执行日期：2026-07-15

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- 标准验证：iPhone 17 Pro，402 × 874 pt，截图 1206 × 2622 px。
- 390 × 844 基线与最窄本机设备验证：iPhone 17e，390 × 844 pt，截图 1170 × 2532 px。
- 状态栏固定为 09:41、满电、稳定网络图标。
- gallery 是明确标注的 presentation-only fixture，不连接课程、网络、音频、进度或麦克风。

## 证据

| 文件 | 状态 | SHA-256 |
| --- | --- | --- |
| [`screenshots/iphone-17-pro-gallery.png`](screenshots/iphone-17-pro-gallery.png) | 标准字号、完整 Design System gallery | `ad29cb501fed092f99083170766ff5d467b23b807cde3c4ba27fc276f730f7b7` |
| [`screenshots/iphone-17e-gallery.png`](screenshots/iphone-17e-gallery.png) | 390 × 844 pt 最窄设备、标准字号 | `88b4cebc29a1f27b5d56effa707eff251ebf17870c8057061a01e8a46a20b913` |
| [`screenshots/iphone-17e-accessibility-reduce-motion.png`](screenshots/iphone-17e-accessibility-reduce-motion.png) | accessibility 3 字号、fixture 强制 Reduce Motion | `951eaa37b44865a984d46bc728a01125ace905ae3352d7fa0d7ecc182274ae47` |

## 人工检查

- 六套 palette 的 background、ink、accent 均出现，顺序与 Web 机器基线一致。
- 六套 `ink / background` 和小文字角色均由单元测试锁定为至少 4.5:1；装饰 accent 原值不变，accent 不足时仅小文字角色回退到 ink。
- Geist Sans/Mono 已在模拟器渲染；没有空白字体或退回后导致的布局缺失。
- 390 pt 宽度下 gallery 没有横向溢出；标题按宽度换行，palette 仍保持三列可辨识。
- accessibility 3 下大标题、说明、palette label 和 ModeSwitch 放大并换行；页面通过自身 ScrollView 保持内容可达，不横向裁切。
- Reduce Motion fixture 通过 launch argument 让 Waveform 保持静态；同一组 launch arguments 已由 UI test 验证可启动。
- UI tests 可操作 dialog 的 `CANCEL` 与 drawer 的关闭按钮，证明两个 modal visual container 暴露可用的 VoiceOver 控件。
- 最小命中尺寸由 `WordLoopSpacing.minimumHit = 44` 和组件测试固定；纯装饰圆环从 accessibility tree 隐藏。

P3.1 只验收视觉基础层。启动页、主学习页、课程/进度抽屉的最终信息结构和逐页截图分别留给 P3.2–P3.5。
