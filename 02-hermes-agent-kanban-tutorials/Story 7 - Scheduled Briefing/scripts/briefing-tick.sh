#!/usr/bin/env bash
#
# briefing-tick.sh — eine Tagesausgabe des Briefings in Auftrag geben
# ===================================================================
#
#   scout ──▶ editor ──▶ publisher
#
# Legt die dreistufige Pipeline fuer EINEN Stichtag an. Zweimal fuer denselben
# Tag aufgerufen entsteht nichts Neues (Idempotenzschluessel).
#
#   ./briefing-tick.sh                 heute
#   ./briefing-tick.sh 2026-08-10      bestimmter Tag
#
# Im Cron-Betrieb muss dieses Skript unter ~/.hermes/scripts/ liegen;
# das erledigt ../install-cron.sh.
#
# Umgebungsvariablen:
#   VAULT_DIR      Pfad zum Vault      (Standard: ../workspace/vault)
#   VAULT_BOARD    Board-Slug          (Standard: kanban-story-7)
#
set -euo pipefail

BOARD="${VAULT_BOARD:-kanban-story-7}"
DAY="${1:-${BRIEFING_DAY:-$(date +%F)}}"

if [ -n "${VAULT_DIR:-}" ]; then
    VAULT="$VAULT_DIR"
else
    HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VAULT="$(cd "$HERE/.." && pwd)/workspace/vault"
fi

[ -d "$VAULT" ] || { echo "briefing-tick: Vault '$VAULT' fehlt" >&2; exit 1; }
command -v jq >/dev/null || { echo "briefing-tick: 'jq' fehlt" >&2; exit 1; }

if [ ! -d "$VAULT/sources/$DAY" ]; then
    echo "briefing-tick: kein Quellabwurf unter sources/$DAY — nichts zu tun."
    exit 0
fi

new() {  # new <titel> <assignee> <key> <body> [--parent id]
    local title="$1" assignee="$2" key="$3" body="$4"; shift 4
    hermes kanban --board "$BOARD" create "$title" \
        --assignee "$assignee" --tenant "briefing" \
        --workspace "dir:$VAULT" \
        --idempotency-key "$key" \
        --priority 1 \
        --body "$body" \
        "$@" --json | jq -r .id
}

SCOUT=$(new "Sichten: Quellabwurf $DAY" scout "brief-scout-$DAY" \
"Sichte den Quellabwurf des Tages: sources/$DAY/.

Du sammelst, du bewertest nicht. Ziehe JEDEN Kandidaten heraus, der eine
Finanzierungs- oder Personalmeldung sein koennte — auch schwache. Das Ranking
ist die Karte danach.

Schreibe shortlists/$DAY-kandidaten.md, je Kandidat eine Zeile:
| Unternehmen | Ort | Runde | Betrag | Bewertung | Investoren | Quelle |
Fehlt ein Feld in der Quelle, schreibe null. Erfinde nichts.

Haenge danach eine Zeile an journal.jsonl an:
{\"ts\": \"...\", \"stage\": \"scout\", \"day\": \"$DAY\", \"candidates\": N}

Schliesse mit kanban_complete(summary=..., metadata={\"candidates\": N,
\"changed_files\": [\"shortlists/$DAY-kandidaten.md\", \"journal.jsonl\"]}).")

EDITOR=$(new "Redigieren: Auswahl fuer $DAY" editor "brief-editor-$DAY" \
"Kuerze die Kandidatenliste des Scouts auf das, was Kirsten Aalborg
tatsaechlich lesen will.

Vor allem anderen:
1. Lies READER-PROFILE.md. Relevanz ist relativ zu dieser Leserin.
2. Lies journal.jsonl UND die vorhandenen Dateien in editions/. Was in einer
   frueheren Ausgabe schon stand, kommt NICHT wieder. Das ist die wichtigste
   Regel dieser Karte.
3. Fasse Doppelmeldungen innerhalb des Tages zu einem Eintrag zusammen.

Schreibe shortlists/$DAY-auswahl.md mit zwei Abschnitten:
- '## Aufgenommen' — sortiert, wichtigste Meldung zuerst, je Eintrag ein Satz
  zur Begruendung.
- '## Verworfen' — jeder verworfene Kandidat mit dem Grund. Ein stiller
  Rauswurf ist keine redaktionelle Entscheidung.

Haenge an journal.jsonl an:
{\"ts\": \"...\", \"stage\": \"editor\", \"day\": \"$DAY\", \"kept\": N, \"dropped\": N}

Schliesse mit kanban_complete(summary=..., metadata={\"kept\": N,
\"dropped\": N, \"changed_files\": [...]})." --parent "$SCOUT")

PUB=$(new "Ausgabe schreiben: $DAY" publisher "brief-pub-$DAY" \
"Schreibe die Tagesausgabe.

Quelle ist der Handoff des Editors in deinem Kontext, ergaenzend
shortlists/$DAY-auswahl.md. Nur was dort unter 'Aufgenommen' steht.

1. editions/$DAY.md — Form laut READER-PROFILE.md: ein Absatz Einleitung mit
   der wichtigsten Meldung, dann die Liste. Je Eintrag eine Zeile:
   Unternehmen, Runde, Betrag, Investoren, warum relevant.
   Ueberschreibe NIE eine aeltere Ausgabe. Der Vault ist eine Zeitleiste.
2. INDEX.md — die Tabelle um eine Zeile ergaenzen: Ausgabe, Zahl der
   Eintraege, wichtigste Meldung. Bestehende Zeilen bleiben stehen.
3. journal.jsonl — anhaengen:
   {\"ts\": \"...\", \"stage\": \"publisher\", \"day\": \"$DAY\", \"items\": N}

Schliesse mit kanban_complete(summary=..., metadata={\"edition\": \"$DAY\",
\"items\": N, \"changed_files\": [...]})." --parent "$EDITOR")

cat > "$(dirname "${BASH_SOURCE[0]}")/../task-ids-$DAY.env" <<EOF
BOARD=$BOARD
DAY=$DAY
SCOUT=$SCOUT
EDITOR=$EDITOR
PUB=$PUB
EOF

echo "Briefing-Pipeline fuer $DAY auf Board $BOARD:"
printf '  %-10s %s\n' scout "$SCOUT" editor "$EDITOR" publisher "$PUB"
