import { readFile, readdir } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import ts from "typescript";

function sourceFile(source, filename) {
  return ts.createSourceFile(filename, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
}

function unwrap(expression) {
  let value = expression;
  while (value && (ts.isAsExpression(value) || ts.isSatisfiesExpression(value) || ts.isParenthesizedExpression(value))) {
    value = value.expression;
  }
  return value;
}

function variableDeclaration(file, name) {
  let result;
  function visit(node) {
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.name.text === name) result = node;
    if (!result) ts.forEachChild(node, visit);
  }
  visit(file);
  if (!result) throw new Error(`Missing variable declaration: ${name}`);
  return result;
}

function arrayInitializer(declaration) {
  const value = unwrap(declaration.initializer);
  if (!value || !ts.isArrayLiteralExpression(value)) throw new Error(`Expected array initializer for ${declaration.name.getText()}`);
  return value;
}

function property(object, name) {
  return object.properties.find((item) => {
    if (!ts.isPropertyAssignment(item)) return false;
    return item.name.getText().replaceAll('"', "") === name;
  });
}

function stringProperty(object, name, lengths = new Map()) {
  const item = property(object, name);
  if (!item || !ts.isPropertyAssignment(item)) throw new Error(`Missing property: ${name}`);
  const value = unwrap(item.initializer);
  if (ts.isStringLiteralLike(value)) return value.text;
  if (ts.isTemplateExpression(value)) {
    let output = value.head.text;
    for (const span of value.templateSpans) {
      const expression = span.expression;
      if (!ts.isPropertyAccessExpression(expression) || expression.name.text !== "length" || !ts.isIdentifier(expression.expression)) {
        throw new Error(`Unsupported template expression for ${name}: ${expression.getText()}`);
      }
      const length = lengths.get(expression.expression.text);
      if (length === undefined) throw new Error(`Unknown entry count in ${name}: ${expression.expression.text}`);
      output += `${length}${span.literal.text}`;
    }
    return output;
  }
  throw new Error(`Expected string property: ${name}`);
}

function identifierProperty(object, name) {
  const item = property(object, name);
  const value = item && ts.isPropertyAssignment(item) ? unwrap(item.initializer) : undefined;
  if (!value || !ts.isIdentifier(value)) throw new Error(`Expected identifier property: ${name}`);
  return value.text;
}

function imports(file) {
  const defaults = new Map();
  const named = new Map();
  for (const statement of file.statements) {
    if (!ts.isImportDeclaration(statement) || !ts.isStringLiteral(statement.moduleSpecifier)) continue;
    const specifier = statement.moduleSpecifier.text;
    if (statement.importClause?.name) defaults.set(statement.importClause.name.text, specifier);
    const bindings = statement.importClause?.namedBindings;
    if (bindings && ts.isNamedImports(bindings)) {
      for (const element of bindings.elements) named.set(element.name.text, specifier);
    }
  }
  return { defaults, named };
}

function entrySource(declaration) {
  let manifestIdentifier;
  let highlightIdentifier;
  let audioPrefix;
  function visit(node) {
    if (!manifestIdentifier && ts.isPropertyAccessExpression(node) && node.name.text === "entries" && ts.isIdentifier(node.expression)) {
      manifestIdentifier = node.expression.text;
    }
    if (!highlightIdentifier && ts.isElementAccessExpression(node) && ts.isIdentifier(node.expression)) {
      const argument = node.argumentExpression;
      if (argument && ts.isPropertyAccessExpression(argument) && ts.isIdentifier(argument.expression) && argument.expression.text === "entry" && argument.name.text === "id") {
        highlightIdentifier = node.expression.text;
      }
    }
    if (!audioPrefix && ts.isTemplateExpression(node)) {
      const raw = node.getText();
      const match = raw.match(/\$\{basePath\}(\/courses\/[^$`]+\/)\$\{entry\.audio\}/);
      if (match) audioPrefix = match[1];
    }
    ts.forEachChild(node, visit);
  }
  visit(declaration);
  return { manifestIdentifier, highlightIdentifier, audioPrefix };
}

function objectLiteralValue(node) {
  const value = unwrap(node);
  if (!value || !ts.isObjectLiteralExpression(value)) throw new Error("Expected object literal");
  const result = {};
  for (const item of value.properties) {
    if (!ts.isPropertyAssignment(item)) continue;
    const key = ts.isStringLiteralLike(item.name) ? item.name.text : item.name.getText();
    if (Object.hasOwn(result, key)) throw new Error(`Duplicate highlight entry ID: ${key}`);
    const initializer = unwrap(item.initializer);
    if (!initializer || !ts.isArrayLiteralExpression(initializer)) throw new Error(`Expected string array for ${key}`);
    result[key] = initializer.elements.map((element) => {
      if (!ts.isStringLiteralLike(element)) throw new Error(`Expected string highlight for ${key}`);
      return element.text;
    });
  }
  return result;
}

async function readHighlights(root, relativePath) {
  if (!relativePath) return {};
  const path = join(root, "app", relativePath.replace(/^\.\//, ""));
  const source = await readFile(path, "utf8");
  const file = sourceFile(source, path);
  const declaration = file.statements
    .flatMap((statement) => ts.isVariableStatement(statement) ? [...statement.declarationList.declarations] : [])
    .find((item) => item.initializer);
  if (!declaration?.initializer) throw new Error(`Missing highlights object: ${relative(root, path)}`);
  return objectLiteralValue(declaration.initializer);
}

function wordTuples(wordsSource) {
  const file = sourceFile(wordsSource, "app/words.ts");
  return arrayInitializer(variableDeclaration(file, "WORDS")).elements.map((element) => {
    const tuple = unwrap(element);
    if (!tuple || !ts.isArrayLiteralExpression(tuple) || tuple.elements.length < 4) throw new Error("Invalid WORDS tuple");
    const [word, translation, , phonetic] = tuple.elements;
    if (![word, translation, phonetic].every(ts.isStringLiteralLike)) throw new Error("WORDS tuple must contain strings");
    return { id: word.text, text: word.text, translation: translation.text, phonetic: phonetic.text };
  });
}

async function manifestFiles(root) {
  const directory = join(root, "app/data");
  const names = (await readdir(directory)).filter((name) => name.endsWith(".json")).sort();
  const manifests = [];
  for (const name of names) {
    const path = join(directory, name);
    const value = JSON.parse(await readFile(path, "utf8"));
    if (Array.isArray(value.entries)) manifests.push(path);
  }
  return manifests;
}

async function assertExactAudioSet(directory, expectedPaths, label) {
  const entries = await readdir(directory, { withFileTypes: true });
  const actual = entries.filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".m4a")).map((entry) => resolve(directory, entry.name));
  const expected = expectedPaths.map((path) => resolve(path));
  assertUnique(expected, `${label} audio reference`);
  const expectedSet = new Set(expected);
  const actualSet = new Set(actual);
  const missing = expected.filter((path) => !actualSet.has(path));
  const extra = actual.filter((path) => !expectedSet.has(path));
  if (missing.length || extra.length) throw new Error(`${label} audio mismatch: missing=${missing.length}, extra=${extra.length}`);
}

function assertUnique(values, label) {
  const seen = new Set();
  const duplicates = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicates.add(value);
    else seen.add(value);
  }
  if (duplicates.size) throw new Error(`Duplicate ${label}: ${[...duplicates].join(", ")}`);
}

export async function loadCourseSources(root, { courseIds, defaultCourseId: requestedDefaultCourseId } = {}) {
  const [coursesSource, wordsSource] = await Promise.all([
    readFile(join(root, "app/courses.ts"), "utf8"),
    readFile(join(root, "app/words.ts"), "utf8"),
  ]);
  const file = sourceFile(coursesSource, "app/courses.ts");
  const imported = imports(file);

  const collections = arrayInitializer(variableDeclaration(file, "COURSE_COLLECTIONS")).elements.map((element) => {
    const object = unwrap(element);
    if (!object || !ts.isObjectLiteralExpression(object)) throw new Error("COURSE_COLLECTIONS must contain object literals");
    return {
      id: stringProperty(object, "id"),
      label: stringProperty(object, "label"),
      title: stringProperty(object, "title"),
      subtitle: stringProperty(object, "subtitle"),
    };
  });
  assertUnique(collections.map((collection) => collection.id), "collection ID");
  const collectionIds = new Set(collections.map((collection) => collection.id));

  const packageObjects = arrayInitializer(variableDeclaration(file, "COURSE_PACKAGES")).elements.map((element) => {
    const object = unwrap(element);
    if (!object || !ts.isObjectLiteralExpression(object)) throw new Error("COURSE_PACKAGES must contain object literals");
    return object;
  });
  const packageBasics = packageObjects.map((object) => ({
    id: stringProperty(object, "id"),
    entriesVariable: identifierProperty(object, "entries"),
  }));
  assertUnique(packageBasics.map((course) => course.id), "course ID");

  const aliases = new Map();
  for (const statement of file.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      const initializer = unwrap(declaration.initializer);
      if (!ts.isIdentifier(declaration.name) || !initializer || !ts.isElementAccessExpression(initializer)) continue;
      if (ts.isIdentifier(initializer.expression) && initializer.expression.text === "COURSE_PACKAGES" && ts.isNumericLiteral(initializer.argumentExpression)) {
        aliases.set(declaration.name.text, Number(initializer.argumentExpression.text));
      }
    }
  }
  const defaultInitializer = unwrap(variableDeclaration(file, "DEFAULT_COURSE").initializer);
  if (!defaultInitializer || !ts.isIdentifier(defaultInitializer) || !aliases.has(defaultInitializer.text)) throw new Error("Cannot resolve DEFAULT_COURSE");
  const defaultCourseId = packageBasics[aliases.get(defaultInitializer.text)]?.id;
  if (!defaultCourseId) throw new Error("DEFAULT_COURSE points outside COURSE_PACKAGES");

  const words = wordTuples(wordsSource);
  assertUnique(words.map((word) => word.id), "word ID");
  const entryLengths = new Map([["ieltsEntries", words.length]]);
  const sourceByEntries = new Map();
  for (const basic of packageBasics.filter((course) => course.entriesVariable !== "ieltsEntries")) {
    const source = entrySource(variableDeclaration(file, basic.entriesVariable));
    const manifestSpecifier = source.manifestIdentifier ? imported.defaults.get(source.manifestIdentifier) : undefined;
    if (!manifestSpecifier?.endsWith(".json") || !source.audioPrefix) throw new Error(`Cannot resolve source for ${basic.entriesVariable}`);
    const manifestPath = join(root, "app", manifestSpecifier.replace(/^\.\//, ""));
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const entries = manifest.entries.filter((entry) => entry.learnable === true && typeof entry.audio === "string");
    entryLengths.set(basic.entriesVariable, entries.length);
    const highlightSpecifier = source.highlightIdentifier ? imported.named.get(source.highlightIdentifier) : undefined;
    const highlights = await readHighlights(root, highlightSpecifier ? `${highlightSpecifier}.ts` : undefined);
    sourceByEntries.set(basic.entriesVariable, { manifestPath, manifest, entries, highlights, audioPrefix: source.audioPrefix });
  }

  const courses = packageObjects.map((object, index) => {
    const basic = packageBasics[index];
    const course = {
      id: basic.id,
      collectionId: stringProperty(object, "collectionId"),
      title: stringProperty(object, "title"),
      subtitle: stringProperty(object, "subtitle", entryLengths),
      description: stringProperty(object, "description"),
      kind: stringProperty(object, "kind"),
      practiceOrder: stringProperty(object, "practiceOrder"),
      entriesVariable: basic.entriesVariable,
    };
    if (!collectionIds.has(course.collectionId)) throw new Error(`${course.id} references unknown collection ${course.collectionId}`);
    if (course.kind === "word") {
      course.sourceManifestId = null;
      course.entries = words.map((word) => ({ ...word, audioSource: join(root, "public/audio", `${word.id}.m4a`) }));
    } else {
      const source = sourceByEntries.get(course.entriesVariable);
      if (!source) throw new Error(`Missing entry source for ${course.id}`);
      course.sourceManifestId = source.manifest.courseId ?? null;
      course.sourceManifest = relative(root, source.manifestPath);
      const learnableIds = new Set(source.entries.map((entry) => entry.id));
      course.ignoredHighlightIds = Object.keys(source.highlights).filter((id) => !learnableIds.has(id)).sort();
      course.entries = source.entries.map((entry) => ({
        id: entry.id,
        text: entry.text,
        translation: entry.translation,
        highlights: source.highlights[entry.id] ?? [],
        durationMilliseconds: Math.round(Number(entry.duration) * 1000),
        audioSource: join(root, "public", source.audioPrefix.replace(/^\//, ""), entry.audio.replace(/^\/+/, "")),
      }));
    }
    assertUnique(course.entries.map((entry) => entry.id), `${course.id} entry ID`);
    return course;
  });

  const registeredManifests = new Set([...sourceByEntries.values()].map((source) => resolve(source.manifestPath)));
  const unregistered = (await manifestFiles(root)).filter((path) => !registeredManifests.has(resolve(path)));
  if (unregistered.length) throw new Error(`Unregistered course manifests: ${unregistered.map((path) => relative(root, path)).join(", ")}`);
  for (const course of courses) {
    const directory = dirname(course.entries[0]?.audioSource ?? "");
    if (!directory) throw new Error(`${course.id} has no entries`);
    await assertExactAudioSet(directory, course.entries.map((entry) => entry.audioSource), course.id);
  }
  if (!courseIds) return { collections, courses, words, defaultCourseId };

  assertUnique(courseIds, "selected course ID");
  const selectedIDs = new Set(courseIds);
  const selectedCourses = courses.filter((course) => selectedIDs.has(course.id));
  const missing = courseIds.filter((id) => !selectedCourses.some((course) => course.id === id));
  if (missing.length) throw new Error(`Selected courses are not registered: ${missing.join(", ")}`);
  if (selectedCourses.length !== courseIds.length) throw new Error("Selected course count mismatch");
  const selectedCollectionIDs = new Set(selectedCourses.map((course) => course.collectionId));
  const selectedCollections = collections.filter((collection) => selectedCollectionIDs.has(collection.id));
  const selectedDefaultCourseId = requestedDefaultCourseId ?? defaultCourseId;
  if (!selectedIDs.has(selectedDefaultCourseId)) throw new Error(`Selected default course is not in the release: ${selectedDefaultCourseId}`);
  return { collections: selectedCollections, courses: selectedCourses, words, defaultCourseId: selectedDefaultCourseId };
}
