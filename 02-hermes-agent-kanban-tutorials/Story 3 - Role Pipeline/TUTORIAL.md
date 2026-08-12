# Story 3 — Rollen-Pipeline mit Block und Retry

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-3` |
| Profile | `pm`, `backend-dev`, `reviewer` |
| Mandant | `reset-feature` |
| Workspace-Art | `dir:` — ein gemeinsames Verzeichnis |
| Dauer | ca. 15 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Hier verdient ein Board sein Geld gegenüber einer flachen Todo-Liste. Ein PM
schreibt eine Spezifikation. Ein Entwickler implementiert sie. Der erste
Versuch wird abgelehnt. Der Entwickler versucht es erneut — und weiß dabei
**genau**, was am ersten Versuch fehlte.

```
Spec: password reset flow  →  Implement password reset flow  →  Review password reset PR
          pm                          backend-dev                      reviewer
                                    (blockiert, dann Retry)
```

Der Kern: **jeder Versuch ist eine eigene Zeile in `task_runs`** mit eigenem
Outcome, Summary und Metadata. Die Retry-Historie wird nicht nachträglich über
einen „aktueller-Zustand"-Task gelegt — sie *ist* die Darstellung.

### Wie der Block reproduzierbar wird

Wann ein Modell von sich aus blockiert, ist nicht steuerbar. Diese Story
erzwingt es über eine Regel im Task-Body, die auf den **Worker-Kontext**
zugreift:

> Sieh nach, ob es bereits frühere Versuche zu diesem Task gibt.
> – **Nein:** implementiere, lies dann `REVIEW-FEEDBACK.md` und rufe
>   `kanban_block()` mit diesen Punkten auf.
> – **Ja:** lies den Block-Grund und arbeite genau diese Punkte ab, dann
>   `kanban_complete()`.

Damit ist der Ablauf deterministisch — **und** die Regel demonstriert
gleichzeitig die Kernaussage: der Worker im zweiten Versuch sieht, warum der
erste scheiterte.

---

## Schritt 3.1 — Setup

```bash
cd "Story 3 - Role Pipeline"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt Board `kanban-story-3`, die drei Profile (mit `SOUL.md`,
Beschreibung, `config.yaml`) und `workspace/` aus `seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an — deshalb schreibt `setup.sh` alle
vier Modell-Schlüssel aus deiner Root-Konfiguration ins Profil.

```bash
hermes kanban --board kanban-story-3 assignees   # pm, backend-dev, reviewer: ON DISK = yes
```

### Die Arbeitsdateien

```
workspace/
├── README.md            erklärt den Mechanismus
├── REVIEW-FEEDBACK.md   die offenen Review-Punkte — der Block-Auslöser
├── spec/                leer — Ziel des PM-Workers
└── auth/reset.py        leerer Stub — Ziel des Engineer-Workers
```

`REVIEW-FEEDBACK.md` — bewusst zwei blockierende und ein nicht-blockierender
Punkt, damit man sieht, ob der Worker unterscheidet:

```markdown
# Review-Feedback zum Passwort-Reset (offen)

Status: **OFFEN** — zwei Punkte blockieren das Merge.

1. **Passwortstärke wird nicht geprüft.**
   `POST /reset` akzeptiert jedes nicht-leere Passwort. Es fehlt eine
   Mindestprüfung (Länge, Trivialpasswörter, Ähnlichkeit zur E-Mail-Adresse).

2. **Der Reset-Link ist nicht single-use.**
   Der Token bleibt bis zum Ablauf (30 Minuten) gültig und kann innerhalb
   dieses Fensters mehrfach eingelöst werden. Er muss beim ersten
   erfolgreichen Reset invalidiert werden.

Nicht blockierend, aber erwünscht:

- Nach erfolgreichem Reset sollten alle aktiven Sessions des Nutzers
  invalidiert werden.
```

`auth/reset.py`:

```python
"""Passwort-Reset — Startdatei des Tutorials.

Der Engineer-Worker aus Story 3 füllt dieses Modul mit den drei Schritten
des Reset-Flows:

    forgot_password(conn, email)        -> versendet einen Reset-Token
    render_reset_form(conn, token)      -> prüft den Token
    apply_reset(conn, token, new_pw)    -> setzt das neue Passwort

Bewusst leer gelassen.
"""

RESET_TOKEN_TTL_SECONDS = 30 * 60
```

Beide Dateien werden von Workern **überschrieben** — deshalb das
unangetastete `seed/` und `reset-workspace.sh`.

---

## Schritt 3.2 — Die Pipeline anlegen

```bash
./create-tasks.sh
source task-ids.env       # setzt BOARD, SPEC, IMPL, REVIEW
```

Wichtig am PM-Task: er wird ausdrücklich angewiesen, die Akzeptanzkriterien
**zusätzlich als Liste ins `metadata` unter `acceptance`** zu legen. Genau
dieses Feld liest der Engineer-Worker später aus dem Eltern-Handoff:

```bash
hermes kanban --board $BOARD create "Spec: password reset flow" \
    --assignee pm --tenant reset-feature --priority 1 \
    --workspace "dir:$PWD/workspace" \
    --body "… Wichtig: lege die Akzeptanzkriterien ZUSÄTZLICH als Liste in
metadata unter dem Schlüssel 'acceptance' ab — der Engineer-Worker liest
genau dieses Feld aus dem Parent-Handoff."
```

---

## Schritt 3.3 — PM und erster Implementierungsversuch

```bash
./pump.sh
```

Der PM-Worker lief in fünf Minuten durch und legte **acht** Akzeptanzkriterien
ab. Danach beförderte die Engine `$IMPL` automatisch von `todo` auf `ready` —
sichtbar als Event `promoted`.

Der Engineer-Worker implementierte dann und blockierte am Ende:

```bash
hermes kanban --board $BOARD runs $IMPL
```

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  blocked       backend-dev             2m  2026-08-10 11:10
     → Review-offene Punkte (aus REVIEW-FEEDBACK.md): 1) Passwortstärke wird
       nicht geprüft – POST /reset akzeptiert jedes nicht-leere Passwort …
       2) Der Reset-Link ist nicht single-use – Token bleibt bis zum Ablauf
       (30 Min) gültig … Nicht blockierend, gewünscht: nach erfolgreichem
       Reset alle aktiven Sessions des Nutzers invalidieren.
```

Beachte den letzten Satz: der Worker hat den **nicht** blockierenden Punkt aus
`REVIEW-FEEDBACK.md` als solchen erkannt und getrennt aufgeführt.

Was der Worker dabei tat (**nicht** von dir eingetippt):

```python
# Worker-Tool-Calls
kanban_show()     # liest die acceptance-Liste aus dem Parent-Handoff
# (implementiert forgot_password / render_reset_form / apply_reset)
kanban_heartbeat(...)   # im Minutentakt — hält den Claim lebendig
kanban_block(
    reason="Review-Feedback … (1) Passwortstärke … (2) nicht single-use …",
)
```

Im Event-Log sieht man die Heartbeats und den Block:

```console
  [11:10] [run 2] claimed {'lock': 'my-mac:…', 'run_id': 2}
  [11:10] [run 2] spawned {'pid': …}
  [11:11] [run 2] heartbeat
  [11:12] [run 2] heartbeat
  [11:12] [run 2] blocked {'reason': 'Review-offene Punkte …', 'kind': None,
                           'recurrences': 1}
```

`[run 2]` ist die **board-globale** `run_id`: auf diesem Board war der PM-Lauf
`[run 1]`. `hermes kanban runs` zählt dagegen je Karte und führt denselben
Versuch als `1`.

Die Heartbeats sind kein Zierrat: ohne sie würde der Dispatcher den Claim nach
`kanban.dispatch_stale_timeout_seconds` für verwaist halten und den Task
zurück in die Queue legen.

**Im Dashboard:** die Karte steht jetzt in *Blocked*, im Drawer steht der
Block-Grund unter dem Outcome von Run 1.

---

## Schritt 3.4 — Entblocken

Du (oder ein separates Reviewer-Profil) liest den Grund, hältst die Richtung
für klar und gibst den Task frei:

```bash
hermes kanban --board $BOARD unblock $IMPL
```

```console
Unblocked t_15ee2e30
```

**Im Dashboard:** „Unblock" im Drawer. **Aus einem Chat heraus:**
`/kanban unblock <id>`.

Der Task geht nach `ready`, der nächste Tick startet `backend-dev` neu — als
**neuer Run auf demselben Task**.

Möchtest du dem Worker zusätzlich etwas mitgeben, kommentiere vorher; der
Kommentar steht im Kontext des nächsten Versuchs:

```bash
hermes kanban --board $BOARD comment $IMPL "Sessions-Invalidierung ist optional, nicht blockierend."
```

---

## Schritt 3.5 — Der Handoff des Fehlversuchs

Bevor du weiterlaufen lässt: sieh dir an, was der zweite Worker vorgesetzt
bekommt.

```bash
hermes kanban --board $BOARD context $IMPL
```

Real gemessen — jetzt stehen **drei** Abschnitte drin:

```console
## Prior attempts on this task
### Attempt 1 — blocked (backend-dev, 2026-08-10 11:10, 2m ago)
Review-offene Punkte (aus REVIEW-FEEDBACK.md): 1) Passwortstärke wird nicht
geprüft … 2) Der Reset-Link ist nicht single-use … Nicht blockierend,
gewünscht: nach erfolgreichem Reset alle aktiven Sessions invalidieren.

## Parent task results
### t_0fb940ff (completed 2m ago)
Spezifikation für den Passwort-Reset in spec/password-reset.md erstellt
(Abschnitte Ziel, Ablauf POST /forgot-password, GET /reset/:token, POST /reset,
Nicht-Ziel) mit 8 testbaren Akzeptanzkriterien. Kriterien zusätzlich als Liste
unter metadata.acceptance abgelegt.
_metadata_: {"acceptance": [
  "POST /forgot-password mit unbekannter E-Mail liefert 200 mit identischem
   Body wie fuer eine bekannte E-Mail und erzeugt keinen Token-Eintrag.",
  "GET /reset/:token liefert 4xx und kein Formular fuer (a) syntaktisch
   unmoeglichen, (b) abgelaufenen (>30 Min), (c) bereits eingeloesten Token.",
  "POST /reset lehnt new_password ab (400) wenn kuerzer als 8 Zeichen, trivial
   (password, 12345678, password123) oder aehnlich zur E-Mail-Adresse …",
  "Token ist single-use: nach erfolgreichem POST /reset liefert ein zweiter
   POST /reset mit demselben Token eine Fehlerantwort …",
  "Nach erfolgreichem POST /reset liefert ein vor dem Reset ausgestellter
   Session-Token 401; andere Nutzer bleiben unberuehrt.",
  "Neu erzeugte Tokens haben min. 128 Bit Entropie (z. B.
   secrets.token_urlsafe(32)) …"],
  "changed_files": ["spec/password-reset.md"],
  "decisions": ["Token-TTL 30 Min via RESET_TOKEN_TTL_SECONDS uebernommen", …]}

## Recent work by @backend-dev
- …
```

Der PM hat **acht** Akzeptanzkriterien abgelegt, nicht die drei, die der
Task-Body mindestens verlangte — und die beiden Punkte aus
`REVIEW-FEEDBACK.md` (Passwortstärke, single-use) sind darunter. Der zweite
Versuch hat damit gefordertes Verhalten *und* Fehlerbefund vor sich.

Der zweite Worker weiß also **ohne Rückfrage**: was gefordert war (PM), was
gefehlt hat (Run 1) und was er selbst zuletzt getan hat.

---

## Schritt 3.6 — Zweiter Versuch und Review

```bash
./pump.sh
```

Real gemessen — beide Versuche derselben Karte:

```console
#    OUTCOME       PROFILE            ELAPSED  STARTED
  1  blocked       backend-dev             2m  2026-08-10 11:10
  2  completed     backend-dev             4m  2026-08-10 11:12
     → Beide blockierenden Review-Punkte in auth/reset.py abgearbeitet und per
       Test verifiziert: (1) Passwortstärke wird in apply_reset über
       _password_strength_error geprüft (Länge >= 8, Trivialpasswörter,
       Ähnlichkeit zur E-Mail-Adresse), (2) Token ist single-use — beim ersten
       erfolgreichen Reset wird reset_tokens.used_at gesetzt und
       _validate_token lehnt eingelöste Token ab. Zusätzlich werden nach
       erfolgreichem Reset alle aktiven Sessions des Nutzers invalidiert.
       REVIEW-FEEDBACK.md auf ERLEDIGT gesetzt. auth/test_reset.py deckt alle
       8 Akzeptanzkriterien ab (25 Assertions, 0 Fehler).
```

Lies die Zusammenfassung von Run 2 daraufhin, **worauf sie sich bezieht**: sie
nennt die zwei Punkte des Blockgrunds namentlich, die acht Kriterien des PM,
und den nicht blockierenden Wunsch als Zugabe. Der zweite Worker hat nicht von
vorne angefangen — er hat abgearbeitet, was Run 1 offengelassen hatte.

Das `metadata` von Run 2, real:

```json
{
  "changed_files": ["auth/reset.py", "REVIEW-FEEDBACK.md", "auth/test_reset.py"],
  "review_iteration": 2,
  "acceptance_covered": 8,
  "tests_run": 25,
  "tests_passed": 25,
  "tests_failed": 0
}
```

Anschließend wird `$REVIEW` automatisch nach `ready` befördert. Der
Reviewer-Worker liest genau dieses `metadata` aus dem Eltern-Handoff und hat
damit die Liste der geänderten Dateien in der Hand, bevor er in einen Diff
schaut. Sein Urteil, real:

```console
  1  completed     reviewer                2m  2026-08-10 11:17
     → Review abgeschlossen: APPROVED. auth/reset.py erfüllt alle 8
       Akzeptanzkriterien aus spec/password-reset.md …
```

```json
{
  "verdict": "approved",
  "acceptance_covered": 8,
  "review_feedback_points_closed": 2,
  "tests_run": 25, "tests_passed": 25, "tests_failed": 0,
  "non_blocking_notes": [
    "AC8 test prueft Entropie direkt ueber secrets statt ueber
     forgot_password-generierten Token (Code korrekt)",
    "Single-use nicht atomar (TOCTOU) - unkritisch in Einzel-Prozess Umgebung"
  ]
}
```

Der Reviewer hat approved **und** zwei Befunde festgehalten, die kein Merge
blockieren. Genau dafür gibt es das `metadata`: das Urteil ist maschinenlesbar,
die Vorbehalte gehen nicht verloren.

---

## Das solltest du sehen

```bash
hermes kanban --board $BOARD list --tenant reset-feature
hermes kanban --board $BOARD runs $IMPL
./reset-workspace.sh --diff
```

```console
✓ t_0fb940ff  done      pm            [reset-feature]  Spec: password reset flow
✓ t_15ee2e30  done      backend-dev   [reset-feature]  Implement password reset flow
✓ t_ff78f375  done      reviewer      [reset-feature]  Review password reset PR
```

- Alle drei Tasks auf `done`, **vier** Runs insgesamt.
- `$IMPL` mit **zwei** Runs: `blocked`, dann `completed`.
- Real entstanden bzw. verändert:

```console
  Files …/seed/REVIEW-FEEDBACK.md and …/workspace/REVIEW-FEEDBACK.md differ  ← auf ERLEDIGT gesetzt
  Files …/seed/auth/reset.py     and …/workspace/auth/reset.py     differ    ← ausgefüllt
  Only in …/workspace: REVIEW-VERDICT.md                                    ← Urteil des Reviewers
  Only in …/workspace/auth: test_reset.py                                   ← 25 Assertions
  Only in …/workspace/spec: password-reset.md                               ← 8 Akzeptanzkriterien
```

Ein Detail, das beim Vergleichen zweier Ausgaben irritiert: `hermes kanban
runs` nummeriert die Versuche **eines Tasks** fortlaufend ab 1, `hermes kanban
show` zeigt dagegen die board-globale `run_id`. Auf diesem Board war der
PM-Lauf `run 1`, der erste Implementierungsversuch `run 2` und der zweite
`run 3` — `hermes kanban runs $IMPL` führt die letzten beiden als `1` und `2`.

### Blockiert oder geplant?

`blocked` heißt „wartet auf einen Menschen", `scheduled` heißt „wartet auf
Zeit". Beide sind nicht dispatchbar, beide kommen mit demselben Befehl zurück:

```bash
hermes kanban --board $BOARD block <id> "brauche Entscheidung von dir"
hermes kanban --board $BOARD schedule <id> "erst nach dem Release am Freitag"
hermes kanban --board $BOARD unblock <id>    # holt BEIDE zurück
```

`unblock` bringt einen Task nach `ready` — oder nach `todo`, falls noch offene
Eltern-Tasks existieren.

---

## Aufräumen

```bash
source task-ids.env
hermes kanban --board $BOARD archive $SPEC $IMPL $REVIEW
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

⚠ `backend-dev` wird auch von Story 1 und Story 4 benutzt, `reviewer` auch von
Story 9. Arbeitest du parallel daran, nimm `--keep-profiles`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --parent <id>` | Abhängigkeit |
| `hermes kanban runs <id>` | **Versuchshistorie** — je Run Outcome, Summary, Dauer |
| `hermes kanban context <id>` | Was der Worker sieht — inkl. `Prior attempts` |
| `hermes kanban block <id> "<grund>"` | Warten auf einen Menschen (Grund **positional**) |
| `hermes kanban schedule <id> "…"` | Warten auf Zeit |
| `hermes kanban unblock <id>` | Zurück nach `ready` bzw. `todo` |
| `hermes kanban comment <id> "…"` | Hinweis, den der nächste Versuch sieht |
| `hermes kanban promote <id…>` | `todo`/`blocked` → `ready` (Notweg) |
| `hermes kanban show <id>` | Event-Log mit Heartbeats und Block-Grund |
| `hermes config get kanban.dispatch_stale_timeout_seconds` | Wann ein Claim als verwaist gilt |
