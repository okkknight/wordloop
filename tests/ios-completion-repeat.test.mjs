import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const completionRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/CompletionDialog");
const studyRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell");

test("iOS completion dialogs and repeat states stay presentation-only iPhone fixtures", async () => {
  const [kind, state, store, dialogView, studyState, studyView, components, tokens, appRoot, packageManifest] = await Promise.all([
    readFile(join(completionRoot, "CompletionDialogKind.swift"), "utf8"),
    readFile(join(completionRoot, "CompletionDialogViewState.swift"), "utf8"),
    readFile(join(completionRoot, "CompletionDialogStore.swift"), "utf8"),
    readFile(join(completionRoot, "CompletionDialogView.swift"), "utf8"),
    readFile(join(studyRoot, "StudyShellViewState.swift"), "utf8"),
    readFile(join(studyRoot, "MainStudyView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopDesignSystem/Sources/WordLoopDesignSystem/Components.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopDesignSystem/Sources/WordLoopDesignSystem/Tokens.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopFeatures/Package.swift"), "utf8"),
  ]);

  assert.match(kind, /case restartCompletedCourse/);
  assert.match(kind, /case courseCompleted/);
  for (const copy of ["COURSE COMPLETE", "这门课程已经完成", "这门课程学完了", "重新开始", "再练一次"]) {
    assert.match(kind, new RegExp(copy));
  }
  assert.match(state, /暂时无法重置进度，请稍后重试。/);
  assert.match(state, /-wordloop-completion-dialog/);
  assert.match(store, /@MainActor\s+@Observable\s+public final class CompletionDialogStore/);
  assert.match(store, /requestedRestart\(state\.courseID\)/);
  assert.doesNotMatch(store, /reset|URLSession|UserDefaults|SwiftData/);

  for (const identifier of ["completion-dialog.page", "completion-dialog"]) {
    assert.match(dialogView, new RegExp(identifier.replaceAll(".", "\\.")));
  }
  assert.match(dialogView, /ConfirmDialog\(/);
  assert.match(dialogView, /\.ultraThinMaterial/);
  assert.match(components, /dialogSecondaryText/);
  assert.match(components, /dialogBoundary/);
  assert.match(tokens, /accessibleStatusVisual/);

  const repeatCases = ["idle", "connecting", "ready", "playing", "speak", "speaking", "scoring", "passed", "paused", "retry", "error"];
  for (const value of repeatCases) assert.match(studyState, new RegExp(`case ${value}(?:\\n|$)`));
  assert.match(studyState, /-wordloop-repeat-state/);
  assert.match(studyState, /-wordloop-repeat-transcript/);
  assert.match(studyView, /study\.repeat-state\./);
  assert.match(studyView, /study\.repeat-result/);
  assert.match(studyView, /study\.repeat-transcript/);
  assert.match(appRoot, /CompletionDialogViewState\.fixture/);
  assert.match(appRoot, /if completionState\.isPresented/);
  assert.match(appRoot, /completionDialogStore: completionDialogStore/);

  const runtime = `${kind}\n${state}\n${store}\n${dialogView}\n${studyState}\n${studyView}`;
  const forbidden = /(?:Timer|URLSession|UserDefaults|Keychain|SwiftData|AVFoundation|WebRTC|WordLoopNetworking|WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime)/;
  assert.doesNotMatch(runtime, forbidden);
  assert.doesNotMatch(packageManifest, /\.product\(name: "WordLoopNetworking"/);
});
