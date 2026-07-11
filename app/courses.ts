import modernFamilyS01E01 from "./data/modern-family-s01e01.json";
import { WORDS } from "./words";

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
};

export type CoursePackage = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  kind: "word" | "sentence";
  entries: readonly CourseEntry[];
};

const modernFamilyEntries = modernFamilyS01E01.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    audio: `/courses/modern-family/s01e01/${entry.audio}`,
  })) as CourseEntry[];

const ieltsEntries: CourseEntry[] = WORDS.map(([word, translation, , phonetic]) => ({
  id: word,
  text: word,
  translation,
  phonetic,
  audio: `/audio/${word}.m4a`,
}));

export const COURSE_PACKAGES: readonly CoursePackage[] = [
  {
    id: "ielts-high-frequency",
    title: "IELTS 高频词",
    subtitle: "Academic Word List · 570 words",
    description: "从 570 个高频学术词汇开始，逐词建立听辨和发音记忆。",
    kind: "word",
    entries: ieltsEntries,
  },
  {
    id: "modern-family-s01e01",
    title: "Modern Family · S01E01",
    subtitle: "Pilot · 222 learning sentences",
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    entries: modernFamilyEntries,
  },
];

export const IELTS_HIGH_FREQUENCY_COURSE = COURSE_PACKAGES[0];
export const MODERN_FAMILY_S01E01_COURSE = COURSE_PACKAGES[1];
export const DEFAULT_COURSE = IELTS_HIGH_FREQUENCY_COURSE;
