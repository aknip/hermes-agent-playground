#!/usr/bin/env bash
#
# ESF — Der Merge-Riegel
# ======================
#
#     merge-riegel.sh <branch> [--dry-run] [--protokoll <datei>]
#
# Das einzige, was einen Feature-Branch nach main lässt. Kein Modell merged;
# dieses Skript merged oder verweigert. Der Unterschied ist nicht kosmetisch:
# Eine Regel in einer SOUL.md gilt, solange das Modell sie liest — ein Riegel
# im Code gilt immer, auch wenn ein Worker sich sehr sicher ist.
#
# Sechs Prüfungen, in dieser Reihenfolge, jede mit Abbruch:
#
#   1. Der Branch existiert und ist von main aus erreichbar zu mergen
#   2. Der Merge ist konfliktfrei (Probe im Trockenlauf, kein Schreiben)
#   3. Die geänderten Dateien sind sauber (biome auf DIESEN Dateien)
#   4. Typecheck der betroffenen Workspaces
#   5. Unit-Tests
#   6. Die VOLLE E2E-Suite ist grün — inklusive der Journey des Features
#
# Prüfung 3 lintet bewusst nur die geänderten Dateien: Das Ziel-Repo ist schon
# auf seinem Ausgangs-Commit rot (`biome ci .`, Bestandsschuld von Upstream).
# Ein Riegel, der an fremder Altlast scheitert, wird umgangen und ist dann
# gar kein Riegel mehr. Gemessen wird deshalb die Regression, nicht der
# Absolutstand.
#
# Exit 0 = gemerged (bzw. im Trockenlauf: würde mergen)
# Exit 1 = verweigert, mit Grund
# Exit 2 = Aufrufproblem
#
# Getestet mit: git 2.x, pnpm 10.x auf macOS
#
set -uo pipefail

BRANCH="${1:-}"
DRY=0
PROTOKOLL=""

shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY=1 ;;
        --protokoll) shift; PROTOKOLL="${1:-}" ;;
        *) echo "Unbekannte Option '$1'"; exit 2 ;;
    esac
    shift
done

[ -n "$BRANCH" ] || {
    echo "Aufruf: merge-riegel.sh <branch> [--dry-run] [--protokoll <datei>]"
    exit 2
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADENCE="$HERE/../workspace/company/cadence.yaml"
[ -f "$CADENCE" ] || CADENCE="$HERE/../seed/company/cadence.yaml"

# Das Produkt-Repo steht in cadence.yaml — nicht im Skript, nicht im Kopf.
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$CADENCE" | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$CADENCE" | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$CADENCE" | head -1)"
[ -d "$REPO/.git" ] || { echo "FEHLER: '$REPO' ist kein Git-Repo (cadence.yaml: produkt.repo)"; exit 2; }

cd "$REPO" || exit 2

zeile()  { printf '%s\n' "$*" | tee -a "${PROTOKOLL:-/dev/null}"; }
titel()  { zeile ""; zeile "── $* ──────────────────────────────────────────"; }
verweigert() {
    zeile ""
    zeile "✗ VERWEIGERT: $*"
    zeile ""
    zeile "Der Riegel merged nicht. Ursache beheben, dann erneut aufrufen."
    zeile "Nicht umgehen — 'git merge' von Hand ist ein Governance-Verstoss und"
    zeile "monitor.sh meldet einen Merge ohne Riegel-Protokoll."
    exit 1
}

if [ -n "$PROTOKOLL" ]; then
    mkdir -p "$(dirname "$PROTOKOLL")"
    : > "$PROTOKOLL"
fi

zeile "ESF Merge-Riegel — $(date '+%Y-%m-%d %H:%M:%S')"
zeile "Repo:   $REPO"
zeile "Branch: $BRANCH"
[ "$DRY" -eq 1 ] && zeile "Modus:  Trockenlauf (es wird nichts geschrieben)"

# ---------------------------------------------------------------------------
titel "1/6  Branch und Ausgangslage"
# ---------------------------------------------------------------------------
git rev-parse --verify --quiet "$BRANCH" >/dev/null \
    || verweigert "Branch '$BRANCH' existiert nicht."

# Ein schmutziger Arbeitsbaum macht jede folgende Messung wertlos: Man wüsste
# nicht, ob der grüne Test den Branch prüft oder etwas Unversioniertes.
if [ -n "$(git status --porcelain)" ]; then
    git status --short | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}"
    verweigert "Der Arbeitsbaum ist nicht sauber."
fi

AUSGANG="$(git rev-parse --abbrev-ref HEAD)"
[ "$AUSGANG" = "main" ] || git checkout -q main || verweigert "Wechsel nach main fehlgeschlagen."

BASIS="$(git merge-base main "$BRANCH")"
DATEIEN="$(git diff --name-only "$BASIS" "$BRANCH" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|json)$' || true)"
ANZAHL="$(git diff --name-only "$BASIS" "$BRANCH" | wc -l | tr -d ' ')"
zeile "  Basis:            $BASIS"
zeile "  Geänderte Dateien: $ANZAHL"
[ "$ANZAHL" -gt 0 ] || verweigert "Der Branch ändert nichts gegenüber main."
git diff --name-only "$BASIS" "$BRANCH" | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}" >/dev/null

# ---------------------------------------------------------------------------
titel "2/6  Konfliktfreiheit"
# ---------------------------------------------------------------------------
# --no-commit --no-ff prüft echt, hinterlässt aber einen Zustand — der wird in
# jedem Fall zurückgenommen. Erst danach wird richtig gemerged.
if git merge --no-commit --no-ff "$BRANCH" >/dev/null 2>&1; then
    git merge --abort 2>/dev/null || git reset -q --hard HEAD
    zeile "  konfliktfrei"
else
    git merge --abort 2>/dev/null || git reset -q --hard HEAD
    verweigert "Der Merge nach main hat Konflikte. Der Branch muss aktualisiert werden."
fi

# ---------------------------------------------------------------------------
titel "3/6  Linter auf den geänderten Dateien"
# ---------------------------------------------------------------------------
if [ -z "$DATEIEN" ]; then
    zeile "  keine lintbaren Dateien geändert — übersprungen"
else
    git checkout -q "$BRANCH" || verweigert "Wechsel auf '$BRANCH' fehlgeschlagen."
    # shellcheck disable=SC2086
    if pnpm exec biome check $DATEIEN > /tmp/esf-riegel-lint.$$ 2>&1; then
        zeile "  sauber ($(printf '%s\n' "$DATEIEN" | wc -l | tr -d ' ') Dateien)"
    else
        tail -30 /tmp/esf-riegel-lint.$$ | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}"
        rm -f /tmp/esf-riegel-lint.$$
        git checkout -q main
        verweigert "Der Linter beanstandet Dateien, die DIESER Branch geändert hat."
    fi
    rm -f /tmp/esf-riegel-lint.$$
    git checkout -q main
fi

# ---------------------------------------------------------------------------
titel "4/6  Typecheck"
# ---------------------------------------------------------------------------
git checkout -q "$BRANCH" || verweigert "Wechsel auf '$BRANCH' fehlgeschlagen."
if pnpm typecheck > /tmp/esf-riegel-tc.$$ 2>&1; then
    zeile "  grün"
else
    tail -25 /tmp/esf-riegel-tc.$$ | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}"
    rm -f /tmp/esf-riegel-tc.$$; git checkout -q main
    verweigert "Der Typecheck ist rot."
fi
rm -f /tmp/esf-riegel-tc.$$

# ---------------------------------------------------------------------------
titel "5/6  Unit-Tests"
# ---------------------------------------------------------------------------
if pnpm test > /tmp/esf-riegel-ut.$$ 2>&1; then
    zeile "  grün"
else
    tail -25 /tmp/esf-riegel-ut.$$ | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}"
    rm -f /tmp/esf-riegel-ut.$$; git checkout -q main
    verweigert "Die Unit-Tests sind rot."
fi
rm -f /tmp/esf-riegel-ut.$$

# ---------------------------------------------------------------------------
titel "6/6  Volle E2E-Suite"
# ---------------------------------------------------------------------------
# Die ganze Suite, nicht nur die Journey des Features: Der Riegel ist das
# Regressionsnetz. Ein Feature, das seine eigene Journey grün bekommt und drei
# fremde bricht, darf nicht durch.
zeile "  Vorbedingung: $E2E_VORBED"
eval "$E2E_VORBED" >/dev/null 2>&1 || zeile "  ⚠ Vorbedingung meldete einen Fehler — der Lauf zeigt gleich, ob es trägt"

if eval "$E2E_BEFEHL" > /tmp/esf-riegel-e2e.$$ 2>&1; then
    grep -E '^\s+[0-9]+ (passed|failed|skipped)' /tmp/esf-riegel-e2e.$$ | sed 's/^/  /' | tee -a "${PROTOKOLL:-/dev/null}"
    zeile "  grün"
else
    tail -30 /tmp/esf-riegel-e2e.$$ | sed 's/^/    /' | tee -a "${PROTOKOLL:-/dev/null}"
    rm -f /tmp/esf-riegel-e2e.$$; git checkout -q main
    verweigert "Die E2E-Suite ist rot. Kein Feature merged über ein rotes Regressionsnetz."
fi
rm -f /tmp/esf-riegel-e2e.$$
git checkout -q main

# ---------------------------------------------------------------------------
titel "Ergebnis"
# ---------------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
    zeile "✓ Alle sechs Prüfungen bestanden. Trockenlauf — es wurde nicht gemerged."
    exit 0
fi

if git merge --no-ff "$BRANCH" -m "Merge $BRANCH (Riegel bestanden)" >/dev/null 2>&1; then
    zeile "✓ Gemerged: $(git rev-parse --short HEAD)"
    zeile ""
    zeile "Der Worktree des Branches bleibt bestehen — der Reviewer braucht ihn"
    zeile "noch. Aufgeräumt wird beim Sprint-Abschluss."
    exit 0
fi
verweigert "Der Merge scheiterte trotz konfliktfreier Probe — Zustand von Hand prüfen."
