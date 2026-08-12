---
title: Gateway und Dispatcher
slug: gateway-und-dispatcher
updated: 2026-07-30
tags: [gateway, dispatcher, kanban]
sources: [hermes-docs/gateway.md, hermes-docs/kanban.md]
version: 0.20.0
status: aktuell
---

## Kurzfassung

Der Dispatcher ist die Schleife, die zugewiesene Kanban-Karten beansprucht, das
Profil als eigenstaendigen Betriebssystemprozess startet, tote Worker
einsammelt und `todo`-Karten nach `ready` befoerdert, sobald deren Eltern fertig
sind. Er lebt im Gateway. `hermes kanban daemon` ist seit 0.20.0 deprecated.
Ein laufendes Gateway bedient **alle** Boards, auch gerade neu angelegte.

## Details

### Betrieb

| Weg | Wirkung |
|---|---|
| `hermes gateway start` | Dispatcher im Hintergrund, Tick alle 60 s |
| `hermes kanban --board <slug> dispatch` | genau ein Tick, sofort |
| `hermes kanban --board <slug> dispatch --dry-run` | zeigen, was ein Tick tun *wuerde* |
| `hermes kanban --board <slug> dispatch --max <n>` | Spawns je Tick deckeln |
| `hermes pause` / `hermes resume` | Kanban und Cron gemeinsam anhalten |

### Was ein Tick tut

Ein Tick meldet sieben Zaehlwerte: `Reclaimed`, `Crashed`, `Timed out`,
`Stale`, `Auto-blocked`, `Promoted`, `Spawned`. `Promoted` ist der
interessanteste — er zaehlt die Karten, die aus `todo` (und aus `blocked`!)
nach `ready` gehoben wurden, weil ihre Eltern fertig geworden sind.

### Umgebungsvariablen im Worker

Der Dispatcher setzt sie beim Spawn:

| Variable | Inhalt |
|---|---|
| `HERMES_KANBAN_TASK` | Karten-ID |
| `HERMES_KANBAN_WORKSPACE` | aufgeloester Workspace-Pfad |
| `HERMES_KANBAN_BOARD` | Board-Slug |
| `HERMES_KANBAN_RUN_ID` | laufende Run-ID |
| `HERMES_KANBAN_BRANCH` | Branch, bei Worktree-Karten |
| `HERMES_TENANT` | Mandantenname, falls gesetzt |
| `HERMES_HOME` / `HERMES_PROFILE` | Profilverzeichnis und -name |

### Heartbeats

Ohne `kanban_heartbeat` haelt der Dispatcher einen Claim nach
`kanban.dispatch_stale_timeout_seconds` (Standard 14400) fuer verwaist und legt
die Karte zurueck in die Queue.

### Karten ohne Assignee

Sie werden nie gestartet. Das ist der einfachste Weg, etwas anzulegen und in
Ruhe anzusehen, waehrend ein Gateway laeuft.

## Quellen

- `hermes-docs/gateway.md` — offizielle Dokumentation, Stand 2026-07-30
- `hermes-docs/kanban.md` — Abschnitt Dispatcher

## Siehe auch

- [[kanban-board]]
- [[cron-und-zeitplan]]
