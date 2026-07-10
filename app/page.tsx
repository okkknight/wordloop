"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { WORDS } from "./words";

const MAX_STUDY_COUNT = 50;
const PASS_SCORE = 22;
const AUTO_ADVANCE_MS = 700;
const USER_ID_KEY = "word-loop-user-id";
const PROGRESS_KEY = "word-loop-progress";

type ProgressMap = Record<string, number>;
type StudyMode = "listen" | "repeat";
type RepeatState =
  | "idle"
  | "connecting"
  | "ready"
  | "playing"
  | "listening"
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

function normalizeSpeech(value: string) {
  return value.toLowerCase().replace(/[^a-z]/g, "");
}

function repeatStatusLabel(state: RepeatState) {
  switch (state) {
    case "connecting":
      return "Connecting";
    case "ready":
      return "Ready";
    case "playing":
      return "Playing";
    case "listening":
      return "Listening";
    case "scoring":
      return "Checking";
    case "passed":
      return "Good";
    case "paused":
      return "Paused";
    case "retry":
      return "Retrying";
    case "error":
      return "Mic retry";
    default:
      return "Stand by";
  }
}

function repeatStatusHint(state: RepeatState) {
  switch (state) {
    case "connecting":
      return "Setting up voice session";
    case "ready":
      return "Tap or press space to repeat";
    case "playing":
      return "Listen to the model pronunciation";
    case "listening":
      return "Speak now";
    case "scoring":
      return "Matching your pronunciation";
    case "passed":
      return "Moving to the next word";
    case "paused":
      return "Resume when you are ready";
    case "retry":
      return "Trying this word again";
    case "error":
      return "Recovering microphone input";
    default:
      return "Repeat mode is ready";
  }
}

function repeatFeedbackLabel(message: string, state: RepeatState) {
  if (message === "PASS" || state === "passed") return "Good";
  if (message === "TRY AGAIN" || state === "retry") return "Almost";
  if (state === "error") return "Retrying";
  if (state === "scoring") return "Checking";
  return "";
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
  const candidates = transcript
    .split(/\s+/)
    .map(normalizeSpeech)
    .filter(Boolean);
  const pool = candidates.length ? candidates : [normalizeSpeech(transcript)];

  let matched = "";
  let bestSimilarity = 0;

  for (const candidate of pool) {
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

  const exact = pool.includes(normalizedTarget);
  const score = exact
    ? 100
    : Math.max(8, Math.round(bestSimilarity * 100 - Math.max(0, pool.length - 1) * 4));
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
  const [paletteIndex, setPaletteIndex] = useState(() => randomIndex(PALETTES.length));
  const [studyMode, setStudyMode] = useState<StudyMode>("listen");
  const [spoken, setSpoken] = useState(false);
  const [activated, setActivated] = useState(false);
  const [progress, setProgress] = useState<ProgressMap>({});
  const [panelOpen, setPanelOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [repeatState, setRepeatState] = useState<RepeatState>("idle");
  const [repeatMessage, setRepeatMessage] = useState("READY");
  const [repeatTranscript, setRepeatTranscript] = useState("");
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const preloadedAudioRef = useRef<HTMLAudioElement | null>(null);
  const dataChannelRef = useRef<RTCDataChannel | null>(null);
  const peerConnectionRef = useRef<RTCPeerConnection | null>(null);
  const repeatAdvanceTimerRef = useRef<number | null>(null);
  const repeatRetryTimerRef = useRef<number | null>(null);
  const repeatTrackRef = useRef<MediaStreamTrack | null>(null);
  const repeatWordRef = useRef("");
  const repeatStreamRef = useRef<MediaStream | null>(null);
  const userIdRef = useRef("");
  const nextWordIndexRef = useRef(nextWordIndex);
  const wordIndexRef = useRef(wordIndex);
  const [word, meaning, , phonetic] = WORDS[wordIndex];
  const [background, ink, accent] = PALETTES[paletteIndex];
  const currentStudyCount = progress[word] ?? 0;
  const totalStudies = Object.values(progress).reduce((sum, count) => sum + count, 0);
  const completedWords = WORDS.filter(([entry]) => (progress[entry] ?? 0) >= MAX_STUDY_COUNT).length;
  const filteredWords = WORDS.filter(([entry, entryMeaning]) =>
    `${entry} ${entryMeaning}`.toLowerCase().includes(search.trim().toLowerCase()),
  );
  const repeatLabel = repeatStatusLabel(repeatState);
  const repeatHint = repeatStatusHint(repeatState);
  const repeatFeedback = repeatFeedbackLabel(repeatMessage, repeatState);
  const showRepeatFeedback = repeatState === "retry" || repeatState === "error";
  const showRepeatTranscript = Boolean(repeatTranscript) && (repeatState === "retry" || repeatState === "error");

  const stopListening = useCallback(() => {
    if (repeatTrackRef.current) repeatTrackRef.current.enabled = false;
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

    let cachedProgress: ProgressMap = {};
    try {
      cachedProgress = JSON.parse(localStorage.getItem(PROGRESS_KEY) ?? "{}") as ProgressMap;
      applyProgress(cachedProgress);
    } catch {
      localStorage.removeItem(PROGRESS_KEY);
    }

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

  useEffect(() => () => {
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    currentAudioRef.current?.pause();
    preloadedAudioRef.current?.pause();
    stopListening();
    peerConnectionRef.current?.close();
    dataChannelRef.current?.close();
    repeatStreamRef.current?.getTracks().forEach((track) => track.stop());
  }, [clearRepeatAdvanceTimer, clearRepeatRetryTimer, stopListening]);

  const recordStudy = useCallback((index: number) => {
    const studiedWord = WORDS[index][0];
    setProgress((current) => {
      const next = {
        ...current,
        [studiedWord]: Math.min(MAX_STUDY_COUNT, (current[studiedWord] ?? 0) + 1),
      };
      localStorage.setItem(PROGRESS_KEY, JSON.stringify(next));
      setNextWordIndex(eligibleIndex(next, index));
      return next;
    });

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
        localStorage.setItem(PROGRESS_KEY, JSON.stringify(next));
        return next;
      });
    }).catch(() => undefined);
  }, []);

  const playWord = useCallback((targetWord: string, onEnded?: () => void) => {
    const source = new URL(`/audio/${targetWord}.m4a`, window.location.href).href;
    const preloaded = preloadedAudioRef.current;
    const audio = preloaded?.src === source ? preloaded : new Audio(source);

    currentAudioRef.current?.pause();
    currentAudioRef.current = audio;
    if (audio === preloaded) preloadedAudioRef.current = null;
    audio.currentTime = 0;
    audio.onended = () => {
      setSpoken(false);
      onEnded?.();
    };
    setSpoken(false);
    void audio.play().then(() => setSpoken(true)).catch(() => setSpoken(false));
  }, []);

  const ensurePronunciationSession = useCallback(async () => {
    const dataChannel = dataChannelRef.current;
    const existingPeer = peerConnectionRef.current;
    if (
      existingPeer &&
      dataChannel &&
      (dataChannel.readyState === "open" || existingPeer.connectionState === "connected")
    ) {
      return;
    }

    setRepeatState("connecting");
    setRepeatMessage("CONNECTING");

    const stream = repeatStreamRef.current ?? await navigator.mediaDevices.getUserMedia({
      audio: {
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
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

    channel.addEventListener("message", (event) => {
      const payload = JSON.parse(event.data) as {
        transcript?: string;
        type: string;
      };

      if (payload.type === "input_audio_buffer.speech_started") {
        setRepeatMessage("LISTENING");
        setRepeatState("listening");
        return;
      }

      if (
        payload.type === "input_audio_buffer.speech_stopped" ||
        payload.type === "input_audio_buffer.committed"
      ) {
        setRepeatMessage("SCORING");
        setRepeatState("scoring");
        return;
      }

        if (payload.type === "conversation.item.input_audio_transcription.completed") {
          stopListening();
          const transcript = (payload.transcript ?? "").trim();
          const result = scoreTranscript(repeatWordRef.current, transcript);
          setRepeatMessage(result.feedback);

        if (result.passed) {
          setRepeatState("passed");
          recordStudy(wordIndexRef.current);
          clearRepeatAdvanceTimer();
          clearRepeatRetryTimer();
          repeatAdvanceTimerRef.current = window.setTimeout(() => {
            if (nextWordIndexRef.current < 0) return;
            const upcomingIndex = nextWordIndexRef.current;
            setWordIndex(upcomingIndex);
            setPaletteIndex((current) => randomIndex(PALETTES.length, current));
            repeatWordRef.current = WORDS[upcomingIndex][0];
            playWord(WORDS[upcomingIndex][0], async () => {
              try {
                await ensurePronunciationSession();
                setRepeatMessage("LISTENING");
                setRepeatState("listening");
                if (repeatTrackRef.current) repeatTrackRef.current.enabled = true;
              } catch (error) {
                setRepeatState("error");
                setRepeatMessage("RETRYING");
                clearRepeatRetryTimer();
                repeatRetryTimerRef.current = window.setTimeout(() => {
                  beginRepeatTurn(wordIndexRef.current);
                }, 1200);
              }
            });
          }, AUTO_ADVANCE_MS);
        } else {
          setRepeatState("retry");
          setRepeatMessage("RETRYING");
          clearRepeatRetryTimer();
          repeatRetryTimerRef.current = window.setTimeout(() => {
            beginRepeatTurn(wordIndexRef.current);
          }, 850);
        }
        return;
      }

      if (payload.type === "conversation.item.input_audio_transcription.failed") {
        stopListening();
        setRepeatState("error");
        setRepeatMessage("RETRYING");
        clearRepeatRetryTimer();
        repeatRetryTimerRef.current = window.setTimeout(() => {
          beginRepeatTurn(wordIndexRef.current);
        }, 1200);
      }
    });

    const openPromise = new Promise<void>((resolve, reject) => {
      channel.addEventListener("open", () => resolve(), { once: true });
      channel.addEventListener("error", () => reject(new Error("Realtime channel failed.")), { once: true });
    });

    const offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);

    const response = await fetch("/api/pronunciation-session", {
      method: "POST",
      headers: {
        "Content-Type": "application/sdp",
        ...(userIdRef.current ? { "x-user-id": userIdRef.current } : {}),
      },
      body: offer.sdp,
    });

    if (!response.ok) {
      const payload = await response.json().catch(() => ({ error: "Unable to start realtime session." }));
      throw new Error(payload.error || "Unable to start realtime session.");
    }

    await peerConnection.setRemoteDescription({
      type: "answer",
      sdp: await response.text(),
    });
    await openPromise;
    setRepeatState("ready");
    setRepeatMessage("READY");
  }, [clearRepeatAdvanceTimer, nextWordIndex, playWord, recordStudy, stopListening]);

  const beginRepeatTurn = useCallback((targetIndex: number) => {
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    stopListening();
    repeatWordRef.current = WORDS[targetIndex][0];
    setRepeatState("playing");
    setRepeatMessage("PLAYING");
    void ensurePronunciationSession().catch((error) => {
      setRepeatState("error");
      setRepeatMessage("RETRYING");
      clearRepeatRetryTimer();
      repeatRetryTimerRef.current = window.setTimeout(() => {
        beginRepeatTurn(wordIndexRef.current);
      }, 1200);
    });
    playWord(WORDS[targetIndex][0], async () => {
      try {
        await ensurePronunciationSession();
        setRepeatState("listening");
        setRepeatMessage("LISTENING");
        if (repeatTrackRef.current) repeatTrackRef.current.enabled = true;
      } catch (error) {
        setRepeatState("error");
        setRepeatMessage("RETRYING");
        clearRepeatRetryTimer();
        repeatRetryTimerRef.current = window.setTimeout(() => {
          beginRepeatTurn(wordIndexRef.current);
        }, 1200);
      }
    });
  }, [clearRepeatAdvanceTimer, clearRepeatRetryTimer, ensurePronunciationSession, playWord, stopListening]);

  const pauseRepeat = useCallback(() => {
    if (studyMode !== "repeat") return;
    clearRepeatAdvanceTimer();
    clearRepeatRetryTimer();
    currentAudioRef.current?.pause();
    setSpoken(false);
    stopListening();
    setRepeatState("paused");
    setRepeatMessage("PAUSED");
  }, [clearRepeatAdvanceTimer, clearRepeatRetryTimer, stopListening, studyMode]);

  const toggleRepeatPause = useCallback(() => {
    if (repeatState === "paused") {
      beginRepeatTurn(wordIndexRef.current);
      return;
    }
    pauseRepeat();
  }, [beginRepeatTurn, pauseRepeat, repeatState]);

  const speak = useCallback(() => {
    if (studyMode === "repeat") beginRepeatTurn(wordIndexRef.current);
    else playWord(word);
  }, [beginRepeatTurn, playWord, studyMode, word]);

  const next = useCallback(() => {
    if (nextWordIndex < 0) return;
    stopListening();
    clearRepeatAdvanceTimer();
    setWordIndex(nextWordIndex);
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));

    if (studyMode === "listen") {
      playWord(WORDS[nextWordIndex][0]);
      recordStudy(nextWordIndex);
      return;
    }

    beginRepeatTurn(nextWordIndex);
  }, [beginRepeatTurn, clearRepeatAdvanceTimer, nextWordIndex, playWord, recordStudy, stopListening, studyMode]);

  const activate = useCallback(() => {
    setActivated(true);
    if (studyMode === "listen") {
      playWord(word);
      recordStudy(wordIndex);
      return;
    }
    beginRepeatTurn(wordIndex);
  }, [beginRepeatTurn, playWord, recordStudy, studyMode, word, wordIndex]);

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
      setRepeatState("idle");
      setRepeatMessage("READY");
      playWord(word);
      return;
    }

    beginRepeatTurn(wordIndexRef.current);
  }, [activated, beginRepeatTurn, clearRepeatAdvanceTimer, clearRepeatRetryTimer, playWord, stopListening, studyMode, word]);

  useEffect(() => {
    if (nextWordIndex < 0) return;
    const preload = new Audio(`/audio/${WORDS[nextWordIndex][0]}.m4a`);
    preload.preload = "auto";
    preload.load();
    preloadedAudioRef.current = preload;
    return () => {
      if (preloadedAudioRef.current === preload) {
        preloadedAudioRef.current = null;
        preload.src = "";
      }
    };
  }, [nextWordIndex]);

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
          repeatState === "retry" ||
          repeatState === "error" ||
          repeatState === "ready" ||
          repeatState === "idle" ||
          repeatState === "paused"
        ) {
          beginRepeatTurn(wordIndexRef.current);
        }
        return;
      }

      if (event.key.toLowerCase() === "r" && activated && studyMode === "repeat") {
        event.preventDefault();
        beginRepeatTurn(wordIndexRef.current);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activate, activated, beginRepeatTurn, next, repeatState, studyMode]);

  const handlePosterClick = useCallback(() => {
    if (!activated) {
      activate();
      return;
    }

    if (studyMode === "listen") {
      next();
      return;
    }

    if (repeatState === "listening" || repeatState === "scoring" || repeatState === "playing") return;
    beginRepeatTurn(wordIndexRef.current);
  }, [activate, activated, beginRepeatTurn, next, repeatState, studyMode]);

  return (
    <main
      className="poster"
      style={{ "--bg": background, "--ink": ink, "--accent": accent } as React.CSSProperties}
      onClick={handlePosterClick}
      aria-live="polite"
    >
      <header className="topbar">
        <div className="brand"><span>WORD</span><span>LOOP</span></div>
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
            PROGRESS · {completedWords}/{WORDS.length}
          </button>
          <button
            className="sound"
            onClick={(event) => { event.stopPropagation(); activated ? speak() : activate(); }}
            aria-label={studyMode === "repeat" ? `Replay and repeat ${word}` : `Play pronunciation of ${word}`}
          >
            <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
            {studyMode === "repeat" ? "REPEAT WORD" : "PLAY SOUND"}
          </button>
        </div>
      </header>

      {!activated && (
        <div className="start-overlay" role="dialog" aria-label="Start study mode">
          <button onClick={(event) => { event.stopPropagation(); activate(); }}>
            <span className="start-icon" aria-hidden="true">▶</span>
            {studyMode === "repeat" ? "START REPEAT" : "START LEARNING"}
          </button>
          <p>{studyMode === "repeat" ? "Repeat mode" : "British pronunciation · 570 academic words"}</p>
        </div>
      )}

      <section className="word-stage">
        <h1 key={word} className={word.length > 12 ? "very-long" : word.length > 9 ? "long" : undefined}>{word}</h1>
        <div key={`${word}-phonetic`} className="phonetic">/{phonetic}/</div>
        <p key={`${word}-meaning`} className="meaning">{meaning}</p>
        {studyMode === "repeat" && (
          <div className={`repeat-card ${repeatState}`}>
            <div className="repeat-copy">
              <div className="repeat-head">
                <span className="repeat-mode-badge">Repeat mode</span>
                <span className={`repeat-state-chip ${repeatState}`}>
                  <i aria-hidden="true" />
                  {repeatLabel}
                </span>
              </div>
              <div className={`repeat-siri ${repeatState}`} aria-label={`Repeat mode ${repeatMessage.toLowerCase()}`}>
                <span className="repeat-siri-orb" aria-hidden="true">
                  <i /><i /><i /><i />
                </span>
                <div className="repeat-body">
                  <strong>{repeatLabel}</strong>
                  <span>{repeatHint}</span>
                </div>
                <span className="sr-only">{repeatMessage}</span>
              </div>
              {showRepeatFeedback && repeatFeedback && (
                <div className={`repeat-feedback ${repeatState}`}>
                  <strong>{repeatFeedback}</strong>
                  <span>{repeatState === "retry" ? "One more clean read" : "Recovering and restarting"}</span>
                </div>
              )}
              {showRepeatTranscript && (
                <div className="repeat-transcript">
                  <span>You said</span>
                  <strong>{repeatTranscript}</strong>
                </div>
              )}
            </div>
            <button
              className="repeat-toggle"
              onClick={(event) => { event.stopPropagation(); toggleRepeatPause(); }}
              aria-label={repeatState === "paused" ? "Resume repeat" : "Pause repeat"}
              aria-pressed={repeatState === "paused"}
            >
              <span aria-hidden="true" className={repeatState === "paused" ? "repeat-toggle-play" : "repeat-toggle-pause"} />
            </button>
          </div>
        )}
      </section>

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
                <h2>{totalStudies.toLocaleString()} / {(WORDS.length * MAX_STUDY_COUNT).toLocaleString()}</h2>
              </div>
              <button onClick={() => setPanelOpen(false)} aria-label="Close progress panel">×</button>
            </div>
            <div className="progress-track"><i style={{ width: `${totalStudies / (WORDS.length * MAX_STUDY_COUNT) * 100}%` }} /></div>
            <div className="panel-stats">
              <span><b>{completedWords}</b> 已掌握</span>
              <span><b>{WORDS.length - completedWords}</b> 学习中</span>
            </div>
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="搜索单词或中文释义"
              aria-label="Search vocabulary progress"
            />
            <div className="word-list">
              {filteredWords.map(([entry, entryMeaning, , entryPhonetic]) => {
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
        <div className="prompt">
          {studyMode === "repeat" ? (
            <><span className="space-key">SPACE</span><span>retry current word</span></>
          ) : nextWordIndex >= 0 ? (
            <><span className="space-key">SPACE</span><span>next word</span></>
          ) : (
            <span>ALL 570 WORDS MASTERED</span>
          )}
        </div>
        <div className="current-progress">
          <span>THIS WORD</span>
          <strong>{currentStudyCount} / {MAX_STUDY_COUNT}</strong>
        </div>
        <div className="status">
          <span className={spoken ? "dot active" : "dot"} />
          {studyMode === "repeat"
            ? repeatState === "connecting"
              ? "CONNECTING"
              : repeatState === "listening"
                ? "LISTENING"
                : repeatState === "scoring"
                  ? "SCORING"
                  : activated
                    ? "READY"
                    : "CLICK TO START"
            : spoken
              ? "PLAYING BRITISH AUDIO"
              : activated
                ? "AUDIO READY"
                : "CLICK TO START"}
        </div>
      </footer>
    </main>
  );
}
