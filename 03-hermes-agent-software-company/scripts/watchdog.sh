#!/usr/bin/env bash
#
# ESF — Der Hänger-Wachhund
# =========================
#
#   scripts/watchdog.sh [--kill] [--min <minuten>]
#
# Sucht Worker, die laufen, aber nicht arbeiten. Ohne --kill wird nur gemeldet.
#
# Das Problem, mehrfach real gemessen (siehe VERIFIKATION.md):
#
#   Ein Worker verliert die Verbindung zum Modell-Provider, ohne es zu merken.
#   Das TCP-Socket steht auf CLOSE_WAIT — die Gegenseite hat geschlossen, der
#   Client wartet weiter. Von aussen ist der Zustand von echter Arbeit NICHT zu
#   unterscheiden: Das Board meldet `running`, die Heartbeats laufen brav
#   weiter. Nur zwei Dinge verraten ihn, und beide stehen ausserhalb von
#   Hermes: 0 % CPU über Minuten, und der Socket-Zustand.
#
#   Ohne diesen Wachhund beendet erst `--max-runtime` den Zustand. Bei einer
#   Analysekarte mit 45 Minuten Deckel heisst das 45 Minuten Nichts.
#
# Zwei Kriterien, beide müssen zutreffen:
#   1. Der Prozess verbraucht ~keine CPU (unter der Schwelle)
#   2. Er hält mindestens ein Socket auf CLOSE_WAIT
#      ODER er läuft länger als --min ohne jede CPU-Zeit
#
# Ein beendeter Worker ist kein Datenverlust: Der Dispatcher erkennt den
# Absturz (`outcome: "crashed"`) und startet die Karte im Rahmen von
# --max-retries neu. Belegt.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
KILL=0
MIN_MINUTEN=5
CPU_SCHWELLE=1.0

while [ $# -gt 0 ]; do
    case "$1" in
        --kill) KILL=1 ;;
        --min)  shift; MIN_MINUTEN="${1:-5}" ;;
        *) echo "Unbekannte Option '$1'"; exit 2 ;;
    esac
    shift
done

command -v jq   >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
command -v lsof >/dev/null || { echo "FEHLER: 'lsof' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

# ELAPSED von ps ist [[dd-]hh:]mm:ss — in Minuten umrechnen.
minuten_aus() {
    printf '%s' "$1" | awk -F'[-:]' '{
        if (NF==4)      print $1*1440 + $2*60 + $3
        else if (NF==3) print $1*60 + $2
        else if (NF==2) print $1
        else            print 0
    }'
}

gefunden=0
printf 'ESF Wachhund — %s  (CPU < %s%%, Mindestlaufzeit %s min)\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$CPU_SCHWELLE" "$MIN_MINUTEN"
printf '%.0s─' $(seq 1 74); echo

for id in $(k list --json 2>/dev/null | jq -r '.[] | select(.status=="running") | .id'); do
    pid="$(k show "$id" --json 2>/dev/null \
           | jq -r '[.events[] | select(.kind=="spawned")] | last | .payload.pid // empty')"
    [ -n "$pid" ] || continue
    ps -p "$pid" >/dev/null 2>&1 || continue

    werte="$(ps -o etime=,%cpu= -p "$pid" 2>/dev/null | tr -s ' ' | sed 's/^ //')"
    laufzeit="$(printf '%s' "$werte" | cut -d' ' -f1)"
    cpu="$(printf '%s' "$werte" | cut -d' ' -f2)"
    dauer_min="$(minuten_aus "$laufzeit")"

    # Beide Zahlen zählen, nicht nur die tote Verbindung: Ein Worker hält
    # oft mehrere Sockets. Ein einzelnes CLOSE_WAIT NEBEN einer lebenden
    # Verbindung ist ein Überbleibsel einer abgeschlossenen Anfrage, kein
    # Hänger — wer darauf tötet, wirft laufende Arbeit weg. Beim ersten Entwurf
    # dieses Skripts wäre genau das passiert.
    tot="$(lsof -p "$pid" -i -a 2>/dev/null | grep -c 'CLOSE_WAIT' || true)"
    lebend="$(lsof -p "$pid" -i -a 2>/dev/null | grep -c 'ESTABLISHED' || true)"

    # awk statt bc: bc ist auf macOS nicht überall da.
    leerlauf="$(awk -v c="${cpu:-0}" -v s="$CPU_SCHWELLE" 'BEGIN{print (c < s) ? 1 : 0}')"

    verdacht=""; toeten=0
    if [ "$leerlauf" -eq 1 ] && [ "${tot:-0}" -gt 0 ] && [ "${lebend:-0}" -eq 0 ]; then
        # Keine lebende Verbindung, keine CPU, aber ein toter Socket: Der
        # Worker wartet auf eine Antwort, die nie kommt. Das ist der Hänger.
        verdacht="${tot} tote(r) Socket, KEINE lebende Verbindung, ${cpu}% CPU"
        toeten=1
    elif [ "$leerlauf" -eq 1 ] && [ "${dauer_min:-0}" -ge "$MIN_MINUTEN" ]; then
        verdacht="${dauer_min} min bei ${cpu}% CPU, aber ${lebend} lebende Verbindung(en)"
    fi
    [ -n "$verdacht" ] || continue

    titel="$(k list --json | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    gefunden=$((gefunden + 1))
    printf '\n  %s  %s\n' "$id" "$titel"
    printf '    pid %s, läuft %s, %s\n' "$pid" "$laufzeit" "$verdacht"

    if [ "$toeten" -eq 1 ] && [ "$KILL" -eq 1 ]; then
        kill "$pid" 2>/dev/null && printf '    → beendet. Der Dispatcher startet die Karte neu.\n'
    elif [ "$toeten" -eq 1 ]; then
        printf '    → mit --kill beenden; der Dispatcher startet die Karte dann neu.\n'
    else
        printf '    → NICHT beendet: solange eine Verbindung steht, ist eine lange\n'
        printf '      Modellantwort die wahrscheinlichere Erklärung. Dafür ist\n'
        printf '      --max-runtime da. Ein Fehlkill kostet die ganze Karte.\n'
    fi
done

if [ "$gefunden" -eq 0 ]; then
    echo "Keine verdächtigen Worker."
    exit 0
fi
printf '\n%s verdächtige(r) Worker.\n' "$gefunden"
exit 1
