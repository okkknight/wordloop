# WordLoop 课程制作规范

本规范基于《Modern Family》S01E01、S01E02 的实际制作流程。目标是把一集双语字幕和原始音频制作成可直接进入 WordLoop 的句子课程包：句子、中文翻译、逐句音频，以及可选的可复用表达标记。

## 1. 成品标准

每个课程包必须满足：

- 以完整、有独立学习价值的英语句子为最小练习单位；不按单词或任意时长切片。
- 每个可学习句子都要有与字幕时间线对应的独立音频片段。
- 保留原剧顺序，课程使用 `practiceOrder: "sequential"`。
- 不收录西语或其他非英语台词、纯人名、语气词、重复应答、舞台说明、多人混杂台词、明显断句和无上下文价值的片段。
- 仅对有复用价值、不过分低幼的单词、词组或固定搭配添加点状下划线标记；无合适标记的句子保持不标记。
- 原始剧集音频、压缩包和临时工作文件不进入 Git；仅提交最终 manifest、课程配置、标记文件和切分后的音频。

第一、二集分别保留 220、217 句。这是质量参考，不是固定配额；宁可少收录，也不要为凑数量保留低价值语料。

## 2. 输入与目录约定

准备以下输入：

1. 一份原始音频文件，例如 `modernfamily/S01E03. .mp3`。
2. 一份同集双语 ASS 字幕。字幕应含英文和中文，并使用可被 Python `utf-16` 读取的编码；若不是，请先转换编码。

使用以下临时目录，不提交：

```text
work/modern-family-s01e03/
  source/S01E03.ass
  manifest.json
  audio/
```

最终受版本控制的目录：

```text
app/data/modern-family-s01e03.json
app/data/modern-family-s01e03-highlights.ts
public/courses/modern-family/s01e03/audio/
```

课程 ID、文件名和音频 ID 统一使用小写剧集编号：`modern-family-s01e03`、`s01e03-0001`。

### 2.1 先验证源音内容（必做）

不要仅相信原始音频的文件名。制作前应试听开头、中段和结尾，确认它们与同集字幕内容一致；若文件名与内容不符，绝不能按文件名直接切片。

对来源复杂或已发现错位的媒体，先以 `scripts/transcribe_course_audio.py --word-timestamps` 生成实际音频的单词时间戳，再使用 `scripts/align_modern_family_episode.py` 将字幕与转写结果顺序对齐。该脚本会在同集覆盖率不足时拒绝输出，防止错集音频进入课程包。

## 3. 生成流程

### 3.1 初次生成

从仓库根目录运行。将字幕路径和音频路径替换为当前剧集的实际位置：

```bash
python3 scripts/prepare_modern_family_episode.py \
  --episode S01E03 \
  --subtitle work/modern-family-s01e03/source/S01E03.ass \
  --audio 'modernfamily/S01E03. .mp3' \
  --output work/modern-family-s01e03
```

脚本会：

- 读取 ASS 时间线，抽取英文与中文；
- 生成稳定的句子 ID、起止时间和时长；
- 进行基础筛选，并在 `reviewReasons` 中记录原因；
- 为保留句子用 `ffmpeg` 切出 48 kbps 单声道 AAC `.m4a` 文件；
- 写出 `work/.../manifest.json`。

若只想先审核文本、不切音频，添加 `--no-audio`。人工筛选规则更新后，应删除当前工作目录内旧的 `audio/` 文件，再完整重新运行脚本，防止已被过滤句子的旧片段残留。

### 3.2 人工审核（必做）

自动筛选只负责明显问题，不能代替内容判断。按原剧顺序逐句审阅 `manifest.json` 中 `learnable: true` 的条目，重点检查：

- 句子是否完整、自然，能脱离具体画面练习；
- 是否是无意义的寒暄、纯应答、重复喊叫或角色名；
- 是否是字幕切断的半句话，或两人台词被拼在一起；
- 是否有西语、口音转写乱码、文化梗残片或不适合学习的表达；
- 中文翻译是否存在；缺失翻译的条目不能直接上线。

应保留的典型表达：`be supposed to`、`take advantage of`、`keep up with`、`I've been meaning to`、`make a judgment call`、`I've been down this road before`、`no matter what`。

应剔除的典型内容：纯人名；`No, no, no, no.`；单独的 `Okay.`；无语境碎片；字幕转写错误或含其他语言的台词。

如果某类低质量内容在多集重复出现，可把**规范化后的完整句子**加入脚本的 `LOW_VALUE_EXACT`，或把明显外语词组加入 `NON_ENGLISH_PATTERNS`。不要为单个偶发问题写过宽正则，避免误删正常句子。`SHORT_KEEP` 只用于少量虽短但确有复用价值的完整表达。

完成音频对齐后，还要逐条进行第二轮人工筛选：剔除必须依赖人物关系或剧情才能理解的句子、单独应答、重复台词、过度低幼表达和复用价值低的文化梗。将结论记录在 `app/data/modern-family-manual-exclusions.json`，并用 `scripts/apply_modern_family_manual_review.py` 同步移除 manifest、音频和高亮中的对应条目。

### 3.3 复制最终资产

审核完成并重新生成后，复制最终 manifest 和音频：

```bash
mkdir -p public/courses/modern-family/s01e03/audio
rsync -a --delete work/modern-family-s01e03/audio/ public/courses/modern-family/s01e03/audio/
cp work/modern-family-s01e03/manifest.json app/data/modern-family-s01e03.json
```

`--delete` 只应作用于当前剧集的最终音频目录，确保音频数量与 manifest 内的可学习句子数一致。

## 4. 学习表达标记

在 `app/data/modern-family-s01e03-highlights.ts` 创建标记表：

```ts
export const MODERN_FAMILY_S01E03_HIGHLIGHTS: Readonly<Record<string, readonly string[]>> = {
  "s01e03-0012": ["look forward to", "for a while"],
  "s01e03-0041": ["take it for granted"],
};
```

规则：

- 标记值必须是该句英文中原样存在的连续文本；匹配不区分大小写。
- 可以在一句中标记多个片段；片段可以跨单词，但不应为了覆盖整句而滥标。
- 优先标记可迁移到日常表达的固定搭配、动词短语、自然句型和高价值语块。
- 不标记专有名词、单纯基础词、剧情专属信息、纯语法功能词或低幼表达。
- 大约半数以上的句子有高价值标记即可；没有合适表达时不要强加标记。

## 5. 接入课程包

在 `app/courses.ts` 按 S01E01/S01E02 的模式新增：

1. import 新 manifest 和 highlights；
2. 从 `entries` 中筛选 `learnable && audio`；
3. 将音频路径前缀设为 `${basePath}/courses/modern-family/s01e03/`；
4. 向 `COURSE_PACKAGES` 新增课程：

```ts
{
  id: "modern-family-s01e03",
  title: "Modern Family · S01E03",
  subtitle: `Come Fly with Me · ${modernFamilyS01E03Entries.length} learning sentences`,
  description: "用真实对白练习听力、表达和跟读。",
  kind: "sentence",
  practiceOrder: "sequential",
  entries: modernFamilyS01E03Entries,
}
```

除非产品明确要求，否则不要改变现有默认课程。每个课程独立保存学习进度，接入新课程不应影响已有课程。

## 6. 验收清单

提交前至少完成以下检查：

- [ ] `manifest.episode`、课程 ID、目录名、音频 ID 的剧集编号完全一致。
- [ ] `learnable: true` 的每一项都有 `audio` 字段和对应的 `.m4a` 文件。
- [ ] 音频文件数等于可学习句子数。
- [ ] 已验证源音内容与同集字幕一致；错标文件不可进入切片流程。
- [ ] 对经过转写对齐的课程，`scripts/verify_modern_family_course.py` 已通过。
- [ ] 已完成逐条人工复核，低价值条目已记录在课程审阅清单中。
- [ ] 所有 highlight 只指向可学习句子，且每个短语都存在于原句。
- [ ] 试听若干开头、中段、结尾音频，确认没有明显错位或截断。
- [ ] 在课程切换器中能看到新课程；进入后可播放、跟读、前进和恢复进度。
- [ ] `npm run lint && npm test && git diff --check` 全部通过。

可用以下脚本快速核对 manifest 和音频数量：

```bash
python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path("app/data/modern-family-s01e03.json").read_text())
learnable = [item for item in manifest["entries"] if item["learnable"]]
audio = list(Path("public/courses/modern-family/s01e03/audio").glob("*.m4a"))
assert all(item.get("audio") for item in learnable)
assert len(learnable) == len(audio), (len(learnable), len(audio))
print(f"{len(learnable)} learning sentences and {len(audio)} clips")
PY
```

## 7. 提交与部署

仅暂存新课程相关的 manifest、highlights、音频、课程配置、测试和必要的筛选脚本改动。确认不包含 `modernfamily/` 原始媒体或 `work/` 临时文件后提交、推送。

部署到 VPS 后，应验证：

1. 前端和 API 服务均为 `active`；
2. `https://boringmax.com/wordloop/` 返回 HTTP 200；
3. 任一新剧集音频 URL 返回 HTTP 200；
4. 线上课程切换器中能进入新课程。

## 8. 后续维护原则

- 筛选规则是共享资产：新增规则要能解释其适用范围，并在已有剧集中避免产生意外影响。
- 课程内容是学习产品，不是完整字幕存档；质量优先于覆盖率。
- 新增剧集后，如发现通用问题，应修正制作脚本并重新审核受影响课程，而不是只在前端隐藏。
- 若字幕本身不可靠，先修正字幕或标记为不制作；不要用猜测补全时间线或翻译。

## 9. 非剧集音频课程

对公开授权的对话、短讲或短文音频，也可以制作课程包。额外要求：

- 保存来源 URL、创作者/机构署名与授权说明；第三方通讯社、受限转载素材不能使用。
- 优先使用来源提供的独立对话音轨和逐角色文本；去除教学旁白、片头片尾与舞台说明。
- 没有时间轴时，可用 `scripts/transcribe_course_audio.py` 生成 Whisper 分段，再逐句与官方文本人工对齐后切音频。
- 课程标题应标注内容形式与建议 CEFR 等级，例如 `DIALOGUE · B1`、`SHORT TALK · B2`；等级是内部学习推荐，不是来源的官方认证。
