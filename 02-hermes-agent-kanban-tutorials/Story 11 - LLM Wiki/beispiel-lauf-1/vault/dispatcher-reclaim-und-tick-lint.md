# Lint-Bericht: dispatcher-reclaim-und-tick

| | vorher | nachher |
|---|---|---|
| ERROR | 0 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

Branch `kb/ingest-dispatcher-reclaim-und-tick`. Lint vom 2026-08-11.
Keine Änderungen an `bin/kb_lint.py` oder `wiki/AGENTS.md` vorgenommen — die
Arbeitsliste stammt ausschließlich aus `bin/kb_lint.py wiki --json`.

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| — | — | Keine ERROR-Befunde. Die geänderten Seiten `pages/gateway-und-dispatcher.md` und `log/ingest-log.md` validieren fehlerfrei (Frontmatter, Abschnittsreihenfolge, Verlinkung, Größe, Index). |

## Nicht repariert

| Datei | Regel | Warum ein Mensch nötig ist |
|---|---|---|
| — | — | Keine. `errors_after` = 0. |

## Prune-Kandidaten für Tor 2

| Datei | Was verschwinden würde | Befund | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | nichts (Prune-Vorschlag) | `STALE` (freshness): `updated 2026-01-20` ist 203 Tage alt (Grenze 180). Seite referenziert `version: 0.17.0` und Quellenstand 2026-01. Der Befund ist **vorbestehend** und stammt nicht aus diesem Ingest (letzter Zugriff über Ingest skills-system, `b1ca3be`); ich habe die Seite in diesem Branch **nicht angefasst**. | Kein Prune — Prüfung erbeten, ob die Aussagen noch `aktuell` sind. Trifft das zu, benötigt die Seite nur ein neues `updated` (Entscheidung Tor 2, nicht Lint). Trifft eine Aussage nicht mehr zu (z. B. Dispatchregeln unter 0.20.x), ist das ein Folge-Ingest zur Ersetzung. |

## Anmerkung zum Item-Wortlaut

Der Rückweisung des Ingestors folgend wurde die Aussage des Changelogs,
`kanban.dispatch_stale_timeout_seconds` sei pro Profil überschreibbar, **nicht**
aufgenommen. Für mich ergibt das keine Lint-Befunde: die Aussage erscheint
weder in `pages/gateway-und-dispatcher.md` noch im Index, also verletzt ihre
Abwesenheit keinen Vertrag. Nichts zu tun.

Der einzige `STALE` (profile-system) ist Folgestufen-Arbeit und koerperlich
nicht Teil dieses Items; er ist hier nur als Befund dokumentiert, damit die
Commit-Stufe ihn nicht versehentlich dem Ingest zurechnet.