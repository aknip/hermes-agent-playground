#!/usr/bin/env bash
#
# ESF — das Roadmap-Gate zwischen zwei Releases
# =============================================
#
#   ./create-roadmap-gate.sh R2     der Neuschnitt vor Release 2
#
# ZWEI Karten, nicht eine: Der Chief of Staff schneidet neu (Dokument), der
# Supervisor entscheidet (Gate). Getrennt, weil die Gate-Arithmetik je Karte
# nur zwei menschliche Fragen zulaesst (BLOCK_RECURRENCE_LIMIT = 2 je kind)
# und weil die Wartezeit auf den Menschen sonst die Laufzeitmessung der
# Arbeitskarte verfaelschte.
#
# WARUM DIESES GATE UEBERHAUPT STEHT — es ist eine Zusage, keine Zeremonie.
# Am Release-Gate R1 (t_d85e4216) hat der Supervisor geschrieben:
#
#     "HORIZONT BLEIBT release. … Der Schnitt von R2 und R3 wird am naechsten
#      Roadmap-Gate gegen gemessene Intervalle gemacht — erstmals gegen welche,
#      die diesen Namen verdienen."
#
# Inzwischen liegen drei Sprints im Ledger, und das Gate hat drei
# Entscheidungen zu treffen statt einer (siehe Kartentext).
#
# ceo-tick.sh RUEHRT DIESES GATE NICHT AN. `art_von` -> roadmap -> continue.
# Roadmap-Gates sind nicht delegierbar, auch nicht im Schattenbetrieb — sie
# liefern deshalb auch keinen Schatten-Vergleich fuer den Stufe-B-Nachweis.
# Das ist Absicht und in VERIFIKATION.md als Befund festgehalten.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
VAULT="$HERE/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"

REL="${1:-}"
case "$REL" in
    R[0-9]) ;;
    *) echo "Aufruf: ./create-roadmap-gate.sh R2"; exit 2 ;;
esac
KLEIN="$(printf '%s' "$REL" | tr 'A-Z' 'a-z')"
IDS="$HERE/task-ids-roadmap-$KLEIN.env"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }
[ -f "$VAULT/roadmap/q1-freigegeben.html" ] || {
    echo "FEHLER: Es gibt keine freigegebene Roadmap, die neu zu schneiden waere."
    exit 1
}

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }
PRODUKT="$(cad name)"
KARTEN_DECKEL="$(cad karten_pro_feature)"

# ---------------------------------------------------------------------------
# Vorbedingung: der letzte Sprint muss abgerechnet sein
# ---------------------------------------------------------------------------
# Ein Neuschnitt "gegen gemessene Intervalle" braucht die Messung. Ohne die
# Kalibrierungs-Karte des letzten Sprints saehe der Chief of Staff ein Ledger,
# dem die juengsten Zeilen fehlen — und schnitte gegen veraltete Zahlen.
letzte_kal="$(k list --json 2>/dev/null \
    | jq -r '[.[] | select(.title|startswith("Kalibrierung "))] | last // null')"
if [ "$(printf '%s' "$letzte_kal" | jq -r '.status // "fehlt"')" != "done" ]; then
    echo
    echo "VERWEIGERT — die letzte Kalibrierungs-Karte ist nicht fertig."
    echo "Ein Neuschnitt gegen gemessene Intervalle braucht die Messung."
    exit 1
fi
printf '\n\033[32m✓\033[0m Vorbedingung: %s ist fertig\n' \
    "$(printf '%s' "$letzte_kal" | jq -r '.title')"

echo "Release:  $REL"
echo "Produkt:  $PRODUKT"
echo "Vault:    $VAULT"

# ---------------------------------------------------------------------------
say "1/2  Neuschnitt  (esf-chief-of-staff)"
# ---------------------------------------------------------------------------
SCHNITT=$(k create "Neuschnitt $REL — gegen gemessene Intervalle" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --idempotency-key "roadmap-$KLEIN-neuschnitt" \
    --max-retries 2 --max-runtime 60m \
    --body "Schneide $REL und R3 neu. Nicht neu ERFINDEN — neu SCHNEIDEN: Die
freigegebene Roadmap bleibt die Grundlage, und was du aenderst, begruendest du
gegen eine Zahl.

WARUM DIESE KARTE EXISTIERT
Am Release-Gate R1 hat der Supervisor zugesagt: 'Der Schnitt von R2 und R3 wird
am naechsten Roadmap-Gate gegen gemessene Intervalle gemacht — erstmals gegen
welche, die diesen Namen verdienen.' Bis dahin war das Ledger leer oder trug
nur Istwerte. Jetzt trägt es (Schaetzung, Ist)-Paare aus drei Sprints.

DEINE QUELLEN — alle im Vault, alle lesen, bevor du schreibst
  roadmap/q1-freigegeben.html        der geltende Plan
  ledger/estimates.jsonl             die Paare; PRUEFE bei jeder Zeile 'runs'
  reports/controller-s1.html         Kalibrierung nach dem ersten Feature
  reports/controller-s2.html         nach dem zweiten und dritten
  reports/controller-s3.html         nach F-R1-1 — hier steht auch die Luecke
  reports/sprint-s1..s3-report.html  was je Sprint wirklich passiert ist

WAS IN $REL SCHON ERLEDIGT IST
F-R1-1 (Import CSV + WeKan) ist gebaut und auf main. ABER: nur der CSV-Teil.
Der Architekt hat WeKan bewusst als benanntes Folgestueck geschnitten
(specs/r2-f1-import-csv-wekan.html). Das ist eine Entscheidung, die DU jetzt
einzuordnen hast: Kommt WeKan als eigenes Feature in $REL, rutscht es nach R3,
oder faellt es weg? Nenne den Grund.

Offen in $REL laut freigegebener Roadmap: F-R2-1 (MCP-Agentenkanal),
F-R2-2 (2FA), F-R2-4 (Quick-Start), F-R2-5 (Einladen erleichtern).

DIE STEHENDE AUFLAGE, die du einloesen musst
Abschnitt 8b der freigegebenen Roadmap: 'F-R2-2 (2FA) und F-R2-3
(Automatisierung) werden erst als Kartengraph verteilt, wenn sie auf <= 8 Karten
je Feature geschnitten sind (cadence.yaml karten_pro_feature).' Der Deckel steht
bei $KARTEN_DECKEL. Zerlege beide Features so weit, dass der Schnitt sichtbar
haelt — und wenn eines nicht in $KARTEN_DECKEL Karten passt, ist das dein
Ergebnis: dann gehoert es geteilt, nicht gequetscht.

DREI ENTSCHEIDUNGEN BEREITEST DU VOR — du triffst sie nicht
Der Supervisor entscheidet am Gate. Deine Arbeit ist, ihm jede der drei so
vorzulegen, dass er OHNE eine Datei zu oeffnen entscheiden kann, und dass er
trotzdem fuer jede Zahl den Beleg findet.

 (1) DER SCHNITT VON $REL UND R3. Welche Features, in welcher Reihenfolge, mit
     welchem Intervall aus dem Ledger. Wo eine Referenzklasse leer ist, sagst
     du das hin — mit der Klasse, die als naechste in Frage kaeme.

 (2) WAS FOLGT DARAUS, DASS AUFLAGE b) DES R1-GATES GERISSEN IST.
     Die Auflage lautete: 'check-sprint.sh muss im naechsten Sprint auf
     Pruefung 3 gruen sein.' Sie ist rot. Und das ist der dritte Riss dieser
     Art in drei Sprints, jedes Mal an einer anderen Karte:
        S1  t_e70f40ff  Spezifikation  — lief vor dem Estimator
        S2  t_c35344ff  Merge          — dritter Elternteil verdraengte den mit der Zahl
        S3  t_de53e678  Umsetzung      — metadata aufs reichste Feld zusammengefaltet
     Nach S1 und nach S2 wurde der Kartentext gezielt fuer die jeweils vorige
     Variante nachgeschaerft. Die Rate hat sich nicht bewegt. Rechne selbst
     nach, wieviele Karten je Sprint betroffen waren und wieviele nicht —
     die Quote ist die Zahl, um die es geht, nicht die Anekdote.
     Lege dem Supervisor die Optionen vor, mit Preis. Mindestens diese drei,
     gern mehr, wenn du eine bessere hast:
        a) Auflage wiederholen. Preis: dritter Anlauf derselben Forderung.
        b) Die Schaetzung technisch aufloesen — ledger-sync.sh koennte sie
           ueber die Estimator-Karte holen statt aus der Karte selbst.
           Preis: Pruefung 3 misst danach nichts mehr; Fehlerklasse und
           Detektor verschwinden in derselben Bewegung.
        c) Die Auflage fallenlassen und die Quote als gemessene Eigenschaft
           des Verfahrens ausweisen. Preis: Der Phase-2-Nachweis traegt dann
           eine benannte Luecke statt eines Versprechens.
     Du empfiehlst eine. Mit Begruendung, nicht mit Vorliebe.

 (3) DER RELEASE-ABSCHLUSS VON $REL BRAUCHT VORARBEIT.
     create-release.sh hat R1 an sieben Stellen fest verdrahtet und nimmt kein
     Argument. Das ist Klempnerei, keine Entscheidung — aber sie muss VOR dem
     Abschluss passieren und gehoert in deinen Plan als benannter Posten.

SCHREIBE roadmap/${KLEIN}-neuschnitt.html (esf-typ 'roadmap'). Aufbau:
  · Was sich gegenueber der Freigabe aendert — als Liste, jede Zeile mit Grund
    und Beleg. Was gleich bleibt, steht als 'unveraendert' da, nicht gar nicht.
  · Der Schnitt $REL / R3 mit Intervallen je Feature und der Referenzklasse.
  · Die Zerlegung von F-R2-2 und F-R2-3 auf <= $KARTEN_DECKEL Karten.
  · Ein Abschnitt 'Was wir NICHT machen' mit Begruendung — der wertvollste
    Teil jeder Roadmap.
  · Die drei Entscheidungen von oben, je mit Optionen, Preis und deiner
    Empfehlung.
  · Was du bewusst NICHT entschieden hast und warum.

Jede Behauptung nennt ihren Beleg (AGENTS.md 3.1): eine Zahl nennt ihre
Messung, ein Code-Bezug seine Fundstelle. Zeitstempel kommen vom System.

DU LEGST KEINE ARBEITSKARTEN AN. Ein Neuschnitt ist ein Entwurf, bis der
Supervisor ihn freigegeben hat; Karten fuer nicht freigegebene Features waeren
Arbeit auf Verdacht. Schliesse sofort danach ab — die Gate-Karte haengt an dir.

VAULT-FORMAT (AGENTS.md 2.2): <!doctype html>, lang=de, meta esf-typ 'roadmap',
esf-karte <deine Karten-ID>, esf-datum $HEUTE.

Du rufst NIEMALS kanban_unblock auf (AGENTS.md 7)." \
    --json | jq -r .id)
echo "  SCHNITT = $SCHNITT"

# ---------------------------------------------------------------------------
say "2/2  Das Gate  (blockiert sich selbst)"
# ---------------------------------------------------------------------------
GATE=$(k create "GATE Roadmap — Neuschnitt $REL" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$SCHNITT" \
    --idempotency-key "roadmap-$KLEIN-gate" \
    --max-retries 2 --max-runtime 30m \
    --body "Lege dem Supervisor den Neuschnitt $REL zur Entscheidung vor.

ERSTER LAUF
1. Lies roadmap/${KLEIN}-neuschnitt.html deiner Elternkarte.
2. Blockiere dich SELBST:  kanban_block(kind=\"needs_input\", reason=\"…\")

   Die Vorlage hat neun Zeilen, jede eine. Der Massstab: Man kann entscheiden,
   ohne eine Datei zu oeffnen — und trotzdem verweist jede Zeile auf die
   Detailakte fuer einen Supervisor, der pruefen will.

     1 Was ansteht      — Neuschnitt $REL: N Features, davon M neu geschnitten
     2 Beleg            — drei Sprints im Ledger, welche Klassen tragen
     3 Der Schnitt      — die Features von $REL in der geplanten Reihenfolge
     4 Was NICHT kommt  — und warum
     5 Kosten           — Intervall gesamt, und wo die Konfidenz niedrig ist
     6 ENTSCHEIDUNG 2   — Auflage b) ist gerissen: die Quote, deine drei
                          Optionen in je vier Worten, deine Empfehlung
     7 ENTSCHEIDUNG 3   — create-release.sh ist auf R1 verdrahtet; als Posten
     8 Empfehlung       — dein Vorschlag in einem Satz
     9 Wie antworten    — ./gate.sh approve <id>  ·  modify <id> \"…\"  ·
                          shelve <id> \"…\"

   Die Entscheidung zu Auflage b) gehoert AUSDRUECKLICH in den Blockgrund.
   Sie nur im Dokument zu haben waere genau der Fehler, den der Supervisor am
   R1-Gate selbst gemacht hat: Bedingungen, die nur in einem Gate-Kommentar
   stehen, sind in zwei Wochen vergessen.

ZWEITER LAUF — nach der Antwort des Menschen
3. Lies seine Antwort im Kommentar-Thread. Sie beginnt mit einem Verb.
     approve  → Neuschnitt nach roadmap/${KLEIN}-freigegeben.html einfrieren
                (der Entwurf bleibt daneben stehen). Freigabedatum und den
                WORTLAUT der Antwort ins Dokument. Traegt die Antwort eine
                Entscheidung zu Auflage b), schreibst du sie als eigenen,
                benannten Abschnitt hinein — nicht als Nebensatz.
     modify   → Die Aenderung EINARBEITEN, das urspruengliche Urteil daneben
                stehen lassen: nicht ueberschrieben, sondern widerlegt. Dann
                einfrieren wie bei approve.
     shelve   → Nichts einfrieren. Vermerke im Entwurf, was fehlte.
4. Committe den Vault.
5. kanban_complete mit der Antwort und dem, was du daraus gemacht hast.

Wenn die Ausfuehrung der Antwort scheitert, blockiere diese Karte NICHT ein
zweites Mal. Hermes zaehlt zwei Blockaden derselben Art auf derselben Karte als
Schleife (BLOCK_RECURRENCE_LIMIT = 2, je kind) und schiebt sie still nach
'triage'. Stattdessen: kanban_complete mit dem Befund im metadata, und eine
NEUE Karte fuer die Folgeentscheidung. Eine Entscheidung, eine Karte.

Und du rufst NICHT kanban_request_review. Eine Karte im Status 'review' kann
sich selbst nicht mehr abschliessen.

Du rufst NIEMALS kanban_unblock auf. Nicht auf dieser Karte, nicht auf einer
anderen, aus keinem Grund. Das ist die Grenze zwischen der Organisation und
dem Menschen (AGENTS.md 7), und monitor.sh meldet jede Verletzung." \
    --json | jq -r .id)
echo "  GATE    = $GATE"

{
    echo "# Von create-roadmap-gate.sh $REL erzeugt — $(date '+%Y-%m-%d %H:%M')"
    echo "BOARD='$BOARD'"
    echo "VAULT='$VAULT'"
    echo "${REL}_SCHNITT='$SCHNITT'"
    echo "${REL}_GATE='$GATE'"
} > "$IDS"

say "Board"
k list

cat <<EOF

IDs liegen in $(basename "$IDS"):   source $(basename "$IDS")

Weiter:
  ./pump.sh                takten — der Chief of Staff schneidet, dann blockiert das Gate
  ./gate.sh                zeigt, worauf gewartet wird, und nimmt die Antwort

Zur Erinnerung: ceo-tick.sh laesst Roadmap-Gates liegen. Dieses Gate liefert
KEINEN Schatten-Vergleich fuer Phase 3 Stufe B — dafuer braucht es ein
Release-, Irreversibel- oder Budget-Gate.
EOF
