---
title: Kanban — Block-Semantik
slug: kanban-block-semantik
updated: 2026-08-11
tags: [kanban, block, gate]
sources: [hermes-docs/kanban.md, changelog-0.20.1.md, changelog-0.20.2.md, sources/transcripts/2026-08-08-block-semantik.md]
version: 0.20.x
status: aktuell
---

## Kurzfassung

Eine Karte wartet entweder auf einen **Menschen** (`blocked`) oder auf **Zeit**
(`scheduled`). `hermes kanban unblock` holt beide zurueck. Ein Block ist der
Baustein jedes menschlichen Tors: der Worker haelt seine eigene Karte an, ein
Mensch antwortet, derselbe Worker laeuft ein zweites Mal an und liest die
Antwort. Seit 0.20.0 nimmt `block` den Grund **positional**, nicht als
`--reason`. Haelt nur ein echtes `block` bzw. `kanban_block()` — nicht das
Parken mit `--initial-status blocked`.

## Details

### Die drei Befehle

```
hermes kanban block    <id> "brauche eine Entscheidung von dir"
hermes kanban block    --kind needs_input <id> "brauche eine Entscheidung"
hermes kanban schedule <id> "erst nach dem Release am Freitag"
hermes kanban unblock  <id> --reason "approve"
```

`block` nimmt den Grund seit 0.20.0 **positional**; ein `--reason`-Flag gibt es
nicht und bricht mit `unrecognized arguments` ab. `--kind` steht **vor** der
Kartennummer; dahinter bricht `block` ebenfalls ab. Nur bei `unblock` gibt es
weiterhin `--reason` — dort legt es den Text als Kommentar an die Karte und
hebt sie danach nach `ready`. Beides in einem Schritt — deshalb ist das die
natuerliche Form einer Antwort an ein Tor.

`--kind` ist eine **Typangabe, keine Haltekraft**: ein Block ohne `--kind`
haelt genauso. `needs_input` ist trotzdem die richtige Angabe, weil sie jedem
Leser sagt: hier wartet ein Mensch.

### Block-Arten

| `--kind` | Bedeutung |
|---|---|
| `dependency` | wartet in `todo`, wird automatisch befoerdert — **kein** Mensch |
| `needs_input` | wartet auf einen Menschen |
| `capability` | wartet auf einen Menschen (fehlende Faehigkeit) |
| `transient` | vermutlich fluechtiger Fehler |

### `--initial-status blocked`

`--initial-status blocked` setzt beim Anlegen nur die **Spalte**, erzeugt aber
**kein** `blocked`-Ereignis und ist deshalb **kein Tor**. Liegen bleibt nur
eine Karte, deren juengstes Ereignis ein echtes `blocked` ist; ein so geparkter
Wartepunkt laeuft stumm durch, sobald seine Eltern fertig sind. Merksatz:
**`--initial-status blocked` parkt, `block` haelt.**

### Aus dem Worker heraus

`kanban_block(kind="needs_input", reason=…)` blockiert die **eigene** Karte.
Das ist der Weg, ein Tor zu bauen, das den Kontext des Workers behaelt: sein
naechster Run auf derselben Karte ist die Ausfuehrung der Entscheidung.

### Wiederholtes Blockieren

Wird eine Karte nach einem `unblock` erneut mit derselben Block-Art blockiert,
routet Hermes sie in die Triage statt nach `blocked`. Das ausgeloeste Ereignis
heisst `block_loop_detected` und traegt im Payload den Zaehler
`block_recurrences` (pro Block-Art, Reset nur bei erfolgreichem Abschluss).
Zwei menschliche Tore hintereinander auf derselben Karte brauchen deshalb
**verschiedene** Block-Arten — oder besser: zwei Tore sind zwei Karten.

## Quellen

- `hermes-docs/kanban.md` — Abschnitt „Blocking and unblocking", Stand 2026-06
- `changelog-0.20.1.md` — Grund seit 0.20.0 positional, `--initial-status
  blocked` kein Tor, `--kind` vor der Nummer (2026-08-06)
- `changelog-0.20.2.md` — `block_loop_detected` + `block_recurrences`
  (2026-08-09)
- `sources/transcripts/2026-08-08-block-semantik.md` — gemessene Demo
  (2026-08-08)

## Siehe auch

- [[kanban-board]]
- [[gateway-und-dispatcher]]