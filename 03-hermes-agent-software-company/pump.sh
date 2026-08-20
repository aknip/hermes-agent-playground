#!/usr/bin/env bash
#
# ESF — Dispatcher-Pumpe
# ======================
#
#   ./pump.sh            alle 20 s ein Tick, max. 120 Ticks
#   ./pump.sh 10 300     alle 10 s, max. 300 Ticks
#   ./pump.sh --once     genau ein Tick
#   ./pump.sh --dry      Trockenlauf: was WÜRDE der Dispatcher tun
#
# Im Dauerbetrieb übernimmt das Gateway (launchd, Tick 60 s) diese Aufgabe.
# Die Pumpe ist der manuelle Ersatz für Testläufe — und das Werkzeug, mit dem
# man beim Zusehen lernt, wo die Organisation stehenbleibt.
#
# `blocked` zählt hier NICHT als offen: Die Pumpe endet von selbst, sobald nur
# noch Gates warten, und sagt, welche. Weiter mit ./gate.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }

case "${1:-}" in
    --once) hermes kanban --board "$BOARD" dispatch; exit 0 ;;
    --dry)  hermes kanban --board "$BOARD" dispatch --dry-run; exit 0 ;;
esac

INTERVALL="${1:-20}"
MAX_TICKS="${2:-120}"

# Wie oft die Pumpe den Wachhund laufen lässt. 10 Ticks × 20 s ≈ alle 3 Minuten.
#
# Warum das hier hängt und nicht in einem Cron-Job: Ein Worker, der die
# Verbindung zum Provider verloren hat, steht auf `running`, sendet brav
# Heartbeats weiter und verbraucht 0 % CPU — vom Board aus ist der Zustand von
# echter Arbeit NICHT zu unterscheiden (VERIFIKATION.md 185, 16 Minuten
# gemessen). `scripts/watchdog.sh` erkennt ihn an drei Merkmalen, die alle
# ausserhalb von Hermes liegen, wurde aber von KEINEM Skript aufgerufen — nur
# von Hand, also genau dann nicht, wenn man zusieht statt zu warten. Ohne den
# Wachhund beendet erst `--max-runtime` den Zustand: bei einer Karte mit
# 90-Minuten-Deckel sind das 90 Minuten Nichts, zum vollen Preis.
#
# Die Pumpe TÖTET nichts. Ein Fehlkill kostet die ganze Karte, und das ist
# zweimal real passiert (RUN-PROTOKOLL.md 430, 51 min und 30 min). Sie meldet
# und nennt den Befehl. 0 schaltet die Prüfung ab.
WACHHUND_TAKT="${ESF_WACHHUND_TAKT:-10}"

# Wie oft die Pumpe nach abgebrochenen Läufen sieht. Geprüft werden genau die
# vier Klassen, die Zeit kosten und nichts hinterlassen:
#
#   timed_out     am --max-runtime abgeschnitten
#   crashed       `pid … not alive`
#   gave_up       Retries oder Iterationsbudget erschöpft
#   spawn_failed  der Worker kam nie hoch
#
# `blocked` (Gate wartet), `review_requested` (Arbeit fertig, übergeben) und
# `scheduled` stehen bewusst NICHT dabei — das sind Normalzustände.
#
# Warum die Pumpe das braucht: Eine Karte, die ihre Retries verbrennt, sieht im
# Lagebild aus wie `running`. Gemessen (OPTIMIERUNG.md 1.1) sind das 387 von
# 1114 Minuten in beispiel-lauf-2 und 165 von 541 in beispiel-lauf-3 — rund ein
# Drittel der Kartenzeit, das erst nach dem Lauf im Board.json auffiel. Wer
# zusieht, soll es sehen, während es passiert.
LAGE_TAKT="${ESF_LAGE_TAKT:-5}"
GEMELDET=""

lage() {
    local json triage blocked
    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"

    triage="$(printf '%s' "$json" | jq -r '[.[] | select(.status=="triage")] | length')"
    if [ "$triage" -gt 0 ]; then
        printf '\n\033[33m⚠ %s Karte(n) in der TRIAGE — vermutlich block_loop_detected:\033[0m\n' "$triage"
        printf '%s' "$json" | jq -r '.[] | select(.status=="triage") | "   \(.id)  \(.title)"'
        printf '   Diese Karten fragen niemanden mehr. Nichts in Hermes warnt davor.\n'
    fi

    blocked="$(printf '%s' "$json" | jq -r '[.[] | select(.status=="blocked")] | length')"
    [ "$blocked" -gt 0 ] || return 0
    printf '\n\033[1m%s Gate(s) warten auf den CEO:\033[0m\n' "$blocked"
    printf '%s' "$json" | jq -r '.[] | select(.status=="blocked") | "   \(.id)  \(.title)"'
    printf '\nVollständige Vorlagen:  ./gate.sh\n'
}

abbrueche() { # braucht $json und $tick
    [ "$LAGE_TAKT" -gt 0 ] || return 0
    [ $((tick % LAGE_TAKT)) -eq 0 ] || return 0
    local id zeile neu=""
    # Nur die LAUFENDE Arbeit. Am 20.08.2026 beim Validierungslauf gemessen:
    # Auf einem Board mit 62 Karten — 61 davon `done` aus frueheren Sprints —
    # brauchte ein Bericht 29 Sekunden (0,47 s je `show`-Aufruf) und meldete die
    # Abbrueche aller alten Sprints als waeren sie neu. Die Pumpe beobachtet,
    # was JETZT passiert; was eine fertige Karte in ihrer Historie hat, ist
    # Sache von scripts/monitor.sh. Damit kostet der Bericht so viel, wie
    # gerade Arbeit offen ist.
    for id in $(printf '%s' "$json" | jq -r '.[]
            | select(.status=="running" or .status=="ready" or .status=="todo"
                     or .status=="blocked" or .status=="triage") | .id'); do
        zeile="$(hermes kanban --board "$BOARD" show "$id" --json 2>/dev/null \
            | jq -r '[.runs[]? | .outcome
                      | select(. == "timed_out" or . == "crashed"
                               or . == "gave_up" or . == "spawn_failed")]
                     | if length == 0 then empty
                       else (group_by(.) | map("\(.[0])=\(length)") | join(" ")) end' \
              2>/dev/null || true)"
        [ -n "$zeile" ] || continue
        # Nur NEUES melden — sonst steht derselbe Abbruch bei jedem Bericht
        # wieder da und der Leser hört nach dem dritten Mal auf hinzusehen.
        case " $GEMELDET " in *" $id:$zeile "*) continue ;; esac
        GEMELDET="$GEMELDET $id:$zeile"
        neu="$neu   abgebrochen: $id  $zeile
"
    done
    [ -n "$neu" ] || return 0
    printf '\n\033[31m⚠ Läufe ohne Ergebnis, neu seit dem letzten Bericht:\033[0m\n'
    printf '%s' "$neu"
    printf '   Diese Wanduhr ist bezahlt und hat nichts hinterlassen — und sie landet\n'
    printf '   als Istwert im Ledger, wo sie jede künftige Schätzung verzerrt.\n'
    printf '   Einzelheiten:  scripts/monitor.sh\n\n'
}

wachhund() {
    [ "$WACHHUND_TAKT" -gt 0 ] || return 0
    [ $((tick % WACHHUND_TAKT)) -eq 0 ] || return 0
    [ -x "$HERE/scripts/watchdog.sh" ] || {
        printf '   \033[33mWachhund fehlt (%s) — Hänger bleiben unentdeckt\033[0m\n' \
            "scripts/watchdog.sh"
        return 0
    }
    local aus
    if aus="$("$HERE/scripts/watchdog.sh" 2>&1)"; then
        printf '   Wachhund: keine hängenden Worker.\n'
    else
        printf '\n\033[33m⚠ Der Wachhund hat hängende Worker gefunden:\033[0m\n'
        printf '%s\n' "$aus" | sed 's/^/   /'
        printf '   Beenden mit:  scripts/watchdog.sh --kill\n'
        printf '   Der Dispatcher startet die Karte danach im Rahmen von --max-retries neu.\n\n'
    fi
}

DISPATCH_FEHLER=0

for tick in $(seq 1 "$MAX_TICKS"); do
    # `dispatch >/dev/null 2>&1 || true` stand hier bis zum 20.08.2026, und der
    # Fehlertext eines fehlgeschlagenen Dispatch existierte damit nie. Gemessen
    # in beispiel-lauf-2: einmal `spawn_failed` und einmal `gave_up`, beide mit
    # `workspace: git worktree add failed` — die Ursache stand in genau der
    # Ausgabe, die dieses `2>&1` verworfen hat. Die Pumpe tickte weiter, das
    # Lagebild blieb unverändert, und die Karte kam nie hoch.
    if dispatch_aus="$(hermes kanban --board "$BOARD" dispatch 2>&1)"; then
        DISPATCH_FEHLER=0
    else
        DISPATCH_FEHLER=$((DISPATCH_FEHLER + 1))
        printf '\n\033[31m⚠ Dispatch fehlgeschlagen (Tick %s, %s. Mal in Folge):\033[0m\n' \
            "$tick" "$DISPATCH_FEHLER"
        printf '%s\n' "$dispatch_aus" | sed 's/^/   /'
        # Fünf in Folge sind kein Ausrutscher. Eine Pumpe, die 120 Ticks lang
        # gegen einen kaputten Dispatcher tickt, verbraucht Wanduhr und meldet
        # am Ende "es ist noch Arbeit offen" — richtig, aber nutzlos.
        if [ "$DISPATCH_FEHLER" -ge 5 ]; then
            printf '\n\033[31mFünf fehlgeschlagene Dispatches in Folge — die Pumpe hält an.\033[0m\n'
            printf 'Häufigste Ursache: ein Worktree, dessen Karte nicht mehr auf dem Board ist.\n'
            printf 'Nachsehen mit:  scripts/monitor.sh   und   git -C <repo> worktree list\n'
            exit 1
        fi
    fi

    json="$(hermes kanban --board "$BOARD" list --json 2>/dev/null || echo '[]')"
    offen="$(printf '%s' "$json" | jq '[.[] | select(.status=="ready" or .status=="running" or .status=="todo")] | length')"
    lagebild="$(printf '%s' "$json" | jq -r 'group_by(.status) | map("\(.[0].status)=\(length)") | join("  ")')"

    printf '[%03d %s] %s\n' "$tick" "$(date '+%H:%M:%S')" "${lagebild:-leer}"

    wachhund
    abbrueche

    if [ "$offen" -eq 0 ]; then
        echo; echo "Nichts mehr in Arbeit — Pumpe beendet."
        hermes kanban --board "$BOARD" list
        lage
        exit 0
    fi
    sleep "$INTERVALL"
done

echo; echo "Maximale Tick-Zahl ($MAX_TICKS) erreicht, es ist noch Arbeit offen:"
hermes kanban --board "$BOARD" list
lage
