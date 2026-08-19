#!/usr/bin/env bash
#
# ESF — Phase 2: Die Sprint-Graphen von Release 1
# ==============================================
#
#   ./create-sprint.sh 1     S1 — Wartung F-R1-5 + Feature F-R1-2      (R1)
#   ./create-sprint.sh 2     S2 — F-R1-3 ∥ F-R1-4 (Tastatur · E2E-Netz) (R1)
#   ./create-sprint.sh 3     S3 — Wartung Auflage R1-c + Feature F-R1-1 (R2)
#   ./create-sprint.sh 4     S4 — F-R1-1b ∥ F-R2-1 (WeKan · MCP)        (R2)
#
# WARUM S3 OHNE EIN NEUES ROADMAP-GATE STARTET — einmal hier, damit es niemand
# neu ausdiskutieren muss. Am Release-Gate R1 (t_d85e4216) hat der Supervisor
# zugesagt: "Der Schnitt von R2 und R3 wird am naechsten Roadmap-Gate gegen
# gemessene Intervalle gemacht." Dieser Schnitt betrifft, was NEU in R2 kommt
# und wie F-R2-2/F-R2-3 zerlegt werden (Splitting-Auflage, <= 8 Karten). Er
# betrifft NICHT F-R1-1: Das Feature steht in der bereits freigegebenen
# Roadmap als Position 1 von R2, mit der ausdruecklichen Begruendung, es solle
# "auf ein kalibriertes Intervall warten, nicht es verbrauchen". Das Intervall
# gibt es jetzt (Kalibrierung S1 und S2). F-R1-1 zu starten nimmt dem
# Roadmap-Gate also nichts vorweg; F-R2-2 anzufangen wuerde es.
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
    1|2|3|4) ;;
    *) echo "Aufruf: ./create-sprint.sh 1 | 2 | 3 | 4"; exit 2 ;;
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

WARNUNG BEI MEHR ALS ZWEI ELTERN
Hat deine Karte drei Eltern, ist einer davon vermutlich nur da, um eine
REIHENFOLGE zu erzwingen (etwa "erst der andere Merge, dann du"). Er traegt
keine Zahl. Deine Schaetzung steht in der metadata der esf-estimator-Karte,
nicht in der des Reihenfolge-Elternteils. Such sie dort, bevor du abschliesst.

Gemessen am 19.08.2026 in S2, an zwei Karten derselben Art:
  Merge F3, zwei Eltern (Review + Schaetzung)          -> estimate kopiert
  Merge F4, drei Eltern (Review + Merge F3 + Schaetzung) -> estimate FEHLT ganz
Der dritte Elternteil stand nur fuer die Serialisierung der Riegel-Laeufe da
und hat den verdraengt, der die Zahl trug. check-sprint.sh S2 meldete den
zerrissenen Handoff.

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
# ⚠ IN R1 (S1, S2) NICHT AUFGERUFEN, IN S3 SCHON.
#   Das AK8 setzt eine gemeinsame Montagestelle voraus (apps/api/src/app.ts).
#   F-R1-2, F-R1-3 und F-R1-4 arbeiten an der Weboberflaeche und an tests/,
#   keines montiert Routen — ein Kriterium, das auf eine Datei zeigt, die kein
#   Branch anfasst, waere Zeremonie gewesen. F-R1-1 (Import) kann Routen
#   montieren, je nachdem wie die Spezifikation schneidet, und deshalb steht
#   `$(ak8 solo)` im Umsetzungs-Kartentext von S3.
#   Der Parameter ist noetig, weil der erste der zwei Gruende — die
#   Kollisionsfreiheit zweier Branches — in S3 nicht zutrifft: dort baut nur
#   einer. Ein Kartentext, der dem Worker eine Lage beschreibt, die es nicht
#   gibt, kostet Vertrauen in alles andere, was daneben steht.
#
# Vorgeschichte, weil sie die Regel erklaert: Das erste AK8 lautete "app.ts
# bleibt < 450 Zeilen". Die Umsetzung landete bei 565, obwohl sie die
# Zielstruktur genau befolgte — die Spezifikation forderte inhaltlich mehr, als
# 450 Zeilen fassen. Der CEO hob das Limit auf; der esf-architect ersetzte es
# und verwarf dabei den Kandidaten des CEO ("hoechstens N geaenderte Zeilen"),
# weil N wieder eine nicht abgeleitete Zahl gewesen waere. Sein Kriterium misst
# stattdessen die UEBERSCHRIEBENE FLAECHE, und das ist die Groesse, die
# Merge-Konflikte wirklich verursacht.
ak8() { # $1 = parallel|solo — nur der erste der zwei Gruende haengt daran
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
  umschreiben. Zwei rein additive Branches koennen nicht kollidieren.
EOF
case "${1:-parallel}" in
    solo) cat <<'EOF'
  In diesem Sprint baut nur ein Branch — der Schutz kostet dich hier nichts und
  gilt trotzdem, weil der naechste Sprint auf derselben Montagestelle aufsetzt.
EOF
        ;;
    *)    cat <<'EOF'
  Und in diesem Sprint baut ein zweites Feature gleichzeitig.
EOF
        ;;
esac
cat <<'EOF'
· Die Montagereihenfolge um den api.use("*", …)-Auth-Block ist
  VERHALTENSWIRKSAM (Invariante aus ADR-001). Wer sie umsortiert, aendert das
  Verhalten, ohne eine Zeile Logik anzufassen.

Lass also auch die Formatierung in Ruhe. Ein biome --write ueber die ganze
Datei waere genau der Verstoss, den dieses Kriterium verhindert: er schreibt
bestehende Zeilen um. Lintе nur, was du selbst geschrieben hast.
EOF
}

# ---------------------------------------------------------------------------
# Die Karten-IDs an den Schaetzer nachreichen (Bedingung 2a, Roadmap-Gate R2)
# ---------------------------------------------------------------------------
# Warum als Kommentar und nicht im Kartentext: Die Schaetzkarte entsteht VOR
# ihren Folgekarten — sie ist deren Elternteil, und Hermes vergibt die ID erst
# beim Anlegen. Ein Kartentext kann eine ID also nicht enthalten, die es noch
# nicht gibt. Der Kommentar-Thread ist derselbe Weg, auf dem auch die
# Gate-Antworten ankommen; der Worker liest ihn in seinem Handoff-Kontext.
schluessel_an_schaetzer() { # <estimator-id> <rolle>=<karten-id> …
    local est="$1"; shift
    local text p
    text="DIE KARTEN-IDs DEINER FOLGEKARTEN — Schluessel fuer dein estimates-Objekt.

Angehaengt vom Supervisor, weil es diese IDs beim Anlegen deiner Karte noch
nicht gab. Nimm sie woertlich als Schluessel, NICHT die Kartentitel:
"
    for p in "$@"; do
        text="$text
  ${p#*=}   fuer die Karte \"${p%%=*}\""
    done
    text="$text

Gemessen am 19.08.2026, deshalb steht das hier: Ein Schaetzer schluesselte
\"S3 F1 3/5 Umsetzung\", die Karte hiess \"S3 F1 3/5 — Umsetzung F-R1-1 Import
CSV + WeKan\". Ueber den Titel findet ledger-sync.sh nichts und die Schaetzung
faellt still aus dem Ledger — und seit dem Roadmap-Gate R2 ist DEINE Zahl die
einzige Quelle: Die Arbeitskarten kopieren sie nicht mehr, ledger-sync.sh holt
sie hier ab. Ein falscher Schluessel ist damit kein Schoenheitsfehler mehr."
    k comment "$est" --author supervisor "$text" >/dev/null
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

# ---------------------------------------------------------------------------
# Die Vorbedingung von S3: R1 muss durch sein
# ---------------------------------------------------------------------------
# S3 ist der erste Sprint von R2. Ihn zu starten, waehrend R1 noch offen ist,
# hiesse an zwei Releases gleichzeitig zu bauen — und der Riegel misst gegen
# main, das dann beiden gehoerte. Der Nachweis dafuer ist nicht "S2 ist fertig",
# sondern das beantwortete Release-Gate: Erst dort hat ein Mensch entschieden,
# dass das Paket steht.
if [ "$SPRINT" = "3" ]; then
    gate="$(k list --json 2>/dev/null | jq -r '[.[] | select(.title|startswith("GATE Release — R1"))] | last // null')"
    gstatus="$(printf '%s' "$gate" | jq -r '.status // "fehlt"')"
    if [ "$gstatus" != "done" ]; then
        printf '\nVERWEIGERT — das Release-Gate R1 steht auf \x27%s\x27, nicht auf \x27done\x27.\n' "$gstatus"
        cat <<'EOF'
S3 ist der erste Sprint von Release 2. Solange R1 nicht freigegeben ist, gehoert
main noch dem alten Paket, und ein Feature-Branch, der von dort abzweigt, traegt
dessen offene Punkte mit. Erst abschliessen:

  ./create-release.sh          Release-Abschluss + Release-Gate
  ./gate.sh                    zeigt, worauf gewartet wird
EOF
        exit 1
    fi
    printf '\n\033[32m✓\033[0m Vorbedingung erfüllt: Release-Gate R1 ist beantwortet (%s)\n' \
        "$(printf '%s' "$gate" | jq -r '.id')"
fi

# ---------------------------------------------------------------------------
# Die Vorbedingung von S4: der Neuschnitt R2 muss freigegeben sein
# ---------------------------------------------------------------------------
# S4 ist der erste Sprint NACH dem Roadmap-Gate R2. Sein Zuschnitt steht in
# roadmap/r2-freigegeben.html; ohne diese Datei baute er gegen einen Plan, den
# niemand freigegeben hat.
if [ "$SPRINT" = "4" ]; then
    if [ ! -f "$VAULT/roadmap/r2-freigegeben.html" ]; then
        cat <<'EOF'

VERWEIGERT — es gibt keine freigegebene R2-Roadmap
(roadmap/r2-freigegeben.html).

S4 setzt den Neuschnitt um, den der Supervisor am Roadmap-Gate R2 freigegeben
hat. Ohne diese Freigabe waere sein Zuschnitt eine Behauptung.

  ./create-roadmap-gate.sh R2
  ./pump.sh
  ./gate.sh
EOF
        exit 1
    fi
    printf '\n\033[32m✓\033[0m Vorbedingung: roadmap/r2-freigegeben.html liegt vor\n'
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

   DIE SCHLUESSEL SIND KARTEN-IDs, KEINE TITEL. Du findest die drei IDs als
   Kommentar an DIESER Karte — der Supervisor haengt sie an, sobald die
   Folgekarten stehen. Nimm sie woertlich.
   Warum, gemessen am 19.08.2026: Ein Schaetzer schluesselte
   'S3 F1 3/5 Umsetzung', die Karte hiess aber
   'S3 F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan'. Ueber den Titel findet
   ledger-sync.sh nichts, und die Schaetzung faellt still aus dem Ledger.
   Findest du den Kommentar nicht: schreib die Titel wie oben UND sag im
   metadata unter 'schluessel_notbehelf' hin, dass die IDs fehlten. Still
   raten ist die eine Sache, die hier nicht geht.

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
· Ist gemerged: den Worktree des Entwicklers ABRAEUMEN, den Branch behalten.
    git -C \$(git rev-parse --show-toplevel) worktree remove .worktrees/<seine-karten-id>
  Das war bis zum 19.08.2026 umgekehrt formuliert ('nicht aufraeumen, er ist
  Beleg') — und die Formulierung war falsch. Der Beleg ist die Branch-Referenz:
  Sie zeigt exakt auf den Commit, den der Riegel geprueft hat, und ueberlebt das
  Entfernen des Verzeichnisses. Das Verzeichnis selbst traegt nur zusaetzlich
  Unverfolgtes (node_modules, .env-Symlink, Testartefakte).
  Gemessen, warum es SCHADET, wenn es liegen bleibt: Am 19.08.2026 konnte die
  Wartungskarte von S3 auf main nicht committen, weil 'biome ci .' des
  Pre-Commit-Hooks in den drei liegengebliebenen Worktrees je eine
  verschachtelte biome.json fand und abbrach. Der Worker hat sie entfernt, um
  ueberhaupt arbeiten zu koennen — und tat damit genau das, was diese Zeile ihm
  auf einer ANDEREN Karte verboten hatte. Den Branch loeschst du nie.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: das Riegel-Ergebnis (bestanden/verweigert), welche der sechs
Pruefungen wie ausging, der Merge-Commit auf main, die Testzahlen aus dem
Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  MERGE= $MERGE"

schluessel_an_schaetzer "$EST" \
    "$S F2 3/5 Umsetzung=$IMPL" "$S F2 4/5 Review=$REV" "$S F2 5/5 Merge=$MERGE"
echo "  Karten-IDs an den Schaetzer $EST nachgereicht"

LETZTE="$MERGE"
FEATURES="F-R1-2 (dazu die Wartungskarte F-R1-5)"

# ===========================================================================
elif [ "$SPRINT" = "2" ]; then
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
   Karte eines, geschluesselt nach der KARTEN-ID (nicht nach dem Titel; die
   drei IDs haengen als Kommentar an dieser Karte, siehe unten) — plus unter
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
   Karte eines, geschluesselt nach der KARTEN-ID (nicht nach dem Titel; die
   drei IDs haengen als Kommentar an dieser Karte, siehe unten) — plus unter
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
merged (Kapitel 6). Den Worktree des Entwicklers nach erfolgreichem Merge
abraeumen (git worktree remove), den BRANCH aber behalten — der Branch ist der
Beleg, und ein liegengebliebener Worktree bricht den Pre-Commit-Hook des
Hauptbaums (gemessen am 19.08.2026, siehe die Merge-Karte).

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

WARUM DU AN DREI ELTERN HAENGST — und welcher davon deine Zahl traegt
An deiner Review-Karte, weil du ihr Urteil brauchst. An 'Merge F3', weil zwei
gleichzeitige Riegel-Laeufe sich unter Last setzen und eine Verweigerung ohne
Sachgrund produzieren. Und an der Schaetzkarte, damit dein (Schaetzung,
Ist)-Paar zusammenbleibt.

ACHTUNG: 'Merge F3' ist ein REIHENFOLGE-Elternteil. Er traegt keine Zahl fuer
dich. Deine Schaetzung steht in der metadata der Karte
'$S F4 2/4 — Schaetzung F-R1-4', unter estimates mit deinem Kartentitel als
Schluessel. Genau hier ist es am 19.08.2026 schiefgegangen: Die Merge-Karte mit
zwei Eltern kopierte ihre Schaetzung, die mit drei Eltern liess sie ganz weg.

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
schluessel_an_schaetzer "$FA_EST" \
    "$S F3 3/4 Umsetzung=$FA_IMPL" "$S F3 4/4 Review=$FA_REV" "$S Merge F3=$FA_MERGE"
schluessel_an_schaetzer "$FB_EST" \
    "$S F4 3/4 Umsetzung=$FB_IMPL" "$S F4 4/4 Review=$FB_REV" "$S Merge F4=$FB_MERGE"
echo "  Karten-IDs an beide Schaetzer nachgereicht"

FEATURES="F-R1-3 und F-R1-4"


# ===========================================================================
elif [ "$SPRINT" = "4" ]; then   # der erste Sprint NACH dem Neuschnitt R2
# ===========================================================================
SLUG_FA="r2-f1b-import-wekan"
SLUG_FB="r2-f2-mcp-agentenkanal"
BRANCH_FA="${PRAEFIX}esf-$SLUG_FA"
BRANCH_FB="${PRAEFIX}esf-$SLUG_FB"

# Der Zuschnitt kommt aus roadmap/r2-freigegeben.html, nicht aus diesem Skript.
# Dort steht die Reihenfolge von R2 (F-R1-1b → F-R2-1 → F-R2-2 → F-R2-4 →
# F-R2-5) und der Satz, an dem dieser Sprint haengt: "in drei weiteren Sprints
# (Plan · Umsetzung · Umsetzung) bei 1–2 Features/Sprint umsetzbar".
#
# WARUM GENAU DIESE ZWEI PARALLEL, und warum 2FA NICHT dabei ist:
#  · F-R1-1b und F-R2-1 sind beide feature-backend-M mit 97/230 min und je
#    EINER Bau-Karte. Die Klasse impl-worktree-M ist seit S3 besetzt (n=1,
#    Ist/Schaetzung 1,38) — das ist der Anker, auf den F-R1-1 in der Roadmap
#    ausdruecklich warten sollte, und er traegt jetzt zwei Features.
#  · Ihre Flaechen sind disjunkt: WeKan ist ein Schwester-Paket unter
#    packages/ auf dem geteilten kaneo-client, MCP liegt in apps/api/src/mcp.
#    Das ist dieselbe Bedingung, unter der S2 parallel getragen hat — dort war
#    die Schnittmenge der beruehrten tests/-Dateien leer.
#  · F-R2-2 (2FA) hat 262/620 min und VIER Bau-Karten. Es ist das Stueck mit
#    der leeren Referenzklasse (feature-auth-L) und der hoechsten Bruchflaeche
#    (codebase.html §6). Es laeuft allein, in einem eigenen Sprint. Zwei
#    Unbekannte gleichzeitig zu fahren verteilt den Fehler auf zwei Ursachen.
#
# NEU AB S4, und der Grund steht in roadmap/r2-freigegeben.html §5: Die
# Schaetzung wird von den Arbeitskarten NICHT mehr kopiert. ledger-sync.sh
# holt sie beim Schaetzer, aufgeloest ueber die Karten-ID (Bedingung 2a).
# Die Kartentexte verlangen sie trotzdem weiter im metadata — als Rueckfall
# und weil ein Worker, der seine eigene Schaetzung liest, besser plant. Nur
# ist ihr Ausfall jetzt kein Loch mehr im Ledger.

say "S4 F1b 1/4  Spezifikation — F-R1-1b WeKan (Abschluss von F-R1-1)"
# Der Architekt und nicht der Product Manager: Es ist die zweite Haelfte
# SEINER eigenen Spezifikation. Er hat WeKan in specs/r2-f1-… §2 als benanntes
# Folgestueck geschnitten; wer den Schnitt gemacht hat, schliesst ihn.
FA_SPEC=$(k create "$S F1b 1/4 — Spezifikation F-R1-1b WeKan-Import" \
    --assignee esf-architect \
    --workspace "dir:$VAULT" \
    --idempotency-key "s4-f1b-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere F-R1-1b: den WeKan-Teil des Imports. Das ist die zweite
Haelfte eines Features, das DU geschnitten hast — kein neues.

DEINE EIGENE VORARBEIT IST DIE GRUNDLAGE
specs/$( printf 'r2-f1-import-csv-wekan' ).html (deine Spezifikation aus S3) fuehrt WeKan
als benanntes Folgestueck. Lies zuerst, was du dort festgelegt hast, und halte
dich daran, wo es noch gilt. Wo es NICHT mehr gilt, weil der Bau etwas gezeigt
hat, schreibst du das ausdruecklich hin — ein widerlegter eigener Satz ist ein
Ergebnis, kein Makel.

WAS SEIT S3 EXISTIERT, und was du deshalb nicht neu erfindest
  packages/kaneo-client   der geteilte Client (aus planka-import extrahiert)
  packages/csv-import     das erste Schwester-Paket, mit seinen Tests
  packages/planka-import  das aeltere Vorbild
WeKan ist das dritte Paket derselben Familie. Pruef am Code nach, was der
geteilte Client heute kann und was er koennen muesste — und wenn er sich
erweitern muss, ist DAS die Architekturentscheidung dieser Karte.

DIE FRAGE, DIE DIESES FEATURE AUSMACHT
Ein WeKan-Export ist eine JSON-Datei, kein CSV. Die Abbildung ist damit
strukturell reicher (Boards, Listen, Karten, Checklisten, Kommentare,
Mitglieder) und nicht zeilenweise. Entscheide und begruende:
 · Welche Ebenen des WeKan-Modells werden abgebildet, welche nicht?
   Die Zeile 'was NICHT abbildbar ist' ist die ehrlichste jeder
   Import-Spezifikation.
 · Traegt die Abbildung aus csv-import? Oder braucht WeKan eine eigene?
   Doppelter Code ist billiger als eine falsche Abstraktion — sag, welchen
   Weg du nimmst und warum.

DER ZUSCHNITT: EINE Bau-Karte, wie die Roadmap ihn bemisst
roadmap/r2-freigegeben.html §3.1 fuehrt F-R1-1b mit 'spec + est + 1×impl-M +
review-M + merge-S', p50 97 / p90 230 min, mit dem Beleg 'Eine Bau-Karte
dieser Groesse ≈ Import-CSV (49 min Ist, t_de53e678)'. Passt dein Soll-Zustand
nicht in EINE Bau-Karte, schneide ihn kleiner und benenne den Rest als
Folgekarte. Was du bewusst liegen laesst, gehoert in die Spezifikation.

SCHREIBE specs/$SLUG_FA.html. Sie muss beantworten:
 · Der Ist-Zustand: Was traegt der geteilte Client, was traegt csv-import,
   was davon ist wiederverwendbar? Mit Fundstellen (datei.ts:zeile).
 · Die Abbildungstabelle WeKan -> Kaneo, mit der Zeile 'nicht abbildbar'.
 · Fehlerverhalten: halb durchgelaufener Import, Wiederholbarkeit. Der
   CSV-Weg hat das geloest (neues Projekt beim zweiten Lauf, das erste bleibt
   unangetastet) — gilt dasselbe, oder ist WeKan anders?
 · Was NICHT passieren darf: keine Aenderung bestehender Daten, keine
   Aenderung an der oeffentlichen API, volle Suite bleibt gruen.
 · Akzeptanzkriterien, pruefbar, einzeln abhakbar.

E2E: wie bei F-R1-1 vermutlich KEINE — begruende es, statt es wegzulassen.
Kommt doch eine Journey dazu, gehoert sie in DERSELBEN Karte in
analysis/journeys.html (Auflage a des R1-Gates).

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance als Liste, die Architekturentscheidung in einem
Satz, und was auf eine Folgekarte geht.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_SPEC = $FA_SPEC"

say "S4 F2 1/4  Spezifikation — F-R2-1 MCP-Agentenkanal"
FB_SPEC=$(k create "$S F2 1/4 — Spezifikation F-R2-1 MCP-Agentenkanal haerten" \
    --assignee esf-architect \
    --workspace "dir:$VAULT" \
    --parent "$FA_SPEC" \
    --idempotency-key "s4-f2-spec" \
    --max-retries 2 --max-runtime 45m \
    --body "Spezifiziere F-R2-1: den MCP-Agentenkanal ausbauen und haerten.

WARUM DIESE KARTE AN DER VORIGEN HAENGT
Nur der Reihenfolge wegen — ihr wird derselbe Worker zugeteilt, und zwei
gleichzeitige Auftraege an dasselbe Profil warten ohnehin aufeinander. Der
Inhalt der Elternkarte geht dich nichts an; nimm nichts von dort mit.

DER AUFTRAG AUS DER FREIGEGEBENEN ROADMAP (r2-freigegeben.html §3.1)
Nutzeraufgabe: 'Aufgaben ueber KI-Assistenten fuehren und steuern' — ohne
UI-Klicks und fragile Skripte. Marktbeleg: Kaneo ist der einzige offene,
selbst gehostete Kanal im Korpus; Linear bietet MCP nur als geschlossenes
Enterprise-Produkt (market.html §4, H1 Score 18,5). Der Kanal EXISTIERT
bereits (codebase.html Modul 10, MCP-OAuth-Store getestet) — das hier ist
Ausbau und Haertung, kein Neubau. Referenzklasse feature-backend-M,
p50 97 / p90 230 min, EINE Bau-Karte.

DEINE ERSTE PFLICHT: FESTSTELLEN, WAS DER KANAL HEUTE KANN
apps/api/src/mcp und packages/mcp. Zaehl die Werkzeuge ab, die er anbietet,
und pruefe je Werkzeug drei Dinge — mit Fundstelle:
 · Autorisierung: Prueft es die Berechtigung des Aufrufers, oder verlaesst es
   sich darauf, dass der Kanal schon der richtige ist? Das ist die Frage, aus
   der ein Sicherheitsbefund wird.
 · Eingabepruefung: Was passiert bei fehlenden oder unsinnigen Argumenten?
 · Fehlerausgabe: Bekommt der Aufrufer etwas, mit dem er weiterarbeiten kann?
Eine Aufzaehlung ohne diese drei Spalten ist eine Inhaltsangabe, keine
Analyse.

'HAERTEN' MUSS DU DEFINIEREN, sonst ist es ein Gefuehl
Aus deiner Bestandsaufnahme leitest du eine LISTE ab: was fehlt, was
gefaehrlich ist, was nur unbequem ist. Danach schneidest du: Was in EINE
Bau-Karte passt, kommt hinein; der Rest wird benannte Folgekarte. Ein
Haertungs-Feature ohne Grenze waechst, bis der Sprint reisst.

Und sag ausdruecklich, was 'ausbauen' hier NICHT heisst. Neue Werkzeuge zu
erfinden, weil sie nett waeren, ist die naheliegende Falle dieses Auftrags.

SCHREIBE specs/$SLUG_FB.html. Sie muss beantworten:
 · Die Bestandsaufnahme als Tabelle (Werkzeug | Autorisierung |
   Eingabepruefung | Fehlerausgabe | Fundstelle).
 · Die Haertungsliste, nach Schwere sortiert, mit Begruendung der Sortierung.
 · Der Schnitt: was diese Bau-Karte macht, was ausdruecklich nicht.
 · Was NICHT passieren darf: keine Aenderung am OAuth-Store ohne eigenes
   Gate, keine Aenderung an der oeffentlichen API-Oberflaeche, volle Suite
   bleibt gruen.
 · Akzeptanzkriterien, pruefbar, einzeln abhakbar.

FINDEST DU EINE ECHTE SICHERHEITSLUECKE, ist das nicht Teil dieser
Spezifikation, sondern ein eigener Befund im metadata unter 'sicherheit' —
mit Fundstelle und Auswirkung. Der Supervisor entscheidet dann, ob sie diesen
Sprint vordraengt. Sie stillschweigend in die Haertungsliste zu schieben
waere die falsche Entscheidung an der falschen Stelle.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance als Liste, die Zahl der geprueften Werkzeuge,
die Haertungsliste in Kurzform, und was auf eine Folgekarte geht.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_SPEC = $FB_SPEC"

say "S4  Schätzung — beide Features in EINER Karte"
# Ein Schaetzer, eine Karte, sechs Zahlen. Zwei Schaetzkarten haetten
# denselben Worker serialisiert und zweimal dasselbe Ledger gelesen.
EST=$(k create "$S Schätzung — F-R1-1b und F-R2-1" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$FA_SPEC" --parent "$FB_SPEC" \
    --idempotency-key "s4-estimate" \
    --max-retries 2 --max-runtime 40m \
    --body "Schaetze die sechs Folgekarten dieses Sprints — drei je Feature. Beide
Spezifikationen stehen in deinem Handoff-Kontext (specs/$SLUG_FA.html und
specs/$SLUG_FB.html).

DEINE ZAHL IST SEIT DIESEM SPRINT DIE EINZIGE QUELLE
Bis S3 haben die Arbeitskarten deine Schaetzung in ihr eigenes metadata
kopiert, und ledger-sync.sh las sie dort. Diese Kopie ist dreimal gerissen
(2 von 12 Karten, 17 %, nach zwei Nachschaerfungen unveraendert). Seit dem
Roadmap-Gate R2 holt ledger-sync.sh die Schaetzung DIREKT BEI DIR — aufgeloest
ueber die Karten-ID. Konsequenz fuer dich: Ein falscher oder fehlender
Schluessel ist kein Schoenheitsfehler mehr, sondern eine Luecke im Ledger, die
niemand mehr auffaengt. Die sechs Karten-IDs haengen als Kommentar an dieser
Karte.

DAS LEDGER TRAEGT JETZT 12 PAARE IN 7 KLASSEN. Lies es, bevor du rechnest,
und pruef bei jeder Zeile 'runs'. Zwei Karten (t_c35344ff, t_de53e678) tragen
KEINE Schaetzung — die bekannten Luecken. Nimm sie nicht als 'Istwert ohne
Schaetzung' in eine Velocity-Rechnung.

Der wichtigste Anker fuer diesen Sprint: impl-worktree-M ist seit S3 besetzt
(t_de53e678, Ist 49 min gegen p50 65). Beide Bau-Karten dieses Sprints sind
derselben Klasse, und die freigegebene Roadmap beziffert beide Features mit
p50 97 / p90 230 (r2-freigegeben.html §3.1). Diese Zahl ist eine SCHAETZUNG
DES CHIEF OF STAFF aus Kartenketten, nicht deine. Du darfst ihr folgen oder
widersprechen — aber du sagst, welches von beidem du tust, und warum.

SCHAETZE DIESE SECHS KARTEN:

  Feature   Karte        Referenzklasse     Lage im Ledger
  ---------------------------------------------------------------------------
  F-R1-1b   Umsetzung    impl-worktree-M    besetzt (n=1)
  F-R1-1b   Review       review-repo-M      besetzt (n=3)
  F-R1-1b   Merge        merge-repo-S       besetzt (n=3)
  F-R2-1    Umsetzung    impl-worktree-M    besetzt (n=1)
  F-R2-1    Review       review-repo-M      besetzt (n=3)
  F-R2-1    Merge        merge-repo-S       besetzt (n=3)

DIE BEIDEN UMSETZUNGEN SIND NICHT AUTOMATISCH GLEICH. Dieselbe Klasse heisst
nicht dieselbe Flaeche: WeKan baut ein drittes Paket nach dem Muster zweier
bestehender, MCP haertet Bestandscode mit unbekannter Zahl von Werkzeugen.
Lies beide Spezifikationen und begruende den Unterschied — oder begruende,
warum es keinen gibt. Zwei identische Zahlen ohne Begruendung sind das
Zeichen, dass nicht gelesen wurde.

DAS BUDGET-GATE HAENGT AN DEINEM P90. Ueberschreitet die Ist-Zeit das
1,5-fache, feuert es. Ein absichtlich weites Intervall macht dieses Tor stumm,
ein absichtlich enges macht es zum Fehlalarm. Schaetze, was du glaubst.

tokens_k und cost_usd: 'null'. Hermes v0.20.0 misst keine Tokens; der
OpenRouter-Zaehler laeuft je Rolle kumulativ.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-s4.html (esf-typ 'report'): die sechs Intervalle, die
   Klassen, die Ledger-Zeilen mit task_id, die Velocity-Rechnung, dein
   Verhaeltnis zur Roadmap-Zahl, und die Konfidenz je Schaetzung mit Grund.
2. Ins Abschluss-metadata ein Objekt 'estimates' mit sechs Eintraegen,
   GESCHLUESSELT NACH KARTEN-ID (Kommentar an dieser Karte) — plus unter
   'estimate' die Schaetzung DIESER Karte selbst (estimate-vault-S).

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  EST     = $EST"

say "S4 F1b 2/4  Umsetzung WeKan  (eigener Worktree)"
FA_IMPL=$(k create "$S F1b 2/4 — Umsetzung F-R1-1b WeKan-Import" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH_FA" \
    --parent "$EST" \
    --idempotency-key "s4-f1b-impl" \
    --max-retries 2 --max-runtime 150m \
    --skill test-driven-development \
    --body "Setze F-R1-1b um: den WeKan-Import nach specs/$SLUG_FA.html.

DEIN BAUM
Eigener Worktree auf Branch '$BRANCH_FA'. In diesem Sprint baut ein ZWEITES
Feature gleichzeitig (F-R2-1, MCP, in apps/api/src/mcp). Du fasst dessen
Dateien nicht an, und es fasst deine nicht an. Du mergst NICHT.

$(env_hinweis)

DEIN BESTES WERKZEUG IST DAS, WAS S3 GEBAUT HAT
packages/csv-import loest dieselbe Aufgabe fuer ein anderes Quellformat, auf
demselben geteilten packages/kaneo-client. Lies es zuerst — Trennung von
Quellformat, Abbildung und Schreibweg. Uebernimm das Muster, statt ein eigenes
zu erfinden. Wo du abweichst, gehoert ein Satz ins metadata, warum.

DIE EINZIGE HARTE REGEL
Ein Import schreibt fremde Daten in eine bestehende Instanz. Er aendert nichts
Bestehendes und loescht nichts. Fuehrt die Spezifikation an eine Stelle, an
der bestehende Daten ueberschrieben wuerden: nicht bauen, sondern Befund ins
metadata.

REIHENFOLGE
1. Erst messen: pnpm exec turbo typecheck test --force. Wieviele Tests, wie
   lange? Das ist dein Vergleichsmassstab.
2. Test zuerst. Die Abbildung WeKan -> Kaneo ist reine Funktion und damit der
   Teil, der sich am billigsten testen laesst — dort liegt auch der Fehler,
   der beim Anwender ankommt.
3. Fehlerverhalten bauen, wie die Spezifikation es festlegt. Steht es dort
   nicht: Befund ins metadata, und den einfachsten sicheren Weg waehlen.
4. Nachweis mit Zahlen:
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
   Das --force ist Pflicht: turbo spielt bei gleichem Hash das alte Ergebnis
   ab, und genau das hat am 19.08.2026 einen Reviewer ein fremdes Protokoll
   als eigene Messung melden lassen.
5. Beruehrst du eine Journey aus analysis/journeys.html, ziehst du den Katalog
   in DERSELBEN Karte nach. Beruehrst du keine, schreib das hin.
6. Commit auf deinen Branch, Conventional Commits in Kleinschreibung.

$(ak8 parallel)

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber gruen. Was du weggelassen hast, gehoert ins metadata
unter 'deliberately_not_done' mit deinem eigenen, geprueften Grund.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: geaenderte und neue Dateien, Testergebnis vor und nach
(Zahlen), E2E-Ergebnis, Zahl der neuen Tests, ob journeys.html betroffen war,
Commit-Hash, und je Akzeptanzkriterium ein Haekchen mit Beleg.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_IMPL = $FA_IMPL"

say "S4 F2 2/4  Umsetzung MCP  (eigener Worktree)"
FB_IMPL=$(k create "$S F2 2/4 — Umsetzung F-R2-1 MCP-Agentenkanal" \
    --assignee esf-dev-b \
    --workspace "worktree:$REPO" --branch "$BRANCH_FB" \
    --parent "$EST" \
    --idempotency-key "s4-f2-impl" \
    --max-retries 2 --max-runtime 150m \
    --skill test-driven-development \
    --body "Setze F-R2-1 um: den MCP-Agentenkanal haerten, nach
specs/$SLUG_FB.html.

DEIN BAUM
Eigener Worktree auf Branch '$BRANCH_FB'. In diesem Sprint baut ein ZWEITES
Feature gleichzeitig (F-R1-1b, WeKan-Import, in packages/). Du fasst dessen
Dateien nicht an, und es fasst deine nicht an. Du mergst NICHT.

$(env_hinweis)

DU HAERTEST BESTANDSCODE — das ist etwas anderes als bauen
Der Kanal funktioniert. Jede Aenderung, die du machst, kann etwas kaputt
machen, das heute jemand benutzt. Daraus folgt eine Reihenfolge, von der du
nicht abweichst:
1. Erst das REGRESSIONSNETZ, dann die Haertung. Fuer jedes Verhalten, das du
   anfasst, muss VORHER ein Test existieren, der das heutige Verhalten
   festhaelt — gruen, bevor du etwas aenderst. Ohne diesen Schritt weisst du
   hinterher nicht, ob du gehaertet oder gebrochen hast.
2. Dann die Aenderung, klein, je Befund der Spezifikation einzeln.
3. Nach jeder Aenderung die Tests.

Ein Test, der das ALTE Verhalten festhaelt und danach angepasst wird, weil das
neue anders ist, ist in Ordnung — solange die Anpassung im Commit sichtbar ist
und im metadata steht. Ein Test, der stillschweigend mitwaechst, ist kein Netz.

DIE HARTE GRENZE
Der OAuth-Store bleibt unangetastet. Die Spezifikation sagt es, und hier steht
es noch einmal: Eine Aenderung an der Authentifizierung des Kanals ist
gate-pflichtig und nicht Teil dieser Karte. Faellt dir dort etwas auf, ist das
ein Befund im metadata unter 'sicherheit', kein Bauauftrag.

REIHENFOLGE IM UEBRIGEN wie ueblich
1. Erst messen: pnpm exec turbo typecheck test --force.
2. Regressionsnetz, dann Haertung, in kleinen Schritten.
3. Nachweis mit Zahlen:
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
   Das --force ist Pflicht (turbo spielt sonst zwischengespeicherte
   Ergebnisse ab — am 19.08.2026 real passiert).
4. Beruehrst du eine Journey, ziehst du analysis/journeys.html in DERSELBEN
   Karte nach. Beruehrst du keine, schreib das hin.
5. Commit auf deinen Branch, Conventional Commits in Kleinschreibung.

$(ak8 parallel)

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber gruen. Zwei gehaertete Werkzeuge mit Netz sind ein
Ergebnis; fuenf halb gehaertete sind keins.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: geaenderte Dateien, welche Werkzeuge du gehaertet hast und
welche nicht, die Tests VOR der Haertung (das Netz) und danach mit Zahlen,
E2E-Ergebnis, Commit-Hash, je Akzeptanzkriterium ein Haekchen mit Beleg, und
alles unter 'sicherheit', was du gefunden aber nicht gebaut hast.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_IMPL = $FB_IMPL"

say "S4 F1b 3/4  Review WeKan"
FA_REV=$(k create "$S F1b 3/4 — Review F-R1-1b" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$FA_IMPL" --parent "$EST" \
    --idempotency-key "s4-f1b-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R1-1b auf Branch '$BRANCH_FA'.

DEIN ORT
HAUPTBAUM ($REPO). Von hier siehst du in die fremden Baeume unter .worktrees/
hinein. Kein 'git checkout $BRANCH_FA' — der Branch ist von einem Worktree
beansprucht und der Befehl scheitert hart. In diesem Sprint liegen ZWEI fremde
Baeume dort; sieh nach, dass du im richtigen liest.

WAS DU PRUEFST — die erste Frage ist die teuerste
1. WAS PASSIERT BEI EINEM HALB DURCHGELAUFENEN IMPORT? Geh den Weg durch.
   Pruef, ob der in der Spezifikation vorgesehene Weg im Code EXISTIERT und
   FUNKTIONIERT, nicht ob er beschrieben ist.
2. WERDEN BESTEHENDE DATEN ANGEFASST? Zeig an der Fundstelle, welche
   Schreibvorgaenge stattfinden.
3. Enthaelt die Aenderung eine Datenmigration oder Schema-Aenderung? Wenn ja:
   laeuft sie auf einer BESTEHENDEN Datenbank, ist sie ruecknehmbar? Eine
   irreversible Migration ist nach Kapitel 7 gate-pflichtig — dann ist dein
   Befund 'braucht ein Irreversibel-Gate', und das gehoert ins metadata.
   Wenn nein: schreib auch das hin, mit dem, woran du es festgemacht hast.
4. Jedes Akzeptanzkriterium einzeln, mit der Stelle, an der du es geprueft
   hast. 'Sieht erfuellt aus' ist keine Pruefung.
5. Deckt die Abbildung ab, was die Spezifikations-Tabelle sagt — und was
   passiert mit den Feldern, die sie als 'nicht abbildbar' fuehrt? Stilles
   Verschlucken ist der haeufigste Fehler eines Importers.
6. Fuehre die Tests SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
   Das --force ist nicht verhandelbar.
7. Hat sich das Feature an seinen Schnitt gehalten? Mehr gebaut als
   geschnitten ist ein Befund, kein Bonus.
8. Ist main unberuehrt?

Dein Urteil ist 'approved' oder 'changes_requested' im metadata unter
'verdict'. Du reparierst nichts selbst.

Bekannter Stoerfaktor: mcp-internal-api-url.test.ts ist lastempfindlich und
faellt reproduzierbar, wenn typecheck und test PARALLEL laufen (gemessen am
19.08.2026, auch auf sauberem Baum). Faellt genau dieser Test und sonst
nichts, lauf ihn allein nach; gruen allein ist ein Betriebsbefund.
ACHTUNG in DIESEM Sprint: Das zweite Feature haertet genau den MCP-Kanal. Ein
Fehler in dieser Datei koennte diesmal ECHT sein — er gehoert dann trotzdem
nicht dir, sondern als Befund ins metadata mit dem Hinweis auf F-R2-1.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, die Befunde, das selbst gemessene Testergebnis
(Zahlen), und ausdruecklich die Antwort auf Punkt 3.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_REV  = $FA_REV"

say "S4 F2 3/4  Review MCP"
FB_REV=$(k create "$S F2 3/4 — Review F-R2-1" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$FB_IMPL" --parent "$FA_REV" --parent "$EST" \
    --idempotency-key "s4-f2-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R2-1 auf Branch '$BRANCH_FB'.

DREI ELTERN — UND NUR EINER TRAEGT DEINE ZAHL
Deine Schaetzung steht im metadata der Schaetzkarte, nicht in dem der anderen
Review-Karte; die haengt nur dran, um euch zu serialisieren (ein Reviewer,
zwei Auftraege). Such die Zahl dort.

DEIN ORT
HAUPTBAUM ($REPO), Lesen im fremden Baum unter .worktrees/. Zwei fremde Baeume
liegen dort; sieh nach, dass du im richtigen liest.

WAS DU PRUEFST — die erste Frage ist die teuerste
1. IST DAS REGRESSIONSNETZ ECHT? Der Entwickler sollte VOR jeder Haertung
   einen Test geschrieben haben, der das heutige Verhalten festhaelt. Pruef
   das am Commit-Verlauf, nicht an seiner Erzaehlung: Kam der Test vor der
   Aenderung? Und ist er danach angepasst worden? Eine Anpassung ist erlaubt,
   wenn sie sichtbar und begruendet ist — ein Test, der stillschweigend
   mitgewachsen ist, ist kein Netz, und dann ist die ganze Karte ungedeckt.
2. IST ETWAS KAPUTT, DAS VORHER GING? Das ist die Frage, die bei Haertung an
   Bestandscode Nutzer trifft. Geh die geaenderten Werkzeuge durch und pruef
   je Werkzeug den Weg, den ein Aufrufer heute geht.
3. IST DER OAUTH-STORE UNANGETASTET? 'git diff main..$BRANCH_FB' auf die
   Auth-Pfade. Jede Aenderung dort ist gate-pflichtig und nicht Teil dieser
   Karte — dann ist dein Befund 'braucht ein Gate', nicht 'Fehler'.
4. Jedes Akzeptanzkriterium einzeln, mit Fundstelle.
5. Ist die Haertung wirklich eine? Nimm zwei der behobenen Punkte und pruef
   am Code, ob der beschriebene Angriff oder Fehlerfall jetzt wirklich nicht
   mehr geht. Eine Haertung, die nur eine Pruefung HINZUFUEGT, ohne den Weg
   daneben zu schliessen, ist keine.
6. Fuehre die Tests SELBST aus, im Baum des Entwicklers:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
7. Ist main unberuehrt?

Dein Urteil ist 'approved' oder 'changes_requested' im metadata unter
'verdict'. Du reparierst nichts selbst.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, die Befunde, das selbst gemessene Testergebnis
(Zahlen), die Antwort auf Punkt 1 (Netz echt: ja/nein, woran festgemacht) und
auf Punkt 3.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_REV  = $FB_REV"

say "S4 Merge F1b  (zuerst)"
FA_MERGE=$(k create "$S Merge F1b — F-R1-1b am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$FA_REV" --parent "$EST" \
    --idempotency-key "s4-f1b-merge" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R1-1b nach main — ueber den Riegel.

DER EINZIGE ERLAUBTE WEG
    $HERE/scripts/merge-riegel.sh $BRANCH_FA --protokoll $VAULT/reports/riegel-r2-f1b.txt

Du rufst kein 'git merge'. Sechs Pruefungen: Erreichbarkeit, Konfliktfreiheit,
Linter auf den geaenderten Dateien, Typecheck, Unit-Tests, volle E2E-Suite.

DU BIST DER ERSTE VON ZWEI MERGES in diesem Sprint. Der zweite (F-R2-1)
haengt an dir und laeuft erst danach — zwei Riegel-Laeufe gleichzeitig auf
demselben main waeren ein Rennen.

VORBEDINGUNGEN, die du selbst herstellst
1. Reviewer-Urteil 'approved'. Steht 'changes_requested': NICHT mergen,
   abschliessen, neue Karte fuer die Nacharbeit.
2. Meldet der Reviewer 'braucht ein Irreversibel-Gate': NICHT mergen. Karte
   mit Titel-Praefix 'GATE Irreversibel' anlegen, die sich selbst per
   kanban_block blockiert. Darueber entscheidet ein Mensch (Kapitel 7).
3. Arbeitsbaum von $REPO sauber ('git status --short').
4. Postgres laeuft: $E2E_VORBED
5. Keine fremden Dev-Server auf den E2E-Ports — 'reuseExistingServer' testete
   sonst die FALSCHE Anwendung und die Suite waere trotzdem gruen.

WENN ER VERWEIGERT: Sachgrund (Konflikt, roter Test, Linter auf neuen Zeilen)
-> nicht mergen, neue Karte. Betriebsgrund (schmutziger Baum,
lastempfindlicher Test) -> Ursache benennen, EINMAL sauber nachlaufen lassen.
Du ueberstimmst den Riegel nicht und benutzt kein --no-verify.

DANACH
· Das Riegel-Protokoll bleibt als Rohbeleg liegen (reports/riegel-r2-f1b.txt).
· Ist gemerged: den Worktree des Entwicklers ABRAEUMEN, den Branch behalten.
    git -C \$(git rev-parse --show-toplevel) worktree remove .worktrees/<karten-id>
  Der Beleg ist die Branch-Referenz, nicht das Verzeichnis — und ein
  liegengebliebener Worktree bricht den Pre-Commit-Hook des Hauptbaums
  (gemessen am 19.08.2026: eine verschachtelte biome.json in drei alten
  Worktrees liess 'biome ci .' abbrechen). Den Branch loeschst du nie.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, welche der sechs Pruefungen wie ausging,
Merge-Commit auf main, Testzahlen aus dem Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FA_MERGE= $FA_MERGE"

say "S4 Merge F2  (danach — serialisiert)"
FB_MERGE=$(k create "$S Merge F2 — F-R2-1 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$FB_REV" --parent "$FA_MERGE" --parent "$EST" \
    --idempotency-key "s4-f2-merge" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R2-1 nach main — ueber den Riegel, NACH F-R1-1b.

DREI ELTERN, UND NUR EINER TRAEGT DIE ZAHL
Deine Schaetzung steht im metadata der SCHAETZKARTE. Der Merge F1b haengt nur
dran, um die Reihenfolge zu erzwingen; er traegt keine Zahl fuer dich. Genau
diese Verwechslung hat am 19.08.2026 in S2 ein zerrissenes Paar erzeugt.
(Seit dem Roadmap-Gate R2 faengt ledger-sync.sh das ab, indem es die Zahl beim
Schaetzer holt — aber ins metadata gehoert sie trotzdem.)

DER EINZIGE ERLAUBTE WEG
    $HERE/scripts/merge-riegel.sh $BRANCH_FB --protokoll $VAULT/reports/riegel-r2-f2.txt

DU BIST DER ZWEITE. main hat sich seit dem Review veraendert — F-R1-1b liegt
jetzt darauf. Der Riegel prueft deshalb gegen einen anderen Stand, als der
Reviewer gesehen hat. Ein Konflikt hier ist kein Fehler des Entwicklers,
sondern die normale Folge parallelen Bauens; er ist trotzdem ein Sachgrund.
Die Flaechen sollten disjunkt sein (packages/ gegen apps/api/src/mcp) — ist
das NICHT so, gehoert die Ueberschneidung ins metadata, weil sie den Zuschnitt
des naechsten Sprints betrifft.

VORBEDINGUNGEN wie bei Merge F1b: Reviewer-Urteil 'approved'; bei 'braucht ein
Irreversibel-Gate' nicht mergen, sondern Gate-Karte; sauberer Arbeitsbaum;
Postgres laeuft ($E2E_VORBED); keine fremden Dev-Server auf den E2E-Ports.

WENN ER VERWEIGERT: Sachgrund -> nicht mergen, neue Karte. Betriebsgrund ->
benennen, EINMAL sauber nachlaufen lassen. Kein Ueberstimmen, kein --no-verify.

DANACH
· Riegel-Protokoll bleibt liegen (reports/riegel-r2-f2.txt).
· Beide Worktrees dieses Sprints ABRAEUMEN, beide Branches behalten
  (git worktree remove; der Branch ist der Beleg, das Verzeichnis bricht den
  Pre-Commit-Hook des Hauptbaums).

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: Riegel-Ergebnis, welche der sechs Pruefungen wie ausging,
Merge-Commit, Testzahlen, und ob es Konflikte gegen den neuen main gab.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  FB_MERGE= $FB_MERGE"

schluessel_an_schaetzer "$EST" \
    "$S F1b 2/4 Umsetzung=$FA_IMPL" "$S F1b 3/4 Review=$FA_REV" "$S Merge F1b=$FA_MERGE" \
    "$S F2 2/4 Umsetzung=$FB_IMPL"  "$S F2 3/4 Review=$FB_REV"  "$S Merge F2=$FB_MERGE"
echo "  Karten-IDs an den Schaetzer $EST nachgereicht"

LETZTE="$FB_MERGE"
FEATURES="F-R1-1b (WeKan) und F-R2-1 (MCP)"

# ===========================================================================
else   # SPRINT 3 — der erste Sprint von Release 2
# ===========================================================================
SLUG="r2-f1-import-csv-wekan"
BRANCH="${PRAEFIX}esf-$SLUG"

# Die Form von S3 ist die von S1 und nicht die von S2: eine Wartungskarte vor
# genau einem Feature. Zwei Gruende, und beide sind Auflagen, keine Vorlieben.
#
#  · Die Wartungskarte loest Auflage c) des Release-Gates R1 ein: "Der
#    praeexistente Palette-Keydown-Handler bekommt eine eigene Karte in R2."
#    Der Befund selbst liegt fertig analysiert im Vault
#    (reports/befund-palette-keydown.html, Karte t_2616e83d) — die Karte urteilt
#    also nicht mehr, sie baut. Ein Befund, der nur in einem Gate-Kommentar
#    steht, ist in zwei Wochen vergessen; das ist der Grund, warum die Auflage
#    ueberhaupt so formuliert wurde.
#  · Nur EIN Feature, obwohl S2 zwei parallel getragen hat. F-R1-1 ist laut
#    Roadmap "das groesste und riskanteste Stueck" des Quartals, und seine
#    Referenzklasse impl-worktree-M hat im Ledger keine einzige Zeile. Zwei
#    Unbekannte gleichzeitig zu fahren — neue Klasse UND Parallelitaet —
#    verteilt den Fehler auf zwei Ursachen, wenn es schiefgeht.
#
# Die Wartungskarte ist Elternteil der Spezifikation und nicht ihr Nachbar:
# Sie committet direkt auf main, und der Riegel misst am Ende gegen main. Ein
# Wartungs-Commit, der mitten in der Feature-Arbeit landet, macht die
# Reviewer-Frage "ist main unberuehrt?" zweideutig.

say "S3 W 1/1  Wartung — Palette-Keydown-Guard  (Auflage c des R1-Gates)"
WARTUNG=$(k create "$S W 1/1 — Wartung: Palette-Keydown-Guard" \
    --assignee esf-dev-a \
    --workspace "dir:$REPO" \
    --idempotency-key "s3-wartung-palette-keydown" \
    --max-retries 2 --max-runtime 90m \
    --body "Wartungskarte aus Auflage c) des Release-Gates R1. Kein Feature, kein
Feature-Slot: ein praeexistenter Korrektheits-Befund, der nicht aus R1 stammt und
deshalb dort nicht nachgebessert wurde.

DER BEFUND LIEGT FERTIG ANALYSIERT VOR — du urteilst nicht, du baust
$VAULT/reports/befund-palette-keydown.html (Karte t_2616e83d) hat den Befund aus
dem F-R1-3-Review nachgeprueft und als echten Defekt bestaetigt. Lies das
Dokument, bevor du anfaengst; es nennt Fundstellen mit Zeilennummern.

Der Kern, damit du weisst, worum es geht:
apps/web/src/components/command-palette/index.tsx registriert bei geoeffneter
Palette einen ZWEITEN, eigenen keydown-Zuhoerer auf document (um Z. 238–278).
Er prueft event.target nicht. Wer also in das Suchfeld der offenen Palette
'pc' tippt, oeffnet das Create-Project-Modal und schliesst die Palette — eine
Suchtexteingabe loest eine Aktion aus. Der globale Guard in
apps/web/src/hooks/use-keyboard-shortcuts.ts (um Z. 164–182) macht es richtig
und prueft INPUT/TEXTAREA/contentEditable; der paletteneigene Handler umgeht
ihn, weil er ein unabhaengiger Listener ist.

Betroffen laut Befund: pc, tc, wc, pl sowie '?' und '/'.

PRUEF DIE ZEILENNUMMERN SELBST NACH, bevor du etwas aenderst. Sie stammen vom
19.08.2026; seither ist F-R1-3 gemerged und die Datei kann sich verschoben
haben. Eine Zeilennummer aus einem fremden Bericht ist eine Behauptung, bis du
sie gesehen hast. Verschoben heisst nicht falsch — such den Handler an seiner
Mechanik (Zeichenketten-Puffer 'sequence', 700-ms-Ruecksetzer), nicht an der
Zahl.

DEIN ORT
Hauptbaum ($REPO), Branch main. Kein Worktree, kein Merge, kein Riegel: Zu
diesem Zeitpunkt arbeitet niemand sonst am Repo, und ein Ein-Zeilen-Guard ueber
einen Feature-Branch zu fuehren waere Zeremonie ohne Schutzwirkung. Du
committest direkt auf main.

$(env_hinweis)

WAS ZU TUN IST — in dieser Reihenfolge
1. Reproduzieren, BEVOR du reparierst. Der Befund nennt den Weg: Palette
   oeffnen, 'pc' in das Suchfeld tippen. Ein Fix ohne vorher gesehenen Fehler
   ist ein Fix auf Verdacht. Reproduzierst du ihn NICHT, ist genau das dein
   Ergebnis — ins metadata, mit dem, was du stattdessen beobachtet hast, und
   ohne Aenderung am Code.
2. Erst der Test, dann der Guard (test-driven, in dieser Reihenfolge). Der
   Test muss ROT sein, bevor du den Guard einbaust — sonst weisst du nicht, ob
   er den Fehler ueberhaupt trifft. Der Befund schlaegt vor: Palette oeffnen,
   'pc' und mindestens 'tc' in den CommandInput tippen, Assertion: kein Modal,
   Palette bleibt offen, das Getippte steht im Suchfeld. Ob Unit oder E2E
   entscheidest du und begruendest es im metadata; beruehrst du eine Journey,
   gilt Punkt 5.
3. Der Guard selbst: im keydown-Handler der Palette VOR der Sequenz-Bildung
   abbrechen, wenn event.target ein bearbeitbares Textelement ist. Nimm
   dieselbe Pruefung wie use-keyboard-shortcuts.ts — nicht eine zweite,
   aehnliche. Zwei Pruefungen, die dasselbe fast gleich tun, sind die naechste
   Fassung dieses Fehlers. Faellt dir dabei auf, dass sich die Pruefung sauber
   herausziehen laesst: tu es, wenn es klein bleibt, und begruende es.
4. Nachweis, alle drei, mit Zahlen:
     pnpm exec turbo typecheck test --force   -> gruen
     $E2E_VORBED
     $E2E_BEFEHL                              -> die volle Suite gruen
   Das --force ist Pflicht und kein Detail: turbo spielt bei gleichem Hash das
   alte Ergebnis ab ('>>> FULL TURBO', 170 ms), und am 19.08.2026 hat genau das
   einen Reviewer ein fremdes Protokoll als eigene Messung melden lassen.
5. Beruehrt dein Test eine Journey aus analysis/journeys.html, ziehst du den
   Katalog in DERSELBEN Karte nach — Schrittzahl und Beschreibung. Das ist
   Auflage a) desselben Gates und gilt ab jetzt fuer jede Karte. Beruehrst du
   keine, schreib das hin; die Aussage 'nicht betroffen' ist auch eine.
6. Commit auf main, Conventional Commits in Kleinschreibung (z.B.
   'fix(web): keydown-guard fuer das suchfeld der command-palette'). Der
   Pre-Commit-Hook lintet deine gestageten Dateien; umgehe ihn nicht, kein
   --no-verify.

DIE HARTE REGEL
Diese Karte behebt genau diesen einen Befund. Der Handler tut daneben noch
anderes; das bleibt, wie es ist. Faellt dir ein weiterer echter Fehler auf:
nicht beheben, sondern ins metadata unter 'gefunden_nicht_gemacht'. Daraus wird
eine eigene Karte.

$(metadata_pflicht 'maintenance-repo-S')
Dazu ins metadata: ob und wie du den Fehler reproduziert hast, der rote Test vor
dem Guard (Ausgabe!), die geaenderten Dateien, die Testzahlen vor und nach,
E2E-Ergebnis, ob du journeys.html nachgezogen hast (ja/nein und warum), der
Commit-Hash.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  WARTUNG = $WARTUNG"

say "S3 F1 1/5  Spezifikation — F-R1-1 Import CSV + WeKan"
# Der Architekt und nicht der Product Manager: F-R1-1 ist eine
# Strukturentscheidung. Ob der Import ein eigenes CLI-Paket neben
# packages/planka-import wird oder eine API-Route in apps/api, ist die Frage,
# die dieses Feature ausmacht — und sie faellt hier, nicht beim Entwickler.
SPEC=$(k create "$S F1 1/5 — Spezifikation F-R1-1 Import CSV + WeKan" \
    --assignee esf-architect \
    --workspace "dir:$VAULT" \
    --parent "$WARTUNG" \
    --idempotency-key "s3-f1-spec" \
    --max-retries 2 --max-runtime 60m \
    --body "Spezifiziere F-R1-1 der freigegebenen Roadmap: den Import aus CSV und
WeKan.

DER AUFTRAG AUS DER ROADMAP (roadmap/q1-freigegeben.html, F-R1-1)
Nutzeraufgabe: 'Team/Tool auf Kaneo umziehen' — von wochenlangem Abtippen auf
einen Importlauf. Marktbeleg: Import ist Standard bei jedem Korpus-Wettbewerber
(Vikunja 'WeKan + CSV', OpenProject 'Jira migrations', Linear-Importer),
market.html H2, Score 20. Referenzklasse feature-backend-M. Die Roadmap nennt
es das groesste und riskanteste Stueck des Quartals und setzt es genau deshalb
auf Position 1 von R2: Es sollte auf ein kalibriertes Intervall WARTEN, nicht
es verbrauchen.

DIE ENTSCHEIDENDE VORARBEIT: es gibt schon einen Importer
packages/planka-import ist ein fertiges CLI-Paket mit eigenen Tests
(args, colors, keys, mapping, migrate, planka — je eine .test.ts daneben). Lies
es, bevor du irgendetwas entwirfst. Zwei Dinge daran sind fuer deine
Entscheidung wichtiger als alles andere, und beide pruefst du selbst nach:
 · WIE es schreibt. src/kaneo.ts fuehrt eine KaneoClient-Klasse mit
   baseUrl und apiKey — der Importer geht ueber die API und nicht in die
   Datenbank. Ist das so, hat ein neuer Importer nach demselben Muster keine
   Schema-Aenderung und keine Migration. Ist es NICHT so, ist das der
   wichtigste Satz deiner Spezifikation.
 · WIE es abbildet. src/mapping.ts und src/migrate.ts enthalten die
   Uebersetzung Fremdmodell -> Kaneo (Spalten, Prioritaeten, Termine, Labels,
   Kommentare). Genau diese Uebersetzung brauchst du zweimal neu: fuer CSV und
   fuer WeKan.

DEINE ENTSCHEIDUNG, UND SIE IST DER KERN DIESER KARTE
Wird das ein zweites CLI-Paket neben planka-import? Eine Erweiterung des
bestehenden? Oder eine Route in apps/api? Entscheide, begruende, und nenne je
Alternative, was sie kostet. Ein Architekturbefund ohne die verworfenen
Alternativen ist eine Meinung.

Faellt die Entscheidung strukturell aus (neues Paket, neue Route, neues
Datenmodell), schreibst du dazu ein ADR nach dem Muster der bestehenden
(ADR-001 wird in den Kartentexten dieses Boards zitiert; sieh nach, wo sie
liegen und wie sie aussehen). Faellt sie klein aus, schreibst du KEIN ADR und
sagst warum. Beides ist richtig; nur unbegruendet ist falsch.

DER ZUSCHNITT IST TEIL DEINER ARBEIT — und hier ist er der schwierige Teil
Der Deckel liegt bei $KARTEN_DECKEL Karten je Feature; dieses Feature hat
fuenf und davon genau EINE Bau-Karte. 'CSV + WeKan' passt mit hoher
Wahrscheinlichkeit nicht in eine Bau-Karte. Dann schneidest du:
ein erster Schnitt, der traegt (etwa: CSV vollstaendig, WeKan als benanntes
Folgestueck), statt zweier halber. Was du bewusst liegen laesst, gehoert
NAMENTLICH in die Spezifikation als Folgekarte — nicht in eine stille
Auslassung, und nicht in eine Bau-Karte, die es nicht schafft.

SCHREIBE specs/$SLUG.html. Sie muss beantworten:
 · Der Ist-Zustand: Was kann planka-import heute, was davon ist
   wiederverwendbar, was nicht? Mit Fundstellen (datei.ts:zeile).
 · Der Schnitt: Was baut diese eine Bau-Karte, was ausdruecklich nicht.
 · Das Datenmodell des Imports: Welche Felder kommen aus einer CSV, welche aus
   einem WeKan-Export, worauf werden sie in Kaneo abgebildet? Eine Tabelle.
   Was NICHT abgebildet werden kann, steht mit hin — das ist die ehrlichste
   Zeile jeder Import-Spezifikation.
 · Fehlerverhalten: Was passiert bei einer halb durchgelaufenen Einspielung?
   Bricht sie ab, macht sie weiter, kann man sie wiederholen? Ein Import ohne
   beantwortete Wiederholbarkeit ist der Fehler, der beim Anwender ankommt.
 · Was NICHT passieren darf: keine Aenderung an bestehenden Daten, keine
   Aenderung an der oeffentlichen API-Oberflaeche, die volle Suite bleibt gruen.
 · Akzeptanzkriterien, pruefbar formuliert, jedes einzeln abhakbar.
   Mindestens: Typecheck gruen, Unit-Tests gruen (mit neuen Tests fuer die
   Abbildung), volle E2E-Suite unveraendert gruen.

E2E: DIE EHRLICHE ANTWORT IST VERMUTLICH 'KEINE'
Die Roadmap sagt zu F-R1-1 ausdruecklich 'keine E2E-Deckung'. Ein CLI-Importer
laeuft nicht durch den Browser, und eine Journey zu erfinden, damit die Zeile
gefuellt ist, waere Scheinabdeckung. Entscheide bewusst und schreib es hin:
Wenn keine Journey, dann warum nicht und was stattdessen den Nachweis traegt
(Unit-Tests auf der Abbildung, ein Importlauf gegen eine lokale Instanz mit
gezaehltem Ergebnis). Kommt eine Journey dazu, gehoert sie in
analysis/journeys.html — in derselben Karte, die sie einfuehrt.

$(metadata_pflicht 'spec-vault-M')
Dazu ins metadata: acceptance (die Kriterien als Liste — Entwickler und
Reviewer arbeiten beide gegen genau diese Liste), die Architekturentscheidung in
einem Satz, ob ein ADR entstanden ist, und was du vom Feature bewusst auf eine
Folgekarte geschoben hast.

$(vault_format 'spec')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  SPEC = $SPEC"

say "S3 F1 2/5  Schätzung"
EST=$(k create "$S F1 2/5 — Schätzung F-R1-1" \
    --assignee esf-estimator \
    --workspace "dir:$VAULT" \
    --parent "$SPEC" \
    --idempotency-key "s3-f1-estimate" \
    --max-retries 2 --max-runtime 30m \
    --body "Schaetze die drei Folgekarten von F-R1-1. Die Spezifikation deiner
Elternkarte (specs/$SLUG.html) steht in deinem Handoff-Kontext.

DAS LEDGER IST DEINE EINZIGE QUELLE — und es traegt jetzt echte Paare
ledger/estimates.jsonl hat nach S1 und S2 nicht mehr nur Istwerte, sondern
(Schaetzung, Ist)-Paare. Das ist der Unterschied zu den beiden Schaetzungen
davor, und er ist der ganze Zweck von Evidence-Based Scheduling: Du kannst
erstmals eine VELOCITY rechnen (Ist/Schaetzung) statt nur einen Nachbarn zu
suchen. Lies die Datei, bevor du rechnest.

Was du dort findest und was es wert ist:
  · Die Velocity-Drehung zwischen S1 und S2 ist der wichtigste Befund im
    Ledger. In S1 lag die Schaetzung um ein Vielfaches zu hoch, in S2 nahe an
    eins. Rechne beide selbst nach, statt diesen Satz zu glauben, und sag hin,
    welche der beiden Runden du fuer die tragfaehigere Grundlage haeltst — mit
    Begruendung. Wer die S1-Werte mitmittelt, schaetzt systematisch zu hoch.
  · Zwei Karten im Ledger haben KEINE Schaetzung: eine Spezifikationskarte aus
    S1 und eine Merge-Karte aus S2. Beides sind bekannte, benannte Luecken
    (zerrissener Handoff, historisch nicht heilbar, Auflage b des R1-Gates).
    Nimm sie nicht als 'Istwert ohne Schaetzung' in eine Velocity-Rechnung.
  · Pruefe bei JEDER Zeile, die du heranziehst, das Feld 'runs'. Eine Zeile mit
    runs=2 traegt einen verlorenen Lauf mit und ist als Normalfall zu hoch.

SCHAETZE DIESE DREI KARTEN, jede einzeln, jede mit ihrer Klasse:

  Karte                    Referenzklasse       Lage im Ledger
  ---------------------------------------------------------------------------
  $S F1 3/5 Umsetzung      impl-worktree-M      LEER — keine einzige Zeile
  $S F1 4/5 Review         review-repo-M        besetzt
  $S F1 5/5 Merge          merge-repo-S         besetzt

impl-worktree-M IST DIE EIGENTLICHE AUFGABE DIESER KARTE.
Die Klasse hat keine Historie. Du hast impl-worktree-S mit mehreren Zeilen und
musst den Sprung S -> M begruenden, statt ihn zu raten. Zwei Wege stehen dir
offen, und du nimmst den, den du belegen kannst:
 · Der Skalierungsfaktor aus einer anderen Klasse, die BEIDE Groessen hat.
   Sieh nach, ob es eine gibt (die E2E- und die Review-Reihe sind Kandidaten),
   rechne den Faktor aus und uebertrage ihn — mit dem ausdruecklichen Hinweis,
   dass ein aus einer Klasse uebertragener Faktor eine Annahme ist.
 · Die Flaeche aus der Spezifikation: Zahl der neuen Dateien, Zahl der
   Abbildungsregeln, Zahl der neuen Tests. Rechne von der S-Zeile hoch und
   nenne die Rechnung.
Die Konfidenz ist entsprechend niedrig, und das ist die richtige Antwort, nicht
eine schlechte. Kapitel 8: 'Klassen ohne Historie starten mit breiten
Intervallen und niedriger Konfidenz, und sagen das dem CEO.' Ein 'kann ich
nicht' waere hier falsch — eine ausgewiesene Unsicherheit ist eine Zahl.

DAS BUDGET-GATE HAENGT AN DEINEM P90, und du sollst es nicht schonen
Ueberschreitet die Ist-Zeit spaeter das 1,5-fache deines P90, feuert ein
Budget-Gate. Ein absichtlich weites Intervall macht dieses Tor stumm, ein
absichtlich enges macht es zum Fehlalarm. Schaetze, was du glaubst, und
begruende die Breite mit der Datenlage — nicht mit der Wirkung, die sie haette.

tokens_k und cost_usd: 'null'. Hermes v0.20.0 misst keine Tokens, und der
OpenRouter-Zaehler laeuft je Rolle kumulativ — je Karte gibt es keine Zahl. Ein
hineingeschriebener Wert waere die vergiftete Kalibrierung aus AGENTS.md 6.

SCHREIBE ZWEIERLEI
1. reports/schaetzung-r2-f1.html (esf-typ 'report'): die drei Intervalle, die
   Referenzklassen, die Ledger-Zeilen, auf die du dich stuetzt (task_id
   nennen!), die gerechnete Velocity aus S1 und S2 mit ihren Zahlen, die
   Herleitung des S -> M-Sprungs, und die Konfidenz je Schaetzung mit einem
   Satz, warum sie so hoch oder niedrig ist.
2. Ins Abschluss-metadata dieser Karte ein Objekt 'estimates' mit den drei
   Schaetzungen, je Karte eines, nach dem festen Schema deiner SOUL — sowie
   zusaetzlich unter 'estimate' die Schaetzung DIESER Karte selbst
   (reference_class 'estimate-vault-S').

   DIE SCHLUESSEL SIND KARTEN-IDs, KEINE TITEL. Du findest die drei IDs als
   Kommentar an DIESER Karte — der Supervisor haengt sie an, sobald die
   Folgekarten stehen. Nimm sie woertlich.
   Warum, gemessen am 19.08.2026: Ein Schaetzer schluesselte
   'S3 F1 3/5 Umsetzung', die Karte hiess aber
   'S3 F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan'. Ueber den Titel findet
   ledger-sync.sh nichts, und die Schaetzung faellt still aus dem Ledger.
   Findest du den Kommentar nicht: schreib die Titel wie oben UND sag im
   metadata unter 'schluessel_notbehelf' hin, dass die IDs fehlten. Still
   raten ist die eine Sache, die hier nicht geht.

$(metadata_pflicht 'estimate-vault-S')

$(vault_format 'report')

$(gate_verbot)" \
    --json | jq -r .id)
echo "  EST  = $EST"

say "S3 F1 3/5  Umsetzung  (eigener Worktree, eigener Branch)"
IMPL=$(k create "$S F1 3/5 — Umsetzung F-R1-1 Import CSV + WeKan" \
    --assignee esf-dev-a \
    --workspace "worktree:$REPO" --branch "$BRANCH" \
    --parent "$EST" \
    --idempotency-key "s3-f1-impl" \
    --max-retries 2 --max-runtime 150m \
    --skill test-driven-development \
    --body "Setze F-R1-1 um: den Import nach specs/$SLUG.html.

DEIN BAUM
Du arbeitest in deinem eigenen Worktree auf Branch '$BRANCH'. Kein anderer
Worker fasst diesen Branch an. Du mergst NICHT — das tut der Riegel auf einer
eigenen Karte, und kein Modell merged (Kapitel 6).

$(env_hinweis)

Die Spezifikation und die Akzeptanzkriterien stehen in deinem Handoff-Kontext;
die Datei liegt im Vault unter $VAULT/specs/$SLUG.html. Der Schnitt darin ist
verbindlich: Was dort als Folgekarte benannt ist, baust du NICHT, auch wenn es
schnell ginge. Ein Feature, das ueber seinen Schnitt hinauswaechst, macht jede
Schaetzung dieses Sprints wertlos.

DEIN BESTES WERKZEUG IST DAS BESTEHENDE PAKET
packages/planka-import loest dieselbe Aufgabe fuer eine andere Quelle, mit
Tests je Modul (args, colors, keys, mapping, migrate, planka). Lies es zuerst.
Uebernimm sein Muster — Trennung von Quellformat, Abbildung und Schreibweg —
statt ein eigenes zu erfinden. Wo du abweichst, gehoert ein Satz ins metadata,
warum.

DIE EINZIGE HARTE REGEL DIESER KARTE
Ein Import schreibt fremde Daten in eine bestehende Instanz. Er aendert nichts
Bestehendes und er loescht nichts. Findest du in der Spezifikation eine Stelle,
an der ein Import bestehende Daten ueberschreiben wuerde: nicht bauen, sondern
ins metadata als Befund. Das ist keine Entwurfsfreiheit, das ist die Grenze
zwischen 'zusaetzlich' und 'nicht zuruecknehmbar'.

REIHENFOLGE
1. Erst messen, dann bauen. Notiere den Ausgangsstand mit Zahlen:
     cd \$(git rev-parse --show-toplevel)
     pnpm exec turbo typecheck test --force
   Wieviele Tests, wie lange? Diese Zahl ist dein Vergleichsmassstab, und du
   brauchst sie am Ende noch.
2. Test zuerst, in kleinen Schritten (dafuer hast du den Skill
   test-driven-development). Die Abbildung Fremdformat -> Kaneo ist reine
   Funktion und damit der Teil, der sich am billigsten testen laesst — genau
   dort liegt auch der Fehler, der beim Anwender ankommt. Ein Import mit
   getesteter Abbildung und ungetestetem Schreibweg ist besser als umgekehrt.
3. Fehlerverhalten bauen, wie die Spezifikation es festlegt (Abbruch,
   Wiederaufnahme, Wiederholbarkeit). Steht es dort nicht: ins metadata als
   Befund, und den einfachsten sicheren Weg waehlen — lieber abbrechen und
   nichts halb einspielen.
4. Nachweis, mit Zahlen:
     pnpm exec turbo typecheck test --force   -> gruen, mit deinen neuen Tests
     $E2E_VORBED
     $E2E_BEFEHL                              -> die volle Suite unveraendert
   Die E2E-Suite ist nicht dein Nachweis, sondern dein Nicht-Kaputtmachen-
   Nachweis: Sie muss gruen bleiben, auch wenn dein Feature nicht durch den
   Browser laeuft.
5. Beruehrst du eine Journey aus analysis/journeys.html, ziehst du den Katalog
   in DERSELBEN Karte nach (Auflage a des R1-Gates). Beruehrst du keine,
   schreib das hin.
6. Commit auf deinen Branch, Conventional Commits in Kleinschreibung (z.B.
   'feat(import): csv-import mit abbildung und tests'). Der Pre-Commit-Hook
   lintet nur DEINE gestageten Dateien — er wird halten, wenn deine Zeilen
   sauber sind. Umgehe ihn nicht.

$(ak8 solo)

WENN DU NICHT DURCHKOMMST
Liefere weniger, aber gruen. Ein CSV-Import, der laeuft und getestet ist, ist
ein Ergebnis; CSV und WeKan halb fertig sind keins. Was du weggelassen hast,
gehoert ins metadata unter 'deliberately_not_done' mit deinem eigenen Grund.
Pruef, was du abschreibst.

$(metadata_pflicht 'impl-worktree-M')
Dazu ins metadata: die Liste der geaenderten und neuen Dateien, das
Testergebnis vor und nach (Zahlen!), das E2E-Ergebnis, wieviele neue Tests du
geschrieben hast, ob journeys.html betroffen war, der Commit-Hash, und je
Akzeptanzkriterium ein Haekchen mit dem Beleg.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  IMPL = $IMPL"

say "S3 F1 4/5  Review  (Hauptbaum, sieht in den fremden Worktree)"
REV=$(k create "$S F1 4/5 — Review F-R1-1" \
    --assignee esf-reviewer \
    --workspace "dir:$REPO" \
    --parent "$IMPL" --parent "$EST" \
    --idempotency-key "s3-f1-review" \
    --max-retries 2 --max-runtime 90m \
    --body "Pruefe die Umsetzung von F-R1-1 auf Branch '$BRANCH'.

DEIN ORT
Du arbeitest im HAUPTBAUM ($REPO), nicht in einem Worktree. Von hier siehst du
in die fremden Baeume unter .worktrees/ hinein. Der Branch ist bereits von einem
Worktree beansprucht — ein 'git checkout $BRANCH' im Hauptbaum scheitert hart
('fatal: ... is already used by worktree'). Nimm 'git log/diff/show $BRANCH' und
lies im fremden Baum, ohne ihn anzufassen. Genau dieser Fehler hat im ersten
Lauf eine Karte in den Circuit Breaker gefahren (RUN-PROTOKOLL.md).

WAS DU PRUEFST — in dieser Reihenfolge, weil die erste Frage die teuerste ist
1. WAS PASSIERT BEI EINEM HALB DURCHGELAUFENEN IMPORT? Geh den Weg durch:
   Einspielung startet, bricht in der Mitte ab. Was liegt jetzt in der
   Instanz, und was passiert beim zweiten Versuch — Duplikate, Fehler,
   sauberer Wiederanlauf? Pruef, ob der in der Spezifikation vorgesehene Weg im
   Code wirklich existiert und funktioniert, nicht ob er beschrieben ist. Das
   ist die einzige Frage, deren falsche Antwort beim Anwender ankommt.
2. WERDEN BESTEHENDE DATEN ANGEFASST? Ein Import ist additiv oder er ist ein
   Problem. Zeig an der Fundstelle, welche Schreibvorgaenge stattfinden.
3. Enthaelt die Aenderung eine Datenmigration oder eine Schema-Aenderung? Wenn
   ja: Laeuft sie auf einer BESTEHENDEN Datenbank, und ist sie ruecknehmbar?
   Eine irreversible Migration ist nach Kapitel 7 gate-pflichtig — dann ist dein
   Befund nicht 'Fehler', sondern 'braucht ein Irreversibel-Gate', und das
   gehoert ins metadata. Wenn nein: schreib auch das hin, mit dem, woran du es
   festgemacht hast. Beides ist ein Ergebnis.
4. Ist jedes Akzeptanzkriterium der Spezifikation erfuellt? Geh die Liste aus
   dem Handoff-Kontext einzeln durch und schreib je Kriterium hin, WORAN du es
   geprueft hast. 'Sieht erfuellt aus' ist keine Pruefung.
5. Deckt die Abbildung ab, was die Spezifikations-Tabelle sagt — und was
   passiert mit den Feldern, die sie als 'nicht abbildbar' fuehrt? Stilles
   Verschlucken ist der haeufigste Fehler eines Importers.
6. Fuehre die Tests SELBST aus, im Baum des Entwicklers. Nicht sein Protokoll
   lesen — laufen lassen:
     cd $REPO/.worktrees/<sein-verzeichnis>
     pnpm exec turbo typecheck test --force
     $E2E_VORBED
     $E2E_BEFEHL
   Das --force ist nicht verhandelbar: Ohne es antwortet turbo mit dem
   zwischengespeicherten Protokoll des Entwicklers, und du meldest seine
   Messung als deine. Am 19.08.2026 real passiert.
7. Hat sich das Feature an seinen Schnitt gehalten? Die Spezifikation benennt,
   was auf eine Folgekarte geschoben wurde. Mehr gebaut als geschnitten ist ein
   Befund, kein Bonus.
8. Ist main unberuehrt? 'git log main..' und der Arbeitsbaum-Status.

WENN ETWAS FEHLT
Dein Urteil ist 'approved' oder 'changes_requested', im metadata unter
'verdict', mit den Befunden als Liste. Bei 'changes_requested' beschreibt jeder
Befund, WAS zu tun ist, nicht dass etwas nicht stimmt. Du reparierst nichts
selbst — dann waere niemand mehr da, der prueft.

Ein bekannter Stoerfaktor, damit du ihn nicht als Befund missdeutest:
mcp-internal-api-url.test.ts ist lastempfindlich. Faellt genau dieser Test und
sonst nichts, lauf ihn allein nach; gruen allein und rot unter Last ist ein
Betriebsbefund, kein Fehler des Entwicklers. Notier ihn als solchen.

$(metadata_pflicht 'review-repo-M')
Dazu ins metadata: verdict, die Befunde, das selbst gemessene Testergebnis
(Zahlen), und ausdruecklich die Antwort auf Punkt 3 — Migration ja/nein und
woran festgemacht.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  REV  = $REV"

say "S3 F1 5/5  Merge am Riegel"
MERGE=$(k create "$S F1 5/5 — Merge F-R1-1 am Riegel" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$REV" --parent "$EST" \
    --idempotency-key "s3-f1-merge" \
    --max-retries 2 --max-runtime 90m \
    --body "Bringe F-R1-1 nach main — ueber den Riegel, nicht mit der Hand.

DER EINZIGE ERLAUBTE WEG
    $HERE/scripts/merge-riegel.sh $BRANCH --protokoll $VAULT/reports/riegel-r2-f1.txt

Du rufst kein 'git merge'. Der Riegel merged oder verweigert; das ist der
Unterschied zwischen einer Regel und einem Riegel (Kapitel 6). Sechs Pruefungen:
Erreichbarkeit, Konfliktfreiheit, Linter auf den geaenderten Dateien, Typecheck,
Unit-Tests, volle E2E-Suite.

DEINE SCHAETZUNG STEHT IM HANDOFF DER ESTIMATOR-KARTE, nicht in dem der
Review-Karte. Diese Karte hat zwei Eltern, und nur einer traegt die Zahl. In S2
ist genau das an einer Merge-Karte mit drei Eltern schiefgegangen; die Luecke
steht bis heute im Ledger. Auflage b) des Release-Gates R1 verlangt, dass
check-sprint.sh in DIESEM Sprint auf Pruefung 3 gruen ist. Diese Karte ist die,
an der es zuletzt gerissen ist.

VORBEDINGUNGEN, die du selbst herstellst — sonst verweigert er ohne Sachgrund
1. Das Urteil des Reviewers muss 'approved' sein. Steht 'changes_requested' in
   deinem Handoff-Kontext: NICHT mergen. Schliesse ab mit dem Befund im
   metadata und lege eine neue Karte fuer die Nacharbeit an.
2. Meldet der Reviewer 'braucht ein Irreversibel-Gate': NICHT mergen. Schliess
   ab mit dem Befund und leg eine Gate-Karte an — Titel-Praefix
   'GATE Irreversibel', sie blockiert sich selbst per kanban_block. Nach
   Kapitel 7 entscheidet darueber ein Mensch, nicht der Riegel und nicht du.
3. Der Arbeitsbaum von $REPO muss sauber sein. Im ersten Lauf verweigerte der
   Riegel, weil dort uncommittete Fremdaenderungen lagen — eine Verweigerung
   ohne Sachbezug. 'git status --short' zuerst; ist er schmutzig und nicht deine
   Schuld, notier das und melde es, statt aufzuraeumen.
4. Postgres muss laufen: $E2E_VORBED
5. Es duerfen keine fremden Dev-Server auf den E2E-Ports stehen. Die
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
· Das Riegel-Protokoll bleibt als Rohbeleg liegen (reports/riegel-r2-f1.txt,
  .txt und nicht .html — AGENTS.md 2.1 nimmt Maschinenprotokolle aus der
  HTML-Pflicht aus).
· Ist gemerged: den Worktree des Entwicklers ABRAEUMEN, den Branch behalten.
    git -C \$(git rev-parse --show-toplevel) worktree remove .worktrees/<seine-karten-id>
  Das war bis zum 19.08.2026 umgekehrt formuliert ('nicht aufraeumen, er ist
  Beleg') — und die Formulierung war falsch. Der Beleg ist die Branch-Referenz:
  Sie zeigt exakt auf den Commit, den der Riegel geprueft hat, und ueberlebt das
  Entfernen des Verzeichnisses. Das Verzeichnis selbst traegt nur zusaetzlich
  Unverfolgtes (node_modules, .env-Symlink, Testartefakte).
  Gemessen, warum es SCHADET, wenn es liegen bleibt: Am 19.08.2026 konnte die
  Wartungskarte von S3 auf main nicht committen, weil 'biome ci .' des
  Pre-Commit-Hooks in den drei liegengebliebenen Worktrees je eine
  verschachtelte biome.json fand und abbrach. Der Worker hat sie entfernt, um
  ueberhaupt arbeiten zu koennen — und tat damit genau das, was diese Zeile ihm
  auf einer ANDEREN Karte verboten hatte. Den Branch loeschst du nie.

$(metadata_pflicht 'merge-repo-S')
Dazu ins metadata: das Riegel-Ergebnis (bestanden/verweigert), welche der sechs
Pruefungen wie ausging, der Merge-Commit auf main, die Testzahlen aus dem
Riegel-Lauf.

$(gate_verbot)" \
    --json | jq -r .id)
echo "  MERGE= $MERGE"

schluessel_an_schaetzer "$EST" \
    "$S F1 3/5 Umsetzung=$IMPL" "$S F1 4/5 Review=$REV" "$S F1 5/5 Merge=$MERGE"
echo "  Karten-IDs an den Schaetzer $EST nachgereicht"

LETZTE="$MERGE"
FEATURES="F-R1-1 (dazu die Wartungskarte aus Auflage c des R1-Gates)"
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
    elif [ "$SPRINT" = "2" ]; then
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
    elif [ "$SPRINT" = "3" ]; then
        echo "S3_WARTUNG='$WARTUNG'"
        echo "S3_F1_SPEC='$SPEC'"
        echo "S3_F1_EST='$EST'"
        echo "S3_F1_IMPL='$IMPL'"
        echo "S3_F1_REV='$REV'"
        echo "S3_F1_MERGE='$MERGE'"
        echo "S3_BRANCH='$BRANCH'"
    elif [ "$SPRINT" = "4" ]; then
        echo "S4_F1B_SPEC='$FA_SPEC'"
        echo "S4_F2_SPEC='$FB_SPEC'"
        echo "S4_EST='$EST'"
        echo "S4_F1B_IMPL='$FA_IMPL'"
        echo "S4_F2_IMPL='$FB_IMPL'"
        echo "S4_F1B_REV='$FA_REV'"
        echo "S4_F2_REV='$FB_REV'"
        echo "S4_MERGE_F1B='$FA_MERGE'"
        echo "S4_MERGE_F2='$FB_MERGE'"
        echo "S4_BRANCH_F1B='$BRANCH_FA'"
        echo "S4_BRANCH_F2='$BRANCH_FB'"
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
case "$SPRINT" in
1) cat <<EOF
  ./create-sprint.sh 2               erst NACH 'Kalibrierung S1' — das Skript prüft es
EOF
   ;;
2) cat <<EOF
  ./create-release.sh                Release-Abschluss + Release-Gate
EOF
   ;;
4) cat <<EOF
  ./create-sprint.sh 5               der naechste R2-Sprint (F-R2-2 2FA, allein:
                                     vier Bau-Karten, feature-auth-L ist leer)
EOF
   ;;
3) cat <<EOF
  Danach: der Release-Abschluss R2 — aber NICHT mit ./create-release.sh in
  seiner heutigen Fassung. Das Skript hat R1 fest verdrahtet (Kartentitel,
  Report-Namen, Gate-Text) und nimmt kein Argument. Es auf R2 zu parametrisieren
  ist eine eigene Aufgabe und gehoert VOR den Abschluss, nicht mittendrin.

  Und wenn das R2-Gate steht, gilt die Reihenfolge des Schattenbetriebs — sie
  ist zwingend und laesst sich nicht nachholen (VERIFIKATION.md, Phase 3):

     Gate blockiert -> ceo-tick (legt die Entscheidungskarte an)
                    -> pump.sh  (esf-ceo schreibt das Dokument)
                    -> ceo-tick (validiert: 'schatten-validiert')
                    -> DANN erst gate.sh (der Supervisor antwortet)
                    -> ceo-tick (Nachlese: 'schatten-vergleich')

  Antwortet der Supervisor frueher, gibt es fuer dieses Gate nie einen
  Vergleich, und es ist fuer den Stufe-B-Nachweis verbraucht.
EOF
   ;;
esac
