import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = resolve(new URL("../", import.meta.url).pathname);
const script = join(root, "scripts/capture_ios_migration_baseline.mjs");

async function fixture() {
  const target = await mkdtemp(join(tmpdir(), "wordloop-baseline-"));
  await mkdir(join(target, "app/data"), { recursive: true });
  await cp(join(root, "app/page.tsx"), join(target, "app/page.tsx"));
  await cp(join(root, "app/repeat-scorer.ts"), join(target, "app/repeat-scorer.ts"));
  await cp(join(root, "app/courses.ts"), join(target, "app/courses.ts"));
  await cp(join(root, "app/words.ts"), join(target, "app/words.ts"));
  await cp(join(root, "app/globals.css"), join(target, "app/globals.css"));
  await cp(join(root, "app/data"), join(target, "app/data"), { recursive: true });
  await symlink(join(root, "public"), join(target, "public"), "dir");
  return target;
}

function run(target, ...argumentsPassed) {
  return spawnSync(process.execPath, [script, ...argumentsPassed], {
    cwd: root,
    encoding: "utf8",
    env: { ...process.env, WORDLOOP_BASELINE_ROOT: target },
  });
}

test("iOS migration baseline output is deterministic and grounded in the runtime registry", async () => {
  const target = await fixture();
  const first = run(target);
  const second = run(target);
  assert.equal(first.status, 0, first.stderr);
  assert.equal(second.status, 0, second.stderr);
  assert.equal(first.stdout, second.stdout);
  const inventory = JSON.parse(first.stdout);
  assert.equal(inventory.counts.courses, 53);
  assert.equal(inventory.counts.totalM4aFiles, 1774);
  assert.equal(inventory.defaults.courseId, "modern-family-s01e01");
  assert.equal(inventory.defaults.studyMode, "repeat");
  assert.equal(inventory.registeredCourses.length, 53);
});

test("iOS migration baseline observes default course and mode source changes", async () => {
  const target = await fixture();
  const coursesPath = join(target, "app/courses.ts");
  const pagePath = join(target, "app/page.tsx");
  await writeFile(coursesPath, (await readFile(coursesPath, "utf8")).replace(
    "export const DEFAULT_COURSE = MODERN_FAMILY_S01E01_COURSE;",
    "export const DEFAULT_COURSE = IELTS_HIGH_FREQUENCY_COURSE;",
  ));
  await writeFile(pagePath, (await readFile(pagePath, "utf8")).replace(
    'useState<StudyMode>("repeat")',
    'useState<StudyMode>("listen")',
  ));
  const result = run(target);
  assert.equal(result.status, 0, result.stderr);
  const inventory = JSON.parse(result.stdout);
  assert.equal(inventory.defaults.courseId, "ielts-high-frequency");
  assert.equal(inventory.defaults.studyMode, "listen");
});

test("iOS migration baseline rejects a missing referenced audio file", async () => {
  const target = await fixture();
  const manifestPath = join(target, "app/data/modern-family-s01e01.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  manifest.entries.find((entry) => entry.learnable && entry.audio).audio = "audio/does-not-exist.m4a";
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  const result = run(target);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /audio\/ID mismatch/);
});

test("iOS migration baseline rejects an unregistered course manifest", async () => {
  const target = await fixture();
  await writeFile(join(target, "app/data/unregistered.json"), JSON.stringify({ entries: [] }));
  const result = run(target);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unregistered course manifests/);
});

test("iOS migration baseline CLI rejects conflicting and unknown arguments", () => {
  const conflicting = run(root, "--write", "--check");
  const unknown = run(root, "--unknown");
  assert.notEqual(conflicting.status, 0);
  assert.match(conflicting.stderr, /either --write or --check/);
  assert.notEqual(unknown.status, 0);
  assert.match(unknown.stderr, /Unknown arguments/);
});
