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
  const [paletteIndex, setPaletteIndex] = useState(() => randomIndex(PALETTES.length));
  const [spoken, setSpoken] = useState(false);
  const firstRender = useRef(true);
  const [word, meaning, sublist] = WORDS[wordIndex];
  const [background, ink, accent] = PALETTES[paletteIndex];

  const speak = useCallback(() => {
    if (!("speechSynthesis" in window)) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(word);
    utterance.lang = "en-US";
    utterance.rate = 0.82;
    utterance.pitch = 1;
    utterance.onstart = () => setSpoken(true);
    window.speechSynthesis.speak(utterance);
  }, [word]);

  const next = useCallback(() => {
    setWordIndex((current) => randomIndex(WORDS.length, current));
    setPaletteIndex((current) => randomIndex(PALETTES.length, current));
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(speak, firstRender.current ? 380 : 120);
    firstRender.current = false;
    return () => window.clearTimeout(timer);
  }, [speak]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.code === "Space") {
        event.preventDefault();
        next();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [next]);

  return (
    <main
      className="poster"
      style={{ "--bg": background, "--ink": ink, "--accent": accent } as React.CSSProperties}
      onClick={next}
      aria-live="polite"
    >
      <header className="topbar">
        <div className="brand"><span>WORD</span><span>LOOP</span></div>
        <button
          className="sound"
          onClick={(event) => { event.stopPropagation(); speak(); }}
          aria-label={`Play pronunciation of ${word}`}
        >
          <span className="sound-bars" aria-hidden="true"><i /><i /><i /></span>
          PLAY SOUND
        </button>
      </header>

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
          {spoken ? "LISTENING MODE" : "CLICK TO START SOUND"}
        </div>
      </footer>
    </main>
  );
}
