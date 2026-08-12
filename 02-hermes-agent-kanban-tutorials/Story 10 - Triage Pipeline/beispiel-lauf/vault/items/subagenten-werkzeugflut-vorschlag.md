# Vorschlag: Video — Sub-Agenten waehlen Werkzeuge falsch (oder gar keins), sobald zu viele Werkzeuge/MCP-Server im Kontext liegen

**Slug:** `subagenten-werkzeugflut`  ·  **Pfad:** `video`  ·  **Punkte:** 85/100

## Der Schmerz

Der Sub-Agent greift bei vielen Werkzeugen das falsche Werkzeug — oder gar
keins. kd_rasmus misst den Abfall: „40 Werkzeuge -> 9 von 10 Laeufe gut,
80 Werkzeuge -> 3 von 10", die Schwelle liegt „zwischen 50 und 70 Werkzeugen"
(Reddit, 2026-08-04). mkirsch_dev erlebt es als „stumpf das falsche Werkzeug
gegriffen oder gar keins" und verbrennt drei Stunden (X, 2026-08-03). Das
Tückische: Der Haupt-Agent laeuft mit derselben Werkzeugmenge problemlos weiter
— der Schaden bleibt unsichtbar, solange nur er beobachtet wird. Betroffene
verdaechtigen zuerst das Modell („Wir dachten erst, es liegt am Modell",
aniela.p, Reddit).

## Belege

- `sources/web/reddit-subagenten-werkzeugflut.md` — u/halbmond, u/kd_rasmus, u/aniela.p (r/aiagents, 2026-08-04)
- `sources/web/youtube-kommentare-agenten-werkzeuge.md` — @renkoe, @ilvahn (YouTube, 2026-08-07)
- `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (X, 2026-08-03)
- Scout-Berichte: `intake/web.md`, `intake/x.md`
- Vollstaendige Bewertung und Recherche: `vault/items/subagenten-werkzeugflut.md` (Score 85/100)

## Warum ein Video und kein Werkzeug

Das Loesungs-Audit ergibt: **es gibt eine Loesung, sie ist aber schlecht
erklaert** (`loesungsqualitaet: schlecht_erklaert`). Die MCP-Allow-List
(`tools.include`/`tools.exclude`, per Server) ist heute gut dokumentiert, aber
fuer den entscheidenden Sub-Agent-Fall ist die Begrenzung mies und
selbstwiderspruechlich dokumentiert: Das Tool exponiert tatsaechlich
`delegate_task.enabled_toolsets`, waehrend die Delegations-Doku wörtlich sagt
„delegate_task does not accept a model-facing toolsets parameter" — sie fuehrt
Nutzer aktiv in die Irre. Zudem steht in keiner Doku eine
Werkzeugzaehl-Grenze, und kein Werkzeug zeigt die aktive Tool-Zahl an. Das ist
eine Erklaerungsluecke ueber eine vorhandene Loesung, kein Neubau — also ein
Video, das die Hebel zugengaenglich macht und die Stolpersteine benennt.

## Der Bogen

Das Video folgt der Spec (`pipeline/specs/video.md`) in vier Teilen:

1. **Der Schmerz** — was genau schiefgeht, im O-Ton der Quelle: kd_rasmus'
   Messung (40 -> 9/10, 80 -> 3/10), mkirsch' „falsches Werkzeug oder gar
   keins" und drei verlorene Stunden; der unsichtbare Schaden, weil der
   Haupt-Agent stabil bleibt.
2. **Warum es passiert** — der Mechanismus, nicht die Symptome: der wirksame
   Faktor ist die Zahl der Werkzeugbeschreibungen im Kontext, nicht ein
   MCP-Server-Zaehler; Sub-Agenten kippen bei derselben Tool-Menge, auf der der
   Haupt-Agent die Trefferquote haelt; keine dokumentierte Grenze.
3. **Die Hebel** — 2–3 konkrete Massnahmen: Tool-Umfang je Sub-Agent begrenzen
   (`enabled_toolsets`), pro MCP-Server filtern statt global begrenzen
   (`tools.include`/`exclude`, `enabled: false`, Globs), und die aktive
   Tool-Zahl sichtbar machen (als Anforderung benennen, kein Neubau).
4. **Grenzen** — was diese Hebel nicht loesen: ~50–70/~60 ist Selbstbericht
   ohne N (Richtwert, kein Messwert); Kausalitaet ist nicht durch ein
   Kontrollexperiment bewiesen; der Doku-Widerspruch muss in der Doku
   korrigiert werden, das Video baut nichts; extern nicht verifizierbar
   (eingefrorenes Korpus).

## Offene Punkte

1. **Keine belegte Schwelle:** Die Werte ~50–70 (kd_rasmus) bzw. ~60 (mkirsch)
   sind Selbstbericht ohne N, ohne Laufdefinition, ohne Modell-/Promptangabe —
   als Richtwert tragbar, nicht als Messwert. Ein offizielles Tool-Limit ist
   aus dem Korpus nicht belegbar (mkirsch: „Niemand sagt dir das. In keiner
   Doku steht eine Zahl."); die echte Doku/Changelog ist zu verifizieren.
2. **Doku-Widerspruch:** Die Delegations-Doku („does not accept a toolsets
   parameter") widerspricht dem laufenden Tool, das `enabled_toolsets`
   exponiert. Das Video zeigt den Widerspruch, korrigiert die Doku nicht.
3. **Kein Anzeige-/Warnwerkzeug** fuer die aktive Tool-Zahl und keine
   dokumentierte Grenze bestehen fort — als Anforderung benennen, kein Neubau.
4. **Kausalitaet und Verifizierbarkeit:** Kein Kontrollexperiment isoliert die
   Versagensursache; die Quelle-URLs sind `.example`-Platzhalter in einem
   eingefrorenen Korpus — extern nicht verifizierbar. Stimmenzahl im Item (8)
   weicht von den 6 distinkten Personen ab; das Video belegt 6, nicht 8.

---

**Antworte auf dem Board:**

    hermes kanban --board kanban-story-10 unblock t_4bb57feb --reason "approve"
    hermes kanban --board kanban-story-10 unblock t_4bb57feb --reason "shelve: <grund>"
    hermes kanban --board kanban-story-10 unblock t_4bb57feb --reason "modify: <aenderung>"