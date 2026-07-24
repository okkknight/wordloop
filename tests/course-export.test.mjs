import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { cp, mkdtemp, readFile, readdir, rename, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { promisify } from "node:util";
import test from "node:test";
import { createContractValidator } from "../scripts/lib/course-export/contract.mjs";
import { digestGeneratedTree, generateCoursePackages } from "../scripts/lib/course-export/exporter.mjs";
import { loadCourseSources } from "../scripts/lib/course-export/source.mjs";

const execFileAsync = promisify(execFile);
const root = resolve(import.meta.dirname, "..");

async function json(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

async function temporaryDirectory(prefix) {
  return mkdtemp(join(tmpdir(), prefix));
}

async function withSourceDateEpoch(action) {
  const previous = process.env.SOURCE_DATE_EPOCH;
  process.env.SOURCE_DATE_EPOCH = "0";
  try {
    return await action();
  } finally {
    if (previous === undefined) delete process.env.SOURCE_DATE_EPOCH;
    else process.env.SOURCE_DATE_EPOCH = previous;
  }
}

test("course schemas accept valid fixtures and reject invalid fixtures", async () => {
  const validator = await createContractValidator(root);
  const validDirectory = join(root, "content/fixtures/valid");
  for (const prefix of ["ielts-word", "modern-family-sequential", "voa-sequential"]) {
    const catalog = await json(join(validDirectory, `${prefix}.catalog.json`));
    const course = await json(join(validDirectory, `${prefix}.course.json`));
    const integrity = await json(join(validDirectory, `${prefix}.integrity.json`));
    assert.doesNotThrow(() => validator.validatePackage(catalog, [{ course, integrity }]));
  }

  const invalidDirectory = join(root, "content/fixtures/invalid");
  const invalidFiles = (await readdir(invalidDirectory, { withFileTypes: true })).filter((entry) => entry.isFile() && entry.name.endsWith(".json"));
  for (const entry of invalidFiles) {
    const type = entry.name.match(/\.(catalog|course|integrity)\.json$/)?.[1];
    assert.ok(type, `fixture has a contract suffix: ${entry.name}`);
    const value = await json(join(invalidDirectory, entry.name));
    assert.throws(() => validator.validateDocument(type, value), undefined, entry.name);
  }

  const mismatch = join(invalidDirectory, "id-version-mismatch");
  const catalog = await json(join(mismatch, "catalog.json"));
  const course = await json(join(mismatch, "course.json"));
  const integrity = await json(join(mismatch, "integrity.json"));
  assert.throws(() => validator.validatePackage(catalog, [{ course, integrity }]), /mismatch|missing/i);
});

test("exporter is deterministic, complete, and preserves runtime course semantics", async () => {
  const temporary = await temporaryDirectory("wordloop-export-");
  try {
    const first = join(temporary, "first");
    const second = join(temporary, "second");
    await withSourceDateEpoch(async () => {
      await generateCoursePackages({ root, output: first, mode: "write" });
      await generateCoursePackages({ root, output: second, mode: "write" });
    });
    const [firstDigest, secondDigest] = await Promise.all([digestGeneratedTree(first), digestGeneratedTree(second)]);
    assert.deepEqual(firstDigest, secondDigest);

    const catalog = await json(join(first, "catalog.json"));
    const report = await json(join(first, "validation-report.json"));
    assert.equal(catalog.defaultCourseId, "modern-family-s01e01");
    assert.equal(catalog.collections.length, 4);
    assert.equal(catalog.courses.length, 36);
    assert.deepEqual(report.counts, { collections: 4, courses: 36, wordEntries: 570, sentenceEntries: 932, audioFiles: 1502, audioBytes: 36027152 });
    assert.deepEqual(report.sourceIdDifferences, [{ courseId: "modern-family-s01e01", sourceManifestId: "modern-family-s01", source: "app/data/modern-family-s01e01.json" }]);
    assert.equal(report.ignoredHighlights[0].entryIds.length, 47);

    for (const descriptor of catalog.courses) {
      const courseDirectory = join(first, "courses", descriptor.id, String(descriptor.contentVersion));
      const integrity = await json(join(courseDirectory, "integrity.json"));
      for (const file of integrity.files) {
        const bytes = await readFile(join(courseDirectory, file.path));
        assert.equal(bytes.length, file.bytes, `${descriptor.id}/${file.path} byte count`);
        assert.equal(createHash("sha256").update(bytes).digest("hex"), file.sha256, `${descriptor.id}/${file.path} hash`);
      }
    }

    const ielts = await json(join(first, "courses/ielts-high-frequency/1/course.json"));
    const modernFamily = await json(join(first, "courses/modern-family-s01e01/1/course.json"));
    const voa = await json(join(first, "courses/voa-workplace-conversations-b1/1/course.json"));
    const ieltsIntegrity = await json(join(first, "courses/ielts-high-frequency/1/integrity.json"));
    const modernFamilyIntegrity = await json(join(first, "courses/modern-family-s01e01/1/integrity.json"));
    const voaIntegrity = await json(join(first, "courses/voa-workplace-conversations-b1/1/integrity.json"));
    assert.deepEqual(ielts.entries[0], {
      id: "abandon", text: "abandon", translation: "vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵；n. 放任, 无拘束, 狂热", phonetic: "ə'bændən",
      audio: "audio/abandon.m4a", durationMilliseconds: 836,
    });
    assert.equal(modernFamily.practiceOrder, "sequential");
    assert.deepEqual(modernFamily.entries[0], {
      id: "s01e01-0003", text: "Phil, would you get them?", translation: "菲尔 把他们叫下来好吗", highlights: ["get them"],
      audio: "audio/s01e01-0003.m4a", durationMilliseconds: 1000,
    });
    assert.equal(voa.practiceOrder, "sequential");
    assert.deepEqual(voa.entries[0].highlights, ["What do you think", "is about"]);
    assert.equal(voa.entries[0].durationMilliseconds, 5540);
    assert.deepEqual(ieltsIntegrity.files.find((file) => file.path === "audio/abandon.m4a"), {
      path: "audio/abandon.m4a", bytes: 9444, sha256: "3fb0659af62b5a138310c727d6c0fa7adb599cb23a7a75b172992b2bc212298d",
    });
    assert.deepEqual(modernFamilyIntegrity.files.find((file) => file.path === "audio/s01e01-0003.m4a"), {
      path: "audio/s01e01-0003.m4a", bytes: 7099, sha256: "d9e76ee4892c447669f4f80942e0e47a18a6e07125e7d6e14b2a9b5ca5de8506",
    });
    assert.deepEqual(voaIntegrity.files.find((file) => file.path === "audio/voa-work-b1-001.m4a"), {
      path: "audio/voa-work-b1-001.m4a", bytes: 68746, sha256: "e535f90c0fef877930489566648c6856cff13a95adf2fc3b8ed80f6da7b08860",
    });
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("check detects output tampering and CLI rejects ambiguous arguments", async () => {
  const temporary = await temporaryDirectory("wordloop-export-check-");
  try {
    const output = join(temporary, "dist");
    await withSourceDateEpoch(() => generateCoursePackages({ root, output, mode: "write" }));
    await withSourceDateEpoch(() => generateCoursePackages({ root, output, mode: "check" }));
    const integrityPath = join(output, "courses/ielts-high-frequency/1/integrity.json");
    const integrity = await json(integrityPath);
    integrity.files[0].sha256 = "0".repeat(64);
    await writeFile(integrityPath, `${JSON.stringify(integrity, null, 2)}\n`);
    await assert.rejects(withSourceDateEpoch(() => generateCoursePackages({ root, output, mode: "check" })), /stale/);

    const cli = join(root, "scripts/export_course_packages.mjs");
    await assert.rejects(execFileAsync(process.execPath, [cli, "--write", "--check"]), /exactly one/);
    await assert.rejects(execFileAsync(process.execPath, [cli, "--output"]), /requires a directory/);
    await assert.rejects(execFileAsync(process.execPath, [cli, "--unknown"]), /Unknown argument/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("source mutations fail closed and a failed write preserves the last valid output", async () => {
  const temporary = await temporaryDirectory("wordloop-export-mutation-");
  const mutationRoot = join(temporary, "repository");
  try {
    await Promise.all([
      cp(join(root, "app"), join(mutationRoot, "app"), { recursive: true }),
      cp(join(root, "public"), join(mutationRoot, "public"), { recursive: true }),
      cp(join(root, "content/schema"), join(mutationRoot, "content/schema"), { recursive: true }),
    ]);
    const coursesPath = join(mutationRoot, "app/courses.ts");
    const originalCourses = await readFile(coursesPath, "utf8");
    const output = join(temporary, "dist");
    await withSourceDateEpoch(() => generateCoursePackages({ root: mutationRoot, output, mode: "write" }));
    const goodDigest = await digestGeneratedTree(output);

    const sourceAudio = join(mutationRoot, "public/audio/abandon.m4a");
    const replacementAudio = join(mutationRoot, "public/audio/abstract.m4a");
    const originalAudio = await readFile(sourceAudio);
    await withSourceDateEpoch(() => generateCoursePackages({
      root: mutationRoot,
      output,
      mode: "write",
      hooks: {
        afterBuild: async () => cp(replacementAudio, sourceAudio),
      },
    }));
    assert.deepEqual(await digestGeneratedTree(output), goodDigest, "materialize writes the bytes that were already hashed");
    await writeFile(sourceAudio, originalAudio);

    await assert.rejects(withSourceDateEpoch(() => generateCoursePackages({
      root: mutationRoot,
      output,
      mode: "write",
      hooks: {
        afterMaterialize: async ({ temporary: generated }) => cp(replacementAudio, join(generated, "courses/ielts-high-frequency/1/audio/abandon.m4a")),
      },
    })), /integrity mismatch/);
    assert.deepEqual(await digestGeneratedTree(output), goodDigest, "failed temporary verification preserves the last valid output");

    await assert.rejects(withSourceDateEpoch(() => generateCoursePackages({
      root: mutationRoot,
      output,
      mode: "write",
      hooks: {
        afterMaterialize: async ({ temporary: generated }) => cp(replacementAudio, join(generated, "courses/ielts-high-frequency/1/audio/undeclared.m4a")),
      },
    })), /file set mismatch/);
    assert.deepEqual(await digestGeneratedTree(output), goodDigest, "an undeclared generated file cannot replace the last valid output");

    const duplicateCollection = originalCourses.replace('{ id: "ielts", label:', '{ id: "modern-family-s01", label:');
    await writeFile(coursesPath, duplicateCollection);
    await assert.rejects(loadCourseSources(mutationRoot), /Duplicate collection ID/);
    await assert.rejects(withSourceDateEpoch(() => generateCoursePackages({ root: mutationRoot, output, mode: "write" })), /Duplicate collection ID/);
    assert.deepEqual(await digestGeneratedTree(output), goodDigest);
    await writeFile(coursesPath, originalCourses);

    const orphanPath = join(mutationRoot, "app/data/orphan-course.json");
    await writeFile(orphanPath, '{"courseId":"orphan","entries":[]}\n');
    await assert.rejects(loadCourseSources(mutationRoot), /Unregistered course manifests/);
    await rm(orphanPath);

    const audioPath = sourceAudio;
    const movedAudioPath = `${audioPath}.missing`;
    await rename(audioPath, movedAudioPath);
    await assert.rejects(loadCourseSources(mutationRoot), /audio mismatch/);
    await rename(movedAudioPath, audioPath);

    const extraAudioPath = join(mutationRoot, "public/audio/orphan.m4a");
    await cp(audioPath, extraAudioPath);
    await assert.rejects(loadCourseSources(mutationRoot), /extra=1/);
    await rm(extraAudioPath);

    const realAudioPath = `${audioPath}.real`;
    await rename(audioPath, realAudioPath);
    await symlink(basename(realAudioPath), audioPath);
    await assert.rejects(loadCourseSources(mutationRoot), /audio mismatch/);
    await rm(audioPath);
    await rename(realAudioPath, audioPath);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
