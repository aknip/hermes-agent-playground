# Seiten-Abgleich: dispatcher-reclaim-und-tick

Item: `vault/dispatcher-reclaim-und-tick.md`
Geprüfte Betroffenheit laut Triage: `wiki/pages/gateway-und-dispatcher.md`
(Vorgabe der Karte), zusätzlich `wiki/pages/cron-und-zeitplan.md`
(Pause-Aussage).

## Die drei Verhaltensänderungen (Quelle: offizieller Changelog)

1. **Idempotenter Reclaim** — `sources/releases/changelog-0.20.1.md`,
   Abschnitt „Behoben" / „Kanban / Dispatcher", Zeilen 22-24 (veröffentlicht
   2026-08-06):
   > „Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen
   > Fällen zweimal eingesammelt und die Karte doppelt gespawnt. Der Reclaim
   > ist jetzt idempotent."

2. **Tick bricht nach `hermes pause` ab** —
   `sources/releases/changelog-0.20.2.md`, Abschnitt „Behoben" / „Gateway",
   Zeilen 27-28 (veröffentlicht 2026-08-09):
   > „Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns
   > noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab."

3. **`kanban.dispatch_stale_timeout_seconds` pro Profil überschreibbar** —
   `sources/releases/changelog-0.20.2.md`, Abschnitt „Geändert", Zeilen 34-35:
   > „Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt
   > 14400, ist aber jetzt pro Profil überschreibbar."

## Geprüfte Seiten — Ist-Stand

### `wiki/pages/gateway-und-dispatcher.md` (updated 2026-07-30, version 0.20.0)
Gelesen komplett. Betroffene Abschnitte:

- **Heartbeats** (Zeilen 52-56): „Ohne `kanban_heartbeat` haelt der Dispatcher
  einen Claim nach `kanban.dispatch_stale_timeout_seconds` (Standard 14400)
  fuer verwaist und legt die Karte zurueck in die Queue."
  → Deckt den Reclaim-Mechanismus und den Default 14400 ab, **nicht** aber:
  die Idempotenz (#1) noch die Überschreibbarkeit pro Profil (#3).
- **Betrieb-Tabelle** (Zeile 29): `hermes pause` / `hermes resume` — „Kanban
  und Cron gemeinsam anhalten". → Command ist gelistet, das
  Tick-Abbruch-Verhalten (#2) fehlt.

Weder #1 noch #2 noch #3 stehen in gleicher Präzision auf der Seite. #3 ist
teilweise „schwächer" vorhanden (der Konfigurationsschlüssel und sein Default
sind benannt, nicht aber die neue Überschreibbarkeit pro Profil).

### `wiki/pages/cron-und-zeitplan.md` (updated 2026-07-14, version 0.20.0)
Gelesen komplett. Zeilen 49-50: „`hermes pause` haelt Cron **und**
Kanban-Dispatch gemeinsam an; laufende Arbeit wird dabei nicht getoetet."
→ Berührt das Pause-Thema aus Cron-Perspektive. Steht nicht im Widerspruch
zu #2 („laufende Arbeit wird nicht getoetet" ist konsistent damit, dass der
Tick nur keine *neuen* Spawns mehr startet), formuliert die
Tick-Abbruch-Änderung aber explizit nicht.

## Bewertung je Änderung

| # | Änderung | Seite | Stand auf der Seite |
|---|----------|-------|---------------------|
| 1 | Idempotenter Reclaim | gateway-und-dispatcher | **fehlt** (Reclaim-Mechanismus ja, Idempotenz nein) |
| 2 | Tick bricht nach pause ab | gateway-und-dispatcher / cron-und-zeitplan | **fehlt** (Command ja, Verhalten nein) |
| 3 | stale_timeout pro Profil überschreibbar | gateway-und-dispatcher | **ungenau/fehlt** (Schlüssel+Default ja, Überschreibbarkeit nein) |

## Was ich VERIFIZIERT habe

- Alle drei Aussagen wörtlich gegen `sources/releases/changelog-0.20.1.md` und
  `changelog-0.20.2.md` geprüft (Originaltext oben). Quellenrang: offizieller
  Changelog.
- `wiki/pages/gateway-und-dispatcher.md` und `wiki/pages/cron-und-zeitplan.md`
  vollständig gelesen; kein anderer Abschnitt nennt eine der drei Änderungen.
- Kein Widerspruch: keine Seite behauptet das Gegenteil einer der drei
  Änderungen. Die Pause-Aussage auf cron-und-zeitplan ist konsistent.

## Was ich INFERIERE

- Die drei Verhaltensänderungen sind auf gateways Und-übergreifenden Seiten
  nicht vorhanden. Das Thema (Heartbeats/Reclaim, pause/resume) ist auf
  `gateway-und-dispatcher.md` angeschnitten, aber alle drei neuen Präzisierungen
  fehlen oder sind nur „schwächer" vorhanden.
- `gateway-und-dispatcher.md` ist die gegebene Heimatseite für alle drei
  (Heartbeats-Abschnitt, Betrieb-Tabelle). Eine Änderung (#2) könnte zusätzlich
  auf `cron-und-zeitplan.md` passen, reicht aber bereits über
  `gateway-und-dispatcher` hinaus.
- Da die Seite existiert und die Aussagen fehlen/ungenau sind, nicht zu
  Widersprüchen: Klassifikation `unvollstaendig` → Route `update`.

Dieses Dokument ändert nichts unter `wiki/`. Es ist der Klassifikator-Behund
für die Route-Karte.

wissensstand: unvollstaendig