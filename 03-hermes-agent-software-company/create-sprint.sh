#!/usr/bin/env bash
#
# ESF — Phase 2: Die Sprint-Graphen von Release 1
# ==============================================
#
#   ./create-sprint.sh 1     S1 — Wartung F-R1-5 + Feature F-R1-2
#   ./create-sprint.sh 2     S2 — F-R1-3 ∥ F-R1-4 (Tastatur · E2E-Netz)
#
# Der Zuschnitt folgt der Roadmap, die AM GATE FREIGEGEBEN wurde
# (roadmap/q1-freigegeben.html), nicht der eines frueheren Laufs. Wer diese
# Datei fuer ein anderes Release wiederverwendet, muss die Feature-Kennungen
# und die Kartentexte gegen die dann gueltige Freigabe pruefen: Ein Kartentext,
# der auf einen Roadmap-Abschnitt verweist, den es nicht gibt, schickt einen
# Worker ins Leere — und genau diese Drift hat in Phase 0 eine Gate-Karte in
# die Triage gefahren.
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

# --- Zu den --max-runtime-Werten ------------------------------------------
# Am 18.08.2026 rissen ZWEI Karten ihre Zeitgrenze um Sekunden und verloren
# damit ihren ganzen Lauf:
#
#   Onboarding 4/6 (E2E)   5406 s gegen 5400 s  -> 103 min statt ~50
#   Probelauf 2/4 (Bau)    1516 s gegen 1500 s  ->  36 min statt 11
#
# Die Bau-Karte schreibt eine dreizeilige Markdown-Datei; ihr erfolgreicher
# zweiter Lauf brauchte dafuer 11 Minuten. Das ist kein Haenger, sondern die
# Arbeitsgeschwindigkeit dieses Modells — und die Grenzen der Skripte waren
# fuer ein schnelleres kalibriert. Der Ausgang ist der teuerste denkbare:
# voller Preis, kein Ergebnis, vollstaendige Wiederholung. Und die verlorene
# Zeit landet als Wanduhr im Ledger und verzerrt jede kuenftige Schaetzung.
#
# Die Karten, die die volle E2E-Suite UND die Unit-Tests fahren (Wartung,
# Review, Merge), stehen deshalb auf 90 Minuten statt 60. Ein zu hoher Deckel
# kostet nichts, wenn er nicht erreicht wird; ein zu niedriger kostet einen
# ganzen Lauf.

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

DIE KLASSE IST PFLICHT, DAS INTERVALL NICHT IMMER.
Zwei Faelle, und du musst wissen, in welchem du bist:

 a) Dein Handoff-Kontext enthaelt ein Schaetz-Intervall des esf-estimator fuer
    DIESE Karte. Dann kopiere das vollstaendige estimate-Objekt WOERTLICH —
    dieselben Zahlen, dasselbe confidence, dasselbe estimated_by. Nicht neu
    schaetzen, nicht runden, nicht "verbessern".

 b) Es enthaelt keines — weil du VOR dem esf-estimator laufst (jede erste Karte
    einer Feature-Kette tut das). Dann schreibst du das estimate-Objekt
    trotzdem, nur mit der Klasse allein:

        "estimate": {"reference_class": "$1", "wall_minutes": null,
                     "confidence": null, "estimated_by": null,
                     "tokens_k": null, "cost_usd": null}

    Du erfindest keine Zahl. Aber du laesst das Objekt auch nicht weg.

Am 19.08.2026 ist genau Fall b) schiefgegangen: Die Spezifikationskarte von
F-R1-2 schrieb ein vollstaendiges metadata mit acceptance, Schrittzahlen und
Commit — und ohne estimate. Sie las die Bedingung "traegst du ein Intervall,
dann kopiere", fand keines, und liess das ganze Objekt weg. check-sprint.sh
meldete sie als "ohne metadata.estimate.reference_class"; im Ledger waere sie
als 'unklassifiziert' gelandet und fuer jede kuenftige Schaetzung wertlos.
Der Fehler lag im Kartentext, nicht im Modell: Er sprach fast nur vom Kopieren.

Warum das penibel ist: ledger-sync.sh liest Schätzung und Istwert aus dem
metadata DERSELBEN Karte. Die Schätzung entsteht aber auf einer anderen. Wer
sie nicht mitnimmt, hinterlässt einen Istwert ohne Paar — und scripts/check-sprint.sh
schlägt darauf fehl, weil zwei Sprint-Reports MIT Paaren der Nachweis sind, den
Phase 2 erbringen muss.

Damit die Schätzung dich überhaupt erreicht, ist die Estimator-Karte ein
ZWEITER Elternteil dieser Karte — nicht nur der Karte vor dir. Das ist am
17.08.2026 nachgerüstet worden: In S1 hing die Kette
Schätzung → Umsetzung → Review → Merge, und die Schätzung musste von Hand
weitergereicht werden. Die Umsetzung und das Review nahmen sie mit, die
Merge-Karte nicht — Prüfung 3 von check-sprint.sh fand das zerrissene Paar. Eine
Vorschrift, die von vier Weitergaben abhängt, reisst an der vierten. Jetzt liegt
die Schätzung in DEINEM Handoff-Kontext, nicht in dem deines Vorgängers.
EOF
}

# Für jede Karte, die im Worktree baut. Ohne diesen Absatz hat ein Entwickler
# am 17.08.2026 rund 80 Minuten in Umgebungs-Archäologie gesteckt — und dabei
# die `.env` des HAUPTBAUMS neu geschrieben. Ein Worker, der aus seinem Worktree
# in den Hauptbaum schreibt, hebt die Isolation auf, auf der die ganze parallele
# Arbeit beruht.
# Warum in jedem Review- und Merge-Kartentext `--force` steht.
#
# Gemessen am 19.08.2026 im Worktree der F-R1-2-Umsetzung, direkt nachdem der
# Entwickler dort seine Tests hatte laufen lassen:
#
#     pnpm typecheck
#     Cached: 6 cached, 6 total   Time: 170ms >>> FULL TURBO
#
# turbo hasht seine Eingaben und spielt bei gleichem Hash das alte Ergebnis ab.
# Der Reviewer fuehrt den Befehl in gutem Glauben aus, turbo antwortet mit dem
# Protokoll des Entwicklers, und der Reviewer meldet es als eigene Messung.
# Genau die Anweisung "Fuehre die Tests SELBST aus. Nicht sein Protokoll lesen"
# wird damit von einem Build-Werkzeug entwertet — lautlos, ohne Fehlermeldung.
#
# `playwright test` laeuft nicht ueber turbo und war nie betroffen. Dass eine
# der Pruefungen immer echt war, ist der Grund, warum es nicht auffiel.
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

# Das neue AK8 aus dem Spec-Nachtrag vom 17.08.2026.
#
# ⚠ IN DIESEM RELEASE NICHT AUFGERUFEN — bewusst stehengelassen.
#   Das AK8 setzt eine gemeinsame Montagestelle voraus (apps/api/src/app.ts
#   nach der Haertung R1-F5). Die Roadmap, die am 18.08.2026 freigegeben wurde,
#   enthaelt diese Haertung nicht: F-R1-2, F-R1-3 und F-R1-4 arbeiten an der
#   Weboberflaeche und an tests/, keines montiert Routen. Ein Kriterium, das
#   auf eine Datei zeigt, die kein Branch anfasst, waere Zeremonie.
#   Es bleibt hier, weil die Regel dahinter allgemein ist und beim naechsten
#   geteilten Montagepunkt wieder gilt: `$(ak8)` in den Kartentext, fertig.
#
# Vorgeschichte, weil sie die Regel erklaert: Das erste AK8 lautete "app.ts
# bleibt < 450 Zeilen". Die Umsetzung landete bei 565, obwohl sie die
# Zielstruktur genau befolgte — die Spezifikation forderte inhaltlich mehr, als
# 450 Zeilen fassen. Der CEO hob das Limit auf; der esf-architect ersetzte es
# und verwarf dabei den Kandidaten des CEO ("hoechstens N geaenderte Zeilen"),
# weil N wieder eine nicht abgeleitete Zahl gewesen waere. Sein Kriterium misst
# stattdessen die UEBERSCHRIEBENE FLAECHE, und das ist die Groesse, die
# Merge-Konflikte wirklich verursacht.
ak8() {
cat <<'EOF'
app.ts — DAS NEUE AK8: rein additiv, keine Zahl
Nach der Haertung R1-F5 ist apps/api/src/app.ts die Montagestelle aller Routen.
Fuer deinen Branch gilt:

    git diff main...<dein Branch> -- apps/api/src/app.ts

muss AUSSCHLIESSLICH additive Montagezeilen zeigen — je eine neue
api.route(...)- bzw. register*-Registrierungszeile fuer deine Route. Keine
bestehende Zeile wird geaendert, verschoben, umsortiert oder umformatiert. Jede
geaenderte bestehende Zeile ist ein Verstoss, und der Reviewer prueft das in
unter einer Minute.

Zwei Gruende, und der zweite ist der wichtigere:
· Merge-Konflikte entstehen dort, wo zwei Branches dieselbe bestehende Region
  umschreiben. Zwei rein additive Branches koennen nicht kollidieren — und in
  diesem Sprint baut ein zweites Feature gleichzeitig.
· Die Montagereihenfolge um den api.use("*", …)-Auth-Block ist
  VERHALTENSWIRKSAM (Invariante aus ADR-001). Wer sie umsortiert, aendert das
  Verhalten, ohne eine Zeile Logik anzufassen.

Lass also auch die Formatierung in Ruhe. Ein biome --write ueber die ganze
Datei waere genau der Verstoss, den dieses Kriterium verhindert: er schreibt
bestehende Zeilen um. Lintе nur, was du selbst geschrieben hast.
EOF
}

gate_verbot() {
cat <<'EOF'
DIE GRENZE
Du rufst NIEMALS kanban_unblock auf — nicht auf dieser Karte, nicht auf einer
anderen, aus keinem Grund (AGENTS.md 7). monitor.sh meldet jede Verletzung.

Und du rufst NICHT kanban_request_review. Eine Karte im Status 'review' kann
sich selbst nicht mehr abschliessen: kanban_complete antwortet dann
'could not complete <id> (unknown id or already terminal)'. Real am 18.08.2026
passiert — ein Worker drehte vier Laeufe in dieser Schleife, jeder 0 Minuten,
bis der Circuit Breaker aufgab; die Arbeit war laengst committet. Wer eine
Entscheidung braucht, blockiert sich EINMAL mit kanban_block(kind="needs_input")
und stellt seine Frage im Blockgrund — das ist der Weg, den gate.sh bedient.
Wer fertig ist, ruft kanban_complete.

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

Die freigegebene Roadmap bindet die Reihenfolge (Abschnitt 8, Auflage a):
F-R1-3 und F-R1-4 dürfen nicht spezifiziert oder geschätzt werden, bevor die
Kalibrierung aus dem ersten abgeschlossenen Feature gelaufen ist. Der Sinn eines
leeren Ledgers ist, ihn zu füllen, nicht ihn zu überspringen.

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
SLUG="r1-f2-create-task-subtraktion"
BRANCH="${PRAEFIX}esf-$SLUG"

# Die Reihenfolge dieses Sprints steht nicht hier, sondern in der freigegebenen
# Roadmap: die Wartungskarte VOR der Feature-Arbeit, dann genau ein Feature.
# roadmap/q1-freigegeben.html, Abschnitt 4:
#
#   "F-R1-5 (Biome-Hygiene) ist keine Feature-Arbeit: Sie laeuft als
#    Wartungskarte im ersten Sprint von R1, vor der Feature-Arbeit, und belegt
#    keinen Feature-Slot."
#
# Sie ist deshalb Elternteil der Spezifikationskarte: Der Feature-Branch soll
# von einem main abzweigen, auf dem `biome ci` bereits gruen ist — sonst
# schleppt jede spaetere Riegel-Pruefung die Bestandsschuld mit.

say "S1 W 1/1  Wartung — biome ci gruen  (Hauptbaum, vor der Feature-Arbeit)"
WARTUNG=$(k create "$S W 1/1 — Wartung: biome ci gruen" \
    --assignee esf-dev-a \
    --workspace "dir:$REPO" \
    --idempotency-key "s1-wartung-biome" \
    --max-retries 2 --max-runtime 90m \
    --body "Wartungskarte aus der freigegebenen Roadmap (roadmap/q1-freigegeben.html,
Abschnitt 4). Kein Feature, kein Feature-Slot: Sie raeumt die Werkzeugkette auf,
BEVOR die Feature-Arbeit beginnt.

DER BEFUND, AUF DEN DU AUFSETZT (analysis/codebase.html §5.1)
Der Architekt hat 'pnpm exec biome ci .' selbst gefahren: 1.190 Dateien in
414 ms, 'Found 1 error. Found 80 warnings. Found 1 info.', Exit 1. Aufgeteilt
nach Regel: 64 x lint/suspicious/noUndeclaredEnvVars (Konfiguration, keine
Logik), 12 inhaltliche Stil-Findings (davon 8 useOptionalChain, 2 noImgElement),
Rest verteilt. Belegt ist ausserdem, dass keine der beanstandeten Dateien vom
Ausgangs-Commit beruehrt wurde: Bestandsschuld, kein Regressionsproblem.

PRUEF DIESE ZAHLEN SELBST NACH, bevor du etwas aenderst. Sie stammen aus einer
Analyse von heute frueh; der Arbeitsbaum hat sich seither veraendert (die
E2E-Karte hat Specs und playwright.config.ts committet). Eine Zahl aus einem
fremden Bericht ist eine Behauptung, bis du sie gemessen hast.

DEIN ORT
Hauptbaum ($REPO), Branch main. Kein Worktree, kein Merge, kein Riegel: Zu
diesem Zeitpunkt arbeitet niemand sonst am Repo, und eine reine
Formatierungs-/Konfigurationsaenderung ueber einen Feature-Branch zu fuehren
waere Zeremonie ohne Schutzwirkung. Du committest direkt auf main.

$(env_hinweis)

WAS ZU TUN IST — in dieser Reihenfolge
1. Messen und festhalten: 'pnpm exec biome ci .' und die Aufteilung nach Regel
   ('biome ci --reporter=summary' oder die Ausgabe selbst auszaehlen). Das ist
   dein Vorher-Wert.
2. Die 64 noUndeclaredEnvVars: Das sind Umgebungsvariablen, die in turbo.json
   nicht deklariert sind. Deklariere sie dort, ODER schalte die Regel gezielt
   ab — welchen Weg du gehst, begruendest du im metadata. Die Regel abzuschalten
   ist erlaubt und manchmal richtig; sie ohne Begruendung abzuschalten ist es
   nicht.
3. Die inhaltlichen Stil-Findings: 'pnpm exec biome check --write' fuer das
   automatisch Behebbare. Danach LIES den Diff. Ein Auto-Fix, den niemand
   angesehen hat, ist eine ungeprufte Aenderung, auch wenn ein Werkzeug sie
   gemacht hat.
4. Bleibt etwas uebrig, das weder auto-fixbar noch trivial ist: NICHT mit der
   Hand umbauen. Ins metadata unter 'offen_gelassen' mit Regel, Datei und Grund.
   Diese Karte darf Verhalten nicht aendern.
5. Nachweis, alle drei, mit Zahlen:
     pnpm exec biome ci .        -> muss Exit 0 sein
     pnpm typecheck && pnpm test -> unveraendert gruen
     $E2E_VORBED
     $E2E_BEFEHL                 -> die volle Suite unveraendert gruen
6. Commit auf main, Conventional Commits in Kleinschreibung
   (z.B. 'chore(lint): biome-bestandsschuld abgeraeumt'). Der Pre-Commit-Hook
   lintet deine gestageten Dateien; er wird halten. Umgehe ihn nicht, kein
   --no-verify.

DIE HARTE REGEL
Verhalten unveraendert. Diese Karte fasst keine Logik an. Faellt dir dabei ein
echter Fehler auf: nicht beheben, sondern ins metadata unter
'gefunden_nicht_gemacht'. Daraus wird eine eigene Karte.

KOMMST DU NICHT AUF EXIT 0
Liefere weniger, aber gruen in Typecheck, Tests und E2E. 'biome ci' teilweise
entlastet ist ein Ergebnis; ein kaputter Hauptbaum ist keins. Was offen bleibt,
steht im metadata mit Zahl (wieviele Findings bleiben, welcher Regel).

$(metadata_pflicht 'maintenance-repo-S')
Dazu ins metadata: die Vorher-/Nachher-Zahlen von biome ci (error/warning/info),
die Aufteilung nach Regel vorher, welchen Weg du bei noUndeclaredEnvVars
gewaehlt hast und warum, die Testzahlen vor und nach, der Commit-Hash.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  WARTUNG = $WARTUNG"

say "S1 F2 1/5  Spezifikation — F-R1-2 Create-Task-Dialog entschlacken"
# Der Product Manager und nicht der Architekt: F-R1-2 hat eine Nutzeraufgabe
# (K2 aus product.html), keine Strukturentscheidung. Kein ADR noetig.
SPEC=$(k create "$S F2 1/5 — Spezifikation F-R1-2 Create-Task-Dialog entschlacken" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --parent "$WARTUNG" \
    --idempotency-key "s1-f2-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere F-R1-2 der freigegebenen Roadmap: die Subtraktion am
Create-Task-Dialog.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, Abschnitt 4, F-R1-2)
Nutzeraufgabe: 'Einen Vorgang anlegen und zuweisen' (K2 aus product.html) — die
laengste Alltags-Journey wird kuerzer. Belegt ist der Befund in deiner eigenen
Produktanalyse: jede Eigenschaft (Assignee, Prioritaet, Termin, Label) ist ein
eigenes Popover; J-03 hat 6 Schritte und ist der taegliche Planungskern.
Referenzklasse feature-frontend-S. E2E: erweitert die bestehende Journey J-03.

WARUM GERADE DIESE UND KEINE ANDERE
Die Roadmap begruendet die Auswahl mit dem Subtraktions-Abschnitt: J-01 hat mit
7 Schritten die hoechste Schrittzahl, lohnt die Kuerzung aber nicht — sie ist
eine einmalige Onboarding-Journey. J-03 wiederholt sich taeglich. Vereinfachung
zaehlt dort, wo sie sich wiederholt. Halte diese Begruendung in der
Spezifikation fest; sie ist der Massstab, an dem der Reviewer misst, ob die
Aenderung ihr Ziel trifft.

DEINE ARBEIT — ein Dokument im Vault, kein Code
Du liest im Repo ($REPO) und aenderst dort nichts. Die Oberflaeche liegt unter
apps/web/src; der Dialog ist an der Klasse .kaneo-create-task-modal erkennbar
(so findet ihn die bestehende Spec tests/e2e/journeys/vorgang-anlegen-zuweisen.spec.ts).

SCHREIBE specs/r1-f2-create-task-subtraktion.html. Sie muss beantworten:
 · Der Ist-Zustand, mit Zahlen: Welche Felder und Popover hat der Dialog heute,
   wieviele Klicks kostet der haeufigste Fall? Zaehl sie an den Komponenten ab,
   rate sie nicht.
 · Was WEG kommt oder zusammenwaechst — und was ausdruecklich bleibt.
   Subtraktion heisst entfernen, nicht umsortieren. Nenne je Entscheidung den
   Fall, der dadurch schlechter wird; wenn es keinen gibt, hast du nicht genau
   genug hingesehen.
 · Der Soll-Zustand mit derselben Zaehlung. Die Differenz ist der Wert dieses
   Features.
 · Was NICHT passieren darf: kein Datenverlust, keine Aenderung an der API,
   keine Pflichtfelder, die vorher optional waren. J-03 muss weiter gruen sein.
 · Akzeptanzkriterien, pruefbar formuliert, jedes einzeln abhakbar.
   Mindestens: Typecheck gruen, Unit-Tests gruen, volle E2E-Suite gruen,
   J-03 um die neue Kuerze erweitert, Schrittzahl nachweislich gesunken.

E2E: KEIN neuer Spec, sondern die bestehende J-03 erweitert
tests/e2e/journeys/vorgang-anlegen-zuweisen.spec.ts deckt J-03 heute ab. Sie
muss nach dem Umbau weiter gruen sein UND die kuerzere Bedienung abbilden.
Schreib ausdruecklich hin, wie: welche Schritte in der Spec entfallen.

DER ZUSCHNITT IST TEIL DEINER ARBEIT
Der Deckel liegt bei $KARTEN_DECKEL Karten je Feature; dieses Feature hat fuenf
und davon genau EINE Bau-Karte. Passt dein Soll-Zustand nicht in eine Bau-Karte,
schneide ihn kleiner — ein erster Schnitt, der traegt, statt einer vollstaendigen
Neugestaltung. Was du bewusst liegen laesst, gehoert in die Spezifikation, nicht
in eine stille Auslassung.

$(metadata_pflicht 'spec-vault-S')
Dazu ins metadata: acceptance (die Kriterien als Liste — Entwickler und Reviewer
arbeiten beide gegen genau diese Liste), die Schrittzahl vorher und das Ziel
nachher als Zahlen.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  SPEC = $SPEC"

say "S1 F2 2/5  Schätzung"
EST=$(k create "$S F2 2/5 — Schätzung F-R1-2" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$SPEC" \
    --idempotency-key "s1-f2-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schaetze die drei Folgekarten von F-R1-2. Die Spezifikation deiner
Elternkarte (specs/r1-f2-create-task-subtraktion.html) steht in deinem
Handoff-Kontext.

DAS LEDGER IST DEINE EINZIGE QUELLE — und es ist erstmals nicht leer
ledger/estimates.jsonl traegt die nachgebuchten Ist-Zeiten dieses Laufs:
gemessene Wanduhrminuten aus Board-Zeitstempeln, klassifiziert, mit
'estimate: null' und '\"backfill\": true'. Lies die Datei, bevor du rechnest.

Was du dort findest und was das wert ist:
  · Die Klassen sind mit n=1 bis n=3 besetzt. Das ist wenig. Sag es hin.
  · Es sind ISTWERTE ohne Schaetzung. Es gibt also noch keine Velocity-
    Verteilung (Ist/Schaetzung) — die entsteht erst mit DIESER Schaetzung und
    ihrer Messung. Behaupte keine, die du nicht hast.
  · Eine Zeile ist verzerrt und du musst sie erkennen: die Karte der Klasse
    e2e-repo-L traegt 'runs: 2'. Ihr erster Lauf lief in die Zeitgrenze
    (timed_out bei 5406 s gegen 5400 s) und wurde vom zweiten geerbt. Die
    103 Minuten sind gemessene Wanduhr, aber gut die Haelfte davon ist
    Wiederholung. Wer diese Zeile als Normalfall nimmt, schaetzt zu hoch.
    Pruefe bei JEDER Zeile, die du heranziehst, das Feld 'runs'.
  · Deine Aufgabe ist trotzdem eine Zahl, nicht ein Achselzucken. Ein breites
    Intervall mit niedriger Konfidenz und benannter Grundlage ist die
    geforderte Antwort (Kapitel 8: 'Klassen ohne Historie starten mit breiten
    Intervallen und niedriger Konfidenz, und sagen das dem CEO'). Ein 'kann ich
    nicht' waere hier falsch: der Backfill IST die Historie.

SCHAETZE DIESE DREI KARTEN, jede einzeln, jede mit ihrer Klasse:

  Karte                    Referenzklasse       naechste Nachbarn im Ledger
  ---------------------------------------------------------------------------
  $S F2 3/5 Umsetzung      impl-worktree-S      impl-worktree-S (Probelauf)
  $S F2 4/5 Review         review-repo-S        review-repo-S (Probelauf)
  $S F2 5/5 Merge          merge-repo-S         — keine, Riegel-Lauf

Die Nachbarn aus dem Probelauf sind DUMMY-Arbeit: eine triviale Datei, ein
triviales Review. Sie sind ein schwacher Anker, kein guter. Sag genau das hin
und rechne den Abstand vor: 'impl-worktree-S hat n=1 mit X min an einer Datei;
dieses Feature beruehrt N Komponenten laut Spezifikation, daher ...'. Wer den
Schritt hinschreibt, kann spaeter zeigen, wo er falsch war — das ist der ganze
Zweck von Evidence-Based Scheduling.

Fuer merge-repo-S gibt es keinen Nachbarn. Dort ist die ehrliche Grundlage der
Riegel selbst: sechs Pruefungen, deren laengste die volle E2E-Suite ist
(gemessen in diesem Lauf: 7 Tests, siehe reports/) plus die Unit-Tests. Rechne
daraus, nenn die Rechnung.

tokens_k und cost_usd: 'null'. Hermes v0.20.0 misst keine Tokens, und der
OpenRouter-Zaehler laeuft je Rolle kumulativ — je Karte gibt es keine Zahl. Ein
hineingeschriebener Wert waere die vergiftete Kalibrierung aus AGENTS.md 6.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-r1-f2.html (esf-typ 'report'): die drei Intervalle, die
   Referenzklassen, die Ledger-Zeilen, auf die du dich stuetzt (task_id nennen!),
   die Konfidenz je Schaetzung und in einem Satz, warum sie so niedrig ist.
2. Ins Abschluss-metadata dieser Karte ein Objekt 'estimates' mit den drei
   Schaetzungen, je Karte eines, nach dem festen Schema deiner SOUL — sowie
   zusaetzlich unter 'estimate' die Schaetzung DIESER Karte selbst
   (reference_class 'estimate-vault-S').

   Das metadata ist der Weg, auf dem die Zahlen bei den Folgekarten ankommen:
   sie lesen es in ihrem Handoff-Kontext. Schreib es maschinenlesbar, mit
   genau den Kartentiteln oben als Schluessel.

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  EST  = $EST"

say "S1 F2 3/5  Umsetzung  (eigener Worktree, eigener Branch)"
IMPL=$(k create "$S F2 3/5 — Umsetzung F-R1-2" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH" \
    --parent "$EST" \
    --idempotency-key "s1-f2-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze F-R1-2 um: den Create-Task-Dialog nach
specs/r1-f2-create-task-subtraktion.html entschlacken.

DEIN BAUM
Du arbeitest in deinem eigenen Worktree auf Branch '$BRANCH'. Kein anderer
Worker fasst diesen Branch an. Du mergst NICHT — das tut der Riegel auf einer
eigenen Karte, und kein Modell merged (Kapitel 6).

$(env_hinweis)

Die Spezifikation und die Akzeptanzkriterien stehen in deinem Handoff-Kontext;
die Datei liegt im Vault unter
$VAULT/specs/r1-f2-create-task-subtraktion.html.

DIE EINZIGE HARTE REGEL DIESER KARTE
Kein Datenverlust und keine API-Aenderung. Subtraktion heisst: der Anwender
braucht weniger Schritte fuer denselben Vorgang — nicht, dass er weniger
speichern kann. Faellt eine Eigenschaft aus dem Dialog, muss sie an anderer
Stelle weiter erreichbar sein, und die Spezifikation sagt wo. Steht es dort
nicht, ist das ein Befund fuer dein metadata, keine eigene Entscheidung.

REIHENFOLGE
1. Erst messen, dann schneiden. Notiere den Ausgangsstand mit Zahlen:
     cd \$(git rev-parse --show-toplevel)
     pnpm typecheck && pnpm test
   Wieviele Tests, wie lange? Diese Zahl ist dein Vergleichsmassstab, und du
   brauchst sie am Ende noch.
2. Umbauen, in kleinen Schritten, nach dem Soll-Zustand der Spezifikation.
   Nach jedem Schritt typecheck. Ein grosser Sprung, der am Ende rot ist, kostet
   mehr als vier kleine.
3. Die E2E-Journey J-03 mitfuehren:
   tests/e2e/journeys/vorgang-anlegen-zuweisen.spec.ts muss die KUERZERE
   Bedienung abbilden und gruen sein. Was in der Spec an Schritten entfaellt,
   steht in der Spezifikation.
     $E2E_VORBED
     $E2E_BEFEHL
   Die volle Suite muss gruen sein, nicht nur J-03.
4. Commit auf deinen Branch, Conventional Commits in Kleinschreibung
   (z.B. 'feat(web): create-task-dialog auf einen schritt verdichtet').
   Der Pre-Commit-Hook lintet nur DEINE gestageten Dateien — er wird halten,
   wenn deine Zeilen sauber sind. Umgehe ihn nicht. Wenn er meckert, sind es
   deine Zeilen.

EIN GEMESSENER STOLPERSTEIN IM HELFER
tests/e2e/support/journey.ts enthaelt seit Phase 1 in arbeitsbereichAnlegen eine
Schleife ueber fuenf Versuche gegen ein Rennen mit React Hook Form. Das ist
Toleranz gegen Flakiness. Wenn DEIN Umbau dazu fuehrt, dass ein Feld nicht mehr
ankommt, kann diese Schleife den Fehler verdecken. Faellt dir das auf: ins
metadata, nicht stillschweigend mehr Versuche.

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber gruen. Ein Dialog, der zwei Popover statt vier braucht und
gruen ist, ist ein Ergebnis; ein vollstaendiger Umbau mit roten Tests ist keins.
Was du weggelassen hast, gehoert ins metadata unter 'deliberately_not_done' mit
Grund — und zwar deinem eigenen Grund, nachgeprueft. Pruef, was du abschreibst.

$(metadata_pflicht 'impl-worktree-S')
Dazu ins metadata: die Liste der geaenderten Dateien, das Testergebnis vor und
nach dem Umbau (Zahlen!), das E2E-Ergebnis, die Schrittzahl vorher/nachher mit
der Stelle, an der du sie gezaehlt hast, der Commit-Hash, und je
Akzeptanzkriterium ein Haekchen mit dem Beleg.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  IMPL = $IMPL"

say "S1 F2 4/5  Review  (Hauptbaum, sieht in den fremden Worktree)"
REV=$(k create "$S F2 4/5 — Review F-R1-2" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$IMPL" --parent "$EST" \
    --idempotency-key "s1-f2-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R1-2 auf Branch '$BRANCH'.

DEIN ORT
Du arbeitest im HAUPTBAUM ($REPO), nicht in einem Worktree. Von hier siehst du
in die fremden Baeume unter .worktrees/ hinein. Der Branch ist bereits von einem
Worktree beansprucht — ein 'git checkout $BRANCH' im Hauptbaum scheitert hart
('fatal: ... is already used by worktree'). Nimm 'git log/diff/show $BRANCH' und
lies im fremden Baum, ohne ihn anzufassen. Genau dieser Fehler hat im ersten
Lauf eine Karte in den Circuit Breaker gefahren (RUN-PROTOKOLL.md).

WAS DU PRUEFST — in dieser Reihenfolge, weil die erste Frage die teuerste ist
1. Ist der Vorgang noch vollstaendig speicherbar? Das ist der Zweck der Regel
   'kein Datenverlust' und die einzige Frage, deren falsche Antwort Nutzer
   trifft. Pruefe konkret: Welche Eigenschaften konnte man vorher am Dialog
   setzen, welche jetzt, und wo sind die uebrigen erreichbar? 'git diff
   main..$BRANCH' und dann die Komponenten gegeneinander.
2. Ist die Schrittzahl wirklich gesunken? Die Spezifikation nennt eine Zahl
   vorher und ein Ziel nachher. Zaehl selbst nach, an derselben Stelle. Eine
   Subtraktion, die nur umsortiert, hat ihr Ziel verfehlt — das ist der
   haeufigste Fehlschlag dieser Art von Feature.
3. Ist jedes Akzeptanzkriterium der Spezifikation erfuellt? Geh die Liste aus dem
   Handoff-Kontext einzeln durch und schreib je Kriterium hin, WORAN du es
   geprueft hast. 'Sieht erfuellt aus' ist keine Pruefung.
4. Fuehre die Tests SELBST aus, im Baum des Entwicklers. Nicht sein Protokoll
   lesen — laufen lassen:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
   Der Unterschied zwischen Behauptung und geprüfter Tatsache ist dein ganzer
   Daseinsgrund.
5. Bildet die J-03-Spec die neue, kuerzere Bedienung ab — oder ist sie nur
   angepasst worden, bis sie wieder gruen war? Lies den Diff der Spec-Datei.
   Eine Journey, die man an den Code anpasst, statt den Code an die Journey,
   ist kein Regressionsnetz mehr.
6. Ist main unberuehrt? 'git log main..' und der Arbeitsbaum-Status.

WENN ETWAS FEHLT
Dein Urteil ist 'approved' oder 'changes_requested', im metadata unter
'verdict', mit den Befunden als Liste. Bei 'changes_requested' beschreibt jeder
Befund, WAS zu tun ist, nicht dass etwas nicht stimmt. Du reparierst nichts
selbst — dann waere niemand mehr da, der prueft.

Ein bekannter Stoerfaktor, damit du ihn nicht als Befund missdeutest:
mcp-internal-api-url.test.ts ist lastempfindlich. Faellt genau dieser Test und
sonst nichts, lauf ihn allein nach; gruen allein und rot unter Last ist ein
Betriebsbefund, kein Fehler des Entwicklers. Notier ihn als solchen.

$(metadata_pflicht 'review-repo-S')
Dazu ins metadata: verdict, die Befunde, das selbst gemessene Testergebnis
(Zahlen), die selbst nachgezaehlte Schrittzahl aus Punkt 2.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  REV  = $REV"

say "S1 F2 5/5  Merge am Riegel"
MERGE=$(k create "$S F2 5/5 — Merge F-R1-2 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$REV" --parent "$EST" \
    --idempotency-key "s1-f2-merge" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R1-2 nach main — ueber den Riegel, nicht mit der Hand.

DER EINZIGE ERLAUBTE WEG
    $HERE/scripts/merge-riegel.sh $BRANCH --protokoll $VAULT/reports/riegel-r1-f2.txt

Du rufst kein 'git merge'. Der Riegel merged oder verweigert; das ist der
Unterschied zwischen einer Regel und einem Riegel (Kapitel 6). Sechs Pruefungen:
Erreichbarkeit, Konfliktfreiheit, Linter auf den geaenderten Dateien, Typecheck,
Unit-Tests, volle E2E-Suite.

VORBEDINGUNGEN, die du selbst herstellst — sonst verweigert er ohne Sachgrund
1. Das Urteil des Reviewers muss 'approved' sein. Steht 'changes_requested' in
   deinem Handoff-Kontext: NICHT mergen. Schliesse ab mit dem Befund im
   metadata und lege eine neue Karte fuer die Nacharbeit an.
2. Der Arbeitsbaum von $REPO muss sauber sein. Im ersten Lauf verweigerte der
   Riegel, weil dort uncommittete Fremdaenderungen lagen — eine Verweigerung
   ohne Sachbezug. 'git status --short' zuerst; ist er schmutzig und nicht deine
   Schuld, notier das und melde es, statt aufzuraeumen.
3. Postgres muss laufen: $E2E_VORBED
4. Es duerfen keine fremden Dev-Server auf den E2E-Ports stehen. Die
   Playwright-Konfiguration hat 'reuseExistingServer' an — ein alter Server aus
   einem fremden Worktree wuerde die FALSCHE Anwendung testen, und die Suite
   waere trotzdem gruen. Genau das ist der schwerste Messbefund des ersten
   Laufs. Pruefe es, bevor du startest.

WENN ER VERWEIGERT
Der Riegel hat immer einen Grund und er schreibt ihn ins Protokoll. Zwei Sorten,
und die Unterscheidung ist dein Urteil:
 · Sachgrund (Konflikt, roter Test, Linter auf neuen Zeilen) -> nicht mergen,
   abschliessen, neue Karte fuer die Nacharbeit, Befund ins metadata.
 · Betriebsgrund (schmutziger Baum, lastempfindlicher Test — bekannt:
   mcp-internal-api-url.test.ts) -> Ursache benennen, EINMAL sauber nachlaufen
   lassen, und wenn er dann besteht, mergen. Verweigert er erneut, ist es ein
   Sachgrund.

Was du NICHT tust: den Riegel ueberstimmen. Ein Riegel, den man ueberstimmt, ist
keiner. Und du benutzt kein --no-verify.

DANACH
· Das Riegel-Protokoll bleibt als Rohbeleg liegen (reports/riegel-r1-f2.txt,
  .txt und nicht .html — AGENTS.md 2.1 nimmt Maschinenprotokolle aus der
  HTML-Pflicht aus; ein Rohbeleg, den jemand fuer die Darstellung angefasst hat,
  ist keiner mehr).
· Ist gemerged: den Worktree des Entwicklers NICHT aufraeumen. Er ist Beleg.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: das Riegel-Ergebnis (bestanden/verweigert), welche der sechs
Pruefungen wie ausging, der Merge-Commit auf main, die Testzahlen aus dem
Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  MERGE= $MERGE"

LETZTE="$MERGE"
FEATURES="F-R1-2 (dazu die Wartungskarte F-R1-5)"

# ===========================================================================
else   # SPRINT 2
# ===========================================================================
SLUG_FA="r1-f3-tastatur-command-palette"
SLUG_FB="r1-f4-e2e-netz-j05-j06"
BRANCH_FA="${PRAEFIX}esf-$SLUG_FA"
BRANCH_FB="${PRAEFIX}esf-$SLUG_FB"

# Die beiden Features dieses Sprints stehen in roadmap/q1-freigegeben.html,
# Abschnitt 4. Sie laufen parallel, weil sie sich nicht beruehren: F-R1-3 baut
# an der Weboberflaeche, F-R1-4 an der E2E-Suite unter tests/. Genau diese
# Disjunktheit ist der Grund, dass zwei Worktrees hier vertretbar sind —
# parallele Git-Arbeit war im ersten Lauf der haeufigste Ausfallgrund.

# --- Feature F-R1-3 · Tastaturbedienung & Command-Palette ------------------
say "S2 F3 1/4  Spezifikation — F-R1-3 Tastaturbedienung & Command-Palette"
FA_SPEC=$(k create "$S F3 1/4 — Spezifikation F-R1-3 Tastatur & Command-Palette" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --idempotency-key "s2-f3-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere F-R1-3 der freigegebenen Roadmap: Tastaturbedienung und
eine Command-Palette.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, Abschnitt 4, F-R1-3)
Nutzeraufgabe: 'Aufgabe anlegen / Board wechseln' ohne Maus — senkt die Reibung
im taeglichen Flow. Beleg aus analysis/market.html H5 (Score 18,5): Plane
(Power K), Linear und Kanboard liefern das als Kategoriestandard; Kaneo hat
keine explizite Spur. Bewertet als reine Frontend-Arbeit ohne Datenrisiko
(risiko_invers 4, aufwand_invers 4). Referenzklasse feature-frontend-M.
E2E: erweitert J-02 und J-04.

PRUEFE DIE PRAEMISSE, BEVOR DU SPEZIFIZIERST
'Kaneo hat keine explizite Spur' stammt aus einer Korpus-Analyse, nicht aus dem
Code. Sieh selbst nach, ob es schon Tastaturkuerzel gibt (apps/web/src, Suche
nach keydown, hotkey, cmdk, Shortcut). Findest du welche, ist das kein Grund,
die Karte abzubrechen — es aendert den Zuschnitt: dann ist die Aufgabe
Vereinheitlichen und Sichtbarmachen, nicht Neubauen. Schreib den Befund hin.
Im ersten Lauf hat ein Architekt eine Kartentext-Behauptung geprueft und
widerlegt; das ist das erwartete Verhalten, nicht die Ausnahme.

DEINE ARBEIT — ein Dokument im Vault, kein Code
Du liest im Repo ($REPO) und aenderst dort nichts.

SCHREIBE specs/r1-f3-tastatur-command-palette.html. Sie muss beantworten:
 · Welche Aktionen bekommen ein Kuerzel? Leite sie aus den Kernaufgaben in
   analysis/product.html ab (K1-K7), nicht aus einer Wunschliste. Jede Aktion
   mit der Begruendung, warum gerade sie.
 · Wie oeffnet sich die Command-Palette, und was steht darin? Nenne die
   konkrete Tastenkombination und begruende sie gegen die Wettbewerber im
   Korpus.
 · Konflikte mit Browser- und Betriebssystem-Kuerzeln. Das ist der Abschnitt,
   den man vergisst und der hinterher weh tut.
 · Barrierefreiheit: Fokus-Reihenfolge, sichtbarer Fokus, Escape schliesst.
 · Was NICHT passieren darf: keine Aktion, die nur per Tastatur erreichbar ist;
   keine Aenderung an der API; kein Kuerzel, das in einem Textfeld feuert.
 · Akzeptanzkriterien, pruefbar formuliert, jedes einzeln abhakbar.
   Mindestens: Typecheck gruen, Unit-Tests gruen, volle E2E-Suite gruen,
   J-02 und J-04 um mindestens je einen Tastaturweg erweitert.

ACHTUNG PARALLELITAET
F-R1-4 (E2E-Netz J-05/J-06) wird GLEICHZEITIG gebaut, von esf-dev-b, in einem
eigenen Worktree. Beruehrungsflaeche ist tests/e2e/. Deine Spezifikation darf
verlangen, dass J-02 und J-04 erweitert werden — sie darf NICHT verlangen, dass
tests/e2e/support/journey.ts umgebaut wird, denn dort arbeitet das andere
Feature. Braucht dein Feature einen neuen Helfer, schreib hin: eigene Datei,
nicht journey.ts erweitern.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance (die Kriterien als Liste), die Liste der
Aktionen mit ihren Kuerzeln, und dein Befund zur geprueften Praemisse.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_SPEC = $FA_SPEC"

say "S2 F3 2/4  Schätzung — F-R1-3"
FA_EST=$(k create "$S F3 2/4 — Schätzung F-R1-3" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$FA_SPEC" \
    --idempotency-key "s2-f3-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schaetze die zwei Folgekarten von F-R1-3 und die Merge-Karte.

DAS LEDGER TRAEGT JETZT ECHTE PAARE
ledger/estimates.jsonl enthaelt nach S1 erstmals (Schaetzung, Ist)-Paare, nicht
nur nachgebuchte Istwerte. Das aendert deine Arbeit grundlegend: Du kannst
erstmals eine VELOCITY rechnen — Ist geteilt durch Schaetzung, je Klasse — und
deine neue Schaetzung damit korrigieren.

    $HERE/scripts/check-sprint.sh S1

zeigt dir die Paare von S1. Lies auch reports/controller-s1.html, wenn es
schon liegt: Der Controller hat dort ausgerechnet, wo S1 daneben lag.

Drei Dinge, die du dabei ehrlich halten musst:
  · n ist immer noch klein. Eine Velocity aus einem Sprint ist ein Hinweis,
    keine Verteilung. Sag es hin.
  · Pruefe bei jeder Ledger-Zeile das Feld 'runs'. Eine Karte mit zwei Laeufen
    traegt die Wiederholung in ihrer Wanduhrzeit; sie als Normalfall zu nehmen
    schaetzt zu hoch.
  · Die Klasse dieses Features ist feature-frontend-M, die von S1 war
    feature-frontend-S. Der Sprung von S nach M ist eine Behauptung ueber den
    Umfang. Belege ihn an der Spezifikation (Zahl der Aktionen, Zahl der
    beruehrten Komponenten), nicht am Buchstaben.

SCHAETZE DIESE DREI KARTEN, jede einzeln, jede mit ihrer Klasse:

  Karte                    Referenzklasse       naechste Nachbarn im Ledger
  ---------------------------------------------------------------------------
  $S F3 3/4 Umsetzung      impl-worktree-M      impl-worktree-S (aus S1, mit Paar)
  $S F3 4/4 Review         review-repo-M        review-repo-S (aus S1, mit Paar)
  $S Merge F3              merge-repo-S         merge-repo-S (aus S1, mit Paar)

tokens_k und cost_usd: 'null'. Hermes v0.20.0 misst keine Tokens, und der
OpenRouter-Zaehler laeuft je Rolle kumulativ.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-r1-f3.html (esf-typ 'report'): die drei Intervalle, die
   Klassen, die Ledger-Zeilen mit task_id, die gerechnete Velocity je Klasse
   und die Konfidenz je Schaetzung.
2. Ins Abschluss-metadata ein Objekt 'estimates' mit den drei Schaetzungen, je
   Karte eines, mit genau den Kartentiteln oben als Schluessel — plus unter
   'estimate' die Schaetzung DIESER Karte (reference_class 'estimate-vault-S').

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_EST  = $FA_EST"

say "S2 F3 3/4  Umsetzung — F-R1-3  (esf-dev-a)"
FA_IMPL=$(k create "$S F3 3/4 — Umsetzung F-R1-3 Tastatur & Command-Palette" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH_FA" \
    --parent "$FA_EST" \
    --idempotency-key "s2-f3-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze F-R1-3 um: Tastaturbedienung und Command-Palette nach
specs/r1-f3-tastatur-command-palette.html.

DEIN BAUM
Eigener Worktree, Branch '$BRANCH_FA'. Du mergst NICHT.

$(env_hinweis)

ACHTUNG PARALLELITAET — das ist die wichtigste Zeile dieser Karte
esf-dev-b baut GLEICHZEITIG F-R1-4 (die Journeys J-05 und J-06) in einem
eigenen Worktree. Eure Beruehrungsflaeche ist tests/e2e/.
 · Du fasst tests/e2e/support/journey.ts NICHT an. Brauchst du einen Helfer,
   leg eine eigene Datei an.
 · Du fasst die Spec-Dateien von J-05 und J-06 nicht an — die entstehen drueben.
 · J-02 und J-04 gehoeren dir.
Im ersten Lauf war parallele Git-Arbeit der haeufigste Ausfallgrund; die
Trennung oben ist der Grund, warum dieser Sprint sie trotzdem wagt.

REIHENFOLGE
1. Erst messen: 'pnpm typecheck && pnpm test' — Zahlen notieren.
2. Umbauen in kleinen Schritten, nach der Spezifikation. Nach jedem Schritt
   typecheck.
3. Die Kuerzel in J-02 und J-04 mitfuehren, dann:
     $E2E_VORBED
     $E2E_BEFEHL
   Die volle Suite muss gruen sein.
4. Commit auf deinen Branch, Conventional Commits in Kleinschreibung. Der
   Pre-Commit-Hook lintet deine gestageten Dateien. Umgehe ihn nicht.

EIN GEMESSENER STOLPERSTEIN
Ein Kuerzel, das in einem Textfeld feuert, ist der klassische Fehler dieser
Art von Feature — und die E2E-Suite tippt viel in Textfelder. Faellt eine
bestehende Journey nach deinem Umbau, ist das mit hoher Wahrscheinlichkeit
kein flaky Test, sondern genau dieser Fehler. Sieh hin, bevor du wiederholst.

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber gruen. Drei Kuerzel, die sitzen, schlagen zehn, die
kollidieren. Was du weggelassen hast, ins metadata unter
'deliberately_not_done' mit Grund.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: geaenderte Dateien, Testergebnis vor und nach (Zahlen),
E2E-Ergebnis, Commit-Hash, je Akzeptanzkriterium ein Haekchen mit Beleg, und
die Liste der Dateien unter tests/, die du beruehrt hast (der Merge-Wart
braucht sie, um die Schnittmenge mit F-R1-4 zu beurteilen).

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_IMPL = $FA_IMPL"

say "S2 F3 4/4  Review — F-R1-3"
FA_REV=$(k create "$S F3 4/4 — Review F-R1-3" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$FA_IMPL" --parent "$FA_EST" \
    --idempotency-key "s2-f3-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R1-3 auf Branch '$BRANCH_FA'.

DEIN ORT
HAUPTBAUM ($REPO). Der Branch ist von einem Worktree beansprucht — ein
'git checkout' scheitert hart. Nimm 'git log/diff/show $BRANCH_FA' und lies im
fremden Baum unter .worktrees/, ohne ihn anzufassen.

WAS DU PRUEFST
1. Feuert ein Kuerzel in einem Textfeld? Das ist der teuerste Fehler dieser
   Feature-Art. Sieh dir die Event-Handler an: Wird auf das Ziel des Ereignisses
   geprueft (INPUT, TEXTAREA, contenteditable)? Fehlt die Pruefung, ist das ein
   Befund, auch wenn alle Tests gruen sind.
2. Kollidiert ein Kuerzel mit Browser oder Betriebssystem? Die Spezifikation
   hat einen Abschnitt dazu; geh die Liste durch.
3. Ist jede Aktion AUCH ohne Tastatur erreichbar? Die Spezifikation verbietet
   Nur-Tastatur-Aktionen. Eine versteckte Funktion ist keine Bedienhilfe.
4. Barrierefreiheit: sichtbarer Fokus, Escape schliesst die Palette,
   Fokus-Reihenfolge sinnvoll.
5. Jedes Akzeptanzkriterium einzeln, mit der Angabe, WORAN du es geprueft hast.
6. Fuehre die Tests SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
7. Hat er die Grenze zu F-R1-4 eingehalten? tests/e2e/support/journey.ts und
   die Spec-Dateien von J-05/J-06 gehoeren ihm NICHT. 'git diff main..$BRANCH_FA
   --name-only' zeigt es. Ein Verstoss ist ein Befund, auch wenn er harmlos
   aussieht — er erzeugt den Merge-Konflikt, den dieser Sprint vermeiden will.
8. Ist main unberuehrt?

Dein Urteil ist 'approved' oder 'changes_requested', im metadata unter
'verdict', mit den Befunden als Liste. Du reparierst nichts selbst.

Bekannter Stoerfaktor: mcp-internal-api-url.test.ts ist lastempfindlich.
Faellt genau der und sonst nichts, lauf ihn allein nach.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, Befunde, selbst gemessenes Testergebnis (Zahlen),
und die Liste der von diesem Branch beruehrten Dateien unter tests/.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_REV  = $FA_REV"

# --- Feature F-R1-4 · E2E-Netz J-05 + J-06 ---------------------------------
say "S2 F4 1/4  Spezifikation — F-R1-4 E2E-Netz J-05 + J-06"
# Der QA-Eigner und nicht der Product Manager: Das Ergebnis dieses Features IST
# die Suite. Wer sie besitzt, sagt auch, was sie abdecken muss.
FB_SPEC=$(k create "$S F4 1/4 — Spezifikation F-R1-4 E2E-Netz J-05 + J-06" \
    --assignee esf-qa-release \
    --workspace "dir:$VAULT" \
    --idempotency-key "s2-f4-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere F-R1-4 der freigegebenen Roadmap: die Journeys J-05 und
J-06 e2e-fest machen.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, Abschnitt 4, F-R1-4)
J-05 'Teammitglied einladen' (K5) und J-06 'Vorgang bis ins Detail pflegen'
(K4) stehen im Katalog analysis/journeys.html als 'offen' mit '—' als
Spec-Datei. Beleg fuer die Dringlichkeit: analysis/codebase.html §4 und §5.6 —
apps/web/src umfasst rund 62.600 Zeilen bei 35 Testdateien und praktisch keinem
Component-Rendering. Und: J-05 ist Voraussetzung dafuer, dass J-03 die Zuweisung
an ein ZWEITES Mitglied ueberhaupt testen kann; heute faellt die Zuweisung auf
den Anwender selbst zurueck. Referenzklasse e2e-M.

DAS BESONDERE AN DIESEM FEATURE
Sein Ergebnis ist kein Produktcode, sondern das Regressionsnetz selbst. Es gibt
deshalb keine 'erweiterte Journey' — die Journeys ENTSTEHEN hier. Was sonst die
Akzeptanz sichert, ist hier der Liefergegenstand. Schreib das ausdruecklich in
die Spezifikation, damit der Reviewer nicht nach einer Absicherung sucht, die
es nicht getrennt gibt.

DEINE ARBEIT — ein Dokument im Vault, kein Code
Du liest im Repo ($REPO) und aenderst dort nichts.

SCHREIBE specs/r1-f4-e2e-netz-j05-j06.html. Sie muss beantworten:
 · Je Journey: die Schritte, die eine Spec nachspielen muss, in der Sprache des
   Anwenders. Grundlage sind analysis/product.html (K4, K5) und die
   Schrittanalyse in analysis/journeys.html.
 · Der Zustellkanal von J-05. Aus product.html: Ohne SMTP bleibt das
   Invite-Modal offen und zeigt den Einladungslink zum manuellen Verteilen
   (invite-team-member-modal.tsx:105-125). Genau das macht die Journey ohne
   Mailserver autonom testbar — sag hin, wie die Spec an den Link kommt.
 · Wie J-05 zwei Konten braucht und wie die Spec das zuverlaessig herstellt.
   Das ist der schwierigste Teil und der Grund, warum diese Journey bisher
   offen ist.
 · Die Dateinamen der beiden neuen Specs unter $E2E_DIR, im Stil der
   bestehenden (Kleinschreibung, Bindestriche, deutsche Nutzeraufgabe).
 · Was NICHT passieren darf: kein Produktcode geaendert, kein bestehender Spec
   angefasst, tests/e2e/support/journey.ts NICHT umgebaut (dort arbeitet
   F-R1-3 parallel) — Helfer nur additiv in eigener Datei.
 · Akzeptanzkriterien, pruefbar: beide Specs existieren, die volle Suite laeuft
   gruen, analysis/journeys.html fuehrt J-05 und J-06 mit ihrer Spec-Datei
   statt mit '—'.

EIN GEMESSENER STOLPERSTEIN, DEN DU EINPLANEN MUSST
tests/e2e/support/journey.ts enthaelt in arbeitsbereichAnlegen seit Phase 1
eine Schleife ueber fuenf Versuche gegen ein Rennen mit React Hook Form. Das ist
Toleranz gegen Flakiness und kann echte Fehler verdecken. Deine Specs duerfen
sich nicht auf weitere solche Schleifen stuetzen. Verlange in den
Akzeptanzkriterien, dass jede Wartebedingung an einem SICHTBAREN Zustand haengt
(ein Element, ein URL-Wechsel), nicht an einer Wiederholung.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance als Liste, die beiden geplanten Dateinamen, und
die Schritte je Journey als Liste.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_SPEC = $FB_SPEC"

say "S2 F4 2/4  Schätzung — F-R1-4"
FB_EST=$(k create "$S F4 2/4 — Schätzung F-R1-4" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$FB_SPEC" \
    --idempotency-key "s2-f4-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schaetze die zwei Folgekarten von F-R1-4 und die Merge-Karte.

DEINE BESTE UND SCHLECHTESTE ZEILE IST DIESELBE
Fuer die Klasse e2e-repo gibt es genau einen Ledger-Eintrag: die E2E-Karte aus
Phase 1, 103 Minuten, Klasse e2e-repo-L. Und sie ist verzerrt — 'runs: 2', weil
der erste Lauf in die Zeitgrenze lief (timed_out bei 5406 s gegen 5400 s) und
der zweite die Vorarbeit erbte. Gut die Haelfte der 103 Minuten ist
Wiederholung.

Das ist keine Ausrede, sondern deine Rechenaufgabe: Schaetze, was EIN Lauf
gekostet haette, und sag, wie du das aufteilst. Nenn beide Zahlen — die
gemessene und die bereinigte — und begruende die Bereinigung. Wer eine verzerrte
Zeile ungefiltert weiterreicht, vergiftet jede kuenftige Schaetzung dieser
Klasse.

Zweiter Massstab: Jene Karte schrieb DREI Specs (J-02, J-03, J-04) und baute
das Harness mit. Dieses Feature schreibt ZWEI Specs auf ein fertiges Harness.
Rechne den Abstand vor.

Dazu traegt das Ledger nach S1 erstmals echte (Schaetzung, Ist)-Paare. Nutze
sie fuer die Velocity, auch wenn sie aus anderen Klassen stammen:

    $HERE/scripts/check-sprint.sh S1

SCHAETZE DIESE DREI KARTEN:

  Karte                    Referenzklasse       naechste Nachbarn im Ledger
  ---------------------------------------------------------------------------
  $S F4 3/4 Umsetzung      e2e-repo-M           e2e-repo-L (verzerrt, runs=2)
  $S F4 4/4 Review         review-repo-M        review-repo-S (aus S1, mit Paar)
  $S Merge F4              merge-repo-S         merge-repo-S (aus S1, mit Paar)

tokens_k und cost_usd: 'null'.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-r1-f4.html (esf-typ 'report'): die drei Intervalle, die
   Klassen, die Ledger-Zeilen mit task_id, die Bereinigung der verzerrten Zeile
   mit Rechnung, die Konfidenz je Schaetzung.
2. Ins Abschluss-metadata ein Objekt 'estimates' mit den drei Schaetzungen, je
   Karte eines, mit genau den Kartentiteln oben als Schluessel — plus unter
   'estimate' die Schaetzung DIESER Karte (reference_class 'estimate-vault-S').

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_EST  = $FB_EST"

say "S2 F4 3/4  Umsetzung — F-R1-4  (esf-dev-b)"
FB_IMPL=$(k create "$S F4 3/4 — Umsetzung F-R1-4 E2E-Netz J-05 + J-06" \
    --assignee esf-dev-b \
    --workspace "worktree:$REPO" --branch "$BRANCH_FB" \
    --parent "$FB_EST" \
    --idempotency-key "s2-f4-impl" \
    --max-retries 2 --max-runtime 120m \
    --skill test-driven-development \
    --body "Setze F-R1-4 um: die Journeys J-05 und J-06 nach
specs/r1-f4-e2e-netz-j05-j06.html als Playwright-Specs bauen.

DEIN BAUM
Eigener Worktree, Branch '$BRANCH_FB'. Du mergst NICHT.

$(env_hinweis)

ACHTUNG PARALLELITAET — das ist die wichtigste Zeile dieser Karte
esf-dev-a baut GLEICHZEITIG F-R1-3 (Tastatur & Command-Palette) in einem
eigenen Worktree. Eure Beruehrungsflaeche ist tests/e2e/.
 · Du fasst tests/e2e/support/journey.ts NICHT an. Brauchst du Helfer, leg eine
   eigene Datei an (z.B. tests/e2e/support/einladung.ts).
 · Du fasst die Specs von J-02 und J-04 nicht an — die gehoeren drueben.
 · J-05 und J-06 gehoeren dir.
 · Du aenderst KEINEN Produktcode. Dieses Feature testet, es baut nicht.
   Findest du beim Testen einen echten Produktfehler: nicht beheben, sondern
   ins metadata unter 'gefunden_nicht_gemacht'. Daraus wird eine eigene Karte.

DIE HARTE REGEL DIESER KARTE
Keine Wartebedingung, die auf Wiederholung setzt. Jede Erwartung haengt an
einem sichtbaren Zustand — ein Element, ein URL-Wechsel, ein Text. Der
bestehende Helfer arbeitsbereichAnlegen enthaelt eine Schleife ueber fuenf
Versuche; sie ist gemessene Toleranz gegen ein React-Hook-Form-Rennen und
bleibt, wie sie ist. Bau keine zweite. Eine Suite, die Fehler wegwiederholt,
ist kein Regressionsnetz.

REIHENFOLGE
1. Erst den Ist-Zustand messen: die volle Suite laufen lassen, Zahl und Dauer
   notieren.
     $E2E_VORBED
     $E2E_BEFEHL
2. J-05 bauen. Das ist der schwierige Teil: zwei Konten, Einladungslink ohne
   SMTP. Die Spezifikation sagt, wie du an den Link kommst.
3. J-06 bauen.
4. Die volle Suite gruen laufen lassen — nicht nur deine beiden. Eine neue
   Spec, die eine alte umwirft, ist kein Fortschritt.
5. analysis/journeys.html im VAULT nachziehen: J-05 und J-06 tragen jetzt ihre
   Spec-Datei statt '—'. Das ist der Katalog, gegen den
   scripts/check-onboarding.sh die Abdeckung zaehlt. Vault-Format nach
   AGENTS.md 2.2 beachten.
6. Commit auf deinen Branch (Produkt-Repo) und Commit im Vault (Katalog),
   Conventional Commits in Kleinschreibung.

WENN DU NICHT DURCHKOMMST
Eine Journey gruen ist besser als zwei rot. Kommst du bei J-05 an den zwei
Konten nicht vorbei, liefere J-06 gruen und schreib bei J-05 GENAU hin, woran
es lag — welcher Schritt, welche Fehlermeldung, was du versucht hast. Das ist
dann ein Befund fuer die naechste Karte, kein Versagen.

$(metadata_pflicht 'e2e-repo-M')
Dazu ins metadata: die angelegten Dateien, das Suite-Ergebnis vor und nach
(Zahl der Tests und Dauer), ob J-05 und J-06 gruen sind, die Commit-Hashes in
Produkt-Repo UND Vault, je Akzeptanzkriterium ein Haekchen mit Beleg, und die
Liste der von dir beruehrten Dateien unter tests/.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_IMPL = $FB_IMPL"

say "S2 F4 4/4  Review — F-R1-4"
FB_REV=$(k create "$S F4 4/4 — Review F-R1-4" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$FB_IMPL" --parent "$FB_EST" \
    --idempotency-key "s2-f4-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R1-4 auf Branch '$BRANCH_FB'.

DEIN ORT
HAUPTBAUM ($REPO). Der Branch ist von einem Worktree beansprucht. Nimm
'git log/diff/show $BRANCH_FB' und lies im fremden Baum unter .worktrees/.

DIE ERSTE FRAGE IST HIER EINE ANDERE ALS SONST
Bei einem Produkt-Feature fragst du, ob die Tests den Code absichern. Hier SIND
die Tests der Liefergegenstand — also fragst du, ob sie etwas wert sind:

1. Faellt jede der beiden neuen Specs, wenn man das Feature kaputtmacht? Das
   ist die einzige Frage, die zaehlt. Pruefe sie nicht durch Nachdenken:
   Aendere im Baum des Entwicklers versuchsweise etwas, das die Journey brechen
   MUSS (ein Selektor, ein Beschriftungstext), lauf die Spec, sieh sie fallen,
   und mach die Aenderung rueckgaengig. Eine Spec, die immer gruen ist, ist
   kein Test, sondern Dekoration. Dokumentier, was du kaputtgemacht hast und
   was passiert ist.
2. Haengt jede Wartebedingung an einem sichtbaren Zustand — oder gibt es neue
   Wiederholschleifen? Die Spezifikation verbietet sie. Lies die Diffs unter
   tests/ Zeile fuer Zeile.
3. Wurde tests/e2e/support/journey.ts angefasst? Das gehoert F-R1-3 und ist ein
   Befund. 'git diff main..$BRANCH_FB --name-only'.
4. Wurde Produktcode geaendert? Diese Karte darf keinen anfassen. Auch das
   zeigt --name-only.
5. Fuehre die volle Suite SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     $E2E_VORBED
     $E2E_BEFEHL
   Nicht nur die neuen Specs — die ganze Suite.
6. Fuehrt analysis/journeys.html im Vault J-05 und J-06 jetzt mit ihrer
   Spec-Datei? Und stimmen die Dateinamen mit denen im Repo ueberein? Ein
   Katalog, der auf eine Datei zeigt, die es nicht gibt, ist die haeufigste
   Form von Scheinvollstaendigkeit.
7. Ist main unberuehrt?

Dein Urteil ist 'approved' oder 'changes_requested', im metadata unter
'verdict'. Du reparierst nichts selbst.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, Befunde, das selbst gemessene Suite-Ergebnis
(Zahlen), das Ergebnis deines Kaputtmach-Versuchs aus Punkt 1, und die Liste
der von diesem Branch beruehrten Dateien unter tests/.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_REV  = $FB_REV"

say "S2  Merge F3 am Riegel"
FA_MERGE=$(k create "$S Merge F3 — F-R1-3 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$FA_REV" --parent "$FA_EST" \
    --idempotency-key "s2-merge-f3" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R1-3 nach main — ueber den Riegel.

    $HERE/scripts/merge-riegel.sh $BRANCH_FA --protokoll $VAULT/reports/riegel-r1-f3.txt

Du bist der ERSTE von zwei Merges dieses Sprints. Danach merged eine zweite
Karte F-R1-4; sie haengt an dir, damit die beiden Riegel-Laeufe sich nicht
gegenseitig unter Last setzen.

VORBEDINGUNGEN
1. Reviewer-Urteil 'approved'. Bei 'changes_requested': NICHT mergen,
   abschliessen, neue Karte fuer die Nacharbeit.
2. Arbeitsbaum von $REPO sauber ('git status --short').
3. Postgres laeuft: $E2E_VORBED
4. Keine fremden Dev-Server auf den E2E-Ports. 'reuseExistingServer' ist an —
   ein alter Server aus einem fremden Worktree wuerde die FALSCHE Anwendung
   testen und die Suite trotzdem gruen melden. Der schwerste Messbefund des
   ersten Laufs. Pruef es, bevor du startest.

WENN ER VERWEIGERT
 · Sachgrund (Konflikt, roter Test, Linter auf neuen Zeilen) -> nicht mergen,
   abschliessen, neue Karte, Befund ins metadata.
 · Betriebsgrund (schmutziger Baum; mcp-internal-api-url.test.ts ist
   lastempfindlich) -> Ursache benennen, EINMAL sauber nachlaufen lassen, bei
   Bestehen mergen. Verweigert er erneut, ist es ein Sachgrund.

Du ueberstimmst den Riegel nicht und du benutzt kein --no-verify. Kein Modell
merged (Kapitel 6). Den Worktree des Entwicklers nicht aufraeumen — er ist Beleg.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, welche der sechs Pruefungen wie ausging,
Merge-Commit auf main, Testzahlen aus dem Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_MERGE= $FA_MERGE"

say "S2  Merge F4 am Riegel  (hängt an Merge F3 — bewusst serialisiert)"
FB_MERGE=$(k create "$S Merge F4 — F-R1-4 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$FB_REV" --parent "$FA_MERGE" --parent "$FB_EST" \
    --idempotency-key "s2-merge-f4" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R1-4 nach main — ueber den Riegel. Du bist der ZWEITE Merge
dieses Sprints; F-R1-3 liegt bereits auf main.

    $HERE/scripts/merge-riegel.sh $BRANCH_FB --protokoll $VAULT/reports/riegel-r1-f4.txt

WARUM DU AN DREI ELTERN HAENGST
An deiner Review-Karte, weil du ihr Urteil brauchst. An 'Merge F3', weil zwei
gleichzeitige Riegel-Laeufe sich unter Last setzen und eine Verweigerung ohne
Sachgrund produzieren. Und an der Schaetzkarte, damit dein (Schaetzung,
Ist)-Paar zusammenbleibt.

DAS BESONDERE AN DEINEM MERGE
Dein Branch startete von einem main OHNE F-R1-3. Inzwischen liegt es dort. Beide
Features haben unter tests/ gearbeitet — das ist die Stelle, an der ein Konflikt
zu erwarten ist. Die Listen der beruehrten Test-Dateien haben dir BEIDE
Reviewer ins metadata geschrieben. Lies sie zuerst und bilde die Schnittmenge:
 · Leere Schnittmenge -> ein Konflikt waere ueberraschend.
 · Nicht leer -> genau dort wird er auftreten, und du weisst es vorher.

Meldet der Riegel einen Konflikt: NICHT selbst aufloesen. Du bist der
Riegel-Wart, nicht der Entwickler. Abschliessen, den Konflikt genau benennen
(Dateien, Zeilen), neue Karte fuer esf-dev-b.

VORBEDINGUNGEN
1. Reviewer-Urteil 'approved'.
2. Arbeitsbaum sauber.
3. Postgres laeuft: $E2E_VORBED
4. Keine fremden Dev-Server auf den E2E-Ports.

NACH DEM MERGE — eine Pruefung, die nur du machen kannst
Auf main liegen jetzt BEIDE Features. Lauf die volle Suite noch einmal auf main
und vergleiche die Zahl der Tests mit der Summe, die du erwartest: die Suite vor
dem Sprint plus die zwei neuen Journeys aus F-R1-4. Stimmt die Zahl nicht, ist
beim Merge etwas verlorengegangen — und das faellt sonst niemandem auf.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, die sechs Pruefungen, Merge-Commit,
Testzahlen, ob ein Konflikt mit F-R1-3 auftrat, und die Zahl der Tests auf main
nach beiden Merges gegen die erwartete Zahl.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_MERGE= $FB_MERGE"

LETZTE="$FB_MERGE"
FEATURES="F-R1-3 und F-R1-4"
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
        echo "S1_WARTUNG='$WARTUNG'"
        echo "S1_SPEC='$SPEC'"
        echo "S1_EST='$EST'"
        echo "S1_IMPL='$IMPL'"
        echo "S1_REV='$REV'"
        echo "S1_MERGE='$MERGE'"
        echo "S1_BRANCH='$BRANCH'"
    else
        echo "S2_F3_SPEC='$FA_SPEC'"
        echo "S2_F3_EST='$FA_EST'"
        echo "S2_F3_IMPL='$FA_IMPL'"
        echo "S2_F3_REV='$FA_REV'"
        echo "S2_F4_SPEC='$FB_SPEC'"
        echo "S2_F4_EST='$FB_EST'"
        echo "S2_F4_IMPL='$FB_IMPL'"
        echo "S2_F4_REV='$FB_REV'"
        echo "S2_MERGE_F3='$FA_MERGE'"
        echo "S2_MERGE_F4='$FB_MERGE'"
        echo "S2_BRANCH_F3='$BRANCH_FA'"
        echo "S2_BRANCH_F4='$BRANCH_FB'"
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
