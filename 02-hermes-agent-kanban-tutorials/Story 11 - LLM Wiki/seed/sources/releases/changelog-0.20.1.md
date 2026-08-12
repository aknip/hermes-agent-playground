# Hermes Agent 0.20.1 — Patch-Release

**Veröffentlicht:** 2026-08-06
**Quelle:** offizieller Changelog, GitHub Releases
**Typ:** Patch auf 0.20.0 „Velocity"

## Behoben

- **Kanban / Dispatcher:** `recompute_ready` beförderte Karten mit
  `--initial-status blocked` mit, sobald deren Eltern fertig waren. Karten, die
  als Wartepunkt gedacht waren, liefen dadurch stumm durch. Das Verhalten ist
  **unverändert** — dokumentiert ist nun ausdrücklich, dass `--initial-status
  blocked` die Spalte setzt, aber **kein** `blocked`-Ereignis erzeugt, und
  deshalb kein Tor ist. Nur ein echtes `block` bzw. `kanban_block()` hält.

- **Kanban / CLI:** `hermes kanban block` nahm den Grund bereits seit 0.20.0
  **positional**; die Dokumentation zeigte weiterhin `--reason`. Die
  Dokumentation ist korrigiert. `--kind` muss **vor** der Kartennummer stehen.
  Bei `unblock` gibt es `--reason` weiterhin, und dort legt es den Text als
  Kommentar an die Karte, bevor sie nach `ready` geht.

- **Kanban / Dispatcher:** Ein Claim, dessen Worker ohne `kanban_heartbeat`
  lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt
  gespawnt. Der Reclaim ist jetzt idempotent.

- **Cron:** Jobs mit `--no-agent` schrieben bei leerem stdout eine leere
  Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen
  keine Datei mehr.

## Geändert

- `hermes kanban diagnostics` weist blockierte Karten jetzt mit ihrer
  Block-Art (`kind`) aus, statt nur mit dem Grund.

## Bekannte Einschränkung

`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn
Handoff-Flags gesetzt sind. Das ist Absicht: Summary und Metadata gelten je
Run, und dieselbe Zusammenfassung auf drei Karten zu kopieren ist fast immer
falsch.
