#!/usr/bin/env bash
#
# ESF — Abschluss-Check Release-Ebene
# ===================================
#
#   scripts/check-release.sh R1
#
# Kapitel 5: Ein Release ist abgeschlossen, "wenn der Härtungs-Sprint fertig
# ist: Integration, Release Notes, voller E2E-Regressionslauf, Paket am Riegel"
# — und Kapitel 9: das prüft Code, kein Modell.
#
# Fünf Prüfungen:
#   1. Alle Sprints des Release sind abgeschlossen (check-sprint.sh je Sprint)
#   2. Die Release-Abschluss-Karte ist done und trägt ihr metadata
#   3. Das Release-Gate ist beantwortet UND ausgeführt (nicht nur beantwortet)
#   4. Release Notes und die E2E-Akte liegen im Vault
#   5. Main ist grün: Typecheck, Unit-Tests, volle E2E-Suite — hier wird
#      gemessen und nicht gelesen
#
# Prüfung 5 kostet Minuten. Sie steht trotzdem drin: Ein Release-Nachweis, der
# das Testergebnis aus einem Report abschreibt, den ein Modell geschrieben hat,
# ist genau der grüne Lauf ohne Aussage aus dem ersten Lauf (RUN-PROTOKOLL.md,
# "Ein grüner Lauf, der nichts prüft, ist schlimmer als ein roter").
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"

R="${1:-R1}"
case "$R" in
    R[0-9]) ;;
    [0-9]) R="R$R" ;;
    *) echo "Aufruf: scripts/check-release.sh R1"; exit 2 ;;
esac
KLEIN="$(printf '%s' "$R" | tr 'A-Z' 'a-z')"
OHNE_TESTS=0
[ "${2:-}" = "--ohne-tests" ] && OHNE_TESTS=1

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }

printf '\n\033[1mAbschluss-Check Release %s\033[0m\n' "$R"
printf '%.0s─' $(seq 1 70); echo

liste="$(k list --json 2>/dev/null || echo '[]')"

# ---------------------------------------------------------------------------
echo
echo "1. Sprints des Release"
# ---------------------------------------------------------------------------
# R1 läuft in diesem Lauf in zwei Sprints statt vier — CEO-Entscheidung,
# begründet in PHASE-2-PLAN.md; cadence.yaml gibt vier als OBERGRENZE vor.
for s in S1 S2; do
    karte="$(printf '%s' "$liste" | jq -r --arg t "Sprint-Abschluss $s" \
             '[.[] | select(.title==$t)] | last // null')"
    if [ "$karte" = "null" ]; then
        nein "$s hat keine Abschluss-Karte"
    else
        st="$(printf '%s' "$karte" | jq -r '.status')"
        if [ "$st" = "done" ]; then
            ok "Sprint-Abschluss $s ist fertig ($(printf '%s' "$karte" | jq -r '.id'))"
        else
            nein "Sprint-Abschluss $s steht auf '$st'"
        fi
    fi
done

# ---------------------------------------------------------------------------
echo
echo "2. Release-Abschluss-Karte"
# ---------------------------------------------------------------------------
ab="$(printf '%s' "$liste" | jq -r --arg t "Release-Abschluss $R" \
      '[.[] | select(.title==$t)] | last // null')"
if [ "$ab" = "null" ]; then
    nein "Es gibt keine Karte 'Release-Abschluss $R'. Erst ./create-release.sh $R"
else
    abid="$(printf '%s' "$ab" | jq -r '.id')"
    abst="$(printf '%s' "$ab" | jq -r '.status')"
    if [ "$abst" != "done" ]; then
        nein "Karte $abid steht auf '$abst' statt 'done'"
    else
        meta="$(k show "$abid" --json 2>/dev/null | jq -c '[.runs[]?.metadata // empty] | last // null')"
        if [ "$meta" = "null" ]; then
            nein "Karte $abid trägt kein Abschluss-metadata — nicht messbar"
        else
            frei="$(printf '%s' "$meta" | jq -r '.freigabefaehig // "fehlt"')"
            ok "Karte $abid ist fertig, metadata liegt vor (freigabefaehig: $frei)"
            # Ein 'false' ist kein Fehler dieses Checks — es ist ein Befund, den
            # der CEO am Gate zu würdigen hatte. Sichtbar machen, nicht bewerten.
            [ "$frei" = "false" ] && info "Die Karte hielt das Paket für NICHT freigabefähig. Die Gate-Antwort muss dazu Stellung nehmen."
        fi
    fi
fi

# ---------------------------------------------------------------------------
echo
echo "3. Das Release-Gate"
# ---------------------------------------------------------------------------
# Der Unterschied, auf den es ankommt: beantwortet heisst, der Mensch hat ein
# Verb gesagt. Ausgeführt heisst, die Karte hat danach gearbeitet und ist done.
# Ein Gate, das beantwortet aber nicht ausgeführt ist, sieht in `list` fast
# gleich aus.
gate="$(printf '%s' "$liste" | jq -r --arg t "GATE Release — $R" \
        '[.[] | select(.title==$t)] | last // null')"
if [ "$gate" = "null" ]; then
    nein "Es gibt keine Karte 'GATE Release — $R'"
else
    gid="$(printf '%s' "$gate" | jq -r '.id')"
    gst="$(printf '%s' "$gate" | jq -r '.status')"
    voll="$(k show "$gid" --json 2>/dev/null || echo '{}')"
    grund="$(printf '%s' "$voll" | jq -r '[.events[]? | select(.kind=="blocked")] | last | .payload.reason // ""')"
    zeilen="$(printf '%s' "$grund" | grep -c . || true)"
    # Die Antwort steht im KOMMENTAR, nicht in der Ereignis-Payload.
    #
    # Das `unblocked`-Ereignis traegt eine LEERE Payload; `gate.sh --reason`
    # legt den Text als Kommentar mit dem Praefix "UNBLOCK: " an. monitor.sh
    # dokumentiert das seit Phase 1 ausdruecklich — und dieses Skript hat die
    # Lehre nicht bekommen: Es las `.payload.reason`, fand nichts und meldete
    # "es gibt kein unblocked-Ereignis", obwohl das Ereignis da war und die
    # Freigabe erteilt.
    #
    # Dritte Wiederholung derselben Fehlerklasse in diesem Lauf (nach
    # `metadata` auf Karten- statt Laufebene und der flachen gegen die
    # verschachtelte Schaetzung). Die Lehre daraus ist nicht "besser lesen",
    # sondern: Ein Pruefer, der eine Form annimmt, MUSS gegen echte Daten
    # gelaufen sein, bevor man ihm glaubt. Dieser hier lief zum ersten Mal
    # gegen ein beantwortetes Gate — und fiel sofort auf.
    unblocks="$(printf '%s' "$voll" | jq '[.events[]? | select(.kind=="unblocked")] | length')"
    antwort="$(printf '%s' "$voll" | jq -r '
        [.comments[]? | (.text // .body // "")
         | select(test("^UNBLOCK: *(approve|modify|shelve|continue|cut|stop|manuell)\\b"))]
        | last // ""
        | sub("^UNBLOCK: *"; "")
        | .[0:160]')"

    case "$gst" in
        blocked)
            if [ "$zeilen" -ge 6 ]; then
                nein "Karte $gid wartet noch auf den CEO (Vorlage: $zeilen Zeilen)"
                info "Das ist kein Mangel der Organisation, sondern der offene Punkt."
                info "Antworten:  ./gate.sh approve $gid"
            else
                nein "Karte $gid ist blockiert, aber die Vorlage hat nur $zeilen Zeilen"
                info "Maßstab: man kann entscheiden, ohne eine Datei zu öffnen."
            fi ;;
        done)
            if [ "${unblocks:-0}" -eq 0 ]; then
                nein "Karte $gid ist done, aber es gibt kein unblocked-Ereignis"
                info "Eine Gate-Karte, die ohne menschliche Antwort fertig wurde, ist"
                info "ein Governance-Befund — kein Agent öffnet je ein Gate (AGENTS.md 7)."
            elif [ -z "$antwort" ]; then
                nein "Karte $gid wurde entblockt, aber ohne gate.sh-Kommentar mit gültigem Verb"
                info "Nur gate.sh schreibt 'UNBLOCK: <verb>: …'. Fehlt das, ist die Herkunft"
                info "der Antwort nicht belegt — monitor.sh meldet das als Verstoss."
            else
                # Das Verb-Präfix ist das Erkennungsmerkmal einer legitimen
                # menschlichen Antwort (gate.sh setzt es). Fehlt es, war es
                # vielleicht ein Worker.
                case "$antwort" in
                    approve*|modify*|shelve*)
                        ok "Karte $gid beantwortet und ausgeführt: \"$antwort\""
                        [ "$zeilen" -ge 6 ] && ok "die Vorlage hatte $zeilen Zeilen" \
                                            || nein "die Vorlage hatte nur $zeilen Zeilen" ;;
                    *)  nein "Karte $gid wurde ohne gültiges Verb entblockt: \"$antwort\""
                        info "Nur ./gate.sh setzt das Verb-Präfix. Ohne es ist die Herkunft"
                        info "der Antwort nicht belegt — monitor.sh meldet das als Verstoss." ;;
                esac
            fi ;;
        triage)
            nein "Karte $gid ist in der TRIAGE — sie fragt niemanden mehr (block_loop_detected)" ;;
        *)
            nein "Karte $gid steht auf '$gst' statt blocked/done" ;;
    esac
fi

# ---------------------------------------------------------------------------
echo
echo "4. Release-Artefakte im Vault"
# ---------------------------------------------------------------------------
notes="$VAULT/reports/release-$KLEIN.html"
if [ ! -f "$notes" ]; then
    nein "reports/release-$KLEIN.html fehlt"
elif [ "$(wc -c < "$notes")" -lt 1000 ]; then
    nein "reports/release-$KLEIN.html ist mit $(wc -c < "$notes" | tr -d ' ') Byte zu dünn"
else
    ok "reports/release-$KLEIN.html ($(wc -c < "$notes" | tr -d ' ') Byte)"
    # Der Abschnitt, ohne den Release Notes eine Werbung sind.
    if grep -qiE 'nicht (drin|enthalten|geliefert|umgesetzt)|deliberately_not_done|Einschränkung' "$notes"; then
        ok "nennt, was NICHT drin ist"
    else
        nein "nennt nirgends, was NICHT drin ist — ein Release-Dokument ohne diesen Abschnitt ist eine Werbung"
    fi
    if grep -qiE 'passed|[0-9]+/[0-9]+|E2E' "$notes"; then
        ok "nennt den Prüfstand"
    else
        nein "nennt keine Testzahlen"
    fi
fi

akte="$(ls -d "$VAULT"/reports/e2e-*/ 2>/dev/null | tail -1)"
if [ -z "$akte" ]; then
    nein "keine E2E-Akte unter reports/e2e-<datum>/ — der Regressionslauf hat keine Spur hinterlassen"
else
    n="$(find "$akte" -type f | wc -l | tr -d ' ')"
    if [ "$n" -eq 0 ]; then
        nein "reports/$(basename "$akte")/ ist leer"
    else
        ok "E2E-Akte reports/$(basename "$akte")/ mit $n Datei(en)"
    fi
fi

echo
echo "   Vault-Linter"
if python3 "$ESF/scripts/vault-lint.py" "$VAULT" > /tmp/esf-cr-lint.$$ 2>&1; then
    ok "sauber"
else
    nein "beanstandet:"
    grep '^ERROR' /tmp/esf-cr-lint.$$ | head -8 | sed 's/^/      /'
fi
rm -f /tmp/esf-cr-lint.$$

# ---------------------------------------------------------------------------
echo
echo "5. Main ist grün — selbst gemessen"
# ---------------------------------------------------------------------------
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"

if [ ! -d "$REPO/.git" ]; then
    nein "produkt.repo ist kein Git-Repo: $REPO"
elif [ "$OHNE_TESTS" -eq 1 ]; then
    info "übersprungen (--ohne-tests)"
else
    zweig="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
    [ "$zweig" = "main" ] && ok "Hauptbaum steht auf main ($(git -C "$REPO" rev-parse --short HEAD))" \
                          || nein "Hauptbaum steht auf '$zweig', nicht auf main"

    schmutz="$(git -C "$REPO" status --porcelain | grep -v '^?? .worktrees/' | head -5)"
    if [ -z "$schmutz" ]; then
        ok "Arbeitsbaum sauber"
    else
        nein "Arbeitsbaum nicht sauber:"
        printf '%s\n' "$schmutz" | sed 's/^/      /'
    fi

    printf '   Typecheck … '
    if ( cd "$REPO" && pnpm typecheck ) > /tmp/esf-cr-tc.$$ 2>&1; then
        printf '\r'; ok "Typecheck grün"
    else
        printf '\r'; nein "Typecheck rot"; tail -8 /tmp/esf-cr-tc.$$ | sed 's/^/      /'
    fi
    rm -f /tmp/esf-cr-tc.$$

    printf '   Unit-Tests … '
    if ( cd "$REPO" && pnpm test ) > /tmp/esf-cr-ut.$$ 2>&1; then
        # SUMMIEREN, nicht das letzte Paket nehmen.
        #
        # `pnpm test` ist `turbo test`: sieben Pakete, sieben eigene
        # Zusammenfassungen. Ein `grep … | tail -1` liefert deshalb die Zahl des
        # ZULETZT fertigen Pakets, und die Reihenfolge ist bei turbo nicht
        # stabil. Gemessen am 18.08.2026: tail -1 sagte "111 passed", die Summe
        # war 613.
        #
        # Das stand so im gruenen Phase-2-Nachweis — eine falsche Zahl mitten im
        # Artefakt, das die Phase beweist. Vierte Wiederholung derselben
        # Fehlerklasse an diesem Tag (metadata auf Karten- statt Laufebene,
        # flache gegen verschachtelte Schaetzung, Gate-Antwort in der Payload
        # statt im Kommentar, und nun das). Jede einzelne war ein Leser, der
        # eine Form annahm und nie gegen echte Daten lief.
        #
        # Die ANSI-Sequenzen muessen weg, bevor awk zaehlt: vitest faerbt die
        # Zahl, und "\x1b[1m613" ist kein Zahlenfeld.
        #
        # Der E2E-Aufruf zwei Bloecke weiter unten benutzt bewusst WEITERHIN
        # `tail -1`, und das ist dort richtig: Playwright gibt genau EINE
        # Zusammenfassung fuer die ganze Suite aus. Wer das hier "vereinheitlicht",
        # macht es kaputt.
        summe="$(sed 's/\x1b\[[0-9;]*m//g' /tmp/esf-cr-ut.$$ \
                 | grep -E 'Tests[[:space:]]+[0-9]+ passed' \
                 | awk '{for(i=1;i<=NF;i++) if($i=="passed"){s+=$(i-1)}} END {print s}')"
        printf '\r'; ok "Unit-Tests grün — ${summe:-?} passed über $(sed 's/\x1b\[[0-9;]*m//g' /tmp/esf-cr-ut.$$ | grep -cE 'Tests[[:space:]]+[0-9]+ passed') Pakete"
    else
        printf '\r'; nein "Unit-Tests rot"
        grep -iE 'fail|✗' /tmp/esf-cr-ut.$$ | head -6 | sed 's/^/      /'
    fi
    rm -f /tmp/esf-cr-ut.$$

    printf '   E2E-Suite … '
    ( cd "$REPO" && eval "$E2E_VORBED" ) >/dev/null 2>&1 || true
    if ( cd "$REPO" && eval "$E2E_BEFEHL" ) > /tmp/esf-cr-e2e.$$ 2>&1; then
        printf '\r'; ok "E2E grün — $(grep -oE '[0-9]+ passed' /tmp/esf-cr-e2e.$$ | tail -1)"
        # Der Regressionslauf vor dem Release ist der wichtigste grüne Lauf,
        # den die Organisation hat — er bekommt seine Video-Akte sofort
        # (AGENTS.md 8), nicht blockierend und ohne Einfluss auf das Urteil.
        if [ -x "$HERE/e2e-video.sh" ]; then
            "$HERE/e2e-video.sh" --alle --anlass "release-$R" 2>&1 | sed 's/^/      /' \
                || echo "      (Video-Akte fehlgeschlagen — Betriebsbefund, kein ✗)"
        fi
    else
        printf '\r'; nein "E2E rot"; tail -12 /tmp/esf-cr-e2e.$$ | sed 's/^/      /'
    fi
    rm -f /tmp/esf-cr-e2e.$$
fi

printf '\n'
printf '%.0s─' $(seq 1 70); echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Release %s abgeschlossen und freigegeben.\033[0m\n' "$R"
    exit 0
fi
printf '\033[31m✗ Release %s noch nicht abgeschlossen — siehe die ✗ oben.\033[0m\n' "$R"
exit 1
