#!/usr/bin/env python3
"""Create timestamped source segments from a course audio file using Whisper."""

from __future__ import annotations

import argparse
import json
import os
import time
import urllib.request
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--language", default="en")
    parser.add_argument(
        "--word-timestamps",
        action="store_true",
        help="Request word-level timestamps for precise course-audio alignment.",
    )
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is required")

    boundary = "----WordLoopWhisperBoundary"
    audio = args.audio.read_bytes()
    parts = [
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="model"\r\n\r\nwhisper-1\r\n',
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="language"\r\n\r\n{args.language}\r\n'.encode(),
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="response_format"\r\n\r\nverbose_json\r\n',
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="file"; filename="{args.audio.name}"\r\n'.encode(),
        b"Content-Type: audio/mpeg\r\n\r\n",
        audio,
        b"\r\n",
    ]
    if args.word_timestamps:
        parts.extend([
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="timestamp_granularities[]"\r\n\r\nword\r\n',
        ])
    parts.append(f"--{boundary}--\r\n".encode())
    body = b"".join(parts)
    request = urllib.request.Request(
        "https://api.openai.com/v1/audio/transcriptions",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    last_error: OSError | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                payload = json.load(response)
            break
        except OSError as error:
            last_error = error
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    else:
        raise last_error or RuntimeError("transcription request failed")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {len(payload.get('segments', []))} timestamped segments to {args.output}")


if __name__ == "__main__":
    main()
