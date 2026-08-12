# Ingest-Log

Ein Absatz je Ingest, neueste oben. Format steht in `AGENTS.md`, Abschnitt 7.2.

Dieses Log ist die Antwort auf „warum steht das hier?" — und die einzige Stelle,
an der eine menschliche Entscheidung dauerhaft im Repository steht.

---

## 2026-08-11 · kanban-block-semantik-korrektur · konflikt · 91/100
- **Branch:** `kb/ingest-kanban-block-semantik-korrektur`
- **Entscheidung Tor 1:** approve — „UNBLOCK: approve" (Rueckmeldung auf die Block-Anfrage der Kette)
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 0 geschrieben / 1 geaendert / 1 geprunt
- **Quellen:** `changelog-0.20.1.md`, `changelog-0.20.2.md`, `2026-08-08-block-semantik.md`

Route **konflikt**: die QUELLE gewinnt, der Mensch hat am Tor 1 mit `approve`
entschieden. Geprunt (ersetzt, nicht ergaenzt): die falsche Aussage
`block <id> --reason "…"` (Z. 24). `block` nimmt den Grund **positional**,
`--reason` existiert dafuer nicht und bricht mit `unrecognized arguments` ab;
`--kind` muss **vor** der Kartennummer stehen. `pages/kanban-block-semantik.md`
dokumentiert jetzt `block <id> "…"` und den Typfall
`block --kind needs_input <id> "…"`. Ergänzt: F2 `--kind`-Reihenfolge vor der
ID; F3 `--initial-status blocked` setzt nur die Spalte, erzeugt kein
`blocked`-Ereignis und ist **kein** Tor („parkt ≠ haelt"); F4 Haltekraft
unabhaengig von der Block-Art; F5 `block_loop_detected` mit Zaehler
`block_recurrences` (pro Art, Reset nur bei Erfolg) und Grenze
`BLOCK_RECURRENCE_LIMIT` = 2 — der zweite gleichartige Block nach `unblock`
schickt die Karte in die Triage. Frontmatter: `updated` 2026-08-11,
`version` 0.20.2, `sources` um die drei neuen Quellen ergaenzt, `status: aktuell`.
Index unveraendert (Seite weiterhin aus `index.md` verlinkt).

## 2026-08-11 · dispatcher-reclaim-und-tick · update · 85/100
- **Branch:** `kb/ingest-dispatcher-reclaim-und-tick`
- **Entscheidung Tor 1:** modify — „UNBLOCK: modify: Nur den idempotenten Claim-Reclaim und den Tick-Abbruch nach 'hermes pause' aufnehmen. Die Aussage 'dispatch_stale_timeout_seconds ist jetzt pro Profil ueberschreibbar' weglassen: sie steht nur im Changelog, und die Verifikations-Bahn hat sie nicht an der Installation nachgewiesen."
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 0 geschrieben / 1 geaendert / 0 geprunt
- **Quellen:** `changelog-0.20.1.md`, `changelog-0.20.2.md`

`pages/gateway-und-dispatcher.md` praezisiert: (1) Seit 0.20.1 ist der
Claim-Reclaim idempotent — ein Claim, dessen Worker nie heartbeaten, wurde in
seltenen Faellen zweimal eingesammelt und die Karte doppelt gespawnt; genau das
ist jetzt unterbunden (Abschnitt `### Heartbeats`). (2) Seit 0.20.2 bricht ein
laufender Tick nach `hermes pause` nach dem aktuellen Spawn ab statt seine
restlichen Spawns zu beenden — laufende Arbeit stirbt nicht, es kommen nur
keine neuen Spawns dazu (Betrieb-Tabelle). `version` auf 0.20.2 gehoben,
`updated` auf 2026-08-11. Die Changelog-Aussage zur pro-Profile-Ueberschreibbarkeit
von `dispatch_stale_timeout_seconds` wurde bewusst **nicht** aufgenommen
(nur im Changelog, nicht an der Installation verifiziert). Index unveraendert.

## 2026-08-11 · skills-system · neue_seite · 98/100
- **Branch:** `kb/ingest-skills-system`
- **Entscheidung Tor 1:** approve — „UNBLOCK: approve"
- **Entscheidung Tor 2:** merge — „UNBLOCK: merge"
- **Seiten:** 1 geschrieben / 1 geaendert / 0 geprunt
- **Quellen:** `2026-08-07-skills-system.md`

Neue Seite `pages/skills-system.md` geschrieben: Skill-Aufbau (SKILL.md mit
YAML-Frontmatter `name`/`description`), drei Speicherorte mit abgestufter
Reichweite, description-im-Kontext (progressive disclosure), `skills list`-Herkunft,
`--skill`-Erzwingung sowie Skill-vs-MCP als Konzept. Damit ist der Stub-Link
`[[skills-system]]` aus `index.md:21` geheilt (Index unveraendert). Die
Speicherort-Aussage wurde zum praezisierten Profilmodell geschaerft: default-Home
`~/.hermes/skills/` = Skills-Root des default-Profils (nicht „global fuer jedes
Profil"), profil-eigenes Home `~/.hermes/profiles/<name>/skills/` als `local`,
gebündelt als `builtin`. Optional ergaenzt: `profile-system.md` verweist jetzt
per `[[skills-system]]` (verlinkt statt wiederholt).

## 2026-08-04 · release-historie · update · manuell
- **Branch:** `-` (von Hand gepflegt, vor Einfuehrung der Pipeline)
- **Entscheidung Tor 1:** — (kein Tor, manueller Eintrag)
- **Entscheidung Tor 2:** — (kein Tor, manueller Eintrag)
- **Seiten:** 0 geschrieben / 1 geaendert / 0 geprunt
- **Quellen:** `changelog-0.20.0.md`

Erste Erfassung des 0.20.0-Hauptreleases („Velocity"). Die Patch-Releases
danach sind **noch nicht** erfasst.
