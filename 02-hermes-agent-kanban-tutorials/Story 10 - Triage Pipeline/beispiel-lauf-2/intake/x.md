# Scout-Bericht: x

Ausgewertet: 3 Dateien unter sources/x
Kandidaten: 3

## Sub-Agenten versagen ab ~60 MCP-Werkzeugen im Kontext

- **behauptung:** Ab ungefaehr 60 geladenen MCP-Werkzeugen im Kontext kippen die Sub-Agenten: Sie greifen stumpf das falsche Werkzeug oder gar keins und bekommen ihre Aufgabe nicht hin, waehrend der Haupt-Agent damit noch zurechtkommt.
- **quellen:**
  - `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03 — "Drei Stunden verbrannt. Meine Sub-Agenten bekamen die Aufgabe einfach nicht hin — sie haben stumpf das falsche Werkzeug gegriffen oder gar keins."
  - `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03 — "Ab ungefaehr 60 Werkzeugen im Kontext kippt es. Der Haupt-Agent kommt damit klar, die Sub-Agenten nicht."
- **warum_relevant:** Eine unabhaengige Stimme, aber mit konkret verlorenen Stunden (drei Stunden fuer eine Aufgabe). Der Ausloeser — viele MCP-Server dazuklemmen — duerfte mit wachsenden Tool-Einrichtungen haeufiger werden.
- **loesbar_oder_erklaerbar:** erklaeren — der Mechanismus (Sub-Agenten verlieren bei zu vielen Werkzeugen die Orientierung) ist erklaerbar; eine Loesung (Begrenzen/Kuratieren der Werkzeugauswahl je Sub-Agent) ist zumindest denkbar.
- **loesungsluecke:** Der Autor betont, dass keine Doku eine Zahl nennt: "Niemand sagt dir das. In keiner Doku steht eine Zahl." Ein dokumentierter Richtwert oder ein Warnmechanismus fehlt.
- **strategische_passung:** hoch — betrifft Menschen, die KI-Coding-Agenten mit vielen Werkzeugen/MCP-Servern erweitern, sprich das Publikum des Kanals direkt.

## IDE-Erweiterung und Agent lesen eine andere config.toml als die Oberflaeche schreibt

- **behauptung:** Der Agent liest eine andere config.toml als die IDE-Oberflaeche sie schreibt, sodass eine in der Oberflaeche gesetzte Einstellung („approve required") vom Agenten ignoriert wird, und es gibt kein Werkzeug, das anzeigt, welche Datei tatsaechlich gewinnt.
- **quellen:**
  - `sources/x/2026-08-05-config-pfad.md` — @tnowak (X), 2026-08-05 — "Ich habe in der IDE-Erweiterung sauber 'approve required' gesetzt. Der Agent hat trotzdem ohne Rueckfrage geschrieben."
  - `sources/x/2026-08-05-config-pfad.md` — @tnowak (X), 2026-08-05 — "die Erweiterung liest eine ANDERE config.toml als die IDE-Oberflaeche sie schreibt. Zwei Pfade, ein Name, keine Warnung. Unter WSL kommt noch ein dritter dazu."
- **warum_relevant:** Eine unabhaengige Stimme, aber der Vorfall hat Sicherheitsrelevanz (Freigabe-Pflicht wird umgangen) und kostete den Autor zwei Tage Suche.
- **loesbar_oder_erklaerbar:** erklaeren — welche config.toml gewinnt, ist erklaerbar und behebbar; die Verwechslungsgefahr bei gleichnamigen Configs an mehreren Pfaden ist benennbar.
- **loesungsluecke:** Der Autor stellt fest: "Es gibt kein Werkzeug, das dir sagt, welche Datei tatsaechlich gewinnt." Ein Aufloesungs-/Diagnose-Werkzeug fehlt.
- **strategische_passung:** hoch — betrifft Konfiguration und Vertrauen in Agenten-Freigabe, ein Kern-Thema fuer Nutzer von KI-Coding-Agenten.

## Agent packt zwei Emojis in jede Commit-Message

- **behauptung:** Der Agent versieht jede Commit-Message mit zwei Emojis, was in der Historie albern aussieht und beim Grepen stoert; ob man das abstellen kann, ist dem Nutzer unbekannt.
- **quellen:**
  - `sources/x/2026-08-06-emoji.md` — @sbrandt (X), 2026-08-06 — "mein Agent packt in jede Commit-Message zwei Emojis. In der Historie sieht das albern aus, und beim Grepen stoert es auch."
  - `sources/x/2026-08-06-emoji.md` — @sbrandt (X), 2026-08-06 — "Ich habe noch nicht nachgesehen, ob man das irgendwo abstellen kann — vermutlich gibt es eine Einstellung. Kostet mich keine Zeit, es ist einfach haesslich."
- **warum_relevant:** Eine unabhaengige Stimme; rein kosmetisch und ohne verlorene Zeit, aber vom Nutzer tatsaechlich als wiederkehrende Aergernis erlebt („seit Wochen nervt").
- **loesbar_oder_erklaerbar:** erklaeren — vermutlich eine vorhandene Einstellung, die man dem Nutzer sauber erklaeren kann; andernfalls bauen.
- **loesungsluecke:** Keine gefunden; der Nutzer vermutet nur eine Einstellung, hat sie aber nicht verifiziert.
- **strategische_passung:** niedrig — reine Optik ohne Funktions- oder Zeitverlust, duerfte fuer das Publikum des Kanals kaum Relevanz haben.
