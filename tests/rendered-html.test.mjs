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

test("ships the first sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e01.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e01/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E01");
  assert.equal(course.entries.length, 499);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 222);
  assert.equal(sentenceAudio.length, 222);
  assert.match(course.entries[0].text, /Kids, breakfast/);
});

test("exposes the listen, repeat, progress, and pronunciation flows", async () => {
  const page = await read("app/page.tsx");
  const courses = await read("app/courses.ts");
  const progressRoute = await read("app/api/progress/route.ts");
  const pronunciationRoute = await read("app/api/pronunciation-session/route.ts");

  assert.match(page, /studyMode.*listen/);
  assert.match(page, /studyMode.*repeat/);
  assert.match(page, /localStorage/);
  assert.match(page, /\/api\/progress/);
  assert.match(page, /RTCPeerConnection/);
  assert.match(page, /studyContent/);
  assert.match(page, /SENTENCES/);
  assert.match(courses, /modern-family-s01e01/);
  assert.match(courses, /COURSE_PACKAGES/);
  assert.match(progressRoute, /export async function GET/);
  assert.match(progressRoute, /export async function POST/);
  assert.match(pronunciationRoute, /OPENAI_REALTIME_URL/);
  assert.match(pronunciationRoute, /gpt-4o-mini-transcribe/);
});
