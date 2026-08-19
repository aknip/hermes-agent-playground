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

# ---------------------------------------------------------------------------
# Die Laufzeit-Tabelle
# ---------------------------------------------------------------------------
# Wanduhrzeit je Karte aus den Board-Zeitstempeln — die einzige Messung, die
# Hermes verlässlich liefert.
#
# BEFUND vom 20.08.2026: Diese Tabelle hat in BEIDEN gesicherten Akten ihrer
# eigenen Summenzeile widersprochen, und zwar um genau denselben Betrag:
#
#   awk '/^t_/{s+=$3} END{print s}' beispiel-lauf-2/laufzeiten.txt  -> 1114
#   grep Summe                     beispiel-lauf-2/laufzeiten.txt   -> 1131
#   awk '/^t_/{s+=$3} END{print s}' beispiel-lauf-3/laufzeiten.txt  ->  541
#   grep Summe                     beispiel-lauf-3/laufzeiten.txt   ->  558
#
# Ursache: Die Spalte wurde je Karte mit `floor` auf Minuten abgeschnitten, die
# Summe aber aus den SEKUNDEN gebildet und erst danach gerundet. Bei 33 bzw. 34
# Karten sammelt das im Mittel eine halbe Minute je Karte — 17 und 17.
#
# Die Summe war also die genauere Zahl, aber sie war nicht nachrechenbar, und
# nach dem eigenen Vertrag dieses Projekts ist eine Zahl, die niemand
# nachrechnen kann, kein Beleg. Jetzt steht beides da: die Summe der GEDRUCKTEN
# Spalte (nachrechenbar) und die genaue Sekundenzahl daneben, mit dem
# Rundungsverlust ausgewiesen. Wer die Vorher/Nachher-Spalte einer Optimierung
# aus dieser Tabelle zieht, zieht sie damit aus einer Zahl, die stimmt.
laufzeiten_tabelle() { # board.json  -> Tabelle auf stdout
    local quelle="$1" tabelle spalte sekunden
    tabelle="$(jq -r '.karten[] |
        [ .task.id,
          (.task.assignee // "-"),
          ( [ .runs[]? | select(.started_at and .ended_at) | (.ended_at - .started_at) ]
            | add // 0 | . / 60 | floor ),
          ([.runs[]?] | length),
          .task.title
        ] | @tsv' "$quelle" \
        | awk -F'\t' '{printf "%-12s %-22s %8s %6s  %s\n", $1, $2, $3, $4, $5}')"
    printf '%-12s %-22s %8s %6s  %s\n' KARTE PROFIL MINUTEN LAEUFE TITEL
    printf '%s\n' "$tabelle"
    spalte="$(printf '%s\n' "$tabelle" | awk 'NF>=5 {s+=$3} END{print s+0}')"
    sekunden="$(jq -r '[.karten[] | [.runs[]? | select(.started_at and .ended_at)
                        | (.ended_at - .started_at)] | add // 0] | add // 0' "$quelle")"
    printf '\nSumme Kartenzeit: %s Minuten   (Summe der Spalte oben, nachrechenbar)\n' "$spalte"
    printf 'Genau %s Sekunden = %s Minuten; die Differenz von %s Minuten ist der\n' \
        "$sekunden" \
        "$(awk -v s="$sekunden" 'BEGIN{printf "%.1f", s/60}')" \
        "$(awk -v s="$sekunden" -v sp="$spalte" 'BEGIN{printf "%.1f", s/60 - sp}')"
    printf 'Rundungsverlust je Karte (floor), nicht ein Messfehler.\n'
}

# --nur-laufzeiten <board.json>
# Nur die Tabelle, auf stdout, ohne Board, ohne Vault, ohne zu schreiben. Sie
# existiert, damit die Arithmetik dieser Tabelle pruefbar ist, ohne einen echten
# Lauf zu fahren — scripts/test-optimierung.sh 5 tut genau das.
if [ "${1:-}" = "--nur-laufzeiten" ]; then
    [ -n "${2:-}" ] && [ -f "${2:-}" ] \
        || { echo "FEHLER: --nur-laufzeiten braucht eine board.json"; exit 2; }
    laufzeiten_tabelle "$2"
    exit 0
fi

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
laufzeiten_tabelle "$ZIEL/board.json" > "$ZIEL/laufzeiten.txt"
echo "  $(grep '^Summe Kartenzeit:' "$ZIEL/laufzeiten.txt")"

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
