# P6.1 跟读评分 Golden Fixtures

状态：原评分迁移 PASS；15 分产品调整已开发，待独立复核

## 范围

- 从 Web 原实现无行为变化地提取纯 TypeScript scorer。
- 共享匿名 JSON fixtures 覆盖 normalization、noise labels、最多 12 token 候选窗口、Levenshtein、15 分阈值、contraction/`'em` 和句子 60% 覆盖。
- 在 WordLoopCore 实现纯 Swift scorer，逐 fixture 对齐 `passed/score/matched`。
- 不接麦克风、Realtime、Audio Session、UI 或网络。

## 最终结果（2026-07-18）

- Web 原评分逻辑已无行为变化地提取到 `app/repeat-scorer.ts`，页面只调用组合后的 `scoreRepeatTranscript`。
- 10 条共享匿名 JSON fixtures 覆盖 exact/noise、近似匹配、空匹配、相邻窗口、12-token 上限、句子低于/等于 60% 覆盖、contraction/`em` 与重复词集合语义。
- `WordLoopCore.RepeatScorer` 以纯 Swift 实现相同的 ASCII normalization、候选插入顺序、Levenshtein、JS 正数 round、15 分阈值和覆盖计算；逐 fixture 的 `passed/score/matched` 完全一致。
- 验证：Core 10/10（golden 1/1）、Web/Node 64/64、统一 iOS verify、Web build、baseline 与 diff check 通过；lint 保持既有 4 errors/0 warnings，没有新增问题。未改 App/Feature/UI，按范围未跑 UI。

## 15 分产品调整（2026-07-24）

- 按产品决定将 Web、VPS 线上 Web 与 iOS 的词面相似度通过门槛统一从 20 分调整为 15 分。
- 句子至少 60% 单词覆盖率、精确匹配、normalization、候选窗口和 Levenshtein 计算均不改变。
- 不新增测试用例；只同步既有 Web 静态断言。当前状态为已开发，待独立复核。
- 定向验证：Swift Core 10/10 通过；Web `rendered-html` 30/31，评分阈值断言通过，唯一失败为既有启动页用户名文案断言，与评分修改无关。
