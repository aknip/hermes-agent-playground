# Verifikation — kanban-board-0-20-x

Lane: verifikation
Geprueft gegen: sources/releases/release-0.20.0-velocity.md, changelog-0.20.1.md, changelog-0.20.2.md
Zusaetzlich: Messung gegen lokale Hermes-Installation (v0.20.0, installiert 2026-08-03, `~/.local/bin/hermes`).

Alle sechs Aussagen stammen aus offiziellen Changelogs (hoechste Belastbarkeitsstufe).
Weil die lokale Installation genau 0.20.0 ist, liessen sich die 0.20.0-Aussagen (1–2)
zusaetzlich messend bestaetigen; die 0.20.1/0.20.2-Aussagen (3–6) liegen ueber der lokal
installierten Version und sind nur ueber den offiziellen Changelog belegt — die
Kommando-Signaturen existieren in 0.20.0 bereits (per `--help` gemessen), das darin
beschriebene *Verhalten* der spaeteren Patches ist nicht lokal reproduzierbar.

---

## 1. `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` vereint Fan-out, Verifier und Synthese in einem Befehl (0.20.0)

- quelle: offizieller Changelog release-0.20.0-velocity.md, Zeile 13–14 (Hauptrelease 0.20.0, 2026-08-03)
- typ: offizieller Changelog + Messung
- befunde (gemessen, `hermes kanban swarm --help` auf v0.20.0):
  - Subkommando `swarm` vorhanden: "Create a Kanban Swarm v1 graph (parallel workers → verifier → synthesizer)"
  - `--worker PROFILE:TITLE[:SKILL,SKILL]` (repeatable) — entspricht `P:T`
  - `--verifier VERIFIER` und `--synthesizer SYNTHESIZER` vorhanden
  - Positional `goal` — entspricht `"<ziel>"`
  - Signatur entspricht der Aussage; Konzept "Fan-out + Verifier + Synthese in einem Befehl" stimmt mit dem Help-Text ueberein.
- markierung: bestaetigt

## 2. Bestehende Boards werden beim ersten Zugriff automatisch migriert, keine Migrationsschritte noetig (0.20.0)

- quelle: offizieller Changelog release-0.20.0-velocity.md, Zeile 29: "Keine Schritte nötig. Bestehende Boards werden beim ersten Zugriff migriert."
- typ: offizieller Changelog
- Die Aussage entspricht dem Changelog 1:1. "automatisch" ist eine zulaessige Paraphrase von "beim ersten Zugriff migriert / keine Schritte noetig".
- markierung: bestaetigt

## 3. `hermes kanban diagnostics` weist blockierte Karten mit ihrer Block-Art (`kind`) aus (0.20.1)

- quelle: offizieller Changelog changelog-0.20.1.md, Zeile 32–33 (Geändert): "weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund."
- typ: offizieller Changelog (Patch 0.20.1, 2026-08-06)
- Subkommando `diagnostics` existiert in 0.20.0 bereits (gemessen, `--help`); das in 0.20.1 ergaenzte `kind`-Verhalten liegt ueber der lokalen Version und ist nicht messbar.
- markierung: bestaetigt

## 4. `hermes kanban complete a b c --summary …` wird bei gesetzten Handoff-Flags absichtlich abgewiesen (0.20.1)

- quelle: offizieller Changelog changelog-0.20.1.md, Zeile 37–40 (Bekannte Einschränkung): "`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn Handoff-Flags gesetzt sind. Das ist Absicht: …"
- typ: offizieller Changelog (Patch 0.20.1)
- Die Aussage ist korrekt, inkl. des "absichtlich". WICHTIGE PRAEZISIERUNG: Im Changelog steht es unter "Bekannte Einschränkung" (nicht unter "Behoben"/"Geändert") und als "bleibt abgewiesen" — es ist ein beabsichtigtes, dokumentiertes Verhalten, kein neuer Fix in 0.20.1. Die Formulierung im Item ("wird ... abgewiesen") ist deshalb inhaltlich richtig, aber die Einordnung als Release-*Aenderung* waere irrefuehrend; es ist eine dokumentierte bestehende Einschraenkung.
- markierung: bestaetigt (mit Praezisierung: als bekannte Einschraenkung, nicht als neuer Fix)

## 5. `kanban_create` mit relativem `workspace_path` schlaegt jetzt mit Meldung fehl, statt eine unstartbare Karte zu hinterlassen (0.20.2)

- quelle: offizieller Changelog changelog-0.20.2.md, Zeile 17–20 (Behoben): "Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen."
- typ: offizieller Changelog (Patch 0.20.2, 2026-08-09)
- Die Aussage entspricht dem Changelog. Anmerkung: Der Changelog spricht von `kanban_create` "im Worker" (d. h. dem agentischen Tool) mit relativem `workspace_path`; der CLI-Befehl `hermes kanban create` verwendet `--workspace` mit Werten `scratch|worktree|worktree:<path>|dir:<path>` (gemessen). Die Item-Aussage ist wertneutral-korrekt; wer sie aufs CLI-Pendant uebertraegt, muss die unterschiedliche Parameterform beachten.
- markierung: bestaetigt

## 6. `hermes kanban stats` zeigt das Alter der aeltesten `ready`-Karte in Minuten (0.20.2)

- quelle: offizieller Changelog changelog-0.20.2.md, Zeile 32–33 (Geändert): "zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel."
- typ: offizieller Changelog (Patch 0.20.2)
- Subkommando `stats` existiert in 0.20.0 bereits und beschreibt sich als "Per-status + per-assignee counts + oldest-ready age" (gemessen, `--help`); das in 0.20.2 ergaenzte Minuten-Format liegt ueber der lokalen Version.
- markierung: bestaetigt

---

## Gesamturteil

Quelle ist belastbar: alle sechs Aussagen stammen aus offiziellen Changelogs der
0.20.x-Linie (0.20.0 Hauptrelease, 0.20.1/0.20.2 Patches). Keine Aussage wird durch den
Quelltext widersprochen; keine ist erfunden oder verstaerkt ueber den Changelog hinaus.
Zwei Praezisierungen fuer den Ingator:
- Aussage 4: im Changelog als "Bekannte Einschränkung" / "bleibt abgewiesen" eingeordnet — beabsichtigtes Verhalten, nicht als Release-Neuerung darstellen.
- Aussage 5: betrifft das agentische `kanban_create`-Tool im Worker (relativer `workspace_path`), nicht direkt das CLI-`--workspace`.
- Aussage 2: "automatisch" ist Paraphrase, kein Quellwort.

Was die Aussage widerlegen wuerde: ein Beispiel/Gegenbeleg, in dem `swarm` ohne
`--verifier`/`--synthesizer` akzeptiert wird bzw. Fan-out ohne Synthese laeuft; ein
Board, das ohne Migration den ersten Zugriff uebersteht; ein `diagnostics`-Output ohne
`kind`-Spalte; ein `complete a b c --summary` oder `kanban_create` mit relativem path,
der dennoch eine Karte anlegt. Keinerlei solcher Gegenbelege vorhanden.

Unterschied "was die Quelle sagt" vs. "was verifiziert wurde":
- Quelle sagt: alle sechs Verhaltensweisen wie oben beschrieben.
- Verifiziert (Messung, v0.20.0): Kommandos `swarm`/`diagnostics`/`complete`/`stats`/`create`
  und ihre Signaturen existieren wie behauptet; `swarm` traegt die volle
  `--worker/--verifier/--synthesizer`-Signatur.
- Inferiert: dass das in 0.20.1/0.20.2 beschriebene Verhalten (kind-Ausgabe, complete-Sperre,
  workspace_path-Fehler, stats-Minuten) so eintritt, wie der offizielle Changelog es
  beschreibt — nicht lokal nachgeprueft, da lokale Version 0.20.0.
