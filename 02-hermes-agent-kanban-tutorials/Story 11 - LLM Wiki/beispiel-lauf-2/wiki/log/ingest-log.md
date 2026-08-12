# Ingest-Log

Ein Absatz je Ingest, neueste oben. Format steht in `AGENTS.md`, Abschnitt 7.2.

Dieses Log ist die Antwort auf „warum steht das hier?" — und die einzige Stelle,
an der eine menschliche Entscheidung dauerhaft im Repository steht.

---

## 2026-08-11 · kanban-board-0-20-x · update · 75/100
- **Branch:** `kb/ingest-kanban-board-0-20-x`
- **Entscheidung Tor 1:** modify — „modify: Vier der sechs Aussagen aufnehmen: die swarm-Signatur --worker/--verifier/--synthesizer, die automatische Board-Migration beim ersten Zugriff, diagnostics mit Block-Art (kind) und den Fehlschlag von kanban_create bei relativem workspace_path. WEGLASSEN auf pages/kanban-board.md: (a) 'stats zeigt das Alter der aeltesten ready-Karte in Minuten' und (b) die 'complete a b c --summary'-Sperre. … Die swarm-Signatur in release-historie.md ergaenzen wie vorgeschlagen."
- **Entscheidung Tor 2:** (offen)
- **Seiten:** 0 geschrieben / 2 geaendert / 0 geprunt
- **Quellen:** `release-0.20.0-velocity.md`, `changelog-0.20.1.md`,
  `changelog-0.20.2.md`

Vier der sechs Aussagen aus dem Vorschlag sind auf `kanban-board.md`
aufgenommen — neuer Unterabschnitt „### Befehle und Verhalten in 0.20.x" unter
`## Details`: die swarm-Signatur (`--worker P:T --verifier P --synthesizer P`),
die automatische Board-Migration beim ersten Zugriff, `diagnostics` mit
Block-Art (`kind`) statt nur Grund, und der `kanban_create`-Fehlschlag im
Worker bei relativem `workspace_path`. Die zwei Ausgabe- bzw. Einzelfall-Aussagen
(`stats`-Alter der aeltesten `ready`-Karte, die `complete a b c --summary`-
Sperre) sind bewusst **weggelassen** — die Seite ist die Konzeptseite zum
Board, nicht sein Changelog. Die swarm-Signatur wird in `release-historie.md`
ergaenzt (vorhandene Zeile umgebaut). Index unveraendert; keine neue Seite;
keine Prune-Kandidaten.

## 2026-08-11 · block-semantik-0-20-x · konflikt · 83/100
- **Branch:** `kb/ingest-block-semantik-0-20-x`
- **Entscheidung Tor 1:** approve — „UNBLOCK: approve"
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 0 geschrieben / 2 geaendert / 1 geprunt
- **Quellen:** `changelog-0.20.1.md`, `changelog-0.20.2.md`,
  `sources/transcripts/2026-08-08-block-semantik.md`

Die QUELLE gewinnt: `block <id> --reason "…"` existiert nicht (Grund ist seit
0.20.0 **positional**); die falsche `--reason`-Syntax in Zeile 24 von
`kanban-block-semantik.md` wurde **ersetzt** durch die positionale Form
`block <id> "…"` — ein Prune, entscheidet Tor 2. Daneben die vier
Ergaenzungen derselben Seite (— `--kind` vor der Kartennummer; —
`--initial-status blocked` = nur Spalte, kein Tor; — `--kind` = Typangabe,
keine Haltekraft; — `block_loop_detected` + `block_recurrences`). Bei voller
Reichweite zusaetzlich eine minimale Ergaenzung auf `kanban-board.md` zu
`--initial-status blocked` (parkt Spalte, haelt nicht). Beide Seiten auf
2026-08-11 / 0.20.x nachgezogen.

## 2026-08-11 · skills-system · neue_seite · 88/100
- **Branch:** `kb/ingest-skills-system`
- **Entscheidung Tor 1:** approve — „UNBLOCK: approve"
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 1 geschrieben / 1 geaendert / 0 geprunt
- **Quellen:** `sources/transcripts/2026-08-07-skills-system.md`

Neue Kernseite Skills-System (Struktur einer Skill, drei Herkunfts-Ebenen,
Description-Disclosure, `kanban create --skill`, `skills list`, Skill vs.
MCP). Schliesst den bestehenden Index-Stub `[[skills-system]]`; zusaetzlich
als `## Siehe auch` in `profile-system.md` verlinkt.

## 2026-08-04 · release-historie · update · manuell
- **Branch:** `-` (von Hand gepflegt, vor Einfuehrung der Pipeline)
- **Entscheidung Tor 1:** — (kein Tor, manueller Eintrag)
- **Entscheidung Tor 2:** — (kein Tor, manueller Eintrag)
- **Seiten:** 0 geschrieben / 1 geaendert / 0 geprunt
- **Quellen:** `changelog-0.20.0.md`

Erste Erfassung des 0.20.0-Hauptreleases („Velocity"). Die Patch-Releases
danach sind **noch nicht** erfasst.
## 2026-08-11 · kanban-board-0-20-x · update · 75/100
- **Branch:** `kb/ingest-kanban-board-0-20-x`
- **Entscheidung Tor 1:** modify — vier der sechs Kandidaten ingesten (swarm-Signatur, Auto-Migration, `diagnostics --kind`, `kanban_create`-Fehlschlag bei relativem `workspace_path`); `stats`-Alter und `complete a b c --summary`-Sperre entfallen (Konzeptseite, nicht Changelog)
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 0 geschrieben / 2 geaendert / 0 geprunt
- **Quellen:** `changelog-0.20.0.md`, `changelog-0.20.1.md`, `changelog-0.20.2.md`

Vier der sechs Aussagen auf `kanban-board.md` ergaenzt (Unterabschnitt `### Befehle und
Verhalten in 0.20.x`): der CLI-Befehl `hermes kanban swarm "<ziel>" --worker P:T --verifier
P --synthesizer P`, automatische Board-Migration beim ersten Zugriff, `hermes kanban
diagnostics` weist die Block-Art (`kind`) aus, und `kanban_create` schlaegt mit relativem
`workspace_path` fehl statt eine unstartbare Karte zu hinterlassen. `release-historie.md`:
swarm-Zeile um die Signatur erweitert. RE-SET nach Discard: neu aufgesetzt OHNE die Seite
`skills-system.md` (gehoert der eigenen gated Kette, eigener Tor 1). Lint BESTANDEN (0->0
ERROR, STALE 1 vorbestehend auf profile-system, nicht Teil dieses Ingest).
