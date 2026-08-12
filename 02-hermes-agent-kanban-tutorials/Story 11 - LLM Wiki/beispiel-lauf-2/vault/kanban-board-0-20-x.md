---
slug: kanban-board-0-20-x
titel: "Kanban-Board-Ergaenzungen aus 0.20.x: swarm-Befehl, Auto-Migration, diagnostics --kind, complete--summary-Sperre, relativer workspace_path, stats-Alter"
status: gemergt
score: 75
score_breakdown: {neuheit: 15, quellenvertrauen: 17, themenbezug: 22,
                  versionsrelevanz: 13, klarheitsgewinn: 8}
wissensstand: unvollstaendig
route: update
gebuendelt_aus:
  - "intake/releases.md (0.20.0/0.20.1/0.20.2): 'hermes kanban swarm --worker/--verifier/--synthesizer' ; 'Boards werden beim ersten Zugriff automatisch migriert' ; 'hermes kanban diagnostics weist kind aus' ; 'complete a b c --summary bleibt absichtlich abgewiesen' ; 'kanban_create mit relativem workspace_path schlaegt jetzt fehl' ; 'hermes kanban stats zeigt Alter der aeltesten ready-Karte in Minuten'"
betrifft: [kanban-board]
---
Der Slug beschreibt das Item (die Kanban-Board-Seite in der 0.20.x-Linie),
nicht die Quelle. Sechs Kandidaten aus einem Vorgang (Changelogs 0.20.0-0.20.2)
betreffen dieselbe Seitengruppe (`kanban-board.md`).

Dedup: `kanban-board.md` beschreibt Board-Struktur, Spalten, Datenbankpfade,
Worker-Werkzeuge und die review-Spalte. `hermes kanban swarm` steht nur als
Einzeller in `release-historie.md` (Zeile 29) ohne die Signatur
`--worker/--verifier/--synthesizer`; in `kanban-board.md` fehlt der Befehl
ganz. Auto-Migration, `diagnostics --kind`, `complete a b c --summary`-Sperre,
relativer `workspace_path`-Fehler und `stats`-Alter in Minuten stehen in keiner
Seite. Keine dieser Aussagen ist in gleicher Genauigkeit abgedeckt.

Bewertung je Dimension:
- neuheit (15/25): die Signatur von `swarm`, der Migrations-Satz und die
  Werkzeug-Verhalten sind einzeln neu; teils nur Betriebsdetails
  (stats-Alter), teils substanzielle Board-Kommandos.
- quellenvertrauen (17/20): alle aus offiziellem Changelog (0.20.0-0.20.2),
  hoechste Vertrauensstufe.
- themenbezug (22/25): direkt das Kanban-Board von Hermes Agent; die
  Werkzeug-Semantik ist fuer jeden Worker und Pipeline-Bauer relevant.
- versionsrelevanz (13/15): betrifft die aktuelle 0.20.x-Linie.
- klarheitsgewinn (8/15): nur ein Mitglied (swarm-Signatur) beantwortet eine
  bislang unbeantwortbare Frage; die uebrigen sind kleinere Praezisierungen,
  einige an den Rand des Nennenswerten.

summe = 75 >= schwelle 65. status -> recherche. Fan-out ueber
verifikation + seiten-abgleich.
## Discard am Tor 2 (2026-08-11)

`kanban_board discard kb/ingest-kanban-board-0-20-x` ausgefuehrt. main unveraendert (4052eda). Grund (Antwort des Menschen):
Der Branch enthielt eine 57-zeilige neue Seite `pages/skills-system.md`, die NIE durch Tor 1 gegangen ist. Der Linter hat sie beim Reparieren des Befunds `index-toter-link` angelegt (Weg 'Seite schreiben' aus kb-lint) und ihren Inhalt aus `sources/transcripts/2026-08-07-skills-system.md` gezogen. Das ist das Item `skills-system` (Score 88), das auf Karte t_12c04f48 an seinem eigenen Tor 1 steht. (1) Tor-1-Umgehung und (2) Herkunftsluecke im Ingest-Log. Das Item kanban-board-0-20-x selbst und die Tor-1 modify-Antwort bleiben inhaltlich richtig und werden auf einem Branch ohne die ungetorte Seite neu aufgesetzt.
