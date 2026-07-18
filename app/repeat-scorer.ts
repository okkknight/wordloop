export const REPEAT_PASS_SCORE = 20;
export const MIN_SENTENCE_WORD_COVERAGE = 0.6;

export type RepeatScoreResult = {
  feedback: "PASS" | "TRY AGAIN";
  matched: string;
  passed: boolean;
  score: number;
};

export function normalizeSpeech(value: string) {
  return value.toLowerCase().replace(/[^a-z]/g, "");
}

export function speechCandidates(transcript: string) {
  const withoutNoiseLabels = transcript.replace(
    /[\[(](?:background noise|noise|music|laughter|silence|inaudible)[\])]/gi,
    " ",
  );
  const words = withoutNoiseLabels.split(/\s+/).map(normalizeSpeech).filter(Boolean);
  const candidates = new Set(words);
  for (let start = 0; start < words.length; start += 1) {
    let combined = words[start];
    for (let end = start + 1; end < Math.min(words.length, start + 12); end += 1) {
      combined += words[end];
      candidates.add(combined);
    }
  }
  return [...candidates];
}

export function hasEnoughSpeechEvidence(target: string, transcript: string) {
  const spokenWords = transcript.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g) ?? [];
  const targetWords = target.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g) ?? [];
  return spokenWords.length >= (targetWords.length > 1 ? 2 : 1);
}

export function normalizeCoverageWord(value: string) {
  const word = value.toLowerCase().replace(/’/g, "'").replace(/^[^a-z']+|[^a-z']+$/g, "");
  if (word === "'em" || word === "em") return "them";
  const contraction = word.match(/^([a-z]+)'(?:d|ll|re|ve|m|s)$/);
  return contraction?.[1] ?? normalizeSpeech(word);
}

export function sentenceWordCoverage(target: string, transcript: string) {
  const targetWords = target.split(/\s+/).map(normalizeCoverageWord).filter(Boolean);
  const spokenWords = new Set(transcript.split(/\s+/).map(normalizeCoverageWord).filter(Boolean));
  if (targetWords.length === 0) return 0;
  return targetWords.filter((word) => spokenWords.has(word)).length / targetWords.length;
}

export function levenshtein(a: string, b: string) {
  if (!a.length) return b.length;
  if (!b.length) return a.length;
  const matrix = Array.from({ length: a.length + 1 }, (_, row) =>
    Array.from({ length: b.length + 1 }, (_, column) => row === 0 ? column : column === 0 ? row : 0));
  for (let row = 1; row <= a.length; row += 1) {
    for (let column = 1; column <= b.length; column += 1) {
      const cost = a[row - 1] === b[column - 1] ? 0 : 1;
      matrix[row][column] = Math.min(
        matrix[row - 1][column] + 1,
        matrix[row][column - 1] + 1,
        matrix[row - 1][column - 1] + cost,
      );
    }
  }
  return matrix[a.length][b.length];
}

export function scoreTranscript(target: string, transcript: string): RepeatScoreResult {
  const normalizedTarget = normalizeSpeech(target);
  const candidates = speechCandidates(transcript);
  let matched = "";
  let bestSimilarity = 0;
  for (const candidate of candidates) {
    const distance = levenshtein(normalizedTarget, candidate);
    const similarity = Math.max(0, 1 - distance / Math.max(normalizedTarget.length, candidate.length, 1));
    if (similarity > bestSimilarity) {
      bestSimilarity = similarity;
      matched = candidate;
    }
  }
  const exact = candidates.includes(normalizedTarget);
  const score = exact ? 100 : Math.round(bestSimilarity * 100);
  const passed = exact || score >= REPEAT_PASS_SCORE;
  return { feedback: passed ? "PASS" : "TRY AGAIN", matched, passed, score: matched ? score : 0 };
}

export function scoreRepeatTranscript(target: string, transcript: string, sentence: boolean): RepeatScoreResult {
  const result = scoreTranscript(target, transcript);
  const passed = result.passed && (!sentence || sentenceWordCoverage(target, transcript) >= MIN_SENTENCE_WORD_COVERAGE);
  return { ...result, passed, feedback: passed ? "PASS" : "TRY AGAIN" };
}
