#!/usr/bin/env bash
#
# ESF — Die Supervisor-Hülle (bis Phase 2: die CEO-Hülle)
# ========================================================
#
# Der einzige legitime Weg, ein Gate zu öffnen. Ohne Argumente zeigt das Skript
# alle wartenden Gates mit ihrer Entscheidungsvorlage; mit Argumenten antwortet
# es.
#
# Seit Phase 3 gibt es zwei Aufrufer (AGENTS.md 7):
#   · der SUPERVISOR (Mensch) — direkt, wie bisher. Roadmap-Gates und
#     Notfälle sind ausschließlich seine.
#   · scripts/ceo-tick.sh — führt validierte Entscheidungsdokumente von
#     esf-ceo aus und hängt dafür `--von esf-ceo` an. Der Zusatz landet als
#     `[von:esf-ceo]` im UNBLOCK-Kommentar; check-phase3.sh zählt daran, wer
#     was beantwortet hat. Ein Roadmap-Gate mit --von esf-ceo wird hier
#     VERWEIGERT — nicht delegierbar ist nicht delegierbar.
#
#   ROADMAP     ./gate.sh approve  <id>
#               ./gate.sh approve  <id> "horizont: quartal"
#               ./gate.sh modify   <id> "<Änderung>"
#               ./gate.sh shelve   <id> "<Grund>"
#
#   RELEASE     ./gate.sh approve | modify | shelve
#
#   IRREVERSIBEL (Feature-Entfernung, Breaking Change, Datenmigration)
#               ./gate.sh approve | modify | shelve
#
#   BUDGET      ./gate.sh continue <id>
#               ./gate.sh cut      <id> "<Scope>"
#               ./gate.sh stop     <id> "<Grund>"
#
# Dahinter steckt genau ein Befehl:
#
#   hermes kanban --board sw-company unblock <id> --reason "<verb>: …"
#
# `--reason` legt den Text als Kommentar an die Karte und hebt sie nach `ready`.
# Derselbe Worker läuft ein zweites Mal an, liest die Antwort in seinem
# Kommentar-Thread und führt sie aus.
#
# Warum eine Hülle und nicht der Befehl selbst: Das Verb-Präfix ist das
# Erkennungsmerkmal, an dem monitor.sh eine legitime menschliche Antwort von
# einem Worker unterscheidet, der sich selbst freischaltet. Ein `unblock` ohne
# gültiges Verb ist ein Governance-Verstoss und wird gemeldet.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

VERBEN_ENTSCHEIDUNG="approve modify shelve"
VERBEN_BUDGET="continue cut stop"

# Welche Art Gate ist eine Karte? Am Titel-Präfix, das der Chief of Staff setzt.
art_von() {
    case "$1" in
        "GATE Roadmap"*)      echo roadmap ;;
        "GATE Release"*)      echo release ;;
        "GATE Irreversibel"*) echo irreversibel ;;
        "GATE Budget"*)       echo budget ;;
        "GATE"*)              echo unbekannt ;;
        *)                    echo keins ;;
    esac
}

verben_zu() {
    case "$1" in
        budget) echo "$VERBEN_BUDGET" ;;
        keins|unbekannt) echo "" ;;
        *)      echo "$VERBEN_ENTSCHEIDUNG" ;;
    esac
}

beschriftung() {
    case "$1" in
        roadmap)      echo "ROADMAP — nicht delegierbar. Auch die Kadenz-Limits und der Autonomie-Horizont hängen hier." ;;
        release)      echo "RELEASE — Freigabe des Pakets. Kein Tag, kein Deploy vor deiner Antwort." ;;
        irreversibel) echo "IRREVERSIBEL — Entfernung, Breaking Change, Migration. Gegenüber Bestandskunden nicht zurücknehmbar." ;;
        budget)       echo "BUDGET — Ist über der Schwelle. Weiterlaufen, Scope kürzen oder anhalten." ;;
        unbekannt)    echo "GATE unbekannter Art — Titel-Präfix prüfen." ;;
        *)            echo "KEIN GATE — eine echte Blockade, kein Freigabepunkt." ;;
    esac
}

# ---------------------------------------------------------------------------
# Ohne Argumente: zeigen, worauf gewartet wird
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    json="$(k list --json 2>/dev/null || echo '[]')"

    # Karten in der TRIAGE sind das stille Versagen dieser Mechanik: dorthin
    # routet Hermes eine Karte, die zweimal mit derselben Block-Art blockiert
    # wurde. Nichts warnt davor — diese Prüfung ist handgeschrieben.
    triage="$(printf '%s' "$json" | jq -r '[.[] | select(.status=="triage")] | length')"
    if [ "$triage" -gt 0 ]; then
        printf '\n\033[33m⚠ %s Karte(n) in der TRIAGE — vermutlich block_loop_detected.\033[0m\n' "$triage"
        printf '%s' "$json" | jq -r '.[] | select(.status=="triage") | "   \(.id)  \(.title)"'
        printf '   Diese Karten fragen dich NICHT mehr. Prüfen: hermes kanban --board %s show <id> --json\n' "$BOARD"
    fi

    ids="$(printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | .id')"
    if [ -z "$ids" ]; then
        echo
        echo "Kein offenes Gate. Die Organisation wartet gerade nicht auf dich."
        echo
        k list
        exit 0
    fi

    anzahl="$(printf '%s\n' "$ids" | grep -c . || true)"
    deckel="$(sed -n 's/^gate_fragen_pro_tag:[[:space:]]*//p' "$HERE/workspace/company/cadence.yaml" 2>/dev/null | head -1)"
    deckel="${deckel:-3}"
    if [ "$anzahl" -gt "$deckel" ]; then
        printf '\n\033[33m⚠ %s Gates offen, der Aufmerksamkeits-Deckel liegt bei %s.\033[0m\n' "$anzahl" "$deckel"
        printf '  Ein Gate mit zwölf wartenden Karten wird nicht sorgfältiger beantwortet,\n'
        printf '  sondern durchgewinkt. Beantworte die ersten %s, den Rest morgen.\n' "$deckel"
    fi

    for id in $ids; do
        titel="$(printf '%s' "$json" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
        art="$(art_von "$titel")"

        printf '\n\033[1m%s  %s\033[0m\n' "$id" "$titel"
        printf '\033[1m%s\033[0m\n' "$(beschriftung "$art")"
        printf '%.0s─' $(seq 1 76); echo

        # Der Blockgrund IST die Entscheidungsvorlage. `runs` schneidet ihn ab;
        # vollständig steht er im Ereignis.
        k show "$id" --json 2>/dev/null \
          | jq -r '[.events[] | select(.kind=="blocked")] | last
                   | .payload.reason // "(kein Grund hinterlegt — die Vorlage fehlt, das ist ein Mangel der Karte)"' \
          | fold -s -w 76 | sed 's/^/  /'

        echo
        case "$art" in
          budget)
            cat <<EOF
  ./gate.sh continue $id
  ./gate.sh cut      $id "Feature F3 aus diesem Release nehmen"
  ./gate.sh stop     $id "Kosten stehen nicht im Verhältnis"
EOF
            ;;
          roadmap)
            cat <<EOF
  ./gate.sh approve $id
  ./gate.sh approve $id "horizont: quartal"      # alle drei Releases autonom
  ./gate.sh modify  $id "F2 vor F1, F4 streichen"
  ./gate.sh shelve  $id "Marktbild reicht nicht"
EOF
            ;;
          keins|unbekannt)
            printf '  Kein Freigabeverb. Ursache beheben, dann:\n'
            printf '  hermes kanban --board %s unblock %s --reason "manuell: <Grund>"\n' "$BOARD" "$id"
            ;;
          *)
            cat <<EOF
  ./gate.sh approve $id
  ./gate.sh modify  $id "<Änderung>"
  ./gate.sh shelve  $id "<Grund>"
EOF
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
VON=""
# `--von <name>` darf als 3./4. bzw. 5. Argument stehen (ceo-tick.sh hängt es
# hinten an). Alles andere an dieser Position ist ein Aufruffehler.
if [ "${3:-}" = "--von" ]; then VON="${4:-}"; TEXT=""; fi
if [ "${4:-}" = "--von" ]; then VON="${5:-}"; fi

case " $VERBEN_ENTSCHEIDUNG $VERBEN_BUDGET " in
    *" $VERB "*) ;;
    *) echo "Unbekanntes Verb '$VERB'."
       echo "  Roadmap/Release/Irreversibel: $VERBEN_ENTSCHEIDUNG"
       echo "  Budget:                       $VERBEN_BUDGET"
       exit 1 ;;
esac
[ -n "$ID" ] || { echo "Kartennummer fehlt. Offene Gates:  ./gate.sh"; exit 1; }

json="$(k list --json)"
status="$(printf '%s' "$json" | jq -r --arg i "$ID" '.[] | select(.id==$i) | .status')"
titel="$(printf '%s' "$json"  | jq -r --arg i "$ID" '.[] | select(.id==$i) | .title')"
[ -n "$status" ] || { echo "Karte $ID gibt es auf $BOARD nicht."; exit 1; }
if [ "$status" != "blocked" ]; then
    echo "Karte $ID ist '$status', nicht 'blocked' — hier ist gerade kein Gate."
    exit 1
fi

art="$(art_von "$titel")"
erlaubt="$(verben_zu "$art")"
if [ -z "$erlaubt" ]; then
    echo "Karte $ID ist kein Gate ('$titel'), sondern eine echte Blockade."
    echo "Ursache beheben, dann: hermes kanban --board $BOARD unblock $ID --reason \"manuell: <Grund>\""
    exit 1
fi
case " $erlaubt " in
    *" $VERB "*) ;;
    *) echo "'$VERB' gilt an einem $art-Gate nicht. Dort gelten: $erlaubt"
       echo
       echo "Budget-Gates haben ein eigenes Vokabular, weil sie eine andere Frage"
       echo "stellen: nicht 'ist das richtig', sondern 'ist es das noch wert'."
       exit 1 ;;
esac

# Das Roadmap-Gate ist nicht delegierbar — auch nicht an das eigene
# CEO-Profil. ceo-lint.py verweigert dort schon jedes Verb außer escalate;
# dieser Riegel hier ist die zweite, unabhängige Hälfte derselben Regel.
if [ -n "$VON" ] && [ "$art" = "roadmap" ]; then
    echo "VERWEIGERT: das Roadmap-Gate beantwortet nur der Supervisor selbst."
    echo "            (Aufruf kam mit --von $VON.)"
    exit 1
fi

# Verben, die eine Begründung brauchen. `approve` darf einen Zusatz tragen
# (z.B. "horizont: quartal"), muss aber nicht.
MARKE=""
[ -n "$VON" ] && MARKE=" [von:$VON]"
case "$VERB" in
    modify|shelve|cut|stop)
        [ -n "$TEXT" ] || { echo "'$VERB' braucht einen Text (Änderung bzw. Grund)."; exit 1; }
        REASON="$VERB$MARKE: $TEXT" ;;
    *)  if [ -n "$TEXT" ]; then REASON="$VERB$MARKE: $TEXT"; else REASON="$VERB$MARKE"; fi ;;
esac

printf 'Antwort an %s (%s-Gate):  "%s"\n' "$ID" "$art" "$REASON"
k unblock "$ID" --reason "$REASON"

cat <<EOF

Die Karte steht wieder auf 'ready'. Beim nächsten Dispatcher-Tick läuft
derselbe Worker ein zweites Mal an, liest deine Antwort und führt sie aus.

  ./pump.sh
  hermes kanban --board $BOARD show $ID --json | jq '.events[-3:]'
EOF
