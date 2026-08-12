# Ingest-Vorschlag: Neue Seite — Skills-System: Aufbau, Speicherorte, description-im-Kontext-Mechanik

**Slug:** `skills-system` · **Route:** `neue_seite` · **Punkte:** 98/100
**Branch (geplant):** `kb/ingest-skills-system`

## 1. Warum es diese Seite noch nicht gibt

`wiki/index.md:21` verlinkt `[[skills-system]]`, aber die Seite `pages/skills-system.md`
existiert nicht (geprüft: keine Datei auf der Platte) — also ein Stub-Link. Die Aussage
des Items (Skill-Aufbau, die drei Speicherorte mit Reichweite, die description-im-Kontext-
Mechanik, `skills list`-Herkunft, `--skill`-Erzwingung) steht nirgends in gleicher
Genauigkeit: `profile-system.md` nennt nur eine Tabellenzeile (einen Speicherort als
Profil-Datei), `memory-system.md`, `cron-und-zeitplan.md`, `gateway-und-dispatcher.md`,
`kanban-block-semantik.md`, `release-historie.md` und `kanban-board.md` erwähnen das
Skill-System gar nicht oder nur am Rand. Das ist eine Erwähnung, keine Abdeckung.

## 2. Geplante Seite

**Dateiname:** `pages/skills-system.md`

```yaml
title: Skills-System: Aufbau, Speicherorte und description-im-Kontext
slug: skills-system
updated: 2026-08-11
tags: [skills, konfiguration]
sources: [2026-08-07-skills-system.md]
version: 0.20.0
```

**Gliederung nach AGENTS.md 2.2:**

- `## Kurzfassung` — eine Skill ist ein Verzeichnis mit `SKILL.md` (YAML-Frontmatter
  `name`/`description` + Markdown); nur die `description` landet automatisch im Kontext,
  der Rumpf wird bedarfsgeladen; drei Speicherorte mit abgestufter Reichweite.
- `## Details`
  - ### Aufbau einer Skill — Verzeichnis + `SKILL.md`, Frontmatter `name`/`description`,
    keine Registrierung für lokal abgelegte Skills (`hermes skills install` gilt für
    Hub-Skills).
  - ### Speicherorte und Reichweite — die präzisierte Fassung: default-Home
    (`~/.hermes/skills/`, Skills-Root des default-Profils), profil-eigenes Home
    (`~/.hermes/profiles/<name>/skills/`, als `local` ausgewiesen), gebündelte/builtin.
  - ### description-im-Kontext (progressive disclosure) — Stufe 0/1/2, die description
    ist die wichtigste Zeile.
  - ### `skills list` — Herkunft `hub-installed`/`builtin`/`local`, Status
    `enabled`/`disabled`.
  - ### Skills erzwingen — `hermes kanban create … --skill <name>`.
  - ### Skill gegen MCP-Server — Text/Wissen (Kontext) gegen Werkzeug (Kontext +
    Werkzeug-Slots), als Konzept.
- `## Quellen` — `sources/transcripts/2026-08-07-skills-system.md`
- `## Siehe auch` — `[[profile-system]]`

**Geschätzte Länge:** ~65 Zeilen (Grenze 120)

## 3. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `2026-08-07-skills-system.md` | 00:05:40 | „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown." |
| `2026-08-07-skills-system.md` | 00:07:55 | „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens `~/.hermes/skills/` … Zweitens `~/.hermes/profiles/<name>/skills/` … Drittens die eingebauten." |
| `2026-08-07-skills-system.md` | 00:09:30 | „… nur die `description` landet ungefragt im Kontext. Der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill relevant ist." |
| `2026-08-07-skills-system.md` | 00:12:10 | „`hermes kanban create … --skill <name>`. Dann liegt sie im Kontext des Workers" |
| `2026-08-07-skills-system.md` | 00:18:22 | „`hermes -p <profil> skills list` zeigt … Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder `disabled`." |

**Verifikations-Bahn sagt:** teilweise bestätigt — 4 von 6 Kernaussagen an der lokalen
Installation v0.20.0 verifiziert; eine (Speicherort-Zählung) ist teil-widerlegt und wird
in der Seite präzisiert statt wortgleich übernommen.

## 4. Folgen für den Rest der Wissensbasis

**Index:** `index.md:21` verlinkt `[[skills-system]]` bereits — die Seite füllt einen
vorhandenen Link und wird nicht verändert.
**Eingehende Links:** optional `profile-system.md` (Zeile über profil-lokale Skills) → die
neue Seite, um den Verweis «verlinkt statt wiederholt» zu erfüllen.
**Heilt einen Linter-Befund:** ja — den Stub-Link `[[skills-system]]` aus `index.md:21`.
**Prune-Kandidaten:** keine.

## 5. Was NICHT aufgenommen wird

Kein wortgetreues Abschreiben der Quelle — verdichtet. Nicht übernommen werden: die
anekdotische Daumenregel „in neun von zehn Fällen falsches Verzeichnis oder disabled";
Meinungen/Empfehlungen des Sprechers ohne Beleg; die behauptete Kosten-Bilanz
„MCP-Server kostet Kontext und Werkzeug-Slots" nur als nicht gemessenes Konzept, nicht als
präzise Regel; und der vom Sprecher behauptete, gemessen falsche Satz „`~/.hermes/skills/`
gilt global für jedes Profil" — stattdessen steht das präzisierte Profilmodell in der Seite.

## 6. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 25/25 | Zielseite existiert nicht (nur Stub-Link); kein Platz hat die Aussage in gleicher Genauigkeit. |
| quellenvertrauen | 18/20 | gemessene Demo, Bezug 0.20.0, mehrfach Zitat + Zeitmarke, gegen lokale Installation gegen-geprüft. |
| themenbezug | 25/25 | direkt das Skill-System von Hermes Agent, Kernkonzept. |
| versionsrelevanz | 15/15 | aktuelles Hauptrelease 0.20.0. |
| klarheitsgewinn | 15/15 | füllt eine ganze fehlende Seite (description-wichtigste-Zeile, Speicherorte, bedarfsgeladener Rumpf). |
| **Summe** | **98/100** | Schwelle 65 |