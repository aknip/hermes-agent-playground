---
title: Skills-System: Aufbau, Speicherorte und description-im-Kontext
slug: skills-system
updated: 2026-08-11
tags: [skills, konfiguration]
sources: [2026-08-07-skills-system.md]
version: 0.20.0
---

## Kurzfassung

Eine Skill ist ein Verzeichnis mit einer `SKILL.md` — YAML-Frontmatter
(`name`, `description`) und darunter Markdown. Es gibt keine Registrierung:
Hermes findet eine lokal abgelegte Skill allein über das Verzeichnis. Nur die
`description` landet ungefragt im Kontext, der Rumpf wird erst geladen, wenn
das Modell die Skill für relevant hält — deshalb ist die `description` die
wichtigste Zeile. Skills liegen an drei Orten mit abgestufter Reichweite:
default-Profil, profil-eigen und gebündelt.

## Details

### Aufbau einer Skill

- Ein Ordnername platziert eine Skill; der Ordnername ist der Skill-Name.
- `SKILL.md` beginnt mit einem YAML-Frontmatter `name` + `description`,
  darunter folgt der Markdown-Rumpf (Anweisungen, Wissen, Ablauf).
- Lokal abgelegte Skills brauchen keine Registrierung; `hermes skills install`
  ist nur für Hub-Skills nötig.

### Speicherorte und Reichweite

Reihenfolge und Reichweite sind wichtig — sie bestimmen, welche Skills ein
Profil sieht:

| Ort | Reichweite | In `skills list` |
|---|---|---|
| `~/.hermes/skills/` | default-Profil — hier liegt der Skills-Root des default-Profils | — |
| `~/.hermes/profiles/<name>/skills/` | nur dieses Profil | `local` |
| gebündelt (builtin) | kommt mit Hermes selbst | `builtin` |

Eine Skill in einem profil-eigenen Verzeichnis steht damit nur dem einen
Profil zur Verfügung — das ist das Werkzeug, um einer Flotte je Agent nur den
Ablauf zu geben, den er braucht (siehe `[[profile-system]]`).

### description-im-Kontext (progressive disclosure)

- Stufe 0: nur die `description` steht ungefragt im Kontext.
- Stufe 1: der Rumpf wird erst geladen, wenn das Modell die Skill als
  relevant einstuft.
- Stufe 2: eine erzwungene Skill liegt vollständig im Kontext des Workers.

### `skills list`

`hermes -p <profil> skills list` zeigt die Auflösung einer Skill mit Herkunft
(`hub-installed`, `builtin`, `local`) und je Zeile `enabled` oder `disabled`.
Greift eine Skill nicht, ist die erste Diagnose: falsches Verzeichnis oder
`disabled`.

### Skills erzwingen

`hermes kanban create … --skill <name>` legt die Skill fest in den Kontext des
Workers, unabhängig davon, ob das Modell sie für relevant hält. Für Pipelines
mit festem Ablauf ist das der richtige Weg — der Ablauf hängt dann nicht von
der Überzeugungskraft einer `description` ab.

### Skill gegen MCP-Server

Eine Skill ist **Text** (Wissen + Anweisungen → Kontext). Ein MCP-Server ist
**Werkzeug** (Fähigkeiten → Funktionen, die der Agent aufrufen kann). Eine
Skill kostet nur Kontext, ein MCP-Server Kontext und Werkzeug-Slots — was als
Text löschbar ist, gehört als Skill.

## Quellen

- `2026-08-07-skills-system.md` — Transkript „Skills in Hermes Agent, von
  unten aufgebaut" (Tonbi's AI Garage), verifiziert an der lokalen Installation
  v0.20.0; die Speicherort-Aussage wurde zum präzisierten Profilmodell
  geschärft, nicht wortgleich übernommen.

## Siehe auch

- [[profile-system]]