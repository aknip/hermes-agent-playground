# Verifikation · Item skills-system

**Quelle:** `sources/transcripts/2026-08-07-skills-system.md` — „Skills in Hermes
Agent, von unten aufgebaut" (Kanal: Tonbi's AI Garage, veröffentlicht 2026-08-07,
Bezug: Hermes Agent 0.20.0).
**Rang der Quelle:** Drittanbieter-YouTube-Video (Assertion/Demo-Recherche), KEIN
offizieller Changelog. Die belastbaren Punkte wurden gegen die **lokale
Installation v0.20.0** (`hermes --version` → `Hermes Agent v0.20.0 (2026.8.3)`)
und die **offizielle Doku** (hermes-agent.nousresearch.com/docs/user-guide/features/skills)
gegengeprüft. Jede Teilaussage trägt Quell-Zeitmarke plus das, was an der lokalen
Installation tatsächlich beobachtet wurde.

Legende je Teilaussage: **VERIFIZIERT** (an Installation/Doku beobachtet) ·
**UNEINDEUTIG** (nur Assertion des Sprechers od. teils bestätigt) ·
**WIDERLEGT** (messbar anders).

---

## 1. [00:05:40] „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown. … Keine Registrierung, keine Installation im engeren Sinne — das Verzeichnis liegt da, und Hermes findet es."

**Kernsatz:** Skill = Verzeichnis + `SKILL.md` (YAML-Frontmatter mit `name`/`description`, darunter Markdown); keine Registrierung/Installation nötig, Hermes findet sie über die bloße Lage.
**Befund: VERIFIZIERT.**
- **Verifiziert (lokal):** Temporärer Skill `zzz-verify-test` als reines Verzeichnis mit `SKILL.md` (nur name+description+Markdown) in `~/.hermes/profiles/kb-researcher/skills/` abgelegt → `hermes -p kb-researcher skills list` zeigte ihn sofort als `local`/`enabled`, ohne Install- oder Registrierungsschritt. Die Frontmatter-Struktur (name, description, darunter Markdown) entspricht realen `SKILL.md`-Dateien unter `~/.hermes/skills/`.
- **Verifiziert (Doku):** Abschnitt „Skill Directory Structure" und „SKILL.md Format" der offiziellen Skills-System-Seite bestätigen `SKILL.md` mit `name`/`description` (+ optionale weitere Felder) und Verzeichnislayout `SKILL.md` (required) + `references/`/`templates/`/`scripts/`.
- **Einschränkung (Doku-Nuance):** Es gibt sehr wohl eine `hermes skills install`-Mechanik für Hub-/Registry-Skills (mit Security-Scan) — siehe Abschnitt „Skills Hub". „Keine Installation im engeren Sinne" trifft also für **lokal abgelegte** Skills zu, nicht wörtlich für entfernt installierte. Ich habe nur den Lokal-Fall gemessen; der Satz ist in dieser Präzision für lokale Skills richtig.

---

## 2. [00:07:55] „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens `~/.hermes/skills/` — die gelten **global für jedes Profil**. Zweitens `~/.hermes/profiles/<name>/skills/` — die gelten **nur** für dieses Profil, und in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens die eingebauten, die mit Hermes selbst kommen."

**Kernsatz:** Drei Speicherorte mit abgestufter Reichweite; profil-lokale erscheinen als `local`; eingebaute existieren.

**Befund: UNEINDEUTIG bis TEIL-WIDERLEGT — die Zählung „drei Orte" und die `local`-Zuordnung stimmen, das „global für jedes Profil" stimmt so NICHT (gemessen).**

- **Verifiziert (lokal):** Profil-lokaler Ort und `local`-Label korrekt: temporary Skill in `~/.hermes/profiles/kb-researcher/skills/` → `hermes -p kb-researcher skills list` zeigte ihn als `local`, `enabled`.
- **Verifiziert (lokal):** `builtin`-Quelle existiert: `hermes -p default skills list` listete `79 builtin`. Doku bestätigt gebündelte Skills über `~/.hermes/.bundled_manifest`.
- **WIDERLEGT in Präzision (lokal):** `~/.hermes/skills/` ist **nicht** „global für jedes Profil". `hermes profile show default` → `Path: ~/.hermes`; d.h. `~/.hermes/skills/` ist das Skills-Root des **default**-Profils, nicht eine für alle Profil-Namen sichtbare gemeinsame Ablage. Messung: Ein dort platzierter Skill `zzz-verify-global` erschien in `hermes -p default skills list` als `local`, war aber in **keinem** benannten Profil sichtbar (`kb-researcher` und `developer` zeigten ihn nicht).
- **Nuance (Doku):** Die offizielle Doku sagt „All skills live in `~/.hermes/skills/` — the primary directory and source of truth" und nennt daneben **externe** Skill-Verzeichnisse (`skills.external_dirs` in config.yaml) — also eigentlich zwei Ablagen, nicht drei, und beide Doku-Orte liegen beim realen Home `~/.hermes` bzw. config-referenziert, nicht unter `profiles/<name>/skills/`. Das reale Profilmodell (jedes Profil hat ein eigenes `HERMES_HOME`) macht aus der vom Sprecher behaupteten „drei Orte"-Liste faktisch: default-Home-Skills, profil-eigenes Home-Skills, und gebündelte/builtin. **Der Satz sollte in der Wissensbasis präzisiert statt wortgleich übernommen werden.**

---

## 3. [00:09:30] „… **nur die `description` landet ungefragt im Kontext.** Der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill relevant ist. Deshalb ist die `description` die wichtigste Zeile der ganzen Datei — sie ist der einzige Teil, den das Modell garantiert sieht."

**Kernsatz:** Nur `description` (bzw. Metadaten) automatisch im Kontext; Rumpf bedarfsgeladen (progressive disclosure).
**Befund: VERIFIZIERT.**
- **Verifiziert (Doku):** Abschnitt „Progressive Disclosure": `Level 0: skills_list() → [{name, description, category}, …] (~3k tokens)`; `Level 1: skill_view(name) → Full content + metadata` und `Level 2: skill_view(name, path)` für Referenzdateien. „The agent only loads the full skill content when it actually needs it." — deckt sich exakt mit dem Sprecher.
- **Verifiziert (Kontext-Abgleich):** Das System dieser Session selbst injiziert für jede Skill nur die `description` (Skills Index), der Rumpf kommt erst über `skill_view` — konsistent mit der behaupteten Mechanik.
- **Präzisierungs-Hinweis:** Es ist nicht nur die `description`, sondern der Eintrag `{name, description, category}` — die Aussage ist in der Substanz richtig, leicht zu eng formuliert.

---

## 4. [00:12:10] „Wer eine Skill für einen Kanban-Worker schreibt, kann sie auch erzwingen: `hermes kanban create … --skill <name>`. Dann liegt sie im Kontext des Workers, unabhängig davon, ob das Modell sie für relevant hält."

**Kernsatz:** `hermes kanban create … --skill <name>` erzwingt die Skill im Worker-Kontext, unabhängig von der Relevanzentscheidung.
**Befund: VERIFIZIERT (Flag), Assertion (Semantik).**
- **Verifiziert (lokal):** `hermes kanban create --help` enthält `[--skill SKILLS]` (Metavariable `SKILLS`, wiederholbar). Zudem ist `skill_name` ein Feld des `kanban_create`-Tools in dieser Session — die Mechanik ist real.
- **Uneindeutig (Semantik):** Dass die Skill damit fest im Kontext liegt „unabhängig davon, ob das Modell sie für relevant hält", ist die plausible Ansage des Sprechers; auf der genutzten Oberfläche wirkt sie mit der `skills`-Erzwingung (kanban-create lädt die genannten Skills) konsistent. Kein Gegenbeispiel in Doku/Installation gefunden.

---

## 5. [00:18:22] „`hermes -p <profil> skills list` zeigt euch die Auflösung mit Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder `disabled`. Wenn eine Skill nicht greift, schaut da zuerst hin — in neun von zehn Fällen liegt sie im falschen Verzeichnis oder ist disabled."

**Kernsatz:** `skills list` zeigt Herkunft (`hub-installed`/`builtin`/`local`) und Status (`enabled`/`disabled`) je Zeile.
**Befund: VERIFIZIERT.**
- **Verifiziert (lokal):** Spalte `Source` lieferte exakt die Werte `hub-installed`, `builtin`, `local`; Spalte `Status` je Zeile `enabled`/`disabled`; Abschlusszeile z.B. `0 hub-installed, 0 builtin, 1 local — 1 enabled, 0 disabled`. Beide Beobachtungen (bei `default` mit großem sortiertem `skills list` und bei `kb-researcher` nach Test-Skill) zeigen das Schema.
- **Uneindeutig (Heuristik):** „In neun von zehn Fällen falsches Verzeichnis oder disabled" ist eine anekdotische Daumenregel des Sprechers, nicht prüfbar — als solche kennzeichnen, nicht als Regel übernehmen.

---

## 6. [00:24:05] „Eine Skill ist **Text**. … Ein MCP-Server ist **Werkzeug** — er fügt Fähigkeiten hinzu, also Funktionen, die der Agent aufrufen kann. Eine Skill kostet Kontext, ein MCP-Server kostet Kontext **und** Werkzeug-Slots."

**Kernsatz:** Skill = Text/Wissen (kostet Kontext); MCP-Server = Werkzeug/Funktionen (kostet Kontext UND Werkzeug-Slots).
**Befund: CONCEPTUELL VERIFIZIERT / als Assertion einordnen.**
- **Verifiziert (Doku, erste Hälfte):** Offizielle Doku öffnet Skills-System-Seite mit „Skills are on-demand knowledge documents the agent can load when needed." — deckt Skill=Wissen/Text.
- **Uneindeutig (zweite Hälfte):** Die genaue Kosten-Bilanz „MCP-Server kostet Kontext **und** Werkzeug-Slots" ist eine erklärende Assertion aus dem Video (analog dem Einstieg [00:02:14] „drei völlig verschiedene Dinge"), keine messbare Eigenschaft dieser Installation. Konsistent mit dem Skills-/Tools-Modell, aber keine offizielle Quelle mit dieser Formulierung. Als Konzept-Baustein brauchbar, nicht als präzise messbare Kostenregel belegt.

---

## 7. Versionierung (Context)

**Kernsatz:** Das Video bezieht sich auf Hermes Agent 0.20.0.
**Befund: VERIFIZIERT.**
- **Verifiziert (lokal):** Lokale Installation = `Hermes Agent v0.20.0 (2026.8.3)`; die geprüften Kommandos/Fenster (`skills list`, `kanban create --help`) laufen auf genau dieser Version identisch zu den Behauptungen. Die offizielle Doku-Seite (Skills System) beschreibt den aktuelleren Stand inkl. `skills.external_dirs`, das als Ausblick zu kennzeichnen ist, nicht als Widerspruch zu 0.20.0.

---

## Zusammenfassung für die Abnahme

- 4 von 6 Kernaussagen **VERIFIZIERT** (1 Skill-Aufbau, 3 description-im-Kontext, 4 `--skill`-Flag, 5 `skills list`-Schema).
- Aussage 6 **conceptuell verifiziert**, zweite Hälfte als Assertion kennzeichnen.
- Aussage 2 **teil-widerlegt**: Die Zählung „drei Orte" und das `local`-Label stimmen, aber „`~/.hermes/skills/` gilt global für jedes Profil" ist **gemessen falsch** — es ist das Skills-Root des default-Profils (`~/.hermes` = Path von `profile default`); benannte Profile haben ein eigenes `HERMES_HOME` und sehen Inhalte von `~/.hermes/skills/` nicht. **Nicht wortgleich übernehmen; präzisieren.**

**Letzte Bereinigung bestätigt:** Alle temporären Verifikations-Skills (`zzz-verify-test`, `zzz-verify-global`) wurden nach der Messung entfernt; `find ~/.hermes -name 'zzz-verify*'` → 0 Treffer. Es wurden keine `wiki/`-Dateien und keine Kanban-Karten angefasst.