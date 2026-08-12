#!/usr/bin/env bash
#
# Story 7 — Cron-Job fuer das taegliche Briefing anlegen bzw. entfernen
# =====================================================================
#
#   ./install-cron.sh              werktags um 9 Uhr
#   ./install-cron.sh "0 6 * * *"  eigener Zeitplan
#   ./install-cron.sh --remove     Job und Wrapper entfernen
#
# `hermes cron` fuehrt nur Skripte unter ~/.hermes/scripts/ aus. Deshalb legt
# dieses Skript dort einen Wrapper an, der VAULT_DIR setzt und den echten
# Erzeuger aufruft.
#
# --no-agent heisst: kein Modell. Das Skript IST der Job und kostet keine
# Tokens; die fallen erst bei scout/editor/publisher an.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_NAME="story7-briefing"
WRAPPER="story7-briefing.sh"
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
    fi
    rm -f "$TARGET"
    echo "Wrapper $TARGET entfernt."
    exit 0
fi

SCHEDULE="${1:-0 9 * * 1-5}"

mkdir -p "$HOME/.hermes/scripts"
cat > "$TARGET" <<EOF
#!/usr/bin/env bash
# Von "Story 7 - Scheduled Briefing/install-cron.sh" erzeugt.
set -euo pipefail
export VAULT_DIR="$HERE/workspace/vault"
export VAULT_BOARD="kanban-story-7"
exec "$HERE/scripts/briefing-tick.sh"
EOF
chmod +x "$TARGET"
echo "Wrapper angelegt: $TARGET"
echo "  VAULT_DIR   = $HERE/workspace/vault"
echo "  VAULT_BOARD = kanban-story-7"
echo

hermes cron create "$SCHEDULE" \
    --name "$JOB_NAME" \
    --script "$WRAPPER" \
    --no-agent \
    --deliver local

echo
echo "Der Wrapper erzeugt die Pipeline fuer HEUTE. Liegt unter"
echo "vault/sources/<heute>/ kein Abwurf, tut er nichts und meldet das."
echo
echo "Kontrolle:  hermes cron list"
echo "Sofort:     hermes cron run  $(job_id)"
echo "Historie:   hermes cron runs $(job_id)"
echo "Entfernen:  ./install-cron.sh --remove"
