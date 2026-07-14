import modernFamilyS01E01 from "./data/modern-family-s01e01.json";
import modernFamilyS01E02 from "./data/modern-family-s01e02.json";
import modernFamilyS01E03 from "./data/modern-family-s01e03.json";
import modernFamilyS01E04 from "./data/modern-family-s01e04.json";
import modernFamilyS01E05 from "./data/modern-family-s01e05.json";
import voaWorkplaceConversationsB1 from "./data/voa-workplace-conversations-b1.json";
import voaProjectFeedbackB1 from "./data/voa-project-feedback-b1.json";
import voaPetsResponsibilityB1 from "./data/voa-pets-responsibility-b1.json";
import voaVisitPeruB1 from "./data/voa-visit-peru-b1.json";
import voaWeatherAtWorkB1 from "./data/voa-weather-at-work-b1.json";
import voaStayCalmB1 from "./data/voa-stay-calm-b1.json";
import voaHelpingOutB1 from "./data/voa-helping-out-b1.json";
import voaInCommonB1 from "./data/voa-in-common-b1.json";
import voaKeepMovingB1 from "./data/voa-keep-moving-b1.json";
import voaFindYourWayB1 from "./data/voa-find-your-way-b1.json";
import voaSpeakForYourselfB1 from "./data/voa-speak-for-yourself-b1.json";
import voaFollowInstructionsB1 from "./data/voa-follow-instructions-b1.json";
import voaPoliteRequestsB1 from "./data/voa-polite-requests-b1.json";
import voaReportedSpeechB1 from "./data/voa-reported-speech-b1.json";
import voaCreativeReuseB1 from "./data/voa-creative-reuse-b1.json";
import voaLearnFromMistakesB1 from "./data/voa-learn-from-mistakes-b1.json";
import voaFuturePlansB1 from "./data/voa-future-plans-b1.json";
import voaAdvicePreferencesB1 from "./data/voa-advice-preferences-b1.json";
import voaOfferingHelpB1 from "./data/voa-offering-help-b1.json";
import voaLookAlikesB1 from "./data/voa-look-alikes-b1.json";
import voaFishOutOfWaterB1 from "./data/voa-fish-out-of-water-b1.json";
import voaForTheBirdsB1 from "./data/voa-for-the-birds-b1.json";
import voaWhereTheresSmokeB1 from "./data/voa-where-theres-smoke-b1.json";
import { MODERN_FAMILY_S01E01_HIGHLIGHTS } from "./data/modern-family-s01e01-highlights";
import { MODERN_FAMILY_S01E02_HIGHLIGHTS } from "./data/modern-family-s01e02-highlights";
import { MODERN_FAMILY_S01E03_HIGHLIGHTS } from "./data/modern-family-s01e03-highlights";
import { MODERN_FAMILY_S01E04_HIGHLIGHTS } from "./data/modern-family-s01e04-highlights";
import { MODERN_FAMILY_S01E05_HIGHLIGHTS } from "./data/modern-family-s01e05-highlights";
import { VOA_WORKPLACE_CONVERSATIONS_B1_HIGHLIGHTS } from "./data/voa-workplace-conversations-b1-highlights";
import { VOA_PROJECT_FEEDBACK_B1_HIGHLIGHTS } from "./data/voa-project-feedback-b1-highlights";
import { VOA_PETS_RESPONSIBILITY_B1_HIGHLIGHTS } from "./data/voa-pets-responsibility-b1-highlights";
import { VOA_VISIT_PERU_B1_HIGHLIGHTS } from "./data/voa-visit-peru-b1-highlights";
import { VOA_WEATHER_AT_WORK_B1_HIGHLIGHTS } from "./data/voa-weather-at-work-b1-highlights";
import { VOA_STAY_CALM_B1_HIGHLIGHTS } from "./data/voa-stay-calm-b1-highlights";
import { VOA_HELPING_OUT_B1_HIGHLIGHTS } from "./data/voa-helping-out-b1-highlights";
import { VOA_IN_COMMON_B1_HIGHLIGHTS } from "./data/voa-in-common-b1-highlights";
import { VOA_KEEP_MOVING_B1_HIGHLIGHTS } from "./data/voa-keep-moving-b1-highlights";
import { VOA_FIND_YOUR_WAY_B1_HIGHLIGHTS } from "./data/voa-find-your-way-b1-highlights";
import { VOA_SPEAK_FOR_YOURSELF_B1_HIGHLIGHTS } from "./data/voa-speak-for-yourself-b1-highlights";
import { VOA_FOLLOW_INSTRUCTIONS_B1_HIGHLIGHTS } from "./data/voa-follow-instructions-b1-highlights";
import { VOA_POLITE_REQUESTS_B1_HIGHLIGHTS } from "./data/voa-polite-requests-b1-highlights";
import { VOA_REPORTED_SPEECH_B1_HIGHLIGHTS } from "./data/voa-reported-speech-b1-highlights";
import { VOA_CREATIVE_REUSE_B1_HIGHLIGHTS } from "./data/voa-creative-reuse-b1-highlights";
import { VOA_LEARN_FROM_MISTAKES_B1_HIGHLIGHTS } from "./data/voa-learn-from-mistakes-b1-highlights";
import { VOA_FUTURE_PLANS_B1_HIGHLIGHTS } from "./data/voa-future-plans-b1-highlights";
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
  collectionId: string;
  title: string;
  subtitle: string;
  description: string;
  kind: "word" | "sentence";
  practiceOrder: "random" | "sequential";
  entries: readonly CourseEntry[];
};

export type CourseCollection = {
  id: string;
  label: string;
  title: string;
  subtitle: string;
};

const modernFamilyEntries = modernFamilyS01E01.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E01_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e01/${entry.audio}`,
  })) as CourseEntry[];

const modernFamilyS01E02Entries = modernFamilyS01E02.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E02_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e02/${entry.audio}`,
  })) as CourseEntry[];

const modernFamilyS01E03Entries = modernFamilyS01E03.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E03_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e03/${entry.audio}`,
  })) as CourseEntry[];

const modernFamilyS01E04Entries = modernFamilyS01E04.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E04_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e04/${entry.audio}`,
  })) as CourseEntry[];

const modernFamilyS01E05Entries = modernFamilyS01E05.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    translation: entry.translation,
    highlights: MODERN_FAMILY_S01E05_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/modern-family/s01e05/${entry.audio}`,
  })) as CourseEntry[];

const voaWorkplaceConversationsB1Entries = voaWorkplaceConversationsB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({
    ...entry,
    highlights: VOA_WORKPLACE_CONVERSATIONS_B1_HIGHLIGHTS[entry.id],
    audio: `${basePath}/courses/voa/workplace-conversations-b1/${entry.audio}`,
  })) as CourseEntry[];

const voaProjectFeedbackB1Entries = voaProjectFeedbackB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_PROJECT_FEEDBACK_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/project-feedback-b1/${entry.audio}` })) as CourseEntry[];

const voaPetsResponsibilityB1Entries = voaPetsResponsibilityB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_PETS_RESPONSIBILITY_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/pets-responsibility-b1/${entry.audio}` })) as CourseEntry[];

const voaVisitPeruB1Entries = voaVisitPeruB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_VISIT_PERU_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/visit-peru-b1/${entry.audio}` })) as CourseEntry[];

const voaWeatherAtWorkB1Entries = voaWeatherAtWorkB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_WEATHER_AT_WORK_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/weather-at-work-b1/${entry.audio}` })) as CourseEntry[];

const voaStayCalmB1Entries = voaStayCalmB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_STAY_CALM_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/stay-calm-b1/${entry.audio}` })) as CourseEntry[];

const voaHelpingOutB1Entries = voaHelpingOutB1.entries
  .filter((entry) => entry.learnable && entry.audio)
  .map((entry) => ({ ...entry, highlights: VOA_HELPING_OUT_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/helping-out-b1/${entry.audio}` })) as CourseEntry[];
const voaInCommonB1Entries = voaInCommonB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_IN_COMMON_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/in-common-b1/${entry.audio}` })) as CourseEntry[];
const voaKeepMovingB1Entries = voaKeepMovingB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_KEEP_MOVING_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/keep-moving-b1/${entry.audio}` })) as CourseEntry[];
const voaFindYourWayB1Entries = voaFindYourWayB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_FIND_YOUR_WAY_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/find-your-way-b1/${entry.audio}` })) as CourseEntry[];
const voaSpeakForYourselfB1Entries = voaSpeakForYourselfB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_SPEAK_FOR_YOURSELF_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/speak-for-yourself-b1/${entry.audio}` })) as CourseEntry[];
const voaFollowInstructionsB1Entries = voaFollowInstructionsB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_FOLLOW_INSTRUCTIONS_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/follow-instructions-b1/${entry.audio}` })) as CourseEntry[];
const voaPoliteRequestsB1Entries = voaPoliteRequestsB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_POLITE_REQUESTS_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/polite-requests-b1/${entry.audio}` })) as CourseEntry[];
const voaReportedSpeechB1Entries = voaReportedSpeechB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_REPORTED_SPEECH_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/reported-speech-b1/${entry.audio}` })) as CourseEntry[];
const voaCreativeReuseB1Entries = voaCreativeReuseB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_CREATIVE_REUSE_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/creative-reuse-b1/${entry.audio}` })) as CourseEntry[];
const voaLearnFromMistakesB1Entries = voaLearnFromMistakesB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_LEARN_FROM_MISTAKES_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/learn-from-mistakes-b1/${entry.audio}` })) as CourseEntry[];
const voaFuturePlansB1Entries = voaFuturePlansB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, highlights: VOA_FUTURE_PLANS_B1_HIGHLIGHTS[entry.id], audio: `${basePath}/courses/voa/future-plans-b1/${entry.audio}` })) as CourseEntry[];
const voaAdvicePreferencesB1Entries = voaAdvicePreferencesB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/advice-preferences-b1/${entry.audio}` })) as CourseEntry[];
const voaOfferingHelpB1Entries = voaOfferingHelpB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/offering-help-b1/${entry.audio}` })) as CourseEntry[];
const voaLookAlikesB1Entries = voaLookAlikesB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/look-alikes-b1/${entry.audio}` })) as CourseEntry[];
const voaFishOutOfWaterB1Entries = voaFishOutOfWaterB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/fish-out-of-water-b1/${entry.audio}` })) as CourseEntry[];
const voaForTheBirdsB1Entries = voaForTheBirdsB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/for-the-birds-b1/${entry.audio}` })) as CourseEntry[];
const voaWhereTheresSmokeB1Entries = voaWhereTheresSmokeB1.entries.filter((entry) => entry.learnable && entry.audio).map((entry) => ({ ...entry, audio: `${basePath}/courses/voa/where-theres-smoke-b1/${entry.audio}` })) as CourseEntry[];

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
    collectionId: "ielts",
    title: "IELTS 高频词",
    subtitle: "Academic Word List · 570 words",
    description: "从 570 个高频学术词汇开始，逐词建立听辨和发音记忆。",
    kind: "word",
    practiceOrder: "random",
    entries: ieltsEntries,
  },
  {
    id: "modern-family-s01e01",
    collectionId: "modern-family-s01",
    title: "Modern Family · S01E01",
    subtitle: `Pilot · ${modernFamilyEntries.length} learning sentences`,
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyEntries,
  },
  {
    id: "modern-family-s01e02",
    collectionId: "modern-family-s01",
    title: "Modern Family · S01E02",
    subtitle: `The Bicycle Thief · ${modernFamilyS01E02Entries.length} learning sentences`,
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyS01E02Entries,
  },
  {
    id: "modern-family-s01e03",
    collectionId: "modern-family-s01",
    title: "Modern Family · S01E03",
    subtitle: `Come Fly with Me · ${modernFamilyS01E03Entries.length} learning sentences`,
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyS01E03Entries,
  },
  {
    id: "modern-family-s01e04",
    collectionId: "modern-family-s01",
    title: "Modern Family · S01E04",
    subtitle: `The Incident · ${modernFamilyS01E04Entries.length} learning sentences`,
    description: "用真实对白练习听力、表达和跟读。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyS01E04Entries,
  },
  {
    id: "modern-family-s01e05",
    collectionId: "modern-family-s01",
    title: "Modern Family · S01E05",
    subtitle: `Coal Digger · ${modernFamilyS01E05Entries.length} learning sentences`,
    description: "家庭磨合、表达误会与讨论分歧的自然口语。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: modernFamilyS01E05Entries,
  },
  {
    id: "voa-workplace-conversations-b1",
    collectionId: "voa-level-2",
    title: "Workplace Conversations · B1",
    subtitle: `VOA Learning English · ${voaWorkplaceConversationsB1Entries.length} learning sentences`,
    description: "工作场景的自然对白：会议、协作、求职与面试。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaWorkplaceConversationsB1Entries,
  },
  {
    id: "voa-project-feedback-b1",
    collectionId: "voa-level-2",
    title: "Project Feedback · B1",
    subtitle: `VOA Learning English · ${voaProjectFeedbackB1Entries.length} learning sentences`,
    description: "征求建议、复盘项目、表达观点与追问细节。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaProjectFeedbackB1Entries,
  },
  {
    id: "voa-pets-responsibility-b1",
    collectionId: "voa-level-2",
    title: "Pets & Responsibility · B1",
    subtitle: `VOA Learning English · ${voaPetsResponsibilityB1Entries.length} learning sentences`,
    description: "分享经历、表达责任，以及照看他人的日常英语。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaPetsResponsibilityB1Entries,
  },
  {
    id: "voa-visit-peru-b1",
    collectionId: "voa-level-2",
    title: "Visit to Peru · B1",
    subtitle: `VOA Learning English · ${voaVisitPeruB1Entries.length} learning sentences`,
    description: "邀约、婉拒、表达希望与安排时间的自然口语。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaVisitPeruB1Entries,
  },
  {
    id: "voa-weather-at-work-b1",
    collectionId: "voa-level-2",
    title: "Weather at Work · B1",
    subtitle: `VOA Learning English · ${voaWeatherAtWorkB1Entries.length} learning sentences`,
    description: "工作准备、资源不足、实时信息与团队复盘的自然表达。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaWeatherAtWorkB1Entries,
  },
  {
    id: "voa-stay-calm-b1",
    collectionId: "voa-level-2",
    title: "Stay Calm · B1",
    subtitle: `VOA Learning English · ${voaStayCalmB1Entries.length} learning sentences`,
    description: "表达担心、礼貌沟通、给出条件与保持冷静的自然口语。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaStayCalmB1Entries,
  },
  {
    id: "voa-helping-out-b1",
    collectionId: "voa-level-2",
    title: "Helping Out · B1",
    subtitle: `VOA Learning English · ${voaHelpingOutB1Entries.length} learning sentences`,
    description: "提出帮助、给出建议、表达感受与感谢的实用口语。",
    kind: "sentence",
    practiceOrder: "sequential",
    entries: voaHelpingOutB1Entries,
  },
  { id: "voa-in-common-b1", collectionId: "voa-level-2", title: "In Common · B1", subtitle: `VOA Learning English · ${voaInCommonB1Entries.length} learning sentences`, description: "表达共同点、邀约、坦诚说明与关系感受的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaInCommonB1Entries },
  { id: "voa-keep-moving-b1", collectionId: "voa-level-2", title: "Keep Moving · B1", subtitle: `VOA Learning English · ${voaKeepMovingB1Entries.length} learning sentences`, description: "协商节奏、运动建议、取消安排与求助的自然表达。", kind: "sentence", practiceOrder: "sequential", entries: voaKeepMovingB1Entries },
  { id: "voa-find-your-way-b1", collectionId: "voa-level-2", title: "Find Your Way · B1", subtitle: `VOA Learning English · ${voaFindYourWayB1Entries.length} learning sentences`, description: "失物招领、问路、寻求帮助与回忆习惯的实用口语。", kind: "sentence", practiceOrder: "sequential", entries: voaFindYourWayB1Entries },
  { id: "voa-speak-for-yourself-b1", collectionId: "voa-level-2", title: "Speak for Yourself · B1", subtitle: `VOA Learning English · ${voaSpeakForYourselfB1Entries.length} learning sentences`, description: "任务安排、表达观点、说明规则与投入工作的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaSpeakForYourselfB1Entries },
  { id: "voa-follow-instructions-b1", collectionId: "voa-level-2", title: "Follow Instructions · B1", subtitle: `VOA Learning English · ${voaFollowInstructionsB1Entries.length} learning sentences`, description: "汇报任务、描述意外、表达评价与遵循指示的实用口语。", kind: "sentence", practiceOrder: "sequential", entries: voaFollowInstructionsB1Entries },
  { id: "voa-polite-requests-b1", collectionId: "voa-level-2", title: "Polite Requests · B1", subtitle: `VOA Learning English · ${voaPoliteRequestsB1Entries.length} learning sentences`, description: "礼貌提问、委婉提醒、说明状况与公共场合沟通的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaPoliteRequestsB1Entries },
  { id: "voa-reported-speech-b1", collectionId: "voa-level-2", title: "Reported Speech · B1", subtitle: `VOA Learning English · ${voaReportedSpeechB1Entries.length} learning sentences`, description: "转述信息、确认任务、表达观点与描述体验的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaReportedSpeechB1Entries },
  { id: "voa-creative-reuse-b1", collectionId: "voa-level-2", title: "Creative Reuse · B1", subtitle: `VOA Learning English · ${voaCreativeReuseB1Entries.length} learning sentences`, description: "寻求推荐、介绍店铺、评价物品与表达创作想法的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaCreativeReuseB1Entries },
  { id: "voa-learn-from-mistakes-b1", collectionId: "voa-level-2", title: "Learn from Mistakes · B1", subtitle: `VOA Learning English · ${voaLearnFromMistakesB1Entries.length} learning sentences`, description: "解释误会、给出提醒、解决问题与继续尝试的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaLearnFromMistakesB1Entries },
  { id: "voa-future-plans-b1", collectionId: "voa-level-2", title: "Future Plans · B1", subtitle: `VOA Learning English · ${voaFuturePlansB1Entries.length} learning sentences`, description: "未来安排、表达期待、邀请与讨论日程的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaFuturePlansB1Entries },
  { id: "voa-advice-preferences-b1", collectionId: "voa-level-2", title: "Advice & Preferences · B1", subtitle: `VOA Learning English · ${voaAdvicePreferencesB1Entries.length} learning sentences`, description: "给出建议、表达偏好、描述风险与回应困惑的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaAdvicePreferencesB1Entries },
  { id: "voa-offering-help-b1", collectionId: "voa-level-2", title: "Offering Help · B1", subtitle: `VOA Learning English · ${voaOfferingHelpB1Entries.length} learning sentences`, description: "主动提供帮助、回应感谢、处理问题与风险提醒的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaOfferingHelpB1Entries },
  { id: "voa-look-alikes-b1", collectionId: "voa-level-2", title: "Look-alikes · B1", subtitle: `VOA Learning English · ${voaLookAlikesB1Entries.length} learning sentences`, description: "描述相似、表达判断、邀请他人与处理人际互动的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaLookAlikesB1Entries },
  { id: "voa-fish-out-of-water-b1", collectionId: "voa-level-2", title: "Fish out of Water · B1", subtitle: `VOA Learning English · ${voaFishOutOfWaterB1Entries.length} learning sentences`, description: "邀约与婉拒、船屋生活、表达担忧和礼貌离开的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaFishOutOfWaterB1Entries },
  { id: "voa-for-the-birds-b1", collectionId: "voa-level-2", title: "For the Birds · B1", subtitle: `VOA Learning English · ${voaForTheBirdsB1Entries.length} learning sentences`, description: "表达失望、说明职责、提出猜想，以及 have to 和 ought to 的自然口语。", kind: "sentence", practiceOrder: "sequential", entries: voaForTheBirdsB1Entries },
  { id: "voa-where-theres-smoke-b1", collectionId: "voa-level-2", title: "Where There's Smoke... · B1", subtitle: `VOA Learning English · ${voaWhereTheresSmokeB1Entries.length} learning sentences`, description: "消防安全、紧急撤离、条件句与明确安全指令的实用口语。", kind: "sentence", practiceOrder: "sequential", entries: voaWhereTheresSmokeB1Entries },
];

export const COURSE_COLLECTIONS: readonly CourseCollection[] = [
  { id: "ielts", label: "WORD COURSE", title: "IELTS 高频词", subtitle: "Academic Word List · 570 words" },
  { id: "modern-family-s01", label: "DIALOGUE COURSE", title: "摩登家庭 · 第一季", subtitle: "5 集对白课程" },
  { id: "voa-level-2", label: "DIALOGUE COURSE", title: "VOA · Level 2", subtitle: "23 节实用口语课程 · B1" },
];

export const IELTS_HIGH_FREQUENCY_COURSE = COURSE_PACKAGES[0];
export const MODERN_FAMILY_S01E01_COURSE = COURSE_PACKAGES[1];
export const MODERN_FAMILY_S01E02_COURSE = COURSE_PACKAGES[2];
export const MODERN_FAMILY_S01E03_COURSE = COURSE_PACKAGES[3];
export const MODERN_FAMILY_S01E04_COURSE = COURSE_PACKAGES[4];
export const DEFAULT_COURSE = MODERN_FAMILY_S01E01_COURSE;
