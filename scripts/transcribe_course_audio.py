#!/usr/bin/env python3
"""Create timestamped source segments from a course audio file using Whisper."""

from __future__ import annotations

import argparse
import json
import os
import urllib.request
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--language", default="en")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is required")

    boundary = "----WordLoopWhisperBoundary"
    audio = args.audio.read_bytes()
    body = b"".join([
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
        f"--{boundary}--\r\n".encode(),
    ])
    request = urllib.request.Request(
        "https://api.openai.com/v1/audio/transcriptions",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {len(payload.get('segments', []))} timestamped segments to {args.output}")


if __name__ == "__main__":
    main()
