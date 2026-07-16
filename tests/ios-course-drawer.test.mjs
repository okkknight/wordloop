import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const sourceRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/CourseDrawer");

test("iOS course drawer stays a fixture-only iPhone feature", async () => {
  const [models, fixtures, state, store, view, studyView, appRoot, packageManifest] = await Promise.all([
    readFile(join(sourceRoot, "CourseDrawerModels.swift"), "utf8"),
    readFile(join(sourceRoot, "CourseDrawerFixtures.swift"), "utf8"),
    readFile(join(sourceRoot, "CourseDrawerViewState.swift"), "utf8"),
    readFile(join(sourceRoot, "CourseDrawerStore.swift"), "utf8"),
    readFile(join(sourceRoot, "CourseDrawerView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell/MainStudyView.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Package.swift"), "utf8"),
  ]);

  assert.match(models, /completionAccessibilityValue/);
  assert.match(fixtures, /IELTS 高频词/);
  assert.match(fixtures, /摩登家庭 · 第一季/);
  assert.match(fixtures, /VOA · Level 2/);
  assert.equal((fixtures.match(/Modern Family · S01E0[1-5]/g) ?? []).length, 5);
  assert.match(state, /-wordloop-course-drawer/);
  assert.match(store, /@MainActor\s+@Observable\s+public final class CourseDrawerStore/);
  assert.match(store, /horizontal < -72/);

  for (const identifier of [
    "course-drawer.page", "course-drawer.close", "course-drawer.backdrop",
    "course-drawer.search", "course-drawer.search-clear", "course-drawer.list",
    "course-drawer.empty", "course-drawer.collection", "course-drawer.course",
  ]) {
    assert.match(view, new RegExp(identifier.replaceAll(".", "\\.")));
  }
  assert.match(view, /SideDrawer\(/);
  assert.match(view, /CourseCard\(/);
  assert.match(view, /COURSE PACKAGES/);
  assert.match(view, /选择课程/);
  assert.match(view, /搜索课程/);
  assert.match(studyView, /courseDrawerStore\.present/);
  assert.match(studyView, /courseDrawerStore\.state\.isPresented \|\| progressDrawerStore\.state\.isPresented/);
  assert.match(appRoot, /CourseDrawerViewState\.fixture/);
  assert.match(appRoot, /courseDrawerStore: courseDrawerStore,[\s\S]*progressDrawerStore: progressDrawerStore/);

  const runtime = `${models}\n${fixtures}\n${state}\n${store}\n${view}`;
  const forbiddenRuntime = /(?:URLSession|UserDefaults|Keychain|SwiftData|AVFoundation|WebRTC|WordLoopNetworking|WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime)/;
  assert.doesNotMatch(runtime, forbiddenRuntime);
  assert.doesNotMatch(packageManifest, /\.product\(name: "WordLoopNetworking"/);
});
