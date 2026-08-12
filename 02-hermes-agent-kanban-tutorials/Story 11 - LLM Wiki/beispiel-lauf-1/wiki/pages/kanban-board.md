---
title: Kanban-Board
slug: kanban-board
updated: 2026-07-28
tags: [kanban, orchestrierung, kern]
sources: [hermes-docs/kanban.md, changelog-0.20.0.md]
version: 0.20.0
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

## Quellen

- `hermes-docs/kanban.md` — offizielle Dokumentation, Stand 2026-07-28
- `changelog-0.20.0.md` — Einfuehrung der `review`-Spalte

## Siehe auch

- [[gateway-und-dispatcher]]
- [[kanban-block-semantik]]
- [[profile-system]]
