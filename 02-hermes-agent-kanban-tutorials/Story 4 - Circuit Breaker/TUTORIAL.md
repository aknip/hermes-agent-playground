# Story 4 — Circuit Breaker, Respawn-Sperre und Crash Recovery

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-4` |
| Profile | `deploy-bot`, `backend-dev` |
| Mandant | `ops` |
| Workspace-Art | absichtlich kaputte Pfade (4a) und `dir:` (4b) |
| Dauer | ca. 8 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Worker scheitern. Fehlende Zugangsdaten, OOM-Kills, kaputte Pfade,
Netzwerkfehler. Der Dispatcher hat dafür **drei** Verteidigungslinien, und sie
verhalten sich unterschiedlich genug, dass man sie auseinanderhalten muss:

| Mechanismus | Wann | Ergebnis |
|---|---|---|
| **Circuit Breaker** | N Fehlversuche in Folge bei einem *wiederholbaren* Fehler | Run-Outcome `gave_up`, Task-Status `blocked` |
| **Respawn-Sperre** | Fehlertext sieht nach Auth/Quota aus | **gar kein** neuer Versuch, Task bleibt `ready` |
| **Crash-Erkennung** | Worker-Prozess ist weg, TTL noch nicht abgelaufen | Run-Outcome `crashed`, Task zurück auf `ready` |

Die zweite ist die unangenehmste: die Karte sieht auf dem Board aus wie
„wartet auf den Dispatcher", wird aber nie wieder angefasst — und
`hermes kanban diagnostics` meldet sie nicht.

---

## Schritt 4.1 — Setup

```bash
cd "Story 4 - Circuit Breaker"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh breaker.sh crash.sh
./setup.sh
```

Das legt Board `kanban-story-4`, die Profile `deploy-bot` und `backend-dev`
(jeweils mit `SOUL.md`, Beschreibung, `config.yaml`) und `workspace/` aus
`seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an — `setup.sh` schreibt daher alle vier
Modell-Schlüssel aus deiner Root-Konfiguration ins Profil.

### Die Arbeitsdateien

Teil 4a braucht keine — der Spawn scheitert, bevor irgendwer ein Verzeichnis
betritt. Teil 4b braucht eine Aufgabe, die lange genug läuft, um den Worker
mitten in der Arbeit zu erwischen:

```
workspace/
├── data/events.csv    420 Zeilen synthetische Ereignisdaten, 10 Kategorien
└── reports/           leer — Ziel des Workers
```

`data/events.csv` (Auszug):

```csv
event_id,ts,category,duration_ms,outcome,account
ev_00001,2026-07-01T08:07:00,search,2680,ok,acct_122
ev_00002,2026-07-01T08:14:00,signup,72,ok,acct_103
```

Erzeugen lässt sie sich mit diesem Schnipsel — nützlich, wenn du die Menge
verändern willst, um die Laufzeit zu treffen:

```python
import csv, random, datetime
random.seed(20260810)
cats = ["checkout","search","signup","billing","export",
        "dashboard","api","email","upload","settings"]
outcomes = ["ok","ok","ok","ok","slow","error"]
start = datetime.datetime(2026, 7, 1, 8, 0, 0)
rows = [{
    "event_id": f"ev_{i:05d}",
    "ts": (start + datetime.timedelta(minutes=7 * i)).isoformat(timespec="seconds"),
    "category": cats[i % len(cats)],
    "duration_ms": random.randint(35, 4200),
    "outcome": random.choice(outcomes),
    "account": f"acct_{random.randint(100, 140)}",
} for i in range(1, 421)]
with open("data/events.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
```

---

## Schritt 4.2 — Circuit Breaker

**Beide Teile von 4a kosten keine Tokens:** der Fehler tritt auf, bevor das
Modell gestartet wird.

`spawn_failed` entsteht im Dispatcher an genau zwei Stellen: wenn die
**Workspace-Auflösung** eine Exception wirft, oder wenn der **Prozess-Spawn**
selbst eine wirft. Beide Teilversuche hier benutzen den ersten Weg, mit zwei
verschiedenen Fehlertexten — weil der Fehlertext entscheidet, welcher der
beiden Schutzmechanismen greift.

```bash
./breaker.sh
```

Der Kern von [`breaker.sh`](breaker.sh):

```bash
hermes kanban --board kanban-story-4 create \
    "Deploy to staging (Zielpfad ist kein Verzeichnis)" \
    --assignee deploy-bot --tenant ops \
    --workspace "dir:/dev/null/staging" \
    --max-retries 3 \
    --body "…"
```

`/dev/null` ist eine Gerätedatei, kein Verzeichnis. `mkdir -p` darunter wirft
`NotADirectoryError` (Errno 20). Dieser Text enthält **kein** Auth- oder
Quota-Muster — die Respawn-Sperre greift also nicht, und der Dispatcher
versucht es jedes Mal erneut, bis der Breaker zuschlägt.

Real gemessen:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  spawn_failed  deploy-bot              0s  2026-08-10 10:47
     ✖ workspace: [Errno 20] Not a directory: '/dev/null/staging'
  2  spawn_failed  deploy-bot              0s  2026-08-10 10:47
     ✖ workspace: [Errno 20] Not a directory: '/dev/null/staging'
  3  gave_up       deploy-bot              0s  2026-08-10 10:47
     ✖ workspace: [Errno 20] Not a directory: '/dev/null/staging'
```

Event-Log:

```console
created → claimed → spawn_failed → claimed → spawn_failed → claimed → gave_up
```

Die ersten zwei Runs sind `spawn_failed` (wiederholbar), der dritte ist
`gave_up` (endgültig). Task-Status danach: `blocked`. Ohne `--max-retries` gilt
`kanban.failure_limit` aus der Konfiguration (Standard **2**).

So findest du solche Fälle, ohne das Board abzusuchen:

```bash
hermes kanban --board kanban-story-4 diagnostics
```

```console
1 active diagnostic(s) across 1 task(s):

  t_bbd45043  blocked   @deploy-bot   Deploy to staging (Zielpfad ist kein Verzeichnis)
    !! [error] repeated_failures: Agent spawn x3: workspace: [Errno 20] Not a
       directory: '/dev/null/staging'
       data: consecutive_failures=3 | most_recent_outcome=spawn_failed
             | last_error=workspace: [Errno 20] Not a directory: '/dev/null/staging'
             | failure_threshold=2 | failure_limit=2
       → Verify profile: hermes -p deploy-bot doctor
```

Zurückholen:

```bash
hermes kanban --board kanban-story-4 unblock t_bbd45043    # → ready
```

Sind Telegram, Discord oder Slack angebunden, feuert beim `gave_up`-Event eine
Gateway-Benachrichtigung. Abonnieren lässt sich das auch pro Karte:

```bash
hermes kanban --board kanban-story-4 notify-subscribe <id> …
hermes kanban --board kanban-story-4 notify-list
```

---

## Schritt 4.3 — Die Respawn-Sperre

`breaker.sh` fährt danach einen zweiten Fall: derselbe Aufbau, aber der Pfad
liegt auf einem **nicht gemounteten** Netzlaufwerk.

```bash
--workspace "dir:/Volumes/deploy-share/staging"
```

Auf macOS liefert `mkdir` dort `PermissionError` (Errno 13). Und jetzt kommt
der Unterschied. Vor jedem Spawn läuft `check_respawn_guard` und vergleicht den
letzten Fehlertext mit diesem Muster (aus `kanban_db.py`):

```python
_RESPAWN_BLOCKER_RE = re.compile(
    r"\b(quota|rate[\s_\-]?limit|429|403|auth\w*|"
    r"unauthorized|forbidden|billing|subscription|"
    r"access[\s_]denied|permission[\s_]denied|"
    r"invalid[\s_]api[\s_]key)\b", re.IGNORECASE)
```

„Permission denied" passt darauf. Der Dispatcher stuft den Fehler damit als
„durch Wiederholen nicht lösbar" ein und versucht es **überhaupt nicht mehr**.
Real gemessen, über drei Dispatch-Ticks:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  spawn_failed  deploy-bot              0s  2026-08-10 10:47
     ✖ workspace: [Errno 13] Permission denied: '/Volumes/deploy-share'

Events: created → claimed → spawn_failed → respawn_guarded → respawn_guarded
```

Kein zweiter Versuch. Kein `gave_up`. **Task-Status bleibt `ready`.**

Das ist die unangenehmere Fehlerart: die Karte sieht auf dem Board aus wie
„wartet auf den Dispatcher", wird aber nie wieder angefasst — und
**`hermes kanban diagnostics` meldet diesen Fall nicht.** Nur das Event-Log
verrät ihn:

```bash
hermes kanban --board kanban-story-4 show <id> --json \
  | jq -r '.events[].kind'
```

Steht dort `respawn_guarded`, ist der Task gesperrt. Weitere Sperrgründe im
selben Wächter: ein erfolgreicher Run innerhalb der letzten Stunde, eine
GitHub-PR-URL in einem Kommentar innerhalb von 24 Stunden, und ein
Rate-Limit-Cooldown von 300 Sekunden.

Die praktische Konsequenz: **eine `ready`-Karte, die sich über mehrere Ticks
nicht bewegt, ist verdächtig.** Prüf sie über das Event-Log, nicht über
`diagnostics`.

---

## Schritt 4.4 — Crash Recovery

Manchmal gelingt der Spawn, aber der Prozess stirbt später — Segfault, OOM,
`systemctl stop`. Der Dispatcher pollt `kill(pid, 0)`, erkennt die tote PID,
gibt den Claim frei und schickt den Task zurück auf `ready`.

```bash
./crash.sh          # tötet den Worker 25 s nach dem Spawn
./crash.sh 10       # aggressiver, falls dein Modell schneller ist
```

`kill -9` löst denselben Erkennungspfad aus wie ein OOM-Kill (tote PID) und
ist reproduzierbar.

Was [`crash.sh`](crash.sh) tut:

1. Legt einen Task an, der lange genug läuft: `data/events.csv` (420 Zeilen)
   in zehn Kategorie-Reports zerlegen, **Datei für Datei**, damit
   Teilfortschritt erhalten bleibt.
2. `hermes kanban dispatch` — Worker startet.
3. Liest die PID aus dem Event-Log:
   ```bash
   hermes kanban --board kanban-story-4 show $MIG --json \
     | jq -r '[.events[] | select(.kind=="spawned") | .payload.pid] | last'
   ```
4. Wartet, dann `kill -9 <pid>`.
5. `hermes kanban dispatch` — der Dispatcher erkennt die tote PID.
6. `hermes kanban dispatch` — zweiter Versuch.

Der Task-Body enthält außerdem die Anweisung, bei einem früheren abgestürzten
Versuch erst zu prüfen, welche Reports schon existieren, und dort
weiterzumachen.

Real gemessen:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  crashed       backend-dev            30s  2026-08-10 10:54
     ✖ pid 91688 not alive
  2  completed     backend-dev             3m  2026-08-10 10:55
     → Zerlegte data/events.csv (420 Events) in 10 Kategorie-Reports
       reports/<category>.md …
```

Event-Log, mit den Run-Wechseln:

```console
  [run -] created
  [run 5] claimed
  [run 5] spawned
  [run 5] heartbeat
  [run 5] crashed
  [run 6] claimed
  [run 6] spawned
  [run 6] heartbeat
  [run 6] heartbeat
  [run 6] heartbeat
  [run 6] completed
```

Die Nummern `5` und `6` sind die **board-globalen** `run_id`s — auf diesem Board
war es der fünfte und sechste Worker-Lauf überhaupt. `hermes kanban runs` zeigt
dieselben beiden Versuche als `1` und `2`, weil es je Karte zählt.

Der abgestürzte Versuch verschwindet **nicht**. Er bleibt als Zeile in
`task_runs` stehen, mit `pid 91688 not alive` im `error`-Feld — auch Monate
später noch für eine Ursachenanalyse lesbar.

---

## Verwandt: `reclaim` und `--max-runtime`

Zwei Wege, die ohne Crash auskommen:

```bash
# Claim eines hängenden Workers von Hand freigeben:
hermes kanban --board kanban-story-4 reclaim <id>

# Laufzeitdeckel schon beim Anlegen: nach 30 Minuten SIGTERM, dann SIGKILL,
# Task zurück in die Queue (Outcome 'timed_out'):
hermes kanban --board kanban-story-4 create "Langer Import" \
    --assignee backend-dev --max-runtime 30m
```

`spawn_failed`, `timed_out` und `crashed` zählen alle auf denselben
Fehlerzähler des Circuit Breakers. Ein Task, der dreimal in eine Zeitschranke
läuft, wird also genauso blockiert wie einer, der dreimal nicht startet.

---

## Das solltest du sehen

```bash
hermes kanban --board kanban-story-4 list --tenant ops
hermes kanban --board kanban-story-4 diagnostics
ls workspace/reports/
```

- Der Breaker-Task auf `blocked`, drei Runs, letzter `gave_up`.
- Der gesperrte Task auf `ready`, ein Run, danach nur `respawn_guarded`.
- Der Crash-Task auf `done`, zwei Runs: `crashed`, dann `completed`.
- Elf Dateien in `workspace/reports/`: zehn Kategorien plus `SUMMARY.md`.

**In der Oberfläche:** Diese Story ist die terminal-lastigste. Beide grafischen
Oberflächen zeigen die Karten in *Blocked* bzw. *Ready* und im Drawer die Runs
mit ihren Outcomes — aber keine hat ein Gegenstück zu
`hermes kanban diagnostics`, und den Unterschied zwischen „wartet auf den
Dispatcher" und „ist durch die Respawn-Sperre stillgelegt" siehst du dort
nicht. Für Fehlersuche gilt: Terminal.

---

## Aufräumen

```bash
hermes kanban --board kanban-story-4 list --tenant ops --json \
  | jq -r '.[].id' | xargs hermes kanban --board kanban-story-4 archive
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

⚠ `backend-dev` wird auch von Story 1 und Story 3 benutzt. Arbeitest du
parallel daran, nimm `--keep-profiles`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --max-retries N` | Circuit Breaker für diese Karte |
| `hermes kanban create … --max-runtime 30m` | Laufzeitdeckel; danach SIGTERM/SIGKILL, erneut in die Queue |
| `hermes kanban diagnostics` | Aktive Probleme mit Handlungsvorschlag — **findet die Respawn-Sperre nicht** |
| `hermes kanban show <id> --json \| jq -r '.events[].kind'` | Event-Kette; verrät `respawn_guarded` |
| `hermes kanban runs <id>` | Outcomes: `spawn_failed`, `gave_up`, `crashed`, `timed_out` |
| `hermes kanban reclaim <id>` | Claim eines hängenden Workers freigeben |
| `hermes kanban unblock <id>` | Nach `gave_up` zurück nach `ready` |
| `hermes kanban notify-subscribe/-list/-unsubscribe` | Gateway-Benachrichtigung zu Endzuständen |
| `hermes config get kanban.failure_limit` | Standardschwelle des Breakers |
| `hermes -p <profil> doctor` | Profil prüfen, wenn `diagnostics` es vorschlägt |
