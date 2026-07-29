# iPhone 产品验收矩阵

## 1. 冻结范围

- 只冻结 iPhone 移动端体验，不实现桌面端、iPad 或 macOS 布局。
- Web 是行为、文案和可见结果的基准，不迁移浏览器实现技术。
- 必须覆盖启动页、主学习页、课程抽屉、进度抽屉、完成/重练对话框。
- 默认课程是 `modern-family-s01e01`，默认模式是 `REPEAT`。
- `LISTEN` 与 `REPEAT` 进度分开；课程完成次数和最近课程偏好按当前服务端合同共用。
- 原生内容以 Safe Area 为边界，保持 20–24 pt 视觉边距；点击区域至少 44 × 44 pt。

主要证据：`app/page.tsx:460-2162`、`app/globals.css:7-774`、[`content-inventory.json`](content-inventory.json)。

## 2. 页面矩阵

### M-01 启动页

| 验收项 | 冻结要求 | 来源 |
| --- | --- | --- |
| 输入 | placeholder `USERNAME`，最多 32 字符，不自动大写，关闭拼写检查 | `page.tsx:1860-1873` |
| 用户名 | 可留空；非空只允许 A–Z/a–z，转小写并保存为 `name:<username>` | `page.tsx:1559-1569` |
| 错误 | 非英文输入显示“用户名只能使用英文字母” | `page.tsx:1561-1564` |
| 主操作 | `START`、`PREPARING…`、`SYNCING…` 三态 | `page.tsx:1875-1878` |
| 辅助状态 | “正在恢复上次课程”或“正在同步学习进度” | `page.tsx:1880-1882` |
| 匿名身份 | 留空时生成并持久化匿名 ID | `page.tsx:39-47` |
| 恢复 | 恢复本地待同步事件、最近课程和远端进度；远端失败或约 650 ms 后仍可进入 | `page.tsx:830-938` |
| 视觉 | 全屏半透明遮罩、约 12 px blur、表单居中、胶囊 START 按钮 | `globals.css:128-199` |

截图：[`iphone-startup.png`](screenshots/iphone-startup.png)。

### M-02 主学习页

| 验收项 | 冻结要求 | 来源 |
| --- | --- | --- |
| 顶栏 | 左 `COURSE`、中 `LISTEN/REPEAT`、右 `PROGRESS` | `page.tsx:1807-1847` |
| 移动文案 | iPhone 顶栏只显示 `PROGRESS`，不显示完成数长文案 | `globals.css:765-766` |
| 上下文 | `{课程标题} · {当前序号}/{总数}` | `page.tsx:1886-1887` |
| 主文本 | 英文单词/句子，句子可对指定表达做点状下划线强调 | `page.tsx:240-260,1888-1894` |
| 副文本 | 句子显示中文；单词显示音标和中文释义 | `page.tsx:1895-1919` |
| 播放 | LISTEN 重播；REPEAT 重新开始当前轮次 | `page.tsx:1483-1491,1897-1908` |
| 文本三态 | 句子全文 → 仅高亮 → 隐藏；单词全文 → 隐藏；隐藏用圆点占位 | `page.tsx:228-260,657-667` |
| 熟练度 | 左下 `{count} / 3` | `page.tsx:2146-2149` |
| 太简单 | 直接置 3/3、反馈并前进；已掌握时禁用 | `page.tsx:1085-1126,1534-1539` |
| 色板 | 换项使用与上一项不同的六色板之一 | `page.tsx:125-139,1519` |
| 结构 | 全屏三行结构，主页面自身不滚动 | `globals.css:3-22` |

截图：[`iphone-repeat.png`](screenshots/iphone-repeat.png)、[`iphone-listen.png`](screenshots/iphone-listen.png)。

### M-03 课程抽屉

| 验收项 | 冻结要求 | 来源 |
| --- | --- | --- |
| 方向 | 从左进入，背景变暗并模糊 | `globals.css:610-622,646-657` |
| 标题 | `COURSE PACKAGES` / “选择课程” | `page.tsx:2003-2006` |
| 搜索 | placeholder “搜索课程” | `page.tsx:2007-2013` |
| 集合 | label、标题、副标题、`+ / −` 展开态 | `page.tsx:2015-2027` |
| 课程卡 | 标题、副标题、当前 accent 边框、完成次数 `× N` | `page.tsx:2028-2041` |
| 空结果 | “没有匹配的课程” | `page.tsx:2047` |
| 关闭 | `×`、遮罩或向左横滑超过 72 pt 且横向位移占优 | `page.tsx:669-682,1988-2005` |
| 滚动 | 只滚动抽屉列表，不带动主学习页 | `globals.css:659-670` |

截图：[`iphone-course-drawer.png`](screenshots/iphone-course-drawer.png)。

### M-04 进度抽屉

| 验收项 | 冻结要求 | 来源 |
| --- | --- | --- |
| 方向 | 从右进入，与课程抽屉镜像 | `globals.css:621-645` |
| 标题 | `YOUR PROGRESS` | `page.tsx:2098-2104` |
| 汇总 | `{学习次数} / {条目数 × 3}` 与当前课程 | `page.tsx:2100-2103` |
| 统计 | “已掌握”“学习中”与进度条 | `page.tsx:2106-2110` |
| 搜索 | 句子搜索句子/翻译；单词搜索单词/释义 | `page.tsx:2111-2117` |
| 列表 | 英文、中文/音标、右侧 `{count} / 3`，完成项为 accent | `page.tsx:2118-2130` |
| 关闭 | `×`、遮罩或向右横滑超过 72 pt | `page.tsx:669-682,2083-2105` |

截图：[`iphone-progress-drawer.png`](screenshots/iphone-progress-drawer.png)。

### M-05 完成与重练对话框

| 场景 | 固定内容 |
| --- | --- |
| 选择已完成课程 | `COURSE COMPLETE`；“这门课程已经完成”；说明进度清零；“取消”“重新开始” |
| 自然完成 | `COURSE COMPLETE`；“这门课程学完了”；“选择课程”“再练一次” |
| 重置失败 | “暂时无法重置进度，请稍后重试。” |

对话框居中、最大可见宽度约 320 pt、外边距 24 pt、内边距 25 pt、圆角 16 pt。可见按钮高度可保持约 34 pt，原生命中区域不少于 44 pt。来源：`page.tsx:1792-1797,2053-2080`、`globals.css:623-633`。

截图：[`iphone-restart-dialog.png`](screenshots/iphone-restart-dialog.png)。

## 3. LISTEN 状态矩阵

| 状态/事件 | 冻结行为 |
| --- | --- |
| 启动 | 播放当前项并记录一次学习 |
| 重播 | 只播放当前片段 |
| 预加载 | 只预加载下一片段，不加载整门课程或全部课程 |
| NEXT/画布轻点 | 停止旧音频，进入下一未掌握项并记录 |
| AUTOPLAY | `AUTOPLAY` / `AUTOPLAY ON`；当前片段结束后等待约 500 ms 再前进 |
| 音频失败 | 关闭自动连续前进，保留手动重试/下一项能力 |
| 课程完成 | 所有条目达到 3 后打开完成对话框 |
| 切课/切模式 | 旧音频回调不得推进新课程 |

来源：`page.tsx:1163-1220,1493-1524,1541-1550,1617-1629,1967-1984`。

## 4. REPEAT 状态矩阵

| 内部状态 | 标题 | 提示 |
| --- | --- | --- |
| idle | `STANDBY` | 跟读模式已准备好 |
| connecting | `CONNECTING` | 正在准备麦克风 |
| ready | `READY` | 听完示范后开始跟读 |
| playing | `LISTENING` | 先听一遍标准发音 |
| speak | `SPEAKING` | 请清晰地跟读 |
| speaking | `SPEAKING` | 正在听你发音 |
| scoring | `CHECKING` | 正在分析这次发音 |
| passed | `GREAT` | 这次发音通过了 |
| paused | `PAUSED` | 准备好后继续练习 |
| retry/error | `TRY AGAIN` | 请再读一次 |

补充边界：

- 播放示范音结束后才 armed；旧 turn、旧 Realtime item 或未 armed 的事件不得评分。
- 播放 8 s、等待开口 6 s、持续说话 6 s、评分 6 s 进入恢复路径。
- retry 分支使用 500/850/1000/1200 ms；切后台 1500 ms 后暂停活动轮次。
- 通过后约 700 ms 自动前进；暂停/恢复和 NEXT 始终可见。
- 通过阈值 20，句子最低词覆盖率 60%，最短语音 350 ms。
- `speaking` 用 accent 波形，失败为静止失败波形，通过为绿色勾号。

来源：`page.tsx:13-24,328-380,724-829,1128-1432,1920-1964`。

## 5. iPhone 视觉尺寸

| 元素 | 基线 |
| --- | --- |
| 页面 | 100svh 可见结果；24 pt 四周视觉边距；页面不整体滚动 |
| 装饰圆环 | 约 110vw，右移约 -55vw，顶部约 -18% |
| 学习区 | 约 4vh 上下空间，整体下移 26 pt |
| 标题 | 普通 46–84 pt；长 40–70 pt；超长 34–58 pt；行高约 0.94 |
| REPEAT 卡 | 屏宽减 48 pt；顶部/上边距约 44 pt；波形区 72 pt |
| 底部控制 | 左右与底部约 20 pt |
| 抽屉 | 屏宽 86%，最大 344 pt，全高 |
| 动效 | 色板 420 ms；主文本 520 ms；抽屉 260 ms；退出 240 ms；波形 880 ms |

来源：`globals.css:7-35,347-398,610-701,735-774`。

## 6. 色板

六组 `background / ink / accent` 以 [`content-inventory.json`](content-inventory.json) 的 `palettes` 为机器真值。切换条目时不得连续使用同一组。

## 7. 移动端手势

| 手势 | 结果 |
| --- | --- |
| 点击 COURSE / PROGRESS | 打开左/右抽屉 |
| 点击模式胶囊 | 停止上一模式活动并进入新模式 |
| 点击学习画布空白 | LISTEN 下一项；REPEAT 非活动阶段重启当前轮次 |
| 点击播放/眼睛/NEXT/太简单 | 重播、文本三态、下一项、直接掌握 |
| 点击遮罩/× | 关闭抽屉 |
| 左滑课程抽屉 / 右滑进度抽屉 | 位移超过 72 pt 时关闭 |
| 抽屉上下滑 | 只滚动列表 |

## 8. 明确不迁移

- 空格键启动/下一项/暂停、R 键重启、`SPACE next ...` 提示。
- hover、鼠标指针、鼠标专属 pointer 分支和桌面 focus-visible 外观。
- 大于 700 px 的排版、桌面超大字号、footer 横排和 PROGRESS 长文案。
- 浏览器 `localStorage`、`HTMLAudioElement`、CSS `color-mix`、DOM WebRTC 等实现技术。
- 桌面窗口、菜单栏、右键、键盘快捷键、iPad/macOS 专属布局。
- 把整个 poster 机械变成覆盖原生控件的透明按钮；只允许非控件学习画布接收轻点。

桌面来源：`page.tsx:1631-1668,2136-2145`、`globals.css:18,52-55,87-90,735-774`。

## 9. iOS 后续验收门

- 最窄支持宽度无横向溢出；主流/大屏 iPhone 保持安全边距。
- Dynamic Type、VoiceOver、Reduce Motion 验收。
- 所有可交互区域至少 44 × 44 pt。
- LISTEN 完整覆盖播放、重播、NEXT、AUTOPLAY、太简单、完成。
- REPEAT 完整覆盖权限、连接、示范、开口、说话、评分、通过、重试、暂停、NEXT、错误。
- 两个抽屉覆盖按钮/遮罩/×/横滑关闭和列表纵向滚动。
- 两类完成对话框与重置失败文案由 UI 测试或真机证据覆盖。
