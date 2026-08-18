---
name: esf-video-komposition
description: Use when a card asks you to author a HyperFrames composition for a vault document (AGENTS.md 8.1) — how the job manifest binds your timing, what the machine gate checks, and where the deliverable goes
version: 1.0.0
platforms: [macos]
---

# ESF Video Composition

## Overview

You author ONE composition per document, individual to its content. The audio,
its **measured** duration and the subtitle cues already exist when your card
starts — they arrive as `auftrag.json` in your working directory. You design
the picture around a fixed soundtrack; you never change the sound, the text or
the document.

The contract is `AGENTS.md 8.1`. What decides whether you are finished is not
your judgement but `scripts/video-werkzeug.py pruefe` plus `hyperframes lint` —
both run again after you complete, and a composition that fails them is not
rendered.

## Your working directory

The card names it. It is always next to the document:

    company/analysis/market.komposition/
        auftrag.json     ← machine-written; READ-ONLY for you
        audio.m4a        ← the finished narration; do not re-encode
        index.html       ← YOUR deliverable
        <assets you create>

## `auftrag.json` binds you

    {
      "dokument":  "analysis/market.html",
      "titel":     "Marktbild — Kaneo, KW 34",
      "typ":       "analyse",
      "dauer":     81.38,
      "audio":     "audio.m4a",
      "cues": [ { "text": "…", "start": 0.0, "dauer": 7.033 }, … ]
    }

- `dauer` **is** your root `data-duration`. To the millisecond. It was measured
  with `ffprobe` from the real audio file.
- `cues` are the subtitle timings already written to the `.vtt`. Use them as the
  rhythm of your composition — if your visuals change on other beats than the
  narration, the video fights itself.
- `typ` tells you which form the document expects (`analyse`, `roadmap`,
  `report`, `gate`).

## The seven checks the machine runs

Run them yourself before completing — in your composition directory:

    npx --registry https://registry.npmjs.org hyperframes lint .
    python3 <esf>/scripts/video-werkzeug.py pruefe . <esf>/…/auftrag.json

1. `index.html` exists and carries no unreplaced `__PLACEHOLDER__`.
2. The root has `data-composition-id`, `data-width`, `data-height`,
   `data-duration`.
3. `data-duration` equals `auftrag.json`'s `dauer` (tolerance 50 ms).
4. The timeline is registered: `window.__timelines["<your composition id>"]`.
5. `<audio>` carries `src` **directly** (not set from JavaScript) and points at
   the file named in the manifest.
6. No `performance.now()` and no `requestAnimationFrame` outside comments — the
   renderer *seeks* to a frame, it does not play your scene.
7. No remote URLs except the pinned GSAP tag. No registry installs, no CDN
   images, no web fonts.

`hyperframes lint` must be at zero errors. Warnings are allowed; name them in
your metadata.

## Two traps that are measured, not theoretical

- **Do not animate `opacity` on a clip element.** Clip visibility is managed for
  you; tweening it triggers `gsap_exit_missing_hard_kill`. Wrap the content in an
  inner non-clip `<div>` and animate that.
- **Round clip boundaries from one series, not twice.** Compute the start times,
  then take each duration as the difference to the next start. Rounding start and
  duration independently overlaps neighbouring clips by a millisecond and lint
  rejects it (`overlapping_clips_same_track`).

## Content fidelity is on you alone

The gate above is structural: it cannot tell whether a number on screen is true.
Every figure you show must already stand in the document, unrounded and
unrecomputed. A slide with no number beats a slide with a wrong one.

## The reference is a floor, not a ceiling

`templates/hyperframes-zusammenfassung/` is the generic fallback: it passes the
gate and looks the same for every document. Read it to see a known-good shape,
then do better — that is the entire reason your role exists. If you merely
reproduce it, the channel gained nothing over the static path.
