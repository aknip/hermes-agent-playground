#!/usr/bin/env bash
#
# ESF — die Budget-Wache
# ======================
#
#   scripts/budget-wache.sh              pruefen und, bei Ueberschreitung, ein Gate anlegen
#   scripts/budget-wache.sh --dry-run    zeigen statt anlegen
#   scripts/budget-wache.sh --selbsttest hermes-frei: nur die Rechnung
#
# WARUM ES DIESES SKRIPT GIBT — eine Regel, die nur auf dem Papier stand.
#
# cadence.yaml traegt seit Phase 0 `budget_eskalation_bei: 1.5`. gate.sh und
# ceo-tick.sh kennen die Gate-Art `GATE Budget` samt ihrem eigenen Vokabular
# (continue | cut | stop), ceo-lint.py erzwingt es, und der Kartentext jeder
# Schaetzkarte sagt dem esf-estimator: "Das Budget-Gate haengt an deinem P90."
#
# Nur: BIS ZUM 20.08.2026 HAT NIEMAND DIE SCHWELLE GELESEN. Kein Skript
# rechnete Ist gegen p90, keines legte je eine Gate-Karte an. Sichtbar wurde
# das an S4: Die Review-Karte t_4798143b brauchte 61 Minuten gegen ein p90 von
# 20 — Schwelle 1,5 x 20 = 30 min, ueberschritten um 31 min, und nichts ist
# passiert. Ein Tor, das nie zugeht, ist keines.
#
# WAS DIE WACHE MISST
# Sie liest die Schaetzung dort, wo sie autoritativ liegt: bei der
# Estimator-Karte, aufgeloest ueber die KARTEN-ID (Bedingung 2a des
# Roadmap-Gates R2, gemeinsame Funktion in lib-schaetzung.sh). Kein Ledger —
# die Wache soll auch waehrend eines Sprints greifen koennen, und das Ledger
# fuellt sich erst bei der Kalibrierung.
#
#   Ueberschreitung  :=  Ist  >  faktor x p90
#
# p90 und nicht p50: Das p50 ist der Median, ihn zu ueberschreiten ist der
# Normalfall. Das p90 ist die Zusage "in neun von zehn Faellen darunter";
# 1,5 x p90 zu reissen heisst, dass die Schaetzung die Karte nicht mehr
# beschreibt. Traegt eine Schaetzung kein p90, wird sie GENANNT und
# uebersprungen — nicht auf p50 zurueckgefallen. Eine Schwelle aus einer
# anderen Groesse als der zugesagten waere eine andere Regel.
#
# EIN GATE JE SPRINT, NICHT JE KARTE. cadence.yaml: "Die knappe Ressource ist
# die Aufmerksamkeit des CEO, nicht das Token-Budget." Drei Ueberschreitungen
# in einem Sprint sind EINE Frage ("weiterlaufen, kuerzen oder anhalten?"),
# nicht drei.
#
# WAS SIE NICHT TUT: Sie entscheidet nicht. Sie legt eine Karte an, die sich
# selbst blockiert; die Antwort gibt ein Mensch ueber ./gate.sh — oder, im
# Schattenbetrieb, gibt esf-ceo parallel sein Urteil ab und ceo-tick.sh
# vergleicht (Phase 3 Stufe B).
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"

DRY=0; SELBSTTEST=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY=1 ;;
        --selbsttest) SELBSTTEST=1 ;;
        *) echo "Unbekannte Option '$arg'"; exit 2 ;;
    esac
done

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }

# ---------------------------------------------------------------------------
# Die Rechnung — als eigene Funktion, damit der Selbsttest sie ohne Board hat
# ---------------------------------------------------------------------------
# Ausgabe auf stdout: "ueber" | "drunter" | "kein_p90"
ueberschritten() { # ist_minuten p90 faktor
    local ist="${1:-}" p90="${2:-}" faktor="${3:-1.5}"
    case "$p90" in ''|null|0) printf 'kein_p90'; return 0 ;; esac
    case "$ist" in ''|null) printf 'kein_p90'; return 0 ;; esac
    # In Zehntelminuten rechnen, damit kein bc/python noetig ist und die
    # Grenze nicht an einer Rundung haengt.
    local schwelle_zehntel
    schwelle_zehntel="$(awk -v p="$p90" -v f="$faktor" 'BEGIN{printf "%d", p*f*10}')"
    local ist_zehntel=$(( ist * 10 ))
    if [ "$ist_zehntel" -gt "$schwelle_zehntel" ]; then printf 'ueber'; else printf 'drunter'; fi
}

# Der Sprint einer Karte steckt in ihrem Titel-Praefix. Karten ohne einen
# gehoeren zur Gruppe 'sonstige' — sie bekommen ein eigenes Gate, weil ein
# Gate ohne benannten Bezug niemandem sagt, worueber er entscheidet.
sprint_von() { # titel
    case "$1" in
        S[0-9]\ *|S[0-9][0-9]\ *) printf '%s' "${1%% *}" ;;
        *) printf 'sonstige' ;;
    esac
}

# ---------------------------------------------------------------------------
# Selbsttest — hermes-frei
# ---------------------------------------------------------------------------
if [ "$SELBSTTEST" -eq 1 ]; then
    say "budget-wache Selbsttest (hermes-frei)"
    fehler=0

    # (a) die Grenze selbst — genau darauf, knapp darunter, knapp darueber
    for fall in "30 20 1.5 drunter" "31 20 1.5 ueber" "29 20 1.5 drunter" \
                "61 20 1.5 ueber" "204 160 1.5 drunter" "241 160 1.5 ueber"; do
        set -- $fall
        got="$(ueberschritten "$1" "$2" "$3")"
        if [ "$got" = "$4" ]; then ok "Ist $1 gegen p90 $2 x $3 -> $got"
        else nein "Ist $1 gegen p90 $2 x $3 -> $got, erwartet $4"; fehler=1; fi
    done

    # (b) 30 gegen 30 ist NICHT ueber. Die Schwelle ist eine Grenze, keine
    #     Zone: 'ueber der Schwelle' heisst echt darueber. Ohne diesen Fall
    #     entschiede eine Rundung, ob ein Mensch gefragt wird.
    [ "$(ueberschritten 30 20 1.5)" = "drunter" ] \
        && ok "genau auf der Schwelle zaehlt nicht als Ueberschreitung" \
        || { nein "Grenzfall falsch"; fehler=1; }

    # (c) ohne p90 wird NICHT auf p50 zurueckgefallen
    [ "$(ueberschritten 999 '' 1.5)" = "kein_p90" ] && [ "$(ueberschritten 999 null 1.5)" = "kein_p90" ] \
        && ok "ohne p90: uebersprungen statt geraten" \
        || { nein "kein_p90 wird nicht erkannt"; fehler=1; }

    # (d) ohne Istwert ebenso
    [ "$(ueberschritten '' 20 1.5)" = "kein_p90" ] \
        && ok "ohne Istwert: uebersprungen" || { nein "leerer Istwert falsch"; fehler=1; }

    # (e) die Sprint-Zuordnung
    [ "$(sprint_von "S4 F2 3/4 — Review F-R2-1")" = "S4" ] \
      && [ "$(sprint_von "S12 W 1/1 — Wartung")" = "S12" ] \
      && [ "$(sprint_von "Release-Abschluss R1")" = "sonstige" ] \
        && ok "Sprint aus dem Titel: S4, S12, sonstige" \
        || { nein "Sprint-Zuordnung falsch: $(sprint_von "S4 F2 3/4 — Review")"; fehler=1; }

    exit "$fehler"
fi

command -v hermes >/dev/null || { echo "FEHLER: 'hermes' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }
. "$HERE/lib-schaetzung.sh"

cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }
FAKTOR="$(cad budget_eskalation_bei)"; FAKTOR="${FAKTOR:-1.5}"

say "Budget-Wache — Schwelle: Ist > $FAKTOR x p90"
liste="$(k list --json 2>/dev/null || echo '[]')"
JETZT="$(date +%s)"

ueber=""; kein_p90=""; geprueft=0
for id in $(printf '%s' "$liste" | jq -r '.[] | select(.title | startswith("GATE ") | not) | .id'); do
    titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"

    # Die Schaetzung: erst aus der Karte selbst, sonst beim Schaetzer.
    meta="$(printf '%s' "$karte" | jq -c '[.runs[]?.metadata // empty] | last // {}')"
    p90="$(printf '%s' "$meta" | jq -r '.estimate.wall_minutes.p90 // empty')"
    if [ -z "$p90" ]; then
        aufgeloest="$(schaetzer_aufloesen "$karte" "$id" 2>/dev/null || true)"
        p90="$(printf '%s' "$aufgeloest" | jq -r '.wall_minutes.p90 // empty' 2>/dev/null || true)"
    fi
    [ -n "$p90" ] || continue          # gar keine Schaetzung: nicht Sache dieser Wache

    # Der Istwert: abgeschlossene Laeufe plus, falls einer laeuft, seine
    # bisherige Dauer. Genau das macht die Wache waehrend eines Sprints
    # nuetzlich — eine Karte, die schon ueber der Schwelle ist, kann man noch
    # anhalten; eine abgeschlossene nicht mehr.
    ist="$(printf '%s' "$karte" | jq --argjson jetzt "$JETZT" '
        [ .runs[]? | (if .ended_at then (.ended_at - .started_at)
                      elif .started_at then ($jetzt - .started_at)
                      else 0 end) ] | add // 0 | . / 60 | floor')"
    geprueft=$((geprueft + 1))

    case "$(ueberschritten "$ist" "$p90" "$FAKTOR")" in
        ueber)
            schwelle="$(awk -v p="$p90" -v f="$FAKTOR" 'BEGIN{printf "%.0f", p*f}')"
            ueber="$ueber$(sprint_von "$titel")|$id|$titel|$ist|$p90|$schwelle
" ;;
        kein_p90) kein_p90="$kein_p90 $id" ;;
    esac
done

echo "  $geprueft Karte(n) mit beziffertem p90 geprüft"
[ -n "$kein_p90" ] && info "ohne p90, übersprungen statt geraten:$kein_p90"

if [ -z "$ueber" ]; then
    ok "keine Karte über $FAKTOR x p90 — kein Budget-Gate"
    exit 0
fi

# ---------------------------------------------------------------------------
# Je Sprint EIN Gate
# ---------------------------------------------------------------------------
for gruppe in $(printf '%s\n' "$ueber" | awk -F'|' 'NF{print $1}' | sort -u); do
    zeilen="$(printf '%s\n' "$ueber" | awk -F'|' -v g="$gruppe" '$1==g')"
    anzahl="$(printf '%s\n' "$zeilen" | grep -c . || true)"

    tabelle="$(printf '%s\n' "$zeilen" | awk -F'|' 'NF{
        printf "  %-14s %-46s Ist %4s min gegen Schwelle %4s (p90 %s)\n", $2, substr($3,1,46), $4, $6, $5 }')"
    summe_ist="$(printf '%s\n' "$zeilen" | awk -F'|' 'NF{s+=$4} END{print s+0}')"
    summe_schwelle="$(printf '%s\n' "$zeilen" | awk -F'|' 'NF{s+=$6} END{print s+0}')"

    warn "$gruppe: $anzahl Überschreitung(en)"
    printf '%s\n' "$tabelle"

    if [ "$DRY" -eq 1 ]; then
        info "würde anlegen: GATE Budget — $gruppe (idempotency-key budget-gate-$gruppe)"
        continue
    fi

    id="$(k create "GATE Budget — $gruppe" \
        --assignee esf-chief-of-staff \
        --workspace "dir:$VAULT" \
        --idempotency-key "budget-gate-$gruppe" \
        --max-retries 2 --max-runtime 75m \
        --body "Der Ist-Aufwand von $gruppe hat die Budget-Schwelle gerissen. Lege dem
Supervisor die Entscheidung vor: weiterlaufen, Scope kürzen oder anhalten.

DIE MESSUNG — von scripts/budget-wache.sh, nicht von einem Modell
Schwelle: Ist > $FAKTOR x p90 (cadence.yaml budget_eskalation_bei).
$anzahl Karte(n) darüber, zusammen $summe_ist min gegen $summe_schwelle min Schwelle:

$tabelle

Diese Zahlen sind Board-Zeitstempel und Schätzungen des esf-estimator. Du
erfindest sie nicht neu — aber du DEUTEST sie, und das ist deine Arbeit.

ERSTER LAUF
1. Stell fest, WORAN es lag. Nicht 'die Schätzung war zu niedrig' — das ist
   die Tautologie. Sondern: Was hat die Karte getan, das die Schätzung nicht
   vorhergesehen hat? Lies das Abschluss-metadata der genannten Karten und
   den Schätz-Report des Sprints. Wenn zwei Karten derselben Klasse weit
   auseinanderliegen, ist DAS der interessante Satz.
2. Sag, ob es sich WIEDERHOLEN wird. Ein einmaliger Ausreisser (ein
   Betriebsbefund, ein Fehlschlag mit Wiederholung) ist etwas anderes als
   eine systematisch zu enge Klasse. Der Unterschied entscheidet zwischen
   'weiterlaufen' und 'kürzen'.
3. Blockiere dich SELBST: kanban_block(kind=\"needs_input\", reason=\"…\")

   Sieben Zeilen, jede eine:
     1 Was ansteht   — $gruppe über der Budget-Schwelle: $anzahl Karte(n)
     2 Die Zahlen    — Ist gegen Schwelle, die schlimmste Karte namentlich
     3 Woran es lag  — deine Antwort auf Punkt 1, in einem Satz
     4 Wiederholt es sich — ja/nein, mit Grund
     5 Was auf dem Spiel steht — was noch offen ist und was es kosten würde
     6 Empfehlung    — continue, cut oder stop, in einem Satz begründet
     7 Wie antworten — ./gate.sh continue <id> · cut <id> \"<Scope>\" ·
                       stop <id> \"<Grund>\"

   DAS VOKABULAR IST HIER EIN ANDERES. An einem Budget-Gate gelten
   continue | cut | stop — nicht approve/modify/shelve. gate.sh weist alles
   andere ab, und ceo-lint.py auch.

ZWEITER LAUF — nach der Antwort
4. Lies die Antwort im Kommentar-Thread; sie beginnt mit einem Verb.
     continue → Nichts ändern. Die Begründung des Supervisors in einem
                Vermerk festhalten (reports/budget-$(printf '%s' "$gruppe" | tr 'A-Z' 'a-z').html),
                damit die nächste Überschreitung nicht neu diskutiert wird.
     cut      → Den genannten Scope aus dem laufenden Plan nehmen. Was
                herausfällt, steht namentlich im Vermerk — nicht 'wir machen
                weniger'.
     stop     → Keine neuen Arbeitskarten mehr für $gruppe. Der Vermerk hält
                fest, was unfertig bleibt.
5. Committe den Vault.
6. kanban_complete mit der Antwort und dem, was du daraus gemacht hast.

Blockiere dich höchstens EINMAL (BLOCK_RECURRENCE_LIMIT = 2 je kind).
Du rufst NIEMALS kanban_unblock (AGENTS.md 7) und NICHT
kanban_request_review.

VAULT-FORMAT (AGENTS.md 2.2) für den Vermerk: <!doctype html>, lang=de,
meta esf-typ 'report', esf-karte <deine Karten-ID>, esf-datum vom System." \
        --json | jq -r .id)"
    ok "GATE Budget — $gruppe angelegt: $id"
done

echo
warn "Die Gate-Karte blockiert sich beim ersten Lauf selbst. Weiter: ./pump.sh, dann ./gate.sh"
exit 0
