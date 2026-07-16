import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const sourceRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/ProgressDrawer");

test("iOS progress drawer stays a fixture-only iPhone feature", async () => {
  const [entry, summary, fixtures, state, store, view, studyView, appRoot, packageManifest] = await Promise.all([
    readFile(join(sourceRoot, "ProgressDrawerEntry.swift"), "utf8"),
    readFile(join(sourceRoot, "ProgressDrawerSummary.swift"), "utf8"),
    readFile(join(sourceRoot, "ProgressDrawerFixtures.swift"), "utf8"),
    readFile(join(sourceRoot, "ProgressDrawerViewState.swift"), "utf8"),
    readFile(join(sourceRoot, "ProgressDrawerStore.swift"), "utf8"),
    readFile(join(sourceRoot, "ProgressDrawerView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell/MainStudyView.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Package.swift"), "utf8"),
  ]);

  assert.match(entry, /studyCount = Self\.clamp/);
  assert.match(entry, /已学习.*共 3 次/);
  assert.match(summary, /maxStudyCount = 3/);
  assert.match(fixtures, /Modern Family · S01E01/);
  assert.match(fixtures, /Phil, would you get them\?/);
  assert.match(fixtures, /\/ˈkʌmftəbl\/ · 舒服的；自在的/);
  assert.match(state, /-wordloop-progress-drawer/);
  assert.match(state, /-wordloop-progress-(?:word|mixed|complete|query|empty)/);
  assert.match(store, /@MainActor\s+@Observable\s+public final class ProgressDrawerStore/);
  assert.match(store, /horizontal > 72/);

  for (const identifier of [
    "progress-drawer.page", "progress-drawer.close", "progress-drawer.backdrop",
    "progress-drawer.track", "progress-drawer.stats.mastered", "progress-drawer.stats.learning",
    "progress-drawer.search", "progress-drawer.search-clear", "progress-drawer.list",
    "progress-drawer.empty", "progress-drawer.entry",
  ]) {
    assert.match(view, new RegExp(identifier.replaceAll(".", "\\.")));
  }
  assert.match(view, /SideDrawer\([\s\S]*edge: \.trailing/);
  assert.match(view, /YOUR PROGRESS/);
  assert.match(view, /没有匹配的学习记录/);
  assert.match(view, /ProgressTrack\(/);
  assert.match(studyView, /progressDrawerStore\.present/);
  assert.match(studyView, /courseDrawerStore\.state\.isPresented \|\| progressDrawerStore\.state\.isPresented/);
  assert.match(appRoot, /ProgressDrawerViewState\.fixture/);
  assert.match(appRoot, /let courseState = CourseDrawerViewState\.fixture[\s\S]*if courseState\.isPresented[\s\S]*progressState\.isPresented = false/);

  const runtime = `${entry}\n${summary}\n${fixtures}\n${state}\n${store}\n${view}`;
  const forbiddenRuntime = /(?:URLSession|UserDefaults|Keychain|SwiftData|AVFoundation|WebRTC|WordLoopNetworking|WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime)/;
  assert.doesNotMatch(runtime, forbiddenRuntime);
  assert.doesNotMatch(packageManifest, /\.product\(name: "WordLoopNetworking"/);
});
