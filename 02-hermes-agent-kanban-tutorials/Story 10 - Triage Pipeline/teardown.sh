#!/usr/bin/env bash
#
# Story 10 - Triage Pipeline — Teardown
# ================================
#
# Entfernt ausschliesslich die Artefakte DIESER Story:
#
#   ./teardown.sh                  Board + Profile + Arbeitsdateien
#   ./teardown.sh --keep-profiles  Board + Arbeitsdateien (Profile bleiben)
#   ./teardown.sh --files-only     nur Arbeitsdateien
#   -y / --yes                     ohne Rueckfrage
#
# Achtung: Profile liegen global in ~/.hermes/profiles/. Einige Namen kommen in
# mehreren Stories vor. Die sieben Profile dieser Story tragen alle das
# Praefix 'triage-' und kollidieren mit KEINER anderen Story — --keep-profiles
# ist hier also nur noetig, wenn du sie selbst weiterverwenden willst.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-10"
PROFILE_NAMES=(triage-scout triage-orchestrator triage-researcher triage-analyst
               triage-builder triage-tester triage-producer)

ASSUME_YES=0; REMOVE_BOARD=1; REMOVE_PROFILES=1
for arg in "$@"; do
    case "$arg" in
        -y|--yes)        ASSUME_YES=1 ;;
        --keep-profiles) REMOVE_PROFILES=0 ;;
        --files-only)    REMOVE_PROFILES=0; REMOVE_BOARD=0 ;;
        *) echo "Unbekannte Option: $arg"; exit 1 ;;
    esac
done

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "Es werden entfernt:"
[ "$REMOVE_BOARD"    -eq 1 ] && echo "  • Board:   $BOARD (inkl. Tasks, Runs, Events, Logs, Workspaces)" \
                             || echo "  • Board:   bleibt"
[ "$REMOVE_PROFILES" -eq 1 ] && echo "  • Profile: ${PROFILE_NAMES[*]}" \
                             || echo "  • Profile: bleiben"
echo "  • Arbeitsdateien: workspace/ wird aus seed/ neu aufgebaut"

if [ "$ASSUME_YES" -eq 0 ]; then
    printf '\nFortfahren? [j/N] '
    read -r answer
    case "$answer" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
fi

say "1/3  Board"
if [ "$REMOVE_BOARD" -eq 0 ]; then
    echo "  uebersprungen"
else
    if hermes kanban boards show 2>/dev/null | head -1 | grep -qx "Current board: ${BOARD}"; then
        hermes kanban boards switch default >/dev/null
        echo "  aktives Board zurueck auf 'default'"
    fi
    if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
        hermes kanban boards rm "$BOARD" --delete
    else
        echo "  Board '$BOARD' existiert nicht (mehr)"
    fi
    rm -rf "$HOME/.hermes/kanban/boards/$BOARD"
fi

say "2/3  Profile"
if [ "$REMOVE_PROFILES" -eq 0 ]; then
    echo "  uebersprungen"
else
    for name in "${PROFILE_NAMES[@]}"; do
        if [ -d "$HOME/.hermes/profiles/$name" ]; then
            hermes profile delete "$name" -y >/dev/null 2>&1 \
                && echo "  $name — geloescht" \
                || echo "  $name — 'profile delete' schlug fehl, raeume von Hand auf"
            rm -rf "$HOME/.hermes/profiles/$name"
            rm -f  "$HOME/.local/bin/$name"
        else
            echo "  $name — nicht vorhanden"
        fi
    done
fi

say "3/3  Arbeitsverzeichnis"
"$HERE/reset-workspace.sh" --diff | sed 's/^/  /'
echo
"$HERE/reset-workspace.sh" | sed 's/^/  /'

say "Kontrolle"
echo "Boards:";  hermes kanban boards list 2>/dev/null | sed 's/^/  /'
echo; echo "Profile:"; hermes profile list 2>/dev/null | sed 's/^/  /'

printf '\n\033[32m✓ Teardown abgeschlossen.\033[0m\n'
