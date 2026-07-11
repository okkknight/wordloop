import modernFamilyS01E01 from "./data/modern-family-s01e01.json";

export type SentenceEntry = {
  id: string;
  episode: string;
  start: number;
  end: number;
  duration: number;
  text: string;
  translation: string;
  learnable: boolean;
  reviewReasons: string[];
  audio: string;
};

export type CoursePackage = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  entries: readonly SentenceEntry[];
};

const modernFamilyEntries = modernFamilyS01E01.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    audio: `/courses/modern-family/s01e01/${entry.audio}`,
  })) as SentenceEntry[];

export const COURSE_PACKAGES: readonly CoursePackage[] = [
  {
    id: "modern-family-s01e01",
    title: "Modern Family · S01E01",
    subtitle: "Pilot · 481 learning sentences",
    description: "用真实对白练习听力、表达和跟读。",
    entries: modernFamilyEntries,
  },
];

export const DEFAULT_COURSE = COURSE_PACKAGES[0];
