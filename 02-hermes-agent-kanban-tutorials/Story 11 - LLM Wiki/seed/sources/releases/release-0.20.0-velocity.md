# Hermes Agent 0.20.0 „Velocity" — Hauptrelease

**Veröffentlicht:** 2026-08-03
**Quelle:** offizieller Changelog, GitHub Releases
**Typ:** Hauptrelease

## Neu

- **Kanban:** neue Spalte `review`. Erzeugt ein Worker einen Pull Request, gibt
  er die Karte nach `review` weiter; der Dispatcher startet dafür einen eigenen
  Review-Agenten mit der Skill `sdlc-review`, der entweder merged (→ `done`)
  oder die Karte zurückgibt (→ `running`).
- **Kanban:** `hermes kanban swarm "<ziel>" --worker P:T --verifier P
  --synthesizer P` — Fan-out, Verifier und Synthese in einem Befehl.
- **Kanban:** `--goal` und `--goal-max-turns`. Ein Judge prüft nach jeder Runde,
  ob die Karte erfüllt ist.
- **Cron:** `--no-agent`. Kein Modell, keine Tokenkosten — das Skript ist der
  Job.
- **Profile:** `hermes profile install <git-url|verzeichnis>` für
  Distributionen mit `distribution.yaml`.

## Deprecated

- `hermes kanban daemon`. Der Dispatcher lebt im Gateway
  (`hermes gateway start`).

## Migration

Keine Schritte nötig. Bestehende Boards werden beim ersten Zugriff migriert.
