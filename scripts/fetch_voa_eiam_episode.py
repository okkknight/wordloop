#!/usr/bin/env python3
"""Fetch and timestamp one VOA English in a Minute episode.

Run where OPENAI_API_KEY is available. The resulting JSON is an editorial
source file: select useful segments and provide Chinese translations before
turning it into a WordLoop course manifest.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import urllib.request
from pathlib import Path


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "WordLoop course importer/1.0"})
    with urllib.request.urlopen(request) as response, destination.open("wb") as output:
        output.write(response.read())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="Official learningenglish.voanews.com episode URL")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is required for timestamp transcription")

    args.output.mkdir(parents=True, exist_ok=True)
    page = urllib.request.urlopen(args.url).read().decode("utf-8", errors="replace")
    title_match = re.search(r'<title>\s*(?:English in a Minute:\s*)?([^<|]+)', page, re.IGNORECASE)
    title = title_match.group(1).strip() if title_match else args.url
    video_match = re.search(r'https://[^"\\]+?_mobile\.mp4', page)
    if not video_match:
        raise RuntimeError("Could not find VOA mobile MP4 in episode page")
    video_url = video_match.group(0).replace(r"\u0026", "&")
    video_path = args.output / "source.mp4"
    download(video_url, video_path)

    transcript_path = args.output / "transcript.json"
    subprocess.run([
        "curl", "-fsS", "https://api.openai.com/v1/audio/transcriptions",
        "-H", f"Authorization: Bearer {key}",
        "-F", f"file=@{video_path}",
        "-F", "model=whisper-1",
        "-F", "response_format=verbose_json",
        "-o", str(transcript_path),
    ], check=True)
    transcript = json.loads(transcript_path.read_text())
    source = {
        "provider": "VOA Learning English",
        "sourceUrl": args.url,
        "title": title,
        "videoUrl": video_url,
        "attribution": "Source: VOA Learning English",
        "licenseNote": "VOA-produced Learning English content is public domain; exclude third-party agency material.",
        "segments": [
            {"start": round(segment["start"], 2), "end": round(segment["end"], 2), "text": segment["text"].strip()}
            for segment in transcript.get("segments", [])
        ],
    }
    (args.output / "source.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"title": title, "segments": len(source["segments"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
