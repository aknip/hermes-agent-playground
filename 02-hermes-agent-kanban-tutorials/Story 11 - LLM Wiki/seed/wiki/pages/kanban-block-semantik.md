---
title: Kanban — Block-Semantik
slug: kanban-block-semantik
updated: 2026-06-02
tags: [kanban, block, gate]
sources: [hermes-docs/kanban.md]
version: 0.19.0
status: aktuell
---

## Kurzfassung

Eine Karte wartet entweder auf einen **Menschen** (`blocked`) oder auf **Zeit**
(`scheduled`). `hermes kanban unblock` holt beide zurueck. Ein Block ist der
Baustein jedes menschlichen Tors in einer Pipeline: der Worker haelt seine
eigene Karte an, ein Mensch antwortet, derselbe Worker laeuft ein zweites Mal
an und liest die Antwort.

## Details

### Die drei Befehle

```
hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"
hermes kanban schedule <id> "erst nach dem Release am Freitag"
hermes kanban unblock  <id> --reason "approve"
```

Bei `unblock` legt `--reason` den Text als Kommentar an die Karte und hebt sie
danach nach `ready`. Beides in einem Schritt — deshalb ist das die natuerliche
Form einer Antwort an ein Tor.

### Block-Arten

| `--kind` | Bedeutung |
|---|---|
| `dependency` | wartet in `todo`, wird automatisch befoerdert — **kein** Mensch |
| `needs_input` | wartet auf einen Menschen |
| `capability` | wartet auf einen Menschen (fehlende Faehigkeit) |
| `transient` | vermutlich fluechtiger Fehler |

### Aus dem Worker heraus

`kanban_block(kind="needs_input", reason=…)` blockiert die **eigene** Karte.
Das ist der Weg, ein Tor zu bauen, das den Kontext des Workers behaelt: sein
naechster Run auf derselben Karte ist die Ausfuehrung der Entscheidung.

### Wiederholtes Blockieren

Wird eine Karte nach einem `unblock` erneut mit derselben Block-Art blockiert,
routet Hermes sie in die Triage statt nach `blocked`. Das bricht
Endlosschleifen aus Blockieren und Entblocken auf.

## Quellen

- `hermes-docs/kanban.md` — Abschnitt „Blocking and unblocking", Stand 2026-06

## Siehe auch

- [[kanban-board]]
- [[gateway-und-dispatcher]]
