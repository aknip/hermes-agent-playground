# Ingest-Vorschlag: Update — Kanban-CLI-Guardrails

**Slug:** `kanban-boardschutz` · **Route:** `update` · **Punkte:** 76/100
**Branch (geplant):** `kb/ingest-kanban-boardschutz`

## 1. Was aufgenommen werden soll

Drei Verhaltensgrenzen der Kanban-Worker-Werkzeuge, die 0.20.1 und 0.20.2
gesetzt haben, werden in die Seite `kanban-board` aufgenommen. Erstens weist
`kanban_create` einen relativen `workspace_path` jetzt mit einer Fehlermeldung
ab; vorher entstand stillschweigend eine Karte, die nie gestartet wurde.
Zweitens wird `kanban complete a b c --summary …` abgewiesen, sobald
Handoff-Flags gesetzt sind — Absicht, denn Summary und Metadata gelten je Run
und dieselbe Zusammenfassung auf mehrere Karten zu kopieren ist fast immer
falsch. Drittens zeigt `hermes kanban stats` zusätzlich das Alter der ältesten
`ready`-Karte in Minuten (nicht mehr nur als Zeitstempel). Alle drei sind
Worker-/CLI-Guardrails, die auf der Seite derzeit nicht dokumentiert sind.

## 2. Belege

| Quelle | Stelle | Zitat (wörtlich) |
|---|---|---|
| `changelog-0.20.2.md` | Behoben → `kanban_create` im Worker, Z.17–20 | „Ein relativer `workspace_path` wurde stillschweigend abgewiesen — die Karte entstand, wurde aber nie gestartet und es gab keine Fehlermeldung auf dem Board. Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen." |
| `changelog-0.20.1.md` | Bekannte Einschränkung, Z.37–40 | „`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn Handoff-Flags gesetzt sind. Das ist Absicht: Summary und Metadata gelten je Run, und dieselbe Zusammenfassung auf drei Karten zu kopieren ist fast immer falsch." |
| `changelog-0.20.2.md` | Geändert, Z.32–33 | „`hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel." |

**Verifikations-Bahn sagt:** bestätigt — alle drei Teilaussagen sind in den
offiziellen Changelogs (höchste Quellenstufe) wörtlich bzw. quasi-wörtlich
belegt; keine wurde verschärft oder verfälscht. Lokal nur als Baseline
(0.20.0, Absenz des stats-Altersfelds) prüfbar, da die Installation älter als
beide Releases ist.

## 3. Betroffene Seiten

| Seite | Änderung | Warum |
|---|---|---|
| `pages/kanban-board.md` | Abschnitt `## Details` → `### Werkzeuge im Worker` ergänzen | Dort steht die Werkzeugliste des Workers (`kanban_create` inklusive); die drei Verhaltensgrenzen gehören an genau diese Stelle. |

**Index:** unverändert (`[[kanban-board]]` ist bereits verlinkt)
**Neue Seiten:** keine
**Prune-Kandidaten:** keine

## 4. Was NICHT aufgenommen wird

Nicht aufgenommen wird der genaue Wortlaut der neuen Fehlermeldung von
`kanban_create`: Der Changelog nennt sie nicht, und lokal (0.20.0) ist sie
nicht reproduzierbar — ein erfundener Meldungstext wäre eine Kopie an Genauigkeit
vorbei und nicht belegbar. Ebenso wird **nicht** behauptet, dass `kanban
complete` bei der Abweisung eine bestimmte Fehlermeldung erzeugt oder dass es
einen Workaround (etwa pro Karte einzeln mit `--summary`) gibt; beides steht
nicht im Changelog und wurde nicht geprüft. Die Guardrails werden auf das
dokumentierte Verhalten reduziert, nicht auf mutmaßliche Mechanik.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 16/25 | Verhaltensgrenzen des Worker-Werkzeugs, auf der Seite nicht dokumentiert. |
| quellenvertrauen | 18/20 | Offizieller Changelog 0.20.1/0.20.2, höchste Quellenstufe. |
| themenbezug | 22/25 | Direkt die Kanban-Board-/Worker-Werkzeuge. |
| versionsrelevanz | 15/15 | Aktuelle Patches (0.20.1, 0.20.2). |
| klarheitsgewinn | 5/15 | Hauptsächlich ein Guardrail (relativer `workspace_path`), für diese Pipeline relevant; der Rest ergänzt wenig Neues für die Antwortqualität. |
| **Summe** | **76/100** | Schwelle 65 |