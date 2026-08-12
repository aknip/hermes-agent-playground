#!/usr/bin/env bash
#
# Story 8 - Digital Twin — Dispatcher-Pumpe
# ================================
#
# Stoesst wiederholt `hermes kanban dispatch` auf dem Board dieser Story an und
# zeigt nach jedem Tick den Board-Zustand, bis nichts mehr offen ist.
#
# Im Normalbetrieb macht das der Dispatcher im Gateway — aber nur alle 60 s
# (kanban.dispatch_interval_seconds) und fuer ALLE Boards. Diese Pumpe arbeitet
# nur auf "kanban-story-8" und laesst sich mit Ctrl-C stoppen.
#
#   ./pump.sh            alle 15 s ein Tick, max. 40 Ticks
#   ./pump.sh 10 100     alle 10 s, max. 100 Ticks
#   ./pump.sh --once     genau ein Tick
#
set -euo pipefail

BOARD="kanban-story-8"

if [ "${1:-}" = "--once" ]; then
    hermes kanban --board "$BOARD" dispatch
    exit 0
fi

INTERVAL="${1:-15}"
MAX_TICKS="${2:-40}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

for tick in $(seq 1 "$MAX_TICKS"); do
    hermes kanban --board "$BOARD" dispatch >/dev/null 2>&1 || true

    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"
    open=$(printf '%s' "$json" | jq '[.[] | select(.status=="ready" or .status=="running" or .status=="todo")] | length')
    summary=$(printf '%s' "$json" | jq -r 'group_by(.status) | map("\(.[0].status)=\(length)") | join("  ")')

    printf '[%02d] %s\n' "$tick" "${summary:-leer}"

    if [ "$open" -eq 0 ]; then
        echo; echo "Nichts mehr offen — Pumpe beendet."
        hermes kanban --board "$BOARD" list
        exit 0
    fi
    sleep "$INTERVAL"
done

echo; echo "Maximale Tick-Zahl ($MAX_TICKS) erreicht, es ist noch Arbeit offen:"
hermes kanban --board "$BOARD" list
