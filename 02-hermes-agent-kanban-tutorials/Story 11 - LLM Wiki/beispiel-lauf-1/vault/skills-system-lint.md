# Lint-Bericht: skills-system

Branch `kb/ingest-skills-system` · Lauf 2026-08-11

| | vorher | nachher |
|---|---|---|
| ERROR | 4 | 0 |
| STALE | 1 | 1 |
| PRUNE-VORSCHLAG | 0 | 0 |

## Repariert

| Datei | Regel | Was ich getan habe |
|---|---|---|
| `pages/cron-und-zeitplan.md` | abschnitt-reihenfolge | `## Quellen` hinter `## Details` verschoben — Reihenfolge ist jetzt Kurzfassung → Details → Quellen → Siehe auch (AGENTS.md 2.2). Inhalt unveraendert. |
| `pages/kanban-board.md` | toter-link | `[[kanban-review-agent]]` entfernt. **Weg: Link entfernen.** Die Seite ist nicht geplant; der Satz ist ohne den Link vollstaendig (der Review-Agent wird bereits durch Skill `sdlc-review` beschrieben). Kein Stub angelegt. |
| `pages/memory-system.md` | frontmatter-key | Pflichtschluessel `updated: 2026-08-11` ergaenzt — Datum der letzten inhaltlichen Aenderung laut Git-Historie (Seed-Commit); `## Quellen` nennt kein Datum. |
| `index.md` | waise | `[[gateway-und-dispatcher]]` im Abschnitt `Kern` ergaenzt — die Seite existierte, war aber nicht aus dem Index verlinkt (AGENTS.md 4). |

Alle vier ERROR-Befunde waren bereits vor diesem Ingest vorhanden; der Ingest
selbst (Seite `pages/skills-system.md` neu) hat keine neuen Fehler eingefuehrt.

## Nicht repariert

| Datei | Regel | Warum ein Mensch noetig ist |
|---|---|---|
| — | — | — |

`errors_after` ist 0; keine unreparierten ERROR-Befunde.

## Pruef-Kandidaten fuer Tor 2 (STALE, nicht geloescht)

| Datei | Was betroffen ist | Befund | Empfehlung |
|---|---|---|---|
| `pages/profile-system.md` | `updated 2026-01-20`, 203 Tage alt (Grenze 180) | STALE `freshness`. Die Aussagen betreffen das Profil-System (config.yaml ist Dispatch-Voraussetzung, Beschreibung ist funktional, Verteilung per distribution.yaml). Diese Fakten wurden in diesem Ingest nicht neu geprueft. | Ein Mensch muss bei Tor 2 entscheiden: Nachpruefen und `updated` neu setzen, oder die Seite als Prune-Kandidat bewerten. Ich setze KEIN `updated` — das waere eine Frontmatter-Luege, weil ich den Inhalt nicht gegen die aktuelle Version verifizieren konnte. |

**Kein PRUNE-VORSCHLAG** in diesem Lauf: Keine Seite ist offensichtlich
ueberfluessig, und es gibt keine Konflikte, die Entfernung nahelegen.