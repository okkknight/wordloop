"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { WORDS } from "./words";

const MAX_STUDY_COUNT = 50;
const USER_ID_KEY = "word-loop-user-id";
const PROGRESS_KEY = "word-loop-progress";
type ProgressMap = Record<string, number>;

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

export default function Home() {
  const [wordIndex, setWordIndex] = useState(() => randomIndex(WORDS.length));
  const [nextWordIndex, setNextWordIndex] = useState(() => randomIndex(WORDS.length));
  const [paletteIndex, setPaletteIndex] = useState(() => randomIndex(PALETTES.length));
  const [spoken, setSpoken] = useState(false);
  const [activated, setActivated] = useState(false);
  const [progress, setProgress] = useState<ProgressMap>({});
  const [panelOpen, setPanelOpen] = useState(false);
  const [search, setSearch] = useState("");
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const preloadedAudioRef = useRef<HTMLAudioElement | null>(null);
  const userIdRef = useRef("");
  const [word, meaning, sublist, phonetic] = WORDS[wordIndex];
  const [background, ink, accent] = PALETTES[paletteIndex];
  const currentStudyCount = progress[word] ?? 0;
  const totalStudies = Object.values(progress).reduce((sum, count) => sum + count, 0);
  const completedWords = WORDS.filter(([entry]) => (progress[entry] ?? 0) >= MAX_STUDY_COUNT).length;
  const filteredWords = WORDS.filter(([entry, entryMeaning]) =>
    `${entry} ${entryMeaning}`.toLowerCase().includes(search.trim().toLowerCase()),
  );

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

  const playWord = useCallback((targetWord: string) => {
    const source = new URL(`/audio/${targetWord}.m4a`, window.location.href).href;
    const preloaded = preloadedAudioRef.current;
    const audio = preloaded?.src === source ? preloaded : new Audio(source);

    currentAudioRef.current?.pause();
    currentAudioRef.current = audio;
    if (audio === preloaded) preloadedAudioRef.current = null;
    audio.currentTime = 0;
    audio.onended = () => setSpoken(false);
    setSpoken(false);
    void audio.play().then(() => setSpoken(true)).catch(() => setSpoken(false));
  }, []);

  const speak = useCallback(() => {
    playWord(word);
  }, [playWord, word]);

  const next = useCallback(() => {
    if (nextWordIndex < 0) return;
    playWord(WORDS[nextWordIndex][0]);
    setWordIndex(nextWordIndex);
    recordStudy(nextWordIndex);
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));
  }, [nextWordIndex, playWord, recordStudy]);

  const activate = useCallback(() => {
    setActivated(true);
    speak();
    recordStudy(wordIndex);
  }, [recordStudy, speak, wordIndex]);

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
        if (activated) next();
        else activate();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activate, activated, next]);

  return (
    <main
      className="poster"
      style={{ "--bg": background, "--ink": ink, "--accent": accent } as React.CSSProperties}
      onClick={activated ? next : activate}
      aria-live="polite"
    >
      <header className="topbar">
        <div className="brand"><span>WORD</span><span>LOOP</span></div>
        <div className="header-actions">
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
            aria-label={`Play pronunciation of ${word}`}
          >
            <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
            PLAY SOUND
          </button>
        </div>
      </header>

      {!activated && (
        <div className="start-overlay" role="dialog" aria-label="Start listening mode">
          <button onClick={(event) => { event.stopPropagation(); activate(); }}>
            <span className="start-icon" aria-hidden="true">▶</span>
            START LEARNING
          </button>
          <p>British pronunciation · 570 academic words</p>
        </div>
      )}

      <section className="word-stage">
        <div className="eyebrow">
          AWL · SUBLIST {sublist} · WORD {String(wordIndex + 1).padStart(3, "0")} / {WORDS.length}
        </div>
        <h1 key={word} className={word.length > 12 ? "very-long" : word.length > 9 ? "long" : undefined}>{word}</h1>
        <div className="word-meta">
          <div key={`${word}-phonetic`} className="phonetic">/{phonetic}/</div>
          <div className="study-count">已学习 {currentStudyCount} / {MAX_STUDY_COUNT}</div>
        </div>
        <p key={`${word}-meaning`} className="meaning">{meaning}</p>
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
          {nextWordIndex >= 0 ? (
            <><span className="space-key">SPACE</span><span>next word</span></>
          ) : (
            <span>ALL 570 WORDS MASTERED</span>
          )}
        </div>
        <div className="status">
          <span className={spoken ? "dot active" : "dot"} />
          {spoken ? "PLAYING BRITISH AUDIO" : activated ? "AUDIO READY" : "CLICK TO START"}
        </div>
      </footer>
    </main>
  );
}
