#!/usr/bin/env bash
#
# Story 8 — einen Triage-Zyklus in Auftrag geben
# ==============================================
#
#   ./create-tasks.sh 1     Zyklus 1  (inbox/zyklus-1/)
#   ./create-tasks.sh 2     Zyklus 2  (inbox/zyklus-2/)
#
# Beide Zyklen laufen auf DERSELBEN Identitaet: Profil `inbox-triage`, Board
# `kanban-story-8`, Workspace `mailops/`. Es gibt keinen Elternagenten — das
# Profil IST der Agent.
#
# Die Eskalation an `legal` legt der Assistent selbst an (kanban_create),
# waehrend er laeuft. Sie steht nicht in diesem Skript.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="kanban-story-8"
TENANT="mailops"
WS="$HERE/workspace/mailops"
CYCLE="${1:-1}"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt (brew install jq)"; exit 1; }
[ -d "$WS/inbox/zyklus-$CYCLE" ] || {
    echo "FEHLER: $WS/inbox/zyklus-$CYCLE fehlt — erst ./setup.sh ausfuehren."
    exit 1
}

ID=$(hermes kanban --board "$BOARD" create "Posteingang sichten — Zyklus $CYCLE" \
    --assignee inbox-triage --tenant "$TENANT" \
    --workspace "dir:$WS" \
    --priority 1 \
    --idempotency-key "triage-zyklus-$CYCLE" \
    --max-runtime 20m \
    --json --body \
"Dies ist Zyklus $CYCLE deiner laufenden Arbeit an diesem Postfach. Du bist
nicht neu hier.

## Zuerst lesen — immer, in dieser Reihenfolge
1. PROFILE.md — wer der Eigentuemer ist, wie er schreibt, wer fuer ihn zaehlt.
2. MEMORY-NOTES.md — was DU in frueheren Zyklen gelernt hast. Diese Notizen
   haben Vorrang vor deinem ersten Eindruck.
3. ESKALATIONSREGELN.md — was du nicht selbst entscheiden darfst.

## Dann arbeiten
Sichte jede Datei in inbox/zyklus-$CYCLE/ und ordne sie einer Klasse zu:
handeln / antworten / spaeter lesen / ignorieren. Begruende jede Zuordnung in
einem Satz.

- Fuer 'antworten': schreibe einen Entwurf nach drafts/ als
  <nachrichtendatei>.antwort.md — in der Stimme aus PROFILE.md.
  Du versendest nichts.
- Faellt eine Nachricht unter die Eskalationsregeln fuer 'legal': lege mit
  kanban_create eine Karte an —
    assignee='legal',
    parents=[<diese Karte>],
    workspace_kind='dir', workspace_path='$WS',
    title='Rechtliche Pruefung: <Thema>',
    body=<vollstaendiger Sachverhalt, Dateiname der Nachricht, konkrete Frage>
  Danach arbeitest du den Rest des Posteingangs WEITER ab. Eine Eskalation
  haelt den Zyklus nicht an.
- Faellt eine Nachricht unter 'An Anders selbst': kein Entwurf, nur in den
  Digest unter '## Braucht dich'.

## Ergebnisse
1. digests/zyklus-$CYCLE.md — Abschnitte '## Braucht dich',
   '## Entwuerfe liegen bereit', '## Eskaliert', '## Spaeter', '## Ignoriert'.
2. logs/journal.jsonl — eine Zeile je Nachricht, angehaengt:
   {\"ts\": \"...\", \"cycle\": $CYCLE, \"message\": \"...\", \"decision\": \"...\", \"reason\": \"...\"}
3. MEMORY-NOTES.md — **fortschreiben**, nicht neu schreiben. Ergaenze unter
   '## Absender', was du ueber die Absender gelernt hast (wer sie sind, wie
   dringend sie sind, was sie brauchen), unter '## Muster' wiederkehrende
   Ablaeufe, unter '## Korrekturen' alles, was sich als falsch erwiesen hat.
   Schreibe so, dass DU im naechsten Zyklus damit schneller bist.

Schliesse mit kanban_complete(summary=..., metadata={\"cycle\": $CYCLE,
\"triaged\": N, \"escalated\": [...], \"changed_files\": [...]})." | jq -r .id)

cat > "$HERE/task-ids.env" <<EOF
BOARD=$BOARD
TENANT=$TENANT
CYCLE=$CYCLE
TRIAGE=$ID
EOF

echo "Zyklus $CYCLE angelegt auf Board $BOARD: $ID"
echo "IDs in task-ids.env"
hermes kanban --board "$BOARD" list --tenant "$TENANT"
