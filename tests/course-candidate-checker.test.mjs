import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import test from "node:test";
import { checkCourseCandidates, countEnglishWords, createCourseCandidateChecker } from "../scripts/lib/course-pipeline/checker.mjs";

const root = resolve(import.meta.dirname, "..");
const execFileAsync = promisify(execFile);

function makeBlueprint() {
  const curve = ["entry", "entry", "entry", "entry", ...Array(5).fill("targetBase"), ...Array(5).fill("targetCore"), "stretch", "stretch", "targetCore", "targetCore", "stretch", "stretch"];
  return {
    courseId: "office-small-talk",
    courseBrief: {
      courseType: "communication_skill", targetLevel: "B1", learnerOutcome: "Start a short conversation at work.",
      communicationGoals: ["Open a conversation."], coreChunks: ["I'd like", "How was", "That sounds"],
      supportingVocabulary: [], contentBoundaries: ["No technical jargon."], realWorldContexts: ["At work."],
    },
    difficultyPlan: {
      entryLevel: "A2+", coreLevel: "B1", stretchLevel: "B1+",
      distribution: { entry: 4, targetBase: 5, targetCore: 7, stretch: 4 }, curve, principles: ["Increase one factor at a time."], adjustmentReason: null,
    },
    contentStructure: [{ name: "Open", purpose: "Start naturally.", sentenceCount: 20 }],
    coreChunkCoverage: [{ chunk: "I'd like", plannedCount: 1, slots: [1], distinctUses: ["A polite opening."], chunkMatchers: ["I'd like..."] }],
    sentenceSlots: curve.map((difficultyBand, index) => ({
      slot: index + 1, section: "Open", role: "Practice a useful line.", meaningTarget: "Say one useful thing.", difficultyBand,
      difficultyFocus: "detail", requiredChunks: index === 0 ? ["I'd like"] : [], optionalChunks: [],
      wordCountMin: 5, wordCountMax: 10, maxClauses: 3, maxInformationUnits: 2, maxNewChunks: 1,
      relationshipToPrevious: "variation", realWorldUse: "In a short work conversation.", avoid: [],
    })),
    blueprintReview: { valid: true, strengths: ["Focused."], risks: [], humanReviewFocus: [] }, approved: true,
  };
}

function makeCandidates() {
  return {
    courseId: "office-small-talk", candidateCountPerSlot: 2,
    slots: Array.from({ length: 20 }, (_, index) => ({
      slot: index + 1,
      generationWarning: null,
      options: [
        {
          candidateId: `s${index + 1}-a`, text: index === 0 ? "I'd like to start with this task." : `I can handle task number ${index + 1} today.`, translation: "我今天可以处理这项任务。",
          usedChunks: index === 0 ? ["I'd like"] : [], estimatedDifficulty: "entry", difficultyFactors: ["detail"], wordCount: 7,
          clauseCount: 1, informationUnitCount: 1, realWorldUseExplanation: "Useful at work.",
        },
        {
          candidateId: `s${index + 1}-b`, text: index === 0 ? "I'd like to discuss this task today." : `Today I can finish task number ${index + 1}.`, translation: "我今天能完成这项任务。",
          usedChunks: index === 0 ? ["I'd like"] : [], estimatedDifficulty: "entry", difficultyFactors: ["detail"], wordCount: 7,
          clauseCount: 1, informationUnitCount: 1, realWorldUseExplanation: "Useful at work.",
        },
      ],
    })),
    generationReview: { coverageComplete: true, warnings: [] },
  };
}

test("word tokenizer treats contractions and hyphenated words as one word", () => {
  assert.equal(countEnglishWords("I'm following up on a well-planned project."), 7);
});

test("checker accepts a schema-valid course and produces only editorial warnings", async () => {
  const checker = await createCourseCandidateChecker(root);
  const report = checkCourseCandidates({ checker, blueprint: makeBlueprint(), candidates: makeCandidates() });
  assert.equal(report.valid, true);
  assert.equal(report.summary.errorCount, 0);
  assert.ok(report.warnings.some((item) => item.code === "high_similarity"));
  assert.match(report.metrics.wordTokenizer, /apostrophes/i);
});

test("checker matches a core chunk with variable words around punctuation", async () => {
  const checker = await createCourseCandidateChecker(root);
  const blueprint = makeBlueprint();
  const candidates = makeCandidates();
  blueprint.coreChunkCoverage[0] = { chunk: "I'd love to, but", plannedCount: 1, slots: [1], distinctUses: ["A polite refusal."] };
  blueprint.sentenceSlots[0].requiredChunks = ["I'd love to, but"];
  candidates.slots[0].options = [
    { ...candidates.slots[0].options[0], text: "I'd love to join, but I can't today.", wordCount: 8, usedChunks: ["I'd love to, but"] },
    { ...candidates.slots[0].options[1], text: "I'd love to help, but I'm busy tonight.", wordCount: 8, usedChunks: ["I'd love to, but"] },
  ];
  const report = checkCourseCandidates({ checker, blueprint, candidates });
  assert.equal(report.errors.some((item) => item.code === "required_chunk_missing" || item.code === "planned_chunk_missing"), false);
});

test("clause heuristic does not treat the pronoun that as a second clause", async () => {
  const checker = await createCourseCandidateChecker(root);
  const blueprint = makeBlueprint();
  const candidates = makeCandidates();
  candidates.slots[0].options = [
    { ...candidates.slots[0].options[0], text: "I can't take that on right now.", wordCount: 7, usedChunks: ["right now"] },
    { ...candidates.slots[0].options[1], text: "I'm not available for that today.", wordCount: 6, usedChunks: ["today"] },
  ];
  const report = checkCourseCandidates({ checker, blueprint, candidates });
  assert.equal(report.warnings.some((item) => item.code === "clause_count_warning" && item.slot === 1), false);
});

test("checker reports structural, word-count, required-chunk, and duplicate errors", async () => {
  const checker = await createCourseCandidateChecker(root);
  const candidates = makeCandidates();
  candidates.slots[0].options[0].text = "This is an unnecessarily long sentence with many extra words for the first slot today.";
  candidates.slots[0].options[0].wordCount = 2;
  candidates.slots[1].options[1].text = candidates.slots[1].options[0].text;
  candidates.slots.pop();
  const report = checkCourseCandidates({ checker, blueprint: makeBlueprint(), candidates });
  assert.equal(report.valid, false);
  assert.ok(report.errors.some((item) => item.code === "slot_set_invalid"));
  assert.ok(report.errors.some((item) => item.code === "word_count_out_of_range"));
  assert.ok(report.errors.some((item) => item.code === "required_chunk_missing"));
  assert.ok(report.errors.some((item) => item.code === "duplicate_sentence"));
  assert.ok(report.warnings.some((item) => item.code === "reported_word_count_mismatch"));
});

test("CLI writes a report and exits nonzero when errors are found", async () => {
  const temporary = await mkdtemp(join(tmpdir(), "wordloop-checker-"));
  const blueprintPath = join(temporary, "blueprint.json");
  const candidatesPath = join(temporary, "candidates.json");
  const reportPath = join(temporary, "report.json");
  const candidates = makeCandidates();
  candidates.courseId = "other-course";
  await Promise.all([
    writeFile(blueprintPath, JSON.stringify(makeBlueprint())),
    writeFile(candidatesPath, JSON.stringify(candidates)),
  ]);
  const cli = join(root, "scripts/check_course_candidates.mjs");
  await assert.rejects(execFileAsync(process.execPath, [cli, "--blueprint", blueprintPath, "--candidates", candidatesPath, "--report", reportPath]), { code: 1 });
  const report = JSON.parse(await readFile(reportPath, "utf8"));
  assert.equal(report.valid, false);
  assert.ok(report.errors.some((item) => item.code === "course_id_mismatch"));
});
