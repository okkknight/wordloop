"use client";

import { useCallback, useEffect, useRef, useState } from "react";

const WORDS = [
  ["serendipity", "a happy discovery made by chance"],
  ["resilient", "able to recover and grow after difficulty"],
  ["wanderlust", "a strong desire to travel"],
  ["eloquent", "fluent, graceful, and persuasive"],
  ["tranquil", "calm, quiet, and peaceful"],
  ["curiosity", "a strong wish to know or learn"],
  ["radiant", "shining brightly with joy or light"],
  ["meticulous", "very careful about small details"],
  ["ephemeral", "lasting for only a short time"],
  ["audacious", "bold and willing to take risks"],
  ["mellifluous", "pleasantly smooth and musical to hear"],
  ["nostalgia", "affection for a remembered time"],
  ["luminous", "softly bright or full of light"],
  ["tenacious", "determined and unwilling to give up"],
  ["whimsical", "playfully unusual and imaginative"],
  ["solitude", "the peaceful state of being alone"],
  ["flourish", "to grow or develop successfully"],
  ["harmony", "a pleasing balance of different parts"],
  ["vivid", "producing clear, powerful images"],
  ["sincere", "honest, genuine, and heartfelt"],
  ["embrace", "to accept something with enthusiasm"],
  ["momentum", "the force that keeps progress moving"],
  ["perspective", "a particular way of seeing something"],
  ["ineffable", "too extraordinary to describe in words"],
] as const;

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
  const [word, meaning] = WORDS[wordIndex];
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
        <div className="eyebrow">WORD #{String(wordIndex + 1).padStart(2, "0")}</div>
        <h1 key={word}>{word}</h1>
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
