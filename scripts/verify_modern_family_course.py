#!/usr/bin/env python3
"""Verify a rebuilt Modern Family course only exposes aligned audio clips."""

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
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    report = json.loads(args.report.read_text())
    aligned = {entry["id"]: entry for entry in report["entries"] if entry["status"] == "aligned"}
    entries = [entry for entry in manifest["entries"] if entry["learnable"]]
    entry_by_id = {entry["id"]: entry for entry in manifest["entries"]}
    learnable_ids = {entry["id"] for entry in entries}
    if not learnable_ids.issubset(aligned):
        raise SystemExit("a learnable entry is missing from the alignment report")
    manually_removed = set(aligned) - learnable_ids
    manual_reasons = {"manual-low-value", "below-a2"}
    if any(not manual_reasons.intersection(entry_by_id[entry_id].get("reviewReasons", [])) for entry_id in manually_removed):
        raise SystemExit("an aligned entry was removed without a manual review reason")
    if report.get("alignedRatio", 0) < report["minimumAlignedRatio"]:
        raise SystemExit("course source did not meet the required alignment ratio")

    clips = sorted(args.audio_dir.glob("*.m4a"))
    if len(clips) != len(entries):
        raise SystemExit(f"clip count {len(clips)} does not match learnable entries {len(entries)}")
    for entry in entries:
        if aligned[entry["id"]]["coverage"] < report["minimumCoverage"]:
            raise SystemExit(f"{entry['id']} is below the required transcript coverage")
        clip = args.audio_dir / Path(entry["audio"]).name
        if not clip.is_file():
            raise SystemExit(f"{entry['id']} clip is missing")
        if abs(audio_duration(clip) - entry["duration"]) > 0.08:
            raise SystemExit(f"{entry['id']} clip duration differs from manifest")
    print(f"verified {len(entries)} aligned clips for {manifest['courseId']}")


if __name__ == "__main__":
    main()
