import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const designSystem = join(root, "ios/Packages/WordLoopDesignSystem");

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

test("iOS design system ships pinned fonts, license, tokens, and no business dependency", async () => {
  const [manifest, tokens, typography, components, app, container, audit, sans, mono, license] = await Promise.all([
    readFile(join(designSystem, "Package.swift"), "utf8"),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Tokens.swift"), "utf8"),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Typography.swift"), "utf8"),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Components.swift"), "utf8"),
    readFile(join(root, "ios/App/RootView.swift"), "utf8"),
    readFile(join(root, "ios/App/AppContainer.swift"), "utf8"),
    readFile(join(root, "docs/ios-migration/p3/design-system/font-audit.md"), "utf8"),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Resources/Fonts/Geist[wght].ttf")),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Resources/Fonts/GeistMono[wght].ttf")),
    readFile(join(designSystem, "Sources/WordLoopDesignSystem/Resources/Fonts/LICENSE.txt"), "utf8"),
  ]);

  assert.match(manifest, /resources:\s*\[\.process\("Resources"\)\]/);
  assert.doesNotMatch(manifest, /\.package\(/, "DesignSystem must not depend on another package");
  assert.match(tokens, /0xf3f0e8/);
  assert.match(tokens, /0x26233e/);
  assert.match(tokens, /paletteDuration[^\n]*0\.420/);
  assert.match(tokens, /minimumHit[^\n]*44/);
  assert.match(tokens, /contrastRatio\(with:/);
  assert.match(tokens, /accessibleAccentText/);
  assert.match(typography, /CTFontManagerRegisterFontsForURL/);
  for (const component of ["PosterBackground", "ModeSwitch", "PosterButton", "CourseCard", "SideDrawer", "ProgressTrack", "ConfirmDialog", "Waveform"]) {
    assert.match(components, new RegExp(`public struct ${component}\\b`), component);
  }

  assert.equal(sha256(sans), "8f700c5c9f8e5af507132f1b50baf02fc12ca4c04a1100473bf44babbe8528fe");
  assert.equal(sha256(mono), "506fbaf05ffde249c7c400b5591d1999577ebe82372b0e35266dd5d9ee385771");
  assert.equal(sha256(Buffer.from(license)), "930853ee1daa68554d9e35c8a9175affb74f699fad9a5da6ee5ebe76379d9137");
  assert.match(license, /SIL OPEN FONT LICENSE Version 1\.1/);
  assert.match(audit, /91158e012bdc4abd59fa066d0eae9fc11c2c9f24/);
  assert.match(audit, /344,268 bytes/);

  assert.match(app, /import WordLoopFeatures/);
  assert.match(app, /DesignSystemGalleryView/);
  assert.doesNotMatch(`${app}\n${container}`, /import WordLoopDesignSystem/);
  assert.doesNotMatch(`${app}\n${container}`, /import (?:WordLoopContent|WordLoopAudio|WordLoopProgress|WordLoopRealtime|WordLoopNetworking)/);
});
