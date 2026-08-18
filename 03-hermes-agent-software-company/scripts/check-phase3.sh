#!/usr/bin/env bash
#
# ESF — Abschluss-Check Phase 3 (Dauerbetrieb unter einem CEO-Profil)
# ===================================================================
#
#   scripts/check-phase3.sh [--stufe a|b|c]
#
# Ohne --stufe wird die Stufe aus cadence.yaml abgeleitet:
# ceo_modus schatten → b, live → c. Stufe a ist explizit.
#
# Die Nachweise, je Stufe (PHASE-3-PLAN.md):
#
#   a  Betriebs-Selbstorganisation: jedes unblocked-Ereignis trägt ein
#      gate.sh-Verb; jede Betriebsrettung ist journaliert; keine Karte in
#      triage. (Der Planungs-Teil von Stufe A — kein Kartentext von Hand —
#      ist bewusst noch nicht prüfbar: die Graph-Generierung ist nicht gebaut.)
#   b  Schattenbetrieb: mindestens 3 Gates mit gültigem CEO-Dokument UND
#      Supervisor-Antwort; die Übereinstimmungsquote wird ausgewiesen —
#      als Zahl, nicht als Urteil. Ob sie für 'live' reicht, entscheidet
#      der Supervisor am Roadmap-Gate, nicht dieses Skript.
#   c  CEO live: jedes beantwortete CEO-Gate (Release/Irreversibel/Budget)
#      trägt [von:esf-ceo]; kein Roadmap-Gate wurde von esf-ceo beantwortet;
#      für jedes Irreversibel-Gate belegt das Journal die Einspruchsfrist;
#      keine offene Eskalation.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
CEO_JOURNAL="$VAULT/ledger/ceo-entscheidungen.jsonl"
ESK_JOURNAL="$VAULT/ledger/eskalationen.jsonl"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }
cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

fehler=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }
info() { printf '    %s\n' "$*"; }
kopf() { printf '\n\033[1m%s\033[0m\n' "$*"; }

STUFE=""
if [ "${1:-}" = "--stufe" ]; then STUFE="${2:?--stufe braucht a|b|c}"; fi
if [ -z "$STUFE" ]; then
    case "$(cad ceo_modus)" in
        live) STUFE=c ;;
        *)    STUFE=b ;;
    esac
fi
case "$STUFE" in a|b|c) ;; *) echo "FEHLER: --stufe a|b|c"; exit 2 ;; esac

printf '\n\033[1mAbschluss-Check Phase 3 — Stufe %s\033[0m\n' "$STUFE"
printf '%.0s═' $(seq 1 70); echo

# ===========================================================================
kopf "VORBEDINGUNG — zwölf Profile dispatchbar"
# ===========================================================================
assignees="$(k assignees 2>/dev/null || true)"
if [ -z "$assignees" ]; then
    nein "Board '$BOARD' nicht erreichbar — läuft die ESF überhaupt?"
else
    fehlend=""
    for name in esf-chief-of-staff esf-market-scout esf-market-analyst \
                esf-product-manager esf-architect esf-estimator esf-dev-a \
                esf-dev-b esf-reviewer esf-qa-release esf-controller esf-ceo; do
        printf '%s\n' "$assignees" | awk '{print $1, $2}' | grep -qx "$name yes" \
            || fehlend="$fehlend $name"
    done
    if [ -z "$fehlend" ]; then ok "alle zwölf Profile ON DISK = yes"
    else nein "nicht dispatchbar:$fehlend"; fi
fi

liste="$(k list --json 2>/dev/null || echo '[]')"

# Gemeinsame Zählung: unblocked-Ereignisse gegen Verb-Kommentare, je Karte.
# Dieselbe Logik wie monitor.sh — gemessen: der Grund steht im KOMMENTAR,
# das Ereignis hat eine leere Payload.
pruefe_unblocks() {
    verstoesse=0; gesamt=0
    for id in $(printf '%s' "$liste" | jq -r '.[].id'); do
        karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
        u="$(printf '%s' "$karte" | jq '[.events[]? | select(.kind=="unblocked")] | length')"
        [ "${u:-0}" -gt 0 ] || continue
        gesamt=$((gesamt + u))
        legitim="$(printf '%s' "$karte" | jq '
            [.comments[]? | (.text // .body // "")
             | select(test("^UNBLOCK: *(approve|modify|shelve|continue|cut|stop|manuell)\\b"))]
            | length')"
        if [ "${u:-0}" -gt "${legitim:-0}" ]; then
            nein "Unblock ohne gate.sh-Verb auf $id ($u Ereignisse, $legitim belegt)"
            verstoesse=$((verstoesse + 1))
        fi
    done
    [ "$verstoesse" -eq 0 ] && ok "alle $gesamt Unblock-Ereignisse tragen ein Verb"
}

# ===========================================================================
if [ "$STUFE" = "a" ]; then
# ===========================================================================
    kopf "NACHWEIS A1 — jedes unblocked-Ereignis trägt ein Verb"
    pruefe_unblocks

    kopf "NACHWEIS A2 — Betriebsrettungen sind journaliert"
    if [ ! -s "$ESK_JOURNAL" ]; then
        info "ledger/eskalationen.jsonl ist leer — kein Rettungsfall bisher"
        ok "nichts Unjournalisiertes"
    else
        r="$(jq -r 'select(.aktion=="betriebsrettung") | 1' "$ESK_JOURNAL" | wc -l | tr -d ' ')"
        n="$(jq -r 'select(.aktion=="notfall") | 1' "$ESK_JOURNAL" | wc -l | tr -d ' ')"
        ok "$r Betriebsrettung(en), $n Notfall/Notfälle journaliert"
    fi

    kopf "NACHWEIS A3 — keine Karte in triage"
    t="$(printf '%s' "$liste" | jq '[.[] | select(.status=="triage")] | length')"
    [ "${t:-0}" -eq 0 ] && ok "triage ist leer" || nein "$t Karte(n) in triage"

    kopf "OFFEN (bewusst) — Selbstplanung"
    info "Der Nachweis 'kein Kartentext von Hand' ist erst prüfbar, wenn die"
    info "Graph-Generierung durch esf-chief-of-staff gebaut ist (PHASE-3-PLAN.md)."
fi

# ===========================================================================
if [ "$STUFE" = "b" ]; then
# ===========================================================================
    kopf "NACHWEIS B1 — mindestens 3 Schatten-Vergleiche"
    if [ ! -s "$CEO_JOURNAL" ]; then
        nein "ledger/ceo-entscheidungen.jsonl ist leer — kein einziges CEO-Dokument"
    else
        v="$(jq -r 'select(.status=="schatten-vergleich") | 1' "$CEO_JOURNAL" | wc -l | tr -d ' ')"
        if [ "${v:-0}" -ge 3 ]; then
            ok "$v Gates mit CEO-Dokument UND Supervisor-Antwort"
        else
            nein "erst $v von 3 Schatten-Vergleichen"
        fi
        kopf "NACHWEIS B2 — die Übereinstimmungsquote, als Zahl"
        gleich="$(jq -r 'select(.status=="schatten-vergleich") | select(.uebereinstimmung==true) | 1' "$CEO_JOURNAL" | wc -l | tr -d ' ')"
        if [ "${v:-0}" -gt 0 ]; then
            info "Übereinstimmung: $gleich von $v"
            jq -r 'select(.status=="schatten-vergleich")
                   | "    \(.gate)  esf-ceo=\(.verb)  supervisor=\(.supervisor_verb)  übereinstimmend=\(.uebereinstimmung)"' \
                "$CEO_JOURNAL"
            ok "Quote ausgewiesen — ob sie für 'live' reicht, entscheidet der Supervisor am Roadmap-Gate"
        else
            nein "keine Vergleiche — keine Quote"
        fi
        kopf "NACHWEIS B3 — kein Dokument zweimal abgewiesen ohne Eskalation"
        zweimal="$(jq -r 'select(.status=="dokument-abgewiesen") | .gate' "$CEO_JOURNAL" | sort | uniq -d)"
        if [ -n "$zweimal" ]; then
            for g in $zweimal; do
                esk="$(jq -r --arg g "$g" 'select(.gate==$g) | select(.status=="eskaliert") | 1' "$CEO_JOURNAL" | wc -l | tr -d ' ')"
                [ "${esk:-0}" -ge 1 ] && ok "$g: zweimal abgewiesen, korrekt eskaliert" \
                                      || nein "$g: zweimal abgewiesen, NICHT eskaliert"
            done
        else
            ok "kein Gate mit zwei abgewiesenen Dokumenten"
        fi
    fi
fi

# ===========================================================================
if [ "$STUFE" = "c" ]; then
# ===========================================================================
    kopf "NACHWEIS C1 — jedes unblocked-Ereignis trägt ein Verb"
    pruefe_unblocks

    kopf "NACHWEIS C2 — CEO-Gates von esf-ceo, Roadmap-Gates nie"
    gates_gesamt=0; ceo_beantwortet=0
    for id in $(printf '%s' "$liste" | jq -r '.[] | select(.title|startswith("GATE ")) | .id'); do
        titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
        karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
        u="$(printf '%s' "$karte" | jq '[.events[]? | select(.kind=="unblocked")] | length')"
        [ "${u:-0}" -gt 0 ] || continue
        gates_gesamt=$((gates_gesamt + 1))
        von_ceo="$(printf '%s' "$karte" | jq '
            [.comments[]? | (.text // .body // "")
             | select(test("^UNBLOCK: .*\\[von:esf-ceo\\]"))] | length')"
        case "$titel" in
            "GATE Roadmap"*)
                [ "${von_ceo:-0}" -eq 0 ] && ok "$id Roadmap-Gate: vom Supervisor beantwortet" \
                                          || nein "$id Roadmap-Gate wurde von esf-ceo beantwortet — nicht delegierbar" ;;
            *)
                if [ "${von_ceo:-0}" -ge 1 ]; then
                    ok "$id $titel: [von:esf-ceo]"
                    ceo_beantwortet=$((ceo_beantwortet + 1))
                else
                    nein "$id $titel: ohne [von:esf-ceo] beantwortet — im Live-Modus ist das ein Supervisor-Eingriff, der zählt"
                fi ;;
        esac
    done
    [ "$gates_gesamt" -gt 0 ] || nein "kein einziges beantwortetes Gate — Stufe C braucht ein volles Release"

    kopf "NACHWEIS C3 — Einspruchsfrist am Irreversibel-Gate belegt"
    irr="$(printf '%s' "$liste" | jq -r '[.[] | select(.title|startswith("GATE Irreversibel"))] | length')"
    if [ "${irr:-0}" -eq 0 ]; then
        info "kein Irreversibel-Gate in diesem Lauf"
        ok "nichts zu belegen"
    elif [ -s "$CEO_JOURNAL" ]; then
        f="$(jq -r 'select(.status=="validiert") | select(.frist_stunden != null) | 1' "$CEO_JOURNAL" | wc -l | tr -d ' ')"
        [ "${f:-0}" -ge 1 ] && ok "$f Validierung(en) mit Frist journaliert" \
                            || nein "Irreversibel-Gate vorhanden, aber keine Frist-Zeile im Journal"
    else
        nein "ledger/ceo-entscheidungen.jsonl ist leer"
    fi

    kopf "NACHWEIS C4 — keine offene Eskalation"
    if [ -s "$ESK_JOURNAL" ]; then
        n="$(jq -r 'select(.aktion=="notfall") | 1' "$ESK_JOURNAL" | wc -l | tr -d ' ')"
        if [ "${n:-0}" -gt 0 ]; then
            info "$n Notfall-Zeile(n) im Journal — je Karte prüfen, ob behoben:"
            jq -r 'select(.aktion=="notfall") | "    \(.karte)  \(.klasse)  \(.text)"' "$ESK_JOURNAL" | tail -10
            # Behoben = die Karte ist heute weder blocked noch triage.
            offen=0
            for kid in $(jq -r 'select(.aktion=="notfall") | .karte' "$ESK_JOURNAL" | sort -u); do
                st="$(printf '%s' "$liste" | jq -r --arg i "$kid" '.[] | select(.id==$i) | .status // empty')"
                case "$st" in blocked|triage) nein "Notfall auf $kid weiterhin offen ($st)"; offen=1 ;; esac
            done
            [ "$offen" -eq 0 ] && ok "alle journalierten Notfälle sind vom Board verschwunden"
        else
            ok "keine Notfall-Zeile im Journal"
        fi
    else
        ok "Journal leer — kein Notfall"
    fi
fi

echo
if [ "$fehler" -eq 0 ]; then
    printf '\033[32m✓ Stufe %s: alle Nachweise grün.\033[0m\n' "$STUFE"
else
    printf '\033[31m✗ Stufe %s unvollständig — siehe oben.\033[0m\n' "$STUFE"
fi
exit "$fehler"
