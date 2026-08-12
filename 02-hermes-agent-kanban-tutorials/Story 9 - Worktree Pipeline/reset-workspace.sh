#!/usr/bin/env bash
#
# Story 9 — Arbeitsverzeichnis zuruecksetzen (inklusive Git-Repository)
# =====================================================================
#
# seed/       unveraenderliche Startdateien
# workspace/  Arbeitskopie — hier arbeiten die Worker
#
# Diese Story braucht in workspace/repo/ ein ECHTES Git-Repository: ein
# Worktree kann nur an einem Repo haengen. Deshalb macht dieses Skript nach
# dem Kopieren ein `git init` und einen Ausgangscommit.
#
#   ./reset-workspace.sh          workspace/ neu aufbauen + git init
#   ./reset-workspace.sh --diff   nur zeigen, was sich unterscheidet
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED="$HERE/seed"
WS="$HERE/workspace"
REPO="$WS/repo"

[ -d "$SEED" ] || { echo "FEHLER: $SEED fehlt."; exit 1; }

if [ "${1:-}" = "--diff" ]; then
    if [ -d "$WS" ]; then
        # .git und .worktrees sind Laufzeitzustand, kein Arbeitsergebnis.
        diff -rq -x .git -x .worktrees "$SEED" "$WS" 2>&1 | sed 's/^/  /' || true
        if [ -d "$REPO/.git" ]; then
            echo "  --- Branches im Repo ---"
            git -C "$REPO" branch -a 2>/dev/null | sed 's/^/  /'
            echo "  --- Worktrees ---"
            git -C "$REPO" worktree list 2>/dev/null | sed 's/^/  /'
        fi
    else
        echo "  workspace/ existiert nicht"
    fi
    exit 0
fi

command -v git >/dev/null || { echo "FEHLER: 'git' fehlt."; exit 1; }

# Bestehende Worktrees sauber loesen, sonst bleiben Verweise im Repo zurueck.
if [ -d "$REPO/.git" ]; then
    git -C "$REPO" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print $2}' \
        | while read -r wt; do
            [ "$wt" = "$REPO" ] && continue
            git -C "$REPO" worktree remove --force "$wt" 2>/dev/null || true
        done
fi

rm -rf "$WS"
mkdir -p "$WS"
cp -R "$SEED"/. "$WS"/

git -C "$REPO" init -q -b main
git -C "$REPO" add -A
git -C "$REPO" -c user.email="tutorial@example.invalid" \
               -c user.name="Kanban Tutorial" \
               commit -q -m "minibuch: Ausgangsstand"

count=$(find "$WS" -type f -not -path "*/.git/*" | wc -l | tr -d ' ')
printf 'workspace/ zurueckgesetzt (%s Startdateien aus seed/)\n' "$count"
printf 'Git-Repo in workspace/repo auf Branch %s, Commit %s\n' \
    "$(git -C "$REPO" branch --show-current)" \
    "$(git -C "$REPO" rev-parse --short HEAD)"
