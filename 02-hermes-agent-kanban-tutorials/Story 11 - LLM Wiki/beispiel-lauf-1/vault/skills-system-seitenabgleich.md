# Seiten-Abgleich · Item `skills-system`

**Karte:** t_6373c513 · Bahn: seiten-abgleich (Klassifikator)
**Itemschema:** vault/skills-system.md (slug `skills-system`, score 98, status triage)
**Datum:** 2026-08-11

## Gegenstand

Das Item buendelt die Kandidaten aus `intake/transcripts.md` zur Quelle
`sources/transcripts/2026-08-07-skills-system.md` („Skills in Hermes Agent, von
unten aufgebaut", Bezug Hermes Agent 0.20.0). Die zu pruefende Aussage ist das
Skill-System insgesamt, in seiner Genauigkeit laut Item-Titel: **„Skills-System:
Aufbau, Speicherorte, description-im-Kontext-Mechanik"**. Konkrete Teilaussagen
aus dem Intake:

1. Eine Skill = Verzeichnis mit `SKILL.md`, oben YAML-Frontmatter (`name`,
   `description`), darunter Markdown; keine Registrierung/installation.
2. Drei Speicherorte mit Reihenfolge/Reichweite: `~/.hermes/skills/` (global),
   `~/.hermes/profiles/<name>/skills/` (profil-lokal, `local` im `skills list`),
   eingebaute Skills.
3. Nur die `description` landet automatisch im Kontext; der Rumpf wird erst bei
   Relevanzentscheidung geladen — die `description` ist die wichtigste Zeile.
4. `hermes kanban create … --skill <name>` erzwingt eine Skill im Worker-Kontext.
5. `hermes -p <profil> skills list` zeigt Herkunft (`hub-installed`, `builtin`,
   `local`) und je Zeile `enabled`/`disabled`.
6. Skill = Text/Wissen (kostet Kontext), MCP-Server = Werkzeug (kostet Kontext
   **und** Werkzeug-Slots).

## Gelesene Seiten

**wiki/index.md** (vollstaendig, 31 Zeilen)
- Zeile 21: `[[skills-system]] — Skills, Aufloesung, profil-lokale Skills`.
- Die Zielseite `pages/skills-system.md` **existiert nicht** auf der Platte
  (geprueft: `ls wiki/pages/skills-system.md` → No such file or directory).
  Damit ist `index.md:21` ein **Stub-Link** auf eine nicht geschriebene Seite —
  laut wiki/AGENTS.md §3 ein Linter-Fehler, keine Absichtserklaerung.

**wiki/pages/kanban-board.md** (vollstaendig, 64 Zeilen)
- Zeile 57–61: Der Review-Agent fuers `review`-Routing nutzt eine Skill namens
  `sdlc-review`. Das ist eine Erwaehnung des Skill-**Verwendungsorts** fuer ein
  konkretes Kommando, **nicht** die Aussage des Items (Aufbau, Speicherorte,
  description-Mechanik). Keine der sechs Teilaussagen ist hier enthalten.

**wiki/pages/profile-system.md** (vollstaendig, 59 Zeilen)
- Zeile 29, Tabelle „Dateien eines Profils": eine Zeile `skills/<name>/SKILL.md`
  | profil-lokale Skills.
- Zeile 14–15: „eigener Systemprompt … eigener Konfiguration und eigenen
  Skills".
- Das nennt **einen** der drei Speicherorte und nur als Verzeichniszeile im
  Profil-Kontext. Es sagt nichts ueber die Skill-Struktur (YAML-Frontmatter),
  nichts ueber die Reihenfolge/Reichweite der drei Orte, nichts ueber die
  description-im-Kontext-Mechanik, nichts ueber `skills list`-Herkunft oder
  `--skill`-Erzwingung. Deckt Teilaussage 2 nur rudimentaer ab, in keiner
  Genauigkeit der Kernaussage.

**wiki/pages/memory-system.md** (vollstaendig, 53 Zeilen)
- Zeile 36: „ob ein Worker sein Gedaechtnis … eine Convention, die der Task-Body
  oder eine Skill durchsetzen muss." — reines Stichwort, keine inhaltliche
  Abdeckung.

**wiki/pages/cron-und-zeitplan.md** (vollstaendig, 56 Zeilen)
- Kein Bezug zum Skill-System.

**wiki/pages/gateway-und-dispatcher.md** (vollstaendig, 59 Zeilen)
- Kein Bezug zum Skill-System (Dispatcher/Gateway, keine Skills).

**wiki/pages/kanban-block-semantik.md** (vollstaendig, 52 Zeilen)
- Kein Bezug zum Skill-System.

**wiki/pages/release-historie.md** (vollstaendig, 45 Zeilen)
- Erwaehnt den `sdlc-review`-Agenten als Release-Inhalt 0.20.0, kein Skill-Modell.

## Befund

- **Zielseite fehlt.** `wiki/pages/skills-system.md` existiert nicht, obwohl der
  Index sie verlinkt. Es gab auf keiner Seite einen Platz, der die Aussage des
  Items aufgenommen haette.
- **Keine bestehende Seite deckt die Kernaussage.** Der Kern — Aufbau einer
  Skill (YAML-Frontmatter, keine Registrierung), die **drei** Speicherorte mit
  Reihenfolge, die description-im-Kontext-Mechanik, `skills list`-Herkunft,
  `--skill`-Erzwingung, Skill-vs-MCP — steht nirgends in gleicher Genauigkeit.
  Die einzige Teil-Thematisierung ist die eine Tabellenzeile in
  profile-system.md, die einen Speicherort als Profil-Datei auflistet. Das ist
  eine Erwaehnung, keine Abdeckung (dedup.hinweis: „Die Seite erwaehnt …" ist
  keine Abdeckung).
- **KEIN Widerspruch:** Keine Seite sagt etwas Anderes zum Skill-System; es gibt
  nur einen Stub-Link.

## Klassifikation

Woertlich zum dedup-Verfahren der Pipeline: ein Kandidat ist abgedeckt, wenn die
Aussage dort in gleicher Genauigkeit schon steht. Das ist nicht der Fall. Die
Seite fehlt komplett; die einzige Beruehrung ist eine Erwaehnung in
profile-system.md und ein Stub-Link im Index.

Route laut ingest.yaml route.tabelle: `fehlt → neue_seite`.

wissensstand: fehlt