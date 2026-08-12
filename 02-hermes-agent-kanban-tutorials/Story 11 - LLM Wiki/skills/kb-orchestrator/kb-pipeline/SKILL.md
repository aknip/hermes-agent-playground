---
name: kb-pipeline
description: "Ablauf der Wissensbasis-Pipeline fuer den Orchestrator: Kandidaten gegen die Wissensbasis deduplizieren, gegen die Rubrik bewerten, zwei Recherche-Bahnen anlegen, die Route aufloesen, den Ingest-Vorschlag schreiben, Tor 1 halten, die Ingest-Kette serialisiert anlegen und an Tor 2 ueber Merge und Prune entscheiden lassen. Enthaelt die exakten kanban_create-Rezepte je Stufe."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Wissensbasis-Pipeline

Du bist der Orchestrator. Diese Skill sagt dir, **welche Stufe du gerade bist**
und **welche Karten du danach anlegst**. Die Fachlichkeit — Rubrik, Schwelle,
Route-Tabelle, Pfade, Tore — steht **nicht hier**, sondern in `ingest.yaml` in
deinem Workspace. Die Form der Wissensbasis steht in `wiki/AGENTS.md`. Lies
beide bei jeder Karte neu.

## Welche Stufe bin ich?

Am Titel deiner Karte:

| Titel beginnt mit | Stufe | Abschnitt |
|---|---|---|
| `Triage:` | Dedup gegen die Wissensbasis + Bewertung + Fan-out | [Stufe 1](#stufe-1--triage) |
| `Route:` | Klassifikation aufloesen, Prep + Tor 1 anlegen | [Stufe 2](#stufe-2--route) |
| `Vorschlag + Tor 1:` | Vorschlag schreiben, blockieren, Entscheidung ausfuehren | [Stufe 3](#stufe-3--vorschlag--tor-1) |
| `Commit + Tor 2:` | Merge und Prune vorlegen, blockieren, ausfuehren | [Stufe 4](#stufe-4--commit--tor-2) |

## Vier Regeln, die in jeder Stufe gelten

**1. Absolute Pfade.** Jede Karte, die du anlegst, bekommt
`workspace_kind="dir"` und einen **absoluten** `workspace_path`, gebaut aus
`$HERMES_KANBAN_WORKSPACE`. Ein relativer Pfad wird abgewiesen, und die Karte
wird nie gestartet.

**2. Ein Workspace fuer alle.** Anders als in Story 10 bekommen **alle** Karten
denselben Pfad, naemlich den Workspace selbst. Der Grund: die Wissensbasis ist
ein Git-Repository unter `wiki/`, und alle Stufen arbeiten daran. Es gibt hier
keine Unterverzeichnisse je Item.

**3. Sofort abschliessen.** Sobald die Folgekarten stehen, `kanban_complete`.

**4. `idempotency_key` bei jeder Karte, die du in einer Kette anlegst.** Ein
Worker, der seinen Auftrag liest und die Folgestufen darin beschrieben findet,
legt sie sonst ein zweites Mal an. Mit dem Schluessel bekommt der zweite Aufruf
die vorhandene Kartennummer zurueck.

---

## Stufe 1 — Triage

Eingang: die Scout-Berichte unter `intake/`. Sie stehen ausserdem als
Eltern-Handoff in deinem Kontext.

### 1.1 Buendeln

Bevor du dedupliziert: mehrere Kandidaten, die **dieselbe Seitengruppe**
betreffen und aus **demselben Vorgang** stammen, sind **ein** Item. Kriterium
steht in `ingest.yaml` unter `buendelung`. Zwei Patch-Releases derselben
Hauptversion sind ein Item, nicht zwei.

Der Slug beschreibt das Item, nicht die Quelle.

### 1.2 Dedup — gegen die Wissensbasis, nicht gegen die Kandidaten

Das ist der Unterschied zu einer Schmerzpunkt-Triage. Die Frage ist nicht
„haben wir das schon gemeldet", sondern **„wissen wir das schon"**.

Fuer jedes Item:

1. Nimm `betrifft_vermutlich` aus dem Scout-Bericht als Startpunkt, aber
   verlasse dich nicht darauf. Sieh in `wiki/index.md` nach, welche Seiten es
   gibt.
2. **Lies die betroffenen Seiten wirklich.** Nicht ueberfliegen, nicht aus dem
   Titel schliessen.
3. Notiere je Seite, was dort steht und in welcher Genauigkeit.

`abgedeckt` heisst: die Aussage steht dort in **gleicher Genauigkeit**. Eine
Seite, die das Thema erwaehnt, ist keine Abdeckung.

> Der wertvollste Ausgang dieser Pipeline ist der, bei dem sie **nichts** tut,
> weil sie es schon weiss. Wenn du hier oberflaechlich arbeitest, schreibt die
> Pipeline Wissen ein zweites Mal — und ein Widerspruch mit sich selbst ist
> teurer als eine Luecke.

Je Item eine Datei `vault/<slug>.md` mit diesem Kopf:

```markdown
---
slug: <slug>
titel: <titel>
status: triage
score: <n>
score_breakdown: {neuheit: n, quellenvertrauen: n, themenbezug: n,
                  versionsrelevanz: n, klarheitsgewinn: n}
wissensstand:        # leer, setzt die Bahn seiten-abgleich
route:               # leer, setzt die Route-Stufe
gebuendelt_aus: [<quelldatei>, ...]
betrifft: [<seite>, ...]
---
```

### 1.3 Bewerten

Vergib je Dimension aus `rubrik.dimensionen` einen Wert zwischen 0 und `max`,
mit **einem** Satz Begruendung je Dimension.

- Summe **unter** `rubrik.schwelle` → `status: geshelved` in die Item-Datei,
  Begruendung dazu, **und hier ist Schluss fuer dieses Item**. Kein Fan-out,
  keine Karte, kein Mensch.
- Ist ein Item nach 1.2 **bereits abgedeckt**, ist `neuheit` niedrig und die
  Summe faellt meist von selbst unter die Schwelle. Faellt sie es nicht, setze
  `status: geshelved` mit dem Grund `bereits abgedeckt` und der Fundstelle.
- Summe **ab** der Schwelle und nicht abgedeckt → `status: recherche`, weiter
  mit 1.4.

### 1.3b Der Deckel auf die Aufmerksamkeit

Die Schwelle sortiert nach Wichtigkeit; sie begrenzt die **Menge** nicht. Jedes
Item, das in den Fan-out geht, kostet den Menschen spaeter **zwei**
Entscheidungen. Deshalb steht in `ingest.yaml` unter `rubrik.max_pro_lauf` eine
Obergrenze.

Sind mehr Items ueber der Schwelle als `max_pro_lauf`:

1. Sortiere sie nach `score`, absteigend.
2. Die besten `max_pro_lauf` bekommen `status: recherche` und gehen in 1.4.
3. **Alle uebrigen bekommen `status: zurueckgestellt`** — nicht `geshelved`.
   Dazu ein Satz, dass nicht die Bewertung, sondern der Deckel sie
   zurueckgehalten hat, und ihr Rang. Die Item-Datei bleibt vollstaendig
   erhalten; der naechste Sweep nimmt sie auf.
4. Nenne beides in der Summary: wie viele in den Fan-out gingen und wie viele
   der Deckel zurueckgehalten hat.

`zurueckgestellt` ist ausdruecklich **kein** Urteil ueber das Item. Verwechselst
du es mit `geshelved`, verschwindet ein Item, das die Schwelle bestanden hat, mit
einer Begruendung, die nicht zutrifft.

> Ein Tor, an dem zwoelf Karten warten, wird nicht sorgfaeltiger beantwortet als
> eines mit drei — es wird unsorgfaeltiger. Die knappe Ressource dieser Pipeline
> ist die Aufmerksamkeit am Tor, nicht das Token-Budget.

### 1.4 Fan-out anlegen

Fuer **jedes** Item ab der Schwelle: je Bahn aus `recherche_bahnen.bahnen` eine
Karte, danach **genau eine** Route-Karte mit allen Bahnen als parents.
`WS` ist `$HERMES_KANBAN_WORKSPACE`.

```
Fuer jede Bahn L in recherche_bahnen.bahnen:
  kanban_create(
    title           = "Bahn <L>: <slug>",
    assignee        = <recherche_bahnen.rolle>,
    parents         = [<deine eigene Kartennummer>],
    workspace_kind  = "dir",  workspace_path = "<WS>",
    tenant          = "wiki",
    idempotency_key = "lane-<slug>-<L>",
    body            = <Auftrag der Bahn>,
  )

Danach GENAU EINE Route-Karte:
  kanban_create(
    title           = "Route: <slug>",
    assignee        = "kb-orchestrator",
    parents         = [<alle Bahn-Karten>],        # <- Fan-in
    workspace_kind  = "dir",  workspace_path = "<WS>",
    tenant          = "wiki",
    idempotency_key = "route-<slug>",
    body            = "Item <slug>. Loese die Route auf. Skill kb-pipeline, Stufe 2.",
  )
```

Der Bahn-Auftrag nennt immer: den Slug, die Item-Datei, die Ausgabedatei unter
`vault/`, die Frage der Bahn — und bei der Bahn aus `klassifikator_bahn` die
Pflicht, als **letzte Zeile** `wissensstand: <wert>` mit einem Wert aus
`route.tabelle` zu liefern.

Die Bahn-Karten bekommen **deine** Karte als Elternteil und stehen damit auf
`todo`, bis du fertig bist — richtig so, denn vorher gibt es die Item-Dateien
nicht.

### 1.5 Abschluss

```
kanban_complete(
  summary  = "<n> Kandidaten aus <quellen> zu <m> Items gebuendelt; "
             "<a> geshelved (davon <b> bereits abgedeckt), "
             "<z> zurueckgestellt (Deckel max_pro_lauf), <s> im Fan-out",
  metadata = {"items": [{"slug":…, "score":…, "status":…, "betrifft":[…]}, …],
              "zurueckgestellt": [<slugs>],
              "spawned": [<alle angelegten Kartennummern>]},
)
```

---

## Stufe 2 — Route

Eingang: die Bahn-Ergebnisse, als Eltern-Handoffs **und** unter `vault/`.

1. Lies aus der Klassifikator-Bahn die letzte Zeile: `wissensstand: <wert>`.
2. Schlage den Wert in `route.tabelle` nach — **mehr nicht**. Steht er dort
   nicht: `kanban_block(kind="needs_input", reason=…)` mit dem gelieferten Wert
   im Grund. **Rate nicht.**
3. Schreibe `wissensstand:` und `route:` in den Kopf der Item-Datei.
4. Ist der Pfad `auto: true` (also `shelve`): `status: abgelegt` setzen,
   Begruendung dazu, abschliessen. **Keine weitere Karte, kein Tor.**
5. Sonst: Prep-Kette (falls `paths.<route>.prep` nicht leer ist), dann die
   Tor-1-Karte.

```
Fuer jede Stufe P in paths.<route>.prep (der Reihe nach, verkettet):
  kanban_create(
    title           = "Prep <P.stufe>: <slug>",
    assignee        = <P.rolle>,
    parents         = [<vorherige Prep-Karte>] bzw. [<deine Karte>] bei der ersten,
    workspace_kind  = "dir",  workspace_path = "<WS>",
    tenant          = "wiki",
    idempotency_key = "prep-<slug>-<P.stufe>",
    body            = <Auftrag>,
  )

Zuletzt Tor 1:
  kanban_create(
    title           = "Vorschlag + Tor 1: <slug>",
    assignee        = <paths.<route>.propose.rolle>,
    parents         = [<letzte Prep-Karte>] bzw. [<deine Karte>] ohne Prep,
    workspace_kind  = "dir",  workspace_path = "<WS>",
    tenant          = "wiki",
    idempotency_key = "tor1-<slug>",
    body            = "Item <slug>, Route <route>. "
                      "Vorlage <paths.<route>.propose.vorlage>. "
                      "Skill kb-pipeline, Stufe 3.",
  )
```

Abschluss mit `metadata={"slug":…, "wissensstand":…, "route":…, "spawned":[…]}`.

---

## Stufe 3 — Vorschlag + Tor 1

Diese Karte laeuft **zweimal**. Erst schreibst du den Vorschlag und haeltst an;
dann kommt die Entscheidung, und du fuehrst sie aus.

### Lauf 1 — Vorschlag schreiben und anhalten

1. Lies die Vorlage aus `paths.<route>.propose.vorlage` (unter `proposals/`) und
   fuelle sie aus der Item-Datei und den Bahn-Ergebnissen. Platzhalter in
   spitzen Klammern werden **ersetzt**, nicht uebernommen.
2. Schreibe sie nach `vault/<slug>-vorschlag.md`.
3. `status: wartet_auf_tor1` in die Item-Datei.
4. **Halte an:**

```
kanban_block(
  kind   = "needs_input",
  reason = "TOR 1 <slug> (<route>, <score>/100): <ein Satz, was in die "
           "Wissensbasis geschrieben wuerde und welche Seiten das beruehrt>. "
           "Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'",
)
```

Bei Route `konflikt` beginnt der Grund mit `TOR 1 ⚠ KONFLIKT <slug>` und nennt
**beide** Aussagen in einem Satz. Der Mensch muss ohne die Datei sehen koennen,
dass hier zwei Dinge gegeneinander stehen.

Der `reason` ist das, was der Mensch **liest** — in `kanban list`, in `runs` und
im Drawer. Schreib ihn so, dass man ohne die Datei entscheiden kann.

### Lauf 2 — die Entscheidung ausfuehren

Du bist wieder da, weil ein Mensch `unblock --reason "…"` gerufen hat. Seine
Antwort steht als **Kommentar** an deiner Karte (`kanban_show`). Das erste Wort
ist das Verb.

| Verb | Was du tust |
|---|---|
| `shelve` | `status: abgelegt` + Grund in die Item-Datei. **Keine Karte.** Abschliessen. |
| `modify` | Die Aenderung in den Auftrag uebernehmen, dann weiter wie `approve`. |
| `modify` mit einem anderen **Routennamen** | Routenkorrektur, siehe unten. |
| `approve` | Ingest-Kette anlegen, siehe unten. |
| nichts davon | `kanban_block(kind="needs_input", reason="Antwort nicht verstanden: '<text>'. Bitte approve, shelve oder modify.")` |

**Routenkorrektur.** Nennt die Antwort einen Pfad aus `paths:`, der nicht der
eingetragene ist, dann korrigiert der Mensch die Route. Er darf das: die Route
ist ein Nachschlagen in einer Tabelle, gefuettert von einem Urteil, und Urteile
sind falsifizierbar. Schreibe `route: <neu>` in die Item-Datei, vermerke
darunter **wer** korrigiert hat und **mit welcher Begruendung**, und lass den
urspruenglichen `wissensstand` **stehen** — er wird nicht ueberschrieben, er
wird widerlegt. Die Prep-Stufen des neuen Pfades werden **nicht** nachgeholt.

### Bei `approve`: die Ingest-Kette — serialisiert

⚠ **Vor dem Anlegen: nachsehen, ob ein anderer Ingest offen ist.** Alle Ingests
arbeiten im **selben** Arbeitsbaum. Zwei gleichzeitig ueberschreiben sich.

```
offene = kanban_list()   # nach Karten filtern, deren Titel mit
                         # "Commit + Tor 2:" beginnt und deren Status
                         # NICHT "done" ist — und die nicht zu <slug> gehoeren
```

- Ist **eine** solche Karte offen: ihre Kartennummer wird `parents` der
  **ersten** Karte deiner Kette. Deine Kette wartet dann in `todo`, bis der
  fremde Ingest gemergt oder verworfen ist.
- Ist **keine** offen: die erste Karte deiner Kette bekommt **bewusst keinen**
  Elternteil. Haengst du sie an deine eigene Karte, wartet sie, bis du fertig
  bist — und wenn du aus irgendeinem Grund noch einmal blockierst, wartet sie
  fuer immer.

Das ist die **kooperative** Ebene des Konkurrenzschutzes. Die **deterministische**
liegt in `bin/kb_git.py branch`: der Aufruf weist ab, solange ein anderer
Ingest-Branch nicht in `main` ist. Er haelt auch dann, wenn diese Pruefung hier
versagt.

Dann die drei Stufen aus `paths.<route>.fulfill`, verkettet:

```
kanban_create(
  title           = "Ingest: <slug>",
  assignee        = "kb-ingestor",
  parents         = [<fremde Commit-Karte>] oder [],
  workspace_kind  = "dir",  workspace_path = "<WS>",
  tenant          = "wiki",
  idempotency_key = "ingest-<slug>",
  max_runtime_seconds = 1800,
  body            = <Auftrag, siehe unten>,
)
kanban_create(
  title = "Lint: <slug>", assignee = "kb-linter",
  parents = [<Ingest-Karte>], idempotency_key = "lint-<slug>", …
)
kanban_create(
  title = "Commit + Tor 2: <slug>", assignee = "kb-orchestrator",
  parents = [<Lint-Karte>], idempotency_key = "commit-<slug>", …
)
```

Der **Ingest-Auftrag** enthaelt, vollstaendig ausgeschrieben:

- den Slug, die Route, den Branchnamen `kb/ingest-<slug>`
- den **Wortlaut der menschlichen Antwort** — verbatim, nicht zusammengefasst.
  Der Ingestor soll lesen, was der Mensch gesagt hat, nicht, was du daraus
  gemacht hast.
- den Pfad auf `vault/<slug>-vorschlag.md` und die betroffenen Seiten
- den Satz: **„Die Folgestufen dieser Kette (Lint, Commit) sind bereits
  angelegt. Lege selbst KEINE weiteren Karten an."**
- bei Route `konflikt`: welche der beiden Aussagen gewinnt und dass die
  widerlegte **ersetzt** wird, nicht ergaenzt.

Dann `status: ingest` in die Item-Datei und **sofort**:

```
kanban_complete(
  summary  = "approve <slug>: Ingest-Kette angelegt (3 Karten), Branch "
             "kb/ingest-<slug>[, wartet auf <fremder slug>]",
  metadata = {"slug":…, "decision":"approve", "route":…, "branch":…,
              "serialisiert_hinter": <id oder null>, "spawned":[…]},
)
```

---

## Stufe 4 — Commit + Tor 2

Auch diese Karte laeuft **zweimal**. Sie ist das zweite Tor, und sie ist eine
**eigene Karte**, nicht ein zweiter Block auf Tor 1.

⚠ Der Grund ist gemessen: `BLOCK_RECURRENCE_LIMIT` ist 2 und wird **pro
Block-Art** gezaehlt. Ein zweiter `kanban_block` mit derselben Art nach einem
`unblock` schickt die Karte in die **Triage**, nicht nach `blocked` (Ereignis
`block_loop_detected`). Zwei Tore auf einer Karte gehen nur mit zwei
verschiedenen Arten und genau einmal je Art. Zwei Karten gehen immer.

### Lauf 1 — Merge vorlegen und anhalten

1. Lies den Lint-Bericht der Elternkarte. Steht dort `errors_after > 0`, hat
   der Merge keine Chance — `bin/kb_git.py merge` wird ihn abweisen. Blockiere
   dann mit genau dieser Auskunft, statt ein Tor vorzulegen, das nichts
   entscheiden kann.
2. Lass dir zeigen, was der Branch aendert:

```
python3 bin/kb_git.py changed kb/ingest-<slug>
```

3. Fasse fuer den Menschen **drei** Dinge zusammen: was inhaltlich hinzukommt,
   was der Linter gemeldet und repariert hat, und **was geloescht werden
   wuerde**. Der dritte Punkt ist der Grund, warum dieses Tor existiert.
4. **Halte an:**

```
kanban_block(
  kind   = "capability",          # NICHT needs_input — siehe oben
  reason = "TOR 2 <slug>: Branch kb/ingest-<slug> — <n> Seiten neu, <m> geaendert, "
           "Lint <errors_before>→<errors_after> ERROR. "
           "PRUNE: <was geloescht wuerde, oder 'nichts'>. "
           "Antwort: unblock --reason 'merge' | 'merge-ohne-prune' | 'discard: <grund>'",
)
```

Steht bei PRUNE etwas anderes als `nichts`, gehoert **wortwoertlich** in den
Grund, was verschwindet. Ein Mensch, der `merge` tippt, ohne das gelesen zu
haben, hat nicht entschieden — er hat quittiert.

### Lauf 2 — die Entscheidung ausfuehren

| Verb | Was du tust |
|---|---|
| `merge` | `kb_git.py merge kb/ingest-<slug>` — Ingest und Lint haben ihre Arbeit schon committet. Liegt trotzdem etwas im Arbeitsbaum, erst `kb_git.py commit -m "…"`. |
| `merge-ohne-prune` | Die Loeschungen auf dem Branch **zuruecknehmen** (Seiten/Absaetze wiederherstellen, `status: strittig` statt Entfernen), dann committen und mergen |
| `discard` | `kb_git.py discard kb/ingest-<slug>`. `main` bleibt unveraendert. `status: verworfen` + Grund in die Item-Datei. |
| nichts davon | `kanban_block(kind="capability", reason="Antwort nicht verstanden: …")` |

Weist `kb_git.py merge` ab, weil der Lint fehlschlaegt: **nicht** nachhelfen und
nicht am Linter drehen. Lege eine neue Lint-Karte an
(`idempotency_key = "lint-<slug>-2"`) und schliesse mit dem Befund ab.

Trage die Entscheidung in `wiki/log/ingest-log.md` ein — beide Tore, im Wortlaut,
im Format aus `AGENTS.md` 7.2. **Das ist die einzige Stelle, an der eine
menschliche Entscheidung dauerhaft im Repository steht.**

```
kanban_complete(
  summary  = "<verb> <slug>: <n> Seiten in main, Lint bestanden, "
             "Prune <ausgefuehrt|zurueckgenommen|keiner>",
  metadata = {"slug":…, "decision":…, "branch":…, "merged": true|false,
              "pruned": [...], "commit": "<hash>"},
)
```

## Was du nie tust

- Ein Item unter der Schwelle einem Menschen vorlegen.
- Ein zweites Mal mit derselben Block-Art blockieren, um etwas nachzufragen.
- Selbst freigeben, mergen oder prunen, weil der Vorschlag ueberzeugend aussieht.
- `git` direkt aufrufen. `bin/kb_git.py` hat sechs Verben, und das ist die
  ganze erlaubte Flaeche.
- Zwei Ingests gleichzeitig starten lassen.
- Einen Widerspruch zugunsten der neueren Quelle „aufloesen", ohne zu fragen.
