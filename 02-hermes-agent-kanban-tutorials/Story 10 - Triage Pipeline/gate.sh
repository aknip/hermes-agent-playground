#!/usr/bin/env bash
#
# Story 10 - Triage Pipeline — Das menschliche Tor
# ================================================
#
# Der EINZIGE Punkt der ganzen Pipeline, an dem ein Mensch entscheidet.
#
#   ./gate.sh                          offene Tore anzeigen (mit Vorschlag)
#   ./gate.sh approve <id>             freigeben
#   ./gate.sh shelve  <id> "<grund>"   ablegen, nichts bauen
#   ./gate.sh modify  <id> "<aend.>"   mit dieser Aenderung umsetzen
#
# Dahinter steckt genau ein Befehl:
#
#   hermes kanban --board kanban-story-10 unblock <id> --reason "<verb> …"
#
# `--reason` legt den Text als KOMMENTAR an die Karte und hebt sie danach nach
# `ready`. Der Orchestrator, der die Karte blockiert hat, laeuft ein zweites
# Mal an — und liest deine Antwort in seinem Kommentar-Thread.
#
# Im Original (tonbistudio/hermes-multi-agent-workflow) laeuft dieses Tor ueber
# Telegram. Dass es hier ueber das Board laeuft, aendert nichts am Prinzip:
# eine Entscheidung, drei Verben, ein Mensch.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-10"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

# ---------------------------------------------------------------------------
# Ohne Argumente: zeigen, worauf gewartet wird
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    json="$(k list --json 2>/dev/null || echo '[]')"
    ids=$(printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | .id')

    if [ -z "$ids" ]; then
        echo "Kein offenes Tor. Die Pipeline wartet gerade nicht auf dich."
        echo
        k list
        exit 0
    fi

    for id in $ids; do
        title=$(printf '%s' "$json" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')
        printf '\n\033[1m%s  %s\033[0m\n' "$id" "$title"
        printf '%.0s─' $(seq 1 72); echo

        # Der Block-Grund ist das, was der Orchestrator dich lesen lassen wollte.
        # `runs` schneidet ihn ab — vollstaendig steht er im Ereignis.
        k show "$id" --json 2>/dev/null \
          | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // "(kein Grund hinterlegt)"' \
          | fold -s -w 74 | sed 's/^/  /'

        # Der ausformulierte Vorschlag liegt als Datei im Workspace.
        slug=$(printf '%s' "$title" | sed 's/.*: *//')
        vorschlag="$HERE/workspace/vault/items/${slug}-vorschlag.md"
        if [ -f "$vorschlag" ]; then
            printf '\n  Vollstaendiger Vorschlag: workspace/vault/items/%s-vorschlag.md\n' "$slug"
        fi

        cat <<EOF

  ./gate.sh approve $id
  ./gate.sh shelve  $id "passt nicht zum Kanal"
  ./gate.sh modify  $id "nur Linux und WSL, Windows weglassen"
EOF
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Mit Argumenten: entscheiden
# ---------------------------------------------------------------------------
VERB="${1:-}"
ID="${2:-}"
TEXT="${3:-}"

case "$VERB" in
    approve|shelve|modify) ;;
    *) echo "Verb muss approve, shelve oder modify sein (war: '$VERB')"; exit 1 ;;
esac
[ -n "$ID" ] || { echo "Kartennummer fehlt. Offene Tore:  ./gate.sh"; exit 1; }

status=$(k list --json | jq -r --arg i "$ID" '.[] | select(.id==$i) | .status')
if [ "$status" != "blocked" ]; then
    echo "Karte $ID ist '$status', nicht 'blocked' — hier ist gerade kein Tor."
    exit 1
fi

case "$VERB" in
    approve) REASON="approve" ;;
    shelve)  [ -n "$TEXT" ] || { echo "shelve braucht einen Grund."; exit 1; }
             REASON="shelve: $TEXT" ;;
    modify)  [ -n "$TEXT" ] || { echo "modify braucht die gewuenschte Aenderung."; exit 1; }
             REASON="modify: $TEXT" ;;
esac

echo "Antwort an $ID:  \"$REASON\""
k unblock "$ID" --reason "$REASON"

cat <<EOF

Die Karte steht wieder auf 'ready'. Beim naechsten Dispatcher-Tick laeuft
derselbe Orchestrator ein zweites Mal an, liest deine Antwort im
Kommentar-Thread und fuehrt sie aus.

  ./pump.sh
  hermes kanban --board $BOARD show $ID
EOF
