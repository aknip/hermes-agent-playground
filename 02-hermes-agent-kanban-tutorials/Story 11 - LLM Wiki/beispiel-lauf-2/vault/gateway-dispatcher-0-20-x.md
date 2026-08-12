---
slug: gateway-dispatcher-0-20-x
titel: "Gateway/Dispatcher-Ergaenzungen aus 0.20.x: doppelter Reclaim idempotent, Tick bricht nach pause ab, dispatch_stale_timeout pro Profil ueberschreibbar"
status: zurueckgestellt
score: 66
score_breakdown: {neuheit: 12, quellenvertrauen: 16, themenbezug: 20,
                  versionsrelevanz: 12, klarheitsgewinn: 6}
wissensstand:
route:
gebuendelt_aus:
  - "intake/releases.md (0.20.1/0.20.2): 'Doppelter Reclaim von Claims ist durch Idempotenz behoben' ; 'Gateway-Tick bricht nach hermes pause nach dem aktuellen Spawn ab' ; 'kanban.dispatch_stale_timeout_seconds bleibt 14400, ist aber pro Profil ueberschreibbar'"
betrifft: [gateway-und-dispatcher]
---
Der Slug beschreibt das Item (Dispatcher-Verhalten der 0.20.x-Linie), nicht die
Quelle. Drei Kandidaten aus demselben Vorgang (Changelogs 0.20.1/0.20.2)
betreffen dieselbe Seitengruppe (`gateway-und-dispatcher.md`).

Dedup: `gateway-und-dispatcher.md` beschreibt Dispatcher, Ticks, Heartbeats
(14400) und pause/resume. Der doppelte-Reclaim-Fix (Idempotenz), das
pause-Zuendungsende nach dem aktuellen Spawn und die pro-Profil-Ueberschreibbarkeit
des Timeouts stehen in keiner Seite. Keine dieser Aussagen ist abgedeckt.

Bewertung je Dimension:
- neuheit (12/25): drei betriebliche Fehlerbehebungs-/Konfigurationsdetails,
  teils Anwendungsgrenzen bekannter Mechaniken; insgesamt nur sanft neu.
- quellenvertrauen (16/20): offizieller Changelog.
- themenbezug (20/25): direkt der Dispatcher von Hermes Agent, aber nur fuer
  Betreiber mit staerkerer Dispatch-Nutzung relevant.
- versionsrelevanz (12/15): aktuelle 0.20.x-Linie.
- klarheitsgewinn (6/15): gering; beantwortet kaum eine Agenten-Frage
  substanziell neu, es sind Randpraezisierungen fuer den Betrieb.

summe = 66 >= schwelle 65, ABER: der Deckel `rubrik.max_pro_lauf = 3` hat dieses
Item zurueckgehalten. Rang 4 nach score (88, 83, 75, 66). Diese Datei bleibt
vollstaendig erhalten und wird beim naechsten Sweep wieder aufgenommen. Das ist
KEIN Urteil ueber das Item und KEIN 'geshelved' — nur der Deckel hat es
zurueckgehalten. status: zurueckgestellt.