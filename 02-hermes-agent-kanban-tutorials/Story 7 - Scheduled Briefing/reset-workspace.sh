#!/usr/bin/env bash
#
# Story 7 - Scheduled Briefing — Arbeitsverzeichnis zuruecksetzen
# ======================================
#
# seed/       unveraenderliche Startdateien (Master, wird nie beschrieben)
# workspace/  Arbeitskopie — hier arbeiten die Worker
#
# Worker ueberschreiben auch Startdateien. Nur mit einer unangetasteten Kopie
# ist die Story beliebig oft wiederholbar.
#
#   ./reset-workspace.sh          workspace/ aus seed/ neu aufbauen
#   ./reset-workspace.sh --diff   nur zeigen, was die Worker angefasst haben
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED="$HERE/seed"
WS="$HERE/workspace"

[ -d "$SEED" ] || { echo "FEHLER: $SEED fehlt."; exit 1; }

if [ "${1:-}" = "--diff" ]; then
    if [ -d "$WS" ]; then
        diff -rq "$SEED" "$WS" 2>&1 | sed 's/^/  /' || true
    else
        echo "  workspace/ existiert nicht"
    fi
    exit 0
fi

rm -rf "$WS"
mkdir -p "$WS"
cp -R "$SEED"/. "$WS"/
count=$(find "$WS" -type f | wc -l | tr -d ' ')
printf 'workspace/ zurueckgesetzt (%s Startdateien aus seed/)\n' "$count"
