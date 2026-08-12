# Folien: Sub-Agenten-Werkzeugflut

Pfad: video · Slug: `subagenten-werkzeugflut` · Stufe: folien
Aufbau nach Spec `pipeline/specs/video.md`: Der Schmerz, Warum es passiert,
Die Hebel, Grenzen. 7 Folien, je Folie eine Ueberschrift und hoechstens
5 Stichpunkte. Belege mit Fundstelle; Details in `faktencheck.md`.

---

## Folie 1 — Der Schmerz | Der Sub-Agent waehlt das falsche Werkzeug — oder gar keins

- kd_rasmus, Messung (Reddit r/aiagents, 2026-08-04): 40 Werkzeuge -> 9 von
  10 Laeufen gut, 80 Werkzeuge -> 3 von 10.
- kd_rasmus: die Schwelle liegt "zwischen 50 und 70 Werkzeugen"
  (sources/web/reddit-subagenten-werkzeugflut.md Z.15-16).
- mkirsch_dev (X, 2026-08-03): Sub-Agenten "haben stumpf das falsche Werkzeug
  gegriffen oder gar keins" (sources/x/2026-08-03-subagenten-mcp.md Z.8-9).
- mkirsch_dev: drei verlorene Stunden dadurch (ebd. Z.8).

---

## Folie 2 — Der Schmerz | Nur der Haupt-Agent ist unsichtbar betroffen

- Bei derselben Tool-Menge behaelt der Haupt-Agent die Trefferquote, die
  Sub-/untergeordneten Agenten kippen (halbmond, reddit Z.12-13; mkirsch, x
  Z.12-13; renkoe vs. ilvahn, youtube Z.12-16).
- Symptom-Variante: falsches Werkzeug ODER gar keins (mkirsch, x Z.9).
- Fehlannahme der Betroffenen: zuerst das Modell verdaechtigt (aniela.p,
  reddit Z.18-19: "Wir dachten erst, es liegt am Modell").
- Pointe: Solange nur der Haupt-Agent beobachtet wird, bleibt der Schaden
  unsichtbar (Item, Abschnitt "Warum relevant").

---

## Folie 3 — Warum es passiert | Der Mechanismus: Werkzeugbeschreibungen im Kontext

- Wirksamer Faktor ist die Zahl der Werkzeugbeschreibungen im Kontext, nicht
  ein MCP-Server-Zaehler (ilvahn, youtube Z.15-16; konvergent ueber das
  Korpus, Item "kontext" Abs. 1).
- Sub-Agenten kippen bei der Menge, auf der der Haupt-Agent stabil bleibt
  (halbmond reddit Z.12-13; mkirsch x Z.12-13).
- MCP-Server als Ausloeser-Metrik: halbmond "mehr als vier" (reddit Z.11),
  ilvahn "sieben" (youtube Z.14), renkoe "Neun" (youtube Z.18), mkirsch
  "sechs" (x Z.11-12) — roh kohaerent im Band ~4-7.
- Konvergenz der Schwellenangaben: ~50-70 (kd_rasmus) und ~60 (mkirsch)
  Werkzeuge (Item, "kontext" Abs. 1 und "quellen-pruefen", Zahlenpruefung).

---

## Folie 4 — Warum es passiert | Keine dokumentierte Grenze

- mkirsch_dev (X, 2026-08-03): "Niemand sagt dir das. In keiner Doku steht
  eine Zahl." (sources/x/2026-08-03-subagenten-mcp.md Z.15).
- Im Korpus existiert keine Schwellen-Dokumentation und kein offizielles
  Tool-Limit (Item, "kontext" Abs. 3).
- Die Referenz-Doku nennt keine konkrete Tool-Zahl und begruendet Filterung
  mit Sicherheit und Listen-Sauberkeit, nicht mit Selektionsgenauigkeit
  (Item, "kontext" Abs. 4).
- Ohne Grenze raten Betroffene und verdaechtigen zuerst das Modell
  (aniela.p, reddit Z.18-19).

---

## Folie 5 — Die Hebel | Die Loesung existiert bereits

- Hebel 1 — Tool-Umfang je Sub-Agent begrenzen: das Tool exponiert
  `delegate_task.enabled_toolsets` (Item, "loesungs-audit" Abs. 2).
- Hebel 2 — Pro MCP-Server filtern statt global begrenzen: `tools.include`
  (Whitelist), `tools.exclude` (Blacklist), `enabled: false`, fnmatch-Globs
  fuer grosse Flaechen (MCP-Doku, Item "kontext" Abs. 4).
- Auswahl bei Installzeit: Hermes schreibt nur die angehakten Server-Tools in
  `tools.include` (Item, "kontext" Abs. 4).
- Community bestaetigt die Abhilfe: "pro Sub-Agent nur seine sechs
  Werkzeuge" (halbmond, reddit Z.21-22; ilvahn, youtube Z.20-21).

---

## Folie 6 — Die Hebel | Der Stolperstein: die Doku fuehrt in die Irre

- Delegations-Doku: "delegate_task does not accept a model-facing toolsets
  parameter" — wörtliches Zitat (Item, "kontext" Abs. 5 / "loesungs-audit"
  Abs. 2).
- Tatsaechlich exponiert das laufende Tool `enabled_toolsets` — die Doku
  widerspricht dem Tool (Item, "loesungs-audit" Abs. 2).
- Konfigurationsschluessel heisst `tools.include`, "nicht so, wie man ihn
  suchen wuerde" (kd_rasmus, reddit Z.25-26).
- Es gibt kein Werkzeug, das die aktive Tool-Zahl pro Sub-Agent anzeigt oder
  ueber eine Schwelle warnt (Item, "loesungs-audit" Abs. 3).

---

## Folie 7 — Grenzen | Was diese Hebel nicht loesen

- Die Schwellen ~50-70 bzw. ~60 sind Selbstbericht ohne N und ohne
  Laufdefinition — Richtwert, kein Messwert (Item, "quellen-pruefen",
  Zahlenpruefung).
- Kausalitaet "Werkzeugbeschreibungen verschlechtern die Wahl" ist nicht
  durch ein Kontrollexperiment belegt — als Muster haltbar, nicht als
  Kausalgesetz (Item, "quellen-pruefen", Mechanismus-Haltbarkeit).
- Der Doku-Widerspruch muss in der Doku korrigiert werden; das Video baut
  nichts und korrigiert keine Doku (Item, "loesungs-audit" / Vorschlag,
  "Offene Punkte" 2).
- Extern nicht verifizierbar: Quelle-URLs sind `.example`-Platzhalter im
  eingefrorenen Korpus (Item, "quellen-pruefen", Fazit).