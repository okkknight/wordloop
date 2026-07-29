import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { scoreRepeatTranscript } from "../app/repeat-scorer.ts";

test("Web repeat scorer matches shared anonymous golden fixtures", async () => {
  const fixtures = JSON.parse(await readFile(new URL("./fixtures/repeat-scoring.json", import.meta.url), "utf8"));
  for (const fixture of fixtures) {
    const actual = scoreRepeatTranscript(fixture.target, fixture.transcript, fixture.sentence);
    assert.deepEqual(
      { passed: actual.passed, score: actual.score, matched: actual.matched },
      fixture.expected,
      fixture.id,
    );
  }
});
