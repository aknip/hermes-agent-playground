#!/usr/bin/env bash
#
# ESF — Abschluss-Check Phase 2 (Begleiteter Betrieb)
# ==================================================
#
#   scripts/check-phase2.sh [--ohne-tests]
#
# Genau die drei Nachweise, die Kapitel 12 für Phase 2 verlangt — nicht mehr
# und nicht weniger:
#
#   1. Zwei Sprint-Reports mit (Schätzung, Ist)-PAAREN
#   2. Erstes Release durch das Release-Gate
#   3. Schätzgüte-Baseline im Controller-Report
#
# Der Unterschied zwischen "zwei Sprint-Reports" und "zwei Sprint-Reports mit
# Paaren" ist der ganze Nachweis. Ein Report mit Istwerten ohne Schätzung ist
# eine Zeitmessung; erst das Paar ist Kalibrierung. Deshalb zählt dieses Skript
# die Paare im LEDGER nach und liest sie nicht aus dem Report ab.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
LEDGER="$VAULT/ledger/estimates.jsonl"
OHNE_TESTS="${1:-}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }
kopf() { printf '\n\033[1m%s\033[0m\n' "$*"; }

printf '\n\033[1mAbschluss-Check Phase 2 — Begleiteter Betrieb\033[0m\n'
printf 'Kapitel 12: zwei Sprint-Reports mit (Schätzung, Ist)-Paaren · erstes\n'
printf 'Release durch das Release-Gate · Schätzgüte-Baseline im Controller-Report\n'
printf '%.0s═' $(seq 1 70); echo

# ===========================================================================
kopf "NACHWEIS 1 — Zwei Sprint-Reports mit (Schätzung, Ist)-Paaren"
# ===========================================================================
for s in s1 s2; do
    datei="$VAULT/reports/sprint-$s-report.html"
    if [ ! -f "$datei" ]; then
        nein "reports/sprint-$s-report.html fehlt"
        continue
    fi
    groesse="$(wc -c < "$datei" | tr -d ' ')"
    if [ "$groesse" -lt 800 ]; then
        nein "reports/sprint-$s-report.html ist mit $groesse Byte zu dünn"
        continue
    fi
    # Der Report muss die Paare FÜHREN, nicht nur erwähnen. Ein Quotient oder
    # ein p50/p90 im Dokument ist das Erkennungsmerkmal — ohne das ist es ein
    # Tätigkeitsbericht.
    bez="$(grep -c -iE 'p50|p90|Ist/Sch|Quotient|Schätzgüte' "$datei" || true)"
    if [ "$bez" -eq 0 ]; then
        nein "sprint-$s-report.html führt keine Schätz-Bezüge (p50/p90/Quotient)"
        info "Ein Report ohne Paare ist eine Zeitmessung, keine Kalibrierung."
    else
        ok "reports/sprint-$s-report.html ($groesse Byte, $bez Schätz-Bezüge)"
    fi
done

# Und jetzt die harte Zählung, unabhängig von dem, was in den Dokumenten steht.
echo
echo "   Paare im Ledger (gezählt, nicht abgelesen)"
if [ ! -s "$LEDGER" ]; then
    nein "ledger/estimates.jsonl ist leer"
else
    zeilen="$(grep -c . "$LEDGER" || true)"
    paare="$(jq -s '[.[] | select(.estimate != null and .estimate.wall_minutes != null
                                  and .estimate.wall_minutes.p50 != null
                                  and .actual.wall_minutes != null)] | length' "$LEDGER" 2>/dev/null || echo 0)"
    backfill="$(jq -s '[.[] | select(.backfill == true)] | length' "$LEDGER" 2>/dev/null || echo 0)"
    echo "     $zeilen Zeilen, davon $backfill nachgebucht (Phase 0/1) und $paare echte Paare"
    if [ "$paare" -ge 4 ]; then
        ok "$paare (Schätzung, Ist)-Paare — genug für eine Baseline je Klasse"
    elif [ "$paare" -gt 0 ]; then
        nein "nur $paare Paar(e) — zu wenig für zwei Sprint-Baselines"
        info "Erwartet werden mindestens vier: je Sprint Umsetzung und Review."
    else
        nein "kein einziges Paar — nur Istwerte"
        info "Ursache ist fast immer der zerrissene Handoff: die Schätzung"
        info "entstand auf der Estimator-Karte und wurde nicht ins metadata der"
        info "geschätzten Karte kopiert. scripts/check-sprint.sh benennt die Karte."
    fi

    echo
    echo "   Je Referenzklasse"
    jq -rs '[.[] | select(.estimate != null and .estimate.wall_minutes.p50 != null
                          and .actual.wall_minutes != null)]
            | group_by(.reference_class)
            | if length == 0 then "     (keine)"
              else (.[] | "     \(.[0].reference_class): n=\(length), Ist/Schätzung im Mittel " +
                          ((([.[] | .actual.wall_minutes / .estimate.wall_minutes.p50] | add / length) * 100 | round / 100) | tostring))
              end' "$LEDGER" 2>/dev/null || echo "     (nicht auswertbar)"
fi

# ===========================================================================
kopf "NACHWEIS 2 — Erstes Release durch das Release-Gate"
# ===========================================================================
# Delegiert an den Check, der dafür zuständig ist. Zwei Skripte, die dasselbe
# prüfen, driften auseinander; im ersten Lauf ist genau das vier Skripten
# passiert.
if [ -x "$HERE/check-release.sh" ]; then
    if "$HERE/check-release.sh" R1 ${OHNE_TESTS:+--ohne-tests} > /tmp/esf-p2-rel.$$ 2>&1; then
        ok "check-release.sh R1 ist grün"
        grep -E '✓' /tmp/esf-p2-rel.$$ | sed 's/^/    /' | head -20
    else
        nein "check-release.sh R1 ist rot:"
        grep -E '✗' /tmp/esf-p2-rel.$$ | sed 's/^/    /'
        info "Volle Ausgabe:  scripts/check-release.sh R1"
    fi
    rm -f /tmp/esf-p2-rel.$$
else
    nein "scripts/check-release.sh fehlt oder ist nicht ausführbar"
fi

# ===========================================================================
kopf "NACHWEIS 3 — Schätzgüte-Baseline im Controller-Report"
# ===========================================================================
gefunden=0
for s in s1 s2; do
    datei="$VAULT/reports/controller-$s.html"
    if [ ! -f "$datei" ]; then
        nein "reports/controller-$s.html fehlt"
        continue
    fi
    groesse="$(wc -c < "$datei" | tr -d ' ')"
    # Eine Baseline besteht aus drei Dingen, und alle drei müssen im Dokument
    # nachweisbar sein: die Klasse, der Vergleich, und die Benennung der
    # Kontaminationen. Das letzte ist das, was am leichtesten wegfällt.
    hat_klasse="$(grep -c -iE 'referenzklasse|reference_class|impl-worktree|review-repo|merge-repo' "$datei" || true)"
    hat_quotient="$(grep -c -iE 'Ist/Sch|Quotient|Faktor|p50|p90' "$datei" || true)"
    hat_kontam="$(grep -c -iE 'standby|Gate-Wartezeit|Kontamination|nicht gemessen' "$datei" || true)"

    mangel=""
    [ "$hat_klasse" -eq 0 ]   && mangel="$mangel keine-Referenzklassen"
    [ "$hat_quotient" -eq 0 ] && mangel="$mangel kein-Vergleich"
    [ "$hat_kontam" -eq 0 ]   && mangel="$mangel keine-Kontaminationen"

    if [ -n "$mangel" ]; then
        nein "controller-$s.html ($groesse Byte) unvollständig:$mangel"
        [ "$hat_kontam" -eq 0 ] && info "Ein unkontaminierter Durchschnitt kontaminierter Daten ist die selbstsicherste Form von falsch (SOUL esf-controller)."
    else
        ok "reports/controller-$s.html ($groesse Byte): Klassen, Vergleich und Kontaminationen benannt"
        gefunden=$((gefunden + 1))
    fi
done
if [ "$gefunden" -eq 0 ]; then
    nein "keine verwertbare Schätzgüte-Baseline"
fi

# Der Controller-Report von S2 ist der interessantere: Er ist der erste, der
# eine Verengung zeigen KANN, weil er zwei Sprints zum Vergleich hat.
if [ -f "$VAULT/reports/controller-s2.html" ]; then
    if grep -qiE 'S1|Sprint 1|verengt|schmaler|breiter|Vergleich zum' "$VAULT/reports/controller-s2.html"; then
        ok "controller-s2.html setzt sich zu S1 in Beziehung — die Baseline ist eine Reihe, kein Einzelwert"
    else
        info "controller-s2.html nennt S1 nicht. Kein Fehler, aber die Verengung"
        info "der Intervalle ist damit nicht gezeigt — der eigentliche Zweck der Schleife."
    fi
fi

# ===========================================================================
kopf "Begleitung: was der Mensch in dieser Phase getan hat"
# ===========================================================================
# Phase 2 heisst "begleiteter Betrieb": der Mensch liest mit und korrigiert.
# Das ist kein Nachweis mit Exit-Code, aber ohne diese Spur ist "begleitet"
# eine Behauptung. Deshalb: ausweisen, nicht bewerten.
if [ -d "$ESF/.git" ] || git -C "$ESF" rev-parse --git-dir >/dev/null 2>&1; then
    n="$(git -C "$ESF" log --oneline -- "$(basename "$ESF")" 2>/dev/null | wc -l | tr -d ' ')"
    [ "$n" = "0" ] && n="$(git -C "$ESF" log --oneline 2>/dev/null | wc -l | tr -d ' ')"
    info "Commits in der ESF-Installation: $n  (git log)"
fi
if [ -f "$ESF/RUN-PROTOKOLL.md" ]; then
    gates="$(grep -c -iE '^\s*(###|##)\s*.*[Gg]ate' "$ESF/RUN-PROTOKOLL.md" || true)"
    info "RUN-PROTOKOLL.md: $(wc -l < "$ESF/RUN-PROTOKOLL.md" | tr -d ' ') Zeilen, $gates Gate-Abschnitte"
else
    nein "RUN-PROTOKOLL.md fehlt — ein begleiteter Betrieb ohne Protokoll ist unbegleitet"
fi

printf '\n'
printf '%.0s═' $(seq 1 70); echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Phase 2 abgeschlossen.\033[0m\n'
    printf '  Damit ist die Vorbedingung für Phase 3 (Dauerbetrieb) erfüllt.\n'
    exit 0
fi
printf '\033[31m✗ Phase 2 noch nicht abgeschlossen — siehe die ✗ oben.\033[0m\n'
exit 1
