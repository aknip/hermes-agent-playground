---
name: triage-pipeline
description: "Ablauf der Triage-Pipeline fuer den Orchestrator: Kandidaten deduplizieren, gegen die Rubrik bewerten, den Recherche-Fan-out anlegen, die Route aufloesen, den Vorschlag schreiben und das menschliche Tor halten. Enthaelt die exakten kanban_create-Rezepte je Stufe."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Triage-Pipeline

Du bist der Orchestrator. Diese Skill sagt dir, **welche Stufe du gerade
bist** und **welche Karten du danach anlegst**. Die Fachlichkeit — Rubrik,
Schwelle, Route-Tabelle, Pfade — steht **nicht hier**, sondern in
`pipeline/triage.yaml` in deinem Workspace. Lies sie bei jeder Karte neu.

## Welche Stufe bin ich?

Am Titel deiner Karte:

| Titel beginnt mit | Stufe | Abschnitt |
|---|---|---|
| `Triage:` | Dedup + Bewertung + Fan-out | [Stufe 1](#stufe-1--triage) |
| `Route:` | Klassifikation aufloesen, Prep + Tor anlegen | [Stufe 2](#stufe-2--route) |
| `Vorschlag + Tor:` | Vorschlag schreiben, blockieren, entscheiden | [Stufe 3](#stufe-3--vorschlag--tor) |

## Zwei Regeln, die in jeder Stufe gelten

**1. Absolute Pfade.** Jede Karte, die du anlegst, bekommt
`workspace_kind="dir"` und einen **absoluten** `workspace_path`. Du baust ihn
aus `$HERMES_KANBAN_WORKSPACE`. Ein relativer Pfad wird abgewiesen, und die
Karte wird nie gestartet — ohne Fehlermeldung auf dem Board.

**2. Sofort abschliessen.** Sobald die Folgekarten stehen, rufst du
`kanban_complete`. Solange deine Karte offen ist, warten alle Kinder in `todo`.

---

## Stufe 1 — Triage

Eingang: die Scout-Berichte unter `intake/`. Du bekommst sie ausserdem als
Eltern-Handoff in deinem Kontext.

### 1.1 Dedup

Vergleiche jeden Kandidaten gegen die bereits vorhandenen Dateien unter
`vault/items/`. Kriterium steht in `triage.yaml` unter `dedup.hinweis`:
**derselbe Fehlermechanismus = dasselbe Item**, auch bei anderer Wortwahl,
anderer Oberflaeche, anderer Quelle.

- **Duplikat** → keine neue Datei. Haenge die Quelle an das vorhandene Item an
  (Abschnitt `## Quellen`) und notiere im Kopf `duplikate:` die Herkunft.
- **Neu** → lege `vault/items/<slug>.md` an. Der Slug ist kurz, klein
  geschrieben, mit Bindestrichen, aus dem Kern des Problems gebildet
  (`subagenten-werkzeugflut`, nicht `item-1`).

Kopf jeder Item-Datei:

```markdown
---
slug: <slug>
titel: <titel>
status: triage
score: <n>
score_breakdown: {haeufigkeit: n, schmerzintensitaet: n, ...}
pfad: <leer, setzt die Route-Stufe>
duplikate: [<datei>, ...]
---
```

### 1.2 Bewerten

Vergib je Dimension aus `rubrik.dimensionen` einen Wert zwischen 0 und `max`.
Begruende jede Dimension in **einem** Satz mit Bezug auf die Quellen.

- Summe **unter** `rubrik.schwelle` → `status: archiviert` in die Item-Datei,
  Begruendung dazu, **und hier ist Schluss fuer dieses Item**. Kein Fan-out,
  keine Karte, kein Mensch. Das ist der Sinn der Schwelle.
- Summe **ab** `rubrik.schwelle` → `status: recherche`, weiter mit 1.3.

### 1.3 Fan-out anlegen

Fuer **jedes** Item ab der Schwelle legst du **vier** Karten an. `WS` ist
`$HERMES_KANBAN_WORKSPACE`.

```
Fuer jede Bahn L in recherche_bahnen.bahnen:
  kanban_create(
    title       = "Bahn <L>: <slug>",
    assignee    = <recherche_bahnen.rolle>,
    parents     = [<deine eigene Kartennummer>],
    workspace_kind = "dir",  workspace_path = "<WS>",
    tenant      = "triage",
    body        = <Auftrag der Bahn, siehe unten>,
  )

Danach GENAU EINE Route-Karte:
  kanban_create(
    title       = "Route: <slug>",
    assignee    = "triage-orchestrator",
    parents     = [<die drei Bahn-Karten>],       # <- Fan-in, alle drei
    workspace_kind = "dir",  workspace_path = "<WS>",
    tenant      = "triage",
    body        = "Item <slug>. Loese die Route auf. Siehe Skill triage-pipeline, Stufe 2.",
  )
```

Der Bahn-Auftrag nennt immer: den Slug, die Item-Datei, die Frage der Bahn,
und — bei der Bahn aus `klassifikator_bahn` — die Pflicht, als letzte Zeile
`loesungsqualitaet: <wert>` mit einem Wert aus `route.tabelle` zu liefern.

Die Bahn-Karten bekommen **deine** Karte als Elternteil. Sie stehen damit auf
`todo` und starten erst, wenn du fertig bist — genau richtig, denn vorher gibt
es die Item-Dateien noch nicht.

### 1.4 Abschluss

```
kanban_complete(
  summary  = "<n> Kandidaten, <d> Duplikate, <a> unter der Schwelle archiviert, <s> im Fan-out",
  metadata = {"items": [{"slug":…, "score":…, "status":…}, …],
              "spawned": [<alle angelegten Kartennummern>]},
)
```

---

## Stufe 2 — Route

Eingang: die drei Bahn-Ergebnisse. Sie stehen in deinem Kontext als
Eltern-Handoffs **und** in der Item-Datei.

1. Lies aus der Klassifikator-Bahn den Wert `loesungsqualitaet`.
2. Schlage ihn in `route.tabelle` nach. Steht er dort nicht: `kanban_block`
   mit dem gelieferten Wert im Grund. **Rate nicht.**
3. Schreibe `pfad: <name>` in den Kopf der Item-Datei.
4. Ist der Pfad `auto: true` (z. B. `shelve`): `status: abgelegt` setzen,
   Begruendung dazu, abschliessen. **Keine weitere Karte.**
5. Sonst lege die Prep-Kette und danach die Tor-Karte an:

```
Fuer jede Stufe P in paths.<pfad>.prep (der Reihe nach, verkettet):
  kanban_create(
    title       = "Prep <P.stufe>: <slug>",
    assignee    = <P.rolle>,
    parents     = [<vorherige Prep-Karte>]  bzw. [<deine Karte>] bei der ersten,
    workspace_kind = "dir",  workspace_path = "<WS>",
    tenant      = "triage",
    body        = <Auftrag + Pfad auf rails/spec aus dem Pfad>,
  )

Zuletzt die Tor-Karte:
  kanban_create(
    title       = "Vorschlag + Tor: <slug>",
    assignee    = <paths.<pfad>.propose.rolle>,
    parents     = [<letzte Prep-Karte>],
    workspace_kind = "dir",  workspace_path = "<WS>",
    tenant      = "triage",
    body        = "Item <slug>, Pfad <pfad>. Vorlage <paths.<pfad>.propose.vorlage>. "
                  "Siehe Skill triage-pipeline, Stufe 3.",
  )
```

Abschluss mit `metadata={"slug":…, "loesungsqualitaet":…, "pfad":…, "spawned":[…]}`.

---

## Stufe 3 — Vorschlag + Tor

Diese Karte laeuft **zweimal**. Erst schreibst du den Vorschlag und haeltst an;
dann kommt die Entscheidung des Menschen, und du fuehrst sie aus.

### Lauf 1 — den Vorschlag schreiben und anhalten

1. Lies die Vorlage aus `paths.<pfad>.propose.vorlage` und fuelle sie aus dem
   Item und der Prep-Ausgabe. Platzhalter in spitzen Klammern werden ersetzt,
   nicht uebernommen.
2. Schreibe sie nach `vault/items/<slug>-vorschlag.md`.
3. Setze `status: wartet_auf_freigabe` in der Item-Datei.
4. **Halte an:**

```
kanban_block(
  kind   = "needs_input",
  reason = "FREIGABE <slug> (<pfad>, <score>/100): <ein Satz, was gebaut/produziert wird>. "
           "Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'",
)
```

Der `reason` ist das, was der Mensch **liest** — er steht in `kanban list`,
in `runs` und im Drawer. Schreib ihn so, dass man ohne die Datei entscheiden
kann.

Dass der Block haelt, liegt daran, dass `kanban_block` ueberhaupt ein Ereignis
schreibt — nicht am `kind`. `needs_input` ist trotzdem die richtige Angabe: sie
sagt jedem Leser, dass hier ein Mensch wartet. `dependency` taete das Gegenteil
und wuerde automatisch befoerdert, sobald die Eltern fertig sind.

### Lauf 2 — die Entscheidung ausfuehren

Du bist wieder da, weil ein Mensch `unblock --reason "…"` gerufen hat. Seine
Antwort steht als **Kommentar** an deiner Karte — lies den Kommentar-Thread
(`kanban_show`). Das erste Wort ist das Verb.

| Verb | Was du tust |
|---|---|
| `shelve` | `status: abgelegt` + Grund in die Item-Datei. **Keine Karte.** Abschliessen. |
| `modify` | Die genannte Aenderung in den Auftrag uebernehmen, dann weiter wie `approve`. |
| `approve` | Umsetzungskette anlegen, siehe unten. |
| `modify` mit einem **anderen Pfadnamen** | Der Mensch korrigiert die Route. Siehe unten. |
| nichts davon | `kanban_block(kind="needs_input", reason="Antwort nicht verstanden: '<text>'. Bitte approve, shelve oder modify.")` |

**Bei `modify` mit einem anderen Pfadnamen — der Mensch korrigiert die Route:**

Nennt die Antwort einen Pfad aus `paths:`, der nicht der eingetragene ist
(„Route auf build korrigieren", „mach ein Video daraus"), dann ist das eine
**Routenkorrektur** und keine Detailaenderung. Der Mensch darf das: die Route
ist ein Nachschlagen in einer Tabelle, gefuettert von einem Urteil, und Urteile
sind falsifizierbar.

1. `pfad: <neuer pfad>` in den Kopf der Item-Datei schreiben und darunter
   vermerken, **wer** korrigiert hat und **mit welcher Begruendung**. Den
   urspruenglichen Klassifikatorwert stehen lassen — er wird nicht ueberschrieben,
   er wird widerlegt.
2. Danach weiter wie bei `approve`, aber mit `paths.<neuer pfad>`:
   dessen `unterverzeichnis`, dessen `rails`/`spec`, dessen `fulfill`-Stufen.
3. Die **Prep-Stufen des neuen Pfades werden nicht nachgeholt**. Der Mensch hat
   auf Basis des vorhandenen Vorschlags entschieden; was ihm dabei gefehlt hat,
   stand in seiner Antwort. Nimm sie in `auftrag.md` auf.
4. In den Metadaten: `"decision": "modify"`, `"pfad_alt"`, `"pfad_neu"`.

**Bei `approve`:**

1. Lege das dauerhafte Arbeitsverzeichnis an:
   `<WS>/work/<paths.<pfad>.unterverzeichnis>/<slug>/` — als **absoluten** Pfad.
2. Schreibe dort `auftrag.md` hinein. Es enthaelt, vollstaendig ausgeschrieben:
   den freigegebenen Vorschlag, den Wortlaut der menschlichen Antwort, und den
   **Inhalt** der Rails- bzw. Spec-Datei des Pfades.
   **Kopieren, nicht verlinken.** Die Worker der Umsetzungskette laufen in
   diesem Verzeichnis und sehen den Rest des Workspace nicht.
3. Lege die Kette an:

```
Erste Stufe aus paths.<pfad>.fulfill — OHNE parents:
  kanban_create(
    title = "Fulfill <stufe>: <slug>", assignee = <rolle>,
    workspace_kind  = "dir",
    workspace_path  = "<WS>/work/<unterverzeichnis>/<slug>",   # absolut!
    tenant          = "triage",
    idempotency_key = "fulfill-<slug>-<stufe>",                # Pflicht!
    body            = <Auftrag>,
  )
Jede weitere Stufe: parents = [<vorherige Fulfill-Karte>], gleicher Pfad,
eigener idempotency_key.
```

⚠ **`idempotency_key` ist hier nicht optional.** Ein Worker der Kette, der
seinen Auftrag liest und die Folgestufen darin beschrieben findet, legt sie
sonst ein zweites Mal an — beide laufen dann gleichzeitig im selben
Verzeichnis und überschreiben sich. Mit dem Schlüssel bekommt der zweite
Aufruf die vorhandene Kartennummer zurück, statt eine Karte zu erzeugen.

Und in **jeden** Fulfill-Auftrag gehört der Satz:

> Die Folgestufen dieser Kette sind bereits angelegt. Lege selbst KEINE
> weiteren Karten an.

   Die erste Karte bekommt **bewusst keinen Elternteil**. Haengst du sie an
   deine eigene Karte, wartet sie, bis du fertig bist — und wenn du aus
   irgendeinem Grund noch einmal blockierst, wartet sie fuer immer.

4. `status: umsetzung` in die Item-Datei, dann **sofort**:

```
kanban_complete(
  summary  = "approve <slug>: Umsetzungskette angelegt (<n> Karten) in work/<uv>/<slug>/",
  metadata = {"slug":…, "decision":"approve", "pfad":…,
              "arbeitsverzeichnis": "<absoluter Pfad>", "spawned": [...]},
)
```

## Was du nie tust

- Ein Item unter der Schwelle einem Menschen vorlegen.
- Ein zweites Mal blockieren, um etwas nachzufragen, das im ersten Lauf schon
  klar war.
- Selbst freigeben, weil der Vorschlag ueberzeugend aussieht.
- Eine Umsetzungskarte auf `scratch` legen. Wegwerf-Verzeichnisse werden
  zwischen Karten geleert, und die letzte Stufe steht dann vor nichts.
