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

test("ships all VOA Level 2 clips with complete alignment metadata", async () => {
  const manifests = (await readdir(new URL("app/data", root)))
    .filter((file) => file.startsWith("voa-") && file.endsWith(".json"));

  assert.equal(manifests.length, 24);

  for (const file of manifests) {
    const course = JSON.parse(await read(`app/data/${file}`));
    const slug = course.courseId.replace(/^voa-/, "");
    const audioFiles = new Set(
      (await readdir(new URL(`public/courses/voa/${slug}/audio`, root)))
        .filter((name) => name.endsWith(".m4a")),
    );
    const learnableEntries = course.entries.filter((entry) => entry.learnable);

    assert.equal(audioFiles.size, learnableEntries.length, `${course.courseId}: audio count`);
    for (const entry of learnableEntries) {
      assert.equal(typeof entry.start, "number", `${entry.id}: start`);
      assert.equal(typeof entry.end, "number", `${entry.id}: end`);
      assert.equal(typeof entry.duration, "number", `${entry.id}: duration`);
      assert.ok(entry.end > entry.start, `${entry.id}: ordered timestamps`);
      assert.ok(Math.abs(entry.duration - (entry.end - entry.start)) < 0.001, `${entry.id}: duration`);
      assert.ok(audioFiles.has(entry.audio.replace(/^audio\//, "")), `${entry.id}: audio file`);
    }
  }
});

test("ships the first sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e01.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e01/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E01");
  assert.equal(course.entries.length, 499);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 91);
  assert.equal(sentenceAudio.length, 91);
  assert.match(course.entries[0].text, /Kids, breakfast/);
});

test("ships the second sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e02.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e02/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E02");
  assert.equal(course.entries.length, 459);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 53);
  assert.equal(sentenceAudio.length, 53);
  assert.match(course.entries[0].text, /key to being a great dad/);
});

test("ships the third sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e03.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e03/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E03");
  assert.equal(course.entries.length, 465);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 79);
  assert.equal(sentenceAudio.length, 79);
  assert.match(course.entries[0].text, /Riley Morton/);
});

test("ships the fourth sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e04.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e04/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E04");
  assert.equal(course.entries.length, 512);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 55);
  assert.equal(sentenceAudio.length, 55);
  assert.match(course.entries[2].text, /because he's fine/);
});

test("ships the manually reviewed fifth sentence course package and its clips", async () => {
  const course = JSON.parse(await read("app/data/modern-family-s01e05.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/modern-family/s01e05/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.episode, "S01E05");
  assert.equal(course.entries.length, 513);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 88);
  assert.equal(sentenceAudio.length, 88);
  assert.match(course.sourceSubtitle, /S01E05 Coal Digger/);
  assert.match(course.entries[0].text, /Let's go, buddy\. Schooltime/);
});

test("ships the B1 workplace dialogue course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-workplace-conversations-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/workplace-conversations-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 20);
  assert.equal(sentenceAudio.length, 20);
  assert.match(course.entries[15].text, /completely honest/i);
});

test("ships the B1 pets and responsibility course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-pets-responsibility-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/pets-responsibility-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 16);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 16);
  assert.equal(sentenceAudio.length, 16);
  assert.match(course.entries[12].text, /spend time with a dog/i);
});

test("ships the B1 visit to Peru course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-visit-peru-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/visit-peru-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 20);
  assert.equal(sentenceAudio.length, 20);
  assert.match(course.entries[16].text, /wish I could join you/i);
});

test("ships the B1 weather at work course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-weather-at-work-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/weather-at-work-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 21);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 21);
  assert.equal(sentenceAudio.length, 21);
  assert.match(course.entries[20].text, /team-building exercise/i);
});

test("ships the B1 stay calm course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-stay-calm-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/stay-calm-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 20);
  assert.equal(sentenceAudio.length, 20);
  assert.match(course.entries[2].text, /What makes you say that/i);
});

test("ships the B1 helping out course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-helping-out-b1.json"));
  const sentenceAudio = (await readdir(new URL("public/courses/voa/helping-out-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(course.entries.filter((entry) => entry.learnable).length, 20);
  assert.equal(sentenceAudio.length, 20);
  assert.match(course.entries[12].text, /make a big difference/i);
});
test("ships the B1 in common course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-in-common-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/in-common-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[12].text, /seat taken/i);
});
test("ships the B1 keep moving course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-keep-moving-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/keep-moving-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 18); assert.equal(audio.length, 18); assert.match(course.entries[9].text, /As soon as/i);
});

test("ships the B1 find your way course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-find-your-way-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/find-your-way-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[13].text, /fill out a form/i);
});

test("ships the B1 speak for yourself course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-speak-for-yourself-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/speak-for-yourself-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[14].text, /Speak for yourself/i);
});

test("ships the B1 follow instructions course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-follow-instructions-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/follow-instructions-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[12].text, /followed instructions/i);
});

test("ships the B1 polite requests course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-polite-requests-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/polite-requests-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[9].text, /Would you mind not talking/i);
});

test("ships the B1 reported speech course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-reported-speech-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/reported-speech-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[3].text, /She said that/i);
});

test("ships the B1 creative reuse course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-creative-reuse-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/creative-reuse-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[13].text, /handmade, reclaimed and recycled/i);
});
test("ships the B1 learn from mistakes course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-learn-from-mistakes-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/learn-from-mistakes-b1/audio", root))).filter((file) => file.endsWith(".m4a"));
  assert.equal(course.entries.length, 20); assert.equal(audio.length, 20); assert.match(course.entries[14].text, /fix this/i);
});

test("ships the B1 fish out of water course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-fish-out-of-water-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/fish-out-of-water-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(audio.length, 20);
  assert.match(course.entries[0].text, /Why don't you join us/i);
});

test("ships the B1 for the birds course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-for-the-birds-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/for-the-birds-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(audio.length, 20);
  assert.match(course.entries[6].text, /supposed to be counting birds/i);
});

test("ships the B1 where there's smoke course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-where-theres-smoke-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/where-theres-smoke-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(audio.length, 20);
  assert.match(course.entries[4].text, /fire emergency/i);
});

test("ships the B1 dream a little dream course and its clips", async () => {
  const course = JSON.parse(await read("app/data/voa-dream-a-little-dream-b1.json"));
  const audio = (await readdir(new URL("public/courses/voa/dream-a-little-dream-b1/audio", root)))
    .filter((file) => file.endsWith(".m4a"));

  assert.equal(course.entries.length, 20);
  assert.equal(audio.length, 20);
  assert.match(course.entries[3].text, /dream of being a nurse/i);
});

test("exposes the listen, repeat, progress, and pronunciation flows", async () => {
  const page = await read("app/page.tsx");
  const courses = await read("app/courses.ts");
  const progressRoute = await read("app/api/progress/route.ts");
  const schema = await read("db/schema.ts");
  const completionMigration = await read("drizzle/0003_charming_ikaris.sql");
  const pronunciationRoute = await read("app/api/pronunciation-session/route.ts");
  const server = await read("server/index.mjs");

  assert.match(page, /const \[studyMode, setStudyMode\] = useState<StudyMode>\("repeat"\)/);
  assert.match(page, /studyMode.*repeat/);
  assert.match(page, /localStorage/);
  assert.match(page, /\/api\/progress/);
  assert.match(page, /RTCPeerConnection/);
  assert.match(page, /activeCourseId/);
  assert.match(page, /coursePickerOpen/);
  assert.match(page, /COURSE_PACKAGES/);
  assert.match(page, /const MAX_STUDY_COUNT = 3/);
  assert.match(page, /restartPromptCourseId/);
  assert.match(page, /completionPromptCourseId/);
  assert.match(page, /COURSE COMPLETE/);
  assert.match(page, /这门课程学完了/);
  assert.match(page, /const beginPanelSwipe/);
  assert.match(page, /endPanelSwipe\(event, "left"/);
  assert.match(page, /endPanelSwipe\(event, "right"/);
  assert.match(page, /const closeCoursePicker/);
  assert.match(page, /const closeProgressPanel/);
  assert.match(page, /const openCoursePicker/);
  assert.match(page, /const openProgressPanel/);
  assert.match(page, /const audio = new Audio\(source\)/);
  assert.match(page, /audio\.currentTime = 0/);
  assert.doesNotMatch(page, /preloaded\.cloneNode/);
  const styles = await read("app/globals.css");
  assert.match(styles, /\.word-stage \{[\s\S]*?min-width: 0/);
  assert.match(styles, /\.sentence-translation \{ min-width: 0; flex: 1 1 auto; overflow-wrap: anywhere; \}/);
  assert.match(styles, /\.repeat-card \{[\s\S]*?width: min\(520px, calc\(100vw - 48px\)\)/);
  assert.match(styles, /\.course-panel-backdrop\.closing \.course-panel/);
  assert.match(styles, /@keyframes panel-out-left/);
  assert.match(styles, /@keyframes panel-out-right/);
  assert.match(page, /resetCourse: true/);
  assert.match(page, /completionCourseId/);
  assert.match(page, /course-card-completion/);
  assert.match(progressRoute, /const maxStudyCount = 3/);
  assert.match(progressRoute, /payload\.resetCourse === true/);
  assert.match(progressRoute, /payload\.completeCourse === true/);
  assert.match(schema, /courseCompletionCounts/);
  assert.match(completionMigration, /course_completion_events/);
  assert.match(page, /const PASS_SCORE = 20/);
  assert.match(page, /sentenceIndexRef\.current = target\.index/);
  assert.match(page, /wordIndexRef\.current = target\.index/);
  assert.match(page, /<span>COURSE<\/span>/);
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
  assert.match(courses, /modern-family-s01e02/);
  assert.match(courses, /modern-family-s01e03/);
  assert.match(courses, /modern-family-s01e04/);
  assert.match(courses, /modern-family-s01e05/);
  assert.match(courses, /voa-workplace-conversations-b1/);
  assert.match(courses, /voa-pets-responsibility-b1/);
  assert.match(courses, /voa-visit-peru-b1/);
  assert.match(courses, /voa-weather-at-work-b1/);
  assert.match(courses, /voa-stay-calm-b1/);
  assert.match(courses, /voa-helping-out-b1/);
  assert.match(courses, /voa-fish-out-of-water-b1/);
  assert.match(courses, /voa-for-the-birds-b1/);
  assert.match(courses, /voa-where-theres-smoke-b1/);
  assert.match(courses, /voa-dream-a-little-dream-b1/);
  assert.match(courses, /voa-in-common-b1/);
  assert.match(courses, /voa-keep-moving-b1/);
  assert.match(courses, /voa-find-your-way-b1/);
  assert.match(courses, /voa-speak-for-yourself-b1/);
  assert.match(courses, /voa-follow-instructions-b1/);
  assert.match(courses, /voa-polite-requests-b1/);
  assert.match(courses, /voa-reported-speech-b1/);
  assert.match(courses, /voa-creative-reuse-b1/);
  assert.match(courses, /voa-learn-from-mistakes-b1/);
  assert.match(courses, /MODERN_FAMILY_S01E01_HIGHLIGHTS/);
  assert.match(courses, /MODERN_FAMILY_S01E02_HIGHLIGHTS/);
  assert.match(courses, /MODERN_FAMILY_S01E03_HIGHLIGHTS/);
  assert.match(courses, /MODERN_FAMILY_S01E04_HIGHLIGHTS/);
  assert.match(courses, /ielts-high-frequency/);
  assert.match(courses, /COURSE_PACKAGES/);
  assert.match(courses, /COURSE_COLLECTIONS/);
  assert.match(courses, /modern-family-s01/);
  assert.match(courses, /voa-level-2/);
  assert.match(page, /filteredCourseCollections/);
  assert.match(page, /course-collection-toggle/);
  assert.match(courses, /DEFAULT_COURSE = MODERN_FAMILY_S01E01_COURSE/);
  assert.match(courses, /practiceOrder: "sequential"/);
  assert.match(page, /available\.find\(\(index\) => index > except\) \?\? available\[0\] \?\? -1/);
  assert.match(page, /const sentenceIndexInCourse = sentenceCourse\.entries\[sentenceIndex\] \? sentenceIndex : 0/);
  assert.match(page, /function initialEligibleSentenceIndex\(/);
  assert.match(page, /const firstEligibleSentence = initialEligibleSentenceIndex\(/);
  assert.match(page, /sentenceCourse\.entries\[nextIndex\]\?\.audio \?\? null/);
  assert.match(page, /const \[textVisibilityMode, setTextVisibilityMode\] = useState<TextVisibilityMode>\("full"\)/);
  assert.match(page, /const visibilityControlModes: readonly TextVisibilityMode\[\]/);
  assert.match(page, /aria-label=\{visibilityAriaLabel\}/);
  assert.match(page, /pendingProgressRef\.current = readPendingProgressEvents\(activeUserId, bootstrapStudyMode\)/);
  assert.match(page, /if \(hydratedUserIdRef\.current === activeUserId\) return/);
  assert.match(page, /activeCourseKindRef\.current === "sentence"/);
  assert.match(page, /function renderMaskedText/);
  assert.match(page, /const MIN_SPEECH_MS = 350/);
  assert.match(page, /const MIN_SENTENCE_WORD_COVERAGE = 0\.6/);
  assert.match(page, /hasEnoughSpeechEvidence\(repeatWordRef\.current, transcript\)/);
  assert.match(page, /function normalizeCoverageWord/);
  assert.match(page, /word === "'em"/);
  assert.match(page, /sentenceWordCoverage\(repeatWordRef\.current, transcript\) >= MIN_SENTENCE_WORD_COVERAGE/);
  assert.match(page, /renderStudyText\(currentItem\.text, textVisibilityMode, currentItem\.highlights\)/);
  assert.match(page, /learning-highlight/);
  assert.match(page, /audio: sentence\.audio, highlights: sentence\.highlights/);
  assert.match(page, /用户名只能使用英文字母/);
  assert.match(page, /placeholder="USERNAME"/);
  assert.match(page, /const STARTUP_MAX_WAIT_MS = 650/);
  assert.match(page, /new FormData\(event\.currentTarget\)\.get\("username"\)/);
  assert.match(page, /onInput=\{\(event\) => \{ setUsernameInput\(event\.currentTarget\.value\)/);
  assert.match(page, /正在恢复上次课程/);
  assert.match(page, /正在同步学习进度/);
  assert.match(page, /const PENDING_PROGRESS_KEY = "word-loop-pending-progress"/);
  assert.match(page, /clientEventId: event\.id/);
  assert.match(page, /writePendingProgressEvents\(userId, studyMode, pendingProgressRef\.current\)/);
  assert.match(page, /event\.isComposing \|\| isTextEntry/);
  assert.match(page, /typeof event\.key === "string" \? event\.key\.toLowerCase\(\) : ""/);
  assert.match(page, /const SEGMENT_SETTLE_MS = 700/);
  assert.match(page, /repeatTranscriptPartsRef\.current\.set\(payload\.item_id, transcript\)/);
  assert.match(page, /scheduleRepeatTranscriptFinalization\(turnId\)/);
  assert.match(page, /scheduleRepeatRetry\(turnId, 1_000, true\)/);
  assert.match(page, /function playMasteryCue\(context: AudioContext\)/);
  assert.match(page, /handleMarkCurrentItemMastered/);
  assert.match(page, /nextRef\.current\(\);/);
  assert.match(progressRoute, /export async function GET/);
  assert.match(progressRoute, /export async function POST/);
  assert.match(pronunciationRoute, /OPENAI_REALTIME_URL/);
  assert.match(pronunciationRoute, /gpt-4o-mini-transcribe/);
  assert.match(server, /const namedUserIdPattern = \/\^name:\[a-z\]\+\$\//);
  assert.match(server, /CREATE TABLE IF NOT EXISTS course_progress/);
  assert.match(server, /CREATE TABLE IF NOT EXISTS word_mode_progress/);
  assert.match(server, /CREATE TABLE IF NOT EXISTS course_mode_progress/);
  assert.match(server, /CREATE TABLE IF NOT EXISTS progress_events/);
  assert.match(server, /CREATE TABLE IF NOT EXISTS study_users/);
});
