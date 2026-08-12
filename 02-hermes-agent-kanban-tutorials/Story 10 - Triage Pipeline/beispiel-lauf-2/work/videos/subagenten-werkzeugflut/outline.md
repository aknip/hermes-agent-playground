# Outline-Entwurf: Werkzeugflut durch zu viele MCP-Server

Slug: `subagenten-werkzeugflut` · Pfad: `video` · Score: 87/100
Stufe: prep / outline (triage-producer) · Datum: 2026-08-11

Zweck dieses Dokuments: Entwurf des Video-Bogens (Schmerz → Mechanismus →
Hebel → Grenzen), der die Deliverable-Spec `pipeline/specs/video.md` erfuellt
und dem Orchestrator als Basis fuer den Vorschlag in Stufe 3 (Tor) dient.

---

## Kernaussage (eine Zeile, Regie-Anker)

Ab ~50–80 Werkzeugen (~4–9 MCP-Servern) im Kontext faellt die Trefferquote
von Sub-/Unteragenten, waehrend der Haupt-Agent unbeeindruckt bleibt — und
eine funktionierende, aber mies dokumentierte Umgehung (pro-Sub-Agent-Allow-List)
existiert bereits. Das Video erklaert den Mechanismus und die zwei Hebel.

## Quellenbasis (alle aus dem Item, mit Datum)

- `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X), 2026-08-03
- `sources/web/youtube-kommentare-agenten-werkzeuge.md` — @renkoe, @ilvahn (YouTube), 2026-08-07
- `sources/web/reddit-subagenten-werkzeugflut.md` — u/halbmond, u/kd_rasmus, u/aniela.p (Reddit r/aiagents), 2026-08-04

---

## 1) Der Schmerz — im O-Ton der Quellen

Regie: drei Stimmen, drei Plattformen, eine Symptomatik. Erst das Symptom
(Fehlverhalten der Sub-Agenten), dann die Zeit/Frustkosten, dann die
Fehldiagnose.

Stichpunkte:
- Sub-Agenten greifen das falsche Werkzeug oder gar keins; Haupt-Agent
  benutzt dieselben Werkzeuge problemlos. (@mkirsch_dev; @renkoe)
- Kosten konkret: @mkirsch_dev drei Stunden verbrannt; u/aniela.p's Team
  "seit Wochen" mit demselben Problem.
- Fehldiagnose: u/aniela.p hielt es wochenlang fuer ein Modellproblem.
- Niemand sagt einem das Erste — @mkirsch_dev: "In keiner Doku steht eine Zahl."

Quellen: 1, 2, 3 (siehe oben). Alle Zitate in `faktencheck.md` hinterlegt.

## 2) Warum es passiert — der Mechanismus

Kern: nicht der Modell-"Gehirnschaden", sondern die Werkzeugwahl wird
schwieriger, je mehr Werkzeugbeschreibungen im Kontext stehen. Der einzige
quantitative Beleg zeigt den Abfall: 40 Werkzeuge → 9/10 Laeufe gut, 80
Werkzeuge → 3/10 (u/kd_rasmus). Das ist der Dreh- und Angelpunkt des Videos:
nicht Symptom, sondern Mechanismen-Ebene.

Stichpunkte:
- Mechanismus: zu viele Werkzeugbeschreibungen im Kontext — der Sub-Agent
  muss aus einer grossen Kandidatenmenge waehlen und trifft daneben
  (@ilvahn: "Zu viele Werkzeugbeschreibungen im Kontext").
- Schwelle in Werkzeugen: ~50–80 (u/kd_rasmus: 50–70; @mkirsch_dev: ca. 60).
- Schwelle in MCP-Servern: ~4–9 (u/halbmond: >4; @ilvahn: 7; @renkoe: 9).
- Rollen-Asymmetrie als Kernmerkmal: NUR Sub-/Unteragenten kippen, der
  Haupt-Agent bleibt unbeeindruckt (alle Quellen; kein Gegenbeispiel im Korpus).
- Einzigartige quantitative Messung: 40→9/10 vs. 80→3/10 (u/kd_rasmus).

Luecke: absolute Kontextfenster-Zahlen (Tokens) fehlen im ganzen Korpus;
das Phaenomen ist nur an die relative Werkzeugzahl gebunden, nicht an ein
Token-Budget (→ faktencheck: ungeklaert).

## 3) Die Hebel — 2–3 konkrete Massnahmen

Haupthebel (der zu bauende Kern des Videos): die pro-Sub-Agent-Allow-List.
Zwei weitere als Kontext/Einordnung.

Hebel A — pro-Sub-Agent-Allow-List (Haupthebel):
- Jeder Sub-Agent sieht nur noch die wenigen Werkzeuge, die er braucht.
- Belegt funktionierend, doppelt unabhaengig:
  - u/halbmond: "pro Sub-Agent eine Allow-List setzen, dann sieht er nur
    seine sechs Werkzeuge. Geht seit einer Weile."
  - u/kd_rasmus: "Kann ich bestaetigen."
  - @ilvahn: "Gib jedem Unteragenten nur die Werkzeuge, die er braucht.
    Dann laeuft es wieder."
- Der Schmerz bleibt trotzdem: es ist "schlecht_erklaert" — u/halbmond fand
  es nur ueber einen Changelog-Eintrag; u/kd_rasmus: der Konfigurationsschluessel
  "heisst nicht so, wie man ihn suchen wuerde". Das Video will die Auffindbarkeit
  schliessen.

Hebel B — Werkzeug-/Serverzahl unter der Schwelle halten:
- Anzahl aktiver MCP-Server kritisch pruefen statt blind stapeln (Schwelle
  ~4–9 Server / ~50–80 Einzelwerkzeuge). Nur die Server laden, die der
  jeweilige Durchlauf wirklich braucht.

Hebel C — Fehldiagnose vermeiden (Orientierung):
- Vor einem Modellwechsel erst die Werkzeugzahl pruefen — u/aniela.p's Team
  verlor Wochen, weil es ein Modellproblem annahm. Das Erkennen des
  Mechanismus ist selbst der erste Hebel.

## 4) Grenzen — was die Hebel NICHT loesen

Stichpunkte:
- Allow-List ist manuell, keine automatische Werkzeugbegrenzung/-erklaerung
  des Tools; es gibt nichts, das die Schwelle selbst ueberwacht (loesungsluecke).
- Das Video erklaert die Auffindbarkeit, kann aber die (fehlende) offizielle
  Doku nicht ersetzen.
- Messung (u/kd_rasmus) ist eine einmalige informelle Messung, kein
  kontrollierter Labortest; keine unabhaengige Zweitmessung in derselben Grosse.
- Keine absoluten Kontextfenster-Zahlen im Korpus — die Empfehlung bleibt
  relativ zur Werkzeugzahl, nicht an ein Token-Budget gebunden.
- Rollen-Asymmetrie (nur Sub-Agenten kippen) ist belegt, aber das WARUM der
  Asymmetrie ist nicht erklaert — es gibt keinen Gegenbefund und keinen
  Erklaerungs-Beleg im Korpus.
- Quellen sind redigierte Auszuege mit Platzhalter-URLs (x.example etc.);
  externe Nachpruefung der Original-Threads ist nicht moeglich.

---

## Zu baubare Folien (Mapping auf die Spec `folien.md`, 6–8 Folien)

Der Bogen bildet die vier Abschnitte des Outlines direkt auf Folien ab:

- F1 (Schmerz): Titelfolie + Symptom im O-Ton — Sub-Agenten greifen das
  falsche Werkzeug, Haupt-Agent nicht (@mkirsch_dev, @renkoe).
- F2 (Schmerz): Kosten — 3h verbrannt (@mkirsch_dev), wochenlang Fehldiagnose
  als Modellproblem (u/aniela.p), "in keiner Doku steht eine Zahl".
- F3 (Mechanismus): die Schwelle — ~50–80 Werkzeuge / ~4–9 MCP-Server.
- F4 (Mechanismus): die eine quantitative Messung — 40 Werkzeuge → 9/10,
  80 → 3/10 (u/kd_rasmus) + Rollen-Asymmetrie.
- F5 (Hebel A): pro-Sub-Agent-Allow-List — wie sie funktioniert, doppelt
  belegt (u/halbmond, u/kd_rasmus, @ilvahn).
- F6 (Hebel B+C): Serverzahl pruefen; Fehldiagnose vermeiden (erst
  Werkzeugzahl, nicht Modellwechsel).
- F7 (Grenzen): was nicht geloest ist — manuelle Loesung, keine automatische
  Begrenzung, einmalige Messung, keine Token-Zahlen.
- F8 (Grenzen/CTA): Einordnung + Naechste Schritte fuer das Publikum.

## Offene Punkte / fuer `faktencheck.md`

UNGEKLAERT (im Outline-Bogen brauchbar, aber nicht belegbar aus dem Korpus):
- Absolute Kontextfenster-Groessen (Tokens) — keine Quelle nennt ein
  Context-Window oder den Token-Platzbedarf der Werkzeugbeschreibungen.
- Warum genau NUR Sub-Agenten kippen und der Haupt-Agent nicht (Ursache der
  Rollen-Asymmetrie nicht belegt — nur das Symptom).
- Exakte Zahl fuer "~50–80" ist ein Streubereich aus drei Quellen
  (50–70 / ca. 60 / >4 Server-Schaetzung), keine Einzelmessung.

EINGESCHRAENKT:
- Messung (9/10 vs. 3/10) ist einmalig/informell, keine doppelte Kontrolle.
- Quellen-URLs sind Platzhalter (x.example/youtube.example/reddit.example) —
  Originale nicht nachpruefbar.

Diese Liste wird in der Fulfill-Stufe (folien/skript + faktencheck) als
Grundlage uebernommen.
