# ⚠ Ingest-Vorschlag: KONFLIKT — Block-Semantik: Seite veraltet und teilweise falsch

**Slug:** `block-semantik-0-20-x` · **Route:** `konflikt` · **Punkte:** 83/100
**Branch (geplant):** `kb/ingest-block-semantik-0-20-x`

> Dieser Vorschlag ist **kein** Update. Die neue Information **widerspricht**
> einer bestehenden Seite. Eine der beiden Aussagen ist falsch, und welche das
> ist, entscheidet ein Mensch.

## 1. Die beiden Aussagen, direkt gegenübergestellt

**Kern-Widerspruch (Zeile 24 der Seite):** was nimmt `hermes kanban block` als
Grund — ein `--reason`-Flag oder einen positionalen Parameter?

| | Was die Wissensbasis sagt | Was die Quelle sagt |
|---|---|---|
| **Aussage** | `hermes kanban block <id> --reason "brauche eine Entscheidung von dir"` | „`hermes kanban block` nahm den Grund bereits seit **0.20.0 positional**; die Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist korrigiert." |
| | | „Das gibt es **nicht**. Der Befehl bricht mit `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument: `hermes kanban block <id> "brauche eine Entscheidung"`." |
| **Fundstelle** | `pages/kanban-block-semantik.md:24` | Changelog-0.20.1.md Z.16-18 (2026-08-06); Transkript 2026-08-08, 00:03:12 |
| **Datiert auf** | `updated: 2026-06-02` | 2026-08-06 bzw. 2026-08-08 |
| **Bezieht sich auf Version** | 0.19.0 | 0.20.0 / 0.20.1 |
| **Quellenart** | Wiki-Seite (Doku-Nachbau aus `hermes-docs/kanban.md`) | offizieller Changelog + gemessene Demo + **lokale CLI-Messung (v0.20.0)** |

Auf derselben Seite fehlen zudem vier reine Ergänzungen, die gegen denselben
Bestand laufen (kein Widerspruch): `--kind` muss **vor** der Kartennummer
stehen (B); `--initial-status blocked` setzt nur die **Spalte**, erzeugt
**kein** `blocked`-Ereignis und ist **kein Tor** (C, berührt auch
`kanban-board.md`); `--kind` ist eine **Typangabe, keine Haltekraft** (D); das
Schleifen-Ereignis heißt `block_loop_detected` mit Zähler `block_recurrences`
je Block-Art (E-Detail). Der Triage-Weg bei Wiederholung (Z.48-52 der Seite)
ist bereits abgedeckt.

## 2. Warum sich das nicht auflösen lässt, ohne zu entscheiden

Die Faktenlage ist einseitig: drei unabhängige Belege — offizieller Changelog
0.20.1, gemessene Live-Demo (Transkript 00:03:12) und eine eigene lokale
CLI-Messung auf v0.20.0 (`block --help` zeigt `positional arguments: task_id,
reason`, kein `--reason`; `block 999 --reason "test"` bricht mit
`unrecognized arguments` ab) — sagen dasselbe. Die Seite ist schlicht älter
(0.19.0) und trägt zu Unrecht `status: aktuell`. Die Entscheidung ist also
**leicht**, aber sie bleibt eine **Entscheidung**, aus drei Gründen: (1) die
falsche Zeile 24 zu ersetzen ist ein **Prune**, und nach AGENTS.md §6 entscheidet
Prune ausschließlich ein Mensch am Tor 2; (2) statt stillschweigend zu ersetzen
kann ein Mensch `status: strittig` setzen und beide Aussagen mit Datum stehen
lassen; (3) die Reichweite (nur der Kern-Widerspruch oder auch die vier
Ergänzungen B–E-Detail) ist eine menschliche Wahl. Es gibt keinen Befehl, der
die Frage noch offener machen könnte — es geht um Status und Reichweite, nicht
um die Wahrheit.

**Konflikt-Dossier:** `vault/block-semantik-0-20-x-konflikt.md`

## 3. Wie sich der Konflikt prüfen lässt

Der entscheidende Test ist gefahrlos (bricht **vor** dem Task-Lookup ab) und
beide Ausgänge sind klar unterscheidbar:

```bash
hermes kanban block 999 --reason "test"
```

**Erwartet, wenn die Quelle recht hat (positional, kein `--reason`):**
```
hermes: error: unrecognized arguments: --reason test
```
→ das Flag wird abgewiesen; die Kartennummer wird nie geprüft (so lokal
gemessen, v0.20.0).

**Erwartet, wenn die Wissensbasis recht hat (`--reason` existiert):**
```
kanban: unknown task 999
```
→ `--reason "test"` würde als gültiges Flag geparst, `999` als task_id; der
Befehl käme erst am Task-Lookup an (tritt nicht auf).

Schneller zweiter Blick auf die Argument-Definition:

```bash
hermes kanban block --help
```
- **Quelle recht:** `positional arguments: task_id, reason` — kein `--reason`
  unter den Optionen (so gemessen).
- **Wissensbasis recht:** ein Options-Eintrag `--reason REASON`.

Zusatz für Ergänzung B (ebenfalls gefahrlos, lokal gemessen):
```bash
hermes kanban block --kind needs_input 999 "r"   # -> kanban: unknown task 999  (Syntax OK)
hermes kanban block 999 --kind needs_input "r"   # -> Parse-Fehler (Syntax kaputt)
```

## 4. Was der Ingest tun würde, wenn du zustimmst

| Seite | Änderung |
|---|---|
| `pages/kanban-block-semantik.md` | Zeile 24: die falsche Syntax `block <id> --reason "…"` wird **ersetzt** durch die positionale Form `block <id> "…"` — nicht ergänzt |
| `pages/kanban-block-semantik.md` | Ergänzungen B (`--kind` vor der Kartennummer), C (`--initial-status blocked` = Spalte, kein Tor), D (`--kind` = Typangabe, keine Haltekraft), E-Detail (`block_loop_detected` + `block_recurrences`) in die Details aufnehmen |
| `pages/kanban-block-semantik.md` | `updated` auf 2026-08-11 und `version` auf 0.20.x nachziehen; `sources` um Changelog + Transkript ergänzen |
| `pages/kanban-board.md` | (nur bei voller Reichweite) zu C: `--initial-status blocked` parkt die Spalte, hält nicht |

**Prune:** Der widerlegte Absatz — die falsche `--reason`-Syntax in Zeile 24 —
wird entfernt. Das ist ein Prune und entscheidet ausschließlich Tor 2 — siehe
AGENTS.md 6.
**Alternative bei `modify`:** `status: strittig` setzen und beide Aussagen mit
Datum stehen lassen.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 16/25 | teils Widerspruchs-Korrektur einer falschen Zeile, teils neue Messwerte (B–D, E-Detail); der Triage-Weg ist bereits bekannt |
| quellenvertrauen | 17/20 | offizieller Changelog 0.20.1/0.20.2 + gemessene Demo + lokale CLI-Messung; unabhängig und konsistent |
| themenbezug | 24/25 | Block-Semantik ist die Mechanik, auf der diese Pipeline selbst ruht; normativ für jeden Tor-Bau |
| versionsrelevanz | 14/15 | betrifft 0.20.0–0.20.2, die aktuelle Linie; die Seite steht auf 0.19.0 und ist überholt |
| klarheitsgewinn | 12/15 | korrigiert eine aktiv falsche Syntax, auf die ein Agent sonst bauen und scheitern würde; ein Teil ist schon bekannt |
| **Summe** | **83/100** | Schwelle 65 |