#!/usr/bin/env bash
#
# ESF — Einen Lauf als Akte sichern
# =================================
#
#   scripts/dump-lauf.sh [<zielverzeichnis>]     Standard: beispiel-lauf-1/
#
# Sichert alles, was einen Lauf nachvollziehbar macht, in ein VERSIONIERTES
# Verzeichnis — dasselbe Muster wie `beispiel-lauf-1/` in Story 11.
#
# Warum das nötig ist, und zwar dringend:
#
#   Der Firmen-Vault liegt unter workspace/ und ist gitignored (seed/ ist der
#   Master, workspace/ die Wegwerfkopie). Das Board liegt in
#   ~/.hermes/kanban/boards/<slug>/kanban.db. Beides überlebt weder
#   ./reset-workspace.sh noch ./teardown.sh. Ohne diese Akte wäre das Ergebnis
#   eines Laufs — Analysen, Roadmap, Gate-Antworten, Karten-Historie — nach dem
#   Rückbau spurlos weg.
#
#   Kapitel 10 des Konzepts verlangt „Das Board ist das Protokoll". Ein
#   Protokoll, das nur in einer Datenbank steht, die der Rückbau löscht, ist
#   keins.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
ZIEL="${1:-$ESF/beispiel-lauf-1}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault unter $VAULT"; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

mkdir -p "$ZIEL"

# ---------------------------------------------------------------------------
say "1/5  Das Board"
# ---------------------------------------------------------------------------
# Nicht nur die Liste: je Karte die volle Akte mit Läufen, Ereignissen,
# Kommentaren und Abschluss-metadata. Das ist die Historie, die der Teardown
# löscht.
liste="$(k list --json)"
{
    printf '{\n  "board": "%s",\n  "gesichert_am": "%s",\n  "karten": [\n' \
        "$BOARD" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    erste=1
    for id in $(printf '%s' "$liste" | jq -r '.[].id'); do
        [ "$erste" -eq 1 ] || printf ',\n'
        erste=0
        k show "$id" --json 2>/dev/null | jq -c '.'
    done
    printf '\n  ]\n}\n'
} > "$ZIEL/board.json"
anzahl="$(printf '%s' "$liste" | jq 'length')"
echo "  $anzahl Karten -> board.json ($(wc -c < "$ZIEL/board.json" | tr -d ' ') Byte)"

# Menschenlesbare Kurzfassung daneben.
printf '%s' "$liste" | jq -r '.[] | "\(.status)\t\(.assignee)\t\(.id)\t\(.title)"' \
    | column -t -s $'\t' > "$ZIEL/board.txt" 2>/dev/null \
    || printf '%s' "$liste" | jq -r '.[] | "\(.status) \(.assignee) \(.id) \(.title)"' > "$ZIEL/board.txt"

# ---------------------------------------------------------------------------
say "2/5  Der Vault"
# ---------------------------------------------------------------------------
rm -rf "$ZIEL/vault"
mkdir -p "$ZIEL/vault"
for ordner in analysis roadmap decisions specs reports ledger; do
    [ -d "$VAULT/$ordner" ] || continue
    # e2e-<datum>/ enthält Traces und Screenshots — Megabytes je Lauf, und der
    # Erkenntniswert liegt im Protokoll, nicht im Bildmaterial.
    cp -R "$VAULT/$ordner" "$ZIEL/vault/"
    rm -rf "$ZIEL/vault/$ordner"/e2e-*/test-results 2>/dev/null || true
done
cp "$VAULT/AGENTS.md" "$VAULT/cadence.yaml" "$ZIEL/vault/" 2>/dev/null || true
# sources/ ist der Korpus und liegt schon versioniert unter seed/.
printf 'Der Markt-Korpus dieses Laufs liegt versioniert unter seed/company/sources/.\n' \
    > "$ZIEL/vault/sources-HINWEIS.txt"
echo "  $(find "$ZIEL/vault" -type f | wc -l | tr -d ' ') Dateien -> vault/"

# ---------------------------------------------------------------------------
say "3/5  Die Historien"
# ---------------------------------------------------------------------------
git -C "$VAULT" log --oneline --stat > "$ZIEL/git-log-vault.txt" 2>/dev/null || true
echo "  Vault:   $(git -C "$VAULT" rev-list --count HEAD 2>/dev/null || echo 0) Commits"

REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
if [ -d "$REPO/.git" ]; then
    git -C "$REPO" log --oneline --stat > "$ZIEL/git-log-produkt.txt"
    git -C "$REPO" worktree list > "$ZIEL/worktrees.txt"
    echo "  Produkt: $(git -C "$REPO" rev-list --count HEAD) Commits, $(git -C "$REPO" worktree list | wc -l | tr -d ' ') Worktree(s)"
fi

# ---------------------------------------------------------------------------
say "4/5  Laufzeiten"
# ---------------------------------------------------------------------------
# Wanduhrzeit je Karte aus den Board-Zeitstempeln — die einzige Messung, die
# Hermes verlässlich liefert.
{
    printf '%-12s %-22s %8s %6s  %s\n' KARTE PROFIL MINUTEN LAEUFE TITEL
    jq -r '.karten[] |
        [ .task.id,
          (.task.assignee // "-"),
          ( [ .runs[]? | select(.started_at and .ended_at) | (.ended_at - .started_at) ]
            | add // 0 | . / 60 | floor ),
          ([.runs[]?] | length),
          .task.title
        ] | @tsv' "$ZIEL/board.json" \
    | awk -F'\t' '{printf "%-12s %-22s %8s %6s  %s\n", $1, $2, $3, $4, $5}'
} > "$ZIEL/laufzeiten.txt"
gesamt="$(jq -r '[.karten[] | [.runs[]? | select(.started_at and .ended_at) | (.ended_at - .started_at)] | add // 0] | add / 60 | floor' "$ZIEL/board.json")"
printf '\nSumme Kartenzeit: %s Minuten\n' "$gesamt" >> "$ZIEL/laufzeiten.txt"
echo "  Kartenzeit gesamt: $gesamt min"

# ---------------------------------------------------------------------------
say "5/5  Kurzbericht"
# ---------------------------------------------------------------------------
if [ ! -f "$ZIEL/README.md" ]; then
    cat > "$ZIEL/README.md" <<EOF
# Beispiel-Lauf — $(date '+%d.%m.%Y')

Die Akte eines echten ESF-Laufs, gesichert mit \`scripts/dump-lauf.sh\`.
Sie existiert, weil sowohl der Vault (\`workspace/\`, gitignored) als auch das
Board (\`~/.hermes/kanban/\`) beim Rückbau verschwinden.

| Datei | Inhalt |
|-------|--------|
| \`board.json\` | jede Karte mit Läufen, Ereignissen, Kommentaren und Abschluss-metadata |
| \`board.txt\` | dieselbe Liste zum Überfliegen |
| \`vault/\` | Analysen, Roadmap, ADRs, Spezifikationen, Reports, Ledger |
| \`laufzeiten.txt\` | Wanduhrminuten je Karte aus den Board-Zeitstempeln |
| \`git-log-vault.txt\` | die Historie des Firmen-Vaults |
| \`git-log-produkt.txt\` | die Historie des Produkt-Repos |
| \`worktrees.txt\` | welche Feature-Worktrees am Ende standen |

Der Hergang steht in [\`../RUN-PROTOKOLL.md\`](../RUN-PROTOKOLL.md),
die Befunde in [\`../VERIFIKATION.md\`](../VERIFIKATION.md).
EOF
    echo "  README.md angelegt"
else
    echo "  README.md existiert — unverändert gelassen"
fi

printf '\n\033[32m✓ Lauf gesichert in %s\033[0m\n' "${ZIEL#$ESF/}"
printf '  Jetzt committen — sonst ist die Akte beim nächsten Rückbau weg.\n'
