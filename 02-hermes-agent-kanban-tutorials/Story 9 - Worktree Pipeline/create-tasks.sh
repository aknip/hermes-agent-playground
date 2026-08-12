#!/usr/bin/env bash
#
# Story 9 — die Worktree-Pipeline anlegen
# =======================================
#
#   SPEC ──┬─▶ BACKEND  (Worktree, Branch wt/s9-backend)  ─┐
#          └─▶ FRONTEND (Worktree, Branch wt/s9-frontend) ─┴─▶ REVIEW (Hauptbaum)
#
# BACKEND und FRONTEND laufen gleichzeitig in getrennten Arbeitsbaeumen. Sie
# sehen die Dateien des jeweils anderen nicht — deshalb steht der Vertrag
# zwischen beiden im Karten-Body und nicht im Code.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-9"
TENANT="ledger-export"
REPO="$HERE/workspace/repo"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$REPO/.git" ] || {
    echo "FEHLER: $REPO ist kein Git-Repo — erst ./setup.sh (bzw. ./reset-workspace.sh)."
    exit 1
}

# Der Vertrag zwischen Backend und Frontend. Beide bekommen ihn woertlich,
# weil keiner die Dateien des anderen sehen kann.
CONTRACT='## Vertrag zwischen Backend und Frontend

Beide Seiten halten sich woertlich daran. Ihr arbeitet in getrennten
Arbeitsbaeumen und koennt die Dateien der Gegenseite NICHT lesen.

Datei: `web/ledger-export.csv`, erzeugt vom Backend.
Trennzeichen: Komma. Kodierung: UTF-8 ohne BOM. Zeilenende: \n.
Kopfzeile, genau diese Spalten in genau dieser Reihenfolge:

    entry_id,booked_on,account,description,amount_eur,cost_centre

- `booked_on` im Format YYYY-MM-DD.
- `amount_eur` als Dezimalzahl mit Punkt als Dezimaltrenner und zwei
  Nachkommastellen, negativ mit fuehrendem Minus (Beispiel: -91200.00).
  Kein Tausendertrennzeichen. (Die Anzeige im Browser formatiert deutsch;
  die Datei bleibt maschinenlesbar.)
- `description` wird in doppelte Anfuehrungszeichen gesetzt, wenn sie ein
  Komma enthaelt.
- Sortierung: aufsteigend nach booked_on, dann entry_id.'

new() {  # new <titel> <assignee> [weitere flags...]
    local title="$1" assignee="$2"; shift 2
    hermes kanban --board "$BOARD" create "$title" \
        --assignee "$assignee" --tenant "$TENANT" \
        "$@" --json | jq -r .id
}

# ---------------------------------------------------------------------------
# 1. Spezifikation — im HAUPTBAUM, damit beide Worktrees sie vom Commit erben
# ---------------------------------------------------------------------------
SPEC=$(new "Spezifikation: Ledger-Export als CSV" planner \
    --workspace "dir:$REPO" --priority 1 --body \
"minibuch soll seine Buchungen als CSV exportieren koennen — im Modul und in
der Oberflaeche.

Sieh dir ledger/model.py, ledger/reports.py, web/index.html und web/app.js an.
Der vorhandene Monatsbericht ist die Stilvorlage.

Schreibe spec/ledger-export.md mit:
- '## Ziel' — ein Satz.
- '## Nicht im Umfang' — was ausdruecklich NICHT gebaut wird.
- '## Backend' — welche Funktion in welcher Datei, welche Signatur.
- '## Frontend' — welche Datei, welches Verhalten.
- '## Akzeptanzkriterien' — nummeriert und pruefbar. 'Behandelt Fehler
  sauber' ist kein Kriterium; 'ein Betrag von -9120000 Cent erscheint als
  -91200.00' ist eins.

Der Datenvertrag zwischen beiden Seiten steht bereits fest, uebernimm ihn
unveraendert in die Spezifikation:

$CONTRACT

Committe die Spezifikation auf main:
  git add -A && git commit -m 'Spezifikation Ledger-Export'

Schliesse mit kanban_complete(summary=..., metadata={\"acceptance\": [...],
\"changed_files\": [\"spec/ledger-export.md\"], \"commit\": \"<kurz-sha>\"}).")

# ---------------------------------------------------------------------------
# 2. Zwei Entwickler, gleichzeitig, in eigenen Worktrees
# ---------------------------------------------------------------------------
BACKEND=$(new "Backend: CSV-Export im Modul" backend-eng \
    --parent "$SPEC" --priority 2 \
    --workspace "worktree:$REPO" --branch "wt/s9-backend" --body \
"Implementiere den CSV-Export im Modul.

Dein Arbeitsbaum ist ein eigener Git-Worktree auf dem Branch wt/s9-backend.
Der Frontend-Entwickler arbeitet ZEITGLEICH in einem Nachbar-Worktree auf
wt/s9-frontend. Du kannst seine Dateien nicht sehen und brauchst sie nicht.

Nur diese Dateien gehoeren dir:
  ledger/export.py          (neu)
  tests/test_export.py      (neu)
  web/ledger-export.csv     (erzeugte Ausgabe, eingecheckt)
Fass web/index.html und web/app.js NICHT an — die gehoeren dem Frontend.

Die Akzeptanzkriterien stehen im Handoff der Spezifikation in deinem Kontext,
die Datei liegt zusaetzlich unter spec/ledger-export.md.

$CONTRACT

Aufgaben:
1. ledger/export.py mit einer Funktion, die die Buchungen als CSV-Text
   zurueckgibt, und einer, die sie nach web/ledger-export.csv schreibt.
   Nur Standardbibliothek. Stil wie ledger/reports.py.
2. tests/test_export.py im Stil von tests/test_reports.py — Kopfzeile,
   Sortierung, Betragsformat, Maskierung von Kommata.
3. Beides wirklich ausfuehren: python3 -m tests.test_export. Berichte, was
   herauskam.
4. web/ledger-export.csv erzeugen und mit einchecken.
5. Committen:
   git add -A && git commit -m 'Backend: CSV-Export'

Schliesse mit kanban_complete(summary=..., metadata={\"branch\":
\"wt/s9-backend\", \"changed_files\": [...], \"commit\": \"<kurz-sha>\",
\"tests_passed\": \"<n>/<m>\"}).")

FRONTEND=$(new "Frontend: Exportansicht und Download" frontend-eng \
    --parent "$SPEC" --priority 2 \
    --workspace "worktree:$REPO" --branch "wt/s9-frontend" --body \
"Baue die Exportansicht in der Oberflaeche.

Dein Arbeitsbaum ist ein eigener Git-Worktree auf dem Branch wt/s9-frontend.
Der Backend-Entwickler arbeitet ZEITGLEICH in einem Nachbar-Worktree auf
wt/s9-backend. Seine Dateien existieren in deinem Baum NICHT — auch
web/ledger-export.csv noch nicht. Programmiere gegen den Vertrag unten, nicht
gegen seine Dateien, und behandle die fehlende Datei als regulaeren Fall.

Nur diese Dateien gehoeren dir:
  web/export.html           (neu)
  web/export.js             (neu)
  web/index.html            (nur die Navigation ergaenzen)
Fass ledger/ und tests/ NICHT an — die gehoeren dem Backend.

Die Akzeptanzkriterien stehen im Handoff der Spezifikation in deinem Kontext,
die Datei liegt zusaetzlich unter spec/ledger-export.md.

$CONTRACT

Aufgaben:
1. web/export.html — Aufbau und Stil wie web/index.html, Navigation mit
   beiden Ansichten.
2. web/export.js — laedt web/ledger-export.csv, zerlegt sie (auch die
   maskierten Felder mit Komma), zeigt sie als Tabelle. Betraege in der
   ANZEIGE deutsch formatiert (Punkt als Tausender-, Komma als
   Dezimaltrenner), negative Betraege erkennbar. Dazu ein Knopf
   'Als CSV herunterladen', der die unveraenderte Datei ausliefert.
   Fehlt die Datei oder ist sie leer: verstaendliche Meldung statt leerer
   Tabelle oder Konsolenfehler.
3. web/index.html — Navigationsleiste um den Link auf export.html ergaenzen.
   Sonst nichts aendern.
4. Reines HTML/CSS/JS, kein Framework, kein Build.
5. Committen:
   git add -A && git commit -m 'Frontend: Exportansicht'

Schliesse mit kanban_complete(summary=..., metadata={\"branch\":
\"wt/s9-frontend\", \"changed_files\": [...], \"commit\": \"<kurz-sha>\"}).")

# ---------------------------------------------------------------------------
# 3. Review — Fan-in, im Hauptbaum, liest beide Branches
# ---------------------------------------------------------------------------
REVIEW=$(new "Review: beide Branches gegen die Spezifikation" reviewer \
    --parent "$BACKEND" --parent "$FRONTEND" --priority 1 \
    --workspace "dir:$REPO" --body \
"Zwei Entwickler haben parallel gearbeitet. Ihre Handoffs stehen in deinem
Kontext und nennen je Branch und Commit.

Du arbeitest im HAUPTBAUM auf main. Die Arbeit der beiden liegt auf ihren
Branches; sieh sie dir mit git an:

  git worktree list
  git branch -a
  git diff main..wt/s9-backend
  git diff main..wt/s9-frontend
  git show wt/s9-backend:ledger/export.py

Pruefe:
1. Jedes Akzeptanzkriterium aus spec/ledger-export.md einzeln. Nenne je
   Kriterium die Zeile oder Funktion, die es erfuellt — oder sag, dass es
   nicht erfuellt ist.
2. Den Datenvertrag: Spaltenreihenfolge, Datumsformat, Betragsformat,
   Maskierung. Ein Formatunterschied zwischen den Seiten ist der
   wahrscheinlichste Fehler paralleler Arbeit — such ihn gezielt.
3. Ob die beiden sich in die Dateien des anderen eingemischt haben.
4. Die Tests des Backends: fuehre sie im Backend-Branch wirklich aus.
     git -C .worktrees/<backend-task-id> ... bzw. ueber einen eigenen Worktree
   Berichte das Ergebnis.

Schreibe REVIEW.md auf main mit deinem Urteil (APPROVED oder
CHANGES REQUESTED), je Kriterium einer Zeile Beleg, und den offenen Punkten.
Committe es:
  git add REVIEW.md && git commit -m 'Review Ledger-Export'

Schliesse mit kanban_complete(summary=..., metadata={\"verdict\": \"...\",
\"findings\": [...], \"changed_files\": [\"REVIEW.md\"]}).")

cat > "$HERE/task-ids.env" <<EOF
BOARD=$BOARD
TENANT=$TENANT
REPO="$REPO"
SPEC=$SPEC
BACKEND=$BACKEND
FRONTEND=$FRONTEND
REVIEW=$REVIEW
EOF

echo "Angelegt auf Board $BOARD (Mandant $TENANT):"
printf '  %-9s %s\n' SPEC "$SPEC" BACKEND "$BACKEND" FRONTEND "$FRONTEND" REVIEW "$REVIEW"
echo
echo "IDs in task-ids.env — mit 'source task-ids.env' laden."
hermes kanban --board "$BOARD" list --tenant "$TENANT"
