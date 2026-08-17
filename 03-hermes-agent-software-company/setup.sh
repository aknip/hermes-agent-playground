#!/usr/bin/env bash
#
# ESF — Enterprise Software Factory: Setup (Phase 0, Gerüst)
# ==========================================================
#
# Legt genau das an, was die ESF zum Laufen braucht:
#   1. das Board "sw-company"
#   2. die elf Profile mit esf--Präfix und Markerdatei
#   3. je Profil config.yaml, SOUL.md und Beschreibung
#   4. die profil-lokalen Superpowers-Skills
#   5. die Arbeitskopie des Firmen-Vaults aus seed/
#   6. modellfreie Selbsttests: Vault-Linter, Merge-Riegel, ON DISK
#
# Idempotent — mehrfaches Ausführen ist unschädlich.
# Rückbau: ./teardown.sh
#
# Getestet mit: Hermes Agent v0.20.0 (2026.8.3) auf macOS
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
MARKER=".esf"

PROFILE_NAMES=(
    esf-chief-of-staff esf-market-scout esf-market-analyst esf-product-manager
    esf-architect esf-estimator esf-dev-a esf-dev-b esf-reviewer
    esf-qa-release esf-controller
)

# --- Modell-Tiers ----------------------------------------------------------
# Das Konzept unterscheidet drei Tiers. In diesem Lauf zeigen alle drei auf
# denselben Slug — die Struktur bleibt trotzdem stehen, damit ein späterer Lauf
# sie differenzieren kann, ohne das Skript umzubauen.
#
# Überschreibbar von aussen:  ESF_MODELL_HOCH=… ./setup.sh
MODELL_HOCH="${ESF_MODELL_HOCH:-deepseek/deepseek-v4-flash-0731}"
MODELL_MITTEL="${ESF_MODELL_MITTEL:-deepseek/deepseek-v4-flash-0731}"
MODELL_GUENSTIG="${ESF_MODELL_GUENSTIG:-deepseek/deepseek-v4-flash-0731}"

tier_von() {
    case "$1" in
        esf-market-scout)                                echo "$MODELL_GUENSTIG" ;;
        esf-estimator|esf-qa-release|esf-controller)     echo "$MODELL_MITTEL" ;;
        *)                                               echo "$MODELL_HOCH" ;;
    esac
}

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "1/7  Vorbedingungen"
# ---------------------------------------------------------------------------
for werkzeug in hermes jq git python3 pnpm; do
    command -v "$werkzeug" >/dev/null || { echo "FEHLER: '$werkzeug' fehlt."; exit 1; }
done
hermes --version | head -1
echo "git:     $(git --version)"
echo "python3: $(python3 --version)"

PRODUKT_REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$HERE/seed/company/cadence.yaml" | head -1)"
[ -d "$PRODUKT_REPO/.git" ] || {
    echo "FEHLER: Das Produkt-Repo '$PRODUKT_REPO' ist kein Git-Repository."
    echo "        Pfad steht in seed/company/cadence.yaml unter produkt.repo."
    exit 1
}
echo "Produkt: $PRODUKT_REPO ($(git -C "$PRODUKT_REPO" rev-parse --short HEAD))"

# ⚠ Profile liegen global in ~/.hermes/profiles/. Das esf--Präfix hält den
# Namensraum frei, aber wenn dort schon ein esf--Profil ohne unsere Markerdatei
# liegt, gehört es jemand anderem.
fremde=""
for name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$HOME/.hermes/profiles/$name" ] && [ ! -f "$HOME/.hermes/profiles/$name/$MARKER" ]; then
        fremde="$fremde $name"
    fi
done
if [ -n "$fremde" ]; then
    printf '\n\033[33m⚠ Diese Profile existieren bereits und wurden nicht von der ESF angelegt:\033[0m\n'
    printf '   %s\n' "$fremde"
    printf '  setup.sh nutzt sie weiter und überschreibt SOUL.md und Beschreibung.\n'
    printf '  ./teardown.sh --keep-profiles lässt sie danach in Ruhe.\n'
    printf '  Fortfahren? [j/N] '
    read -r antwort
    case "$antwort" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
fi

# ---------------------------------------------------------------------------
say "2/7  Board '$BOARD'"
# ---------------------------------------------------------------------------
BOARD_NAME="ESF — Enterprise Software Factory"
if hermes kanban boards list 2>/dev/null | grep -qE "^[● ] *${BOARD} "; then
    echo "  existiert bereits"
    # Den Anzeigenamen trotzdem nachziehen. Nach einem ./teardown.sh legt ein
    # laufender Gateway-Daemon das Board binnen Sekunden als leere Hülle neu an
    # — mit einem aus dem Slug abgeleiteten Namen ("Sw Company"). Ohne dieses
    # Nachziehen verliert die ESF bei jedem Rundlauf ihren Boardnamen.
    hermes kanban boards rename "$BOARD" "$BOARD_NAME" >/dev/null 2>&1 \
        && echo "  Anzeigename auf '$BOARD_NAME' gesetzt"
else
    hermes kanban boards create "$BOARD" \
        --name "$BOARD_NAME" \
        --description "Autonome Software-Organisation: Markt, Roadmap, Sprints, Releases, Qualität" \
        --icon "🏭"
fi

# ---------------------------------------------------------------------------
say "3/7  Provider-Einstellungen"
# ---------------------------------------------------------------------------
# Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
# Verzeichnis eine config.yaml liegt. `hermes profile create` legt sie NICHT
# an — `hermes -p <p> config set` schon. Ohne sie bleiben Karten für immer
# stumm auf `ready`, ohne Fehlermeldung.
#
# Provider, Base-URL und API-Modus kommen aus der Root-Konfiguration; nur
# model.default setzt das Tier je Rolle.
# Zwei parallele indizierte Arrays statt eines assoziativen: Das Bash auf macOS
# ist 3.2 und kennt `declare -A` nicht.
PROVIDER_SCHLUESSEL=(model.provider model.base_url model.api_mode)
PROVIDER_WERTE=()
for key in "${PROVIDER_SCHLUESSEL[@]}"; do
    wert="$(hermes config get "$key" 2>/dev/null | head -1 || true)"
    case "$wert" in ""|"Config key not set"*) wert="" ;; esac
    PROVIDER_WERTE+=("$wert")
    printf '  %-18s = %s\n' "$key" "${wert:-<nicht gesetzt>}"
done
[ -n "${PROVIDER_WERTE[0]}" ] || {
    echo "FEHLER: model.provider ist in der Root-Konfiguration nicht gesetzt."
    echo "        Führe zuerst 'hermes setup' aus."
    exit 1
}
printf '  %-18s = %s / %s / %s\n' "Tiers (h/m/g)" "$MODELL_HOCH" "$MODELL_MITTEL" "$MODELL_GUENSTIG"

# ---------------------------------------------------------------------------
say "4/7  Profile"
# ---------------------------------------------------------------------------
for name in "${PROFILE_NAMES[@]}"; do
    if [ -d "$HOME/.hermes/profiles/$name" ]; then
        echo "  $name — Verzeichnis existiert, 'profile create' übersprungen"
    else
        hermes profile create "$name" --no-skills \
            --description "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null
        echo "  $name — angelegt"
    fi
    touch "$HOME/.hermes/profiles/$name/$MARKER"

    # Beschreibung immer nachziehen: der Decomposer routet über sie.
    hermes profile describe "$name" \
        --text "$(cat "$HERE/profiles/$name/description.txt")" >/dev/null
    cp "$HERE/profiles/$name/SOUL.md" "$HOME/.hermes/profiles/$name/SOUL.md"

    for i in "${!PROVIDER_SCHLUESSEL[@]}"; do
        [ -n "${PROVIDER_WERTE[$i]}" ] || continue
        hermes -p "$name" config set "${PROVIDER_SCHLUESSEL[$i]}" "${PROVIDER_WERTE[$i]}" >/dev/null
    done
    modell="$(tier_von "$name")"
    hermes -p "$name" config set model.default "$modell" >/dev/null
    printf '      SOUL + Beschreibung + config.yaml   Modell: %s\n' "$modell"

    # Skills PRO PROFIL. Wer alles weiss, ist keine Flotte, sondern elf Kopien
    # desselben Agenten.
    if [ -d "$HERE/skills/$name" ]; then
        mkdir -p "$HOME/.hermes/profiles/$name/skills"
        anzahl=0
        for skill in "$HERE/skills/$name"/*/; do
            [ -d "$skill" ] || continue
            # ${skill%/} OHNE Schrägstrich: `cp -R dir/ ziel/` kopiert auf macOS
            # den INHALT von dir nach ziel, nicht das Verzeichnis selbst.
            rm -rf "$HOME/.hermes/profiles/$name/skills/$(basename "$skill")"
            cp -R "${skill%/}" "$HOME/.hermes/profiles/$name/skills/"
            anzahl=$((anzahl + 1))
        done
        [ -f "$HERE/skills/$name/HERMES-TOOLS.md" ] && \
            cp "$HERE/skills/$name/HERMES-TOOLS.md" "$HOME/.hermes/profiles/$name/skills/"
        printf '      %s Superpowers-Skill(s) + Tool-Mapping\n' "$anzahl"
    fi
done

# ---------------------------------------------------------------------------
say "5/7  Ein OpenRouter-Key je Profil"
# ---------------------------------------------------------------------------
# Muss NACH den Profilen laufen: `hermes -p <p> config set` braucht das
# Profilverzeichnis. Und muss bei JEDEM setup.sh laufen, denn ./teardown.sh
# löscht die Profilverzeichnisse mitsamt ihrer .env.
#
# Fehlt die Schlüsseldatei, ist das kein Abbruchgrund — die ESF läuft dann auf
# dem einen Root-Key. Es ist aber auch kein Nebensatz: Ohne Key je Rolle gibt
# es keine Kostenzurechnung, und der Rückfall passiert lautlos. Deshalb sagt
# assign-keys.sh in dem Fall laut, was fehlt, und der Selbsttest unten warnt
# ein zweites Mal.
set +e
"$HERE/scripts/assign-keys.sh" 2>&1 | sed 's/^/  /'
keys_rc=${PIPESTATUS[0]}
set -e

# ---------------------------------------------------------------------------
say "6/7  Firmen-Vault und Produkt-Repo"
# ---------------------------------------------------------------------------
"$HERE/reset-workspace.sh"

# Der schlanke Pre-Commit-Hook im Produkt-Repo. Ohne ihn scheitert jeder
# Worker-Commit an Kaneos eigenem Hook (biome über alles + voller Build, auf
# dem Ausgangs-Commit bereits rot) und lernt dabei --no-verify.
# ./teardown.sh baut ihn wieder zurück.
echo
"$HERE/scripts/install-repo-hooks.sh" | sed 's/^/  /'

# ---------------------------------------------------------------------------
say "7/7  Modellfreie Selbsttests"
# ---------------------------------------------------------------------------
fehler=0

# (a) Dispatchbarkeit — der teuerste Fehler dieser Bauweise, wenn er fehlt.
echo
hermes kanban --board "$BOARD" assignees
for name in "${PROFILE_NAMES[@]}"; do
    if ! hermes kanban --board "$BOARD" assignees | awk '{print $1, $2}' | grep -qx "${name} yes"; then
        echo "FEHLER: Profil '$name' ist nicht 'ON DISK' — fehlt die config.yaml?"
        fehler=1
    fi
done

# (b) Der Vault-Linter muss auf der Fixture GENAU 9 ERROR finden. Weniger heisst,
#     dass eine Regel nicht mehr greift; mehr heisst, dass seed/ verstellt ist.
say "Vault-Linter gegen die Fixture"
set +e
lint_aus="$(python3 "$HERE/scripts/vault-lint.py" "$HERE/workspace/lint-selbsttest" 2>&1)"
lint_rc=$?
set -e
printf '%s\n' "$lint_aus" | tail -2 | sed 's/^/  /'
gefunden="$(printf '%s' "$lint_aus" | grep -c '^ERROR' || true)"
if [ "$lint_rc" -ne 1 ] || [ "$gefunden" -ne 9 ]; then
    echo "FEHLER: erwartet 9 ERROR und Exit 1, bekommen $gefunden ERROR und Exit $lint_rc."
    fehler=1
else
    echo "  9 ERROR, Exit 1 — wie erwartet"
fi

# (c) Der Merge-Riegel muss einen nicht existierenden Branch verweigern.
say "Merge-Riegel: Verweigerungsfall"
set +e
riegel_aus="$("$HERE/scripts/merge-riegel.sh" esf/gibt-es-nicht --dry-run 2>&1)"
riegel_rc=$?
set -e
if [ "$riegel_rc" -eq 1 ] && printf '%s' "$riegel_aus" | grep -q "VERWEIGERT"; then
    echo "  verweigert mit Exit 1 — wie erwartet"
else
    echo "FEHLER: der Riegel hätte verweigern müssen (Exit $riegel_rc)."
    printf '%s\n' "$riegel_aus" | tail -5 | sed 's/^/    /'
    fehler=1
fi

# (d) Ein Key je Rolle — und elf VERSCHIEDENE. Der Rückfall auf den Root-Key
#     ist die gefährlichere Hälfte, weil nichts daran auffällt: Das Board
#     läuft, die Karten werden fertig, nur die Kostenzurechnung ist erfunden.
say "Ein Key je Profil"
set +e
"$HERE/scripts/assign-keys.sh" --pruefen 2>&1 | tail -13
keys_pruefung=${PIPESTATUS[0]}
set -e
if [ "$keys_pruefung" -ne 0 ]; then
    if [ "${keys_rc:-1}" -eq 0 ]; then
        echo "FEHLER: Keys wurden zugeordnet, aber die Prüfung ist rot."
        fehler=1
    else
        printf '\033[33m  ⚠ Die ESF läuft auf dem Root-Key. Das ist erlaubt, aber\033[0m\n'
        printf '\033[33m    ledger-sync.sh kann dann keine Kosten je Rolle ausweisen.\033[0m\n'
    fi
fi

if [ "$fehler" -eq 0 ]; then
    cat <<EOF

$(printf '\033[32m✓ Phase 0: Gerüst steht.\033[0m')

  Board:    $BOARD  (11 Profile, alle dispatchbar)
  Vault:    workspace/company/  (Git-Repo, Linter grün)
  Produkt:  $PRODUKT_REPO

Weiter:
  ./create-onboarding.sh     Phase 1 — den Analysegraphen anlegen
  ./pump.sh                  den Dispatcher takten
  ./gate.sh                  offene CEO-Gates anzeigen und beantworten
EOF
else
    printf '\n\033[31m✗ Setup unvollständig — siehe Fehler oben.\033[0m\n'
    exit 1
fi
