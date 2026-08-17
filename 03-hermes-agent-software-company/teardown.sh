#!/usr/bin/env bash
#
# ESF — Rückbau
# =============
#
#   ./teardown.sh                    alles zurückbauen (fragt nach)
#   ./teardown.sh --keep-profiles    Board und Arbeitskopie weg, Profile bleiben
#   ./teardown.sh --keep-board       Profile und Arbeitskopie weg, Board bleibt
#   ./teardown.sh --yes              nicht nachfragen
#
# Gelöscht werden AUSSCHLIESSLICH Profile, die eine .esf-Markerdatei tragen.
# Profile liegen global in ~/.hermes/profiles/, und ein Teardown, der nach
# Namen löscht, reisst fremde Arbeit mit — das esf--Präfix schützt den
# Namensraum, die Markerdatei schützt das Löschen.
#
# NICHT angetastet wird das Produkt-Repo: Branches, Worktrees und Commits, die
# die ESF dort erzeugt hat, bleiben stehen. Sie sind das Ergebnis, nicht das
# Werkzeug. Was dort aufzuräumen ist, zeigt dieses Skript am Ende an.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
MARKER=".esf"

PROFILE_NAMES=(
    esf-chief-of-staff esf-market-scout esf-market-analyst esf-product-manager
    esf-architect esf-estimator esf-dev-a esf-dev-b esf-reviewer
    esf-qa-release esf-controller
)

KEEP_PROFILES=0; KEEP_BOARD=0; JA=0
for arg in "$@"; do
    case "$arg" in
        --keep-profiles) KEEP_PROFILES=1 ;;
        --keep-board)    KEEP_BOARD=1 ;;
        --yes|-y)        JA=1 ;;
        *) echo "Unbekannte Option '$arg'"; exit 1 ;;
    esac
done

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "Was zurückgebaut wird"
# ---------------------------------------------------------------------------
zu_loeschen=(); geschuetzt=()
for name in "${PROFILE_NAMES[@]}"; do
    verzeichnis="$HOME/.hermes/profiles/$name"
    [ -d "$verzeichnis" ] || continue
    if [ -f "$verzeichnis/$MARKER" ]; then
        zu_loeschen+=("$name")
    else
        geschuetzt+=("$name")
    fi
done

if [ "$KEEP_PROFILES" -eq 1 ]; then
    echo "  Profile:       bleiben (--keep-profiles)"
elif [ ${#zu_loeschen[@]} -eq 0 ]; then
    echo "  Profile:       keine ESF-markierten gefunden"
else
    printf '  Profile:       %s\n' "${zu_loeschen[*]}"
fi
if [ ${#geschuetzt[@]} -gt 0 ]; then
    printf '\033[33m  ⚠ ohne .esf-Marker, bleiben unangetastet: %s\033[0m\n' "${geschuetzt[*]}"
fi

if [ "$KEEP_BOARD" -eq 1 ]; then
    echo "  Board:         bleibt (--keep-board)"
else
    echo "  Board:         $BOARD (inklusive aller Karten und ihrer Historie)"
fi
echo "  Arbeitskopie:  $HERE/workspace/  (seed/ bleibt)"

if [ -f "$HOME/Library/LaunchAgents/ai.hermes.esf.plist" ] || crontab -l 2>/dev/null | grep -q "ESF-"; then
    printf '\033[33m  ⚠ Es sind ESF-Cron-Einträge aktiv. Erst ./install-cron.sh --remove.\033[0m\n'
fi

if [ "$JA" -eq 0 ]; then
    printf '\nFortfahren? [j/N] '
    read -r antwort
    case "$antwort" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
fi

# ---------------------------------------------------------------------------
if [ "$KEEP_BOARD" -eq 0 ]; then
    say "Board"
    if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
        hermes kanban boards delete "$BOARD" --force 2>/dev/null \
            || hermes kanban boards delete "$BOARD" 2>/dev/null \
            || echo "  ⚠ Löschen fehlgeschlagen — von Hand: hermes kanban boards delete $BOARD"
        echo "  $BOARD entfernt"
    else
        echo "  existiert nicht — übersprungen"
    fi
fi

# ---------------------------------------------------------------------------
if [ "$KEEP_PROFILES" -eq 0 ] && [ ${#zu_loeschen[@]} -gt 0 ]; then
    say "Profile"
    for name in "${zu_loeschen[@]}"; do
        hermes profile delete "$name" --force 2>/dev/null \
            || hermes profile delete "$name" 2>/dev/null || true
        rm -rf "$HOME/.hermes/profiles/$name"
        echo "  $name entfernt"
    done
fi

# ---------------------------------------------------------------------------
say "Arbeitskopie"
# ---------------------------------------------------------------------------
if [ -d "$HERE/workspace" ]; then
    rm -rf "$HERE/workspace"
    echo "  workspace/ entfernt (seed/ ist der Master und bleibt)"
else
    echo "  gibt es nicht — übersprungen"
fi
rm -f "$HERE/task-ids.env"

# ---------------------------------------------------------------------------
say "Was im Produkt-Repo bleibt"
# ---------------------------------------------------------------------------
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$HERE/seed/company/cadence.yaml" | head -1)"
if [ -d "$REPO/.git" ]; then
    branches="$(git -C "$REPO" branch --list 'feat/*' --format='%(refname:short)' | tr '\n' ' ')"
    worktrees="$(git -C "$REPO" worktree list | tail -n +2 | wc -l | tr -d ' ')"
    echo "  Repo:      $REPO"
    echo "  Branches:  ${branches:-<keine feat/-Branches>}"
    echo "  Worktrees: $worktrees zusätzlich zum Hauptbaum"
    echo
    echo "  Das ist Absicht: Der Rückbau entfernt die Organisation, nicht ihr"
    echo "  Ergebnis. Zum Aufräumen von Hand:"
    echo "    git -C \"$REPO\" worktree list"
    echo "    git -C \"$REPO\" worktree remove <pfad>"
    echo "    git -C \"$REPO\" branch -D <branch>"
fi

printf '\n\033[32m✓ Rückbau abgeschlossen. Neu aufsetzen: ./setup.sh\033[0m\n'
