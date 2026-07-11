# Design QA

## Comparison Target

- Source visual truth: `/tmp/codex-remote-attachments/019f4fff-f9e4-7a33-86cb-5750c9df5409/71a0cd05-f13f-4c68-9f48-4a3c397bdede/1-Photo-1.jpg`
- Intended state: mobile Repeat mode, with the course package selector replacing the former `WORDS / SENTENCES` control.
- Implementation capture: unavailable because this session has no browser control surface.

## Findings

- [P1] Visual comparison blocked.
  - Evidence: the supplied source image is available, but no rendered implementation screenshot can be captured at the same mobile viewport.
  - Required check: confirm that the course button does not crowd the Word Loop mark, the top-right area contains only Listen / Repeat / Progress, and the course drawer remains reachable on a 390px-wide viewport.

## Implementation Checklist

1. Capture the course selector and the Repeat state at 390px wide.
2. Compare both views with the supplied reference and correct any P1/P2 spacing or wrapping issues.

final result: blocked
