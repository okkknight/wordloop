import { createServer } from "node:http";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

const port = Number(process.env.PORT ?? 3011);
const maxStudyCount = 3;
const databasePath = resolve(process.env.WORDLOOP_DB_PATH ?? "./data/wordloop.sqlite");
const openAiApiKey = process.env.OPENAI_API_KEY;
const openAiRealtimeUrl = "https://api.openai.com/v1/realtime/calls";
const anonymousUserIdPattern = /^[0-9a-f-]{36}$/i;
const namedUserIdPattern = /^name:[a-z]+$/;
const studyModes = new Set(["listen", "repeat"]);

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
  CREATE TABLE IF NOT EXISTS word_mode_progress (
    user_id TEXT NOT NULL,
    study_mode TEXT NOT NULL CHECK (study_mode IN ('listen', 'repeat')),
    word TEXT NOT NULL,
    study_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, study_mode, word)
  );
  CREATE TABLE IF NOT EXISTS course_mode_progress (
    user_id TEXT NOT NULL,
    study_mode TEXT NOT NULL CHECK (study_mode IN ('listen', 'repeat')),
    course_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    study_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, study_mode, course_id, item_id)
  );
  CREATE TABLE IF NOT EXISTS progress_events (
    event_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    study_mode TEXT NOT NULL CHECK (study_mode IN ('listen', 'repeat')),
    course_id TEXT,
    item_id TEXT,
    word TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );
  CREATE TABLE IF NOT EXISTS course_completion_counts (
    user_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    completion_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id)
  );
  CREATE TABLE IF NOT EXISTS course_completion_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
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

function validStudyMode(value) {
  return typeof value === "string" && studyModes.has(value);
}

function validProgressEventId(value) {
  return typeof value === "string" && /^[a-z0-9-]{8,128}$/i.test(value);
}

function claimProgressEvent(eventId, userId, studyMode, courseId, itemId, word) {
  return database.prepare(
    `INSERT OR IGNORE INTO progress_events (event_id, user_id, study_mode, course_id, item_id, word)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(eventId, userId, studyMode, courseId, itemId, word).changes === 1;
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
    const studyMode = url.searchParams.get("mode");
    if (!validStudyMode(studyMode)) return sendJson(response, 400, { error: "invalid study mode" });
    registerUser(userId);
    const courseId = url.searchParams.get("courseId");
    if (courseId) {
      const progress = database.prepare(
        "SELECT item_id AS itemId, study_count AS studyCount FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ?",
      ).all(userId, studyMode, courseId);
      return sendJson(response, 200, { progress });
    }
    const progress = database.prepare(
      "SELECT word, study_count AS studyCount FROM word_mode_progress WHERE user_id = ? AND study_mode = ?",
    ).all(userId, studyMode);
    const completions = database.prepare(
      "SELECT course_id AS courseId, completion_count AS completionCount FROM course_completion_counts WHERE user_id = ?",
    ).all(userId);
    return sendJson(response, 200, { progress, completions });
  }

  if (request.method === "POST") {
    let payload;
    try { payload = JSON.parse((await readBody(request)).toString("utf8")); } catch { return sendJson(response, 400, { error: "invalid JSON" }); }
    if (payload.resetCourse === true) {
      if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || typeof payload.courseId !== "string" || !payload.courseId) {
        return sendJson(response, 400, { error: "invalid course reset" });
      }
      registerUser(payload.userId);
      database.prepare(
        "DELETE FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ?",
      ).run(payload.userId, payload.mode, payload.courseId);
      database.prepare(
        "DELETE FROM progress_events WHERE user_id = ? AND study_mode = ? AND course_id = ?",
      ).run(payload.userId, payload.mode, payload.courseId);
      return sendJson(response, 200, { courseId: payload.courseId, reset: true });
    }
    if (payload.completeCourse === true) {
      if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !validProgressEventId(payload.clientEventId) || typeof payload.courseId !== "string" || !payload.courseId) {
        return sendJson(response, 400, { error: "invalid course completion" });
      }
      registerUser(payload.userId);
      const isNewEvent = database.prepare(
        "INSERT OR IGNORE INTO course_completion_events (event_id, user_id, course_id, created_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
      ).run(payload.clientEventId, payload.userId, payload.courseId).changes === 1;
      const row = isNewEvent
        ? database.prepare(
          `INSERT INTO course_completion_counts (user_id, course_id, completion_count, updated_at)
           VALUES (?, ?, 1, CURRENT_TIMESTAMP)
           ON CONFLICT(user_id, course_id) DO UPDATE SET completion_count = course_completion_counts.completion_count + 1, updated_at = CURRENT_TIMESTAMP
           RETURNING completion_count AS completionCount`,
        ).get(payload.userId, payload.courseId)
        : database.prepare(
          "SELECT completion_count AS completionCount FROM course_completion_counts WHERE user_id = ? AND course_id = ?",
        ).get(payload.userId, payload.courseId);
      return sendJson(response, 200, { courseId: payload.courseId, completionCount: row?.completionCount ?? 1 });
    }
    if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !validProgressEventId(payload.clientEventId) || (payload.markMastered !== undefined && payload.markMastered !== true)) {
      return sendJson(response, 400, { error: "invalid progress update" });
    }
    registerUser(payload.userId);
    if (typeof payload.courseId === "string" && typeof payload.itemId === "string" && payload.courseId && payload.itemId) {
      const isNewEvent = claimProgressEvent(payload.clientEventId, payload.userId, payload.mode, payload.courseId, payload.itemId, null);
      const row = isNewEvent
        ? database.prepare(
          `INSERT INTO course_mode_progress (user_id, study_mode, course_id, item_id, study_count, updated_at)
           VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(user_id, study_mode, course_id, item_id) DO UPDATE SET
             study_count = CASE WHEN excluded.study_count = ? THEN ? ELSE MIN(?, course_mode_progress.study_count + 1) END,
             updated_at = CURRENT_TIMESTAMP
           RETURNING study_count AS studyCount`,
        ).get(payload.userId, payload.mode, payload.courseId, payload.itemId, payload.markMastered ? maxStudyCount : 1, maxStudyCount, maxStudyCount, maxStudyCount)
        : database.prepare(
          "SELECT study_count AS studyCount FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ? AND item_id = ?",
        ).get(payload.userId, payload.mode, payload.courseId, payload.itemId);
      return sendJson(response, 200, { itemId: payload.itemId, studyCount: row?.studyCount ?? 1 });
    }
    if (typeof payload.word !== "string" || !payload.word.trim()) {
      return sendJson(response, 400, { error: "invalid progress update" });
    }
    const isNewEvent = claimProgressEvent(payload.clientEventId, payload.userId, payload.mode, null, null, payload.word);
    const row = isNewEvent
      ? database.prepare(
        `INSERT INTO word_mode_progress (user_id, study_mode, word, study_count, updated_at)
         VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, study_mode, word) DO UPDATE SET
           study_count = CASE WHEN excluded.study_count = ? THEN ? ELSE MIN(?, word_mode_progress.study_count + 1) END,
           updated_at = CURRENT_TIMESTAMP
         RETURNING study_count AS studyCount`,
      ).get(payload.userId, payload.mode, payload.word, payload.markMastered ? maxStudyCount : 1, maxStudyCount, maxStudyCount, maxStudyCount)
      : database.prepare(
        "SELECT study_count AS studyCount FROM word_mode_progress WHERE user_id = ? AND study_mode = ? AND word = ?",
      ).get(payload.userId, payload.mode, payload.word);
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
