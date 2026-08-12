# Scout-Bericht: web

Ausgewertet: 3 Dateien unter sources/web
Kandidaten: 2

## Ambigue Konfigurationspfade: wirksame Datei unklar, effektive Werte nicht einsehbar

- **behauptung:** Mehrere Kandidaten fuer die Konfigurationsdatei (Home-Verzeichnis, Projektpfad, WSL- und Windows-Roaming-Pfad) machen unklar, welche Datei tatsaechlich wirkt; die Erweiterung nimmt nicht die erwartete, und es gibt keine Anzeige der effektiven Werte.
- **quellen:**
  - `forum-konfigurationspfade.md` — wenzelb, Entwicklerforum, 2026-08-06 — "Ich habe drei Kandidaten fuer die Konfigurationsdatei gefunden — im Home-Verzeichnis, unter dem Projektpfad und einmal in der WSL-Umgebung. Die Erweiterung nimmt nicht die, die ich erwarte."
  - `forum-konfigurationspfade.md` — marek.o, Entwicklerforum, 2026-08-06 — "Bei uns dasselbe Problem, mit echten Folgen: die Freigabepflicht war in der Oberflaeche gesetzt und in der wirksamen Datei nicht. Der Agent hat in einem Kundenrepo committet."
  - `forum-konfigurationspfade.md` — marek.o, Entwicklerforum, 2026-08-06 — "Nein. Ich mache es mit `find` und lese von Hand. Unter Windows kommt der Roaming-Pfad noch dazu, dann sind es vier Stellen."
- **warum_relevant:** Zwei unabhaengige Stimmen (wenzelb, marek.o) bestaetigen dieselbe Verwechslung der Konfigurationspfade. marek.o beschreibt einen realen Schaden (Commit im Kundenrepo trotz Freigabepflicht) und die fehlende Einsicht in die wirksamen Werte.
- **loesbar_oder_erklaerbar:** erklaeren — Der Vorrang der Konfigurationspfade und die Reihenfolge der Dateisuche sind sauber erklaerbar; ein Agent kann die wirksame Datei und die effektiven Werte aufzeigen.
- **loesungsluecke:** Nichts gefunden — laut Quelle gibt es keine Anzeige der effektiven Werte ("Gibt es irgendwas, das einem die effektiven Werte anzeigt?" / "Nein."); die Nutzer greifen zu `find` und handischem Lesen.
- **strategische_passung:** mittel — Betrifft eine Konfigurations-Usability-Frage mit klar benanntem Symptom, aber ohne wiederkehrende Mehrfachbestaetigung ueber mehrere unabhaengige Threads.

## Sub-Agenten waehlen Werkzeuge falsch, sobald zu viele Werkzeuge/MCP-Server im Kontext sind

- **behauptung:** Ab einer Schwelle von zu vielen aktivierten MCP-Servern bzw. zu vielen Werkzeugbeschreibungen im Kontext faellt die Trefferquote der Werkzeugwahl von Sub-Agenten stark ab, waehrend der Haupt-Agent nichts merkt. Abhilfe schafft eine pro Sub-Agent gesetzte Allow-List, die aber nirgends dokumentiert ist.
- **quellen:**
  - `reddit-subagenten-werkzeugflut.md` — u/halbmond, Reddit — r/aiagents, 2026-08-04 — "Sobald ich mehr als vier MCP-Server aktiv habe, faellt die Trefferquote meiner Sub-Agenten ins Bodenlose. Der Haupt-Agent merkt nichts."
  - `reddit-subagenten-werkzeugflut.md` — u/kd_rasmus, Reddit — r/aiagents, 2026-08-04 — "Bei mir kippt es zwischen 50 und 70 Werkzeugen. Ich habe es nachgemessen: 40 Werkzeuge -> 9 von 10 Laeufe gut, 80 Werkzeuge -> 3 von 10."
  - `reddit-subagenten-werkzeugflut.md` — u/aniela.p, Reddit — r/aiagents, 2026-08-04 — "Bei uns im Team dasselbe, seit Wochen. Wir dachten erst, es liegt am Modell."
  - `reddit-subagenten-werkzeugflut.md` — u/halbmond, Reddit — r/aiagents, 2026-08-04 — "Loesung gefunden: pro Sub-Agent eine Allow-List setzen, dann sieht er nur seine sechs Werkzeuge. Geht seit einer Weile, steht aber nirgends in der Doku — ich habe es aus einem Changelog-Eintrag von vor vier Monaten."
  - `reddit-subagenten-werkzeugflut.md` — u/kd_rasmus, Reddit — r/aiagents, 2026-08-04 — "Der Konfigurationsschluessel heisst nicht so, wie man ihn suchen wuerde."
  - `youtube-kommentare-agenten-werkzeuge.md` — @renkoe, YouTube — Kommentare unter "Agent Setup 2026", 2026-08-07 — "Kann jemand erklaeren, warum meine untergeordneten Agenten Werkzeuge nicht benutzen? Der Haupt-Agent benutzt dieselben Werkzeuge problemlos."
  - `youtube-kommentare-agenten-werkzeuge.md` — @ilvahn, YouTube, 2026-08-07 — "Wie viele MCP-Server hast du an? Bei mir ging es kaputt, als ich auf sieben hoch bin. Zu viele Werkzeugbeschreibungen im Kontext, der untergeordnete Agent waehlt dann daneben."
  - `youtube-kommentare-agenten-werkzeuge.md` — @ilvahn, YouTube, 2026-08-07 — "Gib jedem Unteragenten nur die Werkzeuge, die er braucht. Dann laeuft es wieder."
- **warum_relevant:** Sieben unabhaengige Stimmen ueber zwei getrennte Threads (Reddit 4, YouTube 3) bestaetigen denselben Fehlermechanismus: zu viele Werkzeuge/MCP-Server verschlechtern die Werkzeugwahl von Sub-Agenten. kd_rasmus liefert gemessene Zahlen (40 Werkzeuge -> 9 von 10 gut, 80 Werkzeuge -> 3 von 10) und nennt die Schwelle "zwischen 50 und 70 Werkzeugen".
- **loesbar_oder_erklaerbar:** erklaeren — Die Ursache (Kontextueberfluss durch zu viele Werkzeugbeschreibungen) und die Abhilfe (Allow-List je Sub-Agent) sind klar benannt und von mehreren Stimmen bestaetigt; das laesst sich als Anleitung gut erklaeren und als Empfehlung bauen.
- **loesungsluecke:** Es gibt bereits eine funktionierende Loesung (pro Sub-Agent Allow-List), aber sie ist laut Quelle nirgends in der Doku, nur in einem Changelog-Eintrag von vor vier Monaten; der Konfigurationsschluessel heisst nicht erwartbar. Die Dokumentationsluecke ist ungefuellt.
- **strategische_passung:** hoch — Mehrfach bestaetigtes, haeufig wiederkehrendes Problem mit messbarem Effekt, direkt relevant fuer ein Publikum, das mit Agenten/multi-Agent-Setups arbeitet.
