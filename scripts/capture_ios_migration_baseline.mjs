import { createHash } from "node:crypto";
import { readFile, readdir, stat, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const root = resolve(process.env.WORDLOOP_BASELINE_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), ".."));
const outputPath = join(root, "docs/ios-migration/baseline/content-inventory.json");

async function read(relativePath) {
  return readFile(join(root, relativePath), "utf8");
}

async function listFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? listFiles(path) : [path];
  }));
  return nested.flat().sort();
}

function lineNumber(source, marker) {
  const index = source.indexOf(marker);
  if (index < 0) throw new Error(`Missing source marker: ${marker}`);
  return source.slice(0, index).split("\n").length;
}

function stringUnion(source, typeName) {
  const match = source.match(new RegExp(`type ${typeName} =([\\s\\S]*?);`));
  if (!match) throw new Error(`Missing type union: ${typeName}`);
  return [...match[1].matchAll(/"([^"]+)"/g)].map((item) => item[1]);
}

function switchReturns(source, functionName) {
  const start = source.indexOf(`function ${functionName}`);
  if (start < 0) throw new Error(`Missing function: ${functionName}`);
  const end = source.indexOf("\n}\n", start);
  const body = source.slice(start, end + 2);
  const values = {};
  for (const match of body.matchAll(/case "([^"]+)":\s*return "([^"]+)";/g)) {
    values[match[1]] = match[2];
  }
  const fallback = body.match(/default:\s*return "([^"]+)";/)?.[1];
  return { values, fallback };
}

function numericConstant(source, name) {
  const match = source.match(new RegExp(`const ${name} = ([0-9_\\.]+);`));
  if (!match) throw new Error(`Missing numeric constant: ${name}`);
  return Number(match[1].replaceAll("_", ""));
}

function sourceFile(source, filename) {
  return ts.createSourceFile(filename, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
}

function variableDeclaration(file, name) {
  let match;
  function visit(node) {
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.name.text === name) match = node;
    if (!match) ts.forEachChild(node, visit);
  }
  visit(file);
  if (!match) throw new Error(`Missing variable declaration: ${name}`);
  return match;
}

function arrayInitializer(declaration) {
  let value = declaration.initializer;
  while (value && (ts.isAsExpression(value) || ts.isSatisfiesExpression(value) || ts.isParenthesizedExpression(value))) {
    value = value.expression;
  }
  if (!value || !ts.isArrayLiteralExpression(value)) throw new Error(`Expected array initializer for ${declaration.name.getText()}`);
  return value;
}

function objectString(object, propertyName) {
  const property = object.properties.find((item) => ts.isPropertyAssignment(item) && item.name.getText().replaceAll('"', "") === propertyName);
  if (!property || !ts.isPropertyAssignment(property) || !ts.isStringLiteralLike(property.initializer)) {
    throw new Error(`Expected string property ${propertyName}`);
  }
  return property.initializer.text;
}

function objectIdentifier(object, propertyName) {
  const property = object.properties.find((item) => ts.isPropertyAssignment(item) && item.name.getText().replaceAll('"', "") === propertyName);
  if (!property || !ts.isPropertyAssignment(property) || !ts.isIdentifier(property.initializer)) {
    throw new Error(`Expected identifier property ${propertyName}`);
  }
  return property.initializer.text;
}

function firstEntriesOwner(node) {
  let owner;
  function visit(child) {
    if (ts.isPropertyAccessExpression(child) && child.name.text === "entries" && ts.isIdentifier(child.expression)) owner ??= child.expression.text;
    if (!owner) ts.forEachChild(child, visit);
  }
  visit(node);
  return owner;
}

function courseRegistry(coursesSource, pageSource) {
  const file = sourceFile(coursesSource, "app/courses.ts");
  const imports = new Map();
  for (const statement of file.statements) {
    if (ts.isImportDeclaration(statement) && statement.importClause?.name && ts.isStringLiteral(statement.moduleSpecifier)) {
      imports.set(statement.importClause.name.text, statement.moduleSpecifier.text);
    }
  }

  const packages = arrayInitializer(variableDeclaration(file, "COURSE_PACKAGES")).elements.map((element) => {
    if (!ts.isObjectLiteralExpression(element)) throw new Error("COURSE_PACKAGES must contain object literals");
    const entriesVariable = objectIdentifier(element, "entries");
    let manifest = null;
    if (entriesVariable !== "ieltsEntries") {
      const owner = firstEntriesOwner(variableDeclaration(file, entriesVariable));
      const importPath = owner ? imports.get(owner) : undefined;
      if (!importPath?.endsWith(".json")) throw new Error(`Cannot resolve manifest for ${entriesVariable}`);
      manifest = `app/${importPath.replace(/^\.\//, "")}`;
    }
    return {
      id: objectString(element, "id"),
      collectionId: objectString(element, "collectionId"),
      title: objectString(element, "title"),
      kind: objectString(element, "kind"),
      practiceOrder: objectString(element, "practiceOrder"),
      entriesVariable,
      manifest,
    };
  });

  const aliases = new Map();
  for (const statement of file.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      if (!ts.isIdentifier(declaration.name) || !declaration.initializer || !ts.isElementAccessExpression(declaration.initializer)) continue;
      const target = declaration.initializer.expression;
      const index = declaration.initializer.argumentExpression;
      if (ts.isIdentifier(target) && target.text === "COURSE_PACKAGES" && ts.isNumericLiteral(index)) {
        aliases.set(declaration.name.text, Number(index.text));
      }
    }
  }
  const defaultDeclaration = variableDeclaration(file, "DEFAULT_COURSE");
  if (!defaultDeclaration.initializer || !ts.isIdentifier(defaultDeclaration.initializer)) throw new Error("DEFAULT_COURSE must reference a package alias");
  const defaultIndex = aliases.get(defaultDeclaration.initializer.text);
  if (defaultIndex === undefined || !packages[defaultIndex]) throw new Error("Cannot resolve DEFAULT_COURSE");

  const collections = arrayInitializer(variableDeclaration(file, "COURSE_COLLECTIONS")).elements.map((element) => {
    if (!ts.isObjectLiteralExpression(element)) throw new Error("COURSE_COLLECTIONS must contain object literals");
    return {
      id: objectString(element, "id"),
      label: objectString(element, "label"),
      title: objectString(element, "title"),
      subtitle: objectString(element, "subtitle"),
    };
  });

  const pageFile = sourceFile(pageSource, "app/page.tsx");
  const studyModeDeclaration = (() => {
    let found;
    function visit(node) {
      if (ts.isVariableDeclaration(node) && ts.isArrayBindingPattern(node.name) && node.name.elements.some((item) => item.name.getText() === "studyMode")) found = node;
      if (!found) ts.forEachChild(node, visit);
    }
    visit(pageFile);
    return found;
  })();
  const modeArgument = studyModeDeclaration?.initializer && ts.isCallExpression(studyModeDeclaration.initializer)
    ? studyModeDeclaration.initializer.arguments[0]
    : undefined;
  if (!modeArgument || !ts.isStringLiteral(modeArgument)) throw new Error("Cannot resolve default study mode");

  return { packages, collections, defaultCourseId: packages[defaultIndex].id, defaultStudyMode: modeArgument.text };
}

function uniqueNumbers(values) {
  return [...new Set(values)].sort((left, right) => left - right);
}

function palettes(source) {
  const start = source.indexOf("const PALETTES = [");
  const end = source.indexOf("] as const;", start);
  if (start < 0 || end < 0) throw new Error("Missing PALETTES block");
  return [...source.slice(start, end).matchAll(/\["(#[0-9a-f]+)", "(#[0-9a-f]+)", "(#[0-9a-f]+)"\]/gi)]
    .map((match) => ({ background: match[1], ink: match[2], accent: match[3] }));
}

async function fileSummary(path) {
  const info = await stat(path);
  const bytes = await readFile(path);
  return {
    path: relative(root, path),
    bytes: info.size,
    sha256: createHash("sha256").update(bytes).digest("hex"),
  };
}

function sentenceAudioDirectory(courseFile) {
  const id = basename(courseFile, ".json");
  if (id.startsWith("modern-family-")) {
    return join(root, "public/courses/modern-family", id.replace("modern-family-", ""), "audio");
  }
  if (id.startsWith("voa-")) {
    return join(root, "public/courses/voa", id.replace("voa-", ""), "audio");
  }
  if (id.startsWith("ai-")) {
    return join(root, "public/courses/ai", id.replace("ai-", ""), "audio");
  }
  throw new Error(`Unknown sentence course path: ${id}`);
}

async function buildInventory() {
  const [pageSource, repeatScorerSource, coursesSource, wordsSource, cssSource] = await Promise.all([
    read("app/page.tsx"),
    read("app/repeat-scorer.ts"),
    read("app/courses.ts"),
    read("app/words.ts"),
    read("app/globals.css"),
  ]);
  const registry = courseRegistry(coursesSource, pageSource);

  const dataDirectory = join(root, "app/data");
  const jsonPaths = (await readdir(dataDirectory))
    .filter((name) => name.endsWith(".json"))
    .map((name) => join(dataDirectory, name))
    .sort();
  const allCourseManifestPaths = [];
  for (const path of jsonPaths) {
    const value = JSON.parse(await readFile(path, "utf8"));
    if (Array.isArray(value.entries)) allCourseManifestPaths.push(path);
  }
  const manifestPaths = registry.packages.filter((course) => course.manifest).map((course) => join(root, course.manifest));
  const registeredManifestSet = new Set(manifestPaths.map((path) => resolve(path)));
  const unregisteredManifests = allCourseManifestPaths.filter((path) => !registeredManifestSet.has(resolve(path)));
  if (unregisteredManifests.length) throw new Error(`Unregistered course manifests: ${unregisteredManifests.map((path) => relative(root, path)).join(", ")}`);

  const sentenceCourses = [];
  for (const registeredCourse of registry.packages.filter((course) => course.manifest)) {
    const manifestPath = join(root, registeredCourse.manifest);
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const entries = manifest.entries.filter((entry) => entry.learnable === true && typeof entry.audio === "string");
    const audioPaths = (await listFiles(sentenceAudioDirectory(manifestPath)))
      .filter((path) => extname(path).toLowerCase() === ".m4a");
    const audioDirectory = sentenceAudioDirectory(manifestPath);
    const referencedAudio = entries.map((entry) => resolve(audioDirectory, entry.audio.replace(/^audio\//, "")));
    const referencedSet = new Set(referencedAudio);
    const actualSet = new Set(audioPaths.map((path) => resolve(path)));
    const missingAudio = referencedAudio.filter((path) => !actualSet.has(path));
    const extraAudio = audioPaths.filter((path) => !referencedSet.has(resolve(path)));
    const entryIds = entries.map((entry) => entry.id);
    const duplicateEntryIds = entryIds.filter((id, index) => entryIds.indexOf(id) !== index);
    if (missingAudio.length || extraAudio.length || duplicateEntryIds.length || referencedSet.size !== referencedAudio.length) {
      throw new Error(`${registeredCourse.id}: audio/ID mismatch; missing=${missingAudio.length}, extra=${extraAudio.length}, duplicateIds=${duplicateEntryIds.length}, duplicateAudioRefs=${referencedAudio.length - referencedSet.size}`);
    }
    sentenceCourses.push({
      id: registeredCourse.id,
      collectionId: registeredCourse.collectionId,
      kind: registeredCourse.kind,
      practiceOrder: registeredCourse.practiceOrder,
      family: registeredCourse.id.startsWith("voa-") ? "voa" : registeredCourse.collectionId === "ai-practice" ? "ai" : "modern-family",
      manifest: relative(root, manifestPath),
      manifestCourseId: manifest.courseId ?? null,
      learnableEntries: entries.length,
      audioFiles: audioPaths.length,
      audioBytes: (await Promise.all(audioPaths.map((path) => stat(path)))).reduce((sum, info) => sum + info.size, 0),
    });
  }

  const wordAudioPaths = (await listFiles(join(root, "public/audio")))
    .filter((path) => extname(path).toLowerCase() === ".m4a");
  const allM4aPaths = (await listFiles(join(root, "public")))
    .filter((path) => extname(path).toLowerCase() === ".m4a");
  const words = [...wordsSource.matchAll(/^  \["([^"]+)"/gm)].map((match) => match[1]);
  const wordCount = words.length;
  const expectedWordAudio = new Set(words.map((word) => resolve(root, "public/audio", `${word}.m4a`)));
  const actualWordAudio = new Set(wordAudioPaths.map((path) => resolve(path)));
  const missingWordAudio = [...expectedWordAudio].filter((path) => !actualWordAudio.has(path));
  const extraWordAudio = wordAudioPaths.filter((path) => !expectedWordAudio.has(resolve(path)));
  if (missingWordAudio.length || extraWordAudio.length || new Set(words).size !== words.length) {
    throw new Error(`Word/audio mismatch; missing=${missingWordAudio.length}, extra=${extraWordAudio.length}, duplicateWords=${words.length - new Set(words).size}`);
  }
  const sentenceEntryCount = sentenceCourses.reduce((sum, course) => sum + course.learnableEntries, 0);
  const allM4aStats = await Promise.all(allM4aPaths.map((path) => stat(path)));
  const paletteValues = palettes(pageSource);

  const inventory = {
    schemaVersion: 1,
    sources: {
      page: { path: "app/page.tsx", stateDeclarationsStartLine: lineNumber(pageSource, "  const [wordIndex") },
      styles: { path: "app/globals.css", posterStartLine: lineNumber(cssSource, ".poster {") },
      courses: { path: "app/courses.ts", packagesStartLine: lineNumber(coursesSource, "export const COURSE_PACKAGES") },
      words: { path: "app/words.ts", tupleStartLine: lineNumber(wordsSource, "export const WORDS") },
    },
    counts: {
      collections: registry.collections.length,
      courses: registry.packages.length,
      wordCourses: registry.packages.filter((course) => course.kind === "word").length,
      sentenceCourses: sentenceCourses.length,
      modernFamilyCourses: sentenceCourses.filter((course) => course.family === "modern-family").length,
      voaCourses: sentenceCourses.filter((course) => course.family === "voa").length,
      words: wordCount,
      sentenceEntries: sentenceEntryCount,
      totalStudyEntries: wordCount + sentenceEntryCount,
      wordAudioFiles: wordAudioPaths.length,
      sentenceAudioFiles: allM4aPaths.length - wordAudioPaths.length,
      totalM4aFiles: allM4aPaths.length,
      totalM4aBytes: allM4aStats.reduce((sum, info) => sum + info.size, 0),
    },
    defaults: {
      courseId: registry.defaultCourseId,
      studyMode: registry.defaultStudyMode,
      maximumStudyCount: numericConstant(pageSource, "MAX_STUDY_COUNT"),
    },
    identity: {
      usernamePattern: "^[A-Za-z]+$",
      normalizedCase: "lowercase",
      namedUserPrefix: "name:",
      anonymousWhenEmpty: true,
      validationMessage: "用户名只能使用英文字母",
    },
    timingMilliseconds: {
      autoAdvance: numericConstant(pageSource, "AUTO_ADVANCE_MS"),
      listenAutoplayDelay: numericConstant(pageSource, "LISTEN_AUTOPLAY_DELAY_MS"),
      playbackTimeout: numericConstant(pageSource, "PLAYBACK_TIMEOUT_MS"),
      speakTimeout: numericConstant(pageSource, "SPEAK_TIMEOUT_MS"),
      speakingTimeout: numericConstant(pageSource, "SPEAKING_TIMEOUT_MS"),
      scoringTimeout: numericConstant(pageSource, "SCORING_TIMEOUT_MS"),
      minimumSpeech: numericConstant(pageSource, "MIN_SPEECH_MS"),
      segmentSettle: numericConstant(pageSource, "SEGMENT_SETTLE_MS"),
      startupMaximumWait: numericConstant(pageSource, "STARTUP_MAX_WAIT_MS"),
      panelClose: numericConstant(pageSource, "PANEL_CLOSE_MS"),
    },
    scoring: {
      passScore: numericConstant(repeatScorerSource, "REPEAT_PASS_SCORE"),
      minimumSentenceWordCoverage: numericConstant(repeatScorerSource, "MIN_SENTENCE_WORD_COVERAGE"),
    },
    stateTypes: {
      startup: stringUnion(pageSource, "StartupState"),
      repeat: stringUnion(pageSource, "RepeatState"),
      textVisibility: stringUnion(pageSource, "TextVisibilityMode"),
      studyMode: stringUnion(pageSource, "StudyMode"),
    },
    repeatCopy: {
      labels: switchReturns(pageSource, "repeatStatusLabel"),
      hints: switchReturns(pageSource, "repeatStatusHint"),
    },
    startupCopy: {
      idleAction: "START",
      restoringAction: "PREPARING…",
      syncingAction: "SYNCING…",
      restoringHint: "正在恢复上次课程",
      syncingHint: "正在同步学习进度",
    },
    retryDelayMilliseconds: uniqueNumbers([...pageSource.matchAll(/scheduleRepeatRetry\([^,]+,\s*([0-9_]+)/g)].map((match) => Number(match[1].replaceAll("_", "")))),
    hiddenPauseDelayMilliseconds: Number(pageSource.match(/hiddenPauseTimerRef\.current = window\.setTimeout\([\s\S]*?\},\s*([0-9_]+)\);/)?.[1].replaceAll("_", "") ?? NaN),
    palettes: paletteValues,
    collections: registry.collections,
    registeredCourses: registry.packages.map((course) => Object.fromEntries(
      Object.entries(course).filter(([key]) => key !== "entriesVariable"),
    )),
    sentenceCourses,
    representativeFiles: await Promise.all([
      join(root, "public/audio/abandon.m4a"),
      join(root, "public/courses/modern-family/s01e01/audio/s01e01-0003.m4a"),
      join(root, "public/courses/voa/workplace-conversations-b1/audio/voa-work-b1-001.m4a"),
    ].map(fileSummary)),
  };

  const expected = {
    collections: 4,
    courses: 67,
    words: 570,
    sentenceEntries: 1428,
    totalM4aFiles: 1998,
    palettes: 6,
  };
  for (const [key, value] of Object.entries(expected)) {
    const actual = key === "palettes" ? inventory.palettes.length : inventory.counts[key];
    if (actual !== value) throw new Error(`Baseline mismatch for ${key}: expected ${value}, received ${actual}`);
  }
  const courseIds = registry.packages.map((course) => course.id);
  if (new Set(courseIds).size !== courseIds.length) throw new Error("COURSE_PACKAGES contains duplicate course IDs");
  const collectionIds = new Set(registry.collections.map((collection) => collection.id));
  const unknownCollections = registry.packages.filter((course) => !collectionIds.has(course.collectionId));
  if (unknownCollections.length) throw new Error(`Courses reference unknown collections: ${unknownCollections.map((course) => course.id).join(", ")}`);
  for (const copy of Object.values(inventory.startupCopy)) {
    if (!pageSource.includes(copy)) throw new Error(`Missing startup copy in app/page.tsx: ${copy}`);
  }
  if (JSON.stringify(inventory.retryDelayMilliseconds) !== JSON.stringify([500, 850, 1000, 1200])) {
    throw new Error(`Unexpected repeat retry delays: ${inventory.retryDelayMilliseconds.join(", ")}`);
  }
  if (inventory.hiddenPauseDelayMilliseconds !== 1500) {
    throw new Error(`Unexpected hidden pause delay: ${inventory.hiddenPauseDelayMilliseconds}`);
  }
  for (const course of sentenceCourses) {
    if (course.learnableEntries !== course.audioFiles) {
      throw new Error(`${course.id}: ${course.learnableEntries} learnable entries but ${course.audioFiles} audio files`);
    }
  }
  return `${JSON.stringify(inventory, null, 2)}\n`;
}

const supportedArguments = new Set(["--write", "--check"]);
const argumentsPassed = process.argv.slice(2);
const unknownArguments = argumentsPassed.filter((argument) => !supportedArguments.has(argument));
if (unknownArguments.length) throw new Error(`Unknown arguments: ${unknownArguments.join(", ")}`);
if (argumentsPassed.includes("--write") && argumentsPassed.includes("--check")) throw new Error("Choose either --write or --check, not both");

const output = await buildInventory();
if (argumentsPassed.includes("--write")) {
  await writeFile(outputPath, output, "utf8");
  console.log(`Wrote ${relative(root, outputPath)}`);
} else if (argumentsPassed.includes("--check")) {
  const existing = await readFile(outputPath, "utf8");
  if (existing !== output) throw new Error(`Baseline is stale: run ${relative(root, import.meta.filename)} --write`);
  console.log("iOS migration content baseline is current");
} else {
  process.stdout.write(output);
}
