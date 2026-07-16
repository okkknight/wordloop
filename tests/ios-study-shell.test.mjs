import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const sourceRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell");

test("iOS study shell is an explicit fixture-only iPhone page", async () => {
  const [mode, visibility, item, state, store, view, appRoot, appRoute, packageManifest] = await Promise.all([
    readFile(join(sourceRoot, "StudyShellMode.swift"), "utf8"),
    readFile(join(sourceRoot, "StudyTextVisibility.swift"), "utf8"),
    readFile(join(sourceRoot, "StudyShellItem.swift"), "utf8"),
    readFile(join(sourceRoot, "StudyShellViewState.swift"), "utf8"),
    readFile(join(sourceRoot, "StudyShellStore.swift"), "utf8"),
    readFile(join(sourceRoot, "MainStudyView.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/App/AppRoute.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Package.swift"), "utf8"),
  ]);

  assert.match(mode, /case listen/);
  assert.match(mode, /case `?repeat`?/);
  assert.match(visibility, /case full/);
  assert.match(visibility, /case focus/);
  assert.match(visibility, /case hidden/);
  assert.match(item, /resolvedHighlightRanges/);
  assert.match(state, /MODERN FAMILY · S01E01/);
  assert.match(state, /Uh, my dad still isn't completely comfortable with this\./);
  assert.match(state, /我爸对这事还是不太习惯/);
  assert.match(store, /@MainActor\s+@Observable\s+public final class StudyShellStore/);

  for (const identifier of [
    "study.page", "study.course", "study.progress",
    "study.course-context", "study.english", "study.translation", "study.visibility",
    "study.mastery", "study.too-easy", "study.primary-control", "study.next", "study.repeat-card",
  ]) {
    assert.match(view, new RegExp(identifier.replaceAll(".", "\\.")));
  }
  assert.match(view, /accessibilityIdentifierPrefix: "study\.mode"/);
  assert.match(view, /PosterBackground/);
  assert.match(view, /ModeSwitch/);
  assert.match(view, /Waveform/);
  assert.match(view, /accessibilityReduceMotion/);
  assert.match(view, /minimumHit/);
  assert.equal((view.match(/\.font\(\.system\(size: 18, weight: \.semibold\)\)/g) ?? []).length, 2);

  assert.match(appRoute, /-wordloop-study-shell/);
  assert.match(appRoot, /courseDrawerStore: courseDrawerStore,[\s\S]*progressDrawerStore: progressDrawerStore/);
  assert.match(appRoute, /designSystemGallery[\s\S]*fixtureStudy[\s\S]*liveStudy[\s\S]*startup/);
  assert.match(appRoot, /route == \.designSystemGallery[\s\S]*route == \.fixtureStudy[\s\S]*route == \.liveStudy[\s\S]*StartupView/);
  assert.doesNotMatch(appRoot, /import (?:WordLoopDesignSystem|WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime|WordLoopNetworking)/);

  const forbiddenRuntime = /(?:URLSession|UserDefaults|Keychain|SwiftData|AVFoundation|WebRTC|WordLoopNetworking)/;
  assert.doesNotMatch(`${mode}\n${visibility}\n${item}\n${state}\n${store}\n${view}`, forbiddenRuntime);
  assert.doesNotMatch(packageManifest, /\.product\(name: "WordLoopNetworking"/);
});
