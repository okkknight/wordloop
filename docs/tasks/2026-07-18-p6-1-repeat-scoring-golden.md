# P6.1 跟读评分 Golden Fixtures

状态：PASS

## 范围

- 从 Web 原实现无行为变化地提取纯 TypeScript scorer。
- 共享匿名 JSON fixtures 覆盖 normalization、noise labels、最多 12 token 候选窗口、Levenshtein、20 分阈值、contraction/`'em` 和句子 60% 覆盖。
- 在 WordLoopCore 实现纯 Swift scorer，逐 fixture 对齐 `passed/score/matched`。
- 不接麦克风、Realtime、Audio Session、UI 或网络。

## 最终结果（2026-07-18）

- Web 原评分逻辑已无行为变化地提取到 `app/repeat-scorer.ts`，页面只调用组合后的 `scoreRepeatTranscript`。
- 10 条共享匿名 JSON fixtures 覆盖 exact/noise、近似匹配、空匹配、相邻窗口、12-token 上限、句子低于/等于 60% 覆盖、contraction/`em` 与重复词集合语义。
- `WordLoopCore.RepeatScorer` 以纯 Swift 实现相同的 ASCII normalization、候选插入顺序、Levenshtein、JS 正数 round、20 分阈值和覆盖计算；逐 fixture 的 `passed/score/matched` 完全一致。
- 验证：Core 10/10（golden 1/1）、Web/Node 64/64、统一 iOS verify、Web build、baseline 与 diff check 通过；lint 保持既有 4 errors/0 warnings，没有新增问题。未改 App/Feature/UI，按范围未跑 UI。
