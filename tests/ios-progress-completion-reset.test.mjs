import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("P5.5 live progress owns completion reset and no P4 fallback", async () => {
  const [repository, clients, runtime] = await Promise.all([
    read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/PersistentProgressRepository.swift"),
    read("ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Study/StudyClients.swift"),
    read("ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/LiveFeatureRuntime.swift"),
  ]);
  assert.match(repository, /CourseCompletionEvent/);
  assert.match(repository, /resetCourse/);
  assert.match(repository, /completeCourse/);
  assert.match(clients, /repository\.reset/);
  assert.match(clients, /repository\.complete/);
  assert.doesNotMatch(runtime, /TemporaryProgressRepository|completionFallback/);
});
