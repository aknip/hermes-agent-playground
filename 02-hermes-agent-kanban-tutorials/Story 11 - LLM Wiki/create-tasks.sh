#!/usr/bin/env bash
#
# Story 11 - LLM Wiki — Die drei Startkarten anlegen
# ==================================================
#
# Von Hand angelegt wird nur der EINGANG der Pipeline:
#
#     Scout releases    ─┐
#                        ├─▶ Triage (dedup gegen die Wissensbasis + bewerten)
#     Scout transcripts ─┘
#
# Alles danach — Recherche-Bahnen, Route, Tor 1, Ingest, Lint, Tor 2, Merge —
# legt die Flotte selbst an, waehrend sie laeuft.
#
# Die IDs landen in task-ids.env:  source task-ids.env
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-11"
TENANT="wiki"
WS="$HERE/workspace"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS/sources/releases" ] || { echo "FEHLER: $WS/sources fehlt. Erst ./setup.sh."; exit 1; }
[ -d "$WS/wiki/.git" ] || { echo "FEHLER: $WS/wiki ist kein Git-Repository. Erst ./setup.sh."; exit 1; }

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
say "Scout-Karten (laufen parallel)"
# ---------------------------------------------------------------------------
# Beide Scouts laufen auf DEMSELBEN Profil, mit unterschiedlichem Auftrag. Im
# Original sind es zwei Modelle (Grok fuer die Suche auf X); der Mechanismus
# dafuer ist --model/--provider je Karte, siehe TUTORIAL.md, Varianten.
scout_body() {
    local id="$1" dir="$2" bericht="$3" auftrag="$4"
    cat <<EOF
Quelle: $id

Werte JEDE Datei unter $dir aus — alle, nicht stichprobenartig.

Auftrag dieser Quelle:
$auftrag

Halte dich an die Skill 'kb-scout-report': ein \`##\`-Abschnitt je Kandidat, die
Felder aus ingest.yaml (item_schema.felder), Zitate woertlich mit Zeitmarke
bzw. Abschnitt, immer mit Version (oder \`unbestimmt\`).

Zwei Dateien, die dieselbe Aenderung beschreiben, sind EIN Kandidat mit zwei
Quellen — nicht zwei Kandidaten.

Schreibe den Bericht nach $bericht.

Du erkennst nur. Du entscheidest NICHT, ob die Wissensbasis das schon kennt
(dazu hast du sie nicht gelesen — 'neuheit_vermutet' ist eine Vermutung), und
du entscheidest NICHT, ob es wichtig ist. Beides tut die Triage.
EOF
}

SCOUT_REL=$(k create "Scout releases: sources/releases auswerten" \
    --assignee kb-scout --tenant "$TENANT" \
    --workspace "dir:$WS" --skill kb-scout-report \
    --max-retries 2 --max-runtime 20m \
    --body "$(scout_body releases sources/releases intake/releases.md \
      "Changelogs und Release-Notes. Jede inhaltliche Aenderung, die eine Aussage in der Wissensbasis betreffen koennte, ist ein Kandidat: neue Funktion, geaendertes Verhalten, Deprecation, korrigierte Dokumentation. Halte Version und Datum fest.")" \
    --json | jq -r .id)
echo "  SCOUT_REL   = $SCOUT_REL"

SCOUT_TRA=$(k create "Scout transcripts: sources/transcripts auswerten" \
    --assignee kb-scout --tenant "$TENANT" \
    --workspace "dir:$WS" --skill kb-scout-report \
    --max-retries 2 --max-runtime 20m \
    --body "$(scout_body transcripts sources/transcripts intake/transcripts.md \
      "Video-Transkripte. Ein Kandidat ist eine ueberpruefbare Aussage ueber Hermes Agent — ein gemessenes Verhalten, eine korrigierte Annahme, eine erklaerte Mechanik. Zitiere mit Zeitmarke. Kanal-Neuigkeiten, Ankuendigungen und Meinungen sind KEINE Kandidaten.")" \
    --json | jq -r .id)
echo "  SCOUT_TRA   = $SCOUT_TRA"

# ---------------------------------------------------------------------------
say "Triage-Karte (Fan-in auf beide Scouts)"
# ---------------------------------------------------------------------------
# --max-runtime 45m ist ein MESSWERT, keine Schaetzung: diese Karte muss 31
# Kandidaten gegen sieben Wiki-Seiten pruefen und brauchte dafuer real 25
# Minuten. Sie ist die teuerste Karte der Story, und ein Timeout laesst sie den
# ganzen Lesevorgang wiederholen. rubrik.max_pro_lauf hilft hier NICHT — der
# Deckel greift erst NACH der Bewertung.
read -r -d '' TRIAGE_BODY <<'EOF' || true
Du bist Stufe 1 der Pipeline. Die Skill 'kb-pipeline' beschreibt sie
vollstaendig — Abschnitt "Stufe 1 — Triage".

Eingang: die beiden Scout-Berichte unter intake/. Sie stehen ausserdem als
Eltern-Handoff in deinem Kontext.

Kurzfassung dessen, was zu tun ist:

1. ingest.yaml lesen. Rubrik, Schwelle, Buendelungs- und Dedup-Kriterium stehen
   DORT, nicht in deinem Gedaechtnis. Und wiki/AGENTS.md lesen — es sagt dir,
   wie die Wissensbasis gebaut ist, die du gleich beurteilst.

2. BUENDELN: Kandidaten, die dieselbe Seitengruppe betreffen und aus demselben
   Vorgang stammen, sind EIN Item. Zwei Patch-Releases derselben Hauptversion
   sind ein Item, nicht zwei. Je Item eine Datei vault/<slug>.md.

3. DEDUP gegen die WISSENSBASIS, nicht gegen die Kandidaten. Die Frage ist
   nicht "haben wir das schon gemeldet", sondern "wissen wir das schon".
   Sieh in wiki/index.md nach, welche Seiten es gibt, und LIES die betroffenen
   Seiten unter wiki/pages/ wirklich. Notiere je Seite, was dort steht und in
   welcher Genauigkeit. Eine Seite, die das Thema erwaehnt, ist keine
   Abdeckung.

4. Jedes Item gegen die Rubrik bewerten, je Dimension mit einem Satz
   Begruendung. score und score_breakdown in den Kopf der Item-Datei.

5. Items UNTER der Schwelle und Items, die bereits abgedeckt sind: status auf
   'geshelved' setzen, Begruendung mit Fundstelle dazu, fertig. Kein Fan-out,
   kein Mensch wird gefragt.

6. Items AB der Schwelle: fuer jedes die zwei Recherche-Bahnen aus
   recherche_bahnen.bahnen anlegen (parents = [diese Karte hier]) und genau
   EINE Route-Karte, die beide Bahnen als parents hat.

   workspace_kind="dir" und workspace_path = der ABSOLUTE Pfad aus
   $HERMES_KANBAN_WORKSPACE. tenant="wiki". idempotency_key je Karte.

7. Sofort danach kanban_complete mit der Liste der Items und der angelegten
   Kartennummern in den Metadaten.

Du schreibst in dieser Stufe NICHTS nach wiki/. Kein Zeichen.
EOF

TRIAGE=$(k create "Triage: buendeln, dedup gegen die Wissensbasis, bewerten" \
    --assignee kb-orchestrator --tenant "$TENANT" \
    --workspace "dir:$WS" --skill kb-pipeline \
    --parent "$SCOUT_REL" --parent "$SCOUT_TRA" \
    --max-retries 2 --max-runtime 45m \
    --body "$TRIAGE_BODY" --json | jq -r .id)
echo "  TRIAGE      = $TRIAGE"

# Werte gequotet: der Story-Pfad enthaelt Leerzeichen, sonst bricht `source`.
cat > "$HERE/task-ids.env" <<EOF
# Von create-tasks.sh erzeugt — $(date '+%Y-%m-%d %H:%M')
BOARD='$BOARD'
TENANT='$TENANT'
WS='$WS'
WIKI='$WS/wiki'
SCOUT_REL='$SCOUT_REL'
SCOUT_TRA='$SCOUT_TRA'
TRIAGE='$TRIAGE'
EOF

say "Board"
k list --tenant "$TENANT"

cat <<EOF

IDs liegen in task-ids.env:   source task-ids.env

Weiter:    ./pump.sh
Die Tore:  ./gate.sh          (zeigt, worauf gewartet wird — und an welchem Tor)
Git:       ./reset-workspace.sh --git
EOF
