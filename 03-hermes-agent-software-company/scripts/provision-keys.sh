#!/usr/bin/env bash
#
# ESF — Ein OpenRouter-Key je Profil
# ==================================
#
#   scripts/provision-keys.sh [--limit <USD>] [--list] [--remove]
#
# Legt über die OpenRouter-Provisioning-API je Profil einen eigenen API-Key mit
# hartem USD-Limit an.
#
# ⚠ BRAUCHT MAN NUR FÜR DAS LIMIT. Wer bereits Keys hat, ordnet sie mit
#   scripts/assign-keys.sh zu — das ist der durchgespielte Weg (verifiziert am
#   17.08.2026 am Verbrauchszähler, siehe VERIFIKATION.md).
#
# ⚠ EINE ANNAHME DIESES SKRIPTS WAR FALSCH und ist hier korrigiert: Die
#   Kostenzurechnung je Rolle hängt NICHT an der Provisioning-API.
#   `GET /api/v1/key` authentifiziert sich mit dem abgefragten Key selbst und
#   meldet dessen Verbrauch. Elf Profil-Keys genügen also — gleich woher sie
#   stammen. `scripts/assign-keys.sh --verbrauch` tut genau das, und
#   ledger-sync.sh schreibt daraus ledger/kosten-je-rolle.jsonl.
#
#   Was allein hier bleibt, ist der harte USD-Deckel: Ein Limit lässt sich über
#   die API nur mit einem Provisioning-Key setzen. Von Hand erzeugte Keys haben
#   `limit: null` — gemessen an allen elf Keys dieses Laufs.
#
# ⚠ NICHT VERIFIZIERT. Der Weg unten ist an der offiziellen OpenRouter-Doku
#   belegt, aber nicht ausgeführt: In dieser Umgebung liegt kein
#   OPENROUTER_PROVISIONING_KEY vor. Ohne ihn meldet das Skript das und bricht
#   NICHT ab.
#
# Zweite Wechselwirkung, die man kennen muss: Läuft ein Key gegen sein Limit,
# sehen die Fehlertexte nach Billing/Quota aus — exakt das Muster, auf das die
# Respawn-Sperre von Hermes anspringt. Die Karte bleibt dann still auf `ready`
# liegen, unsichtbar für `diagnostics`. Deshalb prüft monitor.sh beides
# zusammen: respawn_guarded-Ereignisse UND das Restguthaben jedes Keys.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
API="https://openrouter.ai/api/v1/keys"
LIMIT="5"
AKTION="create"

while [ $# -gt 0 ]; do
    case "$1" in
        --limit)  shift; LIMIT="${1:-5}" ;;
        --list)   AKTION="list" ;;
        --remove) AKTION="remove" ;;
        *) echo "Unbekannte Option '$1'"; exit 2 ;;
    esac
    shift
done

PROFILE_NAMES=(
    esf-chief-of-staff esf-market-scout esf-market-analyst esf-product-manager
    esf-architect esf-estimator esf-dev-a esf-dev-b esf-reviewer
    esf-qa-release esf-controller
)

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }

if [ -z "${OPENROUTER_PROVISIONING_KEY:-}" ]; then
    cat <<'EOF'

  OPENROUTER_PROVISIONING_KEY ist nicht gesetzt — übersprungen.

  Das ist kein Notstand. Was hier fehlt, ist genau eine Sache: der harte
  USD-Deckel je Rolle. Ein Limit lässt sich über die API nur mit einem
  Provisioning-Key setzen.

  NICHT betroffen ist die Kostenzurechnung je Rolle. Die braucht nur elf
  Keys, gleich woher:

    scripts/assign-keys.sh              vorhandene Keys zuordnen
    scripts/assign-keys.sh --verbrauch  Verbrauch je Rolle abfragen

  Läuft dagegen alles auf dem einen Root-Key, gibt es keine Aufteilung auf
  Rollen — und ledger-sync.sh schreibt lieber nichts als eine Vermutung.

  Deckel nachrüsten:
    1. Provisioning-Key erzeugen: https://openrouter.ai/settings/provisioning-keys
    2. export OPENROUTER_PROVISIONING_KEY=sk-or-v1-…
    3. scripts/provision-keys.sh --limit 5

EOF
    exit 0
fi

# ---------------------------------------------------------------------------
case "$AKTION" in
list)
    curl -fsS "$API" -H "Authorization: Bearer $OPENROUTER_PROVISIONING_KEY" \
      | jq -r '.data[] | select(.name | startswith("esf-"))
               | "  \(.name)  Limit \(.limit // "—") USD  genutzt \(.usage // 0) USD  \(.hash)"'
    exit 0 ;;

remove)
    echo "ESF-Keys entfernen"
    curl -fsS "$API" -H "Authorization: Bearer $OPENROUTER_PROVISIONING_KEY" \
      | jq -r '.data[] | select(.name | startswith("esf-")) | "\(.hash) \(.name)"' \
      | while read -r hash name; do
            curl -fsS -X DELETE "$API/$hash" \
                -H "Authorization: Bearer $OPENROUTER_PROVISIONING_KEY" >/dev/null \
                && echo "  $name entfernt"
        done
    exit 0 ;;
esac

# ---------------------------------------------------------------------------
printf '\nEin Key je Profil, Limit %s USD\n\n' "$LIMIT"
ZIEL="$ESF/workspace/openrouter-keys.env"
: > "$ZIEL"
chmod 600 "$ZIEL"

for name in "${PROFILE_NAMES[@]}"; do
    antwort="$(curl -fsS -X POST "$API" \
        -H "Authorization: Bearer $OPENROUTER_PROVISIONING_KEY" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg n "$name" --argjson l "$LIMIT" '{name:$n, limit:$l}')" 2>/dev/null || true)"

    schluessel="$(printf '%s' "$antwort" | jq -r '.key // empty')"
    if [ -z "$schluessel" ]; then
        printf '  \033[31m✗\033[0m %s — die API lieferte keinen Key\n' "$name"
        printf '%s\n' "$antwort" | head -3 | sed 's/^/      /'
        continue
    fi

    # Der Key gehört in die Profil-Konfiguration, damit dieses Profil ihn
    # benutzt — und nur dieses.
    hermes -p "$name" config set model.api_key "$schluessel" >/dev/null 2>&1 \
        || printf '      ⚠ config set model.api_key schlug fehl — Key steht in %s\n' "$ZIEL"

    hash="$(printf '%s' "$antwort" | jq -r '.data.hash // ""')"
    printf '%s_HASH=%s\n' "$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')" "$hash" >> "$ZIEL"
    printf '  \033[32m✓\033[0m %-22s Limit %s USD\n' "$name" "$LIMIT"
done

cat <<EOF

Die Key-Hashes stehen in workspace/openrouter-keys.env (chmod 600) — über sie
holt ledger-sync.sh die Tageswerte je Rolle.

Prüfen:   scripts/provision-keys.sh --list
Rückbau:  scripts/provision-keys.sh --remove
EOF
