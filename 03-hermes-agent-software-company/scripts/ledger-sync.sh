#!/usr/bin/env bash
#
# ESF — Ledger-Abgleich
# =====================
#
#   scripts/ledger-sync.sh [--dry-run]
#
# Cron 23:30. Holt die Wanduhrzeiten aus dem Board und die Kosten aus der
# OpenRouter-API und schreibt jedes (Schätzung, Ist)-Paar nach
# ledger/estimates.jsonl. Das Ledger ist die einzige Quelle, aus der der
# esf-estimator schätzen darf — und es wird nur angehängt, nie umgeschrieben.
#
# Die unbequeme Wahrheit: Hermes v0.20.0 misst keine Tokens und keine Kosten.
# Verlässlich sind Board-Zeitstempel. Alles Geldwerte kommt von OpenRouter oder
# gar nicht — und "gar nicht" wird als `null` geschrieben, nicht als Schätzung.
# Eine hineingeschriebene Vermutung vergiftet jede künftige Kalibrierung.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
LEDGER="$VAULT/ledger/estimates.jsonl"
HEUTE="$(date '+%Y-%m-%d')"
DRY=0; SELBSTTEST=0
[ "${1:-}" = "--dry-run" ] && DRY=1
[ "${1:-}" = "--selbsttest" ] && SELBSTTEST=1

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ "$SELBSTTEST" -eq 1 ] || [ -d "$VAULT" ] || { echo "FEHLER: Kein Vault unter $VAULT"; exit 1; }
[ "$SELBSTTEST" -eq 1 ] || { mkdir -p "$(dirname "$LEDGER")"; : >> "$LEDGER"; }

k() { hermes kanban --board "$BOARD" "$@"; }

. "$HERE/lib-schaetzung.sh"

# ---------------------------------------------------------------------------
# Selbsttest — hermes-frei, board-frei
# ---------------------------------------------------------------------------
# Der laute Pfad aus Bedingung 2b laesst sich am echten Board nicht ausloesen,
# ohne dafuer Karten anzulegen. Er ist aber der Pfad, auf den es ankommt: Ein
# Aufloesungsweg, der bei fehlendem Anker stumm ein null einsetzt, waere
# schlimmer als die Kopie, die er ersetzt. Also wird `k` hier gestubbt.
if [ "$SELBSTTEST" -eq 1 ]; then
    printf '\n\033[1mledger-sync Selbsttest (hermes-frei)\033[0m\n'
    fehler=0
    ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
    nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }

    STUB_META='{}'
    k() { # nur `show <id> --json` wird gebraucht
        printf '{"runs":[{"metadata":%s}]}' "$STUB_META"
    }
    karte_mit() { # titel eltern -> karten-json
        jq -n -c --arg t "$1" --arg e "$2" '{task:{title:$t}, parents:[$e]}'
    }

    # (a) die Karten-ID schlaegt den Titel
    STUB_META='{"estimates":{"t_zzz":{"reference_class":"per-id","wall_minutes":{"p50":7}},
                             "S4 F1 3/5 Umsetzung":{"reference_class":"per-titel","wall_minutes":{"p50":99}}}}'
    aus="$(schaetzer_aufloesen "$(karte_mit "S4 F1 3/5 — Umsetzung X" t_est)" t_zzz)"
    [ "$(printf '%s' "$aus" | jq -r .reference_class)" = "per-id" ] \
        && ok "Karten-ID schlaegt den Titel" || { nein "ID-Weg greift nicht: $aus"; }

    # (b) Rueckfall ueber den Titel-Praefix — der Altbestand ist so geschluesselt
    STUB_META='{"estimates":{"S4 F1 3/5 Umsetzung":{"reference_class":"per-titel","wall_minutes":{"p50":99}}}}'
    aus="$(schaetzer_aufloesen "$(karte_mit "S4 F1 3/5 — Umsetzung X" t_est)" t_zzz)"
    [ "$(printf '%s' "$aus" | jq -r .reference_class)" = "per-titel" ] \
        && ok "Rueckfall ueber eindeutigen Titel-Praefix" || nein "Praefix-Weg greift nicht: $aus"

    # (c) zwei passende Schluessel sind ein ABBRUCH, keine Auswahl
    STUB_META='{"estimates":{"S4 F1 3/5 Umsetzung":{"wall_minutes":{"p50":1}},
                             "S4 F1 3/5 — Umsetzung":{"wall_minutes":{"p50":2}}}}'
    if schaetzer_aufloesen "$(karte_mit "S4 F1 3/5 — Umsetzung X" t_est)" t_zzz >/dev/null 2>&1; then
        nein "Mehrdeutigkeit wird stillschweigend aufgeloest — genau der Fehler aus 2b"
    else ok "Mehrdeutigkeit bricht ab, statt zu raten"; fi

    # (d) Schaetzer da, kennt die Karte aber nicht -> LAUT
    STUB_META='{"estimates":{"S9 F9 9/9 Etwas":{"wall_minutes":{"p50":1}}}}'
    if schaetzer_aufloesen "$(karte_mit "S4 F1 3/5 — Umsetzung X" t_est)" t_zzz >/dev/null 2>&1; then
        nein "fehlende Schaetzung wird still hingenommen — Bedingung 2b verletzt"
    else ok "Schaetzer ohne Eintrag fuer die Karte: lautes Scheitern"; fi

    # (e) gar kein Schaetzer-Elternteil ist KEIN Fehler (S1, Spezifikationskarten)
    aus="$(schaetzer_aufloesen "$(jq -n -c '{task:{title:"S1 Spezifikation"}, parents:[]}')" t_zzz)"; rc=$?
    [ "$rc" -eq 0 ] && [ -z "$aus" ] \
        && ok "ohne Schaetzer-Elternteil: leer und Exit 0" || nein "Leerfall falsch (rc=$rc, aus='$aus')"

    # (f) ein Elternteil OHNE estimates-Objekt wird uebersprungen, nicht bemaengelt
    STUB_META='{"verdict":"approved"}'
    aus="$(schaetzer_aufloesen "$(karte_mit "S4 F1 5/5 — Merge" t_review)" t_zzz)"; rc=$?
    [ "$rc" -eq 0 ] && [ -z "$aus" ] \
        && ok "Elternteil ohne estimates: uebersprungen, kein Befund" || nein "Nicht-Schaetzer falsch behandelt (rc=$rc)"

    exit "$fehler"
fi


# ---------------------------------------------------------------------------
# Kosten je Rolle aus den Profil-Keys
# ---------------------------------------------------------------------------
# Seit jedes Profil einen eigenen Key hat (scripts/assign-keys.sh), ist die
# Zurechnung auf Rollen keine Schätzung mehr: `GET /api/v1/key` meldet den
# Verbrauch DES KEYS, mit dem gefragt wird. Elf Keys, elf Zahlen.
#
# Zwei Dinge, die dabei leicht schiefgehen:
#
#  1. Die Zahl ist KUMULATIV, kein Tageswert. Der Tagesverbrauch ist deshalb
#     die Differenz zum letzten Schnappschuss — und den führt diese Datei
#     selbst, denn OpenRouter kennt keinen Verlauf je Key.
#  2. Der Zähler läuft dem Lauf nach (gemessen 17.08.2026: gut eine Minute).
#     Für einen Cron um 23:30 ist das ohne Belang; wer direkt nach einem Lauf
#     abgleicht, bucht einen Teil auf den nächsten Tag.
#
# Was damit AUSDRÜCKLICH nicht geht: Kosten je KARTE. Kumulativ je Key heisst
# je Rolle, nicht je Aufgabe — und eine Rolle mit fünf Karten am Tag liesse
# sich nur durch Division aufteilen. Genau das wäre die erfundene Zahl, die
# dieses Skript nicht schreibt. `cost_usd` bleibt je Karte `null`.
ROLLENKOSTEN="$VAULT/ledger/kosten-je-rolle.jsonl"
mkdir -p "$(dirname "$ROLLENKOSTEN")"; : >> "$ROLLENKOSTEN"
KOSTEN_HEUTE="null"

if [ -x "$HERE/assign-keys.sh" ] && [ -f "$ESF/key-zuordnung.txt" ]; then
    messung="$("$HERE/assign-keys.sh" --verbrauch 2>/dev/null \
               | awk 'NF==3 && $1 ~ /^esf-/ {print $1, $2}')"
    if [ -n "$messung" ]; then
        echo "Verbrauch je Rolle (kumulativ / seit dem letzten Abgleich)"
        summe=0
        while read -r profil gesamt; do
            case "$gesamt" in ''|*[!0-9.]*) continue ;; esac
            vorher="$(grep "\"profile\": *\"$profil\"" "$ROLLENKOSTEN" 2>/dev/null \
                      | tail -1 | jq -r '.usage_total // 0' 2>/dev/null || echo 0)"
            delta="$(python3 -c "print(round($gesamt - ${vorher:-0}, 8))")"
            printf '  %-22s %12s   +%s\n' "$profil" "$gesamt" "$delta"
            summe="$(python3 -c "print(round($summe + $delta, 8))")"
            if [ "$DRY" -eq 0 ]; then
                jq -n -c --arg p "$profil" --arg at "$HEUTE" \
                    --argjson g "$gesamt" --argjson d "$delta" \
                    '{at:$at, profile:$p, usage_total:$g, usage_delta:$d}' >> "$ROLLENKOSTEN"
            fi
        done <<< "$messung"
        KOSTEN_HEUTE="$summe"
    fi
fi

echo "OpenRouter-Summe seit dem letzten Abgleich: ${KOSTEN_HEUTE} USD"
[ "$KOSTEN_HEUTE" = "null" ] && cat <<'EOF'
  (nicht gemessen — kein Key je Profil zugeordnet. Die ESF läuft dann auf dem
   Root-Key, und eine Aufteilung auf Rollen gäbe es nur als Erfindung.
   Abhilfe: scripts/assign-keys.sh)
EOF

# ---------------------------------------------------------------------------
# Je fertige Karte eine Ledger-Zeile
# ---------------------------------------------------------------------------
liste="$(k list --json 2>/dev/null || echo '[]')"
neu=0; uebersprungen=0

for id in $(printf '%s' "$liste" | jq -r '.[] | select(.status=="done")
                                          | select(.title | startswith("Keyprobe") | not) | .id'); do
    # Die Prüfkarten aus scripts/check-keys.sh sind Messwerkzeug, keine Arbeit.
    # Ohne diesen Filter landet je Prüflauf eine Zeile mit
    # reference_class "unklassifiziert" und estimate null im Ledger — in der
    # einzigen Datei, aus der der esf-estimator schätzen darf und die nur
    # angehängt, nie bereinigt wird. check-keys.sh archiviert seine Karten
    # zwar selbst; dieser Filter ist die zweite Sicherung.

    # Nur einmal je Karte — das Ledger wird angehängt, nicht gepflegt.
    if grep -q "\"task_id\": *\"$id\"" "$LEDGER" 2>/dev/null; then
        uebersprungen=$((uebersprungen + 1)); continue
    fi

    karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
    profil="$(printf '%s' "$karte" | jq -r '.task.assignee // "unbekannt"')"

    # Das Abschluss-metadata eines Workers hängt am LAUF, nicht an der Karte
    # (`.runs[].metadata`) — die Karte selbst hat gar kein metadata-Feld.
    # Gültig ist der letzte Lauf, der eines geschrieben hat.
    # NORMALISIEREN, nicht nur lesen. Liberal beim Annehmen, streng beim
    # Speichern — sonst verliert das Ledger echte Messungen an einer
    # Formfrage.
    #
    # Real am 17.08.2026: Drei Karten schrieben ihre Schätzung FLACH
    # ("reference_class" auf oberster Ebene, "estimate": {"p50": 15, "p90": 40}),
    # nicht verschachtelt wie im SOUL-Schema. Die Daten waren vollständig da;
    # ledger-sync.sh und check-sprint.sh lasen nur den verschachtelten Pfad und
    # meldeten "unklassifiziert" bzw. ein zerrissenes Paar. Dieselbe
    # Fehlerklasse wie in Phase 1, wo vier Skripte `metadata` auf Kartenebene
    # statt auf Laufebene lasen: EINE Form annehmen und die andere übersehen.
    #
    # Eingeladen hat die flache Form der Kartentext selbst — er nennt
    # "reference_class 'merge-repo-S'" als eigene Zeile. Ein Modell, das das
    # wörtlich befolgt, schreibt flach. Die Schuld liegt beim Leser.
    #
    # Ins Ledger geht ausschliesslich die kanonische, verschachtelte Form.
    # Was dort steht, muss ein Auswertungsskript ohne Fallunterscheidung lesen
    # können.
    roh="$(printf '%s' "$karte" | jq -c '[.runs[]?.metadata // empty] | last // {}')"
    schaetzung="$(printf '%s' "$roh" | jq -c '
        (.estimate // null) as $e
        | (.reference_class // $e.reference_class // null)          as $klasse
        | ($e.wall_minutes // (if ($e.p50 // null) != null
                               then {p50: $e.p50, p90: ($e.p90 // null)}
                               else null end))                      as $wm
        | if $e == null and $klasse == null then null
          else {reference_class: $klasse,
                wall_minutes:    $wm,
                tokens_k:        ($e.tokens_k // null),
                cost_usd:        ($e.cost_usd // null),
                confidence:      ($e.confidence // null),
                estimated_by:    ($e.estimated_by // null),
                at:              ($e.at // null),
                basis:           ($e.basis // $e.note // null)}
          end')"
    # ------------------------------------------------------------------
    # Bedingung 2a/2b des Roadmap-Gates R2 (roadmap/r2-freigegeben.html §5):
    # Traegt die Karte selbst keine bezifferte Schaetzung, wird sie beim
    # SCHAETZER geholt — dort liegt sie autoritativ. Die manuelle Kopie durch
    # den Worker entfaellt damit als Fehlerquelle; sie ist dreimal gerissen
    # (t_e70f40ff, t_c35344ff, t_de53e678), an drei verschiedenen Karten, nach
    # zwei Nachschaerfungen des Kartentextes unveraendert bei 2/12 = 17 %.
    #
    # UEBER DIE KARTEN-ID, nicht ueber den Titel (Bedingung 2a). Gemessen am
    # 19.08.2026: Der Schaetzer schluesselte "S3 F1 3/5 Umsetzung", die Karte
    # heisst "S3 F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan". Ein
    # Titel-Nachschlagen faende NICHTS und schriebe still estimate: null —
    # dieselbe Luecke wie vorher, nur unsichtbar. Der Titel-Weg bleibt als
    # RUECKFALL fuer die Altbestaende, aber nur als eindeutiger Praefix und
    # niemals stillschweigend.
    if [ "$(printf '%s' "$schaetzung" | jq -r '.wall_minutes.p50 // "null"')" = "null" ]; then
        aufgeloest="$(schaetzer_aufloesen "$karte" "$id")" || {
            echo
            echo "ABBRUCH — $id hat einen Schaetzer-Elternteil, aber dort ist keine"
            echo "Schaetzung fuer diese Karte zu finden (Bedingung 2b: laut scheitern,"
            echo "nie still). Kein estimate: null ins Ledger."
            echo "$aufgeloest"
            echo
            echo "Nachsehen:  hermes kanban --board $BOARD show $id --json | jq .parents"
            exit 1
        }
        if [ -n "$aufgeloest" ]; then
            schaetzung="$aufgeloest"
            echo "  $id  Schaetzung beim Schaetzer aufgeloest"
        fi
    fi

    klasse="$(printf '%s' "$schaetzung" | jq -r '.reference_class // "unklassifiziert"' 2>/dev/null || echo unklassifiziert)"
    [ -n "$klasse" ] && [ "$klasse" != "null" ] || klasse="unklassifiziert"

    # Wanduhrzeit aus den Läufen — Board-Zeitstempel, nicht Modelltext.
    # Sie sind Unix-Epoch-Sekunden (Integer), kein ISO-8601.
    laeufe="$(printf '%s' "$karte" | jq -c '[.runs[]? | select(.started_at and .ended_at)]')"
    anzahl_laeufe="$(printf '%s' "$laeufe" | jq 'length')"
    minuten="$(printf '%s' "$laeufe" | jq '
        if length == 0 then null
        else ([.[] | (.ended_at - .started_at)] | add / 60 | floor) end' 2>/dev/null || echo null)"

    # Ein Lauf über eine Standby-Phase misst Schlaf, nicht Arbeit. Die
    # Heuristik: mehr als vier Stunden Wanduhr auf einer Karte ist im
    # Agentenbetrieb kein Rechnen mehr.
    standby=false
    if [ "$minuten" != "null" ] && [ "${minuten:-0}" -gt 240 ]; then standby=true; fi

    zeile="$(jq -n -c \
        --arg id "$id" --arg klasse "$klasse" --arg profil "$profil" \
        --argjson schaetzung "$schaetzung" \
        --argjson minuten "${minuten:-null}" --argjson laeufe "$anzahl_laeufe" \
        --argjson standby "$standby" --arg at "$HEUTE" \
        '{task_id:$id, reference_class:$klasse, profile:$profil,
          estimate:$schaetzung,
          actual:{wall_minutes:$minuten, runs:$laeufe, standby_overlap:$standby,
                  tokens_k:null, cost_usd:null},
          comment:"cost_usd je Karte gibt es nicht: der Key misst je Rolle. Siehe ledger/kosten-je-rolle.jsonl",
          at:$at}')"

    if [ "$DRY" -eq 1 ]; then
        printf '  würde anhängen: %s\n' "$zeile"
    else
        printf '%s\n' "$zeile" >> "$LEDGER"
    fi
    neu=$((neu + 1))
done

echo "Ledger: $neu neue Zeile(n), $uebersprungen bereits erfasst -> $LEDGER"

# ---------------------------------------------------------------------------
# Kalibrierungs-Kurzbild
# ---------------------------------------------------------------------------
if [ -s "$LEDGER" ]; then
    echo
    echo "Referenzklassen im Ledger:"
    jq -rs 'group_by(.reference_class)
            | map({klasse: .[0].reference_class,
                   n: length,
                   ist_median: ([.[].actual.wall_minutes | select(. != null)] | sort | if length==0 then null else .[length/2|floor] end)})
            | .[] | "  \(.klasse): \(.n) Karten, Ist-Median \(.ist_median // "nicht gemessen") min"' \
        "$LEDGER" 2>/dev/null || echo "  (noch nicht auswertbar)"
fi

if [ "$DRY" -eq 0 ] && [ "$neu" -gt 0 ] && [ -d "$VAULT/.git" ]; then
    git -C "$VAULT" add ledger/estimates.jsonl
    git -C "$VAULT" -c user.name="esf-controller" -c user.email="esf-controller@esf.local" \
        commit -q -m "Ledger: $neu (Schätzung, Ist)-Paar(e) vom $HEUTE" 2>/dev/null || true
fi
