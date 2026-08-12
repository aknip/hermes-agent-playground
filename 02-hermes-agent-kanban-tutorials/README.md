# Hermes Kanban — Tutorial für Hermes Agent 0.20.0 auf macOS

Elf eigenständige Tutorials zum Kanban-Board von Hermes Agent. Jede Story
bringt ihr eigenes Setup mit, läuft auf ihrem eigenen Board und lässt sich
einzeln durchspielen und wieder zurückbauen. Es gibt **kein** übergreifendes
Setup — du kannst mit jeder beliebigen Story anfangen.

Alle elf sind auf einer Standard-Installation von **Hermes Agent v0.20.0
(2026.8.3)** unter macOS mit echten Workern durchgespielt worden; die
Konsolenausgaben in den Tutorials unter „Real gemessen" stammen aus diesen
Läufen. Welche Funktionen dabei geprüft wurden und welche **nicht**, steht in
[VERIFIKATION.md](VERIFIKATION.md) — diese Liste gehört zum Ergebnis.

## Die elf Stories

| Story | Worum es geht | Profile | Board |
|---|---|---|---|
| **[1 — Solo Dev](Story%201%20-%20Solo%20Dev/TUTORIAL.md)** | Abhängigkeitskette und strukturierter Handoff | `backend-dev`, `qa-dev` | `kanban-story-1` |
| **[2 — Fleet Farming](Story%202%20-%20Fleet%20Farming/TUTORIAL.md)** | Zwölf unabhängige Tasks auf drei Spezialisten | `translator`, `transcriber`, `copywriter` | `kanban-story-2` |
| **[3 — Role Pipeline](Story%203%20-%20Role%20Pipeline/TUTORIAL.md)** | PM → Engineer → Reviewer, mit Block und Retry | `pm`, `backend-dev`, `reviewer` | `kanban-story-3` |
| **[4 — Circuit Breaker](Story%204%20-%20Circuit%20Breaker/TUTORIAL.md)** | Circuit Breaker, Respawn-Sperre, Crash Recovery | `deploy-bot`, `backend-dev` | `kanban-story-4` |
| **[5 — Tenant Fleet](Story%205%20-%20Tenant%20Fleet/TUTORIAL.md)** | Ein Profil, viele Mandanten, cron-getriebene Erzeugung | `account-manager` | `kanban-story-5` |
| **[6 — Research Triage](Story%206%20-%20Research%20Triage/TUTORIAL.md)** | Fan-out auf Rechercheure, Fan-in in die Analyse, Block mitten im Lauf | `planner`, `researcher`, `analyst`, `writer` | `kanban-story-6` |
| **[7 — Scheduled Briefing](Story%207%20-%20Scheduled%20Briefing/TUTORIAL.md)** | Wiederkehrende Pipeline auf einem langlebigen Vault | `scout`, `editor`, `publisher` | `kanban-story-7` |
| **[8 — Digital Twin](Story%208%20-%20Digital%20Twin/TUTORIAL.md)** | Eine dauerhafte Identität mit eigenem Gedächtnis und Eskalation | `inbox-triage`, `legal` | `kanban-story-8` |
| **[9 — Worktree Pipeline](Story%209%20-%20Worktree%20Pipeline/TUTORIAL.md)** | Parallele Git-Worktrees, Fan-in in den Review | `planner`, `backend-eng`, `frontend-eng`, `reviewer` | `kanban-story-9` |
| **[10 — Triage Pipeline](Story%2010%20-%20Triage%20Pipeline/TUTORIAL.md)** | Autonome Pipeline mit Rubrik, Selbst-Fan-out und genau einem menschlichen Tor | sieben `triage-*`-Profile | `kanban-story-10` |
| **[11 — LLM Wiki](Story%2011%20-%20LLM%20Wiki/TUTORIAL.md)** | Wissensbasis pflegen: ein Vertrag, ein deterministischer Linter, **zwei** menschliche Tore, Branch je Ingest | fünf `kb-*`-Profile | `kanban-story-11` |

Stories 1–4 folgen dem offiziellen
[Kanban-Tutorial](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban-tutorial),
Stories 5–9 den Anwendungsfällen aus Kapitel 8 und 9 der
[v1-Designspezifikation](https://github.com/NousResearch/hermes-agent/blob/main/docs/hermes-kanban-v1-spec.pdf).
Story 10 baut den Multi-Agent-Workflow aus
[tonbistudio/hermes-multi-agent-workflow](https://github.com/tonbistudio/hermes-multi-agent-workflow)
mit Hermes-Bordmitteln nach, Story 11 dessen Fortsetzung für eine
Wissensbasis ([tonbistudio/llm-wiki](https://github.com/tonbistudio/llm-wiki)).

**Story 10 und 11 sind ein Paar.** Story 10 lässt eine Rechnung offen — sie legt
Rubrik, Route und Kettenbau in eine Skill und gibt zu, damit genau das zu tun,
wovor das Original warnt („fat engine, thin skill"). Story 11 zahlt einen Teil
davon: die Form der Wissensbasis liegt dort als Code in einem Linter, und ein
Merge nach `main` ist ohne dessen Zustimmung nicht möglich. Lies 10 zuerst; 11
setzt es nicht voraus, aber der Vergleich ist die halbe Lehre.

Zusätzlich: **[TUTORIAL.md](TUTORIAL.md)** — das Grundmodell, die acht Spalten
des Boards und die vollständige Befehlsreferenz. Nachschlagewerk, kein
Einstieg.

## Wo anfangen?

| Wenn du … | fang an mit |
|---|---|
| noch nie ein Kanban-Board benutzt hast | **Story 1** |
| viele gleichartige Aufgaben parallel fahren willst | **Story 2**, dann **Story 5** |
| eine Übergabe zwischen Rollen brauchst | **Story 3**, dann **Story 9** |
| wissen willst, was bei Fehlern passiert | **Story 4** |
| eine breite Frage aufteilen willst | **Story 6** |
| etwas täglich laufen lassen willst | **Story 7** |
| einen benannten Assistenten mit Gedächtnis willst | **Story 8** |
| eine Pipeline willst, die von selbst läuft und dich einmal fragt | **Story 10** — am besten nach 6 und 7 |
| eine Wissensbasis automatisiert pflegen willst — inklusive Löschen | **Story 11** — am besten nach 10 |
| wissen willst, wie man Determinismus in eine Agenten-Pipeline bekommt | **Story 11**, Schritte 11.3 und 11.4 |

## Voraussetzungen

```bash
hermes --version                    # v0.20.0 (2026.8.3) oder neuer
jq --version                        # falls nicht vorhanden: brew install jq
hermes config get model.default     # muss ein Modell zeigen, nicht leer sein
git --version                       # für Story 9 und 11
python3 --version                   # für Story 11 (nur Standardbibliothek)
```

Mehr braucht es nicht. Board, Profile, Skills und Arbeitsdateien legt jede
Story selbst an. Dein `default`-Board, deine eigenen Profile und deine
Root-Konfiguration (`~/.hermes/config.yaml`) werden nicht angefasst.

## Aufbau eines Story-Verzeichnisses

Alle elf sind gleich gebaut:

```
Story N - …/
├── TUTORIAL.md          das Tutorial dieser Story — hier anfangen
├── setup.sh             Board + Profile + Skills + Arbeitskopie anlegen
├── create-tasks.sh      die Karten anlegen (bzw. breaker.sh / crash.sh /
│                        scripts/fleet-tick.sh / scripts/briefing-tick.sh)
├── pump.sh              Dispatcher-Ticks, bis nichts mehr offen ist
├── gate.sh              Story 10 und 11: die menschlichen Tore beantworten
├── reset-workspace.sh   workspace/ aus seed/ neu aufbauen; --diff zeigt Änderungen
├── teardown.sh          Board + Profile + Arbeitsdateien wieder entfernen
├── profiles/<name>/     SOUL.md und description.txt je Profil
├── skills/<name>/       profil-lokale Skills (nur wo eine Story sie braucht)
├── seed/                unveränderliche Startdateien — der Master
├── workspace/           Arbeitskopie; hier arbeiten die Worker wirklich
└── beispiel-lauf*/      Story 10: `beispiel-lauf/` und `beispiel-lauf-2/`
                        Story 11: `beispiel-lauf-1/`
                        — die Ergebnisse der protokollierten Läufe
```

`workspace/` wird aus `seed/` aufgebaut und lässt sich jederzeit zurücksetzen.
Das ist nötig, weil Worker auch **Startdateien überschreiben** — sonst wäre
eine Story nur einmal durchführbar.

Skripte, die IDs erzeugen, schreiben sie nach `task-ids.env` neben sich; mit
`source task-ids.env` hast du sie in den Folgeschritten zur Hand.

## Zwei Dinge, die für alle Stories gelten

**1. Ein Profil braucht eine `config.yaml`, sonst ist es kein Assignee.**

So prüft Hermes, welche Profile auf der Platte liegen
(`kanban_db.list_profiles_on_disk`):

```python
if (entry / "config.yaml").is_file():
    names.add(entry.name)
```

`hermes profile create` legt `.env`, `SOUL.md` und `profile.yaml` an — **keine
`config.yaml`**. Ein so erzeugtes Profil erscheint in `hermes profile list`,
aber nicht in `hermes kanban assignees`, und Karten für dieses Profil bleiben
ohne Fehlermeldung für immer auf `ready` liegen. Erst `hermes -p <profil>
config set …` legt die Datei an. Jedes `setup.sh` in diesem Repository
erledigt das und prüft danach nach.

**2. Ein laufendes Gateway startet Karten auf jedem Board, auch auf einem
gerade neu angelegten.**

Du kannst eine Karte also nicht „erst anlegen und später ansehen", solange es
läuft:

```bash
hermes gateway status
hermes pause      # hält Kanban- UND Cron-Dispatch an; laufende Arbeit stirbt nicht
hermes resume
```

Alternativ die Karte geparkt anlegen (`--triage`, `--initial-status blocked`)
oder direkt nach dem Anlegen `hermes kanban block <id> "<grund>"`.

⚠ Bei `block` ist der Grund **positional**; `--reason` gibt es dort nicht
(wohl aber bei `unblock`). Und `--initial-status blocked` hält eine Karte
**nicht** dauerhaft an — Details in [Story 10](Story%2010%20-%20Triage%20Pipeline/TUTORIAL.md).

## Die drei Oberflächen — was geht wo?

Es gibt drei Zugänge zum selben Board, und sie sind nicht gleichwertig.

### 1. Terminal (`hermes kanban …`)

Vollständig. Jede Operation ist hier verfügbar, und nur hier gibt es die
Diagnose-Befehle, die in mehreren Stories die eigentliche Lehre tragen
(`context`, `runs`, `diagnostics`, `log`).

### 2. Web-Dashboard (`hermes dashboard` → <http://127.0.0.1:9119>)

```bash
hermes dashboard            # startet, öffnet http://127.0.0.1:9119
hermes dashboard --status
hermes dashboard --stop
```

Links im Menü „Kanban", oben das Board wählen. Diese Oberfläche zeigen die
Screenshots der offiziellen Dokumentation: „Nudge dispatcher", die Pille
„Orchestration: Auto/Manual", „⚗ Decompose", „✨ Specify", „Lanes by profile".

### 3. Desktop-App (`/Applications/Hermes.app`)

Die Desktop-App hat ein **eigenes, neueres** Kanban-Board — sie bettet nicht
das Web-Dashboard ein. Zwei Dinge dazu:

- **Das Kanban-Board ist standardmäßig ausgeschaltet.** Erst einschalten unter
  **Settings ▸ Plugins ▸ Kanban**. Danach erscheint „Kanban" in der linken
  Seitenleiste.
- Es fehlen zwei Knöpfe: es gibt **keinen** expliziten „Nudge
  dispatcher"-Button (ein Dispatch-Anstoß läuft automatisch bei jeder
  Schreiboperation mit) und **kein** „✨ Specify" pro Karte. „Decompose" gibt
  es nur als Auto-Schalter in den Orchestrierungs-Einstellungen, nicht pro
  Karte.

### Matrix

| Funktion | Terminal | Web-Dashboard | Desktop-App |
|---|---|---|---|
| Task anlegen | `kanban create` | „New task"-Dialog | „New task"-Dialog |
| Board ansehen | `kanban list` | Spaltenansicht | Spaltenansicht |
| Status ändern | `kanban promote/block/unblock/archive` | Drag & Drop | Drag & Drop |
| Task-Details | `kanban show` | Drawer rechts | Drawer rechts |
| **Attempt-Historie (Runs)** | `kanban runs` | Drawer ▸ Run History | Drawer ▸ Runs |
| **Worker-Kontext ansehen** | `kanban context` | — | — |
| **Worker-Log live** | `kanban log --tail N` | Drawer ▸ Worker log | Drawer ▸ Worker log |
| **Event-Stream live** | `kanban watch` / `tail` | Drawer ▸ Activity | Drawer ▸ Activity |
| **Aktive Probleme** | `kanban diagnostics` | — | — |
| Dispatcher anstoßen | `kanban dispatch` | „Nudge dispatcher" | automatisch bei Schreibzugriff |
| Auto-Decompose an/aus | `config set kanban.auto_decompose` | „Orchestration"-Pille | Orchestrierungs-Einstellungen |
| Einzelnen Task decomposen | `kanban decompose <id>` | „⚗ Decompose" auf der Karte | — |
| Triage-Task ausformulieren | `kanban specify <id>` | „✨ Specify" auf der Karte | — |
| Board wechseln / anlegen | `kanban boards …` | Board-Auswahl | Board-Auswahl in der Titelleiste |
| Profil-Beschreibungen pflegen | `hermes profile describe` | — | Orchestrierungs-Einstellungen |
| Statistik | `kanban stats` | Zählwerte je Spalte | Zählwerte je Spalte |

**Empfehlung:** Terminal für die Befehle, daneben eine der grafischen
Oberflächen offen, um den Kartenfluss zu sehen. Für Fehlersuche führt kein Weg
am Terminal vorbei.

## Rückbau

Jede Story räumt sich selbst auf:

```bash
cd "Story N - …"
./teardown.sh                  # Board + Profile + Arbeitsdateien
./teardown.sh --keep-profiles  # Board + Arbeitsdateien
./teardown.sh --files-only     # nur Arbeitsdateien
./teardown.sh -y               # ohne Rückfrage
```

⚠ Profile liegen global in `~/.hermes/profiles/`, und einige Namen kommen in
mehreren Stories vor (`backend-dev` in 1/3/4, `reviewer` in 3/9, `planner` in
6/9). Arbeitest du parallel an mehreren Stories, nimm `--keep-profiles`.

Die sieben Profile von Story 10 (`triage-`) und die fünf von Story 11 (`kb-`)
kollidieren mit keiner anderen Story. Story 11 geht dabei einen Schritt weiter:
`setup.sh` legt eine Marke `.story11` in jedes Profil, und `teardown.sh` entfernt
**nur** markierte Profile — ein gleichnamiges Profil aus deinem eigenen Bestand
bleibt stehen.

⚠ Story 11 legt ihre Wissensbasis als **Git-Repository** unter
`workspace/wiki/` an. `teardown.sh` und `reset-workspace.sh` löschen
`workspace/` — willst du das Ergebnis eines Laufs behalten, kopiere es vorher
heraus.

Stories 5, 7, 10 und 11 können zusätzlich einen Cron-Job anlegen (in 10 und 11
optional). Den zuerst entfernen, sonst legt er weiter Karten an:

```bash
./install-cron.sh --remove
```
