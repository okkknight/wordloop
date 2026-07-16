import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { join, resolve } from "node:path";
import test from "node:test";

const root = resolve(import.meta.dirname, "..");
const audioRoot = join(root, "ios/Packages/WordLoopAudio");

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

test("iOS audio player exposes tokenized current-next playback primitives", async () => {
  const source = await swiftSource(join(audioRoot, "Sources/WordLoopAudio"));

  assert.match(source, /public actor AudioPlayer/);
  assert.match(source, /public struct PlaybackRequestID/);
  assert.match(source, /public enum AudioPlaybackPhase/);
  assert.match(source, /public enum AudioPlayerError/);
  assert.match(source, /func prepare\(current: URL, next: URL\?\)/);
  assert.match(source, /func play\(\) async throws -> PlaybackRequestID/);
  assert.match(source, /func pause\(\) async/);
  assert.match(source, /func stop\(\) async/);
  assert.match(source, /func events\(\) async -> AsyncStream<AudioPlayerEvent>/);

  for (const seam of [
    "AudioEngine",
    "AudioEngineFactory",
    "AudioSessionControlling",
    "AudioSystemEventSource",
  ]) {
    assert.match(source, new RegExp(`protocol ${seam}\\b`), `${seam} seam`);
  }
  assert.match(source, /AVAudioPlayer\(contentsOf:/);
  assert.match(source, /prepareToPlay\(\)/);
  assert.match(source, /\.playback, mode: \.spokenAudio/);
});

test("system audio events pause safely without owning LISTEN orchestration", async () => {
  const source = await swiftSource(join(audioRoot, "Sources/WordLoopAudio"));

  assert.match(source, /interruptionNotification/);
  assert.match(source, /routeChangeNotification/);
  assert.match(source, /mediaServicesWereResetNotification/);
  assert.match(source, /oldDeviceUnavailable/);
  assert.match(source, /didEnterBackgroundNotification/);
  assert.match(source, /case \.interruptionEnded, \.otherRouteChange, \.lifecycleInactive, \.lifecycleActive:\s*break/);

  assert.doesNotMatch(source, /(?:URLSession|WebRTC|SwiftData|UserDefaults|Keychain|MPNowPlayingInfoCenter|MPRemoteCommandCenter)/);
  assert.doesNotMatch(source, /(?:AUTOPLAY|AutoPlay|autoplay|500\s*(?:ms|milliseconds)|CourseRepository|BundledCourseSource|CourseID|EntryID|StudyShell|ProgressDrawer|Realtime)/);
  assert.doesNotMatch(source, /import (?:WordLoopContent|WordLoopFeatures|WordLoopProgress|WordLoopRealtime|WordLoopNetworking|SwiftUI)/);
  assert.doesNotMatch(source, /https?:\/\//);
});

test("Audio remains an iPhone-only service and only the live feature factory initializes it", async () => {
  const [manifest, features, p3StudyShell, app, info, shared] = await Promise.all([
    readFile(join(audioRoot, "Package.swift"), "utf8"),
    swiftSource(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures")),
    swiftSource(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures/StudyShell")),
    swiftSource(join(root, "ios/App")),
    readFile(join(root, "ios/App/Info.plist"), "utf8"),
    readFile(join(root, "ios/Config/Shared.xcconfig"), "utf8"),
  ]);

  assert.match(manifest, /\.package\(path: "\.\.\/WordLoopCore"\)/);
  assert.doesNotMatch(manifest, /https?:\/\//);
  assert.match(features, /makeLiveStudyStore\(\)/);
  assert.match(features, /AudioPlayer\.live\(\)/);
  assert.doesNotMatch(p3StudyShell, /AudioPlayer\.live\(\)|AudioPlayer\s*\(/);
  assert.doesNotMatch(app, /AudioPlayer\.live\(\)|AudioPlayer\s*\(/);
  assert.doesNotMatch(info, /UIBackgroundModes|audio/);
  assert.match(shared, /TARGETED_DEVICE_FAMILY = 1/);
  assert.match(shared, /SUPPORTS_MACCATALYST = NO/);
  assert.match(shared, /SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO/);
});
