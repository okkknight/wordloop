import Ajv2020 from "ajv/dist/2020.js";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const BANDS = new Set(["entry", "targetBase", "targetCore", "stretch"]);
const DIFFICULTIES = new Set([
  ...BANDS,
  "A2-", "A2", "A2+", "B1-", "B1", "B1+", "B2-", "B2", "B2+",
]);
const DEFAULTS = Object.freeze({
  tokenSimilarityWarning: 0.82,
  sequenceSimilarityWarning: 0.88,
  wordCountTolerance: 1,
  forbiddenCharacters: ["(", ")", "/", "\\", "—", "–"],
});
const SENTENCE_COUNT = 16;

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

export async function createCourseCandidateChecker(root) {
  const schemaDirectory = resolve(root, "wordloop_course_production_pack/schemas");
  const [blueprintSchema, candidatesSchema] = await Promise.all([
    readJson(resolve(schemaDirectory, "course-blueprint.schema.json")),
    readJson(resolve(schemaDirectory, "candidate-sentences.schema.json")),
  ]);
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  return {
    validateBlueprint: ajv.compile(blueprintSchema),
    validateCandidates: ajv.compile(candidatesSchema),
  };
}

export function countEnglishWords(text) {
  return String(text).match(/[A-Za-z]+(?:['’][A-Za-z]+)*(?:-[A-Za-z]+(?:['’][A-Za-z]+)*)*/g)?.length ?? 0;
}

export function normalizeSentence(text) {
  return String(text)
    .toLowerCase()
    .replace(/[’]/g, "'")
    .replace(/[^a-z0-9'\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenSet(text) {
  return new Set(normalizeSentence(text).split(/\s+/).filter(Boolean));
}

function jaccard(left, right) {
  const a = tokenSet(left);
  const b = tokenSet(right);
  const union = new Set([...a, ...b]);
  if (!union.size) return 1;
  return [...a].filter((token) => b.has(token)).length / union.size;
}

function levenshtein(left, right) {
  const a = normalizeSentence(left);
  const b = normalizeSentence(right);
  if (!a.length || !b.length) return a === b ? 1 : 0;
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let row = 1; row <= a.length; row += 1) {
    const current = [row];
    for (let column = 1; column <= b.length; column += 1) {
      current[column] = Math.min(
        current[column - 1] + 1,
        previous[column] + 1,
        previous[column - 1] + (a[row - 1] === b[column - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  return 1 - previous[b.length] / Math.max(a.length, b.length);
}

function estimateClauses(text) {
  const markers = String(text).match(/;|\b(?:and|but|or|so|because|although|while|if|when|which|who)\b|\b(?:once|after|before)\s+(?:i|we|you|they|he|she|it)\b/gi) ?? [];
  return Math.max(1, markers.length + 1);
}

function containsChunk(text, chunk, matchers = []) {
  const normalizedText = normalizeSentence(text);
  const normalizedChunk = normalizeSentence(chunk);
  if (normalizedChunk && normalizedText.includes(normalizedChunk)) return true;
  for (const matcher of [chunk, ...matchers]) {
    const parts = String(matcher).split(/\.\.\.|,/).map(normalizeSentence).filter(Boolean);
    let position = 0;
    if (parts.length > 1 && parts.every((part) => {
      const next = normalizedText.indexOf(part, position);
      if (next === -1) return false;
      position = next + part.length;
      return true;
    })) return true;
  }
  return false;
}

function mergedConfig(config) {
  return { ...DEFAULTS, ...(config?.checker ?? config ?? {}) };
}

function issue(report, level, code, message, details = {}) {
  report[level].push({ code, message, ...details });
}

function schemaIssues(report, validator, value, document) {
  if (validator(value)) return true;
  for (const error of validator.errors ?? []) {
    issue(report, "errors", "schema_invalid", `${document}${error.instancePath || "/"} ${error.message}`, {
      document,
      instancePath: error.instancePath || "/",
      keyword: error.keyword,
    });
  }
  return false;
}

function validateSlots(report, blueprint, candidates, expectedCandidateCount) {
  const blueprintSlots = Array.isArray(blueprint?.sentenceSlots) ? blueprint.sentenceSlots : [];
  const candidateSlots = Array.isArray(candidates?.slots) ? candidates.slots : [];
  const checkIds = (slots, field) => {
    const ids = slots.map((item) => item?.slot).filter(Number.isInteger);
    const duplicates = ids.filter((id, index) => ids.indexOf(id) !== index);
    const missing = Array.from({ length: SENTENCE_COUNT }, (_, index) => index + 1).filter((id) => !ids.includes(id));
    if (slots.length !== SENTENCE_COUNT || duplicates.length || missing.length) {
      issue(report, "errors", "slot_set_invalid", `${field} must contain each slot from 1 through ${SENTENCE_COUNT} exactly once`, { field, duplicates: [...new Set(duplicates)], missing });
    }
  };
  checkIds(blueprintSlots, "blueprint.sentenceSlots");
  checkIds(candidateSlots, "candidates.slots");
  const blueprintBySlot = new Map(blueprintSlots.map((slot) => [slot.slot, slot]));
  for (const candidateSlot of candidateSlots) {
    const blueprintSlot = blueprintBySlot.get(candidateSlot.slot);
    if (!blueprintSlot) {
      issue(report, "errors", "unknown_slot", `Candidate slot ${candidateSlot.slot} is not present in the blueprint`, { slot: candidateSlot.slot });
      continue;
    }
    if (!Array.isArray(candidateSlot.options) || candidateSlot.options.length !== expectedCandidateCount) {
      issue(report, "errors", "candidate_count_invalid", `Slot ${candidateSlot.slot} must contain ${expectedCandidateCount} candidates`, {
        slot: candidateSlot.slot,
        expected: expectedCandidateCount,
        actual: candidateSlot.options?.length ?? 0,
      });
    }
  }
  return blueprintBySlot;
}

function validateDifficultyPlan(report, blueprint) {
  const plan = blueprint?.difficultyPlan;
  const slots = blueprint?.sentenceSlots ?? [];
  if (!plan || !Array.isArray(plan.curve) || !plan.distribution) return;
  const total = Object.values(plan.distribution).reduce((sum, value) => sum + value, 0);
  if (total !== SENTENCE_COUNT) issue(report, "errors", "difficulty_distribution_invalid", `Difficulty distribution must total ${SENTENCE_COUNT}`, { actual: total });
  for (const band of BANDS) {
    const actual = plan.curve.filter((value) => value === band).length;
    if (actual !== plan.distribution[band]) issue(report, "errors", "difficulty_curve_mismatch", `Difficulty curve has ${actual} ${band} slots but distribution declares ${plan.distribution[band]}`, { band, actual, expected: plan.distribution[band] });
  }
  plan.curve.forEach((band, index) => {
    if (slots[index]?.difficultyBand !== band) issue(report, "errors", "slot_difficulty_mismatch", `Slot ${index + 1} difficulty does not match the blueprint curve`, { slot: index + 1, expected: band, actual: slots[index]?.difficultyBand });
  });
  let stretchRun = 0;
  for (const band of plan.curve) {
    stretchRun = band === "stretch" ? stretchRun + 1 : 0;
    if (stretchRun > 2) {
      issue(report, "errors", "stretch_run_invalid", "Blueprint contains more than two consecutive stretch slots");
      break;
    }
  }
}

function validateCandidate(report, candidate, slot, config) {
  const location = { slot: slot.slot, candidateId: candidate.candidateId };
  const text = candidate.text ?? "";
  const translation = candidate.translation ?? "";
  if (!String(text).trim() || !String(translation).trim()) issue(report, "errors", "empty_text", "English text and Chinese translation are required", location);
  const wordCount = countEnglishWords(text);
  const distance = wordCount < slot.wordCountMin ? slot.wordCountMin - wordCount : Math.max(0, wordCount - slot.wordCountMax);
  if (distance) issue(report, distance > config.wordCountTolerance ? "errors" : "warnings", "word_count_out_of_range", `Candidate has ${wordCount} words; slot allows ${slot.wordCountMin}-${slot.wordCountMax}`, { ...location, actual: wordCount, min: slot.wordCountMin, max: slot.wordCountMax });
  if (candidate.wordCount !== wordCount) issue(report, "warnings", "reported_word_count_mismatch", `Reported word count ${candidate.wordCount} differs from calculated count ${wordCount}`, { ...location, reported: candidate.wordCount, actual: wordCount });
  if (/\r?\n| {2,}|[!?.,;:]{2,}/.test(text) || config.forbiddenCharacters.some((character) => text.includes(character)) || /[\p{Extended_Pictographic}]/u.test(text)) {
    issue(report, "warnings", "punctuation_or_character_warning", "Candidate contains a prohibited or suspicious character pattern", location);
  }
  if (String(text).trim() && !/[.!?]$/.test(String(text).trim())) issue(report, "warnings", "sentence_ending_warning", "English sentence should end with ., !, or ?", location);
  if (String(translation).trim() && !/[\u3400-\u9fff]/u.test(translation)) issue(report, "warnings", "translation_language_warning", "Translation does not contain Chinese characters", location);
  const measuredClauses = estimateClauses(text);
  if (measuredClauses > slot.maxClauses) issue(report, "warnings", "clause_count_warning", `Estimated clause count ${measuredClauses} exceeds slot maximum ${slot.maxClauses}`, { ...location, actual: measuredClauses, max: slot.maxClauses });
  if (Math.abs((candidate.clauseCount ?? 0) - measuredClauses) > 1) issue(report, "warnings", "reported_clause_count_mismatch", "Reported clause count materially differs from the heuristic estimate", { ...location, reported: candidate.clauseCount, actual: measuredClauses });
  if (!Array.isArray(candidate.usedChunks) || !candidate.usedChunks.length) issue(report, "warnings", "used_chunks_empty", "Candidate should identify its used core chunks", location);
  if (!DIFFICULTIES.has(candidate.estimatedDifficulty)) issue(report, "errors", "estimated_difficulty_invalid", `Unsupported estimated difficulty: ${candidate.estimatedDifficulty}`, location);
  for (const chunk of slot.requiredChunks ?? []) {
    if (!containsChunk(text, chunk)) issue(report, "errors", "required_chunk_missing", `Required chunk is missing: ${chunk}`, { ...location, chunk });
  }
}

function validateChunkCoverage(report, blueprint, candidateSlots) {
  const candidatesBySlot = new Map(candidateSlots.map((item) => [item.slot, item.options ?? []]));
  for (const coverage of blueprint?.coreChunkCoverage ?? []) {
    const matchedSlots = [];
    for (const slotNumber of coverage.slots ?? []) {
      const options = candidatesBySlot.get(slotNumber) ?? [];
      if (options.some((candidate) => containsChunk(candidate.text, coverage.chunk, coverage.chunkMatchers))) matchedSlots.push(slotNumber);
      else issue(report, "errors", "planned_chunk_missing", `Planned core chunk is absent from slot ${slotNumber}: ${coverage.chunk}`, { slot: slotNumber, chunk: coverage.chunk });
    }
    if (matchedSlots.length < coverage.plannedCount) issue(report, "errors", "core_chunk_coverage_low", `Core chunk appears in ${matchedSlots.length} planned slots but needs ${coverage.plannedCount}`, { chunk: coverage.chunk, actual: matchedSlots.length, expected: coverage.plannedCount });
  }
}

function validateDuplicatesAndSimilarity(report, candidates, config) {
  const all = (candidates?.slots ?? []).flatMap((slot) => (slot.options ?? []).map((option) => ({ ...option, slot: slot.slot })));
  const seen = new Map();
  for (const candidate of all) {
    const normalized = normalizeSentence(candidate.text);
    if (!normalized) continue;
    if (seen.has(normalized)) issue(report, "errors", "duplicate_sentence", "Exact or normalized duplicate candidate sentence", { first: seen.get(normalized), second: { slot: candidate.slot, candidateId: candidate.candidateId } });
    else seen.set(normalized, { slot: candidate.slot, candidateId: candidate.candidateId });
  }
  for (let index = 0; index < all.length; index += 1) {
    for (let other = index + 1; other < all.length; other += 1) {
      const tokenSimilarity = jaccard(all[index].text, all[other].text);
      const sequenceSimilarity = levenshtein(all[index].text, all[other].text);
      if (tokenSimilarity >= config.tokenSimilarityWarning || sequenceSimilarity >= config.sequenceSimilarityWarning) {
        issue(report, "warnings", "high_similarity", "Candidate pair needs editorial review for possible mechanical repetition", {
          first: { slot: all[index].slot, candidateId: all[index].candidateId },
          second: { slot: all[other].slot, candidateId: all[other].candidateId },
          tokenSimilarity: Number(tokenSimilarity.toFixed(3)),
          sequenceSimilarity: Number(sequenceSimilarity.toFixed(3)),
        });
      }
    }
  }
}

export function checkCourseCandidates({ checker, blueprint, candidates, config = {} }) {
  const report = { valid: false, summary: { errorCount: 0, warningCount: 0 }, errors: [], warnings: [], metrics: { wordTokenizer: "ASCII words with internal apostrophes and hyphens each count as one word" } };
  const settings = mergedConfig(config);
  const blueprintValid = schemaIssues(report, checker.validateBlueprint, blueprint, "blueprint");
  const candidatesValid = schemaIssues(report, checker.validateCandidates, candidates, "candidates");
  if (blueprint?.courseId !== candidates?.courseId) issue(report, "errors", "course_id_mismatch", "Blueprint and candidates must have the same courseId", { blueprintCourseId: blueprint?.courseId, candidatesCourseId: candidates?.courseId });
  const expectedCandidateCount = settings.candidateCountPerSlot ?? candidates?.candidateCountPerSlot;
  if (!Number.isInteger(expectedCandidateCount) || expectedCandidateCount < 1) issue(report, "errors", "candidate_count_missing", "A positive candidateCountPerSlot is required");
  const blueprintBySlot = validateSlots(report, blueprint, candidates, expectedCandidateCount);
  if (blueprintValid) validateDifficultyPlan(report, blueprint);
  for (const candidateSlot of candidates?.slots ?? []) {
    const slot = blueprintBySlot.get(candidateSlot.slot);
    if (!slot) continue;
    for (const candidate of candidateSlot.options ?? []) validateCandidate(report, candidate, slot, settings);
  }
  if (blueprintValid && candidatesValid) validateChunkCoverage(report, blueprint, candidates.slots ?? []);
  validateDuplicatesAndSimilarity(report, candidates, settings);
  report.summary.errorCount = report.errors.length;
  report.summary.warningCount = report.warnings.length;
  report.valid = report.errors.length === 0;
  return report;
}
