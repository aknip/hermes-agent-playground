#!/usr/bin/env bash
#
# ESF — Phase 2: Die Sprint-Graphen von Release 1
# ==============================================
#
#   ./create-sprint.sh 1     S1 — R1-F5 (technische Härtung)
#   ./create-sprint.sh 2     S2 — R1-F1 ∥ R1-F2 (Suche · 2FA)
#
# Zwei Aufrufe, nicht einer — und das ist keine Bequemlichkeit, sondern eine
# Auflage. `roadmap/q1-freigegeben.html` § "Auflage für den Sprint-Zuschnitt":
#
#     Nach dem ERSTEN vollständig abgeschlossenen Feature lässt der
#     esf-controller die Kalibrierung laufen und der esf-estimator schätzt die
#     restlichen R1-Features neu, BEVOR sie starten.
#
# Ein Skript, das beide Sprints vorab auslegt, verletzt genau das. `2` prüft
# deshalb selbst, ob `Kalibrierung S1` fertig ist, und verweigert sonst.
#
# Der Graph je Feature (Kapitel 6: Spezifikation → Schätzung → n Bau-Karten
# → Review (Fan-in) → Merge), Deckel 8 Karten je Feature aus cadence.yaml:
#
#   1/n Spezifikation   dir:VAULT        schreibt specs/<slug>.html
#   2/n Schätzung       dir:VAULT        schreibt das Intervall je Folgekarte
#   3/n Umsetzung       worktree:REPO    ein eigener Branch, TDD, E2E-Journey
#   4/n Review          dir:REPO         Hauptbaum, sieht in .worktrees/ hinein
#   5/n Merge           dir:REPO         merge-riegel.sh — kein Modell merged
#
# Die Abschluss-Karten (`Kalibrierung S<n>`, `Sprint-Abschluss S<n>`) liegen
# ABSICHTLICH ausserhalb des `S<n> `-Namensraums: Die Sprint-Erkennung in
# monitor.sh zählt alle Karten mit diesem Präfix, und ein Sprint, dessen
# Abschluss-Karte mitzählt, kann nie voll werden, ohne schon abgeschlossen zu
# sein.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
VAULT="$HERE/workspace/company"
HEUTE="$(date '+%Y-%m-%d')"

SPRINT="${1:-}"
case "$SPRINT" in
    1|2) ;;
    *) echo "Aufruf: ./create-sprint.sh 1 | 2"; exit 2 ;;
esac
S="S$SPRINT"
IDS="$HERE/task-ids-$(echo "$S" | tr 'A-Z' 'a-z').env"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }
[ -f "$VAULT/roadmap/q1-freigegeben.html" ] || {
    echo "FEHLER: Es gibt keine freigegebene Roadmap unter roadmap/q1-freigegeben.html."
    echo "        Ohne CEO-Freigabe wären diese Karten Arbeit auf Verdacht."
    echo "        Abhilfe: ./restore-phase1.sh"
    exit 1
}

# cadence.yaml lesen — mit abgeschnittenem Zeilenkommentar. Ohne das trägt
# `karten_pro_feature: 8   # Deckel für den Planungsgraphen je Feature` den
# ganzen Kommentar als Wert, und der landet mitten im Kartentext eines Workers.
# Die Werte, die e2e_befehl heissen, enthalten selbst kein '#'.
cad() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$VAULT/cadence.yaml" \
        | head -1 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//'; }

REPO="$(cad repo)"
PRODUKT="$(cad name)"
PRAEFIX="$(cad branch_praefix)"
E2E_DIR="$(cad e2e_verzeichnis)"
E2E_BEFEHL="$(cad e2e_befehl)"
E2E_VORBED="$(cad e2e_vorbedingung)"
KARTEN_DECKEL="$(cad karten_pro_feature)"

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Bausteine, die in jedem Kartentext gleich lauten
# ---------------------------------------------------------------------------
# Sie stehen hier einmal, weil eine abweichende Formulierung je Karte genau die
# Sorte Drift ist, die im ersten Lauf den Kartentext gegen die SOUL gewinnen
# liess (RUN-PROTOKOLL.md, "Und dann kippte die Gate-Karte nach triage").

# $1 = Referenzklasse
metadata_pflicht() {
cat <<EOF
DEIN ABSCHLUSS-metadata — ohne das fällst du aus der Kalibrierung
Deine Referenzklasse für diese Karte ist festgelegt und lautet:

    $1

Du erfindest sie nicht und du änderst sie nicht. Sie steht hier, damit die
Zuordnung vom Skript kommt und nicht vom Modell.

kanban_complete(metadata={ ... "estimate": {"reference_class": "$1", ...} ... })

Trägst du im Handoff-Kontext deiner Elternkarte ein Schätz-Intervall des
esf-estimator für DIESE Karte, dann kopiere das vollständige estimate-Objekt
WÖRTLICH — dieselben Zahlen, dasselbe confidence, dasselbe estimated_by. Nicht
neu schätzen, nicht runden, nicht "verbessern".

Warum das penibel ist: ledger-sync.sh liest Schätzung und Istwert aus dem
metadata DERSELBEN Karte. Die Schätzung entsteht aber auf einer anderen. Wer
sie nicht mitnimmt, hinterlässt einen Istwert ohne Paar — und scripts/check-sprint.sh
schlägt darauf fehl, weil ein Sprint ohne (Schätzung, Ist)-Paare der einzige
Nachweis ist, den Phase 2 nicht erbringen darf zu verlieren.
EOF
}

# Für jede Karte, die im Worktree baut. Ohne diesen Absatz hat ein Entwickler
# am 17.08.2026 rund 80 Minuten in Umgebungs-Archäologie gesteckt — und dabei
# die `.env` des HAUPTBAUMS neu geschrieben. Ein Worker, der aus seinem Worktree
# in den Hauptbaum schreibt, hebt die Isolation auf, auf der die ganze parallele
# Arbeit beruht.
env_hinweis() {
cat <<EOF
DIE .env IST NICHT IM GIT — und dein Worktree hat deshalb keine
\`.env\` steht in .gitignore. Ein frischer Worktree bekommt sie also nicht, und
ohne sie startet die Anwendung nicht (DATABASE_URL, POSTGRES_PASSWORD,
AUTH_SECRET). Der Weg ist EINE Zeile, und nur diese:

    ln -sf "$REPO/.env" "\$(git rev-parse --show-toplevel)/.env"

Was du dabei NICHT tust, und das ist die eigentliche Regel:
· Du schreibst NIE in $REPO — nicht in dessen .env, nicht in dessen
  Arbeitsbaum, nicht in dessen Git. Der Hauptbaum gehört dem Reviewer und dem
  Riegel. Real passiert und deshalb hier: ein Worker hat die .env des
  Hauptbaums neu geschrieben, während er seine eigene suchte.
· Du erzeugst keine Geheimnisse neu. Ein neues AUTH_SECRET macht bestehende
  Sitzungen ungültig, und ein neues POSTGRES_PASSWORD trennt die Anwendung von
  dem Container, der schon läuft.
· Findest du die Datei nicht: abschliessen mit dem Befund im metadata. Eine
  fehlende Umgebung ist ein Aufbau-Mangel, kein Rätsel für dich.
EOF
}

gate_verbot() {
cat <<'EOF'
DIE GRENZE
Du rufst NIEMALS kanban_unblock auf — nicht auf dieser Karte, nicht auf einer
anderen, aus keinem Grund (AGENTS.md 7). monitor.sh meldet jede Verletzung.

Blockiere dich höchstens EINMAL. Hermes zählt zwei Blockaden derselben Art auf
derselben Karte als Schleife (BLOCK_RECURRENCE_LIMIT = 2, je kind) und schiebt
die Karte still nach 'triage', wo sie niemanden mehr fragt. Real passiert, siehe
RUN-PROTOKOLL.md. Musst du ein zweites Mal fragen: abschliessen mit dem Befund
im metadata und eine NEUE Karte für die Folgefrage. Eine Entscheidung, eine Karte.
EOF
}

vault_format() {
cat <<EOF
VAULT-FORMAT (AGENTS.md 2.2) — der Linter weist alles andere ab:

  <!doctype html>
  <html lang="de">
  <head>
    <meta charset="utf-8">
    <title>… — ESF</title>
    <meta name="esf-typ" content="$1">
    <meta name="esf-karte" content="<deine Karten-ID>">
    <meta name="esf-datum" content="$HEUTE">
  </head>

Jede Behauptung nennt ihren Beleg (AGENTS.md 3.1): Code zitiert datei.ts:zeile,
eine Zahl nennt ihre Messung. Zeitstempel kommen vom System, nie aus deinem
Gefühl für das Datum (AGENTS.md 3.2).
EOF
}

echo "Sprint:   $S"
echo "Produkt:  $PRODUKT  ($REPO, $(git -C "$REPO" rev-parse --short HEAD))"
echo "Vault:    $VAULT"
echo "Deckel:   $KARTEN_DECKEL Karten je Feature"

# ---------------------------------------------------------------------------
# Die Auflage des CEO als Vorbedingung von S2
# ---------------------------------------------------------------------------
if [ "$SPRINT" = "2" ]; then
    kal="$(k list --json 2>/dev/null | jq -r '[.[] | select(.title=="Kalibrierung S1")] | last // null')"
    if [ "$kal" = "null" ]; then
        cat <<'EOF'

VERWEIGERT — es gibt keine Karte "Kalibrierung S1".

Die freigegebene Roadmap bindet die Reihenfolge (§ Auflage für den
Sprint-Zuschnitt): R1-F1 und R1-F2 dürfen nicht spezifiziert oder geschätzt
werden, bevor die Kalibrierung aus dem ersten abgeschlossenen Feature gelaufen
ist. Der Sinn eines leeren Ledgers ist, ihn zu füllen, nicht ihn zu überspringen.

  ./create-sprint.sh 1
EOF
        exit 1
    fi
    kstatus="$(printf '%s' "$kal" | jq -r '.status')"
    if [ "$kstatus" != "done" ]; then
        printf '\nVERWEIGERT — "Kalibrierung S1" steht auf '"'"'%s'"'"', nicht auf '"'"'done'"'"'.\n' "$kstatus"
        echo "Die CEO-Auflage verlangt die Kalibrierung VOR dem Start der restlichen"
        echo "R1-Features. Erst takten, dann diesen Aufruf wiederholen."
        exit 1
    fi
    printf '\n\033[32m✓\033[0m Auflage erfüllt: Kalibrierung S1 ist fertig (%s)\n' \
        "$(printf '%s' "$kal" | jq -r '.id')"
fi

# ===========================================================================
if [ "$SPRINT" = "1" ]; then
# ===========================================================================
SLUG="r1-f5-api-modularisierung"
BRANCH="${PRAEFIX}esf-$SLUG"

say "S1 1/5  Konzept & ADR — R1-F5 technische Härtung"
# Der Architekt und nicht der Product Manager: R1-F5 hat keine Nutzeraufgabe,
# sondern eine Strukturentscheidung, und die gehört nach AGENTS.md 4 in ein ADR.
SPEC=$(k create "$S F5 1/5 — Konzept & ADR: apps/api/src/index.ts zerlegen" \
    --assignee esf-architect \
    --workspace "dir:$VAULT" \
    --idempotency-key "s1-f5-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Feature R1-F5 der freigegebenen Roadmap: technische Härtung, Position 1
des Release auf CEO-Anweisung.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, R1-F5)
Der höchste Kollisions-Hotspot ist apps/api/src/index.ts (968 Zeilen). Er wird
zerlegt, BEVOR mehrere Feature-Branches daran arbeiten. Beleg:
analysis/codebase.html §5.1, §5.2, §6.1. Die Organisation hat am 17.08.2026
dreimal bewiesen, dass parallele Git-Arbeit ihr häufigster Ausfallgrund ist.
Nutzersichtbar ändert sich NICHTS — das ist eine Voraussetzung, kein Feature.

DEINE ARBEIT — zwei Dokumente im Vault, kein Code
Du liest im Repo ($REPO) und änderst dort nichts.

1. decisions/ADR-001-api-modularisierung.html — fünf Pflichtabschnitte
   (AGENTS.md 4): Kontext, Optionen (mindestens zwei, jede mit Konsequenz),
   Entscheidung, Konsequenzen, Revision. Die verworfene Option mit Begründung
   ist der Teil, der in einem Jahr Wert hat.

   Die Optionen, die du wirklich abwägen musst, sind: Zerlegung nach Domäne
   (Route-Gruppen in eigene Module), Zerlegung nach Schicht (Router/Handler/
   Middleware), und — als ernstzunehmende Nullvariante — die Datei so lassen und
   nur die Kollisionsfläche durch Reihenfolge der Karten entschärfen. Die
   Nullvariante ist keine Alibi-Option: eine Umstrukturierung ohne
   Verhaltensänderung ist reines Risiko, wenn sie zu gross wird.

2. specs/r1-f5-haertung.html — die ausführbare Spezifikation. Sie muss
   beantworten:
   · Welche Datei entsteht wo, mit welchem Inhalt? Benenne die Zielstruktur
     konkret (Pfade), nicht als Prinzip.
   · Was darf sich NICHT ändern? Öffentliche Routen, Pfade, Statuscodes,
     Verhalten. Das ist der wichtigste Abschnitt: Der Wert dieser Karte liegt
     darin, dass hinterher alles genau so funktioniert wie vorher.
   · Die Akzeptanzkriterien, prüfbar formuliert, jedes einzeln abhakbar.
     Mindestens: Typecheck grün, Unit-Tests grün (374/374 auf dem
     Ausgangsstand), volle E2E-Suite grün, keine Änderung an öffentlichen
     Routen.

   E2E: kein neuer Spec. Die Absicherung ist der volle Regressionslauf über
   J-00..J-06 (8 Tests, analysis/journeys.html). Schreib das ausdrücklich hin,
   damit der Entwickler nicht meint, er müsse einen erfinden.

DER ZUSCHNITT IST TEIL DEINER ARBEIT
Der Deckel liegt bei $KARTEN_DECKEL Karten je Feature; dieses Feature hat fünf
und davon genau EINE Bau-Karte. Also muss die Zerlegung in eine Bau-Karte
passen. Passt sie nicht: schneide sie kleiner (ein erster Schnitt, der trägt,
statt einer vollständigen Neuordnung) und schreib in das ADR unter Revision,
was du bewusst für später liegen lässt. Ein Konzept, das die eigene Kadenz
sprengt, ist kein ehrgeiziges Konzept, sondern ein ungeprüftes.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance (die Kriterien als Liste — der Entwickler und der
Reviewer arbeiten beide gegen genau diese Liste), und die Zielstruktur als Liste
der Dateien, die entstehen sollen.

$(vault_format 'adr')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  SPEC = $SPEC"

say "S1 2/5  Schätzung"
EST=$(k create "$S F5 2/5 — Schätzung R1-F5" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$SPEC" \
    --idempotency-key "s1-f5-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schätze die drei Folgekarten von R1-F5. Die Spezifikation deiner
Elternkarte (specs/r1-f5-haertung.html, ADR-001) steht in deinem Handoff-Kontext.

DAS LEDGER IST DEINE EINZIGE QUELLE — und es ist erstmals nicht leer
ledger/estimates.jsonl trägt die nachgebuchten Ist-Zeiten des Phase-0/1-Laufs:
gemessene Wanduhrminuten aus Board-Zeitstempeln, klassifiziert, mit
'estimate: null' und '\"backfill\": true'. Lies die Datei, bevor du rechnest.

Was du dort findest und was das wert ist:
  · Die Klassen sind mit n=1 bis n=3 besetzt. Das ist wenig. Sag es hin.
  · Es sind ISTWERTE ohne Schätzung. Es gibt also noch keine Velocity-
    Verteilung (Ist/Schätzung) — die entsteht erst mit DIESER Schätzung und
    ihrer Messung. Behaupte keine, die du nicht hast.
  · Deine Aufgabe ist trotzdem eine Zahl, nicht ein Achselzucken. Ein breites
    Intervall mit niedriger Konfidenz und benannter Grundlage ist die
    geforderte Antwort (Kapitel 8: 'Klassen ohne Historie starten mit breiten
    Intervallen und niedriger Konfidenz, und sagen das dem CEO'). Ein 'kann ich
    nicht' wäre hier falsch: der Backfill IST die Historie.

SCHÄTZE DIESE DREI KARTEN, jede einzeln, jede mit ihrer Klasse:

  Karte                    Referenzklasse       nächste Nachbarn im Ledger
  ---------------------------------------------------------------------------
  $S F5 3/5 Umsetzung      impl-worktree-M      impl-worktree-S
  $S F5 4/5 Review         review-repo-M        review-repo-S
  $S F5 5/5 Merge          merge-repo-S         — keine, Riegel-Lauf

Die Größenordnung von S nach M leitest du aus der Spezifikation ab (Umfang der
Zielstruktur, Zahl der berührten Dateien), nicht aus einem Gefühl. Schreib den
Schritt hin: 'S hat n=1 mit 21 min; dieses Feature berührt N Dateien gegen 1 in
der Referenz, daher …'. Wer den Schritt hinschreibt, kann später zeigen, wo er
falsch war — das ist der ganze Zweck von Evidence-Based Scheduling.

Für merge-repo-S gibt es keinen Nachbarn. Dort ist die ehrliche Grundlage der
Riegel selbst: sechs Prüfungen, deren längste die volle E2E-Suite ist
(gemessen 24,7 s für 8 Tests, RUN-PROTOKOLL.md) plus 374 Unit-Tests (unter Last
gemessen 52,9 s allein für den Import). Rechne daraus, nenn die Rechnung.

tokens_k und cost_usd: 'null'. Hermes v0.20.0 misst keine Tokens, und der
OpenRouter-Zähler läuft je Rolle kumulativ — je Karte gibt es keine Zahl. Ein
hineingeschriebener Wert wäre die vergiftete Kalibrierung aus AGENTS.md 6.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-r1-f5.html (esf-typ 'report'): die drei Intervalle, die
   Referenzklassen, die Ledger-Zeilen, auf die du dich stützt (task_id nennen!),
   die Konfidenz je Schätzung und in einem Satz, warum sie so niedrig ist.
2. Ins Abschluss-metadata dieser Karte ein Objekt 'estimates' mit den drei
   Schätzungen, je Karte eines, nach dem festen Schema deiner SOUL — sowie
   zusätzlich unter 'estimate' die Schätzung DIESER Karte selbst
   (reference_class 'estimate-vault-S').

   Das metadata ist der Weg, auf dem die Zahlen bei den Folgekarten ankommen:
   sie lesen es in ihrem Handoff-Kontext. Schreib es maschinenlesbar, mit
   genau den Kartentiteln oben als Schlüssel.

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  EST  = $EST"

say "S1 3/5  Umsetzung  (eigener Worktree, eigener Branch)"
IMPL=$(k create "$S F5 3/5 — Umsetzung R1-F5" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH" \
    --parent "$EST" \
    --idempotency-key "s1-f5-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze R1-F5 um: apps/api/src/index.ts nach specs/r1-f5-haertung.html
zerlegen.

DEIN BAUM
Du arbeitest in deinem eigenen Worktree auf Branch '$BRANCH'. Kein anderer
Worker fasst diesen Branch an. Du mergst NICHT — das tut der Riegel auf einer
eigenen Karte, und kein Modell merged (Kapitel 6).

$(env_hinweis)

Die Spezifikation, das ADR und die Akzeptanzkriterien stehen in deinem
Handoff-Kontext; die Dateien liegen im Vault unter
$VAULT/specs/r1-f5-haertung.html und decisions/ADR-001-api-modularisierung.html.

DIE EINZIGE HARTE REGEL DIESER KARTE
Verhalten unverändert. Das ist eine Umstrukturierung, kein Feature. Jede
Änderung an einer öffentlichen Route, einem Pfad, einem Statuscode oder einer
Antwortform ist ein Fehler, auch wenn sie eine Verbesserung wäre. Fällt dir
unterwegs eine echte Verbesserung auf: NICHT machen, sondern ins
Abschluss-metadata unter 'gefunden_nicht_gemacht' schreiben. Daraus wird eine
eigene Karte.

REIHENFOLGE
1. Erst messen, dann schneiden. Notiere den Ausgangsstand mit Zahlen:
     cd \$(git rev-parse --show-toplevel)
     pnpm typecheck && pnpm test
   Wieviele Tests, wie lange? Diese Zahl ist dein Vergleichsmaßstab, und du
   brauchst sie am Ende noch.
2. Umbauen, in kleinen Schritten, nach der Zielstruktur der Spezifikation.
   Nach jedem Schritt typecheck. Ein grosser Sprung, der am Ende rot ist, kostet
   mehr als vier kleine.
3. $E2E_VORBED
   $E2E_BEFEHL
   Die volle Suite muss grün sein — sie ist der eigentliche Nachweis, dass das
   Verhalten steht. 8 Tests waren es auf dem Ausgangsstand.
4. Commit auf deinen Branch, Conventional Commits in Kleinschreibung
   (z.B. 'refactor(api): routen aus index.ts in module ausgelagert').
   Der Pre-Commit-Hook lintet nur DEINE gestageten Dateien — er wird halten,
   wenn deine Zeilen sauber sind. Umgehe ihn nicht. Wenn er meckert, sind es
   deine Zeilen.

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber grün. Ein halber Schnitt, der grün ist und die
Kollisionsfläche schon senkt, ist ein Ergebnis; ein vollständiger Umbau mit
roten Tests ist keins. Was du weggelassen hast, gehört ins metadata unter
'deliberately_not_done' mit Grund — und zwar deinem eigenen Grund, nachgeprüft.
Im ersten Lauf hat ein Worker eine falsche Behauptung aus dem Kartentext in sein
metadata übernommen, wo sie wie ein Befund aussah (RUN-PROTOKOLL.md). Prüf, was
du abschreibst.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: die Liste der angelegten und geänderten Dateien, das
Testergebnis vor und nach dem Umbau (Zahlen!), das E2E-Ergebnis, der
Commit-Hash, und je Akzeptanzkriterium ein Häkchen mit dem Beleg, an dem du es
geprüft hast.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  IMPL = $IMPL"

say "S1 4/5  Review  (Hauptbaum, sieht in den fremden Worktree)"
REV=$(k create "$S F5 4/5 — Review R1-F5" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$IMPL" \
    --idempotency-key "s1-f5-review" \
    --max-retries 2 --max-runtime 60m \
    --body "Prüfe die Umsetzung von R1-F5 auf Branch '$BRANCH'.

DEIN ORT
Du arbeitest im HAUPTBAUM ($REPO), nicht in einem Worktree. Von hier siehst du
in die fremden Bäume unter .worktrees/ hinein. Der Branch ist bereits von einem
Worktree beansprucht — ein 'git checkout $BRANCH' im Hauptbaum scheitert hart
('fatal: … is already used by worktree'). Nimm 'git log/diff/show $BRANCH' und
lies im fremden Baum, ohne ihn anzufassen. Genau dieser Fehler hat im ersten
Lauf eine Karte in den Circuit Breaker gefahren (RUN-PROTOKOLL.md).

WAS DU PRÜFST — in dieser Reihenfolge, weil die erste Frage die teuerste ist
1. Ist das Verhalten unverändert? Das ist der Zweck des Features und die
   einzige Frage, deren falsche Antwort Nutzer trifft. Vergleiche die
   öffentlichen Routen vor und nach dem Umbau — konkret, nicht dem Eindruck
   nach: 'git diff main..$BRANCH' und dann die Route-Definitionen gegeneinander.
2. Ist jedes Akzeptanzkriterium der Spezifikation erfüllt? Geh die Liste aus dem
   Handoff-Kontext einzeln durch und schreib je Kriterium hin, WORAN du es
   geprüft hast. 'Sieht erfüllt aus' ist keine Prüfung.
3. Führe die Tests SELBST aus, im Baum des Entwicklers. Nicht sein Protokoll
   lesen — laufen lassen:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm typecheck && pnpm test
     $E2E_VORBED
     $E2E_BEFEHL
   Der Unterschied zwischen Behauptung und geprüfter Tatsache ist dein ganzer
   Daseinsgrund. Im ersten Lauf hat dieses Vorgehen den Unterschied gemacht.
4. Ist main unberührt? 'git log main..' und der Arbeitsbaum-Status.
5. Ist der Umbau tatsächlich eine Entlastung des Hotspots, oder nur eine
   Umschichtung? Zähl die Zeilen: apps/api/src/index.ts vorher 968 —
   wieviele jetzt, und wohin sind sie gegangen?

WENN ETWAS FEHLT
Dein Urteil ist 'approved' oder 'changes_requested', im metadata unter
'verdict', mit den Befunden als Liste. Bei 'changes_requested' beschreibt jeder
Befund, WAS zu tun ist, nicht dass etwas nicht stimmt. Du reparierst nichts
selbst — dann wäre niemand mehr da, der prüft.

Ein bekannter Störfaktor, damit du ihn nicht als Befund missdeutest:
mcp-internal-api-url.test.ts ist lastempfindlich. Fällt genau dieser Test und
sonst nichts, lauf ihn allein nach; grün allein und rot unter Last ist ein
Betriebsbefund, kein Fehler des Entwicklers. Notier ihn als solchen.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, die Befunde, das selbst gemessene Testergebnis
(Zahlen), die Zeilenzahl-Bilanz aus Punkt 5.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  REV  = $REV"

say "S1 5/5  Merge am Riegel"
MERGE=$(k create "$S F5 5/5 — Merge R1-F5 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$REV" \
    --idempotency-key "s1-f5-merge" \
    --max-retries 2 --max-runtime 60m \
    --body "Bringe R1-F5 nach main — über den Riegel, nicht mit der Hand.

DER EINZIGE ERLAUBTE WEG
    $HERE/scripts/merge-riegel.sh $BRANCH --protokoll $VAULT/reports/riegel-r1-f5.txt

Du rufst kein 'git merge'. Der Riegel merged oder verweigert; das ist der
Unterschied zwischen einer Regel und einem Riegel (Kapitel 6). Sechs Prüfungen:
Erreichbarkeit, Konfliktfreiheit, Linter auf den geänderten Dateien, Typecheck,
Unit-Tests, volle E2E-Suite.

VORBEDINGUNGEN, die du selbst herstellst — sonst verweigert er ohne Sachgrund
1. Das Urteil des Reviewers muss 'approved' sein. Steht 'changes_requested' in
   deinem Handoff-Kontext: NICHT mergen. Schliesse ab mit dem Befund im
   metadata und lege eine neue Karte für die Nacharbeit an.
2. Der Arbeitsbaum von $REPO muss sauber sein. Im ersten Lauf verweigerte der
   Riegel, weil dort uncommittete Fremdänderungen lagen — eine Verweigerung
   ohne Sachbezug. 'git status --short' zuerst; ist er schmutzig und nicht deine
   Schuld, notier das und melde es, statt aufzuräumen.
3. Postgres muss laufen: $E2E_VORBED

WENN ER VERWEIGERT
Der Riegel hat immer einen Grund und er schreibt ihn ins Protokoll. Zwei Sorten,
und die Unterscheidung ist dein Urteil:
 · Sachgrund (Konflikt, roter Test, Linter auf neuen Zeilen) → nicht mergen,
   abschliessen, neue Karte für die Nacharbeit, Befund ins metadata.
 · Betriebsgrund (schmutziger Baum, lastempfindlicher Test — bekannt:
   mcp-internal-api-url.test.ts, gemessen 52,9 s Import unter vier Workern
   gegen 7,3 s allein) → Ursache benennen, EINMAL sauber nachlaufen lassen,
   und wenn er dann besteht, mergen. Verweigert er erneut, ist es ein Sachgrund.

Was du NICHT tust: den Riegel überstimmen. Ein Riegel, den man überstimmt, ist
keiner. Und du benutzt kein --no-verify.

DANACH
· Das Riegel-Protokoll bleibt als Rohbeleg liegen (reports/riegel-r1-f5.txt,
  .txt und nicht .html — AGENTS.md 2.1 nimmt Maschinenprotokolle aus der
  HTML-Pflicht aus; ein Rohbeleg, den jemand für die Darstellung angefasst hat,
  ist keiner mehr).
· Ist gemerged: den Worktree des Entwicklers NICHT aufräumen. Er ist Beleg.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: das Riegel-Ergebnis (bestanden/verweigert), welche der sechs
Prüfungen wie ausging, der Merge-Commit auf main, die Testzahlen aus dem
Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  MERGE= $MERGE"

LETZTE="$MERGE"
FEATURES="R1-F5"

# ===========================================================================
else   # SPRINT 2
# ===========================================================================
SLUG_F1="r1-f1-globale-suche"
SLUG_F2="r1-f2-zwei-faktor"
BRANCH_F1="${PRAEFIX}esf-$SLUG_F1"
BRANCH_F2="${PRAEFIX}esf-$SLUG_F2"

# --- Feature R1-F1 · Globaler Sucheinstieg ---------------------------------
say "S2 F1 1/4  Spezifikation — R1-F1 globaler Sucheinstieg"
F1_SPEC=$(k create "$S F1 1/4 — Spezifikation R1-F1 globaler Sucheinstieg" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --idempotency-key "s2-f1-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere R1-F1 der freigegebenen Roadmap: den sichtbaren globalen
Sucheinstieg.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, R1-F1, H1, Score 22,5)
Nutzeraufgabe K9 — 'eine bestimmte Aufgabe in einem von mehreren Projekten
finden' — ist heute tastaturgebunden (Kommando-Palette, eigene Such-Route). Das
ist der grösste Bruch mit dem eigenen Versprechen 'find tasks across projects'
(analysis/product.html §5, K9). Ziel: ein SICHTBARER Griff.

DIE VORHANDENE SUBSTANZ ZUERST — das ist die Hälfte der Arbeit
Lies analysis/codebase.html und dann im Repo ($REPO) nach, was es schon gibt:
Kommando-Palette, Such-Route, Such-Endpunkt im API. Deine Spezifikation baut
darauf auf, statt daneben. Ein zweiter Suchpfad neben dem bestehenden wäre genau
die Flächenvergrösserung, gegen die Kaneos Versprechen baut
(roadmap § 'Was wir NICHT machen').

Zitiere jede Aussage über den Bestand mit datei.ts:zeile. Wenn du eine Datei
nicht gefunden hast, schreib das hin statt zu vermuten.

WAS DIE SPEZIFIKATION LEISTEN MUSS
 · Welche Nutzeraufgabe wird um welche Schritte kürzer? Nenn die Schrittzahl
   vorher und die Zielzahl. Die Schrittzahl ist die UX-Metrik der Organisation
   (Kapitel 6), und dieses Feature wird an ihr gemessen.
 · Der sichtbare Griff: wo genau in der Oberfläche, mit welcher Beschriftung,
   welchem Verhalten bei Klick, welchem Tastaturkürzel (das bestehende bleibt).
 · Was das Feature NICHT tut. Kein Filter-Baukasten, keine gespeicherten
   Suchen, keine Volltext-Indizierung — es sei denn, du belegst, dass es ohne
   nicht geht.
 · Akzeptanzkriterien, einzeln abhakbar, jedes von aussen sichtbar prüfbar.
 · Die E2E-Journey J-07 'Aufgabe über die Suche wiederfinden'. Sie ist im
   Katalog bewusst offen (analysis/journeys.html) und wird mit diesem Feature
   geschrieben. Beschreib die Schritte, die der Spec nachspielen soll — der
   Entwickler schreibt ihn, du legst fest, was er beweisen muss.

DER ZUSCHNITT IST TEIL DEINER ARBEIT
Eine Bau-Karte, ein Entwickler, $KARTEN_DECKEL Karten Deckel je Feature. Was in
eine Bau-Karte passt, ist die Spezifikation; der Rest ist ein Vorschlag für
später und steht unter 'nicht in diesem Feature'. Ein zu grosser Schnitt fällt
nicht auf, bis er am Riegel rot ist.

Achtung Parallelität: R1-F2 (2FA) wird GLEICHZEITIG von esf-dev-b gebaut. Halte
dich von Auth-Dateien fern und benenne im Abschnitt 'Berührungspunkte', welche
Dateien du erwartest — der Reviewer braucht das.

SCHREIBE nach specs/r1-f1-suche.html.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance (die Kriterien als Liste), die erwarteten
Berührungspunkte im Code, Schrittzahl vorher/Ziel.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F1_SPEC = $F1_SPEC"

say "S2 F1 2/4  Schätzung — R1-F1"
F1_EST=$(k create "$S F1 2/4 — Schätzung R1-F1" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$F1_SPEC" \
    --idempotency-key "s2-f1-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schätze die zwei Folgekarten von R1-F1 und die Merge-Karte.
Die Spezifikation steht in deinem Handoff-Kontext.

DAS LEDGER TRÄGT JETZT ECHTE PAARE — das ist der Unterschied zu S1
ledger/estimates.jsonl enthält nach S1 erstmals (Schätzung, Ist)-Paare, nicht
nur nachgebuchte Istwerte. Lies auch reports/controller-s1.html: dort steht die
Schätzgüte-Baseline, also der Faktor Ist/Schätzung je Klasse aus S1.

Das ist die CEO-Auflage aus roadmap/q1-freigegeben.html in Aktion: 'Nach dem
ERSTEN vollständig abgeschlossenen Feature … schätzt der esf-estimator die
restlichen R1-Features neu, bevor sie starten.' Du bist diese Neuschätzung.

DESHALB GILT HIER EINE ZUSÄTZLICHE PFLICHT
Nenn je Klasse den Faktor aus S1 und wende ihn an. Hat S1 die Klasse
impl-worktree-M um Faktor 1,8 unterschätzt, dann steht in deiner Schätzung, dass
du 1,8 angewendet hast — und nicht ein glatteres Ergebnis, das besser aussieht.
Deine SOUL sagt es: eine Schätzung, die nach unten angepasst wird, um zu
gefallen, ist der Plan, der sich selbst belügt.

Die Konfidenz darf jetzt steigen — aber nur soweit die Datenmenge es hergibt.
Eine Klasse mit zwei Paaren bleibt unter 0.4, auch wenn die beiden gut trafen.
Schreib die Zahl hin, aus der du die Konfidenz ableitest (n).

SCHÄTZE:
  Karte                    Referenzklasse       Grundlage
  ---------------------------------------------------------------------------
  $S F1 3/4 Umsetzung      impl-worktree-M      S1-Paar + Backfill
  $S F1 4/4 Review         review-repo-M        S1-Paar + Backfill
  $S Merge F1              merge-repo-S         S1-Paar

tokens_k und cost_usd bleiben 'null' — je Karte gibt es keine Zahl, der
OpenRouter-Zähler läuft je Rolle kumulativ. Was du STATTDESSEN liefern kannst
und sollst: ein Wort dazu, was S1 laut ledger/kosten-je-rolle.jsonl an
Rollenkosten verursacht hat, falls die Datei Zahlen trägt.

SCHREIBE reports/schaetzung-r1-f1.html und die Schätzungen ins
Abschluss-metadata unter 'estimates', je Folgekarte eine, mit dem Kartentitel
als Schlüssel.

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F1_EST  = $F1_EST"

say "S2 F1 3/4  Umsetzung — R1-F1  (esf-dev-a)"
F1_IMPL=$(k create "$S F1 3/4 — Umsetzung R1-F1 globaler Sucheinstieg" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH_F1" \
    --parent "$F1_EST" \
    --idempotency-key "s2-f1-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze R1-F1 um: den sichtbaren globalen Sucheinstieg nach
specs/r1-f1-suche.html.

DEIN BAUM
Eigener Worktree, Branch '$BRANCH_F1'. Du mergst NICHT.

$(env_hinweis)

PARALLELBETRIEB — lies das, bevor du eine Datei anfasst
esf-dev-b baut GLEICHZEITIG R1-F2 (2FA) in einem anderen Worktree. Zwei
Feature-Branches, ein main. Deshalb:
 · Bleib in den Dateien, die deine Spezifikation unter 'Berührungspunkte'
   nennt. Brauchst du eine darüber hinaus, schreib sie ins metadata unter
   'zusaetzlich_beruehrt' — der Reviewer und der Riegel brauchen das, weil ein
   Merge-Konflikt zwischen euch beiden hier entsteht und nicht im Code.
 · Fass keine Auth-Dateien an. Die gehören dem anderen Feature.
 · Rebase nicht auf main und merge nicht von main. Dein Branch startet, wo er
   startet.

DIE ARBEIT
1. Lies erst, was es schon gibt — die Spezifikation nennt die Fundstellen. Baue
   auf dem bestehenden Suchpfad auf, leg keinen zweiten daneben.
2. TDD, wie dein Skill es verlangt: erst der fallende Test, dann der Code.
   Bei einem UI-Feature ist der E2E-Spec dieser Test.
3. Die E2E-Journey J-07 ist Pflicht, nicht Zugabe (Kapitel 6: 'ein Feature ohne
   grüne E2E-Journey merged nicht'). Schreib
   $E2E_DIR/aufgabe-ueber-suche-finden.spec.ts nach dem Vorbild der vorhandenen
   Specs — nummerierte Schritt-Kommentare, sichtbare Nutzerschritte, keine
   Implementierungsdetails.

   Zwei Fallen, die dort schon dokumentiert sind:
   · Das Passwort-Label zeigt per 'for' auf den Wrapper-<div>. Nimm
     input[name=\"password\"], nicht getByLabel('Password').
   · Ein frisches Konto landet auf /onboarding. Erst nach 'Arbeitsbereich
     anlegen' geht es weiter. tests/e2e/support/journey.ts hat die Helfer.
4. Volle Suite grün:
     $E2E_VORBED
     $E2E_BEFEHL
   Vorher waren es 8 Tests. Mit J-07 sind es mehr — nenn die Zahl.
5. Commit auf deinen Branch, Conventional Commits in Kleinschreibung. Der
   Pre-Commit-Hook lintet deine gestageten Dateien. Umgehe ihn nicht.

WENN DU NICHT DURCHKOMMST
Weniger, aber grün. 'deliberately_not_done' mit Grund ins metadata. Prüf jede
Behauptung, die du aus dem Kartentext übernimmst — im ersten Lauf ist eine
falsche Prämisse aus einem Kartentext ins Abschluss-metadata gewandert und sah
dort wie ein Befund aus.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: geänderte und angelegte Dateien, 'zusaetzlich_beruehrt',
Testergebnis vor/nach mit Zahlen, die neue Schrittzahl der Journey J-07, der
Commit-Hash, je Akzeptanzkriterium ein Häkchen mit Beleg.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F1_IMPL = $F1_IMPL"

say "S2 F1 4/4  Review — R1-F1"
F1_REV=$(k create "$S F1 4/4 — Review R1-F1" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$F1_IMPL" \
    --idempotency-key "s2-f1-review" \
    --max-retries 2 --max-runtime 60m \
    --body "Prüfe R1-F1 auf Branch '$BRANCH_F1'.

DEIN ORT
Hauptbaum ($REPO). Kein 'git checkout $BRANCH_F1' — der Branch ist von einem
Worktree beansprucht, das scheitert hart. 'git log/diff/show' und Lesen im
fremden Baum unter .worktrees/.

WAS DU PRÜFST
1. Jedes Akzeptanzkriterium der Spezifikation einzeln, mit der Fundstelle,
   AN DER du es geprüft hast. 'Sieht erfüllt aus' ist keine Prüfung.
2. Ist der Griff wirklich sichtbar? Das ist der Kern des Features: eine Suche,
   die man nur mit der Tastatur erreicht, hat das Problem nicht gelöst. Prüf
   das an der Komponente, nicht an der Beschreibung.
3. Ist ein ZWEITER Suchpfad entstanden, wo einer hätte genügt? Das wäre die
   Flächenvergrösserung, die die Roadmap ausdrücklich ausschliesst. Nenn die
   Dateien.
4. Führe die Tests SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm typecheck && pnpm test
     $E2E_VORBED
     $E2E_BEFEHL
   Und lies den neuen Spec J-07: Spielt er die Nutzeraufgabe nach oder prüft er
   die Implementierung? Ein Spec, der Selektoren prüft statt Aufgaben, ist ein
   Befund.
5. Berührt das Feature Dateien, die R1-F2 (2FA, esf-dev-b, Branch
   '$BRANCH_F2') auch anfasst? Das ist der wahrscheinlichste Weg, auf dem der
   Merge nachher scheitert. Vergleiche
     git diff --name-only main..$BRANCH_F1
     git diff --name-only main..$BRANCH_F2
   und melde die Schnittmenge — auch wenn sie leer ist, dann als geprüft.
6. Ist main unberührt?

Störfaktor, nicht Befund: mcp-internal-api-url.test.ts ist lastempfindlich.
Fällt genau dieser und sonst nichts, allein nachlaufen lassen.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict ('approved' | 'changes_requested'), Befunde als
Liste, selbst gemessene Testzahlen, die Schnittmenge aus Punkt 5.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F1_REV  = $F1_REV"

# --- Feature R1-F2 · 2FA ---------------------------------------------------
say "S2 F2 1/4  Spezifikation — R1-F2 Zwei-Faktor-Authentifizierung"
F2_SPEC=$(k create "$S F2 1/4 — Spezifikation R1-F2 Zwei-Faktor-Authentifizierung" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --idempotency-key "s2-f2-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere R1-F2 der freigegebenen Roadmap: Zwei-Faktor-
Authentifizierung.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, R1-F2, H4, Score 17,0)
Security ist im Selbst-Hosting-Segment Einlasskarte, kein USP: Kanboard liefert
fast nur Härtung, Vikunja 'Ten security fixes', Plane drei GHSA-Fixes, Huly 2FA
(analysis/market.html H4). Der selbsthostende Administrator sichert den Zugang.
Risikohinweis aus der Roadmap: Auth ist sicherheitskritisch, ein Fehl-Update
sperrt Nutzer aus — Review-Pflicht (analysis/codebase.html §6.3).

DER ZUSCHNITT IST HIER DIE WICHTIGSTE ENTSCHEIDUNG, NICHT EINE NEBENFRAGE
'2FA' ist ein Wort für sehr unterschiedlich grosse Vorhaben. Was in EINE
Bau-Karte passt, ist die Spezifikation; alles andere ist ein Vorschlag für
später. Der Deckel ist $KARTEN_DECKEL Karten je Feature und dieses Feature hat
eine einzige Bau-Karte.

Nimm deshalb ausdrücklich Stellung zu diesen Schnitten, jeweils mit Begründung
am Bestand (analysis/codebase.html und die Auth-Dateien im Repo, zitiert mit
datei.ts:zeile):
 · TOTP (Authenticator-App) — die kleinste Fläche, kein Mailversand, kein SMS.
 · Opt-in je Nutzer gegen erzwungen für alle — erzwungen ist ein Breaking
   Change gegenüber Bestandsnutzern und damit gate-pflichtig (Kapitel 7). Für
   dieses Release: opt-in.
 · Wiederherstellungs-Codes — was passiert, wenn das Gerät weg ist? Ohne
   Antwort darauf ist 2FA ein Aussperr-Mechanismus. Wenn du sie in diesem
   Schnitt nicht unterbringst, MUSS die Spezifikation sagen, wie ein
   ausgesperrter Administrator wieder hereinkommt (z.B. ein Skript-Pfad) —
   und dass das eine bewusste Einschränkung ist.
 · Welche Auth-Wege es überhaupt gibt (lokal, OAuth-Anbieter?) und für welche
   das Feature gilt.

Kommst du zu dem Schluss, dass ein tragfähiger 2FA-Schnitt NICHT in eine
Bau-Karte passt, dann ist das ein Ergebnis und keine Niederlage: Schreib die
Spezifikation für den kleinsten tragfähigen Schnitt, benenne im metadata unter
'zu_gross_fuer_eine_karte' was du herausgeschnitten hast, und begründe es. Ein
überdehnter Schnitt fällt erst am Riegel auf, und dann teuer.

WAS DIE SPEZIFIKATION LEISTEN MUSS
 · Der Ablauf aus Nutzersicht: Einrichten, Anmelden mit zweitem Faktor,
   Abschalten. Je Schritt, was sichtbar passiert.
 · Datenhaltung: welches Feld, welche Tabelle, verschlüsselt oder nicht,
   Migration ja/nein. Eine Migration ist irreversibel gegenüber
   Bestandsinstallationen — steht sie in deinem Schnitt, sag es ausdrücklich.
 · Was das Feature NICHT tut.
 · Akzeptanzkriterien, einzeln abhakbar, von aussen prüfbar. Mindestens eines
   muss den Aussperr-Fall abdecken.
 · Die E2E-Journey: eine neue Journey (Auth-Härtung), die J-01 (Konto anlegen)
   erweitert. Beschreib die Schritte. TOTP im Test heisst: der Spec muss den
   Code selbst berechnen können — nenn die Bibliothek, mit der das geht, oder
   schreib hin, dass das zu klären ist.

Achtung Parallelität: R1-F1 (Suche) wird GLEICHZEITIG von esf-dev-a gebaut.
Benenne im Abschnitt 'Berührungspunkte' die Dateien, die du erwartest.

SCHREIBE nach specs/r1-f2-zwei-faktor.html.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance, die erwarteten Berührungspunkte,
'zu_gross_fuer_eine_karte' falls zutreffend, und ob eine Datenmigration
enthalten ist (das entscheidet, ob später ein Irreversibel-Gate nötig wird).

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F2_SPEC = $F2_SPEC"

say "S2 F2 2/4  Schätzung — R1-F2"
F2_EST=$(k create "$S F2 2/4 — Schätzung R1-F2" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$F2_SPEC" \
    --idempotency-key "s2-f2-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schätze die zwei Folgekarten von R1-F2 und die Merge-Karte.
Die Spezifikation steht in deinem Handoff-Kontext.

GRUNDLAGE
ledger/estimates.jsonl (jetzt mit echten Paaren aus S1) und
reports/controller-s1.html (die Schätzgüte-Baseline). Du bist Teil der
CEO-Auflage: Neuschätzung der restlichen R1-Features nach der ersten
Kalibrierung.

SCHÄTZE:
  Karte                    Referenzklasse       Grundlage
  ---------------------------------------------------------------------------
  $S F2 3/4 Umsetzung      impl-worktree-M      S1-Paar + Backfill
  $S F2 4/4 Review         review-repo-M        S1-Paar + Backfill
  $S Merge F2              merge-repo-S         S1-Paar

EINE BESONDERHEIT, die du nicht glattbügeln darfst
R1-F2 ist Auth: sicherheitskritisch, mit Datenhaltung und möglicherweise einer
Migration. Die Klasse impl-worktree-M deckt das nicht sauber ab — die S1-Karte
in dieser Klasse war eine Umstrukturierung ohne Verhaltensänderung. Zwei
ehrliche Möglichkeiten, und du entscheidest sichtbar:
 · Neue Klasse 'impl-worktree-auth-M' aufmachen, ohne Historie, mit breitem
   Intervall — deine SOUL sagt: 'A new class is a decision you write down.'
 · Bei impl-worktree-M bleiben und einen Aufschlag begründen, mit der Zahl.
Was du nicht tust: die Klasse benutzen, als passte sie, und den Unterschied
nicht erwähnen.

Nenn ausserdem, ob die Spezifikation ein 'zu_gross_fuer_eine_karte' meldet.
Wenn ja, ist das die wichtigste Zeile deiner Schätzung: eine p90, die über dem
--max-runtime der Bau-Karte (120 min) liegt, sagt voraus, dass die Karte
abgebrochen wird. Schreib das hin, statt es zu unterschätzen. Genau dafür bist
du eine eigene Rolle.

tokens_k und cost_usd bleiben 'null'.

SCHREIBE reports/schaetzung-r1-f2.html und die Schätzungen ins
Abschluss-metadata unter 'estimates', mit dem Kartentitel als Schlüssel.

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F2_EST  = $F2_EST"

say "S2 F2 3/4  Umsetzung — R1-F2  (esf-dev-b)"
F2_IMPL=$(k create "$S F2 3/4 — Umsetzung R1-F2 Zwei-Faktor-Authentifizierung" \
    --assignee esf-dev-b \
    --workspace "worktree:$REPO" --branch "$BRANCH_F2" \
    --parent "$F2_EST" \
    --idempotency-key "s2-f2-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze R1-F2 um: Zwei-Faktor-Authentifizierung nach
specs/r1-f2-zwei-faktor.html.

DEIN BAUM
Eigener Worktree, Branch '$BRANCH_F2'. Du mergst NICHT.

$(env_hinweis)

PARALLELBETRIEB
esf-dev-a baut GLEICHZEITIG R1-F1 (globale Suche) in einem anderen Worktree.
Bleib in den Auth-Dateien deiner Spezifikation. Kein Rebase, kein Merge von
main. Zusätzlich berührte Dateien ins metadata unter 'zusaetzlich_beruehrt'.

DIE HÄRTESTE ANFORDERUNG DIESER KARTE
Niemand darf sich aussperren können. 2FA, die eine Anmeldung unmöglich macht,
ist schlimmer als keine 2FA. Der Aussperr-Fall aus der Spezifikation ist ein
Akzeptanzkriterium wie jedes andere, und er wird getestet.

DIE ARBEIT
1. Lies erst den bestehenden Auth-Pfad. Die Spezifikation nennt die
   Fundstellen; prüf sie nach, statt sie zu glauben.
2. TDD: erst der fallende Test. Bei Auth heisst das Unit-Tests für die
   TOTP-Prüfung UND den E2E-Spec — die Verifikationslogik ist genau die Sorte
   Code, die man nicht durch Ausprobieren im Browser absichert.
3. Die neue E2E-Journey ist Pflicht: $E2E_DIR/<slug>.spec.ts, nach dem Vorbild
   der vorhandenen Specs, nummerierte Schritt-Kommentare.
   Die dokumentierten Fallen: Passwort-Label zeigt auf den Wrapper-<div> (nimm
   input[name=\"password\"]); ein frisches Konto landet auf /onboarding.
   tests/e2e/support/journey.ts hat die Helfer.
   Für TOTP im Test brauchst du den Code deterministisch — nimm dieselbe
   Bibliothek wie die Implementierung, statt Zeit zu simulieren.
4. Migration, falls deine Spezifikation eine enthält: das Schema-Werkzeug des
   Repos benutzen, nicht von Hand am SQL schrauben. Und die Migration muss auf
   einer bestehenden Datenbank laufen, nicht nur auf einer frischen — prüf das.
5. Volle Suite grün:
     $E2E_VORBED
     $E2E_BEFEHL
6. Commit auf deinen Branch, Conventional Commits in Kleinschreibung. Der
   Pre-Commit-Hook lintet deine gestageten Dateien. Umgehe ihn nicht.

WENN DU NICHT DURCHKOMMST
Das ist bei diesem Feature die wahrscheinlichste Lage, und der richtige Umgang
damit ist nicht Mut, sondern Buchführung. Liefere den kleineren, grünen
Ausschnitt. Was fehlt, kommt ins metadata unter 'deliberately_not_done' mit
Grund. Ein halb eingebautes Auth-Feature, das rot ist, ist schlechter als
gar keins — der Riegel lässt es ohnehin nicht durch, und dann hat die Karte
Geld gekostet, ohne etwas zu hinterlassen.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: geänderte und angelegte Dateien, 'zusaetzlich_beruehrt',
Testergebnis vor/nach mit Zahlen, ob eine Migration enthalten ist, wie der
Aussperr-Fall gelöst ist, der Commit-Hash, je Akzeptanzkriterium ein Häkchen
mit Beleg.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F2_IMPL = $F2_IMPL"

say "S2 F2 4/4  Review — R1-F2"
F2_REV=$(k create "$S F2 4/4 — Review R1-F2" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$F2_IMPL" \
    --idempotency-key "s2-f2-review" \
    --max-retries 2 --max-runtime 60m \
    --body "Prüfe R1-F2 auf Branch '$BRANCH_F2'. Das ist das sicherheitskritische
Feature des Release — die Roadmap schreibt für dieses Feature ausdrücklich
Review-Pflicht fest (analysis/codebase.html §6.3).

DEIN ORT
Hauptbaum ($REPO). Kein 'git checkout $BRANCH_F2'. Lesen im fremden Baum unter
.worktrees/.

WAS DU PRÜFST — Punkt 1 ist der, für den du hier stehst
1. KANN SICH JEMAND AUSSPERREN? Geh den Weg durch: 2FA eingerichtet, Gerät
   verloren. Was jetzt? Prüf, ob der in der Spezifikation vorgesehene Ausweg
   im Code wirklich existiert und funktioniert — nicht ob er beschrieben ist.
   Wenn er nicht existiert, ist das 'changes_requested', unabhängig davon, wie
   gut der Rest ist.
2. Ist die TOTP-Prüfung korrekt und nicht umgehbar? Konkret: Wird der zweite
   Faktor auf JEDEM Anmeldeweg geprüft, oder gibt es einen Pfad daneben
   (API-Token, OAuth, Passwort-Reset)? Nenn die Pfade, die du geprüft hast, mit
   Fundstelle. Ein zweiter Faktor mit einer Hintertür ist keiner.
3. Wird das Geheimnis sicher gehalten? Nicht im Klartext geloggt, nicht in einer
   Antwort zurückgegeben, nicht im Frontend-Zustand liegengeblieben.
4. Enthält die Änderung eine Datenmigration? Wenn ja: Läuft sie auf einer
   BESTEHENDEN Datenbank? Und ist sie rücknehmbar? Eine irreversible Migration
   ist nach Kapitel 7 gate-pflichtig — dann ist dein Befund nicht 'Fehler',
   sondern 'braucht ein Irreversibel-Gate', und das gehört ins metadata.
5. Jedes Akzeptanzkriterium einzeln, mit der Fundstelle, an der du es geprüft
   hast.
6. Führe die Tests SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm typecheck && pnpm test
     $E2E_VORBED
     $E2E_BEFEHL
7. Schnittmenge mit R1-F1 (Branch '$BRANCH_F1'):
     git diff --name-only main..$BRANCH_F1
     git diff --name-only main..$BRANCH_F2
   Melde sie — auch die leere, dann als geprüft. Dein Merge ist der zweite von
   zwei; was hier kollidiert, kollidiert nachher am Riegel.
8. Ist main unberührt?

Störfaktor, nicht Befund: mcp-internal-api-url.test.ts ist lastempfindlich.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, Befunde als Liste, die geprüften Anmeldewege aus
Punkt 2, Aussperr-Fall ja/nein, Migration ja/nein und ob sie ein
Irreversibel-Gate braucht, selbst gemessene Testzahlen, Schnittmenge.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F2_REV  = $F2_REV"

# --- Die zwei Merges, serialisiert ----------------------------------------
say "S2  Merge F1 am Riegel"
F1_MERGE=$(k create "$S Merge F1 — R1-F1 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$F1_REV" \
    --idempotency-key "s2-merge-f1" \
    --max-retries 2 --max-runtime 60m \
    --body "Bringe R1-F1 nach main — über den Riegel.

    $HERE/scripts/merge-riegel.sh $BRANCH_F1 --protokoll $VAULT/reports/riegel-r1-f1.txt

Du bist der ERSTE von zwei Merges dieses Sprints. Danach merged eine zweite
Karte R1-F2; sie hängt an dir, damit die beiden Riegel-Läufe sich nicht
gegenseitig unter Last setzen.

VORBEDINGUNGEN
1. Reviewer-Urteil 'approved'. Bei 'changes_requested': NICHT mergen,
   abschliessen, neue Karte für die Nacharbeit.
2. Arbeitsbaum von $REPO sauber ('git status --short').
3. Postgres läuft: $E2E_VORBED

WENN ER VERWEIGERT
 · Sachgrund (Konflikt, roter Test, Linter auf neuen Zeilen) → nicht mergen,
   abschliessen, neue Karte, Befund ins metadata.
 · Betriebsgrund (schmutziger Baum; mcp-internal-api-url.test.ts ist
   lastempfindlich, gemessen 52,9 s Import unter vier Workern gegen 7,3 s
   allein) → Ursache benennen, EINMAL sauber nachlaufen lassen, bei Bestehen
   mergen. Verweigert er erneut, ist es ein Sachgrund.

Du überstimmst den Riegel nicht und du benutzt kein --no-verify. Kein Modell
merged (Kapitel 6). Den Worktree des Entwicklers nicht aufräumen — er ist Beleg.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, welche der sechs Prüfungen wie ausging,
Merge-Commit auf main, Testzahlen aus dem Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F1_MERGE= $F1_MERGE"

say "S2  Merge F2 am Riegel  (hängt an Merge F1 — bewusst serialisiert)"
F2_MERGE=$(k create "$S Merge F2 — R1-F2 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$F2_REV" --parent "$F1_MERGE" \
    --idempotency-key "s2-merge-f2" \
    --max-retries 2 --max-runtime 60m \
    --body "Bringe R1-F2 nach main — über den Riegel. Du bist der ZWEITE Merge
dieses Sprints; R1-F1 liegt bereits auf main.

    $HERE/scripts/merge-riegel.sh $BRANCH_F2 --protokoll $VAULT/reports/riegel-r1-f2.txt

WARUM DU AN ZWEI ELTERN HÄNGST
An deiner Review-Karte, weil du ihr Urteil brauchst. Und an 'Merge F1', weil
zwei gleichzeitige Riegel-Läufe sich unter Last setzen und eine Verweigerung
ohne Sachgrund produzieren. Der Riegel fährt 374 Unit-Tests und die volle
E2E-Suite; das verträgt keinen Parallelbetrieb.

DAS BESONDERE AN DEINEM MERGE
Dein Branch startete von einem main OHNE R1-F1. Inzwischen liegt R1-F1 dort.
Der Riegel prüft Konfliktfreiheit im Trockenlauf — wenn er einen Konflikt
meldet, ist das der erwartete Fall und kein Betriebsproblem:
 · Konflikt in Dateien, die beide Features berühren → Sachgrund. NICHT selbst
   auflösen: du bist der Riegel-Wart, nicht der Entwickler. Abschliessen, den
   Konflikt genau benennen (Dateien, Zeilen), neue Karte für esf-dev-b.
 · Kein Konflikt → weiter wie üblich.

Die Schnittmenge der berührten Dateien hat dir der Reviewer ins metadata
geschrieben. Lies sie zuerst; sie sagt dir, was zu erwarten ist.

VORBEDINGUNGEN
1. Reviewer-Urteil 'approved'. Und: Meldet das Review 'braucht ein
   Irreversibel-Gate' (Datenmigration), dann mergst du NICHT. Schliesse ab mit
   diesem Befund im metadata und lege eine Gate-Karte
   'GATE Irreversibel — R1-F2 Migration' an, die sich selbst blockiert. Eine
   irreversible Änderung gegenüber Bestandsinstallationen ist nach Kapitel 7
   immer gate-pflichtig, auch mitten im Release.
2. Arbeitsbaum sauber. 3. Postgres läuft: $E2E_VORBED

WENN ER VERWEIGERT: dieselbe Unterscheidung Sachgrund/Betriebsgrund wie oben.
Du überstimmst ihn nicht, du benutzt kein --no-verify.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, die sechs Prüfungen, Merge-Commit,
Testzahlen, und ob ein Konflikt mit R1-F1 auftrat.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  F2_MERGE= $F2_MERGE"

LETZTE="$F2_MERGE"
FEATURES="R1-F1 und R1-F2"
fi

# ===========================================================================
# Die zwei Abschluss-Karten — ausserhalb des `S<n> `-Namensraums
# ===========================================================================
say "Kalibrierung $S  (esf-controller)"
KAL=$(k create "Kalibrierung $S" \
    --assignee esf-controller \
    --workspace "dir:$VAULT" \
    --parent "$LETZTE" \
    --idempotency-key "kalibrierung-$S" \
    --max-retries 2 --max-runtime 45m \
    --body "Sprint $S ist inhaltlich fertig ($FEATURES). Miss, was er gekostet
hat, und vergleiche es mit dem, was geschätzt wurde.

SCHRITT 1 — das Ledger füllen, mit einem Skript, nicht mit der Hand
    $HERE/scripts/ledger-sync.sh

Es liest die Wanduhrzeiten aus den Board-Läufen und die Rollenkosten aus der
OpenRouter-API und hängt je fertige Karte eine Zeile an
ledger/estimates.jsonl. Danach prüfst du das Ergebnis, statt es zu glauben:

    $HERE/scripts/check-sprint.sh $S

Der Check entscheidet, ob der Sprint messbar ist — nicht du.

FÜR DICH ZÄHLT PRÜFUNG 3: '(Schätzung, Ist)-Paare'. Sie ist der Riegel dieses
Sprints. Sie schlägt genau dann fehl, wenn eine Umsetzungs-, Review- oder
Merge-Karte einen Istwert ohne bezifferte Schätzung trägt — dann ist das Paar
zerrissen und die Kalibrierung steht auf Sand. Ist sie rot, ist das dein
wichtigstes Ergebnis und gehört in den Report: welche Karte, woran es lag. Nicht
ein grünes Bild über einer Lücke.

Prüfung 6 (Berichte im Vault) KANN bei deinem ersten Aufruf nicht grün sein —
reports/controller-$(echo "$S" | tr 'A-Z' 'a-z').html schreibst du ja erst, und
den Sprint-Report schreibt danach der esf-chief-of-staff. Das ist kein Befund,
sondern die Reihenfolge. Lauf den Check nach deinem Report gern ein zweites Mal.

SCHRITT 2 — der Controller-Report: reports/controller-$(echo "$S" | tr 'A-Z' 'a-z').html

Er beginnt mit dem, was in drei Minuten reicht (AGENTS.md 5), und enthält:

 · DIE SCHÄTZGÜTE-BASELINE. Das ist der Kern und der Phase-2-Nachweis. Je
   Referenzklasse eine Zeile: Schätzung p50/p90, Ist, Quotient Ist/Schätzung.
   Wird eine Klasse systematisch unterschätzt, nenn den FAKTOR. Diese Zahl ist
   das, was den nächsten Plan glaubwürdig macht (Kapitel 8).
 · Wanduhrminuten je Karte, aus 'hermes kanban runs'. Board-Zeitstempel sind
   verlässlich, Modelltext nicht.
 · Kosten je Rolle aus ledger/kosten-je-rolle.jsonl, falls die Datei Zahlen
   trägt. Je KARTE gibt es keine — der Zähler läuft kumulativ je Key, also je
   Rolle, und eine Division wäre eine Erfindung mit dem Anschein einer Messung.
   Steht dort nichts: 'nicht gemessen'.
 · DIE KONTAMINATIONEN, benannt: Gate-Wartezeit (Gates sind eigene Karten,
   damit sie nicht hineinleckt — prüf, ob das gehalten hat) und
   Rechner-Standby ('standby_overlap' im Ledger; solche Läufe fliegen aus der
   Kalibrierung, sichtbar). Ein unkontaminierter Durchschnitt kontaminierter
   Daten ist die selbstsicherste Form von falsch.
 · Retries und Abbrüche: welche Karte lief wie oft? Eine Karte mit drei Läufen
   hat andere Kosten als ihre Wanduhrzeit vermuten lässt.
 · Die E2E-Schrittzahl je Journey aus analysis/journeys.html — die
   Bedienbarkeits-Kennzahl der Organisation. Ist sie gewachsen?
 · Was die nächste Schätzung anders machen muss. Ein Satz, konkret.

SCHRITT 3 — den Vault committen.

WAS DU NICHT TUST
Keine Zahl ohne Quelle. Wo die Messung fehlt, steht 'nicht gemessen' und nicht
ein Wert in Zahlen-Kleidung. Und wo das metadata einer Karte dem Board
widerspricht, gewinnt das Board und du notierst den Widerspruch (AGENTS.md 3.3:
Widersprüche stehen nebeneinander, sie werden nicht geglättet).

$(metadata_pflicht 'controller-vault-M')
Dazu ins metadata: je Referenzklasse der Quotient Ist/Schätzung, die Zahl der
Paare im Ledger, das Ergebnis von check-sprint.sh, und die Rollenkosten-Summe
falls gemessen.

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  KAL  = $KAL"

say "Sprint-Abschluss $S  (esf-chief-of-staff)"
# Titel und Idempotenzschlüssel sind exakt die, die monitor.sh selbst benutzt.
# Damit fällt die Doppelanlage durch die Abschluss-Erkennung auf den Schlüssel,
# und es gibt keine zweite Karte für dieselbe Sache.
ABSCHLUSS=$(k create "Sprint-Abschluss $S" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$KAL" \
    --idempotency-key "sprint-abschluss-$S" \
    --max-retries 2 --max-runtime 45m \
    --body "Schliesse Sprint $S ab ($FEATURES).

SCHRITT 1 — der Check entscheidet, nicht du
    $HERE/scripts/check-sprint.sh $S

Übernimm sein Ergebnis wörtlich in den Report, auch wenn es rot ist. Ein
Sprint-Report, der grüner aussieht als der Check, ist der teuerste Fehler
dieser Rolle: Er kostet niemanden heute etwas und vergiftet jede Planung
danach.

SCHRITT 2 — reports/sprint-$(echo "$S" | tr 'A-Z' 'a-z')-report.html

Er beginnt mit dem, was in drei Minuten reicht (AGENTS.md 5): was sich geändert
hat, was es gekostet hat, was eine Entscheidung braucht. Dann:

 · DIE TABELLE DER (SCHÄTZUNG, IST)-PAARE. Je Karte eine Zeile: Karte,
   Referenzklasse, Schätzung p50/p90, Ist, Quotient. Das ist der
   Phase-2-Nachweis aus Kapitel 12 und der Grund, warum dieser Report
   existiert. Die Zahlen holst du aus ledger/estimates.jsonl und aus
   reports/controller-$(echo "$S" | tr 'A-Z' 'a-z').html — nicht aus deiner
   Erinnerung an den Sprint.
 · Was geliefert wurde, mit Commit-Hash auf main.
 · Was NICHT geliefert wurde und warum: das 'deliberately_not_done' und
   'gefunden_nicht_gemacht' aus den Abschluss-metadata der Karten. Diese Liste
   ist wertvoller als die Erfolgsliste, weil daraus die nächsten Karten werden.
 · Die Befunde des Reviewers und wie sie ausgingen.
 · Betriebsbefunde: Hänger, Retries, Riegel-Verweigerungen und ihre Ursache.
 · Was für den nächsten Sprint folgt — konkret, nicht als Vorsatz.

SCHRITT 3 — den Vault committen.

WAS DU NICHT TUST
Du legst KEINE Karten für den nächsten Sprint an. Die freigegebene Roadmap
bindet die Reihenfolge (§ Auflage für den Sprint-Zuschnitt): Die restlichen
R1-Features werden erst nach der Kalibrierung neu geschätzt, und den Graphen
legt './create-sprint.sh' an, das diese Auflage selbst prüft. Karten auf
Verdacht sind Arbeit auf Verdacht.

$(metadata_pflicht 'plan-vault-M')
Dazu ins metadata: das Ergebnis von check-sprint.sh, die Zahl der
(Schätzung, Ist)-Paare im Report, die gelieferten Commits, und die offene
Liste für den nächsten Sprint.

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  ABSCHLUSS = $ABSCHLUSS"

# ---------------------------------------------------------------------------
{
    echo "# Von create-sprint.sh $SPRINT erzeugt — $(date '+%Y-%m-%d %H:%M')"
    echo "BOARD='$BOARD'"
    echo "VAULT='$VAULT'"
    echo "REPO='$REPO'"
    if [ "$SPRINT" = "1" ]; then
        echo "S1_SPEC='$SPEC'"
        echo "S1_EST='$EST'"
        echo "S1_IMPL='$IMPL'"
        echo "S1_REV='$REV'"
        echo "S1_MERGE='$MERGE'"
        echo "S1_BRANCH='$BRANCH'"
    else
        echo "S2_F1_SPEC='$F1_SPEC'"
        echo "S2_F1_EST='$F1_EST'"
        echo "S2_F1_IMPL='$F1_IMPL'"
        echo "S2_F1_REV='$F1_REV'"
        echo "S2_F2_SPEC='$F2_SPEC'"
        echo "S2_F2_EST='$F2_EST'"
        echo "S2_F2_IMPL='$F2_IMPL'"
        echo "S2_F2_REV='$F2_REV'"
        echo "S2_MERGE_F1='$F1_MERGE'"
        echo "S2_MERGE_F2='$F2_MERGE'"
        echo "S2_BRANCH_F1='$BRANCH_F1'"
        echo "S2_BRANCH_F2='$BRANCH_F2'"
    fi
    echo "${S}_KAL='$KAL'"
    echo "${S}_ABSCHLUSS='$ABSCHLUSS'"
} > "$IDS"

say "Board"
k list

cat <<EOF

IDs liegen in $(basename "$IDS"):   source $(basename "$IDS")

Weiter:
  ./pump.sh                          takten
  ./scripts/watchdog.sh --kill       zwischendurch; lange Karten hängen an CLOSE_WAIT
  ./scripts/check-sprint.sh $S        den Sprint-Nachweis abnehmen
EOF
if [ "$SPRINT" = "1" ]; then
cat <<EOF
  ./create-sprint.sh 2               erst NACH 'Kalibrierung S1' — das Skript prüft es
EOF
else
cat <<EOF
  ./create-release.sh                Release-Abschluss + Release-Gate
EOF
fi
