# skript.md — subagenten-werkzeugflut (Video, 7 Folien)

Sprechtext je Folie, 90-150 Woerter pro Folie. Zahlen mit Quelle und Datum.
Bogen: Der Schmerz → Warum es passiert → Die Hebel → Grenzen.

---

## Folie 1 — Der Schmerz | Sub-Agenten greifen daneben, der Haupt-Agent nicht

Wer mit KI-Coding-Agenten arbeitet und mehrere MCP-Server angebunden hat, kennt
das Szenario. Die Sub-Agenten greifen ploetzlich das falsche Werkzeug oder gar
keins. Der Haupt-Agent nutzt genau dieselben Werkzeuge problemlos. Laut
@mkirsch_dev, der das am 3. August 2026 auf X beschrieb, kippt die
Trefferquote ab ungefaehr 60 geladenen Werkzeugen im Kontext. @renkoe berichtet
auf YouTube am 7. August von neun MCP-Servern und Unteragenten, die Werkzeuge
nicht benutzen. Er hoehlt zusaetzlich die Aussage, dass der Haupt-Agent dieselbe
Auswahl problemlos schafft. Und u/halbmond meldet auf Reddit am 4. August einen
Abfall ab mehr als vier MCP-Servern. Was das Problem besonders unangenehm
macht: Es ist vorab nicht vorhersagbar. In keiner Doku steht eine Zahl, so
@mkirsch_dev.

---

## Folie 2 — Der Schmerz | Kosten: verbrannte Stunden und wochenlange Fehldiagnose

Der Ausfall kostet reale Arbeitszeit. @mkirsch_dev verbrannte drei Stunden, weil
seine Sub-Agenten die Aufgabe nicht hinbekamen. Noch teurer wird es, wenn das
Problem falsch diagnostiziert wird. u/aniela.p beschreibt auf Reddit, dass ihr
Team seit Wochen mit demselben Problem kaempft und es zunaechst fuer ein
Modellproblem hielt. Diese Fehldiagnose verlaengert den Ausfall, statt ihn zu
beenden. Der Mechanismus selbst ist gut belegt. Sechs unabhaengige Stimmen ueber
drei Plattformen, X, YouTube und Reddit, beschreiben denselben Befund. Es gibt
keine Gegenstimme im Korpus und kein Anzeichen, dass die Berichte
voneinander abgeschrieben sind; der Text ueberlappt nicht. Das ist eine
bemerkenswert konsistente Beleglage fuer ein Phaenomen, das offiziell nirgends
dokumentiert ist.

---

## Folie 3 — Warum es passiert | Die Werkzeugwahl wird schwerer, nicht das Modell

Der Ausloeser ist nicht das Modell, sondern die Menge der
Werkzeugbeschreibungen im Kontext. @ilvahn beschreibt den Mechanismus auf
YouTube praezise. Zu viele Werkzeugbeschreibungen im Kontext, der
untergeordnete Agent waehlt dann daneben. Der Sub-Agent muss aus einer grossen
Kandidatenmenge das richtige Werkzeug waehlen und trifft daneben. Die Schwelle
in Werkzeugen liegt bei etwa 50 bis 80, aus mehreren Quellen. u/kd_rasmus
nennt 50 bis 70, @mkirsch_dev ungefaehr 60. In MCP-Servern gerechnet sind es
ungefaehr vier bis neun. Als Kernmerkmal gilt: Nur die Sub- und Unteragenten
kippen, der Haupt-Agent bleibt unbeeindruckt. Diese Rollen-Asymmetrie ist in
allen Quellen konsistent.

---

## Folie 4 — Warum es passiert | Die einzige quantitative Messung

Die einzige quantitative Messung im Korpus stammt von u/kd_rasmus auf Reddit am
4. August 2026. Bei 40 Werkzeugen im Kontext liefen 9 von 10 Laeufen gut. Bei 80
Werkzeugen nur noch 3 von 10. Das ist ein Abfall der Trefferquote von 90 auf 30
Prozent, ein Einbruch um mehr als die Haelfte. Wichtig zur Einordnung: Das ist
die einzige gemessene Zahl. Alle uebrigen Belege sind anekdotisch. Zusaetzlich
fehlen im gesamten Korpus absolute Kontextfenster- oder Token-Zahlen; keine
Quelle nennt eine Fenstergroesse. Das Phaenomen ist deshalb an die relative
Werkzeugzahl gebunden, nicht an ein Token-Budget. Wer eine konkrete Absolutzahl
sucht, findet sie hier nicht.

---

## Folie 5 — Die Hebel | Haupthebel: pro-Sub-Agent-Allow-List

Der Haupthebel ist die pro-Sub-Agent-Allow-List. Jeder Sub-Agent sieht dann nur
noch die wenigen Werkzeuge, die er tatsaechlich braucht. u/halbmond beschreibt
es auf Reddit so: Pro Sub-Agent eine Allow-List setzen, dann sieht er nur seine
sechs Werkzeuge, das gehe seit einer Weile. u/kd_rasmus bestaetigt das
unmittelbar. Auch @ilvahn empfiehlt unabhaengig davon auf YouTube, jedem
Unteragenten nur die Werkzeuge zu geben, die er braucht; dann laufe es wieder.
Der Haken: Die Loesung ist schlecht auffindbar. u/halbmond fand sie nur ueber
einen Changelog-Eintrag von vor vier Monaten, nicht ueber die offizielle
Dokumentation. Das ist ein Auffindbarkeitsproblem, kein Funktionsproblem.

---

## Folie 6 — Die Hebel | Serverzahl pruefen und Fehldiagnose vermeiden

Neben der Allow-List gibt es zwei weitere Hebel. Hebel B betrifft die Anzahl
aktiver MCP-Server. Statt Server blind zu stapeln, sollte man ihre Zahl
kritisch pruefen; die Schwelle liegt bei ungefaehr vier bis neun Servern
beziehungsweise 50 bis 80 Werkzeugen. Es lohnt sich, nur die Server zu laden,
die der jeweilige Durchlauf wirklich braucht. Hebel C betrifft die
Fehldiagnose. Vor einem Modellwechsel erst die Werkzeugzahl pruefen. u/aniela.p's
Team verlor Wochen durch die Annahme, es liege am Modell. Das Erkennen des
Mechanismus ist damit selbst der erste Hebel. Wer das Muster kennt, spart sich
die falsche Diagnose. Die Allow-List selbst bleibt allerdings schwer zu finden;
der Konfigurationsschluessel heisst laut u/kd_rasmus nicht so, wie man ihn
suchen wuerde.

---

## Folie 7 — Grenzen | Was diese Hebel nicht loesen

Die Hebel loesen das Problem nicht vollstaendig. Die Allow-List ist manuell; es
gibt keine automatische Werkzeugbegrenzung und keine Erklaerung durch das Tool
selbst. Es existiert auch nichts, das die Schwelle ueberwacht, eine echte
Loesungsluecke. Dieses Video kann die fehlende offizielle Dokumentation nicht
ersetzen; es verbessert nur die Auffindbarkeit. Die einzige Messung, 9 von 10
gegen 3 von 10, ist einmalig und informell, kein kontrollierter Labortest. Und
schliesslich ist die Ursache der Rollen-Asymmetrie, warum nur Sub-Agenten
kippen, als Symptom belegt, aber nicht erklaert. Genau diese offenen Punkte
markieren, wo noch ungeklaerte Fragen liegen.
