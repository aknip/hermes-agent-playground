---
slug: profile-install-description
titel: "hermes profile install uebernimmt description aus distribution.yaml in profile.yaml"
status: geshelved
score: 62
score_breakdown: {neuheit: 10, quellenvertrauen: 16, themenbezug: 18,
                  versionsrelevanz: 12, klarheitsgewinn: 6}
wissensstand:
route:
gebuendelt_aus:
  - "intake/releases.md (0.20.2): 'hermes profile install uebernimmt description aus distribution.yaml in profile.yaml' (Kanban-Decomposer routet ueber die Beschreibung)"
betrifft: [profile-system]
---
Einzelner Kandidat aus dem 0.20.2-Changelog. Betrifft `profile-system.md`.

Dedup: `profile-system.md` beschreibt bereits, dass `profile.yaml` eine
`description` traegt (Zeile 26), dass der Kanban-Decomposer ueber diese
Beschreibung routet (Zeilen 40-44) und dass Distributions-Installationen eine
`distribution.yaml` mitbringen (Zeilen 46-50). Der 0.20.2-Text ist eine
Fehlerbehebung an dieser Mechanik (description wurde bei lokaler Installation
nicht in profile.yaml uebernommen). Als Behauptung ueber das Endergebnis —
„installierte Profile sind ueber ihre Beschreibung rout-bar" — ist der
gewuenschte Zustand in der Seite bereits angelegt; die Aussage ergaenzt nur ein
Fehlerbehebungsdetail ohne neuen Wissensgehalt fuer einen Agenten.

Bewertung je Dimension:
- neuheit (10/25): im Wesentlichen bereits in `profile-system.md` angelegt; neu
  ist nur das Luecken-Detail einer Fehlerbehebung, nicht ein neuer Sachverhalt.
- quellenvertrauen (16/20): offizieller Changelog.
- themenbezug (18/25): direkt das Profil-System, aber nur eine Randnotiz.
- versionsrelevanz (12/15): aktuelle 0.20.x-Linie.
- klarheitsgewinn (6/15): gering — schreibt fast nur fest, was die Seite schon
  impliziert; wuerde die Antwort nicht praeziser machen.

summe = 62 < schwelle 65. status -> geshelved (unterhalb der Schwelle), kein
Fan-out, kein Mensch wird gefragt.