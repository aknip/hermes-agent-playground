#!/usr/bin/env bash
#
# ESF — Phase 1: Der Onboarding-Analysegraph
# ==========================================
#
#   ./create-onboarding.sh
#
# Läuft einmalig beim Aufsetzen auf ein Repo. Fan-out in drei Analysen, die
# einander nicht brauchen, dann zwei Fan-ins:
#
#   1 Codebasis   (esf-architect)        ─┐
#   2 Produkt     (esf-product-manager)  ─┼─▶ 4 E2E-Ausbau (esf-qa-release)
#   3 Markt       (esf-market-analyst)   ─┘        └─▶ 5 Roadmap (chief-of-staff)
#                                                          └─▶ 6 GATE an den CEO
#
# Karte 4 hängt an 1+2, weil die Kern-Journeys aus der Produktanalyse kommen
# und ihre technische Machbarkeit aus der Codebasis-Analyse. Karte 5 ist der
# Fan-in über alles. Karte 6 ist das Gate — eine eigene Karte, damit die
# Wartezeit auf den Menschen die Messwerte der Arbeitskarten nicht verfälscht.
#
# Alle Analysekarten laufen im Firmen-Vault (dir:), nicht im Produkt-Repo:
# Sie schreiben Dokumente, keinen Code. Nur Karte 4 fasst das Produkt-Repo an.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="sw-company"
VAULT="$HERE/workspace/company"
IDS="$HERE/task-ids-onboarding.env"
HEUTE="$(date '+%Y-%m-%d')"

command -v jq >/dev/null || { echo "FEHLER: 'jq' fehlt"; exit 1; }
[ -d "$VAULT" ] || { echo "FEHLER: Kein Vault. Erst ./setup.sh"; exit 1; }

REPO="$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
PRODUKT="$(sed -n 's/^[[:space:]]*name:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
E2E_DIR="$(sed -n 's/^[[:space:]]*e2e_verzeichnis:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
E2E_BEFEHL="$(sed -n 's/^[[:space:]]*e2e_befehl:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"
E2E_VORBED="$(sed -n 's/^[[:space:]]*e2e_vorbedingung:[[:space:]]*//p' "$VAULT/cadence.yaml" | head -1)"

k() { hermes kanban --board "$BOARD" "$@"; }
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

KORPUS="$(ls -d "$VAULT"/sources/*/ 2>/dev/null | tail -1)"
if [ -z "$KORPUS" ]; then
    printf '\033[33m⚠ Es gibt keinen Markt-Korpus unter sources/.\033[0m\n'
    printf '  Karte 3 (Marktbild) wird blockieren, und das ist richtig so —\n'
    printf '  der Analyst hat keinen Webzugriff und darf nichts erfinden.\n'
    printf '  Korpus anlegen:  seed/company/sources/%s/  dann ./reset-workspace.sh\n' "$HEUTE"
    printf '  Trotzdem fortfahren? [j/N] '
    read -r antwort
    case "$antwort" in j|J|y|Y) ;; *) echo "Abgebrochen."; exit 0 ;; esac
    KORPUS_REL="sources/ (leer)"
else
    KORPUS_REL="sources/$(basename "$KORPUS")"
fi

say "Produkt: $PRODUKT"
echo "  Repo:   $REPO ($(git -C "$REPO" rev-parse --short HEAD))"
echo "  Korpus: $KORPUS_REL"
echo "  Vault:  $VAULT"

# ---------------------------------------------------------------------------
say "1/6  Codebasis-Analyse"
# ---------------------------------------------------------------------------
CODE=$(k create "Onboarding 1/6 — Codebasis-Analyse" \
    --assignee esf-architect \
    --workspace "dir:$VAULT" \
    --idempotency-key "onboarding-codebase-$HEUTE" \
    --max-retries 2 --max-runtime 45m \
    --body "Analysiere die Codebasis von $PRODUKT unter

    $REPO

Du liest dort, du änderst dort NICHTS. Dein Arbeitsverzeichnis ist der Vault.

WAS DER BERICHT BEANTWORTEN MUSS
  · Architektur: Welche Anwendungen und Pakete gibt es, wie hängen sie
    zusammen, wo liegt die Grenze zwischen Frontend, API und Datenhaltung?
  · Modulkarte: Die 8-15 wichtigsten Module mit je einem Satz, was sie tun.
  · Technischer Stand: Sprache, Framework, Build, Paketmanager, Datenbank,
    Testwerkzeuge — jeweils mit der Datei, in der du es gesehen hast.
  · Testabdeckung: Was gibt es an Tests, welcher Art, was ist NICHT abgedeckt.
  · Technische Schulden: Was fällt auf? Sei konkret und belege es.
    Ein Hinweis, den du prüfen solltest: 'pnpm exec biome ci .' ist auf dem
    Ausgangs-Commit bereits rot. Stelle fest, in welcher Grössenordnung und ob
    das Bestandsschuld oder ein Konfigurationsproblem ist.
  · Wo eine Änderung riskant ist und warum.

BELEGE
Jede strukturelle Aussage zitiert Datei und Zeile ('apps/api/src/index.ts:209').
'Die API benutzt Framework X' ohne Fundstelle ist eine Vermutung. Der Maßstab
aus AGENTS.md 3.1: Ein Leser prüft jede Behauptung in unter einer Minute nach.

SCHREIBE nach analysis/codebase.html — Format nach AGENTS.md 2.2, esf-typ
'analyse', esf-karte deine Karten-ID. Der Vault-Linter prüft das.

Diese Analyse ist die Grundlage jeder späteren Schätzung. Lieber ein
Abschnitt weniger, dafür jeder belegt." \
    --json | jq -r .id)
echo "  ONB_CODE   = $CODE"

# ---------------------------------------------------------------------------
say "2/6  Produkt- und Nutzeranalyse"
# ---------------------------------------------------------------------------
PROD=$(k create "Onboarding 2/6 — Produkt- und Nutzeranalyse" \
    --assignee esf-product-manager \
    --workspace "dir:$VAULT" \
    --idempotency-key "onboarding-product-$HEUTE" \
    --max-retries 2 --max-runtime 45m \
    --body "Analysiere, was $PRODUKT für wen tut. Das Repo liegt unter

    $REPO

Material: README.md, die Dokumentation unter apps/docs bzw. apps/site, die
Oberfläche unter apps/web/src (Routen und Komponenten verraten, welche
Aufgaben die Software überhaupt anbietet), i18n/en-US.json (die Beschriftungen
sind die Sprache des Produkts) und CHANGELOG.md.

WAS DER BERICHT BEANTWORTEN MUSS
  · Für wen ist das gebaut? Welche Rolle, welcher Arbeitskontext?
  · Welche KERN-AUFGABEN erledigt ein Anwender damit? Formuliere jede als
    Nutzeraufgabe, nicht als Feature: 'einen Vorgang einem Kollegen zuweisen',
    nicht 'Assignee-Dropdown'.
  · Für jede Kernaufgabe: Wie viele Schritte braucht sie heute? Wo ist es
    umständlich? Zähle die Schritte, rate sie nicht — geh durch die Routen und
    Komponenten.
  · Was verspricht das Produkt (README, Website) und wo hält die Oberfläche
    das nicht ein?
  · Die 5-8 wichtigsten Kern-Journeys, priorisiert. Das ist der Teil, aus dem
    die E2E-Suite gebaut wird — benenne jede so, wie ein Anwender sie nennen
    würde, und beschreibe ihre Schritte.

Vorhanden ist bereits eine winzige E2E-Suite mit zwei Journeys (J-00
Anwendung erreichbar, J-01 Konto anlegen) unter $E2E_DIR. Nimm sie als
gegeben und schlage vor, was daneben gehört — nicht, was sie ersetzt.

SCHREIBE nach analysis/product.html — Format nach AGENTS.md 2.2, esf-typ
'analyse'. Die Journey-Liste bekommt eine eigene, klar erkennbare Tabelle:
Name, Nutzeraufgabe, Schritte heute, Priorität." \
    --json | jq -r .id)
echo "  ONB_PROD   = $PROD"

# ---------------------------------------------------------------------------
say "3/6  Marktbild"
# ---------------------------------------------------------------------------
MARKT=$(k create "Onboarding 3/6 — Marktbild" \
    --assignee esf-market-analyst \
    --workspace "dir:$VAULT" \
    --idempotency-key "onboarding-market-$HEUTE" \
    --max-retries 2 --max-runtime 45m \
    --body "Erstelle das erste Marktbild für $PRODUKT.

DEIN KORPUS IST $KORPUS_REL — und nur der.
Du hast keinen Webzugriff. Was dort nicht steht, weisst du nicht. 'Ich erinnere
mich, dass Wettbewerber X das kann' ist keine Quelle, sondern Kontamination.
Fehlt dir Material für eine Aussage, die du für wichtig hältst: benenne genau,
welche Quelle du bräuchtest, und markiere die Lücke im Bericht.

WAS DER BERICHT BEANTWORTEN MUSS
  · Wer sind die Wettbewerber im Korpus, und wie positionieren sie sich?
  · Was ist Kategoriestandard — also das, was ein Käufer 2026 voraussetzt?
  · Wo hat $PRODUKT eine Lücke gegenüber diesem Standard?
  · Wo ist $PRODUKT bewusst anders, und trägt diese Entscheidung?
  · Die 5-8 stärksten Feature-Hypothesen, jede mit: Nutzenargument (welche
    Nutzeraufgabe wird einfacher), Beleg aus dem Korpus, Score nach der Rubrik
    in cadence.yaml mit einem Satz Begründung je Dimension, und der Bedingung,
    unter der die Hypothese falsch wäre.

Die Rubrik, die Schwelle und der Mengen-Deckel stehen in cadence.yaml unter
'rubrik'. Lies sie dort. Halte dich an max_pro_lauf.

SCHREIBE nach analysis/market.html — Format nach AGENTS.md 2.2, esf-typ
'analyse'. Jede Marktaussage zitiert ihre Korpusdatei." \
    --json | jq -r .id)
echo "  ONB_MARKT  = $MARKT"

# ---------------------------------------------------------------------------
say "4/6  E2E-Grundgerüst ausbauen  (Fan-in auf 1+2)"
# ---------------------------------------------------------------------------
E2E=$(k create "Onboarding 4/6 — E2E-Suite über die Kern-Journeys" \
    --assignee esf-qa-release \
    --workspace "dir:$REPO" \
    --parent "$CODE" --parent "$PROD" \
    --idempotency-key "onboarding-e2e-$HEUTE" \
    --max-retries 2 --max-runtime 90m \
    --body "Baue die E2E-Suite von $PRODUKT über die Kern-Journeys aus.

Du arbeitest DIREKT im Produkt-Repo ($REPO), nicht in einem Worktree: Das
Testgerüst ist Infrastruktur für alle folgenden Features, nicht ein Feature.

WAS SCHON DA IST — lies es zuerst, es ist dein Vorbild:
  playwright.config.ts             Konfiguration, startet API und Web selbst
  $E2E_DIR/anwendung-erreichbar.spec.ts   J-00
  $E2E_DIR/konto-anlegen.spec.ts          J-01
  tests/e2e/support/journey.ts     neueIdentitaet, kontoAnlegen, arbeitsbereichAnlegen

Zwei Fallen, die dort schon dokumentiert sind und dich sonst kosten:
  · Das Passwort-Label zeigt per 'for' auf den Wrapper-<div>, nicht aufs
    <input>. getByLabel('Password') liefert ein nicht befüllbares Element —
    nimm input[name=\"password\"].
  · Ein frisches Konto landet auf /onboarding, nicht auf /dashboard. Erst nach
    'Arbeitsbereich anlegen' geht es weiter.

AUFTRAG
1. Nimm die Kern-Journeys aus analysis/product.html deiner Elternkarte (sie
   stehen als Tabelle in deinem Handoff-Kontext).
2. Schreibe für die WICHTIGSTEN davon je einen Spec unter $E2E_DIR/<slug>.spec.ts.
   Fang mit den drei bis vier wichtigsten an. Lieber vier Journeys, die
   wirklich grün laufen, als acht, die halb fertig sind — eine rote Suite ist
   schlimmer als eine kleine.
3. Jeder Spec spielt EINE Nutzeraufgabe in sichtbaren Schritten nach, mit
   nummerierten Schritt-Kommentaren wie in den vorhandenen Specs. Er testet
   die Aufgabe, nicht die Implementierung.
4. Lauf die ganze Suite, bis sie grün ist:
     cd $REPO
     $E2E_VORBED
     $E2E_BEFEHL
   Ein Spec, den du nicht grün bekommst, wird NICHT abgeliefert. Nimm ihn
   heraus und schreib in den Katalog, woran es lag — das ist ein ehrliches
   Ergebnis und ein Auftrag für später.

   Sobald sie grün ist, zeichne sie auf (AGENTS.md 8.2 — jeder grüne Lauf
   bekommt seine Video-Akte, sofort und unabhängig von einem Merge):
     $HERE/scripts/e2e-video.sh --alle --anlass onboarding-aufbau
   Das ist der erste sichtbare Durchlauf des Produkts, den die Organisation
   besitzt. Er läuft headless und dauert so lange wie die Suite selbst.
5. Schreibe den Journey-Katalog nach $VAULT/analysis/journeys.html:
   je Journey Name, Nutzeraufgabe, Spec-Dateiname, Schrittzahl, Priorität.
   Die Schrittzahl ist die UX-Metrik der Organisation — zähle die sichtbaren
   Schritte, nicht die Codezeilen.

   Diese Datei liegt im VAULT und muss dessen Format einhalten, auch wenn du
   im Produkt-Repo arbeitest. Der Kopf ist Pflicht, sonst weist der
   Vault-Linter die Datei ab und Phase 1 gilt als unfertig:

     <!doctype html>
     <html lang=\"de\">
     <head>
       <meta charset=\"utf-8\">
       <title>Journey-Katalog — ESF</title>
       <meta name=\"esf-typ\" content=\"katalog\">
       <meta name=\"esf-karte\" content=\"<deine Karten-ID>\">
       <meta name=\"esf-datum\" content=\"$HEUTE\">
     </head>

   ACHTUNG: Der Katalog darf nur Specs nennen, die es wirklich gibt.
   check-onboarding.sh prüft jeden genannten Dateinamen gegen das Dateisystem.
6. Committe im Produkt-Repo auf main. Der Merge-Riegel gilt für Feature-
   Branches; dies ist Testinfrastruktur und geht direkt.
   Der Pre-Commit-Hook des Repos lintet nur die Dateien, die DU änderst — er
   wird also halten, wenn deine Specs sauber sind. Umgehe ihn nicht; wenn er
   meckert, sind es deine Zeilen. Die Commit-Nachricht braucht das
   Conventional-Commits-Format in Kleinschreibung (z.B.
   'test(e2e): journeys fuer projekt- und aufgabenverwaltung').

metadata: die Liste der angelegten Specs, die Schrittzahlen, das Testergebnis
(bestanden/gesamt) und was du bewusst weggelassen hast." \
    --json | jq -r .id)
echo "  ONB_E2E    = $E2E"

# ---------------------------------------------------------------------------
say "5/6  Erste Roadmap  (Fan-in über alles)"
# ---------------------------------------------------------------------------
ROADMAP=$(k create "Onboarding 5/6 — Erste Roadmap mit Schätzintervallen" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$MARKT" --parent "$E2E" \
    --idempotency-key "onboarding-roadmap-$HEUTE" \
    --max-retries 2 --max-runtime 60m \
    --body "Schreibe die erste Roadmap für $PRODUKT.

GRUNDLAGE — lies alle vier, sie liegen im Vault:
  analysis/codebase.html   was technisch möglich und was riskant ist
  analysis/product.html    welche Nutzeraufgaben es gibt und wo es hakt
  analysis/market.html     die bewerteten Feature-Hypothesen
  analysis/journeys.html   was die E2E-Suite heute abdeckt

Die Mengen-Limits stehen in cadence.yaml: max. 3 Releases je Quartal, max. 5
Features je Release, max. 4 Sprints je Release, max. 8 Karten je Feature. Halte
sie ein. Ein Plan, der die Limits sprengt, ist kein ehrgeiziger Plan, sondern
ein ungeprüfter.

AUFBAU DER ROADMAP
  · Quartal Q1 mit bis zu drei Releases, je Release bis zu fünf Features.
  · Je Feature: Name, welche Nutzeraufgabe einfacher wird, Marktbeleg oder
    Produktbefund, betroffene E2E-Journey (vorhandene erweitern oder neue).
  · Je Feature ein Schätzintervall. Du schätzt NICHT selbst — das Ledger ist
    leer, also gibt es noch keine Referenzklassen. Trage deshalb je Feature
    eine Referenzklasse ein (z.B. 'feature-frontend-M') und vermerke
    ausdrücklich: 'ohne Historie, breites Intervall, Konfidenz < 0.3'. Der
    esf-estimator ersetzt das, sobald das Ledger trägt. Eine erfundene Zahl mit
    scheinbarer Präzision wäre der schlimmere Fehler.
  · Ein Abschnitt 'Was wir NICHT machen' mit Begründung. Er ist der
    wertvollste Teil der Roadmap.
  · Ein Abschnitt zur Subtraktion: Welche Journey hat laut journeys.html die
    höchste Schrittzahl, und lohnt sich eine Vereinfachung?

SCHREIBE nach roadmap/q1-entwurf.html — Format nach AGENTS.md 2.2, esf-typ
'roadmap'.

Du legst in dieser Karte KEINE Arbeitskarten an. Die Roadmap ist ein Entwurf,
bis der CEO sie freigegeben hat; Karten für nicht freigegebene Features wären
Arbeit auf Verdacht.

Schliesse sofort danach mit kanban_complete ab — die Gate-Karte hängt an dir." \
    --json | jq -r .id)
echo "  ONB_ROADMAP= $ROADMAP"

# ---------------------------------------------------------------------------
say "6/6  Das Roadmap-Gate"
# ---------------------------------------------------------------------------
# Eigene Karte — zwei Gründe: Die Gate-Arithmetik (BLOCK_RECURRENCE_LIMIT = 2
# je kind) lässt je Karte nur zwei menschliche Fragen zu, und die Wartezeit auf
# den Menschen soll die Laufzeitmessung der Arbeitskarten nicht verfälschen.
GATE=$(k create "GATE Roadmap — Q1-Freigabe" \
    --assignee esf-chief-of-staff \
    --workspace "dir:$VAULT" \
    --parent "$ROADMAP" \
    --idempotency-key "onboarding-gate-$HEUTE" \
    --max-retries 2 --max-runtime 30m \
    --body "Lege dem CEO die Roadmap zur Freigabe vor.

ERSTER LAUF
1. Lies roadmap/q1-entwurf.html deiner Elternkarte.
2. Blockiere dich SELBST:  kanban_block(kind=\"needs_input\", reason=\"…\")

   Die Vorlage hat genau acht Zeilen, jede eine:

     1 Was ansteht        — Q1-Roadmap für $PRODUKT: N Releases, M Features
     2 Beleg              — worauf sie beruht (Marktbild, Produktanalyse)
     3 Die Top-Features   — die drei wichtigsten in je vier Worten
     4 Was NICHT gemacht wird — und warum
     5 Kosten             — Schätzintervall gesamt, mit dem Hinweis auf die
                            fehlende Historie
     6 Kadenz & Horizont  — die Limits aus cadence.yaml und
                            autonomie_horizont: release
     7 Empfehlung         — dein Vorschlag in einem Satz
     8 Wie antworten      — ./gate.sh approve <id>  ·  modify <id> \"…\"  ·
                            shelve <id> \"…\"  ·  approve <id> \"horizont: quartal\"

   Maßstab: Man kann entscheiden, ohne eine Datei zu öffnen. Und trotzdem
   verweist jede Zeile auf die Detailakte für einen CEO, der prüfen will.

ZWEITER LAUF — nach der Antwort des Menschen
3. Lies seine Antwort im Kommentar-Thread. Sie beginnt mit einem Verb.
     approve  → Roadmap nach roadmap/q1-freigegeben.html einfrieren (der
                Entwurf bleibt daneben stehen), Freigabedatum und den
                Wortlaut der CEO-Antwort im Dokument vermerken.
                Steht dahinter 'horizont: quartal', trage das in cadence.yaml
                unter autonomie_horizont ein und vermerke, dass das Mandat
                mit dem Quartals-Gate erlischt.
     modify   → Die Änderung EINARBEITEN, das ursprüngliche Urteil daneben
                stehen lassen: nicht überschrieben, sondern widerlegt. Dann
                einfrieren wie bei approve.
     shelve   → Nichts einfrieren. Vermerke im Entwurf, was fehlte.
4. Committe den Vault.
5. kanban_complete mit der Antwort und dem, was du daraus gemacht hast.

Wenn die Ausführung der Antwort scheitert, blockiere diese Karte NICHT ein
zweites Mal. Hermes zählt zwei Blockaden derselben Art auf derselben Karte als
Schleife (BLOCK_RECURRENCE_LIMIT = 2, je kind) und schiebt sie still nach
'triage'. Real passiert, siehe RUN-PROTOKOLL.md. Stattdessen: kanban_complete
mit dem Befund im metadata, und eine NEUE Karte für die Folgeentscheidung.
Eine Entscheidung, eine Karte.

Du rufst NIEMALS kanban_unblock auf. Nicht auf dieser Karte, nicht auf einer
anderen, aus keinem Grund. Das ist die Grenze zwischen der Organisation und
dem Menschen (AGENTS.md 7), und monitor.sh meldet jede Verletzung." \
    --json | jq -r .id)
echo "  ONB_GATE   = $GATE"

cat > "$IDS" <<EOF
# Von create-onboarding.sh erzeugt — $(date '+%Y-%m-%d %H:%M')
BOARD='$BOARD'
VAULT='$VAULT'
REPO='$REPO'
ONB_CODE='$CODE'
ONB_PROD='$PROD'
ONB_MARKT='$MARKT'
ONB_E2E='$E2E'
ONB_ROADMAP='$ROADMAP'
ONB_GATE='$GATE'
EOF

say "Board"
k list

cat <<EOF

IDs liegen in task-ids-onboarding.env:   source task-ids-onboarding.env

Weiter:
  ./pump.sh                       takten und zusehen
  ./gate.sh                       wenn das Roadmap-Gate steht
  ./scripts/check-onboarding.sh   den Phase-1-Nachweis abnehmen
EOF
