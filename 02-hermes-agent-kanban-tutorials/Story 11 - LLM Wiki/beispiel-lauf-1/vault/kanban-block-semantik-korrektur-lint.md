# Lint-Bericht: kanban-block-semantik-korrektur

| | vorher | nachher |
|---|---|---|
| ERROR | 0 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| — | — | Keine ERROR-Befunde. Die geaenderte Seite `pages/kanban-block-semantik.md` validiert fehlerfrei (Frontmatter, Abschnittsreihenfolge, Wikilinks, Index, Freshness). Der 1 vorbereitete Prune (falsche Zeile `block <id> --reason …`, ersetzt statt ergaenzt) wurde vom Ingest bereits angewandt. |

## Nicht repariert

Keine ERROR-Befunde; kein Reparaturbedarf ohne menschliche Entscheidung.

## Prune-Kandidaten für Tor 2

| Datei | Was verschwinden würde | Befund | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | nichts (STALE = pruefen, nicht loeschen) | `updated 2026-01-20` ist 203 Tage alt (Grenze 180). Vorbestehend, **nicht** Teil dieses Ingests; ich habe sie nicht angefasst. Die Aussagen (Profil = Verzeichnis unter `~/.hermes/profiles/<name>`, `config.yaml` entscheidet ueber Dispatchbarkeit, Beschreibung ist funktional) decken sich mit der beobachteten Umgebung und professionellen Praktiken, koennen aber nur gegen `hermes-docs/profiles.md` endgueltig verifiziert werden. | Tor 2 prufe, ob die Seite noch den aktuellen Stand beschreibt. Stimmt sie: neues `updated` setzen (Ingest, nicht Lint). Stimmt sie nicht: Ersatz. Nur wenn der Inhalt nicht mehr relevant ist: Prune. Kein Agent loescht hier etwas auf eigene Rechnung. |