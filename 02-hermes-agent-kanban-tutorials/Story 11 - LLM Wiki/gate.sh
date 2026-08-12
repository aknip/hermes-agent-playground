#!/usr/bin/env bash
#
# Story 11 - LLM Wiki — Die zwei menschlichen Tore
# ================================================
#
# Diese Pipeline fragt ZWEIMAL, und die beiden Fragen sind verschieden:
#
#   TOR 1  "Soll dieses Wissen in die Wissensbasis?"
#          ./gate.sh approve <id>
#          ./gate.sh shelve  <id> "<grund>"
#          ./gate.sh modify  <id> "<aenderung>"
#
#   TOR 2  "Soll dieser Branch nach main — samt der vorgeschlagenen Prunes?"
#          ./gate.sh merge            <id>
#          ./gate.sh merge-ohne-prune <id>
#          ./gate.sh discard          <id> "<grund>"
#
# Ohne Argumente zeigt das Skript alle offenen Tore, jeweils MIT den Verben,
# die dort gelten. Ein Verb am falschen Tor wird abgewiesen — das ist Absicht:
# `merge` an Tor 1 wuerde ungeprueften Inhalt nach main bringen, und `approve`
# an Tor 2 hiesse, ueber eine Loeschung mit dem Vokabular einer Aufnahme zu
# entscheiden.
#
# Dahinter steckt beide Male genau ein Befehl:
#
#   hermes kanban --board kanban-story-11 unblock <id> --reason "<verb> …"
#
# `--reason` legt den Text als KOMMENTAR an die Karte und hebt sie danach nach
# `ready`. Derselbe Orchestrator laeuft ein zweites Mal an und liest die Antwort
# in seinem Kommentar-Thread.
#
# Im Original (tonbistudio/llm-wiki) laufen beide Tore ueber Telegram, mit
# `approve` als Chat-Antwort. Dass sie hier ueber das Board laufen, aendert
# nichts am Prinzip: zwei Entscheidungen, zwei Vokabulare, ein Mensch.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-11"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

VERBEN_TOR1="approve shelve modify"
VERBEN_TOR2="merge merge-ohne-prune discard"

# Welches Tor ist eine Karte? Am Titel, den die Skill kb-pipeline festlegt.
tor_von() {
    case "$1" in
        "Vorschlag + Tor 1"*) echo 1 ;;
        "Commit + Tor 2"*)    echo 2 ;;
        *)                    echo 0 ;;
    esac
}

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
        tor=$(tor_von "$title")
        case "$tor" in
            1) label="TOR 1 — Soll dieses Wissen in die Wissensbasis?" ;;
            2) label="TOR 2 — Soll dieser Branch nach main, samt Prunes?" ;;
            *) label="KEIN TOR — eine echte Blockade, kein Freigabepunkt" ;;
        esac

        printf '\n\033[1m%s  %s\033[0m\n' "$id" "$title"
        printf '\033[1m%s\033[0m\n' "$label"
        printf '%.0s─' $(seq 1 74); echo

        # Der Block-Grund ist das, was der Orchestrator dich lesen lassen wollte.
        # `runs` schneidet ihn ab — vollstaendig steht er im Ereignis.
        k show "$id" --json 2>/dev/null \
          | jq -r '[.events[] | select(.kind=="blocked")] | last
                   | .payload.reason // "(kein Grund hinterlegt)"' \
          | fold -s -w 74 | sed 's/^/  /'

        slug=$(printf '%s' "$title" | sed 's/.*: *//')
        case "$tor" in
          1)
            [ -f "$HERE/workspace/vault/${slug}-vorschlag.md" ] && \
              printf '\n  Vollstaendiger Vorschlag: workspace/vault/%s-vorschlag.md\n' "$slug"
            cat <<EOF

  ./gate.sh approve $id
  ./gate.sh shelve  $id "steht so schon woanders"
  ./gate.sh modify  $id "nur den Teil zu block, den Rest weglassen"
EOF
            ;;
          2)
            [ -f "$HERE/workspace/vault/${slug}-lint.md" ] && \
              printf '\n  Lint-Bericht: workspace/vault/%s-lint.md\n' "$slug"
            printf '  Diff des Branches:  python3 workspace/bin/kb_git.py changed kb/ingest-%s\n' "$slug"
            cat <<EOF

  ./gate.sh merge            $id
  ./gate.sh merge-ohne-prune $id
  ./gate.sh discard          $id "erst pruefen, ob die Quelle stimmt"
EOF
            ;;
          *)
            printf '\n  Kein Freigabeverb. Ursache beheben, dann:\n'
            printf '  hermes kanban --board %s unblock %s\n' "$BOARD" "$id"
            ;;
        esac
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Mit Argumenten: entscheiden
# ---------------------------------------------------------------------------
VERB="${1:-}"
ID="${2:-}"
TEXT="${3:-}"

case " $VERBEN_TOR1 $VERBEN_TOR2 " in
    *" $VERB "*) ;;
    *) echo "Unbekanntes Verb '$VERB'."
       echo "  Tor 1: $VERBEN_TOR1"
       echo "  Tor 2: $VERBEN_TOR2"
       exit 1 ;;
esac
[ -n "$ID" ] || { echo "Kartennummer fehlt. Offene Tore:  ./gate.sh"; exit 1; }

json="$(k list --json)"
status=$(printf '%s' "$json" | jq -r --arg i "$ID" '.[] | select(.id==$i) | .status')
title=$(printf '%s' "$json"  | jq -r --arg i "$ID" '.[] | select(.id==$i) | .title')
[ -n "$status" ] || { echo "Karte $ID gibt es auf $BOARD nicht."; exit 1; }
if [ "$status" != "blocked" ]; then
    echo "Karte $ID ist '$status', nicht 'blocked' — hier ist gerade kein Tor."
    exit 1
fi

# Das Verb muss zum Tor passen.
tor=$(tor_von "$title")
case "$tor" in
    1) erlaubt="$VERBEN_TOR1" ;;
    2) erlaubt="$VERBEN_TOR2" ;;
    *) echo "Karte $ID ist kein Tor ('$title'), sondern eine echte Blockade."
       echo "Ursache beheben, dann: hermes kanban --board $BOARD unblock $ID"
       exit 1 ;;
esac
case " $erlaubt " in
    *" $VERB "*) ;;
    *) echo "'$VERB' gilt an Tor $tor nicht. Dort gelten: $erlaubt"
       echo
       echo "Tor 1 entscheidet, ob Wissen AUFGENOMMEN wird."
       echo "Tor 2 entscheidet, ob es nach main geht und ob etwas GELOESCHT wird."
       echo "Dieselben Verben fuer beides waeren ein Tor, zweimal gebaut."
       exit 1 ;;
esac

# Verben, die eine Begruendung brauchen.
case "$VERB" in
    shelve|modify|discard)
        [ -n "$TEXT" ] || { echo "'$VERB' braucht einen Text (Grund bzw. Aenderung)."; exit 1; }
        REASON="$VERB: $TEXT" ;;
    *)  REASON="$VERB" ;;
esac

printf 'Antwort an %s (Tor %s):  "%s"\n' "$ID" "$tor" "$REASON"
k unblock "$ID" --reason "$REASON"

cat <<EOF

Die Karte steht wieder auf 'ready'. Beim naechsten Dispatcher-Tick laeuft
derselbe Orchestrator ein zweites Mal an, liest deine Antwort im
Kommentar-Thread und fuehrt sie aus.

  ./pump.sh
  hermes kanban --board $BOARD show $ID
EOF

[ "$tor" = "2" ] && cat <<EOF
  ./reset-workspace.sh --git          # was ist in main gelandet?
  python3 workspace/bin/kb_lint.py workspace/wiki
EOF
exit 0
