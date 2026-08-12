---
title: Kanban — Block-Semantik
slug: kanban-block-semantik
updated: 2026-08-11
tags: [kanban, block, gate]
sources: [hermes-docs/kanban.md, changelog-0.20.1.md, changelog-0.20.2.md, 2026-08-08-block-semantik.md]
version: 0.20.2
status: aktuell
---

## Kurzfassung

Eine Karte wartet entweder auf einen **Menschen** (`blocked`) oder auf **Zeit**
(`scheduled`). `hermes kanban unblock` holt beide zurueck. Ein Block ist der
Baustein jedes menschlichen Tors in einer Pipeline: der Worker haelt seine
eigene Karte an, ein Mensch antwortet, derselbe Worker laeuft ein zweites Mal
an und liest die Antwort. Es haelt nur ein echtes `block` bzw. `kanban_block()` —
`--initial-status blocked` parkt die Karte nur in die Spalte und ist **kein**
Tor.

## Details

### Die drei Befehle

```
hermes kanban block   <id> "brauche eine Entscheidung von dir"
hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"
hermes kanban schedule <id> "erst nach dem Release am Freitag"
hermes kanban unblock  <id> --reason "approve"
```

Der Grund von `block` ist **positional** — `--reason` existiert fuer `block`
nicht und bricht mit `unrecognized arguments` ab. Eine Block-Art gibt man per
`--kind` an, und das **vor** der Kartennummer. `--kind` hinter der ID bricht
ebenfalls ab.

Bei `unblock` gibt es `--reason` weiterhin: er legt den Text als Kommentar an
die Karte und hebt sie danach nach `ready`. Beides in einem Schritt — deshalb
ist das die natuerliche Form einer Antwort an ein Tor.

### Block-Arten

| `--kind` | Bedeutung |
|---|---|
| `dependency` | wartet in `todo`, wird automatisch befoerdert — **kein** Mensch |
| `needs_input` | wartet auf einen Menschen |
| `capability` | wartet auf einen Menschen (fehlende Faehigkeit) |
| `transient` | vermutlich fluechtiger Fehler |

Die Block-Art (`--kind`) ist eine **Typangabe**, keine Haltekraft: ein Block
ohne `--kind` haelt genauso. `needs_input` ist trotzdem die richtige Angabe,
weil sie jedem Leser sagt: hier wartet ein Mensch.

### `--initial-status blocked` ist kein Tor

`--initial-status blocked` beim Anlegen setzt die **Spalte**, erzeugt aber
**kein** `blocked`-Ereignis und haelt nicht: sobald die Eltern der Karte fertig
sind, befoerdert `recompute_ready` sie weiter. Merksatz: **parkt, haelt nicht**.
Ein Tor baut nur ein echtes `block` bzw. `kanban_block()`.

### Aus dem Worker heraus

`kanban_block(kind="needs_input", reason=…)` blockiert die **eigene** Karte.
Das ist der Weg, ein Tor zu bauen, das den Kontext des Workers behaelt: sein
naechster Run auf derselben Karte ist die Ausfuehrung der Entscheidung.

### Wiederholtes Blockieren

Wird eine Karte nach einem `unblock` erneut mit **derselben** Block-Art
blockiert, routet Hermes sie in die Triage statt nach `blocked`. Das bricht
Endlosschleifen aus Blockieren und Entblocken auf. Seit 0.20.2 heisst das
ausgeloeste Ereignis `block_loop_detected` und traegt Zaehler und Grenze im
Payload: `block_recurrences` laeuft pro Block-Art und wird **nur bei
erfolgreichem Abschluss** zurueckgesetzt; die Grenze (`BLOCK_RECURRENCE_LIMIT`)
ist 2 — bereits der zweite gleichartige Block nach `unblock` schickt die Karte
in die Triage.

Zwei menschliche Tore auf derselben Karte brauchen also **unterschiedliche**
Block-Arten, sonst greift die Schleifenerkennung — zwei Tore sind zwei Karten.

## Quellen

- `hermes-docs/kanban.md` — Abschnitt „Blocking and unblocking", Stand 2026-06
- `changelog-0.20.1.md` — Grund positional, `--kind` vor der ID; `--initial-status blocked` haelt nicht (2026-08-06)
- `changelog-0.20.2.md` — Schleifenerkennung `block_loop_detected` mit Zaehler und Grenze (2026-08-09)
- `2026-08-08-block-semantik.md` — gemessene Demo: parkt ≠ haelt, Haltekraft unabhaengig von der Art

## Siehe auch

- [[kanban-board]]
- [[gateway-und-dispatcher]]