import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { join, resolve } from "node:path";
import test from "node:test";

const root = resolve(import.meta.dirname, "..");

async function swiftSource(directory) {
  const parts = [];
  async function visit(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const path = join(current, entry.name);
      if (entry.isDirectory()) await visit(path);
      else if (entry.name.endsWith(".swift")) parts.push(await readFile(path, "utf8"));
    }
  }
  await visit(directory);
  return parts.join("\n");
}

test("live study is split into state selection projection clients session and view roles", async () => {
  const studyRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Study");
  const names = await readdir(studyRoot);
  for (const file of [
    "StudyState.swift",
    "StudyStore.swift",
    "StudyClients.swift",
    "ListenSession.swift",
    "StudySelection.swift",
    "StudyProjection.swift",
    "LiveStudyView.swift",
  ]) {
    assert.ok(names.includes(file), file);
  }

  const store = await readFile(join(studyRoot, "StudyStore.swift"), "utf8");
  const view = await readFile(join(studyRoot, "LiveStudyView.swift"), "utf8");
  assert.match(store, /@MainActor\s*@Observable\s*public final class StudyStore/);
  assert.match(store, /ListenSessionGeneration/);
  assert.match(store, /PlaybackRequestID/);
  assert.match(store, /\.milliseconds\(500\)/);
  assert.match(store, /public func retry\(\) async/);
  assert.match(store, /sessionMatches\(/);
  assert.doesNotMatch(store, /requestID == nil \|\|/);
  assert.match(view, /MainStudyView\(/);
  assert.match(view, /store\.retry\(\)/);
  assert.doesNotMatch(view, /CourseRepository|AudioPlayer|TemporaryProgressRepository|Task\.sleep/);
});

test("temporary progress is session-only and production study has no deferred platform scope", async () => {
  const [progress, study, appInfo] = await Promise.all([
    readFile(join(root, "ios/Packages/WordLoopProgress/Sources/WordLoopProgress/TemporaryProgressRepository.swift"), "utf8"),
    swiftSource(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Study")),
    readFile(join(root, "ios/App/Info.plist"), "utf8"),
  ]);

  assert.match(progress, /public actor TemporaryProgressRepository/);
  assert.match(progress, /CourseID/);
  assert.match(progress, /StudyMode/);
  assert.match(progress, /EntryID/);
  assert.match(progress, /func reset\(courseID: CourseID, mode: StudyMode\)/);
  assert.match(progress, /func complete\(courseID: CourseID, completionID: String\)/);
  assert.doesNotMatch(progress, /UserDefaults|SwiftData|URLSession|Keychain|outbox/);
  assert.doesNotMatch(study, /URLSession|SwiftData|UserDefaults|AVAudioRecorder|WebRTC|MPRemoteCommandCenter|MPNowPlayingInfoCenter/);
  assert.doesNotMatch(appInfo, /UIBackgroundModes|audio/);
});

test("live route coexists with frozen fixtures and remains iPhone-only", async () => {
  const [route, rootView, project, shared] = await Promise.all([
    readFile(join(root, "ios/App/AppRoute.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/WordLoop.xcodeproj/project.pbxproj"), "utf8"),
    readFile(join(root, "ios/Config/Shared.xcconfig"), "utf8"),
  ]);

  assert.match(route, /designSystemGallery[\s\S]*fixtureStudy[\s\S]*liveStudy[\s\S]*startup/);
  assert.match(route, /-wordloop-live-study/);
  assert.match(rootView, /StartupView\(store: startupStore\)/);
  assert.match(rootView, /LiveStudyView\(store: liveStudyStore\)/);
  assert.match(project, /AppRoute\.swift in Sources/);
  assert.match(shared, /TARGETED_DEVICE_FAMILY = 1/);
  assert.match(shared, /SUPPORTS_MACCATALYST = NO/);
  assert.match(shared, /SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO/);
  assert.doesNotMatch(project, /com\.apple\.product-type\.application\.watchapp|product-type\.application\.on-demand-install-capable/);
});
