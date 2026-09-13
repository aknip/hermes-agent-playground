#!/usr/bin/env bash
# Stellt ein Hermes-Profil auf den claude-code-mcp-Provider um — oder wieder zurück.
#
#   ./switch-profile.sh claude-dev            # umstellen (sichert vorher)
#   ./switch-profile.sh claude-dev --restore  # letzte Sicherung zurückspielen
#
# Setzt alle vier Modell-Schlüssel: ein Profil ist nur dispatchbar, wenn
# ~/.hermes/profiles/<name>/config.yaml sie trägt.
set -euo pipefail

PROFILE="${1:-}"
MODE="${2:-switch}"
[ -n "$PROFILE" ] || { echo "Aufruf: $0 <profil> [--restore]" >&2; exit 1; }

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CONFIG="$HERMES_HOME/profiles/$PROFILE/config.yaml"
[ -f "$CONFIG" ] || { echo "FEHLER: kein Profil '$PROFILE' unter $CONFIG" >&2; exit 1; }

if [ "$MODE" = "--restore" ]; then
    # Nach DATEINAMEN sortieren, nicht nach mtime: ``cp -p`` erbt die Zeit der
    # Quelldatei, alle Sicherungen tragen damit dieselbe mtime und ``ls -t`` würde
    # willkürlich wählen. Der Zeitstempel steht im Namen und ist sortierfähig.
    LATEST="$(ls -1 "$HERMES_HOME/profiles/$PROFILE"/config.yaml.pre-claude-code-*.bak 2>/dev/null | sort | tail -1 || true)"
    [ -n "$LATEST" ] || { echo "FEHLER: keine Sicherung gefunden." >&2; exit 1; }
    cp -p "$LATEST" "$CONFIG"
    echo "==> Zurückgespielt aus $(basename "$LATEST")"
    hermes -p "$PROFILE" config get model || true
    exit 0
fi

BACKUP="$CONFIG.pre-claude-code-$(date +%Y%m%d-%H%M%S).bak"
cp -p "$CONFIG" "$BACKUP"
echo "==> Gesichert: $(basename "$BACKUP")"

echo "==> Modell-Schlüssel setzen"
hermes -p "$PROFILE" config set model.provider claude-code-mcp
hermes -p "$PROFILE" config set model.default sonnet
hermes -p "$PROFILE" config set model.base_url claude-code://cli
hermes -p "$PROFILE" config set model.api_mode chat_completions

# Hilfsaufrufe: 'auto' würde je Kompression/Titel/Zerlegung einen CLI-Kaltstart
# auslösen. Sie bleiben auf der billigen Route, für die das Profil schon Zugangsdaten
# hat. Mit HERMES_CC_AUX_PROVIDER=claude-code-mcp bewusst abwählbar.
AUX_PROVIDER="${HERMES_CC_AUX_PROVIDER:-openrouter}"
AUX_MODEL="${HERMES_CC_AUX_MODEL:-deepseek/deepseek-v4-flash-0731}"
if [ "$AUX_PROVIDER" != "claude-code-mcp" ]; then
    echo "==> Hilfsaufrufe auf $AUX_PROVIDER / $AUX_MODEL festnageln"
    for aux in compression title_generation kanban_decomposer; do
        hermes -p "$PROFILE" config set "auxiliary.$aux.provider" "$AUX_PROVIDER"
        hermes -p "$PROFILE" config set "auxiliary.$aux.model" "$AUX_MODEL"
    done
fi

echo "==> Ergebnis"
hermes -p "$PROFILE" config get model
