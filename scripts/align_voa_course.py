#!/usr/bin/env python3
"""Rebuild a VOA course only from reviewed word-level timestamps.

The command deliberately refuses missing or ambiguous text matches. Callers must
resolve those cases in the manifest (or pass an explicit occurrence) before any
course assets are replaced.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path


WORD = re.compile(r"[a-z0-9']+")


def normalized_words(text: str) -> list[str]:
    return [word.replace("'", "") for word in WORD.findall(text.lower())]


def parse_occurrences(values: list[str]) -> dict[str, int]:
    occurrences: dict[str, int] = {}
    for value in values:
        entry_id, separator, occurrence = value.partition("=")
        if not separator or not entry_id or not occurrence.isdigit() or int(occurrence) < 1:
            raise ValueError(f"Invalid occurrence override: {value}; use entry-id=1")
        occurrences[entry_id] = int(occurrence)
    return occurrences


def parse_alignment_texts(values: list[str]) -> dict[str, str]:
    texts: dict[str, str] = {}
    for value in values:
        entry_id, separator, text = value.partition("=")
        if not separator or not entry_id or not text:
            raise ValueError(f"Invalid alignment-text override: {value}; use entry-id=spoken text")
        texts[entry_id] = text
    return texts


def candidates(target: list[str], words: list[dict[str, object]]) -> list[int]:
    source = [str(word["word"]).lower().replace("'", "") for word in words]
    return [
        index
        for index in range(len(source) - len(target) + 1)
        if source[index:index + len(target)] == target
    ]


def run_ffmpeg(source: Path, start: float, duration: float, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "ffmpeg", "-nostats", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{start:.2f}", "-t", f"{duration:.2f}", "-i", str(source),
        "-vn", "-ac", "1", "-c:a", "aac", "-b:a", "96k", str(output),
    ], check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--word-timestamps", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    parser.add_argument("--occurrence", action="append", default=[])
    parser.add_argument("--alignment-text", action="append", default=[])
    parser.add_argument(
        "--entry",
        action="append",
        default=[],
        help="Limit alignment to these entry IDs; preserves other course clips.",
    )
    parser.add_argument(
        "--strict-boundaries",
        action="store_true",
        help="Ensure selected clips never overlap, even when timestamp padding meets the next line.",
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    words = json.loads(args.word_timestamps.read_text()).get("words")
    if not isinstance(words, list) or not words:
        raise ValueError("Word-level timestamps are required")
    occurrences = parse_occurrences(args.occurrence)
    alignment_texts = parse_alignment_texts(args.alignment_text)
    requested_entries = set(args.entry)
    known_entries = {str(entry["id"]) for entry in manifest["entries"]}
    unknown_entries = requested_entries - known_entries
    if unknown_entries:
        raise ValueError(f"Unknown entry IDs: {', '.join(sorted(unknown_entries))}")
    entries = [entry for entry in manifest["entries"] if not requested_entries or str(entry["id"]) in requested_entries]
    staged: list[tuple[dict[str, object], Path, float, float]] = []

    for entry in entries:
        # The manifest always keeps the reviewed official text. This optional
        # override exists only for harmless ASR surface differences such as
        # `&` versus `and` or `use` versus a Whisper `used` misrecognition.
        target = normalized_words(alignment_texts.get(str(entry["id"]), str(entry["text"])))
        matches = candidates(target, words)
        requested = occurrences.get(str(entry["id"]))
        if requested:
            if requested > len(matches):
                raise ValueError(f"{entry['id']}: requested occurrence {requested}, found {len(matches)}")
            index = matches[requested - 1]
        elif len(matches) == 1:
            index = matches[0]
        else:
            raise ValueError(f"{entry['id']}: expected one exact match, found {len(matches)}")

        first = words[index]
        last = words[index + len(target) - 1]
        start = max(0.0, float(first["start"]) - 0.12)
        end = float(last["end"]) + 0.18
        entry["start"] = round(start, 2)
        entry["end"] = round(end, 2)
        entry["duration"] = round(end - start, 2)
        staged.append((
            entry,
            args.audio_dir / Path(str(entry["audio"])).name,
            float(first["start"]),
            float(last["end"]),
        ))

    if args.strict_boundaries:
        ordered = sorted(staged, key=lambda item: item[2])
        for previous, current in zip(ordered, ordered[1:]):
            boundary = round((previous[3] + current[2]) / 2, 2)
            previous_entry = previous[0]
            current_entry = current[0]
            previous_entry["end"] = min(float(previous_entry["end"]), boundary)
            current_entry["start"] = max(float(current_entry["start"]), boundary)
        for entry, _, _, _ in staged:
            entry["duration"] = round(float(entry["end"]) - float(entry["start"]), 2)

    if not args.apply:
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        return

    temporary_audio = args.audio_dir.parent / f".{args.audio_dir.name}-staging"
    shutil.rmtree(temporary_audio, ignore_errors=True)
    for entry, output, _, _ in staged:
        run_ffmpeg(args.source, float(entry["start"]), float(entry["duration"]), temporary_audio / output.name)
    if len(list(temporary_audio.glob("*.m4a"))) != len(entries):
        raise RuntimeError("Incomplete staged audio output")
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    args.audio_dir.mkdir(parents=True, exist_ok=True)
    for _, output, _, _ in staged:
        os.replace(temporary_audio / output.name, output)
    temporary_audio.rmdir()
    print(f"Aligned {len(entries)} entries")


if __name__ == "__main__":
    main()
