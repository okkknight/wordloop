#!/usr/bin/env python3
"""Rebuild a reviewed VOA course from explicitly selected Whisper segments."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path


WORD = re.compile(r"[a-z0-9']+")


def normalized(text: str) -> list[str]:
    return [word.replace("'", "") for word in WORD.findall(text.lower())]


def parse_selection(values: list[str]) -> dict[str, tuple[int, int]]:
    result = {}
    for value in values:
        entry, sep, range_text = value.partition("=")
        start, dash, end = range_text.partition(":")
        if not sep or not dash or not start.isdigit() or not end.isdigit():
            raise ValueError(f"Invalid segment selection: {value}; use entry-id=start:end")
        result[entry] = (int(start), int(end))
    return result


def cut(source: Path, start: float, duration: float, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-nostats", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{start:.2f}", "-t", f"{duration:.2f}", "-i", str(source), "-vn", "-ac", "1", "-c:a", "aac", "-b:a", "96k", str(output)], check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--segments", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    parser.add_argument("--select", action="append", default=[])
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    segments = json.loads(args.segments.read_text())["segments"]
    selected = parse_selection(args.select)
    if set(selected) != {entry["id"] for entry in manifest["entries"]}:
        raise ValueError("Every manifest entry must have exactly one reviewed segment selection")
    staging = args.audio_dir.parent / f".{args.audio_dir.name}-staging"
    shutil.rmtree(staging, ignore_errors=True)
    for entry in manifest["entries"]:
        first, last = selected[entry["id"]]
        if first > last or last >= len(segments):
            raise ValueError(f"Invalid segment range for {entry['id']}")
        source_text = " ".join(segment["text"] for segment in segments[first:last + 1])
        if normalized(source_text) != normalized(entry["text"]):
            raise ValueError(f"{entry['id']} text does not exactly match selected source segments")
        start = max(0.0, float(segments[first]["start"]) - 0.12)
        end = float(segments[last]["end"]) + 0.18
        entry["start"], entry["end"], entry["duration"] = round(start, 2), round(end, 2), round(end - start, 2)
        cut(args.source, start, end - start, staging / Path(entry["audio"]).name)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    shutil.rmtree(args.audio_dir, ignore_errors=True)
    shutil.move(str(staging), str(args.audio_dir))
    print(f"Aligned {len(manifest['entries'])} entries")


if __name__ == "__main__":
    main()
