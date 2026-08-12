#!/usr/bin/env bash
#
# Story 4b — Crash Recovery
# =========================
#
# Zeigt, was passiert, wenn ein Worker-Prozess MITTEN in der Arbeit stirbt
# (OOM-Kill, segfault, `kill -9`, Neustart des Rechners).
#
# Ablauf:
#   1. Task anlegen, der lange genug läuft, um ihn zu erwischen
#   2. Dispatch → Worker startet, PID landet im Event-Log
#   3. `kill -9 <pid>` — der Crash
#   4. Dispatch → Dispatcher prüft kill(pid, 0), erkennt die toten PID,
#      schließt Run 1 mit Outcome 'crashed' und gibt den Claim frei
#   5. Dispatch → Run 2 startet frisch; im worker_context steht der Crash
#      des ersten Versuchs
#
# Die Doku beschreibt als Beispiel einen OOM-Kill bei 2,3 Mio. Zeilen. Ein
# echter OOM lässt sich nicht verlässlich herbeiführen — `kill -9` löst
# exakt denselben Erkennungspfad im Dispatcher aus (tote PID) und ist
# reproduzierbar. Das ist die einzige Abweichung.
#
set -euo pipefail

BOARD="kanban-story-4"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/workspace"
KILL_AFTER="${1:-25}"   # Sekunden nach dem Spawn bis zum kill -9

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -f "$WS/data/events.csv" ] || { echo "FEHLER: $WS/data/events.csv fehlt."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

# ---------------------------------------------------------------------------
# 1. Task anlegen
# ---------------------------------------------------------------------------
MIG=$(k create "Migration: events.csv in Kategorie-Reports zerlegen" \
    --assignee backend-dev --tenant ops \
    --workspace "dir:$WS" \
    --max-retries 3 \
    --body "Zerlege data/events.csv in einen Report pro Kategorie.
  1. Lies data/events.csv (420 Zeilen, Spalten: event_id, ts, category,
     duration_ms, outcome, account).
  2. Schreibe fuer JEDE der zehn Kategorien eine Datei
     reports/<category>.md mit: Anzahl Events, Anzahl je outcome,
     durchschnittliche und maximale duration_ms, Anzahl verschiedener accounts.
  3. Arbeite die Kategorien EINZELN und NACHEINANDER ab und schreibe jede
     Datei sofort, bevor du mit der naechsten anfaengst — so bleibt bei einem
     Abbruch der Teilfortschritt erhalten.
  4. Schreibe zum Schluss reports/SUMMARY.md mit einer Tabelle aller Kategorien.
Falls im worker_context ein frueherer, abgestuerzter Versuch steht: pruefe
zuerst, welche Dateien in reports/ schon existieren, und mache dort weiter
statt von vorne anzufangen. Erwaehne diese Strategie im metadata-Feld
unter dem Schluessel 'strategy'.
Schliesse mit kanban_complete ab." \
    --json | jq -r .id)

echo "MIG = $MIG"
cat > "$HERE/task-ids-crash.env" <<EOF
export BOARD=$BOARD
export MIG=$MIG
EOF

# ---------------------------------------------------------------------------
# 2. Dispatch und auf die Worker-PID warten
# ---------------------------------------------------------------------------
echo
echo "----- Dispatch: Worker starten -----"
k dispatch | sed 's/^/  /'

PID=""
for _ in $(seq 1 20); do
    PID=$(k show "$MIG" --json | jq -r '[.events[] | select(.kind=="spawned") | .payload.pid] | last // empty')
    [ -n "$PID" ] && [ "$PID" != "null" ] && break
    sleep 2
done

[ -n "$PID" ] || { echo "FEHLER: keine Worker-PID im Event-Log gefunden."; exit 1; }
echo "  Worker-PID laut Event-Log: $PID"

# ---------------------------------------------------------------------------
# 3. Der Crash
# ---------------------------------------------------------------------------
echo
echo "----- Warte ${KILL_AFTER}s, damit der Worker echte Arbeit anfaengt -----"
sleep "$KILL_AFTER"
echo "  Bereits erzeugt:"
ls -1 "$WS/reports" | sed 's/^/    /'
echo
echo "----- kill -9 $PID  (der simulierte Crash) -----"
if kill -9 "$PID" 2>/dev/null; then
    echo "  PID $PID abgeschossen."
else
    echo "  PID $PID lebte nicht mehr — der Worker war schon fertig."
    echo "  Starte das Skript mit kuerzerer Wartezeit neu, z. B.:  ./crash.sh 10"
fi
sleep 3

# ---------------------------------------------------------------------------
# 4. Dispatch erkennt die tote PID
# ---------------------------------------------------------------------------
echo
echo "----- Dispatch: tote PID erkennen -----"
k dispatch | sed 's/^/  /'
echo "  Status: $(k show "$MIG" --json | jq -r .task.status)"

# ---------------------------------------------------------------------------
# 5. Zweiter Versuch
# ---------------------------------------------------------------------------
echo
echo "----- Dispatch: zweiten Versuch starten -----"
k dispatch | sed 's/^/  /'

echo
echo "----- Warte auf Abschluss (max. 6 Min) -----"
for _ in $(seq 1 24); do
    st=$(k show "$MIG" --json | jq -r .task.status)
    echo "  Status: $st"
    case "$st" in done|blocked) break ;; esac
    k dispatch >/dev/null 2>&1 || true
    sleep 15
done

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
echo
echo "===== Attempt-Historie ====="
k runs "$MIG"
echo
echo "===== Event-Log ====="
k show "$MIG" --json | jq -r '.events[] | "  [run \(.run_id // "-")] \(.kind)"'
echo
echo "===== Erzeugte Reports ====="
ls -1 "$WS/reports"
echo
echo "Erwartung: Run 1 mit Outcome 'crashed', Run 2 mit 'completed'."
