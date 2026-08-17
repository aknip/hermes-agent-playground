#!/usr/bin/env bash
#
# ESF — Abschluss-Check Sprint-Ebene
# ==================================
#
#   scripts/check-sprint.sh S1
#
# Kapitel 5: Ein Sprint ist abgeschlossen, "wenn alle Sprint-Karten done oder
# per Gate zurückgestellt sind — nicht, wenn ein Wochentag erreicht ist". Und
# Kapitel 9: "ob der Tag, der Sprint, das Release fertig ist, prüft Code".
# Dieses Skript ist dieser Code. monitor.sh ruft es im Body der
# Sprint-Abschluss-Karte auf.
#
# Sechs Prüfungen:
#   1. Alle `S<n> `-Karten sind done (oder erklärt zurückgestellt)
#   2. Jede fertige Karte trägt Abschluss-metadata
#   3. DER RIEGEL: jede Umsetzungs-, Review- und Merge-Karte trägt einen
#      Istwert MIT bezifferter Schätzung — ein (Schätzung, Ist)-Paar, nicht nur
#      einen Istwert
#   4. Das Ledger kennt jede fertige Karte des Sprints
#   5. Die Feature-Branches liegen auf main (der Riegel ist passiert)
#   6. Die Sprint-Berichte liegen im Vault und der Linter nimmt sie an
#
# Prüfung 3 ist der Grund, warum dieses Skript existiert. `ledger-sync.sh`
# liest Schätzung und Istwert aus dem metadata DERSELBEN Karte; die Schätzung
# entsteht aber auf einer anderen Karte (esf-estimator) und muss von Hand
# mitgenommen werden. Ohne diesen Riegel bekommt man Istwerte statt Paare —
# und einen grünen Check über einem Report ohne den einzigen Nachweis, den
# Phase 2 erbringen muss.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
LEDGER="$VAULT/ledger/estimates.jsonl"

S="${1:-}"
case "$S" in
    S[0-9]|S[0-9][0-9]) ;;
    [0-9]|[0-9][0-9]) S="S$S" ;;
    *) echo "Aufruf: scripts/check-sprint.sh S1"; exit 2 ;;
esac
KLEIN="$(printf '%s' "$S" | tr 'A-Z' 'a-z')"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }

printf '\n\033[1mAbschluss-Check Sprint %s\033[0m\n' "$S"
printf '%.0s─' $(seq 1 70); echo

liste="$(k list --json 2>/dev/null || echo '[]')"
# Der Namensraum des Sprints ist das Titel-Präfix "S<n> " — dieselbe Regel, mit
# der monitor.sh die Sprint-Zugehörigkeit erkennt. Die Abschluss-Karten
# (`Kalibrierung S1`, `Sprint-Abschluss S1`) liegen absichtlich daneben: läge
# der Abschluss im Namensraum, könnte der Sprint nie voll werden, ohne schon
# abgeschlossen zu sein.
sprintkarten="$(printf '%s' "$liste" | jq -c --arg s "$S " '[.[] | select(.title | startswith($s))]')"

# ---------------------------------------------------------------------------
echo
echo "1. Sprint-Karten"
# ---------------------------------------------------------------------------
gesamt="$(printf '%s' "$sprintkarten" | jq 'length')"
fertig="$(printf '%s' "$sprintkarten" | jq '[.[] | select(.status=="done")] | length')"

if [ "$gesamt" -eq 0 ]; then
    nein "Es gibt keine Karte mit dem Präfix '$S '. Erst ./create-sprint.sh"
elif [ "$gesamt" -eq "$fertig" ]; then
    ok "$fertig von $gesamt fertig"
else
    nein "$fertig von $gesamt fertig"
    printf '%s' "$sprintkarten" | jq -r '.[] | select(.status!="done")
        | "      \(.id)  [\(.status)]  \(.title)"'
    # Zurückgestellt zählt nach Kapitel 5 als abgeschlossen — aber nur, wenn es
    # jemand entschieden hat. Ein blockiertes Gate ist keine Zurückstellung.
    blockiert="$(printf '%s' "$sprintkarten" | jq '[.[] | select(.status=="blocked")] | length')"
    [ "$blockiert" -gt 0 ] && info "$blockiert davon blockiert — ein wartendes Gate ist keine Zurückstellung."
    triage="$(printf '%s' "$sprintkarten" | jq '[.[] | select(.status=="triage")] | length')"
    [ "$triage" -gt 0 ] && info "$triage in TRIAGE — diese Karten fragen niemanden mehr (block_loop_detected)."
fi

# ---------------------------------------------------------------------------
echo
echo "2. Abschluss-metadata"
# ---------------------------------------------------------------------------
# Das metadata hängt am LAUF (.runs[].metadata), nicht an der Karte — die Karte
# hat gar kein metadata-Feld. Vier Skripte haben das im ersten Lauf falsch
# gelesen und lautlos `null` gerechnet.
ohne_meta=""
for id in $(printf '%s' "$sprintkarten" | jq -r '.[] | select(.status=="done") | .id'); do
    n="$(k show "$id" --json 2>/dev/null | jq '[.runs[]?.metadata // empty] | length')"
    [ "${n:-0}" -gt 0 ] || ohne_meta="$ohne_meta $id"
done
if [ "$fertig" -eq 0 ]; then
    info "keine fertige Karte — nichts zu prüfen"
elif [ -z "$ohne_meta" ]; then
    ok "alle $fertig fertigen Karten tragen Abschluss-metadata"
else
    nein "ohne Abschluss-metadata:$ohne_meta"
    info "Eine Karte ohne metadata ist nicht messbar und fällt still aus der Kalibrierung."
fi

# ---------------------------------------------------------------------------
echo
echo "3. (Schätzung, Ist)-Paare — der Riegel dieses Checks"
# ---------------------------------------------------------------------------
# Welche Karten MÜSSEN ein Paar tragen? Die, die hinter der Schätzung liegen:
# Umsetzung, Review, Merge. Die Spezifikations- und die Schätzkarte selbst
# laufen VOR ihr — sie können strukturell keine haben, und das ist keine
# Schlamperei, sondern die Ordnung der Kette. Sie tragen nur ihre Klasse.
paare=0; ohne_paar=""; ohne_klasse=""
for id in $(printf '%s' "$sprintkarten" | jq -r '.[] | select(.status=="done") | .id'); do
    titel="$(printf '%s' "$sprintkarten" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"

    # BEIDE Formen annehmen. Das SOUL-Schema verschachtelt
    # (estimate.reference_class, estimate.wall_minutes.p50); drei Karten haben
    # am 17.08.2026 flach geschrieben (reference_class auf oberster Ebene,
    # estimate.p50 direkt) — und mein eigener Kartentext hat das eingeladen, weil
    # er "reference_class 'merge-repo-S'" als eigene Zeile nennt.
    #
    # Ein Prüfer, der nur eine Form kennt, meldet vorhandene Messungen als
    # fehlend. Das ist schlimmer als gar nicht zu prüfen: Der Befund sieht aus
    # wie ein Fehler der Organisation und ist einer des Prüfers. Genau dieselbe
    # Fehlerklasse wie in Phase 1 (metadata auf Karten- statt Laufebene).
    meta="$(printf '%s' "$karte" | jq -c '[.runs[]?.metadata // empty] | last // {}')"
    klasse="$(printf '%s' "$meta" | jq -r '.reference_class // .estimate.reference_class // ""')"
    p50="$(printf '%s' "$meta" | jq -r '.estimate.wall_minutes.p50 // .estimate.p50 // ""')"

    [ -n "$klasse" ] || ohne_klasse="$ohne_klasse $id"

    braucht_paar=0
    case "$titel" in
        *Umsetzung*|*Review*|*Merge*) braucht_paar=1 ;;
    esac
    if [ "$braucht_paar" -eq 1 ]; then
        if [ -n "$p50" ]; then
            ist="$(printf '%s' "$karte" | jq '[(.runs[]? | select(.started_at and .ended_at) | (.ended_at - .started_at))] | if length==0 then null else (add/60|floor) end')"
            q="–"
            if [ "$ist" != "null" ] && [ -n "$p50" ]; then
                q="$(python3 -c "print(f'{$ist/$p50:.2f}')" 2>/dev/null || echo '–')"
            fi
            printf '  \033[32m✓\033[0m %-14s %-20s p50=%-5s Ist=%-5s Ist/Schätzung=%s\n' \
                "$id" "$klasse" "$p50" "$ist" "$q"
            paare=$((paare + 1))
        else
            ohne_paar="$ohne_paar $id"
        fi
    fi
done

if [ -n "$ohne_klasse" ]; then
    nein "ohne metadata.estimate.reference_class:$ohne_klasse"
    info "Ohne Klasse landet die Karte als 'unklassifiziert' im Ledger und ist"
    info "für jede künftige Schätzung wertlos."
fi
if [ -n "$ohne_paar" ]; then
    nein "Istwert ohne bezifferte Schätzung:$ohne_paar"
    info "Das ist der zerrissene Handoff: die Schätzung entstand auf der"
    info "Estimator-Karte und wurde nicht ins metadata dieser Karte kopiert."
    info "ledger-sync.sh kann daraus kein Paar bilden — und zwei Sprint-Reports"
    info "MIT (Schätzung, Ist)-Paaren sind der Phase-2-Nachweis aus Kapitel 12."
elif [ "$paare" -gt 0 ]; then
    ok "$paare vollständige (Schätzung, Ist)-Paare"
else
    nein "kein einziges (Schätzung, Ist)-Paar in diesem Sprint"
fi

# ---------------------------------------------------------------------------
echo
echo "4. Ledger"
# ---------------------------------------------------------------------------
if [ ! -s "$LEDGER" ]; then
    nein "ledger/estimates.jsonl ist leer — scripts/ledger-sync.sh ist nicht gelaufen"
else
    fehlend=""
    for id in $(printf '%s' "$sprintkarten" | jq -r '.[] | select(.status=="done") | .id'); do
        grep -q "\"task_id\": *\"$id\"" "$LEDGER" || fehlend="$fehlend $id"
    done
    if [ -n "$fehlend" ]; then
        nein "nicht im Ledger:$fehlend"
        info "Abhilfe: scripts/ledger-sync.sh"
    else
        ok "jede fertige Sprint-Karte hat eine Ledger-Zeile"
    fi

    echo
    echo "   Referenzklassen mit Paaren (Grundlage der nächsten Schätzung)"
    jq -rs '[.[] | select(.estimate != null and .estimate.wall_minutes.p50 != null)]
            | group_by(.reference_class)
            | map({k:.[0].reference_class, n:length,
                   q:([.[] | select(.actual.wall_minutes != null)
                           | (.actual.wall_minutes / .estimate.wall_minutes.p50)]
                      | if length==0 then null else (add/length) end)})
            | if length==0 then "    (noch keine Paare — nur Istwerte)"
              else (.[] | "    \(.k): n=\(.n), Ist/Schätzung im Mittel \(if .q==null then "–" else (.q*100|round/100) end)")
              end' "$LEDGER" 2>/dev/null || echo "    (nicht auswertbar)"
fi

# ---------------------------------------------------------------------------
echo
echo "5. Die Arbeit liegt auf main"
# ---------------------------------------------------------------------------
REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" 2>/dev/null | head -1)"
if [ ! -d "$REPO/.git" ]; then
    nein "produkt.repo aus cadence.yaml ist kein Git-Repo: $REPO"
else
    # Welche Branches gehören zu diesem Sprint? Die, die die Merge-Karten
    # genannt haben. Verlässlicher als raten: die Branch-Liste mit dem
    # ESF-Präfix, und dann prüfen, ob main sie enthält.
    branches="$(git -C "$REPO" for-each-ref --format='%(refname:short)' refs/heads \
                | grep -E '^feat/esf-r1-' || true)"
    if [ -z "$branches" ]; then
        info "keine feat/esf-r1-*-Branches vorhanden — nichts zu prüfen"
    else
        for b in $branches; do
            if git -C "$REPO" merge-base --is-ancestor "$b" main 2>/dev/null; then
                ok "$b ist in main enthalten ($(git -C "$REPO" rev-parse --short "$b"))"
            else
                offen="$(git -C "$REPO" rev-list --count "main..$b" 2>/dev/null || echo '?')"
                info "$b noch nicht in main ($offen Commit(s) davor) — gehört ggf. zu einem anderen Sprint"
            fi
        done
    fi
fi

# ---------------------------------------------------------------------------
echo
echo "6. Berichte im Vault"
# ---------------------------------------------------------------------------
for datei in "reports/controller-$KLEIN.html" "reports/sprint-$KLEIN-report.html"; do
    pfad="$VAULT/$datei"
    if [ ! -f "$pfad" ]; then
        nein "$datei fehlt"
    elif [ "$(wc -c < "$pfad")" -lt 800 ]; then
        nein "$datei ist mit $(wc -c < "$pfad" | tr -d ' ') Byte zu dünn für einen Report"
    else
        # Ein Sprint-Report ohne Paare ist der Fehler, den Prüfung 3 verhindern
        # soll — hier noch einmal am Dokument, weil ein Report auch dann grün
        # aussehen kann, wenn er die Zahlen nicht führt.
        treffer="$(grep -c -iE 'p50|p90|Ist/Sch|Schätzgüte|Quotient' "$pfad" || true)"
        if [ "$treffer" -eq 0 ]; then
            nein "$datei nennt weder p50/p90 noch einen Quotienten — kein Schätz-Vergleich"
        else
            ok "$datei ($(wc -c < "$pfad" | tr -d ' ') Byte, $treffer Schätz-Bezüge)"
        fi
    fi
done

echo
echo "   Vault-Linter"
if python3 "$ESF/scripts/vault-lint.py" "$VAULT" > /tmp/esf-cs-lint.$$ 2>&1; then
    ok "sauber"
else
    nein "beanstandet:"
    grep '^ERROR' /tmp/esf-cs-lint.$$ | head -8 | sed 's/^/      /'
fi
rm -f /tmp/esf-cs-lint.$$

printf '\n'
printf '%.0s─' $(seq 1 70); echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Sprint %s abgeschlossen.\033[0m\n' "$S"
    exit 0
fi
printf '\033[31m✗ Sprint %s noch nicht abgeschlossen — siehe die ✗ oben.\033[0m\n' "$S"
exit 1
