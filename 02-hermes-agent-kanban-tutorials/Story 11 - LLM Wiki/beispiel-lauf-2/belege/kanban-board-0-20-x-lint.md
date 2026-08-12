# Lint-Bericht: kanban-board-0-20-x

| | vorher | nachher |
|---|---|---|
| ERROR | 5 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

_Ausgefuehrt auf Branch `kb/ingest-kanban-board-0-20-x` (Stand: f45add9, nach
Reparatur-Commit 8a9fe6b). Alle fuenf ERROR-Befunde waren vorbestehend (aus dem
Seed, nicht aus diesem Ingest)._

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| `pages/cron-und-zeitplan.md` | `abschnitt-reihenfolge` | Abschnitte umgestellt: `## Details` steht jetzt vor `## Quellen` (Reihenfolge Kurzfassung → Details → Quellen → Siehe auch). Inhalt Wort fuer Wort unveraendert. |
| `pages/kanban-board.md` | `toter-link` | Link `[[kanban-review-agent]]` entfernt. **Weg: Link entfernen.** Der Satz ueber den Review-Agenten (`sdlc-review`, merged oder gibt zurueck) ist ohne den Link vollstaendig; die Details liegen ohnehin im selben Absatz. Eine eigene Seite `kanban-review-agent` ist nicht geplant, das Wissen steckt in der Seite selbst — eine Stub-Seite haette den Linter nur still gemacht. |
| `pages/memory-system.md` | `frontmatter-key` | Pflichtschluessel `updated` ergaenzt: `2026-08-11` (Datum der letzten inhaltlichen Aenderung = Erzeugung der Seite im Seed; kein aelteres Datum in `## Quellen` od. Historie). |
| `index.md` | `index-toter-link` | **Weg: Seite schreiben.** `pages/skills-system.md` neu geschrieben, weil der Inhalt als Wissen existiert (Transkript `sources/transcripts/2026-08-07-skills-system.md`, offizielle 0.20.0-Quelle) und dorthin gehoert. Damit zeigt der Index-Eintrag `[[skills-system]]` auf eine echte Seite statt auf einen toten Link. |
| `index.md` | `waise` | `[[gateway-und-dispatcher]]` im Abschnitt `## Kern` ergaenzt — die Seite existiert unter `pages/`, war aber nicht aus dem Index verlinkt. |

## Nicht repariert

| Datei | Regel | Warum ein Mensch noetig ist |
|---|---|---|
| — | — | Keine ERROR-Befunde offen. |

## Stale-Kandidat fuer Tor 2

| Datei | Befund | Was zu pruefen ist | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | `freshness` | `updated` ist 2026-01-20, also 203 Tage alt (Grenze 180). Aussage: Profile als Assignees, `config.yaml`, Profilbeschreibungen; `version: 0.17.0`. Die Page ist nicht Teil dieses Ingest, daher hier **nicht** angefasst. | Pruefen, ob die Aussagen zu Profilen und `config.yaml` unter 0.20.x noch stimmen. Stimmen sie, braucht die Seite ein neues `updated` (menschlich / Ingest). Stimmen Teile nicht mehr, ist das ein Ersatz-Ingest, kein Lint. |

_Hinweis: Abweichend vom Wortlaut der Karte (die `vault/kanban-board-0-20-x-vorschlag.md` nennt) liegt dieser Lint-Bericht unter
`vault/kanban-board-0-20-x-lint.md`, weil `bin/gate.sh` und die kb-pipeline-Stufe 4 genau diese Datei lesen und die
`-vorschlag.md` bereits den Tor-1-Ingest-Vorschlag der Elternkarte enthaelt (wird nicht ueberschrieben)._

## Prune-Kandidaten fuer Tor 2

Keine. Der Linter meldet `PRUNE-VORSCHLAG` 0; der einzige staendige Befund ist der STALE-Kandidat `profile-system.md` oben, der STEMT eine menschliche Pruefung und ggf. ein neues `updated` oder einen Ersatz-Ingest — kein Prune.
