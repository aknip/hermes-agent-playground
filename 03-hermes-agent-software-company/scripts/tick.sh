#!/usr/bin/env bash
#
# ESF — Der Herzschlag
# ====================
#
#   scripts/tick.sh [--dry-run]
#
# Cron 07:00, tokenfrei (--no-agent). Der Tick selbst kostet nichts; Kosten
# entstehen erst bei den Workern, die der Dispatcher danach startet.
#
# Vier Aufgaben, in dieser Reihenfolge:
#   1. Selbst-Übersprung prüfen (drei Bedingungen)
#   2. Markt-Fetch: die konfigurierten Quellen nach sources/<datum>/ holen
#   3. Täglicher E2E-Regressionslauf (headless, tokenfrei)
#   4. Fällige Karten anlegen — mit Datums-Idempotenzschlüssel
#
# Die dritte Übersprung-Bedingung ist die wichtigste: Stehen offene Gates, legt
# der Tick nichts Neues an. Ein Cron-Job kann niemanden fragen — er würde die
# Gates nur stapeln, bis der Aufmerksamkeits-Deckel bedeutungslos ist.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault unter $VAULT. Erst ./setup.sh"; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Tick $HEUTE${DRY:+ (Trockenlauf)}"

# ---------------------------------------------------------------------------
# 1. Selbst-Übersprung: drei Bedingungen
# ---------------------------------------------------------------------------
json="$(k list --json 2>/dev/null || echo '[]')"

laufend="$(printf '%s' "$json" | jq '[.[] | select(.status=="running")] | length')"
if [ "$laufend" -gt 0 ]; then
    log "übersprungen: $laufend Karte(n) laufen noch"
    exit 0
fi

heute_angelegt="$(printf '%s' "$json" | jq -r --arg t "$HEUTE" \
    '[.[] | select(.title | contains("[" + $t + "]"))] | length')"
if [ "$heute_angelegt" -gt 0 ]; then
    log "übersprungen: der Tick für $HEUTE ist schon gelaufen ($heute_angelegt Karten)"
    exit 0
fi

blockiert="$(printf '%s' "$json" | jq '[.[] | select(.status=="blocked")] | length')"
if [ "$blockiert" -gt 0 ]; then
    log "übersprungen: $blockiert Gate(s) warten auf den CEO"
    printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | "        \(.id)  \(.title)"'
    log "Ein Cron-Job kann niemanden fragen. Erst ./gate.sh, dann läuft es weiter."
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Markt-Fetch
# ---------------------------------------------------------------------------
QUELLEN="$ESF/seed/quellen.txt"
ZIEL="$VAULT/sources/$HEUTE"
if [ -f "$QUELLEN" ]; then
    mkdir -p "$ZIEL"
    geholt=0; fehlgeschlagen=0
    while IFS='|' read -r name url; do
        case "$name" in ''|'#'*) continue ;; esac
        name="$(printf '%s' "$name" | tr -d ' ')"
        url="$(printf '%s' "$url" | tr -d ' ')"
        if [ "$DRY" -eq 1 ]; then
            log "  würde holen: $name <- $url"; continue
        fi
        if curl -fsSL --max-time 30 "$url" -o "$ZIEL/$name" 2>/dev/null; then
            geholt=$((geholt + 1))
        else
            # Eine Quelle, die nicht antwortet, wird VERMERKT, nicht verschwiegen.
            # Ein stillschweigend fehlender Tag macht den Korpus zur Lüge.
            printf 'FEHLGESCHLAGEN %s\nURL: %s\nZeit: %s\n' \
                "$name" "$url" "$(date '+%Y-%m-%d %H:%M:%S')" > "$ZIEL/$name.fehler"
            fehlgeschlagen=$((fehlgeschlagen + 1))
        fi
    done < "$QUELLEN"
    log "Markt-Fetch: $geholt geholt, $fehlgeschlagen fehlgeschlagen -> sources/$HEUTE/"
else
    log "Markt-Fetch: keine seed/quellen.txt — übersprungen"
fi

# ---------------------------------------------------------------------------
# 3. Täglicher E2E-Regressionslauf
# ---------------------------------------------------------------------------
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
AKTE="$VAULT/reports/e2e-$HEUTE"

if [ "$DRY" -eq 1 ]; then
    log "  würde laufen lassen: $E2E_BEFEHL in $REPO"
elif [ -d "$REPO" ] && ! "$HERE/e2e-video.sh" --headless-waechter "$REPO" "$E2E_BEFEHL" > "/tmp/esf-headless-befund.$$" 2>&1; then
    # HEADLESS IST PFLICHT (AGENTS.md 8 / cadence.yaml): Ein headed-Lauf aus
    # Cron wartete ewig auf einen Bildschirm — und sähe vom Board aus wie
    # Arbeit. Der Lauf wird ÜBERSPRUNGEN und der Verstoss wird eine Karte.
    log "E2E: ÜBERSPRUNGEN — Headless-Pflicht verletzt ($(cat "/tmp/esf-headless-befund.$$" | head -1))"
    k create "[$HEUTE] Headless-Pflicht verletzt — E2E-Regressionslauf übersprungen" \
        --assignee esf-qa-release \
        --workspace "dir:$REPO" \
        --idempotency-key "headless-verstoss-$HEUTE" \
        --max-retries 2 --max-runtime 75m \
        --body "Der tägliche E2E-Lauf wurde übersprungen: $(cat "/tmp/esf-headless-befund.$$")

Entferne --headed bzw. headless: false aus Konfiguration oder e2e_befehl.
Headless ist Pflicht ohne Ausnahme — Wächter: scripts/e2e-video.sh
--headless-waechter. Danach läuft der Tick von selbst wieder." >/dev/null 2>&1 || true
    rm -f "/tmp/esf-headless-befund.$$"
elif [ -d "$REPO" ]; then
    rm -f "/tmp/esf-headless-befund.$$"
    mkdir -p "$AKTE"
    ( cd "$REPO" && eval "$E2E_VORBED" ) >/dev/null 2>&1 || true
    set +e
    ( cd "$REPO" && eval "$E2E_BEFEHL" ) > "$AKTE/lauf.txt" 2>&1
    e2e_rc=$?
    set -e
    [ -d "$REPO/test-results" ] && cp -R "$REPO/test-results" "$AKTE/" 2>/dev/null || true
    if [ "$e2e_rc" -eq 0 ]; then
        log "E2E: grün -> reports/e2e-$HEUTE/"
        # Ein grüner Lauf bekommt seine Video-Akte sofort (AGENTS.md 8) — der
        # Tick ist einer von vier Anlässen; auf einen Merge wartet hier nichts.
        # Nicht blockierend: Der Tick darf an einem Video nicht sterben.
        if [ -x "$HERE/e2e-video.sh" ]; then
            "$HERE/e2e-video.sh" --alle --anlass tick 2>&1 | sed 's/^/    /' \
                || log "  (Video-Akte des Tick-Laufs fehlgeschlagen — Betriebsbefund, kein Abbruch)"
        fi
    else
        log "E2E: ROT (Exit $e2e_rc) -> reports/e2e-$HEUTE/lauf.txt"
        # Flakiness wird behandelt wie ein Bug, nicht wie Wetter.
        if [ "$DRY" -eq 0 ]; then
            k create "[$HEUTE] E2E-Regressionslauf ist rot" \
                --assignee esf-qa-release \
                --workspace "dir:$VAULT" \
                --idempotency-key "e2e-rot-$HEUTE" \
                --max-retries 2 --max-runtime 75m \
                --body "Der tägliche Regressionslauf vom $HEUTE ist fehlgeschlagen.

Protokoll: reports/e2e-$HEUTE/lauf.txt
Traces und Screenshots: reports/e2e-$HEUTE/test-results/

Diagnostiziere die Ursache, bevor du irgendetwas reparierst. Ein Spec, der
einmal in zehn Läufen fällt, bekommt eine Diagnose, keinen Retry-Zähler.
Halte in deinem Abschluss-metadata fest: welcher Spec, welche Ursachenklasse
(Produktfehler | Testfehler | Umgebung | echte Flakiness), und was du getan
hast." >/dev/null 2>&1 || log "  (Karte konnte nicht angelegt werden)"
        fi
    fi
else
    log "E2E: Produkt-Repo '$REPO' nicht gefunden — übersprungen"
fi

# ---------------------------------------------------------------------------
# 4. Fällige Karten anlegen
# ---------------------------------------------------------------------------
# --idempotency-key mit Datum: ein zweiter Tick am selben Tag dupliziert nichts.
if [ -d "$ZIEL" ] && [ -n "$(ls -A "$ZIEL" 2>/dev/null)" ]; then
    if [ "$DRY" -eq 1 ]; then
        log "  würde anlegen: Markt-Sichtung für $HEUTE"
    else
        k create "[$HEUTE] Markt-Sichtung" \
            --assignee esf-market-scout \
            --workspace "dir:$VAULT" \
            --idempotency-key "markt-sichtung-$HEUTE" \
            --max-retries 2 --max-runtime 90m \
            --body "Werte JEDE Datei unter sources/$HEUTE/ aus — alle, nicht stichprobenartig.

Dateien mit der Endung .fehler sind Quellen, die heute nicht geantwortet
haben. Liste sie unter '## Nicht auswertbar' auf; sie sind Teil des
Tagesbildes, nicht Rauschen.

Schreibe deinen Bericht nach analysis/sichtung-$HEUTE.html — Format nach
AGENTS.md 2.2, inklusive esf-karte mit deiner Karten-ID.

Du erkennst nur. Du bewertest nicht." >/dev/null 2>&1 \
            && log "Karte angelegt: Markt-Sichtung $HEUTE" \
            || log "Markt-Sichtung: Karte existiert schon (Idempotenz greift)"
    fi
else
    log "Keine Quellen für $HEUTE — keine Sichtungskarte"
fi

log "Tick fertig"
