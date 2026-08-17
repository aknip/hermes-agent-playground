#!/usr/bin/env bash
#
# ESF — Dispatcher-Pumpe
# ======================
#
#   ./pump.sh            alle 20 s ein Tick, max. 120 Ticks
#   ./pump.sh 10 300     alle 10 s, max. 300 Ticks
#   ./pump.sh --once     genau ein Tick
#   ./pump.sh --dry      Trockenlauf: was WÜRDE der Dispatcher tun
#
# Im Dauerbetrieb übernimmt das Gateway (launchd, Tick 60 s) diese Aufgabe.
# Die Pumpe ist der manuelle Ersatz für Testläufe — und das Werkzeug, mit dem
# man beim Zusehen lernt, wo die Organisation stehenbleibt.
#
# `blocked` zählt hier NICHT als offen: Die Pumpe endet von selbst, sobald nur
# noch Gates warten, und sagt, welche. Weiter mit ./gate.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

case "${1:-}" in
    --once) hermes kanban --board "$BOARD" dispatch; exit 0 ;;
    --dry)  hermes kanban --board "$BOARD" dispatch --dry-run; exit 0 ;;
esac

INTERVALL="${1:-20}"
MAX_TICKS="${2:-120}"

lage() {
    local json triage blocked
    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"

    triage="$(printf '%s' "$json" | jq -r '[.[] | select(.status=="triage")] | length')"
    if [ "$triage" -gt 0 ]; then
        printf '\n\033[33m⚠ %s Karte(n) in der TRIAGE — vermutlich block_loop_detected:\033[0m\n' "$triage"
        printf '%s' "$json" | jq -r '.[] | select(.status=="triage") | "   \(.id)  \(.title)"'
        printf '   Diese Karten fragen niemanden mehr. Nichts in Hermes warnt davor.\n'
    fi

    blocked="$(printf '%s' "$json" | jq -r '[.[] | select(.status=="blocked")] | length')"
    [ "$blocked" -gt 0 ] || return 0
    printf '\n\033[1m%s Gate(s) warten auf den CEO:\033[0m\n' "$blocked"
    printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | "   \(.id)  \(.title)"'
    printf '\nVollständige Vorlagen:  ./gate.sh\n'
}

for tick in $(seq 1 "$MAX_TICKS"); do
    hermes kanban --board "$BOARD" dispatch >/dev/null 2>&1 || true

    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"
    offen="$(printf '%s' "$json" | jq '[.[] | select(.status=="ready" or .status=="running" or .status=="todo")] | length')"
    lagebild="$(printf '%s' "$json" | jq -r 'group_by(.status) | map("\(.[0].status)=\(length)") | join("  ")')"

    printf '[%03d %s] %s\n' "$tick" "$(date '+%H:%M:%S')" "${lagebild:-leer}"

    if [ "$offen" -eq 0 ]; then
        echo; echo "Nichts mehr in Arbeit — Pumpe beendet."
        hermes kanban --board "$BOARD" list
        lage
        exit 0
    fi
    sleep "$INTERVALL"
done

echo; echo "Maximale Tick-Zahl ($MAX_TICKS) erreicht, es ist noch Arbeit offen:"
hermes kanban --board "$BOARD" list
lage
