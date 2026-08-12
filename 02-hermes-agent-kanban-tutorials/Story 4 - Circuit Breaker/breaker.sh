#!/usr/bin/env bash
#
# Story 4a — Circuit Breaker UND Respawn-Sperre
# ============================================
#
# Teil A: Circuit Breaker
#   Ein Task, dessen Spawn immer scheitert, wird nach N aufeinanderfolgenden
#   Fehlversuchen endgültig blockiert (Outcome 'gave_up'), statt das Board
#   ewig zu beschäftigen.
#
# Teil B: Respawn-Sperre (steht in KEINER Doku)
#   Sieht der Dispatcher im Fehlertext ein Auth-/Quota-Muster
#   ("permission denied", "quota", "rate limit", "429", "403", "unauthorized",
#   "invalid api key" …), stuft er den Fehler als nicht-durch-Wiederholung-
#   lösbar ein und versucht es GAR NICHT erneut. Der Task bleibt auf 'ready'
#   und der Dispatcher meldet 'respawn_guarded'. Der Circuit Breaker wird in
#   diesem Fall nie erreicht.
#
# ⚠ ABWEICHUNG VON DER OFFIZIELLEN DOKU
#   Die Doku benutzt als Beispiel ein fehlendes AWS_ACCESS_KEY_ID und behauptet,
#   der Spawn scheitere daran mit einem RuntimeError. In 0.20.0 ist das NICHT
#   reproduzierbar: eine fehlende Umgebungsvariable verhindert den Spawn nicht.
#   Ein 'spawn_failed' entsteht an genau zwei Stellen im Dispatcher:
#     1. die Workspace-Auflösung wirft eine Exception, oder
#     2. der Prozess-Spawn selbst wirft eine Exception.
#   Beide Teile hier nutzen Fall 1 — und zwar mit zwei verschiedenen
#   Fehlertexten, um die beiden Schutzmechanismen auseinanderzuhalten.
#
# Beide Teile kosten KEINE Tokens: der Fehler tritt auf, bevor das Modell läuft.
#
set -euo pipefail

BOARD="kanban-story-4"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

hr() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ===========================================================================
# TEIL A — Circuit Breaker
# ===========================================================================
# /dev/null ist eine Gerätedatei, kein Verzeichnis. mkdir -p darunter wirft
# NotADirectoryError (Errno 20). Dieser Fehlertext enthält KEIN Auth-/Quota-
# Muster, also greift die Respawn-Sperre nicht und der Dispatcher versucht es
# jedes Mal erneut — bis der Breaker zuschlägt.
hr "TEIL A — Circuit Breaker (Fehler ist wiederholbar)"

DEPLOY=$(k create "Deploy to staging (Zielpfad ist kein Verzeichnis)" \
    --assignee deploy-bot --tenant ops \
    --workspace "dir:/dev/null/staging" \
    --max-retries 3 \
    --body "Deployt den aktuellen Stand nach Staging. Der konfigurierte
Release-Pfad ist kaputt — er zeigt nicht auf ein Verzeichnis. Der Dispatcher
kann den Workspace nicht anlegen und der Spawn schlaegt fehl." \
    --json | jq -r .id)

echo "DEPLOY = $DEPLOY   (--max-retries 3, trippt also beim 3. Fehlversuch)"
echo

for tick in 1 2 3 4; do
    echo "----- Dispatch-Tick $tick -----"
    k dispatch | sed -n 's/^\(Spawned\|Auto-blocked\).*/  &/p'
    status=$(k show "$DEPLOY" --json | jq -r .task.status)
    echo "  Task-Status danach: $status"
    [ "$status" = "blocked" ] && break
done

hr "Attempt-Historie"
k runs "$DEPLOY"

hr "Event-Log"
k show "$DEPLOY" --json | jq -r '.events[] | "  \(.kind)"'

cat <<TXT

Erwartet und real gemessen:
  Run 1  spawn_failed   (wiederholbar)
  Run 2  spawn_failed   (wiederholbar)
  Run 3  gave_up        (endgültig)  → Task-Status 'blocked'
  Events: created → claimed → spawn_failed → claimed → spawn_failed
          → claimed → gave_up

Ohne --max-retries gilt kanban.failure_limit aus der config.yaml (Default 2).
Erst ein Mensch bringt den Task zurück:
  hermes kanban --board $BOARD unblock $DEPLOY
TXT

# ===========================================================================
# TEIL B — Respawn-Sperre
# ===========================================================================
hr "TEIL B — Respawn-Sperre (Fehler gilt als NICHT wiederholbar)"

UNREACHABLE="/Volumes/deploy-share/staging"

if mkdir -p "$UNREACHABLE" 2>/dev/null; then
    echo "Übersprungen: '$UNREACHABLE' liess sich anlegen, auf diesem System"
    echo "ist /Volumes schreibbar. Teil B braucht einen Pfad, dessen Fehlertext"
    echo "'Permission denied' enthält."
    rmdir "$UNREACHABLE" 2>/dev/null || true
else
    echo "Szenario: das Deploy-Share ist nicht gemountet."
    echo "  → mkdir liefert 'Permission denied' → Auth-/Quota-Muster erkannt"
    echo

    GUARDED=$(k create "Deploy to staging (Netzlaufwerk nicht gemountet)" \
        --assignee deploy-bot --tenant ops \
        --workspace "dir:$UNREACHABLE" \
        --max-retries 3 \
        --body "Deployt nach Staging. Das Release-Verzeichnis liegt auf dem
Netzlaufwerk deploy-share, das nicht gemountet ist." \
        --json | jq -r .id)
    echo "GUARDED = $GUARDED"
    echo

    for tick in 1 2 3; do
        echo "----- Dispatch-Tick $tick -----"
        k dispatch | sed -n 's/^\(Spawned\|Auto-blocked\).*/  &/p'
        echo "  Task-Status danach: $(k show "$GUARDED" --json | jq -r .task.status)"
    done

    hr "Attempt-Historie"
    k runs "$GUARDED"

    hr "Event-Log"
    k show "$GUARDED" --json | jq -r '.events[] | "  \(.kind)"'

    cat <<TXT

Erwartet und real gemessen:
  Run 1  spawn_failed  ✖ workspace: [Errno 13] Permission denied: '/Volumes/deploy-share'
  danach nur noch Events 'respawn_guarded' — KEIN weiterer Versuch,
  KEIN 'gave_up', Task-Status bleibt 'ready'.

Das ist die gefährlichere Fehlerart: der Task sieht im Board aus wie
"wartet auf den Dispatcher", wird aber nie wieder angefasst. So findest du das:
  hermes kanban --board $BOARD diagnostics
  hermes kanban --board $BOARD show $GUARDED     # Events ansehen
TXT
fi

cat > "$HERE/task-ids-breaker.env" <<EOF
export BOARD=$BOARD
export DEPLOY=$DEPLOY
${GUARDED:+export GUARDED=$GUARDED}
EOF

hr "IDs gesichert in $HERE/task-ids-breaker.env"
