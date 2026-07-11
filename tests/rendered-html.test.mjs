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
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 221);
  assert.equal(sentenceAudio.length, 221);
  assert.match(course.entries[0].text, /Kids, breakfast/);
});

test("exposes the listen, repeat, progress, and pronunciation flows", async () => {
  const page = await read("app/page.tsx");
  const courses = await read("app/courses.ts");
  const progressRoute = await read("app/api/progress/route.ts");
  const pronunciationRoute = await read("app/api/pronunciation-session/route.ts");

  assert.match(page, /const \[studyMode, setStudyMode\] = useState<StudyMode>\("repeat"\)/);
  assert.match(page, /studyMode.*repeat/);
  assert.match(page, /localStorage/);
  assert.match(page, /\/api\/progress/);
  assert.match(page, /RTCPeerConnection/);
  assert.match(page, /activeCourseId/);
  assert.match(page, /coursePickerOpen/);
  assert.match(page, /COURSE_PACKAGES/);
  assert.match(page, /const PASS_SCORE = 20/);
  assert.match(page, /sentenceIndexRef\.current = target\.index/);
  assert.match(page, /wordIndexRef\.current = target\.index/);
  assert.match(page, /<span>SWITCH COURSE<\/span>/);
  assert.doesNotMatch(page, /<span>\{activeCourse\.title\}<\/span>/);
  assert.doesNotMatch(page, /THIS \{sentenceMode \? "SENTENCE" : "WORD"\}/);
  assert.match(page, /const \[wordIndex, setWordIndex\] = useState\(0\)/);
  assert.match(page, /repeatAdvanceTargetRef\.current = \{ index: upcomingIndex, sentenceMode, turnId \}/);
  assert.match(page, /if \(repeatState !== "passed"\) return/);
  assert.match(page, /const isSentenceCourse = activeCourseKindRef\.current === "sentence"/);
  assert.match(page, /if \(!target\) \{/);
  assert.match(page, /document\.addEventListener\("visibilitychange", pauseWhenHidden\)/);
  assert.match(page, /\}, 1_500\);/);
  assert.match(page, /function playRecordingCue/);
  assert.match(page, /playToneWhenReady\(feedbackAudioContextRef\.current, \(audio\) => playFeedbackTone\(audio, false\)\)/);
  assert.match(page, /playToneWhenReady\(feedbackAudioContextRef\.current, playRecordingCue\)/);
  assert.match(courses, /modern-family-s01e01/);
  assert.match(courses, /ielts-high-frequency/);
  assert.match(courses, /COURSE_PACKAGES/);
  assert.match(courses, /DEFAULT_COURSE = MODERN_FAMILY_S01E01_COURSE/);
  assert.match(courses, /practiceOrder: "sequential"/);
  assert.match(page, /available\.find\(\(index\) => index > except\) \?\? available\[0\] \?\? -1/);
  assert.match(page, /const \[studyTextVisible, setStudyTextVisible\] = useState\(true\)/);
  assert.match(page, /Hide \$\{sentenceMode \? "sentence" : "word"\}/);
  assert.match(page, /storedSentenceProgress, -1, "random"/);
  assert.match(page, /study-text-placeholder">✦ ✦ ✦/);
  assert.match(progressRoute, /export async function GET/);
  assert.match(progressRoute, /export async function POST/);
  assert.match(pronunciationRoute, /OPENAI_REALTIME_URL/);
  assert.match(pronunciationRoute, /gpt-4o-mini-transcribe/);
});
