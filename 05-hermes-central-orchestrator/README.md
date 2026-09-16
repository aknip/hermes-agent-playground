# 05 — Zentraler Orchestrator für das Kanban-Board

Ein Profil `orchestrator`, das **Aufgaben entgegennimmt und daraus Karten macht** —
es löst nichts selbst. Jede Karte bekommt einen Assignee (ein real existierendes
Profil), einen vollständigen `body` und einen **festen Ablageort** für das Ergebnis.

**Stand:** 15.09.2026 · Hermes Agent **v0.21.2 (2026.9.11)**, macOS.

> ⚠ **Versionsabweichung zur Repo-Konvention.** `CLAUDE.md` schreibt das Repo auf
> v0.20.0 fest; installiert ist v0.21.2. Alle Zeilenangaben hier und in
> [`PLAN.md`](PLAN.md) stammen aus dem Quellcode der **installierten** Version
> unter `~/.hermes/hermes-agent/`.

## Dateien

| Datei | Inhalt |
|---|---|
| `SOUL.orchestrator.md` | Der Systemprompt. Master — wird nach `~/.hermes/profiles/orchestrator/SOUL.md` kopiert. Aktuell **v4**, 136 Zeilen. |
| `PLAN.md` | Aufbau, Messreihen, Modellauswahl, Fehlschläge. Die Langfassung. |
| `README.md` | Diese Übersicht. |

Der Systemprompt ist **nicht** optional: ohne ihn erledigt der Orchestrator die
Aufgabe selbst, statt eine Karte anzulegen — mit der generischen `SOUL.md` kam im
Test die fertige Zusammenfassung zurück und das Board blieb leer
(`PLAN.md`, Abschnitt 9).

```bash
cp 05-hermes-central-orchestrator/SOUL.orchestrator.md \
   ~/.hermes/profiles/orchestrator/SOUL.md
```

## Benutzung

**Per Chat** (der übliche Weg):

```bash
hermes -p orchestrator chat --oneshot -Q -q "erstelle zusammenfassung für: <URL> \
  => speichere im Arbeitsverzeichnis des ausgewählten Profils"
```

Antwort ist ausschließlich die Kartenliste — Id, Titel, Assignee, Abhängigkeiten,
Ablageort. Danach übernimmt der Dispatcher.

**Per Triage:** eine Karte in der Spalte `triage` anlegen; der Orchestrator
fächert sie in Kindkarten auf und die Wurzelkarte wacht auf, wenn alle fertig
sind (`PLAN.md`, Abschnitt 8).

**Läuft kein Dispatcher**, passiert nach dem Anlegen nichts. Ein Durchlauf:

```bash
hermes kanban dispatch          # ein Durchgang, kein Dauerlauf
hermes kanban daemon            # Dauerschleife (--interval, Default 60 s)
```

## ⚠ Wo die Ergebnisse landen

Das ist die Stelle, an der am meisten schiefgeht, deshalb hier zuerst der Kern:

**Ein Profil hat für Kanban-Karten kein wirksames Arbeitsverzeichnis.** Zwar
trägt jedes Profil ein `terminal.cwd` — der Dispatcher überschreibt `TERMINAL_CWD`
aber mit dem Workspace der Karte (`hermes_cli/kanban_db_dispatch.py:2239-2240`).
Maßgeblich sind allein `workspace_kind` und `workspace_path` **auf der Karte**.

Die `SOUL` v4 vergibt deshalb für **jede** Karte einen Ablageort, nach einer
Leiter — die erste zutreffende Stufe gewinnt:

| Stufe | Bedingung | Ablageort |
|---|---|---|
| 1 | Anfrage nennt einen Zielpfad | dieser Pfad — schlägt auch Stufe 2 |
| 2 | Anfrage übergibt eine Eingabedatei **mit Pfad** | Verzeichnis dieser Datei |
| 3 | sonst | `terminal.cwd` des **Assignees**, zu `$HOME/<Rest>` expandiert |
| 4 | Stufe 3 nicht auflösbar | `scratch` (flüchtig, Rettung als Attachment) |

Stufe 1 bis 3 setzen `workspace_kind="dir"`. Ein im Chat **eingefügter** Text ohne
Pfad ist Stufe 3, nicht Stufe 2.

Nachsehen, was eine Karte tatsächlich bekommen hat:

```bash
sqlite3 ~/.hermes/kanban.db \
  "SELECT workspace_kind, workspace_path FROM tasks WHERE id='t_xxxxxxxx';"
```

Ein hübsch formulierter `body` ist **kein** Beleg dafür, dass die Felder gesetzt
wurden — nur diese Abfrage ist es.

### Zwei Folgen, die man kennen muss

**Keine Karten-Anhänge mehr.** Weil jede Karte `dir` ist, entsteht kein
`task_attachments`-Eintrag (nur der `scratch`-Pfad rettet Artefakte in den
Attachment-Store). Die Provenienz bleibt über `metadata["artifacts"]` und die
`completed`-Ereignisnutzlast. Wer den Anhang will:

```bash
hermes kanban attach $HERMES_KANBAN_TASK <Pfad>     # im Worker, nimmt einen Pfad
```

Das **Werkzeug** `kanban_attach` nimmt dagegen *keinen* Pfad, sondern `filename` +
`content_base64` (`tools/kanban_tools_schemas.py:291-314`). Ein Worker, der es mit
einem Pfad versucht, kodiert die Datei von Hand — in einer Messung 278 s statt
100 s Laufzeit, plus ein fehlerhaftes Doppel-Artefakt (`PLAN.md`, Abschnitt 18).
Die `SOUL` verbietet den Aufruf deshalb ausdrücklich.

**Stufe 2 zieht Fremdkontext.** Das Verzeichnis der Eingabedatei wird zum cwd des
Workers; eine dort liegende `AGENTS.md` lädt er als Kontext mit.

Hintergrund und Quellenlage:
[`00-hermes-FAQ/Hermes-Kanban-Persistenz.md`](../00-hermes-FAQ/Hermes-Kanban-Persistenz.md).

## Konfiguration

**Root** (`~/.hermes/config.yaml` — *nicht* im Profil):

```yaml
kanban:
  orchestrator_profile: orchestrator
  default_assignee: claude-dev
  auto_decompose: true
```

**Profil** `orchestrator`: Modellblock, `platform_toolsets` für `cli` und
`telegram` je mit `kanban`, und `SOUL.md`. Ein Profil ist nur dispatchbar, wenn
seine `config.yaml` alle vier Modell-Schlüssel trägt.

## Fallstricke

- **`assignee` muss ein existierendes Profil sein.** Ein erfundener Name wird
  stillschweigend angenommen, aber nie ausgeführt — die Karte bleibt liegen.
- **Der `body` ist alles, was der Worker sieht.** Er kennt weder den Chat noch
  Geschwisterkarten. Steht der zu bearbeitende Text im Chat, muss er vollständig
  in den `body`.
- **Rollentreue ist nicht garantiert.** Je nach Modell erledigt der Orchestrator
  die Aufgabe doch selbst (`PLAN.md`, Abschnitte 13 und 16).
- **Laufzeiten streuen stark.** Zwei identische Aufgaben lagen bei 58 s und 235 s.
  Einzelvergleiche taugen nicht als Beleg.
