---
title: Kanban-Board
slug: kanban-board
updated: 2026-08-11
tags: [kanban, orchestrierung, kern]
sources: [hermes-docs/kanban.md, changelog-0.20.0.md, changelog-0.20.1.md, release-0.20.0-velocity.md, changelog-0.20.2.md]
version: 0.20.x
status: aktuell
---

## Kurzfassung

Das Kanban-Board ist die dauerhafte Arbeitswarteschlange von Hermes Agent. Ein
Board ist eine isolierte SQLite-Datenbank; Worker eines Boards sehen Karten
anderer Boards physisch nicht. Eine Karte traegt Titel, Body, Assignee (ein
**Profilname**, keine Person), Status und optional einen Mandanten. Jeder
Ausfuehrungsversuch ist ein eigener Run mit eigenem Outcome. Der Unterschied zu
`delegate_task`: Kanban-Karten ueberleben Neustarts und hinterlassen eine
Audit-Spur.

## Details

### Spalten

Der Statusvorrat umfasst neun Werte, von denen acht als Spalte gerendert
werden: `triage`, `todo`, `scheduled`, `ready`, `running`, `blocked`, `review`,
`done`. `archived` ist der neunte und hat keine Spalte.

| Spalte | Wartet auf |
|---|---|
| `triage` | eine Spezifikation |
| `todo` | offene Eltern-Karten |
| `scheduled` | **Zeit** |
| `ready` | einen freien Worker |
| `running` | den laufenden Worker |
| `blocked` | einen **Menschen** — siehe [[kanban-block-semantik]] |
| `review` | einen Review-Agenten |
| `done` | nichts |

Mit `--initial-status blocked` angelegte Karten stehen in der Spalte
`blocked`, halten aber nicht: das setzt nur die Spalte, kein `blocked`-Ereignis
— der Dispatcher befoerdert sie weiter, sobald die Eltern fertig sind.
Halten tut nur ein echtes `block` (siehe [[kanban-block-semantik]]).

### Datenbankpfade

- Standard-Board: `~/.hermes/kanban.db`
- jedes weitere: `~/.hermes/kanban/boards/<slug>/kanban.db`

### Werkzeuge im Worker

Ein gespawnter Worker hat einen eigenen Werkzeugsatz, den es ausserhalb eines
Worker-Prozesses nicht gibt: `kanban_show`, `kanban_list`, `kanban_complete`,
`kanban_block`, `kanban_heartbeat`, `kanban_comment`, `kanban_create`,
`kanban_link`, `kanban_unblock`, `kanban_attach`. Der Lebenszyklus wird
automatisch in den Systemprompt injiziert.

`kanban_create` ist das Werkzeug, mit dem ein Worker das Board **selbst**
erweitert — die Grundlage jeder Pipeline, die ihren eigenen Graphen baut.

### Review-Spalte

Erzeugt ein Worker einen Pull Request, gibt er die Karte nach `review` weiter.
Der Dispatcher startet dafuer einen eigenen Review-Agenten mit der Skill
`sdlc-review`, der entweder merged oder die Karte zurueckgibt.

### Befehle und Verhalten in 0.20.x

- `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P`
  vereint Fan-out, Verifier und Synthese in einem Befehl (seit 0.20.0).
- Bestehende Boards werden beim ersten Zugriff automatisch migriert — manuelle
  Migrationsschritte sind nicht noetig (seit 0.20.0).
- `hermes kanban diagnostics` weist blockierte Karten mit ihrer Block-Art
  (`kind`) aus, statt nur mit dem Grund (seit 0.20.1).
- `kanban_create` im Worker schlaegt bei relativem `workspace_path` mit einer
  Meldung fehl, statt eine unstartbare Karte anzulegen (seit 0.20.2).

## Quellen

- `hermes-docs/kanban.md` — offizielle Dokumentation, Stand 2026-07-28
- `changelog-0.20.0.md` — Einfuehrung der `review`-Spalte
- `release-0.20.0-velocity.md` — swarm-Signatur, automatische Board-Migration
  beim ersten Zugriff (2026-08-03)
- `changelog-0.20.1.md` — `--initial-status blocked` setzt die Spalte, kein
  `blocked`-Ereignis; `diagnostics` mit `kind` (2026-08-06)
- `changelog-0.20.2.md` — `kanban_create`-Schlag bei relativem `workspace_path`
  (2026-08-09)

## Siehe auch

- [[gateway-und-dispatcher]]
- [[kanban-block-semantik]]
- [[profile-system]]