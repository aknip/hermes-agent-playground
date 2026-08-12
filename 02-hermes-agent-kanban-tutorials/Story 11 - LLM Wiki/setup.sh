#!/usr/bin/env bash
#
# Story 11 - LLM Wiki — Setup
# ===========================
#
# Legt genau das an, was DIESE Story braucht:
#   1. das Board "kanban-story-11"
#   2. die fuenf Profile der Flotte
#   3. je Profil eine config.yaml, eine SOUL.md und eine Beschreibung
#   4. die profil-lokalen Skills (nur dort, wo sie hingehoeren)
#   5. eine frische Arbeitskopie workspace/ aus seed/ — inklusive
#      git init auf workspace/wiki/, denn die Wissensbasis IST ein Repository
#
# Idempotent — mehrfaches Ausfuehren ist unschaedlich.
# Rueckbau: ./teardown.sh
#
# Getestet mit: Hermes Agent v0.20.0 (2026.8.3) auf macOS
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-11"
PROFILE_NAMES=(kb-scout kb-orchestrator kb-researcher kb-ingestor kb-linter)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "1/5  Vorbedingungen"
# ---------------------------------------------------------------------------
command -v hermes >/dev/null || { echo "FEHLER: 'hermes' nicht im PATH."; exit 1; }
command -v jq     >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)."; exit 1; }
command -v git    >/dev/null || { echo "FEHLER: 'git' fehlt — diese Story braucht es."; exit 1; }
command -v python3 >/dev/null || { echo "FEHLER: 'python3' fehlt."; exit 1; }
hermes --version | head -1
echo "git:     $(git --version)"
echo "python3: $(python3 --version)"

# ⚠ Die Profilnamen dieser Story tragen alle das Praefix 'kb-'. Profile liegen
# global in ~/.hermes/profiles/ — wenn du dort schon eines mit diesem Praefix
# hast, wuerde teardown.sh es mit entfernen. Deshalb hier die Warnung.
fremde=""
for name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$HOME/.hermes/profiles/$name" ] && [ ! -f "$HOME/.hermes/profiles/$name/.story11" ]; then
        fremde="$fremde $name"
    fi
done
if [ -n "$fremde" ]; then
    printf '\n\033[33m⚠ Diese Profile existieren bereits und wurden nicht von dieser Story angelegt:\033[0m\n'
    printf '   %s\n' "$fremde"
    printf '  setup.sh nutzt sie weiter und ueberschreibt SOUL.md und Beschreibung.\n'
    printf '  ./teardown.sh --keep-profiles laesst sie danach in Ruhe.\n'
    printf '  Fortfahren? [j/N] '
    read -r answer
    case "$answer" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
fi

# ---------------------------------------------------------------------------
say "2/5  Board '$BOARD'"
# ---------------------------------------------------------------------------
if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
    echo "  existiert bereits — uebersprungen"
else
    hermes kanban boards create "$BOARD" \
        --name "Story 11 - LLM Wiki" \
        --description "Wissensbasis-Pipeline mit zwei menschlichen Toren und deterministischem Linter" \
        --icon "📚"
fi

# ---------------------------------------------------------------------------
say "3/5  Modell-Einstellungen aus der Root-Konfiguration uebernehmen"
# ---------------------------------------------------------------------------
# Ein Profil zaehlt fuer den Kanban-Dispatcher erst dann als Assignee, wenn in
# seinem Verzeichnis eine config.yaml liegt (kanban_db.list_profiles_on_disk).
# `hermes profile create` legt diese Datei nicht an — `hermes -p <p> config set`
# schon. Alle vier Schluessel, damit die Profile denselben Provider benutzen wie
# deine Root-Installation und nicht einen aus den eingebauten Defaults.
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
# Die Skills liegen PRO PROFIL unter skills/<profilname>/<skillname>/.
# Der Orchestrator bekommt den ganzen Ablauf, der Rechercheur bekommt ihn
# NICHT — er soll seine Bahn bearbeiten, nicht mitdenken, was danach kommt.
for name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$HOME/.hermes/profiles/$name" ]; then
        echo "  $name — Verzeichnis existiert, 'profile create' uebersprungen"
    else
        hermes profile create "$name" --no-skills \
            --description "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null
        echo "  $name — angelegt"
    fi
    touch "$HOME/.hermes/profiles/$name/.story11"

    # Beschreibung immer nachziehen: der Kanban-Decomposer routet ueber sie.
    hermes profile describe "$name" \
        --text "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null

    cp "$HERE/profiles/$name/SOUL.md" "$HOME/.hermes/profiles/$name/SOUL.md"

    for i in "${!MODEL_KEYS[@]}"; do
        [ -n "${ROOT_VALUES[$i]}" ] || continue
        hermes -p "$name" config set "${MODEL_KEYS[$i]}" "${ROOT_VALUES[$i]}" >/dev/null
    done
    echo "      SOUL.md + Beschreibung + config.yaml geschrieben"

    if [ -d "$HERE/skills/$name" ]; then
        mkdir -p "$HOME/.hermes/profiles/$name/skills"
        for skill in "$HERE/skills/$name"/*/; do
            [ -d "$skill" ] || continue
            # ${skill%/} — OHNE Schraegstrich am Ende: `cp -R dir/ ziel/` kopiert
            # auf macOS den INHALT von dir nach ziel, nicht das Verzeichnis.
            rm -rf "$HOME/.hermes/profiles/$name/skills/$(basename "$skill")"
            cp -R "${skill%/}" "$HOME/.hermes/profiles/$name/skills/"
            echo "      Skill '$(basename "$skill")' installiert"
        done
    fi
done

# ---------------------------------------------------------------------------
say "5/5  Arbeitskopie, Git-Repository und Verifikation"
# ---------------------------------------------------------------------------
"$HERE/reset-workspace.sh"
echo
hermes kanban --board "$BOARD" assignees

missing=0
for name in "${PROFILE_NAMES[@]}"; do
    if ! hermes kanban --board "$BOARD" assignees | awk '{print $1, $2}' | grep -qx "${name} yes"; then
        echo "FEHLER: Profil '$name' ist nicht 'ON DISK' — fehlt die config.yaml?"
        missing=1
    fi
done

# Der modellfreie Test dieser Story: der Linter muss auf dem Seed genau
# 5 ERROR und 1 STALE finden. Stimmt das nicht, ist seed/ verstellt.
say "Modellfreier Test: der Linter auf dem Ausgangszustand"
# Exit-Code des Linters, nicht der von sed: in einer Pipeline liefert $? den
# Status des LETZTEN Glieds. Deshalb erst in eine Variable, dann anzeigen.
set +e
# --today: siehe reset-workspace.sh — ohne festes Bezugsdatum wandern mit der
# Zeit weitere Seed-Seiten ueber die Freshness-Grenze und der Test wird unscharf.
lint_out="$(python3 "$HERE/workspace/bin/kb_lint.py" "$HERE/workspace/wiki" \
                    --today 2026-08-11 2>&1)"
lint_rc=$?
set -e
printf '%s\n' "$lint_out" | tail -6 | sed 's/^/  /'
if [ "$lint_rc" -ne 1 ]; then
    echo "FEHLER: kb_lint.py sollte auf dem Seed mit Exit 1 enden (war: $lint_rc)."
    missing=1
fi

if [ "$missing" -eq 0 ]; then
    printf '\n\033[32m✓ Setup vollstaendig. Weiter in TUTORIAL.md.\033[0m\n'
else
    printf '\n\033[31m✗ Setup unvollstaendig — siehe Fehler oben.\033[0m\n'
    exit 1
fi
