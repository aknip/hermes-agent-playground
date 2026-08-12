---
name: kb-lint
description: "Ablauf des Lint-Schritts fuer die Wissensbasis: bin/kb_lint.py als Arbeitsliste nehmen, ERROR-Befunde reparieren, STALE und Prune-Vorschlaege sammeln ohne zu loeschen, erneut linten und beide Zahlen berichten. Enthaelt die zwei ehrlichen Reparaturen fuer einen toten Link und die Regel, warum der Linter nie angepasst wird."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Lint

Du bist der deterministische Teil dieser Pipeline. Alle anderen Stufen urteilen;
du prüfst. Wo du urteilst, geht es nur darum, **wie** repariert wird — nie
darum, **ob** ein Befund zählt.

## Schritt 1 — Die Arbeitsliste holen

```bash
python3 bin/kb_lint.py wiki --json
```

Das ist die maschinelle Fassung von `wiki/AGENTS.md`. Die Befunde **sind** die
Arbeitsliste. Du fügst keine eigenen hinzu, und du entschuldigst keinen, weil er
harmlos aussieht.

Halte die Zahlen aus diesem ersten Lauf fest: `errors_before`, `stale`,
`prune_candidates`. Sie kommen in den Bericht.

⚠ **Du änderst weder `bin/kb_lint.py` noch `wiki/AGENTS.md`.** Ein Linter, der
angepasst wird, damit er besteht, prüft nichts mehr. Hältst du einen Befund für
falsch, ist das die Behauptung, dass Linter und Vertrag auseinanderlaufen — das
ist ein Fund, kein Hindernis: `kanban_block(reason=…)` mit der Regel-ID und der
Stelle in `AGENTS.md`, die du anders liest.

## Schritt 2 — Die drei Severities sind drei verschiedene Pflichten

| Severity | Pflicht |
|---|---|
| `ERROR` | **Reparieren.** Sperrt den Merge, und ist ohne Entscheidung reparierbar. |
| `STALE` | **Nicht reparieren, nicht löschen.** Als Prune-Kandidat berichten. |
| `PRUNE-VORSCHLAG` | **Sammeln, nie ausführen.** |

### ERROR — die Reparaturen

| Regel | Reparatur |
|---|---|
| `frontmatter-key` | Schlüssel ergänzen. `updated` = Datum der letzten inhaltlichen Änderung, nicht heute, wenn du nur den Schlüssel nachträgst — dann das Datum aus der Historie bzw. aus `## Quellen`. |
| `slug-dateiname` / `slug-form` | Den `slug` an den Dateinamen anpassen, nicht umgekehrt — der Dateiname ist das Linkziel. |
| `abschnitt-reihenfolge` | Abschnitte umstellen. Inhalt bleibt Wort für Wort. |
| `abschnitt-fehlt` | Fehlt `## Quellen`, sind die Quellen aus dem Frontmatter zu übernehmen. Fehlt `## Kurzfassung`, schreibe sie aus dem vorhandenen Inhalt — erfinde nichts dazu. |
| `abschnitt-unbekannt` | Zu `###` herabstufen und unter `## Details` einordnen. |
| `waise` | `[[slug]]` in `wiki/index.md` ergänzen, im passenden Abschnitt. |
| `index-doppelt` | Den zweiten Vorkommen entfernen. |
| `groesse` | **Nicht kürzen.** Teilen (`AGENTS.md` 2.3) — und das ist eine inhaltliche Änderung. Blockiere und sage, wo die Naht liegen sollte. |
| `siehe-auch-form` | Prosa aus `## Siehe auch` nach `## Details` verschieben. |

### `toter-link` — zwei ehrliche Reparaturen, und eine unehrliche

| Weg | Wann |
|---|---|
| **Link entfernen** | Die verlinkte Seite ist nicht geplant. Der Satz wird so umformuliert, dass er ohne den Link vollständig ist. |
| **Seite schreiben** | Der Inhalt existiert als Wissen und gehört ohnehin hierher. |
| ~~Stub-Seite anlegen~~ | **Nie.** `AGENTS.md` 3 nennt einen Stub-Link genau deshalb einen Fehler: eine leere Seite macht den Linter still, ohne die Lücke zu schließen. |

**Sage im Bericht, welchen Weg du gewählt hast, und warum.** Das ist die einzige
Stelle des Lint-Schritts, an der wirklich eine Entscheidung fällt.

### STALE — was du berichtest, statt zu handeln

Sieh die Seite an und berichte, was zutrifft:

- Aussage stimmt noch → braucht ein neues `updated`. **Setze es nicht selbst**:
  ein `updated`, das du auf heute stellst, ohne den Inhalt geprüft zu haben, ist
  eine Lüge im Frontmatter, und danach findet der Linter sie 180 Tage nicht
  wieder.
- Aussage stimmt nicht mehr → braucht Ersatz. Das ist ein Ingest, kein Lint.
- Aussage ist nicht mehr relevant → Prune-Kandidat.

## Schritt 3 — Erneut linten

```bash
python3 bin/kb_lint.py wiki
```

„Ich habe die Befunde behoben" ohne zweiten Lauf ist kein Befund, sondern eine
Hoffnung. `errors_after` kommt aus einem echten Lauf.

## Schritt 3b — Reparaturen committen

Hast du etwas repariert:

```bash
python3 bin/kb_git.py commit -m "lint <slug>: <n> ERROR-Befunde behoben"
```

Auf dem Ingest-Branch, **nie** auf `main`. Ein eigener Commit für die Reparaturen
hält im Git-Log auseinander, was der Ingest geschrieben hat und was daran nicht
dem Vertrag entsprach — und genau das will man beim nächsten Mal wissen.

Hast du nichts repariert, gibt es nichts zu committen; `kb_git.py commit` weist
das dann korrekt ab, und das ist kein Fehler.

## Schritt 4 — Bericht

Nach `vault/<slug>-lint.md`:

```markdown
# Lint-Bericht: <slug>

| | vorher | nachher |
|---|---|---|
| ERROR | <n> | <m> |
| STALE | <n> | <m> |
| PRUNE-VORSCHLAG | <n> | <m> |

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|

## Nicht repariert

| Datei | Regel | Warum ein Mensch nötig ist |
|---|---|---|

## Prune-Kandidaten für Tor 2

| Datei | Was verschwinden würde | Befund | Empfehlung |
|---|---|---|---|
```

Der letzte Block ist der wichtigste: er ist der Text, aus dem die Commit-Stufe
den Grund für Tor 2 baut. Schreib ihn so, dass ein Mensch in einer Zeile sieht,
**was weg wäre**.

## Schritt 5 — Abschluss

```
kanban_complete(
  summary  = "Lint <slug>: ERROR <before>→<after>, STALE <n>, "
             "<p> Prune-Kandidaten. <ein Satz zum größten Befund>",
  metadata = {"errors_before": n, "errors_after": n, "stale": n,
              "prune_candidates": [...], "repaired": [...],
              "unrepaired": [...]},
)
```

Ist `errors_after` größer als null, **muss** die Summary in einem Satz sagen,
warum die restlichen Befunde ohne einen Menschen nicht reparierbar sind.
`bin/kb_git.py merge` wird den Merge dann abweisen — das ist korrektes
Verhalten, nichts, was man wegerklärt.

## Was du nie tust

- Eine Seite, einen Abschnitt oder eine Aussage löschen. Niemals. Prune ist eine
  menschliche Entscheidung (`AGENTS.md` 6). Du schlägst vor.
- `bin/kb_lint.py` oder `wiki/AGENTS.md` ändern.
- Mergen oder `main` anfassen.
- `updated` auf heute setzen, ohne den Inhalt geprüft zu haben.
- Inhalt umschreiben, weil er dir stilistisch nicht gefällt. Du reparierst
  Vertragsverletzungen. Eine schlecht geschriebene Seite, die den Vertrag
  erfüllt, erfüllt ihn.
- Karten anlegen.
