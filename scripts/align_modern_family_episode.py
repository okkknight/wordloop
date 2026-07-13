#!/usr/bin/env python3
"""Build a Modern Family course from subtitle text and verified Whisper words.

The source media set contains files whose names cannot be trusted.  This tool
aligns every subtitle cue to the audio's word-level transcript before cutting
clips, so an incorrectly labelled source file is rejected instead of producing
silently mismatched lessons.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import shutil
import subprocess
from pathlib import Path


WORD = re.compile(r"[a-z0-9]+(?:'[a-z0-9]+)?")


def normalize(text: str) -> list[str]:
    return [word.replace("'", "") for word in WORD.findall(text.lower())]


def cut(source: Path, start: float, duration: float, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "ffmpeg", "-nostats", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{start:.2f}", "-t", f"{duration:.2f}", "-i", str(source),
        "-vn", "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(output),
    ], check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--transcript", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--min-coverage", type=float, default=0.8)
    parser.add_argument(
        "--min-aligned-ratio",
        type=float,
        default=0.5,
        help="Reject a source whose transcript does not match at least this share of learnable cues.",
    )
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    transcript = json.loads(args.transcript.read_text())
    transcript_words = transcript.get("words", [])
    if not transcript_words:
        raise ValueError("Transcript must contain word-level timestamps")

    subtitle_tokens: list[str] = []
    entry_ranges: dict[str, tuple[int, int]] = {}
    for entry in manifest["entries"]:
        tokens = normalize(entry["text"])
        start = len(subtitle_tokens)
        subtitle_tokens.extend(tokens)
        entry_ranges[entry["id"]] = (start, len(subtitle_tokens))
    # Whisper can emit standalone punctuation as a word token. It has no speech
    # boundary of its own, so exclude it while preserving timestamps for words.
    audio_words = [word for word in transcript_words if normalize(word["word"])]
    audio_tokens = [normalize(word["word"])[0] for word in audio_words]

    matcher = difflib.SequenceMatcher(None, subtitle_tokens, audio_tokens, autojunk=False)
    matches: dict[int, int] = {}
    for block in matcher.get_matching_blocks():
        for offset in range(block.size):
            matches[block.a + offset] = block.b + offset

    staging = args.audio_dir.parent / f".{args.audio_dir.name}-staging"
    shutil.rmtree(staging, ignore_errors=True)
    expected = sum(1 for entry in manifest["entries"] if entry["learnable"])
    aligned, rejected, report_entries = 0, 0, []
    for entry in manifest["entries"]:
        first, last = entry_ranges[entry["id"]]
        token_count = last - first
        mapped = [matches[index] for index in range(first, last) if index in matches]
        coverage = len(mapped) / token_count if token_count else 0.0
        compact = bool(mapped) and mapped == sorted(mapped)
        if not entry["learnable"]:
            report_entries.append({"id": entry["id"], "status": "not-learnable", "coverage": round(coverage, 3)})
            continue
        if not compact or coverage < args.min_coverage:
            entry["learnable"] = False
            entry.pop("audio", None)
            entry.setdefault("reviewReasons", []).append("audio-transcript-mismatch")
            rejected += 1
            report_entries.append({"id": entry["id"], "status": "rejected", "coverage": round(coverage, 3), "text": entry["text"]})
            continue
        start = max(0.0, float(audio_words[mapped[0]]["start"]) - 0.12)
        end = float(audio_words[mapped[-1]]["end"]) + 0.18
        entry["start"] = round(start, 2)
        entry["end"] = round(end, 2)
        entry["duration"] = round(end - start, 2)
        output = staging / Path(entry["audio"]).name
        cut(args.source, start, end - start, output)
        aligned += 1
        report_entries.append({"id": entry["id"], "status": "aligned", "coverage": round(coverage, 3), "text": entry["text"]})

    aligned_ratio = aligned / expected if expected else 0.0
    if aligned_ratio < args.min_aligned_ratio:
        shutil.rmtree(staging, ignore_errors=True)
        raise ValueError(
            f"Audio transcript matched only {aligned}/{expected} learnable cues "
            f"({aligned_ratio:.1%}); source is likely the wrong episode"
        )
    manifest["sourceAudio"] = str(args.source)
    manifest["sourceTranscript"] = str(args.transcript)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    shutil.rmtree(args.audio_dir, ignore_errors=True)
    shutil.move(str(staging), str(args.audio_dir))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps({
        "courseId": manifest["courseId"],
        "aligned": aligned,
        "rejected": rejected,
        "alignedRatio": round(aligned_ratio, 3),
        "minimumCoverage": args.min_coverage,
        "minimumAlignedRatio": args.min_aligned_ratio,
        "entries": report_entries,
    }, ensure_ascii=False, indent=2) + "\n")
    print(f"aligned={aligned} rejected={rejected}")


if __name__ == "__main__":
    main()
