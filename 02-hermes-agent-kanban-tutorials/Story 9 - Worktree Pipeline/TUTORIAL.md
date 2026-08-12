# Story 9 — Zwei Entwickler, zwei Worktrees, ein Review

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-9` |
| Profile | `planner`, `backend-eng`, `frontend-eng`, `reviewer` |
| Mandant | `ledger-export` |
| Workspace-Art | `worktree:` für die Entwickler, `dir:` für Planung und Review |
| Zusätzlich nötig | `git` |
| Dauer | ca. 25 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Ein Feature end-to-end: spezifizieren, **parallel** implementieren, prüfen. Der
Unterschied zu einer Rollen-Pipeline in einem gemeinsamen Verzeichnis ist der
Workspace: jeder Entwickler bekommt einen **eigenen Git-Worktree auf einem
eigenen Branch**. Sie arbeiten gleichzeitig an derselben Codebasis, ohne sich
ins Gehege zu kommen.

```
                 ┌─▶ backend-eng   (wt/s9-backend)  ─┐
Spezifikation ───┤                                    ├─▶ Review
   planner       └─▶ frontend-eng  (wt/s9-frontend) ─┘   reviewer
   (main)              gleichzeitig, getrennt            (main, liest beide Branches)
```

Und weil sie sich nicht sehen, brauchen sie etwas anderes: **einen Vertrag im
Karten-Body**. Das Frontend kann nicht gegen die Dateien des Backends
programmieren — die existieren in seinem Baum nicht. Das ist keine
Einschränkung, sondern der Punkt.

---

## Schritt 9.1 — Setup

```bash
cd "Story 9 - Worktree Pipeline"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt Board `kanban-story-9`, die vier Profile (jeweils mit `SOUL.md`,
Beschreibung, `config.yaml`) und `workspace/` aus `seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an — `setup.sh` schreibt daher alle vier
Modell-Schlüssel aus deiner Root-Konfiguration ins Profil.

**Besonderheit dieser Story:** `reset-workspace.sh` macht aus `workspace/repo/`
ein echtes Git-Repository mit einem Ausgangscommit. Ein Worktree braucht ein
Repo, an dem er hängen kann.

```console
workspace/ zurueckgesetzt (16 Startdateien aus seed/)
Git-Repo in workspace/repo auf Branch main, Commit 78a95b8
```

### Das Projekt

`workspace/repo/` ist ein winziges Buchhaltungsmodul, ohne Abhängigkeiten außer
der Standardbibliothek:

```
repo/
├── ledger/model.py      Datensatz (Entry) und 10 Beispielbuchungen
├── ledger/reports.py    ein vorhandener Bericht — die Stilvorlage
├── tests/test_reports.py
├── web/index.html       minimale Oberfläche
├── web/app.js
└── web/monthly-totals.txt
```

Der Ausgangscommit enthält bewusst schon einen funktionierenden Bericht.
Beide Entwickler können sich daran orientieren, statt sich etwas auszudenken:

```bash
cd workspace/repo && python3 -m tests.test_reports
```

```console
ok   Anzahl Buchungen: 10
ok   euro negativ: '-634,50'
ok   Saldo Juni: -7067450
…
8/8 Pruefungen bestanden
```

---

## Schritt 9.2 — Die Pipeline anlegen

```bash
./create-tasks.sh
source task-ids.env    # BOARD, TENANT, REPO, SPEC, BACKEND, FRONTEND, REVIEW
```

Die entscheidenden Zeilen aus [`create-tasks.sh`](create-tasks.sh):

```bash
REPO="$HERE/workspace/repo"

# Planung im Hauptbaum — beide Worktrees erben ihre Commits
SPEC=$(hermes kanban --board kanban-story-9 create "Spezifikation: …" \
    --assignee planner --workspace "dir:$REPO" …)

# Zwei Worktrees, zwei Branches, ein gemeinsames Elternteil
BACKEND=$(hermes kanban … create "Backend: CSV-Export im Modul" \
    --assignee backend-eng --parent "$SPEC" \
    --workspace "worktree:$REPO" --branch "wt/s9-backend" …)

FRONTEND=$(hermes kanban … create "Frontend: Exportansicht und Download" \
    --assignee frontend-eng --parent "$SPEC" \
    --workspace "worktree:$REPO" --branch "wt/s9-frontend" …)

# Fan-in, wieder im Hauptbaum
REVIEW=$(hermes kanban … create "Review: beide Branches gegen die Spezifikation" \
    --assignee reviewer --parent "$BACKEND" --parent "$FRONTEND" \
    --workspace "dir:$REPO" …)
```

Zum Workspace-Typ:

| Angabe | Was der Worker sieht |
|---|---|
| `--workspace dir:$REPO` | den Hauptbaum auf `main` |
| `--workspace worktree:$REPO --branch wt/…` | einen eigenen Baum unter `$REPO/.worktrees/<task-id>` auf diesem Branch |

Der Pfad **muss absolut sein** und auf ein Git-Repo(-Root) zeigen. Ohne Pfad
(`--workspace worktree`) müsste das Board einen `default_workdir` haben:

```console
task … has workspace_kind=worktree but no workspace_path, and board '…'
has no default_workdir set.
```

Prüfen, wohin eine Karte aufgelöst würde — **ohne einen Worker zu starten**:

```bash
hermes kanban --board $BOARD show $BACKEND | head -8
```

```console
  status:    todo
  assignee:  backend-eng
  tenant:    ledger-export
  workspace: worktree @ …/Story 9 - Worktree Pipeline/workspace/repo
  branch:    wt/s9-backend
```

Der Baum selbst entsteht erst beim Claim. Wenn du das vorab sehen willst:
`hermes kanban --board $BOARD claim <id>` legt ihn an und druckt den Pfad.

### Der Vertrag

Weil die beiden Entwickler die Dateien des jeweils anderen nicht sehen können,
steht das Datenformat **wörtlich in beiden Karten-Bodys**:

```
Datei: web/ledger-export.csv, erzeugt vom Backend.
Trennzeichen: Komma. Kodierung: UTF-8 ohne BOM. Zeilenende: \n.
Kopfzeile, genau diese Spalten in genau dieser Reihenfolge:

    entry_id,booked_on,account,description,amount_eur,cost_centre

- booked_on im Format YYYY-MM-DD.
- amount_eur als Dezimalzahl mit Punkt als Dezimaltrenner und zwei
  Nachkommastellen, negativ mit führendem Minus (Beispiel: -91200.00).
  Kein Tausendertrennzeichen.
- description wird in doppelte Anführungszeichen gesetzt, wenn sie ein
  Komma enthält.
- Sortierung: aufsteigend nach booked_on, dann entry_id.
```

Dazu die Dateiaufteilung, ebenfalls in beiden Karten:

> Nur diese Dateien gehören dir: … Fass `web/index.html` und `web/app.js`
> **nicht** an — die gehören dem Frontend.

Das ist die Disziplin, die einen sauberen Merge möglich macht. Ob sie
eingehalten wurde, prüft der Reviewer.

---

## Schritt 9.3 — Laufen lassen

```bash
./pump.sh
```

Sobald die Spezifikation `done` ist, starten **beide Entwickler im selben
Tick**. Real gemessen:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  completed     planner                 3m  2026-08-10 10:34
  1  completed     backend-eng            13m  2026-08-10 10:38
  1  completed     frontend-eng            9m  2026-08-10 10:38
  1  completed     reviewer                5m  2026-08-10 10:51
```

Während sie laufen, sieht das Repo so aus:

```bash
git -C workspace/repo worktree list
```

```console
…/workspace/repo                        25a7523 [main]
…/workspace/repo/.worktrees/t_5c532d60  25a7523 [wt/s9-backend]
…/workspace/repo/.worktrees/t_c4b389df  25a7523 [wt/s9-frontend]
```

Drei Arbeitsbäume, drei Branches, ein `.git`. Beide Entwickler starten vom
Commit der Spezifikation — deshalb lief die Planung im Hauptbaum.

---

## Schritt 9.4 — Was parallel entstanden ist

Nach beiden Commits:

```bash
git -C workspace/repo branch -a
git -C workspace/repo diff --stat main..wt/s9-backend
git -C workspace/repo diff --stat main..wt/s9-frontend
```

```console
* main
+ wt/s9-backend
+ wt/s9-frontend

 ledger/export.py      | 59 ++++++++++++++++++++++++++
 ledger/model.py       |  7 +++++
 tests/test_export.py  | 75 ++++++++++++++++++++++++++++++++++
 web/ledger-export.csv | 11 ++++++
 4 files changed, 152 insertions(+)

 web/export.html |  36 +++++++++++++
 web/export.js   | 157 +++++++++++++++++++++++++++++++++++++++++++++++++
 web/index.html  |   1 +
 3 files changed, 194 insertions(+)
```

**Keine einzige Datei in beiden Diffs.** Das ist das Ergebnis der
Dateiaufteilung im Body, nicht des Worktrees — der Worktree verhindert nur,
dass sie sich beim Schreiben in die Quere kommen.

Und der Vertrag hat gehalten, obwohl keiner den anderen sehen konnte:

```bash
git -C workspace/repo show wt/s9-backend:web/ledger-export.csv | head -4
```

```console
entry_id,booked_on,account,description,amount_eur,cost_centre
E-0001,2026-06-03,4000,"Projekt Seehafen, Rate 1",14200.00,PRJ-SEE
E-0002,2026-06-05,6300,Hosting Juni,-1840.00,BETRIEB
E-0003,2026-06-11,6000,Gehaelter Juni,-91200.00,PERSONAL
```

Kopfzeile, Datumsformat, Punkt als Dezimaltrenner, Maskierung des Kommas in
der Beschreibung — genau wie vereinbart. Das Frontend hat unabhängig davon
einen Parser gebaut, der maskierte Felder versteht.

---

## Schritt 9.5 — Fan-in in den Review

Der Reviewer bekommt beide Handoffs in seinem Kontext, mit Branch und Commit:

```bash
hermes kanban --board $BOARD context $REVIEW
```

Er arbeitet auf `main` und liest die Arbeit über git:

```bash
git worktree list
git diff main..wt/s9-backend
git show wt/s9-backend:ledger/export.py
```

**Die Worktrees überleben den Abschluss der Karte.** Das ist verifiziert: der
Reviewer hat die Tests des Backends in dessen Arbeitsbaum tatsächlich
ausgeführt, lange nachdem die Backend-Karte `done` war:

```markdown
## Tests ausgeführt (Backend-Branch, Worktree .worktrees/t_5c532d60)

- `python3 -m tests.test_export`  → 15/15 Prüfungen bestanden (Exit 0).
- `python3 -m tests.test_reports` → 8/8 bestanden (Exit 0; bestehende
  Report-Tests weiterhin grün, kein Regressionseffekt auf `model.py`).
```

Sein Urteil, real entstanden in `REVIEW.md`:

```markdown
## Urteil: APPROVED

Alle 11 Akzeptanzkriterien der Spezifikation sind erfüllt. Der Datenvertrag
(Spaltenreihenfolge, Datumsformat, Betragsformat, Maskierung) ist zwischen
Backend und Frontend konsistent.

## Datenvertrag (Gegenseitencheck)

- Spaltenreihenfolge: Backend `HEADER` == Frontend `HEADERS` in `web/export.js`.
- Betragsformat: Datei bleibt maschinenlesbar (`-91200.00`); Frontend
  formatiert nur für die Anzeige deutsch (`14.200,00`) und liefert beim
  Download die unveränderte Datei.
- Ergebnis: KEINE Formatdifferenz zwischen den Seiten gefunden.

## Einmischung der Branches ineinander

Keine. Backend berührte nur `ledger/export.py`, `ledger/model.py`,
`tests/test_export.py`, `web/ledger-export.csv`. Frontend nur
`web/export.html`, `web/export.js`, `web/index.html`.
```

Und er hat die Abweichung gefunden, die ein Diff allein nicht zeigt:

```markdown
## Offene Punkte (keine Blockierer)

- Strukturelle Abweichung Frontend: Die Spezifikation nennt `web/index.html` +
  `web/app.js` mit statischem Download-Link. Umgesetzt wurde eine separate
  Seite `web/export.html` + `web/export.js`. Funktionell vollständig — daher
  nicht versperrend. Bei Merge-Aufstellung beachten.
```

Das ist der Wert der Rolle: der Backend-Entwickler hat auch `ledger/model.py`
angefasst, obwohl seine Karte diese Datei nicht auflistete. Der Reviewer hat es
gesehen, die bestehenden Tests dagegen laufen lassen und es als unschädlich
eingestuft — mit Beleg statt mit Vermutung.

---

## Schritt 9.6 — Zusammenführen

Das Board hat die Arbeit koordiniert, nicht gemergt. Das machst du:

```bash
cd workspace/repo
git merge --no-ff wt/s9-backend  -m "Merge Backend-Export"
git merge --no-ff wt/s9-frontend -m "Merge Frontend-Export"
python3 -m tests.test_export
python3 -m tests.test_reports
python3 -m http.server -d web 8099    # dann http://localhost:8099/export.html
```

Weil die Diffs disjunkt sind, geht das ohne Konflikt durch.

Worktrees und Branches wieder loswerden:

```bash
git worktree remove --force .worktrees/t_5c532d60
git worktree remove --force .worktrees/t_c4b389df
git branch -D wt/s9-backend wt/s9-frontend
```

`./reset-workspace.sh` macht das ebenfalls, bevor es das Repository neu
aufbaut.

---

## Das solltest du sehen

```bash
hermes kanban --board $BOARD list --tenant ledger-export
git -C workspace/repo worktree list
git -C workspace/repo log --oneline --all
./reset-workspace.sh --diff
```

```console
✓ t_5c532d60  done      backend-eng    [ledger-export]  Backend: CSV-Export im Modul
✓ t_c4b389df  done      frontend-eng   [ledger-export]  Frontend: Exportansicht und Download
✓ t_43522e5f  done      planner        [ledger-export]  Spezifikation: Ledger-Export als CSV
✓ t_3a2f81f5  done      reviewer       [ledger-export]  Review: beide Branches gegen die Spezifikation
```

- Vier Karten auf `done`, vier Runs, kein Fehlversuch.
- Drei Worktrees, drei Branches; `main` trägt Spezifikation und `REVIEW.md`.
- Disjunkte Diffs zwischen den beiden Entwicklerbranches.
- `REVIEW.md` mit Urteil, Kriterien-Belegen und offenen Punkten.

**In der Oberfläche:** beide grafischen Oberflächen zeigen die parallelen
Karten in *In progress* als zwei Bahnen („Lanes by profile"). Den Branchnamen
siehst du im Drawer bei den Task-Details; die Worktrees selbst sieht nur `git`.

---

## Aufräumen

```bash
source task-ids.env
hermes kanban --board $BOARD list --tenant ledger-export --json \
  | jq -r '.[].id' | xargs hermes kanban --board $BOARD archive
./reset-workspace.sh          # löst die Worktrees und baut das Repo neu auf
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

⚠ `planner` wird auch von Story 6 benutzt, `reviewer` auch von Story 3.
Arbeitest du parallel daran, nimm `--keep-profiles`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --workspace worktree:<repo> --branch <name>` | Eigener Git-Worktree je Karte |
| `hermes kanban create … --workspace dir:<repo>` | Hauptbaum (Planung, Review) |
| `hermes kanban create … --parent <id> --parent <id>` | Fan-in beider Entwickler in den Review |
| `hermes kanban boards create <slug> --default-workdir <repo>` | Repo fürs Board, dann reicht `--workspace worktree` |
| `hermes kanban boards set-default-workdir <slug> <pfad>` | dasselbe nachträglich |
| `hermes kanban claim <id>` | Worktree anlegen und Pfad drucken, ohne Worker |
| `hermes kanban show <id>` | Zeigt `workspace: worktree @ …` und `branch:` |
| `hermes kanban context <id>` | Beide Handoffs mit Branch und Commit |
| `git worktree list` / `git diff main..<branch>` / `git show <branch>:<datei>` | Die Arbeit lesen, ohne den Branch auszuchecken |
