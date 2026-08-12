---
slug: kanban-block-semantik-korrektur
titel: Kanban-Block-Korrektur: Grund positional statt --reason, --kind-Reihenfolge, Haltekraft, initial-status, Schleifendetail
status: ingest
tor1: approve  # 2026-08-11, Mensch (unblock)
tor2: merge  # 2026-08-11, Mensch (unblock --reason merge); PRUNE freigegeben
score: 91
score_breakdown: {'neuheit': 18, 'quellenvertrauen': 20, 'themenbezug': 25, 'versionsrelevanz': 15, 'klarheitsgewinn': 13}
wissensstand: widerspruch
route: konflikt 
gebuendelt_aus: ['changelog-0.20.1.md', 'changelog-0.20.2.md', '2026-08-08-block-semantik.md']
betrifft: ['kanban-block-semantik']
---

## Bewertung (Schwelle 65)
neuheit 18/25: Seite existiert, aber CLI-Doku (block --reason) ist falsch und mehrere Mechaniken fehlen.
quellenvertrauen 20/20: offizieller Changelog UND gemessene Demo, zwei sich deckende Quellen.
themenbezug 25/25: direkt das Tor-/Block-Konzept, auf dem diese Pipeline beruht.
versionsrelevanz 15/15: klare Korrektur der aktuellen Version.
klarheitsgewinn 13/15: korrigiert dokumentierte-aber-falsche Syntax; Kern (unblock, Schleife->Triage) steht schon.
