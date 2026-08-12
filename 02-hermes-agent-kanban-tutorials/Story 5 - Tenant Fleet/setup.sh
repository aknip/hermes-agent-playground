#!/usr/bin/env bash
#
# Story 5 - Tenant Fleet — Setup
# ================================
#
# Legt genau das an, was DIESE Story braucht:
#   1. das Board "kanban-story-5"
#   2. die Profile: account-manager
#   3. je Profil eine config.yaml, eine SOUL.md und eine Beschreibung
#   4. eine frische Arbeitskopie workspace/ aus seed/
#
# Idempotent — mehrfaches Ausfuehren ist unschaedlich.
# Rueckbau: ./teardown.sh
#
# Getestet mit: Hermes Agent v0.20.0 (2026.8.3) auf macOS
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-5"
PROFILE_NAMES=(account-manager)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "1/5  Vorbedingungen"
# ---------------------------------------------------------------------------
command -v hermes >/dev/null || { echo "FEHLER: 'hermes' nicht im PATH."; exit 1; }
command -v jq     >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)."; exit 1; }
hermes --version | head -1
echo "jq: $(command -v jq)"

# ---------------------------------------------------------------------------
say "2/5  Board '$BOARD'"
# ---------------------------------------------------------------------------
if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
    echo "  existiert bereits — uebersprungen"
else
    hermes kanban boards create "$BOARD" \
        --name "Story 5 - Tenant Fleet" \
        --description "Ein Profil, viele Mandanten, cron-getriebene Erzeugung" \
        --icon "5️⃣"
fi

# ---------------------------------------------------------------------------
say "3/5  Modell-Einstellungen aus der Root-Konfiguration uebernehmen"
# ---------------------------------------------------------------------------
# Ein Profil zaehlt fuer den Kanban-Dispatcher erst dann als Assignee, wenn in
# seinem Verzeichnis eine config.yaml liegt (kanban_db.list_profiles_on_disk).
# `hermes profile create` legt diese Datei nicht an — `hermes -p <p> config set`
# schon. Wir setzen alle vier Modell-Schluessel, damit das Profil denselben
# Provider benutzt wie deine Root-Installation und nicht einen aus den Defaults.
MODEL_KEYS=(model.default model.provider model.base_url model.api_mode)
declare -a ROOT_VALUES=()
for key in "${MODEL_KEYS[@]}"; do
    value="$(hermes config get "$key" 2>/dev/null | head -1 || true)"
    case "$value" in ""|"Config key not set"*) value="" ;; esac
    ROOT_VALUES+=("$value")
    printf '  %-18s = %s\n' "$key" "${value:-<nicht gesetzt>}"
done
[ -n "${ROOT_VALUES[0]}" ] || {
    echo "FEHLER: model.default ist in der Root-Konfiguration nicht gesetzt."
    echo "        Fuehre zuerst 'hermes setup' aus."
    exit 1
}

# ---------------------------------------------------------------------------
say "4/5  Profile"
# ---------------------------------------------------------------------------
for name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$HOME/.hermes/profiles/$name" ]; then
        echo "  $name — Verzeichnis existiert, 'profile create' uebersprungen"
    else
        hermes profile create "$name" --no-skills \
            --description "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null
        echo "  $name — angelegt"
    fi

    # Beschreibung immer nachziehen: der Kanban-Decomposer routet ueber sie.
    hermes profile describe "$name" \
        --text "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null

    # SOUL.md ist die Arbeitsanweisung des Spezialisten.
    cp "$HERE/profiles/$name/SOUL.md" "$HOME/.hermes/profiles/$name/SOUL.md"

    for i in "${!MODEL_KEYS[@]}"; do
        [ -n "${ROOT_VALUES[$i]}" ] || continue
        hermes -p "$name" config set "${MODEL_KEYS[$i]}" "${ROOT_VALUES[$i]}" >/dev/null
    done
    echo "      SOUL.md + Beschreibung + config.yaml geschrieben"

    # Profil-lokale Skills, falls diese Story welche mitbringt. Sie liegen in
    # ~/.hermes/profiles/<profil>/skills/<skill>/ und tauchen danach in
    # `hermes -p <profil> skills list` als 'local' auf.
    if [ -d "$HERE/skills" ]; then
        mkdir -p "$HOME/.hermes/profiles/$name/skills"
        for skill in "$HERE"/skills/*/; do
            [ -d "$skill" ] || continue
            # ${skill%/} — OHNE den Schraegstrich am Ende. `cp -R dir/ ziel/`
            # kopiert auf macOS den INHALT von dir nach ziel, nicht das
            # Verzeichnis selbst; bei zwei Skills ueberschreiben sie sich dann.
            rm -rf "$HOME/.hermes/profiles/$name/skills/$(basename "$skill")"
            cp -R "${skill%/}" "$HOME/.hermes/profiles/$name/skills/"
            echo "      Skill '$(basename "$skill")' installiert"
        done
    fi
done

# ---------------------------------------------------------------------------
say "5/5  Arbeitskopie und Verifikation"
# ---------------------------------------------------------------------------
"$HERE/reset-workspace.sh"
hermes kanban --board "$BOARD" assignees

missing=0
for name in "${PROFILE_NAMES[@]}"; do
    if ! hermes kanban --board "$BOARD" assignees | awk '{print $1, $2}' | grep -qx "${name} yes"; then
        echo "FEHLER: Profil '$name' ist nicht 'ON DISK' — fehlt die config.yaml?"
        missing=1
    fi
done

if [ "$missing" -eq 0 ]; then
    printf '\n\033[32m✓ Setup vollstaendig. Weiter in TUTORIAL.md.\033[0m\n'
else
    printf '\n\033[31m✗ Setup unvollstaendig — siehe Fehler oben.\033[0m\n'
    exit 1
fi
