#!/usr/bin/env bash
#
# Story 1 — Solo Dev shipping a feature
# =====================================
#
# Legt die drei abhängigen Tasks an:
#
#     Design auth schema  →  Implement auth API endpoints  →  Write auth integration tests
#          backend-dev              backend-dev                        qa-dev
#
# Nur der erste Task startet in 'ready'. Die beiden anderen warten in 'todo',
# bis ihr jeweiliger Parent 'done' ist — das ist die Dependency-Promotion-Engine.
#
# Alle drei Worker arbeiten im selben echten Verzeichnis (./workspace), damit
# du hinterher siehst, was tatsächlich entstanden ist.
#
# Die Task-IDs werden nach ./task-ids.env geschrieben, damit die folgenden
# Schritte sie per `source task-ids.env` wiederverwenden können.
#
set -euo pipefail

BOARD="kanban-story-1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/workspace"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS" ] || { echo "FEHLER: $WS fehlt."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

echo "Arbeitsverzeichnis der Worker: $WS"
echo

# ---------------------------------------------------------------------------
# 1. Schema-Task — der einzige ohne Parent, startet daher sofort in 'ready'
# ---------------------------------------------------------------------------
SCHEMA=$(k create "Design auth schema" \
    --assignee backend-dev --tenant auth-project --priority 2 \
    --workspace "dir:$WS" \
    --body "Entwirf das Schema fuer users, sessions und refresh tokens des miniauth-Moduls.
Konkrete Aufgabe:
  1. Lies README.md im Arbeitsverzeichnis.
  2. Schreibe migrations/001_users.sql und migrations/002_sessions.sql
     mit gueltigem SQLite-DDL (CREATE TABLE ...).
  3. Halte es klein: users(id, email, pw_hash, created_at),
     sessions(id, user_id, jti, kind, expires_at)." \
    --json | jq -r .id)
echo "SCHEMA = $SCHEMA"

# ---------------------------------------------------------------------------
# 2. API-Task — Parent ist SCHEMA, startet daher in 'todo'
# ---------------------------------------------------------------------------
API=$(k create "Implement auth API endpoints" \
    --assignee backend-dev --tenant auth-project --priority 2 \
    --parent "$SCHEMA" \
    --workspace "dir:$WS" \
    --body "Implementiere die vier Endpunkte des miniauth-Moduls:
POST /register, POST /login, POST /refresh, POST /logout.
Konkrete Aufgabe:
  1. Schreibe auth/api.py: vier Funktionen register/login/refresh/logout,
     reines Python ohne Web-Framework, jede mit Docstring.
  2. Keine Datenbank-Verbindung noetig — arbeite gegen eine uebergebene
     sqlite3.Connection." \
    --json | jq -r .id)
echo "API    = $API"

# ---------------------------------------------------------------------------
# 3. Test-Task — Parent ist API, startet daher ebenfalls in 'todo'
# ---------------------------------------------------------------------------
TESTS=$(k create "Write auth integration tests" \
    --assignee qa-dev --tenant auth-project --priority 2 \
    --parent "$API" \
    --workspace "dir:$WS" \
    --body "Schreibe Integrationstests fuer das miniauth-Modul.
Konkrete Aufgabe:
  1. Schreibe tests/test_auth.py mit pytest-Tests fuer: Happy Path,
     falsches Passwort, abgelaufener Token, paralleler Refresh.
  2. Die Tests duerfen fehlschlagen — es geht um die Abdeckung, nicht um gruen." \
    --json | jq -r .id)
echo "TESTS  = $TESTS"

# ---------------------------------------------------------------------------
# IDs für die Folgeschritte sichern
# ---------------------------------------------------------------------------
cat > "$HERE/task-ids.env" <<EOF
# Erzeugt von create-tasks.sh — mit 'source task-ids.env' laden
export BOARD=$BOARD
export SCHEMA=$SCHEMA
export API=$API
export TESTS=$TESTS
EOF

echo
echo "IDs gesichert in $HERE/task-ids.env"
echo
echo "Board jetzt:"
k list
echo
echo "Erwartung: '$SCHEMA' steht auf ready, die beiden anderen auf todo."
