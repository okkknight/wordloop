#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checkCourseCandidates, createCourseCandidateChecker } from "./lib/course-pipeline/checker.mjs";

const root = resolve(process.env.WORDLOOP_COURSE_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), ".."));
const args = process.argv.slice(2);
const options = {};
for (let index = 0; index < args.length; index += 1) {
  const key = args[index];
  if (!Object.hasOwn({ "--blueprint": true, "--candidates": true, "--report": true, "--config": true }, key)) throw new Error(`Unknown argument: ${key}`);
  const value = args[index + 1];
  if (!value || value.startsWith("--")) throw new Error(`${key} requires a file path`);
  options[key.slice(2)] = resolve(root, value);
  index += 1;
}
for (const required of ["blueprint", "candidates", "report"]) if (!options[required]) throw new Error(`--${required} is required`);
const [blueprint, candidates, config] = await Promise.all([
  readFile(options.blueprint, "utf8").then(JSON.parse),
  readFile(options.candidates, "utf8").then(JSON.parse),
  options.config ? readFile(options.config, "utf8").then(JSON.parse) : Promise.resolve({}),
]);
const checker = await createCourseCandidateChecker(root);
const report = checkCourseCandidates({ checker, blueprint, candidates, config });
await mkdir(dirname(options.report), { recursive: true });
await writeFile(options.report, `${JSON.stringify(report, null, 2)}\n`);
console.log(`WordLoop checker: ${report.valid ? "PASS" : "FAIL"} (${report.summary.errorCount} errors, ${report.summary.warningCount} warnings)`);
console.log(`Report: ${options.report}`);
if (!report.valid) process.exitCode = 1;
