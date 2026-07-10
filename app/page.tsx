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
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const skipNextAutoPlay = useRef(false);
  const [word, meaning, sublist] = WORDS[wordIndex];
  const [background, ink, accent] = PALETTES[paletteIndex];

  const speak = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.pause();
    audio.src = `/audio/${word}.m4a`;
    audio.currentTime = 0;
    setSpoken(false);
    void audio.play().then(() => setSpoken(true)).catch(() => setSpoken(false));
  }, [word]);

  const next = useCallback(() => {
    setWordIndex(nextWordIndex);
    setNextWordIndex(randomIndex(WORDS.length, nextWordIndex));
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));
  }, [nextWordIndex]);

  const activate = useCallback(() => {
    skipNextAutoPlay.current = true;
    setActivated(true);
    speak();
  }, [speak]);

  useEffect(() => {
    if (!activated) return;
    if (skipNextAutoPlay.current) {
      skipNextAutoPlay.current = false;
      return;
    }
    const timer = window.setTimeout(speak, 120);
    return () => window.clearTimeout(timer);
  }, [activated, speak]);

  useEffect(() => {
    const preload = new Audio(`/audio/${WORDS[nextWordIndex][0]}.m4a`);
    preload.preload = "auto";
    preload.load();
    return () => { preload.src = ""; };
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

      <audio ref={audioRef} preload="auto" onEnded={() => setSpoken(false)} />

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
