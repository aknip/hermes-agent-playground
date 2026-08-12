# Ingest-Vorschlag: Update — Kanban-Board-Ergänzungen aus 0.20.x

**Slug:** `kanban-board-0-20-x` · **Route:** `update` · **Punkte:** 75/100
**Branch (geplant):** `kb/ingest-kanban-board-0-20-x`

## 1. Was aufgenommen werden soll

Vier Kanban-Board-Verhalten aus der 0.20.x-Linie (0.20.0 Hauptrelease,
0.20.1/0.20.2 Patches) fehlen auf der Seite `kanban-board.md` und werden dort
ergänzt. Neu ist vor allem der CLI-Befehl `hermes kanban swarm "<ziel>"
--worker PROFILE:TITLE[:SKILL] --verifier PROFILE --synthesizer PROFILE`, der
Fan-out, Verifier und Synthese in einem einzigen Befehl vereint und bislang nur
ohne Signatur in `release-historie.md` steht. Zusätzlich aufgenommen werden:
Boards werden beim ersten Zugriff automatisch migriert (keine manuellen
Migrationsschritte); `hermes kanban diagnostics` weist blockierte Karten mit
ihrer Block-Art (`kind`) aus; und `kanban_create` im Worker schlägt mit
relativem `workspace_path` jetzt fehl statt eine unstartbare Karte zu
hinterlassen. Anknüpfungspunkt ist die bestehende `kanban-board.md`; der
swarm-Befehl ordnet die bislang beschreibende Zeile in `release-historie.md`
auch um.

## 2. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `release-0.20.0-velocity.md` | Zeile 13–14 | „`hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P`“ (Create a Kanban Swarm v1 graph) |
| `release-0.20.0-velocity.md` | Zeile 29 | „Keine Schritte nötig. Bestehende Boards werden beim ersten Zugriff migriert.“ |
| `changelog-0.20.1.md` | Zeile 32–33 (Geändert) | „weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund.“ |
| `changelog-0.20.2.md` | Zeile 17–20 (Behoben) | „Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen.“ |

**Verifikations-Bahn sagt:** bestätigt — die vier Aussagen stammen aus den
offiziellen Changelogs der 0.20.x-Linie (höchste Belastbarkeitsstufe). Die
0.20.0-Aussagen (1–2) wurden zusätzlich an der lokal installierten v0.20.0
gemessen; die Kommandos `swarm`/`diagnostics`/`create` samt Signaturen
existieren wie behauptet. Aussage 4 betrifft das agentische
`kanban_create`-Tool, nicht das CLI-`--workspace`.

## 3. Betroffene Seiten

| Seite | Änderung | Warum |
|---|---|---|
| `pages/kanban-board.md` | Abschnitt `## Details` um neuen Unterabschnitt (`### Befehle und Verhalten in 0.20.x`) ergänzen | die vier Aussagen fehlen dort in gleicher Genauigkeit; Seite bleibt unter der 120-Zeilen-Grenze |
| `pages/release-historie.md` | `kanban swarm`-Zeile um die Signatur `--worker/--verifier/--synthesizer` ergänzen | der Einzeller ohne Signatur wird korrekt und verlinkbar |

**Index:** unverändert — `[[kanban-board]]` und `[[release-historie]]` sind
bereits aus `index.md` verlinkt.
**Neue Seiten:** keine
**Prune-Kandidaten:** keine — `release-historie.md:29` wird ergänzt, nicht
ersetzt.

## 4. Was NICHT aufgenommen wird

- Ausdrücklich weggelassen (Entscheidung des Menschen am Tor 1, modify):
  - „`hermes kanban stats` zeigt das Alter der ältesten `ready`-Karte in
    Minuten“ — Ausgabeformat-Detail ohne Konzeptwert.
  - die `complete a b c --summary`-Sperre bei gesetzten Handoff-Flags —
    Einzelfall-Detail ohne Konzeptwert.
  - Begründung: `kanban-board.md` ist die Konzeptseite zum Board, nicht sein
    Changelog. AGENTS.md 2.3 deckelt Seiten bei 120 Zeilen; der Platz gehört
    den vier Aussagen, die eine Frage beantworten.
- Das 0.20.1/0.20.2-Verhalten wird nur über den offiziellen Changelog belegt;
  eine Darstellung als lokal gemessen würde den Unterschied zwischen Messung
  (0.20.0) und Changelog-Beleg (Patches) verwischen.
- Der CLI-`--workspace`-Parameter (`scratch|worktree|…`) wird nicht als
  Pendant zum `workspace_path`-Fehler dargestellt — die Aussage betrifft nur das
  agentische `kanban_create`.
- Keine Betriebsdetails über die Migrationsimplementierung (welche Datenbanken
  wo umgebaut werden) — die Aussage ist „beim ersten Zugriff migriert“, mehr
  nicht.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 15/25 | die `swarm`-Signatur, der Migrations-Satz und die Werkzeug-Verhalten stehen bislang nicht in der Zielseite; nur der swarm-Befehl kommt als Einzeller ohne Signatur in `release-historie.md` vor |
| quellenvertrauen | 17/20 | durchgängig offizieller Changelog (0.20.0–0.20.2), zusätzlich messend bestätigt für 0.20.0 |
| themenbezug | 22/25 | direkt das Kanban-Board von Hermes Agent; Werkzeug-Semantik ist für jeden Worker und Pipeline-Bauer relevant |
| versionsrelevanz | 13/15 | betrifft die aktuelle 0.20.x-Linie, kein veralteter Stand |
| klarheitsgewinn | 8/15 | die swarm-Signatur beantwortet eine bislang unbeantwortbare Frage; die übrigen sind kleinere Präzisierungen, teils am Rand des Nennenswerten |
| **Summe** | **75/100** | Schwelle 65 |