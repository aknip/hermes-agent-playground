#!/usr/bin/env bash
#
# ESF — Die Notfall-Leiter
# ========================
#
#   scripts/eskalation.sh              prüfen und (je nach cadence.yaml) handeln
#   scripts/eskalation.sh --dry-run    nur zeigen
#   scripts/eskalation.sh --selbsttest hermes-frei: die Muster-Erkennung
#
# "Der Supervisor wird nur im Notfall gerufen" trägt nur, wenn CODE
# entscheidet, was ein Notfall ist — sonst entscheidet ein Modell über seine
# eigene Entmündigung. Dieses Skript ist diese Entscheidung.
#
# Die Leiter, von unten nach oben (PHASE-3-PLAN.md):
#
#   Code repariert    blockierte NICHT-Gate-Karte, Blockgrund passt auf ein
#                     bekanntes Betriebsmuster — beim ERSTEN Mal je Karte,
#                     und nur bei betriebsrettung: auto. Die Muster sind exakt
#                     die 7 manuellen Rettungs-Unblocks der Phase 2.
#   CEO entscheidet   blockierte Gate-Karten — Sache von ceo-tick.sh.
#   NOTFALL           alles, wofür es kein Muster (mehr) gibt:
#                       · Karte in triage (block_loop_detected)
#                       · respawn_guarded
#                       · zweite Betriebsrettung derselben Karte
#                       · blockierte Nicht-Gate-Karte ohne bekanntes Muster
#                       · Gate älter als gate_unbeantwortet_stunden ohne
#                         gültiges Entscheidungsdokument
#                     → Journalzeile, laute Meldung, Exit 1. Der Supervisor
#                     antwortet über ./gate.sh bzw. von Hand.
#
# Warum die Rettung nur EINMAL je Karte läuft: Der zweite Block derselben Art
# kippt die Karte ohnehin nach triage (BLOCK_RECURRENCE_LIMIT = 2) — eine
# zweite automatische Freischaltung würde also nur den Weg dorthin
# beschleunigen und den Grund verwischen.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
JOURNAL="$VAULT/ledger/eskalationen.jsonl"

# Die bekannten Betriebsmuster — jede Zeile ein grep -E über den Blockgrund.
# Quelle: die manuellen Unblocks in beispiel-lauf-2/board.json.
MUSTER='pid [0-9]+ not alive|APIConnectionError|Iteration budget|worktree add failed|Netzwerk|network|CLOSE_WAIT|timed?[_ ]?out|Zeitüberschreitung'

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

ist_betriebsmuster() { printf '%s' "$1" | grep -qiE "$MUSTER"; }

# ---------------------------------------------------------------------------
if [ "$SELBSTTEST" -eq 1 ]; then
    say "eskalation Selbsttest (hermes-frei)"
    fehler=0
    # Positiv: die Fehlertexte, die Phase 2 real produziert hat.
    while IFS= read -r text; do
        if ist_betriebsmuster "$text"; then ok "erkannt: $text"
        else nein "NICHT erkannt: $text"; fehler=1; fi
    done <<'POSITIV'
pid 36119 not alive
workspace: git worktree add failed for /Users/x/repo
APIConnectionError beim Modellaufruf
Iteration budget exhausted (500/500)
elapsed 7214s > limit 7200s (timed_out)
POSITIV
    # Negativ: Sachgründe, die NIE automatisch freigeschaltet werden dürfen.
    while IFS= read -r text; do
        if ist_betriebsmuster "$text"; then nein "FÄLSCHLICH erkannt: $text"; fehler=1
        else ok "korrekt kein Betriebsmuster: $text"; fi
    done <<'NEGATIV'
Review rejected: drei Umgehungspfade offen
Warte auf die Freigabe der Roadmap durch den CEO
Spezifikation widerspricht sich in AK8
NEGATIV
    exit "$fehler"
fi

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
command -v hermes >/dev/null || { echo "FEHLER: 'hermes' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT — erst ./setup.sh"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }
cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

RETTUNG="$(cad betriebsrettung)";            RETTUNG="${RETTUNG:-melden}"
GATE_MAX_H="$(cad gate_unbeantwortet_stunden)"; GATE_MAX_H="${GATE_MAX_H:-24}"
JETZT="$(date +%s)"
mkdir -p "$VAULT/ledger"
[ -f "$JOURNAL" ] || : > "$JOURNAL"

journal() { # karte klasse text aktion
    [ "$DRY" -eq 1 ] && return 0
    jq -cn --arg karte "$1" --arg klasse "$2" --arg text "$3" --arg aktion "$4" \
           --argjson at "$JETZT" \
        '{at:$at, karte:$karte, klasse:$klasse, text:$text, aktion:$aktion}' >> "$JOURNAL"
}

schon_gerettet() { # karte
    jq -r --arg k "$1" 'select(.karte==$k) | select(.aktion=="betriebsrettung") | 1' \
        "$JOURNAL" 2>/dev/null | grep -q 1
}

ist_gate() { case "$1" in "GATE "*) return 0 ;; *) return 1 ;; esac; }

say "Notfall-Leiter — betriebsrettung: $RETTUNG$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
liste="$(k list --json 2>/dev/null || echo '[]')"
notfaelle=0
rettungen=0

# ---------------------------------------------------------------------------
# 1. Karten in triage — immer ein Notfall
# ---------------------------------------------------------------------------
for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="triage") | .id'); do
    titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    nein "NOTFALL: $id in triage (fragt niemanden mehr, läuft aber weiter): $titel"
    journal "$id" "triage" "$titel" "notfall"
    notfaelle=$((notfaelle + 1))
done

# ---------------------------------------------------------------------------
# 2. Blockierte Karten
# ---------------------------------------------------------------------------
for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="blocked") | .id'); do
    titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
    block_ev="$(printf '%s' "$karte" | jq -r '[.events[] | select(.kind=="blocked")] | last')"
    grund="$(printf '%s' "$block_ev" | jq -r '.payload.reason // ""')"
    seit="$(printf '%s' "$block_ev" | jq -r '.created_at // empty')"

    if ist_gate "$titel"; then
        # Gates gehören dem CEO (bzw. dem Supervisor). Notfall nur, wenn sie
        # ohne gültiges Entscheidungsdokument versauern.
        [ -n "$seit" ] || continue
        alter_h=$(( (JETZT - seit) / 3600 ))
        if [ "$alter_h" -ge "$GATE_MAX_H" ]; then
            dok="$VAULT/reports/ceo-entscheid-$(printf '%s' "$id" | tr 'A-Z_' 'a-z-').html"
            if [ ! -f "$dok" ] || ! python3 "$HERE/ceo-lint.py" "$dok" >/dev/null 2>&1; then
                nein "NOTFALL: Gate $id seit ${alter_h}h ohne gültiges Entscheidungsdokument: $titel"
                journal "$id" "gate-unbeantwortet" "seit ${alter_h}h: $titel" "notfall"
                notfaelle=$((notfaelle + 1))
            fi
        fi
        continue
    fi

    # Nicht-Gate-Blockade
    if ! ist_betriebsmuster "$grund"; then
        nein "NOTFALL: $id blockiert ohne bekanntes Betriebsmuster: ${grund:-(kein Grund)}"
        printf '      Karte: %s\n' "$titel"
        journal "$id" "blockade-unbekannt" "$grund" "notfall"
        notfaelle=$((notfaelle + 1))
        continue
    fi

    if schon_gerettet "$id"; then
        nein "NOTFALL: $id braucht die ZWEITE Betriebsrettung — das ist keine Rettung mehr: $titel"
        journal "$id" "zweite-rettung" "$grund" "notfall"
        notfaelle=$((notfaelle + 1))
        continue
    fi

    if [ "$RETTUNG" != "auto" ] || [ "$DRY" -eq 1 ]; then
        warn "Betriebsmuster auf $id ('$grund') — Rettung möglich, Modus ist '$RETTUNG'$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
        warn "  von Hand: hermes kanban --board $BOARD unblock $id --reason \"manuell: betriebsrettung ($grund)\""
        journal "$id" "betriebsmuster" "$grund" "gemeldet"
        continue
    fi

    if k unblock "$id" --reason "manuell: betriebsrettung ($grund) — automatisch durch eskalation.sh, einmalig je Karte"; then
        ok "Betriebsrettung: $id freigeschaltet ($grund)"
        journal "$id" "betriebsmuster" "$grund" "betriebsrettung"
        rettungen=$((rettungen + 1))
    else
        nein "NOTFALL: unblock auf $id schlug fehl"
        journal "$id" "unblock-fehlgeschlagen" "$grund" "notfall"
        notfaelle=$((notfaelle + 1))
    fi
done

# ---------------------------------------------------------------------------
# 3. respawn_guarded — die Karte sieht wartend aus und startet nie wieder
# ---------------------------------------------------------------------------
for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="ready" or .status=="running" or .status=="todo") | .id'); do
    n="$(k show "$id" --json 2>/dev/null | jq '[.events[]? | select(.kind=="respawn_guarded")] | length' 2>/dev/null || echo 0)"
    if [ "${n:-0}" -gt 0 ]; then
        nein "NOTFALL: $id trägt respawn_guarded (${n}x) — wird nie wieder gestartet"
        journal "$id" "respawn_guarded" "${n}x" "notfall"
        notfaelle=$((notfaelle + 1))
    fi
done

echo
if [ "$notfaelle" -gt 0 ]; then
    nein "$notfaelle NOTFALL/NOTFÄLLE — der Supervisor ist gefragt. Journal: ledger/eskalationen.jsonl"
    exit 1
fi
ok "kein Notfall$( [ "$rettungen" -gt 0 ] && printf ' — %s Betriebsrettung(en) ausgeführt' "$rettungen")"
exit 0
