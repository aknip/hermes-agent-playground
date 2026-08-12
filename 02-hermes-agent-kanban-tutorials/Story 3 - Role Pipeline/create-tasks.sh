#!/usr/bin/env bash
#
# Story 3 — Role pipeline with retry
# ==================================
#
#     Spec: password reset flow  →  Implement password reset flow  →  Review password reset PR
#               pm                          backend-dev                      reviewer
#
# Der mittlere Task wird im ersten Run BLOCKIERT und nach einem
# `hermes kanban unblock` in einem zweiten Run abgeschlossen. Ausgelöst wird
# das durch eine harte Regel im Task-Body (siehe workspace/README.md):
# solange kein früherer Versuch im worker_context steht, blockiert der Worker.
#
set -euo pipefail

BOARD="kanban-story-3"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/workspace"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS" ] || { echo "FEHLER: $WS fehlt."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

echo "Arbeitsverzeichnis der Worker: $WS"
echo

# ---------------------------------------------------------------------------
# 1. Spec — Product Manager
# ---------------------------------------------------------------------------
SPEC=$(k create "Spec: password reset flow" \
    --assignee pm --tenant reset-feature --priority 1 \
    --workspace "dir:$WS" \
    --body "Schreibe die Spezifikation fuer den Passwort-Reset des miniauth-Moduls.
  1. Lies README.md im Arbeitsverzeichnis.
  2. Schreibe spec/password-reset.md mit den Abschnitten Ziel, Ablauf
     (POST /forgot-password, GET /reset/:token, POST /reset) und
     Akzeptanzkriterien.
  3. Mindestens drei testbare Akzeptanzkriterien.
Schliesse mit kanban_complete ab. Wichtig: lege die Akzeptanzkriterien
ZUSAETZLICH als Liste in metadata unter dem Schluessel 'acceptance' ab —
der Engineer-Worker liest genau dieses Feld aus dem Parent-Handoff." \
    --json | jq -r .id)
echo "SPEC   = $SPEC"

# ---------------------------------------------------------------------------
# 2. Implementierung — Engineer. Blockiert im ersten Run.
# ---------------------------------------------------------------------------
IMPL=$(k create "Implement password reset flow" \
    --assignee backend-dev --tenant reset-feature --priority 1 \
    --parent "$SPEC" \
    --workspace "dir:$WS" \
    --body "Implementiere den Passwort-Reset in auth/reset.py.

REGEL FUER DEN ERSTEN VERSUCH:
Sieh im worker_context nach, ob es bereits frühere Versuche ('prior attempts')
zu diesem Task gibt.
  • NEIN, dies ist der erste Versuch:
      Implementiere die drei Funktionen forgot_password, render_reset_form und
      apply_reset in auth/reset.py gemaess der Akzeptanzkriterien aus dem
      Parent-Handoff. Lies DANACH die Datei REVIEW-FEEDBACK.md. Sie enthaelt
      offene Review-Punkte. Rufe kanban_block(reason=...) auf und gib als
      reason die offenen Punkte aus REVIEW-FEEDBACK.md wieder. Rufe NICHT
      kanban_complete auf.
  • JA, es gibt einen früheren, blockierten Versuch:
      Lies den Block-Grund aus dem worker_context. Arbeite GENAU diese Punkte
      in auth/reset.py ab (Passwortstaerke-Pruefung, Token nur einmal
      einloesbar). Setze anschliessend in REVIEW-FEEDBACK.md den Status auf
      ERLEDIGT. Schliesse dann mit kanban_complete ab,
      metadata = {\"changed_files\": [...], \"review_iteration\": 2}." \
    --json | jq -r .id)
echo "IMPL   = $IMPL"

# ---------------------------------------------------------------------------
# 3. Review — Reviewer
# ---------------------------------------------------------------------------
REVIEW=$(k create "Review password reset PR" \
    --assignee reviewer --tenant reset-feature --priority 1 \
    --parent "$IMPL" \
    --workspace "dir:$WS" \
    --body "Reviewe die Implementierung des Passwort-Resets.
  1. kanban_show() liefert dir im worker_context das Ergebnis des
     Engineer-Tasks samt geaenderten Dateien.
  2. Pruefe auth/reset.py gegen die Akzeptanzkriterien aus spec/password-reset.md
     und gegen die beiden Punkte aus REVIEW-FEEDBACK.md.
  3. Schreibe dein Urteil nach REVIEW-VERDICT.md: entweder APPROVED mit
     Begruendung oder CHANGES REQUESTED mit konkreter Liste.
Schliesse mit kanban_complete ab, metadata = {\"verdict\": \"approved\"|\"changes_requested\"}." \
    --json | jq -r .id)
echo "REVIEW = $REVIEW"

cat > "$HERE/task-ids.env" <<EOF
# Erzeugt von create-tasks.sh — mit 'source task-ids.env' laden
export BOARD=$BOARD
export SPEC=$SPEC
export IMPL=$IMPL
export REVIEW=$REVIEW
EOF

echo
echo "IDs gesichert in $HERE/task-ids.env"
echo
k list --tenant reset-feature
echo
echo "Erwartung: '$SPEC' auf ready, die beiden anderen auf todo."
