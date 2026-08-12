# Story 6 — Recherche-Triage: Fan-out, Fan-in und ein Block mitten im Lauf

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-6` |
| Profile | `planner`, `researcher`, `analyst`, `writer` |
| Mandant | `research` |
| Workspace-Art | `dir:` — ein gemeinsames Korpus |
| Dauer | ca. 25 Minuten (inkl. der Unterbrechung) |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Eine breite Frage wird auf mehrere Spezialisten aufgeteilt, läuft parallel,
und die Ergebnisse fließen an genau einer Stelle wieder zusammen. Unterwegs
läuft einer der Zweige ins Leere und **hält an, statt sich etwas
auszudenken** — du korrigierst mitten im Lauf, ohne dass die anderen davon
berührt werden.

```
                  ┌─▶ Recherche Kosten     ─┐
                  ├─▶ Recherche Latenz     ─┤
   Rechercheplan ─┤                         ├─▶ Analyse ─▶ Brief
      planner     ├─▶ Recherche Werkzeuge  ─┤    analyst    writer
                  └─▶ Recherche Lizenzen   ─┘
                        researcher ×4
                     (blockiert, dann Retry)
```

Drei Muster in einer Story:

| | |
|---|---|
| **Fan-out** | Vier Rechercheure, gleiches Profil, unterschiedliche Blickwinkel, gleichzeitig. |
| **Fan-in** | *Eine* Karte mit *vier* `--parent`-Angaben. Sie bleibt `todo`, bis alle vier `done` sind. |
| **Mensch mitten im Lauf** | Ein Zweig blockiert, du kommentierst, entblockst — und nur dieser Zweig läuft neu. |

Die Ausgangsfrage:

> **Warum stagniert die Migration unserer Bestandskunden von Meridian 1 auf
> Meridian 2?**

---

## Schritt 6.1 — Setup

```bash
cd "Story 6 - Research Triage"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt Board `kanban-story-6`, die vier Profile (jeweils mit `SOUL.md`,
Beschreibung und `config.yaml`) und `workspace/` aus `seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an, `hermes -p <profil> config set …`
schon — deshalb schreibt `setup.sh` alle vier Modell-Schlüssel aus deiner
Root-Konfiguration ins Profil.

```bash
hermes kanban --board kanban-story-6 assignees
```

```console
NAME                  ON DISK   COUNTS
analyst               yes       (idle)
planner               yes       (idle)
researcher            yes       (idle)
writer                yes       (idle)
…
```

Die **Beschreibungen** sind hier kein Kommentar: der Kanban-Decomposer routet
Triage-Karten über sie, nicht über den Profilnamen. Ändern lassen sie sich
jederzeit mit `hermes profile describe <profil> --text "…"`.

### Das Korpus

```
workspace/
├── sources/kosten/            Preisliste, Rechnungsvergleiche, eine Kalkulation
├── sources/latenz/            zwei Benchmarkläufe und ein Betriebsbericht
├── sources/werkzeuge/         Supporttickets, Migrationsprotokoll, Umfrage
├── sources/lizenzen/          NUR ein Sperrvermerk — hier ist absichtlich nichts
├── sources/lizenzen-spiegel/  die Ausweichquelle, die es tatsächlich gibt
├── plan/  findings/  analysis/  brief/     leer — die vier Zielorte
```

`sources/lizenzen/SPERRVERMERK.md`:

```markdown
# Zugriff gesperrt

Die Vertrags- und Lizenzunterlagen zu Meridian 2 liegen **nicht** in diesem
Korpus. Sie stehen in der Vertragsablage der Rechtsabteilung und sind für
diese Auswertung nicht freigegeben.
```

Das ist der Auslöser für den Block in Schritt 6.4 — kein Versehen.

---

## Schritt 6.2 — Den Graphen anlegen

```bash
./create-tasks.sh
source task-ids.env    # BOARD, PLAN, RES_KOSTEN, RES_LATENZ, RES_WERKZEUGE, RES_LIZENZEN, ANALYSE, BRIEF
```

Der Fan-in ist eine einzige Zeile — **eine Karte, vier Eltern**:

```bash
ANALYSE=$(hermes kanban --board kanban-story-6 create "Analyse: Befunde zusammenfuehren und ranken" \
    --assignee analyst --tenant research \
    --workspace "dir:$WS" \
    --parent "$RES_KOSTEN" --parent "$RES_LATENZ" \
    --parent "$RES_WERKZEUGE" --parent "$RES_LIZENZEN" \
    --json | jq -r .id)
```

`--parent` ist wiederholbar. Nachträglich verknüpfen geht auch:

```bash
hermes kanban --board $BOARD link   <eltern> <kind>
hermes kanban --board $BOARD unlink <eltern> <kind>
```

Real gemessen direkt nach dem Anlegen:

```console
◻ t_ed0fd8b9  todo      researcher           [research]  Recherche: Kosten und Preisstruktur
◻ t_fa967513  todo      researcher           [research]  Recherche: Latenz und Durchsatz
◻ t_88a645da  todo      researcher           [research]  Recherche: Migrationswerkzeuge und Betrieb
◻ t_d02a7819  todo      researcher           [research]  Recherche: Lizenz- und Vertragsbedingungen
▶ t_54d1a73f  ready     planner              [research]  Rechercheplan: Migrationsstau Meridian 2
◻ t_2f4b877a  todo      analyst              [research]  Analyse: Befunde zusammenfuehren und ranken
◻ t_60265856  todo      writer               [research]  Brief: Entscheidungsvorlage fuer die Produktleitung
```

Genau eine Karte auf `ready`. Sechs warten.

---

## Schritt 6.3 — Fan-out

```bash
./pump.sh
```

Der Planer läuft, und **sobald er fertig ist, gehen alle vier Rechercheure
gleichzeitig los** — sie hängen alle am selben Elternteil.

Real gemessen:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  completed     planner                 1m  2026-08-10 10:16
  1  completed     researcher              3m  2026-08-10 10:17   ← Kosten
  1  completed     researcher              1m  2026-08-10 10:17   ← Latenz
  1  completed     researcher              2m  2026-08-10 10:17   ← Werkzeuge
  1  blocked       researcher              1m  2026-08-10 10:17   ← Lizenzen
```

Alle vier um **10:17** gestartet, als vier getrennte OS-Prozesse. Drei
lieferten, einer blockierte.

---

## Schritt 6.4 — Der blockierte Zweig

```bash
hermes kanban --board $BOARD runs $RES_LIZENZEN
```

```console
  1  blocked       researcher              1m  2026-08-10 10:17
     → sources/lizenzen/ enthaelt nur SPERRVERMERK.md (Vertrags- und
       Lizenzunterlagen zu Meridian 2 nicht freigegeben, liegen in der
       Vertragsablage der Rechtsabteilung). Ich habe nichts Auswertbares in
       meinem zugewiesenen Quellverzeichnis. Ich darf laut Auftrag nicht auf
       andere Verzeichnisse ausweichen. Bitte weisen Sie mir die freigegebene
       Ausweichquelle zu …
```

Der Worker hat `kanban_block()` gerufen und die konkrete Rückfrage gestellt,
statt sich Vertragsklauseln auszudenken. Das ist erzwungen — im Task-Body
steht:

> Findest du dort nichts Auswertbares, rufe `kanban_block(reason=…)` auf und
> nenne genau, was dir fehlt. Weiche **nicht** auf andere Verzeichnisse aus und
> erfinde nichts.

**Und jetzt der Punkt:** die Analyse-Karte wartet weiter. Ein blockierter
Elternteil hält den Fan-in an, ohne dass irgendetwas fehlschlägt.

```bash
hermes kanban --board $BOARD list --tenant research
```

```console
✓ t_ed0fd8b9  done      researcher    Recherche: Kosten und Preisstruktur
✓ t_fa967513  done      researcher    Recherche: Latenz und Durchsatz
✓ t_88a645da  done      researcher    Recherche: Migrationswerkzeuge und Betrieb
⊘ t_d02a7819  blocked   researcher    Recherche: Lizenz- und Vertragsbedingungen
✓ t_54d1a73f  done      planner       Rechercheplan: Migrationsstau Meridian 2
◻ t_2f4b877a  todo      analyst       Analyse: Befunde zusammenfuehren und ranken   ← wartet
◻ t_60265856  todo      writer        Brief: Entscheidungsvorlage                   ← wartet
```

### Du korrigierst

```bash
hermes kanban --board $BOARD comment $RES_LIZENZEN \
  "Freigegebene Ausweichquelle: sources/lizenzen-spiegel/ enthaelt die von der
   Rechtsabteilung geprüfte Zusammenfassung der Lizenzaenderungen. Nutze die.
   sources/lizenzen/ bleibt gesperrt."

hermes kanban --board $BOARD unblock $RES_LIZENZEN
```

**Im Dashboard:** Kommentarfeld und „Unblock" im Drawer. **Aus einem Chat
heraus:** `/kanban comment <id> "…"` und `/kanban unblock <id>`.

### Was der zweite Versuch sieht

```bash
hermes kanban --board $BOARD context $RES_LIZENZEN
```

Real gemessen — **vier** Abschnitte:

```console
## Prior attempts on this task
### Attempt 1 — blocked (researcher, 2026-08-10 10:17, 10m ago)
sources/lizenzen/ enthaelt nur SPERRVERMERK.md … Bitte weisen Sie mir die
freigegebene Ausweichquelle zu …

## Parent task results
### t_54d1a73f (completed 10m ago)
Die Frage … wurde in vier unabhaengige Arbeitspakete zerlegt …
_metadata_: {"packages": [… {"karte": "t_d02a7819", "name": "Lizenz- und
Vertragsbedingungen", "quellen": ["sources/lizenzen/SPERRVERMERK.md
(Sperrvermerk, nicht auswertbar)", "sources/lizenzen-spiegel/… (Ausweichquelle)"],
"zieldatei": "findings/lizenzen.md"}]}

## Recent work by @researcher
- t_ed0fd8b9 — Recherche: Kosten und Preisstruktur (7m ago): …
- t_88a645da — Recherche: Migrationswerkzeuge und Betrieb (8m ago): …
- t_fa967513 — Recherche: Latenz und Durchsatz (8m ago): …

## Comment thread
comment from worker `default` at 2026-08-10 10:28, just now:
Freigegebene Ausweichquelle: sources/lizenzen-spiegel/ …
```

Der Worker weiß damit: warum er anhielt, was der Plan vorsah, was seine
Kollegen schon gefunden haben und was du ihm gerade gesagt hast. Ergebnis:

```console
  1  blocked       researcher              1m  2026-08-10 10:17
  2  completed     researcher              1m  2026-08-10 10:28
     → Blickwinkel Lizenz-/Vertragsbedingungen anhand der freigegebenen
       Ausweichquelle sources/lizenzen-spiegel/ ausgewertet …
```

---

## Schritt 6.5 — Fan-in

Sobald der vierte Rechercheur `done` ist, wird die Analyse automatisch nach
`ready` befördert. Ihr Kontext enthält jetzt **alle vier** Handoffs. Ein
Auszug, real gemessen:

```console
## Parent task results
### t_88a645da (completed 8m ago)
Blickwinkel "Migrationswerkzeuge und Betrieb" ausgewertet. Kernbefund: Das
Migrationswerkzeug kennt keinen Trockenlauf und kein Rollback — 3 von 4
Abbrüchen haben diese Wurzel; in der Umfrage ist "Kein Trockenlauf/Rollback"
mit 17/23 Nennungen der dominante Blockierer.
_metadata_: `{"findings": [...], "sources": ["sources/werkzeuge/…"]}`

### t_ed0fd8b9 (completed 7m ago)
Blickwinkel Kosten/Preisstruktur ausgewertet. Kernbefund: M2 senkt den
Sitzpreis (−7 %) und verteuert Events drastisch (18→26 EUR/1M, +44 %) …
_metadata_: `{"findings": [...], "sources": [...]}`

### t_fa967513 (completed 8m ago)
Interaktive Latenz ist in M2 durchgehend besser (bis −58 %), aber
Massendurchsatz deutlich schlechter (Backfill +42 %, Export +142 %) …
```

**Das ist der Grund für den ganzen Aufbau.** Der Analyst muss keine vier
Dateien lesen, um zu wissen, was drinsteht — er bekommt die Befunde jedes
Zweigs strukturiert im `metadata`, mit Quellenangabe.

Real gemessen, die komplette Kette:

```console
  1  completed     planner                 1m  2026-08-10 10:16
  1  completed     researcher              3m  2026-08-10 10:17
  1  completed     researcher              1m  2026-08-10 10:17
  1  completed     researcher              2m  2026-08-10 10:17
  1  blocked       researcher              1m  2026-08-10 10:17
  2  completed     researcher              1m  2026-08-10 10:28
  1  completed     analyst                 4m  2026-08-10 10:30
  1  completed     writer                  3m  2026-08-10 10:34
```

Acht Runs auf sieben Karten. Vom Anlegen bis zum Brief: 18 Minuten, davon 11
Minuten Wartezeit auf deine Entscheidung.

---

## Das solltest du sehen

```bash
hermes kanban --board $BOARD list --tenant research
./reset-workspace.sh --diff
```

```console
✓ alle sieben Karten auf done

  Only in …/workspace/plan: rechercheplan.md
  Only in …/workspace/findings: kosten.md
  Only in …/workspace/findings: latenz.md
  Only in …/workspace/findings: lizenzen.md
  Only in …/workspace/findings: werkzeuge.md
  Only in …/workspace/analysis: analyse.md
  Only in …/workspace/brief: entscheidungsvorlage.md
```

Der Brief, real entstanden (Auszug):

```markdown
## Befund

Die Migration stockt nicht an fehlender Bereitschaft, sondern an zwei
konkreten, belegten Blockierern im Produkt: das Migrationswerkzeug hat keinen
Trockenlauf und keinen Rollback (17/23 Umfrage-Nennungen, 3 von 4 Abbrüchen
dieselbe Wurzel), und der fixe Ingest-Rate-Limit von 5.000 Events/Min.
verlängert die Backfill-Dauer so weit, dass Kunden konkret abgebrochen haben.

## Offen

- M2-Rechnung von Halden/Alpsteg liegt UNTER der Listenpreis-Formel
  (7.580 vs. 8.580) — Rabatt oder Altpreis?
- Kausalität Testsystem → Erfolg ist ungeklärt (3=3-Deckung, kein Mechanismus).
```

Der Kostenrechercheur hatte die Unstimmigkeit in den Rechnungen als Lücke
notiert, der Analyst hat sie durchgereicht, der Schreiber hat sie unter
„Offen" gestellt. **Diese Kette gibt es nur, weil jeder Handoff Befunde *und*
Lücken transportiert** — ein Zwischenschritt, der nur eine Zusammenfassung
weitergibt, hätte sie verschluckt.

---

## Die Kurzform: `hermes kanban swarm`

Für genau diese Form — parallele Arbeiter, ein Prüfer, ein Zusammenfasser —
gibt es einen eingebauten Befehl:

```bash
hermes kanban --board kanban-story-6 swarm \
  "Warum stagniert die Migration von Meridian 1 auf Meridian 2?" \
  --worker "researcher:Angle Kosten" \
  --worker "researcher:Angle Latenz" \
  --worker "researcher:Angle Werkzeuge" \
  --worker "researcher:Angle Lizenzen" \
  --verifier analyst --synthesizer writer \
  --tenant swarm-variante --json
```

```console
{
  "root_id": "t_1cfdbeff",
  "worker_ids": ["t_9a217b47", "t_4c8c9117", "t_aba879bc", "t_08759043"],
  "verifier_id": "t_29973f4a",
  "synthesizer_id": "t_1d07e8a6"
}
```

```console
✓ t_1cfdbeff  done      default      [swarm-variante]  Swarm: Warum stagniert die Migration …
▶ t_9a217b47  ready     researcher   [swarm-variante]  Angle Kosten
▶ t_4c8c9117  ready     researcher   [swarm-variante]  Angle Latenz
▶ t_aba879bc  ready     researcher   [swarm-variante]  Angle Werkzeuge
▶ t_08759043  ready     researcher   [swarm-variante]  Angle Lizenzen
◻ t_29973f4a  todo      analyst      [swarm-variante]  Verify swarm outputs
◻ t_1d07e8a6  todo      writer       [swarm-variante]  Synthesize swarm outputs
```

Was `swarm` zusätzlich einbaut:

- Die **Wurzelkarte ist sofort `done`** und dient als gemeinsames schwarzes
  Brett. Sie trägt einen strukturierten Kommentar mit der Topologie:
  `[swarm:blackboard] {"key": "topology", "value": {…}}`.
- In jeden Body wird ein `## Swarm protocol`-Block injiziert („Read
  sibling/parent handoffs from Kanban context before working", „Put
  machine-readable facts in completion metadata").
- Die **Verifier-Karte ist ein Tor**: „complete only with metadata
  `{"gate": "pass"}` when evidence is sufficient; otherwise block with exact
  missing work."

Zwei Grenzen, wegen derer diese Story den Graphen von Hand baut:

- `swarm` kennt **kein `--workspace`** — alle Karten laufen auf `scratch`. Du
  siehst die Ergebnisse dann nur in den Summaries, nicht als Dateien.
- Die Bodies sind generisch. Blickwinkel, Zieldatei und Abgrenzung schreibst
  du bei `create` selbst.

Nimm `swarm`, wenn dir Summaries reichen; bau den Graphen von Hand, wenn
Artefakte auf der Platte landen sollen.

---

## Aufräumen

```bash
source task-ids.env
hermes kanban --board $BOARD list --tenant research --json \
  | jq -r '.[].id' | xargs hermes kanban --board $BOARD archive
./reset-workspace.sh
```

Alles entfernen:

⚠ **Vorher die Desktop App schließen** (oder im Board-Switcher auf `Default`
schalten). Solange sie dieses Board anzeigt, pollt der Zähler in der
Statusleiste es weiter — auch ohne offene Kanban-Seite — und legt es nach dem
Löschen innerhalb von 60 s als leeres Board neu an.

```bash
./teardown.sh                  # Board + Profile + Arbeitsdateien
./teardown.sh --keep-profiles  # Board + Arbeitsdateien
./teardown.sh --files-only     # nur Arbeitsdateien
```

⚠ `planner` wird auch von Story 9 benutzt. Arbeitest du parallel daran, nimm
`--keep-profiles`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --parent <id> --parent <id> …` | **Fan-in**: eine Karte, mehrere Eltern |
| `hermes kanban link/unlink <eltern> <kind>` | Abhängigkeit nachträglich setzen/lösen |
| `hermes kanban context <id>` | Was der Worker sieht — Eltern, Fehlversuche, Kommentare |
| `hermes kanban comment <id> "…"` | Korrektur, die der nächste Versuch sieht |
| `hermes kanban unblock <id>` | Blockierten Zweig freigeben |
| `hermes kanban runs <id>` | Versuchshistorie einer Karte |
| `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` | Fan-out/Verify/Synthese in einem Befehl |
| `hermes profile describe <profil> --text "…"` | Beschreibung pflegen (Decomposer-Routing) |
| `hermes kanban stats` | Zählwerte je Status und Assignee |

---

# Alternative: eine einzige Karte, und der Decomposer baut den Graphen

Statt sieben Karten von Hand: **eine** Karte in der Spalte `triage`. Der
Kanban-Decomposer schneidet die Kinder, verdrahtet die Abhängigkeiten und
routet jede Karte auf ein Profil.

```
Triage-Karte ──decompose──┬─▶ Recherche Kosten     ─┐
                          ├─▶ Recherche Latenz     ─┤
                          ├─▶ Recherche Werkzeuge  ─┼─▶ Analyse ─▶ Brief
                          └─▶ Recherche Lizenzen   ─┘        │
                          └──────── Wurzelkarte wacht wieder auf ┘
```

**Der Planer entfällt** — Auto-decompose *ist* der Planer.

## Was der Decomposer sieht

Nur **Titel, Body und die Profilliste mit ihren Beschreibungen**. Keinen
Workspace, kein `sources/`, keine anderen Karten. Der Body wird bei 4000
Zeichen abgeschnitten.

Was er danach in der Datenbank anrichtet (`kanban_db.decompose_triage_task`):

- Die Kinder **erben Tenant und Workspace der Wurzel**. Das ist der Grund,
  warum diese Variante taugt, wo `hermes kanban swarm` scheitert: mit
  `--workspace "dir:…"` landen die Artefakte auf der Platte.
- Die Geschwister werden nach den `parents`-Indizes verdrahtet — Fan-out und
  Fan-in entstehen genauso wie beim Handbau.
- Die **Wurzel wird Kind jedes Kindes** und flippt `triage → todo`. Sind alle
  Kinder `done`, wird sie `ready` und läuft selbst noch einmal.
- Nicht vererbt werden `--priority`, `--skill`, `--max-runtime`, `--model`,
  `--max-retries`.

## Die Karte

Im Dashboard: neue Karte in der Spalte **Triage**.

| Feld | Wert |
|---|---|
| Titel | `Warum stagniert die Migration unserer Bestandskunden von Meridian 1 auf Meridian 2?` |
| Spalte | `Triage` |
| Mandant | `research-triage` — **nicht leer lassen**, siehe unten |
| Workspace | `dir:` + absoluter Pfad auf `Story 6 - Research Triage/workspace` |
| Assignee | leer lassen |

Der Body ist bewusst so knapp gehalten, wie ihn jemand schreibt, der das
Fachliche kennt und von Hermes nichts weiß — Stichpunkte, keine Topologie,
keine Profilnamen, keine Tool-Aufrufe:

```text
Wir kommen bei der Migration unserer Bestandskunden von Meridian 1 auf
Meridian 2 nicht voran und wissen nicht, woran es liegt. Bitte aufklaeren.

Die Unterlagen liegen im Workspace unter sources/.

Bitte ueber vier Wege recherchieren, unabhaengig voneinander:

- Kosten und Preisstruktur          -> sources/kosten/
- Latenz und Durchsatz              -> sources/latenz/
- Migrationswerkzeuge und Betrieb   -> sources/werkzeuge/
- Lizenz- und Vertragsbedingungen   -> sources/lizenzen/

Fuer jeden Weg:

- nur die eigenen Unterlagen auswerten, nichts dazuerfinden
- jeder Befund mit Beleg (Datei und Stelle), Zahlen wo es welche gibt
- was die Unterlagen nicht hergeben, als Luecke benennen
- Ergebnis nach findings/<thema>.md
- wenn in den zugewiesenen Unterlagen nichts Brauchbares steht: nicht auf
  andere Verzeichnisse ausweichen, sondern nachfragen und die Arbeit so
  lange liegen lassen

Wenn alle vier durch sind:

- die vier Ergebnisse zusammenfuehren, nach Belegstaerke sortieren,
  Widersprueche zwischen den Quellen benennen statt wegmitteln
  -> analysis/analyse.md
- daraus eine Entscheidungsvorlage fuer die Produktleitung, hoechstens eine
  Seite: Befund, was das bedeutet, Empfehlung, offene Punkte
  -> brief/entscheidungsvorlage.md

Zum Schluss pruefen, ob alle sechs Dateien da sind und die Vorlage die
Ausgangsfrage wirklich beantwortet.
```

Auf der Kommandozeile — Text vorher in `ticket.txt` legen:

```bash
BOARD=kanban-story-6
WS="$PWD/workspace"

hermes kanban --board $BOARD create \
  "Warum stagniert die Migration unserer Bestandskunden von Meridian 1 auf Meridian 2?" \
  --triage --tenant research-triage \
  --workspace "dir:$WS" \
  --idempotency-key story6-triage-v1 \
  --body "$(cat ticket.txt)"
```

### Warum der Mandant hier nicht optional ist

Der Mandant ist **kein Schutzraum** — er isoliert weder Dispatcher noch
Workspace, und `## Recent work by @researcher` im Worker-Kontext ist
board-weit, nicht mandantenweit. Er ist ein *Etikett*. Aber er ist das
einzige, das du an dieser Stelle noch setzen kannst:

- Die Kinder legt der Decomposer an, nicht du. Sie **erben** den Mandanten der
  Wurzel — die Triage-Karte ist die einzige Gelegenheit, ihn für den ganzen
  Graphen zu vergeben.
- Er ist danach der einzige Griff, mit dem du „die Karten dieses Laufs"
  auswählst: `list --tenant`, `decompose --all --tenant`, das Archivieren beim
  Aufräumen. Ohne ihn liegen deine sieben Karten neben den sieben aus
  `create-tasks.sh`, ohne Unterscheidungsmerkmal.
- Er landet als `HERMES_TENANT` in der Umgebung jedes Workers. Legt ein Worker
  selbst eine Karte nach — was die Wurzelkarte laut Auftrag tun darf —, erbt
  auch die den Mandanten.

Im Dashboard ist das Feld leicht zu übersehen. Der Lauf unten wurde ohne
Mandant angelegt; alle sieben Karten tragen `tenant = NULL`, und jedes
`--tenant`-Kommando läuft danach ins Leere, **ohne Fehlermeldung**.

## Zerlegen

```bash
hermes kanban --board $BOARD decompose <id> --json
```

**`./pump.sh` zerlegt nicht.** Auto-decompose hängt allein im
Gateway-Dispatcher (`gateway/kanban_watchers.py`), nicht im
Ein-Pass-`hermes kanban dispatch`. Und weil `pump.sh` nur `todo`, `ready` und
`running` zählt, hält es eine reine Triage-Karte für „nichts mehr offen" und
beendet sich sofort.

Läuft das Gateway, passiert es von allein — höchstens
`kanban.auto_decompose_per_tick` Karten je Tick (Standard 3), Tickabstand
`kanban.dispatch_interval_seconds`. Abschalten mit
`kanban.auto_decompose: false`; die Einstellung wird bei jedem Tick neu
gelesen und wirkt sofort.

## Real gemessen

Lauf vom 2026-08-10, Karte über das Dashboard angelegt:

```console
19:37  Karte in Triage                       (Mandant leer, assignee default)
19:39  auto-decomposer → 6 Kinder            ~2 min, ein Gateway-Tick
19:39  Runs 1-4  researcher ×4 gleichzeitig  Fan-out
19:40  Run 4     blocked    Lizenzen         kind: needs_input
19:42  Kommentar + unblock → Run 5           2 min Wartezeit
19:43  Run 5     completed  Lizenzen         Fan-in wird frei
19:44  Run 6     analyst
19:46  Run 7     writer
19:47  Run 8     default    Wurzelkarte
19:48  fertig
```

**8 Runs auf 7 Karten** — exakt wie im Handbau. Entstanden ist:

```console
✓ t_45875fe8  done  default     Warum stagniert die Migration …
✓ t_681dd27f  done  researcher  Werte Kosten- und Preisstruktur aus (sources/kosten/)
✓ t_17405160  done  researcher  Werte Latenz und Durchsatz aus (sources/latenz/)
✓ t_54e225bc  done  researcher  Werte Migrationswerkzeuge und Betrieb aus (sources/werkzeuge/)
✓ t_eef726ea  done  researcher  Werte Lizenz- und Vertragsbedingungen aus (sources/lizenzen/)
✓ t_a21634da  done  analyst     Führe vier Befunde zu Analyse zusammen
✓ t_ecda90a4  done  writer      Erstelle Entscheidungsvorlage und prüfe Gesamtergebnis
```

Vier Wege → vier Karten. „unabhaengig voneinander" → vier elternlose Karten.
„Wenn alle vier durch sind" → **vier `parents` an der Analysekarte**. Routing
auf `researcher`/`analyst`/`writer`, obwohl im Ticket kein Profilname steht —
allein über die Profilbeschreibungen. Nichts landete auf `default`,
`developer` oder `summarizer`, die im Roster ebenfalls stehen.

Die sechs Dateien sind da (686 Zeilen), und der inhaltliche Prüfstein aus
Schritt 6.5 hat gehalten: Die Preisunstimmigkeit **Halden 8.580 vs. 7.580
EUR** wird vom Kostenrechercheur als `gap` notiert, vom Analysten unter
`contradictions` durchgereicht und steht im Brief unter „Offene Punkte".

## Warum so wenig Tickettext reicht

Nicht wegen des Decomposers. `profiles/researcher/SOUL.md`:

```
- If the material you need is missing or unusable, call kanban_block(reason=...)
  naming exactly what you need. Do not fabricate around the hole.
- Write your findings as a file in the workspace, then call
  kanban_complete(summary=..., metadata={"findings": [...], "sources": [...],
  "changed_files": [...]}).
```

Der Block im Lizenz-Zweig und die strukturierten Handoffs
(`findings`, `sources`, `gaps`, `numbers`, `contradictions`, `ranked`) kommen
von dort — im Ticket steht davon kein Wort. Der ausformulierte Body aus
Schritt 6.2 und dieser Stichpunkt-Body sind auf genau diesen Achsen
**äquivalent**, weil keiner von beiden der Ort ist, an dem die Regel lebt.

> **Ein knapper Tickettext trägt, solange die Profile scharf sind.** Die
> Präzision verschwindet nicht, sie wandert von der Karte ins Profil — und
> dorthin gehört sie, weil sie dort wiederverwendbar ist.

Wer wissen will, was der Decomposer *allein* leistet, wiederholt den Lauf mit
Profilen ohne diese SOUL.md-Regeln.

## Was er gut kann, was nicht

| | |
|---|---|
| ✓ | Schnitt, Topologie und Routing allein aus Fließtext |
| ✓ | Er schreibt die Dateipfade in jeden Kind-Body — der Fan-in läuft dadurch zusätzlich über das Dateisystem, nicht nur über die Handoffs |
| ✗ | Er sieht den Graphen nicht, den er baut: die Analysekarte beginnt mit „**Warte, bis** die vier Recherchen abgeschlossen sind" — ein No-op, das erledigt die Kante |
| ✗ | Die Schlussprüfung passiert **zweimal**: er faltet sie in die Writer-Karte („…und prüfe Gesamtergebnis") und sie steht weiter im Wurzel-Body |
| ✗ | Die Wurzel läuft auf `default`, nicht auf `planner` (siehe Fallstricke) |

Zeitlich ist nichts gewonnen: 11 Minuten gegen 18 im Handbau — aber der
Handbau wartete 11 Minuten auf die menschliche Entscheidung, dieser Lauf nur
2. Maschinenzeit rund 9 gegen rund 7 Minuten. Gespart hast du an anderer
Stelle: sechs Kartentexte.

## Fallstricke

- **Mandant vergessen** — siehe oben. Der häufigste, weil er still ist.
- **Die Wurzel landet nicht auf `planner`.** `kanban.orchestrator_profile` ist
  standardmäßig leer, dann greift das aktive Default-Profil; ein `--assignee`
  an der Wurzel wird im Fan-out-Pfad überschrieben. `hermes config set
  kanban.orchestrator_profile planner` gilt für **jedes** Board dieser Maschine
  und bleibt gesetzt, bis du es mit `hermes config unset` zurücknimmst — und
  `planner` benutzt auch Story 9.
- **Zwei Tore beim Routing.** Der Decomposer wählt aus `list_profiles()`, der
  Dispatcher braucht `list_profiles_on_disk()` — also eine `config.yaml` im
  Profilverzeichnis (Schritt 6.1). Eine Karte kann auf ein Profil geroutet
  werden, das gar nicht dispatchbar ist. `hermes kanban --board $BOARD
  assignees` zeigt die Spalte `ON DISK`.
- **Kein Aux-Client, keine Zerlegung.** Ist `auxiliary.kanban_decomposer` nicht
  auflösbar, meldet `decompose` „auxiliary client unavailable" und die Karte
  bleibt in `triage` liegen — ohne Fehler, ohne Retry.
- **`fanout: false` ist ein möglicher Ausgang.** Hält das Modell die Frage für
  eine einzige Arbeitseinheit, wird die Karte nur mit geschärftem Spec nach
  `todo` befördert — dasselbe Ergebnis wie `hermes kanban specify`.

## Aufräumen

Mit Mandant:

```bash
hermes kanban --board $BOARD list --tenant research-triage --json \
  | jq -r '.[].id' | xargs hermes kanban --board $BOARD archive
```

Ohne Mandant greift das nicht — dann über die Herkunft, plus die Wurzel von
Hand:

```bash
hermes kanban --board $BOARD list --json \
  | jq -r '.[] | select(.created_by=="auto-decomposer") | .id' \
  | xargs hermes kanban --board $BOARD archive
hermes kanban --board $BOARD archive <wurzel-id>
./reset-workspace.sh
```

## Befehle dieser Variante

| Befehl | Zweck |
|---|---|
| `hermes kanban create "<frage>" --triage --tenant <m> --workspace dir:<pfad>` | Karte in der Triage-Spalte parken |
| `hermes kanban decompose <id> [--json]` | sofort zerlegen, statt auf das Gateway zu warten |
| `hermes kanban decompose --all --tenant <mandant>` | alle Triage-Karten eines Mandanten zerlegen |
| `hermes kanban specify <id>` | nur schärfen und nach `todo` heben, ohne Fan-out |
| `hermes config set kanban.auto_decompose false` | Auto-Zerlegung im Gateway abschalten (wirkt ab dem nächsten Tick) |
| `hermes config set kanban.orchestrator_profile <profil>` | Profil der Wurzelkarte nach dem Fan-out |
| `hermes config set kanban.default_assignee <profil>` | Auffangprofil für nicht zuordenbare Kinder |
