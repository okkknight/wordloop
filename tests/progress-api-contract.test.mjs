import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import test from "node:test";

const root = new URL("../", import.meta.url);
const fixtureURL = new URL("../contracts/progress/post-cases.json", import.meta.url);
const errorFixtureURL = new URL("../contracts/progress/error-cases.json", import.meta.url);

async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => server.listen(0, "127.0.0.1", resolve).once("error", reject));
  const { port } = server.address();
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  return port;
}

async function waitForServer(url, process) {
  for (let attempt = 0; attempt < 200; attempt += 1) {
    if (process.exitCode !== null) throw new Error(`Server exited with ${process.exitCode}`);
    try {
      const response = await fetch(url);
      if (response.status < 500) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function stop(process) {
  if (process.exitCode !== null) return;
  process.kill("SIGTERM");
  await Promise.race([
    new Promise((resolve) => process.once("exit", resolve)),
    new Promise((resolve) => setTimeout(resolve, 2_000)),
  ]);
  if (process.exitCode === null) process.kill("SIGKILL");
}

async function request(baseURL, method, path, payload) {
  const response = await fetch(`${baseURL}${path}`, {
    method,
    ...(payload ? { headers: { "content-type": "application/json" }, body: JSON.stringify(payload) } : {}),
  });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

function normalized(value) {
  if (Array.isArray(value)) {
    return value.map(normalized).sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)));
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).sort(([left], [right]) => left.localeCompare(right)).map(([key, item]) => [key, normalized(item)]));
  }
  return value;
}

test("Node and Cloudflare progress handlers satisfy the shared request contract", { timeout: 90_000 }, async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "wordloop-progress-contract-"));
  const nodePort = await freePort();
  const workerPort = await freePort();
  const nodeProcess = spawn(process.execPath, ["server/index.mjs"], {
    cwd: root,
    env: { ...process.env, PORT: String(nodePort), WORDLOOP_DB_PATH: join(directory, "node.sqlite") },
    stdio: "ignore",
  });
  t.after(async () => {
    await stop(nodeProcess);
    await rm(directory, { recursive: true, force: true });
  });
  await waitForServer(`http://127.0.0.1:${nodePort}/healthz`, nodeProcess);

  const migrationFiles = [
    "0000_wild_black_widow.sql",
    "0001_shocking_dreaming_celestial.sql",
    "0002_wet_ares.sql",
    "0003_charming_ikaris.sql",
    "0004_remember_recent_course.sql",
  ];
  const migrationSQL = (await Promise.all(migrationFiles.map((name) =>
    readFile(new URL(`../dist/.openai/drizzle/${name}`, import.meta.url), "utf8")
  ))).join("\n");
  const migrationPath = join(directory, "migrations.sql");
  await writeFile(migrationPath, migrationSQL);
  const wrangler = new URL("../node_modules/.bin/wrangler", import.meta.url).pathname;
  const migration = spawnSync(wrangler, [
    "d1", "execute", "DB", "--local", "--config", "dist/server/wrangler.json",
    "--persist-to", join(directory, "worker-state"), "--file", migrationPath,
  ], { cwd: root, encoding: "utf8" });
  assert.equal(migration.status, 0, migration.stderr || migration.stdout);

  const workerProcess = spawn(wrangler, [
    "dev", "--config", "dist/server/wrangler.json", "--port", String(workerPort),
    "--persist-to", join(directory, "worker-state"), "--log-level", "error",
  ], { cwd: root, stdio: "ignore" });
  t.after(() => stop(workerProcess));
  await waitForServer(`http://127.0.0.1:${workerPort}/api/progress?userId=bad&mode=listen`, workerProcess);

  const bases = [`http://127.0.0.1:${nodePort}`, `http://127.0.0.1:${workerPort}`];
  const compare = async (method, path, payload, expected) => {
    const results = await Promise.all(bases.map((base) => request(base, method, path, payload)));
    assert.deepEqual(normalized(results[0]), normalized(results[1]), `Node/Worker mismatch for ${method} ${path}: ${JSON.stringify(payload)}`);
    if (expected) assert.deepEqual(normalized(results[0]), normalized(expected), `Fixture mismatch for ${method} ${path}: ${JSON.stringify(payload)}`);
    return results[0];
  };

  const errors = JSON.parse(await readFile(errorFixtureURL, "utf8"));
  for (const fixture of errors) {
    await compare(fixture.method, fixture.path, fixture.request, {
      status: fixture.status,
      body: fixture.response,
    });
  }

  const cases = JSON.parse(await readFile(fixtureURL, "utf8"));
  for (const fixture of cases) {
    await compare("POST", "/api/progress", fixture.request, { status: 200, body: fixture.response });
  }

  const word = cases.find(({ name }) => name === "word-progress").request;
  await compare("POST", "/api/progress", word, { status: 200, body: { word: "example", studyCount: 1 } });
  for (const [id, count] of [["event-004", 2], ["event-005", 3], ["event-006", 3]]) {
    await compare("POST", "/api/progress", { ...word, clientEventId: id }, { status: 200, body: { word: "example", studyCount: count } });
  }

  const complete = cases.find(({ name }) => name === "complete-course").request;
  await compare("POST", "/api/progress", complete, { status: 200, body: { courseId: "course-a", completionCount: 1 } });
  await compare("POST", "/api/progress", { ...complete, mode: "repeat", clientEventId: "event-007" }, { status: 200, body: { courseId: "course-a", completionCount: 2 } });

  await compare("POST", "/api/progress", {
    ...cases.find(({ name }) => name === "select-course").request,
    resetCourse: true, completeCourse: true,
  }, { status: 200, body: { recentCourseId: "course-a" } });

  await compare("POST", "/api/progress", {
    userId: "name:alice", mode: "listen", clientEventId: "event-008",
    courseId: "course-a", itemId: "line-001",
  }, { status: 200, body: { itemId: "line-001", studyCount: 1 } });
  await compare("POST", "/api/progress", cases.find(({ name }) => name === "reset-course").request);
  await compare("GET", "/api/progress?userId=name:alice&mode=listen&courseId=course-a", null, {
    status: 200, body: { progress: [{ itemId: "line-001", studyCount: 1 }] },
  });
  await compare("GET", "/api/progress?userId=name:alice&mode=repeat&courseId=course-a", null, {
    status: 200, body: { progress: [] },
  });
  await compare("GET", "/api/progress?userId=name:alice&mode=listen", null, {
    status: 200,
    body: {
      progress: [{ word: "example", studyCount: 3 }],
      completions: [{ courseId: "course-a", completionCount: 2 }],
      recentCourseId: "course-a",
    },
  });
});
