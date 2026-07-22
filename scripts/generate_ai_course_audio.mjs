#!/usr/bin/env node
import { spawn } from "node:child_process";
import { mkdir, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const defaults = {
  course: "wordloop_course_production_pack/outputs/polite-boundaries-b1/final-course.json",
  manifest: "app/data/ai-polite-boundaries-b1.json",
  audioDirectory: "public/courses/ai/polite-boundaries-b1/audio",
  voice: "marin",
  model: "gpt-4o-mini-tts",
};

function parseArguments(argumentsPassed) {
  const result = { ...defaults };
  for (let index = 0; index < argumentsPassed.length; index += 1) {
    const argument = argumentsPassed[index];
    if (argument === "--force") result.force = true;
    else if (Object.hasOwn({ "--course": true, "--manifest": true, "--audio-dir": true, "--voice": true, "--model": true }, argument)) {
      const value = argumentsPassed[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`${argument} requires a value`);
      result[{ "--course": "course", "--manifest": "manifest", "--audio-dir": "audioDirectory", "--voice": "voice", "--model": "model" }[argument]] = value;
      index += 1;
    } else throw new Error(`Unknown argument: ${argument}`);
  }
  return result;
}

function readEnvValue(contents, name) {
  return contents.split(/\r?\n/).find((line) => line.startsWith(`${name}=`))?.slice(name.length + 1)?.trim();
}

async function apiKey() {
  if (process.env.OPENAI_API_KEY) return process.env.OPENAI_API_KEY;
  const local = await readFile(join(root, ".env.local"), "utf8").catch(() => "");
  const key = readEnvValue(local, "OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY is required in the environment or .env.local");
  return key;
}

async function run(command, argumentsPassed) {
  await new Promise((resolvePromise, reject) => {
    const child = spawn(command, argumentsPassed, { stdio: "inherit" });
    child.on("error", reject);
    child.on("exit", (code) => code === 0 ? resolvePromise() : reject(new Error(`${command} exited with ${code}`)));
  });
}

async function durationSeconds(path) {
  const output = [];
  await new Promise((resolvePromise, reject) => {
    const child = spawn("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path]);
    child.stdout.on("data", (chunk) => output.push(chunk));
    child.on("error", reject);
    child.on("exit", (code) => code === 0 ? resolvePromise() : reject(new Error(`ffprobe exited with ${code}`)));
  });
  const value = Number(Buffer.concat(output).toString("utf8").trim());
  if (!Number.isFinite(value) || value <= 0) throw new Error(`Could not measure generated audio: ${path}`);
  return Number(value.toFixed(3));
}

async function generateSpeech({ key, text, voice, model, target }) {
  const response = await fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      voice,
      input: text,
      response_format: "aac",
      instructions: "Speak clear, natural American English for adult language learners. Use a calm, supportive tone and a moderate pace. Do not add any words before or after the sentence.",
    }),
  });
  if (!response.ok) throw new Error(`OpenAI speech request failed (${response.status}): ${await response.text()}`);
  const temporaryAac = `${target}.aac`;
  await writeFile(temporaryAac, Buffer.from(await response.arrayBuffer()));
  try {
    await run("ffmpeg", ["-y", "-v", "error", "-i", temporaryAac, "-c:a", "copy", target]);
  } finally {
    await rm(temporaryAac, { force: true });
  }
}

const options = parseArguments(process.argv.slice(2));
const [course, key] = await Promise.all([
  readFile(resolve(root, options.course), "utf8").then(JSON.parse),
  apiKey(),
]);
const audioDirectory = resolve(root, options.audioDirectory);
const manifestPath = resolve(root, options.manifest);
await mkdir(audioDirectory, { recursive: true });

const entries = [];
for (const sentence of course.finalSentences) {
  const filename = `polite-boundaries-b1-${String(sentence.order).padStart(3, "0")}.m4a`;
  const target = join(audioDirectory, filename);
  if (options.force || !(await stat(target).then(() => true).catch(() => false))) {
    console.log(`Generating ${sentence.order}/20: ${sentence.text}`);
    await generateSpeech({ key, text: sentence.text, voice: options.voice, model: options.model, target });
  }
  const duration = await durationSeconds(target);
  entries.push({
    id: `ai-boundaries-${String(sentence.order).padStart(3, "0")}`,
    text: sentence.text,
    translation: sentence.translation,
    audio: `audio/${filename}`,
    learnable: true,
    start: 0,
    end: duration,
    duration,
  });
}

const manifest = {
  courseId: course.courseId,
  provider: "OpenAI",
  sourceUrl: "https://developers.openai.com/api/docs/guides/text-to-speech",
  attribution: `Original WordLoop course text · AI-generated voice by OpenAI ${options.model} (${options.voice})`,
  licenseNote: "Course text is original WordLoop content. Audio is AI-generated; disclose this to learners.",
  entries,
};
const temporaryManifest = `${manifestPath}.tmp`;
await mkdir(dirname(manifestPath), { recursive: true });
await writeFile(temporaryManifest, `${JSON.stringify(manifest, null, 2)}\n`);
await rename(temporaryManifest, manifestPath);
console.log(`Generated ${entries.length} AI voice clips in ${audioDirectory}`);
