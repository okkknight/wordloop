# WordLoop VOA 课程制作指南

本指南把 VOA Learning English 的一课制作成 WordLoop 句子课程包。它基于已经完成的 Level 2 课程：`Workplace Conversations · B1`、`Project Feedback · B1`、`Pets & Responsibility · B1` 与 `Visit to Peru · B1`。

适用于 VOA 自制、可复用的对话、短讲或短文。目标是练习自然表达，而不是完整收录节目或语法讲解。

## 1. 成品标准

每个课程包应包含：

- JSON manifest：英语原句、中文翻译、时间轴和相对音频路径；
- 每句一个 `.m4a` 原音频片段；
- 可选的高价值表达标记表；
- `app/courses.ts` 中的课程配置；
- 验证课程与音频数量的测试。

**音频与文字必须绝对对齐。** 每个音频片段只能包含该条 `text` 所对应的完整实际朗读，不能带入前后句、另一位说话人的台词或教学旁白。反过来，`text` 也不能为了提炼学习点而从音频中截取一个会导致朗读从半句开始的片段；遇到这种情况，应将 `text` 恢复为自然、完整的实际台词，或选择另一条可独立练习的原声句。每条最终条目都要保存精确的 `start`、`end` 和 `duration`，以便重新切分与复核。

筛选规则：保留可跨场景复用的 B1–B2 表达，例如邀约、婉拒、说明原因、安排时间、征询意见、表达希望、责任与协作。去除教学旁白、语法讲解、片头片尾、重复复述、纯问候、单独感叹、专有名词展示及强依赖画面的台词。建议每课保留 15–20 句；表达质量优先于数量。

## 2. 来源与授权核验

先在 VOA Learning English 课程页确认：

1. 正文含 `Conversation` 或完整可用文本；
2. 页面或播放器提供 VOA 自制 MP3；
3. 内容不是第三方通讯社或受限转载素材；
4. 将课程页 URL、音频 URL、来源署名与授权说明写入 manifest。

VOA Learning English 的自制学习材料通常可按其公开域说明使用，但每次都要检查该课页面署名及是否包含第三方材料。不要提交外部图片、视频、原始 MP3 或下载的网页。

## 3. 工作目录与命名

以 Level 2 Lesson 10 为例：

```text
work/voa-workplace/source/
  lesson-10-transcript.html
  lesson-10.mp3
  lesson-10-whisper.json

app/data/voa-visit-peru-b1.json
app/data/voa-visit-peru-b1-highlights.ts
public/courses/voa/visit-peru-b1/audio/
  voa-peru-b1-001.m4a
```

- `work/` 是临时目录，不能提交。
- `public/courses/voa/<course-id>/audio/` 只保存最终逐句音频。
- 课程 ID、manifest 文件名、音频目录和音频前缀必须一致。

## 4. 获取官方文本与音频

从课程正文页保存 HTML。页面播放器一般含 64 kbps 和 `_hq.mp3` 两个地址，优先下载 `_hq.mp3`：

```bash
mkdir -p work/voa-workplace/source

curl -L --fail --silent --show-error \
  'https://learningenglish.voanews.com/a/<lesson-slug>/<article-id>.html' \
  -o work/voa-workplace/source/lesson-XX-transcript.html

rg -n -i 'mp3|audio_url|hq\.mp3|Conversation' \
  work/voa-workplace/source/lesson-XX-transcript.html

curl -L --fail --silent --show-error '<official-hq-mp3-url>' \
  -o work/voa-workplace/source/lesson-XX.mp3
```

HTML 中的 Conversation 是文字权威来源。Whisper 只负责定位时间，不能替代人工校对；专名、缩写、否定词与 `want/won` 一类误识别必须回到官方文本确认。

## 5. 生成时间轴与人工筛选

仓库脚本通过 Whisper 生成初始分段。它需要 `OPENAI_API_KEY`，不要输出密钥或写入课程文件：

```bash
set -a
source .dev.vars
set +a

python3 scripts/transcribe_course_audio.py \
  --audio work/voa-workplace/source/lesson-XX.mp3 \
  --output work/voa-workplace/source/lesson-XX-whisper.json

jq '.segments[] | {start,end,text}' \
  work/voa-workplace/source/lesson-XX-whisper.json
```

逐段对照官方 Conversation：校正文字；合并被错切的同一说话回合；不要把不同说话人的台词拼接；删除教学旁白与低价值内容；保留最终的 `text`、`start`、`end` 与 `duration`。文字必须与该时间段实际朗读逐词对应：音频含额外前后内容时调整边界；若现有文字是台词中的不完整摘录，则恢复完整自然台词或更换条目，不能从半句起播。必须试听开头、中段和结尾样本，确认句首、句尾没有明显截断或夹带下一句。

## 6. 编写 manifest 与表达标记

```json
{
  "courseId": "voa-example-b1",
  "provider": "VOA Learning English",
  "attribution": "Source: VOA Learning English",
  "licenseNote": "VOA-produced Learning English content is public domain; third-party agency material is excluded.",
  "entries": [{
    "id": "voa-example-b1-001",
    "text": "I wish I could, but I can't.",
    "translation": "我希望可以，但我做不到。",
    "start": 6.72,
    "end": 9.4,
    "duration": 2.68,
    "learnable": true,
    "audio": "audio/voa-example-b1-001.m4a"
  }]
}
```

```ts
export const VOA_EXAMPLE_B1_HIGHLIGHTS: Readonly<Record<string, readonly string[]>> = {
  "voa-example-b1-001": ["wish I could"],
};
```

只标记完整句中原样存在、可复用且不低幼的语块。优先短语动词、自然句型、搭配和跨场景表达，例如 `wish I could`、`have some work to do`、`in about an hour`。没有合适标记时可不标；不要标专名或整句。

## 7. 切分逐句音频

使用审核后的时间轴。每次仅处理当前课程目标目录：

```bash
mkdir -p public/courses/voa/example-b1/audio
source=work/voa-workplace/source/lesson-XX.mp3
clips=(
  '001 6.72 2.68'
  '002 9.40 3.24'
)

for clip in "${clips[@]}"; do
  read -r number start duration <<< "$clip"
  ffmpeg -hide_banner -loglevel error -y \
    -ss "$start" -t "$duration" -i "$source" \
    -c:a aac -b:a 96k \
    "public/courses/voa/example-b1/audio/voa-example-b1-${number}.m4a"
done
```

音频 ID 必须与 manifest 的 `audio` 字段完全对应。如果片段包含长静音、前一句尾音或下一句开头，应调整时间后重新切分。

## 8. 接入课程列表

在 `app/courses.ts`：import manifest 和 highlights；筛选 `learnable && audio`；将音频映射到完整 base path；向 `COURSE_PACKAGES` 添加课程。

```ts
const voaExampleB1Entries = voaExampleB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    highlights: VOA_EXAMPLE_B1_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/voa/example-b1/${entry.audio}`,
  })) as CourseEntry[];

{
  id: "voa-example-b1",
  title: "Useful Topic · B1",
  subtitle: `VOA Learning English · ${voaExampleB1Entries.length} learning sentences`,
  description: "一句话说明本课的练习场景与核心表达。",
  kind: "sentence",
  practiceOrder: "sequential",
  entries: voaExampleB1Entries,
}
```

不要改动默认课程；课程 ID 是学习进度隔离键，改名或复用已有 ID 会影响现有用户进度。

## 9. 验收、提交与部署边界

在 `tests/rendered-html.test.mjs` 添加课程测试，至少验证条目数、`learnable` 数、音频数和一条预期表达。完成后执行：

```bash
npm run lint
npm test
git diff --check
```

提交前确认：

- [ ] 每条 `learnable` 句子都有音频，音频数等于可学习句数；
- [ ] 每条音频只朗读其 `text` 对应的完整台词；文本不从半句开始，且不省略同一朗读中的必要句首或句尾；
- [ ] 每条条目保存了可复现的 `start`、`end`、`duration`，并抽听确认边界没有夹带前后台词；
- [ ] manifest、highlights、音频、`app/courses.ts` 与测试已纳入版本控制；
- [ ] 不包含原始 MP3、网页、Whisper JSON、`work/` 文件或 API 密钥；
- [ ] 课程切换后可以播放、跟读、前进并独立保存进度；
- [ ] 仅在用户确认后部署到 VPS。

出现错译、错切或低价值条目时，应修正本课 manifest 和音频，不在前端做隐藏补丁。Whisper 分段只是起点，官方文本和实际试听优先；课程应是精简的口语练习集，而不是逐字转录。
