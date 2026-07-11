import assert from "node:assert/strict";
import { access, readFile, readdir } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function read(relativePath) {
  return readFile(new URL(relativePath, root), "utf8");
}

test("build output exists for the WordLoop app", async () => {
  await access(new URL("dist/server/index.js", root));
  await access(new URL("dist/client", root));
});

test("ships the complete vocabulary and audio set", async () => {
  const words = await read("app/words.ts");
  const wordCount = (words.match(/^  \[\"/gm) ?? []).length;
  const audioFiles = (await readdir(new URL("public/audio", root))).filter((file) => file.endsWith(".m4a"));

  assert.equal(wordCount, 570);
  assert.equal(audioFiles.length, 570);
});

test("exposes the listen, repeat, progress, and pronunciation flows", async () => {
  const page = await read("app/page.tsx");
  const progressRoute = await read("app/api/progress/route.ts");
  const pronunciationRoute = await read("app/api/pronunciation-session/route.ts");

  assert.match(page, /studyMode.*listen/);
  assert.match(page, /studyMode.*repeat/);
  assert.match(page, /localStorage/);
  assert.match(page, /\/api\/progress/);
  assert.match(page, /RTCPeerConnection/);
  assert.match(progressRoute, /export async function GET/);
  assert.match(progressRoute, /export async function POST/);
  assert.match(pronunciationRoute, /OPENAI_REALTIME_URL/);
  assert.match(pronunciationRoute, /gpt-4o-mini-transcribe/);
});
