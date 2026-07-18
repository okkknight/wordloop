import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("P5.2 defines the complete versioned SwiftData progress schema", async () => {
  const schema = await read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/ProgressSchema.swift");
  for (const model of [
    "StudyIdentity",
    "ProgressRecord",
    "ProgressEvent",
    "CourseCompletionRecord",
    "CourseCompletionEvent",
    "CoursePreference",
  ]) {
    assert.match(schema, new RegExp(`public final class ${model}`));
  }
  assert.match(schema, /WordLoopProgressSchemaV1: VersionedSchema/);
  assert.match(schema, /Schema\.Version\(1, 0, 0\)/);
  assert.match(schema, /WordLoopProgressMigrationPlan: SchemaMigrationPlan/);
  assert.match(schema, /ProgressStableKey\.make/);
});

test("P5.2 remains persistence-only and keeps the P4 adapter", async () => {
  const [schema, temporary, progressPackage] = await Promise.all([
    read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/ProgressSchema.swift"),
    read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/TemporaryProgressRepository.swift"),
    read("ios/Packages/WordLoopProgress/Package.swift"),
  ]);
  assert.match(schema, /import SwiftData/);
  assert.doesNotMatch(schema, /URLSession|URLRequest|NWPathMonitor|flush|HTTP|StudyStore|StartupStore/);
  assert.match(temporary, /public actor TemporaryProgressRepository/);
  assert.doesNotMatch(progressPackage, /WordLoopFeatures/);
});
