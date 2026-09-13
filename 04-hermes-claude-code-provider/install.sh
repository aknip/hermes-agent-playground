#!/usr/bin/env bash
# Leitet die Plugin-Kopie aus dem Repo-Master nach ~/.hermes/ ab.
#
#   ./install.sh                 # Root-Home + Profil claude-dev
#   ./install.sh claude-dev foo  # Root-Home + genannte Profile
#
# WICHTIG — und in der FAQ so nicht abgebildet: **jedes Profil ist sein eigenes
# HERMES_HOME** (`~/.hermes/profiles/<name>`, siehe hermes_cli/main.py:435 ff. und
# hermes_constants.py:102). `providers._user_plugins_dir()` sucht deshalb unter
# `$HERMES_HOME/plugins/model-providers/` — für ein Profil also NICHT im Root-Home.
# Ein nur nach ~/.hermes/plugins/ gelegtes Provider-Plugin ist für `hermes -p <profil>`
# unsichtbar und endet in „Unknown provider" (hermes_cli/auth.py:1471).
#
# Idempotent: mehrfaches Ausführen führt zum selben Zustand.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugin"
PLUGIN_NAME="claude-code-mcp"

[ -d "$SRC" ] || { echo "FEHLER: Master fehlt: $SRC" >&2; exit 1; }

PROFILES=("$@")
[ ${#PROFILES[@]} -gt 0 ] || PROFILES=("claude-dev")

copy_to() {
    local dest="$1"
    mkdir -p "$dest"
    rm -rf "$dest/__pycache__"
    for f in "$SRC"/*.py "$SRC"/plugin.yaml; do
        [ -e "$f" ] || continue
        install -m 0644 "$f" "$dest/$(basename "$f")"
    done
    echo "    $dest"
}

echo "==> Plugin ausrollen"
copy_to "$HERMES_HOME/plugins/model-providers/$PLUGIN_NAME"
for profile in "${PROFILES[@]}"; do
    profile_home="$HERMES_HOME/profiles/$profile"
    if [ -d "$profile_home" ]; then
        copy_to "$profile_home/plugins/model-providers/$PLUGIN_NAME"
    else
        echo "    (übersprungen: kein Profil '$profile')"
    fi
done

echo "==> Registrierung prüfen"
PY="$HERMES_HOME/hermes-agent/venv/bin/python"
if [ ! -x "$PY" ]; then
    echo "    übersprungen (kein venv unter $PY)"
    exit 0
fi

check_home() {
    local label="$1" home="$2"
    HERMES_HOME="$home" "$PY" - "$label" <<'PYEOF'
import sys
label = sys.argv[1]
from providers import get_provider_profile
from hermes_cli.auth import PROVIDER_REGISTRY, get_external_process_provider_status
ok = get_provider_profile("claude-code-mcp") is not None and "claude-code-mcp" in PROVIDER_REGISTRY
status = get_external_process_provider_status("claude-code-mcp") or {}
print(f"    {label:<22} Profil+Registry={'ja' if ok else 'NEIN'} "
      f"CLI={status.get('resolved_command') or 'FEHLT'}")
sys.exit(0 if ok else 1)
PYEOF
}

cd "$HERMES_HOME/hermes-agent"
failed=0
check_home "root-home" "$HERMES_HOME" || failed=1
for profile in "${PROFILES[@]}"; do
    [ -d "$HERMES_HOME/profiles/$profile" ] || continue
    check_home "profil:$profile" "$HERMES_HOME/profiles/$profile" || failed=1
done

if [ "$failed" -ne 0 ]; then
    echo "    FEHLER: Registrierung unvollständig." >&2
    exit 1
fi
echo "==> Fertig. Profil umstellen mit: ./switch-profile.sh claude-dev"
