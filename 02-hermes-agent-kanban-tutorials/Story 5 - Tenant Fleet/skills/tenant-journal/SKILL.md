---
name: tenant-journal
description: "Mandantendisziplin fuer Flotten-Worker: nur im eigenen Datenraum arbeiten, jede Aktion ins Journal des Mandanten schreiben, Gedaechtnis mit dem Mandantennamen praefixen."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Tenant Journal

Du arbeitest in einer Flotte: dasselbe Profil bearbeitet viele Mandanten, jeder
Mandant bekommt eine eigene Karte. Board, Dispatcher und Profil sind geteilt —
**nur die Daten sind getrennt, und diese Trennung durchzusetzen ist deine
Aufgabe**, nicht die des Kernels.

## Woran du deinen Mandanten erkennst

| Quelle | Inhalt |
|---|---|
| `$HERMES_TENANT` | der Mandantenname, z. B. `acct-halden` |
| `$HERMES_KANBAN_WORKSPACE` | der Datenraum genau dieses Mandanten |
| Karten-Titel und -Body | derselbe Name noch einmal im Klartext |

Stimmen die drei nicht ueberein, ist etwas falsch konfiguriert. Dann
blockierst du die Karte, statt zu raten.

## Die drei Regeln

**1. Verlasse deinen Workspace nicht.**
Lies und schreibe ausschliesslich unterhalb von `$HERMES_KANBAN_WORKSPACE`.
Der Datenraum eines anderen Mandanten ist technisch vielleicht erreichbar —
er geht dich trotzdem nichts an. Kein Pfad mit `..`, keine absoluten Pfade in
Nachbarverzeichnisse.

**2. Schreibe jede Aktion ins Journal.**
Haenge an `logs/journal.jsonl` **eine Zeile pro Aktion** an, ein JSON-Objekt
je Zeile:

```json
{"ts": "2026-08-10T09:14:02", "tenant": "acct-halden", "action": "digest_written", "detail": "digests/2026-08-10.md, 4 Nachrichten, 2 offene Tickets"}
```

Pflichtfelder: `ts`, `tenant`, `action`, `detail`. Das Journal wird
**fortgeschrieben** — anhaengen, nie ueberschreiben. Es ist die Aktenlage
dieses Mandanten und ueberdauert jede einzelne Karte.

**3. Praefixe, was du dir merkst.**
Schreibst du etwas in dein Gedaechtnis, stellst du den Mandantennamen voran:
`acct-halden: Tobias Krenz entscheidet ueber die Verlaengerung`. Sonst
vermischt sich nach der dritten Karte das Wissen ueber alle Mandanten zu
etwas, das fuer keinen mehr stimmt.

## Wenn Daten fehlen

Fehlt eine Datei, die die Karte verlangt: `kanban_block(reason="…")` mit dem
exakten Dateinamen — und dann Schluss. Ein defekter Mandant darf die Flotte
nicht aufhalten; alle anderen Karten laufen unabhaengig weiter. Behelfe dir
nicht mit Daten aus einer anderen Quelle.

## Abschluss

```
kanban_complete(
    summary="…",
    metadata={"tenant": "<dein Mandant>", "changed_files": [...], "actions": N},
)
```

`tenant` im Metadatensatz ist Pflicht. Auswertungen ueber die Flotte laufen
darueber.
