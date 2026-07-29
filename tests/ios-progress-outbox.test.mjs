import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("P5.3 persists pending progress before VPS flush and reuses event identity", async () => {
  const repository = await read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/PersistentProgressRepository.swift");
  assert.match(repository, /context\.insert\(ProgressEvent/);
  assert.match(repository, /try context\.save\(\)[\s\S]*return try projectedCount/);
  assert.match(repository, /clientEventId: event\.clientEventID/);
  assert.match(repository, /activePartitions\.insert/);
  assert.match(repository, /case \.networkRecovered[\s\S]*case appBecameActive|ProgressFlushTrigger/);
  assert.doesNotMatch(repository, /TemporaryProgressRepository|StudyStore|StartupStore/);
});

test("P5.3 transport is injected and the app configuration remains VPS-backed", async () => {
  const [client, debug, release] = await Promise.all([
    read("ios/Packages/WordLoopNetworking/Sources/WordLoopNetworking/ProgressAPIClient.swift"),
    read("ios/Config/Debug.xcconfig"),
    read("ios/Config/Release.xcconfig"),
  ]);
  assert.match(client, /public init\(baseURL: URL, transport:/);
  assert.match(client, /URLSession\.shared\.data/);
  assert.doesNotMatch(client, /boringmax|cloudflare|openai\/hosting/);
  assert.match(debug, /WORDLOOP_API_BASE_URL = https:\/\$\(\)\/boringmax\.com\/wordloop\/api/);
  assert.match(release, /WORDLOOP_API_BASE_URL = https:\/\$\(\)\/boringmax\.com\/wordloop\/api/);
});

test("P5.3 does not prematurely replace the live P4 feature adapter", async () => {
  const [temporary, factory] = await Promise.all([
    read("ios/Packages/WordLoopProgress/Sources/WordLoopProgress/TemporaryProgressRepository.swift"),
    read("ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/WordLoopFeatures.swift"),
  ]);
  assert.match(temporary, /public actor TemporaryProgressRepository/);
  assert.match(factory, /TemporaryProgressRepository\(\)/);
  assert.doesNotMatch(factory, /PersistentProgressRepository|ProgressAPIClient/);
});
