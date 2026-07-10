"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { WORDS } from "./words";

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

export default function Home() {
  const [wordIndex, setWordIndex] = useState(() => randomIndex(WORDS.length));
  const [nextWordIndex, setNextWordIndex] = useState(() => randomIndex(WORDS.length));
  const [paletteIndex, setPaletteIndex] = useState(() => randomIndex(PALETTES.length));
  const [spoken, setSpoken] = useState(false);
  const [activated, setActivated] = useState(false);
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const preloadedAudioRef = useRef<HTMLAudioElement | null>(null);
  const [word, meaning, sublist, phonetic] = WORDS[wordIndex];
  const [background, ink, accent] = PALETTES[paletteIndex];

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
    playWord(WORDS[nextWordIndex][0]);
    setWordIndex(nextWordIndex);
    setNextWordIndex(randomIndex(WORDS.length, nextWordIndex));
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));
  }, [nextWordIndex, playWord]);

  const activate = useCallback(() => {
    setActivated(true);
    speak();
  }, [speak]);

  useEffect(() => {
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
        <button
          className="sound"
          onClick={(event) => { event.stopPropagation(); activated ? speak() : activate(); }}
          aria-label={`Play pronunciation of ${word}`}
        >
          <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
          PLAY SOUND
        </button>
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
        <div key={`${word}-phonetic`} className="phonetic">/{phonetic}/</div>
        <p key={`${word}-meaning`} className="meaning">{meaning}</p>
      </section>

      <footer>
        <div className="prompt">
          <span className="space-key">SPACE</span>
          <span>next word</span>
        </div>
        <div className="status">
          <span className={spoken ? "dot active" : "dot"} />
          {spoken ? "PLAYING BRITISH AUDIO" : activated ? "AUDIO READY" : "CLICK TO START"}
        </div>
      </footer>
    </main>
  );
}
