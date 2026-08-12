# seed/ — die unveränderlichen Startdateien von Story 11

Dies ist der **Master**. Er wird nie beschrieben. Gearbeitet wird in
`workspace/`, das `reset-workspace.sh` aus diesem Verzeichnis aufbaut.

```
ingest.yaml              die EINE Datei mit der Fachlichkeit dieser Pipeline
bin/kb_lint.py           deterministischer Linter — die Code-Fassung von AGENTS.md
bin/kb_git.py            sechs geprüfte Git-Verben, kein freies git für Agenten
proposals/*.md           Vorlagen für Tor 1, eine je Route
intake/                  leer — hier landen die Scout-Berichte
sources/releases/        eingefrorenes Korpus: 3 Changelogs
sources/transcripts/     eingefrorenes Korpus: 3 Transkripte
wiki/                    die Wissensbasis. Wird von reset-workspace.sh zum
                         Git-Repository gemacht (main + ein Initial-Commit).
```

## Die Wissensbasis hat absichtlich Fehler

`wiki/` ist so gebaut, dass `bin/kb_lint.py` **genau fünf** ERROR-Befunde und
**einen** STALE-Befund findet — nicht mehr und nicht weniger. Das ist der
einzige Test dieser Story, der ohne ein Modell auskommt und deshalb bei jedem
Lauf dasselbe Ergebnis liefert:

| Befund | Wo | Was |
|---|---|---|
| `abschnitt-reihenfolge` | `cron-und-zeitplan.md` | `## Quellen` steht vor `## Details` |
| `toter-link` | `kanban-board.md:61` | `[[kanban-review-agent]]` existiert nicht |
| `frontmatter-key` | `memory-system.md` | `updated:` fehlt |
| `index-toter-link` | `index.md:21` | `[[skills-system]]` existiert nicht |
| `waise` | `index.md` | `gateway-und-dispatcher` ist nicht verlinkt |
| `freshness` (STALE) | `profile-system.md` | `updated: 2026-01-20`, 203 Tage alt |

Prüfen:

```bash
cd ..                                    # ins Story-Verzeichnis
python3 seed/bin/kb_lint.py seed/wiki --today 2026-08-11
```

## Das Korpus deckt jeden Ausgang der Pipeline ab

| Quelle | Ausgang |
|---|---|
| `releases/changelog-0.20.1.md` + `changelog-0.20.2.md` + `transcripts/2026-08-08-block-semantik.md` | **gebündelt** zu einem Item, Score 91 |
| `transcripts/2026-08-07-skills-system.md` | über der Schwelle, Score 98 — die Seite fehlt und der Index verlinkt sie schon (`[[skills-system]]`) |
| `releases/release-0.20.0-velocity.md` | **geshelved** — steht schon in `release-historie.md` |
| `transcripts/2026-08-10-community.md` | **keine Kandidaten** — der Scout verwirft Kanal-Neuigkeiten, Ankündigungen und Namensfindung als nicht überprüfbar |

⚠ **Zur letzten Zeile:** Dieses Transkript war als Fall „über die Rubrik unter
die Schwelle gefallen" gedacht. Real gemessen passiert etwas anderes — der Scout
meldet daraus **null** Kandidaten, weil sein Auftrag „überprüfbare Aussage über
Hermes Agent" lautet und Kanal-Neuigkeiten das nicht sind. Das ist korrektes
Verhalten und **kein** blinder Fleck im Sinne von Story 10: dort filtern zwei
Stufen nach *derselben* Frage (ist es wichtig?), hier filtern sie nach
*verschiedenen* (ist es eine Aussage? / ist sie neu und wichtig?).

Der Ausgang „unter der Schwelle" entsteht stattdessen — und zwar reichlich — aus
Kandidaten, die die Wissensbasis **schon kennt**. Real gemessen aus diesem
Korpus: 15 Items, davon **9 mit Score 20** und `status: geshelved`, jedes mit
Fundstelle in der bestehenden Seite. Genau das ist der Beweis des Originals, dass
die Deduplizierung wirkt.

## Die Größenordnung ist selbst eine Lehre

Real gemessen ergab dieses Korpus **6 Items über der Schwelle 65** (Scores 70–98).
Sechs Items bedeuten **zwölf** Torfragen an einen Menschen aus einem einzigen
Sweep. Deshalb hat `ingest.yaml` einen Deckel:

```yaml
rubrik:
  schwelle: 65
  max_pro_lauf: 3      # die besten drei gehen in den Fan-out,
                       # der Rest wird 'zurueckgestellt' (nicht 'geshelved')
```

Die knappe Ressource dieser Pipeline sind nicht Tokens, sondern die
Aufmerksamkeit am Tor.
