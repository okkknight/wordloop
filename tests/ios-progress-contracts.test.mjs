import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("P5.1 progress fixtures cover every frozen request shape", async () => {
  const cases = JSON.parse(await read("contracts/progress/post-cases.json"));
  assert.deepEqual(cases.map(({ name }) => name), [
    "word-progress",
    "course-progress-mastered",
    "select-course",
    "reset-course",
    "complete-course",
  ]);
  assert.deepEqual(JSON.parse(await read("contracts/progress/get-course-success.json")), {
    progress: [{ itemId: "line-001", studyCount: 3 }],
  });
  const errors = JSON.parse(await read("contracts/progress/error-cases.json"));
  assert.deepEqual(errors.map(({ status, response }) => [status, response.error]), [
    [400, "invalid user id"],
    [400, "invalid study mode"],
    [400, "invalid progress update"],
  ]);
});

test("P5.1 Networking remains DTO-only and temporary progress stays in P4", async () => {
  const [dto, temporary] = await Promise.all([
    read("ios/Packages/WordLoopNetworking/Sources/WordLoopNetworking/ProgressDTO.swift"),
    read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/TemporaryProgressRepository.swift"),
  ]);
  assert.match(dto, /public struct CompleteCourseRequestDTO/);
  assert.match(dto, /public struct ProgressQueryDTO/);
  assert.doesNotMatch(dto, /URLSession|SwiftData|UserDefaults|outbox|NWPathMonitor/);
  assert.match(temporary, /public actor TemporaryProgressRepository/);
});

test("Cloudflare progress validation matches the VPS Node contract", async () => {
  const route = await read("app/api/progress/route.ts");
  assert.match(route, /error: "invalid study mode"/);
  assert.match(route, /typeof payload\.courseId !== "string"/);
  assert.match(route, /typeof payload\.itemId === "string"/);
  assert.match(route, /typeof payload\.word !== "string" \|\| !payload\.word\.trim\(\)/);
  assert.doesNotMatch(route, /wordSet\.has\(payload\.word\)/);
});
