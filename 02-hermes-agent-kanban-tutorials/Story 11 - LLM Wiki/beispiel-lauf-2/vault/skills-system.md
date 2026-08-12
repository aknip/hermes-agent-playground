---
slug: skills-system
titel: "Skills-System: Mechanik und Ablageorte als eigene Seite"
status: gemergt
score: 88
score_breakdown: {neuheit: 22, quellenvertrauen: 14, themenbezug: 24,
                  versionsrelevanz: 14, klarheitsgewinn: 14}
wissensstand: fehlt
route: neue_seite
gebuendelt_aus:
  - "intake/transcripts.md (2026-08-07-skills-system.md): Skill=Verzeichnis mit SKILL.md; drei Ablageorte (global/profil-lokal/eingebaut); nur die description landet ungeprueft im Kontext, Rumpf wird bei Bedarf geladen; kanban create --skill erzwingt eine Skill; hermes -p <profil> skills list zeigt Herkunft+enabled/disabled; Skill kostet Kontext, MCP-Server kostet Kontext UND Werkzeug-Slots"
betrifft: [skills-system]
---
Der Slug beschreibt das Item (das fehlende Skills-System), nicht die Quelle. Die
Seite `wiki/pages/skills-system.md` existiert NICHT, obwohl `wiki/index.md` sie
bereits als `[[skills-system]]` verlinkt — es liegt also ein Stub-Link vor, den
dieser Ingest schliessen wuerde. Alle sechs Skill-Aussagen aus dem
Skills-Transkript (0.20.0) betreffen einzig diese Seite und stammen aus demselben
Vorgang, daher EIN Item.

Dedup gegen die Wissensbasis: `skills-system.md` gibt es nicht. `profile-system.md`
erwaehnt `skills/<name>/SKILL.md` als Profildatei (Zeile 29), deckt aber weder die
drei Ablageorte (global/profil-lokal/eingebaut) noch die Lade-Mechanik (nur
description im Kontext) noch `kanban create --skill` ab. Das Themengebiet kommt
vor, die Aussagen in gleicher Genauigkeit stehen NICHT da.

Bewertung je Dimension:
- neuheit (22/25): sechs inhaltlich getrennte Mechanik-Aussagen, von denen keine
  irgendwo in den sieben Seiten in gleicher Genauigkeit steht; eine ganze,
  bereits verlinkte Seite fehlt.
- quellenvertrauen (14/20): Quelle ist ein Video-Transkript des eigenen Kanals
  (erklaerte Mechanik / gemessene Demo), kein offizieller Changelog; deshalb
  braucht es die Verifikations-Bahn.
- themenbezug (24/25): direkter Bezug auf das Skill-System von Hermes Agent
  selbst, Kernbereich der Wissensbasis.
- versionsrelevanz (14/15): bezieht sich auf 0.20.0, die aktuelle Hauptversion.
- klarheitsgewinn (14/15): schafft eine vollstaendig fehlende Kernseite und
  behebt nebenbei einen Stub-Link im Index; ein Agent bekommt eine bislang
  unbeantwortbare Antwort.

summe = 88 >= schwelle 65. status -> recherche. Fan-out ueber
verifikation + seiten-abgleich.