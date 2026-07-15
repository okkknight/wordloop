import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import test from "node:test";

const execFileAsync = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const packages = [
  "WordLoopCore",
  "WordLoopNetworking",
  "WordLoopContent",
  "WordLoopDesignSystem",
  "WordLoopAudio",
  "WordLoopProgress",
  "WordLoopRealtime",
  "WordLoopFeatures",
];

test("native project is an iPhone-only Swift 6 modular skeleton", async () => {
  const required = [
    "ios/WordLoop.xcodeproj/project.pbxproj",
    "ios/WordLoop.xcodeproj/xcshareddata/xcschemes/WordLoop.xcscheme",
    "ios/App/WordLoopApp.swift",
    "ios/App/RootView.swift",
    "ios/App/AppContainer.swift",
    "ios/App/AppEnvironment.swift",
    "ios/App/Info.plist",
    "ios/App/PrivacyInfo.xcprivacy",
    "ios/Config/Shared.xcconfig",
    "ios/Config/Debug.xcconfig",
    "ios/Config/Release.xcconfig",
    "ios/Tests/AppIntegrationTests/AppIntegrationTests.swift",
    "ios/Tests/AppUITests/AppUITests.swift",
    "scripts/verify_ios.sh",
  ];
  for (const path of required) await access(join(root, path));
  for (const name of packages) {
    await access(join(root, `ios/Packages/${name}/Package.swift`));
    await access(join(root, `ios/Packages/${name}/Sources/${name}/${name}.swift`));
    await access(join(root, `ios/Packages/${name}/Tests/${name}Tests/${name}Tests.swift`));
  }

  const [project, shared, app, environment, scheme] = await Promise.all([
    readFile(join(root, "ios/WordLoop.xcodeproj/project.pbxproj"), "utf8"),
    readFile(join(root, "ios/Config/Shared.xcconfig"), "utf8"),
    readFile(join(root, "ios/App/AppContainer.swift"), "utf8"),
    readFile(join(root, "ios/App/AppEnvironment.swift"), "utf8"),
    readFile(join(root, "ios/WordLoop.xcodeproj/xcshareddata/xcschemes/WordLoop.xcscheme"), "utf8"),
  ]);
  assert.match(project, /productType = "com\.apple\.product-type\.application"/);
  assert.match(project, /relativePath = Packages\/WordLoopFeatures/);
  assert.match(shared, /SWIFT_VERSION = 6\.0/);
  assert.match(shared, /IPHONEOS_DEPLOYMENT_TARGET = 17\.0/);
  assert.match(shared, /TARGETED_DEVICE_FAMILY = 1/);
  assert.match(shared, /SUPPORTS_MACCATALYST = NO/);
  assert.match(shared, /SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO/);
  assert.match(app, /import WordLoopFeatures/);
  assert.match(environment, /url\.scheme == "https"/);
  assert.match(scheme, /BlueprintName="WordLoop"/);

  const manifests = new Map(await Promise.all(packages.map(async (name) => [name, await readFile(join(root, `ios/Packages/${name}/Package.swift`), "utf8")])));
  for (const [name, manifest] of manifests) {
    assert.match(manifest, /\.iOS\(\.v17\)/, `${name} iOS platform`);
    assert.match(manifest, /swiftLanguageModes: \[\.v6\]/, `${name} Swift language mode`);
    assert.doesNotMatch(manifest, /https?:\/\//, `${name} has no remote dependency`);
  }
  assert.doesNotMatch(manifests.get("WordLoopCore"), /\.package\(/);
  assert.match(manifests.get("WordLoopFeatures"), /\.package\(path: "\.\.\/WordLoopRealtime"\)/);

  const sensitive = `${project}\n${shared}\n${app}\n${environment}`;
  assert.doesNotMatch(sensitive, /(?:sk-|OPENAI_API_KEY|api[_-]?key\s*=|token\s*=)/i);

  for (const path of [
    "content/dist",
    "ios/Generated",
    "ios/.build/debug.yaml",
    "ios/Packages/WordLoopCore/.build/debug.yaml",
    "ios/.derivedData",
    "ios/WordLoop.xcodeproj/xcuserdata/UserInterfaceState.xcuserstate",
  ]) {
    const result = await execFileAsync("git", ["check-ignore", "-q", path], { cwd: root }).then(() => true, () => false);
    assert.equal(result, true, `${path} must be ignored`);
  }
});
