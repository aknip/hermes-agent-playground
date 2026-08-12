---
slug: skills-system-bahn-verifikation
titel: "Bahn Verifikation: Skills-System — sind die sechs Skill-Aussagen belastbar?"
quelle: "sources/transcripts/2026-08-07-skills-system.md (Tonbi's AI Garage, 2026-08-07, Bezug Hermes Agent 0.20.0)"
version: "0.20.0"
datum: 2026-08-11
bahn: verifikation
bewertung_je_aussage:
  1: bestätigt
  2: bestätigt
  3: bestätigt
  4: bestätigt
  5: bestätigt
  6: bestätigt
---

# Bahn Verifikation — Skills-System

Geprüft: die sechs Skill-Aussagen aus dem Transkript
`sources/transcripts/2026-08-07-skills-system.md` gegen (a) den Wortlaut des
Transkripts, (b) die lokale Hermes-Installation v0.20.0 (live ausgeführt),
(c) die offizielle Doku unter hermes-agent.nousresearch.com/docs und
(d) den Quellcode der lokalen Installation.

## Quellenhierarchie (was hier was sagt)

- **SAGEN** — die Aussagen im Video-Transkript (Erklärung / gemessene Beschreibung
  der Mechanik durch den Kanal).
- **VERIFIZIERT** — was ich selbst ausgeführt/gelesen habe: Live-CLI-Aufrufe gegen
  die lokale v0.20.0-Installation, die offiziellen Docs, und der Quellcode
  unter `~/.hermes/hermes-agent`.
- **GEFOLGERT** — was ich daraus ableite.

Die Quelle ist ein Video-Transkript (eigener Kanal) — also weder ein offizieller
Changelog noch eine gemessene Live-Demo von Nous. Das schwächt die Quelle an
sich (der Grund, warum diese Bahn existiert). **Das ändert hier aber nichts an
der Belastbarkeit: alle sechs Kernbehauptungen lassen sich unabhängig gegen die
offizielle Doku UND die real installierte v0.20.0-Installation verifizieren —
und das habe ich getan.** Keine der Aussagen steht im Widerspruch zu einer
offiziellen Quelle; fünf von sechs sind direkt reproduzierbar, die sechste
bestätigt das dokumentierte Verhalten.

---

## Aussage 1 — Skill = Verzeichnis mit SKILL.md (YAML-Frontmatter name+description, darunter Markdown); keine Registrierung/Installation nötig

**Status: bestätigt**

Quellenangabe (Transkript):
- [00:05:40] „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein
  YAML-Frontmatter mit `name` und `description`, darunter Markdown. Das ist
  alles. Keine Registrierung, keine Installation im engeren Sinne — das
  Verzeichnis liegt da, und Hermes findet es."

Läuft gegen offizielle Quelle: JA, wird bestätigt.
- Doku (developer-guide/creating-skills): SKILL.md-Format ist `--- name:
  my-skill description: ... version: ... ---` mit Markdown darunter.
- Doku (user-guide/features/skills): „kompatibel mit dem agentskills.io open
  standard".

Verifiziert (lokal): Eine echte SKILL.md der Installation gelesen — z. B.
`~/.hermes/skills/creative/ascii-art/SKILL.md` beginnt mit
`---\nname: ascii-art\ndescription: "..."\nversion: 4.0.0\n...---`. Der
Discovery-Code (`_find_all_skills` in tools/skills_tool.py) läuft ohne
Registrierung: er scannt Verzeichnisse nach `SKILL.md`-Dateien (via
`iter_skill_index_files`). Es gibt keine Installations-/Registrierungsdatenbank.

Wer sagt es: Behauptung des Kanals → bestätigt durch Live-Demo (echtes
SKILL.md der Installation) + offizielle Doku.

Gefolgert: Die Schreibweise deckt die Beobachtung exakt ab.

---

## Aussage 2 — Drei Ablageorte: ~/.hermes/skills/ (global), ~/.hermes/profiles/<name>/skills/ (profil-lokal, als `local` ausgezeichnet), eingebaut; Reihenfolge ist bedeutsam

**Status: bestätigt** (mit einer Präzisierung zur „global"-Einordnung)

Quellenangabe (Transkript):
- [00:07:55] „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens
  `~/.hermes/skills/` — die gelten global für jedes Profil. Zweitens
  `~/.hermes/profiles/<name>/skills/` — die gelten **nur** für dieses Profil,
  und in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens
  die eingebauten, die mit Hermes selbst kommen."

Läuft gegen offizielle Quelle: JA, wird bestätigt (mit Nuance).
- Doku (user-guide/features/skills): „All skills live in `~/.hermes/skills/` —
  the primary directory and source of truth. On fresh install, bundled skills
  are copied from the repo. Hub-installed and agent-created skills also go
  here." → Die „eingebauten" (builtin) liegen also MIT unter `~/.hermes/skills/`
  (dort liegt `.bundled_manifest`), nicht in einem dritten Ort.
- Die drei im Transkript genannten „Orte" entsprechen real eher den Herkunfts-
  /Ordnungs-Ebenen: primäres Verzeichnis `~/.hermes/skills/`, profil-lokales
  Verzeichnis `~/.hermes/profiles/<name>/skills/`, plus externe Verzeichnisse.

Verifiziert (lokal):
- `hermes -p test-me skills list` → Quelle `builtin` für die gebündelten Skills;
  Kopfzeile „Source".
- `hermes -p developer skills list` → mehrere Skills mit Quelle **`local`**
  (z. B. brainstorming, executing-plans, …), die aus
  `~/.hermes/profiles/developer/skills/` stammen; echte Datei
  `~/.hermes/profiles/developer/skills/yuanbao/SKILL.md` bestätigt den Ablageort.
- **Reihenfolge ist bedeutsam — bestätigt im Code:** `_find_all_skills`
  (comment, tools/skills_tool.py): „Scan local dir first, then external dirs
  (local takes precedence)" und „local dir" = aktives Profil-Verzeichnis. Die
  Dedup-Logik (`seen_names`, first-hit wins) macht die Scan-Reihenfolge zur
  Vorrang-Reihenfolge: eine `local`-Skill überdeckt eine gleichnamige
  global/builtin-Skill.

Wer sagt es: Behauptung des Kanals → bestätigt durch Live-Demo (hermes -p
developer skills list zeigt `local` + builtin; echte Dateien in beiden Orten)
+ offizielle Doku + Quellcode.

Gefolgert: Die Substanz (drei Ebenen, `local`-Kennzeichnung, Reihenfolge =
Vorrangsreihenfolge) stimmt. Präzisierung: die „eingebauten" liegen real unter
`~/.hermes/skills/` und werden nur herkunftsmäßig als `builtin` getaggt — der
dritte „Ort" ist also eine Herkunftsmarke, kein eigenes Verzeichnis.

---

## Aussage 3 — Nur die description landet ungefragt im Kontext; der Rumpf der SKILL.md wird erst bei Bedarf geladen

**Status: bestätigt**

Quellenangabe (Transkript):
- [00:09:30] „**nur die `description` landet ungefragt im Kontext.** Der Rumpf
  der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill
  relevant ist. Deshalb ist die `description` die wichtigste Zeile der ganzen
  Datei."

Läuft gegen offizielle Quelle: JA, wird bestätigt.
- Doku (user-guide/features/skills), erster Satz: „Skills are on-demand
  knowledge documents the agent can load when needed. They follow a **progressive
  disclosure pattern to minimize token usage**."
- Doku (developer-guide/creating-skills): progressive disclosure als
  Authoring-Empfehlung; `description: Brief description (shown in skill search
  results)`.

Verifiziert (lokal, Quellcode): Der Discovery-Pfad (`_find_all_skills`)
extrahiert pro Skill nur `name`, `description`, `category` — NICHT den Rumpf.
Der Docstring von tools/skills_tool.py sagt wörtlich: „Metadata (name ≤64 chars,
description ≤1024 chars) - shown in skills_list. Full Instructions - loaded via
`skill_view` when needed. Linked Files loaded on demand." Der Rumpf wird erst
über das Werkzeug `skill_view` geholt.

Wer sagt es: Behauptung des Kanals → bestätigt durch Quellcode + offizielle
Doku (progressive disclosure).

Gefolgert: Die Mechanik (Description-Disclosure, Rumpf on demand) ist exakt
richtig. Kleinste Nuance: die description ist Teil des Discovery-Datensatzes,
der für skills_list und die Kontext-Vorschau genutzt wird; der volle SKILL.md-
Rumpf wird nie automatisch eingespielt.

---

## Aussage 4 — `hermes kanban create ... --skill <name>` erzwingt die Skill im Worker-Kontext

**Status: bestätigt**

Quellenangabe (Transkript):
- [00:12:10] „`hermes kanban create … --skill <name>`. Dann liegt sie im
  Kontext des Workers, unabhängig davon, ob das Modell sie für relevant hält."

Läuft gegen offizielle Quelle: JA, CLI ist die offizielle Schnittstelle.
- Auch im aktuellen Worker-Systemprompt dokumentiert: `kanban_create` mit
  Parameter `skills` = „Skill names to force-load into the dispatched worker".

Verifiziert (lokal, Live-CLI): `hermes kanban create --help` zeigt:
```
--skill SKILLS   Skill to force-load into the worker (repeatable).
                 The kanban lifecycle is already injected automatically.
                 Example: --skill translation --skill github-code-review
```

Wer sagt es: Behauptung des Kanals → bestätigt durch Live-CLI-Ausgabe der
installierten v0.20.0 (die offizielle CLI ist hier die maßgebliche Quelle).

Gefolgert: Der Befehl existiert und macht genau, was behauptet wird.

---

## Aussage 5 — `hermes -p <profil> skills list` zeigt die Auflösung mit Herkunft (hub-installed, builtin, local) und je Zeile enabled/disabled

**Status: bestätigt**

Quellenangabe (Transkript):
- [00:18:22] „`hermes -p <profil> skills list` zeigt euch die Auflösung mit
  Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder
  `disabled`. Wenn eine Skill nicht greift, schaut da zuerst hin."

Läuft gegen offizielle Quelle: JA, CLI ist die offizielle Schnittstelle.

Verifiziert (lokal, Live-CLI):
- `hermes -p test-me skills list` → Tabelle mit Spalten
  `Name | Category | Source | Trust | Status`; Source-Werte `builtin`, und in
  der developer-Liste `local`. Status-Spalte je Zeile `enabled`.
- Fußzeile der Ausgabe: „0 hub-installed, 79 builtin, 0 local — 79 enabled,
  0 disabled." Bei developer: „8 hub-installed, 79 builtin, 34 local — 121
  enabled, 0 disabled."
- Die Herkunftswerte `hub-installed`, `builtin`, `local` erscheinen exakt so.

Wer sagt es: Behauptung des Kanals → bestätigt durch Live-Demo der installierten
v0.20.0 (drei Profile ausprobiert).

Gefolgert: Die Befehlsausgabe und die Herkunfts-Vokabeln stimmen wörtlich.

---

## Aussage 6 — Skill kostet Kontext (Text), MCP-Server kostet Kontext UND Werkzeug-Slots; Regel „was Text sein kann, soll Text sein"

**Status: bestätigt** (Mechanik-Teil) — mit Hinweis, dass die „Regel" eine Empfehlung (Meinung) ist

Quellenangabe (Transkript):
- [00:24:05] „eine Skill ist **Text**. Sie fügt Wissen und Anweisungen hinzu.
  Ein MCP-Server ist **Werkzeug** — er fügt Fähigkeiten hinzu, also Funktionen,
  die der Agent aufrufen kann. Eine Skill kostet Kontext, ein MCP-Server kostet
  Kontext **und** Werkzeug-Slots. Deshalb: was Text sein kann, soll Text sein."

Läuft gegen offizielle Quelle: JA (Mechanik-Teil wird bestätigt).
- Doku (user-guide/features/tools + mcp): MCP-Server fügen dem Modell sichtbare
  Werkzeuge hinzu (die in den Modell-Tools-Array einfließen).
- Doku (user-guide/features/skills): progressive disclosure, um Tokens zu
  sparen; Skills sind Textdokumente.

Verifiziert (lokal, Quellcode): tools/tool_search.py beschreibt die
progressive Tool-Offenlegung: MCP-/Plugin-Tools erscheinen im
„model-visible tools array" und es gibt ein `listing_token_budget`
(`min(threshold_pct% of context, listing_max_tokens)`) — d. h. MCP-Werkzeuge
belegen sowohl Kontext (Katalog-Listing) als auch Werkzeug-Plätze im
Tools-Array. Eine Skill dagegen ist reiner Text ohne Werkzeugschema.

Falsifizierbar/Markierung: Der Mechanik-Teil („Skill = Text/Teil des Kontexts;
MCP = Werkzeug mit eigenem Platzbedarf im Tools-Array") ist bestätigt und gegen
den Quellcode geprüft. Die abschließende Norm **„was Text sein kann, soll Text
sein"** ist eine *Empfehlung* des Kanals, keine falsifizierbare Tatsachenbehauptung
— sie ist durch nichts zu widerlegen, weil sie ein Design-Rat ist.

Wer sagt es: Behauptung des Kanals (Mechanik) → bestätigt durch Quellcode +
Doku; die Regel ist eine Meinung/Empfehlung.

---

## Fazit

Alle sechs Aussagen sind **bestätigt**. Keine läuft gegen eine offizielle
Quelle; keine ist widersprüchlich; keine ist unbelegt. Sowohl die offizielle
Doku als auch die real installierte v0.20.0-Installation decken die Kernaussagen
ab — die Verifikations-Bahn war hier der richtige Vorsichtsmechanismus, findet
aber keinen inhaltlichen Fehler.

Zwei Präzisierungen für den Ingest, die KEINE Widersprüche sind:
1. (Aussage 2) Die „eingebauten" Skills liegen real MIT unter
   `~/.hermes/skills/` und werden herkunftsmäßig als `builtin` getaggt — der
   „dritte Ort" ist eine Herkunftsmarke, kein eigenes Verzeichnis.
2. (Aussage 6) Die deutschsprachige Norm „was Text sein kann, soll Text sein"
   ist eine Designempfehlung des Kanals, keine überprüfbare Verhaltensaussage.

Quellenvertrauen in eins: Changelog/Live-Demo (CLI+Installation) > offizielle
Doku > Video-Behauptung. Die Video-Aussage ist als Einstiegspunkt gut, die
Zitierwürdigkeit für die Wissensbasis sollten die verifizierten Fakten tragen
(Referenzierung auf CLI/Installation/Doku), nicht die Video-Behauptung allein.