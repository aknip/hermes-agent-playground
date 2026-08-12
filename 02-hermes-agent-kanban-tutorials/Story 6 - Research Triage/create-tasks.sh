#!/usr/bin/env bash
#
# Story 6 — den Recherchegraphen anlegen
# ======================================
#
#   PLAN ──┬─▶ RES_KOSTEN    ─┐
#          ├─▶ RES_LATENZ    ─┤
#          ├─▶ RES_WERKZEUGE ─┼─▶ ANALYSE ──▶ BRIEF
#          └─▶ RES_LIZENZEN  ─┘
#
# Der Fan-in auf ANALYSE entsteht durch vier `--parent`-Angaben an EINER Karte.
# ANALYSE bleibt auf `todo`, bis ALLE vier Rechercheure `done` sind.
#
# Die IDs landen in task-ids.env; `source task-ids.env` holt sie zurueck.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-6"
TENANT="research"
WS="$HERE/workspace"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS" ] || { echo "FEHLER: workspace/ fehlt — erst ./setup.sh ausfuehren."; exit 1; }

FRAGE="Warum stagniert die Migration unserer Bestandskunden von Meridian 1 auf Meridian 2?"

new() {  # new <titel> <assignee> [--parent id ...]
    local title="$1" assignee="$2"; shift 2
    hermes kanban --board "$BOARD" create "$title" \
        --assignee "$assignee" --tenant "$TENANT" \
        --workspace "dir:$WS" \
        "$@" --json | jq -r .id
}

# ---------------------------------------------------------------------------
# 1. Der Planer
# ---------------------------------------------------------------------------
PLAN=$(new "Rechercheplan: Migrationsstau Meridian 2" planner --priority 1 --body \
"Ausgangsfrage: $FRAGE

Das Korpus liegt in sources/. Sieh es dir an und schneide die Frage in genau
vier unabhaengige Arbeitspakete — Kosten, Latenz/Durchsatz, Werkzeuge und
Lizenzen. Unabhaengig heisst: kein Paket braucht das Ergebnis eines anderen.

Schreibe plan/rechercheplan.md mit je Paket:
- Blickwinkel und Abgrenzung (was gehoert NICHT dazu)
- die Quellen unter sources/, die dafuer zustaendig sind
- die Zieldatei unter findings/
- woran man erkennt, dass das Paket fertig ist

Du beantwortest die Frage NICHT. Du legst fest, wer welchen Teil beantwortet.

Schliesse mit kanban_complete(summary=..., metadata={\"packages\": [...],
\"changed_files\": [\"plan/rechercheplan.md\"]}).")

# ---------------------------------------------------------------------------
# 2. Vier Rechercheure — unabhaengig, alle Kind des Plans
# ---------------------------------------------------------------------------
res() {  # res <slug> <titel> <quellenhinweis>
    new "Recherche: $2" researcher --parent "$PLAN" --priority 2 --body \
"Ausgangsfrage der Gesamtrecherche: $FRAGE

Dein Blickwinkel — und nur dieser: $2

Deine Quelle ist $3
Arbeite ausschliesslich mit dem, was dort steht. Was das Korpus nicht hergibt,
weisst du nicht; schreib das dann hin, statt es zu ergaenzen.

Findest du dort nichts Auswertbares, rufe kanban_block(reason=...) auf und
nenne genau, was dir fehlt und was du stattdessen braeuchtest. Weiche NICHT
auf andere Verzeichnisse aus und erfinde nichts.

Schreibe findings/$1.md mit:
- '## Befunde' — nummeriert. Jeder Befund mit Beleg: Datei und Stelle.
- '## Zahlen' — was sich beziffern laesst, mit Quelle.
- '## Luecken' — was dein Blickwinkel nicht beantworten kann und warum.

Schliesse mit kanban_complete(summary=..., metadata={\"findings\": [...],
\"sources\": [...], \"changed_files\": [\"findings/$1.md\"]})."
}

RES_KOSTEN=$(res    kosten    "Kosten und Preisstruktur"        "sources/kosten/.")
RES_LATENZ=$(res    latenz    "Latenz und Durchsatz"            "sources/latenz/.")
RES_WERKZEUGE=$(res werkzeuge "Migrationswerkzeuge und Betrieb" "sources/werkzeuge/.")
RES_LIZENZEN=$(res  lizenzen  "Lizenz- und Vertragsbedingungen" "sources/lizenzen/.")

# ---------------------------------------------------------------------------
# 3. Fan-in: eine Karte, vier Eltern
# ---------------------------------------------------------------------------
ANALYSE=$(new "Analyse: Befunde zusammenfuehren und ranken" analyst \
    --parent "$RES_KOSTEN" --parent "$RES_LATENZ" \
    --parent "$RES_WERKZEUGE" --parent "$RES_LIZENZEN" \
    --priority 1 --body \
"Ausgangsfrage: $FRAGE

Vier Rechercheure haben ihre Blickwinkel abgeschlossen. Ihre Handoffs stehen
in deinem Kontext — die Metadaten jedes Elternteils tragen 'findings' und
'sources'. Lies alle vier, BEVOR du schreibst; die Dateien unter findings/
kannst du zusaetzlich lesen.

Schreibe analysis/analyse.md mit:
- '## Rangliste' — die Ursachen, sortiert nach Belegstaerke, nicht nach
  Ueberzeugungsgrad des jeweiligen Rechercheurs. Je Eintrag: Ursache, Beleg,
  wie viele der vier Blickwinkel sie stuetzen.
- '## Zusammenfassungen' — wo zwei Blickwinkel denselben Befund von
  verschiedenen Seiten erreicht haben. Das macht ihn staerker, nicht laenger.
- '## Widersprueche' — wo sich Quellen widersprechen. Benenne sie, mittele
  sie nicht weg.
- '## Nicht belegt' — was plausibel klingt, aber im Korpus keinen Beleg hat.

Schliesse mit kanban_complete(summary=..., metadata={\"ranked\": [...],
\"contradictions\": [...], \"changed_files\": [\"analysis/analyse.md\"]}).")

# ---------------------------------------------------------------------------
# 4. Der Brief
# ---------------------------------------------------------------------------
BRIEF=$(new "Brief: Entscheidungsvorlage fuer die Produktleitung" writer \
    --parent "$ANALYSE" --priority 1 --body \
"Ausgangsfrage: $FRAGE

Deine Quelle ist der Handoff der Analyse in deinem Kontext, ergaenzend
analysis/analyse.md. Fuege nichts hinzu, was dort nicht steht.

Adressat: die Produktleitung, die am Freitag ueber die Migrationsstrategie
entscheidet. Sie hat fuenf Minuten.

Schreibe brief/entscheidungsvorlage.md, hoechstens eine Seite:
- '## Befund' — der eine Satz, der zaehlt, zuerst.
- '## Was das bedeutet' — drei bis fuenf Saetze.
- '## Empfehlung' — konkret und umsetzbar, mit der erwarteten Wirkung.
- '## Offen' — was vor der Entscheidung noch geklaert werden muss.

Jede Behauptung traegt ihren Beleg mit.

Schliesse mit kanban_complete(summary=..., metadata={\"recommendation\": \"...\",
\"changed_files\": [\"brief/entscheidungsvorlage.md\"]}).")

# ---------------------------------------------------------------------------
cat > "$HERE/task-ids.env" <<EOF
BOARD=$BOARD
TENANT=$TENANT
PLAN=$PLAN
RES_KOSTEN=$RES_KOSTEN
RES_LATENZ=$RES_LATENZ
RES_WERKZEUGE=$RES_WERKZEUGE
RES_LIZENZEN=$RES_LIZENZEN
ANALYSE=$ANALYSE
BRIEF=$BRIEF
EOF

echo "Angelegt auf Board $BOARD (Mandant $TENANT):"
printf '  %-14s %s\n' PLAN "$PLAN" \
    RES_KOSTEN "$RES_KOSTEN" RES_LATENZ "$RES_LATENZ" \
    RES_WERKZEUGE "$RES_WERKZEUGE" RES_LIZENZEN "$RES_LIZENZEN" \
    ANALYSE "$ANALYSE" BRIEF "$BRIEF"
echo
echo "IDs in task-ids.env — mit 'source task-ids.env' laden."
hermes kanban --board "$BOARD" list --tenant "$TENANT"
