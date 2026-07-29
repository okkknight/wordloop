# API 基线合同

## 1. 路径与通用校验

- `GET /api/progress`
- `POST /api/progress`
- `POST /api/pronunciation-session`

`userId` 允许 36 个 `[0-9a-f-]` 字符或 `name:` 加小写字母；当前实现没有严格验证 UUID 分段。`mode` 仅为 `listen/repeat`。`clientEventId` 为 8–128 个字母、数字或连字符。学习次数上限 3。

来源：`app/api/progress/route.ts:4-20`、`server/index.mjs:7,11-13,99-108`。

POST 分支优先级固定为 `selectCourse → resetCourse → completeCourse → normal progress`；同一 payload 有多个 true 标志时只执行最先分支。

## 2. GET `/api/progress`

请求：

```text
?userId=<id>&mode=listen|repeat[&courseId=<id>]
```

不带 `courseId`：

```json
{
  "progress": [{ "word": "example", "studyCount": 2 }],
  "completions": [{ "courseId": "course-a", "completionCount": 1 }],
  "recentCourseId": "course-a"
}
```

- `progress` 按 user + mode 返回单词。
- `completions` 只按 user，跨 mode 共用。
- 最近课程优先 `course_preferences`；无偏好时取最近 course progress，且不按 mode 过滤。
- 没有最近课程时 JSON 可省略 `recentCourseId`。

带 `courseId`：

```json
{ "progress": [{ "itemId": "line-001", "studyCount": 3 }] }
```

只返回指定 user + mode + course 的句子进度，不附 completions/recentCourseId。

差异：D1 对 userId 或 mode 任一非法均返回 `400 invalid user id`；Node 分别返回 `invalid user id` 与 `invalid study mode`。Node 会更新 `study_users`，D1 不会。

来源：`app/api/progress/route.ts:38-67`、`server/index.mjs:127-153`。

## 3. 普通学习事件

单词：

```json
{
  "userId": "<id>",
  "mode": "listen",
  "clientEventId": "<uuid>",
  "word": "example"
}
```

响应：`{"word":"example","studyCount":1}`。

课程项：

```json
{
  "userId": "<id>",
  "mode": "repeat",
  "clientEventId": "<uuid>",
  "courseId": "course-a",
  "itemId": "line-001"
}
```

响应：`{"itemId":"line-001","studyCount":1}`。

- 缺省 `markMastered` 加 1；`markMastered:true` 直接置 3；显式 false 当前非法。
- 同时有非空 courseId/itemId 时走课程项，否则尝试 word。
- `clientEventId` 先写 `progress_events`；首次才累计，重试读取现有值。
- event ID 是全局主键，不是 user 级复合键；不可复用到另一用户/模式/条目。

差异：D1 单词必须精确属于 `WORDS`；Node 只要求非空字符串。D1 的 courseId/itemId 只做 truthy 判断，Node 要求非空 string。

来源：`app/api/progress/route.ts:23-35,127-166`、`server/index.mjs:111-115,204-240`、`db/schema.ts:39-47`。

## 4. 选择课程

请求：

```json
{
  "userId": "<id>",
  "mode": "listen",
  "courseId": "course-a",
  "selectCourse": true
}
```

响应：`{"recentCourseId":"course-a"}`。

- 按 user upsert，不区分 mode。
- mode 不入表但仍必填。
- 不需要 clientEventId；重复选择为赋值幂等。
- courseId 不验证是否真实存在。

来源：`app/api/progress/route.ts:83-93`、`server/index.mjs:159-170`。

## 5. 重置课程

请求：

```json
{
  "userId": "<id>",
  "mode": "repeat",
  "courseId": "course-a",
  "resetCourse": true
}
```

响应：`{"courseId":"course-a","reset":true}`。

- 删除该 user + mode + course 的 course progress 与 progress events。
- 不删除完成次数/事件、最近课程偏好、单词进度或另一 mode。
- 无需 clientEventId；重复删除幂等。
- 旧 progress event 被删后，同一 ID 可以再次生效。

来源：`app/api/progress/route.ts:94-105`、`server/index.mjs:171-183`。

## 6. 完成课程

请求：

```json
{
  "userId": "<id>",
  "mode": "repeat",
  "clientEventId": "<uuid>",
  "courseId": "course-a",
  "completeCourse": true
}
```

响应：`{"courseId":"course-a","completionCount":1}`。

- 首次 event ID 写 `course_completion_events` 并把 user + course 次数加 1。
- 重试只读既有次数。
- 完成事件和次数不存 mode，LISTEN/REPEAT 共用。
- completion 与 progress 是两张事件表，同一字符串可各生效一次。

来源：`app/api/progress/route.ts:107-124`、`server/index.mjs:184-202`、`db/schema.ts:49-65`。

## 7. Pronunciation session

客户端请求：

```text
POST /api/pronunciation-session
Content-Type: application/sdp
x-user-id: <optional>

<non-empty SDP offer>
```

成功响应为 HTTP 200、`Content-Type: application/sdp` 和 SDP answer。

服务端向 `https://api.openai.com/v1/realtime/calls` 发送 multipart：

- session type `transcription`
- PCM 24 kHz
- model `gpt-4o-mini-transcribe`
- language `en`
- server VAD threshold 0.45
- prefix padding 200 ms
- silence 700 ms
- near-field noise reduction

错误：无 key → 503；空 SDP → 400；上游失败 → 502。当前不校验请求 Content-Type，也没有本地鉴权。API Key 只在服务端 Authorization。

已知差异：

- D1 prompt 只写 study word；Node prompt 写 word or sentence。
- D1 对任意非空 x-user-id 生成 Safety Identifier；Node 只接受合法 userId。
- Node 显式非 POST → 405；D1 交给框架处理。

来源：`app/page.tsx:1326-1335`、`app/api/pronunciation-session/route.ts:9-72`、`server/index.mjs:247-287`。

## 8. 数据与测试缺口

- mode 进度主键：word 为 user/mode/word；course 为 user/mode/course/item。
- `db/schema.ts` 未声明 `course_preferences`，但 migration 与 Node 运行时存在该表。
- 当前 `tests/rendered-html.test.mjs` 主要做源码特征检查，不是请求级/数据库级契约测试。
- P5 实施前必须把本文件合同转成两套实现共用的请求级测试，并先决定是否消除上述差异。
