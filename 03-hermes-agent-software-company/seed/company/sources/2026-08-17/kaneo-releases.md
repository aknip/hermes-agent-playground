# kaneo — Releases

Quelle: GitHub Releases API. 30 Releases geliefert, die neuesten 12 stehen unten.
Je Release sind die ersten 1200 Zeichen der Beschreibung übernommen; längere sind mit […] markiert.

## v2.19.1
Veröffentlicht: 2026-08-15T17:05:58Z
Titel: Release v2.19.1

Recommended for anyone on v2.19.0.

**Task descriptions could be saved to the wrong task** (#1599). The description editor saves on a 700ms debounce, and it read the current task when the timer fired rather than when the text was typed. Leaving a task inside that window wrote its text over whichever task you had opened, so both tasks were damaged: the one you arrived at lost its description, and the one you edited never received the change. A second edit inside the same window could also drop the first task's save entirely.

v2.19.0 made this easier to hit, because that release kept the editor alive across task switches. The underlying mistake was older.

Nothing to do beyond upgrading. No migration and no configuration change.

## What's Changed
* fix(web): save a description to the task it was typed in by @andrejsshell in https://github.com/usekaneo/kaneo/pull/1600


**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.19.0...v2.19.1

## v2.19.0
Veröffentlicht: 2026-08-15T16:16:43Z
Titel: Release v2.19.0

## Before you upgrade

Two changes in this release can affect a running install. Both are listed as ordinary fixes below, so they are called out here instead.

**Session cookies now set `Secure` on any HTTPS deployment** (#1560). Previously `Secure` was only set when the API and the web app lived on different subdomains, which meant a same-domain HTTPS install was sending its session cookie in the clear. If `KANEO_API_URL` starts with `https://` but your instance is actually reached over plain HTTP, logins will stop working after this upgrade. The fix is to make `KANEO_API_URL` match how the instance is really served.

**Tasks imported without a priority are repaired on startup** (#1594). Issues imported from GitHub or Gitea without a `priority:` label were stored with no priority at all, and the API rejected every later edit of those tasks with a 400. Dragging such a card between columns appeared to work and silently reverted. The migration sets those rows to the default priority and then makes the column `NOT NULL`, so it cannot happen again. It runs at API startup and needs a brief exclusive lock on the task table, which is worth knowing if your instance has a very large board.


[…]

## v2.18.0
Veröffentlicht: 2026-08-12T18:53:51Z
Titel: Release v2.18.0

**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.6...v2.18.0

## v2.17.6
Veröffentlicht: 2026-08-11T21:08:14Z
Titel: Release v2.17.6

**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.5...v2.17.6

## v2.17.5
Veröffentlicht: 2026-08-11T20:17:07Z
Titel: Release v2.17.5

**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.4...v2.17.5

## v2.17.4
Veröffentlicht: 2026-08-11T19:49:42Z
Titel: Release v2.17.4

**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.3...v2.17.4

## v2.17.3
Veröffentlicht: 2026-08-11T18:15:56Z
Titel: Release v2.17.3

## What's Changed
* docs(agents): revamp project guidance by @tinsever in https://github.com/usekaneo/kaneo/pull/1564


**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.2...v2.17.3

## v2.17.2
Veröffentlicht: 2026-08-11T17:36:45Z
Titel: Release v2.17.2

## What's Changed
* fix: use internal URL for MCP tool requests by @alloutflo in https://github.com/usekaneo/kaneo/pull/1556

## New Contributors
* @alloutflo made their first contribution in https://github.com/usekaneo/kaneo/pull/1556

**Full Changelog**: https://github.com/usekaneo/kaneo/compare/v2.17.1...v2.17.2

## planka-import-v0.2.0
Veröffentlicht: 2026-08-11T21:04:50Z
Titel: @kaneo/planka-import v0.2.0

Published [@kaneo/planka-import@0.2.0](https://www.npmjs.com/package/@kaneo/planka-import/v/0.2.0) to npm.

## planka-import-v0.1.2
Veröffentlicht: 2026-08-11T17:57:35Z
Titel: @kaneo/planka-import v0.1.2

Published [@kaneo/planka-import@0.1.2](https://www.npmjs.com/package/@kaneo/planka-import/v/0.1.2) to npm.

## planka-import-v0.1.1
Veröffentlicht: 2026-08-11T16:35:34Z
Titel: @kaneo/planka-import v0.1.1

Published [@kaneo/planka-import@0.1.1](https://www.npmjs.com/package/@kaneo/planka-import/v/0.1.1) to npm.

## planka-import-v0.1.0
Veröffentlicht: 2026-08-11T16:18:07Z
Titel: @kaneo/planka-import v0.1.0

Published [@kaneo/planka-import@0.1.0](https://www.npmjs.com/package/@kaneo/planka-import/v/0.1.0) to npm.

