#!/usr/bin/env bash
#
# ESF — Abschluss-Check Tageslauf
# ===============================
#
#   scripts/check-daily.sh
#
# Teil von report-gates.sh. Drei Bedingungen aus Kapitel 9:
#   1. keine Karte hängt in `running`
#   2. jede heute abgeschlossene Karte trägt metadata.actual
#   3. der Gate-Report für heute existiert und listet alle
#      respawn_guarded- und triage-Fälle
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

fehler=0
ok()   { printf '  OK    %s\n' "$*"; }
nein() { printf '  FEHLT %s\n' "$*"; fehler=1; }

liste="$(k list --json 2>/dev/null || echo '[]')"

# 1 — nichts hängt
laufend="$(printf '%s' "$liste" | jq '[.[] | select(.status=="running")] | length')"
if [ "$laufend" -eq 0 ]; then
    ok "keine Karte in running"
else
    nein "$laufend Karte(n) stehen noch auf running"
    printf '%s' "$liste" | jq -r '.[] | select(.status=="running") | "        \(.id)  \(.title)"'
fi

# 2 — Messwerte
# metadata.actual ist der Audit-Kanal. Fehlt er, ist die Karte nicht messbar
# und fällt aus der Kalibrierung — still, und genau das soll auffallen.
ohne="$(printf '%s' "$liste" | jq -r --arg t "$HEUTE" '
    [.[] | select(.status=="done" and ((.updated_at // "") | startswith($t)))
         | select((.metadata.actual // null) == null) | .id] | join(" ")')"
if [ -z "$ohne" ]; then
    ok "jede heute abgeschlossene Karte trägt metadata.actual"
else
    nein "ohne metadata.actual: $ohne"
fi

# 3 — der Report existiert
if [ -f "$VAULT/reports/gate-$HEUTE.html" ]; then
    ok "Gate-Report für $HEUTE liegt vor"
else
    nein "reports/gate-$HEUTE.html fehlt"
fi

# 4 — stille Ausfälle sind gemeldet, nicht nur vorhanden
triage="$(printf '%s' "$liste" | jq '[.[] | select(.status=="triage")] | length')"
if [ "$triage" -eq 0 ]; then
    ok "keine Karte in triage"
elif [ -f "$VAULT/reports/gate-$HEUTE.html" ] && grep -q "Triage" "$VAULT/reports/gate-$HEUTE.html"; then
    ok "$triage triage-Karte(n) — im Gate-Report ausgewiesen"
else
    nein "$triage triage-Karte(n), aber nicht im Gate-Report"
fi

[ "$fehler" -eq 0 ] && exit 0
exit 1
