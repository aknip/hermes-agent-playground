# Skript: Sub-Agenten-Werkzeugflut

Pfad: video · Slug: `subagenten-werkzeugflut` · Stufe: skript
Sprechtext je Folie (90–150 Woerter), in Reihenfolge der Folien aus
`folien.md`. Zahlen mit Quelle und Datum; Details und Belegstellen in
`faktencheck.md`.

---

## Folie 1 — Der Sub-Agent waehlt das falsche Werkzeug — oder gar keins

Der Sub-Agent waehlt das falsche Werkzeug — oder gar keins. kd_rasmus hat das
gemessen und am 4. August 2026 auf Reddit beschrieben: Bei 40 Werkzeugen
liefen 9 von 10 Laeufen gut, bei 80 Werkzeugen nur noch 3 von 10. Die
Schwelle liege, schreibt er, zwischen 50 und 70 Werkzeugen. mkirsch_dev
berichtet am 3. August 2026 auf X denselben Effekt: Sub-Agenten haetten
stumpf das falsche Werkzeug gegriffen oder gar keins — und das habe ihn drei
Stunden gekostet. Beide Berichte sind Selbstauskuenfte aus dem August 2026,
keine kontrollierte Messung; darauf kommen wir am Ende zurueck.

## Folie 2 — Nur der Haupt-Agent ist unsichtbar betroffen

Das Tueckische an diesem Schaden: Er trifft nur die Sub-Agenten, und er
bleibt unsichtbar. Bei derselben Werkzeugmenge behaelt der Haupt-Agent seine
Trefferquote, waehrend die untergeordneten Agenten kippen. Das bestaetigen
halbmond, mkirsch_dev und die Kommentare von renkoe und ilvahn unabhaengig
voneinander. Typisch ist ein Muster: Der Sub-Agent greift entweder zum
falschen Werkzeug oder zu gar keinem. Wer deshalb zuerst das Modell
verdaedtigt, liegt daneben — aniela.p berichtet: Wir dachten erst, es liegt
am Modell. Weil die Fehlwahl nur in der Sub-Agent-Ebene auftritt, bleibt der
Schaden unsichtbar, solange ausschliesslich der Haupt-Agent beobachtet wird.

## Folie 3 — Der Mechanismus: Werkzeugbeschreibungen im Kontext

Der wirksame Faktor ist die Zahl der Werkzeugbeschreibungen im Kontext — nicht
ein Zaehler der MCP-Server. ilvahn nennt den Mechanismus explizit, und die
Aussagen konvergieren ueber das Korpus hinweg. Die von den Erzaehlern
genannten Server-Zahlen — mehr als vier, sieben, neun, sechs — sind ein
anderes Mass als die Werkzeugzahl und streuen. Sub-Agenten kippen bei der
Menge, auf der der Haupt-Agent stabil bleibt. Und die Schwellenangaben zu
Werkzeugen stimmen ueberein: zwischen 50 und 70 laut kd_rasmus, ungefaehr 60
laut mkirsch_dev. Der wirksame Hebelpunkt ist also der Kontextumfang, nicht
ein einzelner Server.

## Folie 4 — Keine dokumentierte Grenze

Eine Grenze ist nirgends dokumentiert. mkirsch_dev bringt es auf den Punkt:
Niemand sagt dir das. In keiner Doku steht eine Zahl. Im eingefrorenen Korpus
dieser Pipeline findet sich tatsaechlich keine Schweilen-Dokumentation und
kein offizielles Tool-Limit. Auch die Referenz-Doku der Umgebung nennt keine
konkrete Tool-Zahl. Sie begruendet Filterung mit Sicherheit und der Sauberkeit
der Werkzeuglisten — nicht mit der Selektionsgenauigkeit der Sub-Agenten.
Selbst der Abschnitt über aktuelle Limits in der MCP-Dokumentation betrifft
nur den eingebetteten hermes mcp serve und keine Tool-Anzahl. Ohne eine Grenze
bleibt den Betroffenen nur das Raten. Und wer raten muss, verdaedtigt zuerst
das Modell — genau die Fehlannahme, die aniela.p beschreibt. Es fehlt damit an
einer Zahl, ab der man ueberhaupt gegensteuern koennte.

## Folie 5 — Die Loesung existiert bereits

Die Loesung existiert bereits — sie ist nur schlecht erklart. Der erste Hebel:
den Werkzeugumfang je Sub-Agent begrenzen. Das Tool exponiert dafuer den
Parameter enabled_toolsets bei delegate_task. Der zweite Hebel: pro MCP-Server
filtern statt global begrenzen. Die Konfiguration kennt tools.include als
Whitelist, tools.exclude als Blacklist, enabled false zum Abschalten ganzer
Server und fnmatch-Globs fuer grosse Flaechen. Bei der Installation schreibt
Hermes nur die angehakten Server-Tools in tools.include. Diese beiden Hebel
lassen sich kombinieren: Der Sub-Agent sieht nur die gefilterte Teilmenge. Die
Community bestaetigt die Abhilfe in zwei unabhaengigen Stimmen: pro Sub-Agent
nur seine sechs Werkzeuge, so halbmond und ilvahn uebereinstimmend.

## Folie 6 — Der Stolperstein: die Doku fuehrt in die Irre

Der Stolperstein ist die Dokumentation. Die Delegations-Doku behauptet
woertlich: delegate_task does not accept a model-facing toolsets parameter.
Doch das laufende Tool exponiert sehr wohl enabled_toolsets — die Doku
widerspricht also dem Tool. Wer den Sub-Agent-Umfang per Allow-List begrenzen
will, wird von der offiziellen Doku aktiv in die Irre gefuehrt. Hinzu kommt:
Der Konfigurationsschluessel heisst tools.include, nicht so, wie man ihn suchen
wuerde, bemangelt kd_rasmus. Und es gibt kein Werkzeug, das die aktive
Tool-Zahl pro Sub-Agent anzeigt oder ueber eine Schwelle warnt. Damit bleibt
der dritte, wuenschenswerte Hebel — Sichtbarkeit der Tool-Menge — eine offene
Anforderung, die als solche benannt, aber nicht neu gebaut wird.

## Folie 7 — Was diese Hebel nicht loesen

Was diese Hebel nicht loesen. Die Schwellen zwischen 50 und 70 beziehungsweise
ungefaehr 60 sind Selbstberichte ohne Stichprobengroesse und ohne
Laufdefinition — ein Richtwert, kein Messwert. Dass Werkzeugbeschreibungen die
Wahl verschlechtern, ist als Muster haltbar, aber nicht durch ein
Kontrollexperiment bewiesen. Der Widerspruch in der Doku muss in der Doku
korrigiert werden; dieses Video baut nichts und aendert keine Dokumentation.
Und extern verifizierbar ist das alles nicht: Die Quell-URLs sind
Beispiel-Platzhalter in einem eingefrorenen Korpus. Wer die Zahlen
uebernehmen will, muss sie gegen die echte Produkt-Doku pruefen.