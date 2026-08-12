# folien.md — subagenten-werkzeugflut (Video, 7 Folien)

Jede Folie: eine Ueberschrift, hoechstens 5 Stichpunkte. Nur belegte Aussagen;
Unbelegtes steht in faktencheck.md unter "ungeklaert". Bogen: Der Schmerz →
Warum es passiert → Die Hebel → Grenzen.

---

## Folie 1 — Der Schmerz | Sub-Agenten greifen daneben, der Haupt-Agent nicht

- Ab ~50-80 geladenen MCP-Werkzeugen im Kontext faellt die Trefferquote von Sub-/Unteragenten beim Werkzeuggebrauch (@mkirsch_dev, X 2026-08-03)
- Der Haupt-Agent nutzt dieselben Werkzeuge problemlos (@mkirsch_dev; @renkoe, YouTube 2026-08-07)
- @renkoe (9 MCP-Server): "Unteragenten, die Werkzeuge nicht benutzen" (YouTube 2026-08-07)
- u/halbmond: ab mehr als vier MCP-Servern faellt die Trefferquote der Sub-Agenten (Reddit r/aiagents 2026-08-04)
- Der Ausfall ist vorab nicht vorhersagbar: @mkirsch_dev: "In keiner Doku steht eine Zahl."

## Folie 2 — Der Schmerz | Kosten: verbrannte Stunden und wochenlange Fehldiagnose

- @mkirsch_dev verbrannte drei Stunden (X 2026-08-03)
- u/aniela.p's Team kaempft "seit Wochen" mit demselben Problem (Reddit 2026-08-04)
- Das Team hielt es wochenlang fuer ein Modellproblem — eine Fehldiagnose (u/aniela.p, Reddit 2026-08-04)
- Sechs unabhaengige Stimmen ueber X, YouTube und Reddit bestaetigen denselben Mechanismus
- Keine Gegenstimme im Korpus; kein Anzeichen von Abkuenftigkeit (kein Textueberlapp zwischen den Quellen)

## Folie 3 — Warum es passiert | Die Werkzeugwahl wird schwerer, nicht das Modell

- Mechanismus laut @ilvahn: "zu viele Werkzeugbeschreibungen im Kontext" (YouTube 2026-08-07)
- Der Sub-Agent muss aus einer grossen Kandidatenmenge waehlen und trifft daneben
- Schwelle in Werkzeugen: ~50-80, aus mehreren Quellen (u/kd_rasmus: 50-70; @mkirsch_dev: ca. 60)
- Schwelle in MCP-Servern: ~4-9 (u/halbmond: >4; @ilvahn: 7; @renkoe: 9)
- Rollen-Asymmetrie als Kernmerkmal: nur Sub-/Unteragenten kippen, der Haupt-Agent bleibt unbeeindruckt

## Folie 4 — Warum es passiert | Die einzige quantitative Messung

- u/kd_rasmus' Messung: 40 Werkzeuge → 9/10 Laeufe gut, 80 Werkzeuge → 3/10 (Reddit 2026-08-04)
- Trefferquote faellt damit von 90 % auf 30 % — Einbruch um mehr als die Haelfte
- Das ist die einzige quantitative Messung im Korpus; die uebrigen Belege sind anekdotisch
- Absoluten Kontextfenster-/Token-Zahlen fehlen im gesamten Korpus (→ faktencheck: ungeklaert)
- Das Phaenomen ist an die relative Werkzeugzahl gebunden, nicht an ein Token-Budget

## Folie 5 — Die Hebel | Haupthebel: pro-Sub-Agent-Allow-List

- Jeder Sub-Agent sieht nur noch die wenigen Werkzeuge, die er braucht
- u/halbmond: "pro Sub-Agent eine Allow-List setzen, dann sieht er nur seine sechs Werkzeuge. Geht seit einer Weile." (Reddit 2026-08-04)
- u/kd_rasmus: "Kann ich bestaetigen." (Reddit 2026-08-04)
- @ilvahn: "Gib jedem Unteragenten nur die Werkzeuge, die er braucht. Dann laeuft es wieder." (YouTube 2026-08-07)
- Die Loesung ist schlecht auffindbar: u/halbmond fand sie nur ueber einen Changelog-Eintrag von vor vier Monaten

## Folie 6 — Die Hebel | Serverzahl pruefen und Fehldiagnose vermeiden

- Hebel B: Anzahl aktiver MCP-Server kritisch pruefen statt blind stapeln (Schwelle ~4-9 Server / ~50-80 Werkzeuge)
- Nur die Server laden, die der jeweilige Durchlauf wirklich braucht
- Hebel C: vor einem Modellwechsel erst die Werkzeugzahl pruefen (u/aniela.p's Team verlor Wochen durch die Annahme eines Modellproblems)
- Das Erkennen des Mechanismus ist selbst der erste Hebel
- Der Konfigurationsschluessel der Allow-List "heisst nicht so, wie man ihn suchen wuerde" (u/kd_rasmus)

## Folie 7 — Grenzen | Was diese Hebel nicht loesen

- Die Allow-List ist manuell — keine automatische Werkzeugbegrenzung oder -erklaerung des Tools
- Es gibt nichts, das die Schwelle selbst ueberwacht (Loesungsluecke)
- Das Video kann die fehlende offizielle Doku nicht ersetzen, nur die Auffindbarkeit verbessern
- Die einzige Messung (9/10 vs. 3/10) ist einmalig und informell, kein kontrollierter Labortest
- Ursache der Rollen-Asymmetrie (warum NUR Sub-Agenten kippen) ist belegt als Symptom, aber nicht erklaert
