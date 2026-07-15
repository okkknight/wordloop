import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const startupRoot = join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/Startup");

test("iOS startup shell keeps the frozen copy, fixture boundary, and App module boundary", async () => {
  const [state, validator, store, visualRoles, view, appRoot, container] = await Promise.all([
    readFile(join(startupRoot, "StartupState.swift"), "utf8"),
    readFile(join(startupRoot, "StartupUsernameValidator.swift"), "utf8"),
    readFile(join(startupRoot, "StartupStore.swift"), "utf8"),
    readFile(join(startupRoot, "StartupVisualRoles.swift"), "utf8"),
    readFile(join(startupRoot, "StartupView.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/App/AppContainer.swift"), "utf8"),
  ]);

  for (const copy of ["START", "PREPARING…", "SYNCING…", "正在恢复上次课程", "正在同步学习进度"]) {
    assert.match(state, new RegExp(copy));
  }
  assert.match(validator, /maximumLength = 32/);
  assert.match(validator, /用户名只能使用英文字母/);
  assert.match(validator, /65\.\.\.90/);
  assert.match(validator, /97\.\.\.122/);
  assert.match(store, /@MainActor\s+@Observable\s+public final class StartupStore/);

  for (const identifier of ["startup.page", "startup.username", "startup.error", "startup.helper", "startup.submit"]) {
    assert.match(view, new RegExp(identifier.replace(".", "\\.")));
  }
  assert.match(visualRoles, /PosterPalette\.all\.first\(where: \{ \$0\.id == "rose" \}\)/);
  assert.match(visualRoles, /placeholder[\s\S]*opacity: 0\.72/);
  assert.match(visualRoles, /inputBoundary[\s\S]*opacity: 0\.86/);
  assert.match(view, /StartupVisualRoles\.placeholder\.foreground\.color/);
  assert.match(view, /StartupVisualRoles\.inputBoundary\.foreground\.color/);
  assert.doesNotMatch(view, /palette\.accent\.color\.opacity\((?:0\.56|0\.78)\)/);
  assert.match(view, /minimumHit/);
  assert.match(view, /accessibilityReduceMotion/);
  assert.match(view, /textInputAutocapitalization\(\.never\)/);
  assert.match(view, /keyboardType\(\.asciiCapable\)/);
  assert.match(view, /autocorrectionDisabled\(true\)/);

  const forbiddenRuntime = /(?:URLSession|UserDefaults|Keychain|SwiftData|AVFoundation|WebRTC|WordLoopNetworking)/;
  assert.doesNotMatch(`${state}\n${validator}\n${store}\n${visualRoles}\n${view}`, forbiddenRuntime);

  assert.match(appRoot, /StartupView\(store: startupStore\)/);
  assert.match(appRoot, /-wordloop-design-system-gallery/);
  assert.match(appRoot, /DesignSystemGalleryView\(\)/);
  assert.match(appRoot, /-wordloop-startup-state/);
  assert.match(appRoot, /-wordloop-startup-invalid/);
  assert.match(appRoot, /import WordLoopFeatures/);
  assert.doesNotMatch(`${appRoot}\n${container}`, /import (?:WordLoopDesignSystem|WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime|WordLoopNetworking)/);
});
