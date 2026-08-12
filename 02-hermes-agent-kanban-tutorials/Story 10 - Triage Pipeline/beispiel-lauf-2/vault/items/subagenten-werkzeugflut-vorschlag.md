# Vorschlag: Video — Werkzeugflut durch zu viele MCP-Server

**Slug:** `subagenten-werkzeugflut`  ·  **Pfad:** `video`  ·  **Punkte:** 87/100

## Der Schmerz

Ab einer Schwelle von ~50–80 Werkzeugen (~4–9 MCP-Servern) im Kontext faellt
die Trefferquote der Sub-/Unteragenten beim Werkzeuggebrauch, waehrend der
Haupt-Agent dieselben Werkzeuge problemlos nutzt. Nutzer verbrennen dabei reale
Arbeitszeit und diagnostizieren das Problem falsch: u/aniela.p's Team verlor
"seit Wochen" Zeit, weil es den Ausfall fuer ein Modellproblem hielt. Und
niemand weiss es im Voraus — @mkirsch_dev: "In keiner Doku steht eine Zahl."

## Belege

- `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03:
  "Ab ungefaehr 60 Werkzeugen im Kontext kippt es. Der Haupt-Agent kommt damit
  klar, die Sub-Agenten nicht." (drei Stunden verbrannt)
- `sources/web/youtube-kommentare-agenten-werkzeuge.md` — YouTube, 2026-08-07:
  @renkoe (9 MCP-Server, Unteragenten nutzen Werkzeuge nicht), @ilvahn
  ("kappt bei sieben MCP-Servern", "zu viele Werkzeugbeschreibungen im Kontext").
- `sources/web/reddit-subagenten-werkzeugflut.md` — Reddit r/aiagents,
  2026-08-04: u/halbmond (>4 MCP-Server), u/kd_rasmus (quantitative Messung:
  40 Werkzeuge→9/10, 80 Werkzeuge→3/10), u/aniela.p (Team, Wochen, Modellproblem-Fehldiagnose).
- Sechs unabhaengige Stimmen ueber drei Plattformen; keine Gegenstimme im Korpus.

## Warum ein Video und kein Werkzeug

Das Loesungs-Audit ergibt: eine funktionierende Loesung existiert bereits —
die pro-Sub-Agent-Allow-List (je Unteragent nur die noetigen Werkzeuge), von
u/halbmond und u/kd_rasmus als lauffaehig bestaetigt, von @ilvahn unabhaengig
empfohlen. Der Mangel ist nicht die Funktion, sondern **schlecht_erklaert /
Auffindbarkeit**: u/halbmond fand die Loesung nur ueber einen Changelog-Eintrag
von vor vier Monaten, u/kd_rasmus sagt, der Konfigurationsschluessel "heisst
nicht so, wie man ihn suchen wuerde". Es gibt nichts zu bauen — wohl aber etwas
zu erklaeren. Deshalb Video-Pfad statt Build.

## Der Bogen

1. **Der Schmerz** — Sub-Agenten greifen das falsche Werkzeug oder gar keins;
   Haupt-Agent nicht. Kosten: 3 Stunden verbrannt, wochenlange Fehldiagnose.
2. **Warum es passiert** — zu viele Werkzeugbeschreibungen im Kontext; die
   Werkzeugwahl wird schwerer. Die eine quantitative Messung: 40→9/10 vs.
   80→3/10 (u/kd_rasmus). Rollen-Asymmetrie: nur Sub-Agenten kippen.
3. **Die Hebel** — (A) pro-Sub-Agent-Allow-List als Haupthebel, (B)
   Serverzahl unter der Schwelle halten, (C) Fehldiagnose vermeiden — erst
   Werkzeugzahl pruefen, nicht Modell wechseln.
4. **Grenzen** — Allow-List ist manuell, keine automatische Begrenzung; das
   Video ersetzt die fehlende offizielle Doku nicht; Messung einmalig/informell;
   keine absoluten Kontextfenster-Zahlen.

## Offene Punkte

- Absolute Kontextfenster-Groessen (Tokens) fehlen im gesamten Korpus; die
  Empfehlung bleibt relativ zur Werkzeugzahl, nicht an ein Token-Budget gebunden.
- Ursache der Rollen-Asymmetrie (warum NUR Sub-Agenten kippen) ist belegt als
  Symptom, aber nicht erklaert.
- "~50–80" ist ein Streubereich aus drei Quellen, keine Einzelmessung; die
  9/10-vs-3/10-Messung ist einmalig/informell.
- Quellen-URLs sind Platzhalter (x.example / youtube.example / reddit.example);
  Originale sind nicht nachpruefbar.

---

**Antworte auf dem Board:**

    hermes kanban --board kanban-story-10 unblock <kartenid> --reason "approve"
    hermes kanban --board kanban-story-10 unblock <kartenid> --reason "shelve: <grund>"
    hermes kanban --board kanban-story-10 unblock <kartenid> --reason "modify: <aenderung>"
