# Hermes Agent — Wissensbasis

Diese Wissensbasis ist **fuer Agenten** geschrieben. Form, Pflege und Grenzen
stehen in [AGENTS.md](AGENTS.md) — das ist der Vertrag, gegen den
`bin/kb_lint.py` validiert.

Jede Seite unter `pages/` ist von hier aus **genau einmal** verlinkt. Eine
Seite, die der Index nicht kennt, existiert fuer einen Agenten nicht, der ueber
den Index einsteigt.

## Kern

- [[kanban-board]] — Board, Spalten, Worker-Werkzeuge
- [[kanban-block-semantik]] — warten auf einen Menschen, warten auf Zeit
- [[profile-system]] — Profile als Assignees, `config.yaml`, Beschreibungen
- [[memory-system]] — Gedaechtnis, Mandanten, Sitzungen

## Automatisierung

- [[cron-und-zeitplan]] — Zeitplaene, tokenfreie Jobs
- [[skills-system]] — Skills, Aufloesung, profil-lokale Skills

## Versionen

- [[release-historie]] — was kam in welchem Release

## Protokoll

Jeder automatisierte Ingest haengt einen Absatz an
[log/ingest-log.md](log/ingest-log.md). Dort steht, welche menschliche
Entscheidung eine Aenderung ausgeloest hat.
