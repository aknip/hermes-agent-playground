---
title: Skills in Hermes Agent
slug: skills-system
updated: 2026-08-11
tags: [skills, profile, kontext]
sources: [sources/transcripts/2026-08-07-skills-system.md]
version: 0.20.0
---

## Kurzfassung

Eine Skill ist ein Verzeichnis mit einer `SKILL.md`: oben ein YAML-Frontmatter
mit `name` und `description`, darunter Markdown. Keine Registrierung — das
Verzeichnis liegt unter einem der drei Herkunftsorte, und Hermes findet es.
Erst die `description` landet ungefragt im Kontext; den Rumpf lädt das Modell
erst, wenn es die Skill für relevant hält. Eine Skill kostet nur Kontext,
ein MCP-Server zusätzlich Werkzeug-Slots.

## Details

### Struktur einer Skill

Eine Skill wird **nicht registriert**; es genügt, das Verzeichnis mit der
`SKILL.md` an den richtigen Ort zu legen. Frontmatter-Pflichtfelder sind
`name` und `description`; darunter steht die Anleitung als Markdown.

### Drei Herkunfts-Ebenen und ihre Reihenfolge

Es sind drei **Herkunfts-Ebenen**, keine drei getrennten physikalischen Orte —
die eingebauten liegen real mit unter dem globalen Verzeichnis:

| Ebene | Ort | Gültigkeit |
|---|---|---|
| global | `~/.hermes/skills/` | jedes Profil |
| profil-lokal (`local`) | `~/.hermes/profiles/<name>/skills/` | nur dieses Profil |
| eingebaut (`builtin`) | mit Hermes selbst | überall |

Gleichnamige `local`-Skills überdecken die globalen. Profil-lokale Skills sind
das stärkste Werkzeug für eine Flotte: der Orchestrator bekommt eine Skill, der
Rechercheur nicht — so bleiben die Agenten Spezialisten statt Kopien desselben
Agenten.

### Lade-Mechanik: Description-Disclosure

**Nur die `description` landet ungefragt im Kontext** — sie ist die einzige
Zeile, die das Modell garantiert sieht. Der Rumpf der `SKILL.md` wird erst bei
Bedarf geladen. Die `description` ist deshalb die wichtigste Zeile: entscheidet
sie über die Relevanz. Eine Versionsnummer in der `SKILL.md` ist keine
Kosmetik — sie zeigt, nach welchem Stand ein alter Workflow noch arbeitet.

### Eine Skill für einen Worker erzwingen

`hermes kanban create … --skill <name>` legt die Skill unabhängig von der
Relevanzentscheidung des Modells in den Kontext des Workers. Für Pipelines mit
festem Ablauf der richtige Weg — so hängt der Ablauf nicht davon ab, wie
überzeugend die `description` gerade wirkt.

### Auflösen mit `skills list`

`hermes -p <profil> skills list` zeigt die Auflösung mit Herkunft
(`hub-installed`, `builtin`, `local`) und je Zeile `enabled` oder `disabled`.
Greift eine Skill nicht, zuerst hier nachsehen — meist liegt sie im falschen
Verzeichnis oder ist disabled.

### Skill vs. MCP-Server

Eine Skill ist **Text** (Wissen und Anweisungen), ein MCP-Server ist
**Werkzeug** (vom Agenten aufrufbare Funktionen). Eine Skill kostet Kontext,
ein MCP-Server kostet Kontext **und** Werkzeug-Slots. Als Empfehlung des
Kanals: was Text sein kann, soll Text sein.

## Quellen

- `sources/transcripts/2026-08-07-skills-system.md` — Tonbi's AI Garage
  („Skills in Hermes Agent"), Stand 2026-08-11, alle sechs Mechanik-Aussagen
  zusätzlich gegen v0.20.0, offizielle Doku und Quellcode verifiziert

## Siehe auch

- [[profile-system]]