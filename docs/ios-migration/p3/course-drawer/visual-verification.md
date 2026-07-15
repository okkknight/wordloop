# P3.4 课程抽屉视觉验证

执行日期：2026-07-15

## 设备与固定状态

- Xcode `26.6` / iOS Simulator `26.5`。
- iPhone 17e：390 × 844 pt，截图 1170 × 2532 px；抽屉按 `86%` 视口计算为 335.4 pt。
- iPhone 17 Pro：402 × 874 pt，截图 1206 × 2622 px；抽屉命中 344 pt 上限。
- 所有状态均来自 `CourseDrawerViewState` 内存 fixture；不读取正式课程包、不切换学习内容、不访问网络、不下载课程、不写进度。

## 证据

| 文件 | 状态与 fixture | SHA-256 |
| --- | --- | --- |
| [`iphone-17e-default.png`](iphone-17e-default.png) | 默认展开摩登家庭；S01E01 selected、S01E01/S01E02 完成次数；`-wordloop-study-shell -wordloop-course-drawer` | `9653eaea9434464d5431996d276c29b4490cb185d3abe545002a2b9d0fabbc12` |
| [`iphone-17e-empty.png`](iphone-17e-empty.png) | 搜索空结果和 clear；`-wordloop-course-empty` | `1af1a2cb084541e519f3ccfe066fdde04aac71b42600c452df923c12bf8da706` |
| [`iphone-17-pro-completion.png`](iphone-17-pro-completion.png) | 标准字号完成次数 fixture，S01E02 显示 `× 12`；`-wordloop-course-completion 12` | `293dc69fcd662866b9fde0dd1c8bd10bb9b842aa80b775ea042c85244702b283` |
| [`iphone-17e-accessibility3-reduce-motion.png`](iphone-17e-accessibility3-reduce-motion.png) | 三集合收起、accessibility 3、Reduce Motion；`-wordloop-course-collapsed -wordloop-fixture-accessibility-text -wordloop-fixture-reduce-motion` | `344222db1269b334b803865c59f7e08b629e26c434779deacbc8abc6f57155fc` |

## 与 Web 基线核对

- 保留左侧进入、黄色 poster 背景、暗色右侧遮罩、`COURSE PACKAGES / 选择课程`、搜索、集合加减号、课程卡、珊瑚色当前态和完成次数；没有增加 Tab Bar、课程商店、iPad 分栏或桌面侧栏。
- Web 390 × 844 证据不含系统栏；原生页面保留状态栏、Dynamic Island/Home Indicator 和 Safe Area。抽屉按 iPhone 可用宽度计算，右侧始终保留可点击遮罩。
- iOS 使用原生 `TextField`、`ScrollView`、Button 和 modal accessibility tree；没有复制 DOM backdrop-filter。只有课程列表纵向滚动，header 与搜索保持固定。
- P3.4 点击课程只关闭 fixture 抽屉；UI test 随后仍读取 `MODERN FAMILY · S01E01` 和 `75/91`，没有伪造真实切课。

## 对比度与可访问性

- sun palette 的不透明 ink/background 为 8.746:1；header、集合标题、搜索和空态直接使用该语义组合。
- `CourseCard` 次要文字使用 ink 75% 的真实 sRGB 合成角色，六套 palette 最低为 5.068:1；卡片边界使用 ink 56%，六套最低为 3.097:1。测试按 SwiftUI 实际底层顺序合成，不用原始色替代最终像素。
- selected 卡保留 canonical accent 的 2 pt 外框，并增加上述 3:1 内侧 ink 边界；选中语义同时通过 `.isSelected` trait 和“当前课程”标签表达，不依赖颜色。
- completion badge 朗读为“已完成 N 次”；集合按钮暴露“已展开/已收起”；关闭按钮、搜索、集合和课程卡均有稳定 identifier。
- modal 打开后背景学习页从 accessibility tree 隔离。header、右侧遮罩和主导左滑三种关闭入口均由真实 UI automation 点击/手势验证；不足阈值和纵向 drag 由 Store 单测验证不关闭。

## 人工检查

- iPhone 17e 默认图中 header、搜索、三个集合和 S01E01–S01E05 均可辨；列表没有横向裁切，右侧遮罩可见且不覆盖抽屉。
- 空态文案精确为“没有匹配的课程”，clear 位于至少 44 pt 命中区内；清除后列表由 UI test 恢复。
- iPhone 17 Pro 图明确显示 S01E02 `× 12`，当前课程仍为 S01E01；完成次数没有挤压标题或超出卡片。
- accessibility 3 图中 kicker、标题、搜索与三集合按内容增高换行，关闭按钮不与标题重叠；列表仍可滚动。Reduce Motion 移除大位移，但不改变展示状态和关闭语义。
- 四张均为真实 App 页面，不含键盘、App Switcher、测试 runner 或调试浮层。

P3.4 只验收课程抽屉静态 Shell。正式课程解析/切换属于 P4，最近课程与进度恢复属于 P6，远程 catalog、下载、更新、删除与失败重试属于 P7。
