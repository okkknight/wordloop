#!/usr/bin/env python3
"""Apply the reviewed low-value exclusions to a Modern Family course package."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    parser.add_argument("--exclusions", type=Path, required=True)
    parser.add_argument(
        "--exclusion-key",
        help="Catalog key to apply; defaults to the manifest course ID.",
    )
    parser.add_argument(
        "--reason",
        default="manual-low-value",
        help="Review reason recorded on every excluded entry.",
    )
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    exclusion_key = args.exclusion_key or manifest["courseId"]
    raw_exclusions = json.loads(args.exclusions.read_text()).get(exclusion_key, [])
    exclusions: dict[str, str] = {}
    for item in raw_exclusions:
        if isinstance(item, str):
            exclusions[item] = args.reason
        else:
            exclusions[item["id"]] = item.get("reason", args.reason)
    ids = {entry["id"] for entry in manifest["entries"]}
    unknown = sorted(set(exclusions) - ids)
    if unknown:
        raise ValueError(f"Unknown exclusion IDs: {', '.join(unknown)}")

    removed = 0
    for entry in manifest["entries"]:
        reason = exclusions.get(entry["id"])
        if reason is None:
            continue
        entry["learnable"] = False
        entry.pop("audio", None)
        reasons = entry.setdefault("reviewReasons", [])
        if reason not in reasons:
            reasons.append(reason)
        removed += 1

    staging = args.audio_dir.parent / f".{args.audio_dir.name}-reviewed"
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    retained = [entry for entry in manifest["entries"] if entry["learnable"]]
    for entry in retained:
        source = args.audio_dir / Path(entry["audio"]).name
        if not source.is_file():
            raise FileNotFoundError(f"Missing audio for {entry['id']}: {source}")
        shutil.copy2(source, staging / source.name)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    shutil.rmtree(args.audio_dir)
    shutil.move(str(staging), str(args.audio_dir))
    print(f"removed={removed} retained={len(retained)}")


if __name__ == "__main__":
    main()
