# Ingest-Vorschlag: Neue Seite — Skills-System

**Slug:** `skills-system` · **Route:** `neue_seite` · **Punkte:** 88/100
**Branch (geplant):** `kb/ingest-skills-system`

## 1. Warum es diese Seite noch nicht gibt

Geprüft wurden `wiki/pages/skills-system.md` (existiert nicht), `wiki/index.md`
(`[[skills-system]]` ist bereits als **Stub-Link** verlinkt, Zeile 21, ohne
Zielseite) und `wiki/pages/profile-system.md` (erwähnt in Zeile 29 nur den
Pfad `skills/<name>/SKILL.md` als Profildatei — eine Topic-Mention, keine der
sechs Mechanik-Aussagen). Die sechs Skill-Mechanik-Aussagen aus dem Transkript
(0.20.0) stehen in **keiner** der sieben vorhandenen Seiten in gleicher
Genauigkeit. Eine ganze, bereits verlinkte Kernseite fehlt.

## 2. Geplante Seite

**Dateiname:** `pages/skills-system.md`

```yaml
title: Skills in Hermes Agent
slug: skills-system
updated: 2026-08-11
tags: [skills, profile, kontext]
sources: [sources/transcripts/2026-08-07-skills-system.md]
version: 0.20.0
```

**Gliederung nach AGENTS.md 2.2:**

- `## Kurzfassung` — eine Skill ist ein Verzeichnis mit `SKILL.md` (YAML-Frontmatter `name`+`description`, darunter Markdown); es gibt drei Herkunfts-Ebenen, nur die `description` landet ungefragt im Kontext.
- `## Details` —
  - `### Struktur einer Skill` (SKILL.md, kein Registrieren)
  - `### Drei Herkunfts-Ebenen und die Reihenfolge` (global / profil-lokal als `local` / eingebaut als `builtin`; `local` überdeckt gleichnamige)
  - `### Lade-Mechanik: Description-Disclosure` (nur description im Kontext, Rumpf on demand)
  - `### kanban create --skill` (Skill im Worker-Kontext erzwingen)
  - `### skills list` (Auflösung: `hub-installed`/`builtin`/`local`, `enabled`/`disabled`)
  - `### Skill vs. MCP` (Skill = Text/Kontext; MCP = Werkzeug/Kontext+Werkzeug-Slots; „was Text sein kann, soll Text sein" als Empfehlung)
- `## Quellen` — `2026-08-07-skills-system.md`, verifiziert gegen lokale v0.20.0, offizielle Doku und Quellcode
- `## Siehe auch` — `[[profile-system]]`

**Geschätzte Länge:** ~90 Zeilen (Grenze 120)

## 3. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `2026-08-07-skills-system.md` | 00:05:40 | „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown. Das ist alles. Keine Registrierung, keine Installation im engeren Sinne — das Verzeichnis liegt da, und Hermes findet es." |
| `2026-08-07-skills-system.md` | 00:07:55 | „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens `~/.hermes/skills/` … Zweitens `~/.hermes/profiles/<name>/skills/` — … und in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens die eingebauten …" |
| `2026-08-07-skills-system.md` | 00:09:30 | „**nur die `description` landet ungefragt im Kontext.** Der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill relevant ist. … sie ist der einzige Teil, den das Modell garantiert sieht." |
| `2026-08-07-skills-system.md` | 00:12:10 | „`hermes kanban create … --skill <name>`. Dann liegt sie im Kontext des Workers, unabhängig davon, ob das Modell sie für relevant hält." |
| `2026-08-07-skills-system.md` | 00:18:22 | „`hermes -p <profil> skills list` zeigt euch die Auflösung mit Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder `disabled`." |
| `2026-08-07-skills-system.md` | 00:24:05 | „Eine Skill kostet Kontext, ein MCP-Server kostet Kontext **und** Werkzeug-Slots. Deshalb: was Text sein kann, soll Text sein." |

**Verifikations-Bahn sagt:** bestätigt — alle sechs Aussagen wurden gegen die
offizielle Doku, den Quellcode und die real installierte v0.20.0 live verifiziert;
keine widerspricht einer offiziellen Quelle. Die Quelle ist ein Video-Transkript
(kein Changelog), aber die zitierwürdigen Fakten tragen CLI/Installation/Doku.

## 4. Folgen für den Rest der Wissensbasis

**Index:** `[[skills-system]]` ist bereits aus `index.md` (Abschnitt
Automatisierung) verlinkt — als Stub. Kein neuer Index-Eintrag nötig; der Ingest
schließt den Stub. Pflicht nach AGENTS.md 4 bleibt erfüllt.
**Eingehende Links:** `[[skills-system]]` als `## Siehe auch` in
`profile-system.md` ergänzen (profil-lokale Skills sind dort bereits Thema;
„verlinkt statt wiederholt").
**Heilt einen Linter-Befund:** ja — der bisherige Stub-Link `[[skills-system]]`
(AGENTS.md Abschnitt 3) wird aufgelöst.
**Prune-Kandidaten:** keine.

## 5. Was NICHT aufgenommen wird

- Die Norm „was Text sein kann, soll Text sein" wird **als Empfehlung** des
  Kanals dargestellt, nicht als überprüfbare Verhaltensaussage (Verifikation,
  Aussage 6) — aufgenommen wird nur der messbare Mechanik-Teil (Skill = Text;
  MCP = Werkzeug mit Kontext- und Werkzeug-Slot-Preis).
- Die „eingebauten" Skills werden **nicht** als eigenes drittes Verzeichnis
  beschrieben: real liegen sie mit unter `~/.hermes/skills/` und werden nur
  herkunftsmäßig als `builtin` getaggt (Verifikation, Aussage 2). Es sind drei
  **Herkunfts-Ebenen**, keine drei physikalischen Orte.
- Keine Inhalte des Transkripts außerhalb der sechs Mechanik-Aussagen (z. B.
  Flotten-/Orchestrator-Ratschläge 00:31:47, Versionsnummern 00:37:12) — die
  gehören nicht in diese Konzeptseite.
- Keine MCP-Server-Details oder Profil-Konfiguration über den Skill-Ablageort
  hinaus.

## 6. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 22/25 | sechs inhaltlich getrennte Mechanik-Aussagen, von denen keine in den sieben vorhandenen Seiten in gleicher Genauigkeit steht; eine ganze, bereits verlinkte Seite fehlt |
| quellenvertrauen | 14/20 | Quelle ist ein Video-Transkript des eigenen Kanals, kein offizieller Changelog; alle sechs Aussagen aber zusätzlich an v0.20.0, Doku und Quellcode verifiziert |
| themenbezug | 24/25 | direkt das Skill-System von Hermes Agent, Kernbereich der Wissensbasis |
| versionsrelevanz | 14/15 | bezieht sich auf 0.20.0, die aktuelle Hauptversion |
| klarheitsgewinn | 14/15 | schafft eine vollständig fehlende Kernseite und behebt nebenbei einen Index-Stub |
| **Summe** | **88/100** | Schwelle 65 |