#!/usr/bin/env python3
"""Build sentence-level learning clips from a bilingual ASS subtitle file.

The script intentionally keeps each subtitle cue intact. Cues containing
multiple speakers or fragments are marked for review instead of being split
with guesses that could damage the audio/text alignment.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


ASS_TIME = re.compile(r"^(\d+):(\d{2}):(\d{2})\.(\d{2})$")
TAG = re.compile(r"\{[^}]*\}")
STAGE_DIRECTION = re.compile(r"^\s*\[[^]]+\]\s*$")
SPEAKER_SEPARATOR = re.compile(r"(^|\s)-\s")
LOW_VALUE = {"uh", "um", "hmm", "hm", "oh", "ah", "wow", "yeah", "yes", "no", "okay", "ok"}
CHARACTER_NAMES = {
    "alex", "brenda", "cam", "cameron", "claire", "dylan", "feldman", "gloria",
    "haley", "jay", "joe", "josh", "lily", "luke", "manny", "mitch", "mitchell",
    "pepper", "phil", "pritchett", "ryan",
}
SHORT_KEEP = {
    "come on", "excuse me", "who's that", "what's wrong with it", "not really",
    "oh god", "hang on one second", "what's the word", "you two broke up",
    "we adopted a baby", "of course it is", "it's supposed to hurt",
}
LOW_VALUE_EXACT = {
    "kids breakfast", "yes the murders", "there be free", "and do what",
    "yes you are", "no you're not", "i've done my job", "i've done our job",
    "we're very different", "that's cool", "i know", "that's not",
    "phil dunphy yo", "one hat", "my dad", "i mean seriously",
    "yeah it was her head okay okay", "yes yes i know", "doggy doggy here doggy",
    "okay there you go", "okay all right thank you thanks that helps okay okay",
    "june found a stick", "girls who play in university orchestras",
    "niagara falls and log rides", "who's a dancing queen huh", "where's where's doggy",
    "i knew it we both knew it", "he got his jaunty butt kicked",
    "it was a wig actually sort of a ghetto fabulous afro thing",
    "you thought ghetto fabulous might be medically relevant",
    "we don't have a lot of pho there", "that was a joke", "oh geez look at that",
    "what's wrong with me", "hey uh alex you", "emergency assistance this is trina",
    "daddy wins do you believe in miracles", "kind of the best job in the world",
    "parking ticket from the mall",
}
NON_ENGLISH_PATTERNS = (
    re.compile(r"\bvamos\b", re.IGNORECASE),
    re.compile(r"\ba\s+la\s+derecha\b", re.IGNORECASE),
    re.compile(r"\bmentira\b", re.IGNORECASE),
    re.compile(r"\bay\W+miren\b", re.IGNORECASE),
    re.compile(r"\bmi\s+ni(?:n|ñ)?o\s+peque(?:n|ñ)?o\b", re.IGNORECASE),
    re.compile(r"\blindo\b", re.IGNORECASE),
)


def timestamp(value: str) -> float:
    match = ASS_TIME.match(value)
    if not match:
        raise ValueError(f"Unsupported ASS timestamp: {value}")
    hours, minutes, seconds, centiseconds = map(int, match.groups())
    return hours * 3600 + minutes * 60 + seconds + centiseconds / 100


def clean_bilingual_text(raw: str) -> tuple[str, str, bool]:
    pieces = []
    translations = []
    mixed_caption = False
    for piece in raw.split(r"\N"):
        piece = TAG.sub("", piece).strip()
        if re.search(r"[A-Za-z]", piece):
            if re.search(r"[\u3400-\u9fff]", piece):
                mixed_caption = True
            pieces.append(piece)
        elif piece:
            translations.append(piece)
    return (
        re.sub(r"\s+", " ", " ".join(pieces)).strip(),
        re.sub(r"\s+", " ", " ".join(translations)).strip(),
        mixed_caption,
    )


def classify(text: str, mixed_caption: bool) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    words = re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text.lower())
    normalized = " ".join(words)
    if not words:
        reasons.append("no-english-text")
    if STAGE_DIRECTION.fullmatch(text):
        reasons.append("stage-direction")
    if mixed_caption:
        reasons.append("mixed-language-caption")
    if len(words) <= 1:
        reasons.append("too-short")
    if len(words) < 4 and normalized not in SHORT_KEEP:
        reasons.append("short-low-context")
    if normalized in LOW_VALUE_EXACT:
        reasons.append("low-value-utterance")
    # Repeated acknowledgements or emotional interjections do not form useful
    # sentence practice, even when the cue contains several repeated words.
    if len(words) > 0 and all(word in LOW_VALUE for word in words):
        reasons.append("low-value-utterance")
    if SPEAKER_SEPARATOR.search(text):
        reasons.append("multiple-speakers")
    if words and all(word in CHARACTER_NAMES for word in words):
        reasons.append("name-only")
    if any(pattern.search(text) for pattern in NON_ENGLISH_PATTERNS):
        reasons.append("non-english-utterance")
    first_letter = re.search(r"[A-Za-z]", text)
    if first_letter and text[first_letter.start()].islower():
        reasons.append("sentence-fragment")
    terminal = text.rstrip().rstrip('"\'”')
    if (
        terminal.endswith("...")
        or not terminal.endswith((".", "!", "?"))
        or re.search(r"[A-Za-z]-\s", text)
        or text.lower().startswith(("and ", "but ", "or ", "to ", "with ", "which ", "if "))
    ):
        reasons.append("sentence-fragment")
    if len(set(words)) == 1 and len(words) > 1:
        reasons.append("repetitive-utterance")
    blocking = {
        "no-english-text", "stage-direction", "mixed-language-caption", "too-short",
        "short-low-context", "low-value-utterance", "multiple-speakers", "name-only",
        "non-english-utterance", "sentence-fragment", "repetitive-utterance",
    }
    return not any(reason in blocking for reason in reasons), reasons


def parse_ass(path: Path, episode: str) -> list[dict[str, object]]:
    text = path.read_text(encoding="utf-16")
    entries: list[dict[str, object]] = []
    for line in text.splitlines():
        if not line.startswith("Dialogue:"):
            continue
        fields = line.split(",", 9)
        if len(fields) != 10:
            continue
        start = timestamp(fields[1])
        end = timestamp(fields[2])
        sentence, translation, mixed_caption = clean_bilingual_text(fields[9])
        if not sentence:
            continue
        learnable, reasons = classify(sentence, mixed_caption)
        entries.append({
            "id": f"{episode.lower()}-{len(entries) + 1:04d}",
            "episode": episode,
            "start": start,
            "end": end,
            "duration": round(end - start, 2),
            "text": sentence,
            "translation": translation,
            "learnable": learnable,
            "reviewReasons": reasons,
        })
    return entries


def cut_audio(audio: Path, output_dir: Path, entries: list[dict[str, object]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        if not entry["learnable"]:
            continue
        output = output_dir / f"{entry['id']}.m4a"
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(entry["start"]), "-i", str(audio),
            "-t", str(entry["duration"]), "-vn", "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(output),
        ], check=True)
        entry["audio"] = str(output.relative_to(output_dir.parent))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subtitle", type=Path, required=True)
    parser.add_argument("--audio", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--episode", default="S01E01", help="Episode code, for example S01E02")
    parser.add_argument("--no-audio", action="store_true", help="Only write the manifest")
    args = parser.parse_args()

    episode = args.episode.upper()
    if not re.fullmatch(r"S\d{2}E\d{2}", episode):
        raise ValueError("Episode must use the format S01E02")
    entries = parse_ass(args.subtitle, episode)
    args.output.mkdir(parents=True, exist_ok=True)
    if not args.no_audio:
        cut_audio(args.audio, args.output / "audio", entries)
    manifest = {
        "courseId": f"modern-family-{episode.lower()}",
        "episode": episode,
        "sourceAudio": str(args.audio),
        "sourceSubtitle": str(args.subtitle),
        "entries": entries,
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "entries": len(entries),
        "learnable": sum(1 for entry in entries if entry["learnable"]),
        "review_or_filtered": sum(1 for entry in entries if not entry["learnable"]),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
