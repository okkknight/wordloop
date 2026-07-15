import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { lstat, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { basename, dirname, join, relative, resolve } from "node:path";
import { promisify } from "node:util";
import { createContractValidator } from "./contract.mjs";
import { loadCourseSources } from "./source.mjs";

const execFileAsync = promisify(execFile);

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function json(value) {
  return Buffer.from(`${JSON.stringify(value, null, 2)}\n`);
}

async function generatedAt(root) {
  if (process.env.SOURCE_DATE_EPOCH !== undefined) {
    const seconds = Number(process.env.SOURCE_DATE_EPOCH);
    if (!Number.isInteger(seconds) || seconds < 0) throw new Error("SOURCE_DATE_EPOCH must be a non-negative integer");
    return new Date(seconds * 1000).toISOString().replace(".000Z", "Z");
  }
  const { stdout } = await execFileAsync("git", ["log", "-1", "--format=%cI"], { cwd: root });
  const value = new Date(stdout.trim());
  if (Number.isNaN(value.valueOf())) throw new Error("Cannot derive generatedAt from Git HEAD");
  return value.toISOString().replace(".000Z", "Z");
}

function m4aDurationMilliseconds(bytes, path) {
  const marker = bytes.indexOf(Buffer.from("mvhd"));
  if (marker < 4 || bytes.subarray(4, 8).toString("ascii") !== "ftyp") throw new Error(`Unrecognized M4A container: ${path}`);
  const version = bytes[marker + 4];
  let timescale;
  let duration;
  if (version === 0) {
    timescale = bytes.readUInt32BE(marker + 16);
    duration = bytes.readUInt32BE(marker + 20);
  } else if (version === 1) {
    timescale = bytes.readUInt32BE(marker + 24);
    duration = Number(bytes.readBigUInt64BE(marker + 28));
  } else {
    throw new Error(`Unsupported M4A mvhd version ${version}: ${path}`);
  }
  if (!timescale || !duration) throw new Error(`Invalid M4A duration: ${path}`);
  return Math.max(1, Math.round(duration / timescale * 1000));
}

async function audioFile(sourcePath, packagePath) {
  const info = await lstat(sourcePath);
  if (info.isSymbolicLink()) throw new Error(`Audio source must not be a symlink: ${sourcePath}`);
  if (!info.isFile() || info.size <= 0) throw new Error(`Audio source is missing or empty: ${sourcePath}`);
  const bytes = await readFile(sourcePath);
  return {
    packagePath,
    sourcePath,
    bytes,
    durationMilliseconds: m4aDurationMilliseconds(bytes, sourcePath),
    integrity: { path: packagePath, bytes: bytes.length, sha256: sha256(bytes) },
  };
}

async function packageForCourse(source) {
  const audios = [];
  for (const entry of source.entries) {
    const packagePath = `audio/${basename(entry.audioSource)}`;
    audios.push(await audioFile(entry.audioSource, packagePath));
  }
  const audioPaths = audios.map((audio) => audio.packagePath);
  if (new Set(audioPaths).size !== audioPaths.length) throw new Error(`${source.id} contains duplicate audio package paths`);
  const course = {
    schemaVersion: 1,
    id: source.id,
    collectionId: source.collectionId,
    contentVersion: 1,
    title: source.title,
    subtitle: source.subtitle,
    description: source.description,
    kind: source.kind,
    practiceOrder: source.practiceOrder,
    entries: source.entries.map((entry, index) => {
      const output = {
        id: entry.id,
        text: entry.text,
        translation: entry.translation,
      };
      if (entry.phonetic) output.phonetic = entry.phonetic;
      if (entry.highlights?.length) output.highlights = entry.highlights;
      output.audio = audios[index].packagePath;
      output.durationMilliseconds = source.kind === "word" ? audios[index].durationMilliseconds : entry.durationMilliseconds;
      if (!Number.isInteger(output.durationMilliseconds) || output.durationMilliseconds <= 0) {
        throw new Error(`${source.id}/${entry.id} has invalid duration`);
      }
      return output;
    }),
  };
  const courseBytes = json(course);
  const integrity = {
    schemaVersion: 1,
    courseId: course.id,
    contentVersion: course.contentVersion,
    files: [
      { path: "course.json", bytes: courseBytes.length, sha256: sha256(courseBytes) },
      ...audios.map((audio) => audio.integrity),
    ],
  };
  const integrityBytes = json(integrity);
  return { source, course, courseBytes, integrity, integrityBytes, audios };
}

async function build(root) {
  const sources = await loadCourseSources(root);
  const packages = [];
  for (const source of sources.courses) packages.push(await packageForCourse(source));
  const timestamp = await generatedAt(root);
  const catalog = {
    schemaVersion: 1,
    generatedAt: timestamp,
    defaultCourseId: sources.defaultCourseId,
    collections: sources.collections,
    courses: packages.map((item) => ({
      id: item.course.id,
      collectionId: item.course.collectionId,
      title: item.course.title,
      subtitle: item.course.subtitle,
      description: item.course.description,
      kind: item.course.kind,
      practiceOrder: item.course.practiceOrder,
      contentVersion: item.course.contentVersion,
      minimumAppVersion: "1.0.0",
      manifestURL: `courses/${item.course.id}/${item.course.contentVersion}/course.json`,
      manifestSHA256: sha256(item.courseBytes),
      downloadSize: item.courseBytes.length + item.integrityBytes.length + item.audios.reduce((sum, audio) => sum + audio.bytes.length, 0),
      status: "available",
    })),
  };
  const validationReport = {
    schemaVersion: 1,
    generatedAt: timestamp,
    counts: {
      collections: sources.collections.length,
      courses: packages.length,
      wordEntries: packages.filter((item) => item.course.kind === "word").reduce((sum, item) => sum + item.course.entries.length, 0),
      sentenceEntries: packages.filter((item) => item.course.kind === "sentence").reduce((sum, item) => sum + item.course.entries.length, 0),
      audioFiles: packages.reduce((sum, item) => sum + item.audios.length, 0),
      audioBytes: packages.reduce((sum, item) => sum + item.audios.reduce((audioSum, audio) => audioSum + audio.bytes.length, 0), 0),
    },
    sourceIdDifferences: packages
      .filter((item) => item.source.sourceManifestId && item.source.sourceManifestId !== item.course.id)
      .map((item) => ({ courseId: item.course.id, sourceManifestId: item.source.sourceManifestId, source: item.source.sourceManifest })),
    ignoredHighlights: packages
      .filter((item) => item.source.ignoredHighlightIds?.length)
      .map((item) => ({ courseId: item.course.id, entryIds: item.source.ignoredHighlightIds })),
  };
  const validator = await createContractValidator(root);
  validator.validatePackage(catalog, packages);
  return { catalog, catalogBytes: json(catalog), validationReport, validationReportBytes: json(validationReport), packages };
}

async function materialize(result, directory) {
  await mkdir(directory, { recursive: true });
  await writeFile(join(directory, "catalog.json"), result.catalogBytes);
  await writeFile(join(directory, "validation-report.json"), result.validationReportBytes);
  for (const item of result.packages) {
    const courseDirectory = join(directory, "courses", item.course.id, String(item.course.contentVersion));
    await mkdir(courseDirectory, { recursive: true });
    await writeFile(join(courseDirectory, "course.json"), item.courseBytes);
    await writeFile(join(courseDirectory, "integrity.json"), item.integrityBytes);
    for (const audio of item.audios) {
      const target = join(courseDirectory, audio.packagePath);
      await mkdir(dirname(target), { recursive: true });
      await writeFile(target, audio.bytes);
    }
  }
}

async function verifyMaterialized(result, directory) {
  const expected = new Map([
    ["catalog.json", { bytes: result.catalogBytes.length, sha256: sha256(result.catalogBytes) }],
    ["validation-report.json", { bytes: result.validationReportBytes.length, sha256: sha256(result.validationReportBytes) }],
  ]);
  for (const item of result.packages) {
    const prefix = `courses/${item.course.id}/${item.course.contentVersion}`;
    expected.set(`${prefix}/course.json`, { bytes: item.courseBytes.length, sha256: sha256(item.courseBytes) });
    expected.set(`${prefix}/integrity.json`, { bytes: item.integrityBytes.length, sha256: sha256(item.integrityBytes) });
    for (const audio of item.audios) expected.set(`${prefix}/${audio.packagePath}`, audio.integrity);
  }
  const actualPaths = [];
  async function visit(current) {
    const entries = await readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const path = join(current, entry.name);
      const info = await lstat(path);
      if (info.isSymbolicLink()) throw new Error(`Generated package contains symlink: ${path}`);
      if (info.isDirectory()) await visit(path);
      else if (info.isFile()) actualPaths.push(relative(directory, path));
      else throw new Error(`Generated package contains unsupported entry: ${path}`);
    }
  }
  await visit(directory);
  const expectedPaths = [...expected.keys()].sort();
  actualPaths.sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    throw new Error("Generated package file set mismatch");
  }
  for (const [path, integrity] of expected) {
    const bytes = await readFile(join(directory, path));
    if (bytes.length !== integrity.bytes || sha256(bytes) !== integrity.sha256) {
      throw new Error(`Generated package integrity mismatch: ${path}`);
    }
  }
}

async function treeDigest(directory) {
  const files = [];
  async function visit(current) {
    const entries = await readdir(current, { withFileTypes: true });
    for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
      const path = join(current, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`Generated output contains symlink: ${path}`);
      if (entry.isDirectory()) await visit(path);
      else if (entry.isFile()) files.push(path);
      else throw new Error(`Unsupported generated output entry: ${path}`);
    }
  }
  await visit(directory);
  const entries = [];
  for (const path of files) entries.push(`${relative(directory, path)} ${sha256(await readFile(path))}`);
  return { files: entries, sha256: sha256(Buffer.from(`${entries.join("\n")}\n`)) };
}

export async function generateCoursePackages({ root, output, mode, hooks = {} }) {
  const target = resolve(output);
  const temporary = `${target}.tmp-${process.pid}-${Date.now()}`;
  await rm(temporary, { recursive: true, force: true });
  try {
    const result = await build(root);
    await hooks.afterBuild?.({ temporary, result });
    await materialize(result, temporary);
    await hooks.afterMaterialize?.({ temporary, result });
    await verifyMaterialized(result, temporary);
    const generatedDigest = await treeDigest(temporary);
    if (mode === "check") {
      let currentDigest;
      try {
        currentDigest = await treeDigest(target);
      } catch (error) {
        if (error.code === "ENOENT") throw new Error(`Generated content is missing: ${target}`);
        throw error;
      }
      if (JSON.stringify(currentDigest) !== JSON.stringify(generatedDigest)) throw new Error(`Generated content is stale: ${target}`);
      return { ...result.validationReport, tree: { files: generatedDigest.files.length, sha256: generatedDigest.sha256 } };
    }
    const backup = `${target}.backup-${process.pid}`;
    await rm(backup, { recursive: true, force: true });
    let hadTarget = false;
    try {
      await rename(target, backup);
      hadTarget = true;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    try {
      await mkdir(dirname(target), { recursive: true });
      await rename(temporary, target);
      if (hadTarget) await rm(backup, { recursive: true, force: true });
    } catch (error) {
      if (hadTarget) await rename(backup, target).catch(() => {});
      throw error;
    }
    return { ...result.validationReport, tree: { files: generatedDigest.files.length, sha256: generatedDigest.sha256 } };
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

export async function digestGeneratedTree(directory) {
  return treeDigest(directory);
}
