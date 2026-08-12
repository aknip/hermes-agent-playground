# Scout-Bericht: releases

Ausgewertet: 3 Dateien unter sources/releases
Kandidaten: 19

---

## 0.20.0: Kanban erhält eine neue Spalte `review` mit automatischem Review-Agenten

- **titel:** Kanban erhält eine neue Spalte `review` mit automatischem Review-Agenten
- **aussage:** Es gibt eine neue Kanban-Spalte `review`: Ein Worker, der einen Pull Request erzeugt, gibt die Karte nach `review` weiter; der Dispatcher startet dafür einen eigenen Review-Agenten mit der Skill `sdlc-review`, der entweder merged (→ `done`) oder die Karte zurückgibt (→ `running`).
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu", erster Bullet — 2026-08-03 — „**Kanban:** neue Spalte `review`. Erzeugt ein Worker einen Pull Request, gibt er die Karte nach `review` weiter; der Dispatcher startet dafür einen eigenen Review-Agenten mit der Skill `sdlc-review`, der entweder merged (→ `done`) oder die Karte zurückgibt (→ `running`)."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Kanban-Board, Review-Spalte, Review-Agenten/Dispatcher
- **neuheit_vermutet:** vermutlich neu — eine `review`-Spalte und der `sdlc-review`-Agent sind ein konkretes, neues Feature des 0.20.0-Hauptreleases

## 0.20.0: Neuer Befehl `hermes kanban swarm` mit Fan-out, Verifier und Synthese

- **titel:** Neuer Befehl `hermes kanban swarm` mit Fan-out, Verifier und Synthese
- **aussage:** `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` vereint Fan-out, Verifier und Synthese in einem einzigen Befehl.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu", zweiter Bullet — 2026-08-03 — „**Kanban:** `hermes kanban swarm \"<ziel>\" --worker P:T --verifier P --synthesizer P` — Fan-out, Verifier und Synthese in einem Befehl."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Kanban-Befehlen, Swarm/Delegation
- **neuheit_vermutet:** vermutlich neu — neuer Befehl aus dem 0.20.0-Hauptrelease

## 0.20.0: Kanban-Karten unterstützen `--goal` und `--goal-max-turns` mit nachgeschaltetem Judge

- **titel:** Kanban-Karten unterstützen `--goal` und `--goal-max-turns` mit nachgeschaltetem Judge
- **aussage:** `hermes kanban` kennt die Flags `--goal` und `--goal-max-turns`; ein Judge prüft nach jeder Runde, ob die Karte erfüllt ist.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu", dritter Bullet — 2026-08-03 — „**Kanban:** `--goal` und `--goal-max-turns`. Ein Judge prüft nach jeder Runde, ob die Karte erfüllt ist."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Kanban-Kartenerstellung, Goal-Mode
- **neuheit_vermutet:** vermutlich neu — neues Flag-Paar aus dem 0.20.0-Hauptrelease

## 0.20.0: Neues Cron-Flag `--no-agent` — Skript als Job ohne Modell

- **titel:** Neues Cron-Flag `--no-agent` — Skript als Job ohne Modell
- **aussage:** Cron-Jobs unterstützen `--no-agent`: kein Modell, keine Tokenkosten — das Skript ist der Job.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu", vierter Bullet — 2026-08-03 — „**Cron:** `--no-agent`. Kein Modell, keine Tokenkosten — das Skript ist der Job."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Cron-Jobs, `--no-agent`
- **neuheit_vermutet:** vermutlich neu — neues Cron-Flag aus dem 0.20.0-Hauptrelease

## 0.20.0: Neuer Befehl `hermes profile install <git-url|verzeichnis>` für Distributionen

- **titel:** Neuer Befehl `hermes profile install <git-url|verzeichnis>` für Distributionen
- **aussage:** `hermes profile install <git-url|verzeichnis>` installiert Profile für Distributionen mit `distribution.yaml`.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu", fünfter Bullet — 2026-08-03 — „**Profile:** `hermes profile install <git-url|verzeichnis>` für Distributionen mit `distribution.yaml`."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Profilen/Installation
- **neuheit_vermutet:** vermutlich neu — neuer Profil-Befehl aus dem 0.20.0-Hauptrelease

## 0.20.0: `hermes kanban daemon` ist deprecated — der Dispatcher lebt im Gateway

- **titel:** `hermes kanban daemon` ist deprecated — der Dispatcher lebt im Gateway
- **aussage:** `hermes kanban daemon` ist deprecated; der Kanban-Dispatcher lebt seither im Gateway und wird über `hermes gateway start` gestartet.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Deprecated" — 2026-08-03 — „`hermes kanban daemon`. Der Dispatcher lebt im Gateway (`hermes gateway start`)."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Kanban-Daemon, Dispatcher, Gateway
- **neuheit_vermutet:** vermutlich neu — Deprecation-Änderung des 0.20.0-Hauptreleases

## 0.20.0: Bestehende Boards werden beim ersten Zugriff ohne Migrationsschritte migriert

- **titel:** Bestehende Boards werden beim ersten Zugriff ohne Migrationsschritte migriert
- **aussage:** Für den Wechsel zu 0.20.0 sind keine Migrationsschritte nötig; bestehende Boards werden beim ersten Zugriff automatisch migriert.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Migration" — 2026-08-03 — „Keine Schritte nötig. Bestehende Boards werden beim ersten Zugriff migriert."
- **version:** 0.20.0
- **betrifft_vermutlich:** Wiki-Seiten zu Kanban-Board-Migration/Update
- **neuheit_vermutet:** vermutlich abgedeckt — eine Migrationsnotiz ist eher dokumentarisch; ob die Wissensbasis das schon beschreibt, ist unklar

---

## 0.20.1: `--initial-status blocked` ist kein Tor — dokumentiert statt geändert

- **titel:** `--initial-status blocked` ist kein Tor — dokumentiert statt geändert
- **aussage:** `recompute_ready` beförderte Karten mit `--initial-status blocked` mit, sobald deren Eltern fertig waren. Das Verhalten ist unverändert; dokumentiert ist nun ausdrücklich, dass `--initial-status blocked` die Spalte setzt, aber kein `blocked`-Ereignis erzeugt und deshalb kein Tor ist. Nur ein echtes `block` bzw. `kanban_block()` hält.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben", erster Bullet — 2026-08-06 — „`recompute_ready` beförderte Karten mit `--initial-status blocked` mit, sobald deren Eltern fertig waren. […] Das Verhalten ist **unverändert** — dokumentiert ist nun ausdrücklich, dass `--initial-status blocked` die Spalte setzt, aber **kein** `blocked`-Ereignis erzeugt, und deshalb kein Tor ist. Nur ein echtes `block` bzw. `kanban_block()` hält."
- **version:** 0.20.1 (Verhalten seit früher; nur Dokumentation korrigiert)
- **betrifft_vermutlich:** Wiki-Seiten zu `--initial-status blocked`, Kanban-Block/Sperren
- **neuheit_vermutet:** vermutlich neu — eine ausdrückliche Klarstellung darüber, dass `--initial-status blocked` kein Tor ist

## 0.20.1: `hermes kanban block` nimmt den Grund positional — Dokumentation korrigiert

- **titel:** `hermes kanban block` nimmt den Grund positional — Dokumentation korrigiert
- **aussage:** `hermes kanban block` nahm den Grund bereits seit 0.20.0 positional, während die Dokumentation `--reason` zeigte; die Dokumentation wurde korrigiert. `--kind` muss **vor** der Kartennummer stehen. Bei `unblock` gibt es `--reason` weiterhin, und dort legt es den Text als Kommentar an die Karte, bevor sie nach `ready` geht.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben", zweiter Bullet — 2026-08-06 — „`hermes kanban block` nahm den Grund bereits seit 0.20.0 **positional**; die Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist korrigiert. `--kind` muss **vor** der Kartennummer stehen. Bei `unblock` gibt es `--reason` weiterhin, und dort legt es den Text als Kommentar an die Karte, bevor sie nach `ready` geht."
- **version:** 0.20.1 (Verhalten seit 0.20.0)
- **betrifft_vermutlich:** Wiki-Seiten zu `hermes kanban block`/`unblock`, CLI-Referenz
- **neuheit_vermutet:** vermutlich neu — korrigierte CLI-Semantik (positionaler Grund, `--kind`-Position), soweit erkennbar nicht in älteren Unterlagen

## 0.20.1: Doppelter Reclaim von Claims ist durch Idempotenz behoben

- **titel:** Doppelter Reclaim von Claims ist durch Idempotenz behoben
- **aussage:** Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt gespawnt; der Reclaim ist jetzt idempotent.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben", dritter Bullet — 2026-08-06 — „Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt gespawnt. Der Reclaim ist jetzt idempotent."
- **version:** 0.20.1
- **betrifft_vermutlich:** Wiki-Seiten zu Dispatcher/Reclaim, Heartbeat
- **neuheit_vermutet:** vermutlich neu — Fehlerbehebungsdetails des 0.20.1-Patchreleases

## 0.20.1: Leere `--no-agent`-Cron-Läufe erzeugen keine Ausgabedatei mehr

- **titel:** Leere `--no-agent`-Cron-Läufe erzeugen keine Ausgabedatei mehr
- **aussage:** `--no-agent`-Cron-Jobs schrieben bei leerem stdout bisher eine leere Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`; leere Läufe erzeugen keine Datei mehr.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben", vierter Bullet — 2026-08-06 — „Jobs mit `--no-agent` schrieben bei leerem stdout eine leere Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen keine Datei mehr."
- **version:** 0.20.1
- **betrifft_vermutlich:** Wiki-Seiten zu Cron, `--no-agent`, Ausgabedateien
- **neuheit_vermutet:** vermutlich neu — Detailänderung des 0.20.1-Patchreleases zum Verhalten von `--no-agent`

## 0.20.1: `hermes kanban diagnostics` weist Block-Art (`kind`) blockierter Karten aus

- **titel:** `hermes kanban diagnostics` weist Block-Art (`kind`) blockierter Karten aus
- **aussage:** `hermes kanban diagnostics` weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Geändert" — 2026-08-06 — „`hermes kanban diagnostics` weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund."
- **version:** 0.20.1
- **betrifft_vermutlich:** Wiki-Seiten zu `hermes kanban diagnostics`, Blockarten
- **neuheit_vermutet:** vermutlich neu — Ausgabeänderung des 0.20.1-Patchreleases

## 0.20.1: `hermes kanban complete … --summary` mit Handoff-Flags bleibt absichtlich abgewiesen

- **titel:** `hermes kanban complete … --summary` mit Handoff-Flags bleibt absichtlich abgewiesen
- **aussage:** `hermes kanban complete a b c --summary …` wird abgewiesen, sobald Handoff-Flags gesetzt sind; das ist absichtlich, weil Summary und Metadata je Run gelten und dieselbe Zusammenfassung auf drei Karten zu kopieren fast immer falsch ist.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Bekannte Einschränkung" — 2026-08-06 — „`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn Handoff-Flags gesetzt sind. Das ist Absicht: Summary und Metadata gelten je Run, und dieselbe Zusammenfassung auf drei Karten zu kopieren ist fast immer falsch."
- **version:** 0.20.1
- **betrifft_vermutlich:** Wiki-Seiten zu `hermes kanban complete`, Handoff/Summary
- **neuheit_vermutet:** vermutlich neu — dokumentierte Verhaltenseinschränkung des 0.20.1-Patchreleases

---

## 0.20.2: Wiederholte Blockade mit derselben Block-Art löst `block_loop_detected` und Triage aus

- **titel:** Wiederholte Blockade mit derselben Block-Art löst `block_loop_detected` und Triage aus
- **aussage:** Eine Karte, die nach einem `unblock` erneut mit derselben Block-Art blockiert wird, landet in der Triage statt in `blocked`. Der Zähler `block_recurrences` wird pro Block-Art geführt und nur bei erfolgreichem Abschluss zurückgesetzt. Das ausgelöste Ereignis heißt jetzt `block_loop_detected` und trägt Zähler und Grenze im Payload; vorher war es ein gewöhnliches `blocked`-Ereignis und der Wechsel in die Triage war von außen nicht erkennbar. (Der „Hinweis für Betreiber" im selben Release wiederholt diese Mechanik: Für ein zweites menschliches Tor auf derselben Karte muss eine andere Block-Art gewählt werden.)
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben", erster Bullet — 2026-08-09 — „Eine Karte, die nach einem `unblock` erneut mit **derselben** Block-Art blockiert wird, landet in der Triage statt in `blocked`. Der Zähler dafür (`block_recurrences`) wird pro Block-Art geführt und **nur bei erfolgreichem Abschluss** zurückgesetzt. Neu ist, dass das ausgelöste Ereignis `block_loop_detected` heißt und Zähler und Grenze im Payload trägt; vorher war es ein gewöhnliches `blocked`-Ereignis und der Wechsel in die Triage war von außen nicht erkennbar."
  - `changelog-0.20.2.md` — Abschnitt „Hinweis für Betreiber" — 2026-08-09 — „Wer eine Pipeline mit zwei aufeinanderfolgenden menschlichen Toren auf **derselben** Karte baut, muss für das zweite Tor eine **andere** Block-Art wählen — sonst greift die Schleifenerkennung aus diesem Release und die Karte geht in die Triage statt in `blocked`."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu Block-Schleifenerkennung/Triage, Blockarten, Toren
- **neuheit_vermutet:** vermutlich neu — `block_loop_detected` und der Triage-Wechsel sind ein deutliches neues Verhalten des 0.20.2-Patchreleases

## 0.20.2: `kanban_create` mit relativem `workspace_path` schlägt jetzt fehl statt stumm zu bleiben

- **titel:** `kanban_create` mit relativem `workspace_path` schlägt jetzt fehl statt stumm zu bleiben
- **aussage:** `kanban_create` im Worker wies einen relativen `workspace_path` bisher stillschweigend ab — die Karte entstand, wurde aber nie gestartet, ohne Fehlermeldung auf dem Board. Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben", zweiter Bullet — 2026-08-09 — „Ein relativer `workspace_path` wurde stillschweigend abgewiesen — die Karte entstand, wurde aber nie gestartet und es gab keine Fehlermeldung auf dem Board. Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu `kanban_create`, Workspace-Konfiguration
- **neuheit_vermutet:** vermutlich neu — Fehlerbehebungsverhalten des 0.20.2-Patchreleases

## 0.20.2: `hermes profile install` übernimmt `description` aus `distribution.yaml` in `profile.yaml`

- **titel:** `hermes profile install` übernimmt `description` aus `distribution.yaml` in `profile.yaml`
- **aussage:** `hermes profile install` aus einem lokalen Verzeichnis übernahm die `description` aus `distribution.yaml` nicht in `profile.yaml`; dadurch blieb ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über die Beschreibung routet. Dies wurde behoben.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben", dritter Bullet — 2026-08-09 — "`hermes profile install` aus einem lokalen Verzeichnis übernahm die `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über die Beschreibung routet. Behoben."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu `hermes profile install`, `distribution.yaml`, Kanban-Decomposer
- **neuheit_vermutet:** vermutlich neu — Fehlerbehebungsdetail des 0.20.2-Patchreleases (verweist auf den „Kanban-Decomposer" als neuen/routenden Baustein)

## 0.20.2: Gateway-Tick bricht nach `hermes pause` nach dem aktuellen Spawn ab

- **titel:** Gateway-Tick bricht nach `hermes pause` nach dem aktuellen Spawn ab
- **aussage:** Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns noch weiter; der Tick bricht jetzt nach dem aktuellen Spawn ab.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben", vierter Bullet — 2026-08-09 — „Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu Gateway, `hermes pause`, Spawns
- **neuheit_vermutet:** vermutlich neu — Fehlerbehebungsverhalten des 0.20.2-Patchreleases

## 0.20.2: `hermes kanban stats` zeigt das Alter der ältesten `ready`-Karte in Minuten

- **titel:** `hermes kanban stats` zeigt das Alter der ältesten `ready`-Karte in Minuten
- **aussage:** `hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Geändert", erster Bullet — 2026-08-09 — „`hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu `hermes kanban stats`
- **neuheit_vermutet:** vermutlich neu — Ausgabeänderung des 0.20.2-Patchreleases

## 0.20.2: `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber pro Profil überschreibbar

- **titel:** `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber pro Profil überschreibbar
- **aussage:** Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber jetzt pro Profil überschreibbar.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Geändert", zweiter Bullet — 2026-08-09 — „Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber jetzt pro Profil überschreibbar."
- **version:** 0.20.2
- **betrifft_vermutlich:** Wiki-Seiten zu Dispatcher-Konfiguration, `dispatch_stale_timeout_seconds`
- **neuheit_vermutet:** vermutlich neu — Konfigurationsänderung des 0.20.2-Patchreleases