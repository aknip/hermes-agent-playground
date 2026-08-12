# ⚠ Ingest-Vorschlag: KONFLIKT — Kanban-Block-Korrektur: Grund positional statt --reason, --kind-Reihenfolge, Haltekraft, initial-status, Schleifendetail

**Slug:** `kanban-block-semantik-korrektur` · **Route:** `konflikt` · **Punkte:** 91/100
**Branch (geplant):** `kb/ingest-kanban-block-semantik-korrektur`

> Dieser Vorschlag ist **kein** Update. Die neue Information **widerspricht**
> einer bestehenden Seite. Eine der beiden Aussagen ist falsch, und welche das
> ist, entscheidet ein Mensch.

## 1. Die beiden Aussagen, direkt gegenübergestellt

| | Was die Wissensbasis sagt | Was die Quelle sagt |
|---|---|---|
| **Aussage** | `hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"` | `hermes kanban block <id> "brauche eine Entscheidung"` — Grund ist **positional**; `--reason` existiert für `block` nicht. Für eine Art: `hermes kanban block --kind needs_input <id> "…"` — `--kind` muss **vor** der Kartennummer stehen, sonst bricht es ab. |
| **Fundstelle** | `pages/kanban-block-semantik.md:24` | `changelog-0.20.1.md` Z.16–18 (Offizieller Changelog); `2026-08-08-block-semantik.md` [00:03:12] (gemessene Demo); lokal gegen v0.20.0 am CLI gemessen (MESS) |
| **Datiert auf** | `updated: 2026-06-02` | Changelog 2026-08-06 · Transkript 2026-08-08 · CLI-Test 2026-08-11 |
| **Bezieht sich auf Version** | 0.19.0 | 0.20.0 / 0.20.1 |
| **Quellenart** | offizielle Doku (`hermes-docs/kanban.md`) | offizieller Changelog + gemessene Demo + selbst gemessenes CLI-Verhalten |

**Konflikt-Dossier:** `vault/kanban-block-semantik-korrektur-konflikt.md`

## 2. Warum sich das nicht auflösen lässt, ohne zu entscheiden

Die Wissensbasis dokumentiert eine `block`-Syntax (`--reason`), die am CLI
**nicht** existiert und dort mit `unrecognized arguments` abbricht. Changelog
0.20.1, das Transkript 2026-08-08 **und** eine eigene Messung gegen die lokal
installierte Hermes v0.20.0 belegen übereinstimmend, dass der Grund seit 0.20.0
**positional** ist und `--kind` **vor** der Kartennummer stehen muss. Damit ist
die Seite schlicht älter (v0.19.0-Doku-Stand) und die Entscheidung inhaltlich
eindeutig zugunsten der Quelle — aber es bleibt eine *Entscheidung*, weil die
Seite gerade das Gegenteil des aktuellen Verhaltens behauptet.

Zusätzlich schweigt die Seite zu vier Befunden, die nicht widersprüchlich,
sondern Lücken sind (F2 `--kind`-Reihenfolge, F3 `--initial-status blocked` =
Spalte ≠ Tor, F4 Haltekraft unabhängig von der Art) und deckt F5
(Schleifenerkennung) unvollständig ab — die gehören in dasselbe Ingest-Paket.

## 3. Wie sich der Konflikt prüfen lässt

Der entscheidende Test ist nicht der Doku-Stand, sondern das Verhalten des
echten CLI (`999999` = garantiert nicht existierende Karte, keine echte Karte
wird verändert):

```bash
hermes kanban block --help
hermes kanban block 999999 --reason test
```

**Erwartet, wenn die Quelle recht hat:** unter `positional arguments` stehen
`task_id` und `reason`; unter `options` gibt es **kein** `--reason`; die
Seitensyntax bricht ab mit `hermes: error: unrecognized arguments: --reason
test`. — Genau das wurde am 2026-08-11 gegen v0.20.0 beobachtet.
**Erwartet, wenn die Wissensbasis recht hat:** unter `options` stünde ein
`--reason REASON`, und die Seitensyntax liefe bis zur Task-Prüfung durch.

## 4. Was der Ingest tun würde, wenn du zustimmst

| Seite | Änderung |
|---|---|
| `pages/kanban-block-semantik.md` | Die falsche Aussage (Z. 24 `block <id> --reason …`) wird **ersetzt**, nicht ergänzt: korrekt `block <id> "…"` sowie der Typfall `block --kind needs_input <id> "…"` |
| `pages/kanban-block-semantik.md` | F2–F4 ergänzen (`--kind` vor id; `--initial-status blocked` = Spalte, kein Tor, „parkt ≠ hält"; Haltekraft unabhängig von der Art), F5 vervollständigen (`block_loop_detected` + Zähler/Grenze) |
| `pages/kanban-block-semantik.md` | `updated: 2026-06-02` → `2026-08-11`; `version: 0.19.0` → `0.20.2`; `sources` ergänzen um die Changelogs 0.20.1/0.20.2 und das Transkript; `status: aktuell` bleibt |

**Prune:** Der widerlegte Z.-24-Absatz (`block <id> --reason`) wird entfernt.
Das ist ein Prune und entscheidet ausschließlich Tor 2 — siehe AGENTS.md 6.
**Alternative bei `modify`:** `status: strittig` setzen und beide Aussagen mit
Datum stehen lassen.

## 5. Rubrik

| Dimension | Punkte | Begründung |
|---|---|---|
| neuheit | 18/25 | Seite existiert, aber die CLI-Doku (`block --reason`) ist falsch und mehrere Mechaniken fehlen |
| quellenvertrauen | 20/20 | offizieller Changelog UND gemessene Demo, zwei sich deckende Quellen |
| themenbezug | 25/25 | direkt das Tor-/Block-Konzept, auf dem diese Pipeline beruht |
| versionsrelevanz | 15/15 | klare Korrektur der aktuellen Version |
| klarheitsgewinn | 13/15 | korrigiert dokumentierte-aber-falsche Syntax; Kern (unblock, Schleife→Triage) steht schon |
| **Summe** | **91/100** | Schwelle 65 |