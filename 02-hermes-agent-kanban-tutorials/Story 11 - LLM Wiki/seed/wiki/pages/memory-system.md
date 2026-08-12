---
title: Memory-System
slug: memory-system
tags: [memory, kern]
sources: [hermes-docs/memory.md]
version: 0.19.0
status: aktuell
---

## Kurzfassung

Hermes Agent haelt Gedaechtnis auf zwei Ebenen: eine dateibasierte
Langzeitablage unter `~/.hermes/memories/` und den Sitzungszustand in
`state.db`. Profile haben ein eigenes Gedaechtnis; ein Profil liest das
Gedaechtnis eines anderen nicht mit. Das Gedaechtnis ist kein Protokoll,
sondern eine gepflegte Ablage — Eintraege werden ueberschrieben, wenn sie
falsch geworden sind.

## Details

### Ablageorte

| Ort | Inhalt | Lebensdauer |
|---|---|---|
| `~/.hermes/memories/` | dauerhafte Notizen, eine Datei je Fakt | unbegrenzt |
| `state.db` | Sitzungen, Zustaende, Verifikationsspuren | bis zum Aufraeumen |
| `~/.hermes/sessions/` | Transkripte | bis zum Aufraeumen |

### Trennung nach Profil und Mandant

Ein Profil hat sein eigenes Verzeichnis unter `~/.hermes/profiles/<name>/`.
Setzt eine Karte `--tenant`, landet der Name als `$HERMES_TENANT` im Worker.

> Achtung: `$HERMES_TENANT` trennt Daten **nicht von selbst**. Der Kernel setzt
> die Variable; ob ein Worker sein Gedaechtnis danach getrennt haelt, ist eine
> Konvention, die der Task-Body oder eine Skill durchsetzen muss.

### Was ins Gedaechtnis gehoert

- wer der Nutzer ist, was er kann, wie er arbeiten will
- Rueckmeldungen zur Arbeitsweise, mit Begruendung
- laufende Vorhaben und Randbedingungen, die nicht aus dem Code folgen
- Verweise auf externe Ressourcen

Nicht hinein gehoert, was das Repository selbst schon festhaelt.

## Quellen

- `hermes-docs/memory.md` — offizielle Dokumentation

## Siehe auch

- [[profile-system]]
