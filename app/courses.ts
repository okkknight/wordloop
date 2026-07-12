import modernFamilyS01E01 from "./data/modern-family-s01e01.json";
import { MODERN_FAMILY_S01E01_HIGHLIGHTS } from "./data/modern-family-s01e01-highlights";
import { WORDS } from "./words";

const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export type CourseEntry = {
  id: string;
  text: string;
  translation: string;
  phonetic?: string;
  audio: string;
  episode?: string;
  start?: number;
  end?: number;
  duration?: number;
  learnable?: boolean;
  reviewReasons?: string[];
  highlights?: readonly string[];
};

export type CoursePackage = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  kind: "word" | "sentence";
  practiceOrder: "random" | "sequential";
  entries: readonly CourseEntry[];
};

const modernFamilyEntries = modernFamilyS01E01.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E01_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e01/${entry.audio}`,
  })) as CourseEntry[];

const ieltsEntries: CourseEntry[] = WORDS.map(([word, translation, , phonetic]) => ({
  id: word,
  text: word,
  translation,
  phonetic,
  audio: `${basePath}/audio/${word}.m4a`,
}));

export const COURSE_PACKAGES: readonly CoursePackage[] = [
  {
    id: "ielts-high-frequency",
    title: "IELTS 高频词",
    subtitle: "Academic Word List · 570 words",
    description: "从 570 个高频学术词汇开始，逐词建立听辨和发音记忆。",
    kind: "word",
    practiceOrder: "random",
    entries: ieltsEntries,
  },
  {
    id: "modern-family-s01e01",
    title: "Modern Family · S01E01",
    subtitle: `Pilot · ${modernFamilyEntries.length} learning sentences`,
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyEntries,
  },
];

export const IELTS_HIGH_FREQUENCY_COURSE = COURSE_PACKAGES[0];
export const MODERN_FAMILY_S01E01_COURSE = COURSE_PACKAGES[1];
export const DEFAULT_COURSE = MODERN_FAMILY_S01E01_COURSE;
