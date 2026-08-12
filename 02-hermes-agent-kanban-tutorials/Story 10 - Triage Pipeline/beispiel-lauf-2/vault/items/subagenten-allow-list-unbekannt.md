---
slug: subagenten-allow-list-unbekannt
titel: Allow-List-Umgehung gegen Werkzeugflut ist nicht dokumentiert, Schluesselname irrefuehrend
status: archiviert
score: 63
score_breakdown: {haeufigkeit: 14, schmerzintensitaet: 11, loesbar_oder_erklaerbar: 18, loesungsluecke: 10, strategische_passung: 10}
pfad:
duplikate: [web-3-allow-list]
---

# subagenten-allow-list-unbekannt

## Kernproblem
Die existierende Loesung gegen die Werkzeugflut (pro Sub-Agent eine
Werkzeug-Allow-List setzen) steht nirgends in der Doku, und der
Konfigurationsschluessel hat einen Namen, den man so nicht suchen wuerde.

## Quellen
- `sources/web/reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents, 2026-08-04 — u/halbmond ("Loesung gefunden: pro Sub-Agent eine Allow-List ... steht aber nirgends in der Doku — ich habe es aus einem Changelog-Eintrag von vor vier Monaten") und u/kd_rasmus ("Der Konfigurationsschluessel heisst nicht so, wie man ihn suchen wuerde").

## Bewertung
- **haeufigkeit (14/25):** zwei Stimmen im selben Reddit-Faden, eine Plattform — kein breites Wiederauftreten.
- **schmerzintensitaet (11/20):** gering bis mittel — laest sich durch Suchen im Changelog beheben, keine verlorenen Stunden oder Blockade.
- **loesbar_oder_erklaerbar (18/25):** ein Agent kann die existierende Funktion samt korrektem Schluesselnamen sauber erklaeren.
- **loesungsluecke (10/15):** die Loesung existiert; es fehlt lediglich Doku/Benennung.
- **strategische_passung (10/15):** gleiches Publikum wie subagenten-werkzeugflut, aber rein ein Doku-/Erklaerungsmangel.

**Score: 63/100 — UNTER der Schwelle (65), Status: archiviert.** Verwandt mit
subagenten-werkzeugflut, aber eigener (Doku-)Mechanismus; als eigenstaendiges
Videothema zu duenn belegt. Kein Fan-out, kein menschliches Tor.
