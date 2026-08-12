# KONFLIKT-DOSSIER — `block-semantik-0-20-x`

**Lane:** konflikt-dossier · **Datum des Befunds:** 2026-08-11
**Item:** `vault/block-semantik-0-20-x.md` (score 83, route konflikt)
**Speist:** Abschnitt 2 und 3 der Vorlage `proposals/konflikt.md`

Bahnen-Regel: Ich trenne durchgehend, was die **QUELLE sagt**, was ich
**VERIFIZIERT** habe (eigene Beobachtung, lokal nachgemessen), und was ich
**SCHLIESSE** (Inferenz, keine neue Messung). Ich entscheide NICHT — dieses
Dossier soll die Entscheidung für einen Menschen billig machen.

---

## 1. Der Konflikt in einem Satz

Die Wissensbasis (`kanban-block-semantik.md`, Zeile 24) dokumentiert
`hermes kanban block <id> --reason "…"`; die verifizierte Realität ab 0.20.0
ist, dass `block` den Grund **positional** nimmt und **kein** `--reason`-Flag
kennt. Auf derselben Seite fehlen zudem vier Ergänzungen (Position von `--kind`,
`--initial-status blocked` = Spalte/kein Tor, `--kind` = Typangabe/keine
Haltekraft, Ereignisname `block_loop_detected` + Zähler `block_recurrences`),
die gegen dieselbe 0.19.0-Seite laufen.

---

## 2. Die beiden Aussagen, direkt gegenübergestellt

### Kern-Widerspruch: Syntax von `block`

| | Was die Wissensbasis sagt | Was die Quelle sagt |
|---|---|---|
| **Aussage (wörtlich)** | `hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"` | „`hermes kanban block` nahm den Grund bereits seit **0.20.0 positional**; die Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist korrigiert." — offizieller Changelog 0.20.1 |
| | | „Das gibt es **nicht**. Der Befehl bricht mit `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument: `hermes kanban block <id> "brauche eine Entscheidung"`." — Transkript, Zeitmarke 00:03:12 |
| **Fundstelle** | `wiki/pages/kanban-block-semantik.md:24` | `sources/releases/changelog-0.20.1.md` Z.16-18 (2026-08-06); `sources/transcripts/2026-08-08-block-semantik.md` Z.13-20 (2026-08-08) |
| **Datiert auf** | `updated: 2026-06-02` | 2026-08-06 bzw. 2026-08-08 |
| **Bezieht sich auf Version** | 0.19.0 | 0.20.0 / 0.20.1 |
| **Status der Seite** | `aktuell` | — |
| **Quellenart** | Wiki-Seite (Nachbau aus `hermes-docs/kanban.md`, Stand 2026-06; nur Doku) | offizieller Changelog + gemessene Live-Demo |

### Die vier fehlenden Ergänzungen (gleiche Seite, gegen denselben Bestand)

| # | Aussage der Quelle | Wörtlicher Quelle | Fundstelle | Seite dazu |
|---|---|---|---|---|
| B | `--kind` muss **vor** der Kartennummer stehen; dahinter bricht `block` ab | „`--kind` muss **vor** der Kartennummer stehen." / „`hermes kanban block --kind needs_input <id> …`" | changelog-0.20.1.md Z.18; Transcript Z.22-27 | Z.24-26 zeigt `block`/`schedule`/`unblock` ohne `--kind`; die Arten-Tabelle Z.35-40 nennt `--kind` als Wert, nie die Position → **fehlt** |
| C | `--initial-status blocked` setzt nur die **Spalte**, erzeugt **kein** `blocked`-Ereignis, ist **kein Tor**; nur echtes `block`/`kanban_block()` hält | „`--initial-status blocked` die Spalte setzt, aber **kein** `blocked`-Ereignis erzeugt, und deshalb kein Tor ist." | changelog-0.20.1.md Z.12-14; Transcript Z.36-42 („parkt, hält") | Seite erwähnt `--initial-status` gar nicht (`kanban-board.md` Z.25-38 nennt die Spalte `blocked`, nicht das Verhalten) → **fehlt** |
| D | `--kind` ist eine **Typangabe, keine Haltekraft**; Block ohne `--kind` hält genauso | „`--kind` ist eine **Typangabe**, keine Haltekraft." | Transcript Z.44-48 | Seite Z.35-40/44 führt Typen und Worker-Pfad auf, schweigt zur Haltekraft → **fehlt** |
| E-Detail | Ereignis der Schleife heißt `block_loop_detected`, Zähler `block_recurrences` je Block-Art, Reset **nur bei erfolgreichem Abschluss** | „… das ausgelöste Ereignis `block_loop_detected` heißt und Zähler und Grenze im Payload trägt" | changelog-0.20.2.md Z.9-15 | Z.48-52 deckt nur den Triage-Weg ab (dort `abgedeckt`), nicht Ereignisname/Zähler → **fehlt** (Detail-Ebene) |

> B, C, D und die Detail-Ebene von E sind **Ergänzungen, kein Widerspruch**. Sie
> stecken im selben Item, weil sie dieselbe Seite betreffen und aus demselben
> 0.20.x-Vorgang stammen. Für die Route entscheidend ist nur der Kern-Widerspruch
> in Zeile 24.

---

## 3. Was ich VERIFIZIERT habe (eigene Messung, lokal)

Ich habe die Prüf-Befehle selbst auf der installierten Hermes-Installation
ausgeführt: `hermes --version` → **Hermes Agent v0.20.0 (2026.8.3)**.

- `hermes kanban block --help`
  → `positional arguments: task_id, reason` · Optionen `-h/--help`, `--ids`,
  `--kind {capability,dependency,needs_input,transient}` — **kein** `--reason`.
- `hermes kanban block 999 --reason "test"`
  → `hermes: error: unrecognized arguments: --reason test` (bricht VOR dem
  Task-Lookup ab; 999 wird nie geprüft).
- `hermes kanban block --kind needs_input 999 "r"`
  → `kanban: unknown task 999` — Syntax wird akzeptiert, scheitert erst am
  Task-Lookup. ⇒ `--kind` VOR der Kartennummer ist gültig.
- `hermes kanban block 999 --kind needs_input "r"`
  → Argparse-Fehler (Usage-Dump, bricht ab). ⇒ `--kind` HINTER der Kartennummer
  ist ungültig.

Das deckt sich exakt mit dem Transkript (00:03:12) und dem Changelog 0.20.1.
NICHT lokal nachgemessen: Aussagen C, D, E-Detail (erfordern vollständiges
Board/Dispatcher-Setup) — dort stütze ich mich auf offiziellen Changelog +
gemessene Demo, nicht auf eigene Messung.

---

## 4. Warum sich das nicht auflösen lässt, ohne zu entscheiden

Die Faktenlage ist einseitig: drei unabhängige Belege — offizieller Changelog
0.20.1, gemessene Live-Demo (Transkript 00:03:12) und meine eigene lokale
CLI-Messung auf v0.20.0 — sagen dasselbe (Grund positional, kein `--reason`).
Die Seite ist schlicht älter (0.19.0 / 2026-06) und trägt zu Unrecht
`status: aktuell`. Die Entscheidung ist also **leicht**, aber sie bleibt eine
**Entscheidung**, aus drei Gründen:

1. **Prune.** Die falsche Zeile 24 zu entfernen/ersetzen ist ein Prune
   (Löschen einer falschen Aussage aus der Wissensbasis). Nach `AGENTS.md` §6
   entscheidet Prune **ausschließlich ein Mensch am Tor 2** — kein Agent darf
   das eigenmächtig.
2. **Status-Neuzuweisung.** Die Seite steht auf 0.19.0/`aktuell`. Statt sie
   stillschweigend zu ersetzen, kann ein Mensch auch `status: strittig` setzen
   und beide Aussagen mit Datum stehen lassen (Alternative bei `modify`).
3. **Umfang.** Neben dem Widerspruch sind B/C/D/E-Detail reine Ergänzungen der
   Seiten (`kanban-block-semantik.md`, bei C auch `kanban-board.md`). Ob sie
   im selben Zug mitkorrigiert werden oder nur der Kern-Widerspruch, ist eine
   Reichweiten-Entscheidung des Menschen.

Es gibt keinen weiteren Befehl, der die Frage noch offener machen könnte — die
Entscheidung ist eine über Status/Reichweite, nicht über die Wahrheit.

---

## 5. Wie sich der Konflikt prüfen lässt (kopierbar)

Der entscheidende, eindeutige Test ist die Syntax-Ausführung gegen eine
beliebige (nicht existierende) Kartennummer — beide Ausgänge sind klar
unterscheidbar und der Befehl ist gefahrlos (bricht vor dem Task-Lookup ab):

```bash
hermes kanban block 999 --reason "test"
```

**Erwartet, wenn die QUELLE recht hat (positional, kein `--reason`):**
```
hermes: error: unrecognized arguments: --reason test
```
→ das Flag wird abgewiesen; die Kartennummer wird nie geprüft (Messung:
genau diese Ausgabe, v0.20.0).

**Erwartet, wenn die WISSENSBASIS recht hat (`--reason` existiert):**
```
kanban: unknown task 999
```
→ `--reason "test"` würde als gültiges Flag geparst, `999` als task_id; der
Befehl käme erst am Task-Lookup an. (Tritt nicht auf.)

Zweiter, schneller Blick auf die Argument-Definition:

```bash
hermes kanban block --help
```

- **Quelle recht:** `positional arguments: task_id, reason` — und `--reason`
  taucht nicht unter den Optionen auf (Messung: genau so, v0.20.0).
- **Wissensbasis recht:** ein Eintrag `--reason REASON` unter `options:`.

Zusatz-Befund für die Ergänzungen (B), ebenfalls gefahrlos und lokal gemessen:

```bash
hermes kanban block --kind needs_input 999 "r"   # -> kanban: unknown task 999  (Syntax OK)
hermes kanban block 999 --kind needs_input "r"   # -> Parse-Fehler (Syntax kaputt)
```

---

## 6. Erwartet für den Vorschlag (Inferenz, keine Festlegung)

Aus dem Dossier folgt für die Vorlage `proposals/konflikt.md` (Abschnitt 2/3),
nicht als Entscheidung meinerseits, sondern als Befundlage:
- Die Seite hat den Fehler; die Quellen sind einseitig und hochbelastbar
  (offizieller Changelog + gemessene Demo + lokale Messung).
- Der Ingest würde Zeile 24 **ersetzen** (positionale Syntax), `updated` und
  `version` nachziehen (0.19.0 → 0.20.x), und B/C/D/E-Detail als Ergänzung
  derselben Seite aufnehmen.
- `Prune`-Charakter der falschen Zeile: entscheidet Tor 2; `modify`-Alternative:
  `status: strittig` mit beiden Aussagen.

---

## Anhang: beteiligte Dateien

- `sources/releases/changelog-0.20.1.md` — 2026-08-06, Zeilen 12-20
- `sources/releases/changelog-0.20.2.md` — 2026-08-09, Zeilen 9-15
- `sources/transcripts/2026-08-08-block-semantik.md` — 2026-08-08, Z.13-20, 22-27, 36-48, 50-61
- `wiki/pages/kanban-block-semantik.md` — 0.19.0, updated 2026-06-02, Z.24-26, 35-44, 48-52
- `wiki/pages/kanban-board.md` — 0.20.0, updated 2026-07-28, Z.25-38 (zu C)
- Eigenmessung auf lokaler Installation: Hermes Agent v0.20.0 (2026.8.3)
