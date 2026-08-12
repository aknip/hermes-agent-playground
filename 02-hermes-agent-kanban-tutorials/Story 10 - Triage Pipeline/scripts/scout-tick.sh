#!/usr/bin/env bash
#
# Story 10 — Scout-Tick: legt die Eingangskarten eines Durchlaufs an
# ==================================================================
#
# Laeuft als Cron-Job mit --no-agent: kein Modell, keine Tokenkosten. Das
# Skript IST der Job. Es legt nur die drei Eingangskarten an — die Tokens
# fallen erst bei den Workern an, die der Dispatcher danach startet.
#
# Erwartet aus der Umgebung (setzt install-cron.sh):
#   TRIAGE_WS      absoluter Pfad auf das workspace/-Verzeichnis der Story
#   TRIAGE_BOARD   Board-Slug
#
# --idempotency-key enthaelt das Datum: ein zweiter Tick am selben Tag legt
# nichts Neues an, sondern bekommt die vorhandenen IDs zurueck.
#
set -euo pipefail

WS="${TRIAGE_WS:?TRIAGE_WS ist nicht gesetzt}"
BOARD="${TRIAGE_BOARD:-kanban-story-10}"
TENANT="triage"
DAY="$(date +%Y-%m-%d)"

k() { hermes kanban --board "$BOARD" "$@"; }

[ -d "$WS/sources/x" ] || { echo "FEHLER: $WS/sources/x fehlt."; exit 1; }

scout_body() {
    cat <<EOF
Quelle: $1

Werte JEDE Datei unter $2 aus — alle, nicht stichprobenartig.

Auftrag dieser Quelle:
$4

Halte dich an die Skill 'scout-report': ein \`##\`-Abschnitt je Kandidat, die
Felder aus pipeline/triage.yaml (item_schema.felder), Zitate woertlich.

Zwei Dateien, die denselben Fehlermechanismus beschreiben, sind EIN Kandidat
mit zwei Quellen.

Schreibe den Bericht nach $3.

Du erkennst nur. Nicht bewerten, nicht entscheiden, was damit geschieht.
EOF
}

SCOUT_X=$(k create "Scout x: sources/x auswerten ($DAY)" \
    --assignee triage-scout --tenant "$TENANT" --workspace "dir:$WS" \
    --skill scout-report --max-retries 2 --max-runtime 20m \
    --idempotency-key "story10-scout-x-$DAY" \
    --body "$(scout_body x sources/x intake/x.md "Konkreter, aktueller Schmerz mit KI-Coding-Agenten. Zitiere woertlich.")" \
    --json | jq -r .id)

SCOUT_WEB=$(k create "Scout web: sources/web auswerten ($DAY)" \
    --assignee triage-scout --tenant "$TENANT" --workspace "dir:$WS" \
    --skill scout-report --max-retries 2 --max-runtime 20m \
    --idempotency-key "story10-scout-web-$DAY" \
    --body "$(scout_body web sources/web intake/web.md "Faeden mit mehreren bestaetigenden Stimmen bevorzugen. Stimmenzahl festhalten.")" \
    --json | jq -r .id)

TRIAGE=$(k create "Triage: dedup, bewerten, Fan-out ($DAY)" \
    --assignee triage-orchestrator --tenant "$TENANT" --workspace "dir:$WS" \
    --skill triage-pipeline --max-retries 2 --max-runtime 30m \
    --parent "$SCOUT_X" --parent "$SCOUT_WEB" \
    --idempotency-key "story10-triage-$DAY" \
    --body "Stufe 1 der Pipeline, siehe Skill 'triage-pipeline', Abschnitt 'Stufe 1 — Triage'.
Eingang sind die Scout-Berichte unter intake/.
pipeline/triage.yaml lesen — Rubrik, Schwelle und Dedup-Kriterium stehen DORT.
Unter der Schwelle: archivieren, keinen Menschen fragen.
Ab der Schwelle: drei Recherche-Bahnen + eine Route-Karte je Item anlegen,
workspace_kind='dir' mit ABSOLUTEM Pfad, dann sofort abschliessen." \
    --json | jq -r .id)

echo "Scout-Tick $DAY auf $BOARD"
echo "  $SCOUT_X    Scout x"
echo "  $SCOUT_WEB  Scout web"
echo "  $TRIAGE  Triage"
