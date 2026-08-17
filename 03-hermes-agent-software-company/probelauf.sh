#!/usr/bin/env bash
#
# ESF — Der Phase-0-Probelauf
# ===========================
#
#   ./probelauf.sh            die Kette anlegen
#   ./probelauf.sh --pruefen  prüfen, ob der Nachweis erbracht ist
#   ./probelauf.sh --aufraeumen  Karten archivieren, Branch und Worktree entfernen
#
# Der Abschluss-Nachweis aus Kapitel 12 für Phase 0, wörtlich:
#
#   "Probelauf: eine Dummy-Kette Spezifikation→Bau→Review→Riegel läuft durch;
#    ein Probe-Gate hält (dry-run: Spawned 0)"
#
# Die Kette ist bewusst winzig — sie prüft nicht, ob die Organisation gute
# Software baut, sondern ob die MECHANIK trägt: Handoff über Eltern-Ketten,
# Worktree-Isolation, Review über einen fremden Baum, der deterministische
# Riegel, und ein Gate, das den Dispatcher wirklich anhält.
#
#   PROBE-SPEC   esf-product-manager  dir:vault      Spezifikation schreiben
#        └─ PROBE-BAU     esf-dev-a   worktree       umsetzen, mit Test
#             └─ PROBE-REVIEW esf-reviewer worktree  fremden Baum prüfen
#                  └─ PROBE-GATE  esf-chief-of-staff dir:vault  blockiert sich
#
# Das Gate ist die vierte Karte und blockiert sich SELBST — nicht per
# --initial-status blocked. Der Unterschied ist der ganze Punkt: --initial-status
# parkt eine Karte nur, sie läuft durch, sobald ihre Eltern fertig sind, ohne
# Fehler und ohne Warnung. Nur kanban_block erzeugt ein echtes blocked-Ereignis,
# das den Dispatcher stoppt.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
VAULT="$HERE/workspace/company"
IDS="$HERE/task-ids-probe.env"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }

REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
BRANCH="feat/esf-probelauf"

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
if [ "${1:-}" = "--aufraeumen" ]; then
    say "Probelauf zurückbauen"
    if [ -f "$IDS" ]; then
        # shellcheck disable=SC1090
        . "$IDS"
        for id in "${PROBE_GATE:-}" "${PROBE_REVIEW:-}" "${PROBE_BAU:-}" "${PROBE_SPEC:-}"; do
            [ -n "$id" ] || continue
            k archive "$id" >/dev/null 2>&1 && echo "  Karte $id archiviert" || true
        done
        rm -f "$IDS"
    fi
    if [ -d "$REPO/.git" ]; then
        pfad="$(git -C "$REPO" worktree list --porcelain | grep -B2 "branch refs/heads/$BRANCH" | sed -n 's/^worktree //p' | head -1)"
        [ -n "$pfad" ] && git -C "$REPO" worktree remove --force "$pfad" 2>/dev/null && echo "  Worktree $pfad entfernt"
        git -C "$REPO" branch -D "$BRANCH" 2>/dev/null && echo "  Branch $BRANCH entfernt" || true
    fi
    rm -f "$VAULT/specs/probelauf.html"
    echo "  fertig"
    exit 0
fi

# ---------------------------------------------------------------------------
if [ "${1:-}" = "--pruefen" ]; then
    say "Nachweis Phase 0"
    [ -f "$IDS" ] || { echo "Kein Probelauf angelegt. Erst ./probelauf.sh"; exit 1; }
    # shellcheck disable=SC1090
    . "$IDS"
    fehler=0
    ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
    nein() { printf '  \033[31m✗\033[0m %s\n' "$*"; fehler=1; }

    liste="$(k list --json)"
    zustand() { printf '%s' "$liste" | jq -r --arg i "$1" '.[] | select(.id==$i) | .status'; }

    echo
    echo "Kette Spezifikation → Bau → Review → Riegel"
    for paar in "PROBE_SPEC:$PROBE_SPEC:Spezifikation" "PROBE_BAU:$PROBE_BAU:Bau" "PROBE_REVIEW:$PROBE_REVIEW:Review"; do
        name="${paar%%:*}"; rest="${paar#*:}"; id="${rest%%:*}"; label="${rest#*:}"
        st="$(zustand "$id")"
        if [ "$st" = "done" ]; then ok "$label (Karte $id) ist done"
        else nein "$label (Karte $id) steht auf '${st:-nicht gefunden}'"; fi
    done

    echo
    echo "Das Probe-Gate hält"
    gst="$(zustand "$PROBE_GATE")"
    if [ "$gst" = "blocked" ]; then
        grund="$(k show "$PROBE_GATE" --json | jq -r '[.events[] | select(.kind=="blocked")] | last | .payload.reason // ""')"
        zeilen="$(printf '%s' "$grund" | grep -c . || true)"
        ok "Karte $PROBE_GATE ist blocked, Vorlage hat $zeilen Zeilen"

        # DER Nachweis: Der Dispatcher startet nichts, solange das Gate steht.
        trocken="$(k dispatch --dry-run 2>&1 || true)"
        printf '%s\n' "$trocken" | sed 's/^/      /'
        if printf '%s' "$trocken" | grep -qiE 'spawn(ed)?:? *0'; then
            ok "dispatch --dry-run: Spawned 0 — das Gate hält"
        else
            nein "dispatch --dry-run meldet nicht 'Spawned: 0'"
        fi
    elif [ "$gst" = "done" ]; then
        ok "Karte $PROBE_GATE wurde beantwortet und ausgeführt (Gate hat vorher gehalten)"
    elif [ "$gst" = "triage" ]; then
        nein "Karte $PROBE_GATE ist in der TRIAGE — sie fragt niemanden mehr"
    else
        nein "Karte $PROBE_GATE steht auf '${gst:-nicht gefunden}' statt blocked"
    fi

    echo
    echo "Der Riegel"
    if git -C "$REPO" rev-parse --verify --quiet "$BRANCH" >/dev/null; then
        ok "Branch $BRANCH existiert"
        if [ -f "$VAULT/reports/riegel-probelauf.txt" ]; then
            ergebnis="$(tail -3 "$VAULT/reports/riegel-probelauf.txt" | tr '\n' ' ')"
            ok "Riegel-Protokoll liegt vor: $ergebnis"
        else
            nein "kein Riegel-Protokoll unter reports/riegel-probelauf.txt"
        fi
    else
        nein "Branch $BRANCH existiert nicht — der Bau hat nichts hinterlassen"
    fi

    printf '\n'
    if [ "$fehler" -eq 0 ]; then
        printf '\033[32m✓ Phase 0 nachgewiesen.\033[0m  Weiter: ./create-onboarding.sh\n'
        exit 0
    fi
    printf '\033[31m✗ Der Nachweis ist noch nicht vollständig.\033[0m\n'
    exit 1
fi

# ---------------------------------------------------------------------------
say "Die Probe-Kette anlegen"
# ---------------------------------------------------------------------------

SPEC=$(k create "Probelauf 1/4 — Spezifikation" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --idempotency-key "probelauf-spec" \
    --max-retries 2 --max-runtime 15m \
    --body "Das hier ist ein Mechanik-Test der Organisation, kein echtes Feature.
Halte dich trotzdem exakt an deine Rolle — geprüft wird, ob die Übergabe trägt.

AUFGABE
Schreibe die Spezifikation für eine winzige, risikofreie Änderung am Produkt:

  Das Produkt-Repo bekommt eine Datei docs/ESF-PROBELAUF.md mit genau drei
  Zeilen: einer Überschrift, dem heutigen Datum, und dem Satz
  'Diese Datei belegt, dass die ESF-Kette Spezifikation → Bau → Review →
  Riegel durchgelaufen ist.'

SCHREIBE nach specs/probelauf.html, Format nach AGENTS.md 2.2 — mit
<meta name=\"esf-typ\" content=\"spec\"> und deiner Karten-ID in esf-karte.

metadata.acceptance ist Pflicht und enthält mindestens:
  · 'docs/ESF-PROBELAUF.md existiert und hat drei Zeilen'
  · 'Die vorhandene E2E-Suite läuft weiterhin grün' (das ist das E2E-Kriterium
    dieser Karte — eine Doku-Datei bekommt keine eigene Journey)

Schliesse sofort danach mit kanban_complete ab." \
    --json | jq -r .id)
echo "  PROBE_SPEC   = $SPEC"

BAU=$(k create "Probelauf 2/4 — Bau" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH" \
    --parent "$SPEC" \
    --idempotency-key "probelauf-bau" \
    --max-retries 2 --max-runtime 25m \
    --body "Setze die Spezifikation deiner Elternkarte um. Sie steht in deinem
Kontext unter '## Parent task results'; die Datei liegt im Vault unter
specs/probelauf.html, aber der Handoff sollte reichen.

Du arbeitest in einem GIT-WORKTREE, der schon existiert und schon auf dem
richtigen Branch steht. Lege keinen zweiten an, wechsle den Branch nicht.

TUN
1. docs/ESF-PROBELAUF.md anlegen, genau wie spezifiziert.
2. Committen — Nachricht sagt, was und warum.
3. NICHT mergen, main nicht anfassen.

Diese Karte ist der Grund, warum es die Regel 'bei fehlendem Material
blockieren statt raten' gibt: Wenn die Spezifikation dir nicht sagt, was in
die Datei soll, dann blockiere mit kanban_block(kind=\"needs_input\") — und
erfinde den Inhalt nicht.

metadata: changed_files, der Commit-Hash, und was du bewusst nicht getan hast." \
    --json | jq -r .id)
echo "  PROBE_BAU    = $BAU"

# ⚠ Der Reviewer bekommt KEINEN eigenen Worktree auf demselben Branch.
# Git lässt einen Branch nur in genau einem Worktree auschecken; ein zweites
# `git worktree add` auf feat/… scheitert mit "already used by worktree at …",
# der Circuit Breaker gibt nach zwei Versuchen auf, und die Karte steht
# blockiert da — real passiert, siehe VERIFIKATION.md.
#
# Er arbeitet deshalb im HAUPTBAUM (dir:) und sieht von dort aus in die
# fremden Bäume unter .worktrees/. Das ist nicht nur die Reparatur, sondern
# auch die einzige Bauform, die ein Fan-in-Review über MEHRERE Feature-Branches
# eines Sprints überhaupt zulässt — ein einzelner Worktree könnte immer nur
# einen davon zeigen.
REVIEW=$(k create "Probelauf 3/4 — Review" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$BAU" \
    --idempotency-key "probelauf-review" \
    --max-retries 2 --max-runtime 25m \
    --body "Prüfe den Branch $BRANCH.

Du arbeitest im Hauptbaum des Repos. Der Baum des Entwicklers liegt daneben:
'git worktree list' zeigt dir, wo. Du darfst dort lesen und Tests ausführen,
aber nichts ändern.

Geprüft wird hier auch, ob DU im fremden Baum wirklich arbeitest statt die
Zusammenfassung des Entwicklers zu übernehmen. Also:

1. Sieh dir den Diff an:  git diff main...$BRANCH
2. Lies die Datei, die dabei entstanden ist.
3. Geh die Akzeptanzkriterien der Spezifikation Punkt für Punkt durch, mit
   Beleg je Punkt.

Urteil maschinenlesbar in metadata:
  verdict: approved | rejected
  findings: [ {severity, file, what, why} ]
  acceptance: [ {criterion, status, evidence} ]

Du merged nicht. Der Riegel merged." \
    --json | jq -r .id)
echo "  PROBE_REVIEW = $REVIEW"

GATE=$(k create "GATE Roadmap — Probelauf 4/4" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$REVIEW" \
    --idempotency-key "probelauf-gate" \
    --max-retries 2 --max-runtime 20m \
    --body "Diese Karte ist das Probe-Gate. Ihr Zweck ist NICHT, eine echte
Entscheidung herbeizuführen, sondern zu beweisen, dass ein Gate den
Dispatcher wirklich anhält.

TUN — in dieser Reihenfolge, beim ERSTEN Lauf:

1. Lies das Review-Urteil deiner Elternkarte.
2. Führe den Merge-Riegel aus, im Trockenlauf, und hebe das Protokoll auf:

     scripts/merge-riegel.sh $BRANCH --dry-run --protokoll \\
       \"$VAULT/reports/riegel-probelauf.txt\"

   Der Riegel entscheidet, nicht du. Verweigert er, ist das ein gültiges
   Ergebnis — schreib es in die Vorlage.

3. Blockiere dich danach SELBST mit einer Entscheidungsvorlage von acht Zeilen:

     kanban_block(kind=\"needs_input\", reason=\"…\")

   Die acht Zeilen, jede eine:
     · Was steht an
     · Beleg (Review-Urteil, Riegel-Ergebnis)
     · Was entsteht, wenn zugestimmt wird
     · Was es kostet (Schätzintervall, hier: trivial)
     · Empfehlung
     · Wie geantwortet wird: ./gate.sh approve <id> | modify <id> \"…\" | shelve <id> \"…\"
     · Wo die Details liegen (Datei-Pfade)
     · Ab wann es eilt

   Maßstab: Man kann entscheiden, ohne eine Datei zu öffnen.

Beim ZWEITEN Lauf — nachdem der Mensch geantwortet hat — liest du seine
Antwort im Kommentar-Thread und führst sie aus. Bei 'approve' heisst das:
den Riegel ohne --dry-run laufen lassen. Dann kanban_complete.

Du rufst NIEMALS kanban_unblock auf. Kein einziges Mal. Das ist die Grenze
zwischen der Organisation und dem Menschen, und sie ist der Grund, warum diese
Probe existiert." \
    --json | jq -r .id)
echo "  PROBE_GATE   = $GATE"

cat > "$IDS" <<EOF
# Von probelauf.sh erzeugt — $(date '+%Y-%m-%d %H:%M')
BOARD='$BOARD'
VAULT='$VAULT'
REPO='$REPO'
BRANCH='$BRANCH'
PROBE_SPEC='$SPEC'
PROBE_BAU='$BAU'
PROBE_REVIEW='$REVIEW'
PROBE_GATE='$GATE'
EOF

say "Board"
k list

cat <<EOF

IDs liegen in task-ids-probe.env:   source task-ids-probe.env

Weiter:
  ./pump.sh                    takten und zusehen
  ./gate.sh                    wenn das Gate steht
  ./probelauf.sh --pruefen     den Nachweis abnehmen
  ./probelauf.sh --aufraeumen  danach zurückbauen
EOF
