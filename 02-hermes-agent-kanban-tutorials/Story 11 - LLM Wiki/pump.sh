#!/usr/bin/env bash
#
# Story 11 - LLM Wiki — Dispatcher-Pumpe
# ======================================
#
# Stoesst wiederholt `hermes kanban dispatch` auf dem Board dieser Story an und
# zeigt nach jedem Tick den Board-Zustand, bis nichts mehr offen ist.
#
#   ./pump.sh            alle 15 s ein Tick, max. 100 Ticks
#   ./pump.sh 10 200     alle 10 s, max. 200 Ticks
#   ./pump.sh --once     genau ein Tick
#
# Besonderheit dieser Story: die Pipeline haelt MEHRMALS an — an Tor 1 je Item
# und an Tor 2 je Ingest. `blocked` zaehlt hier nicht als offen, die Pumpe endet
# also von selbst und sagt dir, an WELCHEM Tor gewartet wird. Weiter mit
# ./gate.sh
#
# Du wirst diese Pumpe also mehrfach starten. Das ist kein Mangel: eine
# Pipeline, die Wissen schreibt und Wissen loescht, fragt zweimal.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-11"

if [ "${1:-}" = "--once" ]; then
    hermes kanban --board "$BOARD" dispatch
    exit 0
fi

INTERVAL="${1:-15}"
MAX_TICKS="${2:-100}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

report_gates() {
    local json blocked triage
    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"

    # Karten in der TRIAGE sind hier ein Warnsignal: dorthin routet Hermes eine
    # Karte, die nach einem unblock ein zweites Mal mit DERSELBEN Block-Art
    # blockiert wurde (block_loop_detected). Genau das soll diese Story
    # vermeiden, indem jedes Tor eine eigene Karte ist.
    triage=$(printf '%s' "$json" | jq -r '[.[] | select(.status=="triage")] | length')
    if [ "$triage" -gt 0 ]; then
        printf '\n\033[33m⚠ %s Karte(n) in der TRIAGE — vermutlich block_loop_detected:\033[0m\n' "$triage"
        printf '%s' "$json" | jq -r '.[] | select(.status=="triage") | "  \(.id)  \(.title)"'
        printf '  Pruefen:  hermes kanban --board %s show <id>  (Ereignis block_loop_detected?)\n' "$BOARD"
    fi

    blocked=$(printf '%s' "$json" | jq -r '[.[] | select(.status=="blocked")] | length')
    [ "$blocked" -gt 0 ] || return 0

    printf '\n\033[1m%s Karte(n) warten auf einen Menschen:\033[0m\n' "$blocked"
    # Am Titel ist erkennbar, WELCHES Tor wartet — und damit, welche Verben
    # gelten. Zwei Tore mit denselben Verben waeren ein Tor, zweimal gebaut.
    printf '%s' "$json" | jq -r '
      .[] | select(.status=="blocked") |
      if   (.title | startswith("Vorschlag + Tor 1"))
      then "  \(.id)  [TOR 1: approve | shelve | modify]        \(.title)"
      elif (.title | startswith("Commit + Tor 2"))
      then "  \(.id)  [TOR 2: merge | merge-ohne-prune | discard]  \(.title)"
      else "  \(.id)  [kein Tor — echte Blockade]                \(.title)"
      end'
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
