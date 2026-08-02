#!/usr/bin/env node
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadCourseSources } from "./lib/course-export/source.mjs";
import {
  APP_STORE_RELEASE_COURSE_IDS,
  APP_STORE_RELEASE_DEFAULT_COURSE_ID,
} from "./lib/course-export/app-store-release.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const requiredLocales = Object.freeze([
  "zh-Hans", "zh-Hant", "ja", "ko", "es", "pt-BR", "fr", "de", "it", "ru", "ar", "id", "th", "vi", "tr",
]);
const argumentsPassed = process.argv.slice(2);
const strict = argumentsPassed.includes("--strict");
if (argumentsPassed.some((argument) => argument !== "--strict")) {
  throw new Error("Usage: node scripts/check_mother_tongue_translations.mjs [--strict]");
}

const source = await loadCourseSources(root, {
  courseIds: APP_STORE_RELEASE_COURSE_IDS,
  defaultCourseId: APP_STORE_RELEASE_DEFAULT_COURSE_ID,
});
const totals = Object.fromEntries(requiredLocales.map((locale) => [locale, 0]));
const missing = [];
for (const course of source.courses) {
  for (const entry of course.entries) {
    for (const locale of requiredLocales) {
      const value = entry.translations?.[locale];
      if (typeof value === "string" && value.trim()) totals[locale] += 1;
      else missing.push({ course: course.id, entry: entry.id, locale });
    }
  }
}

const report = {
  releaseCourseCount: source.courses.length,
  releaseEntryCount: source.courses.reduce((count, course) => count + course.entries.length, 0),
  requiredLocales,
  translationsPresent: totals,
  missingCount: missing.length,
  missing: strict ? missing : missing.slice(0, 20),
};
console.log(JSON.stringify(report, null, 2));
if (strict && missing.length) process.exitCode = 1;
