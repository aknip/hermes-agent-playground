---
title: Release-Historie
slug: release-historie
updated: 2026-08-11
tags: [releases, versionen]
sources: [changelog-0.20.0.md, hermes-docs/releases.md, release-0.20.0-velocity.md]
version: 0.20.0
status: aktuell
---

## Kurzfassung

Diese Seite fuehrt die Releases von Hermes Agent mit ihren tragenden
Aenderungen. Sie ist die Einstiegsseite fuer jede Frage der Form „seit wann gibt
es X?" und „was hat sich zwischen A und B geaendert?". Gepflegt wird sie aus den
offiziellen Changelogs; Patch-Releases werden zusammengefasst, nicht einzeln
aufgezaehlt.

## Details

### 0.20.0 — „Velocity" (2026-08-03)

Das aktuelle Hauptrelease.

| Bereich | Aenderung |
|---|---|
| Kanban | neue Spalte `review` mit eigenem Review-Agenten (`sdlc-review`) |
| Kanban | `hermes kanban daemon` deprecated — der Dispatcher lebt im Gateway |
| Kanban | `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` — Fan-out, Verifier und Synthese in einem Befehl |
| Kanban | `--goal` / `--goal-max-turns`: Judge prueft nach jeder Runde |
| Cron | `--no-agent` fuer tokenfreie Skript-Jobs |
| Profile | `hermes profile install` fuer Distributionen mit `distribution.yaml` |

### 0.19.x (2026-05 bis 2026-07)

- `--idempotency-key` bei `kanban create`
- `--max-runtime` als Laufzeitdeckel je Karte
- Mandantenraeume ueber `--tenant` und `$HERMES_TENANT`

### 0.17.x (2026-02)

- erste Fassung des Kanban-Boards mit mehreren Boards je Installation
- `hermes profile describe` und das Routing ueber Profilbeschreibungen

## Quellen

- `changelog-0.20.0.md` — offizieller Changelog zu 0.20.0, Stand 2026-08-03
- `release-0.20.0-velocity.md` — swarm-Signatur in der 0.20.0-Linie (2026-08-03)
- `hermes-docs/releases.md` — Uebersicht aller Releases

## Siehe auch

- [[kanban-board]]
- [[cron-und-zeitplan]]
- [[profile-system]]
