# Hermes Kanban — Grundlagen und Befehlsreferenz

Dies ist das **Nachschlagewerk**, nicht der Einstieg. Die eigentlichen
Tutorials liegen je Story in ihrem eigenen Verzeichnis; die Übersicht steht im
[README](README.md).

Verifiziert gegen **Hermes Agent v0.20.0 (2026.8.3)** auf **macOS**
(Darwin 25.5.0, Python 3.11.15).

---

## Inhalt

- [Das Grundmodell in fünf Begriffen](#das-grundmodell-in-fünf-begriffen)
- [Wie die Story-Tutorials zu lesen sind](#wie-die-story-tutorials-zu-lesen-sind)
- [Das Board hat acht Spalten](#das-board-hat-acht-spalten)
- [Der Dispatcher](#der-dispatcher)
- [Workspaces](#workspaces)
- [Profile als Assignees](#profile-als-assignees)
- [Befehlsreferenz](#befehlsreferenz)
- [Werkzeuge, die nur der Worker hat](#werkzeuge-die-nur-der-worker-hat)
- [Umgebungsvariablen im Worker](#umgebungsvariablen-im-worker)
- [Konfigurationsschlüssel](#konfigurationsschlüssel)

---

## Das Grundmodell in fünf Begriffen

| Begriff | Bedeutung |
|---|---|
| **Board** | Eine isolierte SQLite-Warteschlange. Das Standard-Board liegt in `~/.hermes/kanban.db`, jedes weitere unter `~/.hermes/kanban/boards/<slug>/kanban.db`. Worker eines Boards können Karten anderer Boards physisch nicht sehen. |
| **Task** | Eine Zeile mit Titel, Body, Assignee, Status und optionalem Mandanten. Kann Eltern-Tasks haben. |
| **Assignee** | Der **Profilname**, der den Task ausführen soll — nicht eine Person. `backend-dev` ist ein Hermes-Profil. |
| **Run** | Ein Ausführungsversuch. Drei Versuche = drei Runs, jeder mit eigenem Outcome, Summary und Metadata. Die Historie ist die primäre Darstellung, kein Nachgedanke. |
| **Dispatcher** | Die Schleife, die zugewiesene Tasks beansprucht, das Profil als eigenständigen OS-Prozess startet, tote Worker einsammelt und `todo`-Tasks nach `ready` befördert, wenn deren Eltern fertig sind. |

Der entscheidende Unterschied zu `delegate_task`: Kanban-Tasks überleben
Neustarts, sind für Menschen einsehbar und behalten eine dauerhafte
Audit-Spur. `delegate_task` blockiert, bis der Unteragent fertig ist, und
hinterlässt nichts.

Wann welches Werkzeug:

| | `delegate_task` | Kanban |
|---|---|---|
| Dauer | Sekunden bis Minuten | Minuten bis Wochen |
| Eingriff mitten im Lauf | nein | ja (`comment`, `unblock`, `reassign`) |
| Überlebt einen Neustart | nein | ja |
| Mehrere Rollen nacheinander | nur verschachtelt blockierend | als Graph |
| Teilfortschritt sichtbar | nein | ja |
| Audit-Spur | nein | `task_events` + `task_runs` |

---

## Wie die Story-Tutorials zu lesen sind

**Codeblöcke mit `bash` sind Befehle, die *du* eintippst.** Sie laufen alle im
Terminal, im jeweiligen Story-Verzeichnis.

**Codeblöcke mit `# Worker-Tool-Calls` sind das, was der gespawnte Agent
intern aufruft.** Die tippt niemand ein — sie stehen dort, damit du den Kreis
schließen kannst. Diese Werkzeuge (`kanban_show`, `kanban_complete`,
`kanban_block`, `kanban_heartbeat`, …) existieren ausschließlich innerhalb
eines Worker-Prozesses. Der Worker sieht weder das Dashboard noch die CLI.

Jede Story endet mit **„Das solltest du sehen"** und **„Aufräumen"**.

Konsolenausgaben unter der Überschrift **„Real gemessen"** stammen aus einem
tatsächlichen Durchlauf, mit echten Task-IDs und echten Laufzeiten. Deine IDs
werden andere sein, die Struktur nicht.

---

## Das Board hat acht Spalten

Der Statusvorrat in `hermes_cli/kanban_db.py`:

```python
VALID_STATUSES = {"triage", "todo", "scheduled", "ready", "running",
                  "blocked", "review", "done", "archived"}
```

Und die Spaltenreihenfolge, die beide Oberflächen rendern
(`plugins/kanban/dashboard/plugin_api.py`):

```python
BOARD_COLUMNS: list[str] = [
    "triage", "todo", "scheduled", "ready", "running", "blocked", "review", "done",
]
```

| Spalte | Bedeutung | Wie kommt eine Karte hinein? |
|---|---|---|
| **Triage** | Rohe Idee, noch keine Spezifikation. | `create --triage` |
| **Todo** | Wartet auf offene Eltern-Tasks. | `create --parent <id>` |
| **Scheduled** | Wartet auf **Zeit**, nicht auf einen Menschen. Absichtlich nicht dispatchbar. | `kanban schedule <id> "…"` |
| **Ready** | Beanspruchbar. | Standard bzw. automatische Beförderung |
| **Running** | Ein Worker-Prozess hält den Claim. | Dispatcher |
| **Blocked** | Wartet auf einen **Menschen**. | `kanban block <id> "<grund>"` oder `kanban_block()` im Worker; auch nach `gave_up` |
| **Review** | Ein Worker hat einen PR erzeugt und die Karte zur Prüfung weitergegeben. Der Dispatcher startet dafür einen Review-Agenten mit der Skill `sdlc-review`, der entweder merged (→ `done`) oder zurückgibt (→ `running`). | Worker-seitig im SDLC-Ablauf |
| **Done** | Abgeschlossen, mit Summary und Metadata. | `kanban_complete()` bzw. `kanban complete` |

`archived` ist ein neunter Status, aber keine Spalte — archivierte Karten
verschwinden aus der Ansicht (`--archived` bzw. der Schalter „Show archived"
holt sie zurück).

Praktischer Unterschied zwischen `blocked` und `scheduled`:

```bash
hermes kanban block    <id> "brauche Entscheidung von dir"
hermes kanban schedule <id> "erst nach dem Release am Freitag"
hermes kanban unblock  <id>    # holt BEIDE zurück
```

⚠ Der Grund ist bei `block` **positional**, nicht `--reason` — anders als bei
`unblock`. Optional davor `--kind`, und zwar **vor** der Kartennummer:

```bash
hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"
```

| `--kind` | Bedeutung |
|---|---|
| `dependency` | wartet in `todo`, wird automatisch befördert, wenn die Eltern fertig sind — **kein** Mensch |
| `needs_input` / `capability` | geht nach `blocked` und wartet auf einen **Menschen** |
| `transient` | vermutlich flüchtiger Fehler |

Wiederholtes Blockieren mit demselben `kind` nach einem `unblock` routet die
Karte in die Triage — das bricht Endlosschleifen aus `unblock` und
Wieder-Blockieren.

⚠ **Das ist die Falle jeder Pipeline mit zwei Freigaben.** Der Zähler
(`block_recurrences`) wird **pro `kind`** geführt, die Grenze ist
`BLOCK_RECURRENCE_LIMIT = 2` (`kanban_db.py:134`, **kein**
Konfigurationsschlüssel), und zurückgesetzt wird er nur bei erfolgreichem
Abschluss. Gemessen:

| Block 1 | Block 2 | Status danach |
|---|---|---|
| `--kind needs_input` | `--kind needs_input` | **`triage`** — Ereignis `block_loop_detected`, `recurrences: 2, limit: 2` |
| `--kind needs_input` | `--kind capability` | `blocked` — der Zähler startet wieder bei 1 |

Zwei Tore auf **einer** Karte gehen also nur mit zwei verschiedenen `kind` und
genau einmal je `kind`. Zwei Tore auf **zwei** Karten gehen immer. Story 11 zeigt
das gemessen und baut deshalb zwei Karten.

⚠ **`--initial-status blocked` ist kein Tor.** Es setzt die Spalte, erzeugt
aber kein `blocked`-**Ereignis**. `recompute_ready` befördert `blocked`-Karten
mit, sobald die Eltern fertig sind, und lässt nur die in Ruhe, deren jüngstes
Ereignis ein echtes `blocked` ist (`_has_sticky_block`). Zum Parken beim
Anlegen ist die Option richtig; als Wartepunkt für einen Menschen ist sie
falsch. Story 10 zeigt beides gemessen.

`unblock` bringt eine Karte nach `ready` — oder nach `todo`, falls noch offene
Eltern-Tasks existieren.

---

## Der Dispatcher

Damit überhaupt etwas passiert, muss jemand den Dispatcher laufen lassen:

```bash
# a) Gateway — der Normalfall. Enthält den Dispatcher, Tick alle 60 s,
#    bedient ALLE Boards (auch neu angelegte).
hermes gateway start
hermes gateway status
hermes gateway stop

# b) Ein einzelner Tick, sofort. Entspricht "Nudge dispatcher" im Dashboard.
hermes kanban --board <slug> dispatch

# c) Die Pumpe jeder Story: Tick alle 15 s, bis nichts mehr offen ist.
cd "Story N - …" && ./pump.sh
```

Für die Tutorials ist **(c)** am angenehmsten: 60 Sekunden Wartezeit pro
Schritt summieren sich sonst erheblich. `hermes kanban daemon` ist in 0.20.0
**deprecated** — der Dispatcher lebt im Gateway.

Vorher ansehen, was ein Tick tun *würde*:

```bash
hermes kanban --board <slug> dispatch --dry-run
```

```console
Reclaimed:    0
Crashed:      0
Timed out:    0
Stale:        0
Auto-blocked: 0
Promoted:     0
Spawned:      1
  - t_21263ef2  ->  backend-dev  @ - (dry)
```

Global anhalten (Kanban **und** Cron; laufende Arbeit wird nicht getötet):

```bash
hermes pause --reason "…"
hermes resume
```

Spawns pro Tick deckeln, wenn die Maschine sonst überläuft:

```bash
hermes kanban --board <slug> dispatch --max 4
```

**Karten ohne Assignee werden nie gestartet.** Das ist der einfachste Weg,
etwas anzulegen und in Ruhe anzusehen, während ein Gateway läuft.

---

## Workspaces

| Angabe | Ergebnis |
|---|---|
| *(nichts)* / `--workspace scratch` | Wegwerf-Verzeichnis unter `~/.hermes/kanban/boards/<slug>/workspaces/<task-id>` |
| `--workspace dir:<absoluter-pfad>` | Genau dieses Verzeichnis. **Relative Pfade werden abgewiesen.** |
| `--workspace worktree:<repo> --branch <name>` | Git-Worktree unter `<repo>/.worktrees/<task-id>` auf Branch `<name>` |
| `--workspace worktree --branch <name>` | Wie oben, aber das Repo kommt aus dem `default_workdir` des Boards |
| `--project <slug>` | Worktree unter dem Haupt-Repo eines Projekts, mit deterministischem Branch |

Prüfen, wohin eine Karte auflösen würde — **ohne einen Worker zu starten**:

```bash
hermes kanban --board <slug> claim <id>
```

```console
Claimed t_34933aa5
Workspace: /pfad/zum/repo/.worktrees/t_34933aa5
```

Ein Board kann ein Standard-Arbeitsverzeichnis mitbringen:

```bash
hermes kanban boards create <slug> --default-workdir /abs/pfad/zum/repo
hermes kanban boards set-default-workdir <slug> /abs/pfad
```

Das füllt **nur** die Worktree-Auflösung für `--workspace worktree` ohne Pfad.
Karten ohne `--workspace` bleiben `scratch`.

---

## Profile als Assignees

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt
(`kanban_db.list_profiles_on_disk`):

```python
if (entry / "config.yaml").is_file():
    names.add(entry.name)
```

`hermes profile create` legt sie **nicht** an. Der vollständige Weg:

```bash
hermes profile create backend-dev --no-skills --description "Backend engineer. …"

for key in model.default model.provider model.base_url model.api_mode; do
    hermes -p backend-dev config set "$key" "$(hermes config get "$key")"
done

hermes kanban --board <slug> assignees    # backend-dev muss ON DISK = yes zeigen
```

Alle vier Schlüssel, nicht nur `model.default`: die übrigen drei würden sonst
aus eingebauten Defaults gefüllt und könnten auf einen anderen Provider zeigen
als deine Root-Installation benutzt.

Ein API-Key im Profil ist **nicht** nötig — Profile erben die Schlüssel aus der
Umgebung.

### Beschreibung, SOUL.md und Skills

| Artefakt | Wofür |
|---|---|
| `profile.yaml: description` | Der **Kanban-Decomposer** routet Triage-Karten darüber — über die Beschreibung, nicht über den Profilnamen. `hermes profile describe <p> --text "…"`, oder `--all --auto` zum Generieren. |
| `SOUL.md` | Der Systemprompt des Profils. `hermes profile create` legt einen generischen an; eine eigene Fassung macht aus dem Profil erst einen Spezialisten. |
| `skills/<name>/SKILL.md` | Profil-lokale Skills, sichtbar in `hermes -p <p> skills list` als `local`. Pro Karte erzwingbar mit `create --skill <name>`. |

### Profile teilen und mitnehmen

```bash
hermes profile export <name> -o <name>.tar.gz     # Sicherung auf derselben Maschine
hermes profile import <archiv>
hermes profile install <git-url|verzeichnis> -y   # Distribution mit distribution.yaml
hermes profile update <name>
```

Eine Distribution ist ein Verzeichnis mit `distribution.yaml`, `SOUL.md`,
`config.yaml`, optional `skills/`, `cron/` und `mcp.json`. Weil sie eine
`config.yaml` mitbringt, ist ein so installiertes Profil sofort dispatchbar.
Die Beschreibung aus `distribution.yaml` landet allerdings **nicht** in
`profile.yaml` — `hermes profile describe` bleibt nötig.

---

## Befehlsreferenz

Alles akzeptiert `--board <slug>` **vor** dem Unterbefehl.

### Board

| Befehl | Zweck |
|---|---|
| `hermes kanban init` | `kanban.db` anlegen. Optional — jeder erste Aufruf tut das selbst. |
| `hermes kanban boards list` | Alle Boards mit Zählwerten |
| `hermes kanban boards create <slug> --name … --icon … [--color …] [--default-workdir …] [--switch]` | Board anlegen |
| `hermes kanban boards switch <slug>` | Aktives Board setzen (spart das `--board`) |
| `hermes kanban boards show` | Aktives Board mit DB-Pfad und Zählwerten |
| `hermes kanban boards rename <slug> <name>` | Anzeigename ändern (der Slug ist unveränderlich) |
| `hermes kanban boards set-default-workdir <slug> <pfad>` | Standard-Arbeitsverzeichnis für Worktrees |
| `hermes kanban boards rm <slug> [--delete]` | Archivieren bzw. endgültig löschen |

### Karten anlegen und ändern

| Befehl | Zweck |
|---|---|
| `hermes kanban create "<titel>" …` | Karte anlegen |
| `… --assignee <profil>` | Zuweisen (Profilname, nicht Person) |
| `… --parent <id>` | Abhängigkeit; wiederholbar → Fan-in |
| `… --workspace dir:<absoluter-pfad>` | Echtes Arbeitsverzeichnis |
| `… --workspace scratch` | Wegwerf-Verzeichnis (Standard) |
| `… --workspace worktree[:<repo>] --branch <name>` | Echter Git-Worktree |
| `… --project <slug>` | Worktree unter dem Repo eines Projekts |
| `… --tenant <name>` | Mandantenraum; landet als `$HERMES_TENANT` im Worker |
| `… --priority <n>` | Reihenfolge bei Gleichstand |
| `… --triage` | In der Triage-Spalte parken |
| `… --initial-status blocked\|running` | Karte gleich geparkt bzw. als laufend anlegen |
| `… --skill <name>` | Skill in den Worker erzwingen; wiederholbar |
| `… --max-retries <n>` | Circuit Breaker für diese Karte |
| `… --max-runtime 30m` | Laufzeitdeckel; danach SIGTERM/SIGKILL und erneut in die Queue |
| `… --model <m> --provider <p>` | Modell nur für diese Karte |
| `… --goal [--goal-max-turns N]` | Goal-Loop: ein Judge prüft nach jeder Runde, ob die Karte erfüllt ist |
| `… --idempotency-key <k>` | Doppelanlage verhindern; gibt die vorhandene ID zurück |
| `… --json` | Maschinenlesbar (für `jq -r .id`) |
| `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` | Fan-out + Verifier + Synthese in einem Befehl |
| `hermes kanban edit <id>` | Felder einer fertigen Karte korrigieren |
| `hermes kanban assign <id> <profil>` | Zuweisung ändern |
| `hermes kanban set-model <id> …` | Modell-Override nachträglich setzen/löschen |
| `hermes kanban link/unlink <eltern> <kind>` | Abhängigkeit nachträglich setzen/lösen |
| `hermes kanban attach <id> <datei>` / `attachments` / `attach-rm` | Anhänge |

### Zustand ändern

| Befehl | Zweck |
|---|---|
| `hermes kanban promote <id…>` | `todo`/`blocked` → `ready` (Notweg) |
| `hermes kanban block [--kind K] <id…> "<grund>"` | Warten auf einen Menschen (Grund **positional**) |
| `hermes kanban schedule <id…> "…"` | Warten auf Zeit |
| `hermes kanban unblock <id…> [--reason "…"]` | Zurück nach `ready` bzw. `todo`; `--reason` legt den Text vorher als Kommentar an |
| `hermes kanban complete <id…> --summary … --metadata '{…}'` | Von Hand abschließen |
| `hermes kanban archive <id…>` | Aus der Ansicht nehmen |
| `hermes kanban claim <id>` | Atomar beanspruchen; **druckt den aufgelösten Workspace** |
| `hermes kanban reclaim <id>` | Claim eines laufenden Workers freigeben |
| `hermes kanban reassign <id> <profil>` | Umhängen, optional mit Reclaim |
| `hermes kanban comment <id> "…"` | Kommentar; steht im Kontext des nächsten Versuchs |

⚠ **Sammelabschluss mit Handoff ist absichtlich gesperrt.**
`hermes kanban complete a b c --summary X` wird abgewiesen: dieselbe
Zusammenfassung auf drei Karten zu kopieren ist fast immer falsch, weil Summary
und Metadata pro Run gelten. Ohne die Handoff-Flags funktioniert der
Sammelabschluss weiter. Das Worker-Werkzeug `kanban_complete` kennt aus dem
gleichen Grund gar keine Sammelvariante.

### Ansehen und diagnostizieren

| Befehl | Zweck |
|---|---|
| `hermes kanban list [--status … --assignee … --tenant … --archived --json --sort …]` | Board auflisten |
| `hermes kanban list --mine` | Nur Karten des Profils aus `$HERMES_PROFILE` |
| `hermes kanban show <id> [--json]` | Karte mit Kommentaren, Events und Runs |
| `hermes kanban runs <id>` | Nur die Versuchshistorie |
| `hermes kanban context <id>` | **Was der Worker sieht** — Eltern-Handoffs, frühere Versuche, Kommentare |
| `hermes kanban log <id> [--tail N]` | Worker-Log, auch live |
| `hermes kanban tail <id>` | Event-Stream einer Karte verfolgen |
| `hermes kanban watch [--kinds completed,gave_up,timed_out]` | Event-Stream des ganzen Boards |
| `hermes kanban stats` | Zählwerte je Status und Assignee, ältestes `ready` |
| `hermes kanban diagnostics` | Aktive Probleme, mit Handlungsvorschlag |
| `hermes kanban assignees` | Bekannte Profile + `ON DISK` |
| `hermes kanban notify-subscribe/-list/-unsubscribe` | Gateway-Benachrichtigung zu Endzuständen |

`hermes kanban runs` nummeriert die Versuche **einer Karte** fortlaufend ab 1,
`hermes kanban show` zeigt dagegen die board-globale `run_id`. Derselbe Versuch
kann bei `runs` als „1" und bei `show` als „#5" erscheinen.

⚠ **`hermes kanban show <id>` ohne `--json` bricht in v0.20.0 ab.**
Reproduzierbar auf jedem Board, auch mit einer frisch angelegten Karte:

```console
$ hermes kanban show t_abc12345
Task t_abc12345: …
  status:    ready
  …
Traceback (most recent call last):
  File ".../hermes_cli/kanban.py", line 1766, in _cmd_show
    task, events, runs, graph=kb.task_graph_context(conn, task.id)
  File ".../hermes_cli/kanban_db.py", line 3669, in task_graph_contexts
    for row in conn.execute(
sqlite3.ProgrammingError: Cannot operate on a closed database.
```

Der Kopf der Karte wird noch gedruckt, dann stirbt es im Diagnostics-Block —
`task_graph_context` benutzt eine bereits geschlossene Verbindung. Kommentare,
Events und Runs erscheinen damit nie. Funktionierende Wege zum selben Inhalt:

```bash
hermes kanban show <id> --json | jq        # vollständig, inkl. events/comments/runs
hermes kanban runs    <id>                 # Versuchshistorie
hermes kanban context <id>                 # was der Worker sieht
hermes kanban log     <id> [--tail N]      # Worker-Log
```

Alle Skripte in diesem Repository benutzen deshalb `show --json`.

### Pflege

| Befehl | Zweck |
|---|---|
| `hermes kanban gc` | Workspaces archivierter Karten, alte Events und Logs aufräumen |
| `hermes kanban repair` | Inkonsistenzen im Board beheben |

### Triage-Automatik

| Befehl | Zweck |
|---|---|
| `hermes kanban specify <id>` | Rohe Idee zu einer Spezifikation ausformulieren, dann nach `todo` |
| `hermes kanban decompose <id>` | In einen Graphen von Kind-Karten zerlegen und auf Spezialisten routen |

Beide benutzen Hilfsmodelle aus `config.yaml`
(`auxiliary.triage_specifier` bzw. `auxiliary.kanban_decomposer`). Die
Automatik steuert `kanban.auto_decompose` und `kanban.auto_decompose_per_tick`.
Das Routing läuft über die **Profilbeschreibungen**.

### Zeitsteuerung

| Befehl | Zweck |
|---|---|
| `hermes cron create "<plan>" --name … --script <s> --no-agent --deliver local` | Skript auf Zeitplan; `--no-agent` = kein Modell, keine Tokenkosten |
| `hermes cron list` / `runs <id>` / `run <id>` / `rm <id>` | Auflisten, Historie, sofort feuern, entfernen |
| `hermes cron tick` | Fällige Jobs einmal ausführen und beenden |
| `hermes cron status` | Läuft der Scheduler? |

Skripte müssen unter `~/.hermes/scripts/` liegen. `.sh`/`.bash` laufen über
bash, alles andere über Python. Ausgaben landen unter
`~/.hermes/cron/output/<job-id>/`, die Jobdefinitionen in
`~/.hermes/cron/jobs.json`.

---

## Werkzeuge, die nur der Worker hat

`kanban_show`, `kanban_list`, `kanban_complete`, `kanban_block`,
`kanban_heartbeat`, `kanban_comment`, `kanban_attach`, `kanban_attach_url`,
`kanban_attachments`, `kanban_create`, `kanban_link`, `kanban_unblock`.

Der Lebenszyklus (`kanban_show` → arbeiten → `kanban_heartbeat` →
`kanban_complete`/`kanban_block`) wird automatisch in den Systemprompt jedes
Workers injiziert. Du musst dafür nichts konfigurieren.

`kanban_create` ist das Werkzeug, mit dem ein Worker **selbst** Karten anlegt —
für Fan-out oder Eskalation an ein anderes Profil. Es kennt `title`,
`assignee`, `body`, `parents`, `tenant`, `priority`, `workspace_kind`,
`workspace_path`, `project`, `triage`, `idempotency_key`,
`max_runtime_seconds` und `initial_status`.

Die Heartbeats sind kein Zierrat: ohne sie hält der Dispatcher den Claim nach
`kanban.dispatch_stale_timeout_seconds` für verwaist und legt die Karte zurück
in die Queue.

---

## Umgebungsvariablen im Worker

Der Dispatcher setzt sie beim Spawn (`hermes_cli/kanban_db.py`):

| Variable | Inhalt |
|---|---|
| `HERMES_KANBAN_TASK` | Karten-ID — deshalb braucht `kanban_show()` kein Argument |
| `HERMES_KANBAN_WORKSPACE` | aufgelöster Workspace-Pfad |
| `HERMES_KANBAN_BOARD` | Board-Slug |
| `HERMES_KANBAN_RUN_ID` | laufende Run-ID |
| `HERMES_KANBAN_CLAIM_LOCK` | Claim-Kennung |
| `HERMES_KANBAN_BRANCH` | Branch, bei Worktree-Karten |
| `HERMES_KANBAN_DB` / `_WORKSPACES_ROOT` | Pfade des Boards |
| `HERMES_TENANT` | Mandantenname, falls gesetzt |
| `HERMES_HOME` / `HERMES_PROFILE` | Profilverzeichnis und -name |
| `TERMINAL_CWD` | Arbeitsverzeichnis der Werkzeuge |

⚠ **`HERMES_TENANT` trennt Daten nicht von selbst.** Der Kernel setzt die
Variable; ob ein Worker sein Gedächtnis danach getrennt hält und im eigenen
Verzeichnis bleibt, ist eine **Konvention**, die der Task-Body oder eine Skill
durchsetzen muss. Story 5 zeigt, wie das aussieht.

---

## Konfigurationsschlüssel

```bash
hermes config get kanban.dispatch_interval_seconds       # 60
hermes config get kanban.failure_limit                   # 2
hermes config get kanban.auto_decompose                  # true
hermes config get kanban.auto_decompose_per_tick
hermes config get kanban.orchestrator_profile            # '' → aktives Default-Profil
hermes config get kanban.default_assignee                # ''
hermes config get kanban.dispatch_in_gateway             # true
hermes config get kanban.dispatch_stale_timeout_seconds  # 14400
```

Setzen mit `hermes config set <schlüssel> <wert>`, pro Profil mit
`hermes -p <profil> config set …`.
