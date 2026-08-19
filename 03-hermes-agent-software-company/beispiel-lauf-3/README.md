# Beispiel-Lauf 3 — zweiter Rundlauf, 18./19.08.2026

**Phasen 0, 1 und 2 in einem Durchgang**, auf einer frisch zurückgebauten
Hermes-Instanz, mit dem Menschen in der Supervisor-Rolle.

| | |
|---|---|
| Karten | 25 (6 Onboarding · 4 Probelauf, archiviert · 8 Sprint 1 · 12 Sprint 2 · Release) |
| Kartenzeit | 558 Minuten |
| Modell | `deepseek/deepseek-v4-flash-0731`, alle Tiers, ein OpenRouter-Key je Rolle |
| Gates | Roadmap `modify` · Probe `approve` · Release `approve` mit drei Auflagen |
| Ergebnis | Release R1 freigegeben, drei Features auf `main`, E2E von 2 auf 13 Tests |

Die Schätzgüte drehte über die zwei Sprints — der Zweck des Ledgers, gemessen:

| Klasse | S1 (Ist/Schätzung) | S2 (Ist/Schätzung) |
|--------|--------------------|--------------------|
| Umsetzung | 0,21 | 1,38 |
| Review | 0,09 | 0,88 |
| E2E-Bau | — | 0,63 |


Die Akte eines echten ESF-Laufs, gesichert mit `scripts/dump-lauf.sh`.
Sie existiert, weil sowohl der Vault (`workspace/`, gitignored) als auch das
Board (`~/.hermes/kanban/`) beim Rückbau verschwinden.

| Datei | Inhalt |
|-------|--------|
| `board.json` | jede Karte mit Läufen, Ereignissen, Kommentaren und Abschluss-metadata |
| `board.txt` | dieselbe Liste zum Überfliegen |
| `vault/` | Analysen, Roadmap, ADRs, Spezifikationen, Reports, Ledger |
| `laufzeiten.txt` | Wanduhrminuten je Karte aus den Board-Zeitstempeln |
| `git-log-vault.txt` | die Historie des Firmen-Vaults |
| `git-log-produkt.txt` | die Historie des Produkt-Repos |
| `worktrees.txt` | welche Feature-Worktrees am Ende standen |

Der Hergang steht in [`../RUN-PROTOKOLL.md`](../RUN-PROTOKOLL.md),
die Befunde in [`../VERIFIKATION.md`](../VERIFIKATION.md).
