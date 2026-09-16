# Wo landet das Ergebnis einer Kanban-Karte?

**Stand:** 15.09.2026 · Geprüft am Quelltext der **installierten v0.21.2 (2026.9.11)**
in `~/.hermes/hermes-agent/` — nicht an der im Repo festgeschriebenen v0.20.0.
Beide Fälle zusätzlich **real gemessen**: `scratch` an Karte `t_075937a7`,
`dir` an `t_582dbca2`, `t_41dc0447` und drei Karten der v4-Leiter.

Praktische Umsetzung im Orchestrator-Profil:
[`05-hermes-central-orchestrator/`](../05-hermes-central-orchestrator/README.md).

**Ausgangsfrage:** Eine über den Orchestrator erstellte Karte lief sauber durch,
die Ergebnisdatei lag danach aber nicht im Arbeitsverzeichnis des ausführenden
Profils. Wo wird definiert, wohin das Ergebnis geschrieben wird?

---

## Kurzantwort

Das Ziel definiert **die Karte**, nicht das Profil — über die Spalten
`workspace_kind` und `workspace_path` in `tasks`.

| `workspace_kind` | Arbeitsverzeichnis des Workers | Nach `complete` |
|---|---|---|
| `scratch` (Default) | `~/.hermes/kanban/workspaces/<task-id>/` | **gelöscht**; `artifacts=[…]` werden vorher in den Attachment-Store gerettet |
| `dir` | `workspace_path` (muss absolut sein) | **bleibt erhalten**, aber kein Attachment-Eintrag |
| `worktree` | Linked Git-Worktree | nur entfernt, wenn nachweislich ohne offene Arbeit |

Gültige Werte: `kanban_db.py:98`. Default `scratch`: `kanban_db.py:1271-1272`,
Schema-Default `:863`. Pfadauflösung: `kanban_db_workspace.py:493-530`.

**Das `terminal.cwd` des Profils greift für Karten nicht.** Ein Profil *hat* ein
Arbeitsverzeichnis — `hermes -p summarizer config get terminal.cwd` liefert etwa
`./hermes-working/summarizer`. Für Kanban-Worker ist es aber wirkungslos: der
Dispatcher überschreibt `TERMINAL_CWD` mit dem Workspace der Karte
(`hermes_cli/kanban_db_dispatch.py:2239-2240`, Kommentar: *„the workspace is where
the task's work actually happens"*). Das ist Absicht, kein Fehler — ohne die
Klammer würden relative Schreibvorgänge im Home des Gateway-Nutzers landen und
Worker dessen `AGENTS.md` laden. Der Worker startet also im Workspace **der
Karte**; ein Profil ist im Übrigen ein eigenes `HERMES_HOME`
(`~/.hermes/profiles/<name>/`) für Konfiguration, Sessions und Logs.

## Der Default-Weg (`scratch`)

1. `create_task` ohne `workspace_kind` → `scratch`.
2. `resolve_workspace()` legt `<board-root>/workspaces/<task-id>/` an — das wird
   das cwd des Workers (`kanban_db_workspace.py:493-509`).
3. `kanban_complete(artifacts=[<abs. Pfad>])` → `_persist_scratch_completion_artifacts()`
   kopiert die Dateien nach `~/.hermes/kanban/attachments/<task-id>/`, *bevor*
   aufgeräumt wird (`kanban_db.py:2745`).
4. `_cleanup_workspace()` löscht das Scratch-Verzeichnis
   (`kanban_db_workspace.py:113-118`: „`scratch` is removed; `worktree` only when
   provably free of work; **`dir` is intentionally preserved**").

Nur Dateien **innerhalb** des Scratch-Verzeichnisses werden kopiert
(`is_relative_to(workspace_root)`); für alles außerhalb bleibt nur der Pfad
vermerkt. Ein `stored_path` unterhalb von `attachments_root` ist also der Beleg,
dass die Rettungskopie wirklich lief.

## Festes Zielverzeichnis erzwingen

```bash
hermes kanban create "Titel" --assignee <profil> --workspace dir:/absoluter/pfad
```

Flag-Syntax: `scratch | worktree | worktree:<path> | dir:<path>`
(`kanban_parser.py:153`). Über den Orchestrator entsprechend
`create_task(workspace_kind="dir", workspace_path="/absoluter/pfad")` —
beide Felder reicht `tools/kanban_tools.py:846` durch. Relative Pfade brechen
bewusst ab (sie würden gegen das cwd des Dispatchers auflösen).

## Zwei Fallen

**a) `default_workdir` allein bewirkt nichts.** Es gibt
`hermes kanban boards set-default-workdir <board> <pfad>` (`kanban_boards.py:146`),
aber `kanban_db.py:1302-1305` erbt es **nur** für `dir` und `worktree`:
„Only persistent kinds inherit the board `default_workdir`: a scratch task
inheriting it would point cleanup at the user's source tree." Für die
Default-Karte (`scratch`) passiert also nichts. Es ist der Fallback-Anker für
`dir`/`worktree`, kein globaler Schalter.

**b) `dir` erzeugt kein Attachment.** `_scratch_workspace()` liefert für `dir`
`None`, die Rettungsfunktion steigt sofort aus, und `_staged_artifacts` wird
ausschließlich in ihr gesetzt (`kanban_db.py:2825`). Die Datei bleibt dauerhaft
liegen, taucht aber nicht an der Karte auf. **Real gemessen** an `t_41dc0447`:
`dir`-Lauf, `done`, null `task_attachments`-Zeilen.

Wer beides will, nimmt im Worker das **CLI**:

```bash
hermes kanban attach $HERMES_KANBAN_TASK <Pfad>     # nimmt einen Pfad
```

Das gleichnamige **Werkzeug** `kanban_attach` nimmt dagegen *keinen* Pfad, sondern
`filename` + `content_base64` (`tools/kanban_tools_schemas.py:291-314`). Ein
Worker, dem man den Pfad-Aufruf aufträgt, scheitert an
`content_base64 is not valid base64` und kodiert die Datei danach von Hand —
gemessen 278 s statt 100 s Laufzeit, dazu ein fehlerhaftes Doppel-Artefakt.

Kurz: `scratch` = flüchtiges Verzeichnis, dafür automatische Konservierung als
Attachment. `dir` = dauerhaftes Verzeichnis eigener Wahl, dafür ist das Anhängen
Holschuld.

## Konsequenz: den Ablageort auf der Karte festlegen

Weil weder das Profil noch ein Board-Schlüssel den Ablageort bestimmt, muss ihn
**die erzeugende Instanz** setzen. Im Orchestrator-Profil dieses Repos ist das
eine Leiter im Systemprompt — erste zutreffende Stufe gewinnt:

| Stufe | Bedingung | `workspace_path` |
|---|---|---|
| 1 | Anfrage nennt einen Zielpfad | dieser Pfad (schlägt auch Stufe 2) |
| 2 | Anfrage übergibt eine Eingabedatei **mit Pfad** | Verzeichnis dieser Datei |
| 3 | sonst | `terminal.cwd` des **Assignees**, zu `$HOME/<Rest>` expandiert |
| 4 | Stufe 3 nicht auflösbar | `scratch` |

Belegt an drei Karten (`t_a43527d0`, `t_8fac3da3`, `t_5c8c8940`): dieselbe
Eingabedatei landet mit und ohne expliziten Zielpfad in zwei verschiedenen
Verzeichnissen. Wortlaut und Messreihen:
[`05-hermes-central-orchestrator/README.md`](../05-hermes-central-orchestrator/README.md)
und dort `PLAN.md`, Abschnitt 18.

Nachsehen, was eine Karte wirklich bekommen hat — ein gut formulierter `body`
ist **kein** Beleg dafür:

```bash
sqlite3 ~/.hermes/kanban.db \
  "SELECT workspace_kind, workspace_path FROM tasks WHERE id='t_xxxxxxxx';"
```

## Formulierungsfalle im Kartentext

Der Prompt der Karte `t_075937a7` sagte „Schreibe das Ergebnis in eine Datei im
Arbeitsverzeichnis". Der Worker hat das korrekt befolgt — gemeint war das
Scratch-Verzeichnis der Karte, gelesen wurde es als „Verzeichnis des Profils".
In Kartentexten besser den absoluten Pfad nennen oder auf das Workspace-Konzept
verweisen, statt „Arbeitsverzeichnis" unqualifiziert zu verwenden.

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Verhalten von `worktree` beim Aufräumen | `_cleanup_worktree_workspace()` nur überflogen |
| Stufe 4 der Leiter (`scratch`-Fallback) | in dieser Installation nicht erreichbar — alle vier Profile haben ein explizites `terminal.cwd` |
| Ob Stufe 2 die `AGENTS.md` neben der Eingabedatei wirklich lädt | aus `kanban_db_dispatch.py:2233-2240` abgeleitet, nicht provoziert |
| Ob der Zeitunterschied 278 s → 100 s allein am Base64-Umweg liegt | je ein Lauf; die Laufzeitstreuung ist groß (58 s vs. 235 s bei identischer Aufgabe) |
| Ob `default_workdir` im `dir`-Fall wirklich greift | Board `default` hat hier keinen gesetzt, also nicht beobachtet |
| Verhalten bei fehlgeschlagener statt abgeschlossener Karte | nur der `complete`-Pfad verfolgt |
