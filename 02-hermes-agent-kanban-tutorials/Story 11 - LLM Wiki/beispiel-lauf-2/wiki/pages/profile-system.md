---
title: Profil-System
slug: profile-system
updated: 2026-01-20
tags: [profile, konfiguration, kern]
sources: [hermes-docs/profiles.md]
version: 0.17.0
status: aktuell
---

## Kurzfassung

Ein Profil ist ein benannter Agent mit eigenem Verzeichnis unter
`~/.hermes/profiles/<name>/`, eigenem Systemprompt (`SOUL.md`), eigener
Konfiguration und eigenen Skills. Im Kanban-Board ist der Assignee einer Karte
immer ein **Profilname**. Profile erben API-Schluessel aus der Umgebung; ein
eigener Schluessel je Profil ist nicht noetig.

## Details

### Dateien eines Profils

| Datei | Zweck |
|---|---|
| `SOUL.md` | Systemprompt — macht aus dem Profil einen Spezialisten |
| `profile.yaml` | Metadaten, darunter `description` |
| `config.yaml` | Modell- und Providereinstellungen |
| `.env` | profil-lokale Umgebungsvariablen |
| `skills/<name>/SKILL.md` | profil-lokale Skills |

### Die config.yaml entscheidet ueber Dispatchbarkeit

Ein Profil zaehlt fuer den Kanban-Dispatcher erst als Assignee, wenn in seinem
Verzeichnis eine `config.yaml` liegt. `hermes profile create` legt diese Datei
**nicht** an — erst `hermes -p <profil> config set …` tut das. Ein Profil ohne
`config.yaml` erscheint in `hermes profile list`, aber nicht in
`hermes kanban assignees`, und Karten fuer dieses Profil bleiben ohne
Fehlermeldung auf `ready` liegen.

### Die Beschreibung ist funktional

Der Kanban-Decomposer routet Triage-Karten ueber die **Profilbeschreibung**,
nicht ueber den Profilnamen. Eine leere Beschreibung heisst: dieses Profil
bekommt nie eine zerlegte Karte.

### Verteilen

Profile lassen sich exportieren, importieren und als Distribution mit einer
`distribution.yaml` installieren. Weil eine Distribution eine `config.yaml`
mitbringt, ist ein so installiertes Profil sofort dispatchbar.

## Quellen

- `hermes-docs/profiles.md` — offizielle Dokumentation, Stand 2026-01

## Siehe auch

- [[kanban-board]]
- [[memory-system]]
- [[skills-system]]
