# Story 1 — Abhängigkeiten und strukturierter Handoff

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-1` |
| Profile | `backend-dev`, `qa-dev` |
| Mandant | `auth-project` |
| Workspace-Art | `dir:` — alle drei Worker im selben Verzeichnis |
| Dauer | ca. 15 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Der Alltag eines einzelnen Entwicklers: Schema entwerfen, API implementieren,
Tests schreiben. Drei Aufgaben in einer Kette.

```
Design auth schema  →  Implement auth API endpoints  →  Write auth integration tests
     backend-dev              backend-dev                        qa-dev
```

Zwei Dinge sollst du danach gesehen haben:

1. **Nur der erste Task startet.** Die anderen beiden warten, bis ihr
   jeweiliger Eltern-Task fertig ist — automatisch, ohne dass du etwas
   auslöst.
2. **Der zweite Worker bekommt das Ergebnis des ersten strukturiert
   vorgelegt**, statt ein Design-Dokument neu lesen zu müssen. Das ist der
   *structured handoff*, und er ist der eigentliche Unterschied zu einer
   flachen Todo-Liste.

---

## Schritt 1.1 — Setup

```bash
cd "Story 1 - Solo Dev"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt an:

1. Board `kanban-story-1`.
2. Profile `backend-dev` und `qa-dev` — jeweils mit `SOUL.md`, Beschreibung
   und `config.yaml`.
3. `workspace/` als frische Kopie von `seed/`.

Ein Profil zählt für den Kanban-Dispatcher erst dann als Assignee, wenn in
seinem Verzeichnis eine **`config.yaml`** liegt — so prüft Hermes das
(`kanban_db.list_profiles_on_disk`):

```python
if (entry / "config.yaml").is_file():
    names.add(entry.name)
```

`hermes profile create` legt diese Datei nicht an, `hermes -p <profil> config
set …` schon. Deshalb schreibt `setup.sh` alle vier Modell-Schlüssel
(`model.default`, `model.provider`, `model.base_url`, `model.api_mode`) aus
deiner Root-Konfiguration ins Profil. Setzt man nur `model.default`, werden die
übrigen drei aus eingebauten Defaults gefüllt — und das kann ein anderer
Provider sein als der, den du benutzt.

Kontrolle:

```bash
hermes kanban --board kanban-story-1 assignees
```

```console
NAME                  ON DISK   COUNTS
backend-dev           yes       (idle)
qa-dev                yes       (idle)
…
```

Fehlt eines der beiden, fehlt seine `config.yaml`. Ein API-Key im Profil ist
**nicht** nötig — Profile erben die Schlüssel aus der Umgebung.

### Die Arbeitsdateien

In `seed/` liegt ein absichtlich leeres Mini-Projekt; `workspace/` ist die
Arbeitskopie:

```
workspace/
├── README.md          Projektbeschreibung für die Worker
├── auth/
│   └── __init__.py    leeres Paket — hier landet die Implementierung
├── migrations/        leer — hier landen die SQL-Migrationen
└── tests/             leer — hier landen die Tests
```

`seed/` fasst niemand an. Das ist nötig, weil der API-Worker
`auth/__init__.py` **überschreibt** — ohne unangetastete Kopie wäre die Story
nur einmal durchführbar.

`workspace/auth/__init__.py`:

```python
"""miniauth — Authentifizierungs-Baustein.

Startdatei des Tutorials. Der API-Worker aus Story 1 füllt dieses Paket
mit den Endpunkten register / login / refresh / logout.
"""

__all__: list[str] = []
```

---

## Schritt 1.2 — Die drei Tasks anlegen

```bash
./create-tasks.sh
source task-ids.env      # setzt BOARD, SCHEMA, API, TESTS
```

Der Kern von [`create-tasks.sh`](create-tasks.sh) — beachte `--parent`:

```bash
BOARD=kanban-story-1
WS="$PWD/workspace"

SCHEMA=$(hermes kanban --board $BOARD create "Design auth schema" \
    --assignee backend-dev --tenant auth-project --priority 2 \
    --workspace "dir:$WS" \
    --body "Entwirf das Schema für users, sessions und refresh tokens …" \
    --json | jq -r .id)

API=$(hermes kanban --board $BOARD create "Implement auth API endpoints" \
    --assignee backend-dev --tenant auth-project --priority 2 \
    --parent "$SCHEMA" \
    --workspace "dir:$WS" \
    --body "POST /register, POST /login, POST /refresh, POST /logout …" \
    --json | jq -r .id)

hermes kanban --board $BOARD create "Write auth integration tests" \
    --assignee qa-dev --tenant auth-project --priority 2 \
    --parent "$API" \
    --workspace "dir:$WS" \
    --body "Happy Path, falsches Passwort, abgelaufener Token, paralleler Refresh …"
```

Zwei Details:

- **`--workspace dir:<pfad>` muss absolut sein.** Relative Pfade werden
  abgewiesen — sie würden sonst gegen das Arbeitsverzeichnis des Dispatchers
  auflösen. Ohne `--workspace` bekommt jeder Task ein eigenes
  Wegwerf-Verzeichnis (`scratch`), und du siehst das Ergebnis nur im Summary.
- **Der Task-Body ist der Auftrag an das Modell.** Je konkreter — welche
  Dateien, welches Format, was ins `metadata` — desto brauchbarer das
  Ergebnis.

### Ausgangszustand prüfen

```bash
hermes kanban --board $BOARD list --tenant auth-project
```

Real gemessen:

```console
▶ t_29e19221  ready     backend-dev          [auth-project]  Design auth schema
◻ t_125b9111  todo      backend-dev          [auth-project]  Implement auth API endpoints
◻ t_9a859e10  todo      qa-dev               [auth-project]  Write auth integration tests
```

**Einer auf `ready`, zwei auf `todo`.** Das ist die
Dependency-Promotion-Engine: niemand schreibt Tests, solange es keine API gibt.

**Im Dashboard:** die Karte „Design auth schema" steht in *Ready*, die anderen
zwei in *Todo*. Klick auf eine Karte öffnet den Drawer rechts; unter
*Dependencies* siehst du „blocked by".

---

## Schritt 1.3 — Arbeiten lassen

```bash
./pump.sh
```

`pump.sh` stößt alle 15 Sekunden einen Dispatch-Tick auf diesem Board an, bis
nichts mehr offen ist. Alternativen:

```bash
hermes kanban --board $BOARD dispatch            # genau ein Tick
hermes kanban --board $BOARD dispatch --dry-run  # zeigen, was ein Tick täte
hermes gateway start                             # Normalbetrieb, alle Boards, Tick alle 60 s
```

**Im Dashboard:** „Nudge dispatcher" oben rechts. `hermes kanban daemon` ist in
0.20.0 deprecated — der Dispatcher lebt im Gateway.

Der Dispatcher beansprucht `$SCHEMA`, startet das Profil `backend-dev` als
eigenen OS-Prozess und setzt `HERMES_KANBAN_TASK=$SCHEMA` in dessen Umgebung.

**Läuft bei dir ein Gateway, startet es Tasks auch ohne dein Zutun** — auf
jedem Board, auch auf einem gerade neu angelegten. Wenn du einen Task erst
anlegen und später ansehen willst, parke ihn:

```bash
hermes kanban --board $BOARD block <id> "noch nicht starten"
hermes kanban --board $BOARD unblock <id>
# oder global:
hermes pause     # hält Kanban- und Cron-Dispatch an
hermes resume
```

### Was im Worker passiert

Diese Aufrufe macht das Modell im Worker-Prozess — **nicht du**. Sie existieren
nur innerhalb eines Workers; der Worker sieht weder Dashboard noch CLI.

```python
# Worker-Tool-Calls — KEINE Befehle für dein Terminal
kanban_show()
# → Titel, Body, worker_context, Eltern-Ergebnisse, frühere Versuche, Kommentare

# (der Worker liest Dateien, schreibt die Migrationen, prüft sie)

kanban_heartbeat(note="Schema entworfen, schreibe jetzt die Migrationen")

kanban_complete(
    summary="users(id, email, pw_hash), sessions(id, user_id, jti, expires_at); "
            "Refresh-Tokens als sessions mit kind='refresh'",
    metadata={
        "changed_files": ["migrations/001_users.sql", "migrations/002_sessions.sql"],
        "decisions": ["bcrypt zum Hashen", "JWT als Session-Token"],
    },
)
```

`kanban_show()` braucht keine Task-ID — es füllt sie aus
`$HERMES_KANBAN_TASK`. `kanban_complete()` schreibt Summary und Metadata auf
die aktuelle `task_runs`-Zeile, schließt den Run und setzt den Task in einem
atomaren Schritt auf `done`.

Live zusehen:

```bash
hermes kanban --board $BOARD log $SCHEMA --tail 2000
hermes kanban --board $BOARD tail $SCHEMA        # Event-Stream dieses Tasks
hermes kanban --board $BOARD watch               # Event-Stream des Boards
```

---

## Schritt 1.4 — Den Handoff sichtbar machen

Das ist der lehrreichste Befehl dieser Story: **`hermes kanban context`** zeigt
genau das, was der Worker sieht.

Vor dem Abschluss des Eltern-Tasks:

```bash
hermes kanban --board $BOARD context $API
```

```console
# Kanban task t_125b9111: Implement auth API endpoints

Assignee: backend-dev
Status:   todo
Tenant:   auth-project
Workspace: dir @ /Users/…/Story 1 - Solo Dev/workspace

## Body
Implementiere die vier Endpunkte des miniauth-Moduls: …
```

Kein Eltern-Abschnitt. Nach dem Abschluss von `$SCHEMA` derselbe Befehl —
jetzt kommt der entscheidende Block hinzu (real gemessen, gekürzt):

```console
## Parent task results
_Handoffs from upstream tasks, captured when each parent completed (see age
below). These are point-in-time snapshots, not live state …_
### t_29e19221 (completed 12m ago)
Auth schema designed and validated. Tables: users(id, email, pw_hash,
created_at) and sessions(id, user_id, jti, kind, expires_at). Migrations run
cleanly against throwaway SQLite: CHECK on kind('access'/'refresh'),
case-insensitive-unique email, and FK cascade all verified working.
_metadata_: `{"changed_files": ["…/migrations/001_users.sql",
"…/migrations/002_sessions.sql"], "decisions": ["users: id INTEGER PRIMARY KEY
AUTOINCREMENT, email TEXT NOT NULL UNIQUE, …", "added UNIQUE index on
lower(email) to make emails case-insensitively unique", "sessions: … kind TEXT
NOT NULL CHECK IN ('access','refresh') …", "timestamps stored as TEXT ISO-8601
(SQLite has no native datetime type)"], "tests_run": 3}`

## Recent work by @backend-dev
- t_29e19221 — Design auth schema (12m ago): Auth schema designed and validated …
```

**Das ist der Kern von Kanban gegenüber einer flachen Todo-Liste.** Der
API-Worker liest die Schema-Entscheidungen strukturiert, statt sich durch
Kommentare und Arbeitsergebnisse zu wühlen. Der Abschnitt
„Recent work by @&lt;profil&gt;" kommt dazu, ohne dass du etwas konfigurierst —
das Profil sieht, was es zuletzt selbst getan hat.

---

## Schritt 1.5 — Ergebnis inspizieren

```bash
hermes kanban --board $BOARD runs $SCHEMA
```

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  completed     backend-dev             2m  2026-08-10 10:48
     → Auth schema designed and validated. Tables: users(id, email, pw_hash, …
```

```bash
hermes kanban --board $BOARD show $SCHEMA
```

zeigt zusätzlich das vollständige Event-Log — die eigentliche Audit-Spur:

```console
Events (7):
  [10:48] created {'assignee': 'backend-dev', 'status': 'ready', 'parents': [], …}
  [10:48] [run 1] claimed {'lock': 'my-mac:12441', 'expires': …, 'run_id': 1}
  [10:48] [run 1] spawned {'pid': 58537}
  [10:48] [run 1] heartbeat
  [10:50] [run 1] heartbeat
  [10:51] [run 1] heartbeat
  [10:51] [run 1] completed {'result_len': 0, 'summary': 'Auth schema designed and validated. …'}

Runs (1):
  #1   completed    @backend-dev  153s  2026-08-10 10:48
```

Ein Detail, das beim Vergleichen zweier Ausgaben irritiert: `hermes kanban
runs` nummeriert die Versuche **eines Tasks** fortlaufend ab 1, `hermes kanban
show` zeigt dagegen die board-globale `run_id`. Derselbe Versuch kann bei
`runs` als „1" und bei `show` als „#5" erscheinen.

**Im Dashboard:** derselbe Inhalt im Drawer, Abschnitt *Run History* bzw.
*Activity*.

---

## Das solltest du sehen

```bash
hermes kanban --board $BOARD list --tenant auth-project
./reset-workspace.sh --diff
```

Alle drei Tasks auf `done`, und im Arbeitsverzeichnis echte Dateien. Real entstanden (gesamte Kette rund 15 Minuten, je ein Run pro Task):

```console
✓ t_29e19221  done      backend-dev          [auth-project]  Design auth schema
✓ t_125b9111  done      backend-dev          [auth-project]  Implement auth API endpoints
✓ t_9a859e10  done      qa-dev               [auth-project]  Write auth integration tests

  Only in …/workspace: .pytest_cache
  Only in …/workspace/auth: __pycache__
  Only in …/workspace/auth: api.py                 ← vom API-Worker
  Only in …/workspace/migrations: 001_users.sql    ← vom Schema-Worker
  Only in …/workspace/migrations: 002_sessions.sql ← vom Schema-Worker
  Only in …/workspace/tests: test_auth.py          ← vom QA-Worker (11 Tests)
```

`.pytest_cache` und `__pycache__` sind Nebenprodukte: der QA-Worker hat seine
Tests wirklich laufen lassen. `reset-workspace.sh` räumt sie mit weg.

Der QA-Worker hat die Endpunktnamen aus dem Eltern-Handoff übernommen, ohne
`auth/api.py` vorher lesen zu müssen — genau das ist der Punkt.

---

## Aufräumen

Nur die Karten, Board und Profile behalten:

```bash
source task-ids.env
hermes kanban --board $BOARD archive $SCHEMA $API $TESTS
./reset-workspace.sh
```

`reset-workspace.sh` wirft `workspace/` weg und baut es aus `seed/` neu auf.
Ein reines „lösche die neuen Dateien" reicht nicht, weil der API-Worker
`auth/__init__.py` **überschreibt**.

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

`-y` überspringt die Rückfrage. `teardown.sh` entfernt ausschließlich das Board
`kanban-story-1` und die Profile `backend-dev` und `qa-dev`.

⚠ `backend-dev` wird auch von Story 3 und Story 4 benutzt. Arbeitest du
parallel an einer davon, nimm `--keep-profiles`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban boards create <slug> --name … --icon …` | Eigenes Board |
| `hermes kanban create "<titel>" --assignee <profil>` | Task anlegen |
| `… --parent <id>` | Abhängigkeit; wiederholbar |
| `… --workspace dir:<absoluter-pfad>` | Echtes Arbeitsverzeichnis |
| `… --tenant <name>` / `--priority <n>` / `--json` | Filterachse, Reihenfolge, `jq -r .id` |
| `hermes kanban list [--tenant …]` | Board auflisten |
| `hermes kanban context <id>` | **Was der Worker sieht** — inkl. Eltern-Handoff |
| `hermes kanban runs <id>` | Versuchshistorie |
| `hermes kanban show <id>` | Task mit Kommentaren, Events und Runs |
| `hermes kanban log <id> --tail N` | Worker-Log, auch live |
| `hermes kanban tail <id>` / `watch` | Event-Stream eines Tasks / des Boards |
| `hermes kanban dispatch [--dry-run]` | Ein Tick |
| `hermes kanban archive <id…>` | Aus der Ansicht nehmen |
| `hermes pause` / `hermes resume` | Dispatch anhalten |
