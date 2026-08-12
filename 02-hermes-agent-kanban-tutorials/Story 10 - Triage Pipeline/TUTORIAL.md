# Story 10 — Triage-Pipeline: eine Flotte, ein menschliches Tor

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

Baiert auf "/Docs/Hermes Agent Kanban Workflow - Video und Github-Repo.md"

Quellen:
https://www.youtube.com/watch?v=EKVRqcpTT6s
https://github.com/tonbistudio/hermes-multi-agent-workflow

| | |
|---|---|
| Board | `kanban-story-10` |
| Profile | `triage-scout`, `triage-orchestrator`, `triage-researcher`, `triage-analyst`, `triage-builder`, `triage-tester`, `triage-producer` |
| Mandant | `triage` |
| Workspace-Art | `dir:` — ein gemeinsamer Raum, plus **dauerhafte** Unterverzeichnisse nach dem Tor |
| Dauer | ca. 60 Minuten, davon eine Entscheidung von dir |
| Vorlage | [tonbistudio/hermes-multi-agent-workflow](https://github.com/tonbistudio/hermes-multi-agent-workflow) |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Die vorigen neun Stories zeigen je **einen** Mechanismus. Diese hier setzt sie
zusammen zu dem, wofür das Board eigentlich gebaut ist: einer Pipeline, die
**von selbst läuft**, sich **selbst** die nächsten Karten anlegt und genau
**einmal** stehen bleibt, um einen Menschen zu fragen.

```
 sources/x  ─▶ Scout x  ─┐
                         ├─▶ Triage ─── Dedup ─── Rubrik ──┬─▶ unter 65: archiviert. Ende.
 sources/web ─▶ Scout web┘   (Fan-in)                      │   Kein Mensch wird gefragt.
                                                           │
                                     ┌─────────────────────┘
                                     │  je Item, selbst angelegt:
                                     ├─▶ Bahn quellen-pruefen ─┐
                                     ├─▶ Bahn kontext          ─┼─▶ Route ─┐
                                     └─▶ Bahn loesungs-audit   ─┘          │
                                              (parallel)                   │
                    ┌──────────────────────────────────────────────────────┘
                    │  Route-Tabelle aus triage.yaml
        ┌───────────┼───────────────┬──────────────────┐
    fehlt/kaputt  verwirrend/     gut                  │
        │         schlecht_erklaert │                  │
        ▼              ▼            ▼                  │
     Pfad build    Pfad video    shelve (automatisch)  │
        │              │                               │
     Prep Synthese  Prep Outline                       │
        └──────┬───────┘                               │
               ▼                                       │
    ╔══════════════════════╗                           │
    ║  MENSCHLICHES TOR    ║  approve · shelve · modify│
    ╚══════════════════════╝                           │
               │                                       │
        ┌──────┴───────┐                               │
     Prototyp        Folien                            │
     Test            Skript                            │
     (in work/builds/<slug>/, dauerhaft)               │
```

Das ist der Workflow aus dem Video von **Tonbi's AI Garage**, nachgebaut mit
Hermes-Bordmitteln. Vier Dinge lernst du hier, die in keiner anderen Story
vorkommen:

| | |
|---|---|
| **Ein Worker baut den Graphen** | Von Hand legst du **drei** Karten an. Die restlichen sechzehn legt die Flotte im Laufen selbst an. In Story 6 steht der Graph vorher fest. |
| **Eine Rubrik entscheidet über deine Aufmerksamkeit** | Was unter 65 von 100 Punkten bleibt, wird archiviert — du erfährst nie davon. Das ist der Sinn, nicht ein Mangel. |
| **Ein Tor, das wirklich hält** | Eine Karte blockiert sich selbst und wartet. Nicht jeder Block hält — welcher hält und warum, ist die technisch interessanteste Stelle dieser Story. |
| **Dauerhafte Workspaces nach dem Tor** | Die Umsetzungskette teilt sich **ein** Verzeichnis. Auf `scratch` wäre die letzte Stufe leer ausgegangen. |

---

## Schritt 10.1 — Setup

```bash
cd "Story 10 - Triage Pipeline"
chmod +x *.sh scripts/*.sh
./setup.sh
```

Das legt Board `kanban-story-10`, die **sieben** Profile und `workspace/` aus
`seed/` an.

```console
4/5  Profile
  triage-scout — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'scout-report' installiert
  triage-orchestrator — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'triage-pipeline' installiert
  triage-researcher — angelegt
  …
```

```console
NAME                  ON DISK   COUNTS
triage-analyst        yes       (idle)
triage-builder        yes       (idle)
triage-orchestrator   yes       (idle)
triage-producer       yes       (idle)
triage-researcher     yes       (idle)
triage-scout          yes       (idle)
triage-tester         yes       (idle)
```

Alle sieben Namen tragen das Präfix `triage-` und kollidieren mit **keiner**
anderen Story. Du kannst hier aufräumen, ohne Story 3, 6 oder 9 zu beschädigen.

### Skills liegen hier pro Profil

Anders als in Story 5, wo jedes Profil jede Skill der Story bekommt, liegen
sie hier unter `skills/<profilname>/<skillname>/`:

```
skills/triage-scout/scout-report/SKILL.md          Berichtsformat
skills/triage-orchestrator/triage-pipeline/SKILL.md  der ganze Ablauf
```

Nachprüfen:

```bash
hermes -p triage-orchestrator skills list
hermes -p triage-researcher   skills list
```

```console
│ triage-pipeline │          │ local  │ local │ enabled │
0 hub-installed, 0 builtin, 1 local — 1 enabled, 0 disabled

0 hub-installed, 0 builtin, 0 local — 0 enabled, 0 disabled
```

Der Rechercheur bekommt den Pipeline-Ablauf **nicht** in den Kontext. Er soll
seine Bahn bearbeiten, nicht mitdenken, was danach kommt. Was er stattdessen
mitbringt, steht in seiner `SOUL.md`.

---

## Schritt 10.2 — Die eine Datei, in der die Fachlichkeit steht

`workspace/pipeline/triage.yaml`. Das ist die Idee, die das Original
transportiert und die den ganzen Aufbau trägt:

> **Die Form der Pipeline ist fest. Was durch sie hindurchfließt, steht in
> einer Datei.**

Die vier Blöcke, die alles entscheiden:

```yaml
rubrik:
  schwelle: 65
  dimensionen:
    - {key: haeufigkeit,             max: 25, hinweis: "wie viele unabhaengige Quellen …"}
    - {key: schmerzintensitaet,      max: 20, hinweis: "wie akut — verlorene Stunden …"}
    - {key: loesbar_oder_erklaerbar, max: 25, hinweis: "kann ein Agent eine Loesung bauen ODER …"}
    - {key: loesungsluecke,          max: 15, hinweis: "gibt es noch keine gute Loesung"}
    - {key: strategische_passung,    max: 15, hinweis: "passt es zum Publikum des Kanals"}

recherche_bahnen:
  bahnen: [quellen-pruefen, kontext, loesungs-audit]
  klassifikator_bahn: loesungs-audit

route:
  tabelle:
    fehlt:             build
    kaputt:            build
    verwirrend:        video
    schlecht_erklaert: video
    veraltet:          video
    gut:               shelve

paths:
  build:
    prep:    [{stufe: synthese, rolle: triage-analyst}]
    fulfill: [{stufe: prototyp, rolle: triage-builder},
              {stufe: test,     rolle: triage-tester}]
    unterverzeichnis: builds
    rails: pipeline/rails/build.md
```

Willst du die Pipeline auf dein Thema umstellen, änderst du **diese Datei** und
die Markdown-Vorlagen daneben — nicht die Profile und nicht die Skill.

Die `SOUL.md` des Orchestrators macht das zur Pflicht:

```
Bevor du irgendetwas entscheidest, lies `pipeline/triage.yaml` in deinem
Workspace. Die Rubrik, die Schwellen, die Route-Tabelle und die Pfade leben
dort. Widersprechen sich dein Urteil und diese Datei, gewinnt die Datei.
```

### Das Korpus

Im Original suchen die Scouts live auf X, Reddit und im Web. Hier lesen sie ein
**eingefrorenes** Korpus — sonst wäre kein Durchlauf mit dem nächsten
vergleichbar, und die Story bräuchte Web-Zugang und API-Schlüssel.

```
workspace/sources/x/     3 Posts
workspace/sources/web/   3 Threads (Reddit, Forum, YouTube-Kommentare)
```

Es ist so gebaut, dass **alle vier Ausgänge** der Triage vorkommen:

| Was drinsteht | Was passieren soll |
|---|---|
| MCP-Werkzeugflut, in `x/` **und** in zwei `web/`-Dateien | Dedup: drei Quellen → **ein** Item |
| Konfigurationspfade, in `x/` **und** in `web/` | Dedup: zwei Quellen → **ein** Item, Route → `build` |
| MCP-Werkzeugflut hat eine Lösung, die niemand findet | Route → `video` |
| Emojis in Commit-Messages | unter der Schwelle → **archiviert**, ohne dich zu fragen |

---

## Schritt 10.3 — Drei Karten anlegen, sechzehn entstehen lassen

```bash
./create-tasks.sh
source task-ids.env      # BOARD, TENANT, WS, SCOUT_X, SCOUT_WEB, TRIAGE
./pump.sh
```

Angelegt wird nur der Eingang:

```console
▶ t_8555ffe8  ready     triage-scout         [triage]  Scout x: sources/x auswerten
▶ t_4adb71aa  ready     triage-scout         [triage]  Scout web: sources/web auswerten
◻ t_8bdde899  todo      triage-orchestrator  [triage]  Triage: dedup, bewerten, Fan-out
```

### Was die Scouts tun — und was nicht

Ein Scout **erkennt nur**. Real gemessen, `intake/x.md`:

```markdown
# Scout-Bericht: x

Ausgewertet: 3 Dateien unter sources/x
Kandidaten: 2

## Sub-Agenten greifen ab vielen Tools im Kontext das falsche Werkzeug (oder gar keins)

- **behauptung:** Sobald viele MCP-Server bzw. Werkzeuge im Kontext liegen, greifen
  die Sub-Agenten das falsche Werkzeug oder gar keins …
- **quellen:**
  - `2026-08-03-subagenten-mcp.md` — @mkirsch_dev (x), 2026-08-03 — „Ab ungefaehr
    60 Werkzeugen im Kontext kippt es. Der Haupt-Agent kommt damit klar, die
    Sub-Agenten nicht."
- **warum_relevant:** … Die genannte Grenze „ab ungefaehr 60 Werkzeugen" ist eine
  Schaetzung des Autors aus der Quelle und keine dokumentierte Spezifikation.
```

Der letzte Halbsatz ist der Grund für die Zitierregeln in der Skill
`scout-report`: **eine Zahl aus einer Quelle ist nicht dieselbe Aussage wie
eine gemessene Zahl.** Wer das im Bericht verwischt, kann es später nicht mehr
trennen.

Der Web-Scout hat aus **drei** Dateien **zwei** Kandidaten gemacht — Reddit-
und YouTube-Faden beschreiben denselben Mechanismus:

```console
Ausgewertet: 3 Dateien unter sources/web
Kandidaten: 2
## Ambigue Konfigurationspfade: wirksame Datei unklar, effektive Werte nicht einsehbar
## Sub-Agenten waehlen Werkzeuge falsch, sobald zu viele Werkzeuge/MCP-Server im Kontext sind
```

Das ist Dedup **innerhalb** einer Quelle. Über die Quellgrenze hinweg kann ein
Scout es nicht — er sieht die andere Quelle nicht. Dafür gibt es die
Triage-Karte.

### Die Triage-Karte: Dedup, Rubrik, Fan-out

Real gemessen, in **zwei Minuten**:

```console
#    OUTCOME       PROFILE                    ELAPSED  STARTED
  1  completed     triage-orchestrator             2m  2026-08-11 08:07
     → 4 Kandidaten aus web+x dedupliziert zu 2 Items (subagenten-werkzeugflut 85,
       konfigurationspfade-ambig 76), beide ueber der Schwelle 65. Fan-out angelegt:
       je Item 3 Recherche-Bahnen + 1 Route-Karte.
```

Und `workspace/vault/items/subagenten-werkzeugflut.md`:

```markdown
---
slug: subagenten-werkzeugflut
titel: Sub-Agenten waehlen Werkzeuge falsch (oder gar keins), sobald zu viele
       Werkzeuge/MCP-Server im Kontext liegen
status: recherche
score: 85
score_breakdown: {haeufigkeit: 22, schmerzintensitaet: 16, loesbar_oder_erklaerbar: 22,
                  loesungsluecke: 11, strategische_passung: 14}
pfad:
duplikate: []
---
```

**Der `score_breakdown` ist kein Zierrat.** Er ist der einzige Grund, warum du
später überprüfen kannst, *warum* etwas 85 bekommen hat — und warum diese
Pipeline nicht dasselbe ist wie „ein Modell hat entschieden".

---

## Schritt 10.4 — Fan-out: sechs Bahnen gleichzeitig

Sobald die Triage-Karte fertig ist, gehen alle Bahnen los:

```console
● t_21fc8092  running   triage-researcher    [triage]  Bahn quellen-pruefen: subagenten-werkzeugflut
● t_385dd981  running   triage-researcher    [triage]  Bahn kontext: subagenten-werkzeugflut
● t_1d12178f  running   triage-researcher    [triage]  Bahn loesungs-audit: subagenten-werkzeugflut
● t_ddd92de3  running   triage-researcher    [triage]  Bahn quellen-pruefen: konfigurationspfade-ambig
● t_9d56332f  running   triage-researcher    [triage]  Bahn kontext: konfigurationspfade-ambig
● t_b159701d  running   triage-researcher    [triage]  Bahn loesungs-audit: konfigurationspfade-ambig
✓ t_8bdde899  done      triage-orchestrator  [triage]  Triage: dedup, bewerten, Fan-out
◻ t_502065ac  todo      triage-orchestrator  [triage]  Route: subagenten-werkzeugflut
◻ t_52e6ad87  todo      triage-orchestrator  [triage]  Route: konfigurationspfade-ambig
```

**Sechs OS-Prozesse gleichzeitig, alle auf demselben Profil.** Zwei
Route-Karten warten auf je drei Eltern.

Diese neun Karten hat **kein Mensch angelegt**. Der Orchestrator hat sie
während seines Laufs mit `kanban_create` geschrieben — dem einzigen
Worker-Werkzeug, mit dem ein Agent das Board erweitert:

```python
kanban_create(
    title          = "Bahn loesungs-audit: subagenten-werkzeugflut",
    assignee       = "triage-researcher",
    parents        = ["t_8bdde899"],           # die Triage-Karte selbst
    workspace_kind = "dir",
    workspace_path = "/…/Story 10 - Triage Pipeline/workspace",   # ABSOLUT
    tenant         = "triage",
    body           = "…",
)
```

### Zwei Fallen, die hier scharf sind

**1. `workspace_path` muss absolut sein.** Relative Pfade werden abgewiesen.
Der Worker kennt sein eigenes Verzeichnis nur über
`$HERMES_KANBAN_WORKSPACE` — daraus muss er den Pfad bauen. Deshalb steht in
der Skill fett:

> Jede Karte, die du anlegst, bekommt `workspace_kind="dir"` und einen
> **absoluten** `workspace_path`. Ein relativer Pfad wird abgewiesen, und die
> Karte wird nie gestartet — **ohne Fehlermeldung auf dem Board**.

**2. Die Bahn-Karten bekommen die Triage-Karte als Elternteil.** Sie stehen
damit auf `todo` und starten erst, wenn der Orchestrator fertig ist. Das ist
kein Detail: zu dem Zeitpunkt, an dem er sie anlegt, hat er die Item-Dateien
teils noch gar nicht geschrieben.

---

## Schritt 10.5 — Route: eine Tabelle entscheidet, keine Meinung

Die Klassifikator-Bahn (`loesungs-audit`) liefert als letzte Zeile einen Wert:

```
loesungsqualitaet: schlecht_erklaert
```

Die Route-Karte schlägt ihn in `route.tabelle` nach — mehr nicht. Steht der
Wert nicht in der Tabelle, blockiert die Karte, statt zu raten. Das ist die
Stelle, an der diese Pipeline am wenigsten „KI" ist und am meisten
Nachschlagewerk, und das ist Absicht:

> Der Klassifikator darf urteilen. Was aus dem Urteil folgt, ist eine Tabelle.

Real gemessen:

```console
$ hermes kanban --board $BOARD show <route-id> --json | jq -r .latest_summary

Route fuer subagenten-werkzeugflut aufgeloest: loesungsqualitaet=schlecht_erklaert
-> Pfad video (nicht auto). pfad: video in die Item-Datei geschrieben,
Prep-Kette (outline) und Tor-Karte angelegt.
```

Beide Items bekamen `schlecht_erklaert` — für beide gibt es also eine Lösung,
die niemand findet. Beide gingen damit auf `video`. **Der Bau-Pfad kam in
diesem Lauf über die Route gar nicht vor**; wie er trotzdem gelaufen ist, steht
in Schritt 10.6 unter `modify`.

Dass der Klassifikator zweimal dasselbe sagt, ist übrigens kein Zufall des
Modells: das Korpus enthält für beide Fälle einen Hinweis auf eine existierende
Lösung (die Allow-List aus dem Reddit-Faden, `hermes config path` beim
Konfigurationsthema). Der Rechercheur hat sie gefunden. **Genau dafür ist die
Bahn `loesungs-audit` da** — sie verhindert, dass etwas gebaut wird, das es
schon gibt.

---

## Schritt 10.6 — Das Tor

Jetzt hält die Pipeline an. `./pump.sh` endet von selbst und sagt, worauf:

```console
[01] blocked=2

Nichts mehr offen — Pumpe beendet.

⊘ t_6ed15790  blocked   (unassigned)          Pump-Probe A
⊘ t_1b540e8c  blocked   (unassigned)          Pump-Probe B

2 Karte(n) warten auf einen Menschen:
  t_6ed15790  Pump-Probe A
  t_1b540e8c  Pump-Probe B

Worauf genau, zeigt:  ./gate.sh
```

*(Die Kartennummern stammen aus einer separaten Probe mit zwei blockierten
Wegwerf-Karten. Im zweiten protokollierten Lauf ist dieselbe Ausgabe aus der
Pipeline selbst entstanden — mit den beiden echten Tor-Karten, siehe
[`beispiel-lauf-2/README.md`](beispiel-lauf-2/README.md).)*

`blocked` zählt für `pump.sh` **nicht** als „offen". Die Pumpe endet also von
selbst, sobald die Pipeline auf dich wartet — sie dreht nicht weiter durch.

### Wie ein Tor gebaut wird, das wirklich hält

Die Vorschlagskarte blockiert **sich selbst**:

```python
kanban_block(
    kind   = "needs_input",
    reason = "FREIGABE <slug> (<pfad>, <score>/100): <ein Satz>. "
             "Antwort: unblock --reason 'approve' | 'shelve: …' | 'modify: …'",
)
```

⚠ **Was den Block hält, ist nicht das `kind` — es ist, dass `block` überhaupt
ein Ereignis schreibt.** `--initial-status blocked` tut das nicht. Das ist die
technisch wichtigste Erkenntnis dieser Story.

Der Dispatcher befördert in jedem Tick alle Karten nach `ready`, deren Eltern
fertig sind — und er sieht sich dafür `todo` **und `blocked`** an
(`kanban_db.recompute_ready`). Eine blockierte Karte bleibt nur dann liegen,
wenn ihr letztes Block-Ereignis ein **echtes `blocked`-Event** ist
(`_has_sticky_block`):

```python
todo_rows = conn.execute(
    "SELECT id, status, … FROM tasks WHERE status IN ('todo', 'blocked')"
).fetchall()
for row in todo_rows:
    if cur_status == "blocked" and _has_sticky_block(conn, task_id):
        continue          # Mensch hat blockiert — nicht anfassen
    …                     # sonst: befoerdern, sobald die Eltern fertig sind
```

`--initial-status blocked` erzeugt **kein** solches Event — es setzt nur die
Spalte. Real gemessen an einer Karte, die genau so angelegt wurde:

⚠ Die folgenden Ereignis-Blöcke sind so aufgebaut, wie `hermes kanban show <id>`
sie darstellt. In v0.20.0 bricht `show` **ohne `--json`** allerdings ab
(`sqlite3.ProgrammingError: Cannot operate on a closed database`), sodass diese
Information praktisch nur über `hermes kanban show <id> --json` zu bekommen ist
— Details in der [Befehlsreferenz](../TUTORIAL.md#ansehen-und-diagnostizieren).

```console
Events (7):
  [07:38] created {'status': 'blocked', 'parents': ['t_c0347293'], …}
  [07:38] promoted                      ← der Dispatcher hat sie hochgeholt
  [07:38] [run 2] claimed
  [07:38] [run 2] spawned
  [07:40] [run 2] completed
```

Die Karte war als Tor gedacht und ist einfach durchgelaufen, sobald ihr
Elternteil fertig war. **Kein Fehler, keine Warnung.**

Mit `kanban_block` bzw. `hermes kanban block` entsteht dagegen ein Event, und
die Karte hält:

```console
  [07:45] [run 4] blocked {'reason': '…', 'kind': 'needs_input', 'recurrences': 1}
```

```console
$ hermes kanban --board kanban-story-10 dispatch --dry-run
Promoted:     0
Spawned:      0
```

| Weg | Erzeugt ein `blocked`-Event? | Hält, wenn die Eltern fertig sind? |
|---|---|---|
| `--initial-status blocked` | **nein** | **nein** — läuft durch |
| `hermes kanban block <id> "<grund>"` | ja | **ja** |
| `kanban_block(reason=…)` im Worker | ja | **ja** |
| Circuit Breaker (`gave_up`) | nein (`gave_up`) | nein — erholt sich absichtlich selbst |

Merksatz: **`--initial-status blocked` parkt, `block` hält.** Zum Parken beim
Anlegen ist es richtig; als Tor ist es falsch.

### Wozu dann `--kind`?

Ein Block **ohne** `--kind` hält genauso — real geprüft, drei Ticks lang und in
`dispatch --dry-run`. `--kind` ist kein Schalter für die Haltekraft, sondern
eine **Typangabe**, und eine davon verhält sich tatsächlich anders:

| `--kind` | Verhalten |
|---|---|
| *(weggelassen)* | generischer Block, hält |
| `needs_input` / `capability` | hält, und sagt jedem Leser: **hier wartet ein Mensch** |
| `dependency` | wartet in `todo` und wird automatisch befördert, wenn die Eltern fertig sind — **kein** Mensch |
| `transient` | markiert einen vermutlich flüchtigen Fehler |

Für ein Tor ist `needs_input` deshalb die richtige Angabe: sie hält nicht
*mehr*, sie ist ehrlich. Und sie hat eine Nebenwirkung, die man kennen sollte —
wiederholtes Blockieren mit demselben `kind` nach einem `unblock` routet die
Karte in die Triage. Das bricht Endlosschleifen aus Blockieren und Entblocken.

### ⚠ Die Syntax von `block` ist nicht die dokumentierte

Das Nachschlagewerk in diesem Repository und die offizielle Dokumentation
schreiben `--reason`. In v0.20.0 gibt es das bei `block` **nicht** — der Grund
ist ein **positionales** Argument, und `--kind` muss **vor** die Kartennummer:

```bash
# falsch — bricht mit "unrecognized arguments" ab:
hermes kanban block <id> --reason "Freigabe noetig"
hermes kanban block <id> --kind needs_input "Freigabe noetig"

# richtig:
hermes kanban block <id> "Freigabe noetig"
hermes kanban block --kind needs_input <id> "Freigabe noetig"
```

Bei `unblock` gibt es `--reason` sehr wohl — und dort ist es genau das, was
das Tor braucht.

### Deine Entscheidung

```bash
./gate.sh                                    # was wartet?
./gate.sh approve <id>
./gate.sh shelve  <id> "passt nicht zum Kanal"
./gate.sh modify  <id> "nur Linux und WSL, Windows weglassen"
```

Dahinter steckt **ein** Befehl:

```bash
hermes kanban --board kanban-story-10 unblock <id> --reason "approve"
```

`--reason` legt den Text als **Kommentar** an die Karte und hebt sie danach
nach `ready`. Beides in einem Schritt — deshalb ist das die natürliche Form
eines Tors auf dem Board.

Real gemessen, beide Tore:

```console
$ ./gate.sh

t_a96d0cf5  Vorschlag + Tor: konfigurationspfade-ambig
────────────────────────────────────────────────────────────────────────
  FREIGABE konfigurationspfade-ambig (video, 76/100): Video-Outline bauen —
  warum mehrere config.toml-Pfade (Home/Projekt/WSL/Roaming) unklar machen,
  welche wirkt; Approve-Gate wird stumm umgangen (Commit im Kundenrepo, 2
  verlorene Tage); Loesung existiert bereits (hermes config path/show/get),
  Rest-Luecken: keine Konkurrenz-Warnung, Prioritaetsordnung
  undokumentiert, Secrets-Redaktion. 7 Folien + Skript + Faktencheck.
  Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'

  Vollstaendiger Vorschlag: workspace/vault/items/konfigurationspfade-ambig-vorschlag.md

  ./gate.sh approve t_a96d0cf5
  ./gate.sh shelve  t_a96d0cf5 "passt nicht zum Kanal"
  ./gate.sh modify  t_a96d0cf5 "nur Linux und WSL, Windows weglassen"
```

**Das ist die ganze Ausbeute von neunzehn Minuten Flottenarbeit, in acht
Zeilen.** Genau so soll ein Tor aussehen: entscheidbar, ohne eine Datei zu
öffnen. Wer mehr will, findet den ausformulierten Vorschlag daneben.

### `modify` darf auch die Route korrigieren

Für das zweite Item wurde nicht freigegeben, sondern **widersprochen**:

```bash
./gate.sh modify t_a96d0cf5 \
  "Route auf build korrigieren. hermes config path/show zeigt PFADE, aber nicht,
   welcher Wert am Ende gilt und aus welcher Datei er stammt — genau das ist die
   Luecke aus den Quellen. Baue das Werkzeug: alle Kandidatenpfade auflisten,
   effektive Werte mit Herkunftsdatei ausgeben, Secrets redigieren."
```

```console
  1  blocked       triage-orchestrator       45s  2026-08-11 08:26
     → FREIGABE konfigurationspfade-ambig (video, 76/100) …
  2  completed     triage-orchestrator        2m  2026-08-11 08:34
     → modify konfigurationspfade-ambig: Route von video auf build korrigiert
       (menschliche Entscheidung) …
```

Der Klassifikator hatte „es gibt ja `hermes config path`" gesagt. Stimmt — nur
zeigt der Befehl **Pfade**, nicht **welcher Wert am Ende gilt**. Diese
Unterscheidung ist genau die Lücke aus den Quellen, und ein Mensch sieht sie in
zehn Sekunden.

Der Orchestrator hat die Route umgeschrieben und dabei den ursprünglichen
Klassifikatorwert **stehen lassen**:

```markdown
pfad: build
```
```
**Routenkorrektur:** Der Mensch korrigierte die Route von `video` auf `build`.
Der urspruengliche Klassifikatorwert `loesungsqualitaet: schlecht_erklaert`
bleibt in der Item-Datei stehen — er wird nicht ueberschrieben, sondern durch
die menschliche Entscheidung widerlegt.
```

> **Das ist der Grund, warum das Tor existiert.** Der Autor des Originals sagt
> es so: auch nach guter Recherche kommen Vorschläge durch, die keinen Sinn
> ergeben. Ein Tor, das nur „ja" kennt, hätte hier ein Video über ein Werkzeug
> produziert, das die Frage gar nicht beantwortet.

Und das dritte Verb, `shelve`, brauchst du seltener als gedacht — die Rubrik
hat den unwichtigen Fall schon vor dem Tor aussortiert (Schritt 10.8).

---

## Schritt 10.7 — Nach dem Tor: ein Verzeichnis, das bleibt

Der Orchestrator läuft ein **zweites Mal auf derselben Karte** an, liest deine
Antwort im Kommentar-Thread und führt sie aus.

```
Lauf 1:  Vorschlag schreiben  ─▶ kanban_block(kind="needs_input")
                                      │
                              du: unblock --reason "approve"
                                      │
Lauf 2:  Kommentar lesen ─▶ auftrag.md schreiben ─▶ Kette anlegen ─▶ complete
```

Zwei Regeln, die das Original teuer gelernt hat und die hier in der Skill
stehen:

**1. Die Umsetzungskette läuft in einem dauerhaften Verzeichnis.**

```python
workspace_path = "<WS>/work/builds/<slug>"      # nicht scratch!
```

Wegwerf-Workspaces werden zwischen Karten geleert. Die letzte Stufe — die, die
liefert — stünde dann vor einem leeren Verzeichnis. Alle Stufen einer Kette
teilen sich **dasselbe** `dir:`.

**2. Die erste Karte der Kette bekommt bewusst *keinen* Elternteil.**

Hängst du sie an die Tor-Karte, wartet sie, bis der Orchestrator fertig ist —
und wenn der aus irgendeinem Grund noch einmal blockiert, wartet sie für immer.
Deshalb steht in der `SOUL.md` des Orchestrators:

> **Never linger.** When you have created the follow-up cards, call
> kanban_complete immediately.

**3. `auftrag.md` wird kopiert, nicht verlinkt.**

Die Worker der Umsetzungskette laufen in `work/builds/<slug>/` und sehen den
Rest des Workspace **nicht**. Der freigegebene Vorschlag, deine Antwort im
Wortlaut und der Inhalt der Scope-Rails müssen physisch dort liegen.

Real gemessen, beide Ketten:

```console
✓ t_4bb57feb  done  triage-orchestrator  Vorschlag + Tor: subagenten-werkzeugflut
✓ t_1b003ca4  done  triage-producer      Fulfill folien:  subagenten-werkzeugflut
✓ t_adca6c17  done  triage-producer      Fulfill skript:  subagenten-werkzeugflut

✓ t_a96d0cf5  done  triage-orchestrator  Vorschlag + Tor: konfigurationspfade-ambig
✓ t_f48b807e  done  triage-builder       Fulfill prototyp: konfigurationspfade-ambig
✓ t_a4fa765c  done  triage-tester        Fulfill test:     konfigurationspfade-ambig
```

Und der Kopf des `auftrag.md`, das der Orchestrator in das dauerhafte
Verzeichnis geschrieben hat:

```markdown
# Auftrag: Werkzeug bauen — effektive Konfigurationspfade anzeigen

**Slug:** `konfigurationspfade-ambig`  ·  **Pfad:** `build`  ·  **Punkte:** 76/100
**Arbeitsverzeichnis:** `work/builds/konfigurationspfade-ambig/`

## 1. Wortlaut der menschlichen Entscheidung (verbatim)

> UNBLOCK: modify: Route auf build korrigieren. hermes config path/show zeigt
> PFADE, aber nicht, welcher Wert am Ende gilt und aus welcher Datei er stammt …
```

**Der Wortlaut deiner Entscheidung steht wörtlich im Auftrag.** Nicht
zusammengefasst — der Builder soll lesen, was du gesagt hast, nicht, was der
Orchestrator daraus gemacht hat.

### Was der Builder und der Tester daraus gemacht haben

```console
  1  completed     triage-builder    2m  → Baute konfigpfade.py (197 Zeilen, nur
                                           Standardbibliothek) …
  1  completed     triage-tester     7m  → Test bestanden: konfigpfade.py erfuellt
                                           alle Rails …
```

197 Zeilen gegen ein Limit von 200 — die Scope-Rails aus
`pipeline/rails/build.md` sind im Auftrag gelandet und haben gehalten. Der
Tester hat sie einzeln **nachgeprüft**, statt sie zu glauben:

```markdown
## Statische Rails-Pruefung

| Rail | Befund |
|------|--------|
| Genau eine Programmdatei | PASS — nur `konfigpfade.py` |
| <= 200 Zeilen | PASS — `wc -l` = 197 |
| Nur Standardbibliothek | PASS — Imports: os, sys, re, argparse, tomllib |
| Kein Netzwerk/Subprozess/Shell zur Laufzeit | PASS — kein subprocess, os.system, socket … |
| Veraendert nichts ausserhalb | PASS — einziger `open(...)` ist `open(path, "rb")` (lesend) |
```

Dass der Tester ein **eigenes Profil** ist und nicht derselbe Agent, der gebaut
hat, ist kein Zeremoniell: seine `SOUL.md` sagt ihm, er solle gegen das
**Freigegebene** testen, nicht gegen das Gebaute, und Fehler im Bericht stehen
lassen. Ein Builder, der sich selbst testet, hat dieses Interesse nicht.

Das Werkzeug läuft wirklich:

```console
$ python3 workspace/work/builds/konfigurationspfade-ambig/konfigpfade.py --help
usage: konfigpfade [-h] [-f FILE] dirs [dirs ...]

Zeigt Kandidatenpfade, effektive Werte samt Herkunft und redigiert Secrets.
Veraendert nichts.
```

---

## Schritt 10.8 — Der Ausgang, den du nie siehst

Bis hierher ging es um die zwei Items, die es bis zum Tor geschafft haben. Der
häufigste Ausgang einer Triage-Pipeline ist ein anderer: **nichts.**

Im Korpus liegt ein dritter Fall — jemand ärgert sich, dass sein Agent Emojis
in Commit-Messages schreibt. Echt erlebt, konkret beschrieben, seit Wochen. Ein
Kandidat, kein Müll. Real gemessen:

```console
$ hermes kanban --board $BOARD show <triage-id> --json | jq -r .latest_summary

5 Kandidaten aus x+web zu 3 Items dedupliziert: subagenten-werkzeugflut (82),
konfigurationspfade-ambig (84) beide ueber der Schwelle 65;
commit-emoji (26) archiviert.
```

```markdown
---
slug: commit-emoji
titel: Agent packt in jede Commit-Message zwei Emojis
status: archiviert
score: 26
score_breakdown: {haeufigkeit: 3, schmerzintensitaet: 2, loesbar_oder_erklaerbar: 15,
                  loesungsluecke: 3, strategische_passung: 3}
---
```

```console
$ hermes kanban --board $BOARD list --json | jq -r '.[]|select(.title|test("emoji";"i"))|.title'
(nichts)
```

**Für dieses Item wurde keine einzige Karte angelegt.** Kein Rechercheur, kein
Vorschlag, kein Tor. Es liegt als Datei im Vault, mit einer nachvollziehbaren
Begründung, und wartet dort, falls jemand dieselbe Sache noch dreimal meldet
und die Häufigkeit steigt.

Bemerkenswert ist die Verteilung: `loesbar_oder_erklaerbar` bekam **15 von 25**
— das Problem wäre leicht zu lösen. Genau deshalb ist die Rubrik mehrdimensional.
Eine Pipeline, die nur „kann ich das?" fragt, hätte hier gearbeitet.

### Der Scout darf diese Entscheidung nicht vorwegnehmen

Ein Zwischenfall aus der Entwicklung dieser Story, weil er einen echten
Konstruktionsfehler zeigt: In den ersten Läufen tauchte dieses Item **gar nicht
auf**. Der Scout hatte es weggelassen — mit der Begründung, es sei kosmetisch.

Der Effekt: Die Schwelle in `triage.yaml` wurde zur Attrappe. Sie stand da, sie
wurde nie wirksam, und **auf dem Board war das nicht zu sehen** — ein Item, das
der Scout nicht meldet, hinterlässt keine Spur. Die Rubrik hätte man beliebig
verstellen können, ohne dass sich je etwas geändert hätte.

Beide Filter sind für sich vernünftig. Zusammen sind sie ein Fehler:

| Stufe | darf entscheiden | darf **nicht** entscheiden |
|---|---|---|
| Scout | Ist das ein erlebter, konkreter Vorfall? | Ist er wichtig? |
| Rubrik | Ist er wichtig genug (Punkte, Schwelle)? | Ob es ihn gibt |

Die `SOUL.md` des Scouts sagt das jetzt ausdrücklich:

```
- Vague enthusiasm, marketing and speculation are not candidates: skip them.
  But do NOT decide whether a candidate MATTERS — that is the rubric's job,
  downstream, and it needs the weak cases to do it. … Filtering by importance
  here silently removes items nobody will ever see again.
```

> **Zwei Filter hintereinander, die dasselbe Kriterium anlegen, sind kein
> doppelter Schutz — sie sind ein blinder Fleck.** Der zweite kann nicht mehr
> zeigen, was der erste schon entfernt hat.

---

## Das solltest du sehen

```bash
source task-ids.env
hermes kanban --board $BOARD list --tenant triage
./reset-workspace.sh --diff
```

**21 Karten, 23 Runs, alle auf `done`** — davon hast du drei angelegt:

```console
$ hermes kanban --board $BOARD list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'

triage-orchestrator: 16   triage-producer: 2   user: 3
```

Der ganze Verlauf, real gemessen:

```console
07:58  Scout x            2m   ─┐ parallel
07:58  Scout web          9m   ─┘
08:07  Triage             2m       4 Kandidaten → 2 Items (85, 76), Fan-out: 8 Karten
08:10  6× Recherche  2–16m       sechs Prozesse gleichzeitig
08:23  Route #1          57s      schlecht_erklaert → video
08:26  Route #2           1m      schlecht_erklaert → video
08:24  Prep outline #1    1m
08:27  Prep outline #2    2m
08:26  Tor #2 blockiert  45s   ══ wartet auf dich ══
08:29  Tor #1 blockiert   2m   ══ wartet auf dich ══
08:33  Tor #1 Lauf 2      4m      approve  → Kette video angelegt
08:34  Tor #2 Lauf 2      2m      modify   → Route auf build korrigiert
08:36  Fulfill prototyp   2m      konfigpfade.py, 197 Zeilen
08:36  Fulfill folien    13m
08:39  Fulfill test       7m      alle Rails geprueft, PASS
08:49  Fulfill skript   2+6m
08:52  Fulfill faktencheck 3m
08:56  fertig
```

Knapp **eine Stunde** von der ersten Karte bis zum letzten Deliverable (07:58 →
08:56). Die beiden Tore lagen vier bzw. acht Minuten still und warteten auf die
Entscheidung — in einem echten Betrieb wären das Stunden oder Tage, und **die
Pipeline hätte in der Zeit nichts verbraucht**. Die Maschinenzeit ist deutlich
kürzer als die Wanduhr, weil bis zu sechs Worker gleichzeitig liefen.

Entstanden ist:

```console
intake/x.md                         Scout-Bericht X (2 Kandidaten)
intake/web.md                       Scout-Bericht Web (2 Kandidaten)

vault/items/subagenten-werkzeugflut.md            Item + Score + 3 Bahnen
vault/items/subagenten-werkzeugflut-outline.md    Prep
vault/items/subagenten-werkzeugflut-vorschlag.md  was am Tor stand
vault/items/konfigurationspfade-ambig.md
vault/items/konfigurationspfade-ambig-outline.md
vault/items/konfigurationspfade-ambig-vorschlag.md

work/videos/subagenten-werkzeugflut/    auftrag.md folien.md skript.md faktencheck.md
work/builds/konfigurationspfade-ambig/  auftrag.md konfigpfade.py README.md
                                        test-bericht.md fixtures/{home,proj,wsl,
                                        roaming,broken,secretval}/config.toml
```

**`workspace/` ist bei Auslieferung leer** (es wird aus `seed/` gebaut und ist
in `.gitignore`). Damit du die Artefakte lesen kannst, ohne die Pipeline selbst
laufen zu lassen, liegen **zwei** protokollierte Läufe vollständig daneben:

```
beispiel-lauf/     dieselben 23 Dateien, unverändert aus dem Lauf oben
beispiel-lauf-2/   ein zweiter Lauf: 18 Artefakte + README.md als Protokoll,
                   mit den ausgelieferten, nachgeschärften Artefakten
```

Der Vergleich der beiden ist lehrreicher als jeder einzelne Lauf, weil er zeigt,
**was an dieser Pipeline nicht deterministisch ist**: `beispiel-lauf-2` bewertete
dieselben Quellen mit 87/81 statt 85/76, gab dem zweiten Item einen anderen Slug
und einen anderen Klassifikatorwert (`verwirrend` statt `schlecht_erklaert`) —
und landete über die Route-Tabelle trotzdem auf demselben Pfad. Genau die
Eigenschaft, die der Abschnitt „Der ehrliche Tausch: Prosa gegen Python" als
Preis benennt.

Zwei Dinge hat der zweite Lauf zusätzlich belegt, die hier vorher offen standen
(siehe [`beispiel-lauf-2/README.md`](beispiel-lauf-2/README.md)): dass die
Nachschärfung gegen die ungeplanten Karten greift, und dass `pump.sh` am Tor von
selbst endet. Ein Grenzfall kam dazu, den der erste Lauf nicht hatte: ein Item
mit **63 von 100** — zwei Punkte unter der Schwelle, also archiviert, ohne dass
je ein Mensch davon erfährt.

⚠ Im zweiten Lauf wurden **beide** Tore mit `approve` beantwortet. Der
`build`-Pfad kommt dort deshalb nicht vor — das gebaute Werkzeug, die Fixtures
und der Testbericht liegen nur in `beispiel-lauf/`.

Zwei Deliverables, beide durch **ein** menschliches Tor gegangen, beide mit
einer vollständigen Spur zurück bis zu dem Zitat, das sie ausgelöst hat:

```bash
grep -n "mkirsch" workspace/vault/items/subagenten-werkzeugflut.md
grep -n "score_breakdown" workspace/vault/items/*.md
```

### ⚠ Was in diesem Lauf schiefgegangen ist

Zwei der 21 Karten hat **niemand geplant**. Der `folien`-Worker hat, nachdem er
seine Folien geschrieben hatte, die nächsten Stufen der Kette **noch einmal
angelegt** — obwohl der Orchestrator sie längst erzeugt hatte:

```console
$ hermes kanban --board $BOARD list --json \
    | jq -r '.[]|select(.created_by=="triage-producer")|"\(.id)  \(.title)"'

t_cadab15d  Fulfill skript: subagenten-werkzeugflut        ← Duplikat von t_adca6c17
t_a3f76be7  Fulfill faktencheck: subagenten-werkzeugflut   ← gar nicht in triage.yaml
```

Die beiden `skript`-Karten liefen **gleichzeitig im selben Verzeichnis** und
haben dieselbe Datei geschrieben. Hier ging es gut aus, weil beide dasselbe
sollten — als Muster ist es kaputt.

Die Ursache ist banal: `auftrag.md` beschreibt die Kette, und ein Worker mit
`kanban_create` in der Hand ist hilfsbereit. **Wer einem Agenten das Werkzeug
zum Kartenanlegen gibt, muss ihm auch sagen, wann er es nicht benutzen darf.**

Die Artefakte dieser Story sind deshalb an zwei Stellen nachgeschärft:

```python
# Skill triage-pipeline, Stufe 3 — jede Fulfill-Karte:
idempotency_key = "fulfill-<slug>-<stufe>"
```

```
# SOUL.md von triage-builder / -tester / -producer:
- You are ONE stage of a chain that is already fully created. The stages
  after you exist as cards. Do NOT create cards yourself — not even when
  your brief describes the next stage.
```

`--idempotency-key` ist der belastbarere der beiden Griffe: er wirkt auch dann,
wenn ein Modell die Prosa-Regel überliest. Ein zweiter `kanban_create` mit
demselben Schlüssel legt nichts an, sondern gibt die vorhandene Kartennummer
zurück.

⚠ **Der oben protokollierte Lauf entstand *vor* dieser Nachschärfung** — er
zeigt das Problem, nicht die Lösung.

**Nachgemessen im zweiten Lauf** (`beispiel-lauf-2/`, mit den ausgelieferten
Artefakten): das Problem trat nicht mehr auf.

```console
$ hermes kanban --board $BOARD list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'

triage-orchestrator: 16   user: 3        ← kein triage-producer mehr
```

19 Karten statt 21. `faktencheck.md` entstand als **Datei** innerhalb der
`skript`-Stufe — so wie `pipeline/specs/video.md` es verlangt —, ohne dass eine
Karte dafür angelegt wurde. Auch die Karte, die damals entglitt
(`Fulfill folien: subagenten-werkzeugflut`), war dabei und hat nichts angelegt.

⚠ **Das ist ein Lauf, keine Beweisführung.** Der ursprüngliche Fehler war selbst
nicht deterministisch — ein Modell war hilfsbereit. Von den beiden Griffen ist
nur der `idempotency_key` strukturell wirksam; ob die Prosa-Regel in der
`SOUL.md` allein trägt, ist damit **nicht** gezeigt (siehe
[VERIFIKATION.md](../VERIFIKATION.md)).

---

## Was gegenüber dem Original anders ist

Die Vorlage ist ein Python-Projekt mit einer generischen Engine; diese Story
ist ein Hermes-Board mit sieben Profilen. Was das konkret bedeutet:

| Im Original | Hier | Warum |
|---|---|---|
| **Telegram** als Tor, `approve <slug>` als Chat-Antwort | `kanban block` / `unblock --reason` auf dem Board | Telegram braucht Bot-Token, `TELEGRAM_ALLOWED_USERS` und einen erreichbaren Gateway. Das Board kann jeder sofort. Die Semantik ist dieselbe: eine Entscheidung, drei Verben. |
| **Python-Engine** (`engine/engine.py`) rechnet Score, Route und Kartenketten aus | Skill `triage-pipeline` + `triage.yaml`, gelesen vom Worker | Hermes hat für Kartenketten schon einen Mechanismus (`kanban_create` + `parents`). Eine zweite Engine daneben wäre Verdopplung. **Das ist ein echter Tausch, keine reine Vereinfachung** — siehe unten. |
| **Live-Suche** auf X, Reddit, YouTube | eingefrorenes Korpus unter `sources/` | Reproduzierbarkeit. Ohne festes Korpus ist kein Durchlauf mit dem nächsten vergleichbar, und die Story bräuchte API-Schlüssel. |
| **Zwei Scout-Profile** mit zwei Modellen (eines auf Grok) | ein Profil `triage-scout`, zwei Karten | Ein zweites Modell ändert am Mechanismus nichts. Wenn du es willst: `--model`/`--provider` je Karte, siehe unten. |
| `proposal_actions.py` als Gate-Handler | Lauf 2 derselben Karte | Der Worker ist schon da und hat den Kontext. Ein externes Skript müsste ihn sich neu beschaffen. |
| `cost_gate_usd`, `scripts/cost_report.py` | nicht nachgebaut | Setzt Kostenspalten in der Telemetrie voraus, die diese Version nicht garantiert. `--max-runtime` und `--max-retries` sind der Deckel, den es hier gibt. |

### Der ehrliche Tausch: Prosa gegen Python

Das Original macht eine ausdrückliche These auf:

> **Fat engine, thin skill.** Multi-Agent-Pipelines scheitern, wenn zu viel
> Logik in Prosa lebt, die ein Modell bei jedem Lauf neu interpretiert.

Indem diese Story Rubrik, Route und Kettenbau in eine Skill legt, tut sie
genau das, wovor das Original warnt. Der Gewinn ist, dass keine zweite
Laufzeit neben Hermes steht. Der Preis ist real:

- Der Score ist eine **Modellentscheidung**, keine Summe, die ein Test prüfen
  kann. Zwei Läufe können 85 und 81 ergeben.
- Die Route ist eine Tabelle — aber ob der Klassifikator `schlecht_erklaert`
  oder `verwirrend` sagt, ist wieder Urteil.
- `python -m unittest discover -s tests` gibt es hier nicht.

**Was dagegen hilft, und was diese Story deshalb erzwingt:** jede Bewertung
wird **aufgeschrieben** — in die Item-Datei *und* in die Completion-Metadaten.
Damit ist sie nachprüfbar, auch wenn sie nicht deterministisch ist:

```bash
hermes kanban --board $BOARD show <triage-id> --json | jq '.latest_summary'
grep -A2 score_breakdown workspace/vault/items/*.md
```

Wenn du die Determinismus-These des Originals brauchst — weil du die Schwelle
gegen Auditoren verteidigen musst —, ist der Weg: `triage.yaml` von einem
Skript lesen, das den Score aus strukturierten Feldern **rechnet**, und den
Worker nur die Felder füllen lassen. Das Original zeigt in `engine/scoring.py`,
wie das aussieht.

> **[Story 11](../Story%2011%20-%20LLM%20Wiki/TUTORIAL.md) löst einen Teil dieser
> Rechnung ein.** Dort ist die Form der Wissensbasis kein Urteil mehr, sondern
> Code: 14 Regeln in `bin/kb_lint.py`, abgeleitet aus einer autoritativen
> `AGENTS.md`, mit einem gemessenen Ergebnis (5 Befunde vorher, 0 nachher, keine
> False Positives) — und einem Riegel, den kein Modell überlesen kann, weil
> `kb_git.py merge` einen Merge nach `main` verweigert, dessen Lint fehlschlägt.
> Der **Score** bleibt auch dort ein Urteil. Die beiden Stories sind ein Paar:
> diese hier benennt den Tausch, die nächste zeigt, wie weit man ihn
> zurücknehmen kann.

---

## Varianten

### Ein anderes Modell je Scout

Im Original läuft ein Scout auf Grok, der Rest auf GPT. Zwei Wege:

```bash
# a) pro Karte, ohne ein zweites Profil:
hermes kanban --board $BOARD create "Scout x: …" --assignee triage-scout \
    --model "x-ai/grok-4" --provider openrouter …

# b) ein zweites Profil mit eigener config.yaml:
hermes profile create triage-scout-x --no-skills --description "…"
hermes -p triage-scout-x config set model.default "x-ai/grok-4"
```

`--provider` verlangt `--model`. Der Rest der Pipeline merkt davon nichts —
das Board kennt nur den Profilnamen.

### Die Scouts auf einen Zeitplan setzen

```bash
./install-cron.sh                # taeglich 07:00
./install-cron.sh "every 12h"
./install-cron.sh --remove
```

Der Job läuft mit `--no-agent`: kein Modell, **keine Tokenkosten**. Das Skript
`scripts/scout-tick.sh` legt nur die drei Eingangskarten an; die Kosten
entstehen erst bei den Workern, die der Dispatcher danach startet. Die
`--idempotency-key`s enthalten das Datum — ein zweiter Tick am selben Tag legt
nichts Neues an.

⚠ Der Autor des Originals rät ausdrücklich davon ab, die Scouts stündlich
laufen zu lassen: **ein- bis zweimal täglich**. Jeder Tick zieht eine ganze
Pipeline nach sich.

### Das Tor über Telegram statt über das Board

Der Weg wäre `hermes kanban notify-subscribe` für die Benachrichtigung und
`hermes send --to telegram` im Orchestrator für den Vorschlagstext. Beides ist
in diesem Tutorial **nicht** verifiziert (keine Anbindung konfiguriert) — siehe
[VERIFIKATION.md](../VERIFIKATION.md).

Der Hinweis des Originals gilt unabhängig davon: **Telegram reserviert
`/commands`.** Eine Antwort heißt `approve <slug>`, nicht `/approve <slug>`.

---

## Fallstricke

- **`--initial-status blocked` als Tor.** Läuft durch, sobald die Eltern fertig
  sind. Nimm `block` bzw. `kanban_block`. Siehe Schritt 10.6.
- **Die Karte blockieren, während die Eltern schon fertig sind.** Zwischen
  `create` und `block` kann der Dispatcher zuschlagen — real passiert:
  `claimed` und `spawned` lagen vor dem `block`. Lege eine Tor-Karte immer mit
  einem noch offenen Elternteil an (dann ist sie `todo` und unantastbar), oder
  lass den Worker sich selbst blockieren, wie hier.
- **`hermes kanban block <id> --reason "…"`.** Existiert in v0.20.0 nicht. Der
  Grund ist positional, `--kind` gehört vor die Kartennummer.
- **Relativer `workspace_path` in `kanban_create`.** Die Karte wird angelegt und
  nie gestartet — ohne Fehlermeldung. Prüfen mit
  `hermes kanban show <id> --json | jq .task.workspace_path`.
- **Umsetzungskette auf `scratch`.** Die letzte Stufe findet nichts vor. Alle
  Stufen brauchen dasselbe `dir:`.
- **Ein laufendes Gateway startet Karten sofort**, auch auf einem frisch
  angelegten Board. Wer in Ruhe zusehen will: `hermes pause` / `hermes resume`.
- **Die Schwelle ist eine Entscheidung über deine Aufmerksamkeit.** Setzt du sie
  zu tief, landet Unsinn am Tor und du entscheidest dich müde. Zu hoch, und du
  erfährst nie von den Grenzfällen. 65 ist der Wert des Originals, kein
  Naturgesetz.

---

## Aufräumen

```bash
source task-ids.env
hermes kanban --board $BOARD list --tenant triage --json \
  | jq -r '.[].id' | xargs hermes kanban --board $BOARD archive
./reset-workspace.sh
```

Falls du den Cron-Job angelegt hast, **den zuerst** — sonst legt er weiter
Karten an:

```bash
./install-cron.sh --remove
hermes cron list          # muss "No scheduled jobs" zeigen
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

Die sieben `triage-`-Profile werden von keiner anderen Story benutzt —
`teardown.sh` ohne Schalter ist hier gefahrlos.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban block <id> "<grund>"` | Karte anhalten — Grund ist **positional** |
| `hermes kanban block --kind needs_input <id> "<grund>"` | Typisiert: wartet auf einen **Menschen**; `--kind` **vor** die ID |
| `hermes kanban unblock <id> --reason "<antwort>"` | Kommentar **und** Freigabe in einem Schritt — das Tor |
| `kanban_block(kind="needs_input", reason=…)` | dasselbe aus dem Worker heraus, auf der **eigenen** Karte |
| `kanban_create(…, workspace_kind="dir", workspace_path="<absolut>")` | Der Worker erweitert das Board selbst |
| `hermes kanban --board <b> dispatch --dry-run` | Prüfen, ob ein Tor wirklich hält |
| `hermes kanban show <id> --json \| jq .task.workspace_path` | Aufgelösten Workspace einer erzeugten Karte prüfen |
| `hermes kanban create … --model <m> --provider <p>` | Modell nur für diese Karte |
| `hermes kanban create … --skill <name>` | Skill in den Worker erzwingen |
| `hermes -p <profil> skills list` | Welche Skill liegt bei welchem Profil? |
| `hermes cron create "<plan>" --script <s> --no-agent --deliver local` | Scouts auf Zeitplan, tokenfrei |
