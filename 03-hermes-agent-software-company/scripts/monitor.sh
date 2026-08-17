#!/usr/bin/env bash
#
# ESF — Monitor
# =============
#
#   scripts/monitor.sh [--json]
#
# Stündlich. Liest das EREIGNIS-LOG, nicht `diagnostics` — die stillen Ausfälle
# von Hermes sind genau die, die `diagnostics` nicht zeigt:
#
#   respawn_guarded     Karte sieht aus wie "wartend" und wird nie wieder
#                       gestartet. Der häufigste Auslöser ist ein Fehlertext,
#                       der nach Quota/Billing aussieht — z.B. ein OpenRouter-
#                       Key am USD-Limit.
#   block_loop_detected Karte wurde zweimal mit derselben Block-Art blockiert
#                       und ist still nach `triage` gekippt. Sie fragt niemanden
#                       mehr, und nichts warnt davor.
#   crashed             abgebrochener Lauf
#   unblock ohne Verb   ein Worker hat sich selbst freigeschaltet
#                       (Governance-Verstoss, siehe AGENTS.md 7)
#
# Zweite Aufgabe: die ABSCHLUSS-ERKENNUNG. Ist eine Kadenz-Ebene inhaltlich
# voll, legt der Monitor die nächste Abschluss-Karte an. So treibt sich die
# Kadenz von unten nach oben — kalenderunabhängig.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
JSON_AUS=0
[ "${1:-}" = "--json" ] && JSON_AUS=1

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

liste="$(k list --json 2>/dev/null || echo '[]')"
befunde="[]"

melde() { # grad text id
    befunde="$(printf '%s' "$befunde" | jq --arg g "$1" --arg t "$2" --arg i "${3:-}" \
        '. + [{grad:$g, text:$t, karte:$i}]')"
}

# ---------------------------------------------------------------------------
# 1. Stille Ausfälle im Ereignis-Log
# ---------------------------------------------------------------------------
for id in $(printf '%s' "$liste" | jq -r '.[].id'); do
    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
    ereignisse="$(printf '%s' "$karte" | jq -c '.events // []')"
    [ -n "$ereignisse" ] || continue

    for art in respawn_guarded block_loop_detected crashed; do
        n="$(printf '%s' "$ereignisse" | jq --arg a "$art" '[.[] | select(.kind==$a)] | length')"
        # ${n} geklammert: Ohne Klammern liest Bash 3.2 das folgende '×'
        # (Mehrbyte-Zeichen) als Teil des Variablennamens und bricht unter
        # `set -u` mit "unbound variable" ab — ausgerechnet das Skript, das
        # stille Ausfälle melden soll, fiel dadurch selbst still aus.
        if [ "${n:-0}" -gt 0 ]; then
            melde ERROR "$art (${n}x)" "$id"
        fi
    done

    # AGENTS.md 7: Ein Unblock ohne gültiges Verb-Präfix kam nicht von gate.sh.
    #
    # Gemessen: Das `unblocked`-EREIGNIS trägt eine leere Payload — der Grund
    # landet als KOMMENTAR mit dem Präfix "UNBLOCK: ". Wer hier auf
    # .payload.reason prüft, meldet jede legitime Gate-Antwort als Verstoss und
    # hat nach drei Tagen einen Alarm, den niemand mehr liest.
    #
    # Verglichen wird deshalb die Anzahl: so viele Unblock-Ereignisse wie
    # Kommentare mit gültigem Verb. Ein Ereignis ohne passenden Kommentar hat
    # gate.sh nicht geschrieben.
    unblocks="$(printf '%s' "$ereignisse" | jq '[.[] | select(.kind=="unblocked")] | length')"
    legitim="$(printf '%s' "$karte" | jq '
        [.comments[]? | (.text // .body // "")
         | select(test("^UNBLOCK: *(approve|modify|shelve|continue|cut|stop|manuell)\\b"))]
        | length')"
    if [ "${unblocks:-0}" -gt "${legitim:-0}" ]; then
        melde ERROR "Unblock ohne gate.sh-Verb ($unblocks Ereignisse, $legitim belegt) — AGENTS.md 7" "$id"
    fi
done

# ---------------------------------------------------------------------------
# 2. Karten, die still nach triage gekippt sind
# ---------------------------------------------------------------------------
for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="triage") | .id'); do
    titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    melde ERROR "in TRIAGE, fragt niemanden mehr: $titel" "$id"
done

# ---------------------------------------------------------------------------
# 3. OpenRouter: Verbrauch und Restguthaben
# ---------------------------------------------------------------------------
# Läuft ein Key gegen sein USD-Limit, sehen die Fehlertexte nach Billing aus —
# exakt das Muster, auf das die Respawn-Sperre anspringt. Beides muss zusammen
# geprüft werden, sonst sieht man die Ursache nie neben der Wirkung.
#
# Seit scripts/assign-keys.sh gilt: Die Worker benutzen NICHT mehr den Root-Key,
# sondern je Rolle einen eigenen. Ein Monitor, der nur $OPENROUTER_API_KEY
# abfragt, beobachtet dann einen Key, mit dem gar nicht gearbeitet wird —
# er meldet ewig 0 USD, während elf andere laufen. Also erst die Profil-Keys.
key_quelle=""
if [ -x "$HERE/assign-keys.sh" ] && [ -f "$ESF/key-zuordnung.txt" ]; then
    verbrauch="$("$HERE/assign-keys.sh" --verbrauch 2>/dev/null \
                 | awk 'NF==3 && $1 ~ /^esf-/ {print $1, $2, $3}')"
    if [ -n "$verbrauch" ]; then
        key_quelle="profile"
        gesamt=0
        while read -r profil genutzt limit; do
            case "$genutzt" in ''|*[!0-9.]*) continue ;; esac
            gesamt="$(python3 -c "print(round($gesamt + $genutzt, 8))")"
            # `limit: kein` ist der Normalfall bei von Hand erzeugten Keys —
            # gemessen an allen elf. Ein Deckel-Alarm ist dann schlicht nicht
            # möglich, und so zu tun, als überwache man ihn, wäre gelogen.
            [ "$limit" = "kein" ] && continue
            rest="$(python3 -c "print(round($limit - $genutzt, 8))" 2>/dev/null || echo "")"
            case "$rest" in
                -*|0|0.0|0.00*) melde ERROR "$profil am USD-Limit — Karten bleiben still auf ready" "" ;;
            esac
        done <<< "$verbrauch"
        # Über `melde` statt per printf: Der Bericht wird gesammelt und am
        # Ende ausgegeben (und mit --json als JSON). Ein direktes printf
        # erschiene vor der eigenen Überschrift.
        melde INFO "OpenRouter: $gesamt USD über elf Rollen-Keys" ""
        while read -r profil genutzt _; do
            case "$genutzt" in ''|0|0.0) continue ;; esac
            melde INFO "  $profil: $genutzt USD" ""
        done <<< "$verbrauch"
    fi
fi

if [ "$key_quelle" = "profile" ]; then
    :
elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
    melde WARN "kein Key je Rolle zugeordnet — gemessen wird der Root-Key" ""
    antwort="$(curl -fsS --max-time 15 https://openrouter.ai/api/v1/key \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" 2>/dev/null || true)"
    if [ -n "$antwort" ]; then
        limit="$(printf '%s' "$antwort" | jq -r '.data.limit // "ohne Limit"')"
        genutzt="$(printf '%s' "$antwort" | jq -r '.data.usage // 0')"
        melde INFO "OpenRouter: $genutzt USD genutzt, Limit $limit" ""
        if [ "$limit" != "ohne Limit" ] && [ "$limit" != "null" ]; then
            rest="$(printf '%s' "$antwort" | jq -r '(.data.limit - .data.usage)')"
            case "$rest" in
                -*|0|0.*) melde ERROR "OpenRouter-Key am Limit — Karten bleiben still auf ready" "" ;;
            esac
        fi
    else
        melde WARN "OpenRouter-API nicht erreichbar — Kostenstand unbekannt" ""
    fi
else
    melde WARN "OPENROUTER_API_KEY nicht gesetzt — kein Kostenstand, kein Limit-Alarm" ""
fi

# ---------------------------------------------------------------------------
# 4. Abschluss-Erkennung
# ---------------------------------------------------------------------------
# Ein billiger, tokenfreier jq-Check: Ist eine Ebene inhaltlich voll, entsteht
# die nächste Abschluss-Karte. Kein Modell entscheidet, ob etwas fertig ist.
offen_gesamt="$(printf '%s' "$liste" | jq '[.[] | select(.status=="ready" or .status=="running" or .status=="todo")] | length')"
alle="$(printf '%s' "$liste" | jq 'length')"

if [ "$alle" -gt 0 ] && [ "$offen_gesamt" -eq 0 ]; then
    blockiert="$(printf '%s' "$liste" | jq '[.[] | select(.status=="blocked")] | length')"
    if [ "$blockiert" -eq 0 ]; then
        melde INFO "Alle Karten fertig, kein Gate offen — die Ebene ist abgeschlossen" ""
    fi
fi

# Sprint-Ebene: alle Karten mit derselben Sprint-Zugehörigkeit sind fertig.
#
# Die Sprint-Marke steht im Abschluss-metadata des LAUFS (.runs[].metadata.sprint)
# — Karten tragen kein metadata-Feld. Eine Karte, die noch nie gelaufen ist, hat
# also keine Marke; deshalb kommt die Zuordnung zusätzlich aus dem Titel-Präfix
# "S<nr> ", das der Chief of Staff setzt. Nur so zählt eine offene Karte
# überhaupt mit — sonst gälte ein Sprint als voll, sobald seine erste Karte
# fertig ist.
sprint_von_titel() { printf '%s' "$1" | sed -n 's/^\(S[0-9][0-9]*\) .*/\1/p'; }

for sprint in $(printf '%s' "$liste" | jq -r '.[].title' | sed -n 's/^\(S[0-9][0-9]*\) .*/\1/p' | sort -u); do
    gesamt="$(printf '%s' "$liste" | jq --arg s "$sprint" '[.[] | select(.title | startswith($s + " "))] | length')"
    fertig="$(printf '%s' "$liste" | jq --arg s "$sprint" '[.[] | select((.title | startswith($s + " ")) and .status=="done")] | length')"
    if [ "$gesamt" -gt 0 ] && [ "$gesamt" -eq "$fertig" ]; then
        abschluss="$(printf '%s' "$liste" | jq -r --arg s "$sprint" \
            '[.[] | select(.title | startswith("Sprint-Abschluss " + $s))] | length')"
        if [ "$abschluss" -eq 0 ]; then
            k create "Sprint-Abschluss $sprint" \
                --assignee esf-chief-of-staff \
                --workspace "dir:$VAULT" \
                --idempotency-key "sprint-abschluss-$sprint" \
                --max-retries 2 --max-runtime 30m \
                --body "Alle $gesamt Karten von Sprint $sprint sind fertig.

Schliesse den Sprint ab:
1. scripts/check-sprint.sh $sprint laufen lassen — der Check entscheidet, nicht du.
2. Sprint-Report nach reports/sprint-$sprint-report.html (AGENTS.md 5).
3. Für jede Karte das (Schätzung, Ist)-Paar an esf-controller übergeben.
4. Nächsten Sprint aus der Roadmap planen — oder, wenn der Härtungs-Sprint
   fertig ist, die Release-Abschluss-Karte anlegen." >/dev/null 2>&1 \
                && melde INFO "Sprint $sprint ist voll — Abschluss-Karte angelegt" "" \
                || true
        fi
    fi
done

# ---------------------------------------------------------------------------
# Ausgabe
# ---------------------------------------------------------------------------
if [ "$JSON_AUS" -eq 1 ]; then
    printf '%s\n' "$befunde" | jq .
else
    printf 'ESF Monitor — %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%.0s─' $(seq 1 70); echo
    if [ "$(printf '%s' "$befunde" | jq 'length')" -eq 0 ]; then
        echo "Keine Befunde."
    else
        printf '%s' "$befunde" | jq -r '.[] | "\(.grad|.[0:5]|.+"     "|.[0:5])  \(if .karte=="" then "     " else (.karte + "    ")|.[0:5] end)  \(.text)"'
    fi
fi

fehler="$(printf '%s' "$befunde" | jq '[.[] | select(.grad=="ERROR")] | length')"
[ "$fehler" -gt 0 ] && exit 1
exit 0
