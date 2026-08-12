# Lint-Bericht: skills-system

| | vorher | nachher |
|---|---|---|
| ERROR | 4 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

_Ausgefuehrt auf Branch `kb/ingest-skills-system` (Stand: e49faa1, nach
Reparatur-Commit e49faa1). Alle vier ERROR-Befunde waren vorbestehend
(aus dem Seed, nicht aus diesem Ingest) und blockierten die Merge-Pruefung
dieses Branches; sie mussten hier repariert werden, damit der Branch die
Lint-Pruefung besteht._

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| `pages/cron-und-zeitplan.md` | `abschnitt-reihenfolge` | `## Quellen` hinter `## Details` gestellt (Reihenfolge Kurzfassung → Details → Quellen → Siehe auch). Inhalt Wort fuer Wort unveraendert. |
| `pages/kanban-board.md` | `toter-link` | Link `[[kanban-review-agent]]` entfernt. **Weg: Link entfernen.** Der Satz ueber den Review-Agenten (`sdlc-review`, merged oder gibt zurueck) ist ohne den Link vollstaendig; die Details stehen ohnehin im selben Absatz. Eine eigene Seite `kanban-review-agent` ist nicht geplant, das Wissen liegt in der Seite selbst — eine Stub-Seite haette den Linter nur still gemacht (AGENTS.md 3). |
| `pages/memory-system.md` | `frontmatter-key` | Pflichtschluessel `updated` ergaenzt: `2026-08-11` (Datum der letzten inhaltlichen Aenderung = Erzeugung der Seite im Seed, siehe Git-Historie; kein aelteres Datum in `## Quellen`). |
| `index.md` | `waise` | `[[gateway-und-dispatcher]]` im Abschnitt `## Kern` ergaenzt — die Seite existiert unter `pages/`, war aber nicht aus dem Index verlinkt. |

## Nicht repariert

| Datei | Regel | Warum ein Mensch noetig ist |
|---|---|---|
| — | — | Keine ERROR-Befunde offen. |

## Stale-Kandidat fuer Tor 2

| Datei | Befund | Was zu pruefen ist | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | `freshness` | `updated` ist 2026-01-20, also 203 Tage alt (Grenze 180). Aussage: Profile als Assignees, `config.yaml`, Profilbeschreibungen; `version: 0.17.0`. Die Seite ist nicht Teil dieses Ingest, daher hier **nicht** angefasst. | Pruefen, ob die Aussagen zu Profilen und `config.yaml` unter 0.20.x noch stimmen. Stimmen sie, braucht die Seite ein neues `updated` (menschlich / Ingest). Stimmen Teile nicht mehr, ist das ein Ersatz-Ingest, kein Lint. |

## Prune-Kandidaten fuer Tor 2

Keine. Der Linter meldet `PRUNE-VORSCHLAG` 0; der einzige staendige Befund ist
der STALE-Kandidat `profile-system.md` oben, der eine menschliche Pruefung und
ggf. ein neues `updated` oder einen Ersatz-Ingest braucht — kein Prune.
