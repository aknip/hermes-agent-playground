# Lint-Bericht: block-semantik-0-20-x

| | vorher | nachher |
|---|---|---|
| ERROR | 0 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

_Ausgefuehrt auf Branch `kb/ingest-block-semantik-0-20-x` (Stand: 8bd9ad0).
Der Linter meldet `BESTANDEN — keine ERROR-Befunde`. Ein Merge ist erlaubt.
Nichts wurde repariert: kein ERROR-Befund, also kein Reparatur-Commit
(`bin/kb_git.py commit` haette mangels Aenderung korrekt abgewiesen).

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| — | — | Keine ERROR-Befunde. Der Branch ist lint-sauber. |

## Nicht repariert

| Datei | Regel | Warum ein Mensch noetig ist |
|---|---|---|
| — | — | Keine ERROR-Befunde offen. |

## Stale-Kandidat fuer Tor 2

| Datei | Befund | Was zu pruefen ist | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | `freshness` | `updated` ist 2026-01-20, also 203 Tage alt (Grenze 180); `version: 0.17.0`. Die Seite ist **nicht** Teil dieses Ingest und wurde hier nicht angefasst. | Pruefen, ob die Aussagen zu Profilen und `config.yaml` unter 0.20.x noch stimmen. Stimmen sie, braucht die Seite ein neues `updated` (menschlich / Ingest). Stimmen Teile nicht mehr, ist das ein Ersatz-Ingest, kein Lint. Kein Prune. |

## Prune-Kandidaten fuer Tor 2

Keine. Der Linter meldet `PRUNE-VORSCHLAG` 0; der einzige stehende Befund ist
der STALE-Kandidat `profile-system.md` oben, der eine menschliche Pruefung und
ggf. ein neues `updated` oder einen Ersatz-Ingest braucht — kein Prune.