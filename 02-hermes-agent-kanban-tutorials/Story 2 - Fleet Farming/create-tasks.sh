#!/usr/bin/env bash
#
# Story 2 — Fleet Farming
# =======================
#
# Zwölf voneinander UNABHÄNGIGE Tasks, verteilt auf drei Spezialisten-Profile:
#
#     translator    3 Tasks   Homepage nach ES / FR / DE übersetzen
#     transcriber   5 Tasks   fünf rohe Gesprächsnotizen aufbereiten
#     copywriter    4 Tasks   vier Produkttexte aus SKU-Daten schreiben
#
# Kein --parent, keine Abhängigkeiten: alle zwölf stehen sofort auf 'ready'
# und werden vom Dispatcher parallel abgearbeitet.
#
set -euo pipefail

BOARD="kanban-story-2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$HERE/workspace"

[ -d "$WS" ] || { echo "FEHLER: $WS fehlt."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

echo "Arbeitsverzeichnis der Worker: $WS"
echo

# ---------------------------------------------------------------------------
# 3 × Übersetzung
# ---------------------------------------------------------------------------
for lang in Spanish French German; do
    case "$lang" in
        Spanish) code=es ;;
        French)  code=fr ;;
        German)  code=de ;;
    esac
    k create "Translate homepage to $lang" \
        --assignee translator --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Uebersetze source/homepage.md nach $lang.
  1. Lies source/homepage.md.
  2. Schreibe das Ergebnis nach translations/homepage.$code.md.
  3. Markdown-Struktur (Ueberschriften, Listen, Zitat) exakt beibehalten,
     Tonfall Marketing, keine woertliche Uebersetzung von Idiomen.
Schliesse mit kanban_complete ab; metadata = {\"target_language\": \"$lang\", \"output\": \"translations/homepage.$code.md\"}." \
        >/dev/null
    echo "  angelegt: Translate homepage to $lang"
done

# ---------------------------------------------------------------------------
# 5 × Transkription
# ---------------------------------------------------------------------------
for i in 1 2 3 4 5; do
    k create "Transcribe Q3 customer call #$i" \
        --assignee transcriber --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Bereite die rohen Notizen calls/call-$i.txt zu einem sauberen Protokoll auf.
  1. Lies calls/call-$i.txt.
  2. Schreibe transcripts/call-$i.md mit den Abschnitten:
     Account, Teilnehmer, Verlauf (in ganzen Saetzen), Vereinbarte Massnahmen,
     Einschaetzung.
  3. Nichts erfinden — nur das strukturieren, was in den Notizen steht.
Schliesse mit kanban_complete ab; metadata = {\"call\": $i, \"output\": \"transcripts/call-$i.md\"}." \
        >/dev/null
    echo "  angelegt: Transcribe Q3 customer call #$i"
done

# ---------------------------------------------------------------------------
# 4 × Produkttext
# ---------------------------------------------------------------------------
for sku in 1001 1002 1003 1004; do
    k create "Generate product description: SKU-$sku" \
        --assignee copywriter --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Schreibe den Shop-Text fuer SKU-$sku.
  1. Lies products/skus.csv und suche die Zeile mit sku = SKU-$sku.
  2. Schreibe descriptions/SKU-$sku.md mit:
     - einer Headline (max. 8 Woerter)
     - einem Absatz Fliesstext (40-70 Woerter)
     - drei Bullet Points mit konkreten Produktmerkmalen aus der CSV
  3. Nur Fakten aus der CSV verwenden, nichts dazuerfinden.
Schliesse mit kanban_complete ab; metadata = {\"sku\": \"SKU-$sku\", \"output\": \"descriptions/SKU-$sku.md\"}." \
        >/dev/null
    echo "  angelegt: Generate product description: SKU-$sku"
done

echo
echo "Board jetzt (nur content-ops):"
k list --tenant content-ops
echo
echo "Erwartung: 12 Tasks, alle auf 'ready', keine Abhängigkeiten."
