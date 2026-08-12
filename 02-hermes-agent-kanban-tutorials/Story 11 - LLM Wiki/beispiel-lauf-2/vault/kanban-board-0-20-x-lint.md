# Lint-Bericht: kanban-board-0-20-x

| | vorher | nachher |
|---|---|---|
| ERROR | 0 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

_Ausgefuehrt auf Branch `kb/ingest-kanban-board-0-20-x` (Stand: 30ddf75, der
Ingest-Commit der Elternkarte t_0aabf951; Arbeitsbaum sauber). Dies ist der
RE-SET-Lauf nach dem Discard am Tor 2. Der vorherige Lint hatte den Befund
`index-toter-link [[skills-system]]` ueber den Weg 'Seite schreiben' repariert
und dabei eine neue Seite `pages/skills-system.md` angelegt, die nie durch Tor 1
war — das war das Tor-1-Loch, das den Discard ausloeste. Im aktuellen Stand
tritt dieser Befund **nicht mehr auf**, weil die eigenstaendige, gated
skills-system-Ingest-Kette die Seite inzwischen in `main` geschrieben hat
(`pages/skills-system.md` existiert, `index.md` zeigt auf einen echten Link).
Es gab also keinerlei Anlass, in diesem update-Item eine Seite zu schreiben._

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| — | — | Keine ERROR-Befunde. Es war nichts zu reparieren, daher kein Reparatur-Commit. |

## Nicht repariert

| Datei | Regel | Warum ein Mensch noetig ist |
|---|---|---|
| — | — | Keine ERROR-Befunde offen. Der Branch ist lint-sauber, ein Merge ist erlaubt. |

## Stale-Kandidat fuer Tor 2

| Datei | Befund | Was zu pruefen ist | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | `freshness` | `updated` ist 2026-01-20, also 203 Tage alt (Grenze 180). Aussage: Profile als Assignees, `config.yaml`, Profilbeschreibungen; `version: 0.17.0`. | Die Seite ist **nicht Teil dieses Ingest** (separater Freshness-Check, laut Kartentext nicht anfassen). Pruefen, ob die Aussagen zu Profilen und `config.yaml` unter 0.20.x noch stimmen. Stimmen sie, braucht die Seite ein neues `updated` (menschlich / Ingest). Stimmen Teile nicht mehr, ist das ein Ersatz-Ingest, kein Lint. |

## Weg-Entscheidung fuer tote Links

Dieser RE-SET-Lauf hatte **keinen** toten-Link-Befund zu entscheiden. Der
`[[skills-system]]`-Eintrag in `index.md` ist kein Stub-Link: die Seite existiert
unter `pages/skills-system.md` und wurde von ihrer eigenen Ingest-Kette
(t_a49aaf79→t_02c13c3d→t_d14180d5) geschrieben und in `main` gemerged. Genau
der Fall, der das Tor-1-Loch verursacht hatte, ist hier durch die Parallel-Kette
bereits aufgeloest; es war **keine** 'Seite schreiben'-Reparatur noetig und
**keine** Stub-Seite angelegt.

## Prune-Kandidaten fuer Tor 2

Keine. Der Linter meldet `PRUNE-VORSCHLAG` 0; der einzige staendige Befund ist
der STALE-Kandidat `profile-system.md` oben, der eine menschliche Pruefung und
ggf. ein neues `updated` oder einen Ersatz-Ingest braucht — kein Prune.