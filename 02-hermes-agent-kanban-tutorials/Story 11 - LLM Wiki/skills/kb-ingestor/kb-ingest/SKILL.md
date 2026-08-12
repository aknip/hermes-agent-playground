---
name: kb-ingest
description: "Ablauf des Ingest-Schritts fuer den Wissensbasis-Ingestor: Branch mit kb_git.py anlegen, Seiten nach dem Vertrag in wiki/AGENTS.md schreiben oder ersetzen, Index und Ingest-Log nachziehen, den Linter auf die eigene Arbeit anwenden. Enthaelt die Regeln fuer Verdichten statt Kopieren, fuer Ersetzen statt Ergaenzen und fuer den Konfliktfall."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Ingest

Du schreibst in die Wissensbasis. Das ist der einzige Schritt der Pipeline, der
das darf, und er laeuft nur nach einer menschlichen Freigabe, nur auf einem
eigenen Branch.

**Lies zuerst `wiki/AGENTS.md`.** Das ist keine Empfehlung: `bin/kb_lint.py`
prueft deine Arbeit wenige Minuten spaeter Regel fuer Regel gegen genau diese
Datei, und jede Abweichung kommt als Karte zurueck.

## Schritt 1 — Branch

```bash
python3 bin/kb_git.py status
python3 bin/kb_git.py branch kb/ingest-<slug>
```

Weist `branch` ab, ist das eine Auskunft, kein Hindernis:

| Meldung | Bedeutung | Was du tust |
|---|---|---|
| „Arbeitsbaum ist nicht sauber" | ein vorheriger Lauf hat etwas liegen gelassen | `kanban_block` mit der Ausgabe von `status` |
| „es ist noch ein Ingest offen" | ein anderer Ingest arbeitet im selben Arbeitsbaum | `kanban_block` und den fremden Branch nennen |

**Niemals um die Abweisung herumarbeiten.** Zwei Ingests im selben Arbeitsbaum
ueberschreiben sich gegenseitig, und das faellt erst beim Merge auf.

## Schritt 2 — Vorschlag lesen

`vault/<slug>-vorschlag.md` ist dein Auftrag. Der **Wortlaut der menschlichen
Antwort** steht in deinem Karten-Body — lies ihn, nicht nur die
Zusammenfassung. Sagt er etwas anderes als der Vorschlag, gewinnt der Mensch.

Abschnitt „Was NICHT aufgenommen wird" ist bindend. Was dort steht, schreibst
du nicht — auch wenn es interessant ist.

## Schritt 3 — Schreiben

### Ingest ist Verdichten, nicht Kopieren

Das ist die ganze Aufgabe, und sie ist auf eine Weise falsch zu machen, die wie
Erfolg aussieht.

| Changelog-Zeile | Wissen |
|---|---|
| „0.20.1 behebt den Reclaim-Pfad" | „Ein Worker ohne `kanban_heartbeat` konnte zweimal eingesammelt und die Karte doppelt gespawnt werden; der Reclaim ist seit 0.20.1 idempotent." |
| „`--no-agent` hinzugefuegt" | „`hermes cron create … --no-agent` fuehrt das Skript ohne Modell aus: der Tick kostet keine Tokens, die Kosten entstehen erst bei den Workern, die der Dispatcher danach startet." |

Vier Regeln:

1. **Verdichten.** Die Grenze aus `AGENTS.md` 2.3 ist eine Grenze, kein Ziel.
   Wird eine Seite zu lang, wird sie **geteilt** — nicht gekuerzt, bis sie passt.
2. **Bedeutung statt Ereignis.** Nicht „was wurde geaendert", sondern „was gilt
   jetzt".
3. **Datum und Version bleiben.** Undatiertes Wissen kann spaeter niemand
   prunen, weil niemand pruefen kann, ob es noch stimmt.
4. **Ein Fakt, eine Stelle.** Gehoert etwas auf eine andere Seite, verlinke mit
   `[[slug]]`, statt es zu wiederholen.

### Ersetzen, nicht ergaenzen

Loest neues Wissen altes ab, verschwindet das alte **in derselben Aenderung**.

> Eine Seite, die beides sagt, ist schlimmer als eine Seite, die das Falsche
> sagt: der Leser muss jetzt entscheiden und hat dabei weniger Information als
> du hattest.

Ausnahme ist der Konfliktfall unten.

### Route `neue_seite`

- Dateiname `wiki/pages/<slug>.md`, `slug` **gleich** dem Dateinamen ohne `.md`.
- Alle Pflichtschluessel aus `AGENTS.md` 2.1, Abschnitte in der Reihenfolge aus
  2.2.
- **`wiki/index.md` ergaenzen.** Pflicht nach `AGENTS.md` 4 — eine Seite, die der
  Index nicht kennt, ist eine Waise, und der Linter meldet sie.
- Wenn der Vorschlag sagt, dass die neue Seite einen toten Link heilt: pruefe
  danach, dass der Link jetzt aufloest.

### Route `update`

- Nur die betroffenen Abschnitte anfassen.
- `updated` auf das heutige Datum, `version` nachziehen, wenn sich der Bezug
  aendert.
- `sources` um die neue Quelle **erweitern**, die alten stehen lassen.

### Route `konflikt`

Der Vorschlag sagt, **welche der beiden Aussagen gewinnt**. Das hat ein Mensch
entschieden, nicht du.

- Gewinnt die Quelle: die widerlegte Aussage wird **ersetzt**. Der Absatz
  verschwindet. Das ist ein **Prune** — er ist auf dem Branch vorbereitet und
  wird erst an Tor 2 wirksam. Vermerke im Ingest-Log, was entfernt wurde.
- Gewinnt die Seite: nichts wird ersetzt. Vermerke unter `## Quellen`, dass eine
  widersprechende Quelle geprueft und verworfen wurde, mit Datum.
- Sagt die Antwort `modify` mit „strittig": **beide** Aussagen bleiben stehen,
  mit Datum und Quelle, und die Seite bekommt `status: strittig`.

## Schritt 4 — Log

Haenge einen Absatz an `wiki/log/ingest-log.md`, Format aus `AGENTS.md` 7.2,
neueste oben. Die Entscheidung von Tor 1 im Wortlaut. Tor 2 kennst du noch nicht
— dort schreibst du `(offen)`; die Commit-Stufe traegt es nach.

## Schritt 5 — Selbst pruefen

```bash
python3 bin/kb_lint.py wiki
```

**Vor** dem Abschliessen. Es kostet nichts, und es ist der Unterschied zwischen
„sorgfaeltig geschrieben" und „korrekt".

Findet der Linter etwas **an deiner eigenen Arbeit**, behebe es jetzt. Findet er
Altbefunde, die es vorher schon gab: **stehen lassen**. Die naechste Stufe ist
der Linter, und das ist seine Arbeit. Nenne die Zahlen in deiner Summary, damit
sich beides unterscheiden laesst.

## Schritt 6 — Committen (auf DEINEM Branch)

```bash
python3 bin/kb_git.py commit -m "<slug>: <ein Satz, was sich aendert>"
```

Du committest auf `kb/ingest-<slug>`, **nie** auf `main`. Der Commit ist
ungefaehrlich und rueckholbar: Tor 2 entscheidet danach, ob der Branch nach
`main` geht oder verworfen wird.

Warum ueberhaupt, wenn Tor 2 doch noch entscheidet — drei Gruende:

1. **Ohne Commit ist `kb_git.py changed` leer.** Die Commit-Stufe soll dem
   Menschen zeigen, *was* der Branch aendert. Liegt alles nur im Arbeitsbaum,
   kann sie das nicht und muss es aus deiner Summary abschreiben.
2. **Ohne Commit ist deine Arbeit nicht gesichert.** Stirbt ein Worker nach dir,
   raeumt der naechste `branch`-Aufruf einen schmutzigen Arbeitsbaum an.
3. **Mit Commit ist die Kette lesbar.** Ingest und Lint sind zwei Commits, und
   im Git-Log ist danach zu sehen, was der Ingest schrieb und was der Linter
   daran reparieren musste.

⚠ **Der Lauf, aus dem die Beispiele dieser Story stammen, entstand VOR dieser
Regel** — dort liess der Ingestor alles im Arbeitsbaum liegen, und `changed`
meldete an beiden Toren „aendert gegenueber main nichts". Das Ergebnis war
richtig, die Anzeige am Tor aber blind.

## Schritt 7 — Abschluss

Du mergst **nicht**. Das tut die Commit-Stufe nach Tor 2.

```
kanban_complete(
  summary  = "Ingest <slug> auf kb/ingest-<slug>: <n> Seiten neu, <m> geaendert, "
             "<p> Prune vorbereitet. Lint: <e> ERROR (davon <x> vorbestehend).",
  metadata = {"slug":…, "branch":…, "pages_written":[…], "pages_changed":[…],
              "pages_pruned":[…], "index_changed": true|false,
              "lint_errors": <n>, "lint": "pass|fail"},
)
```

## Was du nie tust

- Nach `sources/` schreiben. Rohquellen liegen ausserhalb des Repositorys,
  damit ein falscher Ingest zurueckzunehmen bleibt.
- Eine Quelle erfinden. Jeder `sources:`-Eintrag existiert wirklich unter
  `sources/`.
- Wissen auf eigenes Urteil loeschen. Vorbereiten ja, auf dem Branch. Wirksam
  wird es an Tor 2, durch einen Menschen (`AGENTS.md` 6).
- `main` anfassen, mergen, oder `git` direkt aufrufen.
- Eine Stub-Seite anlegen, nur damit ein Link aufloest.
- Karten anlegen. Lint und Commit existieren bereits als Karten.
