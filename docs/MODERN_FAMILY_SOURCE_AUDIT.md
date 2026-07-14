# Modern Family Source Audit

The original media filenames and subtitle filenames do not use the same
episode numbering. Course production must match spoken dialogue to subtitles,
then verify the episode identity against an independent episode guide.

| Actual episode | Raw audio file | Matching subtitle source | Status |
| --- | --- | --- | --- |
| S01E01 Pilot | `S01E01. .mp3` | `S01E01.ass` | published |
| S01E02 The Bicycle Thief | `S01E02. .mp3` | `S01E03.ass` | published |
| S01E03 Come Fly with Me | `S01E03. .mp3` | `S01E04.ass` | published |
| S01E04 The Incident | `S01E04. .mp3` | `S01E05.ass` | published |
| S01E05 Coal Digger | `S01E05. .mp3` | unavailable | not published |

`S01E02.ass` opens with "Okay, your brother's lunch is packed", which belongs
to S01E06, so it must not be used for S01E02. The published course IDs follow
the actual episode identities, not the mislabeled subtitle filenames.
