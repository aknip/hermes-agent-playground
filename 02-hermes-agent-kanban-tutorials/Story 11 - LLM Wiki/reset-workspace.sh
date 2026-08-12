#!/usr/bin/env bash
#
# Story 11 - LLM Wiki — Arbeitsverzeichnis zuruecksetzen
# =====================================================
#
# seed/       unveraenderliche Startdateien (Master, wird nie beschrieben)
# workspace/  Arbeitskopie — hier arbeiten die Worker
#
# Besonderheit dieser Story: workspace/wiki/ wird zu einem echten
# GIT-REPOSITORY gemacht, mit Branch 'main' und einem Initial-Commit. Das
# passiert HIER und nicht nur in setup.sh — sonst haette ein zweiter Durchlauf
# nach dem Zuruecksetzen kein Repository mehr, und bin/kb_git.py wuerde bei
# jedem Aufruf abweisen.
#
# Die Rohquellen unter sources/ liegen ABSICHTLICH ausserhalb des Repositorys:
# ein falscher Ingest ist damit immer zurueckzunehmen (git stellt die
# Wissensbasis her), und die Quellen sind unversehrt.
#
#   ./reset-workspace.sh          workspace/ aus seed/ neu aufbauen (+ git init)
#   ./reset-workspace.sh --diff   nur zeigen, was die Worker angefasst haben
#   ./reset-workspace.sh --git    nur den Git-Zustand der Wissensbasis zeigen
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED="$HERE/seed"
WS="$HERE/workspace"
WIKI="$WS/wiki"

[ -d "$SEED" ] || { echo "FEHLER: $SEED fehlt."; exit 1; }

# ---------------------------------------------------------------------------
# --diff : Was haben die Worker angefasst?
# ---------------------------------------------------------------------------
# .git muss ausgeschlossen werden, sonst besteht die Ausgabe zu 95 % aus
# Objekten und Refs und ist unlesbar.
if [ "${1:-}" = "--diff" ]; then
    if [ -d "$WS" ]; then
        diff -rq -x '.git' "$SEED" "$WS" 2>&1 | sed 's/^/  /' || true
        if [ -d "$WIKI/.git" ]; then
            echo
            echo "  Git-Zustand der Wissensbasis:"
            git -C "$WIKI" log --oneline -5 2>/dev/null | sed 's/^/    /' || true
            git -C "$WIKI" status --short 2>/dev/null | sed 's/^/    /' || true
        fi
    else
        echo "  workspace/ existiert nicht"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# --git : nur der Git-Zustand
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--git" ]; then
    [ -d "$WIKI/.git" ] || { echo "workspace/wiki ist kein Git-Repository."; exit 1; }
    python3 "$WS/bin/kb_git.py" --wiki "$WIKI" status
    exit 0
fi

# ---------------------------------------------------------------------------
# Neu aufbauen
# ---------------------------------------------------------------------------
command -v git >/dev/null || { echo "FEHLER: 'git' fehlt."; exit 1; }

rm -rf "$WS"
mkdir -p "$WS"
cp -R "$SEED"/. "$WS"/
chmod +x "$WS"/bin/*.py 2>/dev/null || true
count=$(find "$WS" -type f | wc -l | tr -d ' ')
printf 'workspace/ zurueckgesetzt (%s Startdateien aus seed/)\n' "$count"

# --- Die Wissensbasis zu einem Repository machen ---------------------------
# -c statt globaler Konfiguration: diese Story soll die Git-Identitaet des
# Nutzers nicht anfassen. --initial-branch=main, weil kb_git.py 'main' als
# Hauptbranch fuehrt (HAUPTBRANCH) und nicht raet.
git -C "$WIKI" init --quiet --initial-branch=main
git -C "$WIKI" add -A
git -C "$WIKI" \
    -c user.name="kb-seed" -c user.email="kb-seed@localhost" \
    commit --quiet -m "seed: Wissensbasis im Ausgangszustand

Sieben Seiten, ein Index, der Vertrag in AGENTS.md und das Ingest-Log.
Enthaelt absichtlich fuenf ERROR- und einen STALE-Befund — siehe seed/README.md."

printf 'workspace/wiki/ ist ein Git-Repository (Branch %s, %s Commit)\n' \
    "$(git -C "$WIKI" rev-parse --abbrev-ref HEAD)" \
    "$(git -C "$WIKI" rev-list --count HEAD)"

# --- Der Linter-Ausgangsbefund als Kontrolle ------------------------------
# Wenn diese Zahlen nicht stimmen, ist seed/ verstellt worden — und dann ist
# der einzige modellfreie Test dieser Story wertlos.
#
# --today ist hier PFLICHT und kein Testartefakt: die Freshness-Pruefung rechnet
# sonst gegen das Systemdatum, und dann wandern mit der Zeit immer mehr
# Seed-Seiten ueber die 180-Tage-Grenze. Die Kontrolle wuerde dann "seed/ wurde
# veraendert?" melden, obwohl nichts veraendert wurde. Das Datum ist der Stand,
# auf den seed/ geschrieben ist.
SEED_HEUTE="2026-08-11"
set +e
lint_out="$(python3 "$WS/bin/kb_lint.py" "$WIKI" --today "$SEED_HEUTE" --json 2>&1)"
set -e
errors=$(printf '%s' "$lint_out" | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["counts"]["ERROR"])' 2>/dev/null || echo "?")
stale=$(printf '%s' "$lint_out" | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["counts"]["STALE"])' 2>/dev/null || echo "?")
printf 'Ausgangsbefund des Linters (Bezug %s): %s ERROR, %s STALE' \
    "$SEED_HEUTE" "$errors" "$stale"
if [ "$errors" = "5" ] && [ "$stale" = "1" ]; then
    printf '  \033[32m(erwartet)\033[0m\n'
else
    printf '  \033[33m(erwartet waren 5 und 1 — seed/ wurde veraendert?)\033[0m\n'
fi
