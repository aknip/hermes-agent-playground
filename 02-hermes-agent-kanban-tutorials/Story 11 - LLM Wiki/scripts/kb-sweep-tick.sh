#!/usr/bin/env bash
#
# Story 11 — KB-Sweep-Tick: legt die Eingangskarten eines Durchlaufs an
# ====================================================================
#
# Laeuft als Cron-Job mit --no-agent: kein Modell, keine Tokenkosten. Das
# Skript IST der Job. Es legt nur die drei Eingangskarten an — die Tokens
# fallen erst bei den Workern an, die der Dispatcher danach startet.
#
# Erwartet aus der Umgebung (setzt install-cron.sh):
#   KB_WS      absoluter Pfad auf das workspace/-Verzeichnis der Story
#   KB_BOARD   Board-Slug
#
# --idempotency-key enthaelt das Datum: ein zweiter Tick am selben Tag legt
# nichts Neues an, sondern bekommt die vorhandenen IDs zurueck.
#
# ⚠ Der Sweep laeuft NUR, wenn die Wissensbasis sauber und kein Ingest offen
#   ist. Ein neuer Durchlauf auf einem halbfertigen Branch wuerde die
#   Serialisierung unterlaufen — und der Cron-Job hat niemanden, der ihn fragt.
#
set -euo pipefail

WS="${KB_WS:?KB_WS ist nicht gesetzt}"
BOARD="${KB_BOARD:-kanban-story-11}"
TENANT="wiki"
DAY="$(date +%Y-%m-%d)"

k() { hermes kanban --board "$BOARD" "$@"; }

[ -d "$WS/sources/releases" ] || { echo "FEHLER: $WS/sources/releases fehlt."; exit 1; }
[ -d "$WS/wiki/.git" ]        || { echo "FEHLER: $WS/wiki ist kein Git-Repository."; exit 1; }

# --- Vorbedingung: keine halbfertige Arbeit -------------------------------
git_status="$(python3 "$WS/bin/kb_git.py" --wiki "$WS/wiki" status)"
if ! printf '%s' "$git_status" | grep -q 'Arbeitsbaum:     sauber'; then
    echo "UEBERSPRUNGEN — Arbeitsbaum der Wissensbasis ist nicht sauber:"
    printf '%s\n' "$git_status"
    exit 0
fi
if ! printf '%s' "$git_status" | grep -q 'Offene Ingests:  (keine)'; then
    echo "UEBERSPRUNGEN — es ist noch ein Ingest offen:"
    printf '%s\n' "$git_status"
    exit 0
fi

# --- Vorbedingung: kein offenes Tor --------------------------------------
# Ein zweiter Sweep, waehrend ein Mensch noch an Tor 1 oder 2 steht, haeuft
# Entscheidungen auf, die niemand mehr auseinanderhaelt.
offen=$(k list --json 2>/dev/null | jq '[.[] | select(.status=="blocked")] | length' || echo 0)
if [ "${offen:-0}" -gt 0 ]; then
    echo "UEBERSPRUNGEN — $offen Karte(n) warten noch auf eine Entscheidung."
    k list --json | jq -r '.[] | select(.status=="blocked") | "  \(.id)  \(.title)"'
    exit 0
fi

scout_body() {
    cat <<EOF
Quelle: $1

Werte JEDE Datei unter $2 aus — alle, nicht stichprobenartig.

Auftrag dieser Quelle:
$4

Halte dich an die Skill 'kb-scout-report': ein \`##\`-Abschnitt je Kandidat, die
Felder aus ingest.yaml (item_schema.felder), Zitate woertlich mit Zeitmarke,
immer mit Version (oder \`unbestimmt\`).

Zwei Dateien, die dieselbe Aenderung beschreiben, sind EIN Kandidat mit zwei
Quellen.

Schreibe den Bericht nach $3.

Du erkennst nur. Nicht entscheiden, ob die Wissensbasis das schon kennt, und
nicht, ob es wichtig ist.
EOF
}

SCOUT_REL=$(k create "Scout releases: sources/releases auswerten ($DAY)" \
    --assignee kb-scout --tenant "$TENANT" --workspace "dir:$WS" \
    --skill kb-scout-report --max-retries 2 --max-runtime 20m \
    --idempotency-key "story11-scout-releases-$DAY" \
    --body "$(scout_body releases sources/releases intake/releases.md \
      "Changelogs und Release-Notes. Version und Datum je Kandidat festhalten.")" \
    --json | jq -r .id)

SCOUT_TRA=$(k create "Scout transcripts: sources/transcripts auswerten ($DAY)" \
    --assignee kb-scout --tenant "$TENANT" --workspace "dir:$WS" \
    --skill kb-scout-report --max-retries 2 --max-runtime 20m \
    --idempotency-key "story11-scout-transcripts-$DAY" \
    --body "$(scout_body transcripts sources/transcripts intake/transcripts.md \
      "Transkripte. Nur ueberpruefbare Aussagen; Kanal-Neuigkeiten und Ankuendigungen sind keine Kandidaten.")" \
    --json | jq -r .id)

TRIAGE=$(k create "Triage: buendeln, dedup gegen die Wissensbasis, bewerten ($DAY)" \
    --assignee kb-orchestrator --tenant "$TENANT" --workspace "dir:$WS" \
    --skill kb-pipeline --max-retries 2 --max-runtime 45m \
    --parent "$SCOUT_REL" --parent "$SCOUT_TRA" \
    --idempotency-key "story11-triage-$DAY" \
    --body "Stufe 1 der Pipeline, siehe Skill 'kb-pipeline', Abschnitt 'Stufe 1 — Triage'.
Eingang sind die Scout-Berichte unter intake/.
ingest.yaml und wiki/AGENTS.md lesen — Rubrik, Schwelle, Buendelung und
Dedup-Kriterium stehen DORT.
DEDUP gegen die WISSENSBASIS: die betroffenen Seiten unter wiki/pages/ wirklich
lesen. Bereits abgedeckt oder unter der Schwelle: geshelved, keinen Menschen
fragen.
Ab der Schwelle: zwei Recherche-Bahnen + eine Route-Karte je Item anlegen,
workspace_kind='dir' mit ABSOLUTEM Pfad, idempotency_key je Karte, dann sofort
abschliessen.
In dieser Stufe wird NICHTS nach wiki/ geschrieben." \
    --json | jq -r .id)

echo "KB-Sweep $DAY auf $BOARD"
echo "  $SCOUT_REL  Scout releases"
echo "  $SCOUT_TRA  Scout transcripts"
echo "  $TRIAGE  Triage"
