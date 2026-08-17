#!/usr/bin/env bash
#
# ESF — Abschluss-Check Phase 1 (Onboarding)
# ==========================================
#
#   scripts/check-onboarding.sh
#
# Der deterministische Nachweis aus Kapitel 12: Phase 1 ist fertig, wenn
#
#   1. alle Onboarding-Karten `done` sind,
#   2. analysis/ die vier Artefakte enthält — codebase, product, market, journeys,
#   3. die E2E-Suite jede im Katalog gelistete Kern-Journey abdeckt und grün läuft,
#   4. die Roadmap-Gate-Karte mit vollständiger Vorlage auf den CEO wartet
#      (bzw. bereits beantwortet ist).
#
# Kein Modell beurteilt das. Ein grüner Check schliesst die Phase ab, ein roter
# benennt, was fehlt.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }

printf '\n\033[1mAbschluss-Check Phase 1 — Onboarding\033[0m\n'
printf '%.0s─' $(seq 1 70); echo

liste="$(k list --json 2>/dev/null || echo '[]')"

# --- 1. Karten -------------------------------------------------------------
echo
echo "1. Onboarding-Karten"
gesamt="$(printf '%s' "$liste" | jq '[.[] | select(.title | startswith("Onboarding"))] | length')"
fertig="$(printf '%s' "$liste" | jq '[.[] | select((.title | startswith("Onboarding")) and .status=="done")] | length')"
if [ "$gesamt" -eq 0 ]; then
    nein "Es gibt keine Onboarding-Karten. Erst ./create-onboarding.sh"
elif [ "$gesamt" -eq "$fertig" ]; then
    ok "$fertig von $gesamt fertig"
else
    nein "$fertig von $gesamt fertig"
    printf '%s' "$liste" | jq -r '.[] | select((.title | startswith("Onboarding")) and .status!="done")
        | "      \(.id)  [\(.status)]  \(.title)"'
fi

# --- 2. Die vier Analyse-Artefakte -----------------------------------------
echo
echo "2. Analyse-Artefakte im Vault"
for datei in codebase.html product.html market.html journeys.html; do
    pfad="$VAULT/analysis/$datei"
    if [ ! -f "$pfad" ]; then
        nein "analysis/$datei fehlt"
    elif [ "$(wc -c < "$pfad")" -lt 500 ]; then
        nein "analysis/$datei ist mit $(wc -c < "$pfad") Byte zu dünn für einen Bericht"
    else
        ok "analysis/$datei ($(wc -c < "$pfad" | tr -d ' ') Byte)"
    fi
done

echo
echo "   Vault-Linter"
if python3 "$ESF/scripts/vault-lint.py" "$VAULT" > /tmp/esf-check-lint.$$ 2>&1; then
    ok "sauber"
else
    nein "beanstandet:"
    grep '^ERROR' /tmp/esf-check-lint.$$ | head -8 | sed 's/^/      /'
fi
rm -f /tmp/esf-check-lint.$$

# --- 3. E2E-Suite ----------------------------------------------------------
echo
echo "3. E2E-Suite"
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_DIR="$(sed -n 's/^[[:space:]]*e2e_verzeichnis:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"

specs=0
if [ -d "$REPO/$E2E_DIR" ]; then
    specs="$(find "$REPO/$E2E_DIR" -name '*.spec.ts' | wc -l | tr -d ' ')"
    ok "$specs Spec-Datei(en) unter $E2E_DIR"
else
    nein "$E2E_DIR gibt es im Produkt-Repo nicht"
fi

# Jede im Katalog genannte Spec muss existieren. Ein Katalog, der auf nichts
# zeigt, ist die häufigste Form von Scheinvollständigkeit.
if [ -f "$VAULT/analysis/journeys.html" ]; then
    genannte="$(grep -oE '[a-z0-9-]+\.spec\.ts' "$VAULT/analysis/journeys.html" | sort -u)"
    if [ -z "$genannte" ]; then
        nein "journeys.html nennt keine einzige Spec-Datei"
    else
        fehlend=""
        for spec in $genannte; do
            [ -f "$REPO/$E2E_DIR/$spec" ] || fehlend="$fehlend $spec"
        done
        if [ -n "$fehlend" ]; then
            nein "journeys.html nennt Specs, die es nicht gibt:$fehlend"
        else
            ok "alle $(printf '%s\n' "$genannte" | wc -l | tr -d ' ') im Katalog genannten Specs existieren"
        fi
    fi
fi

echo "   Lauf"
if [ -d "$REPO" ] && [ "$specs" -gt 0 ]; then
    ( cd "$REPO" && eval "$E2E_VORBED" ) >/dev/null 2>&1 || true
    if ( cd "$REPO" && eval "$E2E_BEFEHL" ) > /tmp/esf-check-e2e.$$ 2>&1; then
        ok "grün — $(grep -oE '[0-9]+ passed' /tmp/esf-check-e2e.$$ | tail -1)"
    else
        nein "rot"
        tail -12 /tmp/esf-check-e2e.$$ | sed 's/^/      /'
    fi
    rm -f /tmp/esf-check-e2e.$$
else
    nein "nicht ausführbar (kein Repo oder keine Specs)"
fi

# --- 4. Das Roadmap-Gate ---------------------------------------------------
echo
echo "4. Roadmap-Gate"
gate="$(printf '%s' "$liste" | jq -c '[.[] | select(.title | startswith("GATE Roadmap"))] | last // null')"
if [ "$gate" = "null" ]; then
    nein "Es gibt keine Roadmap-Gate-Karte"
else
    gid="$(printf '%s' "$gate" | jq -r '.id')"
    gstatus="$(printf '%s' "$gate" | jq -r '.status')"
    grund="$(k show "$gid" --json 2>/dev/null \
             | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // ""')"
    zeilen="$(printf '%s' "$grund" | grep -c . || true)"

    case "$gstatus" in
        blocked)
            if [ "$zeilen" -ge 6 ]; then
                ok "Karte $gid wartet mit einer Vorlage aus $zeilen Zeilen auf den CEO"
            else
                nein "Karte $gid ist blockiert, aber die Vorlage hat nur $zeilen Zeilen"
                info "Maßstab: man kann entscheiden, ohne eine Datei zu öffnen."
            fi ;;
        done)
            antwort="$(k show "$gid" --json 2>/dev/null \
                       | jq -r '[.events[] | select(.kind=="unblocked")] | last | .payload.reason // "?"')"
            ok "Karte $gid ist beantwortet und ausgeführt: \"$antwort\"" ;;
        triage)
            nein "Karte $gid ist in der TRIAGE gelandet — sie fragt niemanden mehr" ;;
        *)
            nein "Karte $gid steht auf '$gstatus' statt blocked/done" ;;
    esac
fi

# --- Roadmap-Datei ---------------------------------------------------------
echo
echo "5. Roadmap im Vault"
if ls "$VAULT"/roadmap/*.html >/dev/null 2>&1; then
    for datei in "$VAULT"/roadmap/*.html; do
        ok "roadmap/$(basename "$datei") ($(wc -c < "$datei" | tr -d ' ') Byte)"
    done
else
    nein "roadmap/ enthält kein einziges Dokument"
fi

printf '\n'
printf '%.0s─' $(seq 1 70); echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Phase 1 abgeschlossen.\033[0m\n'
    exit 0
fi
printf '\033[31m✗ Phase 1 noch nicht abgeschlossen — siehe die ✗ oben.\033[0m\n'
exit 1
