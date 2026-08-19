# /goal-Prompt: ESF-Optimierung (Stabilität & Effizienz)

Zum Ausführen in Claude Code, gestartet im Verzeichnis
`03-hermes-agent-software-company/`, am besten im Auto-Mode (sonst fragt jeder
Skript-Aufruf einzeln nach). Die Bedingung bleibt unter dem 4000-Zeichen-Limit
von `/goal`. Abbruch jederzeit mit `/goal clear`.

## Der Prompt

```text
/goal Die ESF in /Users/aknipschild/github/hermes-agent-playground/03-hermes-agent-software-company ist messbar in Stabilität und Effizienz verbessert, gemessen gegen das Testrepo ../04-hermes-agent-software-company-test-kaneo. Erreicht, wenn alle vier Blöcke im Transkript durch selbst ausgeführte Kommandos mit sichtbarer Ausgabe belegt sind — oder brich ab und melde den Stand, sobald 50 Turns erreicht sind.

BLOCK 1 — BASELINE (nur lesen, kein Lauf, keine Modell-Token): _NOTES/OPTIMIERUNG.md enthält eine aus beispiel-lauf-2/, beispiel-lauf-3/laufzeiten.txt, RUN-PROTOKOLL.md und VERIFIKATION.md extrahierte Baseline-Tabelle: Kartenzeit gesamt und je Kartentyp, Anzahl und verlorene Minuten abgebrochener Läufe (timed_out, crashed, pid not alive), die bekannten Stabilitätsbefunde (mindestens: Turbo-Cache-Blindheit von Merge-Riegel und Review, Zeitgrenzen-Risse knapp über dem Deckel, hängender Worker bei 0 % CPU, falsche Grün-Meldungen des Phase-1-Prüfers), Schätzgüte und Kosten je Sprint.

BLOCK 2 — MASSNAHMEN: Mindestens fünf Baseline-Schwachstellen sind nach Schaden × Häufigkeit priorisiert und durch Code-Änderungen an der ESF behoben (scripts/, create-*.sh, pump.sh, probelauf.sh, profiles/*/SOUL.md oder seed/company/cadence.yaml — nie am Produktrepo, nie an ~/.hermes/hermes-agent/). Je Maßnahme ein eigener Git-Commit, dessen Message den Befund benennt.

BLOCK 3 — REGRESSIONSNETZ (modellfrei, kostet keine Token): (a) Je Maßnahme existiert ein deterministischer Nachweis — Testskript, Fixture oder Dry-Run —, der den Defekt VOR dem Fix rot und NACH dem Fix grün zeigt; beide Ausgaben stehen im Transkript. (b) Alle bestehenden Riegel bleiben grün: die drei Selbsttests am Ende von setup.sh, scripts/vault-lint.py gegen seed/lint-selbsttest (exakt 9 Befunde), scripts/ceo-lint.py gegen seed/ceo-selbsttest (exakt 5 Befunde), bash -n mit Exit 0 auf jedem geänderten Shellskript.

BLOCK 4 — VALIDIERUNGSLAUF (kostet Modell-Token, bewusst auf Phase 0 begrenzt): ./reset-workspace.sh und ./setup.sh, dann ./probelauf.sh und ./pump.sh takten, bis ./probelauf.sh --pruefen grün ist. Gates beantwortest du selbst über ./gate.sh als Supervisor-Stellvertreter und protokollierst jede Antwort mit Begründung. Danach belegen scripts/monitor.sh bzw. das Hermes-Ereignis-Log für diesen Lauf: 0 timed_out, 0 crashed, 0 respawn_guarded, 0 block_loop_detected, 0 hängende Worker (scripts/watchdog.sh), 0 Unblocks ohne gate.sh-Verb. Die gemessenen Kartenzeiten stehen als Nachher-Spalte neben der Baseline in OPTIMIERUNG.md, mit ehrlichem Fazit: was ist belegt besser, was ist unverändert, was bleibt unverifiziert (Verifikationsvertrag aus VERIFIKATION.md — nichts als verbessert melden, was nicht gemessen ist).

RANDBEDINGUNGEN: ./install-cron.sh nie aufrufen. ./teardown.sh nur nach scripts/dump-lauf.sh. openrouter-keys.txt nie anzeigen und nie committen. Nur Profile mit esf-Präfix anfassen. Bei Kosten über 5 USD (scripts/assign-keys.sh --verbrauch) den Lauf stoppen und den Stand melden statt weiterzumachen.
```

## Warum das Goal so geschnitten ist

- **Der Evaluator liest nur das Transkript.** Er führt selbst nichts aus —
  jede Teilbedingung ist deshalb als „Kommando gelaufen, Ausgabe sichtbar"
  formuliert, nicht als Zustand auf der Platte.
- **Baseline ohne neuen Lauf.** `beispiel-lauf-2/3` sind bereits gemessene
  Läufe gegen dasselbe Kaneo-Repo — ein neues, schlankeres Beispiel-Repo würde
  genau diese Vergleichbarkeit wegwerfen. Deshalb Kaneo.
- **Blocks 1–3 sind modellfrei** (Token-Kosten ≈ 0), erst Block 4 fährt echte
  Worker — und nur Phase 0 (`probelauf.sh`, die Dummy-Kette), nicht einen
  vollen Sprint. Zur Einordnung: Sprint S3 kostete ≈ 2,75 USD.
- **Turn- und Kostendeckel** stehen in der Bedingung selbst (50 Turns, 5 USD),
  wie die Doku es empfiehlt — sonst läuft ein Goal im Zweifel ewig.

## Teurere Variante (mehr Beweiskraft für Effizienz)

Phase 0 belegt Stabilität gut, Effizienz nur schwach (die Dummy-Kette ist
klein). Wer den Effizienz-Nachweis härter will, ersetzt Block 4 durch einen
Sprint-Lauf — nach `./restore-phase1.sh --ledger` dann `./create-sprint.sh 1`
bis `scripts/check-sprint.sh` grün — und vergleicht die Kartenzeiten mit den
S1-Werten aus `beispiel-lauf-3/laufzeiten.txt`. Kosten: einige USD, Wanduhr:
Stunden. Kostendeckel in der Bedingung dann auf ~10 USD anheben.
