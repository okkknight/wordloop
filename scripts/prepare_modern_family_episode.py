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


def timestamp(value: str) -> float:
    match = ASS_TIME.match(value)
    if not match:
        raise ValueError(f"Unsupported ASS timestamp: {value}")
    hours, minutes, seconds, centiseconds = map(int, match.groups())
    return hours * 3600 + minutes * 60 + seconds + centiseconds / 100


def clean_bilingual_text(raw: str) -> tuple[str, str]:
    pieces = []
    translations = []
    for piece in raw.split(r"\N"):
        piece = TAG.sub("", piece).strip()
        if re.search(r"[A-Za-z]", piece):
            pieces.append(piece)
        elif piece:
            translations.append(piece)
    return (
        re.sub(r"\s+", " ", " ".join(pieces)).strip(),
        re.sub(r"\s+", " ", " ".join(translations)).strip(),
    )


def classify(text: str) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    words = re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text.lower())
    if not words:
        reasons.append("no-english-text")
    if STAGE_DIRECTION.fullmatch(text):
        reasons.append("stage-direction")
    if len(words) <= 1:
        reasons.append("too-short")
    if len(words) <= 2 and all(word in LOW_VALUE for word in words):
        reasons.append("low-value-utterance")
    if SPEAKER_SEPARATOR.search(text):
        reasons.append("multiple-speakers-review")
    return not any(reason in reasons for reason in ("no-english-text", "stage-direction", "too-short", "low-value-utterance")), reasons


def parse_ass(path: Path) -> list[dict[str, object]]:
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
        sentence, translation = clean_bilingual_text(fields[9])
        if not sentence:
            continue
        learnable, reasons = classify(sentence)
        entries.append({
            "id": f"s01e01-{len(entries) + 1:04d}",
            "episode": "S01E01",
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
        output = output_dir / f"{entry['id']}.mp3"
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(entry["start"]), "-i", str(audio),
            "-t", str(entry["duration"]), "-acodec", "copy", str(output),
        ], check=True)
        entry["audio"] = str(output.relative_to(output_dir.parent))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subtitle", type=Path, required=True)
    parser.add_argument("--audio", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--no-audio", action="store_true", help="Only write the manifest")
    args = parser.parse_args()

    entries = parse_ass(args.subtitle)
    args.output.mkdir(parents=True, exist_ok=True)
    if not args.no_audio:
        cut_audio(args.audio, args.output / "audio", entries)
    manifest = {
        "courseId": "modern-family-s01",
        "episode": "S01E01",
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
