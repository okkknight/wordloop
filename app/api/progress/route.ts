import { env } from "cloudflare:workers";
import { WORDS } from "../../words";

const wordSet = new Set(WORDS.map(([word]) => word));
const userIdPattern = /^[0-9a-f-]{36}$/i;

function validUserId(value: unknown): value is string {
  return typeof value === "string" && userIdPattern.test(value);
}

export async function GET(request: Request) {
  const userId = new URL(request.url).searchParams.get("userId");
  if (!validUserId(userId)) {
    return Response.json({ error: "invalid user id" }, { status: 400 });
  }

  const result = await env.DB.prepare(
    "SELECT word, study_count AS studyCount FROM word_progress WHERE user_id = ?",
  ).bind(userId).all<{ word: string; studyCount: number }>();

  return Response.json({ progress: result.results });
}

export async function POST(request: Request) {
  const payload = (await request.json()) as { userId?: string; word?: string };
  if (!validUserId(payload.userId) || !payload.word || !wordSet.has(payload.word)) {
    return Response.json({ error: "invalid progress update" }, { status: 400 });
  }

  const row = await env.DB.prepare(
    `INSERT INTO word_progress (user_id, word, study_count, updated_at)
     VALUES (?, ?, 1, CURRENT_TIMESTAMP)
     ON CONFLICT(user_id, word) DO UPDATE SET
       study_count = MIN(50, word_progress.study_count + 1),
       updated_at = CURRENT_TIMESTAMP
     RETURNING study_count AS studyCount`,
  ).bind(payload.userId, payload.word).first<{ studyCount: number }>();

  return Response.json({ word: payload.word, studyCount: row?.studyCount ?? 1 });
}
