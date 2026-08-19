#!/usr/bin/env bash
#
# ESF — Der Release-Abschluss und das Release-Gate
# ================================================
#
#   ./create-release.sh R1              die Sprints aus der Vorgabe (S1 S2)
#   ./create-release.sh R2 S4 S5        Release und seine Sprints ausdruecklich
#   ./create-release.sh R2 S4 --dry-run zeigen, nichts anlegen
#
# BIS ZUM 19.08.2026 WAR HIER R1 FEST VERDRAHTET, und zwar an drei Stellen mit
# drei verschiedenen Preisen:
#   · die Sprintliste `for s in S1 S2` und der Elternteil "Sprint-Abschluss S2"
#     — ein R2-Aufruf haette gegen die falschen Karten geprueft;
#   · die Report-Pfade sprint-s1/s2-report.html im Gate-Kartentext;
#   · und, am teuersten, eine BESCHREIBUNG des Release im Kartentext:
#     "R1 heisst 'Auffindbar & vertrauenswuerdig' und traegt drei Features:
#      R1-F5, R1-F1, R1-F2." Das stammte aus einem frueheren Lauf und war
#     schon fuer R1 falsch — die freigegebene Roadmap fuehrt R1 als "Der
#     taegliche Kern" mit F-R1-2/3/4/5. Ein Kartentext, der dem Worker eine
#     falsche Release-Zusammensetzung nennt, ist schlimmer als einer, der gar
#     keine nennt: Er gibt ihm etwas zu glauben.
# Die Beschreibung ist deshalb nicht parametrisiert, sondern ENTFERNT. Der
# Worker liest die freigegebene Roadmap und stellt selbst fest, was das Release
# traegt — das musste er ohnehin ("Was davon tatsaechlich auf main liegt,
# stellst du fest").
#
# Zwei Karten. Kapitel 5 verortet den Release-Abschluss so: "abgeschlossen, wenn
# der Härtungs-Sprint fertig ist: Integration, Release Notes, voller
# E2E-Regressionslauf, Paket am Riegel" — und dann steht der CEO.
#
#   Release-Abschluss R1   esf-qa-release       dir:REPO
#   GATE Release — R1      esf-chief-of-staff   dir:VAULT   ← Eltern: Abschluss
#
# Die Gate-Karte wird angelegt, WÄHREND ihr Elternteil noch offen ist. Läge sie
# später, würde der Dispatcher sie zwischen `create` und `block` starten — das
# Muster aus Story 10, das im ersten Lauf Geld gekostet hat.
#
# Der Titel "GATE Release — …" ist load-bearing: gate.sh erkennt daran die
# Gate-Art und damit die erlaubten Verben (approve · modify · shelve).
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
VAULT="$HERE/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"

R=""; DRY=0; SPRINTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        R[0-9])    R="$1" ;;
        S[0-9]|S[0-9][0-9]) SPRINTS="$SPRINTS $1" ;;
        *) echo "Unbekanntes Argument '$1'"; echo "Aufruf: ./create-release.sh R2 S4 S5 [--dry-run]"; exit 2 ;;
    esac
    shift
done
R="${R:-R1}"
# Vorgabe nur fuer R1 — sie ist die dokumentierte Aufrufform der Stories und
# soll weiter ohne Argumente laufen. Fuer jedes andere Release ist die
# Sprintliste Pflicht: Sie zu raten hiesse, die Vorbedingung zu erfinden.
SPRINTS="$(printf '%s' "${SPRINTS# }")"
if [ -z "$SPRINTS" ]; then
    if [ "$R" = "R1" ]; then SPRINTS="S1 S2"
    else
        echo "FEHLER: Fuer $R fehlt die Sprintliste."
        echo "        Aufruf: ./create-release.sh $R S4 S5"
        echo "        Nur R1 hat eine Vorgabe (S1 S2) — welche Sprints zu einem"
        echo "        Release gehoeren, steht in der freigegebenen Roadmap, nicht"
        echo "        in diesem Skript."
        exit 2
    fi
fi
KLEIN="$(printf '%s' "$R" | tr 'A-Z' 'a-z')"
LETZTER_SPRINT="$(printf '%s' "$SPRINTS" | awk '{print $NF}')"
IDS="$HERE/task-ids-$KLEIN.env"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }

# Zeilenkommentar abschneiden — sonst wandert er als Wert in den Kartentext.
cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

REPO="$(cad repo)"
PRODUKT="$(cad name)"
E2E_BEFEHL="$(cad e2e_befehl)"
E2E_VORBED="$(cad e2e_vorbedingung)"
HORIZONT="$(cad autonomie_horizont)"

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Vorbedingung: die Sprints des Release sind abgeschlossen
# ---------------------------------------------------------------------------
# Kein Modell entscheidet das, und dieses Skript entscheidet es auch nicht neu —
# es fragt die Abschluss-Karten, die ihrerseits check-sprint.sh gehorchen.
offen=""
for s in $SPRINTS; do
    karte="$(k list --json 2>/dev/null | jq -r --arg t "Sprint-Abschluss $s" \
             '[.[] | select(.title==$t)] | last // null')"
    if [ "$karte" = "null" ]; then
        offen="$offen $s(keine Abschluss-Karte)"
    else
        st="$(printf '%s' "$karte" | jq -r '.status')"
        [ "$st" = "done" ] || offen="$offen $s($st)"
    fi
done
if [ -n "$offen" ]; then
    printf '\nVERWEIGERT — nicht alle Sprints von %s sind abgeschlossen:%s\n' "$R" "$offen"
    echo
    echo "Kapitel 5: Das Release ist abgeschlossen, wenn seine Sprints fertig sind —"
    echo "nicht, wenn jemand findet, es sei so weit. Erst takten:"
    echo "  ./pump.sh"
    for s in $SPRINTS; do echo "  ./scripts/check-sprint.sh $s"; done
    exit 1
fi
printf '\n\033[32m✓\033[0m Sprint-Abschluss%s sind fertig\n' "$(printf '%s' "$SPRINTS" | sed 's/ /, /g' | sed 's/^/ /')"

echo "Release:  $R von $PRODUKT"
echo "Repo:     $REPO ($(git -C "$REPO" rev-parse --short HEAD))"
echo "Horizont: autonomie_horizont: $HORIZONT"

ELTERN="$(k list --json | jq -r --arg t "Sprint-Abschluss $LETZTER_SPRINT" \
          '[.[] | select(.title==$t)] | last | .id')"

# Die Quellenlisten der Kartentexte, aus der Sprintliste erzeugt statt getippt.
SPRINT_REPORTS=""; CONTROLLER_REPORTS=""
for s in $SPRINTS; do
    sk="$(printf '%s' "$s" | tr 'A-Z' 'a-z')"
    SPRINT_REPORTS="$SPRINT_REPORTS  reports/sprint-$sk-report.html   (Schätzung, Ist) aus $s
"
    CONTROLLER_REPORTS="$CONTROLLER_REPORTS  reports/controller-$sk.html      Schätzgüte $s
"
done
SPRINT_REPORTS="${SPRINT_REPORTS%
}"; CONTROLLER_REPORTS="${CONTROLLER_REPORTS%
}"

# Die freigegebene Roadmap DIESES Release, sonst die des Quartals. Seit dem
# Roadmap-Gate R2 friert jeder Neuschnitt unter roadmap/<klein>-freigegeben.html
# ein; für R1 gibt es nur die Quartalsfreigabe.
if [ -f "$VAULT/roadmap/$KLEIN-freigegeben.html" ]; then
    ROADMAP_REL="roadmap/$KLEIN-freigegeben.html"
else
    ROADMAP_REL="roadmap/q1-freigegeben.html"
fi
[ -f "$VAULT/$ROADMAP_REL" ] || {
    echo "FEHLER: keine freigegebene Roadmap unter $ROADMAP_REL"
    echo "        Ohne Freigabe waere dieses Release Arbeit auf Verdacht."
    exit 1
}
echo "Roadmap:  $ROADMAP_REL"
echo "Sprints:  $SPRINTS"

if [ "$DRY" -eq 1 ]; then
    printf '\n\033[1mTrockenlauf — es wird keine Karte angelegt\033[0m\n'
    printf '  Release-Abschluss %s      esf-qa-release,      Elternteil %s\n' "$R" "$ELTERN"
    printf '  GATE Release — %s         esf-chief-of-staff\n' "$R"
    # Die Schluessel werden aus DEM SKRIPT gelesen, nicht danebengeschrieben.
    # Der erste Trockenlauf meldete 'release-gate-R1', tatsaechlich heisst der
    # Schluessel 'gate-release-R1' — ein Trockenlauf, der falsche Namen nennt,
    # ist genau die Scheinpruefung, gegen die er gebaut ist.
    printf '  Idempotenzschluessel:     %s\n' \
        "$(grep -o -- '--idempotency-key "[^\"]*"' "$0" | sed 's/--idempotency-key //;s/\"//g' \
           | sed "s/\$R/$R/g" | tr '\n' ' ')"
    printf '  Release Notes nach:       reports/release-%s.html\n' "$KLEIN"
    printf '  Quellen im Kartentext:\n%s\n%s\n  %s\n' \
        "$SPRINT_REPORTS" "$CONTROLLER_REPORTS" "$ROADMAP_REL"
    printf '  IDs kaemen nach:          %s\n' "$(basename "$IDS")"
    exit 0
fi

# ---------------------------------------------------------------------------
say "1/2  Release-Abschluss $R"
# ---------------------------------------------------------------------------
ABSCHLUSS=$(k create "Release-Abschluss $R" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$ELTERN" \
    --idempotency-key "release-abschluss-$R" \
    --max-retries 2 --max-runtime 90m \
    --body "Stelle das Release $R von $PRODUKT fertig. Du arbeitest im Hauptbaum
($REPO) auf main — hier wird nichts mehr gebaut, hier wird integriert und
geprüft.

DAS RELEASE — was $R trägt, stellst DU fest
Dieser Kartentext nennt dir bewusst keine Feature-Liste. Bis zum 19.08.2026
stand hier eine, und sie war falsch: aus einem früheren Lauf stehengeblieben,
mit einem Release-Namen und drei Features, die die freigegebene Roadmap so
nicht führt. Ein Kartentext, der dir eine falsche Zusammensetzung nennt, ist
schlimmer als einer, der keine nennt — er gibt dir etwas zu glauben.

Deine Quellen, in dieser Reihenfolge:
  $ROADMAP_REL   was $R laut Freigabe liefern sollte
$SPRINT_REPORTS
  git log auf main            was tatsächlich gemergt wurde

Massgeblich ist der letzte Punkt. Die Roadmap sagt, was geplant war; die
Sprint-Reports sagen, was ein Sprint zu liefern glaubte; main sagt, was da ist.
Weicht das voneinander ab, ist genau diese Abweichung der wertvollste Absatz
deiner Release Notes.

VIER PFLICHTEN AUS KAPITEL 5 — in dieser Reihenfolge

1. INTEGRATION PRÜFEN, nicht herstellen
   Die Features sind einzeln am Riegel gemergt. Deine Frage ist, ob sie
   ZUSAMMEN tragen. Konkret:
     git -C $REPO log --oneline --first-parent main | head -20
   Welche Merge-Commits gehören zu $R? Liegt jedes Feature vollständig da?
   Und dann die Frage, die einzelne Riegel-Läufe nicht stellen können: Berühren
   sich zwei Features an einer Stelle, die keiner der beiden Reviews gesehen
   hat? Die Schnittmengen stehen in den Review-metadata.

2. DER VOLLE E2E-REGRESSIONSLAUF, verpflichtend vor jedem Release
     cd $REPO
     $E2E_VORBED
     $E2E_BEFEHL
   Ein roter Lauf ist ein Release-Stopper, kein Wetter (Kapitel 6: 'Flakiness
   wird behandelt wie ein Bug'). Fällt etwas, lauf es einzeln nach und
   unterscheide sichtbar: echter Regressionsfehler oder der bekannt
   lastempfindliche mcp-internal-api-url.test.ts.

   Die Akte des Laufs gehört in den Vault (AGENTS.md 1):
     $VAULT/reports/e2e-$HEUTE/
   Dort hin kommen die Rohbelege — results.json und eine SUMMARY.txt mit der
   Testzahl, der Dauer und der Liste der Journeys. Als .txt/.json und NICHT als
   HTML: AGENTS.md 2.1 nimmt Maschinenprotokolle aus der HTML-Pflicht aus, und
   ein Rohbeleg, den jemand für die Darstellung angefasst hat, ist keiner mehr.
   Dazu Typecheck und Unit-Tests auf main, mit Zahlen.

   Ist der Lauf grün, zeichne ihn sofort auf (AGENTS.md 8.2):
     $HERE/scripts/e2e-video.sh --alle --anlass release-$R-regressionslauf
   Das ist die Video-Akte, auf die sich die Release Notes berufen: der Stand,
   den das Release ausliefert, im Browser durchgespielt. Sie entsteht am
   grünen Lauf, nicht am Merge — und der eigene --anlass hält sie von der
   Akte des Ticks und des Riegels desselben Tages getrennt.

3. RELEASE NOTES — reports/release-$KLEIN.html
   Geschrieben für jemanden, der das Produkt benutzt, nicht für jemanden, der es
   gebaut hat. Je Feature: was kann der Anwender jetzt, was er vorher nicht
   konnte, und wieviele Schritte kostet es ihn (die Schrittzahl aus
   analysis/journeys.html — sie ist die UX-Kennzahl der Organisation).

   Dazu die drei Abschnitte, die ein Release-Dokument ehrlich machen:
   · Was NICHT drin ist, obwohl es geplant war — aus den
     'deliberately_not_done'-Einträgen der Karten-metadata, mit Grund.
   · Was sich für Selbst-Hoster ändert: Migration ja/nein, neue
     Konfiguration, Handgriffe beim Update. Enthält $R eine Datenmigration,
     ist das die wichtigste Zeile des Dokuments.
   · Der Prüfstand: Testzahlen, Journeys, Riegel-Protokolle, jeweils verlinkt.

4. DAS PAKET AM RIEGEL
   Ein Tag oder Deploy passiert NICHT — nicht vor der CEO-Antwort am Gate
   (Kapitel 7). Was du stattdessen lieferst, ist der Nachweis, dass das Paket
   freigabefähig ist: main ist grün, der Arbeitsbaum sauber, jedes Feature
   nachweisbar drin, jede Prüfung gelaufen. Der Riegel je Feature ist gelaufen;
   deine Aufgabe ist die Gesamtaussage.

WENN ETWAS NICHT PASST
Dann ist das dein Ergebnis. Ein Release-Abschluss, der ein Problem glättet,
schiebt es in die Hände des CEO, ohne es zu benennen — und der entscheidet dann
über ein Bild statt über eine Lage. Fehlt ein Feature, ist ein Test rot oder
liegt eine Migration ohne Gate vor: hinschreiben, in die Zusammenfassung, nicht
in eine Fussnote.

DEIN ABSCHLUSS-metadata
    reference_class: 'release-repo-M'
Dazu: welche Features nachweisbar auf main liegen (mit Commit), das
E2E-Ergebnis (Zahlen), Typecheck und Unit-Tests (Zahlen), ob eine Migration
enthalten ist, die Liste der bekannten Einschränkungen, und ein Feld
'freigabefaehig' mit true/false und einem Satz Begründung.

VAULT-FORMAT für release-$KLEIN.html (AGENTS.md 2.2): Kopf mit esf-typ 'report',
esf-karte deine Karten-ID, esf-datum $HEUTE. Jede Behauptung mit Beleg.

DIE GRENZE
Du rufst NIEMALS kanban_unblock auf. Du blockierst dich höchstens einmal
(BLOCK_RECURRENCE_LIMIT = 2 je kind, danach still nach 'triage')." \
    --json | jq -r .id)
echo "  ABSCHLUSS = $ABSCHLUSS"

# ---------------------------------------------------------------------------
say "2/2  GATE Release — $R"
# ---------------------------------------------------------------------------
GATE=$(k create "GATE Release — $R" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$ABSCHLUSS" \
    --idempotency-key "gate-release-$R" \
    --max-retries 2 --max-runtime 45m \
    --body "Lege dem CEO das Release $R zur Freigabe vor. Das ist die Stelle, an
der der Autonomie-Horizont endet: 'autonomie_horizont: $HORIZONT' — die
Organisation läuft vollautomatisch bis hierher und hält für den Menschen an.

ERSTER LAUF
1. Lies, was zu entscheiden ist:
     reports/release-$KLEIN.html          die Release Notes und der Prüfstand
$SPRINT_REPORTS
$CONTROLLER_REPORTS
     $ROADMAP_REL   was $R laut Freigabe liefern sollte

2. Blockiere dich SELBST:  kanban_block(kind=\"needs_input\", reason=\"…\")

   Die Vorlage hat genau acht Zeilen, jede eine:

     1 Was ansteht        — Release $R von $PRODUKT freigeben: N Features
     2 Was drin ist       — die Features in je vier Worten
     3 Was NICHT drin ist — was geplant war und fehlt, mit Grund in vier Worten
     4 Prüfstand          — E2E n/n, Unit n/n, Typecheck, Riegel je Feature
     5 Kosten & Schätzgüte — Ist gegen Schätzung, der Faktor je Klasse. DIE
                            ZAHL, nicht 'im Rahmen'. Hier zahlt sich der ganze
                            Ledger aus.
     6 Risiko             — Migration? Sicherheitsfläche? Was kann nach der
                            Freigabe wehtun, und was ist rücknehmbar?
     7 Empfehlung         — dein Vorschlag in einem Satz, mit dem Grund
     8 Wie antworten      — ./gate.sh approve <id>  ·  modify <id> \"…\"  ·
                            shelve <id> \"…\"

   Maßstab: Man kann entscheiden, ohne eine Datei zu öffnen. Und trotzdem
   verweist jede Zeile auf die Detailakte für einen CEO, der prüfen will.

   Zeile 3 und Zeile 6 sind die, auf die es ankommt. Ein Gate, das nur das
   Gelungene zeigt, ist eine Werbung und keine Entscheidungsvorlage. Im ersten
   Lauf hat ein Worker eine Riegel-Verweigerung ehrlich in Zeile 2 seiner
   Vorlage geschrieben, obwohl seine Empfehlung 'approve' lautete — genau so.

ZWEITER LAUF — nach der Antwort des Menschen
3. Lies seine Antwort im Kommentar-Thread. Sie beginnt mit einem Verb.
     approve  → Das Release ist freigegeben. Halte es fest: einen Abschnitt
                'Freigabebeschluss' in reports/release-$KLEIN.html mit dem
                WORTLAUT der CEO-Antwort, unverändert, und dem Freigabedatum.
                Danach schreibst du roadmap/q1-fortschritt.html: welches
                Release ist erledigt, was steht als nächstes an, und was aus
                der Kalibrierung für die Schätzung von R2 folgt.
     modify   → Die Änderung EINARBEITEN, das ursprüngliche Urteil daneben
                stehen lassen: nicht überschrieben, sondern widerlegt
                (AGENTS.md 3.3). Dann festhalten wie bei approve.
     shelve   → Nichts freigeben. Vermerke in release-$KLEIN.html, was fehlte,
                und was passieren müsste, damit es freigabefähig wird.
4. Committe den Vault.
5. kanban_complete mit der Antwort und dem, was du daraus gemacht hast.

WAS DU NICHT TUST
· Kein Tag, kein Deploy, kein Push nach irgendwo. Die Freigabe ist ein
  Beschluss im Vault, nicht eine Handlung am Produkt.
· Wenn die Ausführung der Antwort scheitert, blockiere diese Karte NICHT ein
  zweites Mal. Hermes zählt zwei Blockaden derselben Art auf derselben Karte
  als Schleife (BLOCK_RECURRENCE_LIMIT = 2, je kind) und schiebt sie still nach
  'triage'. Real passiert, siehe RUN-PROTOKOLL.md. Stattdessen:
  kanban_complete mit dem Befund im metadata und eine NEUE Karte für die
  Folgeentscheidung. Eine Entscheidung, eine Karte.
· Du rufst NIEMALS kanban_unblock auf. Nicht auf dieser Karte, nicht auf einer
  anderen, aus keinem Grund. Das ist die Grenze zwischen der Organisation und
  dem Menschen (AGENTS.md 7), und monitor.sh meldet jede Verletzung.

DEIN ABSCHLUSS-metadata
    reference_class: 'gate-vault-S'
Dazu: die CEO-Antwort im Wortlaut, was du daraus gemacht hast, und die
Zeilenzahl deiner Vorlage." \
    --json | jq -r .id)
echo "  GATE = $GATE"

cat > "$IDS" <<EOF
# Von create-release.sh $R erzeugt — $(date '+%Y-%m-%d %H:%M')
BOARD='$BOARD'
VAULT='$VAULT'
REPO='$REPO'
${R}_ABSCHLUSS='$ABSCHLUSS'
${R}_GATE='$GATE'
EOF

say "Board"
k list

cat <<EOF

IDs liegen in $(basename "$IDS")

Weiter:
  ./pump.sh                        takten — die Pumpe endet, wenn nur das Gate wartet
  ./gate.sh                        die Vorlage lesen
  ./gate.sh approve $GATE
  ./scripts/check-release.sh $R    den Release-Nachweis abnehmen
  ./scripts/check-phase2.sh        die drei Nachweise aus Kapitel 12
EOF
