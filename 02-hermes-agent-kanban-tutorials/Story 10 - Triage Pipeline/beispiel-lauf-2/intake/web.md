# Scout-Bericht: web

Ausgewertet: 3 Dateien unter sources/web
Kandidaten: 3

## Konfigurationsaufloesung mehrdeutig, wirksame Werte nicht sichtbar

- **behauptung:** Mehrere moegliche Konfigurationsdatei-Speicherorte (Home, Projektpfad, WSL, unter Windows zusaetzlich Roaming) machen unklar, welche Datei wirksam ist; es gibt kein Werkzeug, das die effektiven Werte anzeigt, wodurch die falsche Datei Anwendung findet — mit echten Folgen.
- **quellen:**
  - `forum-konfigurationspfade.md` — Entwicklerforum, 2026-08-06 — "Ich habe drei Kandidaten fuer die Konfigurationsdatei gefunden — im Home-Verzeichnis, unter dem Projektpfad und einmal in der WSL-Umgebung. Die Erweiterung nimmt nicht die, die ich erwarte." (wenzelb)
  - `forum-konfigurationspfade.md` — Entwicklerforum, 2026-08-06 — "Bei uns dasselbe Problem, mit echten Folgen: die Freigabepflicht war in der Oberflaeche gesetzt und in der wirksamen Datei nicht. Der Agent hat in einem Kundenrepo committet." (marek.o)
  - `forum-konfigurationspfade.md` — Entwicklerforum, 2026-08-06 — "Nein. Ich mache es mit `find` und lese von Hand. Unter Windows kommt der Roaming-Pfad noch dazu, dann sind es vier Stellen." (marek.o, auf die Frage "Gibt es irgendwas, das einem die effektiven Werte anzeigt?")
- **warum_relevant:** Mindestens zwei unabhaengige Stimmen (wenzelb, marek.o) im selben Faden bestaetigen denselben Mechanismus; marek.o beschreibt eine reale, schadensbehaftete Folge (Agent committet in einem Kundenrepo, weil die in der Oberflaeche gesetzte Freigabepflicht nicht in der wirksamen Datei stand). Die Nachfrage nach einer Anzeige der effektiven Werte bleibt unbeantwortet — es gibt offenbar keine.
- **loesbar_oder_erklaerbar:** erklaeren — ein Agent kann die Aufloesungsreihenfolge der Konfigdateien klar erklaeren und den jeweils wirksamen Pfad samt Werten aufzeigen.
- **loesungsluecke:** nichts gefunden — kein Werkzeug zeigt die effektiven Werte; der Nutzer liest sie von Hand per `find` aus. Hervorgehoben wird zudem, dass in denselben Dateien API-Keys liegen (tessa_k: "Aufpassen beim Herzeigen — in denselben Dateien stehen API-Keys.").
- **strategische_passung:** mittel — betrifft Nutzer, die einen Agenten mit lokaler Konfiguration einsetzen; ein Kanal-Thema, das sich gut erklaeren laesst.

## Werkzeugflut durch zu viele MCP-Server laesst Sub-/Unteragenten Werkzeuge falsch waehlen

- **behauptung:** Sobald zu viele MCP-Server bzw. Werkzeugbeschreibungen aktiv sind, faellt die Trefferquote von Unter-/Sub-Agenten beim Werkzeuggebrauch ab, waehrend der Haupt-Agent unbeeindruckt bleibt.
- **quellen:**
  - `youtube-kommentare-agenten-werkzeuge.md` — YouTube, 2026-08-07 — "Kann jemand erklaeren, warum meine untergeordneten Agenten Werkzeuge nicht benutzen? Der Haupt-Agent benutzt dieselben Werkzeuge problemlos." (@renkoe)
  - `youtube-kommentare-agenten-werkzeuge.md` — YouTube, 2026-08-07 — "Wie viele MCP-Server hast du an? Bei mir ging es kaputt, als ich auf sieben hoch bin. Zu viele Werkzeugbeschreibungen im Kontext, der untergeordnete Agent waehlt dann daneben." (@ilvahn)
  - `reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — "Sobald ich mehr als vier MCP-Server aktiv habe, faellt die Trefferquote meiner Sub-Agenten ins Bodenlose. Der Haupt-Agent merkt nichts." (OP u/halbmond)
  - `reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — "Bei mir kippt es zwischen 50 und 70 Werkzeugen. Ich habe es nachgemessen: 40 Werkzeuge -> 9 von 10 Laeufe gut, 80 Werkzeuge -> 3 von 10." (u/kd_rasmus)
  - `reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — "Bei uns im Team dasselbe, seit Wochen. Wir dachten erst, es liegt am Modell." (u/aniela.p)
- **warum_relevant:** Zwei unabhaengige Quellen mit zusammen mindestens vier bis fuenf unabhaengigen Stimmen bestaetigen denselben Fehlermechanismus (zu viele MCP-Server/Werkzeuge -> Sub-Agent waehlt daneben, Haupt-Agent bleibt unberuehrt). Eine Stimme (kd_rasmus) hat das mit einer Messung belegt (40 Werkzeuge -> 9/10 gut, 80 Werkzeuge -> 3/10); eine weitere (aniela.p) berichtet, das Team haette es wochenlang fuer ein Modellproblem gehalten.
- **loesbar_oder_erklaerbar:** erklaeren — die Ursache (zu viele Werkzeugbeschreibungen im Kontext) ist benannt, und die erprobte Umgehung (pro Sub-Agent eine Werkzeug-Allow-List) ist belegt.
- **loesungsluecke:** eine pro-Sub-Agent-Allow-List existiert als Umgehung, ist aber schlecht auffindbar (Details im naechsten Kandidaten); eine automatische Werkzeugbegrenzung/Erklaerung seitens des Tools wird nicht erwaehnt.
- **strategische_passung:** hoch — betrifft genau das Publikum des Kanals (Nutzer von KI-Agenten mit mehreren MCP-Servern) und wird von mehreren Stimmen unabhaengig bestaetigt.

## Umgehung gegen Werkzeugflut (Allow-List) ist nicht dokumentiert, Schluesselname irrefuehrend

- **behauptung:** Die existierende Loesung — pro Sub-Agent eine Werkzeug-Allow-List setzen — steht nirgends in der Doku, und der Konfigurationsschluessel hat einen Namen, den man so nicht suchen wuerde, wodurch die Loesung schwer auffindbar ist.
- **quellen:**
  - `reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — "Loesung gefunden: pro Sub-Agent eine Allow-List setzen, dann sieht er nur seine sechs Werkzeuge. Geht seit einer Weile, steht aber nirgends in der Doku — ich habe es aus einem Changelog-Eintrag von vor vier Monaten." (OP u/halbmond)
  - `reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — "Kann ich bestaetigen. Der Konfigurationsschluessel heisst nicht so, wie man ihn suchen wuerde." (u/kd_rasmus)
- **warum_relevant:** Zwei unabhaengige Stimmen bestaetigen, dass die Loesung existiert, aber nicht auffindbar ist — einer musste einen Changelog-Eintrag von vor vier Monaten ausgraben, ein anderer bestaetigt, dass der Schluesselname nicht den Erwartungen bei der Suche entspricht.
- **loesbar_oder_erklaerbar:** erklaeren — ein Agent kann die existierende Funktion samt korrektem Schluesselnamen erklaeren und den Weg in die Doku aufzeigen.
- **loesungsluecke:** die Loesung existiert, ist aber nicht dokumentiert bzw. schlecht benannt; eine Doku- oder Benennungsverbesserung fehlt.
- **strategische_passung:** mittel — betrifft dasselbe Agenten-Publikum wie der vorige Kandidat, ist aber eher ein Doku-/Erklaerungsmangel; gut fuer ein Video-Format darstellbar.
