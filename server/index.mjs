import { createServer } from "node:http";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

const port = Number(process.env.PORT ?? 3011);
const databasePath = resolve(process.env.WORDLOOP_DB_PATH ?? "./data/wordloop.sqlite");
const openAiApiKey = process.env.OPENAI_API_KEY;
const openAiRealtimeUrl = "https://api.openai.com/v1/realtime/calls";
const anonymousUserIdPattern = /^[0-9a-f-]{36}$/i;
const namedUserIdPattern = /^name:[a-z]+$/;

mkdirSync(dirname(databasePath), { recursive: true });
const database = new DatabaseSync(databasePath);
database.exec(`
  CREATE TABLE IF NOT EXISTS word_progress (
    user_id TEXT NOT NULL,
    word TEXT NOT NULL,
    study_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, word)
  );
  CREATE TABLE IF NOT EXISTS course_progress (
    user_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    study_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id, item_id)
  );
  CREATE TABLE IF NOT EXISTS study_users (
    user_id TEXT PRIMARY KEY,
    username TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );
`);

function sendJson(response, status, value) {
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(value));
}

function readBody(request) {
  return new Promise((resolveBody, reject) => {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => resolveBody(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

function validUserId(value) {
  return typeof value === "string" && (anonymousUserIdPattern.test(value) || namedUserIdPattern.test(value));
}

function registerUser(userId) {
  const username = userId.startsWith("name:") ? userId.slice(5) : null;
  database.prepare(
    `INSERT INTO study_users (user_id, username, last_seen_at)
     VALUES (?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(user_id) DO UPDATE SET last_seen_at = CURRENT_TIMESTAMP`,
  ).run(userId, username);
}

async function handleProgress(request, response, url) {
  if (request.method === "GET") {
    const userId = url.searchParams.get("userId");
    if (!validUserId(userId)) return sendJson(response, 400, { error: "invalid user id" });
    registerUser(userId);
    const courseId = url.searchParams.get("courseId");
    if (courseId) {
      const progress = database.prepare(
        "SELECT item_id AS itemId, study_count AS studyCount FROM course_progress WHERE user_id = ? AND course_id = ?",
      ).all(userId, courseId);
      return sendJson(response, 200, { progress });
    }
    const progress = database.prepare(
      "SELECT word, study_count AS studyCount FROM word_progress WHERE user_id = ?",
    ).all(userId);
    return sendJson(response, 200, { progress });
  }

  if (request.method === "POST") {
    let payload;
    try { payload = JSON.parse((await readBody(request)).toString("utf8")); } catch { return sendJson(response, 400, { error: "invalid JSON" }); }
    if (!validUserId(payload.userId)) {
      return sendJson(response, 400, { error: "invalid progress update" });
    }
    registerUser(payload.userId);
    if (typeof payload.courseId === "string" && typeof payload.itemId === "string" && payload.courseId && payload.itemId) {
      const row = database.prepare(
        `INSERT INTO course_progress (user_id, course_id, item_id, study_count, updated_at)
         VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, course_id, item_id) DO UPDATE SET
           study_count = MIN(50, course_progress.study_count + 1),
           updated_at = CURRENT_TIMESTAMP
         RETURNING study_count AS studyCount`,
      ).get(payload.userId, payload.courseId, payload.itemId);
      return sendJson(response, 200, { itemId: payload.itemId, studyCount: row?.studyCount ?? 1 });
    }
    if (typeof payload.word !== "string" || !payload.word.trim()) {
      return sendJson(response, 400, { error: "invalid progress update" });
    }
    const row = database.prepare(
      `INSERT INTO word_progress (user_id, word, study_count, updated_at)
       VALUES (?, ?, 1, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id, word) DO UPDATE SET
         study_count = MIN(50, word_progress.study_count + 1),
         updated_at = CURRENT_TIMESTAMP
       RETURNING study_count AS studyCount`,
    ).get(payload.userId, payload.word);
    return sendJson(response, 200, { word: payload.word, studyCount: row?.studyCount ?? 1 });
  }

  response.writeHead(405, { Allow: "GET, POST" });
  response.end();
}

async function handlePronunciationSession(request, response) {
  if (request.method !== "POST") {
    response.writeHead(405, { Allow: "POST" });
    return response.end();
  }
  if (!openAiApiKey) return sendJson(response, 503, { error: "Realtime pronunciation is not configured yet." });

  const sdp = (await readBody(request)).toString("utf8");
  if (!sdp.trim()) return sendJson(response, 400, { error: "Missing SDP offer." });

  const session = {
    type: "transcription",
    audio: {
      input: {
        format: { type: "audio/pcm", rate: 24000 },
        transcription: {
          model: "gpt-4o-mini-transcribe",
          language: "en",
          prompt: "Expect one spoken English study word or sentence at a time from a vocabulary trainer.",
        },
        turn_detection: { type: "server_vad", threshold: 0.45, prefix_padding_ms: 200, silence_duration_ms: 700 },
        noise_reduction: { type: "near_field" },
      },
    },
  };
  const formData = new FormData();
  formData.set("sdp", sdp);
  formData.set("session", JSON.stringify(session));
  const userId = request.headers["x-user-id"]?.trim();
  const upstream = await fetch(openAiRealtimeUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAiApiKey}`,
      ...(validUserId(userId) ? { "OpenAI-Safety-Identifier": `word-loop:${userId}` } : {}),
    },
    body: formData,
  });
  const body = await upstream.text();
  if (!upstream.ok) return sendJson(response, 502, { error: body || "Failed to start realtime pronunciation session." });
  response.writeHead(200, { "Content-Type": "application/sdp" });
  response.end(body);
}

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    if (url.pathname === "/healthz") return sendJson(response, 200, { ok: true });
    if (url.pathname === "/api/progress") return await handleProgress(request, response, url);
    if (url.pathname === "/api/pronunciation-session") return await handlePronunciationSession(request, response);
    return sendJson(response, 404, { error: "not found" });
  } catch (error) {
    console.error("WordLoop API request failed", error);
    return sendJson(response, 500, { error: "internal server error" });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`WordLoop API listening on 127.0.0.1:${port}`);
});
