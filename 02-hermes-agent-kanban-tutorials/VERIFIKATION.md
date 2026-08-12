# Verifikationsprotokoll

Was für diese Tutorials **real ausgeführt** wurde, was dabei herauskam, und was
ich **nicht** verifizieren konnte. Diese Liste ist Teil des Ergebnisses: sie
sagt dir, welchen Aussagen du ohne Nachprüfen trauen kannst und welchen nicht.

## Testumgebung

| | |
|---|---|
| Hermes Agent | v0.20.0 (2026.8.3), Installationsmethode `git` |
| Installationsort | `/Users/<user>/.hermes/hermes-agent` |
| Python | 3.11.15, OpenAI SDK 2.24.0 |
| Betriebssystem | macOS, Darwin 25.5.0 |
| Modell der Worker | `deepseek/deepseek-v4-flash-0731` über OpenRouter (aus der Root-Konfiguration übernommen) |
| Boards | `kanban-story-1` … `kanban-story-11`, je Story ein eigenes |
| Datum der Durchführung | 2026-08-10 (Stories 1–9), 2026-08-11 (Story 10: erster Lauf 07:58–08:56, **zweiter Lauf 10:08–10:56**; Story 11: 15:16 ff.) |
| Python für Story 11 | `python3` aus dem System, `kb_lint.py` und `kb_git.py` benutzen **nur** die Standardbibliothek |
| `jq` | 1.x, `/usr/bin/jq` |
| Dispatcher | Gateway lief (launchd, PID 12441 bzw. 14774), zusätzlich `pump.sh` je Board |

Als Doku-Quelle diente die Markdown-Quelle im lokalen Git-Checkout — sie passt
exakt zur installierten Version:
`~/.hermes/hermes-agent/website/docs/user-guide/features/kanban-tutorial.md`
und `…/kanban.md`, dazu `hermes_cli/kanban_db.py`, `hermes_cli/kanban.py`,
`hermes_cli/kanban_swarm.py` und `tools/kanban_tools.py`.

---

## Zusammenfassung je Story

| Story | Status |
|---|---|
| **1 — Solo Dev**: Dependency-Kette, Handoff | ✅ real ausgeführt, 3 Runs, alle `completed` |
| **2 — Fleet Farming**: 12 Tasks parallel auf 3 Profile | ✅ real ausgeführt, 12 Runs, alle `completed` |
| **3 — Role Pipeline**: Block, `unblock`, zweiter Run, Reviewer | ✅ komplett, 4 Runs (1× `blocked`, 3× `completed`), Reviewer-Urteil APPROVED |
| **4a — Circuit Breaker** → `gave_up` | ✅ real ausgelöst, tokenfrei |
| **4a — Respawn-Sperre** | ✅ real ausgelöst, tokenfrei |
| **4b — Crash Recovery** via `kill -9` | ✅ real ausgelöst, Run 1 `crashed`, Run 2 `completed` |
| **5 — Tenant Fleet**: 6 Mandanten, 1 Profil, Cron-Enumerator | ✅ komplett, 5× `completed` + 1× `blocked` (Fehlerisolation) |
| **6 — Research Triage**: Fan-out, Block, Fan-in | ✅ komplett, 8 Runs auf 7 Karten |
| **7 — Scheduled Briefing**: zwei Ausgaben auf einem Vault | ✅ komplett, 6 Runs |
| **8 — Digital Twin**: zwei Zyklen, Eskalation an `legal` | ✅ komplett, Eskalation vom Worker selbst angelegt |
| **9 — Worktree Pipeline**: zwei parallele Worktrees, Fan-in | ✅ komplett, Worktrees real angelegt |
| **10 — Triage Pipeline**: Selbst-Fan-out, Rubrik, menschliches Tor | ✅ **zweimal** komplett durchgespielt. Lauf 1: 21 Karten / 23 Runs, beide Pfade (`build` und `video`) bis zum Deliverable, Tor mit `approve` **und** `modify`. Lauf 2 (mit den ausgelieferten, nachgeschärften Artefakten): 19 Karten / 21 Runs, nur `video` (beide Tore `approve`), dafür die Nachschärfung gegen ungeplante Karten nachgemessen |
| **11 — LLM Wiki**: Vertrag + deterministischer Linter, zwei Tore, Branch je Ingest | ✅ Bausteine vollständig gemessen (Linter, Git-Helfer, beide Tore, Schleifenerkennung); der Flottenlauf ist im Abschnitt „Story 11 — die Pipeline als Ganzes" protokolliert |

## Was ich **nicht** verifiziert habe

| Bereich | Warum |
|---|---|
| Story 11: die Tore über **Telegram** (wie im Original) | keine Anbindung konfiguriert. Beide Tore laufen hier über `block`/`unblock` auf dem Board, und das ist real durchgespielt. |
| Story 11: **fünf verschiedene Modelle** je Rolle (Grok / Nemotron / MiniMax, wie im Original) | alle fünf Profile liefen auf dem Root-Modell. Der Mechanismus (`--model`/`--provider` je Karte bzw. `hermes -p … config set model.default`) ist nur aus dem Hilfetext belegt. |
| Story 11: die **Kostenaussage** des Originals (~95 Cent je Ingest über OpenRouter mit MiniMax) | anderes Modell, keine Kostentelemetrie ausgewertet |
| Story 11: `workspace/wiki/` als **Obsidian-Vault** geöffnet | die `[[slug]]`-Syntax ist Obsidian-kompatibel, aber nicht in Obsidian geprüft |
| Story 11: der Cron-Sweep über einen **echten Zeitplan** | `install-cron.sh` und die Übersprung-Bedingungen in `kb-sweep-tick.sh` sind geprüft; ein Lauf, den launchd zur geplanten Zeit auslöst, nicht |
| `hermes kanban specify` | Auxiliary-Modell nicht angefasst — würde die Root-Konfiguration berühren |
| `hermes kanban decompose` | dito. Die Aussage „der Decomposer routet über die Profilbeschreibung" ist aus dem Quellcode belegt, **nicht** durch einen Lauf |
| Spalte **Review** und die Skill `sdlc-review` | kein SDLC-Ablauf durchgespielt |
| Gateway-Benachrichtigungen (Telegram / Slack / Discord) | keine Anbindung konfiguriert |
| Story 10: das Tor **über Telegram** (wie im Original) | dito — keine Anbindung. Das Tor läuft hier über `block`/`unblock` auf dem Board, und das ist real durchgespielt. |
| Story 10: `--model`/`--provider` je Karte (zwei Scouts, zwei Modelle) | nur Hilfetext gelesen; alle sieben Profile liefen auf dem Root-Modell |
| Story 10: `cost_gate_usd` / Kostenbericht des Originals | nicht nachgebaut — setzt Kostenspalten in der Telemetrie voraus |
| Story 10: ob die **Prosa-Regel** „do NOT create cards yourself" in den SOULs allein trägt | Sie wurde gemeinsam mit dem `idempotency_key` eingeführt, und Lauf 2 legte keine ungeplanten Karten an. Welcher der beiden Griffe das bewirkt hat, ist damit **nicht** getrennt — nur der `idempotency_key` ist strukturell wirksam. |
| `hermes kanban notify-subscribe` | nur Hilfetext gelesen |
| Desktop-App-Oberfläche | aus dem Quellcode belegt, **nicht** klickend geprüft |
| `--goal` / `--goal-max-turns` | nur Hilfetext gelesen |
| `--project <slug>` als Worktree-Anker | nur Hilfetext gelesen; `worktree:<repo>` dagegen real getestet |
| `hermes kanban gc` / `repair` | nicht ausgeführt |
| `hermes profile install` von einer **Git-URL** | nur aus einem **lokalen Verzeichnis** getestet |
| Story 5, Schritt 5.5: der **Reparaturpfad** (`activity.csv` anlegen → `unblock` → erneuter Run) | Der Block war real; die Reparatur danach ist nicht ausgeführt worden. `unblock` selbst ist in Story 3, 4a und 6 verifiziert. |

---

## Belegte Aussagen

### 1. `hermes profile create` allein macht ein Profil nicht dispatchbar

**Nachgewiesen.** Ein Profil zählt für Kanban nur als vorhandener Assignee,
wenn `~/.hermes/profiles/<name>/config.yaml` existiert
(`kanban_db.list_profiles_on_disk`). `hermes profile create` legt diese Datei
nicht an. Folge: `hermes profile list` zeigt das Profil, `hermes kanban
assignees` nicht — und Karten bleiben ohne Fehlermeldung auf `ready` liegen.

```console
$ hermes profile create backend-dev --no-skills --description "…"
Profile 'backend-dev' created at …/.hermes/profiles/backend-dev

$ ls …/.hermes/profiles/backend-dev/
.env  .no-bundled-skills  SOUL.md  profile.yaml  cron/ home/ logs/ …
                                  ← keine config.yaml

$ hermes kanban assignees
NAME         ON DISK   COUNTS
default      yes       (idle)
developer    yes       (idle)
summarizer   yes       (idle)        ← backend-dev fehlt

$ hermes -p backend-dev config set model.default "deepseek/deepseek-v4-flash-0731"
✓ Set model.default = … in …/.hermes/profiles/backend-dev/config.yaml

$ hermes kanban assignees
backend-dev  yes       (idle)        ← jetzt da
```

Jedes `setup.sh` in diesem Repository setzt deshalb alle **vier**
Modell-Schlüssel und prüft danach `ON DISK = yes` für jedes Profil, sonst
bricht es ab.

### 2. Ein laufendes Gateway greift auf jedes Board zu

**Zweimal beobachtet.** Einmal übernahm der Gateway-Dispatcher die erste Karte
sofort nach dem Anlegen auf einem gerade erst erzeugten Board, einmal ließ er
eine Wegwerf-Aufgabe komplett durchlaufen, obwohl sie nur trocken geprüft
werden sollte. `hermes pause` / `hermes resume` sind der zuverlässige Weg,
das zu unterbinden; unassignierte Karten werden ebenfalls nie gestartet.

### 3. Die Respawn-Sperre steht in keiner Dokumentation

**Real ausgelöst.** Sieht ein Fehlertext nach Auth oder Quota aus
(`_RESPAWN_BLOCKER_RE` in `kanban_db.py`), versucht der Dispatcher es gar
nicht erneut. Die Karte bleibt auf `ready` und sieht aus wie „wartet" — und
`hermes kanban diagnostics` **meldet sie nicht**. Real gemessen mit
`dir:/Volumes/deploy-share/staging` (Errno 13, „Permission denied"):

```console
Events: created → claimed → spawn_failed → respawn_guarded → respawn_guarded
Task-Status: ready
```

Zum Vergleich derselbe Aufbau mit `dir:/dev/null/staging` (Errno 20, „Not a
directory" — kein Auth-Muster), `--max-retries 3`:

```console
  1  spawn_failed  deploy-bot   0s  2026-08-10 10:47
  2  spawn_failed  deploy-bot   0s  2026-08-10 10:47
  3  gave_up       deploy-bot   0s  2026-08-10 10:47
Task-Status: blocked
```

### 4. `HERMES_TENANT` trennt Daten nicht von selbst

`hermes_cli/kanban_db.py:9121` setzt `env["HERMES_TENANT"] = task.tenant`. Die
Formulierung der Designspezifikation („profile memory: account-17-specific,
namespaced by tenant") beschreibt **keine Kernel-Funktion**. Die offizielle
Dokumentation formuliert es korrekt: „Workers receive `$HERMES_TENANT` and
namespace their memory writes by prefix" — also eine Konvention, die der
Task-Body oder eine Skill durchsetzen muss. Story 5 macht das über die Skill
`tenant-journal` explizit.

### 5. Das Board hat acht Spalten

```python
VALID_STATUSES = {"triage", "todo", "scheduled", "ready", "running",
                  "blocked", "review", "done", "archived"}

BOARD_COLUMNS = ["triage", "todo", "scheduled", "ready", "running",
                 "blocked", "review", "done"]
```

`scheduled` und `review` kommen zu den sechs Spalten der offiziellen
Tutorial-Grafik hinzu. `archived` ist ein Status, aber keine Spalte.

### 6. `runs` und `show` nummerieren Versuche verschieden

`hermes kanban runs` zählt die Versuche **einer Karte** ab 1, `hermes kanban
show` zeigt die board-globale `run_id`. Im Test: derselbe Versuch als „1" bei
`runs` und „#5" bei `show`.

---

## Neu verifizierte Funktionen (Probeläufe)

### Worktree-Workspaces ✅

```console
$ hermes kanban create "…" --workspace "worktree:/abs/pfad/repo" --branch wt/probe-1
$ hermes kanban claim <id>
Workspace: /abs/pfad/repo/.worktrees/t_34933aa5

$ git -C /abs/pfad/repo worktree list
…/repo                        665bbfa [main]
…/repo/.worktrees/t_34933aa5  665bbfa [wt/probe-1]
```

- Der Worktree landet **unter dem Repo** in `.worktrees/<task-id>`.
- **Er überlebt `kanban_complete`** — in Story 9 stand der Worktree des
  Frontend-Entwicklers nach dessen Abschluss noch, mit dessen Commit darin.
  Der Reviewer kann also sowohl `git diff main..wt/…` als auch den
  Arbeitsbaum selbst benutzen.
- Bare `--workspace worktree` ohne Pfad scheitert, wenn das Board keinen
  `default_workdir` hat:
  `task … has workspace_kind=worktree but no workspace_path, and board '…'
  has no default_workdir set.`
- Der Pfad muss ein Git-Repo(-Root) sein:
  `worktree path '…' is not inside a git repo and does not point at a git repo root`

### Board-`--default-workdir` ⚠ nur für Worktrees

Füllt **nur** die Worktree-Auflösung. Karten ohne `--workspace` bleiben
`scratch` — `--workspace dir:<abs>` bleibt nötig.

### `hermes kanban swarm` ✅

```console
$ hermes kanban swarm "<Ziel>" --worker P:Titel … --verifier P --synthesizer P --json
{"root_id": …, "worker_ids": [4], "verifier_id": …, "synthesizer_id": …}
```

Erzeugt Wurzelkarte (sofort `done`, dient als schwarzes Brett, trägt
`[swarm:blackboard]`-Kommentar mit der Topologie), N Worker auf `ready`,
Verifier auf `todo` mit allen Workern als Eltern, Synthesizer auf `todo`.
In jeden Body wird ein `## Swarm protocol`-Block injiziert.
**Grenze:** kennt kein `--workspace`, läuft immer auf `scratch`.
Nur die **Struktur** wurde geprüft, kein Swarm-Durchlauf ausgeführt.

### Cron → Kanban, tokenfrei ✅

```console
$ hermes cron create "every 1h" --name X --script s.sh --no-agent --deliver local
$ hermes cron run <job-id>
  Ran now: succeeded.
```

- Skripte müssen unter `~/.hermes/scripts/` liegen.
- `--no-agent`: kein LLM, das Skript *ist* der Job → keine Tokenkosten.
- Das Skript darf `hermes kanban create …` aufrufen; die Karten erscheinen
  sofort auf dem Board.
- Ausgaben landen unter `~/.hermes/cron/output/<job-id>/`, Jobdefinitionen in
  `~/.hermes/cron/jobs.json` (Struktur: `{"jobs": [...]}`).
- `hermes pause` hält Cron- **und** Kanban-Dispatch an.
- **Beide `install-cron.sh` wurden vollständig ausgeführt** — Story 5
  (`story5-fleet-tick`, `every 4h`) und Story 7 (`story7-briefing`,
  `0 9 * * 1-5`): anlegen, `hermes cron run` sofort feuern, Ausgabe unter
  `~/.hermes/cron/output/<job-id>/` prüfen, `--remove`. Danach jeweils
  `hermes cron list` → „No scheduled jobs" und `~/.hermes/scripts/` leer.
  **Auf dem Rechner ist kein Cron-Job aus diesem Tutorial zurückgeblieben.**

### `--idempotency-key` über mehrere Ticks ✅

Zweiter und dritter Aufruf desselben Enumerators am selben Tag legten nichts
Neues an; `create` gab jeweils die vorhandene ID zurück. Kartenzahl blieb 6.

### Fan-in über mehrere `--parent` ✅

Eine Karte mit vier `--parent`-Angaben blieb auf `todo`, bis **alle vier**
Eltern `done` waren — auch über einen `blocked`-Elternteil hinweg, der erst
nach `comment` + `unblock` durchlief.

### `schedule` / `unblock` ✅

`hermes kanban schedule <id> "<grund>"` → Status `scheduled`; die Karte taucht
in `dispatch --dry-run` **nicht** auf. `unblock` holt sie nach `ready` zurück.

### Profil-lokale Skills ✅

`~/.hermes/profiles/<p>/skills/<skill>/SKILL.md` (YAML-Frontmatter: `name`,
`description`, `version`) erscheint in `hermes -p <p> skills list` als
`local / local / enabled`. In Story 5 real installiert und im Worker wirksam
(die Journal-Konvention wurde eingehalten).

### Profil-Distributionen aus einem lokalen Verzeichnis ✅

`hermes profile install <dir> -y` mit `distribution.yaml` + `SOUL.md` +
`config.yaml` legt das Profil an; weil es eine `config.yaml` mitbringt, ist es
**sofort** dispatchbar. Die `description` aus `distribution.yaml` landet
allerdings **nicht** in `profile.yaml` — `hermes profile describe` bleibt
nötig. (Nur aus einem lokalen Verzeichnis getestet, nicht von einer Git-URL.)

### `--initial-status blocked` ist **kein** haltendes Tor ✅ (Story 10)

**Real ausgelöst, zweimal.** Eine Karte, die mit `--initial-status blocked` und
einem noch offenen Elternteil angelegt wurde, hat der Dispatcher befördert und
gestartet, sobald der Elternteil fertig war:

```console
Events (7):
  [07:38] created {'status': 'blocked', 'parents': ['t_c0347293'], …}
  [07:38] promoted                      ← Dispatcher holt sie hoch
  [07:38] [run 2] claimed
  [07:38] [run 2] spawned
  [07:40] [run 2] completed
```

Der Grund steht in `kanban_db.recompute_ready`: die Beförderungsschleife liest
`WHERE status IN ('todo', 'blocked')` und lässt nur die Karten in Ruhe, für die
`_has_sticky_block()` wahr ist — also die, deren jüngstes Ereignis vom Typ
`blocked` (nicht `unblocked`) ist. `--initial-status blocked` setzt **nur die
Spalte** und erzeugt kein solches Ereignis. Der Docstring benennt die Lücke
selbst: „Returns `False` when there is no such event at all … preserves the
pre-#28712 auto-recover semantics for that path."

Mit `hermes kanban block` bzw. `kanban_block()` entsteht das Ereignis, und die
Karte hält über beliebig viele Ticks:

```console
  [07:45] [run 4] blocked {'reason': '…', 'kind': 'needs_input', 'recurrences': 1}

$ hermes kanban --board … dispatch --dry-run
Promoted:     0
Spawned:      0
```

| Weg | `blocked`-Ereignis? | hält bei fertigen Eltern? |
|---|---|---|
| `--initial-status blocked` | nein | **nein** |
| `hermes kanban block <id> "<grund>"` | ja | ja |
| `kanban_block(reason=…)` im Worker | ja | ja |
| Circuit Breaker | nein (`gave_up`) | nein (absichtlich) |

⚠ **Folge für alle Stories:** Der Hinweis in README und Nachschlagewerk, eine
Karte lasse sich mit `--initial-status blocked` „geparkt anlegen", stimmt nur,
solange ein Elternteil offen ist. Als Wartepunkt für einen Menschen ist die
Option falsch. Die betroffenen Stellen sind korrigiert.

### `hermes kanban block` nimmt den Grund **positional** ✅ (Story 10)

**Real ausgelöst.** Die in README, Nachschlagewerk und den Stories 1, 3 und 7
dokumentierte Form `--reason` gibt es bei `block` in v0.20.0 nicht:

```console
$ hermes kanban block <id> --reason "Freigabe noetig"
hermes: error: unrecognized arguments: --reason Freigabe noetig

$ hermes kanban block <id> --kind needs_input "Freigabe noetig"
hermes: error: unrecognized arguments: Freigabe noetig

$ hermes kanban block --kind needs_input <id> "Freigabe noetig"
Blocked t_2be9e920: Freigabe noetig
```

`--kind` muss **vor** die Kartennummer (der Grund ist ein `nargs='*'`-Positional).
Zulässige Werte: `capability`, `dependency`, `needs_input`, `transient`.
Bei `unblock` gibt es `--reason` dagegen sehr wohl — dort legt es den Text als
Kommentar an und hebt die Karte in einem Schritt:

```console
$ hermes kanban unblock <id> --reason "approve"
Unblocked t_73841e64: approve
```

Alle falschen Vorkommen im Repository sind korrigiert.

### Worker legt eine Karte mit dauerhaftem `dir:`-Workspace an ✅ (Story 10)

Über Story 8 hinaus geprüft: ein Worker legte per `kanban_create` eine Kette
aus zwei Karten an — die erste **ohne** Elternteil (landet sofort `ready`), die
zweite mit der ersten als Elternteil — beide mit
`workspace_kind="dir"` auf **denselben absoluten** Pfad. Beide liefen, und die
zweite Stufe fand die Dateien der ersten vor:

```console
{"id": "t_344a6c6f", "workspace_kind": "dir",
 "workspace_path": "…/spike-ws/work/builds/spike",
 "created_by": "developer", "parents": []}
{"id": "t_64be753a", "workspace_path": "…/spike-ws/work/builds/spike",
 "created_by": "developer", "parents": ["t_344a6c6f"]}
```

Relative Pfade werden abgewiesen; der Worker muss den absoluten Pfad aus
`$HERMES_KANBAN_WORKSPACE` bilden.

### `hermes kanban claim` als Workspace-Probe ✅

`claim <id>` löst den Workspace auf und **druckt den Pfad**, ohne einen Worker
zu starten — der günstigste Weg, eine Workspace-Konfiguration zu prüfen.
Kombiniert mit einer Karte ohne `--assignee` (die der Dispatcher nie startet)
lässt sich damit gefahrlos experimentieren, auch bei laufendem Gateway.

### `kanban_create` aus einem Worker heraus ✅

In Story 8 hat der `inbox-triage`-Worker während seines Laufs selbst eine
Karte für das Profil `legal` angelegt, mit `workspace_kind='dir'` und
`parents=[<eigene Karte>]`, und danach weitergearbeitet. Der Dispatcher hat
die neue Karte im nächsten Tick gestartet.

---

### Story 10 — die Pipeline als Ganzes ✅

**Vollständig durchgespielt am 2026-08-11**, Board `kanban-story-10`, sieben
Profile, Modell `deepseek/deepseek-v4-flash-0731`. Das Folgende ist **Lauf 1**
(07:58–08:56); ein zweiter Lauf am selben Tag steht weiter unten.

| | |
|---|---|
| Karten | 21 — **3 von Hand**, 16 vom Orchestrator, 2 ungeplant von einem Worker |
| Runs | 23, davon 2 mit Outcome `blocked` (die beiden Tore) |
| Dauer | 07:58 → 08:56, davon ~7 min Wartezeit auf die menschliche Entscheidung |
| Parallelität | 6 Recherche-Worker gleichzeitig `running` |

Belegt wurden dabei:

- **Selbst gebauter Fan-out.** Der Orchestrator legte per `kanban_create` je
  Item 3 Bahn-Karten + 1 Route-Karte an, mit `workspace_kind="dir"` und
  absolutem Pfad; die Route-Karte mit allen drei Bahnen als `parents`.
  `created_by` weist sie eindeutig dem Profil zu:
  `triage-orchestrator: 16   triage-producer: 2   user: 3`.
- **Dedup über Quellgrenzen.** 4 Kandidaten aus zwei Scout-Berichten → 2 Items;
  in einem späteren Lauf 5 → 3.
- **Rubrik mit Schwelle.** Scores 82/84/26 bei Schwelle 65; das Item mit 26
  bekam `status: archiviert` und **keine einzige Karte**. `score_breakdown`
  steht in der Item-Datei und in den Completion-Metadaten.
- **Das Tor.** Beide Vorschlagskarten blockierten sich selbst mit
  `kanban_block(kind="needs_input")`, hielten über mehrere Dispatcher-Ticks und
  liefen nach `unblock --reason` als **zweiter Run derselben Karte** weiter.
- **Beide Verben real.** `approve` → Video-Kette; `modify` → der Mensch
  korrigierte die Route von `video` auf `build`, der Orchestrator schrieb
  `pfad: build`, ließ den Klassifikatorwert stehen und legte die Bau-Kette an.
- **Dauerhafter Workspace nach dem Tor.** `work/builds/<slug>/` bzw.
  `work/videos/<slug>/`; die Folgestufen fanden die Dateien ihrer Vorgänger vor.
  Erste Kettenkarte ohne `parents` → sofort `ready`.
- **Scope-Rails.** `konfigpfade.py`, 197 Zeilen gegen ein Limit von 200, nur
  Standardbibliothek. Der Tester prüfte jede Rail einzeln nach (alle PASS) und
  führte das Werkzeug wirklich aus.

⚠ **Ein echter Fehler im Lauf, nicht wegretuschiert.** Der `folien`-Worker legte
zwei Karten nach, die niemand geplant hatte (`Fulfill skript` doppelt,
`Fulfill faktencheck` zusätzlich). Die beiden `skript`-Karten liefen
gleichzeitig im selben Verzeichnis. Ursache: `auftrag.md` beschreibt die Kette,
und der Worker hat `kanban_create`. Die Artefakte sind nachgeschärft
(`idempotency_key` je Fulfill-Karte + explizites Verbot in den SOULs) — **diese
Korrektur ist in Lauf 2 nachgemessen**, siehe unten.

⚠ **Ein Konstruktionsfehler, der erst durch einen Fehlversuch sichtbar wurde.**
In den ersten beiden Läufen filterte der Scout den schwachen Kandidaten selbst
weg, wodurch die Rubrik-Schwelle nie wirksam wurde — unsichtbar auf dem Board.
Nach Schärfung der Scout-`SOUL.md` („do NOT decide whether a candidate
MATTERS") erschien das Item und wurde mit 26 Punkten korrekt archiviert. Der
Vorgang steht in Story 10, Schritt 10.8.

Der Lauf liegt vollständig unter `Story 10 - Triage Pipeline/beispiel-lauf/`
(23 Dateien). `workspace/` ist bei Abgabe zurückgesetzt und deckungsgleich mit
`seed/`.

### Story 10 — zweiter vollständiger Lauf ✅ (2026-08-11, 10:08–10:56)

**Von Null durchgespielt** (`setup.sh` auf ein leeres Board, keine `triage-`
Profile vorhanden), mit den **ausgelieferten, nachgeschärften Artefakten**.
Zweck: die zwei Aussagen nachmessen, die Lauf 1 offen ließ.

| | |
|---|---|
| Karten | 19 — **3 von Hand**, 16 vom Orchestrator, **0 ungeplant** |
| Runs | 21 — 17 Karten mit einem Run, die zwei Tor-Karten mit je zwei. Outcomes: 19 `completed`, 2 `blocked` |
| Fehlläufe | keine — `failed` / `gave_up` / `crashed`: 0 |
| Dauer | 48 min, davon ~3 min Wartezeit auf die menschliche Entscheidung |
| Parallelität | 6 Recherche-Worker gleichzeitig `running` |
| Menschliche Entscheidungen | 2 × `approve` |

**1. Die Nachschärfung gegen ungeplante Karten greift.**

```console
$ hermes kanban --board kanban-story-10 list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'
triage-orchestrator: 16   user: 3
```

Kein `triage-producer`-Eintrag (Lauf 1: `triage-producer: 2`). `faktencheck.md`
entstand als **Datei** innerhalb der `skript`-Stufe — so wie
`pipeline/specs/video.md` es verlangt —, ohne dass eine Karte dafür angelegt
wurde. Die Karte, die in Lauf 1 entglitt
(`Fulfill folien: subagenten-werkzeugflut`), lief mit und legte nichts an.

⚠ Ein Lauf, keine Beweisführung — der ursprüngliche Fehler war selbst nicht
deterministisch. Siehe den Eintrag in „Was ich **nicht** verifiziert habe".

**2. `pump.sh` endet am Tor von selbst** — in Lauf 1 nur mit zwei blockierten
Wegwerf-Karten geprobt, hier aus der Pipeline selbst:

```console
Nichts mehr offen — Pumpe beendet.
…
⊘ t_71dcd1d9  blocked   triage-orchestrator  Vorschlag + Tor: config-pfade-mehrdeutig
⊘ t_031f477b  blocked   triage-orchestrator  Vorschlag + Tor: subagenten-werkzeugflut

2 Karte(n) warten auf einen Menschen:
```

**3. Der sticky Block, unabhängig noch einmal ausgelöst.** Beide Eltern der
Tor-Karte standen auf `done`:

```console
$ hermes kanban --board kanban-story-10 show t_031f477b --json \
    | jq -r '[.events[]|select(.kind=="blocked")]|last|.payload.kind'
needs_input

$ hermes kanban --board kanban-story-10 dispatch --dry-run
Promoted:     0
Spawned:      0
```

**4. Beide** Tor-Karten lasen die Antwort im zweiten Run (Lauf 1 belegte das für
eine Karte je Verb, hier für beide dasselbe Verb):

```console
t_71dcd1d9  blocked → completed: approve config-pfade-mehrdeutig: Umsetzungskette angelegt (2 Karten) …
t_031f477b  blocked → completed: approve subagenten-werkzeugflut: Umsetzungskette angelegt (2 Karten: …) …
```

**5. Die Rubrik-Schwelle wurde zweimal wirksam, mit einem echten Grenzfall.**

```
subagenten-werkzeugflut         87   → Fan-out
config-pfade-mehrdeutig         81   → Fan-out
subagenten-allow-list-unbekannt 63   → archiviert   ← 2 Punkte unter der Schwelle
commit-emoji                    35   → archiviert
```

Der Scout meldete `commit-emoji` (3 Kandidaten je Quelle statt 2) und die Rubrik
sortierte es aus — die Arbeitsteilung aus Schritt 10.8 hat also gehalten. Neu
gegenüber Lauf 1, wo der nächste Kandidat bei 26 lag: **63 von 100** bei
`loesbar_oder_erklaerbar: 18/25`. Ein Item, das gut erklärbar wäre und von dem
trotzdem kein Mensch erfährt. Das ist der Fallstrick „zu hoch, und du erfährst
nie von den Grenzfällen" mit einem Messwert dahinter.

**Nicht deterministisch, und genau das ist der Punkt.** Dieselben Quellen ergaben
in Lauf 2 andere Scores (87/81 statt 85/76), einen anderen Slug
(`config-pfade-mehrdeutig` statt `konfigurationspfade-ambig`) und einen anderen
Klassifikatorwert (`verwirrend` statt `schlecht_erklaert`) — der über
`route.tabelle` aber auf denselben Pfad abbildet. Das belegt den im Tutorial
benannten Preis des Tauschs „Prosa gegen Python" mit zwei Messungen statt einer.

⚠ **Der `build`-Pfad lief in Lauf 2 nicht.** Er kam über die Route nicht vor (wie
in Lauf 1) und wurde nicht per `modify` erzwungen, weil beide Tore `approve`
bekamen. `triage-builder` und `triage-tester` liefen also nicht — für den
`build`-Pfad bleibt Lauf 1 der Beleg.

⚠ **Eine Inkonsistenz, nicht wegretuschiert.** Die beiden `Prep outline`-Worker
schrieben ihr Ergebnis an verschiedene Stellen:
`vault/items/<slug>-outline.md` (wie im Tutorial) bzw.
`work/videos/<slug>/outline.md`. Beide Ketten liefen trotzdem durch, weil der
Orchestrator den Vorschlag ohnehin in `auftrag.md` kopiert. Der Ablageort der
Prep-Stufe ist in der Skill `triage-pipeline` offenbar nicht eindeutig
festgelegt.

Keine Seed-Datei wurde überschrieben — `./reset-workspace.sh --diff` zeigte
ausschließlich `Only in …/workspace`, kein `Files … differ`. Der Lauf liegt
vollständig unter `Story 10 - Triage Pipeline/beispiel-lauf-2/` (18 Artefakte
plus `README.md` als Protokoll).

### Story 10 — Cron-Anbindung ✅

`install-cron.sh` vollständig ausgeführt: anlegen (`0 7 * * *`, `--no-agent`,
Wrapper unter `~/.hermes/scripts/`), **zweimal** `hermes cron run` sofort
gefeuert, `--remove`.

```console
$ hermes cron run 1e8bc6bafc34
  Ran now: succeeded.
$ hermes kanban --board kanban-story-10 list --json | jq 'length'
3            ← nach dem ERSTEN Tick
3            ← nach dem ZWEITEN Tick am selben Tag (--idempotency-key)
```

Ausgaben unter `~/.hermes/cron/output/<job-id>/`. Danach `hermes cron list` →
„No scheduled jobs", `~/.hermes/scripts/` leer. **Auf dem Rechner ist kein
Cron-Job aus diesem Tutorial zurückgeblieben.**

⚠ `hermes cron create` hat in v0.20.0 **kein** `--profile`. Der Runbook des
Originals (`docs/07-runbook.md`) empfiehlt, die Scout-Jobs im Cron-Store des
Gateway-Profils zu registrieren — dieser Weg ist hier **nicht** verifiziert.
Story 10 benutzt stattdessen den in Story 5 und 7 belegten Weg: Root-Store,
Wrapper unter `~/.hermes/scripts/`, `--no-agent`, das Skript ruft
`hermes kanban create`.

### Story 10 — `teardown.sh` in allen drei Stufen ✅

1. `./teardown.sh --files-only -y` → Board `kanban-story-10` und alle sieben
   `triage-*`-Profile blieben nachweislich stehen; `workspace/` danach
   deckungsgleich mit `seed/`.
2. `./teardown.sh -y` → Board gelöscht, alle sieben Profile gelöscht, die
   sieben Wrapper unter `~/.local/bin/` entfernt, `~/.hermes/profiles/` ohne
   `triage-*`.
3. `./setup.sh` von Null → Board, sieben Profile, `ON DISK = yes`, und die
   Skills wieder korrekt unter `skills/<name>/SKILL.md`.

⚠ **Das Board kam nach dem Löschen sofort wieder** — als leeres Board mit dem
aus dem Slug abgeleiteten Namen „Kanban Story 10" statt „Story 10 - Triage
Pipeline":

```console
$ hermes kanban boards rm kanban-story-10 --delete
Board 'kanban-story-10' deleted.
$ hermes kanban boards list
    kanban-story-10           Kanban Story 10               (empty)   ← sofort wieder da
```

Das ist die in Story 6 beschriebene Desktop-App-Wirkung, hier zum ersten Mal
direkt reproduziert: die App pollt das angezeigte Board weiter und legt es neu
an. **Vor dem endgültigen Löschen die Desktop-App schließen** oder im
Board-Switcher auf `Default` schalten. Auf den Profilen und Dateien hat das
keine Wirkung — die blieben gelöscht.

✅ **Die empfohlene Gegenmaßnahme ist inzwischen belegt.** Beim Rückbau nach
Lauf 2 war kein Desktop-Prozess aktiv und das aktive Board stand bereits auf
`default`. Unter diesen Bedingungen kam das Board **nicht** zurück — 90 s nach
`./teardown.sh -y` nachgeprüft:

```console
$ hermes kanban boards list
●   default    Default    (empty)          ← kanban-story-10 bleibt weg

$ hermes profile list | grep -c triage
0
$ hermes cron list
No scheduled jobs.
```

Damit ist die Aussage präziser als vorher: es ist **nicht** das Löschen selbst,
das das Board zurückbringt, sondern ein Client, der es weiterhin als aktives
Board pollt. Reste-Suche unter `~/.hermes` und `~/.local/bin` danach ohne
Treffer aus dieser Story.

### Profil-lokale Skills pro Profil ✅ (Story 10)

Über Story 5 hinaus geprüft: unterschiedliche Skills für unterschiedliche
Profile derselben Story (`skills/<profil>/<skill>/`).

```console
$ hermes -p triage-orchestrator skills list   → triage-pipeline  local  enabled
$ hermes -p triage-scout        skills list   → scout-report     local  enabled
$ hermes -p triage-researcher   skills list   → 0 local
```

⚠ **Fallstrick in den setup.sh-Skripten**, gefunden und behoben: `cp -R "$skill"
"$ziel/"` mit einem Glob `*/` übergibt einen Pfad **mit** Schrägstrich am Ende,
und `cp -R dir/ ziel/` kopiert auf macOS den *Inhalt* von `dir` nach `ziel` —
die `SKILL.md` landete direkt in `skills/` statt in `skills/<name>/`. Bei
**einer** Skill je Profil fällt das nicht auf (Hermes liest den Namen aus dem
Frontmatter, nicht aus dem Verzeichnis); bei **zwei** überschreiben sie sich.
Korrigiert zu `cp -R "${skill%/}" …` in Story 10 **und** Story 5.

### `teardown.sh` in allen drei Stufen ✅

⚠ **Nachtrag:** `Story 5 - Tenant Fleet/setup.sh` wurde nach dieser
Verifikation geändert — `cp -R "$skill"` → `cp -R "${skill%/}"` (siehe den
Abschnitt zu den profil-lokalen Skills bei Story 10). Bei **einer** Skill je
Profil, wie Story 5 sie hat, ist die Änderung verhaltensneutral; sie wurde
vorgenommen, damit das Muster auch mit mehreren Skills trägt.

An Story 5 durchgeführt, in dieser Reihenfolge:

1. `./teardown.sh --files-only -y` → Board `kanban-story-5` und Profil
   `account-manager` blieben nachweislich stehen (`boards list`, `assignees`),
   `workspace/` war danach deckungsgleich mit `seed/`
   (`./reset-workspace.sh --diff` ohne Ausgabe).
2. `./teardown.sh -y` → Board weg, Profil weg, Wrapper in `~/.local/bin/` weg,
   `~/.hermes/kanban/boards/` ohne `kanban-story-5`.
3. `./setup.sh` von Null → Board und Profil wieder da, Skill `tenant-journal`
   wieder installiert, `ON DISK = yes`.

⚠ **Folge davon:** das Board `kanban-story-5` ist bei Abgabe **leer**, während
`Story 5 - Tenant Fleet/workspace/` noch die Digests und Journale des echten
Laufs enthält (die habe ich nach dem Test zurückgelegt). Das ist kein Fehler,
sondern die Spur dieses Tests. Die Karten kommen mit
`./scripts/fleet-tick.sh && ./pump.sh` zurück.

### Sammelabschluss mit Handoff ist gesperrt ✅

```console
$ hermes kanban complete <a> <b> --summary "gleiche Zusammenfassung"
kanban: --summary / --metadata are per-task and can't be used with multiple ids
(would apply the same handoff to every task). Complete tasks one at a time, or
drop the flags for the bulk close.

$ hermes kanban complete <a> <b>
Completed t_c076ffe7
Completed t_186645c8
```

---

### Zwei Tore auf einer Karte: `block_loop_detected` ✅ (Story 11)

**Diese Messung entscheidet ein Design.** Sie wurde auf einem Wegwerf-Board
(`kanban-probe`) mit Karten **ohne Assignee** gemacht — kein Worker, keine
Tokens, wenige Sekunden.

**Fall A — zweiter Block mit derselben Block-Art:**

```console
$ ID=$(hermes kanban --board kanban-probe create "reblock-probe" --json | jq -r .id)
$ hermes kanban --board kanban-probe block --kind needs_input $ID "gate 1: ingest freigeben"
Blocked t_2795cbb8: gate 1: ingest freigeben
$ hermes kanban --board kanban-probe unblock $ID --reason "approve"
Unblocked t_2795cbb8: approve
$ hermes kanban --board kanban-probe block --kind needs_input $ID "gate 2: merge freigeben"
t_2795cbb8 → triage (unblock loop detected — needs a human decision): gate 2: merge freigeben
```

Status danach: **`triage`**, nicht `blocked`. Ereignisstrom:

```console
blocked              {"reason":"gate 1...","kind":"needs_input","recurrences":1,"source_status":"ready"}
unblocked            null
block_loop_detected  {"reason":"gate 2...","kind":"needs_input","recurrences":2,"limit":2,"source_status":"ready"}
```

**Fall B — zweiter Block mit einer anderen Block-Art:**

```console
$ hermes kanban --board kanban-probe block --kind capability $ID "gate 2: merge freigeben"
Blocked t_01fad84f: gate 2: merge freigeben

blocked  {"reason":"gate 2: merge freigeben","kind":"capability","recurrences":1,...}
```

Status: `blocked`. Der Zähler startet wieder bei 1, weil die Ursache eine andere
ist.

**Fall C — dritter Block mit einer schon benutzten Art:**

```console
needs_input → unblock → capability → unblock → capability   ⇒   triage
```

**Quelle, passend zur installierten Version:**

```python
# hermes_cli/kanban_db.py:134
BLOCK_RECURRENCE_LIMIT = 2

# hermes_cli/kanban_db.py:~5997
same_cause  = prev_kind == kind
recurrences = prev_recurrences + 1 if same_cause else 1
if recurrences >= BLOCK_RECURRENCE_LIMIT:
    #  -> status = 'triage', Ereignis block_loop_detected
```

`kanban_db.py:994` hält fest, dass der Zähler „only on successful completion"
zurückgesetzt wird. Es gibt **keinen** Konfigurationsschlüssel dafür:

```console
$ hermes config get kanban.block_loop_limit
Config key not set: kanban.block_loop_limit
$ hermes config get kanban.block_recurrence_limit
Config key not set: kanban.block_recurrence_limit
```

Dokumentiert ist das Verhalten in
`website/docs/user-guide/features/kanban.md:1105`.

**Folge für Story 11:** Die beiden Tore liegen auf **zwei Karten** mit zwei
Block-Arten (`needs_input` / `capability`). Das ist gegen den Zähler immun und
erlaubt jedem Tor eine Rückfrage.

### `hermes kanban show <id>` ohne `--json` bricht ab ⚠ **Fehler in v0.20.0**

**Reproduzierbar auf jedem Board, auch mit einer frisch angelegten Karte** —
geprüft auf `default`, `kanban-story-10` und `kanban-story-11`:

```console
$ hermes kanban show t_fe0e99ff
Task t_fe0e99ff: Triage: buendeln, dedup gegen die Wissensbasis, bewerten
  status:    running
  assignee:  kb-orchestrator
  ...
Traceback (most recent call last):
  File ".../hermes_cli/kanban.py", line 1766, in _cmd_show
    task, events, runs, graph=kb.task_graph_context(conn, task.id)
  File ".../hermes_cli/kanban_db.py", line 3696, in task_graph_context
    return task_graph_contexts(conn, [task_id])[task_id]
  File ".../hermes_cli/kanban_db.py", line 3669, in task_graph_contexts
    for row in conn.execute(
sqlite3.ProgrammingError: Cannot operate on a closed database.
```

Der Kopf der Karte wird gedruckt, dann stirbt es im **Diagnostics**-Block
(`kanban.py:1764–1766`): `task_graph_context` benutzt eine Verbindung, die schon
geschlossen ist. Kommentare, Events und Runs erscheinen deshalb **nie**.

Was funktioniert:

```console
$ hermes kanban show <id> --json | jq        # vollständig, inkl. events/comments/runs
$ hermes kanban runs <id>                    # Versuchshistorie
$ hermes kanban context <id>                 # was der Worker sieht
$ hermes kanban log <id> --tail N            # Worker-Log
```

⚠ **Das betrifft auch Story 10.** Deren Tutorial zeigt `Events (…)`-Blöcke, wie
`show` sie ausgeben *würde*. Auf dieser Installation liefert nur
`show --json` diese Information. Alle Skripte in diesem Repository benutzen
`show --json`.

### Story 11 — `kb_lint.py` als deterministischer Test ✅

Der einzige Test dieser Sammlung, der **ohne Modell** läuft und bei jeder
Wiederholung dasselbe Ergebnis liefert.

`seed/wiki/` enthält absichtlich sechs Defekte. Auf dem Ausgangszustand:

```console
$ python3 seed/bin/kb_lint.py seed/wiki --today 2026-08-11
kb_lint — seed/wiki  (7 Seiten, Bezugsdatum 2026-08-11)
==============================================================================

  ERROR   pages/cron-und-zeitplan.md:11   [abschnitt-reihenfolge] Reihenfolge ist
          ['Kurzfassung','Quellen','Details','Siehe auch'], erwartet
          ['Kurzfassung','Details','Quellen','Siehe auch'] (AGENTS.md 2.2)
  ERROR   pages/kanban-board.md:61        [toter-link] [[kanban-review-agent]] …
  ERROR   pages/memory-system.md:1        [frontmatter-key] 'updated' fehlt …
  ERROR   index.md:21                     [index-toter-link] [[skills-system]] …
  ERROR   index.md                        [waise] 'gateway-und-dispatcher' …
  STALE   pages/profile-system.md:1       [freshness] updated 2026-01-20 ist 203
          Tage alt (Grenze 180) — pruefen, nicht loeschen (AGENTS.md 5)

------------------------------------------------------------------------------
ERROR: 5  STALE: 1  PRUNE-VORSCHLAG: 0

FEHLGESCHLAGEN — 5 Befund(e), die einen Merge sperren.
EXIT=1
```

**Gegenprobe:** dieselbe Wissensbasis in einer Kopie, alle sechs Punkte behoben:

```console
ERROR: 0  STALE: 0  PRUNE-VORSCHLAG: 0

BESTANDEN — keine ERROR-Befunde. Ein Merge ist erlaubt.
EXIT=0
```

Keine False Positives, keine False Negatives. Weiter geprüft:

| Aufruf | Ergebnis |
|---|---|
| `--strict` auf dem Seed | Exit 1 — `STALE` zählt mit |
| `--json` | `counts {ERROR:5, STALE:1, PRUNE-VORSCHLAG:0}`, `error_count: 5` |
| `--today 2026-08-11` | macht die Freshness-Prüfung reproduzierbar |
| ohne `--today` | benutzt das Systemdatum |

`setup.sh` und `reset-workspace.sh` prüfen diesen Ausgangsbefund bei jedem
Aufruf und melden, wenn er nicht 5/1 lautet.

### Story 11 — `kb_git.py`: alle Riegel ✅

Alle Verben und alle Abweisungen real ausgelöst, auf dem Repository unter
`workspace/wiki/`:

| Aufruf | Ergebnis |
|---|---|
| `branch kb/ingest-test` | „von main angelegt und ausgecheckt", rc 0 |
| `branch feature/xyz` | **ABGEWIESEN** — Präfix `kb/ingest-` erzwungen, rc 1 |
| `commit -m "leer"` ohne Änderung | **ABGEWIESEN** — „es gibt nichts zu committen", rc 1 |
| `commit` mit Änderung | committet, listet `A pages/skills-system.md` |
| `changed kb/ingest-test` | `A pages/skills-system.md`, `1 file changed, 16 insertions(+)` |
| `merge` bei 5 ERROR | **ABGEWIESEN** — „kb_lint.py hat den Branch nicht bestanden (Exit 1)", rc 1 |
| `merge` bei 0 ERROR / 1 STALE | **BESTANDEN** — „nach main verschmolzen, Branch entfernt" |
| `branch kb/ingest-bbb`, während `kb/ingest-aaa` offen | **ABGEWIESEN** — „es ist noch ein Ingest offen: kb/ingest-aaa", rc 1 |
| `status` | zeigt Branch, Sauberkeit und „Offene Ingests: kb/ingest-aaa" |
| `discard kb/ingest-aaa` | „verworfen. main unveraendert: 9818a51 …" |
| danach `branch kb/ingest-bbb` | rc 0 |

**Zwei Aussagen sind damit belegt:**

1. `ERROR` sperrt den Merge, `STALE` **nicht**. Das ist Absicht: ein
   Freshness-Befund wäre sonst nur dadurch aus dem Weg zu räumen, dass jemand
   `updated` auf heute stellt — und damit die Prüfung für 180 Tage stilllegt.
2. Der Konkurrenzschutz hält auf Code-Ebene, unabhängig davon, ob ein Modell die
   Regel gelesen hat.

### Story 11 — beide Tore und `gate.sh` ✅

Mit synthetischen Tor-Karten (ohne Assignee, tokenfrei) auf
`kanban-story-11` geprüft:

| Prüfung | Ergebnis |
|---|---|
| `./gate.sh` erkennt Tor 1 und Tor 2 am Kartentitel | ✅ beschriftet beide, nennt je Tor die gültigen Verben |
| `./gate.sh merge <tor1-id>` | **abgewiesen**: „'merge' gilt an Tor 1 nicht. Dort gelten: approve shelve modify" |
| `./gate.sh approve <tor2-id>` | **abgewiesen**: „'approve' gilt an Tor 2 nicht. Dort gelten: merge merge-ohne-prune discard" |
| `dispatch --dry-run` bei zwei blockierten Karten | `Promoted: 0`, `Spawned: 0` — beide Blocks halten |
| `pump.sh` bei offenen Toren | endet von selbst (`[01] blocked=2`) und beschriftet beide Tore mit ihren Verben |
| `unblock --reason "approve"` | legt den Kommentar `UNBLOCK: approve` an; der Block hatte vorher `BLOCKED: <grund>` angelegt |

Die beiden Kommentar-Präfixe (`BLOCKED:` / `UNBLOCK:`) setzt Hermes selbst — der
Orchestrator liest im zweiten Lauf genau diesen Thread.

### Story 11 — profil-lokale Skills ✅

```console
$ hermes -p kb-orchestrator skills list
│ kb-pipeline │          │ local  │ local │ enabled │
0 hub-installed, 0 builtin, 1 local — 1 enabled, 0 disabled

$ hermes -p kb-researcher skills list
0 hub-installed, 0 builtin, 0 local — 0 enabled, 0 disabled
```

Vier Skills auf vier Profile verteilt, der Rechercheur bekommt bewusst keine.

### Story 11 — Setup und Rücksetzung ✅

```console
$ ./setup.sh
…
5/5  Arbeitskopie, Git-Repository und Verifikation
workspace/ zurueckgesetzt (25 Startdateien aus seed/)
workspace/wiki/ ist ein Git-Repository (Branch main, 1 Commit)
Ausgangsbefund des Linters: 5 ERROR, 1 STALE  (erwartet)

NAME                  ON DISK   COUNTS
kb-ingestor           yes       (idle)
kb-linter             yes       (idle)
kb-orchestrator       yes       (idle)
kb-researcher         yes       (idle)
kb-scout              yes       (idle)

✓ Setup vollstaendig.
```

`reset-workspace.sh` legt das Repository **selbst** an (nicht nur `setup.sh`) —
sonst hätte ein zweiter Durchlauf nach dem Zurücksetzen keines mehr, und
`kb_git.py` würde bei jedem Aufruf abweisen. `--diff` blendet `.git` aus, sonst
besteht die Ausgabe fast nur aus Git-Objekten.

### Story 11 — die Pipeline als Ganzes ✅ (2026-08-11, 15:21–17:33)

**Ein vollständiger Durchlauf**, 37 Karten, 52 Runs, alle auf `done`.

```console
$ hermes kanban --board kanban-story-11 list --json \
    | jq -r 'group_by(.created_by)|map("\(.[0].created_by): \(length)")|join("   ")'
kb-orchestrator: 34   user: 3

$ hermes kanban --board kanban-story-11 stats
By assignee:
  kb-ingestor           done=3
  kb-linter             done=3
  kb-orchestrator       done=16
  kb-researcher         done=13
  kb-scout              done=2
```

**Keine ungeplante Karte** — `created_by` kennt nur `kb-orchestrator` und
`user`. Das ist der Punkt, an dem Story 10 in ihrem ersten Lauf zwei Duplikate
produzierte; hier hielten `idempotency_key` auf jeder Kettenkarte plus die
Prosa-Regel „Lege selbst KEINE weiteren Karten an". ⚠ Wie in Story 10 ist damit
**nicht** getrennt, welcher der beiden Griffe gewirkt hat.

**Die Kette, gemessen:**

| Stufe | Ergebnis |
|---|---|
| 2 Scouts | 19 + 12 Kandidaten aus je 3 Dateien; `2026-08-10-community.md` → **0 Kandidaten** (Kanal-Neuigkeiten sind keine überprüfbaren Aussagen) |
| Triage (25 min) | 31 Kandidaten → 15 Items; **9 geshelved** (alle Score 20, mit Fundstelle); 6 über der Schwelle (98, 91, 85, 78, 76, 70) |
| Fan-out | 12 Bahn-Karten parallel + 6 Route-Karten (Fan-in auf je 2 Bahnen) |
| Route | `fehlt` ×1, `widerspruch` ×1, `unvollstaendig` ×4 — alle über `route.tabelle` |
| Tor 1 | 6 Karten blockiert (`needs_input`); beantwortet mit 2× `approve`, 1× `modify`, 3× `shelve` |
| Ingest / Lint / Commit | 3 Ketten, **seriell**; Lint ERROR **4 → 0** je Kette |
| Tor 2 | 3 Karten blockiert (`capability`); 3× `merge` |
| Ergebnis | 3 Merge-Commits in `main`, Arbeitsbaum sauber, alle Branches entfernt |
| Linter final | **ERROR 5 → 0**, STALE 1 → 1 (absichtlich unangetastet) |

**Belegt: Dedup gegen die Wissensbasis wirkt.** Neun Items wurden geshelved,
weil die Wissensbasis sie schon kannte (`review`-Spalte, `swarm`, `--goal`,
`--no-agent`, `kanban daemon` deprecated, `unblock --reason`). Für keines wurde
eine Karte angelegt. Besonders aussagekräftig: `unblock-reason-semantik` (20,
geshelved) und `kanban-block-semantik-korrektur` (91, weiter) stammen aus
**derselben Quelle** und betreffen **dieselbe Seite** — die eine Aussage steht
dort schon, die andere widerspricht ihr.

**Belegt: der Konfliktpfad.** Die Wissensbasis dokumentierte
`hermes kanban block <id> --reason "…"`; Changelog, Transkript **und ein
CLI-Test des Rechercheurs gegen die lokale v0.20.0** belegten die positionale
Form. Der Mensch entschied am Tor 1 (`approve`), der Ingestor **ersetzte** die
falsche Aussage (statt zu ergänzen) und zog `updated`, `version` und `sources`
nach; Tor 2 gab den Prune frei.

**Belegt: der Linter löscht nicht.** `pages/profile-system.md` (203 Tage alt)
blieb unverändert; nachgeprüft mit
`git diff -- pages/profile-system.md | grep -E "^[+-](updated|status)"` → keine
Änderung. Der Lint-Bericht begründet es selbst: „das waere eine
Frontmatter-Luege, weil ich den Inhalt nicht gegen die aktuelle Version
verifizieren konnte."

**Belegt: die Serialisierung über eine Kante.**

```console
$ hermes kanban --board kanban-story-11 show <ingest-2> --json | jq '{status:.task.status, parents:.parents}'
{
  "status": "todo",
  "parents": ["t_aa5e5a84"]        ← "Commit + Tor 2: skills-system"
}
```

Der Orchestrator hat die offene Commit-Karte des vorherigen Items mit
`kanban_list` gefunden und seine Ingest-Karte als deren Kind angelegt.

**Belegt: `modify` greift inhaltlich.** Der Vorschlag enthielt eine
Changelog-Aussage (`dispatch_stale_timeout_seconds` pro Profil
überschreibbar), die die Verifikations-Bahn nicht nachweisen konnte. Die
`modify`-Antwort hat sie gestrichen; `wiki/log/ingest-log.md` hält das
ausdrücklich fest.

### ⚠ Story 11 — was der Lauf offengelassen bzw. aufgedeckt hat

| Befund | Konsequenz |
|---|---|
| **`kb_git.py changed` war an beiden Toren leer.** Der Ingestor ließ alles im Arbeitsbaum (so verlangte es die Skill), also gab es keinen Diff gegen `main`. | Artefakte nachgeschärft: Ingestor **und** Linter committen jetzt auf ihrem Branch. ⚠ Der protokollierte Lauf entstand **vorher**. |
| **6 Items über der Schwelle = 12 Torfragen.** Die Schwelle sortiert, sie begrenzt nicht. | `ingest.yaml` hat jetzt `rubrik.max_pro_lauf: 3`; überzählige Items werden `zurueckgestellt`, nicht `geshelved`. ⚠ Beim Lauf noch nicht vorhanden. |
| **5 von 52 Runs `reclaimed`** (`stale_lock=…`) | Ursache: der Rechner schlief 16:20–17:06 (Clamshell). Das ist **kein Mangel, sondern ein bestandener Test** — siehe eigenen Abschnitt unten. |
| **Die Triage brauchte 25 min** bei `--max-runtime 30m` | knapp. Bei größerem Korpus gehört mehr Luft in die Startkarte. |
| Route-Ausgang **`shelve`** (`wissensstand: abgedeckt`) | in diesem Lauf **nicht** durchlaufen: die abgedeckten Items fielen schon in der Triage heraus und erreichten die Route-Stufe nie. Der Pfad ist in `ingest.yaml` definiert, aber ungetestet. |
| Tor-2-Verben **`merge-ohne-prune`** und **`discard`** | in `gate.sh` geprüft (Verb-Validierung, Reason-Pflicht), aber im Flottenlauf nicht ausgelöst — es wurde dreimal `merge` geantwortet. |
| Ein **zweiter Sweep**, der die drei zurückgestellten Items aufnimmt | nicht durchgeführt |

Alle Artefakte dieses Laufs liegen in
`Story 11 - LLM Wiki/beispiel-lauf-1/` mit einem eigenen
[README](../Story%2011%20-%20LLM%20Wiki/beispiel-lauf-1/README.md).

### Story 11 — `teardown.sh` in allen drei Stufen ✅

| Aufruf | Board | Profile | `workspace/` |
|---|---|---|---|
| `--files-only -y` | bleibt (37 done) | bleiben | aus `seed/` neu, Git-Repo neu, Ausgangsbefund 5/1 |
| `--keep-profiles -y` | gelöscht | **5 `kb-*` bleiben** („2/3 Profile: uebersprungen") | neu aufgebaut |
| `-y` (voll) | gelöscht | alle fünf gelöscht („kb-scout — geloescht" …) | neu aufgebaut |

Danach war `~/.hermes/profiles/` frei von `kb-*`, und ein anschließendes
`./setup.sh` legte alles wieder von Null an (fünf Profile, alle `ON DISK yes`,
Ausgangsbefund 5 ERROR / 1 STALE).

⚠ **Das Board taucht nach dem Löschen wieder auf** — als leeres
`Kanban Story 11`. Ursache ist die Desktop-App: solange sie dieses Board
anzeigt, pollt der Zähler in der Statusleiste es weiter und legt es innerhalb
von 60 s neu an. Derselbe Effekt ist für Story 10 dokumentiert; beide Tutorials
weisen im Aufräum-Abschnitt darauf hin.

Die Profil-Entfernung ist gegen Kollisionen abgesichert: `setup.sh` legt eine
Marke `.story11` in jedes Profil, und `teardown.sh` entfernt **nur** markierte.
Ein gleichnamiges Profil aus dem eigenen Bestand bliebe stehen („KEINE
.story11-Marke, bleibt unangetastet").

### Story 11 — der Datums-Fallstrick im Seed-Test ⚠ behoben

Der Ausgangsbefund `5 ERROR / 1 STALE` ist Teil des Setups — aber die
Freshness-Prüfung rechnet gegen die Systemuhr, und der Seed ist auf den Stand
**2026-08-11** geschrieben. Ohne festes Bezugsdatum würden mit der Zeit weitere
Seed-Seiten die 180-Tage-Grenze überschreiten, und die Kontrolle hätte
irgendwann „seed/ wurde veraendert?" gemeldet, obwohl nichts verändert war.

`setup.sh` und `reset-workspace.sh` rufen den Linter deshalb mit
`--today 2026-08-11` auf. Die **ERROR**-Zahl ist datumsunabhängig und bleibt der
eigentliche Test; nur der STALE-Anteil wird damit festgenagelt.

### Story 11 — Laufzeitprofil ✅ (wo die Zeit hingeht)

Gerechnet aus `beispiel-lauf-1/board.json` (`started_at` / `completed_at` je Karte);
das vollständige Profil liegt in `beispiel-lauf-1/laufzeiten.txt`.

| | |
|---|---|
| Wanduhr erste bis letzte Karte | **131 min** |
| Summe **aller** Kartenlaufzeiten | **455 min** → Parallelitätsfaktor **~3,5** |
| höchste Parallelität | **12 Karten gleichzeitig** (15:50) |
| Standby | 46 min |
| mindestens eine Karte aktiv | 86 min |
| **nichts aktiv** | **0 min** |

**Belegte Aussagen:**

1. **Die sechs Quelldateien kosten 3 Minuten.** Zwei Scouts, je drei Dateien,
   gleichzeitig — 2 % der Laufzeit. Der Eingang ist nicht der Kostentreiber.
2. **Urteilen kostet 10–26 min, Nachschlagen unter einer Minute.** Triage
   25,9 min; Recherche-Bahnen 11,7–15,8 min; Vorschlagskarten 10,3–12,9 min. Die
   **Route**-Karten dagegen 0,6–1,4 min (reiner Tabellen-Nachschlag), der
   **Linter** 0,7–3,4 min (`kb_lint.py` liefert die Befunde, das Modell
   repariert nur). Das ist die quantitative Bestätigung des Entwurfsprinzips
   „der Klassifikator darf urteilen, was daraus folgt, ist eine Tabelle".
3. **Das Schreiben ist billig.** Ingest #2 / #3: 1,8 und 2,8 min. Die
   Serialisierung der drei Ketten kostet ~7 min Wanduhr je Kette — der
   Konkurrenzschutz ist fast gratis.
4. **Die Parallelität ist vom Graphen begrenzt, nicht von der Maschine.** Die
   Route-Karte ist ein Fan-in auf beide Bahnen; die langsamste Bahn bestimmt das
   Tempo. Zwölf Bahnen à ~12 min ergeben ~16 min Wanduhr.
5. **Die Laufzeit skaliert mit Items × Stufen, nicht mit Quelldateien.** Eine
   siebte Quelldatei kostet den Scout ~30 s; ein siebtes Item über der Schwelle
   kostet 7 Karten und zwei menschliche Entscheidungen. `rubrik.max_pro_lauf` ist
   damit der wirksamste Laufzeit-Hebel.

⚠ **Korrektur gegenüber der ersten Fassung.** Dort stand „gut 40 Minuten
Wartezeit an vier Torstellungen". Gemessen gibt es außerhalb des Standbys
**0 Minuten Leerlauf** — während der Torentscheidungen liefen andere Karten
weiter. Die Tore haben diesen Lauf nicht verlängert. Auch das war eine Schätzung
ohne Beleg.

⚠ **Nicht trennbar:** Bei den Tor-Karten enthält `completed_at − started_at` die
Wartezeit auf den Menschen mit, weil sie blockieren und auf derselben Karte
weiterlaufen. Drei Karten umspannen zusätzlich den Standby (79,9 / 65,2 /
51,3 min) — deren Laufzeit ist als Maß für Modellarbeit unbrauchbar und in der
Analyse ausgeklammert.

### Story 11 — Wiederaufnahme nach einem echten Standby ✅ (unfreiwilliger Test)

**Der wertvollste ungeplante Test dieser Sammlung.** Während des Flottenlaufs
wurde um 16:20 wegen eines Netzwerkausfalls der Deckel zugeklappt; der Rechner
schlief bis 17:06. Damit liegt ein Beleg für Crash-Recovery unter einer
**realen** Unterbrechung vor — Story 4b erzwingt denselben Zustand mit
`kill -9`, hier war er echt.

**Systemseite**, `pmset -g log`:

```console
2026-08-11 16:20:03  Sleep     Entering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active Using AC (Charge:100%)
2026-08-11 16:23:39  Sleep     Entering Sleep state due to 'Maintenance Sleep' … 1058 secs
2026-08-11 16:41:17  DarkWake  DarkWake from Deep Idle … rtc/SleepService
2026-08-11 16:45:00  DarkWake  DarkWake from Deep Idle … rtc/Maintenance … 45 secs
2026-08-11 16:45:45  Sleep     Entering Sleep state due to 'Maintenance Sleep' … 1018 secs
2026-08-11 17:02:43  DarkWake  DarkWake from Deep Idle … rtc/SleepService
2026-08-11 17:06:13  Wake      Wake from Deep Idle [CDNVA] : due to … lid …
```

**Boardseite**, die zu diesem Zeitpunkt laufende Karte:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  reclaimed     kb-ingestor            27m  2026-08-11 16:17
     ✖ stale_lock=MYMAC…:99349
  2  reclaimed     kb-ingestor            20m  2026-08-11 16:45
     ✖ stale_lock=MYMAC…:7211
  3  completed     kb-ingestor                 2026-08-11 17:06
```

**Die Korrelation ist exakt:**

| Uhrzeit | System | Board |
|---|---|---|
| 16:17 | wach | Run 1 startet |
| 16:20:03 | `Clamshell Sleep` | Worker friert ein, HTTP-Verbindung zum Modell reißt |
| 16:44 (= 16:17 + 27m) | schläft | Run 1 gilt als beendet |
| 16:45:00 | DarkWake, **45 s** | Tick erkennt `stale_lock` → **Run 2 startet 16:45** |
| 16:45:45 | Sleep, 1018 s | Run 2 friert sofort wieder ein |
| 17:05 (= 16:45 + 20m) | schläft | Run 2 gilt als beendet |
| 17:06:13 | `Wake`, Auslöser `lid` | **Run 3 startet 17:06 und läuft durch** |

Run 2 fiel vollständig in ein 45-Sekunden-DarkWake-Fenster; Run 3 startete in
derselben Minute, in der der Deckel aufging. Zusätzlich passt eine
Fremdbeobachtung: eine parallel laufende Polling-Schleife sprang von `16:23:18`
auf `16:45:45` — genau die Lücke zwischen `Sleep 16:23:39` und
`DarkWake 16:45:00`.

**Belegte Aussagen:**

1. Der Dispatcher erkennt einen verwaisten Claim über `stale_lock=<host>:<pid>`
   und legt die Karte zurück in die Queue — **ohne** dass der
   Heartbeat-Timeout (`kanban.dispatch_stale_timeout_seconds`, Standard 14400 s)
   ablaufen musste.
2. Ein Neustart ist ein **voller** Neustart der Stufe, kein Fortsetzen.
3. **Nichts ging verloren, nichts Halbfertiges landete in `main`.** Der Lauf
   endete mit 37/37 Karten `done`, Linter 5 → 0 ERROR, drei saubere Merges.
4. **`--max-runtime` rechnet Wanduhrzeit, nicht Rechenzeit.** Run 1 stand mit
   „27m" da und hat real ~3 Minuten gearbeitet. Ein knapper Laufzeitdeckel wird
   von einem Standby aufgebraucht, ohne dass Arbeit passiert.
5. **Worker überleben den Tod der Pumpe** — separat geprüft: nach
   `pkill -f pump.sh` (um 17:07) liefen drei Worker weiter. Sie sind
   eigenständige OS-Prozesse; tödlich ist nur ein Signal an die ganze
   Prozessgruppe oder eben ein Standby, der ihre Netzverbindung reißt.

**Warum der Abbruch die Wissensbasis nicht beschädigt hat** — drei Ebenen, alle
Konstruktion und nicht Glück: der Neustart schreibt die Seite von vorn (nicht ab
einer halben Datei); `bin/kb_lint.py` prüft danach die **ganze** Wissensbasis, so
dass eine halb geschriebene Seite als `frontmatter`- bzw. `abschnitt-fehlt`-Befund
auffiele; und `bin/kb_git.py merge` lässt nichts nach `main`, was den Linter
nicht besteht. Damit ist der deterministische Linter nicht nur eine
Formatprüfung, sondern das **Sicherheitsnetz unter jeder unterbrochenen
Arbeit** — so war er nicht entworfen.

⚠ **Korrektur gegenüber der ersten Fassung dieses Protokolls.** Die fünf
`reclaimed`-Runs waren dort meinen eigenen Prozess-Kills zugeschrieben. Das war
falsch: `pkill -f pump.sh` lief erst um 17:07, also **nach** allen drei
Anläufen. Die Ursache weisen die `pmset`-Zeitstempel aus. Die frühere Zuschreibung
war eine Vermutung ohne Beleg — genau die Art Aussage, die dieses Protokoll
trennen soll.

⚠ **Nicht geprüft:** ob ein Standby **zwischen** Ingest und Lint (statt mitten im
Ingest) ebenso glatt durchläuft, und ob ein Standby während des `kb_git.py
merge` selbst einen halben Merge hinterlassen kann. Der Merge ist kurz, aber
diese Lücke ist nicht ausgemessen.

### Story 11 — Cron-Anbindung ✅

```console
$ ./install-cron.sh
Wrapper angelegt: ~/.hermes/scripts/story11-kb-sweep.sh
  Script: story11-kb-sweep.sh
  Mode: no-agent (script stdout delivered directly)
  Next run: 2026-08-12T07:00:00+02:00
  ⚠  Gateway is not running — jobs won't fire automatically.

$ hermes cron list
  0bdd8ff01a5d [active]
    Name:      story11-kb-sweep
    Schedule:  0 7 * * *
```

Die **Übersprung-Bedingungen** des Ticks sind real ausgelöst — ein Cron-Job kann
niemanden fragen, also darf er nicht auf halbfertiger Arbeit aufsetzen:

```console
$ KB_WS=… KB_BOARD=kanban-story-11 ./scripts/kb-sweep-tick.sh
UEBERSPRUNGEN — Arbeitsbaum der Wissensbasis ist nicht sauber:
Branch:          kb/ingest-skiptest
Arbeitsbaum:     schmutzig
                 M log/ingest-log.md
Offene Ingests:  (keine)
```

Entfernen sauber:

```console
$ ./install-cron.sh --remove
Removed job: story11-kb-sweep (0bdd8ff01a5d)
Wrapper ~/.hermes/scripts/story11-kb-sweep.sh entfernt.
$ hermes cron list
No scheduled jobs.
```

⚠ Ein Lauf, den launchd **zur geplanten Zeit** auslöst, ist nicht geprüft — das
Gateway lief bei diesen Tests nicht.

## Herkunft der Konsolenausgaben

Alle Blöcke unter der Überschrift **„Real gemessen"** stammen aus tatsächlichen
Durchläufen vom 2026-08-10 (Stories 1–9) bzw. 2026-08-11 (Stories 10 und 11).
Deine Task-IDs werden andere sein, die Struktur nicht.

Story 10 hat als einzige **zwei** protokollierte Läufe. Die „Real
gemessen"-Blöcke in ihrem Tutorial stammen aus Lauf 1; wo Lauf 2 etwas
nachgemessen oder abweichend ergeben hat, steht es dort ausdrücklich dabei und
vollständig in `beispiel-lauf-2/README.md`.

Zwei Einschränkungen, die du kennen solltest:

**Alle elf Stories wurden auf ihrem eigenen Board `kanban-story-N` mit echten
Workern durchgespielt**, und alle gezeigten Ausgaben stammen aus diesen Läufen.

Story 11 hat zusätzlich Ausgaben, die **ohne Modell** entstanden sind und
deshalb bei dir Zeichen für Zeichen gleich aussehen müssen: alles von
`kb_lint.py`, alles von `kb_git.py` und die Verb-Validierung in `gate.sh`. Wenn
dort etwas abweicht, ist es ein echter Unterschied und keine Modellvarianz.

Zwei Dinge, die bei dir zwangsläufig anders aussehen:

- **Laufzeiten sind Anhaltspunkte, keine Zusagen.** Sie hängen am Modell und an
  der Maschine. Wo eine Story eine Zeit nennt (etwa Story 3: 2 Minuten für den
  blockierten Versuch, 4 für den zweiten), ist das ein Messwert, keine
  Spezifikation.
- **Die board-globalen `run_id`s werden andere sein.** `hermes kanban runs`
  zählt je Karte ab 1 und ist stabil; `hermes kanban show` zeigt die laufende
  Nummer des Boards. Deshalb steht in Story 4b `[run 5]` / `[run 6]` (dort
  liefen vorher vier Runs aus Teil 4a) und in Story 3 `[run 2]` für den ersten
  Implementierungsversuch (davor lag der PM-Lauf). Die Tutorials erklären das
  jeweils an der Stelle.

Was inhaltlich reproduzierbar ist und was nicht:

| reproduzierbar | nicht garantiert |
|---|---|
| Statusfolgen (`ready`/`todo`/`blocked`/`done`) | Wortlaut der Summaries |
| Outcome-Folgen (`blocked` → `completed`, `spawn_failed` → `gave_up`, `crashed` → `completed`) | Laufzeiten |
| Welche Karte blockiert (Story 5: `acct-torfhaus`; Story 6: Lizenzen) — das erzwingen die Startdaten bzw. der Task-Body | Anzahl der Akzeptanzkriterien, Zahl der Tests |
| Dass Dedup in Story 7 und Eskalation in Story 8 stattfinden | ob das Modell dieselben Formulierungen wählt |
| Story 11: die **Linter-Befunde** auf dem Seed (5 ERROR, 1 STALE, mit Regel und Zeile) — sie kommen aus Code | Story 11: die **Scores** (98/91/85/…) und die **Anzahl Items** — das sind Modellentscheidungen |
| Story 11: dass `kb_git.py merge` bei ERROR abweist und bei 0 ERROR durchgeht | Story 11: welche Kandidaten das Modell zu welchem Item bündelt |
| Story 11: dass `abgedeckt`-Items geshelved werden und keine Karte erzeugen | Story 11: wie viele es sind |
