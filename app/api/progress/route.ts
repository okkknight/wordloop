import { env } from "cloudflare:workers";
import { WORDS } from "../../words";

const wordSet = new Set(WORDS.map(([word]) => word));
const anonymousUserIdPattern = /^[0-9a-f-]{36}$/i;
const namedUserIdPattern = /^name:[a-z]+$/;
const studyModes = new Set(["listen", "repeat"]);
const progressEventIdPattern = /^[a-z0-9-]{8,128}$/i;
const maxStudyCount = 3;

function validUserId(value: unknown): value is string {
  return typeof value === "string" && (anonymousUserIdPattern.test(value) || namedUserIdPattern.test(value));
}

function validStudyMode(value: unknown): value is "listen" | "repeat" {
  return typeof value === "string" && studyModes.has(value);
}

function validProgressEventId(value: unknown): value is string {
  return typeof value === "string" && progressEventIdPattern.test(value);
}

async function claimProgressEvent(
  eventId: string,
  userId: string,
  studyMode: "listen" | "repeat",
  courseId: string | null,
  itemId: string | null,
  word: string | null,
) {
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO progress_events (event_id, user_id, study_mode, course_id, item_id, word)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).bind(eventId, userId, studyMode, courseId, itemId, word).run();
  return result.meta.changes === 1;
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const userId = url.searchParams.get("userId");
  const studyMode = url.searchParams.get("mode");
  if (!validUserId(userId) || !validStudyMode(studyMode)) {
    return Response.json({ error: "invalid user id" }, { status: 400 });
  }

  const courseId = url.searchParams.get("courseId");
  if (courseId) {
    const result = await env.DB.prepare(
      "SELECT item_id AS itemId, study_count AS studyCount FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ?",
    ).bind(userId, studyMode, courseId).all<{ itemId: string; studyCount: number }>();
    return Response.json({ progress: result.results });
  }

  const result = await env.DB.prepare(
    "SELECT word, study_count AS studyCount FROM word_mode_progress WHERE user_id = ? AND study_mode = ?",
  ).bind(userId, studyMode).all<{ word: string; studyCount: number }>();
  const completionResult = await env.DB.prepare(
    "SELECT course_id AS courseId, completion_count AS completionCount FROM course_completion_counts WHERE user_id = ?",
  ).bind(userId).all<{ courseId: string; completionCount: number }>();
  const preference = await env.DB.prepare(
    "SELECT last_course_id AS recentCourseId FROM course_preferences WHERE user_id = ?",
  ).bind(userId).first<{ recentCourseId: string }>();
  const recentProgress = preference ? undefined : await env.DB.prepare(
    "SELECT course_id AS recentCourseId FROM course_mode_progress WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1",
  ).bind(userId).first<{ recentCourseId: string }>();

  return Response.json({ progress: result.results, completions: completionResult.results, recentCourseId: preference?.recentCourseId ?? recentProgress?.recentCourseId });
}

export async function POST(request: Request) {
  const payload = (await request.json()) as {
    userId?: string;
    mode?: string;
    clientEventId?: string;
    markMastered?: boolean;
    resetCourse?: boolean;
    completeCourse?: boolean;
    selectCourse?: boolean;
    word?: string;
    courseId?: string;
    itemId?: string;
  };
  if (payload.selectCourse === true) {
    if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !payload.courseId) {
      return Response.json({ error: "invalid course selection" }, { status: 400 });
    }
    await env.DB.prepare(
      `INSERT INTO course_preferences (user_id, last_course_id, updated_at)
       VALUES (?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id) DO UPDATE SET last_course_id = excluded.last_course_id, updated_at = CURRENT_TIMESTAMP`,
    ).bind(payload.userId, payload.courseId).run();
    return Response.json({ recentCourseId: payload.courseId });
  }
  if (payload.resetCourse === true) {
    if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !payload.courseId) {
      return Response.json({ error: "invalid course reset" }, { status: 400 });
    }
    await env.DB.prepare(
      "DELETE FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ?",
    ).bind(payload.userId, payload.mode, payload.courseId).run();
    await env.DB.prepare(
      "DELETE FROM progress_events WHERE user_id = ? AND study_mode = ? AND course_id = ?",
    ).bind(payload.userId, payload.mode, payload.courseId).run();
    return Response.json({ courseId: payload.courseId, reset: true });
  }

  if (payload.completeCourse === true) {
    if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !validProgressEventId(payload.clientEventId) || !payload.courseId) {
      return Response.json({ error: "invalid course completion" }, { status: 400 });
    }
    const event = await env.DB.prepare(
      "INSERT OR IGNORE INTO course_completion_events (event_id, user_id, course_id, created_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
    ).bind(payload.clientEventId, payload.userId, payload.courseId).run();
    const row = event.meta.changes === 1
      ? await env.DB.prepare(
        `INSERT INTO course_completion_counts (user_id, course_id, completion_count, updated_at)
         VALUES (?, ?, 1, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, course_id) DO UPDATE SET completion_count = course_completion_counts.completion_count + 1, updated_at = CURRENT_TIMESTAMP
         RETURNING completion_count AS completionCount`,
      ).bind(payload.userId, payload.courseId).first<{ completionCount: number }>()
      : await env.DB.prepare(
        "SELECT completion_count AS completionCount FROM course_completion_counts WHERE user_id = ? AND course_id = ?",
      ).bind(payload.userId, payload.courseId).first<{ completionCount: number }>();
    return Response.json({ courseId: payload.courseId, completionCount: row?.completionCount ?? 1 });
  }

  if (!validUserId(payload.userId) || !validStudyMode(payload.mode) || !validProgressEventId(payload.clientEventId) || (payload.markMastered !== undefined && payload.markMastered !== true)) {
    return Response.json({ error: "invalid progress update" }, { status: 400 });
  }

  if (payload.courseId && payload.itemId) {
    const isNewEvent = await claimProgressEvent(payload.clientEventId, payload.userId, payload.mode, payload.courseId, payload.itemId, null);
    const row = isNewEvent
      ? await env.DB.prepare(
        `INSERT INTO course_mode_progress (user_id, study_mode, course_id, item_id, study_count, updated_at)
         VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id, study_mode, course_id, item_id) DO UPDATE SET
           study_count = CASE WHEN excluded.study_count = ${maxStudyCount} THEN ${maxStudyCount} ELSE MIN(${maxStudyCount}, course_mode_progress.study_count + 1) END,
           updated_at = CURRENT_TIMESTAMP
         RETURNING study_count AS studyCount`,
      ).bind(payload.userId, payload.mode, payload.courseId, payload.itemId, payload.markMastered ? maxStudyCount : 1).first<{ studyCount: number }>()
      : await env.DB.prepare(
        "SELECT study_count AS studyCount FROM course_mode_progress WHERE user_id = ? AND study_mode = ? AND course_id = ? AND item_id = ?",
      ).bind(payload.userId, payload.mode, payload.courseId, payload.itemId).first<{ studyCount: number }>();
    return Response.json({ itemId: payload.itemId, studyCount: row?.studyCount ?? 1 });
  }

  if (!payload.word || !wordSet.has(payload.word)) {
    return Response.json({ error: "invalid progress update" }, { status: 400 });
  }

  const isNewEvent = await claimProgressEvent(payload.clientEventId, payload.userId, payload.mode, null, null, payload.word);
  const row = isNewEvent
    ? await env.DB.prepare(
      `INSERT INTO word_mode_progress (user_id, study_mode, word, study_count, updated_at)
       VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(user_id, study_mode, word) DO UPDATE SET
         study_count = CASE WHEN excluded.study_count = ${maxStudyCount} THEN ${maxStudyCount} ELSE MIN(${maxStudyCount}, word_mode_progress.study_count + 1) END,
         updated_at = CURRENT_TIMESTAMP
       RETURNING study_count AS studyCount`,
    ).bind(payload.userId, payload.mode, payload.word, payload.markMastered ? maxStudyCount : 1).first<{ studyCount: number }>()
    : await env.DB.prepare(
      "SELECT study_count AS studyCount FROM word_mode_progress WHERE user_id = ? AND study_mode = ? AND word = ?",
    ).bind(payload.userId, payload.mode, payload.word).first<{ studyCount: number }>();

  return Response.json({ word: payload.word, studyCount: row?.studyCount ?? 1 });
}
