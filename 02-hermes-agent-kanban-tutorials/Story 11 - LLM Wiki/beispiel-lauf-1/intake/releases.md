# Scout-Bericht: releases

Ausgewertet: 3 Dateien unter sources/releases
Kandidaten: 19

Releases im Korpus:
- release-0.20.0-velocity.md (0.20.0, 2026-08-03, Hauptrelease)
- changelog-0.20.1.md (0.20.1, 2026-08-06, Patch)
- changelog-0.20.2.md (0.20.2, 2026-08-09, Patch)

---

## Kanban: neue Spalte `review` mit eigenem Review-Agenten

- **aussage:** Erzeugt ein Worker einen Pull Request, gibt er seine Karte an die neue Spalte `review` weiter; der Dispatcher startet dafür einen eigenen Review-Agenten mit der Skill `sdlc-review`, der die Karte entweder merged (→ `done`) oder zurückschickt (→ `running`).
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu" / „Kanban", 2026-08-03 — „**Kanban:** neue Spalte `review`. Erzeugt ein Worker einen Pull Request, gibt er die Karte nach `review` weiter; der Dispatcher startet dafür einen eigenen Review-Agenten mit der Skill `sdlc-review`, der entweder merged (→ `done`) oder die Karte zurückgibt (→ `running`)."
- **version:** 0.20.0
- **betrifft_vermutlich:** `kanban-board`, `gateway-und-dispatcher`
- **neuheit_vermutet:** vermutlich neu — eine `review`-Spalte und ein `sdlc-review`-Agent ist kein Thema, das sich aus älteren Release-Notizen erschließen lässt.

## Kanban: `hermes kanban swarm` als Ein-Befehl-Fan-out mit Verifier und Synthese

- **aussage:** Der Befehl `hermes kanban swarm "<ziel>" --worker P:T --verifier P --synthesizer P` führt Fan-out, Verifier und Synthese in einem Befehl aus.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu" / „Kanban", 2026-08-03 — „**Kanban:** `hermes kanban swarm \"<ziel>\" --worker P:T --verifier P --synthesizer P` — Fan-out, Verifier und Synthese in einem Befehl."
- **version:** 0.20.0
- **betrifft_vermutlich:** `kanban-board`, `gateway-und-dispatcher`
- **neuheit_vermutet:** vermutlich neu — ein neues Unterkommando `swarm` mit konkretem Flag-Satz.

## Kanban: `--goal` und `--goal-max-turns` mit Judge pro Runde

- **aussage:** Das Kanban-System hat die Flags `--goal` und `--goal-max-turns`; ein Judge prüft nach jeder Runde, ob die Karte erfüllt ist.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu" / „Kanban", 2026-08-03 — „**Kanban:** `--goal` und `--goal-max-turns`. Ein Judge prüft nach jeder Runde, ob die Karte erfüllt ist."
- **version:** 0.20.0
- **betrifft_vermutlich:** `kanban-board`
- **neuheit_vermutet:** vermutlich neu — der Judge-/Goal-Mechanismus ist eine neue Steuerungsebene.

## Cron: `--no-agent` ohne Modell und Tokenkosten

- **aussage:** Ein Cron-Job mit `--no-agent` nutzt kein Modell und erzeugt keine Tokenkosten; das Skript ist der Job.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu" / „Cron", 2026-08-03 — „**Cron:** `--no-agent`. Kein Modell, keine Tokenkosten — das Skript ist der Job."
- **version:** 0.20.0
- **betrifft_vermutlich:** `cron-und-zeitplan`
- **neuheit_vermutet:** vermutlich neu — ein Modus, der ohne LLM auskommt (2026-08-06, 0.20.1, präzisiert das Ausgabe-Verhalten dieses Modus weiter).

## Profile: `hermes profile install` für Distributionen mit `distribution.yaml`

- **aussage:** `hermes profile install <git-url|verzeichnis>` installiert Profile aus Distributionen, die eine `distribution.yaml` mitbringen.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Neu" / „Profile", 2026-08-03 — „**Profile:** `hermes profile install <git-url|verzeichnis>` für Distributionen mit `distribution.yaml`."
- **version:** 0.20.0
- **betrifft_vermutlich:** `profile-system`
- **neuheit_vermutet:** vermutlich neu — ein neuer Installationsbefehl für Profile (0.20.2 korrigiert einen Fehler genau dieser Funktion).

## Deprecated: `hermes kanban daemon`; Dispatcher lebt im Gateway

- **aussage:** Das Unterkommando `hermes kanban daemon` ist deprecated; der Dispatcher lebt im Gateway und wird mit `hermes gateway start` gestartet.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Deprecated", 2026-08-03 — „`hermes kanban daemon`. Der Dispatcher lebt im Gateway (`hermes gateway start`)."
- **version:** 0.20.0
- **betrifft_vermutlich:** `gateway-und-dispatcher`, `kanban-board`
- **neuheit_vermutet:** vermutlich neu — eine Deprecation mit verlagertem Startpunkt des Dispatchers (0.20.2 ändert das Tick-Verhalten desselben Gateway-Dispatchers).

## Migration: keine Schritte nötig, Boards werden beim ersten Zugriff migriert

- **aussage:** Für den Wechsel auf 0.20.0 sind keine Migrationsschritte nötig; bestehende Boards werden beim ersten Zugriff migriert.
- **quellen:**
  - `release-0.20.0-velocity.md` — Abschnitt „Migration", 2026-08-03 — „Keine Schritte nötig. Bestehende Boards werden beim ersten Zugriff migriert."
- **version:** 0.20.0
- **betrifft_vermutlich:** `kanban-board`
- **neuheit_vermutet:** vermutlich abgedeckt — eine Aussage vom Typ „keine Migration nötig" dürfte als Teil der Release-Historie bereits erfasst sein.

## `--initial-status blocked` setzt die Spalte, ist aber kein Tor

- **aussage:** `--initial-status blocked` setzt die Spalte eines Kanban-Cards, erzeugt aber **kein** `blocked`-Ereignis und ist deshalb kein Tor; nur ein echtes `block` bzw. `kanban_block()` hält eine Karte. Das Verhalten selbst ist unverändert, lediglich die Dokumentation wurde korrigiert, nachdem `recompute_ready` solche Karten nach Fertigstellung der Eltern beförderte.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben" / „Kanban / Dispatcher", 2026-08-06 — „`recompute_ready` beförderte Karten mit `--initial-status blocked` mit, sobald deren Eltern fertig waren. Karten, die als Wartepunkt gedacht waren, liefen dadurch stumm durch. Das Verhalten ist **unverändert** — dokumentiert ist nun ausdrücklich, dass `--initial-status blocked` die Spalte setzt, aber **kein** `blocked`-Ereignis erzeugt, und deshalb kein Tor ist. Nur ein echtes `block` bzw. `kanban_block()` hält."
- **version:** 0.20.1
- **betrifft_vermutlich:** `kanban-block-semantik`, `kanban-board`
- **neuheit_vermutet:** vermutlich abgedeckt — die Block-Semantik dürfte bereits eine eigene Seite haben; fraglich ist, ob die dokumentierte Abgrenzung von `--initial-status blocked` dort schon steht.

## Korrektur: `hermes kanban block` nimmt den Grund positional

- **aussage:** `hermes kanban block` nimmt den Grund bereits seit 0.20.0 **positional** als Argument entgegen; die Dokumentation zeigte fälschlich `--reason` und wurde korrigiert. `--kind` muss **vor** der Kartennummer stehen. Bei `unblock` bleibt `--reason` bestehen und legt den Text als Kommentar an die Karte, bevor sie nach `ready` geht.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben" / „Kanban / CLI", 2026-08-06 — „`hermes kanban block` nahm den Grund bereits seit 0.20.0 **positional**; die Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist korrigiert. `--kind` muss **vor** der Kartennummer stehen. Bei `unblock` gibt es `--reason` weiterhin, und dort legt es den Text als Kommentar an die Karte, bevor sie nach `ready` geht."
- **version:** 0.20.1 (Verhalten seit 0.20.0)
- **betrifft_vermutlich:** `kanban-block-semantik`, `kanban-board`
- **neuheit_vermutet:** vermutlich abgedeckt — die Block-/Unblock-Syntax gehört zur Block-Semantik-Seite; die korrigierte Argumentform könnte dort noch fehlen.

## Dispatcher-Reclaim ist idempotent

- **aussage:** Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt gespawnt; der Reclaim ist jetzt idempotent.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben" / „Kanban / Dispatcher", 2026-08-06 — „Ein Claim, dessen Worker ohne `kanban_heartbeat` lief, wurde in seltenen Fällen zweimal eingesammelt und die Karte doppelt gespawnt. Der Reclaim ist jetzt idempotent."
- **version:** 0.20.1
- **betrifft_vermutlich:** `gateway-und-dispatcher`, `kanban-board`
- **neuheit_vermutet:** vermutlich neu — ein behebbares Dispatcher-Verhalten, das in der Wissensbasis vermutlich nicht dokumentiert ist.

## Cron `--no-agent`: leere Läufe erzeugen keine Datei mehr

- **aussage:** Cron-Jobs mit `--no-agent` schrieben bei leerem stdout eine leere Ausgabedatei unter `~/.hermes/cron/output/<job-id>/`; seit dem Fix erzeugen leere Läufe keine Datei mehr.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Behoben" / „Cron", 2026-08-06 — „Jobs mit `--no-agent` schrieben bei leerem stdout eine leere Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen keine Datei mehr."
- **version:** 0.20.1
- **betrifft_vermutlich:** `cron-und-zeitplan`
- **neuheit_vermutet:** vermutlich neu — das Ausgabeverhalten des `--no-agent`-Modus dürfte auf der Cron-Seite nicht dokumentiert sein.

## `hermes kanban diagnostics` zeigt die Block-Art

- **aussage:** `hermes kanban diagnostics` weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Geändert", 2026-08-06 — „`hermes kanban diagnostics` weist blockierte Karten jetzt mit ihrer Block-Art (`kind`) aus, statt nur mit dem Grund."
- **version:** 0.20.1
- **betrifft_vermutlich:** `kanban-block-semantik`, `kanban-board`
- **neuheit_vermutet:** vermutlich neu — eine geänderte Ausgabe eines Diagnose-Befehls (hängt mit der Block-Art-Terminologie aus 0.20.2 zusammen).

## Einschränkung: `kanban complete` mit Handoff-Flags und mehreren Karten bleibt abgewiesen

- **aussage:** `hermes kanban complete a b c --summary …` wird weiterhin abgewiesen, sobald Handoff-Flags gesetzt sind; das ist Absicht, weil Summary und Metadata je Run gelten und dieselbe Zusammenfassung auf mehrere Karten kopiert fast immer falsch ist.
- **quellen:**
  - `changelog-0.20.1.md` — Abschnitt „Bekannte Einschränkung", 2026-08-06 — „`hermes kanban complete a b c --summary …` bleibt abgewiesen, wenn Handoff-Flags gesetzt sind. Das ist Absicht: Summary und Metadata gelten je Run, und dieselbe Zusammenfassung auf drei Karten zu kopieren ist fast immer falsch."
- **version:** 0.20.1
- **betrifft_vermutlich:** `kanban-board`
- **neuheit_vermutet:** vermutlich neu — eine dokumentierte Verhaltensgrenze des `complete`-Befehls.

## Block-Schleifen erkennen und in die Triage verschieben

- **aussage:** Wird eine Karte nach einem `unblock` erneut mit **derselben** Block-Art blockiert, landet sie in der Triage statt in `blocked`. Der Zähler `block_recurrences` wird pro Block-Art geführt und **nur bei erfolgreichem Abschluss** zurückgesetzt. Neu ist ein Ereignis `block_loop_detected`, das Zähler und Grenze im Payload trägt; vorher war es ein gewöhnliches `blocked`-Ereignis und der Wechsel in die Triage war von außen nicht erkennbar. Ein Betreiberhinweis ergänzt: Wer zwei menschliche Tore auf **derselben** Karte baut, muss für das zweite Tor eine andere Block-Art wählen.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben" / „Kanban / Block-Schleifen", 2026-08-09 — „Eine Karte, die nach einem `unblock` erneut mit **derselben** Block-Art blockiert wird, landet in der Triage statt in `blocked`. Der Zähler dafür (`block_recurrences`) wird pro Block-Art geführt und **nur bei erfolgreichem Abschluss** zurückgesetzt. Neu ist, dass das ausgelöste Ereignis `block_loop_detected` heißt und Zähler und Grenze im Payload trägt; vorher war es ein gewöhnliches `blocked`-Ereignis und der Wechsel in die Triage war von außen nicht erkennbar."
  - `changelog-0.20.2.md` — Abschnitt „Hinweis für Betreiber", 2026-08-09 — „Wer eine Pipeline mit zwei aufeinanderfolgenden menschlichen Toren auf **derselben** Karte baut, muss für das zweite Tor eine **andere** Block-Art wählen — sonst greift die Schleifenerkennung aus diesem Release und die Karte geht in die Triage statt in `blocked`."
- **version:** 0.20.2
- **betrifft_vermutlich:** `kanban-block-semantik`, `kanban-board`
- **neuheit_vermutet:** vermutlich neu — die Schleifenerkennung ist eine neue Mechanik der Block-Semantik (BLOCK_RECURRENCE-Logik wird in ingest.yaml bereits referenziert, die KB-Seite dürfte es noch nicht kennen).

## `kanban_create` weist relativen `workspace_path` ab

- **aussage:** Ein relativer `workspace_path` in `kanban_create` wird jetzt mit einer Meldung abgewiesen; zuvor wurde er stillschweigend akzeptiert, wodurch die Karte entstand, aber nie gestartet wurde und keine Fehlermeldung auf dem Board erschien.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben" / „Kanban / `kanban_create` im Worker", 2026-08-09 — „Ein relativer `workspace_path` wurde stillschweigend abgewiesen — die Karte entstand, wurde aber nie gestartet und es gab keine Fehlermeldung auf dem Board. Der Aufruf schlägt jetzt mit einer Meldung fehl, statt eine unstartbare Karte zu hinterlassen."
- **version:** 0.20.2
- **betrifft_vermutlich:** `kanban-board`
- **neuheit_vermutet:** vermutlich neu — ein Randverhalten des `kanban_create`-Aufrufs im Worker.

## `hermes profile install` übernimmt `description` aus `distribution.yaml`

- **aussage:** `hermes profile install` aus einem lokalen Verzeichnis hat die `description` aus `distribution.yaml` nicht in `profile.yaml` übernommen; dadurch blieb ein installiertes Profil für den Kanban-Decomposer unsichtbar, der über die Beschreibung routet. Das ist behoben.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben" / „Profile", 2026-08-09 — „`hermes profile install` aus einem lokalen Verzeichnis übernahm die `description` aus `distribution.yaml` nicht in `profile.yaml`. Damit blieb ein installiertes Profil für den Kanban-Decomposer unsichtbar, weil der über die Beschreibung routet. Behoben."
- **version:** 0.20.2
- **betrifft_vermutlich:** `profile-system`, `kanban-board`
- **neuheit_vermutet:** vermutlich neu — ein korrigierter Installationsmechanismus für Profile.

## Gateway: Tick bricht nach `hermes pause` nach dem aktuellen Spawn ab

- **aussage:** Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns noch weiter; der Tick bricht jetzt nach dem aktuellen Spawn ab.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Behoben" / „Gateway", 2026-08-09 — „Nach `hermes pause` beendete ein bereits laufender Tick seine Spawns noch. Der Tick bricht jetzt nach dem aktuellen Spawn ab."
- **version:** 0.20.2
- **betrifft_vermutlich:** `gateway-und-dispatcher`
- **neuheit_vermutet:** vermutlich neu — ein geändertes Stopp-Verhalten des Gateway-Dispatchers.

## `hermes kanban stats` zeigt Alter der ältesten `ready`-Karte in Minuten

- **aussage:** `hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Geändert", 2026-08-09 — „`hermes kanban stats` zeigt zusätzlich das Alter der ältesten `ready`-Karte in Minuten statt nur als Zeitstempel."
- **version:** 0.20.2
- **betrifft_vermutlich:** `kanban-board`
- **neuheit_vermutet:** vermutlich neu — eine erweiterte Ausgabe eines Statistik-Befehls.

## `kanban.dispatch_stale_timeout_seconds` ist pro Profil überschreibbar

- **aussage:** Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber jetzt pro Profil überschreibbar.
- **quellen:**
  - `changelog-0.20.2.md` — Abschnitt „Geändert", 2026-08-09 — „Der Standardwert von `kanban.dispatch_stale_timeout_seconds` bleibt 14400, ist aber jetzt pro Profil überschreibbar."
- **version:** 0.20.2
- **betrifft_vermutlich:** `gateway-und-dispatcher`, `kanban-board`
- **neuheit_vermutet:** vermutlich abgedeckt — der Standardwert ist vermutlich bereits bekannt; die neue pro-Profil-Überschreibbarkeit könnte dort fehlen.
