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
# DREI Kriterien, alle müssen zutreffen:
#   1. Der ganze PROZESSBAUM verbraucht ~keine CPU (unter der Schwelle) —
#      Baum, nicht Prozess: bei `pnpm test` rechnet das Enkelkind, nicht der
#      Worker.
#   2. Der Worker hat KEINEN Kindprozess — sonst fährt er gerade ein Kommando
#      und ist nicht untätig.
#   3. Er hält mindestens ein Socket auf CLOSE_WAIT und KEINE lebende
#      Verbindung.
#
# Kriterium 1 (als Baum) und Kriterium 2 wurden am 17.08.2026 nachgerüstet,
# nachdem dieses Skript zwei produktive Läufe getötet hatte. Die Einzelheiten
# stehen unten am Messpunkt. Der erste Entwurf tötete auf „0 % CPU + toter
# Socket" — und genau so sieht ein Worker aus, der `pnpm test` fährt.
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
        --urteil) shift; URTEIL_MODUS=1; set -- "$@"; break ;;
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

# Alle Nachkommen eines Prozesses, breitenweise. `pgrep -P` liefert nur die
# direkten Kinder; ein `pnpm test` hängt aber drei Ebenen tief (pnpm → node →
# vitest), und die CPU sitzt unten. Deshalb der Durchlauf.
baum_kinder() {
    local ebene="$1" alle="" naechste
    while [ -n "$ebene" ]; do
        naechste=""
        for p in $ebene; do
            for kind in $(pgrep -P "$p" 2>/dev/null); do
                naechste="$naechste $kind"
            done
        done
        # shellcheck disable=SC2086
        naechste="$(printf '%s' "$naechste" | tr -s ' ')"
        [ -n "$(printf '%s' "$naechste" | tr -d ' ')" ] || break
        alle="$alle $naechste"
        ebene="$naechste"
    done
    printf '%s' "$alle" | tr -s ' ' | sed 's/^ //;s/ $//'
}


# ---------------------------------------------------------------------------
# Das Urteil, als Funktion und damit pruefbar
# ---------------------------------------------------------------------------
#   urteil <baum_cpu> <tot> <lebend> <n_kinder> <dauer_min>
#     -> "toeten" | "verdacht" | "still"
#
# Herausgezogen am 20.08.2026, damit die Entscheidung ohne echte Prozesse und
# echte Sockets pruefbar ist: scripts/test-optimierung.sh 8 und
# scripts/watchdog.sh --selbsttest fahren sie gegen Zahlentripel.
urteil() { # baum_cpu tot lebend n_kinder dauer_min
    local baum_cpu="${1:-0}" tot="${2:-0}" lebend="${3:-0}" n_kinder="${4:-0}" dauer="${5:-0}" leerlauf
    leerlauf="$(awk -v c="$baum_cpu" -v s="$CPU_SCHWELLE" 'BEGIN{print (c < s) ? 1 : 0}')"
    if [ "$leerlauf" -eq 0 ]; then printf 'still\n'; return 0; fi
    if [ "$tot" -gt 0 ] && [ "$lebend" -eq 0 ] && [ "$n_kinder" -eq 0 ]; then
        printf 'toeten\n'; return 0
    fi
    if [ "$dauer" -ge "$MIN_MINUTEN" ]; then printf 'verdacht\n'; return 0; fi
    printf 'still\n'
}

if [ "${URTEIL_MODUS:-0}" = "1" ]; then
    urteil "$@"
    exit 0
fi

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

    # Der DRITTE Messwert, und er ist der wichtigste — nachgerüstet am
    # 17.08.2026, nachdem dieses Skript zwei produktive Läufe getötet hat.
    #
    # Was schiefging: Ein Worker, der ein langes lokales Kommando fährt
    # (`pnpm test` gemessen 41 s, ein Playwright-Lauf über eine Minute, im
    # Protokoll ein Kommando mit 194 s), sieht von aussen exakt wie ein Hänger
    # aus — er hält keine ESTABLISHED-Verbindung zum Modell, weil die letzte
    # HTTP-Antwort abgeschlossen ist, alte Pool-Sockets liegen auf CLOSE_WAIT,
    # und der Python-Prozess selbst verbraucht keine CPU, weil sein KIND
    # arbeitet. Genau die Signatur, auf die dieses Skript getötet hat.
    #
    # Real: Läufe 6 und 7 der Karte S1 F5 3/5 wurden so beendet, nachdem sie
    # den Umbau fertig hatten. Das agent.log zeigte 55 normale API-Aufrufe mit
    # 5-24 s Latenz und endete mit `reason=interrupted_by_user` — der Kill.
    #
    # Die Lehre ist allgemeiner als der Bugfix: Wer über ein System urteilt,
    # muss auch dessen Kinder ansehen. Ein Prozess mit arbeitenden Kindern ist
    # nicht untätig, egal was seine Sockets sagen.
    kinder="$(baum_kinder "$pid")"
    n_kinder="$(printf '%s' "$kinder" | tr ' ' '\n' | grep -c . || true)"
    baum_cpu="$cpu"
    if [ "${n_kinder:-0}" -gt 0 ]; then
        # shellcheck disable=SC2086
        baum_cpu="$(ps -o %cpu= -p $(printf '%s' "$kinder" | tr ' ' ',')"," 2>/dev/null \
                    | awk -v basis="${cpu:-0}" '{s+=$1} END{printf "%.1f", s + basis}')"
    fi

    verdacht=""; toeten=0
    case "$(urteil "${baum_cpu:-0}" "${tot:-0}" "${lebend:-0}" "${n_kinder:-0}" "${dauer_min:-0}")" in
        toeten)
            verdacht="${tot} tote(r) Socket, KEINE lebende Verbindung im Baum, ${n_kinder} Kindprozess(e), ${baum_cpu}% CPU im Baum, ${dauer_min} min"
            toeten=1 ;;
        verdacht)
            verdacht="${dauer_min} min bei ${baum_cpu}% CPU im Baum, ${lebend} lebende Verbindung(en), ${n_kinder} Kindprozess(e)" ;;
        *)  continue ;;
    esac
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
        printf '    → NICHT beendet: solange eine Verbindung steht oder ein Kind läuft,\n'
        printf '      ist eine lange Modellantwort bzw. ein laufendes Kommando die\n'
        printf '      wahrscheinlichere Erklärung. Dafür ist --max-runtime da.\n'
        printf '      Ein Fehlkill kostet die ganze Karte — zweimal real passiert.\n'
    fi
done

if [ "$gefunden" -eq 0 ]; then
    echo "Keine verdächtigen Worker."
    exit 0
fi
printf '\n%s verdächtige(r) Worker.\n' "$gefunden"
exit 1
