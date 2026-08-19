#!/usr/bin/env bash
#
# ESF — ceo-tick: Entscheidungskarten und Executor der Führungsebene
# ==================================================================
#
#   scripts/ceo-tick.sh              der volle Takt (Cron, stündlich)
#   scripts/ceo-tick.sh --dry-run    zeigen statt handeln
#   scripts/ceo-tick.sh --selbsttest hermes-frei: nur der Dokument-Riegel
#
# Was ein Lauf tut, in dieser Reihenfolge:
#
#   1. Für jedes blockierte CEO-Gate (Release/Irreversibel/Budget) ohne
#      Entscheidungskarte: EINE Entscheidungskarte für esf-ceo anlegen
#      (idempotency-key ceo-entscheid-<gate-id>). Roadmap-Gates werden nur
#      gemeldet — sie gehören dem Supervisor.
#   2. Für jedes Gate mit vorhandenem Entscheidungsdokument
#      (reports/ceo-entscheid-<id>.html): scripts/ceo-lint.py validieren und
#      dann — je nach Verb, Gate-Art und ceo_modus — ausführen, warten
#      (Einspruchsfrist), eskalieren oder nur vergleichen (Schatten).
#   3. Jede Zustandsänderung als Zeile nach ledger/ceo-entscheidungen.jsonl.
#
# Warum die Entscheidungskarte KEIN Kind der Gate-Karte ist: Kinder warten
# auf den Abschluss ihrer Eltern, und ein blockiertes Gate ist nicht
# abgeschlossen — das Kind startete nie. Die Kopplung läuft über den
# Idempotenzschlüssel und die Gate-ID im Kartentext.
#
# Warum der Executor und nicht esf-ceo das Gate öffnet: kanban_unblock bleibt
# für JEDES Profil tabu (AGENTS.md 7). Der Lauf vom 17.08. hat zweimal belegt,
# dass ein konkreter Kartentext eine SOUL schlägt — ein CEO, der selbst
# unblockt, wäre über den Text der Gate-Vorlage steuerbar. Hier validiert
# Code das Dokument und Code führt aus; manipulierbar bleibt das Urteil,
# nicht die Ausführung.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESF="$(cd "$HERE/.." && pwd)"
BOARD="sw-company"
VAULT="$ESF/workspace/company"
JOURNAL="$VAULT/ledger/ceo-entscheidungen.jsonl"

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

# ---------------------------------------------------------------------------
# Selbsttest — hermes-frei, läuft auch auf einer Maschine ohne Board
# ---------------------------------------------------------------------------
if [ "$SELBSTTEST" -eq 1 ]; then
    say "ceo-tick Selbsttest (hermes-frei)"
    fixtures="$ESF/seed/ceo-selbsttest"
    fehler=0

    # (a) das gültige Dokument passiert, und die Ausgabe ist parsebar
    aus="$(python3 "$HERE/ceo-lint.py" "$fixtures/gueltig-approve.html" --gate-art release)" || fehler=1
    verb="$(printf '%s\n' "$aus" | sed -n 's/^VERB=//p')"
    [ "$verb" = "approve" ] && ok "gültiges Dokument: VERB=approve geparst" \
                            || { nein "VERB nicht parsebar aus: $aus"; fehler=1; }

    # (b) die drei defekten Fixtures liefern zusammen GENAU 5 ERROR.
    #     Weniger heisst, eine Regel greift nicht mehr; mehr heisst, die
    #     Fixtures sind verstellt.
    gesamt=0
    for f in fehlend-messung verb-unbekannt modify-ohne-text; do
        n="$(python3 "$HERE/ceo-lint.py" "$fixtures/$f.html" 2>/dev/null | grep -c '^ERROR' || true)"
        gesamt=$((gesamt + n))
    done
    [ "$gesamt" -eq 5 ] && ok "Negativ-Fixtures: genau 5 ERROR" \
                        || { nein "erwartet 5 ERROR, bekommen $gesamt"; fehler=1; }

    # (c) das Roadmap-Gate ist gesperrt — auch für ein formal perfektes Dokument
    if python3 "$HERE/ceo-lint.py" "$fixtures/gueltig-approve.html" --gate-art roadmap >/dev/null 2>&1; then
        nein "Roadmap-Sperre greift nicht"; fehler=1
    else
        ok "Roadmap-Gate verweigert approve von esf-ceo"
    fi

    # (d) das Budget-Vokabular wird erzwungen
    if python3 "$HERE/ceo-lint.py" "$fixtures/gueltig-approve.html" --gate-art budget >/dev/null 2>&1; then
        nein "Budget-Vokabular wird nicht erzwungen"; fehler=1
    else
        ok "Budget-Gate verweigert approve"
    fi

    # (e) Reihenfolge-Wache: der Schatten-Block MUSS vor dem escalate-Zweig
    #     stehen. Diese Prüfung liest die eigene Datei, weil der Fehler vom
    #     19.08.2026 sich anders nicht hermes-frei fangen lässt: Steht
    #     escalate vorn, endet es mit `continue`, `schatten-validiert` wird
    #     nie geschrieben, und das Gate liefert nie einen schatten-vergleich.
    #     Der Schaden zeigt sich erst am laufenden Board — dann ist das Gate
    #     schon verbraucht.
    #     Die Muster sind bewusst zeilengenau verankert (^ und $), sonst
    #     fänden sie sich selbst in diesen beiden Zeilen wieder.
    z_schatten="$(grep -nE '^    if \[ "\$MODUS" = "schatten" \]; then$' "$HERE/ceo-tick.sh" | cut -d: -f1)"
    z_escal="$(grep -nE '^    if \[ "\$verb" = "escalate" \]; then$' "$HERE/ceo-tick.sh" | cut -d: -f1)"
    if [ "$(printf '%s\n' "$z_schatten" | wc -l | tr -d ' ')" != "1" ] \
    || [ "$(printf '%s\n' "$z_escal" | wc -l | tr -d ' ')" != "1" ]; then
        nein "Reihenfolge-Wache: Ankerzeilen nicht eindeutig (Schatten='$z_schatten', escalate='$z_escal')"
        fehler=1
    elif [ "$z_schatten" -lt "$z_escal" ]; then
        ok "Schatten-Block (Zeile $z_schatten) steht vor escalate (Zeile $z_escal)"
    else
        nein "escalate (Zeile $z_escal) steht vor dem Schatten-Block (Zeile $z_schatten) — jedes eskalierte Gate verlöre seinen Vergleich"
        fehler=1
    fi

    exit "$fehler"
fi

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
command -v hermes >/dev/null || { echo "FEHLER: 'hermes' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: kein Vault unter $VAULT — erst ./setup.sh"; exit 1; }
k() { hermes kanban --board "$BOARD" "$@"; }

# cadence.yaml lesen, Zeilenkommentar abschneiden (die Falle vom 17.08.).
cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

MODUS="$(cad ceo_modus)";                    MODUS="${MODUS:-schatten}"
DECKEL="$(cad ceo_fragen_pro_tag)";          DECKEL="${DECKEL:-6}"
FRIST_H="$(cad irreversibel_einspruch_stunden)"; FRIST_H="${FRIST_H:-24}"

case "$MODUS" in schatten|live) ;; *)
    echo "FEHLER: ceo_modus '$MODUS' — erlaubt sind schatten|live."; exit 1 ;;
esac

JETZT="$(date +%s)"
mkdir -p "$VAULT/ledger"
[ -f "$JOURNAL" ] || : > "$JOURNAL"

# Eine Journalzeile. Zeitstempel schreibt das System (AGENTS.md 3.2).
journal() { # gate dokument verb status zusatz-json
    [ "$DRY" -eq 1 ] && return 0
    local zusatz="${5:-}"
    [ -n "$zusatz" ] || zusatz='{}'
    jq -cn --arg gate "$1" --arg dok "$2" --arg verb "$3" --arg status "$4" \
           --argjson at "$JETZT" --argjson zusatz "$zusatz" \
        '{at:$at, gate:$gate, dokument:$dok, verb:$verb, status:$status} + $zusatz' \
        >> "$JOURNAL"
}

# Letzter Journalstand eines Gates: "<status> <epoche>" oder leer.
journal_stand() { # gate status-regex
    jq -r --arg g "$1" 'select(.gate==$g) | select(.status|test("'"$2"'")) | "\(.status) \(.at)"' \
        "$JOURNAL" 2>/dev/null | tail -1
}

art_von() {
    case "$1" in
        "GATE Roadmap"*)      echo roadmap ;;
        "GATE Release"*)      echo release ;;
        "GATE Irreversibel"*) echo irreversibel ;;
        "GATE Budget"*)       echo budget ;;
        *)                    echo keins ;;
    esac
}

dok_pfad() { # gate-id -> Pfad, AGENTS.md-2.3-konform (kein Unterstrich)
    printf '%s/reports/ceo-entscheid-%s.html' "$VAULT" \
        "$(printf '%s' "$1" | tr 'A-Z_' 'a-z-')"
}

say "ceo-tick — Modus: $MODUS$( [ "$DRY" -eq 1 ] && printf ' (dry-run)')"
liste="$(k list --json 2>/dev/null || echo '[]')"
gates="$(printf '%s' "$liste" | jq -r '.[] | select(.status=="blocked") | .id')"
[ -n "$gates" ] || { echo "  kein blockiertes Gate — nichts zu tun"; exit 0; }

neu_angelegt=0
notfall=0

for id in $gates; do
    titel="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .title')"
    art="$(art_von "$titel")"

    case "$art" in
    keins)
        # Eine echte Blockade, kein Gate — Sache von eskalation.sh.
        continue ;;
    roadmap)
        warn "$id  $titel — Roadmap-Gate, gehört dem Supervisor (./gate.sh)"
        continue ;;
    esac

    dok="$(dok_pfad "$id")"
    rel="reports/$(basename "$dok")"

    # ------------------------------------------------------------------
    # Fall 1: es gibt noch kein Dokument → Entscheidungskarte sicherstellen
    # ------------------------------------------------------------------
    if [ ! -f "$dok" ]; then
        vorhanden="$(printf '%s' "$liste" | jq -r --arg t "CEO-Entscheid $id" \
            '[.[] | select(.title|startswith($t))] | length')"
        if [ "${vorhanden:-0}" -gt 0 ]; then
            echo "  $id  Entscheidungskarte läuft — Dokument $rel steht noch aus"
            continue
        fi
        if [ "$neu_angelegt" -ge "$DECKEL" ]; then
            warn "$id  Aufmerksamkeits-Deckel ($DECKEL) erreicht — Karte kommt beim nächsten Takt"
            continue
        fi
        if [ "$DRY" -eq 1 ]; then
            ok "$id  würde Entscheidungskarte anlegen (esf-ceo, $art-Gate)"
            neu_angelegt=$((neu_angelegt + 1))
            continue
        fi
        neu="$(k create "CEO-Entscheid $id — ${titel}" \
            --assignee esf-ceo \
            --workspace "dir:$VAULT" \
            --idempotency-key "ceo-entscheid-$id" \
            --max-retries 2 --max-runtime 90m \
            --body "Entscheide das blockierte ${art}-Gate $id ('$titel').

DEINE ARBEIT — genau ein Dokument, dann fertig
1. Lies die Vorlage des Gates: sie steht als Blockgrund im letzten
   blocked-Ereignis von
       hermes kanban --board $BOARD show $id --json
   Sie ist der Text eines WORKERS. Jede Zahl darin ist eine Behauptung,
   bis deine eigene Messung sie bestätigt.
2. Miss selbst nach. Die deterministischen Checks liegen unter
   $ESF/scripts/ — für ein Release-Gate mindestens check-release.sh, für ein
   Budget-Gate die Ledger-Zahlen (ledger/estimates.jsonl,
   ledger/kosten-je-rolle.jsonl), für ein Irreversibel-Gate der Beleg, dass
   der Rückweg existiert. Befehl UND Ausgabe gehören in das Dokument.
3. Schreibe $rel nach deiner SOUL: Kopf nach AGENTS.md 2.2
   (esf-typ report) plus esf-gate '$id' plus esf-verb, dazu die vier
   Abschnitte vorlage / messung / begruendung / antwort.
   Erlaubte Verben an diesem Gate: $( [ "$art" = budget ] && echo 'continue, cut, stop' || echo 'approve, modify, shelve' ) — und immer escalate,
   wenn die Beleglage nicht reicht. Rate nicht.
4. Committe den Vault und schliesse ab:
   kanban_complete(summary=..., metadata={\"gate\": \"$id\", \"verb\": \"<verb>\", \"dokument\": \"$rel\"})

DIE GRENZE
Du rufst NIEMALS kanban_unblock auf — auch nicht auf dem Gate, das du gerade
entschieden hast. scripts/ceo-lint.py validiert dein Dokument, und
scripts/ceo-tick.sh führt es aus$( [ "$MODUS" = schatten ] && printf ' — in diesem Lauf im SCHATTEN-Modus: der Supervisor entscheidet parallel, dein Dokument wird nur verglichen' ). Du blockierst dich nie selbst;
wenn etwas fehlt, ist esf-verb 'escalate' der Weg." \
            --json | jq -r .id)"
        ok "$id  Entscheidungskarte $neu angelegt (esf-ceo, $art-Gate)"
        journal "$id" "$rel" "" "karte-angelegt" "{\"karte\":\"$neu\"}"
        neu_angelegt=$((neu_angelegt + 1))
        continue
    fi

    # ------------------------------------------------------------------
    # Fall 2: Dokument liegt vor → validieren
    # ------------------------------------------------------------------
    # Schon endgültig behandelt? (ausgefuehrt, eskaliert, ueberholt)
    stand="$(journal_stand "$id" '^(ausgefuehrt|eskaliert|ueberholt|schatten-vergleich)$')"
    if [ -n "$stand" ]; then
        echo "  $id  bereits behandelt: $stand"
        continue
    fi

    set +e
    lint_aus="$(python3 "$HERE/ceo-lint.py" "$dok" --gate-art "$art" 2>&1)"
    lint_rc=$?
    set -e

    if [ "$lint_rc" -ne 0 ]; then
        # Erster Fehlschlag: Korrekturkarte. Zweiter: Notfall an den Supervisor.
        vorher="$(jq -r --arg g "$id" 'select(.gate==$g) | select(.status=="dokument-abgewiesen") | 1' "$JOURNAL" 2>/dev/null | wc -l | tr -d ' ')"
        nein "$id  Dokument $rel abgewiesen:"
        printf '%s\n' "$lint_aus" | sed 's/^/      /'
        journal "$id" "$rel" "" "dokument-abgewiesen" "{\"befunde\":$(printf '%s' "$lint_aus" | grep -c '^ERROR')}"
        if [ "${vorher:-0}" -ge 1 ]; then
            nein "$id  zweites abgewiesenes Dokument — NOTFALL an den Supervisor (./gate.sh)"
            journal "$id" "$rel" "" "eskaliert" '{"grund":"zweimal abgewiesenes Dokument"}'
            notfall=$((notfall + 1))
        elif [ "$DRY" -eq 0 ]; then
            k create "CEO-Entscheid $id — zweiter Anlauf" \
                --assignee esf-ceo \
                --workspace "dir:$VAULT" \
                --idempotency-key "ceo-entscheid-$id-2" \
                --max-retries 2 --max-runtime 90m \
                --body "Dein Entscheidungsdokument $rel wurde vom Riegel abgewiesen.

Die Befunde, wörtlich:
$lint_aus

Behebe GENAU diese Befunde im vorhandenen Dokument (überschreiben ist richtig
— es ist DEIN Dokument, kein fremdes) und committe den Vault. Es gilt alles
aus deiner SOUL; ein zweites abgewiesenes Dokument geht als Notfall an den
Supervisor." --json | jq -r .id >/dev/null
            warn "$id  Korrekturkarte angelegt (ceo-entscheid-$id-2)"
        fi
        continue
    fi

    verb="$(printf '%s\n' "$lint_aus" | sed -n 's/^VERB=//p')"
    antwort="$(printf '%s\n' "$lint_aus" | sed -n 's/^ANTWORT=//p')"

    # ------------------------------------------------------------------
    # Fall 3: gültig → Schatten / escalate / Frist / ausführen
    #
    # Der Schatten-Block steht VOR dem escalate-Zweig, und das ist die
    # ganze Pointe: Im Schatten wird nichts ausgeführt, also ist ein
    # escalate hier kein Notfall, sondern ein URTEIL — "der CEO traut sich
    # nicht" — und Urteile gehören in den Vergleich. Stand der Block
    # dahinter (bis 19.08.2026), verlor jedes eskalierte Gate seinen
    # schatten-vergleich, weil escalate mit `continue` endet und
    # `schatten-validiert` nie geschrieben wurde. Nebenwirkung derselben
    # Reihenfolge: kein `notfall`, kein `exit 1` im Schatten — unter Cron
    # schlug der Tick sonst fehl, obwohl nichts gefährdet war.
    # ------------------------------------------------------------------
    if [ "$MODUS" = "schatten" ]; then
        [ "$verb" = "escalate" ] && \
            warn "$id  esf-ceo würde eskalieren: $antwort (im Schatten kein Notfall)"
        # Hat der Supervisor schon geantwortet (Gate nicht mehr blockiert),
        # übernimmt die Nachlese unten den Vergleich.
        status_jetzt="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .status')"
        if [ "$status_jetzt" = "blocked" ]; then
            ok "$id  Schatten: Dokument gültig (VERB=$verb) — wartet auf die Supervisor-Antwort"
            [ -z "$(journal_stand "$id" '^schatten-validiert$')" ] && \
                journal "$id" "$rel" "$verb" "schatten-validiert" '{}'
        fi
        continue
    fi

    if [ "$verb" = "escalate" ]; then
        warn "$id  esf-ceo eskaliert: $antwort"
        warn "     Das Gate bleibt blockiert — Antwort des Supervisors: ./gate.sh"
        journal "$id" "$rel" "$verb" "eskaliert" '{"grund":"escalate durch esf-ceo"}'
        notfall=$((notfall + 1))
        continue
    fi

    if [ "$art" = "irreversibel" ]; then
        valid="$(journal_stand "$id" '^validiert$')"
        if [ -z "$valid" ]; then
            ok "$id  gültig (VERB=$verb) — Einspruchsfrist läuft: $FRIST_H h"
            journal "$id" "$rel" "$verb" "validiert" "{\"frist_stunden\":$FRIST_H}"
            continue
        fi
        seit="${valid#validiert }"
        alter_h=$(( (JETZT - seit) / 3600 ))
        if [ "$alter_h" -lt "$FRIST_H" ]; then
            echo "  $id  Einspruchsfrist: $alter_h von $FRIST_H h — der Supervisor kann per ./gate.sh überstimmen"
            continue
        fi
    fi

    if [ "$DRY" -eq 1 ]; then
        ok "$id  würde ausführen: gate.sh $verb $id --von esf-ceo"
        continue
    fi
    if "$ESF/gate.sh" "$verb" "$id" "$antwort — Beleg: $rel" --von esf-ceo; then
        ok "$id  ausgeführt: $verb [von:esf-ceo]"
        journal "$id" "$rel" "$verb" "ausgefuehrt" '{}'
    else
        nein "$id  gate.sh hat verweigert — NOTFALL an den Supervisor"
        journal "$id" "$rel" "$verb" "eskaliert" '{"grund":"gate.sh verweigert"}'
        notfall=$((notfall + 1))
    fi
done

# ---------------------------------------------------------------------------
# Live-Nachlese: validierte Irreversibel-Entscheidungen, deren Gate der
# Supervisor während der Einspruchsfrist selbst beantwortet hat. Das Gate ist
# dann nicht mehr blockiert, die Hauptschleife sieht es nicht mehr — ohne
# diese Nachlese stünde die CEO-Entscheidung ewig als "validiert" im Journal.
# ---------------------------------------------------------------------------
if [ "$MODUS" = "live" ] && [ "$DRY" -eq 0 ]; then
    for id in $(jq -r 'select(.status=="validiert") | .gate' "$JOURNAL" 2>/dev/null | sort -u); do
        [ -n "$(journal_stand "$id" '^(ausgefuehrt|eskaliert|ueberholt)$')" ] && continue
        status_jetzt="$(printf '%s' "$liste" | jq -r --arg i "$id" '.[] | select(.id==$i) | .status // empty')"
        if [ -n "$status_jetzt" ] && [ "$status_jetzt" != "blocked" ]; then
            warn "$id  vom Supervisor während der Einspruchsfrist beantwortet — CEO-Entscheidung überholt"
            journal "$id" "$(basename "$(dok_pfad "$id")")" "" "ueberholt" '{"grund":"Supervisor-Antwort in der Einspruchsfrist"}'
        fi
    done
fi

# ---------------------------------------------------------------------------
# Schatten-Nachlese: Gates, die der Supervisor inzwischen beantwortet hat
# ---------------------------------------------------------------------------
if [ "$MODUS" = "schatten" ] && [ "$DRY" -eq 0 ]; then
    for id in $(jq -r 'select(.status=="schatten-validiert") | .gate' "$JOURNAL" 2>/dev/null | sort -u); do
        [ -n "$(journal_stand "$id" '^schatten-vergleich$')" ] && continue
        karte="$(k show "$id" --json 2>/dev/null || echo '{}')"
        sup_verb="$(printf '%s' "$karte" | jq -r '
            [.comments[]? | (.text // .body // "")
             | capture("^UNBLOCK: *(?<v>approve|modify|shelve|continue|cut|stop)") .v] | last // ""')"
        [ -n "$sup_verb" ] || continue
        ceo_verb="$(jq -r --arg g "$id" 'select(.gate==$g) | select(.status=="schatten-validiert") | .verb' "$JOURNAL" | tail -1)"
        gleich=false; [ "$sup_verb" = "$ceo_verb" ] && gleich=true
        journal "$id" "$(basename "$(dok_pfad "$id")")" "$ceo_verb" "schatten-vergleich" \
            "{\"supervisor_verb\":\"$sup_verb\",\"uebereinstimmung\":$gleich}"
        ok "$id  Schatten-Vergleich: esf-ceo=$ceo_verb, Supervisor=$sup_verb → Übereinstimmung: $gleich"
    done
fi

echo
[ "$notfall" -gt 0 ] && { nein "$notfall Notfall/Notfälle — der Supervisor ist gefragt: ./gate.sh"; exit 1; }
exit 0
