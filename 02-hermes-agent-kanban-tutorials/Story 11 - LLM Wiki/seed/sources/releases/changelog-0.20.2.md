# Hermes Agent 0.20.2 — Patch-Release

**Veröffentlicht:** 2026-08-09
**Quelle:** offizieller Changelog, GitHub Releases
**Typ:** Patch auf 0.20.0 „Velocity"

## Behoben

- **Kanban / Block-Schleifen:** Eine Karte, die nach einem `unblock` erneut mit
  **derselben** Block-Art blockiert wird, landet in der Triage statt in
  `blocked`. Der Zähler dafür (`block_recurrences`) wird pro Block-Art geführt
  und **nur bei erfolgreichem Abschluss** zurückgesetzt. Neu ist, dass das
  ausgelöste Ereignis `block_loop_detected` heißt und Zähler und Grenze im
  Payload trägt; vorher war es ein gewöhnliches `blocked`-Ereignis und der
  Wechsel in die Triage war von außen nicht erkennbar.

- **Kanban / `kanban_create` im Worker:** Ein relativer `workspace_path` wurde
  stillschweigend abgewiesen — die Karte entstand, wurde aber nie gestartet und
  es gab keine Fehlermeldung auf dem Board. Der Aufruf schlägt jetzt mit einer
  Meldung fehl, statt eine unstartbare Karte zu hinterlassen.

- **Profile:** `hermes profile install` aus einem lokalen Verzeichnis übernahm
  die `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb
  ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über
  die Beschreibung routet. Behoben.

- **Gateway:** Nach `hermes pause` beendete ein bereits laufender Tick seine
  Spawns noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab.

## Geändert

- `hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte
  in Minuten statt nur als Zeitstempel.
- Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400,
  ist aber jetzt pro Profil überschreibbar.

## Hinweis für Betreiber

Wer eine Pipeline mit zwei aufeinanderfolgenden menschlichen Toren auf
**derselben** Karte baut, muss für das zweite Tor eine **andere** Block-Art
wählen — sonst greift die Schleifenerkennung aus diesem Release und die Karte
geht in die Triage statt in `blocked`.
