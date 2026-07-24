import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { lstat, mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";
import { promisify } from "node:util";
import test from "node:test";

const execFileAsync = promisify(execFile);
const root = resolve(import.meta.dirname, "..");
const distributionRoot = join(root, "content/dist");
const generatedRoot = join(root, "ios/Generated/WordLoopContent");
const packageResourceRoot = join(
  root,
  "ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent",
);

async function regularFiles(directory) {
  const files = [];
  async function visit(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const path = join(current, entry.name);
      const metadata = await lstat(path);
      assert.equal(metadata.isSymbolicLink(), false, `${relative(directory, path)} must not be a symlink`);
      if (metadata.isDirectory()) await visit(path);
      else {
        assert.equal(metadata.isFile(), true, `${relative(directory, path)} must be a regular file`);
        files.push(relative(directory, path).split(sep).join("/"));
      }
    }
  }
  await visit(directory);
  return files.sort();
}

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

async function assertEquivalentTrees(source, destination, expectedFiles) {
  assert.deepEqual(await regularFiles(destination), expectedFiles);
  for (const path of expectedFiles) {
    assert.equal(await sha256(join(destination, path)), await sha256(join(source, path)), `${path} digest`);
  }
}

test("bootstrap atomically refreshes the intermediate and exact Package resource mirrors", async () => {
  await mkdir(generatedRoot, { recursive: true });
  await mkdir(packageResourceRoot, { recursive: true });
  await writeFile(join(generatedRoot, "stale-generated.txt"), "stale\n");
  await writeFile(join(packageResourceRoot, "stale-package.txt"), "stale\n");

  await execFileAsync("sh", ["scripts/bootstrap_ios_content.sh"], {
    cwd: root,
    maxBuffer: 16 * 1024 * 1024,
  });

  const distributionFiles = await regularFiles(distributionRoot);
  const bundledFiles = distributionFiles.filter(
    (path) => path === "catalog.json" || path.startsWith("courses/"),
  );
  assert.equal(distributionFiles.includes("validation-report.json"), true);
  assert.equal(bundledFiles.includes("validation-report.json"), false);
  assert.equal(bundledFiles.length, distributionFiles.length - 1);

  await assertEquivalentTrees(distributionRoot, generatedRoot, distributionFiles);
  await assertEquivalentTrees(distributionRoot, packageResourceRoot, bundledFiles);

  for (const path of bundledFiles) {
    const [sourceMetadata, mirrorMetadata] = await Promise.all([
      stat(join(distributionRoot, path)),
      stat(join(packageResourceRoot, path)),
    ]);
    if (sourceMetadata.dev === mirrorMetadata.dev) {
      assert.equal(mirrorMetadata.ino, sourceMetadata.ino, `${path} should use a same-volume hard link`);
    }
  }

  const report = JSON.parse(await readFile(join(distributionRoot, "validation-report.json"), "utf8"));
  assert.equal(report.counts.collections, 4);
  assert.equal(report.counts.courses, 45);
  assert.equal(report.counts.wordEntries, 570);
  assert.equal(report.counts.sentenceEntries, 1076);
  assert.equal(report.counts.audioFiles, 1_646);
  assert.equal(report.counts.audioBytes, 39_744_004);
  assert.equal(bundledFiles.filter((path) => path.endsWith(".m4a")).length, 1_646);
});

test("Package copy declaration, ignore rules, tracking and App resource ownership stay singular", async () => {
  const [bootstrap, manifest, ignore, project, tracked] = await Promise.all([
    readFile(join(root, "scripts/bootstrap_ios_content.sh"), "utf8"),
    readFile(join(root, "ios/Packages/WordLoopContent/Package.swift"), "utf8"),
    readFile(join(root, ".gitignore"), "utf8"),
    readFile(join(root, "ios/WordLoop.xcodeproj/project.pbxproj"), "utf8"),
    execFileAsync("git", ["ls-files"], { cwd: root }).then(({ stdout }) => stdout.split("\n").filter(Boolean)),
  ]);

  assert.match(bootstrap, /ios\/Generated\/WordLoopContent/);
  assert.match(
    bootstrap,
    /ios\/Packages\/WordLoopContent\/Sources\/WordLoopContent\/Resources\/WordLoopContent/,
  );
  assert.match(bootstrap, /mktemp -d/);
  assert.match(bootstrap, /ln "\$source_file" "\$destination_file"[\s\S]*cp "\$source_file" "\$destination_file"/);
  assert.match(manifest, /\.copy\("Resources\/WordLoopContent"\)/);
  assert.doesNotMatch(manifest, /\.process\("Resources\/WordLoopContent"\)/);
  assert.match(
    ignore,
    /^\/ios\/Packages\/WordLoopContent\/Sources\/WordLoopContent\/Resources\/WordLoopContent\/$/m,
  );

  assert.equal(tracked.some((path) => path.startsWith("ios/Generated/")), false);
  assert.equal(
    tracked.some((path) => path.startsWith("ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent/")),
    false,
  );
  assert.doesNotMatch(project, /ios\/Generated|Generated\/WordLoopContent/);
  assert.doesNotMatch(project, /validation-report\.json/);

  for (const path of [
    "ios/Generated/WordLoopContent/catalog.json",
    "ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent/catalog.json",
  ]) {
    await execFileAsync("git", ["check-ignore", "-q", path], { cwd: root });
  }
});

test("content module remains read-only and repository construction stays in the live feature factory", async () => {
  const presentationRoots = ["Startup", "StudyShell", "CourseDrawer", "ProgressDrawer", "CompletionDialog"];
  const [coreFiles, contentFiles, appFiles, featureFiles, ...presentationFileGroups] = await Promise.all([
    regularFiles(join(root, "ios/Packages/WordLoopCore/Sources/WordLoopCore")),
    regularFiles(join(root, "ios/Packages/WordLoopContent/Sources/WordLoopContent")),
    regularFiles(join(root, "ios/App")),
    regularFiles(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures")),
    ...presentationRoots.map((directory) => regularFiles(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures", directory))),
  ]);
  const readSwift = async (base, paths) => (await Promise.all(paths.filter((path) => path.endsWith(".swift")).map((path) => readFile(join(base, path), "utf8")))).join("\n");
  const [core, content, app, features, ...presentationSources] = await Promise.all([
    readSwift(join(root, "ios/Packages/WordLoopCore/Sources/WordLoopCore"), coreFiles),
    readSwift(join(root, "ios/Packages/WordLoopContent/Sources/WordLoopContent"), contentFiles),
    readSwift(join(root, "ios/App"), appFiles),
    readSwift(join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures"), featureFiles),
    ...presentationRoots.map((directory, index) => readSwift(
      join(root, "ios/Packages/WordLoopFeatures/Sources/WordLoopFeatures", directory),
      presentationFileGroups[index],
    )),
  ]);

  assert.doesNotMatch(core, /import (?:SwiftUI|AVFoundation|WordLoop\w+)/);
  assert.doesNotMatch(
    content,
    /(?:URLSession|AVFoundation|SwiftData|UserDefaults|Keychain|WebRTC|Realtime|Timer\s*[.(]|DispatchSourceTimer)/,
  );
  assert.match(features, /makeLocalIntegrationStudyStore\(\)/);
  assert.match(features, /BundledCourseSource\.live\(\)/);
  assert.match(features, /CourseRepository\(source: source\)/);
  assert.doesNotMatch(app, /(?:BundledCourseSource|CourseRepository)\s*\(/);
  assert.doesNotMatch(presentationSources.join("\n"), /(?:BundledCourseSource|CourseRepository)\s*\(/);
});
