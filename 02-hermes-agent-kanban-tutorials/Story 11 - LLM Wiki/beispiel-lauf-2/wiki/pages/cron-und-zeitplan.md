---
title: Cron und Zeitplan
slug: cron-und-zeitplan
updated: 2026-07-14
tags: [cron, automatisierung]
sources: [hermes-docs/cron.md]
version: 0.20.0
status: aktuell
---

## Kurzfassung

`hermes cron` fuehrt Skripte und Agentenlaeufe auf einem Zeitplan aus. Skripte
muessen unter `~/.hermes/scripts/` liegen; `.sh` und `.bash` laufen ueber bash,
alles andere ueber Python. Mit `--no-agent` laeuft kein Modell mit — das Skript
**ist** der Job, und der Tick kostet keine Tokens. Das ist der guenstigste Weg,
eine Pipeline auf dem Kanban-Board anzustossen.

## Details

### Befehle

| Befehl | Zweck |
|---|---|
| `hermes cron create "<plan>" --name … --script <s>` | Job anlegen |
| `hermes cron list` | Jobs auflisten |
| `hermes cron runs <id>` | Ausfuehrungshistorie |
| `hermes cron run <id>` | sofort feuern |
| `hermes cron rm <id>` | entfernen |
| `hermes cron tick` | faellige Jobs einmal ausfuehren |
| `hermes cron status` | laeuft der Scheduler? |

### Ablageorte

- Jobdefinitionen: `~/.hermes/cron/jobs.json`
- Ausgaben: `~/.hermes/cron/output/<job-id>/`

### Cron in Verbindung mit dem Board

Ein Cron-Job mit `--no-agent`, der `hermes kanban create` aufruft, ist der
uebliche Einstieg in eine wiederkehrende Pipeline. Zusammen mit
`--idempotency-key`, der das Datum enthaelt, legt ein zweiter Tick am selben Tag
nichts Neues an.

`hermes pause` haelt Cron **und** Kanban-Dispatch gemeinsam an; laufende Arbeit
wird dabei nicht getoetet.

## Quellen

- `hermes-docs/cron.md` — offizielle Dokumentation, Stand 2026-07

## Siehe auch

- [[kanban-board]]
- [[gateway-und-dispatcher]]
