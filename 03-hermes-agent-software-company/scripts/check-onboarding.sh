#!/usr/bin/env bash
#
# ESF — Abschluss-Check Phase 1 (Onboarding)
# ==========================================
#
#   scripts/check-onboarding.sh
#
# Der deterministische Nachweis aus Kapitel 12: Phase 1 ist fertig, wenn
#
#   1. alle Onboarding-Karten `done` sind,
#   2. analysis/ die vier Artefakte enthält — codebase, product, market, journeys,
#   3. die E2E-Suite jede im Katalog gelistete Kern-Journey abdeckt und grün läuft,
#   4. die Roadmap-Gate-Karte mit vollständiger Vorlage auf den CEO wartet
#      (bzw. bereits beantwortet ist).
#
# Kein Modell beurteilt das. Ein grüner Check schliesst die Phase ab, ein roter
# benennt, was fehlt.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }

printf '\n\033[1mAbschluss-Check Phase 1 — Onboarding\033[0m\n'
printf '%.0s─' $(seq 1 70); echo

liste="$(k list --json 2>/dev/null || echo '[]')"

# --- 1. Karten -------------------------------------------------------------
echo
echo "1. Onboarding-Karten"
gesamt="$(printf '%s' "$liste" | jq '[.[] | select(.title | startswith("Onboarding"))] | length')"
fertig="$(printf '%s' "$liste" | jq '[.[] | select((.title | startswith("Onboarding")) and .status=="done")] | length')"
if [ "$gesamt" -eq 0 ]; then
    nein "Es gibt keine Onboarding-Karten. Erst ./create-onboarding.sh"
elif [ "$gesamt" -eq "$fertig" ]; then
    ok "$fertig von $gesamt fertig"
else
    nein "$fertig von $gesamt fertig"
    printf '%s' "$liste" | jq -r '.[] | select((.title | startswith("Onboarding")) and .status!="done")
        | "      \(.id)  [\(.status)]  \(.title)"'
fi

# --- 2. Die vier Analyse-Artefakte -----------------------------------------
echo
echo "2. Analyse-Artefakte im Vault"
for datei in codebase.html product.html market.html journeys.html; do
    pfad="$VAULT/analysis/$datei"
    if [ ! -f "$pfad" ]; then
        nein "analysis/$datei fehlt"
    elif [ "$(wc -c < "$pfad")" -lt 500 ]; then
        nein "analysis/$datei ist mit $(wc -c < "$pfad") Byte zu dünn für einen Bericht"
    else
        ok "analysis/$datei ($(wc -c < "$pfad" | tr -d ' ') Byte)"
    fi
done

echo
echo "   Vault-Linter"
if python3 "$ESF/scripts/vault-lint.py" "$VAULT" > /tmp/esf-check-lint.$$ 2>&1; then
    ok "sauber"
else
    nein "beanstandet:"
    grep '^ERROR' /tmp/esf-check-lint.$$ | head -8 | sed 's/^/      /'
fi
rm -f /tmp/esf-check-lint.$$

# --- 3. E2E-Suite ----------------------------------------------------------
echo
echo "3. E2E-Suite"
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_DIR="$(sed -n 's/^[[:space:]]*e2e_verzeichnis:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"

specs=0
if [ -d "$REPO/$E2E_DIR" ]; then
    specs="$(find "$REPO/$E2E_DIR" -name '*.spec.ts' | wc -l | tr -d ' ')"
    ok "$specs Spec-Datei(en) unter $E2E_DIR"
else
    nein "$E2E_DIR gibt es im Produkt-Repo nicht"
fi

# Jede im Katalog genannte Spec muss existieren. Ein Katalog, der auf nichts
# zeigt, ist die häufigste Form von Scheinvollständigkeit.
if [ -f "$VAULT/analysis/journeys.html" ]; then
    genannte="$(grep -oE '[a-z0-9-]+\.spec\.ts' "$VAULT/analysis/journeys.html" | sort -u)"
    if [ -z "$genannte" ]; then
        nein "journeys.html nennt keine einzige Spec-Datei"
    else
        fehlend=""
        for spec in $genannte; do
            [ -f "$REPO/$E2E_DIR/$spec" ] || fehlend="$fehlend $spec"
        done
        if [ -n "$fehlend" ]; then
            nein "journeys.html nennt Specs, die es nicht gibt:$fehlend"
        else
            ok "alle $(printf '%s\n' "$genannte" | wc -l | tr -d ' ') im Katalog genannten Specs existieren"
        fi
    fi
fi

# Der eigentliche Nachweis aus Kapitel 12 lautet „die E2E-Suite deckt die
# KERN-Journeys". Ein Katalog mit drei sauberen Einträgen erfüllt das nicht,
# wenn die Produktanalyse acht Kernaufgaben gefunden hat. Also gegenrechnen —
# und die Zahl in jedem Fall ausgeben, damit eine bewusst kleine Abdeckung eine
# Entscheidung bleibt statt ein unbemerktes Bestehen.
if [ -f "$VAULT/analysis/product.html" ] && [ -f "$VAULT/analysis/journeys.html" ]; then
    echo
    echo "   Abdeckung der Kern-Journeys"
    soll="$(grep -oE 'J-[0-9]{2}' "$VAULT/analysis/product.html" | sort -u)"
    ist="$(grep -oE 'J-[0-9]{2}' "$VAULT/analysis/journeys.html" | sort -u)"
    n_soll="$(printf '%s\n' "$soll" | grep -c . || true)"
    n_ist="$(printf '%s\n' "$ist" | grep -c . || true)"

    if [ "$n_soll" -eq 0 ]; then
        nein "product.html benennt keine Journeys mit J-nn-Kennung"
    else
        # Zwei verschiedene Zahlen, und die Unterscheidung ist der Punkt:
        # Im Katalog ERWÄHNT zu sein heisst nur, dass die Journey bekannt ist —
        # ein guter Katalog listet auch das noch nicht Abgedeckte. Zählen tut
        # aber, ob eine Spec-Datei dazu existiert.
        # Die Zuordnung Journey -> Spec liest die TABELLENZEILE der Journey,
        # nicht ein Zeilenfenster um ihren Namen.
        #
        # Der Vorgaenger nahm `grep -B4 -A8 "$j" journeys.html` und den ersten
        # Dateinamen darin. In einer Tabelle steht dort die Spec der NACHBAR-
        # zeile. Am 18.08.2026 meldete er deshalb „9 von 9 Kern-Journeys haben
        # eine existierende Spec-Datei", waehrend der Katalog bei J-05..J-08
        # ausdruecklich „offen" und „—" fuehrte und nur fuenf Spec-Dateien
        # existierten. Sogar J-04 bekam die Spec von J-00 zugeschrieben — es
        # war KEINE Zuordnung richtig, die Zahl war frei erfunden.
        #
        # Der Kommentar zwanzig Zeilen weiter oben nennt „ein Katalog, der auf
        # nichts zeigt" die haeufigste Form von Scheinvollstaendigkeit. Der
        # Pruefer dagegen erzeugte sie selbst — und niemand konnte es sehen,
        # weil er nur eine Zahl ausgab. Deshalb steht die Zuordnung jetzt
        # einzeln da: eine Zahl, die keiner nachrechnen kann, ist kein Beleg.
        zeilen_von() {
            # Je <tr> eine Ausgabezeile, am </tr> ABGESCHNITTEN, Tags entfernt,
            # fuehrender Leerraum weg.
            #
            # Das Abschneiden ist nicht Kosmetik: Ohne es laeuft die LETZTE
            # Tabellenzeile bis zum Dateiende weiter und verschluckt den
            # gesamten Fliesstext danach. Genau daran zaehlte dieser Pruefer am
            # 18.08.2026 sechs P1-Journeys statt fuenf — J-08 (P2) erbte das
            # "P1" aus dem Satz "Die Reihenfolge P1-P3 bildet den Kundenwert
            # ab", der hinter der Tabelle steht. Dieselbe Fehlerklasse wie das
            # Zeilenfenster, das dieser Fix ersetzt hat, nur eine Ebene tiefer.
            tr '\n' ' ' < "$1" | sed 's|<tr|\n<tr|g' | sed 's|</tr>.*||' \
                | sed 's|<[^>]*>| |g' | sed 's|^[[:space:]]*||'
        }
        katalog="$(zeilen_von "$VAULT/analysis/journeys.html")"

        offen=""; mit_spec=0; zuordnung=""
        for j in $soll; do
            printf '%s\n' "$ist" | grep -qx "$j" || offen="$offen $j"
            # Nur die Zeile, die MIT dieser Journey beginnt. J-03 erwaehnt J-05
            # in seinem Hinweistext — ein blosses grep traefe die falsche Zeile.
            spec="$(printf '%s\n' "$katalog" | grep -E "^$j([^0-9]|$)" \
                    | head -1 | grep -oE '[a-z0-9-]+\.spec\.ts' | head -1)"
            if [ -n "$spec" ] && [ -f "$REPO/$E2E_DIR/$spec" ]; then
                mit_spec=$((mit_spec + 1))
                zuordnung="$zuordnung
      $j  ->  $spec"
            else
                zuordnung="$zuordnung
      $j  ->  (keine Spec)"
            fi
        done
        printf '    %s von %s Kern-Journeys im Katalog erwähnt\n' "$n_ist" "$n_soll"
        printf '    %s davon haben eine existierende Spec-Datei\n' "$mit_spec"
        printf '%s\n' "$zuordnung"
        [ -n "$offen" ] && printf '    nicht einmal erwähnt:%s\n' "$offen"
        if [ "$mit_spec" -eq 0 ]; then
            nein "keine einzige Kern-Journey hat eine Spec"
        fi

        # Harte Untergrenze: mindestens eine P1-Journey muss eine echte Spec
        # haben. Ohne das ist die Suite ein Katalog ohne Deckung. Auch hier
        # zeilenweise statt mit `grep -A3` — dasselbe Fenster-Problem.
        produkt="$(zeilen_von "$VAULT/analysis/product.html")"
        p1_ok=0; p1_gesamt=0; p1_mit_spec=0
        for j in $soll; do
            zeile="$(printf '%s\n' "$produkt" | grep -E "^$j([^0-9]|$)" | head -1)"
            case "$zeile" in
                *P1*)
                    p1_gesamt=$((p1_gesamt + 1))
                    spec="$(printf '%s\n' "$katalog" | grep -E "^$j([^0-9]|$)" \
                            | head -1 | grep -oE '[a-z0-9-]+\.spec\.ts' | head -1)"
                    if [ -n "$spec" ] && [ -f "$REPO/$E2E_DIR/$spec" ]; then
                        p1_ok=1
                        p1_mit_spec=$((p1_mit_spec + 1))
                    fi ;;
            esac
        done
        if [ "$p1_ok" -eq 1 ]; then
            ok "P1-Journeys mit Spec: $p1_mit_spec von $p1_gesamt"
        else
            nein "keine einzige P1-Journey aus product.html hat eine Spec ($p1_gesamt P1 gefunden)"
        fi
    fi
fi

echo "   Lauf"
if [ -d "$REPO" ] && [ "$specs" -gt 0 ]; then
    ( cd "$REPO" && eval "$E2E_VORBED" ) >/dev/null 2>&1 || true
    if ( cd "$REPO" && eval "$E2E_BEFEHL" ) > /tmp/esf-check-e2e.$$ 2>&1; then
        ok "grün — $(grep -oE '[0-9]+ passed' /tmp/esf-check-e2e.$$ | tail -1)"
        # Jeder grüne Lauf hinterlässt seine Video-Akte, auch der aus einem
        # Nachweis (AGENTS.md 8). Nicht blockierend und ohne Einfluss auf das
        # Urteil: Der Nachweis misst die Suite, nicht den Video-Kanal.
        if [ -x "$HERE/e2e-video.sh" ]; then
            "$HERE/e2e-video.sh" --alle --anlass onboarding 2>&1 | sed 's/^/      /' \
                || echo "      (Video-Akte fehlgeschlagen — Betriebsbefund, kein ✗)"
        fi
    else
        nein "rot"
        tail -12 /tmp/esf-check-e2e.$$ | sed 's/^/      /'
    fi
    rm -f /tmp/esf-check-e2e.$$
else
    nein "nicht ausführbar (kein Repo oder keine Specs)"
fi

# --- 4. Das Roadmap-Gate ---------------------------------------------------
echo
echo "4. Roadmap-Gate"
gate="$(printf '%s' "$liste" | jq -c '[.[] | select(.title | startswith("GATE Roadmap"))] | last // null')"
if [ "$gate" = "null" ]; then
    nein "Es gibt keine Roadmap-Gate-Karte"
else
    gid="$(printf '%s' "$gate" | jq -r '.id')"
    gstatus="$(printf '%s' "$gate" | jq -r '.status')"
    grund="$(k show "$gid" --json 2>/dev/null \
             | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // ""')"
    zeilen="$(printf '%s' "$grund" | grep -c . || true)"

    case "$gstatus" in
        blocked)
            if [ "$zeilen" -ge 6 ]; then
                ok "Karte $gid wartet mit einer Vorlage aus $zeilen Zeilen auf den CEO"
            else
                nein "Karte $gid ist blockiert, aber die Vorlage hat nur $zeilen Zeilen"
                info "Maßstab: man kann entscheiden, ohne eine Datei zu öffnen."
            fi ;;
        done)
            # Die Antwort steht im KOMMENTAR, nicht in der Ereignis-Payload.
            # Das `unblocked`-Ereignis traegt eine LEERE Payload; `gate.sh
            # --reason` legt den Text als Kommentar mit dem Praefix "UNBLOCK: "
            # an. monitor.sh, check-phase3.sh und check-release.sh wissen das
            # laengst — dieser Pruefer war der letzte, der `.payload.reason`
            # las, und meldete deshalb am 18.08.2026 ein gruenes
            # "beantwortet und ausgefuehrt: \"?\"": Er bestand, ohne sagen zu
            # koennen, WAS entschieden wurde. Ein Pruefer, der die Antwort
            # nicht lesen kann, prueft die Antwort nicht.
            voll="$(k show "$gid" --json 2>/dev/null || echo '{}')"
            unblocks="$(printf '%s' "$voll" | jq '[.events[]? | select(.kind=="unblocked")] | length')"
            antwort="$(printf '%s' "$voll" | jq -r '
                [.comments[]? | (.text // .body // "")
                 | select(test("^UNBLOCK: *(approve|modify|shelve|continue|cut|stop|manuell)\\b"))]
                | last // ""
                | sub("^UNBLOCK: *"; "")
                | split("\n")[0] // ""
                | .[0:160]')"
            if [ "${unblocks:-0}" -eq 0 ]; then
                nein "Karte $gid ist done, aber es gibt kein unblocked-Ereignis"
                info "Eine Gate-Karte, die ohne menschliche Antwort fertig wurde, ist"
                info "ein Governance-Befund — kein Agent oeffnet je ein Gate (AGENTS.md 7)."
            elif [ -z "$antwort" ]; then
                nein "Karte $gid wurde entblockt, aber ohne gate.sh-Kommentar mit gueltigem Verb"
                info "Ein unblock ohne Verb ist von einem Selbst-Freischalten nicht zu unterscheiden."
            else
                ok "Karte $gid ist beantwortet und ausgefuehrt: \"$antwort\""
            fi ;;
        triage)
            nein "Karte $gid ist in der TRIAGE gelandet — sie fragt niemanden mehr" ;;
        *)
            nein "Karte $gid steht auf '$gstatus' statt blocked/done" ;;
    esac
fi

# --- Roadmap-Datei ---------------------------------------------------------
echo
echo "5. Roadmap im Vault"
if ls "$VAULT"/roadmap/*.html >/dev/null 2>&1; then
    for datei in "$VAULT"/roadmap/*.html; do
        ok "roadmap/$(basename "$datei") ($(wc -c < "$datei" | tr -d ' ') Byte)"
    done
else
    nein "roadmap/ enthält kein einziges Dokument"
fi

printf '\n'
printf '%.0s─' $(seq 1 70); echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Phase 1 abgeschlossen.\033[0m\n'
    exit 0
fi
printf '\033[31m✗ Phase 1 noch nicht abgeschlossen — siehe die ✗ oben.\033[0m\n'
exit 1
