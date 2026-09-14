#!/usr/bin/env bash
# Leitet die Plugin-Kopie aus dem Repo-Master nach ~/.hermes/ ab.
#
#   ./install.sh                      # Root-Home + Profil claude-dev
#   ./install.sh claude-dev foo       # Root-Home + genannte Profile
#   ./install.sh --with-model-picker  # zusaetzlich den providers:-Block schreiben
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

WITH_PICKER=0
PROFILES=()
for arg in "$@"; do
    case "$arg" in
        --with-model-picker) WITH_PICKER=1 ;;
        -*) echo "FEHLER: unbekannte Option: $arg" >&2; exit 1 ;;
        *) PROFILES+=("$arg") ;;
    esac
done
[ ${#PROFILES[@]} -gt 0 ] || PROFILES=("claude-dev")

# Modellauswahl fuer die Desktop-App. Ohne diesen Block bietet das Auswahlfeld nichts an:
# ein Plugin-Provider mit auth_type="external_process" wird von der Auto-Erweiterung der
# kanonischen Liste uebersprungen (hermes_cli/models_catalog_static.py:361-363) und der
# generische Katalogabruf bedient nur auth_type == "api_key" (hermes_cli/models.py:1390) —
# `fallback_models` im Plugin erreicht den Auswaehler also nie.
#
# Der Block ist zugleich die einzige Stelle, an der ein Kontextfenster einen
# /model-Wechsel zur Laufzeit ueberlebt: model.context_length wird dabei geloescht
# (agent/agent_runtime_helpers.py:1963-1964) und danach aus genau diesen Eintraegen neu
# hergeleitet (:2017 ueber hermes_cli/config_providers.py:312). Gemessen in Lauf 13.
#
# Ein Fenster bekommen nur die [1m]-Varianten: dort ist der Wert belegt. haiku/fable
# stehen ohne context_length in der Liste (leerer Eintrag `{}`) — sie tauchen damit in
# der Auswahl auf, und Hermes bleibt bei seiner eigenen Aufloesung. Ein erfundener Wert
# waere hier schaedlich: ohne Eintrag schaetzt Hermes 256000, ein kleinerer Wert wuerde
# das Fenster dieser Modelle also still verkleinern. Unter 64000 nimmt Hermes nichts an.
PICKER_MODELS=("sonnet[1m]:1000000" "opus[1m]:1000000" "haiku:" "fable:")

write_picker_block() {
    local profile="$1"
    local current
    current="$(hermes -p "$profile" config get model.provider 2>/dev/null | tr -d "[:space:]")"
    if [ "$current" != "$PLUGIN_NAME" ]; then
        echo "    $profile — uebersprungen (model.provider=${current:-leer})"
        return 0
    fi
    hermes -p "$profile" config set "providers.$PLUGIN_NAME.name" "Claude Code CLI (MCP)" >/dev/null
    hermes -p "$profile" config set "providers.$PLUGIN_NAME.base_url" "claude-code://cli" >/dev/null
    hermes -p "$profile" config set "providers.$PLUGIN_NAME.api_mode" "chat_completions" >/dev/null
    for entry in "${PICKER_MODELS[@]}"; do
        local model="${entry%%:*}" ctx="${entry##*:}"
        if [ -n "$ctx" ]; then
            hermes -p "$profile" config set \
                "providers.$PLUGIN_NAME.models.$model.context_length" "$ctx" >/dev/null
        else
            # Leere Abbildung: Eintrag in der Auswahl, kein Fenster-Uebersteuern.
            hermes -p "$profile" config set "providers.$PLUGIN_NAME.models.$model" '{}' >/dev/null
        fi
    done
    echo "    $profile — ${#PICKER_MODELS[@]} Modelle eingetragen"
}

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

if [ "$WITH_PICKER" -eq 1 ]; then
    echo "==> Modellauswahl eintragen (providers:-Block)"
    for profile in "${PROFILES[@]}"; do
        if [ -d "$HERMES_HOME/profiles/$profile" ]; then
            write_picker_block "$profile"
        else
            echo "    (übersprungen: kein Profil '$profile')"
        fi
    done
fi

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
