#!/usr/bin/env bash
#
# ESF — Ledger-Abgleich
# =====================
#
#   scripts/ledger-sync.sh [--dry-run]
#
# Cron 23:30. Holt die Wanduhrzeiten aus dem Board und die Kosten aus der
# OpenRouter-API und schreibt jedes (Schätzung, Ist)-Paar nach
# ledger/estimates.jsonl. Das Ledger ist die einzige Quelle, aus der der
# esf-estimator schätzen darf — und es wird nur angehängt, nie umgeschrieben.
#
# Die unbequeme Wahrheit: Hermes v0.20.0 misst keine Tokens und keine Kosten.
# Verlässlich sind Board-Zeitstempel. Alles Geldwerte kommt von OpenRouter oder
# gar nicht — und "gar nicht" wird als `null` geschrieben, nicht als Schätzung.
# Eine hineingeschriebene Vermutung vergiftet jede künftige Kalibrierung.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
LEDGER="$VAULT/ledger/estimates.jsonl"
HEUTE="$(date '+%Y-%m-%d')"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault unter $VAULT"; exit 1; }
mkdir -p "$(dirname "$LEDGER")"; : >> "$LEDGER"

k() { hermes kanban --board "$BOARD" "$@"; }

# ---------------------------------------------------------------------------
# Tageskosten je Profil-Key aus der OpenRouter-Activity-API
# ---------------------------------------------------------------------------
# Solange jedes Profil keinen eigenen Key hat (provision-keys.sh), lässt sich
# die Summe nicht auf Rollen aufteilen. Dann steht sie als Tagessumme im
# Report und je Karte `null` — ehrlich statt erfunden.
KOSTEN_HEUTE="null"
if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    antwort="$(curl -fsS --max-time 20 "https://openrouter.ai/api/v1/activity?date=$HEUTE" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" 2>/dev/null || true)"
    if [ -n "$antwort" ]; then
        KOSTEN_HEUTE="$(printf '%s' "$antwort" | jq -r '[.data[]?.usage // 0] | add // 0' 2>/dev/null || echo null)"
    fi
fi
echo "OpenRouter-Tagessumme $HEUTE: ${KOSTEN_HEUTE} USD"
[ "$KOSTEN_HEUTE" = "null" ] && \
    echo "  (nicht gemessen — OPENROUTER_API_KEY fehlt oder die API antwortete nicht)"

# ---------------------------------------------------------------------------
# Je fertige Karte eine Ledger-Zeile
# ---------------------------------------------------------------------------
liste="$(k list --json 2>/dev/null || echo '[]')"
neu=0; uebersprungen=0

for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="done") | .id'); do
    # Nur einmal je Karte — das Ledger wird angehängt, nicht gepflegt.
    if grep -q "\"task_id\": *\"$id\"" "$LEDGER" 2>/dev/null; then
        uebersprungen=$((uebersprungen + 1)); continue
    fi

    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
    profil="$(printf '%s' "$karte" | jq -r '.task.assignee // "unbekannt"')"

    # Das Abschluss-metadata eines Workers hängt am LAUF, nicht an der Karte
    # (`.runs[].metadata`) — die Karte selbst hat gar kein metadata-Feld.
    # Gültig ist der letzte Lauf, der eines geschrieben hat.
    schaetzung="$(printf '%s' "$karte" | jq -c '[.runs[]?.metadata.estimate // empty] | last // null')"
    klasse="$(printf '%s' "$karte" | jq -r '[.runs[]?.metadata.estimate.reference_class // empty] | last // "unklassifiziert"')"

    # Wanduhrzeit aus den Läufen — Board-Zeitstempel, nicht Modelltext.
    # Sie sind Unix-Epoch-Sekunden (Integer), kein ISO-8601.
    laeufe="$(printf '%s' "$karte" | jq -c '[.runs[]? | select(.started_at and .ended_at)]')"
    anzahl_laeufe="$(printf '%s' "$laeufe" | jq 'length')"
    minuten="$(printf '%s' "$laeufe" | jq '
        if length == 0 then null
        else ([.[] | (.ended_at - .started_at)] | add / 60 | floor) end' 2>/dev/null || echo null)"

    # Ein Lauf über eine Standby-Phase misst Schlaf, nicht Arbeit. Die
    # Heuristik: mehr als vier Stunden Wanduhr auf einer Karte ist im
    # Agentenbetrieb kein Rechnen mehr.
    standby=false
    if [ "$minuten" != "null" ] && [ "${minuten:-0}" -gt 240 ]; then standby=true; fi

    zeile="$(jq -n -c \
        --arg id "$id" --arg klasse "$klasse" --arg profil "$profil" \
        --argjson schaetzung "$schaetzung" \
        --argjson minuten "${minuten:-null}" --argjson laeufe "$anzahl_laeufe" \
        --argjson standby "$standby" --arg at "$HEUTE" \
        '{task_id:$id, reference_class:$klasse, profile:$profil,
          estimate:$schaetzung,
          actual:{wall_minutes:$minuten, runs:$laeufe, standby_overlap:$standby,
                  tokens_k:null, cost_usd:null},
          at:$at}')"

    if [ "$DRY" -eq 1 ]; then
        printf '  würde anhängen: %s\n' "$zeile"
    else
        printf '%s\n' "$zeile" >> "$LEDGER"
    fi
    neu=$((neu + 1))
done

echo "Ledger: $neu neue Zeile(n), $uebersprungen bereits erfasst -> $LEDGER"

# ---------------------------------------------------------------------------
# Kalibrierungs-Kurzbild
# ---------------------------------------------------------------------------
if [ -s "$LEDGER" ]; then
    echo
    echo "Referenzklassen im Ledger:"
    jq -rs 'group_by(.reference_class)
            | map({klasse: .[0].reference_class,
                   n: length,
                   ist_median: ([.[].actual.wall_minutes | select(. != null)] | sort | if length==0 then null else .[length/2|floor] end)})
            | .[] | "  \(.klasse): \(.n) Karten, Ist-Median \(.ist_median // "nicht gemessen") min"' \
        "$LEDGER" 2>/dev/null || echo "  (noch nicht auswertbar)"
fi

if [ "$DRY" -eq 0 ] && [ "$neu" -gt 0 ] && [ -d "$VAULT/.git" ]; then
    git -C "$VAULT" add ledger/estimates.jsonl
    git -C "$VAULT" -c user.name="esf-controller" -c user.email="esf-controller@esf.local" \
        commit -q -m "Ledger: $neu (Schätzung, Ist)-Paar(e) vom $HEUTE" 2>/dev/null || true
fi
