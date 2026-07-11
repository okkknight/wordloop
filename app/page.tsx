"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  COURSE_PACKAGES,
  DEFAULT_COURSE,
  MODERN_FAMILY_S01E01_COURSE,
  type CourseEntry,
} from "./courses";
import { WORDS } from "./words";

const MAX_STUDY_COUNT = 50;
const PASS_SCORE = 20;
const AUTO_ADVANCE_MS = 700;
const PLAYBACK_TIMEOUT_MS = 8_000;
const SPEAK_TIMEOUT_MS = 6_000;
const SPEAKING_TIMEOUT_MS = 6_000;
const SCORING_TIMEOUT_MS = 6_000;
const USER_ID_KEY = "word-loop-user-id";
const PROGRESS_KEY = "word-loop-progress";
const SENTENCE_PROGRESS_KEY = "word-loop-sentence-progress";

type ProgressMap = Record<string, number>;
type StudyMode = "listen" | "repeat";
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

type ScoreResult = {
  feedback: string;
  matched: string;
  passed: boolean;
  score: number;
};

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

function eligibleSentenceIndex(entries: readonly CourseEntry[], progress: ProgressMap, except = -1) {
  const available = entries.flatMap((entry, index) =>
    index !== except && (progress[entry.id] ?? 0) < MAX_STUDY_COUNT ? [index] : [],
  );
  return available.length ? available[Math.floor(Math.random() * available.length)] : -1;
}

function normalizeSpeech(value: string) {
  return value.toLowerCase().replace(/[^a-z]/g, "");
}

function speechCandidates(transcript: string) {
  const withoutNoiseLabels = transcript.replace(
    /[\[(](?:background noise|noise|music|laughter|silence|inaudible)[\])]/gi,
    " ",
  );
  const words = withoutNoiseLabels
    .split(/\s+/)
    .map(normalizeSpeech)
    .filter(Boolean);
  const candidates = new Set(words);

  // Transcription can split a spoken phrase into several pieces. Include
  // adjacent windows long enough to cover a complete learning sentence, while
  // still ignoring unrelated words during scoring.
  for (let start = 0; start < words.length; start += 1) {
    let combined = words[start];
    for (let end = start + 1; end < Math.min(words.length, start + 12); end += 1) {
      combined += words[end];
      candidates.add(combined);
    }
  }

  return [...candidates];
}

function playFeedbackTone(context: AudioContext, passed: boolean) {
  const notes = passed ? [660, 880] : [220, 165];
  const startedAt = context.currentTime;

  for (const [index, frequency] of notes.entries()) {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    const offset = index * 0.09;
    const duration = 0.12;

    oscillator.type = passed ? "sine" : "triangle";
    oscillator.frequency.setValueAtTime(frequency, startedAt + offset);
    gain.gain.setValueAtTime(0.0001, startedAt + offset);
    gain.gain.exponentialRampToValueAtTime(passed ? 0.07 : 0.055, startedAt + offset + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, startedAt + offset + duration);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(startedAt + offset);
    oscillator.stop(startedAt + offset + duration);
  }
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

function levenshtein(a: string, b: string) {
  if (!a.length) return b.length;
  if (!b.length) return a.length;

  const matrix = Array.from({ length: a.length + 1 }, (_, row) =>
    Array.from({ length: b.length + 1 }, (_, column) =>
      row === 0 ? column : column === 0 ? row : 0,
    ),
  );

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

function scoreTranscript(targetWord: string, transcript: string): ScoreResult {
  const normalizedTarget = normalizeSpeech(targetWord);
  const candidates = speechCandidates(transcript);

  let matched = "";
  let bestSimilarity = 0;

  for (const candidate of candidates) {
    const distance = levenshtein(normalizedTarget, candidate);
    const similarity = Math.max(
      0,
      1 - distance / Math.max(normalizedTarget.length, candidate.length, 1),
    );
    if (similarity > bestSimilarity) {
      bestSimilarity = similarity;
      matched = candidate;
    }
  }

  const exact = candidates.includes(normalizedTarget);
  const score = exact
    ? 100
    : Math.round(bestSimilarity * 100);
  const passed = exact || score >= PASS_SCORE;

  if (passed) {
    return {
      feedback: "PASS",
      matched,
      passed: true,
      score,
    };
  }

  if (!matched) {
    return {
      feedback: "TRY AGAIN",
      matched,
      passed: false,
      score: 0,
    };
  }

  return {
    feedback: "TRY AGAIN",
    matched,
    passed: false,
    score,
  };
}

export default function Home() {
  const [wordIndex, setWordIndex] = useState(() => randomIndex(WORDS.length));
  const [nextWordIndex, setNextWordIndex] = useState(() => randomIndex(WORDS.length));
  const [sentenceIndex, setSentenceIndex] = useState(() => randomIndex(MODERN_FAMILY_S01E01_COURSE.entries.length));
  const [nextSentenceIndex, setNextSentenceIndex] = useState(() => randomIndex(MODERN_FAMILY_S01E01_COURSE.entries.length));
  const [paletteIndex, setPaletteIndex] = useState(() => randomIndex(PALETTES.length));
  const [activeCourseId, setActiveCourseId] = useState(DEFAULT_COURSE.id);
  const [studyMode, setStudyMode] = useState<StudyMode>("listen");
  const [activated, setActivated] = useState(false);
  const [progress, setProgress] = useState<ProgressMap>(() => {
    if (typeof window === "undefined") return {};
    try {
      return JSON.parse(localStorage.getItem(PROGRESS_KEY) ?? "{}") as ProgressMap;
    } catch {
      return {};
    }
  });
  const [sentenceProgress, setSentenceProgress] = useState<ProgressMap>(() => {
    if (typeof window === "undefined") return {};
    try {
      return JSON.parse(localStorage.getItem(SENTENCE_PROGRESS_KEY) ?? "{}") as ProgressMap;
    } catch {
      return {};
    }
  });
  const [panelOpen, setPanelOpen] = useState(false);
  const [coursePickerOpen, setCoursePickerOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [repeatState, setRepeatState] = useState<RepeatState>("idle");
  const [repeatMessage, setRepeatMessage] = useState("READY");
  const [repeatTranscript, setRepeatTranscript] = useState("");
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const studyAudioSourceRef = useRef("");
  const preloadedAudioRef = useRef<HTMLAudioElement | null>(null);
  const dataChannelRef = useRef<RTCDataChannel | null>(null);
  const peerConnectionRef = useRef<RTCPeerConnection | null>(null);
  const repeatAdvanceTimerRef = useRef<number | null>(null);
  const repeatRetryTimerRef = useRef<number | null>(null);
  const repeatPlaybackTimerRef = useRef<number | null>(null);
  const repeatSpeakTimerRef = useRef<number | null>(null);
  const repeatSpeakingTimerRef = useRef<number | null>(null);
  const repeatScoringTimerRef = useRef<number | null>(null);
  const sessionPromiseRef = useRef<Promise<void> | null>(null);
  const repeatTurnIdRef = useRef(0);
  const activeRepeatTurnRef = useRef(0);
  const repeatListeningTurnRef = useRef<number | null>(null);
  const beginRepeatTurnRef = useRef<(targetIndex: number) => void>(() => undefined);
  const repeatTrackRef = useRef<MediaStreamTrack | null>(null);
  const feedbackAudioContextRef = useRef<AudioContext | null>(null);
  const repeatListeningArmedRef = useRef(false);
  const repeatSpeechItemIdRef = useRef<string | null>(null);
  const repeatWordRef = useRef("");
  const repeatStreamRef = useRef<MediaStream | null>(null);
  const userIdRef = useRef("");
  const progressRef = useRef<ProgressMap>({});
  const sentenceProgressRef = useRef<ProgressMap>({});
  const nextWordIndexRef = useRef(nextWordIndex);
  const wordIndexRef = useRef(wordIndex);
  const nextSentenceIndexRef = useRef(nextSentenceIndex);
  const sentenceIndexRef = useRef(sentenceIndex);
  const sentenceEntriesRef = useRef<readonly CourseEntry[]>(MODERN_FAMILY_S01E01_COURSE.entries);
  const currentIndexRef = useRef(wordIndex);
  const nextIndexRef = useRef(nextWordIndex);
  const [word, meaning, , phonetic] = WORDS[wordIndex];
  const activeCourse = COURSE_PACKAGES.find((course) => course.id === activeCourseId) ?? DEFAULT_COURSE;
  const sentenceMode = activeCourse.kind === "sentence";
  const sentenceCourse = sentenceMode ? activeCourse : MODERN_FAMILY_S01E01_COURSE;
  const sentence = sentenceCourse.entries[sentenceIndex];
  const currentItem = sentenceMode
    ? { id: sentence.id, text: sentence.text, meaning: sentence.translation, phonetic: "", audio: sentence.audio }
    : { id: word, text: word, meaning, phonetic, audio: `/audio/${word}.m4a` };
  const currentAudio = sentenceMode ? sentence.audio : `/audio/${word}.m4a`;
  const currentIndex = sentenceMode ? sentenceIndex : wordIndex;
  const nextIndex = sentenceMode ? nextSentenceIndex : nextWordIndex;
  const nextAudio = nextIndex < 0
    ? null
    : sentenceMode ? sentenceCourse.entries[nextIndex].audio : `/audio/${WORDS[nextIndex][0]}.m4a`;
  const activeProgress = sentenceMode ? sentenceProgress : progress;
  const activeEntriesCount = activeCourse.entries.length;
  const [background, ink, accent] = PALETTES[paletteIndex];
  const currentStudyCount = activeProgress[currentItem.id] ?? 0;
  const manualNextIndex = nextIndex >= 0
    ? nextIndex
    : sentenceMode
      ? eligibleSentenceIndex(sentenceCourse.entries, sentenceProgress, sentenceIndex)
      : eligibleIndex(progress, wordIndex);
  const totalStudies = Object.values(activeProgress).reduce((sum, count) => sum + count, 0);
  const completedWords = sentenceMode
    ? sentenceCourse.entries.filter((entry) => (sentenceProgress[entry.id] ?? 0) >= MAX_STUDY_COUNT).length
    : WORDS.filter(([entry]) => (progress[entry] ?? 0) >= MAX_STUDY_COUNT).length;
  const filteredWords = WORDS.filter(([entry, entryMeaning]) =>
    `${entry} ${entryMeaning}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  const filteredSentences = sentenceCourse.entries.filter((entry) =>
    `${entry.text} ${entry.translation}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  const repeatLabel = repeatStatusLabel(repeatState);
  const repeatHint = repeatStatusHint(repeatState);
  const showRepeatTranscript = Boolean(repeatTranscript) && (repeatState === "retry" || repeatState === "error");

  const stopListening = useCallback(() => {
    if (repeatTrackRef.current) repeatTrackRef.current.enabled = false;
    repeatListeningArmedRef.current = false;
    repeatSpeechItemIdRef.current = null;
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
    for (const timerRef of [repeatSpeakTimerRef, repeatSpeakingTimerRef, repeatScoringTimerRef]) {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    }
  }, []);

  const isActiveRepeatTurn = useCallback((turnId: number) => (
    activeRepeatTurnRef.current === turnId
  ), []);

  const scheduleRepeatRetry = useCallback((turnId: number, delay = 1_000) => {
    if (!isActiveRepeatTurn(turnId)) return;
    clearRepeatAdvanceTimer();
    clearRepeatPlaybackTimer();
    clearRepeatRetryTimer();
    clearRepeatPhaseTimers();
    stopListening();
    repeatListeningTurnRef.current = null;
    setRepeatState("error");
    setRepeatMessage("RETRYING");
    repeatRetryTimerRef.current = window.setTimeout(() => {
      if (isActiveRepeatTurn(turnId)) beginRepeatTurnRef.current(currentIndexRef.current);
    }, delay);
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, isActiveRepeatTurn, stopListening]);

  const applyProgress = useCallback((nextProgress: ProgressMap) => {
    setProgress(nextProgress);
    localStorage.setItem(PROGRESS_KEY, JSON.stringify(nextProgress));
    setWordIndex((current) => {
      if ((nextProgress[WORDS[current][0]] ?? 0) < MAX_STUDY_COUNT) return current;
      const replacement = eligibleIndex(nextProgress);
      return replacement >= 0 ? replacement : current;
    });
    setNextWordIndex((current) => {
      if (current >= 0 && (nextProgress[WORDS[current][0]] ?? 0) < MAX_STUDY_COUNT) return current;
      return eligibleIndex(nextProgress);
    });
  }, []);

  useEffect(() => {
    let userId = localStorage.getItem(USER_ID_KEY);
    if (!userId) {
      userId = crypto.randomUUID();
      localStorage.setItem(USER_ID_KEY, userId);
    }
    userIdRef.current = userId;

    const cachedProgress = progressRef.current;

    void fetch(`/api/progress?userId=${encodeURIComponent(userId)}`)
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data: { progress: Array<{ word: string; studyCount: number }> }) => {
        const mergedProgress = { ...cachedProgress };
        for (const item of data.progress) {
          mergedProgress[item.word] = Math.max(
            mergedProgress[item.word] ?? 0,
            Math.min(MAX_STUDY_COUNT, item.studyCount),
          );
        }
        applyProgress(mergedProgress);
      })
      .catch(() => undefined);
  }, [applyProgress]);

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
    nextSentenceIndexRef.current = nextSentenceIndex;
  }, [nextSentenceIndex]);

  useEffect(() => {
    currentIndexRef.current = currentIndex;
    nextIndexRef.current = nextIndex;
  }, [currentIndex, nextIndex]);

  useEffect(() => {
    studyAudioSourceRef.current = currentAudio;
  }, [currentAudio]);

  useEffect(() => {
    progressRef.current = progress;
  }, [progress]);

  useEffect(() => {
    sentenceProgressRef.current = sentenceProgress;
  }, [sentenceProgress]);

  useEffect(() => () => {
    clearRepeatAdvanceTimer();
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
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, stopListening]);

  const recordStudy = useCallback((index: number) => {
    if (sentenceMode) {
      const entry = sentenceEntriesRef.current[index];
      const next = {
        ...sentenceProgressRef.current,
        [entry.id]: Math.min(MAX_STUDY_COUNT, (sentenceProgressRef.current[entry.id] ?? 0) + 1),
      };
      const nextEligibleIndex = eligibleSentenceIndex(sentenceEntriesRef.current, next, index);
      sentenceProgressRef.current = next;
      setSentenceProgress(next);
      localStorage.setItem(SENTENCE_PROGRESS_KEY, JSON.stringify(next));
      setNextSentenceIndex(nextEligibleIndex);
      return nextEligibleIndex;
    }

    const studiedWord = WORDS[index][0];
    const next = {
      ...progressRef.current,
      [studiedWord]: Math.min(MAX_STUDY_COUNT, (progressRef.current[studiedWord] ?? 0) + 1),
    };
    const nextEligibleIndex = eligibleIndex(next, index);

    progressRef.current = next;
    setProgress(next);
    localStorage.setItem(PROGRESS_KEY, JSON.stringify(next));
    setNextWordIndex(nextEligibleIndex);

    const userId = userIdRef.current;
    if (!userId) return;
    void fetch("/api/progress", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId, word: studiedWord }),
    }).then(async (response) => {
      if (!response.ok) return;
      const data = await response.json() as { studyCount: number };
      setProgress((current) => {
        const next = { ...current, [studiedWord]: Math.max(current[studiedWord] ?? 0, data.studyCount) };
        progressRef.current = next;
        localStorage.setItem(PROGRESS_KEY, JSON.stringify(next));
        return next;
      });
      }).catch(() => undefined);
    return nextEligibleIndex;
  }, [sentenceMode]);

  const playWord = useCallback((targetWord: string, onEnded?: () => void, onError?: () => void) => {
    const source = new URL(targetWord.startsWith("/") ? targetWord : `/audio/${targetWord}.m4a`, window.location.href).href;
    const preloaded = preloadedAudioRef.current;
    const usePreloaded = preloaded?.src === source;
    const audio = usePreloaded
      ? preloaded.cloneNode(true) as HTMLAudioElement
      : new Audio(source);

    currentAudioRef.current?.pause();
    currentAudioRef.current = audio;
    if (usePreloaded) preloadedAudioRef.current = null;
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
          repeatSpeechItemIdRef.current = payload.item_id ?? "";
          setRepeatMessage("SPEAKING");
          setRepeatState("speaking");
          repeatSpeakingTimerRef.current = window.setTimeout(() => {
            if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
              scheduleRepeatRetry(turnId);
            }
          }, SPEAKING_TIMEOUT_MS);
          return;
        }
        if (payload.type === "input_audio_buffer.speech_stopped" || payload.type === "input_audio_buffer.committed") {
          if (!repeatListeningArmedRef.current) return;
          if (repeatSpeakingTimerRef.current !== null) {
            window.clearTimeout(repeatSpeakingTimerRef.current);
            repeatSpeakingTimerRef.current = null;
          }
          setRepeatMessage("SCORING");
          setRepeatState("scoring");
          repeatScoringTimerRef.current = window.setTimeout(() => {
            if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
              scheduleRepeatRetry(turnId);
            }
          }, SCORING_TIMEOUT_MS);
          return;
        }
        if (payload.type !== "conversation.item.input_audio_transcription.completed" && payload.type !== "conversation.item.input_audio_transcription.failed") return;
        if (!repeatListeningArmedRef.current || (payload.item_id && repeatSpeechItemIdRef.current && payload.item_id !== repeatSpeechItemIdRef.current)) return;
        stopListening();
        repeatListeningTurnRef.current = null;
        clearRepeatPhaseTimers();
        if (payload.type === "conversation.item.input_audio_transcription.failed") {
          scheduleRepeatRetry(turnId, 1_200);
          return;
        }

        const transcript = (payload.transcript ?? "").trim();
        setRepeatTranscript(transcript);
        const result = scoreTranscript(repeatWordRef.current, transcript);
        const feedbackAudio = feedbackAudioContextRef.current;
        if (feedbackAudio?.state === "running") playFeedbackTone(feedbackAudio, result.passed);
        if (!result.passed) {
          scheduleRepeatRetry(turnId, 850);
          return;
        }

        setRepeatState("passed");
        const upcomingIndex = recordStudy(currentIndexRef.current);
        clearRepeatAdvanceTimer();
        repeatAdvanceTimerRef.current = window.setTimeout(() => {
          if (isActiveRepeatTurn(turnId) && upcomingIndex >= 0) {
            if (sentenceMode) {
              sentenceIndexRef.current = upcomingIndex;
              currentIndexRef.current = upcomingIndex;
              setSentenceIndex(upcomingIndex);
            } else {
              wordIndexRef.current = upcomingIndex;
              currentIndexRef.current = upcomingIndex;
              setWordIndex(upcomingIndex);
            }
            setPaletteIndex((current) => randomIndex(PALETTES.length, current));
            beginRepeatTurnRef.current(upcomingIndex);
          }
        }, AUTO_ADVANCE_MS);
      });

      const openPromise = new Promise<void>((resolve, reject) => {
        channel.addEventListener("open", () => resolve(), { once: true });
        channel.addEventListener("error", () => reject(new Error("Realtime channel failed.")), { once: true });
      });
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      const response = await fetch("/api/pronunciation-session", {
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
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, isActiveRepeatTurn, recordStudy, scheduleRepeatRetry, sentenceMode, stopListening]);

  const beginRepeatTurn = useCallback((targetIndex: number) => {
    const target = sentenceMode
      ? sentenceEntriesRef.current[targetIndex]
      : { text: WORDS[targetIndex][0], audio: `/audio/${WORDS[targetIndex][0]}.m4a` };
    const turnId = repeatTurnIdRef.current + 1;
    repeatTurnIdRef.current = turnId;
    activeRepeatTurnRef.current = turnId;
    prepareFeedbackAudio();
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    stopListening();
    repeatListeningTurnRef.current = null;
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
        repeatListeningTurnRef.current = turnId;
        repeatListeningArmedRef.current = true;
        setRepeatState("speak");
        setRepeatMessage("SPEAK");
        if (repeatTrackRef.current) repeatTrackRef.current.enabled = true;
        repeatSpeakTimerRef.current = window.setTimeout(() => {
          if (isActiveRepeatTurn(turnId) && repeatListeningTurnRef.current === turnId) {
            scheduleRepeatRetry(turnId);
          }
        }, SPEAK_TIMEOUT_MS);
      } catch { retry(); }
    }, retry);
  }, [clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, ensurePronunciationSession, isActiveRepeatTurn, playWord, prepareFeedbackAudio, repeatTranscript, scheduleRepeatRetry, sentenceMode, stopListening]);
  useEffect(() => {
    beginRepeatTurnRef.current = beginRepeatTurn;
  }, [beginRepeatTurn]);

  const pauseRepeat = useCallback(() => {
    if (studyMode !== "repeat") return;
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

  const toggleRepeatPause = useCallback(() => {
    if (repeatState === "paused") {
      beginRepeatTurn(currentIndexRef.current);
      return;
    }
    pauseRepeat();
  }, [beginRepeatTurn, pauseRepeat, repeatState]);

  const speak = useCallback(() => {
    if (studyMode === "repeat") beginRepeatTurn(currentIndexRef.current);
    else playWord(studyAudioSourceRef.current);
  }, [beginRepeatTurn, playWord, studyMode]);

  const next = useCallback(() => {
    const targetIndex = nextIndexRef.current >= 0
      ? nextIndexRef.current
      : sentenceMode
        ? eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, currentIndexRef.current)
        : eligibleIndex(progressRef.current, currentIndexRef.current);
    if (targetIndex < 0) return;
    stopListening();
    clearRepeatAdvanceTimer();
    if (sentenceMode) {
      sentenceIndexRef.current = targetIndex;
      currentIndexRef.current = targetIndex;
      setNextSentenceIndex(eligibleSentenceIndex(sentenceEntriesRef.current, sentenceProgressRef.current, targetIndex));
      setSentenceIndex(targetIndex);
    } else {
      wordIndexRef.current = targetIndex;
      currentIndexRef.current = targetIndex;
      setNextWordIndex(eligibleIndex(progressRef.current, targetIndex));
      setWordIndex(targetIndex);
    }
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));

    if (studyMode === "listen") {
      playWord(sentenceMode ? sentenceEntriesRef.current[targetIndex].audio : WORDS[targetIndex][0]);
      recordStudy(targetIndex);
      return;
    }

    beginRepeatTurn(targetIndex);
  }, [beginRepeatTurn, clearRepeatAdvanceTimer, playWord, recordStudy, sentenceMode, stopListening, studyMode]);

  const activate = useCallback(() => {
    setActivated(true);
    if (studyMode === "listen") {
      playWord(studyAudioSourceRef.current);
      recordStudy(currentIndexRef.current);
      return;
    }
    beginRepeatTurn(currentIndexRef.current);
  }, [beginRepeatTurn, playWord, recordStudy, studyMode]);

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
      playWord(studyAudioSourceRef.current);
      return;
    }

    beginRepeatTurn(currentIndexRef.current);
  }, [activated, beginRepeatTurn, clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, playWord, stopListening, studyMode]);

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

      if (event.key.toLowerCase() === "r" && activated && studyMode === "repeat") {
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

  const handleCourseChange = useCallback((courseId: string) => {
    if (courseId === activeCourseId) {
      setCoursePickerOpen(false);
      return;
    }
    activeRepeatTurnRef.current = repeatTurnIdRef.current + 1;
    repeatTurnIdRef.current = activeRepeatTurnRef.current;
    repeatListeningTurnRef.current = null;
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    clearRepeatPlaybackTimer();
    clearRepeatPhaseTimers();
    currentAudioRef.current?.pause();
    stopListening();
    setActiveCourseId(courseId);
    setCoursePickerOpen(false);
    setActivated(false);
    setRepeatState("idle");
    setRepeatMessage("READY");
  }, [activeCourseId, clearRepeatAdvanceTimer, clearRepeatPhaseTimers, clearRepeatPlaybackTimer, clearRepeatRetryTimer, stopListening]);

  return (
    <main
      className="poster"
      style={{ "--bg": background, "--ink": ink, "--accent": accent } as React.CSSProperties}
      onClick={handlePosterClick}
      aria-live="polite"
    >
      <header className="topbar">
        <div className="brand-area">
          <div className="brand"><span>WORD</span><span>LOOP</span></div>
          <button
            className="course-button"
            onClick={(event) => { event.stopPropagation(); setCoursePickerOpen(true); }}
            aria-label="Choose course package"
            aria-expanded={coursePickerOpen}
          >
            <span>SWITCH COURSE</span>
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
          <button
            className="progress-button"
            onClick={(event) => { event.stopPropagation(); setPanelOpen(true); }}
            aria-label="Open learning progress"
          >
            PROGRESS · {completedWords}/{activeEntriesCount}
          </button>
        </div>
      </header>

      {!activated && (
        <div className="start-overlay" role="dialog" aria-label="Start study mode">
          <button onClick={(event) => { event.stopPropagation(); activate(); }}>
            <span className="start-icon" aria-hidden="true">▶</span>
            {studyMode === "repeat" ? "START REPEAT" : "START LEARNING"}
          </button>
          <p>{studyMode === "repeat" ? "Repeat mode" : activeCourse.description}</p>
        </div>
      )}

      <section className="word-stage">
        <div className="course-kicker">{activeCourse.title} · {currentIndex + 1}/{activeEntriesCount}</div>
        <h1 key={currentItem.id} className={sentenceMode ? "sentence-title" : currentItem.text.length > 12 ? "very-long" : currentItem.text.length > 9 ? "long" : undefined}>{currentItem.text}</h1>
        <div className="phonetic-row">
          {sentenceMode ? <div className="phonetic sentence-translation">{currentItem.meaning}</div> : <div key={`${word}-phonetic`} className="phonetic">/{phonetic}/</div>}
          <button
            className="word-play"
            onClick={(event) => {
              event.stopPropagation();
              if (activated) speak();
              else activate();
            }}
            aria-label={studyMode === "repeat" ? `Replay and repeat ${currentItem.text}` : `Play pronunciation of ${currentItem.text}`}
          >
            <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
          </button>
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
            disabled={manualNextIndex < 0}
          >
            NEXT {sentenceMode ? "SENTENCE" : "WORD"} <span aria-hidden="true">→</span>
          </button>
        </div>
      )}

      {coursePickerOpen && (
        <div
          className="panel-backdrop"
          onClick={(event) => {
            event.stopPropagation();
            if (event.target === event.currentTarget) setCoursePickerOpen(false);
          }}
        >
          <aside className="course-panel" aria-label="Course packages">
            <div className="panel-header">
              <div><span>COURSE PACKAGES</span><h2>选择课程</h2></div>
              <button onClick={() => setCoursePickerOpen(false)} aria-label="Close course selector">×</button>
            </div>
            <div className="course-list">
              {COURSE_PACKAGES.map((course) => (
                <button
                  className={course.id === activeCourse.id ? "course-card active" : "course-card"}
                  key={course.id}
                  onClick={() => handleCourseChange(course.id)}
                >
                  <span>{course.kind === "word" ? "WORD COURSE" : "DIALOGUE COURSE"}</span>
                  <strong>{course.title}</strong>
                  <small>{course.subtitle}</small>
                  <p>{course.description}</p>
                </button>
              ))}
            </div>
          </aside>
        </div>
      )}

      {panelOpen && (
        <div
          className="panel-backdrop"
          onClick={(event) => {
            event.stopPropagation();
            if (event.target === event.currentTarget) setPanelOpen(false);
          }}
        >
          <aside className="progress-panel" aria-label="Learning progress panel">
            <div className="panel-header">
              <div>
                <span>YOUR PROGRESS</span>
                <h2>{totalStudies.toLocaleString()} / {(activeEntriesCount * MAX_STUDY_COUNT).toLocaleString()}</h2>
              </div>
              <button onClick={() => setPanelOpen(false)} aria-label="Close progress panel">×</button>
            </div>
            <div className="progress-track"><i style={{ width: `${totalStudies / (activeEntriesCount * MAX_STUDY_COUNT) * 100}%` }} /></div>
            <div className="panel-stats">
              <span><b>{completedWords}</b> 已掌握</span>
              <span><b>{activeEntriesCount - completedWords}</b> 学习中</span>
            </div>
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={sentenceMode ? "搜索句子或中文翻译" : "搜索单词或中文释义"}
              aria-label={sentenceMode ? "Search sentence progress" : "Search vocabulary progress"}
            />
            <div className="word-list">
              {sentenceMode ? filteredSentences.map((entry) => {
                const count = sentenceProgress[entry.id] ?? 0;
                return <div className="word-row" key={entry.id}><div><strong>{entry.text}</strong><small>{entry.translation}</small></div><span className={count >= MAX_STUDY_COUNT ? "complete" : undefined}>{count} / {MAX_STUDY_COUNT}</span></div>;
              }) : filteredWords.map(([entry, entryMeaning, , entryPhonetic]) => {
                const count = progress[entry] ?? 0;
                return (
                  <div className="word-row" key={entry}>
                    <div><strong>{entry}</strong><small>/{entryPhonetic}/ · {entryMeaning}</small></div>
                    <span className={count >= MAX_STUDY_COUNT ? "complete" : undefined}>{count} / {MAX_STUDY_COUNT}</span>
                  </div>
                );
              })}
            </div>
          </aside>
        </div>
      )}

      <footer>
        {studyMode !== "repeat" && (
          <div className="prompt">
            {nextIndex >= 0 ? (
              <><span className="space-key">SPACE</span><span>next {sentenceMode ? "sentence" : "word"}</span></>
            ) : (
              <span>{sentenceMode ? "COURSE COMPLETE" : "ALL 570 WORDS MASTERED"}</span>
            )}
          </div>
        )}
        <div className="current-progress" aria-label={`Current progress: ${currentStudyCount} of ${MAX_STUDY_COUNT}`}>
          <strong>{currentStudyCount} / {MAX_STUDY_COUNT}</strong>
        </div>
      </footer>
    </main>
  );
}
