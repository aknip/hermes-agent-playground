#!/usr/bin/env bash
# Baut das Plugin zurück: Profil auf die Sicherung, Plugin-Kopien weg.
#
#   ./uninstall.sh                 # Profil claude-dev
#   ./uninstall.sh claude-dev foo  # genannte Profile
#   ./uninstall.sh --keep-profile  # nur die Plugin-Dateien entfernen (config.yaml bleibt)
#
# Rührt NICHTS an, was nicht von install.sh/switch-profile.sh stammt.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="claude-code-mcp"

KEEP_PROFILE=0
PROFILES=()
for arg in "$@"; do
    case "$arg" in
        --keep-profile) KEEP_PROFILE=1 ;;
        *) PROFILES+=("$arg") ;;
    esac
done
[ ${#PROFILES[@]} -gt 0 ] || PROFILES=("claude-dev")

if [ "$KEEP_PROFILE" -eq 0 ]; then
    echo "==> Profile zurückspielen"
    for profile in "${PROFILES[@]}"; do
        if [ -d "$HERMES_HOME/profiles/$profile" ]; then
            "$HERE/switch-profile.sh" "$profile" --restore || \
                echo "    WARNUNG: '$profile' nicht zurückgespielt (keine Sicherung?)"
        fi
    done

    # Der providers:-Block aus `install.sh --with-model-picker`. Eine zurueckgespielte
    # Sicherung ist meistens aelter als der Block und traegt ihn deshalb gar nicht mehr;
    # ohne Sicherung bliebe er aber stehen und wuerde in der Modellauswahl vier Modelle
    # eines dann entfernten Providers anbieten. `config unset` endet mit 1, wenn der
    # Schluessel fehlt — das ist hier der Normalfall, kein Fehler.
    #
    # Seit 15.09.2026 schreibt install.sh den Block standardmaessig und auch ins
    # Root-Home — der Rueckbau muss dort ebenfalls greifen, sonst bleibt im
    # Auswahlfeld der Desktop-App ein Provider stehen, dessen Plugin gerade
    # geloescht wurde.
    echo "==> Modellauswahl entfernen (providers:-Block)"
    unset_picker_block() {
        local label="$1"; shift
        local -a H=("$@")
        if [ "${DRY_RUN:-0}" = "1" ]; then
            echo "    [dry-run] ${H[*]} config unset providers.$PLUGIN_NAME"
        elif "${H[@]}" config unset "providers.$PLUGIN_NAME" >/dev/null 2>&1; then
            echo "    $label — entfernt"
        else
            echo "    $label — war nicht eingetragen"
        fi
    }
    unset_picker_block "root-home" hermes
    for profile in "${PROFILES[@]}"; do
        [ -d "$HERMES_HOME/profiles/$profile" ] || continue
        unset_picker_block "profil:$profile" hermes -p "$profile"
    done
fi

echo "==> Plugin-Kopien entfernen"
# Zielliste explizit aufbauen statt per Parameter-Expansion umzuschreiben: ein
# ``rm -rf`` verdient einen Pfad, den man beim Lesen ganz sieht.
TARGETS=("$HERMES_HOME/plugins/model-providers/$PLUGIN_NAME")
for profile in "${PROFILES[@]}"; do
    TARGETS+=("$HERMES_HOME/profiles/$profile/plugins/model-providers/$PLUGIN_NAME")
done

for dir in "${TARGETS[@]}"; do
    # Gürtel und Hosenträger: nur löschen, was auf den erwarteten Pfad endet.
    case "$dir" in
        */plugins/model-providers/"$PLUGIN_NAME") ;;
        *) echo "    übersprungen (unerwarteter Pfad): $dir" >&2; continue ;;
    esac
    if [ -d "$dir" ]; then
        [ "${DRY_RUN:-0}" = "1" ] && echo "    [dry-run] rm -rf $dir" || {
            rm -rf "$dir"; echo "    entfernt: $dir"; }
    fi
done

# Übrig gebliebene Rendezvous-Verzeichnisse eines abgestürzten Laufs.
removed=0
for d in /tmp/hcc-*/; do
    [ -d "$d" ] || continue          # kein Treffer -> Glob bleibt literal
    [ "${DRY_RUN:-0}" = "1" ] && { echo "    [dry-run] rm -rf $d"; continue; }
    rm -rf "$d" && removed=$((removed + 1))
done
[ "$removed" -gt 0 ] && echo "    $removed verwaiste Rendezvous-Ordner aufgeräumt"

echo "==> Fertig."
