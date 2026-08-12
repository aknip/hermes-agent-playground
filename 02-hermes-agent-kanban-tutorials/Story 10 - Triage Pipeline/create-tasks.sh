#!/usr/bin/env bash
#
# Story 10 - Triage Pipeline — Die drei Startkarten anlegen
# =========================================================
#
# Von Hand angelegt wird nur der EINGANG der Pipeline:
#
#     Scout x   ─┐
#                ├─▶ Triage (dedup + bewerten + Fan-out)
#     Scout web ─┘
#
# Alles danach — Recherche-Bahnen, Route, Prep, Tor, Umsetzung — legt die
# Flotte selbst an, waehrend sie laeuft. Das ist der Unterschied zu Story 6,
# wo der ganze Graph vorher feststeht.
#
# Die IDs landen in task-ids.env:  source task-ids.env
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-10"
TENANT="triage"
WS="$HERE/workspace"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS/sources/x" ] || { echo "FEHLER: $WS/sources fehlt. Erst ./setup.sh."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "Scout-Karten (laufen parallel)"
# ---------------------------------------------------------------------------
# Beide Scouts laufen auf DEMSELBEN Profil, mit unterschiedlichem Auftrag.
# Im Original sind es zwei Profile mit zwei Modellen — der Mechanismus dafuer
# ist --model/--provider je Karte, siehe TUTORIAL.md, Schritt 10.7.
scout_body() {
    local id="$1" dir="$2" bericht="$3" auftrag="$4"
    cat <<EOF
Quelle: $id

Werte JEDE Datei unter $dir aus — alle, nicht stichprobenartig.

Auftrag dieser Quelle:
$auftrag

Halte dich an die Skill 'scout-report': ein \`##\`-Abschnitt je Kandidat, die
Felder aus pipeline/triage.yaml (item_schema.felder), Zitate woertlich.

Zwei Dateien, die denselben Fehlermechanismus beschreiben, sind EIN Kandidat
mit zwei Quellen — nicht zwei Kandidaten.

Schreibe den Bericht nach $bericht.

Du erkennst nur. Nicht deduplizieren (ueber Quellgrenzen hinweg), nicht
bewerten, nicht entscheiden, was damit geschieht.
EOF
}

SCOUT_X=$(k create "Scout x: sources/x auswerten" \
    --assignee triage-scout --tenant "$TENANT" \
    --workspace "dir:$WS" --skill scout-report \
    --max-retries 2 --max-runtime 20m \
    --body "$(scout_body x sources/x intake/x.md \
      "Suche nach Leuten, die konkreten, aktuellen Schmerz mit KI-Coding-Agenten beschreiben — verlorene Stunden, aufgegeben, kaputter Ablauf. Zitiere sie. Ueberspringe vages Marketing.")" \
    --json | jq -r .id)
echo "  SCOUT_X   = $SCOUT_X"

SCOUT_WEB=$(k create "Scout web: sources/web auswerten" \
    --assignee triage-scout --tenant "$TENANT" \
    --workspace "dir:$WS" --skill scout-report \
    --max-retries 2 --max-runtime 20m \
    --body "$(scout_body web sources/web intake/web.md \
      "Suche in Foren-, Reddit- und YouTube-Mitschriften nach Nutzern, die konkrete Reibung oder Verwirrung beschreiben. Bevorzuge Faeden, in denen mehrere Stimmen dasselbe bestaetigen. Halte fest, wie viele unabhaengige Stimmen dasselbe sagen.")" \
    --json | jq -r .id)
echo "  SCOUT_WEB = $SCOUT_WEB"

# ---------------------------------------------------------------------------
say "Triage-Karte (Fan-in auf beide Scouts)"
# ---------------------------------------------------------------------------
read -r -d '' TRIAGE_BODY <<'EOF' || true
Du bist Stufe 1 der Pipeline. Die Skill 'triage-pipeline' beschreibt sie
vollstaendig — Abschnitt "Stufe 1 — Triage".

Eingang: die beiden Scout-Berichte unter intake/. Sie stehen ausserdem als
Eltern-Handoff in deinem Kontext.

Kurzfassung dessen, was zu tun ist:

1. pipeline/triage.yaml lesen. Rubrik, Schwelle und Dedup-Kriterium stehen
   DORT, nicht in deinem Gedaechtnis.
2. Kandidaten beider Berichte zusammenfuehren und deduplizieren. Derselbe
   Fehlermechanismus ist dasselbe Item, auch bei anderer Wortwahl und anderer
   Plattform. Je neues Item eine Datei vault/items/<slug>.md.
3. Jedes Item gegen die Rubrik bewerten, je Dimension mit einem Satz
   Begruendung. Score und score_breakdown in den Kopf der Item-Datei.
4. Items UNTER der Schwelle: status auf 'archiviert' setzen, Begruendung
   dazu, fertig. Kein Fan-out, kein Mensch wird gefragt.
5. Items AB der Schwelle: fuer jedes die drei Recherche-Bahnen aus
   recherche_bahnen.bahnen anlegen (parents = [diese Karte hier]) und genau
   EINE Route-Karte, die alle drei Bahnen als parents hat.

   workspace_kind="dir" und workspace_path = der ABSOLUTE Pfad in
   $HERMES_KANBAN_WORKSPACE. tenant="triage".

6. Sofort danach kanban_complete mit der Liste der Items und der angelegten
   Kartennummern in den Metadaten.
EOF

TRIAGE=$(k create "Triage: dedup, bewerten, Fan-out" \
    --assignee triage-orchestrator --tenant "$TENANT" \
    --workspace "dir:$WS" --skill triage-pipeline \
    --parent "$SCOUT_X" --parent "$SCOUT_WEB" \
    --max-retries 2 --max-runtime 30m \
    --body "$TRIAGE_BODY" --json | jq -r .id)
echo "  TRIAGE    = $TRIAGE"

# Werte gequotet: der Story-Pfad enthaelt Leerzeichen, sonst bricht `source`.
cat > "$HERE/task-ids.env" <<EOF
# Von create-tasks.sh erzeugt — $(date '+%Y-%m-%d %H:%M')
BOARD='$BOARD'
TENANT='$TENANT'
WS='$WS'
SCOUT_X='$SCOUT_X'
SCOUT_WEB='$SCOUT_WEB'
TRIAGE='$TRIAGE'
EOF

say "Board"
k list --tenant "$TENANT"

cat <<EOF

IDs liegen in task-ids.env:   source task-ids.env

Weiter:   ./pump.sh
Das Tor:  ./gate.sh            (zeigt, worauf gewartet wird)
EOF
