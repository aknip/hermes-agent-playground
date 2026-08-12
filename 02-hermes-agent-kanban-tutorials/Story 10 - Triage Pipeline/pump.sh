#!/usr/bin/env bash
#
# Story 10 - Triage Pipeline — Dispatcher-Pumpe
# ================================
#
# Stoesst wiederholt `hermes kanban dispatch` auf dem Board dieser Story an und
# zeigt nach jedem Tick den Board-Zustand, bis nichts mehr offen ist.
#
# Im Normalbetrieb macht das der Dispatcher im Gateway — aber nur alle 60 s
# (kanban.dispatch_interval_seconds) und fuer ALLE Boards. Diese Pumpe arbeitet
# nur auf "kanban-story-10" und laesst sich mit Ctrl-C stoppen.
#
#   ./pump.sh            alle 15 s ein Tick, max. 80 Ticks
#   ./pump.sh 10 200     alle 10 s, max. 200 Ticks
#   ./pump.sh --once     genau ein Tick
#
# Besonderheit dieser Story: die Pipeline haelt MIT ABSICHT an, wenn eine
# Tor-Karte auf deine Freigabe wartet. `blocked` zaehlt hier nicht als offen —
# die Pumpe endet dann und sagt dir, worauf gewartet wird. Weiter mit ./gate.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-10"

if [ "${1:-}" = "--once" ]; then
    hermes kanban --board "$BOARD" dispatch
    exit 0
fi

INTERVAL="${1:-15}"
MAX_TICKS="${2:-80}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

report_gates() {
    local json blocked
    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"
    blocked=$(printf '%s' "$json" | jq -r '[.[] | select(.status=="blocked")] | length')
    [ "$blocked" -gt 0 ] || return 0
    printf '\n\033[1m%s Karte(n) warten auf einen Menschen:\033[0m\n' "$blocked"
    printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | "  \(.id)  \(.title)"'
    printf '\nWorauf genau, zeigt:  ./gate.sh\n'
}

for tick in $(seq 1 "$MAX_TICKS"); do
    hermes kanban --board "$BOARD" dispatch >/dev/null 2>&1 || true

    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"
    open=$(printf '%s' "$json" | jq '[.[] | select(.status=="ready" or .status=="running" or .status=="todo")] | length')
    summary=$(printf '%s' "$json" | jq -r 'group_by(.status) | map("\(.[0].status)=\(length)") | join("  ")')

    printf '[%02d] %s\n' "$tick" "${summary:-leer}"

    if [ "$open" -eq 0 ]; then
        echo; echo "Nichts mehr offen — Pumpe beendet."
        hermes kanban --board "$BOARD" list
        report_gates
        exit 0
    fi
    sleep "$INTERVAL"
done

echo; echo "Maximale Tick-Zahl ($MAX_TICKS) erreicht, es ist noch Arbeit offen:"
hermes kanban --board "$BOARD" list
report_gates
