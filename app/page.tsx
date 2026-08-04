"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  COURSE_COLLECTIONS,
  COURSE_PACKAGES,
  DEFAULT_COURSE,
  MODERN_FAMILY_S01E01_COURSE,
  type CourseEntry,
} from "./courses";
import { WORDS } from "./words";
import { hasEnoughSpeechEvidence, scoreRepeatTranscript } from "./repeat-scorer";

const MAX_STUDY_COUNT = 3;
const AUTO_ADVANCE_MS = 700;
const LISTEN_AUTOPLAY_DELAY_MS = 500;
const PLAYBACK_TIMEOUT_MS = 8_000;
const SPEAK_TIMEOUT_MS = 6_000;
const SPEAKING_TIMEOUT_MS = 6_000;
const SCORING_TIMEOUT_MS = 6_000;
const MIN_SPEECH_MS = 350;
const SEGMENT_SETTLE_MS = 700;
const STARTUP_MAX_WAIT_MS = 650;
const PANEL_CLOSE_MS = 240;
const USER_ID_KEY = "word-loop-user-id";
const PENDING_PROGRESS_KEY = "word-loop-pending-progress";
// Included in the rendered shell so each operational release gets a distinct
// content-hashed client entrypoint, even when only infrastructure changed.
const WEB_BUILD_REVISION = "2026-08-04-static-assets";
const APP_BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

function appPath(path: string) {
  return `${APP_BASE_PATH}${path}`;
}

function pendingProgressStorageKey(userId: string, studyMode: StudyMode) {
  return `${PENDING_PROGRESS_KEY}:${studyMode}:${userId}`;
}

function anonymousUserId() {
  let userId = localStorage.getItem(USER_ID_KEY);
  if (!userId) {
    userId = typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    localStorage.setItem(USER_ID_KEY, userId);
  }
  return userId;
}

type ProgressMap = Record<string, number>;
type StudyMode = "listen" | "repeat";
type PendingProgressEvent = {
  id: string;
  userId: string;
  mode: StudyMode;
  courseId?: string;
  itemId?: string;
  word?: string;
  completionCourseId?: string;
  mastered?: boolean;
  // Retain already queued events from the short-lived numeric implementation.
  targetStudyCount?: number;
};
type TextVisibilityMode = "full" | "focus" | "hidden";
type StartupState = "idle" | "restoring" | "syncing";
type RepeatState =
  | "idle"
  | "connecting"
  | "ready"
  | "playing"
  | "speak"
  | "speaking"
  | "scoring"
  | "passed"
  | "paused"
  | "retry"
  | "error";

function readPendingProgressEvents(userId: string, studyMode: StudyMode): PendingProgressEvent[] {
  try {
    const value = JSON.parse(localStorage.getItem(pendingProgressStorageKey(userId, studyMode)) ?? "[]") as unknown;
    return Array.isArray(value) ? value.filter((event): event is PendingProgressEvent => (
      typeof event === "object" && event !== null && typeof event.id === "string"
    )) : [];
  } catch {
    return [];
  }
}

function writePendingProgressEvents(userId: string, studyMode: StudyMode, events: PendingProgressEvent[]) {
  localStorage.setItem(pendingProgressStorageKey(userId, studyMode), JSON.stringify(events));
}

function pendingEventId() {
  return typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function applyPendingProgress(
  confirmedProgress: ProgressMap,
  events: readonly PendingProgressEvent[],
  kind: "word" | "sentence",
  courseId?: string,
) {
  const next = { ...confirmedProgress };
  for (const event of events) {
    const itemId = kind === "word" ? event.word : event.courseId === courseId ? event.itemId : undefined;
    if (itemId) {
      next[itemId] = event.mastered === true || event.targetStudyCount === MAX_STUDY_COUNT
        ? MAX_STUDY_COUNT
        : Math.min(MAX_STUDY_COUNT, (next[itemId] ?? 0) + 1);
    }
  }
  return next;
}

const PALETTES = [
  ["#f3f0e8", "#1e3a34", "#d4562b"],
  ["#f5d547", "#282044", "#e85b44"],
  ["#dfecff", "#183565", "#f06449"],
  ["#f8d9df", "#4b1934", "#157d6a"],
  ["#d8eee3", "#173b33", "#c84e34"],
  ["#26233e", "#f4ead7", "#f3bd4f"],
] as const;

function randomIndex(length: number, except = -1) {
  if (length < 2) return 0;
  let next = Math.floor(Math.random() * length);
  while (next === except) next = Math.floor(Math.random() * length);
  return next;
}

function eligibleIndex(progress: ProgressMap, except = -1) {
  const available = WORDS.flatMap(([word], index) =>
    index !== except && (progress[word] ?? 0) < MAX_STUDY_COUNT ? [index] : [],
  );
  return available.length ? available[Math.floor(Math.random() * available.length)] : -1;
}

function eligibleSentenceIndex(
  entries: readonly CourseEntry[],
  progress: ProgressMap,
  except = -1,
  practiceOrder: "random" | "sequential" = "random",
) {
  const available = entries.flatMap((entry, index) =>
    index !== except && (progress[entry.id] ?? 0) < MAX_STUDY_COUNT ? [index] : [],
  );
  if (practiceOrder === "sequential") {
    return available.find((index) => index > except) ?? available[0] ?? -1;
  }
  return available.length ? available[Math.floor(Math.random() * available.length)] : -1;
}

function initialEligibleSentenceIndex(entries: readonly CourseEntry[], progress: ProgressMap) {
  const available = entries.flatMap((entry, index) =>
    (progress[entry.id] ?? 0) < MAX_STUDY_COUNT ? [index] : [],
  );
  // A new course always starts at the first sentence in manifest order.
  return available[0] ?? -1;
}

function resumeSentenceIndex(
  entries: readonly CourseEntry[],
  progress: ProgressMap,
  resumeItemId: string | null | undefined,
) {
  const index = resumeItemId ? entries.findIndex((entry) => entry.id === resumeItemId) : -1;
  if (index >= 0 && (progress[entries[index].id] ?? 0) < MAX_STUDY_COUNT) return index;
  return initialEligibleSentenceIndex(entries, progress);
}

function sentenceResumeStorageKey(userId: string, mode: StudyMode, courseId: string) {
  return `word-loop-resume:${userId}:${mode}:${courseId}`;
}

function courseIsComplete(entries: readonly CourseEntry[], progress: ProgressMap) {
  return entries.length > 0 && entries.every((entry) => (progress[entry.id] ?? 0) >= MAX_STUDY_COUNT);
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function maskWord(value: string) {
  return "•".repeat(Array.from(value).length);
}

function renderMaskedText(text: string, keyPrefix: string) {
  return text.split(/([A-Za-z]+(?:'[A-Za-z]+)?)/g).map((part, index) => (
    /[A-Za-z]/.test(part)
      ? <span className="study-text-placeholder" key={`${keyPrefix}-${index}`}>{maskWord(part)}</span>
      : part
  ));
}

function renderStudyText(
  text: string,
  visibilityMode: TextVisibilityMode,
  highlights?: readonly string[],
) {
  if (visibilityMode === "hidden") {
    return renderMaskedText(text, "hidden");
  }

  if (!highlights?.length) {
    return visibilityMode === "focus" ? renderMaskedText(text, "focus") : text;
  }

  const marked = new Set(highlights.map((highlight) => highlight.toLocaleLowerCase()));
  const matcher = new RegExp(`(${highlights.map(escapeRegExp).join("|")})`, "gi");
  return text.split(matcher).map((part, index) => (
    marked.has(part.toLocaleLowerCase())
      ? <span className="learning-highlight" key={`${part}-${index}`}>{part}</span>
      : visibilityMode === "focus"
        ? renderMaskedText(part, `focus-${index}`)
        : part
  ));
}

function playFeedbackTone(context: AudioContext, passed: boolean) {
  const notes = passed ? [660, 880] : [420, 260];
  const startedAt = context.currentTime;

  for (const [index, frequency] of notes.entries()) {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    const offset = index * (passed ? 0.09 : 0.12);
    const duration = passed ? 0.12 : 0.16;

    oscillator.type = passed ? "sine" : "triangle";
    oscillator.frequency.setValueAtTime(frequency, startedAt + offset);
    gain.gain.setValueAtTime(0.0001, startedAt + offset);
    gain.gain.exponentialRampToValueAtTime(passed ? 0.07 : 0.12, startedAt + offset + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, startedAt + offset + duration);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(startedAt + offset);
    oscillator.stop(startedAt + offset + duration);
  }
}

function playMasteryCue(context: AudioContext) {
  const startedAt = context.currentTime;
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = "sine";
  oscillator.frequency.setValueAtTime(740, startedAt);
  gain.gain.setValueAtTime(0.0001, startedAt);
  gain.gain.exponentialRampToValueAtTime(0.05, startedAt + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, startedAt + 0.115);
  oscillator.connect(gain).connect(context.destination);
  oscillator.start(startedAt);
  oscillator.stop(startedAt + 0.115);
}

function playRecordingCue(context: AudioContext) {
  const startedAt = context.currentTime;
  for (const [index, frequency] of [520, 700].entries()) {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    const offset = index * 0.07;
    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(frequency, startedAt + offset);
    gain.gain.setValueAtTime(0.0001, startedAt + offset);
    gain.gain.exponentialRampToValueAtTime(0.045, startedAt + offset + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, startedAt + offset + 0.1);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(startedAt + offset);
    oscillator.stop(startedAt + offset + 0.1);
  }
}

function playToneWhenReady(context: AudioContext | null, play: (audio: AudioContext) => void) {
  if (!context || context.state === "closed") return;
  const start = () => {
    if (context.state === "running") play(context);
  };
  if (context.state === "suspended") {
    void context.resume().then(start).catch(() => undefined);
    return;
  }
  start();
}

function repeatStatusLabel(state: RepeatState) {
  switch (state) {
    case "connecting":
      return "CONNECTING";
    case "ready":
      return "READY";
    case "playing":
      return "LISTENING";
    case "speak":
      return "SPEAKING";
    case "speaking":
      return "SPEAKING";
    case "scoring":
      return "CHECKING";
    case "passed":
      return "GREAT";
    case "paused":
      return "PAUSED";
    case "retry":
      return "TRY AGAIN";
    case "error":
      return "TRY AGAIN";
    default:
      return "STANDBY";
  }
}

function repeatStatusHint(state: RepeatState) {
  switch (state) {
    case "connecting":
      return "正在准备麦克风";
    case "ready":
      return "听完示范后开始跟读";
    case "playing":
      return "先听一遍标准发音";
    case "speak":
      return "请清晰地跟读";
    case "speaking":
      return "正在听你发音";
    case "scoring":
      return "正在分析这次发音";
    case "passed":
      return "这次发音通过了";
    case "paused":
      return "准备好后继续练习";
    case "retry":
      return "请再读一次";
    case "error":
      return "请再读一次";
    default:
      return "跟读模式已准备好";
  }
}

export default function Home() {
  // Keep the first server and client render identical. Randomizing here caused
  // hydration to rebuild the page differently across browsers.
  const [wordIndex, setWordIndex] = useState(0);
  const [nextWordIndex, setNextWordIndex] = useState(1);
  const [sentenceIndex, setSentenceIndex] = useState(0);
  const [nextSentenceIndex, setNextSentenceIndex] = useState(1);
  const [paletteIndex, setPaletteIndex] = useState(0);
  const [activeCourseId, setActiveCourseId] = useState(DEFAULT_COURSE.id);
  const [studyMode, setStudyMode] = useState<StudyMode>("repeat");
  const [activated, setActivated] = useState(false);
  const [progress, setProgress] = useState<ProgressMap>({});
  const [sentenceProgress, setSentenceProgress] = useState<ProgressMap>({});
  const [courseCompletionCounts, setCourseCompletionCounts] = useState<ProgressMap>({});
  const [panelOpen, setPanelOpen] = useState(false);
  const [coursePickerOpen, setCoursePickerOpen] = useState(false);
  const [panelClosing, setPanelClosing] = useState(false);
  const [coursePickerClosing, setCoursePickerClosing] = useState(false);
  const [restartPromptCourseId, setRestartPromptCourseId] = useState<string | null>(null);
  const [completionPromptCourseId, setCompletionPromptCourseId] = useState<string | null>(null);
  const [restartPromptError, setRestartPromptError] = useState("");
  const [expandedCourseCollectionId, setExpandedCourseCollectionId] = useState(DEFAULT_COURSE.collectionId);
  const [search, setSearch] = useState("");
  const [courseSearch, setCourseSearch] = useState("");
  const [repeatState, setRepeatState] = useState<RepeatState>("idle");
  const [repeatMessage, setRepeatMessage] = useState("READY");
  const [repeatTranscript, setRepeatTranscript] = useState("");
  const [textVisibilityMode, setTextVisibilityMode] = useState<TextVisibilityMode>("full");
  const [listenAutoPlay, setListenAutoPlay] = useState(false);
  const [activeUserId, setActiveUserId] = useState("");
  const [startupState, setStartupState] = useState<StartupState>("idle");
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const preloadedAudioRef = useRef<HTMLAudioElement | null>(null);
  const dataChannelRef = useRef<RTCDataChannel | null>(null);
  const peerConnectionRef = useRef<RTCPeerConnection | null>(null);
  const repeatAdvanceTimerRef = useRef<number | null>(null);
  const completionPromptTimerRef = useRef<number | null>(null);
  const listenAutoPlayTimerRef = useRef<number | null>(null);
  const hiddenPauseTimerRef = useRef<number | null>(null);
  const repeatAdvanceTargetRef = useRef<{ index: number; sentenceMode: boolean; turnId: number } | null>(null);
  const repeatRetryTimerRef = useRef<number | null>(null);
  const repeatPlaybackTimerRef = useRef<number | null>(null);
  const repeatSpeakTimerRef = useRef<number | null>(null);
  const repeatSpeakingTimerRef = useRef<number | null>(null);
  const repeatScoringTimerRef = useRef<number | null>(null);
  const repeatSegmentSettleTimerRef = useRef<number | null>(null);
  const sessionPromiseRef = useRef<Promise<void> | null>(null);
  const repeatTurnIdRef = useRef(0);
  const activeRepeatTurnRef = useRef(0);
  const repeatListeningTurnRef = useRef<number | null>(null);
  const beginRepeatTurnRef = useRef<(targetIndex: number) => void>(() => undefined);
  const repeatTrackRef = useRef<MediaStreamTrack | null>(null);
  const feedbackAudioContextRef = useRef<AudioContext | null>(null);
  const repeatListeningArmedRef = useRef(false);
  const repeatSpeechItemIdRef = useRef<string | null>(null);
  const repeatSpeechItemIdsRef = useRef(new Set<string>());
  const repeatTranscriptPartsRef = useRef(new Map<string, string>());
  const repeatSpeechInProgressRef = useRef(false);
  const repeatSpeechStartedAtRef = useRef(0);
  const repeatWordRef = useRef("");
  const repeatStreamRef = useRef<MediaStream | null>(null);
  const userIdRef = useRef("");
  const progressRef = useRef<ProgressMap>({});
  const sentenceProgressRef = useRef<ProgressMap>({});
  const confirmedWordProgressRef = useRef<ProgressMap>({});
  const confirmedSentenceProgressRef = useRef<ProgressMap>({});
  const pendingProgressRef = useRef<PendingProgressEvent[]>([]);
  const progressSyncInFlightRef = useRef(false);
  const studyModeRef = useRef<StudyMode>(studyMode);
  const activeCourseIdRef = useRef(activeCourseId);
  const nextWordIndexRef = useRef(nextWordIndex);
  const wordIndexRef = useRef(wordIndex);
  const nextSentenceIndexRef = useRef(nextSentenceIndex);
  const sentenceIndexRef = useRef(sentenceIndex);
  const sentenceEntriesRef = useRef<readonly CourseEntry[]>(MODERN_FAMILY_S01E01_COURSE.entries);
  const activeCourseKindRef = useRef<"word" | "sentence">(DEFAULT_COURSE.kind);
  const currentIndexRef = useRef(wordIndex);
  const nextIndexRef = useRef(nextWordIndex);
  const nextRef = useRef<() => void>(() => undefined);
  const courseSwitchRequestRef = useRef(0);
  const panelSwipeRef = useRef<{ pointerId: number; x: number; y: number } | null>(null);
  const coursePickerCloseTimerRef = useRef<number | null>(null);
  const progressPanelCloseTimerRef = useRef<number | null>(null);
  const hydratedUserIdRef = useRef("");
  const activatedRef = useRef(activated);
  const pendingActivationRef = useRef(false);
  const activateRef = useRef<() => void>(() => undefined);
  const listenAutoPlayRef = useRef(false);
  const [word, meaning, , phonetic] = WORDS[wordIndex];
  const activeCourse = COURSE_PACKAGES.find((course) => course.id === activeCourseId) ?? DEFAULT_COURSE;
  const sentenceMode = activeCourse.kind === "sentence";
  const sentenceCourse = sentenceMode ? activeCourse : MODERN_FAMILY_S01E01_COURSE;
  const sentencePracticeOrder = sentenceCourse.practiceOrder;
  const sentencePracticeOrderRef = useRef(sentencePracticeOrder);
  // A course switch and its follow-up effects can briefly render with the
  // previous course's index. Keep that transient state inside the new course
  // instead of reading past its entries (for example, from a 220-sentence
  // a long course into a much shorter one).
  const sentenceIndexInCourse = sentenceCourse.entries[sentenceIndex] ? sentenceIndex : 0;
  const sentence = sentenceCourse.entries[sentenceIndexInCourse];
  const currentItem = sentenceMode
    ? { id: sentence.id, text: sentence.text, meaning: sentence.translation, phonetic: "", audio: sentence.audio, highlights: sentence.highlights }
    : { id: word, text: word, meaning, phonetic, audio: appPath(`/audio/${word}.m4a`) };
  const currentIndex = sentenceMode ? sentenceIndexInCourse : wordIndex;
  const nextIndex = sentenceMode ? nextSentenceIndex : nextWordIndex;
  const nextAudio = nextIndex < 0
    ? null
    : sentenceMode ? sentenceCourse.entries[nextIndex]?.audio ?? null : appPath(`/audio/${WORDS[nextIndex][0]}.m4a`);
  const activeProgress = sentenceMode ? sentenceProgress : progress;
  const activeEntriesCount = activeCourse.entries.length;
  const [background, ink, accent] = PALETTES[paletteIndex];

  const refreshWordProgress = useCallback(() => {
    const next = applyPendingProgress(confirmedWordProgressRef.current, pendingProgressRef.current, "word");
    progressRef.current = next;
    setProgress(next);
  }, []);

  const refreshSentenceProgress = useCallback((courseId: string) => {
    const next = applyPendingProgress(confirmedSentenceProgressRef.current, pendingProgressRef.current, "sentence", courseId);
    sentenceProgressRef.current = next;
    setSentenceProgress(next);
  }, []);

  const persistSentenceResume = useCallback((courseId: string, entryId: string | null) => {
    const userId = userIdRef.current;
    if (!userId) return;
    const key = sentenceResumeStorageKey(userId, studyModeRef.current, courseId);
    if (entryId) localStorage.setItem(key, entryId);
    else localStorage.removeItem(key);
    void fetch(appPath("/api/progress"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId,
        mode: studyModeRef.current,
        courseId,
        itemId: entryId,
        updateResumePosition: true,
      }),
    });
  }, []);

  const flushPendingProgress = useCallback(async (userId: string, mode: StudyMode) => {
    if (progressSyncInFlightRef.current || !navigator.onLine) return;
    progressSyncInFlightRef.current = true;
    try {
      while (true) {
        const event = readPendingProgressEvents(userId, mode)[0];
        if (!event) return;
        const response = await fetch(appPath("/api/progress"), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId: event.userId,
            mode: event.mode,
            clientEventId: event.id,
            ...(event.completionCourseId ? { courseId: event.completionCourseId, completeCourse: true } : {
              ...(event.mastered || event.targetStudyCount === MAX_STUDY_COUNT ? { markMastered: true } : {}),
              ...(event.word ? { word: event.word } : { courseId: event.courseId, itemId: event.itemId }),
            }),
          }),
        });
        if (!response.ok) return;
        const result = await response.json() as { word?: string; itemId?: string; studyCount?: number; courseId?: string; completionCount?: number };
        const remaining = readPendingProgressEvents(userId, mode).filter((pending) => pending.id !== event.id);
        writePendingProgressEvents(userId, mode, remaining);

        if (userIdRef.current !== userId || studyModeRef.current !== mode) continue;
        pendingProgressRef.current = remaining;
        if (event.completionCourseId && result.courseId && result.completionCount !== undefined) {
          setCourseCompletionCounts((current) => ({ ...current, [result.courseId!]: result.completionCount! }));
        } else if (event.word && result.word && result.studyCount !== undefined) {
          confirmedWordProgressRef.current = {
            ...confirmedWordProgressRef.current,
            [event.word]: Math.max(confirmedWordProgressRef.current[event.word] ?? 0, result.studyCount),
          };
          refreshWordProgress();
        } else if (event.itemId && event.courseId && result.itemId && result.studyCount !== undefined) {
          confirmedSentenceProgressRef.current = {
            ...confirmedSentenceProgressRef.current,
            [event.itemId]: Math.max(confirmedSentenceProgressRef.current[event.itemId] ?? 0, result.studyCount),
          };
          if (activeCourseIdRef.current === event.courseId) refreshSentenceProgress(event.courseId);
        }
      }
    } finally {
      progressSyncInFlightRef.current = false;
    }
  }, [refreshSentenceProgress, refreshWordProgress]);
  const currentStudyCount = activeProgress[currentItem.id] ?? 0;
  const manualNextIndex = nextIndex >= 0
    ? nextIndex
    : sentenceMode
      ? eligibleSentenceIndex(sentenceCourse.entries, sentenceProgress, sentenceIndex, sentencePracticeOrder)
      : eligibleIndex(progress, wordIndex);
  const activeCourseComplete = sentenceMode && courseIsComplete(sentenceCourse.entries, sentenceProgress);
  const nextDisabled = manualNextIndex < 0 && !activeCourseComplete;
  const totalStudies = Object.values(activeProgress).reduce((sum, count) => sum + count, 0);
  const completedWords = sentenceMode
    ? sentenceCourse.entries.filter((entry) => (sentenceProgress[entry.id] ?? 0) >= MAX_STUDY_COUNT).length
    : WORDS.filter(([entry]) => (progress[entry] ?? 0) >= MAX_STUDY_COUNT).length;
  const filteredWords = WORDS.filter(([entry, entryMeaning]) =>
    `${entry} ${entryMeaning}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  const filteredCourses = COURSE_PACKAGES.filter((course) =>
    `${course.title} ${course.subtitle} ${course.description}`.toLowerCase().includes(courseSearch.trim().toLowerCase()),
  );
  const filteredCourseCollections = COURSE_COLLECTIONS.map((collection) => ({
    ...collection,
    courses: filteredCourses.filter((course) => course.collectionId === collection.id),
  })).filter((collection) => collection.courses.length > 0);
  const filteredSentences = sentenceCourse.entries.filter((entry) =>
    `${entry.text} ${entry.translation}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  const repeatLabel = repeatStatusLabel(repeatState);
  const repeatHint = repeatStatusHint(repeatState);
  const showRepeatTranscript = Boolean(repeatTranscript) && (repeatState === "retry" || repeatState === "error");
  const visibilityControlModes: readonly TextVisibilityMode[] = sentenceMode
    ? ["full", "focus", "hidden"]
    : ["full", "hidden"];
  const nextTextVisibilityMode = visibilityControlModes[
    (visibilityControlModes.indexOf(textVisibilityMode) + 1) % visibilityControlModes.length
  ];
  const visibilityAriaLabel = textVisibilityMode === "full"
    ? `Hide ${sentenceMode ? "non-highlighted words" : "word"}`
    : textVisibilityMode === "focus"
      ? "Hide all words"
      : `Show ${sentenceMode ? "sentence" : "word"}`;

  const beginPanelSwipe = useCallback((event: React.PointerEvent<HTMLElement>) => {
    if (event.pointerType === "mouse") return;
    panelSwipeRef.current = { pointerId: event.pointerId, x: event.clientX, y: event.clientY };
  }, []);

  const endPanelSwipe = useCallback((event: React.PointerEvent<HTMLElement>, direction: "left" | "right", close: () => void) => {
    const start = panelSwipeRef.current;
    panelSwipeRef.current = null;
    if (!start || start.pointerId !== event.pointerId) return;
    const horizontalDistance = event.clientX - start.x;
    const verticalDistance = event.clientY - start.y;
    const movedTowardEdge = direction === "left" ? horizontalDistance < -72 : horizontalDistance > 72;
    if (movedTowardEdge && Math.abs(horizontalDistance) > Math.abs(verticalDistance)) close();
  }, []);

  const clearPanelSwipe = useCallback(() => {
    panelSwipeRef.current = null;
  }, []);

  const closeCoursePicker = useCallback(() => {
    if (!coursePickerOpen || coursePickerClosing) return;
    setCoursePickerClosing(true);
    if (coursePickerCloseTimerRef.current !== null) window.clearTimeout(coursePickerCloseTimerRef.current);
    coursePickerCloseTimerRef.current = window.setTimeout(() => {
      coursePickerCloseTimerRef.current = null;
      setCoursePickerOpen(false);
      setCoursePickerClosing(false);
    }, PANEL_CLOSE_MS);
  }, [coursePickerClosing, coursePickerOpen]);

  const closeProgressPanel = useCallback(() => {
    if (!panelOpen || panelClosing) return;
    setPanelClosing(true);
    if (progressPanelCloseTimerRef.current !== null) window.clearTimeout(progressPanelCloseTimerRef.current);
    progressPanelCloseTimerRef.current = window.setTimeout(() => {
      progressPanelCloseTimerRef.current = null;
      setPanelOpen(false);
      setPanelClosing(false);
    }, PANEL_CLOSE_MS);
  }, [panelClosing, panelOpen]);

  const openCoursePicker = useCallback(() => {
    if (coursePickerCloseTimerRef.current !== null) window.clearTimeout(coursePickerCloseTimerRef.current);
    coursePickerCloseTimerRef.current = null;
    setCoursePickerClosing(false);
    setCoursePickerOpen(true);
  }, []);

  const openProgressPanel = useCallback(() => {
    if (progressPanelCloseTimerRef.current !== null) window.clearTimeout(progressPanelCloseTimerRef.current);
    progressPanelCloseTimerRef.current = null;
    setPanelClosing(false);
    setPanelOpen(true);
  }, []);

  const stopListening = useCallback(() => {
    if (repeatTrackRef.current) repeatTrackRef.current.enabled = false;
    repeatListeningArmedRef.current = false;
    repeatSpeechItemIdRef.current = null;
    repeatSpeechInProgressRef.current = false;
  }, []);

  const prepareFeedbackAudio = useCallback(() => {
    const context = feedbackAudioContextRef.current ?? new AudioContext();
    feedbackAudioContextRef.current = context;
    if (context.state === "suspended") void context.resume();
  }, []);

  const clearRepeatAdvanceTimer = useCallback(() => {
    if (repeatAdvanceTimerRef.current !== null) {
      window.clearTimeout(repeatAdvanceTimerRef.current);
      repeatAdvanceTimerRef.current = null;
    }
  }, []);

  const clearCompletionPromptTimer = useCallback(() => {
    if (completionPromptTimerRef.current !== null) {
      window.clearTimeout(completionPromptTimerRef.current);
      completionPromptTimerRef.current = null;
    }
  }, []);

  const scheduleCompletionPrompt = useCallback((courseId: string) => {
    clearCompletionPromptTimer();
    completionPromptTimerRef.current = window.setTimeout(() => {
      completionPromptTimerRef.current = null;
      if (activeCourseIdRef.current === courseId) setCompletionPromptCourseId(courseId);
    }, 800);
  }, [clearCompletionPromptTimer]);

  const clearListenAutoPlayTimer = useCallback(() => {
    if (listenAutoPlayTimerRef.current !== null) {
      window.clearTimeout(listenAutoPlayTimerRef.current);
      listenAutoPlayTimerRef.current = null;
    }
  }, []);

  const clearHiddenPauseTimer = useCallback(() => {
    if (hiddenPauseTimerRef.current !== null) {
      window.clearTimeout(hiddenPauseTimerRef.current);
      hiddenPauseTimerRef.current = null;
    }
  }, []);

  const clearRepeatRetryTimer = useCallback(() => {
    if (repeatRetryTimerRef.current !== null) {
      window.clearTimeout(repeatRetryTimerRef.current);
      repeatRetryTimerRef.current = null;
    }
  }, []);

  const clearRepeatPlaybackTimer = useCallback(() => {
    if (repeatPlaybackTimerRef.current !== null) {
      window.clearTimeout(repeatPlaybackTimerRef.current);
      repeatPlaybackTimerRef.current = null;
    }
  }, []);

  const clearRepeatPhaseTimers = useCallback(() => {
    for (const timerRef of [repeatSpeakTimerRef, repeatSpeakingTimerRef, repeatScoringTimerRef, repeatSegmentSettleTimerRef]) {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    }
  }, []);

  const isActiveRepeatTurn = useCallback((turnId: number) => (
    activeRepeatTurnRef.current === turnId
  ), []);

  const scheduleRepeatRetry = useCallback((turnId: number, delay = 1_000, withFailureTone = false) => {
    if (!isActiveRepeatTurn(turnId)) return;
    repeatAdvanceTargetRef.current = null;
    clearRepeatAdvanceTimer();
    clearRepeatPlaybackTimer();
    clearRepeatRetryTimer();
    clearRepeatPhaseTimers();
    stopListening();
    repeatListeningTurnRef.current = null;
    if (withFailureTone) {
      playToneWhenReady(feedbackAudioContextRef.current, (audio) => playFeedbackTone(audio, false));
    }
    setRepeatState("error");
    setRepeatMessage("RETRYING");
    repeatRetryTimerRef.current = window.setTimeout(() => {
      if (isActiveRepeatTurn(turnId)) beginRepeatTurnRef.current(currentIndexRef.current);
    }, delay);
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, isActiveRepeatTurn, stopListening]);

  useEffect(() => {
    const identityTimer = window.setTimeout(() => {
      setActiveUserId(anonymousUserId());
    }, 0);
    return () => window.clearTimeout(identityTimer);
  }, []);

  useEffect(() => {
    studyModeRef.current = studyMode;
  }, [studyMode]);

  useEffect(() => {
    activeCourseIdRef.current = activeCourseId;
    sentencePracticeOrderRef.current = sentencePracticeOrder;
  }, [activeCourseId, sentencePracticeOrder]);

  useEffect(() => {
    activatedRef.current = activated;
  }, [activated]);

  const restoreRecentCourse = useCallback((courseId: string) => {
    const course = COURSE_PACKAGES.find((item) => item.id === courseId);
    if (!course || course.id === activeCourseIdRef.current) return;

    activeCourseIdRef.current = course.id;
    activeCourseKindRef.current = course.kind;
    sentencePracticeOrderRef.current = course.practiceOrder;
    if (course.kind === "sentence") {
      const initialSentence = initialEligibleSentenceIndex(course.entries, {});
      sentenceEntriesRef.current = course.entries;
      sentenceIndexRef.current = initialSentence;
      currentIndexRef.current = initialSentence;
      setSentenceIndex(initialSentence);
      setNextSentenceIndex(eligibleSentenceIndex(course.entries, {}, initialSentence, course.practiceOrder));
    } else {
      currentIndexRef.current = wordIndexRef.current;
    }
    setActiveCourseId(course.id);
  }, []);

  useEffect(() => {
    if (!activeUserId) return;
    if (hydratedUserIdRef.current === activeUserId) return;
    let activationTimeout: number | null = null;
    const hydrateTimer = window.setTimeout(() => {
      if (hydratedUserIdRef.current === activeUserId) return;
      hydratedUserIdRef.current = activeUserId;
      userIdRef.current = activeUserId;
      const locallyRememberedCourseId = localStorage.getItem(`word-loop-last-course:${activeUserId}`);
      let bootstrapCourse = COURSE_PACKAGES.find((course) => course.id === activeCourseIdRef.current) ?? DEFAULT_COURSE;
      if (!activatedRef.current && courseSwitchRequestRef.current === 0 && locallyRememberedCourseId && COURSE_PACKAGES.some((course) => course.id === locallyRememberedCourseId) && locallyRememberedCourseId !== activeCourseIdRef.current) {
        if (pendingActivationRef.current) setStartupState("restoring");
        restoreRecentCourse(locallyRememberedCourseId);
        bootstrapCourse = COURSE_PACKAGES.find((course) => course.id === locallyRememberedCourseId) ?? bootstrapCourse;
      }
      const bootstrapSentenceMode = bootstrapCourse.kind === "sentence";
      const bootstrapStudyMode = studyModeRef.current;
      let courseSnapshotSettled = !bootstrapSentenceMode;
      pendingProgressRef.current = readPendingProgressEvents(activeUserId, bootstrapStudyMode);
      confirmedWordProgressRef.current = {};
      confirmedSentenceProgressRef.current = {};
      refreshWordProgress();
      refreshSentenceProgress(bootstrapCourse.id);
      const initialWord = randomIndex(WORDS.length);
      const firstEligibleSentence = initialEligibleSentenceIndex(
        bootstrapCourse.entries,
        sentenceProgressRef.current,
      );
      const initialSentence = firstEligibleSentence >= 0 ? firstEligibleSentence : 0;
      setWordIndex(initialWord);
      setNextWordIndex(eligibleIndex(progressRef.current, initialWord));
      sentenceEntriesRef.current = bootstrapCourse.entries;
      sentenceIndexRef.current = initialSentence;
      currentIndexRef.current = bootstrapSentenceMode ? initialSentence : initialWord;
      setSentenceIndex(initialSentence);
      setNextSentenceIndex(eligibleSentenceIndex(
        bootstrapCourse.entries,
        sentenceProgressRef.current,
        initialSentence,
        bootstrapCourse.practiceOrder,
      ));
      setPaletteIndex(randomIndex(PALETTES.length));

      const mergeWordProgress = (remoteProgress: Array<{ word: string; studyCount: number }>) => {
      if (userIdRef.current !== activeUserId || studyModeRef.current !== bootstrapStudyMode) return;
      for (const item of remoteProgress) {
        confirmedWordProgressRef.current[item.word] = Math.max(confirmedWordProgressRef.current[item.word] ?? 0, Math.min(MAX_STUDY_COUNT, item.studyCount));
      }
      refreshWordProgress();
      };
      const mergeSentenceProgress = (remoteProgress: Array<{ itemId: string; studyCount: number }>, courseId: string) => {
      if (userIdRef.current !== activeUserId || studyModeRef.current !== bootstrapStudyMode) return;
      for (const item of remoteProgress) {
        confirmedSentenceProgressRef.current[item.itemId] = Math.max(confirmedSentenceProgressRef.current[item.itemId] ?? 0, Math.min(MAX_STUDY_COUNT, item.studyCount));
      }
      if (activeCourseIdRef.current === courseId) refreshSentenceProgress(courseId);
      };
      const activatePendingSession = () => {
        if (!pendingActivationRef.current || !courseSnapshotSettled) return;
        pendingActivationRef.current = false;
        activateRef.current();
      };
      if (pendingActivationRef.current) setStartupState("syncing");
      activationTimeout = pendingActivationRef.current
        ? window.setTimeout(() => {
          courseSnapshotSettled = true;
          activatePendingSession();
        }, STARTUP_MAX_WAIT_MS)
        : null;
      void fetch(appPath(`/api/progress?userId=${encodeURIComponent(activeUserId)}&mode=${bootstrapStudyMode}`))
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data: { progress: Array<{ word: string; studyCount: number }>; completions?: Array<{ courseId: string; completionCount: number }>; recentCourseId?: string }) => {
        mergeWordProgress(data.progress);
        setCourseCompletionCounts(Object.fromEntries((data.completions ?? []).map(({ courseId, completionCount }) => [courseId, completionCount])));
        const recentCourseId = data.recentCourseId;
        if (recentCourseId && !activatedRef.current && courseSwitchRequestRef.current === 0 && recentCourseId !== activeCourseIdRef.current) {
          restoreRecentCourse(recentCourseId);
          localStorage.setItem(`word-loop-last-course:${activeUserId}`, recentCourseId);
        }
        activatePendingSession();
      })
        .catch(activatePendingSession);
      void fetch(appPath(`/api/progress?userId=${encodeURIComponent(activeUserId)}&mode=${bootstrapStudyMode}&courseId=${encodeURIComponent(bootstrapCourse.id)}`))
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data: { progress: Array<{ itemId: string; studyCount: number }>; resumeItemId?: string | null }) => {
        mergeSentenceProgress(data.progress, bootstrapCourse.id);
        const resumeItemId = data.resumeItemId ?? localStorage.getItem(sentenceResumeStorageKey(activeUserId, bootstrapStudyMode, bootstrapCourse.id));
        if (resumeItemId) localStorage.setItem(sentenceResumeStorageKey(activeUserId, bootstrapStudyMode, bootstrapCourse.id), resumeItemId);
        const resumeIndex = resumeSentenceIndex(bootstrapCourse.entries, sentenceProgressRef.current, resumeItemId);
        if (!activatedRef.current && activeCourseIdRef.current === bootstrapCourse.id && resumeIndex >= 0) {
          sentenceIndexRef.current = resumeIndex;
          currentIndexRef.current = resumeIndex;
          setSentenceIndex(resumeIndex);
          setNextSentenceIndex(eligibleSentenceIndex(bootstrapCourse.entries, sentenceProgressRef.current, resumeIndex, bootstrapCourse.practiceOrder));
        }
      })
        .catch(() => undefined)
        .finally(() => {
          courseSnapshotSettled = true;
          activatePendingSession();
        });
      void flushPendingProgress(activeUserId, bootstrapStudyMode);
    }, 0);
    return () => {
      window.clearTimeout(hydrateTimer);
      if (activationTimeout !== null) window.clearTimeout(activationTimeout);
    };
  }, [activeUserId, flushPendingProgress, refreshSentenceProgress, refreshWordProgress, restoreRecentCourse]);

  useEffect(() => {
    if (!activeUserId || !activated) return;
    const userId = activeUserId;
    const mode = studyMode;
    const courseId = activeCourseId;
    const mergeWordProgress = (remoteProgress: Array<{ word: string; studyCount: number }>) => {
      if (userIdRef.current !== userId || studyModeRef.current !== mode) return;
      for (const item of remoteProgress) {
        confirmedWordProgressRef.current[item.word] = Math.max(confirmedWordProgressRef.current[item.word] ?? 0, Math.min(MAX_STUDY_COUNT, item.studyCount));
      }
      refreshWordProgress();
    };
    const mergeSentenceProgress = (remoteProgress: Array<{ itemId: string; studyCount: number }>) => {
      if (userIdRef.current !== userId || studyModeRef.current !== mode || activeCourseIdRef.current !== courseId) return;
      for (const item of remoteProgress) {
        confirmedSentenceProgressRef.current[item.itemId] = Math.max(confirmedSentenceProgressRef.current[item.itemId] ?? 0, Math.min(MAX_STUDY_COUNT, item.studyCount));
      }
      refreshSentenceProgress(courseId);
    };
    void fetch(appPath(`/api/progress?userId=${encodeURIComponent(userId)}&mode=${mode}`))
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data: { progress: Array<{ word: string; studyCount: number }> }) => mergeWordProgress(data.progress))
      .catch(() => undefined);
    void fetch(appPath(`/api/progress?userId=${encodeURIComponent(userId)}&mode=${mode}&courseId=${encodeURIComponent(courseId)}`))
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data: { progress: Array<{ itemId: string; studyCount: number }> }) => mergeSentenceProgress(data.progress))
      .catch(() => undefined);
  }, [activeCourseId, activeUserId, activated, refreshSentenceProgress, refreshWordProgress, studyMode]);

  useEffect(() => {
    const retryPendingProgress = () => {
      if (userIdRef.current) void flushPendingProgress(userIdRef.current, studyModeRef.current);
    };
    window.addEventListener("online", retryPendingProgress);
    return () => window.removeEventListener("online", retryPendingProgress);
  }, [flushPendingProgress]);

  useEffect(() => {
    wordIndexRef.current = wordIndex;
  }, [wordIndex]);

  useEffect(() => {
    nextWordIndexRef.current = nextWordIndex;
  }, [nextWordIndex]);

  useEffect(() => {
    sentenceIndexRef.current = sentenceIndex;
  }, [sentenceIndex]);

  useEffect(() => {
    sentenceEntriesRef.current = sentenceCourse.entries;
  }, [sentenceCourse]);

  useEffect(() => {
    activeCourseKindRef.current = sentenceMode ? "sentence" : "word";
  }, [sentenceMode]);

  useEffect(() => {
    if (!sentenceMode && textVisibilityMode === "focus") {
      const resetTextVisibility = window.setTimeout(() => setTextVisibilityMode("full"), 0);
      return () => window.clearTimeout(resetTextVisibility);
    }
  }, [sentenceMode, textVisibilityMode]);

  useEffect(() => {
    nextSentenceIndexRef.current = nextSentenceIndex;
  }, [nextSentenceIndex]);

  useEffect(() => {
    currentIndexRef.current = currentIndex;
    nextIndexRef.current = nextIndex;
  }, [currentIndex, nextIndex]);

  useEffect(() => {
    listenAutoPlayRef.current = listenAutoPlay;
  }, [listenAutoPlay]);

  useEffect(() => {
    progressRef.current = progress;
  }, [progress]);

  useEffect(() => {
    sentenceProgressRef.current = sentenceProgress;
  }, [sentenceProgress]);

  useEffect(() => () => {
    clearRepeatAdvanceTimer();
    clearCompletionPromptTimer();
    clearListenAutoPlayTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    preloadedAudioRef.current?.pause();
    stopListening();
    peerConnectionRef.current?.close();
    dataChannelRef.current?.close();
    repeatStreamRef.current?.getTracks().forEach((track) => track.stop());
    void feedbackAudioContextRef.current?.close();
  }, [clearCompletionPromptTimer, clearListenAutoPlayTimer, clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, stopListening]);

  const recordStudy = useCallback((index: number) => {
    if (sentenceMode) {
      const entry = sentenceEntriesRef.current[index];
      const userId = userIdRef.current;
      if (!userId) return eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, index, sentencePracticeOrder);
      const event: PendingProgressEvent = {
        id: pendingEventId(),
        userId,
        mode: studyMode,
        courseId: activeCourseId,
        itemId: entry.id,
      };
      const projectedProgress = { ...sentenceProgressRef.current, [entry.id]: Math.min(MAX_STUDY_COUNT, (sentenceProgressRef.current[entry.id] ?? 0) + 1) };
      const shouldRecordCompletion = !courseIsComplete(sentenceEntriesRef.current, sentenceProgressRef.current)
        && courseIsComplete(sentenceEntriesRef.current, projectedProgress)
        && !pendingProgressRef.current.some((pending) => pending.completionCourseId === activeCourseId);
      pendingProgressRef.current = shouldRecordCompletion
        ? [...pendingProgressRef.current, event, { id: pendingEventId(), userId, mode: studyMode, completionCourseId: activeCourseId }]
        : [...pendingProgressRef.current, event];
      writePendingProgressEvents(userId, studyMode, pendingProgressRef.current);
      refreshSentenceProgress(activeCourseId);
      const nextEligibleIndex = eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, index, sentencePracticeOrder);
      setNextSentenceIndex(nextEligibleIndex);
      persistSentenceResume(activeCourseId, sentenceEntriesRef.current[nextEligibleIndex]?.id ?? null);
      void flushPendingProgress(userId, studyMode);
      return nextEligibleIndex;
    }

    const studiedWord = WORDS[index][0];
    const userId = userIdRef.current;
    if (!userId) return eligibleIndex(progressRef.current, index);
    const event: PendingProgressEvent = {
      id: pendingEventId(),
      userId,
      mode: studyMode,
      word: studiedWord,
    };
    pendingProgressRef.current = [...pendingProgressRef.current, event];
    writePendingProgressEvents(userId, studyMode, pendingProgressRef.current);
    refreshWordProgress();
    const nextEligibleIndex = eligibleIndex(progressRef.current, index);
    setNextWordIndex(nextEligibleIndex);
    void flushPendingProgress(userId, studyMode);
    return nextEligibleIndex;
  }, [activeCourseId, flushPendingProgress, persistSentenceResume, refreshSentenceProgress, refreshWordProgress, sentenceMode, sentencePracticeOrder, studyMode]);

  const markCurrentItemMastered = useCallback(() => {
    if (currentStudyCount >= MAX_STUDY_COUNT) return false;
    const userId = userIdRef.current;
    if (!userId) return false;
    const event: PendingProgressEvent = sentenceMode
      ? {
        id: pendingEventId(),
        userId,
        mode: studyMode,
        courseId: activeCourseId,
        itemId: sentenceEntriesRef.current[currentIndexRef.current].id,
        mastered: true,
      }
      : {
        id: pendingEventId(),
        userId,
        mode: studyMode,
        word: WORDS[currentIndexRef.current][0],
        mastered: true,
      };
    const entry = sentenceMode ? sentenceEntriesRef.current[currentIndexRef.current] : undefined;
    const projectedProgress = entry
      ? { ...sentenceProgressRef.current, [entry.id]: MAX_STUDY_COUNT }
      : sentenceProgressRef.current;
    const shouldRecordCompletion = sentenceMode && entry
      && !courseIsComplete(sentenceEntriesRef.current, sentenceProgressRef.current)
      && courseIsComplete(sentenceEntriesRef.current, projectedProgress)
      && !pendingProgressRef.current.some((pending) => pending.completionCourseId === activeCourseId);
    pendingProgressRef.current = shouldRecordCompletion
      ? [...pendingProgressRef.current, event, { id: pendingEventId(), userId, mode: studyMode, completionCourseId: activeCourseId }]
      : [...pendingProgressRef.current, event];
    writePendingProgressEvents(userId, studyMode, pendingProgressRef.current);
    if (sentenceMode) {
      refreshSentenceProgress(activeCourseId);
      const nextEligibleIndex = eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, currentIndexRef.current, sentencePracticeOrder);
      setNextSentenceIndex(nextEligibleIndex);
      persistSentenceResume(activeCourseId, sentenceEntriesRef.current[nextEligibleIndex]?.id ?? null);
    } else {
      refreshWordProgress();
      setNextWordIndex(eligibleIndex(progressRef.current, currentIndexRef.current));
    }
    void flushPendingProgress(userId, studyMode);
    return true;
  }, [activeCourseId, currentStudyCount, flushPendingProgress, persistSentenceResume, refreshSentenceProgress, refreshWordProgress, sentenceMode, sentencePracticeOrder, studyMode]);

  const finalizeRepeatTranscript = useCallback((turnId: number) => {
    if (!isActiveRepeatTurn(turnId) || repeatListeningTurnRef.current !== turnId || repeatSpeechInProgressRef.current) return;
    const transcript = [...repeatTranscriptPartsRef.current.values()].join(" ").trim();
    const speechDuration = performance.now() - repeatSpeechStartedAtRef.current;
    if (speechDuration < MIN_SPEECH_MS || !hasEnoughSpeechEvidence(repeatWordRef.current, transcript)) {
      playToneWhenReady(feedbackAudioContextRef.current, (audio) => playFeedbackTone(audio, false));
      scheduleRepeatRetry(turnId, 850);
      return;
    }

    stopListening();
    repeatListeningTurnRef.current = null;
    clearRepeatPhaseTimers();
    setRepeatTranscript(transcript);
    const result = scoreRepeatTranscript(
      repeatWordRef.current,
      transcript,
      activeCourseKindRef.current === "sentence",
    );
    const passed = result.passed;
    playToneWhenReady(feedbackAudioContextRef.current, (audio) => playFeedbackTone(audio, passed));
    if (!passed) {
      scheduleRepeatRetry(turnId, 850);
      return;
    }

    const upcomingIndex = recordStudy(currentIndexRef.current);
    if (upcomingIndex < 0 && activeCourseKindRef.current === "sentence") {
      scheduleCompletionPrompt(activeCourseIdRef.current);
    }
    repeatAdvanceTargetRef.current = { index: upcomingIndex, sentenceMode, turnId };
    setRepeatState("passed");
  }, [clearRepeatPhaseTimers, isActiveRepeatTurn, recordStudy, scheduleCompletionPrompt, scheduleRepeatRetry, sentenceMode, stopListening]);

  const scheduleRepeatTranscriptFinalization = useCallback((turnId: number) => {
    if (repeatSpeechInProgressRef.current) return;
    if (repeatSegmentSettleTimerRef.current !== null) window.clearTimeout(repeatSegmentSettleTimerRef.current);
    repeatSegmentSettleTimerRef.current = window.setTimeout(() => finalizeRepeatTranscript(turnId), SEGMENT_SETTLE_MS);
  }, [finalizeRepeatTranscript]);

  const playWord = useCallback((targetWord: string, onEnded?: () => void, onError?: () => void) => {
    const source = new URL(targetWord.startsWith("/") ? targetWord : appPath(`/audio/${targetWord}.m4a`), window.location.href).href;
    const preloaded = preloadedAudioRef.current;
    const audio = new Audio(source);

    audio.preload = "auto";
    audio.playsInline = true;
    // A preload warms the browser cache, but its media state must never carry
    // into a fresh learning turn (especially immediately after hydration).
    audio.currentTime = 0;
    currentAudioRef.current?.pause();
    currentAudioRef.current = audio;
    if (preloaded?.src === source) {
      preloaded.pause();
      preloaded.src = "";
      preloadedAudioRef.current = null;
    }
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      onEnded?.();
    };
    const fail = () => {
      if (settled) return;
      settled = true;
      onError?.();
    };
    audio.onended = finish;
    audio.onerror = fail;
    void audio.play().catch(fail);
  }, []);

  const playListenItem = useCallback((targetWord: string, onFinished?: () => void) => {
    clearListenAutoPlayTimer();
    playWord(targetWord, () => {
      onFinished?.();
      if (!listenAutoPlayRef.current) return;
      listenAutoPlayTimerRef.current = window.setTimeout(() => {
        if (listenAutoPlayRef.current) nextRef.current();
      }, LISTEN_AUTOPLAY_DELAY_MS);
    });
  }, [clearListenAutoPlayTimer, playWord]);

  const toggleListenAutoPlay = useCallback(() => {
    const nextEnabled = !listenAutoPlayRef.current;
    listenAutoPlayRef.current = nextEnabled;
    setListenAutoPlay(nextEnabled);

    if (!nextEnabled) {
      clearListenAutoPlayTimer();
      return;
    }

    const activeAudio = currentAudioRef.current;
    if (!activeAudio || activeAudio.paused || activeAudio.ended) {
      nextRef.current();
    }
  }, [clearListenAutoPlayTimer]);

  const ensurePronunciationSession = useCallback(() => {
    const dataChannel = dataChannelRef.current;
    const existingPeer = peerConnectionRef.current;
    if (existingPeer && dataChannel && dataChannel.readyState === "open" && existingPeer.connectionState === "connected") {
      return Promise.resolve();
    }
    if (sessionPromiseRef.current) return sessionPromiseRef.current;

    const sessionPromise = (async () => {
      const stream = repeatStreamRef.current ?? await navigator.mediaDevices.getUserMedia({
        audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
      repeatStreamRef.current = stream;
      const track = stream.getAudioTracks()[0];
      track.enabled = false;
      repeatTrackRef.current = track;

      const peerConnection = new RTCPeerConnection();
      const channel = peerConnection.createDataChannel("oai-events");
      peerConnectionRef.current = peerConnection;
      dataChannelRef.current = channel;
      peerConnection.addTrack(track, stream);

      const recoverConnection = () => {
        if (peerConnectionRef.current !== peerConnection) return;
        sessionPromiseRef.current = null;
        const turnId = activeRepeatTurnRef.current;
        if (repeatListeningTurnRef.current === turnId) scheduleRepeatRetry(turnId, 500);
      };
      channel.addEventListener("close", recoverConnection);
      peerConnection.addEventListener("connectionstatechange", () => {
        if (peerConnection.connectionState === "failed" || peerConnection.connectionState === "disconnected") recoverConnection();
      });
      channel.addEventListener("message", (event) => {
        let payload: { item_id?: string; transcript?: string; type: string };
        try { payload = JSON.parse(event.data) as typeof payload; } catch { return; }
        const turnId = repeatListeningTurnRef.current;
        if (turnId === null || !isActiveRepeatTurn(turnId)) return;

        if (payload.type === "input_audio_buffer.speech_started") {
          if (!repeatListeningArmedRef.current) return;
          if (repeatSpeakTimerRef.current !== null) {
            window.clearTimeout(repeatSpeakTimerRef.current);
            repeatSpeakTimerRef.current = null;
          }
          if (repeatScoringTimerRef.current !== null) {
            window.clearTimeout(repeatScoringTimerRef.current);
            repeatScoringTimerRef.current = null;
          }
          if (repeatSegmentSettleTimerRef.current !== null) {
            window.clearTimeout(repeatSegmentSettleTimerRef.current);
            repeatSegmentSettleTimerRef.current = null;
          }
          repeatSpeechItemIdRef.current = payload.item_id ?? "";
          if (payload.item_id) repeatSpeechItemIdsRef.current.add(payload.item_id);
          if (repeatSpeechStartedAtRef.current === 0) repeatSpeechStartedAtRef.current = performance.now();
          repeatSpeechInProgressRef.current = true;
          setRepeatMessage("SPEAKING");
          setRepeatState("speaking");
          repeatSpeakingTimerRef.current = window.setTimeout(() => {
            if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
              scheduleRepeatRetry(turnId, 1_000, true);
            }
          }, SPEAKING_TIMEOUT_MS);
          return;
        }
        if (payload.type === "input_audio_buffer.speech_stopped" || payload.type === "input_audio_buffer.committed") {
          if (!repeatListeningArmedRef.current) return;
          // IMPORTANT: If we haven't seen a speech_started event yet (no item_id), this is a stale stop event.
          if (!repeatSpeechItemIdRef.current) return;
          if (repeatSpeakingTimerRef.current !== null) {
            window.clearTimeout(repeatSpeakingTimerRef.current);
            repeatSpeakingTimerRef.current = null;
          }
          repeatSpeechInProgressRef.current = false;
          setRepeatMessage("SCORING");
          setRepeatState("scoring");
          repeatScoringTimerRef.current = window.setTimeout(() => {
            if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
              scheduleRepeatRetry(turnId, 1_000, true);
            }
          }, SCORING_TIMEOUT_MS);
          return;
        }
        if (payload.type !== "conversation.item.input_audio_transcription.completed" && payload.type !== "conversation.item.input_audio_transcription.failed") return;
        if (!repeatListeningArmedRef.current || (payload.item_id && !repeatSpeechItemIdsRef.current.has(payload.item_id))) return;
        if (payload.type === "conversation.item.input_audio_transcription.failed") {
          stopListening();
          repeatListeningTurnRef.current = null;
          clearRepeatPhaseTimers();
          playToneWhenReady(feedbackAudioContextRef.current, (audio) => playFeedbackTone(audio, false));
          scheduleRepeatRetry(turnId, 1_200);
          return;
        }

        const transcript = (payload.transcript ?? "").trim();
        if (transcript && payload.item_id) repeatTranscriptPartsRef.current.set(payload.item_id, transcript);
        scheduleRepeatTranscriptFinalization(turnId);
      });

      const openPromise = new Promise<void>((resolve, reject) => {
        channel.addEventListener("open", () => resolve(), { once: true });
        channel.addEventListener("error", () => reject(new Error("Realtime channel failed.")), { once: true });
      });
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      const response = await fetch(appPath("/api/pronunciation-session"), {
        method: "POST",
        headers: { "Content-Type": "application/sdp", ...(userIdRef.current ? { "x-user-id": userIdRef.current } : {}) },
        body: offer.sdp,
      });
      if (!response.ok) throw new Error("Unable to start realtime session.");
      await peerConnection.setRemoteDescription({ type: "answer", sdp: await response.text() });
      await openPromise;
    })();
    sessionPromiseRef.current = sessionPromise;
    void sessionPromise.catch(() => {
      if (sessionPromiseRef.current === sessionPromise) sessionPromiseRef.current = null;
    });
    return sessionPromise;
  }, [clearRepeatPhaseTimers, isActiveRepeatTurn, scheduleRepeatRetry, scheduleRepeatTranscriptFinalization, stopListening]);

  const beginRepeatTurn = useCallback((targetIndex: number) => {
    const isSentenceCourse = activeCourseKindRef.current === "sentence";
    const sentenceTarget = isSentenceCourse ? sentenceEntriesRef.current[targetIndex] : undefined;
    const wordTarget = !isSentenceCourse ? WORDS[targetIndex] : undefined;
    const target = sentenceTarget
      ? { text: sentenceTarget.text, audio: sentenceTarget.audio }
      : wordTarget
        ? { text: wordTarget[0], audio: appPath(`/audio/${wordTarget[0]}.m4a`) }
        : undefined;
    if (!target) {
      repeatAdvanceTargetRef.current = null;
      repeatListeningTurnRef.current = null;
      stopListening();
      setRepeatState("error");
      setRepeatMessage("RETRYING");
      return;
    }
    const turnId = repeatTurnIdRef.current + 1;
    repeatTurnIdRef.current = turnId;
    activeRepeatTurnRef.current = turnId;
    repeatAdvanceTargetRef.current = null;
    prepareFeedbackAudio();
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    stopListening();
    repeatListeningTurnRef.current = null;
    repeatSpeechItemIdsRef.current.clear();
    repeatTranscriptPartsRef.current.clear();
    repeatSpeechInProgressRef.current = false;
    if (repeatTranscript) setRepeatTranscript("");
    repeatWordRef.current = target.text;
    setRepeatState("playing");
    setRepeatMessage("PLAYING");
    const session = ensurePronunciationSession();
    const retry = () => scheduleRepeatRetry(turnId, 1_200);
    void session.catch(retry);
    repeatPlaybackTimerRef.current = window.setTimeout(retry, PLAYBACK_TIMEOUT_MS);
    playWord(target.audio, async () => {
      try {
        await ensurePronunciationSession();
        if (!isActiveRepeatTurn(turnId)) return;
        clearRepeatPlaybackTimer();
        repeatSpeechItemIdRef.current = null;
        repeatSpeechStartedAtRef.current = 0;
        repeatSpeechItemIdsRef.current.clear();
        repeatTranscriptPartsRef.current.clear();
        repeatListeningTurnRef.current = turnId;
        repeatListeningArmedRef.current = true;
        setRepeatState("speak");
        setRepeatMessage("SPEAK");
        if (repeatTrackRef.current) repeatTrackRef.current.enabled = true;
        playToneWhenReady(feedbackAudioContextRef.current, playRecordingCue);
        repeatSpeakTimerRef.current = window.setTimeout(() => {
          if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
            scheduleRepeatRetry(turnId, 1_000, true);
          }
        }, SPEAK_TIMEOUT_MS);
      } catch { retry(); }
    }, retry);
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, ensurePronunciationSession, isActiveRepeatTurn, playWord, prepareFeedbackAudio, repeatTranscript, scheduleRepeatRetry, stopListening]);
  useEffect(() => {
    beginRepeatTurnRef.current = beginRepeatTurn;
  }, [beginRepeatTurn]);

  useEffect(() => {
    if (repeatState !== "passed") return;
    const target = repeatAdvanceTargetRef.current;
    if (!target || target.index < 0 || !isActiveRepeatTurn(target.turnId)) return;
    clearRepeatAdvanceTimer();
    repeatAdvanceTimerRef.current = window.setTimeout(() => {
      if (!isActiveRepeatTurn(target.turnId)) return;
      repeatAdvanceTargetRef.current = null;
      if (target.sentenceMode) {
        sentenceIndexRef.current = target.index;
        currentIndexRef.current = target.index;
        setSentenceIndex(target.index);
      } else {
        wordIndexRef.current = target.index;
        currentIndexRef.current = target.index;
        setWordIndex(target.index);
      }
      setPaletteIndex((current) => randomIndex(PALETTES.length, current));
      beginRepeatTurnRef.current(target.index);
    }, AUTO_ADVANCE_MS);
    return clearRepeatAdvanceTimer;
  }, [clearRepeatAdvanceTimer, isActiveRepeatTurn, repeatState]);

  const pauseRepeat = useCallback(() => {
    if (studyMode !== "repeat") return;
    repeatAdvanceTargetRef.current = null;
    activeRepeatTurnRef.current = repeatTurnIdRef.current + 1;
    repeatTurnIdRef.current = activeRepeatTurnRef.current;
    repeatListeningTurnRef.current = null;
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    stopListening();
    setRepeatState("paused");
    setRepeatMessage("PAUSED");
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, stopListening, studyMode]);

  useEffect(() => {
    const pauseWhenHidden = () => {
      clearHiddenPauseTimer();
      if (!document.hidden || studyMode !== "repeat") return;
      hiddenPauseTimerRef.current = window.setTimeout(() => {
        if (!document.hidden || studyMode !== "repeat") return;
        currentAudioRef.current?.pause();
        if (activated) pauseRepeat();
      }, 1_500);
    };
    const pauseOnPageHide = () => {
      clearHiddenPauseTimer();
      if (studyMode !== "repeat") return;
      currentAudioRef.current?.pause();
      if (activated) pauseRepeat();
    };
    document.addEventListener("visibilitychange", pauseWhenHidden);
    window.addEventListener("pagehide", pauseOnPageHide);
    return () => {
      clearHiddenPauseTimer();
      document.removeEventListener("visibilitychange", pauseWhenHidden);
      window.removeEventListener("pagehide", pauseOnPageHide);
    };
  }, [activated, clearHiddenPauseTimer, pauseRepeat, studyMode]);

  const toggleRepeatPause = useCallback(() => {
    if (repeatState === "paused") {
      beginRepeatTurn(currentIndexRef.current);
      return;
    }
    pauseRepeat();
  }, [beginRepeatTurn, pauseRepeat, repeatState]);

  const speak = useCallback(() => {
    if (studyMode === "repeat") beginRepeatTurn(currentIndexRef.current);
    else {
      const audio = activeCourseKindRef.current === "sentence"
        ? sentenceEntriesRef.current[currentIndexRef.current]?.audio
        : WORDS[currentIndexRef.current]?.[0];
      if (audio) playWord(audio);
    }
  }, [beginRepeatTurn, playWord, studyMode]);

  const next = useCallback(() => {
    const targetIndex = nextIndexRef.current >= 0
      ? nextIndexRef.current
      : sentenceMode
        ? eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, currentIndexRef.current, sentencePracticeOrderRef.current)
        : eligibleIndex(progressRef.current, currentIndexRef.current);
    if (targetIndex < 0) {
      if (activeCourseKindRef.current === "sentence" && courseIsComplete(sentenceEntriesRef.current, sentenceProgressRef.current)) {
        scheduleCompletionPrompt(activeCourseIdRef.current);
      }
      return;
    }
    repeatAdvanceTargetRef.current = null;
    stopListening();
    clearRepeatAdvanceTimer();
    if (sentenceMode) {
      sentenceIndexRef.current = targetIndex;
      currentIndexRef.current = targetIndex;
      setNextSentenceIndex(eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, targetIndex, sentencePracticeOrderRef.current));
      setSentenceIndex(targetIndex);
      persistSentenceResume(activeCourseIdRef.current, sentenceEntriesRef.current[targetIndex]?.id ?? null);
    } else {
      wordIndexRef.current = targetIndex;
      currentIndexRef.current = targetIndex;
      setNextWordIndex(eligibleIndex(progressRef.current, targetIndex));
      setWordIndex(targetIndex);
    }
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));

    if (studyMode === "listen") {
      const upcomingIndex = recordStudy(targetIndex);
      const completionCourseId = upcomingIndex < 0 && sentenceMode ? activeCourseIdRef.current : null;
      playListenItem(
        sentenceMode ? sentenceEntriesRef.current[targetIndex].audio : WORDS[targetIndex][0],
        completionCourseId ? () => scheduleCompletionPrompt(completionCourseId) : undefined,
      );
      return;
    }

    beginRepeatTurn(targetIndex);
  }, [beginRepeatTurn, clearRepeatAdvanceTimer, persistSentenceResume, playListenItem, recordStudy, scheduleCompletionPrompt, sentenceMode, stopListening, studyMode]);

  useEffect(() => {
    nextRef.current = next;
  }, [next]);

  const handleMarkCurrentItemMastered = useCallback(() => {
    if (!markCurrentItemMastered()) return;
    prepareFeedbackAudio();
    playToneWhenReady(feedbackAudioContextRef.current, playMasteryCue);
    nextRef.current();
  }, [markCurrentItemMastered, prepareFeedbackAudio]);

  const activate = useCallback(() => {
    activatedRef.current = true;
    setActivated(true);
    if (studyMode === "listen") {
      const audio = activeCourseKindRef.current === "sentence"
        ? sentenceEntriesRef.current[currentIndexRef.current]?.audio
        : WORDS[currentIndexRef.current]?.[0];
      const upcomingIndex = recordStudy(currentIndexRef.current);
      const completionCourseId = upcomingIndex < 0 && activeCourseKindRef.current === "sentence"
        ? activeCourseIdRef.current
        : null;
      if (audio) playListenItem(audio, completionCourseId ? () => scheduleCompletionPrompt(completionCourseId) : undefined);
      return;
    }
    beginRepeatTurn(currentIndexRef.current);
  }, [beginRepeatTurn, playListenItem, recordStudy, scheduleCompletionPrompt, studyMode]);

  useEffect(() => {
    activateRef.current = activate;
  }, [activate]);

  const startAsGuest = useCallback(() => {
    if (pendingActivationRef.current) return;
    const userId = anonymousUserId();
    userIdRef.current = userId;
    progressRef.current = {};
    sentenceProgressRef.current = {};
    setProgress({});
    setSentenceProgress({});
    setStartupState("restoring");
    if (activeUserId === userId) {
      activate();
      return;
    }
    pendingActivationRef.current = true;
    setActiveUserId(userId);
  }, [activate, activeUserId]);

  const handleModeChange = useCallback((nextMode: StudyMode) => {
    if (nextMode === studyMode) return;
    stopListening();
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    setStudyMode(nextMode);

    if (!activated) {
      setRepeatState("idle");
      setRepeatMessage("READY");
      return;
    }

    if (nextMode === "listen") {
      activeRepeatTurnRef.current = repeatTurnIdRef.current + 1;
      repeatTurnIdRef.current = activeRepeatTurnRef.current;
      repeatListeningTurnRef.current = null;
      clearRepeatPlaybackTimer();
      clearRepeatPhaseTimers();
      setRepeatState("idle");
      setRepeatMessage("READY");
      const audio = activeCourseKindRef.current === "sentence"
        ? sentenceEntriesRef.current[currentIndexRef.current]?.audio
        : WORDS[currentIndexRef.current]?.[0];
      if (audio) playListenItem(audio);
      return;
    }

    beginRepeatTurn(currentIndexRef.current);
  }, [activated, beginRepeatTurn, clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, playListenItem, stopListening, studyMode]);

  useEffect(() => {
    if (!nextAudio) return;
    const preload = new Audio(nextAudio);
    preload.preload = "auto";
    preload.load();
    preloadedAudioRef.current = preload;
    return () => {
      if (preloadedAudioRef.current === preload) {
        preloadedAudioRef.current = null;
        preload.src = "";
      }
    };
  }, [nextAudio]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target;
      const isTextEntry = target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement;
      if (event.isComposing || isTextEntry) return;

      if (event.code === "Space") {
        event.preventDefault();
        if (!activated) {
          activate();
          return;
        }
        if (studyMode === "listen") {
          next();
          return;
        }
        if (
          repeatState === "speak" ||
          repeatState === "speaking" ||
          repeatState === "scoring" ||
          repeatState === "playing"
        ) {
          pauseRepeat();
          return;
        }
        beginRepeatTurn(currentIndexRef.current);
        return;
      }

      const key = typeof event.key === "string" ? event.key.toLowerCase() : "";
      if (key === "r" && activated && studyMode === "repeat") {
        event.preventDefault();
        beginRepeatTurn(currentIndexRef.current);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activate, activated, beginRepeatTurn, next, pauseRepeat, repeatState, studyMode]);

  const handlePosterClick = useCallback(() => {
    if (!activated) {
      activate();
      return;
    }

    if (studyMode === "listen") {
      next();
      return;
    }

    if (repeatState === "speak" || repeatState === "speaking" || repeatState === "scoring" || repeatState === "playing") return;
    beginRepeatTurn(currentIndexRef.current);
  }, [activate, activated, beginRepeatTurn, next, repeatState, studyMode]);

  const handleCourseChange = useCallback(async (courseId: string, forceRestart = false) => {
    if (courseId === activeCourseId && !forceRestart) {
      closeCoursePicker();
      return;
    }
    const requestId = courseSwitchRequestRef.current + 1;
    courseSwitchRequestRef.current = requestId;
    const targetCourse = COURSE_PACKAGES.find((c) => c.id === courseId) ?? DEFAULT_COURSE;
    const isSentence = targetCourse.kind === "sentence";
    const wasActivated = activated;
    let targetProgress: ProgressMap = forceRestart ? {} : sentenceProgressRef.current;
    let targetResumeItemId: string | null = forceRestart ? null : (userIdRef.current
      ? localStorage.getItem(sentenceResumeStorageKey(userIdRef.current, studyMode, targetCourse.id))
      : null);

    if (isSentence && !forceRestart && userIdRef.current) {
      try {
        const response = await fetch(appPath(`/api/progress?userId=${encodeURIComponent(userIdRef.current)}&mode=${studyMode}&courseId=${encodeURIComponent(targetCourse.id)}`));
        if (courseSwitchRequestRef.current !== requestId) return;
        if (response.ok) {
          const data = await response.json() as { progress: Array<{ itemId: string; studyCount: number }>; resumeItemId?: string | null };
          targetProgress = Object.fromEntries(data.progress.map(({ itemId, studyCount }) => [itemId, studyCount]));
          targetResumeItemId = data.resumeItemId ?? targetResumeItemId;
          if (targetResumeItemId) localStorage.setItem(sentenceResumeStorageKey(userIdRef.current, studyMode, targetCourse.id), targetResumeItemId);
          if (targetCourse.entries.length > 0 && targetCourse.entries.every((entry) => (targetProgress[entry.id] ?? 0) >= MAX_STUDY_COUNT)) {
            closeCoursePicker();
            setRestartPromptError("");
            setRestartPromptCourseId(targetCourse.id);
            return;
          }
        }
      } catch {
        if (courseSwitchRequestRef.current !== requestId) return;
        // Keep the current in-memory progress as a safe fallback while offline.
      }
    }

    if (courseSwitchRequestRef.current !== requestId) return;

    activeCourseKindRef.current = isSentence ? "sentence" : "word";
    sentencePracticeOrderRef.current = targetCourse.practiceOrder;

    // Update refs synchronously so beginRepeatTurn doesn't see a mismatch
    if (isSentence) {
      const firstEligibleSentence = resumeSentenceIndex(targetCourse.entries, targetProgress, targetResumeItemId);
      const initialSentence = firstEligibleSentence >= 0 ? firstEligibleSentence : 0;
      sentenceEntriesRef.current = targetCourse.entries;
      sentenceIndexRef.current = initialSentence;
      currentIndexRef.current = initialSentence;
      setSentenceIndex(initialSentence);
      setNextSentenceIndex(eligibleSentenceIndex(targetCourse.entries, targetProgress, initialSentence, targetCourse.practiceOrder));
      persistSentenceResume(targetCourse.id, targetCourse.entries[initialSentence]?.id ?? null);
    } else {
      currentIndexRef.current = wordIndexRef.current;
    }
    confirmedSentenceProgressRef.current = isSentence ? targetProgress : {};
    refreshSentenceProgress(targetCourse.id);

    activeRepeatTurnRef.current = repeatTurnIdRef.current + 1;
    repeatTurnIdRef.current = activeRepeatTurnRef.current;
    repeatAdvanceTargetRef.current = null;
    repeatListeningTurnRef.current = null;
    clearRepeatAdvanceTimer();
    clearCompletionPromptTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    stopListening();
    activeCourseIdRef.current = courseId;
    setActiveCourseId(courseId);
    localStorage.setItem(`word-loop-last-course:${userIdRef.current}`, courseId);
    if (userIdRef.current) {
      void fetch(appPath("/api/progress"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: userIdRef.current, mode: studyMode, courseId, selectCourse: true }),
      });
    }
    closeCoursePicker();
    setRepeatState("idle");
    setRepeatMessage("READY");
    if (!wasActivated) return;

    if (studyMode === "listen") {
      const targetAudio = isSentence
        ? targetCourse.entries[currentIndexRef.current]?.audio
        : appPath(`/audio/${WORDS[currentIndexRef.current][0]}.m4a`);
      if (targetAudio) playListenItem(targetAudio);
      recordStudy(currentIndexRef.current);
      return;
    }

    beginRepeatTurn(currentIndexRef.current);
  }, [activated, activeCourseId, beginRepeatTurn, clearCompletionPromptTimer, clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, closeCoursePicker, persistSentenceResume, playListenItem, recordStudy, refreshSentenceProgress, stopListening, studyMode]);

  const restartCompletedCourse = useCallback(async (courseId: string | null) => {
    const userId = userIdRef.current;
    if (!courseId || !userId) return;
    setRestartPromptError("");
    try {
      const response = await fetch(appPath("/api/progress"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, mode: studyMode, courseId, resetCourse: true }),
      });
      if (!response.ok) throw new Error("reset failed");
      pendingProgressRef.current = pendingProgressRef.current.filter((event) => event.courseId !== courseId && event.completionCourseId !== courseId);
      writePendingProgressEvents(userId, studyMode, pendingProgressRef.current);
      if (activeCourseIdRef.current === courseId) {
        confirmedSentenceProgressRef.current = {};
        sentenceProgressRef.current = {};
        setSentenceProgress({});
      }
      setRestartPromptCourseId(null);
      setCompletionPromptCourseId(null);
      await handleCourseChange(courseId, true);
    } catch {
      setRestartPromptError("暂时无法重置进度，请稍后重试。");
    }
  }, [handleCourseChange, studyMode]);

  return (
    <main
      className="poster"
      data-build-revision={WEB_BUILD_REVISION}
      style={{ "--bg": background, "--ink": ink, "--accent": accent } as React.CSSProperties}
      onClick={handlePosterClick}
      aria-live="polite"
    >
      <header className="topbar">
        <div className="brand-area">
          <button
            className="course-button"
            onClick={(event) => {
              event.stopPropagation();
              setExpandedCourseCollectionId(activeCourse.collectionId);
              openCoursePicker();
            }}
            aria-label="Choose course package"
            aria-expanded={coursePickerOpen}
          >
            <span>COURSE</span>
          </button>
        </div>
        <div className="header-actions">
          <div className="mode-switch" role="tablist" aria-label="Study mode">
            <button
              className={studyMode === "listen" ? "active" : undefined}
              onClick={(event) => { event.stopPropagation(); handleModeChange("listen"); }}
              aria-pressed={studyMode === "listen"}
            >
              LISTEN
            </button>
            <button
              className={studyMode === "repeat" ? "active" : undefined}
              onClick={(event) => { event.stopPropagation(); handleModeChange("repeat"); }}
              aria-pressed={studyMode === "repeat"}
            >
              REPEAT
            </button>
          </div>
        </div>
        <button
          className="progress-button topbar-progress"
          onClick={(event) => { event.stopPropagation(); openProgressPanel(); }}
          aria-label="Open learning progress"
        >
          PROGRESS · {completedWords}/{activeEntriesCount}
        </button>
      </header>

      {!activated && (
        <div className="start-overlay" role="dialog" aria-label="Start study mode">
          <div className="start-form" onClick={(event) => event.stopPropagation()}>
            <button type="button" onClick={startAsGuest} disabled={startupState !== "idle"} aria-busy={startupState !== "idle"}>
              <span className="start-icon" aria-hidden="true">▶</span>
              {startupState === "idle" ? "START" : startupState === "restoring" ? "PREPARING…" : "SYNCING…"}
            </button>
          </div>
          {startupState !== "idle"
            ? <p aria-live="polite">{startupState === "restoring" ? "正在恢复上次课程" : "正在同步学习进度"}</p>
            : studyMode !== "repeat" && <p>{activeCourse.description}</p>}
        </div>
      )}

      <section className="word-stage">
        <div className="course-kicker">{activeCourse.title} · {currentIndex + 1}/{activeEntriesCount}</div>
        <h1
          key={currentItem.id}
          className={sentenceMode ? "sentence-title" : currentItem.text.length > 12 ? "very-long" : currentItem.text.length > 9 ? "long" : undefined}
          aria-hidden={textVisibilityMode === "hidden"}
        >
          {renderStudyText(currentItem.text, textVisibilityMode, currentItem.highlights)}
        </h1>
        <div className="phonetic-row">
          {sentenceMode ? <div className="phonetic sentence-translation">{currentItem.meaning}</div> : <div key={`${word}-phonetic`} className="phonetic">/{phonetic}/</div>}
          <div className="study-actions">
            <button
              className="study-action word-play"
              onClick={(event) => {
                event.stopPropagation();
                if (activated) speak();
                else activate();
              }}
              aria-label={studyMode === "repeat" ? `Replay and repeat ${currentItem.text}` : `Play pronunciation of ${currentItem.text}`}
            >
              <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
            </button>
            <button
              className="study-action sentence-visibility"
              onClick={(event) => { event.stopPropagation(); setTextVisibilityMode(nextTextVisibilityMode); }}
              aria-label={visibilityAriaLabel}
              aria-pressed={textVisibilityMode !== "full"}
            >
              <span className={`eye-icon${textVisibilityMode === "hidden" ? " closed" : textVisibilityMode === "focus" ? " focus" : ""}`} aria-hidden="true" />
            </button>
          </div>
        </div>
        {!sentenceMode && <p key={`${word}-meaning`} className="meaning">{meaning}</p>}
        {studyMode === "repeat" && (
          <div className={`repeat-card ${repeatState}`}>
            <div className="repeat-visual" aria-hidden="true">
              {repeatState === "passed" ? (
                <span className="repeat-result-icon success">✓</span>
              ) : (
                <span className={`repeat-waveform ${repeatState === "retry" || repeatState === "error" ? "failure" : ""}`}>
                  <i /><i /><i /><i /><i /><i /><i /><i /><i />
                </span>
              )}
            </div>
            <div className="repeat-body" aria-live="polite">
              <strong>{repeatLabel}</strong>
              <span>{repeatHint}</span>
              <span className="sr-only">{repeatMessage}</span>
            </div>
            {showRepeatTranscript && (
              <div className="repeat-transcript">
                <span>You said</span>
                <strong>{repeatTranscript}</strong>
              </div>
            )}
          </div>
        )}
      </section>

      {studyMode === "repeat" && activated && (
        <div className="repeat-controls">
          <button
            className="repeat-toggle repeat-control"
            onClick={(event) => { event.stopPropagation(); toggleRepeatPause(); }}
            aria-label={repeatState === "paused" ? "Resume repeat" : "Pause repeat"}
            aria-pressed={repeatState === "paused"}
          >
            <span aria-hidden="true" className={repeatState === "paused" ? "repeat-toggle-play" : "repeat-toggle-pause"} />
            <span>{repeatState === "paused" ? "RESUME" : "PAUSE"}</span>
          </button>
          <button
            className="manual-next repeat-control"
            onClick={(event) => { event.stopPropagation(); next(); }}
            disabled={nextDisabled}
          >
            NEXT <span aria-hidden="true">→</span>
          </button>
        </div>
      )}

      {studyMode === "listen" && activated && (
        <div className="repeat-controls listen-controls">
          <button
            className={`repeat-control listen-auto-toggle${listenAutoPlay ? " active" : ""}`}
            onClick={(event) => { event.stopPropagation(); toggleListenAutoPlay(); }}
            aria-pressed={listenAutoPlay}
            aria-label={listenAutoPlay ? "Turn off autoplay" : "Turn on autoplay"}
          >
            <span aria-hidden="true" className="listen-auto-icon" />
            <span>{listenAutoPlay ? "AUTOPLAY ON" : "AUTOPLAY"}</span>
          </button>
          <button
            className="manual-next repeat-control"
            onClick={(event) => { event.stopPropagation(); next(); }}
            disabled={nextDisabled}
          >
            NEXT <span aria-hidden="true">→</span>
          </button>
        </div>
      )}

      {coursePickerOpen && (
        <div
          className={coursePickerClosing ? "panel-backdrop closing course-panel-backdrop" : "panel-backdrop course-panel-backdrop"}
          onClick={(event) => {
            event.stopPropagation();
            if (event.target === event.currentTarget) closeCoursePicker();
          }}
        >
          <aside
            className="course-panel"
            aria-label="Course packages"
            onPointerDown={beginPanelSwipe}
            onPointerUp={(event) => endPanelSwipe(event, "left", closeCoursePicker)}
            onPointerCancel={clearPanelSwipe}
          >
            <div className="panel-header">
              <div><span>COURSE PACKAGES</span><h2>选择课程</h2></div>
              <button onClick={closeCoursePicker} aria-label="Close course selector">×</button>
            </div>
            <input
              className="panel-search"
              value={courseSearch}
              onChange={(event) => setCourseSearch(event.target.value)}
              placeholder="搜索课程"
              aria-label="Search course packages"
            />
            <div className="course-list">
              {filteredCourseCollections.map((collection) => {
                const expanded = courseSearch.trim().length > 0 || expandedCourseCollectionId === collection.id;
                return (
                  <section className="course-collection" key={collection.id}>
                    <button
                      className="course-collection-toggle"
                      onClick={() => setExpandedCourseCollectionId(expanded ? "" : collection.id)}
                      aria-expanded={expanded}
                    >
                      <span><em>{collection.label}</em><strong>{collection.title}</strong><small>{collection.subtitle}</small></span>
                      <i aria-hidden="true">{expanded ? "−" : "+"}</i>
                    </button>
                    {expanded && <div className="course-collection-courses">
                      {collection.courses.map((course) => (
                        <button
                          className={course.id === activeCourse.id ? "course-card active" : "course-card"}
                          key={course.id}
                          onClick={() => handleCourseChange(course.id)}
                        >
                          <strong>{course.title}</strong>
                          <small>{course.subtitle}</small>
                          {(courseCompletionCounts[course.id] ?? 0) > 0 && (
                            <span className="course-card-completion" aria-label={`Completed ${courseCompletionCounts[course.id]} times`}>
                              × {courseCompletionCounts[course.id]}
                            </span>
                          )}
                        </button>
                      ))}
                    </div>}
                  </section>
                );
              })}
              {filteredCourseCollections.length === 0 && <p className="panel-empty">没有匹配的课程</p>}
            </div>
          </aside>
        </div>
      )}

      {restartPromptCourseId && (
        <div className="restart-course-backdrop" role="presentation" onClick={(event) => event.stopPropagation()}>
          <section className="restart-course-dialog" role="dialog" aria-modal="true" aria-labelledby="restart-course-title">
            <span>COURSE COMPLETE</span>
            <h2 id="restart-course-title">这门课程已经完成</h2>
            <p>要重新开始练习吗？现有练习进度将被清零。</p>
            {restartPromptError && <p className="restart-course-error">{restartPromptError}</p>}
            <div>
              <button onClick={() => setRestartPromptCourseId(null)}>取消</button>
              <button className="restart-course-confirm" onClick={() => void restartCompletedCourse(restartPromptCourseId)}>重新开始</button>
            </div>
          </section>
        </div>
      )}

      {completionPromptCourseId && (
        <div className="restart-course-backdrop" role="presentation" onClick={(event) => event.stopPropagation()}>
          <section className="restart-course-dialog completion-dialog" role="dialog" aria-modal="true" aria-labelledby="completion-course-title">
            <span>COURSE COMPLETE</span>
            <h2 id="completion-course-title">这门课程学完了</h2>
            <p>太棒了。你可以从头再练一遍，或者挑选下一门课程继续学习。</p>
            {restartPromptError && <p className="restart-course-error">{restartPromptError}</p>}
            <div>
              <button onClick={() => { setCompletionPromptCourseId(null); setRestartPromptError(""); openCoursePicker(); }}>选择课程</button>
              <button className="restart-course-confirm" onClick={() => void restartCompletedCourse(completionPromptCourseId)}>再练一次</button>
            </div>
          </section>
        </div>
      )}

      {panelOpen && (
        <div
          className={panelClosing ? "panel-backdrop closing progress-panel-backdrop" : "panel-backdrop progress-panel-backdrop"}
          onClick={(event) => {
            event.stopPropagation();
            if (event.target === event.currentTarget) closeProgressPanel();
          }}
        >
          <aside
            className="progress-panel"
            aria-label="Learning progress panel"
            onPointerDown={beginPanelSwipe}
            onPointerUp={(event) => endPanelSwipe(event, "right", closeProgressPanel)}
            onPointerCancel={clearPanelSwipe}
          >
            <div className="panel-header">
              <div>
                <span>YOUR PROGRESS</span>
                <h2>{totalStudies.toLocaleString()} / {(activeEntriesCount * MAX_STUDY_COUNT).toLocaleString()}</h2>
                <p className="progress-course-context">{activeCourse.title}</p>
              </div>
              <button onClick={closeProgressPanel} aria-label="Close progress panel">×</button>
            </div>
            <div className="progress-track"><i style={{ width: `${totalStudies / (activeEntriesCount * MAX_STUDY_COUNT) * 100}%` }} /></div>
            <div className="panel-stats">
              <span><b>{completedWords}</b><small>已掌握</small></span>
              <span><b>{activeEntriesCount - completedWords}</b><small>学习中</small></span>
            </div>
            <input
              className="panel-search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={sentenceMode ? "搜索句子或中文翻译" : "搜索单词或中文释义"}
              aria-label={sentenceMode ? "Search sentence progress" : "Search vocabulary progress"}
            />
            <div className="word-list">
              {sentenceMode ? filteredSentences.map((entry) => {
                const count = sentenceProgress[entry.id] ?? 0;
                return <div className="word-row" key={entry.id}><div><strong>{entry.text}</strong><small>{entry.translation}</small></div><span className={count >= MAX_STUDY_COUNT ? "progress-count complete" : "progress-count"}>{count} / {MAX_STUDY_COUNT}</span></div>;
              }) : filteredWords.map(([entry, entryMeaning, , entryPhonetic]) => {
                const count = progress[entry] ?? 0;
                return (
                  <div className="word-row" key={entry}>
                    <div><strong>{entry}</strong><small>/{entryPhonetic}/ · {entryMeaning}</small></div>
                    <span className={count >= MAX_STUDY_COUNT ? "progress-count complete" : "progress-count"}>{count} / {MAX_STUDY_COUNT}</span>
                  </div>
                );
              })}
            </div>
          </aside>
        </div>
      )}

      <footer>
        {studyMode !== "repeat" && !activated && (
          <div className="prompt">
            {nextIndex >= 0 ? (
              <><span className="space-key">SPACE</span><span>next {sentenceMode ? "sentence" : "word"}</span></>
            ) : (
              <span>{sentenceMode ? "COURSE COMPLETE" : "ALL 570 WORDS MASTERED"}</span>
            )}
          </div>
        )}
        <div className="mastery-controls">
          <span className="mastery-progress" aria-label={`Current progress: ${currentStudyCount} of ${MAX_STUDY_COUNT}`}>
            {currentStudyCount} / {MAX_STUDY_COUNT}
          </span>
          <button
            className="mastery-button repeat-control"
            onClick={(event) => { event.stopPropagation(); handleMarkCurrentItemMastered(); }}
            disabled={currentStudyCount >= MAX_STUDY_COUNT}
            aria-label={currentStudyCount >= MAX_STUDY_COUNT ? "Current item mastered" : "Mark current item as mastered"}
          >
            <span>太简单</span>
            <i className="mastery-check" aria-hidden="true">✓</i>
          </button>
        </div>
      </footer>
    </main>
  );
}
