#!/usr/bin/env node
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { generateCoursePackages } from "./lib/course-export/exporter.mjs";

const repositoryRoot = resolve(process.env.WORDLOOP_COURSE_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), ".."));
const argumentsPassed = process.argv.slice(2);
let mode;
let output = resolve(repositoryRoot, "content/dist");
for (let index = 0; index < argumentsPassed.length; index += 1) {
  const argument = argumentsPassed[index];
  if (argument === "--write" || argument === "--check") {
    const nextMode = argument.slice(2);
    if (mode) throw new Error("Choose exactly one of --write or --check");
    mode = nextMode;
  } else if (argument === "--output") {
    const value = argumentsPassed[index + 1];
    if (!value || value.startsWith("--")) throw new Error("--output requires a directory");
    output = resolve(repositoryRoot, value);
    index += 1;
  } else {
    throw new Error(`Unknown argument: ${argument}`);
  }
}
if (!mode) throw new Error("Choose exactly one of --write or --check");

const report = await generateCoursePackages({ root: repositoryRoot, output, mode });
console.log(JSON.stringify(report, null, 2));
