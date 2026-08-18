# Beispiel-Lauf — 18.08.2026

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
