---
name: esf-video-zusammenfassung
description: Use when writing any document under analysis/, roadmap/ or reports/ in the company vault — every document for the CEO or the supervisor ships with a narrated video summary (AGENTS.md 8)
version: 1.0.0
platforms: [macos]
---

# ESF Video Summary

## Overview

Every document you write for the CEO or the supervisor — everything under
`analysis/`, `roadmap/` and `reports/` — carries a video summary: narrated
audio plus subtitles the viewer can switch on. **You write the narration
script; you never render.** Rendering is deterministic code
(`scripts/video-render.sh`, Hyperframes with a measured ffmpeg fallback), and
the subtitles (`.vtt`) are generated from your script against the measured
audio duration. The contract is `AGENTS.md 8`; the vault linter enforces the
consistency of the three parts below.

**Announce at start:** "I'm using the esf-video-zusammenfassung skill for the
video summary."

## The three parts (all mandatory, exact forms in AGENTS.md 8)

1. Head meta, named after the document itself:
   `<meta name="esf-video" content="<document-basename>.mp4">`
   The naming convention IS the linkage — do not invent a different name.
2. `<section id="video-skript">` — the narration script.
3. The `<figure class="esf-video">` embed with the `<track>` subtitle line,
   copied verbatim from AGENTS.md 8. The `.mp4`/`.vtt` files do not exist yet
   when you write the document — that is correct; the renderer creates them
   asynchronously and the names already match.

## How to write the narration script

- 120–220 words, spoken German, plain sentences a listener can follow without
  seeing the document.
- The first two sentences carry the core finding and your recommendation —
  a listener who stops after ten seconds has the essence.
- Every number you speak must also stand in the document with its evidence.
  A number that exists only in the video is an unverifiable claim.
- Never read out file paths, task IDs, commit hashes or URLs. Say "die
  Codebasis-Analyse" — the document carries the reference.
- End with what happens next or what decision is needed, one sentence.

## What you never do

- Never call any video or TTS API, never run `hyperframes`, `say`, `ffmpeg`
  or `scripts/video-render.sh` yourself — the renderer runs on its own clock.
- Never write the `.vtt` yourself — its cue times come from the measured
  audio, not from estimation.
- Never put the narration into a comment or metadata instead of the section:
  the renderer and the linter read `<section id="video-skript">`, nothing else.
