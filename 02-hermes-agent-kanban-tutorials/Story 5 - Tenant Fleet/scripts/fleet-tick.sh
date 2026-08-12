#!/usr/bin/env bash
#
# fleet-tick.sh — der Enumerator der Mandantenflotte
# ==================================================
#
# Zaehlt die Kundenverzeichnisse unter <story>/workspace/accounts/ ab und legt
# pro Kunde EINE Karte an: eigener Mandant, eigener Workspace, eigener
# Idempotenzschluessel.
#
# Das ist der komplette "Flotten-Runtime". Es gibt keinen Flotten-Dienst, keine
# Account-Statusdatenbank und keinen flottenspezifischen Codepfad im Kernel —
# nur dieses Skript, eine Mandantenspalte und eine Verzeichniskonvention.
#
# Zwei Betriebsarten:
#   ./fleet-tick.sh              einmal von Hand
#   hermes cron create … --script fleet-tick.sh --no-agent    zeitgesteuert
#
# Fuer den Cron-Betrieb muss dieses Skript unter ~/.hermes/scripts/ liegen.
# Das erledigt ./install-cron.sh.
#
# Umgebungsvariablen:
#   FLEET_ROOT    Pfad zu accounts/            (Pflicht im Cron-Betrieb)
#   FLEET_BOARD   Board-Slug                   (Standard: kanban-story-5)
#   FLEET_DAY     Stichtag fuer den Schluessel (Standard: heute)
#
set -euo pipefail

BOARD="${FLEET_BOARD:-kanban-story-5}"
DAY="${FLEET_DAY:-$(date +%F)}"

# Ohne FLEET_ROOT: relativ zum Skript suchen (Aufruf aus dem Story-Verzeichnis).
if [ -n "${FLEET_ROOT:-}" ]; then
    ACCOUNTS="$FLEET_ROOT"
else
    HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ACCOUNTS="$(cd "$HERE/.." && pwd)/workspace/accounts"
fi

[ -d "$ACCOUNTS" ] || { echo "fleet-tick: '$ACCOUNTS' existiert nicht" >&2; exit 1; }

created=0
skipped=0
TICK_START=$(date +%s)

for dir in "$ACCOUNTS"/*/; do
    [ -d "$dir" ] || continue
    slug="$(basename "$dir")"
    abs="${dir%/}"

    # --idempotency-key: derselbe Kunde am selben Tag ergibt dieselbe Karte.
    # Ein zweiter Tick legt nichts doppelt an, er gibt die vorhandene ID zurueck.
    out=$(hermes kanban --board "$BOARD" create "Tagesdigest $slug ($DAY)" \
        --assignee account-manager \
        --tenant "$slug" \
        --workspace "dir:$abs" \
        --priority 1 \
        --max-retries 1 \
        --idempotency-key "digest-$slug-$DAY" \
        --json \
        --body "Erstelle das Tagesbriefing fuer den Kunden in deinem Workspace.

Dein Mandant steht in \$HERMES_TENANT und ist '$slug'. Der Workspace ist der
komplette Datenraum genau dieses Kunden — arbeite ausschliesslich darin.

Ablauf:
1. Lies ACCOUNT.md, OPEN-ITEMS.md, activity.csv und alle Dateien in inbox/.
   Fehlt eine dieser Dateien, brich mit kanban_block(reason=...) ab und nenne
   die fehlende Datei. Rate nichts.
2. Schreibe digests/$DAY.md mit genau diesen Abschnitten:
   - '## Lage' — zwei bis vier Saetze, beginnend mit dem Wichtigsten.
   - '## Neue Nachrichten' — je Nachricht eine Zeile: Absender, Anliegen,
     benoetigte Reaktion.
   - '## Kennzahlen' — was sich in activity.csv veraendert hat, mit Zahlen.
   - '## Naechste Schritte' — nummeriert, jeder Punkt mit Verantwortlichem
     und Frist, sofern die Daten eine hergeben.
   Jede Zahl und jedes Zitat muss aus den Dateien dieses Kunden stammen.
3. Haenge an logs/journal.jsonl fuer jede Aktion eine Zeile an — ein
   JSON-Objekt pro Zeile mit den Schluesseln ts, tenant, action, detail.
   Die Datei wird fortgeschrieben, nie neu geschrieben.
4. Schliesse mit kanban_complete(summary=..., metadata={\"tenant\": \"$slug\",
   \"changed_files\": [...], \"actions\": <anzahl>})." 2>/dev/null) || {
        echo "fleet-tick: Karte fuer $slug konnte nicht angelegt werden" >&2
        continue
    }

    id=$(printf '%s' "$out" | jq -r .id)
    # Bei einem Treffer auf den Idempotenzschluessel gibt `create` die
    # BESTEHENDE Karte zurueck — erkennbar daran, dass sie aelter ist als
    # dieser Tick.
    born=$(printf '%s' "$out" | jq -r '.created_at // 0')
    if [ "$born" -lt "$TICK_START" ]; then
        skipped=$((skipped + 1))
        printf '  %-16s %s  (bereits vorhanden)\n' "$slug" "$id"
    else
        created=$((created + 1))
        printf '  %-16s %s  neu\n' "$slug" "$id"
    fi
done

echo "fleet-tick $DAY auf Board $BOARD: $created neu, $skipped uebersprungen"
