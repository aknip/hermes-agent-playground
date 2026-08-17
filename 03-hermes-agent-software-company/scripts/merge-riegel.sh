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
# Prüfung 3 lintet bewusst nur die geänderten Dateien, nicht das ganze Repo:
# Gemessen wird die Regression, nicht der Absolutstand. Ein Riegel, der an
# fremder Altlast scheitert, wird umgangen und ist dann gar kein Riegel mehr —
# und `biome ci .` über alles meldet im Ziel-Repo 78 Warnungen plus eine
# Schema-Version-Abweichung in biome.json, an denen keine Feature-Karte etwas
# ändern kann.
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

# ---------------------------------------------------------------------------
# Der Riegel serialisiert seine eigenen Prüfungen — sonst schlägt er sich selbst
# ---------------------------------------------------------------------------
# Real gemessen am 17.08.2026 beim ersten echten Merge (R1-F5):
#
#   Branch allein, volle Unit-Suite   374/374 grün, import  6,81 s
#   main allein, volle Unit-Suite     374/374 grün
#   Riegel-Lauf                       2 rot,          import 107,74 s
#
# Faktor 16 in der Importzeit. `pnpm test` ist `turbo test`, und turbo fährt die
# Paket-Tasks parallel; kommt die Last der übrigen ESF-Worker dazu, dauert der
# Modulimport so lange, dass tests/api/mcp-internal-api-url.test.ts an einer
# Aufrufzahl scheitert (`toHaveBeenCalledOnce`, bekommt 2) — ein Retry im
# langsamen Pfad feuert einen zweiten Aufruf.
#
# Das ist der unangenehme Teil: Der Riegel erzeugt die Last, an der er scheitert,
# und sein Urteil hing damit davon ab, wie viele andere Karten gerade liefen.
# „Code entscheidet, kein Modell" trägt nur, wenn der Code deterministisch ist.
# Ein Riegel, dessen Ergebnis vom Betriebszustand abhängt, ist ein Würfel mit
# Protokoll.
#
# Deshalb: Prüfungen, die durch turbo laufen, bekommen `--concurrency=1`.
# Das kostet Minuten je Merge und ist es wert — der Riegel läuft einmal je
# Feature, nicht einmal je Commit. Wer die Serialisierung nicht will, setzt
# ESF_RIEGEL_SERIELL=0.
SERIELL="${ESF_RIEGEL_SERIELL:-1}"
turbo_seriell() { # <pnpm-skript>
    if [ "$SERIELL" = "1" ] && grep -q "\"$1\": *\"turbo " "$REPO/package.json" 2>/dev/null; then
        printf 'pnpm exec turbo %s --concurrency=1' "$1"
    else
        printf 'pnpm %s' "$1"
    fi
}
TYPECHECK_BEFEHL="$(turbo_seriell typecheck)"
UNIT_BEFEHL="$(turbo_seriell test)"

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

# Bei einem Fehlschlag wandert die VOLLSTÄNDIGE Ausgabe ins Protokoll und nur
# ein Auszug auf den Bildschirm. Das Protokoll ist die Akte, die archiviert und
# später gelesen wird — ein abgeschnittener Stacktrace darin macht den Befund
# unbrauchbar, und genau das ist einmal passiert.
volltext() { # <logdatei> <zeilen-fuer-den-bildschirm>
    local log="$1" zeilen="$2"
    if [ -n "$PROTOKOLL" ]; then
        {
            printf '\n───── vollständige Ausgabe ─────\n'
            cat "$log"
            printf '───── Ende ─────\n'
        } >> "$PROTOKOLL"
    fi
    tail -"$zeilen" "$log" | sed 's/^/    /'
}

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
# --no-commit --no-ff mergt wirklich, schreibt aber noch keinen Commit. Der
# Zustand bleibt ab hier STEHEN — die Prüfungen 3-6 laufen gegen ihn.
# (Ihn hier zurückzunehmen und danach den Branch auschecken zu wollen war der
# ursprüngliche Fehler: Die Prüfungen liefen dann gegen main und waren wertlos.)
if git merge --no-commit --no-ff "$BRANCH" >/dev/null 2>&1; then
    zeile "  konfliktfrei — der Merge bleibt jetzt stehen und wird geprüft"
else
    git merge --abort 2>/dev/null || git reset -q --hard HEAD
    verweigert "Der Merge nach main hat Konflikte. Der Branch muss aktualisiert werden."
fi

# Ab hier steht im Arbeitsbaum das ERGEBNIS des Merges, nicht der Branch.
# Zwei Gründe, und der zweite ist der wichtigere:
#
#   1. Der Branch lässt sich gar nicht auschecken. Er ist im Worktree des
#      Entwicklers ausgecheckt, und Git erlaubt einen Branch nur in genau einem
#      Worktree — `git checkout feat/…` im Hauptbaum scheitert mit "already
#      used by worktree at …". Real passiert, siehe VERIFIKATION.md.
#   2. Geprüft gehört ohnehin, was auf main LANDET, nicht der Branch für sich.
#      Ein Branch, der isoliert grün ist und nach dem Merge rot, ist genau der
#      Fall, den ein Regressionsnetz fangen soll.
#
# Ab jetzt räumt jeder Ausstieg den Merge weg.
aufraeumen() { git merge --abort 2>/dev/null || git reset -q --hard HEAD; }
verweigert_und_aufraeumen() { aufraeumen; verweigert "$@"; }

# ---------------------------------------------------------------------------
titel "3/6  Linter auf den geänderten Dateien"
# ---------------------------------------------------------------------------
if [ -z "$DATEIEN" ]; then
    zeile "  keine lintbaren Dateien geändert — übersprungen"
else
    # shellcheck disable=SC2086
    if pnpm exec biome check $DATEIEN > /tmp/esf-riegel-lint.$$ 2>&1; then
        zeile "  sauber ($(printf '%s\n' "$DATEIEN" | wc -l | tr -d ' ') Dateien)"
        rm -f /tmp/esf-riegel-lint.$$
    else
        volltext /tmp/esf-riegel-lint.$$ 30
        rm -f /tmp/esf-riegel-lint.$$
        verweigert_und_aufraeumen "Der Linter beanstandet Dateien, die DIESER Branch geändert hat."
    fi
fi

# ---------------------------------------------------------------------------
titel "4/6  Typecheck"
# ---------------------------------------------------------------------------
zeile "  Befehl: $TYPECHECK_BEFEHL"
if eval "$TYPECHECK_BEFEHL" > /tmp/esf-riegel-tc.$$ 2>&1; then
    zeile "  grün"
    rm -f /tmp/esf-riegel-tc.$$
else
    volltext /tmp/esf-riegel-tc.$$ 25
    rm -f /tmp/esf-riegel-tc.$$
    verweigert_und_aufraeumen "Der Typecheck ist rot."
fi

# ---------------------------------------------------------------------------
titel "5/6  Unit-Tests"
# ---------------------------------------------------------------------------
zeile "  Befehl: $UNIT_BEFEHL"
if eval "$UNIT_BEFEHL" > /tmp/esf-riegel-ut.$$ 2>&1; then
    zeile "  grün"
    rm -f /tmp/esf-riegel-ut.$$
else
    volltext /tmp/esf-riegel-ut.$$ 25
    rm -f /tmp/esf-riegel-ut.$$
    verweigert_und_aufraeumen "Die Unit-Tests sind rot."
fi

# ---------------------------------------------------------------------------
titel "6/6  Volle E2E-Suite"
# ---------------------------------------------------------------------------
# Die ganze Suite, nicht nur die Journey des Features: Der Riegel ist das
# Regressionsnetz. Ein Feature, das seine eigene Journey grün bekommt und drei
# fremde bricht, darf nicht durch.
zeile "  Vorbedingung: $E2E_VORBED"
eval "$E2E_VORBED" >/dev/null 2>&1 || zeile "  ⚠ Vorbedingung meldete einen Fehler — der Lauf zeigt gleich, ob es trägt"

if eval "$E2E_BEFEHL" > /tmp/esf-riegel-e2e.$$ 2>&1; then
    grep -E '[0-9]+ (passed|failed|skipped)' /tmp/esf-riegel-e2e.$$ | tail -2 | sed 's/^/  /' | tee -a "${PROTOKOLL:-/dev/null}"
    zeile "  grün"
    rm -f /tmp/esf-riegel-e2e.$$
else
    volltext /tmp/esf-riegel-e2e.$$ 30
    rm -f /tmp/esf-riegel-e2e.$$
    verweigert_und_aufraeumen "Die E2E-Suite ist rot. Kein Feature merged über ein rotes Regressionsnetz."
fi

# ---------------------------------------------------------------------------
titel "Ergebnis"
# ---------------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
    aufraeumen
    zeile "✓ Alle sechs Prüfungen bestanden. Trockenlauf — der Merge wurde zurückgenommen."
    exit 0
fi

# Der Merge steht bereits im Arbeitsbaum und ist geprüft. Jetzt nur noch
# festschreiben — kein zweiter Merge-Versuch, kein zweites Risiko.
if git commit -q --no-verify -m "Merge $BRANCH (Riegel bestanden)" 2>/dev/null; then
    zeile "✓ Gemerged: $(git rev-parse --short HEAD)"
    zeile ""
    zeile "Der Worktree des Branches bleibt bestehen — der Reviewer braucht ihn"
    zeile "noch. Aufgeräumt wird beim Sprint-Abschluss."
    exit 0
fi
verweigert_und_aufraeumen "Das Festschreiben des geprüften Merges scheiterte — Zustand von Hand prüfen."
