# Seiten-Abgleich: kanban-board-0-20-x

Item: `vault/kanban-board-0-20-x.md` — sechs Aussagen zur Kanban-Board-Seite (0.20.0/0.20.1/0.20.2).

Gepruefte Seiten (WIRKLICH gelesen):
- `wiki/pages/kanban-board.md` (72 Zeilen)
- `wiki/pages/release-historie.md` (54 Zeilen)
- `wiki/index.md` (31 Zeilen; nur Inhaltsverzeichnis, keine Sachaussagen)

Betroffen: `kanban-board.md` (hauptsaechlich), `release-historie.md` (teils).

## Befund je Aussage (Quelle SAAGT / Geprueft / Genauigkeit)

### 1. swarm-Signatur — `hermes kanban swarm --worker/--verifier/--synthesizer`
- **kanban-board.md:** fehlt. Zeile 47-51 (Werkzeuge im Worker) nennt nur die
  werkzeugseitigen `kanban_*`-Tools; der CLI-Befehl `hermes kanban swarm`
  kommt nirgends vor.
- **release-historie.md:** Zeile 29:
  `| Kanban | `hermes kanban swarm` als Einzelbefehl fuer Fan-out + Verifier + Synthese |`
  Der Befehl steht als Einzeller, aber OHNE die Signatur
  `--worker/--verifier/--synthesizer`. Fan-out/Verifier/Synthese sind
  beschreibend erwaehnt, die exakten Flags fehlen.
- **Genauigkeit:** unvollstaendig (in release-historie), fehlt (in kanban-board.md).

### 2. Auto-Migration — „Boards werden beim ersten Zugriff automatisch migriert"
- **kanban-board.md:** fehlt.
- **release-historie.md:** fehlt. (Kein Migrations-Satz.)
- **Genauigkeit:** fehlt.

### 3. diagnostics --kind — `hermes kanban diagnostics` weist `kind` blockierter Karten aus
- **kanban-board.md:** fehlt. (`diagnostics` kommt nicht vor.)
- **release-historie.md:** fehlt.
- **Genauigkeit:** fehlt.

### 4. complete--summary-Sperre — `complete a b c --summary` bleibt absichtlich abgewiesen
- **kanban-board.md:** fehlt. (Complete-Semantik/-Sperre nicht behandelt; nur
  die damit verbundene review-Spalte ab Zeile 56.)
- **release-historie.md:** fehlt.
- **Genauigkeit:** fehlt.

### 5. relativer workspace_path — `kanban_create` mit relativem `workspace_path` schlaegt jetzt fehl
- **kanban-board.md:** fehlt. (Zeile 53-54 nennt `kanban_create` als
  Board-erweiterndes Werkzeug, aber nicht das workspace_path-Verhalten.)
- **release-historie.md:** fehlt.
- **Genauigkeit:** fehlt.

### 6. stats-Alter — `hermes kanban stats` zeigt Alter der aeltesten `ready`-Karte in Minuten
- **kanban-board.md:** fehlt. (`stats` kommt nicht vor.)
- **release-historie.md:** fehlt.
- **Genauigkeit:** fehlt.

## Zusammenfassung

- Keine der sechs Aussagen steht in gleicher Genauigkeit in `kanban-board.md`.
- Einzig Anknuepfungspunkt ist `release-historie.md:29` (swarm als Einzeller
  ohne Signatur) — dort unvollstaendig.
- Da die Zielseite `kanban-board.md` existiert und die Aussagen dort fehlen
  bzw. nur unvollstaendig (swarm auch nur als Einzeller andernorts) belegt
  sind, ist die Klassifikation `unvollstaendig` (route.tabelle → update).
- Keine widerspruechliche Aussage gefunden; kein `widerspruch`.

wissensstand: unvollstaendig
