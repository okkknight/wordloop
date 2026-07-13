#!/usr/bin/env python3
"""Verify a VOA manifest has one reproducible clip per aligned entry."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def audio_duration(path: Path) -> float:
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", str(path),
    ], text=True).strip())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    clips = sorted(args.audio_dir.glob("*.m4a"))
    entries = manifest["entries"]
    if len(clips) != len(entries):
        raise SystemExit(f"clip count {len(clips)} does not match entry count {len(entries)}")
    for entry in entries:
        for field in ("start", "end", "duration"):
            if not isinstance(entry.get(field), (int, float)):
                raise SystemExit(f"{entry['id']} is missing {field}")
        if abs((entry["end"] - entry["start"]) - entry["duration"]) > 0.01:
            raise SystemExit(f"{entry['id']} has inconsistent time fields")
        clip = args.audio_dir / Path(entry["audio"]).name
        if not clip.is_file():
            raise SystemExit(f"{entry['id']} clip is missing")
        if abs(audio_duration(clip) - entry["duration"]) > 0.08:
            raise SystemExit(f"{entry['id']} clip duration differs from manifest")
    print(f"verified {len(entries)} aligned clips for {manifest['courseId']}")


if __name__ == "__main__":
    main()
