# Story 11 — LLM-Wiki: zwei Tore, ein Vertrag, ein Linter aus Code

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt. Wer Story 10 kennt, findet
hier die Fortsetzung — inhaltlich *und* in einem Punkt, den Story 10 offen
gelassen hat.

Basiert auf `/Docs/Hermes Agent Kanban Workflow - LLM Wiki - Video und Github-Repo.md`

| | |
|---|---|
| Board | `kanban-story-11` |
| Profile | `kb-scout`, `kb-orchestrator`, `kb-researcher`, `kb-ingestor`, `kb-linter` |
| Mandant | `wiki` |
| Workspace-Art | `dir:` — **ein** gemeinsamer Raum für alle Karten; die Wissensbasis darin ist ein **Git-Repository** |
| Menschliche Tore | **zwei je Item** — Aufnahme und Merge/Prune, mit **verschiedenen** Verben |
| Dauer | ca. 1½ Stunden: ~45 min Maschinenarbeit + vier Wartepunkte für deine Entscheidungen (der protokollierte Lauf brauchte 2 h 12 min, davon 46 min Standby) |
| Vorlagen | [tonbistudio/llm-wiki](https://github.com/tonbistudio/llm-wiki), [tonbistudio/hermes-multi-agent-workflow](https://github.com/tonbistudio/hermes-multi-agent-workflow) |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS, Python 3.11.9, `git`, `jq` |
| Braucht zusätzlich | `git` und `python3` (nur Standardbibliothek) |

---

## Worum es geht

Story 10 baut eine Pipeline, die Themen **findet** und daraus etwas **Neues**
produziert. Diese hier baut eine Pipeline, die eine **bestehende Wissensbasis
pflegt** — und Pflege ist eine andere Aufgabe als Produktion, weil sie
zusätzlich löschen muss.

```
 sources/releases     ─▶ Scout ─┐
 sources/transcripts  ─▶ Scout ─┤
                                ├─▶ Triage ── Bündeln ── Dedup gegen die
                                │              WISSENSBASIS ── Rubrik
                                │                    │
                                │                    ├─▶ abgedeckt oder unter 65:
                                │                    │   geshelved. Ende.
                                │                    │   Kein Mensch wird gefragt.
                                │                    ▼
                                │        je Item, selbst angelegt:
                                │          ├─▶ Bahn verifikation    ─┐
                                │          └─▶ Bahn seiten-abgleich ─┴─▶ Route
                                │                   (parallel)           │
                                │        ┌────────────────────────────────┘
                                │        │  Route-Tabelle aus ingest.yaml
                                │   ┌────┼──────────┬──────────────┐
                                │ fehlt  unvoll-   wider-        abgedeckt
                                │   │    ständig   spruch           │
                                │   ▼       ▼         ▼             ▼
                                │  neue_  update   konflikt      shelve
                                │  seite     │    (+ Dossier)   (automatisch)
                                │   └────────┴─────────┘
                                │            ▼
                                │  ╔═══════════════════════════════════╗
                                │  ║  TOR 1   approve · shelve · modify║
                                │  ╚═══════════════════════════════════╝
                                │            ▼
                                │     Ingest   ← Branch kb/ingest-<slug>
                                │            ▼     serialisiert: einer nach dem anderen
                                │     Lint     ← bin/kb_lint.py, deterministisch
                                │            ▼
                                │  ╔═══════════════════════════════════╗
                                └─▶║  TOR 2   merge · merge-ohne-prune ║
                                   ║          · discard                ║
                                   ╚═══════════════════════════════════╝
                                             ▼
                                    Merge nach main — nur wenn der Lint besteht
```

Das ist der Workflow aus dem LLM-Wiki-Video von **Tonbi's AI Garage**,
nachgebaut mit Hermes-Bordmitteln. **Fünf** Dinge lernst du hier, die in keiner
anderen Story vorkommen:

| | |
|---|---|
| **Ein Vertrag, zwei Leser** | `wiki/AGENTS.md` ist die einzige autoritative Datei. Der Ingestor **schreibt** danach, der Linter **prüft** dagegen. Eine Domäne, in der beide Rollen dieselbe Datei lesen, braucht fast keine neue Logik. |
| **Ein Linter aus Code, nicht aus Prosa** | 14 Regeln in `bin/kb_lint.py`. Damit löst diese Story die Rechnung ein, die Story 10 unter „Der ehrliche Tausch" offen lässt — und sie ist der einzige Test dieser Story, der **ohne Modell** läuft und bei jedem Lauf dasselbe Ergebnis liefert. |
| **Zwei Tore mit zwei Vokabularen** | Aufnehmen und Löschen sind nicht dieselbe Entscheidung. Das zweite Tor hat **andere Verben**, und es liegt auf einer **eigenen Karte**. Warum es das muss, ist gemessen — siehe Schritt 11.11. |
| **Ein Riegel, den kein Modell überlesen kann** | `bin/kb_git.py merge` führt den Linter aus und **weist den Merge ab**, wenn er fehlschlägt. Kein Ratschlag in einer Skill — eine Vorbedingung im Code. |
| **Konkurrenzschutz auf zwei Ebenen** | Alle Ingests arbeiten im selben Arbeitsbaum. Eine Kanten-Ebene ordnet sie kooperativ, eine Code-Ebene weist sie notfalls ab. |

Und ein Ausgang, der wichtiger ist als alle Deliverables zusammen:

> **Der wertvollste Lauf dieser Pipeline ist der, in dem sie nichts tut, weil
> sie es schon weiß.** Im Original ist genau das der Beweis, dass der Aufbau
> funktioniert: der Orchestrator legt ein Release zurück, das der Autor selbst
> schon von Hand eingepflegt hatte.

---

## Schritt 11.1 — Setup

```bash
cd "Story 11 - LLM Wiki"
chmod +x *.sh scripts/*.sh
./setup.sh
```

Das legt Board `kanban-story-11`, die **fünf** Profile und `workspace/` aus
`seed/` an — und macht `workspace/wiki/` zu einem **Git-Repository**.

```console
4/5  Profile
  kb-scout — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'kb-scout-report' installiert
  kb-orchestrator — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'kb-pipeline' installiert
  kb-researcher — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
  kb-ingestor — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'kb-ingest' installiert
  kb-linter — angelegt
      SOUL.md + Beschreibung + config.yaml geschrieben
      Skill 'kb-lint' installiert

5/5  Arbeitskopie, Git-Repository und Verifikation
workspace/ zurueckgesetzt (25 Startdateien aus seed/)
workspace/wiki/ ist ein Git-Repository (Branch main, 1 Commit)
Ausgangsbefund des Linters: 5 ERROR, 1 STALE  (erwartet)
```

```console
NAME                  ON DISK   COUNTS
kb-ingestor           yes       (idle)
kb-linter             yes       (idle)
kb-orchestrator       yes       (idle)
kb-researcher         yes       (idle)
kb-scout              yes       (idle)
```

Alle fünf Namen tragen das Präfix `kb-` und kollidieren mit **keiner** anderen
Story. `setup.sh` legt zusätzlich eine Marke `.story11` in jedes Profil, und
`teardown.sh` entfernt **nur** Profile mit dieser Marke — ein gleichnamiges
Profil, das du selbst angelegt hast, bleibt unangetastet.

### Der Ausgangsbefund ist Teil des Setups

Die letzte Zeile ist kein Schmuck. `reset-workspace.sh` und `setup.sh` prüfen
beide, dass der Linter auf dem Seed **genau 5 ERROR und 1 STALE** findet.
Stimmt das nicht, ist `seed/` verstellt — und dann ist der einzige modellfreie
Test dieser Story wertlos.

### Skills liegen pro Profil

```
skills/kb-scout/kb-scout-report/SKILL.md      Berichtsformat
skills/kb-orchestrator/kb-pipeline/SKILL.md   der ganze Ablauf
skills/kb-ingestor/kb-ingest/SKILL.md         wie eine Seite entsteht
skills/kb-linter/kb-lint/SKILL.md             wie geprüft und repariert wird
```

Nachprüfen:

```bash
hermes -p kb-orchestrator skills list
hermes -p kb-researcher   skills list
```

```console
│ kb-pipeline │          │ local  │ local │ enabled │
0 hub-installed, 0 builtin, 1 local — 1 enabled, 0 disabled

0 hub-installed, 0 builtin, 0 local — 0 enabled, 0 disabled
```

Der Rechercheur bekommt den Pipeline-Ablauf **nicht** in den Kontext. Das ist
dieselbe Entscheidung wie in Story 10, und das Korpus dieser Story enthält
zufällig die Begründung dafür im Wortlaut — aus dem Transkript, das der Scout
gleich auswerten wird:

> „Profil-lokale Skills sind das schärfste Werkzeug im ganzen Kasten, wenn man
> eine Flotte baut. Der Orchestrator bekommt den Ablauf, der Rechercheur
> bekommt ihn **nicht**. […] Wenn jeder Agent alles weiß, hat man keine Flotte,
> sondern fünf Kopien desselben Agenten mit fünf verschiedenen Namen."

---

## Schritt 11.2 — Zwei autoritative Dateien, und keine davon ist ein Profil

Story 10 hat **eine** solche Datei (`triage.yaml`). Diese Story hat **zwei**,
und die Trennung ist der Grund, warum sie mit so wenig eigener Logik auskommt.

| Datei | Sagt | Gelesen von |
|---|---|---|
| `ingest.yaml` | **Wie die Pipeline läuft** — Rubrik, Schwelle, Bündelung, Dedup-Kriterium, Route-Tabelle, Pfade, die zwei Tore | Orchestrator, Scout |
| `wiki/AGENTS.md` | **Wie die Wissensbasis aussieht** — Frontmatter, Abschnittsreihenfolge, Links, Index, Größe, Aktualität, wer löschen darf | Ingestor, Linter, `bin/kb_lint.py` |

### `wiki/AGENTS.md` — der Vertrag

Das ist die Idee, die das Original transportiert:

> **Eine Markdown-Datei, drei Aufgaben.** Der Ingestor schreibt Seiten *nach*
> ihr. Der Linter validiert *gegen* sie. Und sie beschreibt den automatisierten
> Ablauf selbst.

Dadurch braucht diese Domäne kaum neue Logik: die Rolle, die schreibt, und die
Rolle, die prüft, lesen **dieselbe** Spezifikation. Was in Story 10 zwei
getrennte Prosa-Anweisungen wären, ist hier eine Datei plus ein Skript.

Die Abschnitte, die alles entscheiden:

```markdown
## 2.1 Pflichtschluessel im Frontmatter
   title · slug · updated · tags · sources · version
   (slug MUSS dem Dateinamen ohne .md entsprechen)

## 2.2 Abschnittsreihenfolge
   ## Kurzfassung → ## Details → ## Quellen → ## Siehe auch (optional)

## 2.3 Grenzen
   höchstens 120 Zeilen; wird eine Seite länger, wird sie GETEILT

## 3 Verlinkung
   nur [[slug]]; ein Link auf eine nicht existierende Seite ist ein FEHLER,
   keine Absichtserklärung

## 4 Der Index
   jede Seite genau einmal aus index.md verlinkt; jeder Link existiert

## 5 Aktualität
   updated höchstens 180 Tage alt; STALE heißt PRÜFEN, nicht löschen

## 6 Prune
   Prune entscheidet IMMER ein Mensch
```

Abschnitt 6 ist der Kern dieser Story:

> Der Grund ist asymmetrisch: eine überflüssige Seite kostet ein paar Zeilen
> Kontext. Eine gelöschte richtige Seite ist weg, und niemand merkt, dass die
> Antwort fehlt.

### `ingest.yaml` — die Pipeline

```yaml
rubrik:
  schwelle: 65
  dimensionen:
    - {key: neuheit,          max: 25, hinweis: "steht es noch nicht in der Wissensbasis — geprueft, nicht vermutet"}
    - {key: quellenvertrauen, max: 20, hinweis: "offizieller Changelog > gemessene Demo > Behauptung > Ankuendigung"}
    - {key: themenbezug,      max: 25, hinweis: "direkter Bezug zu Hermes Agent, nicht zum Umfeld"}
    - {key: versionsrelevanz, max: 15, hinweis: "betrifft es die aktuelle Version oder eine ueberholte"}
    - {key: klarheitsgewinn,  max: 15, hinweis: "wird eine Antwort dadurch praeziser oder nur laenger"}

dedup:
  gegen: wiki/pages           # NICHT gegen die anderen Kandidaten
  hinweis: |
    Lies die betroffenen Seiten unter wiki/pages/ WIRKLICH, bevor du
    "neu" sagst. … "Die Seite erwaehnt Blocks" ist keine Abdeckung fuer
    "der Grund ist positional".

route:
  tabelle:
    fehlt:          neue_seite
    unvollstaendig: update
    widerspruch:    konflikt
    abgedeckt:      shelve
```

Und ein Block, den der protokollierte Lauf erst erzwungen hat (Schritt 11.7):

```yaml
rubrik:
  schwelle: 65
  max_pro_lauf: 3     # die Schwelle sortiert nach Wichtigkeit — sie begrenzt
                      # die MENGE nicht. Ueberzaehlige Items werden
                      # 'zurueckgestellt', nicht 'geshelved'.
```

**Der Dedup-Block ist der wichtigste Unterschied zu Story 10.** Dort wird gegen
andere *Kandidaten* dedupliziert („haben wir das schon gemeldet?"). Hier wird
gegen die *Wissensbasis selbst* dedupliziert („wissen wir das schon?"). Das ist
eine teurere Frage — sie verlangt, Seiten zu lesen — und sie ist der eigentliche
Wert einer Pflege-Pipeline.

Willst du die Pipeline auf dein Thema umstellen, änderst du **diese zwei
Dateien** und die Vorlagen unter `proposals/` — nicht die Profile, nicht die
Skills und nicht den Linter.

### Das Korpus

Im Original beobachtet der Scout live GitHub-Releases und den eigenen
YouTube-Kanal. Hier liest er ein **eingefrorenes** Korpus.

```
workspace/sources/releases/      3 Changelogs (0.20.0 „Velocity", 0.20.1, 0.20.2)
workspace/sources/transcripts/   3 Transkripte (Skills, Block-Semantik, Community-Update)
```

⚠ **`sources/` liegt außerhalb des Git-Repositorys.** Das ist Absicht und es ist
das ganze Sicherheitsmodell dieser Story:

| | |
|---|---|
| Die Wissensbasis ist versioniert | ein falscher Ingest ist mit `git` zurücknehmbar |
| Die Rohquellen sind es nicht — sie werden **nie angefasst** | es gibt immer einen Punkt, auf den man zurückgehen kann |
| Jeder Ingest lebt auf einem eigenen Branch | in `main` landet nur, was zwei Tore und den Linter passiert hat |

Und die Wissensbasis selbst:

```
workspace/wiki/AGENTS.md        der Vertrag
workspace/wiki/index.md         das Inhaltsverzeichnis
workspace/wiki/pages/           7 Seiten
workspace/wiki/log/             das Ingest-Log
```

---

## Schritt 11.3 — Der Teil, der nicht rät

Story 10 endet mit einer offenen Rechnung. Sie zitiert die These des Originals —

> **Fat engine, thin skill.** Multi-Agent-Pipelines scheitern, wenn zu viel
> Logik in Prosa lebt, die ein Modell bei jedem Lauf neu interpretiert.

— und gibt zu, sie nicht eingelöst zu haben: Rubrik, Route und Kettenbau liegen
dort in einer Skill, der Score ist eine Modellentscheidung, und
„`python -m unittest discover` gibt es hier nicht".

**Diese Story zahlt einen Teil davon.** Nicht den Score — der bleibt ein
Urteil. Aber die Form der Wissensbasis ist kein Urteil mehr, sondern Code:

```bash
python3 workspace/bin/kb_lint.py workspace/wiki
```

```console
kb_lint — .../workspace/wiki  (7 Seiten, Bezugsdatum 2026-08-11)
==============================================================================

  ERROR           pages/cron-und-zeitplan.md:11      [abschnitt-reihenfolge] Reihenfolge ist
                  ['Kurzfassung', 'Quellen', 'Details', 'Siehe auch'], erwartet
                  ['Kurzfassung', 'Details', 'Quellen', 'Siehe auch'] (AGENTS.md 2.2)
  ERROR           pages/kanban-board.md:61           [toter-link] [[kanban-review-agent]] zeigt auf
                  keine Seite unter pages/ — Stub-Links sind Fehler, keine
                  Absichtserklaerung (AGENTS.md 3)
  ERROR           pages/memory-system.md:1           [frontmatter-key] Pflichtschluessel 'updated'
                  fehlt (AGENTS.md 2.1)
  ERROR           index.md:21                        [index-toter-link] [[skills-system]] zeigt auf
                  keine Seite unter pages/ (AGENTS.md 4)
  ERROR           index.md                           [waise] Seite 'gateway-und-dispatcher'
                  existiert, ist aber nicht aus index.md verlinkt — fuer einen Agenten, der
                  ueber den Index einsteigt, gibt es sie nicht (AGENTS.md 4)

  STALE           pages/profile-system.md:1          [freshness] updated 2026-01-20 ist 203 Tage
                  alt (Grenze 180) — pruefen, nicht loeschen (AGENTS.md 5)

------------------------------------------------------------------------------
ERROR: 5  STALE: 1  PRUNE-VORSCHLAG: 0

FEHLGESCHLAGEN — 5 Befund(e), die einen Merge sperren.
```

**Jede Meldung nennt den Abschnitt aus `AGENTS.md`, aus dem sie stammt.** Das
ist die ganze Konstruktion: der Linter ist keine zweite Meinung neben dem
Vertrag, er ist dessen maschinelle Fassung.

### Warum das der belastbarste Test dieser Story ist

Die sechs Befunde sind **absichtlich** in `seed/wiki/` eingebaut, und `seed/`
wird nie beschrieben. Damit ist der Test wiederholbar und modellfrei:

| Befund | Datei | Was fehlt |
|---|---|---|
| `abschnitt-reihenfolge` | `cron-und-zeitplan.md` | `## Quellen` steht vor `## Details` |
| `toter-link` | `kanban-board.md:61` | `[[kanban-review-agent]]` existiert nicht |
| `frontmatter-key` | `memory-system.md` | `updated:` fehlt |
| `index-toter-link` | `index.md:21` | `[[skills-system]]` existiert nicht |
| `waise` | `index.md` | `gateway-und-dispatcher` ist nicht verlinkt |
| `freshness` (STALE) | `profile-system.md` | `updated: 2026-01-20`, 203 Tage alt |

Real gemessen, die Gegenprobe: dieselbe Wissensbasis in einer Kopie, alle sechs
Punkte behoben —

```console
kb_lint — .../lintfix/wiki  (7 Seiten, Bezugsdatum 2026-08-11)
==============================================================================

  keine Befunde

------------------------------------------------------------------------------
ERROR: 0  STALE: 0  PRUNE-VORSCHLAG: 0

BESTANDEN — keine ERROR-Befunde. Ein Merge ist erlaubt.
EXIT=0
```

**Keine False Positives, keine False Negatives, bei jedem Lauf identisch.** Das
ist der Unterschied zu einem Modell, das seine eigene Arbeit gegen eine
Prosa-Regel prüft — dasselbe wollte das Original mit `knowledge_base_lint`, und
aus demselben Grund ist es dort ebenfalls Python.

### Drei Schweregrade sind drei verschiedene Pflichten

| Severity | Sperrt den Merge? | Pflicht |
|---|---|---|
| `ERROR` | **ja** | reparieren — ohne etwas zu entscheiden |
| `STALE` | nein | **prüfen**, nicht löschen. `--strict` macht daraus einen Fehler. |
| `PRUNE-VORSCHLAG` | nein | sammeln, nie ausführen. Entscheidet Tor 2. |

Dass `STALE` den Merge **nicht** sperrt, ist keine Nachlässigkeit. Ein
Freshness-Befund heißt „jemand muss nachsehen", und das ist eine inhaltliche
Arbeit. Würde er den Merge sperren, wäre die einzige Möglichkeit
weiterzukommen, `updated` auf heute zu stellen — und damit wäre die Prüfung
für 180 Tage stillgelegt. Der Linter würde sich sein eigenes Blindwerden
erzwingen.

```bash
python3 workspace/bin/kb_lint.py workspace/wiki --strict   # Exit 1: STALE zählt mit
python3 workspace/bin/kb_lint.py workspace/wiki --json     # für den Worker
python3 workspace/bin/kb_lint.py workspace/wiki --today 2026-08-11   # reproduzierbar
```

⚠ **`--today` ist nicht nur ein Testschalter.** Ohne festes Bezugsdatum rechnet
die Freshness-Prüfung gegen die Systemuhr — und der Seed ist auf den Stand
**2026-08-11** geschrieben. Zwei Folgen davon:

- **Die „203 Tage" oben wachsen bei dir.** Je später du das liest, desto älter
  ist `updated: 2026-01-20`. Der Befund bleibt derselbe, die Zahl nicht.
- **Läufst du das hier deutlich später, findet der Linter mehr STALE-Befunde**,
  weil weitere Seed-Seiten die 180-Tage-Grenze überschreiten. Deshalb prüfen
  `setup.sh` und `reset-workspace.sh` den Ausgangsbefund mit
  `--today 2026-08-11` — sonst würde die Kontrolle irgendwann „seed/ wurde
  verändert?" melden, obwohl niemand etwas verändert hat. Die **ERROR**-Zahl ist
  davon unabhängig und bleibt der eigentliche Test.

---

## Schritt 11.4 — Sechs Verben statt freiem Git

Der zweite neue Baustein. Warum überhaupt ein Helfer, wenn der Agent doch `git`
aufrufen könnte:

> Weil er es dann auch tut — mit `git add -A`, `git commit --amend`,
> `git checkout .` und gelegentlich `git reset --hard` auf einem echten
> Repository.

```bash
python3 workspace/bin/kb_git.py status
python3 workspace/bin/kb_git.py branch  kb/ingest-<slug>
python3 workspace/bin/kb_git.py commit  -m "…"
python3 workspace/bin/kb_git.py changed kb/ingest-<slug>
python3 workspace/bin/kb_git.py merge   kb/ingest-<slug>
python3 workspace/bin/kb_git.py discard kb/ingest-<slug>
```

Jedes Verb prüft vorher, ob es erlaubt ist. Real gemessen, alle Riegel:

```console
$ kb_git.py branch feature/xyz
ABGEWIESEN — Branchname muss mit 'kb/ingest-' beginnen (war: 'feature/xyz').
Jeder Ingest bekommt einen eigenen Branch, und er ist an seinem Namen erkennbar.

$ kb_git.py commit -m "leer"
ABGEWIESEN — es gibt nichts zu committen. Der Ingest hat keine Datei
veraendert — das ist fast immer ein Fehler und keine erfolgreiche Leerarbeit.
```

### Der Riegel, der die Story trägt

`merge` führt den Linter auf dem **Branch** aus und weist ab, wenn er
fehlschlägt:

```console
$ kb_git.py merge kb/ingest-test
ABGEWIESEN — kb_lint.py hat den Branch 'kb/ingest-test' nicht bestanden
(Exit 1). In main landet nur eine Wissensbasis, die den Vertrag aus AGENTS.md
erfuellt. Befunde beheben, erneut committen, erneut mergen.
```

Und nach der Reparatur, mit dem noch offenen STALE-Befund:

```console
ERROR: 0  STALE: 1  PRUNE-VORSCHLAG: 0

BESTANDEN — keine ERROR-Befunde. Ein Merge ist erlaubt.
Es liegen Prune-Kandidaten vor. Darueber entscheidet ein Mensch (AGENTS.md 6).

'kb/ingest-test' nach main verschmolzen, Branch entfernt.
```

> **Das ist der Unterschied zwischen einer Regel und einem Riegel.** Eine Regel
> in einer `SOUL.md` gilt, solange das Modell sie liest. Diese Vorbedingung gilt
> immer.

### Konkurrenzschutz, zwei Ebenen

Alle Ingests arbeiten im **selben** Arbeitsbaum — es gibt nur ein
`workspace/wiki/`. Zwei gleichzeitig würden sich überschreiben.

*Warum nicht einfach `--workspace worktree:`?* Weil ein Git-Worktree pro **Karte**
angelegt wird, nicht pro Ingest: die drei Karten einer Kette (Ingest, Lint,
Commit) bekämen drei getrennte Verzeichnisse und sähen die Arbeit der jeweils
anderen nicht. Und zwei Worktrees auf **demselben** Branch verweigert Git
ohnehin. Für eine Kette, die sich einen Branch teilt, ist `dir:` die richtige
Wahl — und die Serialisierung, die daraus folgt, ist genau der
Konkurrenzschutz, den das Original ebenfalls braucht.

**Ebene 1, kooperativ:** Der Orchestrator sucht mit `kanban_list` nach einer
noch offenen `Commit + Tor 2:`-Karte und hängt seine Ingest-Karte als Kind
daran. Sie wartet dann in `todo`.

**Ebene 2, deterministisch:** `branch` weist ab, solange ein anderer
Ingest-Branch nicht in `main` ist. Real gemessen:

```console
$ kb_git.py branch kb/ingest-bbb        # während kb/ingest-aaa offen ist
ABGEWIESEN — es ist noch ein Ingest offen: kb/ingest-aaa. Zwei Ingests im
selben Arbeitsbaum wuerden sich gegenseitig ueberschreiben. Erst den offenen
abschliessen (merge) oder wegwerfen (discard).

$ kb_git.py status
Branch:          kb/ingest-aaa
Arbeitsbaum:     sauber
Offene Ingests:  kb/ingest-aaa
Branches:        kb/ingest-aaa, main

$ kb_git.py discard kb/ingest-aaa
'kb/ingest-aaa' verworfen. main unveraendert:
9818a51 ingest: skills-system

$ kb_git.py branch kb/ingest-bbb
Branch 'kb/ingest-bbb' von main angelegt und ausgecheckt.
```

Ebene 1 ordnet, Ebene 2 hält. Wer nur Ebene 1 baut, hat einen Schutz, der von
der Aufmerksamkeit eines Modells abhängt.

---

## Schritt 11.5 — Drei Karten anlegen

```bash
./create-tasks.sh
source task-ids.env      # BOARD, TENANT, WS, WIKI, SCOUT_REL, SCOUT_TRA, TRIAGE
./pump.sh
```

Angelegt wird nur der Eingang:

```console
▶ t_b2b09568  ready     kb-scout          [wiki]  Scout releases: sources/releases auswerten
▶ t_87145aab  ready     kb-scout          [wiki]  Scout transcripts: sources/transcripts auswerten
◻ t_fe0e99ff  todo      kb-orchestrator   [wiki]  Triage: buendeln, dedup gegen die Wissensbasis, bewerten
```

Alles danach — Recherche-Bahnen, Route, Tor 1, Ingest, Lint, Tor 2, Merge —
legt die Flotte selbst an.

---

## Schritt 11.6 — Die Scouts: erkennen, nicht urteilen

Ein Scout **erkennt nur**. Real gemessen, `intake/transcripts.md`:

```markdown
# Scout-Bericht: transcripts

Ausgewertet: 3 Dateien unter sources/transcripts
Kandidaten: 12

Quellen:
- `2026-08-07-skills-system.md` — „Skills in Hermes Agent, von unten aufgebaut", Bezug 0.20.0
- `2026-08-08-block-semantik.md` — „Menschliche Tore auf dem Kanban-Board", Bezug 0.20.0 / 0.20.1
- `2026-08-10-community.md` — Community-Update Nr. 47, Bezug allgemein
  (0 Kandidaten: nur Kanal-Neuigkeiten, Ankuendigung, Terminal-Vorliebe, Namensfindung)
```

Und ein Kandidat im Detail:

```markdown
## Nur die description einer SKILL.md landet ungefragt im Kontext; der Rumpf
   wird erst bei Relevanzentscheidung geladen

- **aussage:** Von einer Skill landet nur die `description` automatisch im
  Kontext; der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell die
  Skill fuer relevant haelt …
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:09:30] — „nur die `description` landet
    ungefragt im Kontext. […] sie ist der einzige Teil, den das Modell
    garantiert sieht."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skills und Kontextbelastung
- **neuheit_vermutet:** vermutlich neu — die genaue Mechanik ist ein praeziser,
  ueberpruefbarer Punkt, der in einer Wissensbasis leicht fehlt.
```

Drei Dinge daran sind Absicht:

**Die Zeitmarke ist Pflicht.** Ein Zitat ohne Fundstelle ist für die
Verifikations-Bahn wertlos — sie müsste die ganze Datei erneut lesen.

**`neuheit_vermutet` heißt *vermutet*.** Der Scout hat die Wissensbasis nicht
gelesen. Würde er hier entscheiden, wäre die Dedup-Stufe eine Attrappe.

**Das Community-Update lieferte null Kandidaten** — Abonnentenzahlen,
Ankündigungen und die Frage nach einem Namen für die Wissensbasis sind keine
überprüfbaren Aussagen über das Produkt.

> ⚠ **Das war so nicht geplant, und es ist trotzdem richtig.** Dieses Transkript
> lag im Korpus als Fall „schafft es über die Rubrik nicht über die Schwelle".
> Der Scout hat es eine Stufe früher aussortiert. Ist das der blinde Fleck, vor
> dem Story 10 warnt („zwei Filter hintereinander, die dasselbe Kriterium
> anlegen")? **Nein** — und die Unterscheidung ist genau der Punkt: dort legen
> beide Stufen dasselbe Kriterium an (*ist es wichtig?*), hier legen sie
> verschiedene an (*ist es eine überprüfbare Aussage?* / *ist sie neu und
> wichtig?*). Der Ausgang „unter der Schwelle" entstand in diesem Lauf
> stattdessen reichlich an der richtigen Stelle — siehe Schritt 11.7.

---

## Schritt 11.7 — Die Triage: Bündeln, Dedup, Rubrik

Real gemessen, in **25 Minuten** — die teuerste einzelne Karte der Story, weil
sie 31 Kandidaten gegen sieben Wiki-Seiten prüfen muss:

```console
$ hermes kanban --board $BOARD show $TRIAGE --json | jq -r .latest_summary

15 Kandidaten-Quellen (12 aus intake/transcripts.md, 19 aus intake/releases.md)
zu 6 Items gebuendelt (3 Reco-Sets ueberschnitten sich vollstaendig mit
Transkript-Zwillingen), 9 weitere als geshelved abgelegt. 6 Items ab Schwelle 65
(98..70) im Fan-out: 12 Bahn-Karten (verifikation + seiten-abgleich je Item) +
6 Route-Karten (Fan-in auf beide Bahnen). Nichts an wiki/ angetastet.
```

Der letzte Halbsatz ist der wichtigste: **in dieser Stufe wird kein Zeichen in
die Wissensbasis geschrieben.** Bewerten und schreiben sind getrennte Rollen.

### Der Ausgang, den du nie siehst

```console
$ for f in workspace/vault/*.md; do … done

block-schleifen-triage.md              score=20   status=geshelved
cron-no-agent.md                       score=20   status=geshelved
dispatcher-daemon-deprecated.md        score=20   status=geshelved
kanban-goal-judge.md                   score=20   status=geshelved
kanban-review-spalte.md                score=20   status=geshelved
kanban-swarm.md                        score=20   status=geshelved
migration-keine-schritte.md            score=20   status=geshelved
profile-install-distribution.md        score=20   status=geshelved
unblock-reason-semantik.md             score=20   status=geshelved

cron-no-agent-leerer-lauf.md           score=78   status=triage
dispatcher-reclaim-und-tick.md         score=85   status=triage
kanban-block-semantik-korrektur.md     score=91   status=triage
kanban-boardschutz.md                  score=76   status=triage
profile-install-description.md         score=70   status=triage
skills-system.md                       score=98   status=triage
```

**Neun von fünfzehn Items wurden geshelved, alle mit Score 20** — und jedes mit
einer Fundstelle in der bestehenden Seite. Das ist der Beweis des Originals, in
dieser Story vervielfacht: die Pipeline hat erkannt, dass sie die
`review`-Spalte, `swarm`, `--goal`, `--no-agent`, die Deprecation von
`kanban daemon` und die `unblock --reason`-Semantik **schon weiß**.

Besonders schön ist `unblock-reason-semantik` (20, geshelved) neben
`kanban-block-semantik-korrektur` (91, weiter): dieselbe Seite, zwei Aussagen
aus derselben Quelle — die eine steht schon da, die andere widerspricht ihr.
Eine Pipeline, die pro *Quelle* statt pro *Aussage* entscheidet, kann das nicht
trennen.

> **Der wertvollste Lauf dieser Pipeline ist der, in dem sie nichts tut.** Neun
> Items, für die keine einzige Karte angelegt wurde: kein Rechercheur, kein
> Vorschlag, kein Tor. Sie liegen als Dateien im Vault, mit nachvollziehbarer
> Begründung, und warten dort.

### Ein Item, gebündelt aus drei Quellen

```markdown
---
slug: kanban-block-semantik-korrektur
titel: Kanban-Block-Korrektur: Grund positional statt --reason,
       --kind-Reihenfolge, Haltekraft, initial-status, Schleifendetail
status: triage
score: 91
score_breakdown: {'neuheit': 18, 'quellenvertrauen': 20, 'themenbezug': 25,
                  'versionsrelevanz': 15, 'klarheitsgewinn': 13}
gebuendelt_aus: ['changelog-0.20.1.md', 'changelog-0.20.2.md',
                 '2026-08-08-block-semantik.md']
betrifft: ['kanban-block-semantik']
---

## Bewertung (Schwelle 65)
neuheit 18/25: Seite existiert, aber CLI-Doku (block --reason) ist falsch und
  mehrere Mechaniken fehlen.
quellenvertrauen 20/20: offizieller Changelog UND gemessene Demo, zwei sich
  deckende Quellen.
themenbezug 25/25: direkt das Tor-/Block-Konzept, auf dem diese Pipeline beruht.
versionsrelevanz 15/15: klare Korrektur der aktuellen Version.
klarheitsgewinn 13/15: korrigiert dokumentierte-aber-falsche Syntax; Kern
  (unblock, Schleife->Triage) steht schon.
```

`quellenvertrauen 20/20` mit der Begründung „Changelog **und** gemessene Demo"
ist die Rubrik-Dimension, die in Story 10 fehlt — und in einer Wissensbasis die
wichtigste.

### Was dieser Lauf über die **Menge** gezeigt hat

Sechs Items über der Schwelle. Sechs Items heißen **zwölf** Torfragen an einen
Menschen, aus einem einzigen Sweep.

Das ist kein Fehler der Pipeline — sie hat richtig gerechnet. Es ist eine Lücke
in `ingest.yaml`: **die Schwelle sortiert nach Wichtigkeit, aber sie begrenzt die
Menge nicht.** Deshalb hat `ingest.yaml` seit diesem Lauf einen Deckel:

```yaml
rubrik:
  schwelle: 65
  max_pro_lauf: 3      # die besten drei in den Fan-out;
                       # der Rest wird 'zurueckgestellt' (NICHT 'geshelved')
```

`zurueckgestellt` ist ausdrücklich **kein** Urteil über das Item — die Datei
bleibt vollständig erhalten, und der nächste Sweep nimmt sie auf. Verwechselt man
das mit `geshelved`, verschwindet ein Item, das die Schwelle bestanden hat, mit
einer Begründung, die nicht zutrifft.

> Ein Tor, an dem zwölf Karten warten, wird nicht sorgfältiger beantwortet als
> eines mit drei — es wird unsorgfältiger. **Die knappe Ressource dieser
> Pipeline ist die Aufmerksamkeit am Tor, nicht das Token-Budget.**

⚠ **Der unten protokollierte Lauf entstand *vor* dieser Nachschärfung** — er
zeigt das Problem, nicht die Lösung. Wie ich die sechs Tore tatsächlich
beantwortet habe, steht in Schritt 11.9.

---

## Schritt 11.8 — Fan-out: zwölf Bahnen gleichzeitig

```console
● t_15fd404a  running   kb-researcher  [wiki]  Bahn verifikation: skills-system
● t_6373c513  running   kb-researcher  [wiki]  Bahn seiten-abgleich: skills-system
● t_06b542e0  running   kb-researcher  [wiki]  Bahn verifikation: kanban-block-semantik-korrektur
● t_ff001a56  running   kb-researcher  [wiki]  Bahn seiten-abgleich: kanban-block-semantik-korrektur
● t_9e537a27  running   kb-researcher  [wiki]  Bahn verifikation: dispatcher-reclaim-und-tick
● t_36a0fee4  running   kb-researcher  [wiki]  Bahn seiten-abgleich: dispatcher-reclaim-und-tick
… (12 insgesamt)
◻ t_27dfe66c  todo      kb-orchestrator [wiki] Route: skills-system
◻ t_72d5196f  todo      kb-orchestrator [wiki] Route: kanban-block-semantik-korrektur
… (6 Route-Karten, je 2 Eltern)
```

**Zwölf OS-Prozesse gleichzeitig, alle auf demselben Profil.** Diese 18 Karten
hat kein Mensch angelegt — der Orchestrator hat sie mit `kanban_create`
geschrieben.

### Die Klassifikator-Bahn liefert einen Wert, sonst nichts

```console
$ awk '/^wissensstand:/' workspace/vault/*-seitenabgleich.md

skills-system                     wissensstand=fehlt
kanban-block-semantik-korrektur   wissensstand=widerspruch
dispatcher-reclaim-und-tick       wissensstand=unvollstaendig
cron-no-agent-leerer-lauf         wissensstand=unvollstaendig
kanban-boardschutz                wissensstand=unvollstaendig
profile-install-description       wissensstand=unvollstaendig
```

Die Route-Karte schlägt den Wert in `route.tabelle` nach — **mehr nicht**. Steht
er nicht in der Tabelle, blockiert die Karte, statt zu raten.

> Der Klassifikator darf urteilen. Was aus dem Urteil folgt, ist eine Tabelle.

`unvollstaendig` viermal ist kein Ausweichen: die Seiten existieren und die
Aussagen fehlen dort. Der Wert, der die Story trägt, ist `widerspruch` — und
`fehlt` bei `skills-system`, wo `index.md` die Seite schon verlinkt, sie aber
nie existierte (genau der Linter-Befund `index-toter-link` aus Schritt 11.3).

### Was die Verifikations-Bahn tatsächlich getan hat

Ihre `SOUL.md` verlangt, drei Dinge zu trennen: was die Quelle **sagt**, was
**verifiziert** wurde, und was **gefolgert** ist. Real gemessen, aus dem
Gate-Text zu `skills-system`:

```
… verifiziert an lokaler Installation v0.20.0, eine Speicherort-Aussage wird
praezisiert statt wortgleich uebernommen.
```

**Der Rechercheur hat das Transkript gegen die Installation geprüft und eine
Aussage des Sprechers korrigiert, statt sie zu übernehmen.** Das ist der
Unterschied zwischen einer Wissensbasis und einem Zitatarchiv.

---

## Schritt 11.9 — Tor 1, sechsmal

`./pump.sh` endet von selbst und sagt, worauf:

```console
[01] blocked=5  done=19  ready=1  running=1

5 Karte(n) warten auf einen Menschen:
  t_b167e4f7  [TOR 1: approve | shelve | modify]  Vorschlag + Tor 1: dispatcher-reclaim-und-tick
  t_ae196a5f  [TOR 1: approve | shelve | modify]  Vorschlag + Tor 1: kanban-boardschutz
  t_d5e97fab  [TOR 1: approve | shelve | modify]  Vorschlag + Tor 1: cron-no-agent-leerer-lauf
  t_cb2dda29  [TOR 1: approve | shelve | modify]  Vorschlag + Tor 1: profile-install-description
  t_4a5f7ce6  [TOR 1: approve | shelve | modify]  Vorschlag + Tor 1: skills-system
```

Ein Torgrund, real gemessen — und das ist der Maßstab, an dem ein Tor zu messen
ist:

```console
TOR 1 skills-system (neue_seite, 98/100): Neue Seite pages/skills-system.md
fuellen — Skill-Aufbau (SKILL.md + YAML-Frontmatter name/description), die
drei Speicherorte mit Reichweite (praezisiert: default-Home vs. profil-eigenes
Home vs. builtin), description-im-Kontext-Mechanik (Rumpf bedarfsgeladen),
`skills list`-Herkunft/Status, `--skill`-Erzwingung, Skill-vs-MCP. Heilt den
Stub-Link index.md:21; verifiziert an lokaler Installation v0.20.0, eine
Speicherort-Aussage wird praezisiert statt wortgleich uebernommen.
Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'
```

**Acht Zeilen, und man kann entscheiden, ohne eine Datei zu öffnen.** Score,
Route, was entsteht, was es heilt, und was gegenüber der Quelle geändert wurde.

Und der Konfliktfall, mit `⚠ KONFLIKT` im Grund:

```console
TOR 1 ⚠ KONFLIKT kanban-block-semantik-korrektur (konflikt, 91/100):
Wissensbasis dokumentiert `hermes kanban block <id> --reason "…"`
(pages/kanban-block-semantik.md Z.24), die Quelle belegt dass `--reason` fuer
block nicht existiert und der Grund positional ist (`block <id> "…"`, `--kind`
vor der Kartennummer) — Changelog 0.20.1, Transkript 2026-08-08 und ein
lokaler CLI-Test gegen v0.20.0 bestaetigen die Quelle.
Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'
```

Beide Aussagen, beide Fundstellen, und wer sie stützt. **Kein Vorschlag, wer
gewinnen soll.** Das entscheidet der Mensch.

### Die drei Verben, alle benutzt

```bash
# approve — die Quelle gewinnt, ich habe es selbst am CLI gemessen
./gate.sh approve t_4a5f7ce6      # skills-system, 98
./gate.sh approve t_bf8c3e72      # der Konflikt, 91

# modify — eine Teilaussage fliegt raus
./gate.sh modify t_b167e4f7 \
  "Nur den idempotenten Claim-Reclaim und den Tick-Abbruch nach 'hermes pause'
   aufnehmen. Die Aussage 'dispatch_stale_timeout_seconds ist jetzt pro Profil
   ueberschreibbar' weglassen: sie steht nur im Changelog, und die
   Verifikations-Bahn hat sie nicht an der Installation nachgewiesen. Eine
   unbelegte Konfigurationsaussage in einer Wissensbasis ist schlimmer als
   eine Luecke."

# shelve — dreimal, und zwar wegen der Menge, nicht wegen des Inhalts
./gate.sh shelve t_ae196a5f "zurueckgestellt, nicht verworfen: sechs Items ueber
  der Schwelle sind zwoelf Torfragen aus einem Sweep. …"
```

**`modify` ist das Verb, das diese Pipeline von einem Abnickvorgang
unterscheidet.** Der Changelog behauptet etwas, die Verifikations-Bahn konnte es
nicht nachweisen, der Vorschlag hat es trotzdem aufgenommen — und ein Mensch
sieht das in zehn Sekunden. Was daraus geworden ist, steht später im Ingest-Log:

```markdown
Die Changelog-Aussage zur pro-Profile-Ueberschreibbarkeit von
`dispatch_stale_timeout_seconds` wurde bewusst **nicht** aufgenommen
(nur im Changelog, nicht an der Installation verifiziert).
```

> **Eine unbelegte Aussage in einer Wissensbasis ist schlimmer als eine Lücke.**
> Die Lücke merkt man beim Lesen. Die falsche Aussage nicht.

---

## Schritt 11.10 — Ingest, Lint, Tor 2 — einer nach dem anderen

### Der Konkurrenzschutz, real ausgelöst

Nach `approve` legt Tor 1 die Dreierkette an. Für das **zweite** Item sieht das
so aus:

```console
$ hermes kanban --board $BOARD show <ingest-2-id> --json | jq '{status:.task.status, parents:.parents}'
{
  "status": "todo",
  "parents": [
    "t_aa5e5a84"          ← "Commit + Tor 2: skills-system"
  ]
}
```

**Die Ingest-Karte des zweiten Items hat die Commit-Karte des ersten als
Elternteil.** Der Orchestrator hat sie mit `kanban_list` gefunden — das ist die
kooperative Ebene aus Schritt 11.4, hier gemessen. Der zweite Ingest wartet in
`todo`, bis der erste in `main` ist.

Und die deterministische Ebene daneben:

```console
$ ./reset-workspace.sh --git
Branch:          kb/ingest-skills-system
Arbeitsbaum:     sauber
Offene Ingests:  (keine)
Branches:        kb/ingest-skills-system, main
```

⚠ **Genau in diesem Zustand greift die deterministische Ebene noch nicht.** Ein
Branch **ohne eigene Commits** ist aus Git-Sicht in `main` enthalten und zählt
für `kb_git.py branch` nicht als „offener Ingest". Die zwei Ebenen sind deshalb
komplementär, nicht redundant:

| Ebene | Fängt | Fängt nicht |
|---|---|---|
| Kanten (`parents`) | jeden Fall, solange der Orchestrator `kanban_list` benutzt | ein Modell, das die Prüfung überliest |
| `kb_git.py branch` | einen **committeten** offenen Ingest, und jeden schmutzigen Arbeitsbaum | einen leeren, sauberen Branch |

Wer nur eine der beiden baut, hat eine Lücke. Dass der Ingestor seine Arbeit
inzwischen **selbst committet** (siehe unten), schließt die verbleibende.

### Der Linter an der Arbeit

Real gemessen, `vault/skills-system-lint.md`:

```markdown
| | vorher | nachher |
|---|---|---|
| ERROR | 4 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

## Repariert

| `pages/cron-und-zeitplan.md` | abschnitt-reihenfolge | `## Quellen` hinter
  `## Details` verschoben … Inhalt unveraendert. |
| `pages/kanban-board.md` | toter-link | `[[kanban-review-agent]]` entfernt.
  **Weg: Link entfernen.** Die Seite ist nicht geplant; der Satz ist ohne den
  Link vollstaendig … Kein Stub angelegt. |
| `pages/memory-system.md` | frontmatter-key | `updated: 2026-08-11` ergaenzt … |
| `index.md` | waise | `[[gateway-und-dispatcher]]` im Abschnitt `Kern`
  ergaenzt … |

Alle vier ERROR-Befunde waren bereits vor diesem Ingest vorhanden; der Ingest
selbst hat keine neuen Fehler eingefuehrt.
```

Vier von fünf Startdefekten sind damit weg — der fünfte
(`index-toter-link [[skills-system]]`) war schon geheilt, weil die neue Seite
existiert. **Der Ingest hat einen Linter-Befund geschlossen, ohne dass ihn
jemand darauf angesetzt hätte:** der Index verlangte eine Seite, das Korpus
lieferte den Inhalt, die Rubrik gab ihm 98 Punkte.

Und der STALE-Befund, der wichtigste Teil:

```markdown
| `pages/profile-system.md` | `updated 2026-01-20`, 203 Tage alt | STALE
  `freshness`. Diese Fakten wurden in diesem Ingest nicht neu geprueft. | Ein
  Mensch muss bei Tor 2 entscheiden … **Ich setze KEIN `updated`** — das waere
  eine Frontmatter-Luege, weil ich den Inhalt nicht gegen die aktuelle Version
  verifizieren konnte. |
```

Nachgeprüft, dass er sich daran gehalten hat:

```console
$ git -C workspace/wiki diff -- pages/profile-system.md | grep -E "^[+-](updated|status)"
  (keine Aenderung an updated/status)
```

> **Ein `updated`, das auf heute gestellt wird, ohne den Inhalt anzusehen, legt
> die Prüfung für 180 Tage still.** Der Linter würde sich sein eigenes
> Blindwerden erzwingen. Deshalb sperrt `STALE` den Merge nicht — und deshalb
> darf ihn niemand „reparieren".

### Tor 2: die Entscheidung über das Löschen

```console
TOR 2 skills-system: Branch kb/ingest-skills-system — 1 Seite neu
(pages/skills-system.md), 4 Seiten geaendert (cron-und-zeitplan, kanban-board,
memory-system, profile-system) + index.md. Lint 4→0 ERROR (alle 4
vorbestehend, repariert). PRUNE: nichts — der Branch loescht keine Seite
(profile-system.md bleibt STALE und ist als Nachpruefkandidat markiert, wird
aber NICHT entfernt).
Antwort: unblock --reason 'merge' | 'merge-ohne-prune' | 'discard: <grund>'
```

Und beim Konfliktfall steht dort etwas anderes:

```console
TOR 2 kanban-block-semantik-korrektur: Branch
kb/ingest-kanban-block-semantik-korrektur — 1 Seite geaendert, Lint 0→0 ERROR
(1 STALE vorbestehend). PRUNE: der widerlegte Z.-24-Absatz
`block <id> --reason "…"` wird entfernt (ersetzt durch positional; Grund ist
positional, --kind vor der Kartennummer).
```

**Das ist der Satz, für den dieses zweite Tor existiert.** Wer `merge` tippt,
ohne ihn gelesen zu haben, hat nicht entschieden — er hat quittiert.

### Was der Konflikt-Ingest gemacht hat

```diff
-updated: 2026-06-02
+updated: 2026-08-11
-sources: [hermes-docs/kanban.md]
-version: 0.19.0
+sources: [hermes-docs/kanban.md, changelog-0.20.1.md, changelog-0.20.2.md,
+          2026-08-08-block-semantik.md]
+version: 0.20.2

 ### Die drei Befehle
-hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"
+hermes kanban block   <id> "brauche eine Entscheidung von dir"
+hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"

-Bei `unblock` legt `--reason` den Text als Kommentar an die Karte …
+Der Grund von `block` ist **positional** — `--reason` existiert fuer `block`
+nicht und bricht mit `unrecognized arguments` ab. Eine Block-Art gibt man per
+`--kind` an, und das **vor** der Kartennummer. …
```

**Ersetzt, nicht ergänzt.** Die falsche Zeile ist weg. Frontmatter, Version und
Quellen sind nachgezogen, und die richtige Aussage über `unblock --reason` ist
stehen geblieben — sie war nie falsch.

> Diese Pipeline hat ihre Wissensbasis über genau den Befehl korrigiert, mit dem
> ihre eigenen Tore gebaut sind.

### Der Merge, und der Riegel davor

```console
$ ./gate.sh merge t_aa5e5a84
Antwort an t_aa5e5a84 (Tor 2):  "merge"
Unblocked t_aa5e5a84: merge
```

```console
$ git -C workspace/wiki log --oneline
68369a6 merge kb/ingest-kanban-block-semantik-korrektur
5f323e4 kanban-block-semantik: Grund positional statt --reason, --kind-vor-ID, …
7e9d2e6 merge kb/ingest-dispatcher-reclaim-und-tick
3f11e96 ingest: dispatcher-reclaim-und-tick
0107cc2 merge kb/ingest-skills-system
b1ca3be ingest: skills-system
6a67a2b seed: Wissensbasis im Ausgangszustand
```

Drei Ingests, drei Merge-Commits, `main` sauber, alle Branches nach dem Merge
entfernt. Jeder dieser Merges musste `kb_lint.py` bestehen — sonst hätte
`kb_git.py` abgewiesen.

### ⚠ Was an diesem Lauf nicht gut war

**1. `kb_git.py changed` war an beiden Toren blind.**

```console
$ python3 workspace/bin/kb_git.py changed kb/ingest-skills-system
'kb/ingest-skills-system' aendert gegenueber main nichts.
```

Die Arbeit lag vollständig im **Arbeitsbaum**, nicht in Commits — die Skill
`kb-ingest` sagte dem Ingestor ausdrücklich, er solle nicht committen. Das
Ergebnis war richtig (der Orchestrator hat den Torgrund aus `git status` und dem
Lint-Bericht gebaut), aber das Werkzeug, das dem Menschen den Diff zeigen soll,
lief leer.

Die Artefakte sind deshalb nachgeschärft: **Ingestor und Linter committen jetzt
selbst auf ihrem Branch.** Drei Gründe stehen in der Skill; der belastbarste ist,
dass ein Commit die Arbeit gegen einen sterbenden Worker sichert.

**2. Der Rechner ging mitten im Lauf 46 Minuten schlafen — und das wurde der
wertvollste unfreiwillige Test der ganzen Story.**

Um 16:20 wurde der Deckel zugeklappt (Netzwerkausfall). Der Rechner schlief bis
17:06. Real gemessen, `pmset -g log`:

```console
16:20:03  Sleep     Entering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active Using AC
16:23:39  Sleep     Entering Sleep state due to 'Maintenance Sleep' … 1058 secs
16:41:17  DarkWake  DarkWake from Deep Idle … rtc/SleepService
16:45:00  DarkWake  DarkWake from Deep Idle … rtc/Maintenance … 45 secs
16:45:45  Sleep     Entering Sleep state due to 'Maintenance Sleep' … 1018 secs
17:06:13  Wake      Wake from Deep Idle [CDNVA] : due to … lid …
```

Und die Karte, die zu dem Zeitpunkt lief:

```console
$ hermes kanban --board $BOARD runs <ingest-1>

#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  reclaimed     kb-ingestor            27m  2026-08-11 16:17
     ✖ stale_lock=MYMAC…:99349
  2  reclaimed     kb-ingestor            20m  2026-08-11 16:45
     ✖ stale_lock=MYMAC…:7211
  3  completed     kb-ingestor                 2026-08-11 17:06
```

**Die Zeitstempel deckungsgleich zu legen ist die ganze Analyse:**

| Uhrzeit | System | Board |
|---|---|---|
| 16:17 | wach | Run 1 startet |
| **16:20:03** | **Clamshell Sleep** | Worker friert ein, HTTP-Verbindung zum Modell reißt |
| 16:44 (16:17 + 27m) | schläft | Run 1 gilt als beendet |
| **16:45:00** | **DarkWake, 45 s** | Dispatcher-Tick: `stale_lock` erkannt → **Run 2 startet 16:45** |
| 16:45:45 | Sleep, 1018 s | Run 2 friert sofort wieder ein |
| 17:05 (16:45 + 20m) | schläft | Run 2 gilt als beendet |
| **17:06:13** | **Wake, Auslöser `lid`** | **Run 3 startet 17:06 — und läuft durch** |

Run 2 startete in einem **45-Sekunden-DarkWake-Fenster** und schlief sofort
wieder ein. Run 3 startete in derselben Minute, in der der Deckel aufging.

> **Damit ist die Wiederaufnahme des Boards unter einer echten Unterbrechung
> belegt** — nicht mit `kill -9` wie in Story 4b, sondern mit dem Fall, der im
> Betrieb wirklich vorkommt: der Rechner schläft, die Modell-Verbindung reißt,
> der Worker-Prozess stirbt. Der Dispatcher findet den verwaisten Claim über
> `stale_lock=<host>:<pid>`, legt die Karte zurück in die Queue und startet sie
> neu. **Es ging nichts verloren und es landete nichts Halbfertiges in `main`.**

### Warum der Schlaf nichts kaputt gemacht hat

Ein abgebrochener Ingest ist der gefährlichste Zustand dieser Pipeline: er
schreibt in einen **geteilten** Arbeitsbaum, und ein Worker, der mitten in einer
Seite stirbt, kann eine halbe Seite hinterlassen. Drei Dinge haben das
abgefangen, und alle drei sind Konstruktion, nicht Glück:

| | |
|---|---|
| **Der Neustart ist ein voller Neustart** | Run 3 hat die Stufe von vorn gemacht, auf demselben Branch. Der Ingestor liest `vault/<slug>-vorschlag.md` und schreibt die Seite neu — er setzt nicht an einer halben Datei fort. |
| **Der Linter läuft danach** | `bin/kb_lint.py` prüft die Wissensbasis, nachdem der Ingest fertig ist. Eine halb geschriebene Seite fällt als `frontmatter`- oder `abschnitt-fehlt`-Befund auf. Gemessen: 4 ERROR (alle vorbestehend) → 0. |
| **Der Merge-Riegel** | Was den Linter nicht besteht, kommt nicht nach `main`. Selbst wenn Ingest *und* Linter gestorben wären, wäre `main` unberührt geblieben. |

**Das ist der eigentliche Wert des deterministischen Linters**, und er war so
nicht geplant: er ist nicht nur eine Formatprüfung, er ist das **Sicherheitsnetz
unter jeder unterbrochenen Arbeit.** Eine Pipeline, die ihre Wissensbasis nur
gegen eine Prosa-Regel prüft, hätte nach diesem Schlaf keine Möglichkeit gehabt,
zu *belegen*, dass nichts kaputt ist.

### Was das für den Betrieb heißt

- **`--max-runtime` rechnet in Wanduhrzeit, nicht in Rechenzeit.** Run 1 stand
  mit „27m" da, obwohl er real drei Minuten gearbeitet hat — die übrigen 24
  Minuten hat die Karte geschlafen. Ein knapper Laufzeitdeckel wird durch einen
  Standby aufgebraucht, ohne dass Arbeit passiert ist.
- **Jeder Neustart kostet die ganze Stufe.** Beim `Ingest` sind das die Tokens
  für einen kompletten Seitenschreibvorgang, dreimal.
- **Nimm das Gateway, nicht ein Skript im Terminal.** `hermes gateway start`
  läuft unter launchd und ist nach einem Wake sofort wieder da; `pump.sh` in
  einem Terminal ist an dessen Lebensdauer gebunden.
- **Worker überleben den Tod der Pumpe** — separat geprüft: nach
  `pkill -f pump.sh` liefen drei Worker weiter. Sie sind eigenständige
  OS-Prozesse. Tödlich ist nur ein Signal an die ganze **Prozessgruppe** (oder
  eben ein Standby, der ihre Netzverbindung reißt).

⚠ **Korrektur gegenüber einer früheren Fassung dieses Tutorials:** Ich hatte die
fünf `reclaimed`-Runs meinen eigenen Prozess-Kills zugeschrieben. Das war falsch
— mein `pkill` lief erst um 17:07, also **nach** allen drei Anläufen. Die
Zeitstempel aus `pmset -g log` weisen den Clamshell-Sleep als Ursache aus.

---

## Schritt 11.11 — Warum zwei Tore zwei Karten sind

Das ist die technisch interessanteste Stelle dieser Story, und sie ist der Grund
für eine Konstruktionsentscheidung, die man sonst für Umstand halten würde.

Die naheliegende Bauweise wäre: **eine** Karte hält beide Tore. Erst blockiert
sie für die inhaltliche Freigabe, dann — nach dem Ingest und dem Lint — noch
einmal für den Merge. Der Worker hätte durchgehend den Kontext, und auf dem
Board wäre es eine Karte statt zwei.

**Das funktioniert nicht.** Real gemessen, auf einer Karte ohne Assignee (kein
Worker, keine Tokens):

```bash
ID=$(hermes kanban --board kanban-probe create "reblock-probe" --json | jq -r .id)
hermes kanban --board kanban-probe block --kind needs_input $ID "gate 1: ingest freigeben"
hermes kanban --board kanban-probe unblock $ID --reason "approve"
hermes kanban --board kanban-probe block --kind needs_input $ID "gate 2: merge freigeben"
```

```console
Blocked t_2795cbb8: gate 1: ingest freigeben
Unblocked t_2795cbb8: approve
t_2795cbb8 → triage (unblock loop detected — needs a human decision): gate 2: merge freigeben
```

Die Karte steht danach in **`triage`**, nicht in `blocked`. Das Tor ist weg. Der
Ereignis-Strom sagt, warum — hier gekürzt aus
`hermes kanban show <id> --json | jq -r '.events[]'`, weil `show` **ohne**
`--json` in v0.20.0 abbricht (siehe Fallstricke):

```console
blocked              {"reason":"gate 1...","kind":"needs_input","recurrences":1,"source_status":"ready"}
unblocked            null
block_loop_detected  {"reason":"gate 2...","kind":"needs_input","recurrences":2,"limit":2,"source_status":"ready"}
```

Es ist kein `blocked`-Ereignis mehr, sondern **`block_loop_detected`**. Hermes
hält einen zweiten Block mit derselben Ursache für eine Schleife — für einen
Cron-Job, der eine Karte immer wieder entblockt, die sich immer wieder blockiert
— und eskaliert sie in die Triage, statt sie erneut auf `blocked` zu legen.

### Was „dieselbe Ursache" heißt

Die Ursache ist die **Block-Art**, nicht der Grund. In `hermes_cli/kanban_db.py`:

```python
BLOCK_RECURRENCE_LIMIT = 2                     # Zeile 134
…
same_cause  = prev_kind == kind                # Zeile ~5997
recurrences = prev_recurrences + 1 if same_cause else 1

if recurrences >= BLOCK_RECURRENCE_LIMIT:
    #  -> status = 'triage', Ereignis block_loop_detected
```

Daraus folgt das Verhalten, real geprüft:

| Block 1 | Block 2 | Ergebnis nach Block 2 |
|---|---|---|
| `--kind needs_input` | `--kind needs_input` | **`triage`** — `block_loop_detected`, `recurrences: 2` |
| `--kind needs_input` | `--kind capability` | **`blocked`** — `recurrences` startet wieder bei 1 |

```console
$ hermes kanban --board kanban-probe block --kind capability $ID "gate 2: merge freigeben"
Blocked t_01fad84f: gate 2: merge freigeben

blocked  {"reason":"gate 2: merge freigeben","kind":"capability","recurrences":1,...}
```

Zwei Tore auf **einer** Karte gehen also — aber nur mit **zwei verschiedenen
Block-Arten** und nur **einmal je Art**. Ein dritter Block mit einer schon
benutzten Art kippt wieder in die Triage:

```console
needs_input → unblock → capability → unblock → capability   ⇒   triage
```

Der Zähler wird laut Quelltext „**nur bei erfolgreichem Abschluss**"
zurückgesetzt (`kanban_db.py:994`) — innerhalb einer Karte, die noch läuft, gibt
es also kein Zurücksetzen.

### Und es gibt keinen Schalter dafür

```console
$ hermes config get kanban.block_loop_limit
Config key not set: kanban.block_loop_limit
$ hermes config get kanban.block_recurrence_limit
Config key not set: kanban.block_recurrence_limit
```

`BLOCK_RECURRENCE_LIMIT` ist eine Konstante im Quelltext, kein
Konfigurationsschlüssel. Die Grenze ist 2 und bleibt 2.

### Die Entscheidung

Diese Story baut deshalb **zwei Karten**:

| Karte | Block-Art | Verben |
|---|---|---|
| `Vorschlag + Tor 1: <slug>` | `needs_input` | `approve` · `shelve` · `modify` |
| `Commit + Tor 2: <slug>` | `capability` | `merge` · `merge-ohne-prune` · `discard` |

Drei Gründe, in der Reihenfolge ihrer Belastbarkeit:

1. **Es ist immun gegen den Zähler.** Zwei Karten haben zwei Zähler. Braucht ein
   Tor eine Rückfrage („Antwort nicht verstanden"), darf es ein zweites Mal
   blockieren, ohne die Karte zu verlieren.
2. **Auf dem Board ist sichtbar, an welchem Tor du stehst.** Der Titel sagt es,
   und `pump.sh` beschriftet es mit den Verben, die dort gelten.
3. **Es zwingt zu zwei Vokabularen.** Wären es dieselben drei Verben, hätte man
   ein Tor zweimal gebaut. `approve` an Tor 2 hieße, über eine Löschung mit dem
   Wortschatz einer Aufnahme zu entscheiden.

`gate.sh` setzt das durch — real gemessen:

```console
$ ./gate.sh merge <tor-1-id>
'merge' gilt an Tor 1 nicht. Dort gelten: approve shelve modify

Tor 1 entscheidet, ob Wissen AUFGENOMMEN wird.
Tor 2 entscheidet, ob es nach main geht und ob etwas GELOESCHT wird.
Dieselben Verben fuer beides waeren ein Tor, zweimal gebaut.

$ ./gate.sh approve <tor-2-id>
'approve' gilt an Tor 2 nicht. Dort gelten: merge merge-ohne-prune discard
```

### Dass die Blocks halten, ist geprüft

```console
$ hermes kanban --board kanban-story-11 dispatch --dry-run
Reclaimed:    0
Crashed:      0
Timed out:    0
Stale:        0
Auto-blocked: 0
Promoted:     0
Spawned:      0
```

Und `pump.sh` endet von selbst, sobald die Pipeline auf einen Menschen wartet —
`blocked` zählt dort nicht als „offen":

```console
[01] blocked=2

Nichts mehr offen — Pumpe beendet.

⊘ t_d80d9015  blocked   (unassigned)   [wiki]  Vorschlag + Tor 1: test-item
⊘ t_eb8709ac  blocked   (unassigned)   [wiki]  Commit + Tor 2: test-item

2 Karte(n) warten auf einen Menschen:
  t_d80d9015  [TOR 1: approve | shelve | modify]        Vorschlag + Tor 1: test-item
  t_eb8709ac  [TOR 2: merge | merge-ohne-prune | discard]  Commit + Tor 2: test-item
```

⚠ `pump.sh` warnt außerdem, wenn eine Karte in der **Triage** landet — denn
genau dorthin routet `block_loop_detected`, und ohne Warnung sucht man lange.

### Der Ablauf am Tor

```bash
./gate.sh                                    # was wartet, und an welchem Tor?
./gate.sh approve <tor1-id>
./gate.sh shelve  <tor1-id> "steht so schon in release-historie.md"
./gate.sh modify  <tor1-id> "nur den Block-Teil, den Rest weglassen"
./gate.sh merge            <tor2-id>
./gate.sh merge-ohne-prune <tor2-id>
./gate.sh discard          <tor2-id> "erst pruefen, ob die Quelle stimmt"
```

Dahinter steckt beide Male **ein** Befehl:

```bash
hermes kanban --board kanban-story-11 unblock <id> --reason "<verb> …"
```

`--reason` legt den Text als **Kommentar** an die Karte und hebt sie danach nach
`ready`. Real gemessen, der Kommentar-Thread einer Tor-Karte:

```console
default: BLOCKED: TOR 1 test-item (update, 84/100): zwei Patch-Releases in
         release-historie.md aufnehmen, 1 Seite geaendert, Index unveraendert.
         Antwort: unblock --reason 'approve' | 'shelve: <grund>' | 'modify: <aenderung>'
default: UNBLOCK: approve
```

Beide Zeilen legt Hermes selbst an, mit den Präfixen `BLOCKED:` und `UNBLOCK:`.
Der Orchestrator liest im zweiten Lauf genau diesen Thread — deshalb ist
`--reason` bei `unblock` die natürliche Form einer Antwort an ein Tor.

⚠ **Die Syntax von `block` ist nicht die dokumentierte.** Bei `block` ist der
Grund **positional**, und `--kind` muss **vor** die Kartennummer:

```bash
# falsch — bricht mit "unrecognized arguments" ab:
hermes kanban block <id> --reason "Freigabe noetig"
hermes kanban block <id> --kind needs_input "Freigabe noetig"

# richtig:
hermes kanban block <id> "Freigabe noetig"
hermes kanban block --kind needs_input <id> "Freigabe noetig"
```

Bei `unblock` gibt es `--reason` sehr wohl. Das Korpus dieser Story enthält
diesen Widerspruch übrigens als **Inhalt** — er ist genau der Konfliktfall, den
die Pipeline in Schritt 11.10 selbst behandelt hat. Die Wissensbasis dieser
Story dokumentierte die falsche Syntax, die Quellen belegten die richtige, und
am Ende stand die Korrektur in `main`.

---

## Das solltest du sehen

```bash
source task-ids.env
hermes kanban --board $BOARD stats
./reset-workspace.sh --git
python3 workspace/bin/kb_lint.py workspace/wiki
```

### ⚠ Zuerst: dein Lauf ist **kleiner** als der protokollierte

Der Lauf unten entstand **vor** `rubrik.max_pro_lauf` (Schritt 11.7). Mit den
ausgelieferten Artefakten sieht dieselbe Pipeline auf demselben Korpus so aus:

| | protokollierter Lauf (ohne Deckel) | **dein Lauf** (`max_pro_lauf: 3`) |
|---|---|---|
| Items insgesamt | 15 | 15 |
| davon `geshelved` (schon abgedeckt) | 9 | **9** — unverändert, das Shelven passiert **vor** dem Deckel |
| davon über der Schwelle | 6 | 6 |
| davon im Fan-out | 6 | **3** (die besten nach Score) |
| davon `zurueckgestellt` | — | **3** — kommen beim nächsten Sweep wieder |
| Bahn-Karten | 12 | **6** |
| Route-Karten | 6 | **3** |
| Tor 1 | **6×** | **3×** |
| Ingest / Lint / Commit-Ketten | 3 (nach 2× approve, 1× modify) | bis zu 3 |
| Tor 2 | 3× | bis zu 3× |
| Karten insgesamt | **37** | **grob 25**, je nachdem wie du die Tore beantwortest |

Was sich **nicht** ändert und worauf du deshalb prüfen kannst:

- **9 Items geshelved, alle mit Score 20 und Fundstelle.** Der Deckel greift
  nach der Bewertung; die Dedup-Aussage ist von ihm unberührt.
- **Der Linter geht von 5 ERROR auf 0**, und der eine STALE-Befund bleibt stehen.
- **Keine ungeplante Karte** — `created_by` kennt nur `kb-orchestrator` und `user`.
- **Die Ingest-Ketten laufen seriell**, eine nach der anderen.

Die Scores selbst (98, 91, 85, …) und welche Kandidaten das Modell zu welchem
Item bündelt, sind **Modellentscheidungen** und werden bei dir abweichen.

### Der protokollierte Lauf

**37 Karten, 52 Runs, alle auf `done`** — davon hast du drei angelegt:

```console
$ hermes kanban --board $BOARD list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'

kb-orchestrator: 34   user: 3
```

```console
$ hermes kanban --board $BOARD stats
By assignee:
  kb-ingestor           done=3
  kb-linter             done=3
  kb-orchestrator       done=16
  kb-researcher         done=13
  kb-scout              done=2
```

⚠ **Keine einzige ungeplante Karte.** Story 10 hat an dieser Stelle zwei
Duplikate produziert, weil ein Worker die in seinem Auftrag beschriebenen
Folgestufen selbst angelegt hat. Hier hat der `idempotency_key` auf jeder
Kettenkarte plus der Satz „Lege selbst KEINE weiteren Karten an" gehalten —
`created_by` kennt nur `kb-orchestrator` und `user`.

Der Verlauf, real gemessen:

```console
15:21  Scout releases      3m   ─┐ parallel, 19 Kandidaten
15:21  Scout transcripts   3m   ─┘           12 Kandidaten
15:24  Triage             25m       15 Items, 9 geshelved, 6 im Fan-out (98..70)
15:50  12× Recherche   2–75m       zwölf Prozesse gleichzeitig
16:02  6× Route        1–2m        fehlt · widerspruch · 4× unvollstaendig
16:03  6× Tor 1 blockiert       ══ wartet auf dich ══
16:16  Tor 1 Lauf 2              2× approve, 1× modify, 3× shelve
16:17  Ingest #1        skills-system — 3 Anläufe, 2× reclaimed
       ══ 16:20–17:06 Rechner im Standby (Deckel zu). Board nimmt selbst wieder auf ══
17:09  Lint  #1           3m       ERROR 4 → 0
17:12  Tor 2 #1 blockiert       ══ wartet auf dich ══
17:17  Tor 2 #1 Lauf 2           merge  → main
17:19  Ingest #2 … Tor 2 #2      dispatcher-reclaim-und-tick, serialisiert
17:25  Ingest #3 … Tor 2 #3      der Konflikt, serialisiert
17:33  fertig
```

### Wo die zwei Stunden hingegangen sind

Die naheliegende Frage lautet: **warum braucht die Verarbeitung von sechs
Textdateien so lange?** Die Antwort ist, dass die sechs Dateien praktisch nichts
kosten. Gerechnet aus `beispiel-lauf-1/laufzeiten.txt` (aus `started_at` /
`completed_at` je Karte):

| | |
|---|---|
| Wanduhr erste bis letzte Karte | **131 min** |
| Summe **aller** Kartenlaufzeiten | **455 min** → Parallelitätsfaktor **~3,5** |
| höchste Parallelität | **12 Karten gleichzeitig**, um 15:50 |
| davon Standby (Rechner schlief) | 46 min |
| davon mindestens eine Karte aktiv | 86 min |
| davon **nichts** aktiv | **0 min** |

⚠ **Die letzte Zeile korrigiert eine frühere Fassung dieses Tutorials**, in der
„gut 40 Minuten Wartezeit an vier Torstellungen" stand. Gemessen gibt es
außerhalb des Standbys **keine einzige Minute Leerlauf**: während ich an den
Toren überlegt habe, liefen andere Karten weiter. Die Tore haben diesen Lauf
**nicht** verlängert.

### Die sechs Quelldateien sind nicht der Kostentreiber

```console
15:21  15:24    3.0  Scout releases: sources/releases auswerten
15:21  15:24    3.0  Scout transcripts: sources/transcripts auswerten
```

**Zwei Scouts, je drei Dateien, gleichzeitig, drei Minuten.** Damit ist der
Eingang erledigt — 2 % der Laufzeit.

Was wirklich kostet, sortiert nach Laufzeit:

| min | Karte | Art |
|---|---|---|
| **25,9** | Triage | **Urteil** — eine einzige, serielle Karte |
| 11,7–15,8 | 12 Recherche-Bahnen (parallel) | Urteil |
| 10,3–12,9 | 5 Vorschlags-/Tor-Karten (parallel) | Urteil (+ meine Wartezeit) |
| 3,0 | 2 Scouts (parallel) | Erkennen |
| 2,8 / 1,8 | Ingest #3 / #2 | Schreiben |
| 3,4 / 1,1 / 0,7 | Lint #1 / #2 / #3 | **Skript** |
| 0,6–1,4 | 6 Route-Karten | **Tabellen-Nachschlag** |

Daraus lässt sich die Kostenstruktur dieser Pipeline direkt ablesen:

**1. Die Triage allein ist 26 Minuten — 30 % der wachen Zeit.** Und sie skaliert
nicht mit sechs Dateien, sondern mit **31 Kandidaten × 7 Wiki-Seiten**: sie muss
die Wissensbasis wirklich lesen, 15 Items bilden, jedes gegen fünf Dimensionen
begründen, 15 Dateien schreiben und 18 Karten anlegen — alles in *einem* Kontext,
seriell, weil Dedup eine Gesamtsicht braucht. **Das ist der Preis dafür, dass die
Pipeline neun Items korrekt als „wissen wir schon" abgelegt hat.**

**2. Urteilen kostet 10–26 Minuten, Nachschlagen unter einer Minute.** Die
Route-Karten sind mit 0,6–1,4 min die billigsten des ganzen Boards — genau das
war die Absicht: *der Klassifikator darf urteilen, was daraus folgt, ist eine
Tabelle.* Der Linter braucht 0,7–3,4 min, weil `kb_lint.py` die Befunde liefert
und das Modell nur repariert. Wer diese Pipeline schneller haben will, verschiebt
Arbeit von der linken in die rechte Spalte — nicht in ein größeres Modell.

**3. Das Schreiben ist billig.** Ingest #2 und #3 brauchten 1,8 und 2,8 Minuten.
Die Serialisierung der drei Ketten kostet zwar Wanduhr (~7 min je Kette), aber
das ist der günstigste Teil des Ablaufs — der Konkurrenzschutz ist fast gratis.

**4. Die Parallelität ist echt, aber vom Graphen begrenzt.** 12 Prozesse
gleichzeitig, Faktor 3,5 gesamt. Mehr geht nicht, weil die Route-Karte ein
**Fan-in** ist: sie wartet auf *beide* Bahnen, also bestimmt die langsamste das
Tempo. Zwölf Bahnen zu je ~12 min brauchen zusammen ~16 min Wanduhr — aber keine
Route startet vor der letzten.

> **Die Laufzeit skaliert mit Items × Stufen, nicht mit Quelldateien.** Eine
> siebte Quelldatei kostet den Scout ~30 Sekunden. Ein siebtes *Item* über der
> Schwelle kostet 7 Karten: 2 Bahnen, 1 Route, 1 Tor, 3 Kettenstufen — plus zwei
> Entscheidungen von dir. Genau deshalb ist `rubrik.max_pro_lauf` der wirksamste
> Hebel auf die Laufzeit, und nicht die Zahl der Quellen.

Entstanden ist:

```console
intake/releases.md                 Scout-Bericht (19 Kandidaten)
intake/transcripts.md              Scout-Bericht (12 Kandidaten, 1 Datei mit 0)

vault/  15 Item-Dateien mit score + score_breakdown
        12 Bahn-Ergebnisse (verifikation / seiten-abgleich)
         1 Konflikt-Dossier
         6 Vorschläge (was am Tor stand)
         3 Lint-Berichte

wiki/pages/skills-system.md              NEU — heilt index.md:21
wiki/pages/kanban-block-semantik.md      korrigiert, falsche Aussage GEPRUNT
wiki/pages/gateway-und-dispatcher.md     präzisiert (ohne die unbelegte Aussage)
wiki/pages/{cron-und-zeitplan,kanban-board,memory-system,profile-system}.md
                                         Linter-Reparaturen
wiki/index.md                            zwei Einträge ergänzt
wiki/log/ingest-log.md                   3 Absätze, mit dem Wortlaut aller Tore
```

Und der Linter am Ende:

```console
ERROR: 0  STALE: 1  PRUNE-VORSCHLAG: 0

BESTANDEN — keine ERROR-Befunde. Ein Merge ist erlaubt.
Es liegen Prune-Kandidaten vor. Darueber entscheidet ein Mensch (AGENTS.md 6).
```

**Von fünf ERROR-Befunden auf null, und der eine STALE-Befund steht noch da** —
weil ihn niemand wegräumen durfte, ohne den Inhalt anzusehen. Das ist kein
Restmüll, das ist die offene Frage, die die Pipeline korrekt offen gelassen hat.

### Die Rechenschaft steht im Repository

Das ist der Teil, den Story 10 nicht hat:

```console
$ sed -n '10,20p' workspace/wiki/log/ingest-log.md

## 2026-08-11 · kanban-block-semantik-korrektur · konflikt · 91/100
- **Branch:** `kb/ingest-kanban-block-semantik-korrektur`
- **Entscheidung Tor 1:** approve — „UNBLOCK: approve"
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 0 geschrieben / 1 geaendert / 1 geprunt
- **Quellen:** `changelog-0.20.1.md`, `changelog-0.20.2.md`, `2026-08-08-block-semantik.md`

Route **konflikt**: die QUELLE gewinnt, der Mensch hat am Tor 1 mit `approve`
entschieden. Geprunt (ersetzt, nicht ergaenzt): die falsche Aussage
`block <id> --reason "…"` (Z. 24). …
```

Ein Score in einer Datenbank ist eine Notiz. **Ein Score im Git-Log der
Wissensbasis, neben dem Wortlaut der Freigabe und der Liste dessen, was
gelöscht wurde, ist eine Rechenschaft.**

### Der Lauf liegt vollständig daneben

`workspace/` ist bei Auslieferung leer (es wird aus `seed/` gebaut und ist in
`.gitignore`). Damit du die Artefakte lesen kannst, ohne die Pipeline laufen zu
lassen:

```
beispiel-lauf-1/intake/     die zwei Scout-Berichte
beispiel-lauf-1/vault/      alle 37 Zwischenartefakte
beispiel-lauf-1/wiki/       die Wissensbasis NACH den drei Merges
beispiel-lauf-1/git-log.txt git log --graph --stat der Wissensbasis
beispiel-lauf-1/board.json  das Board am Ende
```

Am lehrreichsten sind zwei Dateien: `wiki/log/ingest-log.md` (warum steht das
hier?) und `vault/kanban-block-semantik-korrektur-konflikt.md` (wie macht man
eine Entscheidung für einen Menschen billig?).

---

## Was gegenüber dem Original anders ist

Die Vorlagen sind ein Python-Projekt mit einer generischen Engine plus ein
Obsidian-Wiki-Template; diese Story ist ein Hermes-Board mit fünf Profilen, zwei
Konfigurationsdateien und zwei kleinen Skripten. Was das konkret bedeutet:

| Im Original | Hier | Warum |
|---|---|---|
| **Telegram** als Kanal für beide Tore, `approve <slug>` als Chat-Antwort | `kanban block` / `unblock --reason` auf dem Board, `./gate.sh` als Hülle | Telegram braucht Bot-Token, `TELEGRAM_ALLOWED_USERS` und einen erreichbaren Gateway. Das Board kann jeder sofort. Die Semantik ist dieselbe: zwei Entscheidungen, zwei Vokabulare. |
| **Python-Engine** rechnet Score, Route und Kartenketten aus | Skill `kb-pipeline` + `ingest.yaml`, gelesen vom Worker | Hermes hat für Kartenketten schon einen Mechanismus (`kanban_create` + `parents`). Eine zweite Engine daneben wäre Verdopplung. |
| **`knowledge_base_lint`** als Python-Skript | `bin/kb_lint.py`, 14 Regeln, aus `AGENTS.md` abgeleitet | **Hier folgt die Story dem Original ausdrücklich.** Der Linter ist der eine Teil, der deterministisch sein *muss* — siehe unten. |
| **`KB git`** als dünner Git-Helfer | `bin/kb_git.py`, sechs geprüfte Verben | Ebenfalls übernommen, und um einen Riegel erweitert, den das Original nur als Regel führt: `merge` lintet selbst. |
| **Live-Suche** auf GitHub-Releases und dem eigenen YouTube-Kanal, später X | eingefrorenes Korpus unter `sources/` | Reproduzierbarkeit. Ohne festes Korpus ist kein Durchlauf mit dem nächsten vergleichbar, und die Story bräuchte API-Schlüssel (im Original: Grok-OAuth für den Scout). |
| **Fünf Modelle** über OpenRouter: Grok für den Scout, Nemotron für Linter und Researcher, MiniMax M3 für den Ingestor | ein Modell für alle fünf Profile | Am Mechanismus ändert das nichts. Wie du es umstellst, steht unter [Varianten](#varianten). Die Kostenaussage des Originals (~95 Cent je Ingest mit MiniMax) lässt sich hier nicht nachmessen. |
| **Obsidian** als Oberfläche der Wissensbasis | reines Markdown mit `[[slug]]` | `[[…]]` ist Obsidian-kompatibel; du kannst `workspace/wiki/` direkt als Vault öffnen. Der Linter braucht Obsidian nicht. |
| **Zwei Gates** (Ingest/Update und Prune) | zwei Gates auf **zwei Karten**, mit verschiedenen Block-Arten | Der Zwang zu zwei Karten ist eine Hermes-Eigenschaft, die das Original nicht hat — siehe Schritt 11.11. |
| Ein **Runbook**, das Claude schreibt und Hermes ausführt | `setup.sh` + `create-tasks.sh` | Ein Skript ist prüfbar und wiederholbar; ein Runbook ist eine Bitte. |

### Die Rechnung, die Story 10 offen lässt

Story 10 zitiert die These des Originals und gibt zu, sie nicht erfüllt zu haben:

> **Fat engine, thin skill.** Multi-Agent-Pipelines scheitern, wenn zu viel
> Logik in Prosa lebt, die ein Modell bei jedem Lauf neu interpretiert.

Und weiter, im Abschnitt „Der ehrliche Tausch: Prosa gegen Python":

> Wenn du die Determinismus-These des Originals brauchst […], ist der Weg:
> `triage.yaml` von einem Skript lesen, das den Score aus strukturierten Feldern
> **rechnet**, und den Worker nur die Felder füllen lassen.

**Diese Story zahlt einen Teil dieser Rechnung — und nur einen Teil.** Es ist
wichtig, beides genau zu benennen:

| Was hier deterministisch ist | Was hier Urteil bleibt |
|---|---|
| die **Form** jeder Seite (14 Regeln, `kb_lint.py`) | der **Score** — zwei Läufe können 91 und 84 ergeben |
| der **Index** (jede Seite genau einmal verlinkt) | die **Klassifikation** (`fehlt` vs. `unvollstaendig`) |
| die **Aktualitätsgrenze** (180 Tage, gerechnet) | ob eine Seite eine Aussage „in gleicher Genauigkeit" enthält |
| die **Merge-Vorbedingung** (Lint muss bestehen) | ob ein Widerspruch ein Widerspruch ist |
| der **Konkurrenzschutz** (`branch` weist ab) | wer bei einem Widerspruch recht hat — das entscheidet ein Mensch |

Die rechte Spalte ist nicht ein Rest, den man noch wegräumen müsste. **Die
Konflikterkennung ist die eigentliche Bewertungsarbeit dieser Pipeline; alles
andere sind deterministische Linter-Checks.** Genau so sagt es das Original, und
genau so ist die Arbeit hier verteilt: was eine Regel sein kann, ist Code; was
ein Urteil ist, wird aufgeschrieben und einem Menschen vorgelegt.

Was gegen die Nicht-Determinismus-Reste hilft, und was diese Story deshalb
erzwingt: **jede Bewertung wird aufgeschrieben** — in die Item-Datei *und* in die
Completion-Metadaten *und* am Ende in `wiki/log/ingest-log.md`.

```bash
grep -A6 "^## Bewertung" workspace/vault/*.md
hermes kanban --board $BOARD show <triage-id> --json | jq -r '.runs[-1].metadata'
sed -n '1,40p' workspace/wiki/log/ingest-log.md
```

Das Ingest-Log ist dabei die stärkste Zutat, und sie fehlt in Story 10: es ist
die einzige Stelle, an der eine **menschliche Entscheidung dauerhaft im
Repository** steht. Ein Score in einer Datenbank ist eine Notiz. Ein Score im
Git-Log der Wissensbasis, neben dem Wortlaut der Freigabe, ist eine
Rechenschaft.

---

## Varianten

### Ein anderes Modell je Rolle

Im Original läuft der Scout auf Grok (um X durchsuchen zu können), Linter und
Researcher auf Nvidia Nemotron 3 Ultra, der Ingestor auf MiniMax M3 — alle über
OpenRouter. Zwei Wege:

```bash
# a) pro Karte, ohne ein zweites Profil:
hermes kanban --board $BOARD create "Scout releases: …" --assignee kb-scout \
    --model "x-ai/grok-4" --provider openrouter …

# b) pro Profil, dauerhaft:
hermes -p kb-ingestor config set model.default "minimax/minimax-m3"
hermes -p kb-linter   config set model.default "nvidia/nemotron-3-ultra"
hermes -p kb-scout    config set model.default "x-ai/grok-4"
```

`--provider` verlangt `--model`. Der Rest der Pipeline merkt davon nichts — das
Board kennt nur den Profilnamen.

⚠ **Der Linter ist genau die Rolle, bei der ein billigeres Modell am wenigsten
schadet.** Er entscheidet fast nichts: `bin/kb_lint.py` liefert die Befunde, das
Modell repariert sie. Umgekehrt ist der **Orchestrator** die Rolle, bei der
Sparen am teuersten ist — er dedupliziert gegen die Wissensbasis, und ein Modell,
das dort oberflächlich liest, schreibt Wissen ein zweites Mal.

⚠ Der Kostenwert des Originals (~95 Cent für einen Ingest über OpenRouter mit
MiniMax) ist hier **nicht** nachgemessen — diese Story wurde auf einem einzigen
Modell durchgespielt.

### Den Sweep auf einen Zeitplan setzen

```bash
./install-cron.sh                # taeglich 07:00
./install-cron.sh "every 12h"
./install-cron.sh --remove
```

Der Job läuft mit `--no-agent`: kein Modell, **keine Tokenkosten**. Das Skript
`scripts/kb-sweep-tick.sh` legt nur die drei Eingangskarten an; die Kosten
entstehen erst bei den Workern, die der Dispatcher danach startet. Die
`--idempotency-key`s enthalten das Datum — ein zweiter Tick am selben Tag legt
nichts Neues an.

**Der Tick überspringt sich selbst**, wenn eine von drei Bedingungen nicht
stimmt, und das ist der wichtigere Teil:

| Bedingung | Warum |
|---|---|
| Arbeitsbaum der Wissensbasis ist sauber | ein Sweep auf halbfertiger Arbeit vermischt zwei Ingests |
| kein Ingest-Branch offen | dasselbe, eine Ebene höher |
| **keine Karte wartet auf eine Entscheidung** | ein Cron-Job kann niemanden fragen |

Die dritte ist die, die man vergisst. Ohne sie wächst die Zahl offener Tore mit
jedem Tick, bis niemand sie mehr auseinanderhält — und dann wird nicht
sorgfältiger entschieden, sondern durchgewinkt.

⚠ Der Autor des Originals rät ausdrücklich davon ab, den Sweep stündlich laufen
zu lassen: **ein- bis zweimal täglich**. Jeder Tick zieht eine ganze Pipeline
nach sich, und diese hier verlangt bis zu zwei menschliche Entscheidungen je
Item.

### Die Tore über Telegram statt über das Board

Der Weg wäre `hermes kanban notify-subscribe` für die Benachrichtigung und
`hermes send --to telegram` im Orchestrator für den Vorschlagstext. Beides ist in
diesem Tutorial **nicht** verifiziert (keine Anbindung konfiguriert) — siehe
[VERIFIKATION.md](../VERIFIKATION.md).

Der Hinweis des Originals gilt unabhängig davon: **Telegram reserviert
`/commands`.** Eine Antwort heißt `approve <slug>`, nicht `/approve <slug>`.

### Die Wissensbasis in einem echten Repository

`workspace/` ist eine Arbeitskopie und wird von `reset-workspace.sh` gelöscht.
Willst du eine echte Wissensbasis pflegen, zeigst du die Karten auf deinen
eigenen Pfad:

```bash
hermes kanban --board $BOARD create "…" --workspace "dir:/abs/pfad/zu/deiner/kb" …
```

Dort müssen `ingest.yaml`, `bin/` und `proposals/` daneben liegen, und `wiki/`
muss ein Repository mit Branch `main` sein. Drei Dinge dann bitte vorher:

1. **`sources/` außerhalb des Repositorys halten.** Das ist die Umkehrbarkeit.
2. **`AGENTS.md` an deine Wissensbasis anpassen** — und `kb_lint.py` mit. Die
   Konstanten dafür stehen ganz oben in der Datei.
3. **`git log` ansehen, nicht nur das Ergebnis.** Jeder Ingest ist ein Commit;
   ein Merge, der etwas Falsches gebracht hat, ist mit `git revert` erledigt.

---

## Fallstricke

- **Zwei Tore auf einer Karte mit derselben Block-Art.** Die Karte landet in der
  **Triage**, nicht in `blocked`, und das Tor ist weg. Gemessen in Schritt 11.11.
  `pump.sh` warnt, wenn eine Karte in der Triage auftaucht.
- **`hermes kanban block <id> --reason "…"`.** Existiert in v0.20.0 nicht. Der
  Grund ist positional, `--kind` gehört **vor** die Kartennummer.
- **`hermes kanban show <id>` ohne `--json` bricht in v0.20.0 ab.** Reproduzierbar
  auf jedem Board, auch mit einer frisch angelegten Karte:
  `sqlite3.ProgrammingError: Cannot operate on a closed database` aus
  `kanban_db.py:3669`. Der Kopf der Karte wird noch gedruckt, dann stirbt es im
  Diagnostics-Block. Nimm `show --json`, `runs`, `context` oder `log` — die
  funktionieren alle. Details unten unter „Ein Fehler in v0.20.0".
- **Relativer `workspace_path` in `kanban_create`.** Die Karte wird angelegt und
  nie gestartet. Prüfen mit
  `hermes kanban show <id> --json | jq .task.workspace_path`.
- **Die Ingest-Kette auf `worktree:` legen.** Jede Karte bekäme ihr eigenes
  Verzeichnis, und Lint und Commit sähen die Arbeit des Ingestors nicht. Alle
  Stufen brauchen dasselbe `dir:`.
- **Zwei Ingests gleichzeitig.** `kb_git.py branch` weist ab — das ist die
  Rettung, nicht das Problem. Wer die Abweisung „umgeht", produziert einen
  Branch, der die Arbeit des anderen enthält.
- **Den Linter reparieren, statt die Wissensbasis.** Ein Linter, der angepasst
  wird, damit er besteht, prüft nichts mehr. Die `SOUL.md` von `kb-linter`
  verbietet es ausdrücklich; wenn Linter und `AGENTS.md` wirklich
  auseinanderlaufen, ist das ein Fund und gehört blockiert.
- **`updated` auf heute setzen, um einen STALE-Befund loszuwerden.** Damit ist
  die Prüfung für 180 Tage stillgelegt, ohne dass jemand den Inhalt angesehen
  hat. Deshalb sperrt STALE den Merge auch nicht.
- **Eine Stub-Seite anlegen, damit ein toter Link auflöst.** Der Linter ist dann
  still und die Lücke ist geblieben. `AGENTS.md` 3 nennt einen Stub-Link genau
  deshalb einen Fehler.
- **Einen Widerspruch „auflösen", indem die neuere Quelle gewinnt.** Eine
  Pipeline, die das automatisch tut, wäscht falsche Information in eine
  Wahrheitsquelle. Der Konfliktfall gehört an ein Tor, immer.
- **`--max-runtime` rechnet Wanduhrzeit, nicht Rechenzeit.** Schläft der Rechner
  mitten in einer Karte, läuft der Deckel weiter. Gemessen: ein Run stand mit
  „27m" da und hatte real drei Minuten gearbeitet — die übrigen 24 hat die Karte
  geschlafen. Bei einer Karte wie der Triage, die real 25 Minuten braucht, ist
  ein Deckel von 30 Minuten deshalb zu knapp; die Startskripte geben ihr 45.
- **Ein Standby killt die Worker, nicht die Karten.** Der Dispatcher nimmt die
  Arbeit von selbst wieder auf (`stale_lock` → neuer Run), aber jeder Neustart
  kostet die **ganze** Stufe an Tokens. Wer eine solche Pipeline laufen lässt,
  klappt den Deckel nicht zu — und nimmt das Gateway statt eines Skripts in einem
  Terminal. Siehe Schritt 11.10, „Was an diesem Lauf nicht gut war".
- **Ein laufendes Gateway startet Karten sofort**, auch auf einem frisch
  angelegten Board. Wer in Ruhe zusehen will: `hermes pause` / `hermes resume`.
- **Die Schwelle allein begrenzt die Menge nicht.** Sie sortiert nach
  Wichtigkeit. Ohne `rubrik.max_pro_lauf` kann ein reiches Korpus ein Dutzend
  Items über 65 liefern — und damit zwei Dutzend Torfragen.

---

## Aufräumen

```bash
source task-ids.env
hermes kanban --board $BOARD list --tenant wiki --json \
  | jq -r '.[].id' | xargs hermes kanban --board $BOARD archive
```

⚠ **Willst du das Ergebnis behalten, kopiere es vorher heraus** — mit dem
Workspace verschwindet das Git-Repository der Wissensbasis:

```bash
cp -R workspace/wiki /pfad/deiner/wahl
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

`teardown.sh` entfernt **nur** Profile mit der Marke `.story11`, die `setup.sh`
hinterlässt. Ein `kb-…`-Profil, das du selbst angelegt hast, bleibt stehen.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban block --kind needs_input <id> "<grund>"` | Tor 1 — wartet auf einen Menschen; `--kind` **vor** die ID, Grund **positional** |
| `hermes kanban block --kind capability <id> "<grund>"` | Tor 2 — eine **andere** Block-Art, damit der Schleifenzähler nicht greift |
| `hermes kanban unblock <id> --reason "<antwort>"` | Kommentar **und** Freigabe in einem Schritt — beide Tore |
| `kanban_block(kind=…, reason=…)` | dasselbe aus dem Worker heraus, auf der **eigenen** Karte |
| `kanban_create(…, idempotency_key="…")` | Der Worker erweitert das Board selbst, ohne Doppelanlage |
| `kanban_list()` im Worker | offene Ingests finden — die kooperative Ebene des Konkurrenzschutzes |
| `hermes kanban --board <b> dispatch --dry-run` | Prüfen, ob ein Tor wirklich hält (`Promoted: 0`) |
| `hermes kanban show <id> --json \| jq .task.workspace_path` | Aufgelösten Workspace prüfen — **`--json` ist in v0.20.0 Pflicht** |
| `hermes kanban runs <id>` / `context <id>` / `log <id>` | die Diagnosewege, die ohne `--json` funktionieren |
| `hermes kanban create … --model <m> --provider <p>` | Modell nur für diese Karte |
| `hermes -p <profil> config set model.default <m>` | Modell dauerhaft je Rolle |
| `hermes -p <profil> skills list` | Welche Skill liegt bei welchem Profil? |
| `hermes cron create "<plan>" --script <s> --no-agent --deliver local` | Sweep auf Zeitplan, tokenfrei |
| `python3 bin/kb_lint.py wiki [--json] [--strict] [--today …]` | Der deterministische Teil |
| `python3 bin/kb_git.py {status,branch,commit,changed,merge,discard,log}` | Sechs geprüfte Git-Verben |
