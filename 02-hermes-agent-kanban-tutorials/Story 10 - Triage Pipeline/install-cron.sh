#!/usr/bin/env bash
#
# Story 10 — Cron-Job fuer die Scouts anlegen bzw. entfernen
# ==========================================================
#
#   ./install-cron.sh              Job anlegen (taeglich 07:00)
#   ./install-cron.sh "every 12h"  eigener Zeitplan
#   ./install-cron.sh --remove     Job und Wrapper wieder entfernen
#
# `hermes cron` fuehrt nur Skripte aus, die unter ~/.hermes/scripts/ liegen.
# Deshalb legt dieses Skript dort einen kleinen Wrapper an, der TRIAGE_WS auf
# das workspace/-Verzeichnis dieser Story setzt und den eigentlichen Tick
# aufruft — so bleibt scripts/scout-tick.sh die einzige Quelle der Wahrheit.
#
# Mit --no-agent laeuft kein Modell mit: das Skript IST der Job. Der Tick
# kostet damit keine Tokens; die fallen erst bei den Workern an, die der
# Dispatcher anschliessend startet.
#
# ⚠ Der Autor des Originals rät ausdruecklich davon ab, die Scouts stuendlich
#   laufen zu lassen — ein- bis zweimal taeglich reicht. Jeder Tick zieht eine
#   ganze Pipeline nach sich.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_NAME="story10-scout-tick"
WRAPPER="story10-scout-tick.sh"
TARGET="$HOME/.hermes/scripts/$WRAPPER"
JOBS_JSON="$HOME/.hermes/cron/jobs.json"

job_id() {
    [ -f "$JOBS_JSON" ] || return 0
    jq -r --arg n "$JOB_NAME" '.jobs[]? | select(.name==$n) | .id' \
        "$JOBS_JSON" 2>/dev/null | head -1
}

if [ "${1:-}" = "--remove" ]; then
    id="$(job_id || true)"
    if [ -n "${id:-}" ] && [ "$id" != "null" ]; then
        hermes cron rm "$id"
    else
        echo "Kein Job namens '$JOB_NAME' gefunden — nichts zu entfernen."
        echo "Falls doch einer laeuft:  hermes cron list"
    fi
    rm -f "$TARGET"
    echo "Wrapper $TARGET entfernt."
    exit 0
fi

SCHEDULE="${1:-0 7 * * *}"

mkdir -p "$HOME/.hermes/scripts"
cat > "$TARGET" <<EOF
#!/usr/bin/env bash
# Von "Story 10 - Triage Pipeline/install-cron.sh" erzeugt. Nicht von Hand aendern.
set -euo pipefail
export TRIAGE_WS="$HERE/workspace"
export TRIAGE_BOARD="kanban-story-10"
exec "$HERE/scripts/scout-tick.sh"
EOF
chmod +x "$TARGET"
echo "Wrapper angelegt: $TARGET"
echo "  TRIAGE_WS    = $HERE/workspace"
echo "  TRIAGE_BOARD = kanban-story-10"
echo

hermes cron create "$SCHEDULE" \
    --name "$JOB_NAME" \
    --script "$WRAPPER" \
    --no-agent \
    --deliver local

echo
echo "Kontrolle:"
echo "  hermes cron list"
echo "  hermes cron run $(job_id)     # sofort feuern, ohne auf den Zeitplan zu warten"
echo "  hermes cron runs $(job_id)    # Ausfuehrungshistorie"
echo "Entfernen:"
echo "  ./install-cron.sh --remove"
