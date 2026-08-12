# faktencheck.md — subagenten-werkzeugflut

Jede belegbare Aussage mit Quelle. Unbelegbare Punkte unter "ungeklaert"
(nicht weggelassen, nicht hochgeschrieben). Zahlen mit Quelle und Datum.

Quellen-Kuerzel:

- `X-1` = `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03
- `YT-1` = `sources/web/youtube-kommentare-agenten-werkzeuge.md` — YouTube, 2026-08-07 (@renkoe, @ilvahn)
- `RD-1` = `sources/web/reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 (u/halbmond, u/kd_rasmus, u/aniela.p)

---

## Belegte Aussagen

### Folie 1

- Sub-/Unteragenten greifen bei zu vielen Werkzeugen das falsche Werkzeug oder gar keins.
  Quelle: X-1, Z. 8-9 („stumpf das falsche Werkzeug gegriffen oder gar keins").
- Haupt-Agent nutzt dieselben Werkzeuge problemlos.
  Quelle: X-1, Z. 13 („Der Haupt-Agent kommt damit klar"); YT-1, Z. 11-12 (@renkoe).
- Ab ungefaehr 60 Werkzeugen im Kontext kippt die Trefferquote der Sub-Agenten.
  Quelle: X-1, Z. 13-14 (@mkirsch_dev, 2026-08-03).
- @renkoe hat neun MCP-Server; Unteragenten benutzen Werkzeuge nicht.
  Quelle: YT-1, Z. 11-12, 18 (@renkoe, 2026-08-07).
- Ab mehr als vier MCP-Servern faellt die Trefferquote der Sub-Agenten.
  Quelle: RD-1, Z. 11-13 (OP u/halbmond, 2026-08-04).
- Vorab nicht vorhersagbar; in keiner Doku steht eine Zahl.
  Quelle: X-1, Z. 15 („In keiner Doku steht eine Zahl").

### Folie 2

- @mkirsch_dev verbrannte drei Stunden.
  Quelle: X-1, Z. 8 („Drei Stunden verbrannt", 2026-08-03).
- u/aniela.p's Team kaempft seit Wochen mit demselben Problem.
  Quelle: RD-1, Z. 18 („Bei uns im Team dasselbe, seit Wochen", 2026-08-04).
- Das Team hielt es zunaechst, ueber Wochen, fuer ein Modellproblem (Fehldiagnose).
  Quelle: RD-1, Z. 18-20 („Wir dachten erst, es liegt am Modell").
- Sechs unabhaengige Stimmen ueber X, YouTube und Reddit bestaetigen denselben Mechanismus.
  Quelle: X-1 (@mkirsch_dev), YT-1 (@renkoe, @ilvahn), RD-1 (u/halbmond, u/kd_rasmus, u/aniela.p). Bewertung aus Vault-Item Z. 24 (haeufigkeit 23/25).
- Keine Gegenstimme im Korpus; kein Textueberlapp zwischen Quellen (kein Beleg fuer Abkuenftigkeit).
  Quelle: Vault-Item subagenten-werkzeugflut.md, Z. 138 (Bahn quellen-pruefen).

### Folie 3

- Mechanismus: zu viele Werkzeugbeschreibungen im Kontext; der Sub-Agent waehlt daneben.
  Quelle: YT-1, Z. 15-16 (@ilvahn, 2026-08-07).
- Schwelle in Werkzeugen ~50-80, aus mehreren Quellen: u/kd_rasmus 50-70, @mkirsch_dev ~60.
  Quelle: RD-1, Z. 14 („kippt es zwischen 50 und 70 Werkzeugen"); X-1, Z. 13 („ungefaehr 60 Werkzeugen").
- Schwelle in MCP-Servern ~4-9: u/halbmond >4, @ilvahn 7, @renkoe 9.
  Quelle: RD-1, Z. 11-13; YT-1, Z. 14-18.
- Rollen-Asymmetrie: nur Sub-/Unteragenten kippen, Haupt-Agent bleibt unbeeindruckt.
  Quelle: X-1 Z. 13-14; RD-1 Z. 12; YT-1 Z. 11-12; Vault-Item Z. 48-50.

### Folie 4

- Einzige quantitative Messung: 40 Werkzeuge -> 9/10 Laeufe gut; 80 Werkzeuge -> 3/10.
  Quelle: RD-1, Z. 14-16 (u/kd_rasmus, 2026-08-04).
- Trefferquote faellt von 90 % auf 30 % — Einbruch um mehr als die Haelfte.
  Ableitung aus RD-1, Z. 14-16. (Einmalige informelle Messung, kein Labortest; siehe Grenzen.)
- Absoluten Kontextfenster-/Token-Zahlen fehlen im gesamten Korpus.
  Quelle: Vault-Item Z. 52-58 (Bahn kontext).
- Relative Werkzeugzahl, nicht Token-Budget: Bewertung der Bahn kontext, Vault-Item Z. 78-82.

### Folie 5

- Pro-Sub-Agent-Allow-List; Sub-Agent sieht nur seine wenigen Werkzeuge.
  Quelle: RD-1, Z. 21-23 (u/halbmond).
- u/halbmond: pro Sub-Agent eine Allow-List, sieht nur seine sechs Werkzeuge, funktioniert seit einer Weile.
  Quelle: RD-1, Z. 21-23.
- u/kd_rasmus bestaetigt die Loesung.
  Quelle: RD-1, Z. 25 („Kann ich bestaetigen").
- @ilvahn: jedem Unteragenten nur die Werkzeuge geben, die er braucht; dann laeuft es.
  Quelle: YT-1, Z. 20-21.
- Loesung schlecht auffindbar; u/halbmond fand sie nur ueber einen Changelog-Eintrag von vor vier Monaten.
  Quelle: RD-1, Z. 22-23; Vault-Item Z. 100-104.

### Folie 6

- Hebel B: Anzahl aktiver MCP-Server kritisch pruefen (Schwelle ~4-9 Server / ~50-80 Werkzeuge).
  Ableitung aus RD-1, YT-1, X-1 (Schwellen oben).
- Hebel C: vor Modellwechsel erst Werkzeugzahl pruefen; u/aniela.p verlor Wochen durch Modellproblem-Annahme.
  Quelle: RD-1, Z. 18-20; Vault-Item Z. 116-118 (Nebenbefund).
- Konfigurationsschluessel heisst nicht so, wie man ihn suchen wuerde.
  Quelle: RD-1, Z. 25-26 (u/kd_rasmus); Vault-Item Z. 104.

### Folie 7

- Allow-List ist manuell; keine automatische Werkzeugbegrenzung/-erklaerung des Tools; Loesungsluecke.
  Quelle: Vault-Item Z. 28 (loesungsluecke 12/15) und Z. 112-113 (route.tabelle).
- Nichts ueberwacht die Schwelle selbst.
  Quelle: Vault-Item Z. 28 („keine automatische Werkzeugbegrenzung/-erklaerung").
- Video ersetzt fehlende offizielle Doku nicht, verbessert nur Auffindbarkeit.
  Einordnung aus Vault-Item Z. 100-107 (schlecht_erklaert, Auffindbarkeitsproblem) — Auftragslogik, keine Quelle.
- Einzige Messung (9/10 vs. 3/10) einmalig und informell, kein kontrollierter Labortest.
  Quelle: Vault-Item Z. 144 (Bahn quellen-pruefen).
- Ursache der Rollen-Asymmetrie (warum NUR Sub-Agenten kippen) als Symptom belegt, nicht erklaert.
  Quelle: Vault-Item Z. 52-54 (Bahn kontext, Luecke).

---

## Ungeklaert

- Absolute Kontextfenster-/Token-Zahlen fehlen im gesamten Korpus. Keine Quelle
  nennt eine Fenstergroesse oder den Platzbedarf einzelner
  Werkzeugbeschreibungen in Tokens. Die Empfehlung bleibt relativ zur
  Werkzeugzahl, nicht an ein Token-Budget gebunden.
- Warum genau NUR die Sub-/Unteragenten kippen und der Haupt-Agent nicht, ist als
  Symptom belegt, aber mechanistisch nicht erklaert (keine Quelle analysiert die
  Ursache der Rollen-Asymmetrie).
- Die Schwelle "~50-80" ist ein Streubereich aus drei Quellen (~60 / 50-70 /
  4-9 Server), keine Einzelmessung.
- Die 9/10-vs-3/10-Messung (u/kd_rasmus) ist einmalig und informell; es gibt
  keine unabhaengige Zweitmessung in derselben Groesse.
- Quellen-URLs sind Platzhalter (x.example, youtube.example, reddit.example);
  die Originale (X-Post, YouTube-Kommentare, Reddit-Thread) sind extern nicht
  nachpruefbar. Inhalte sind redigierte Quellenauszuege.
- Es wurde kein Gegenbefund erhoben; niemand im Korpus berichtet ein Gegenteil.
