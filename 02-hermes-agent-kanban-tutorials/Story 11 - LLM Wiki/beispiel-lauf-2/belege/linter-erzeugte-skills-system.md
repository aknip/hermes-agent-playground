---
title: Skills-System
slug: skills-system
updated: 2026-08-11
tags: [skills, konfiguration, kern]
sources: [transcripts/2026-08-07-skills-system.md]
version: 0.20.0
status: aktuell
---

## Kurzfassung

Eine Skill ist ein Verzeichnis mit einer `SKILL.md`: YAML-Frontmatter mit `name`
und `description`, darunter Markdown. Es gibt keine Registrierung im engeren
Sinn — das Verzeichnis liegt da, und Hermes findet es. Skills sind **Text**:
sie fuegen Wissen und Anweisungen hinzu, im Unterschied zu MCP-Servern, die
**Werkzeuge** hinzufuegen. Nur die `description` landet ungefragt im Kontext;
der Rumpf wird erst geladen, wenn das Modell die Skill fuer relevant haelt.

## Details

### Ablageorte (Reihenfolge wichtig)

1. `~/.hermes/skills/` — global, fuer jedes Profil
2. `~/.hermes/profiles/<name>/skills/` — nur fuer dieses Profil, in
   `hermes -p <name> skills list` als `local` markiert
3. eingebaute Skills, die mit Hermes selbst kommen

### Aufloesung und Kontext

- Nur die `description` wird garantiert gesehen; sie ist die wichtigste Zeile
  der Datei.
- `hermes -p <profil> skills list` zeigt die Aufloesung mit Herkunft
  (`hub-installed`, `builtin`, `local`) und je Zeile `enabled`/`disabled`.
- Fuer feste Ablaeufe: `hermes kanban create … --skill <name>` erzwingt eine
  Skill im Worker-Kontext, unabhaengig davon, ob das Modell sie relevant findet.

### Skill gegen MCP

- Skill = Text, kostet Kontext.
- MCP-Server = Werkzeug, kostet Kontext **und** Werkzeug-Slots.
- Was Text sein kann, soll Text sein.

### Profil-lokale Skills in einer Flotte

Profil-lokale Skills sind das schaerfste Werkzeug fuer Rollentrennung: Der
Orchestrator bekommt den Ablauf, der Rechercheur nicht. Weiss jeder Agent
alles, hat man keine Flotte, sondern Kopien desselben Agenten.

## Quellen

- `transcripts/2026-08-07-skills-system.md` — „Skills in Hermes Agent, von
  unten aufgebaut" (Tonbi's AI Garage, 2026-08-07)

## Siehe auch

- [[profile-system]]
