# Story 5 — Mandantenflotte: ein Profil, viele Kunden

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-5` |
| Profile | `account-manager` |
| Skill | `tenant-journal` |
| Mandanten | `acct-halden`, `acct-nordwind`, `acct-pergament`, `acct-quellwerk`, `acct-steinbach`, `acct-torfhaus` |
| Workspace-Art | `dir:` — pro Mandant ein eigenes Verzeichnis |
| Dauer | ca. 10 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Ein einziger Spezialist bearbeitet **N Kunden**. Nicht N Profile, nicht ein
Flottendienst mit Account-Statusdatenbank — ein Profil, eine Mandantenspalte
und eine Verzeichniskonvention.

```
                      ┌─ acct-halden      → digests/2026-08-10.md
                      ├─ acct-nordwind    → digests/2026-08-10.md
   fleet-tick.sh  ──▶ ├─ acct-pergament   → digests/2026-08-10.md
   (cron, tokenfrei)  ├─ acct-quellwerk   → digests/2026-08-10.md
                      ├─ acct-steinbach   → digests/2026-08-10.md
                      └─ acct-torfhaus    → blockiert (Daten fehlen)

   eine Karte je Kunde · ein Mandant je Karte · ein Workspace je Karte
   alles derselbe Assignee: account-manager
```

Vier Eigenschaften, die diese Bauweise mitbringt und auf die die Story
zusteuert:

| | |
|---|---|
| **Kein Flotten-Runtime** | Der komplette „Flottendienst" sind 59 Zeilen Shell (der Rest von `fleet-tick.sh` ist Kommentar und der Karten-Body). Der Kernel weiß nichts von Flotten. |
| **Fehlerisolation** | Ein Kunde mit kaputten Daten blockiert genau eine Karte. Die anderen laufen durch. |
| **Auditspur je Kunde** | `--tenant acct-halden` filtert Karten, Runs und Events dieses Kunden — 30 Tage später noch. |
| **Horizontale Skalierung** | Ein siebter Kunde ist ein `mkdir`. Der Enumerator zählt ab, er hat keine Liste. |

---

## Schritt 5.1 — Setup

```bash
cd "Story 5 - Tenant Fleet"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh install-cron.sh scripts/fleet-tick.sh
./setup.sh
```

Das legt an:

1. Board `kanban-story-5`.
2. Profil `account-manager` — mit `SOUL.md`, Beschreibung und `config.yaml`.
3. Skill `tenant-journal` im Profil.
4. `workspace/` als frische Kopie von `seed/`.

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
hermes kanban --board kanban-story-5 assignees
```

```console
NAME                  ON DISK   COUNTS
account-manager       yes       (idle)
…
```

Ein API-Key im Profil ist **nicht** nötig — Profile erben die Schlüssel aus
der Umgebung.

---

## Schritt 5.2 — Die Datenräume ansehen

```bash
ls workspace/accounts/
tree -L 2 workspace/accounts/acct-halden 2>/dev/null || find workspace/accounts/acct-halden -type f | sort
```

```console
workspace/accounts/acct-halden/ACCOUNT.md
workspace/accounts/acct-halden/OPEN-ITEMS.md
workspace/accounts/acct-halden/activity.csv
workspace/accounts/acct-halden/inbox/2026-08-09-sam-dashboard.txt
workspace/accounts/acct-halden/inbox/2026-08-09-tobias-ratelimit.txt
workspace/accounts/acct-halden/digests/       ← Ziel
workspace/accounts/acct-halden/logs/          ← Ziel
```

Sechs Kunden, jeder mit demselben Aufbau. Einer davon ist absichtlich kaputt:

```bash
ls workspace/accounts/acct-torfhaus/
```

```console
ACCOUNT.md  OPEN-ITEMS.md  digests  inbox  logs
```

**`activity.csv` fehlt.** Das ist der Ausgangspunkt für die Fehlerisolation
weiter unten — kein Versehen.

---

## Schritt 5.3 — Der Enumerator

Der gesamte „Flottendienst" ist
[`scripts/fleet-tick.sh`](scripts/fleet-tick.sh). Er zählt
`workspace/accounts/*` ab und legt pro Kunde eine Karte an. Der Kern:

```bash
for dir in "$ACCOUNTS"/*/; do
    slug="$(basename "$dir")"
    hermes kanban --board kanban-story-5 create "Tagesdigest $slug ($DAY)" \
        --assignee account-manager \
        --tenant "$slug" \
        --workspace "dir:${dir%/}" \
        --max-retries 1 \
        --idempotency-key "digest-$slug-$DAY" \
        --json \
        --body "…"
done
```

Vier Details, die die Story tragen:

- **`--tenant "$slug"`** — landet als `$HERMES_TENANT` in der Umgebung des
  Workers und wird zur Filterachse für alles Weitere.
- **`--workspace "dir:${dir%/}"`** — jeder Worker sieht nur seinen Kunden. Der
  Pfad **muss absolut sein**; relative Pfade werden abgewiesen.
- **`--idempotency-key "digest-$slug-$DAY"`** — derselbe Kunde am selben Tag
  ergibt dieselbe Karte. Ein zweiter Tick legt nichts doppelt an, sondern gibt
  die vorhandene ID zurück. Ohne das würde ein 4-Stunden-Takt sechsmal am Tag
  dieselbe Arbeit erzeugen.
- **`--max-retries 1`** — der Kunde mit fehlenden Daten soll beim ersten
  Fehlschlag stehen bleiben, nicht zweimal Tokens verbrennen.

Von Hand ausführen:

```bash
./scripts/fleet-tick.sh
```

Real gemessen:

```console
  acct-halden      t_2c4e4155  neu
  acct-nordwind    t_20154916  neu
  acct-pergament   t_109f122f  neu
  acct-quellwerk   t_b9e96799  neu
  acct-steinbach   t_7a746f30  neu
  acct-torfhaus    t_7a74bcf0  neu
fleet-tick 2026-08-10 auf Board kanban-story-5: 6 neu, 0 uebersprungen
```

Noch einmal aufrufen — und nichts passiert:

```console
  acct-halden      t_2c4e4155  (bereits vorhanden)
  …
fleet-tick 2026-08-10 auf Board kanban-story-5: 0 neu, 6 uebersprungen
```

Das Board:

```bash
hermes kanban --board kanban-story-5 list
```

```console
▶ t_2c4e4155  ready     account-manager      [acct-halden]  Tagesdigest acct-halden (2026-08-10)
▶ t_20154916  ready     account-manager      [acct-nordwind]  Tagesdigest acct-nordwind (2026-08-10)
▶ t_109f122f  ready     account-manager      [acct-pergament]  Tagesdigest acct-pergament (2026-08-10)
▶ t_b9e96799  ready     account-manager      [acct-quellwerk]  Tagesdigest acct-quellwerk (2026-08-10)
▶ t_7a746f30  ready     account-manager      [acct-steinbach]  Tagesdigest acct-steinbach (2026-08-10)
▶ t_7a74bcf0  ready     account-manager      [acct-torfhaus]  Tagesdigest acct-torfhaus (2026-08-10)
```

Sechs Karten, **kein** `--parent`: alle stehen sofort auf `ready` und sind
gleichzeitig beanspruchbar.

Bevor du einen Worker startest, kannst du prüfen, wohin ein Task aufgelöst
würde:

```bash
hermes kanban --board kanban-story-5 show t_2c4e4155 | head -6
```

```console
  status:    ready
  assignee:  account-manager
  tenant:    acct-halden
  workspace: dir @ …/Story 5 - Tenant Fleet/workspace/accounts/acct-halden
  max-retries: 1 (task)
```

---

## Schritt 5.4 — Laufen lassen

```bash
./pump.sh
```

`pump.sh` stößt alle 15 Sekunden einen Dispatch-Tick auf **diesem** Board an,
bis nichts mehr offen ist. Im Normalbetrieb macht das der Dispatcher im
Gateway (`hermes gateway start`) — der arbeitet allerdings mit
`kanban.dispatch_interval_seconds` (Standard 60 s) und bedient **alle** Boards.

Real gemessen:

```console
[01] running=6
[02] running=6
[03] running=6
[04] running=6
[05] done=1  running=5
[06] done=4  running=2
[07] done=5  running=1
[08] done=5  running=1
[09] blocked=1  done=5

Nichts mehr offen — Pumpe beendet.
✓ t_2c4e4155  done      account-manager      [acct-halden]  Tagesdigest acct-halden (2026-08-10)
✓ t_20154916  done      account-manager      [acct-nordwind]  Tagesdigest acct-nordwind (2026-08-10)
✓ t_109f122f  done      account-manager      [acct-pergament]  Tagesdigest acct-pergament (2026-08-10)
✓ t_b9e96799  done      account-manager      [acct-quellwerk]  Tagesdigest acct-quellwerk (2026-08-10)
✓ t_7a746f30  done      account-manager      [acct-steinbach]  Tagesdigest acct-steinbach (2026-08-10)
⊘ t_7a74bcf0  blocked   account-manager      [acct-torfhaus]  Tagesdigest acct-torfhaus (2026-08-10)
```

**Alle sechs Worker starteten im selben Tick** und liefen als sechs getrennte
OS-Prozesse nebeneinander. Nach knapp zwei Minuten: fünf fertig, einer
blockiert.

**Läuft bei dir ein Gateway, startet es die Karten auch ohne `pump.sh`** — und
zwar auf jedem Board, auch auf einem gerade neu angelegten. Wenn du Karten
erst anlegen und später ansehen willst, parke sie:

```bash
hermes gateway status
hermes pause          # hält Kanban- UND Cron-Dispatch an
hermes resume
```

---

## Schritt 5.5 — Fehlerisolation

Das ist der Punkt, an dem sich die Bauweise beweist.

```bash
hermes kanban --board kanban-story-5 runs t_7a74bcf0
```

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  blocked       account-manager         2m  2026-08-10 10:07
     → Fehlende Pflichtdatei: activity.csv. Der Karten-Ablauf verlangt
       ACCOUNT.md, OPEN-ITEMS.md, activity.csv …
```

Der Worker hat `kanban_block()` gerufen, statt sich Daten auszudenken. Und —
das ist der eigentliche Punkt — die anderen fünf Karten hat das **nicht
berührt**. Sie liefen im selben Fenster und sind `done`.

Ein Blick auf die Flotte:

```bash
hermes kanban --board kanban-story-5 stats
```

```console
By status:
  triage    0
  todo      0
  scheduled  0
  ready     0
  running   0
  blocked   1
  done      5

By assignee:
  account-manager       blocked=1, done=5
```

Bei 50 Kunden wäre das die Zahl, die du morgens ansiehst: *49 done, 1 blocked*.

Repariert wird der Kunde außerhalb des Boards, dann kommt die Karte zurück:

```bash
printf 'date,metric,value\n2026-08-09,active_users,7\n' \
  > workspace/accounts/acct-torfhaus/activity.csv
hermes kanban --board kanban-story-5 unblock t_7a74bcf0
./pump.sh
```

Der Task geht nach `ready`, der nächste Tick startet `account-manager` erneut —
als **neuer Run auf derselben Karte**, mit dem Blockgrund des ersten Versuchs
im Kontext.

---

## Schritt 5.6 — Was die Worker produziert haben

```bash
./reset-workspace.sh --diff
```

```console
  Only in …/acct-halden/digests: 2026-08-10.md
  Only in …/acct-halden/logs: journal.jsonl
  Only in …/acct-nordwind/digests: 2026-08-10.md
  Only in …/acct-nordwind/logs: journal.jsonl
  Only in …/acct-pergament/digests: 2026-08-10.md
  Only in …/acct-pergament/logs: journal.jsonl
  Only in …/acct-quellwerk/digests: 2026-08-10.md
  Only in …/acct-quellwerk/logs: journal.jsonl
  Only in …/acct-steinbach/digests: 2026-08-10.md
  Only in …/acct-steinbach/logs: journal.jsonl
  Only in …/acct-torfhaus/logs: journal.jsonl        ← nur das Journal
```

Stichprobe `acct-halden/digests/2026-08-10.md` — jede Zahl stammt aus den
Dateien genau dieses Kunden:

```markdown
# Tagesdigest acct-halden — 2026-08-10

## Lage
Der Vertrag steht auf der Kippe: Tobias Krenz wiederholt, dass Halden ohne
eine belastbare Aussage zum Rate-Limit (Ticket #4471) bis zum 20.08. nicht in
die Verlaengerung des Enterprise-Jahresvertrags geht — "das ist keine Drohung,
das ist Planung". Parallel signalisiert die Nutzung das Problem: aktive Nutzer
sind binnen einer Woche von 58 auf 36 gefallen, waehrend die API-429-Fehler
von 1.204 auf 3.941 gestiegen sind.

## Kennzahlen
- Aktive Nutzer: von 58 (2026-08-03) auf 36 (2026-08-09) — -22 Nutzer (-38 %)
- API-429-Fehler: von 1.204 auf 3.941 — +2.737 (+227 %) binnen einer Woche
…
```

Der Worker hat die Kündigungsandrohung, den Nutzerschwund und die 429-Kurve
verbunden — drei Dateien, ein Befund. Er hat dabei nur seinen eigenen
Datenraum gesehen.

---

## Schritt 5.7 — Die Auditspur je Kunde

Der Mandant ist die Filterachse. Alles, was auf dem Board passiert, lässt sich
darauf einschränken.

**Karten eines Kunden:**

```bash
hermes kanban --board kanban-story-5 list --tenant acct-pergament
```

```console
✓ t_109f122f  done      account-manager      [acct-pergament]  Tagesdigest acct-pergament (2026-08-10)
```

**Ereigniskette einer Karte:**

```bash
hermes kanban --board kanban-story-5 show t_109f122f --json \
  | jq -r '.events[].kind'
```

```console
created claimed spawned heartbeat heartbeat completed
```

**Alle Handoffs eines Kunden über die Zeit:**

```bash
hermes kanban --board kanban-story-5 list --tenant acct-halden --json \
  | jq -r '.[].id' \
  | xargs -I{} hermes kanban --board kanban-story-5 show {} --json \
  | jq -r '"\(.completed_at // "offen")  \(.title)"'
```

Dazu kommt das Journal **im Datenraum selbst** — das überlebt sogar den
Rückbau des Boards:

```bash
cat workspace/accounts/acct-halden/logs/journal.jsonl
```

```json
{"ts": "2026-08-10T10:06:00", "tenant": "acct-halden", "action": "read_inputs", "detail": "ACCOUNT.md, OPEN-ITEMS.md, activity.csv, inbox/… gelesen"}
{"ts": "2026-08-10T10:06:00", "tenant": "acct-halden", "action": "digest_written", "detail": "digests/2026-08-10.md, 2 Nachrichten verarbeitet, 2 offene Tickets, Vertragsblocker #4471"}
```

Auch der blockierte Kunde hat eine Zeile:

```json
{"ts": "2026-08-10T10:09:31", "tenant": "acct-torfhaus", "action": "blocked", "detail": "activity.csv fehlt im Datenraum; Digest nicht erstellt"}
```

Die Journaldisziplin steht nicht im Kernel, sondern in der Skill
[`skills/tenant-journal/SKILL.md`](skills/tenant-journal/SKILL.md), die
`setup.sh` ins Profil legt. Das gilt auch für die Behauptung, das Gedächtnis
des Profils sei „nach Mandant getrennt": **ist es nicht von selbst.** Der
Worker bekommt `$HERMES_TENANT`, und die Skill verpflichtet ihn, alles
Gemerkte damit zu präfixen. Board, Dispatcher und Profil sind geteilt — nur
die Daten sind getrennt, und diese Trennung durchzusetzen ist Aufgabe der
Skill, nicht des Dispatchers.

Kontrolle, dass die Skill wirklich geladen ist:

```bash
hermes -p account-manager skills list
```

```console
│ tenant-journal │          │ local  │ local │ enabled │
```

Pro Karte erzwingen ließe sie sich auch mit
`hermes kanban create … --skill tenant-journal`.

---

## Schritt 5.8 — Zeitsteuerung: der Tick als Cron-Job

Bis hier hast du den Enumerator von Hand gestartet. Im Betrieb macht das ein
Cron-Job.

```bash
./install-cron.sh              # alle 4 Stunden
./install-cron.sh "0 7 * * *"  # jeden Morgen um 7
```

```console
Wrapper angelegt: /Users/…/.hermes/scripts/story5-fleet-tick.sh
  FLEET_ROOT  = …/Story 5 - Tenant Fleet/workspace/accounts
  FLEET_BOARD = kanban-story-5

Created job: a2dd3fcf65c4
  Name: story5-fleet-tick
  Schedule: every 240m
  Mode: no-agent (script stdout delivered directly)
  Next run: 2026-08-10T14:10:51+02:00
```

Zwei Dinge dazu:

- **`hermes cron` führt nur Skripte aus, die unter `~/.hermes/scripts/`
  liegen.** `install-cron.sh` legt dort einen kleinen Wrapper an, der
  `FLEET_ROOT` setzt und den echten Enumerator aufruft — so bleibt
  `scripts/fleet-tick.sh` die einzige Quelle.
- **`--no-agent` heißt: kein Modell.** Das Skript *ist* der Job, sein Stdout
  wird direkt ausgeliefert. Der Enumerator kostet damit **keine Tokens**. Die
  fallen erst bei den Workern an, die der Dispatcher danach startet.

Nicht auf den Zeitplan warten:

```bash
JID=$(jq -r '.jobs[]|select(.name=="story5-fleet-tick")|.id' ~/.hermes/cron/jobs.json)
hermes cron run  "$JID"      # sofort feuern
hermes cron runs "$JID"      # Ausführungshistorie
hermes cron list
```

```console
Triggered job: story5-fleet-tick (a2dd3fcf65c4)
  Ran now: succeeded.

a6c1eea99f78…  completed  job=a2dd3fcf65c4  source=direct  2026-08-10T10:11:11+02:00
```

Und das Ergebnis unter `~/.hermes/cron/output/<job-id>/`:

```console
# Cron Job: story5-fleet-tick
**Mode:** no_agent (script)
---
  acct-halden      t_2c4e4155  (bereits vorhanden)
  …
fleet-tick 2026-08-10 auf Board kanban-story-5: 0 neu, 6 uebersprungen
```

Der Job lief, hat aber nichts doppelt angelegt — genau das soll der
Idempotenzschlüssel bewirken. Am nächsten Tag ändert sich `$DAY` und es
entstehen sechs neue Karten.

Wieder entfernen:

```bash
./install-cron.sh --remove
```

---

## Schritt 5.9 — Horizontal skalieren

Ein siebter Kunde ist ein `mkdir`. Der Enumerator hat keine Kundenliste, er
zählt Verzeichnisse ab.

```bash
mkdir -p workspace/accounts/acct-weiher/{inbox,digests,logs}
printf '# Weiher & Co\n\nMandant `acct-weiher`, Starter, Health gruen.\n' \
  > workspace/accounts/acct-weiher/ACCOUNT.md
printf '# Offene Punkte — Weiher & Co\n\nKeine.\n' \
  > workspace/accounts/acct-weiher/OPEN-ITEMS.md
printf 'date,metric,value\n2026-08-09,active_users,4\n' \
  > workspace/accounts/acct-weiher/activity.csv
printf 'Von: b.weiher@weiher.example\nBetreff: Testfrage\n\nWie exportiere ich einen Bericht als PDF?\n' \
  > workspace/accounts/acct-weiher/inbox/2026-08-09-frage.txt

./scripts/fleet-tick.sh
```

Real gemessen:

```console
  acct-halden      t_2c4e4155  (bereits vorhanden)
  acct-nordwind    t_20154916  (bereits vorhanden)
  acct-pergament   t_109f122f  (bereits vorhanden)
  acct-quellwerk   t_b9e96799  (bereits vorhanden)
  acct-steinbach   t_7a746f30  (bereits vorhanden)
  acct-torfhaus    t_7a74bcf0  (bereits vorhanden)
  acct-weiher      t_a621dfc9  neu
fleet-tick 2026-08-10 auf Board kanban-story-5: 1 neu, 6 uebersprungen
```

Kein zweites Profil, keine Änderung am Enumerator, keine Dispatch-Logik. Von 6
auf 50 Kunden ändert sich an dieser Story genau nichts außer der Anzahl der
Verzeichnisse — und `hermes kanban dispatch --max N`, falls du die Spawns pro
Tick deckeln willst.

Probe wieder wegräumen:

```bash
hermes kanban --board kanban-story-5 list --tenant acct-weiher --json \
  | jq -r '.[].id' | xargs hermes kanban --board kanban-story-5 archive
rm -rf workspace/accounts/acct-weiher
```

---

## Das solltest du sehen

```bash
hermes kanban --board kanban-story-5 stats
hermes kanban --board kanban-story-5 list
./reset-workspace.sh --diff
```

- Sechs Karten, alle mit eigenem Mandanten, alle demselben Profil zugewiesen.
- Fünf auf `done`, `acct-torfhaus` auf `blocked` mit Begründung im Run.
- Je erledigtem Kunden ein `digests/<datum>.md` und ein `logs/journal.jsonl`.
- Beim blockierten Kunden **nur** das Journal — kein halbfertiger Digest.
- `hermes -p account-manager skills list` zeigt `tenant-journal` als `local`.

**In der Oberfläche:** Filtere im Dashboard oben auf einen Mandanten. Die
Spalte *In progress* ist mit „Lanes by profile" nach Assignee unterteilt — bei
dieser Story sind alle sechs Bahnen derselbe `account-manager`, was den Punkt
gut zeigt: die Trennung läuft über den Mandanten, nicht über das Profil.

---

## Aufräumen

Nur die Karten, Board und Profil behalten:

```bash
hermes kanban --board kanban-story-5 list --json \
  | jq -r '.[].id' | xargs hermes kanban --board kanban-story-5 archive
./reset-workspace.sh
```

Alles entfernen:

⚠ **Vorher die Desktop App schließen** (oder im Board-Switcher auf `Default`
schalten). Solange sie dieses Board anzeigt, pollt der Zähler in der
Statusleiste es weiter — auch ohne offene Kanban-Seite — und legt es nach dem
Löschen innerhalb von 60 s als leeres Board neu an.

```bash
./install-cron.sh --remove     # zuerst, sonst legt der Job weiter Karten an
./teardown.sh                  # Board + Profil + Arbeitsdateien
./teardown.sh --keep-profiles  # Board + Arbeitsdateien
./teardown.sh --files-only     # nur Arbeitsdateien
```

`-y` überspringt die Rückfrage. `teardown.sh` entfernt ausschließlich das Board
`kanban-story-5` und das Profil `account-manager` — dein `default`-Board, deine
eigenen Profile und deine Root-Konfiguration bleiben unberührt.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban boards create <slug> --name … --icon …` | Eigenes Board |
| `hermes kanban create … --tenant <name>` | Mandantenraum setzen (→ `$HERMES_TENANT`) |
| `hermes kanban create … --workspace dir:<abs>` | Eigener Datenraum je Karte |
| `hermes kanban create … --idempotency-key <k>` | Doppelanlage über mehrere Ticks verhindern |
| `hermes kanban create … --max-retries N` | Circuit Breaker für diese Karte |
| `hermes kanban create … --skill <name>` | Skill in den Worker erzwingen |
| `hermes kanban list --tenant <name>` | Karten eines Mandanten |
| `hermes kanban stats` | Zählwerte je Status und Assignee |
| `hermes kanban runs <id>` | Versuchshistorie einer Karte |
| `hermes kanban unblock <id>` | Blockierte Karte zurück nach `ready` |
| `hermes kanban dispatch [--max N]` | Ein Tick, optional gedeckelt |
| `hermes cron create <plan> --script <s> --no-agent` | Zeitsteuerung ohne Modellkosten |
| `hermes cron run/runs/list/rm <id>` | Job sofort feuern, Historie, entfernen |
| `hermes pause` / `hermes resume` | Kanban- und Cron-Dispatch anhalten |
| `hermes -p <profil> skills list` | Prüfen, ob die Skill geladen ist |
