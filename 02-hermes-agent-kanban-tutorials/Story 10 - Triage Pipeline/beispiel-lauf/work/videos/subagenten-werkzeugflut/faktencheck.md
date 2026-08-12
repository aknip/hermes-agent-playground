# Faktencheck: Sub-Agenten-Werkzeugflut

Pfad: video · Slug: `subagenten-werkzeugflut` · Stufe: skript
Jede belegbare Aussage des Skripts mit Quelle aus der Item-Akte
`vault/items/subagenten-werkzeugflut.md` (referenziert als "Item") und den
dort genannten Quellen. Ungedaerfte Punkte unter "ungeklaert".

Quellenkuerzel (aus dem Item, Abschnitt "Quellen"):
- REDDIT = sources/web/reddit-subagenten-werkzeugflut.md (u/halbmond, u/kd_rasmus, u/aniela.p; r/aiagents, 2026-08-04)
- YOUTUBE = sources/web/youtube-kommentare-agenten-werkzeuge.md (@renkoe, @ilvahn; 2026-08-07)
- X = sources/x/2026-08-03-subagenten-mcp.md (@mkirsch_dev; 2026-08-03)
- `hermes-agent.nousresearch.com/docs` = Referenz-Doku (Docs v0.20.0, Stand 2026-08-11), laut Item Abschnitt "loesungs-audit"

---

## Folie 1 — Der Sub-Agent waehlt das falsche Werkzeug — oder gar keins

| Aussage | Quelle |
|---|---|
| 40 Werkzeuge -> 9 von 10 Laeufen gut; 80 Werkzeuge -> 3 von 10 (kd_rasmus) | Item "Warum relevant" und "kontext" Abs. 1; REDDIT Z.15-16 (woertlich zitiert; Item "quellen-pruefen", Verifikation) |
| Schwelle "zwischen 50 und 70 Werkzeugen" (kd_rasmus) | REDDIT Z.15-16; Item "kontext" Abs. 1 |
| Sub-Agenten "haben stumpf das falsche Werkzeug gegriffen oder gar keins" (mkirsch_dev) | X Z.9-10; Item "kontext" Abs. 2 |
| drei verlorene Stunden (mkirsch_dev) | X Z.8; Item "Warum relevant" |
| Datum Reddit 2026-08-04 | Item "Quellen", REDDIT |
| Datum X 2026-08-03 | Item "Quellen", X |
| Beide Berichte sind Selbstauskuenfte, keine kontrollierte Messung | Item "quellen-pruefen", Zahlenpruefung: "ohne N ... Selbstbericht, nicht kontrolliert" |

## Folie 2 — Nur der Haupt-Agent ist unsichtbar betroffen

| Aussage | Quelle |
|---|---|
| Haupt-Agent behaelt bei derselben Tool-Menge die Trefferquote, Sub-Agenten kippen | Item "kontext" Abs. 2; REDDIT Z.12-13 (halbmond), X Z.13 (mkirsch), YOUTUBE Z.12-13 (renkoe vs. ilvahn) |
| Symptom-Variante falsches Werkzeug ODER gar keins | X Z.9-10 (mkirsch); Item "kontext" Abs. 2 |
| Fehlannahme: zuerst das Modell verdaedtigt — "Wir dachten erst, es liegt am Modell" (aniela.p) | REDDIT Z.19-20; Item "kontext" Abs. 2 |
| Schaden bleibt unsichtbar, solange nur Haupt-Agent beobachtet wird | Item "Warum relevant" (Implikation der Haupt-/Sub-Agent-Asymmetrie); Item "kontext" Abs. 2 |

## Folie 3 — Der Mechanismus: Werkzeugbeschreibungen im Kontext

| Aussage | Quelle |
|---|---|
| Wirksamer Faktor ist die Zahl der Werkzeugbeschreibungen im Kontext, nicht ein MCP-Server-Zaehler | Item "kontext" Abs. 1: "nicht ein MCP-Server-Zaehler, sondern die Zahl der Werkzeugbeschreibungen im Kontext ist der wirksame Faktor"; YOUTUBE Z.15-16 (ilvahn nennt Mechanismus explizit) |
| Server-Zahlen der Erzaehler: halbmond ">4", ilvahn "sieben", renkoe "Neun", mkirsch "sechs" | Item "kontext" Abs. 1; REDDIT Z.11-12, YOUTUBE Z.15-18, X Z.11-12 |
| Server-Zahlen als anderes Mass, roh kohaerent (~4-7), kein Beleg fuer exakten Kipppunkt | Item "quellen-pruefen", Zahlenpruefung |
| Sub-Agenten kippen bei Menge, auf der der Haupt-Agent stabil bleibt | Item "kontext" Abs. 2; REDDIT Z.12-13, X Z.13, YOUTUBE Z.12-13 |
| Schwellen konvergieren: ~50-70 (kd_rasmus), ~60 (mkirsch) | Item "kontext" Abs. 1 ("Konvergenz: ~50-70, ~60"); 60 liegt im 50-70-Band (Item "quellen-pruefen", Zahlenpruefung) |

## Folie 4 — Keine dokumentierte Grenze

| Aussage | Quelle |
|---|---|
| "Niemand sagt dir das. In keiner Doku steht eine Zahl." (mkirsch_dev) | X Z.15; Item "kontext" Abs. 3 |
| Im Korpus keine Schwellen-Dokumentation, kein offizielles Tool-Limit | Item "kontext" Abs. 3 (Befund); Item "loesungs-audit" Punkt 3 |
| Referenz-Doku nennt keine konkrete Tool-Zahl, begruendet Filterung mit Sicherheit/Listen-Sauberkeit statt Selektionsgenauigkeit | Item "kontext" Abs. 4 (Vergleich zur Community-Schwelle) |
| MCP-Abschnitt "Current limits" betrifft nur eingebetteten `hermes mcp serve`, keine Tool-Anzahl | Item "loesungs-audit" Punkt 3 |
| Ohne Grenze verdaedtigen Betroffene zuerst das Modell | REDDIT Z.19-20 (aniela.p); Item "kontext" Abs. 2 |

## Folie 5 — Die Loesung existiert bereits

| Aussage | Quelle |
|---|---|
| Tool exponiert `delegate_task.enabled_toolsets` | Item "loesungs-audit" Punkt 2 und "kontext" Abs. 5 |
| `tools.include` (Whitelist), `tools.exclude` (Blacklist), `enabled: false`, fnmatch-Globs | Item "kontext" Abs. 4 (Per-server filtering); Item "loesungs-audit" Punkt 1 |
| Hermes schreibt nur angehakte Server-Tools bei Installzeit in `tools.include` | Item "kontext" Abs. 4 ("Tool selection at install time"; "If you select everything, no filter is written") |
| Abhilfe "pro Sub-Agent nur seine sechs Werkzeuge" (halbmond, ilvahn) | REDDIT Z.21-22; YOUTUBE Z.20-21; Item "kontext" Abs. 5 |
| Loesung ist "schlecht_erklaert" | Item Frontmatter `loesungsqualitaet: schlecht_erklaert` |

## Folie 6 — Der Stolperstein: die Doku fuehrt in die Irre

| Aussage | Quelle |
|---|---|
| Delegations-Doku woertlich: "delegate_task does not accept a model-facing toolsets parameter. Each subagent inherits the parent's enabled toolsets." | Item "loesungs-audit" Punkt 2 ("Inherited Tool Access") und "kontext" Abs. 5 |
| Tatsaechlich exponiert das laufende Tool `enabled_toolsets` — Doku widerspricht dem Tool | Item "loesungs-audit" Punkt 2 ("falsche/veraltete Aussage in der Doku") |
| Konfigurationsschluessel heisst `tools.include`, "nicht so, wie man ihn suchen wuerde" (kd_rasmus) | REDDIT Z.25-26; Item "kontext", Nebenbefund; Item Frontmatter |
| Kein Werkzeug zeigt aktive Tool-Zahl pro Sub-Agent oder warnt ueber Schwelle | Item "loesungs-audit" Punkt 3; Item "kontext" Abs. 5 (Gap) |
| Sichtbarkeit als offene Anforderung benennen, kein Neubau | Auftrag "Der Bogen" Teil 3; Item "kontext" Abs. 4 |

## Folie 7 — Was diese Hebel nicht loesen

| Aussage | Quelle |
|---|---|
| Schwelle ~50-70 bzw. ~60 als Selbstbericht ohne N, ohne Laufdefinition — Richtwert, kein Messwert | Item "quellen-pruefen", Zahlenpruefung und Fazit |
| Kausalitaet ohne Kontrollexperiment nicht bewiesen — als Muster haltbar, nicht als Kausalgesetz | Item "quellen-pruefen", Mechanismmus-Haltbarkeit und Fazit |
| Doku-Widerspruch muss in der Doku korrigiert werden; das Video baut nichts | Auftrag "Offene Punkte" 2; Item "loesungs-audit" Punkt 2 |
| Quell-URLs sind `.example`-Platzhalter im eingefrorenen Korpus; extern nicht verifizierbar | Item "quellen-pruefen", Fazit und Gap (extern) |

---

## Ungeklaert

Folgende Punkte sind NICHT aus dem Korpus belegbar; sie werden nicht
hochgeschrieben und im Skript als Einschraenkung benannt.

1. **Schwellenwert ~50-70 bzw. ~60 als Messwert.** kd_rasmus (REDDIT Z.15-16)
   und mkirsch (X Z.12-13) nennen die Werte als Selbsbericht ohne N, ohne
   Laufdefinition, ohne Modell-/Promptangabe. Wahrer Kipppunkt und Art der
   Messung sind unbekannt. Im Video nur als Richtwert ausgewiesen.
2. **Kausalitaet.** "Zu viele Werkzeugbeschreibungen verschlechtern die Wahl"
   ist aus dem Korpus als wiederkehrendes Muster haltbar, aber nicht durch ein
   Kontrollexperiment isoliert bewiesen (Item "quellen-pruefen",
   Mechanismmus-Haltbarkeit). Kein Kontrollexperiment, keine Gegengruppe.
3. **Doku-Widerspruch vs. laufendes Tool.** Die Delegations-Doku behauptet,
   `delegate_task` nehme keinen toolsets-Parameter; das Tool-Schema des
   laufenden Hermes exponiert `enabled_toolsets`. Diese Aussage beruht auf dem
   eingefrorenen Doku-Stand (Docs v0.20.0, 2026-08-11) im Item; ob die
   Online-Doku zwischenzeitlich korrigiert wurde, ist hier nicht pruefbar.
4. **Stimmenzahl.** Item nennt "8 unabhaengige Stimmen (Reddit 4, YouTube 3,
   X 1)"; gezaehlt sind Posts. Distinkte Personen sind 6 (Reddit 3: halbmond,
   kd_rasmus, aniela.p; YouTube 2: renkoe, ilvahn; X 1: mkirsch_dev). Das
   Video belegt 6 Personen, nicht 8. (Item "quellen-pruefen",
   Konsistenz der Stimmenzahl; auch `intake/web.md` weicht intern ab,
   "Sieben Stimmen".)
5. **Externe Verifizierbarkeit.** Quell-URLs sind `.example`-Platzhalter in
   einem eingefrorenen Korpus; eine echte Plattform-Pruefung (Reddit/YouTube/X)
   ist hier nicht moeglich.
6. **Echte Produkt-Changelog.** Ob die reale Produkt-Changelog eine
   Werkzeugzahl-Grenze nennt (halbmond bezieht sich auf einen Changelog-Eintrag
   von ~4 Monaten, REDDIT Z.22-23), ist aus dem Korpus nicht belegbar — die
   Changelog-Quelle ist nicht enthalten. Muss gegen die echte Doku/Changelog
   geprueft werden, nicht aus dem Korpus.
7. **Referenz-Doku als "die Umgebung".** Die MCP-/Delegations-Aussagen gelten
   fuer die Referenzumgebung Hermes (Docs v0.20.0); eine Uebertragbarkeit auf
   andere Agentenprodukte ist nicht belegt.