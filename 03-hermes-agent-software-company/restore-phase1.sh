#!/usr/bin/env bash
#
# ESF — Den Phase-1-Stand wiederherstellen
# ========================================
#
#   ./restore-phase1.sh            Vault-Artefakte zurückspielen
#   ./restore-phase1.sh --ledger   dazu die gemessenen Phase-0/1-Zeiten nachbuchen
#   ./restore-phase1.sh --pruefen  nur nachsehen, nichts schreiben
#
# Phase 2 setzt Phase 1 voraus. Zwischen beiden lag in diesem Repo ein Rückbau:
# Das Board ist leer, `workspace/company/` kam frisch aus `seed/`. Die Phase-1-
# Artefakte liegen als Akte in `beispiel-lauf-1/` — dieses Skript spielt sie
# zurück, damit Phase 2 nicht auf einem leeren Vault anfängt und die
# Analyse-Arbeit nicht für Geld ein zweites Mal gemacht wird.
#
# WAS NICHT ZURÜCKKOMMT: die Karten-Historie. Die `esf-karte`-Metas der
# wiederhergestellten Dokumente nennen IDs, die es auf dem Board nicht mehr gibt.
# Nachschlagen geht nur in `beispiel-lauf-1/board.json`. Das ist eine echte
# Lücke im Weg vom Dokument zurück zur Entscheidung (AGENTS.md 2.2), und sie
# steht deshalb als Hinweis im Vault statt still zu bleiben.
#
# ---------------------------------------------------------------------------
# Der Ledger-Backfill (--ledger) — und warum er keine Erfindung ist
# ---------------------------------------------------------------------------
# `ledger/estimates.jsonl` ist leer: ledger-sync.sh ist über die Phase-1-Karten
# nie gelaufen. Ein esf-estimator ohne Ledger darf nach AGENTS.md 6 keine Zahl
# schreiben — und ohne Zahl gibt es kein (Schätzung, Ist)-Paar, also keinen
# Phase-2-Nachweis.
#
# Die Wanduhrzeiten der zehn Phase-0/1-Karten sind aber GEMESSEN. Sie stehen in
# beispiel-lauf-1/board.json als Board-Zeitstempel (runs[].started_at/ended_at)
# — genau die Quelle, die Kapitel 8 als die verlässliche benennt. Dieses Skript
# bucht sie nach, mit drei Regeln:
#
#   1. `estimate` bleibt `null`. Die Karten trugen keine Schätzung; eine
#      nachträglich hineingeschriebene wäre die vergiftete Kalibrierung.
#   2. Die Referenzklasse wird ZUGEORDNET, über die sichtbare Tabelle unten.
#      Sie etikettiert gemessene Arbeit, sie schätzt nichts.
#   3. Jede Zeile trägt `"backfill": true`. Wer dem Ledger misstraut, erkennt
#      die Herkunft an der Zeile selbst.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AKTE="$HERE/beispiel-lauf-1"
VAULT="$HERE/workspace/company"
LEDGER="$VAULT/ledger/estimates.jsonl"

MIT_LEDGER=0
NUR_PRUEFEN=0
case "${1:-}" in
    --ledger)  MIT_LEDGER=1 ;;
    --pruefen) NUR_PRUEFEN=1 ;;
    "")        ;;
    *) echo "Unbekannte Option '$1'. Erlaubt: --ledger | --pruefen"; exit 2 ;;
esac

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$AKTE/vault" ] || { echo "FEHLER: Keine Akte unter $AKTE/vault"; exit 1; }
[ -d "$VAULT" ]      || { echo "FEHLER: Kein Vault unter $VAULT. Erst ./setup.sh"; exit 1; }

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Die Zuordnungstabelle: Titel-Muster → Referenzklasse
# ---------------------------------------------------------------------------
# Bash 3.2 auf macOS kennt kein `declare -A` — zwei parallele Arrays, dasselbe
# Muster wie in setup.sh und Story 11.
#
# Die Klassen benennen Tasktyp × Ort × Größe, weil genau diese drei die
# Laufzeit treiben: eine Analyse im Vault ist etwas anderes als ein Bau im
# Worktree, und ein Review, das fremde Tests ausführt, etwas anderes als eine
# Nachschlagekarte. Die Größenbuchstaben sind die des Roadmap-Vokabulars
# (S < M < L).
MUSTER=(
    'Probelauf 1/4'
    'Probelauf 2/4'
    'Probelauf 3/4'
    'Onboarding 1/6'
    'Onboarding 2/6'
    'Onboarding 3/6'
    'Onboarding 4/6'
    'Onboarding 5/6'
    'GATE'
)
KLASSEN=(
    'spec-vault-S'
    'impl-worktree-S'
    'review-repo-S'
    'analyse-vault-L'
    'analyse-vault-L'
    'analyse-vault-L'
    'e2e-repo-L'
    'plan-vault-M'
    'gate-vault-S'
)

klasse_von() {
    local titel="$1" i
    for i in "${!MUSTER[@]}"; do
        case "$titel" in *"${MUSTER[$i]}"*) printf '%s' "${KLASSEN[$i]}"; return 0 ;; esac
    done
    printf 'unklassifiziert'
}

# ---------------------------------------------------------------------------
say "Akte"
# ---------------------------------------------------------------------------
gesichert="$(jq -r '.gesichert_am // "?"' "$AKTE/board.json" 2>/dev/null)"
echo "  $AKTE  (gesichert $gesichert)"
echo "  Ziel:  $VAULT"

# ---------------------------------------------------------------------------
say "1  Analyse-Artefakte, Roadmap-Stände, Spezifikation"
# ---------------------------------------------------------------------------
# Bewusst NICHT kopiert:
#   AGENTS.md, cadence.yaml  — die kommen aus seed/ und sind dort der Master.
#                              Ein Rückspielen aus der Akte würde eine
#                              zwischenzeitliche Korrektur am Seed überschreiben.
#   sources/                 — liegt schon im Seed und ist dort vollständig.
#   ledger/                  — leer in der Akte; siehe --ledger unten.
#   reports/                 — Berichte des ersten Laufs. Sie gehören zur Akte
#                              des ersten Laufs, nicht in den Vault des zweiten;
#                              ein Sprint-Report von damals würde die
#                              Phase-2-Prüfung fälschlich grün färben.
kopiert=0
for unter in analysis roadmap specs decisions; do
    [ -d "$AKTE/vault/$unter" ] || continue
    for datei in "$AKTE/vault/$unter"/*; do
        [ -f "$datei" ] || continue
        ziel="$VAULT/$unter/$(basename "$datei")"
        if [ "$NUR_PRUEFEN" -eq 1 ]; then
            if [ -f "$ziel" ]; then ok "$unter/$(basename "$datei") liegt bereits"
            else warn "$unter/$(basename "$datei") fehlt"; fi
            continue
        fi
        mkdir -p "$VAULT/$unter"
        cp "$datei" "$ziel"
        ok "$unter/$(basename "$datei")  ($(wc -c < "$ziel" | tr -d ' ') Byte)"
        kopiert=$((kopiert + 1))
    done
done
[ "$NUR_PRUEFEN" -eq 0 ] && echo "  $kopiert Datei(en)"

# ---------------------------------------------------------------------------
say "2  Der Hinweis auf die toten Karten-IDs"
# ---------------------------------------------------------------------------
HINWEIS="$VAULT/analysis/HERKUNFT.txt"
if [ "$NUR_PRUEFEN" -eq 1 ]; then
    [ -f "$HINWEIS" ] && ok "HERKUNFT.txt liegt" || warn "HERKUNFT.txt fehlt"
else
    # Bewusst .txt und nicht .html: AGENTS.md 2.1 nimmt Maschinenprotokolle und
    # Rohbelege aus der HTML-Pflicht aus, und das hier ist ein Herkunftsvermerk,
    # kein Dokument. Der Vault-Linter prüft nur .html.
    cat > "$HINWEIS" <<EOF
HERKUNFT DIESER ARTEFAKTE
=========================
Erzeugt von restore-phase1.sh am $(date '+%Y-%m-%d %H:%M').

Die Dateien in analysis/, roadmap/, specs/ und decisions/ stammen aus dem
Phase-0/1-Lauf vom 17.08.2026 und wurden aus der Akte

    03-hermes-agent-software-company/beispiel-lauf-1/vault/

zurückgespielt, nachdem der Rückbau das Board und den Arbeits-Vault geräumt
hatte. Der Inhalt ist unverändert.

WAS DAS FÜR DIE BELEGKETTE BEDEUTET
Die <meta name="esf-karte">-Angaben nennen Karten-IDs des ERSTEN Laufs
(t_3c0f38b8, t_cb915d07, t_1dbfd0c6, t_eb30ed57, t_b4da6586, t_8a275a77,
t_3f15fa7f, t_3f496fe8, t_43cc8968, t_b28eaa18). Diese Karten gibt es auf dem
Board 'sw-company' nicht mehr.

Nachschlagen — mit voller Ereignis-Historie, Blockgründen und
Abschluss-metadata — geht in

    beispiel-lauf-1/board.json

Der Weg vom Dokument zurück zur Entscheidung führt also über die Akte, nicht
über das Board. Das ist eine Lücke, nicht eine Formalie: AGENTS.md 2.2 verlangt
die Karte, damit dieser Weg da ist, und ein 'hermes kanban show' auf eine dieser
IDs läuft ins Leere.

Karten, die AB Phase 2 entstehen, tragen wieder lebende IDs.
EOF
    ok "analysis/HERKUNFT.txt geschrieben"
fi

# ---------------------------------------------------------------------------
if [ "$MIT_LEDGER" -eq 1 ] || [ "$NUR_PRUEFEN" -eq 1 ]; then
say "3  Ledger-Backfill aus den gemessenen Phase-0/1-Zeiten"
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$LEDGER")"; : >> "$LEDGER"

# Die Akte hält die Karten unter .karten; jede mit ihren Läufen. Wanduhrzeit ist
# die Summe der Laufdauern (Unix-Epoch-Sekunden, kein ISO-8601 — die Verwechslung
# hat im ersten Lauf vier Skripte lautlos falsch rechnen lassen).
karten="$(jq -c '.karten[]? // empty' "$AKTE/board.json" 2>/dev/null)"
if [ -z "$karten" ]; then
    warn "beispiel-lauf-1/board.json enthält keine Karten — kein Backfill möglich"
else
    neu=0; schon=0; ohne_zeit=0
    while IFS= read -r karte; do
        # Die Akte kann die Karte flach (Board-Liste) oder als show-Objekt
        # (.task/.runs) halten. Beide Formen zulassen, statt eine anzunehmen.
        id="$(printf '%s' "$karte"    | jq -r '.id // .task.id // empty')"
        titel="$(printf '%s' "$karte" | jq -r '.title // .task.title // empty')"
        profil="$(printf '%s' "$karte" | jq -r '.assignee // .task.assignee // "unbekannt"')"
        status="$(printf '%s' "$karte" | jq -r '.status // .task.status // "?"')"
        [ -n "$id" ] || continue

        # Nur fertige Karten. Eine abgebrochene Karte hat eine Laufzeit, aber
        # kein Ergebnis — sie in eine Referenzklasse zu buchen, verzerrt jede
        # künftige Schätzung nach unten.
        [ "$status" = "done" ] || continue

        if grep -q "\"task_id\": *\"$id\"" "$LEDGER" 2>/dev/null; then
            schon=$((schon + 1)); continue
        fi

        laeufe="$(printf '%s' "$karte" | jq -c '[(.runs // [])[] | select(.started_at and .ended_at)]')"
        n_laeufe="$(printf '%s' "$laeufe" | jq 'length')"
        minuten="$(printf '%s' "$laeufe" | jq 'if length==0 then null
                                               else ([.[] | (.ended_at - .started_at)] | add / 60 | floor) end')"
        if [ "$minuten" = "null" ]; then
            ohne_zeit=$((ohne_zeit + 1)); continue
        fi

        klasse="$(klasse_von "$titel")"
        standby=false
        [ "$minuten" -gt 240 ] 2>/dev/null && standby=true

        zeile="$(jq -n -c \
            --arg id "$id" --arg klasse "$klasse" --arg profil "$profil" \
            --arg titel "$titel" --arg at "$gesichert" \
            --argjson minuten "$minuten" --argjson laeufe "$n_laeufe" \
            --argjson standby "$standby" \
            '{task_id:$id, reference_class:$klasse, profile:$profil,
              estimate:null,
              actual:{wall_minutes:$minuten, runs:$laeufe, standby_overlap:$standby,
                      tokens_k:null, cost_usd:null},
              backfill:true, title:$titel,
              comment:"Nachgebucht aus beispiel-lauf-1/board.json. Gemessene Wanduhr, keine Schaetzung: die Karte trug keine. Klasse per Titel-Muster zugeordnet (restore-phase1.sh).",
              at:$at}')"

        if [ "$NUR_PRUEFEN" -eq 1 ]; then
            printf '  würde buchen: %-14s %-18s %3s min  %s\n' "$id" "$klasse" "$minuten" "$titel"
        else
            printf '%s\n' "$zeile" >> "$LEDGER"
            printf '  %-14s %-18s %3s min  %s\n' "$id" "$klasse" "$minuten" "$titel"
        fi
        neu=$((neu + 1))
    done <<< "$karten"

    echo
    echo "  $neu nachgebucht, $schon bereits erfasst, $ohne_zeit ohne verwertbare Laufzeit"

    if [ -s "$LEDGER" ]; then
        echo
        echo "  Referenzklassen im Ledger:"
        jq -rs 'group_by(.reference_class)
                | map({k:.[0].reference_class, n:length,
                       min:([.[].actual.wall_minutes|select(.!=null)]|min),
                       med:([.[].actual.wall_minutes|select(.!=null)]|sort|if length==0 then null else .[length/2|floor] end),
                       max:([.[].actual.wall_minutes|select(.!=null)]|max)})
                | .[] | "    \(.k): n=\(.n)  min/med/max = \(.min//"–")/\(.med//"–")/\(.max//"–") min"' \
            "$LEDGER" 2>/dev/null || echo "    (noch nicht auswertbar)"
    fi
fi
fi

# ---------------------------------------------------------------------------
if [ "$NUR_PRUEFEN" -eq 0 ]; then
say "4  Vault-Linter über den wiederhergestellten Stand"
# ---------------------------------------------------------------------------
if python3 "$HERE/scripts/vault-lint.py" "$VAULT" > /tmp/esf-restore-lint.$$ 2>&1; then
    ok "sauber"
else
    warn "beanstandet:"
    grep '^ERROR' /tmp/esf-restore-lint.$$ | head -10 | sed 's/^/      /'
fi
rm -f /tmp/esf-restore-lint.$$

if [ -d "$VAULT/.git" ]; then
    git -C "$VAULT" add -A
    if git -C "$VAULT" diff --cached --quiet; then
        ok "Vault unverändert — nichts zu committen"
    else
        git -C "$VAULT" -c user.name="esf-restore" -c user.email="esf-restore@esf.local" \
            commit -q -m "Phase-1-Stand aus beispiel-lauf-1/ wiederhergestellt" && \
        ok "Vault committet ($(git -C "$VAULT" rev-parse --short HEAD))"
    fi
fi

cat <<EOF

Weiter:
  ./create-sprint.sh 1            den S1-Graphen anlegen
  ./pump.sh                       takten
  ./scripts/watchdog.sh --kill    zwischendurch — lange Karten hängen an CLOSE_WAIT
EOF
fi
