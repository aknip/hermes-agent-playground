---
name: scout-report
description: "Berichtsformat fuer Scouts einer Triage-Pipeline: eine Quelle auswerten, Kandidaten mit Zitat und Beleg extrahieren, im Item-Schema aus triage.yaml berichten. Erkennen ohne zu bewerten."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Scout-Bericht

Du wertest **eine** Quelle aus und schreibst **einen** Bericht. Was danach
damit geschieht — Duplikate zusammenfuehren, bewerten, routen — ist nicht dein
Teil und darf deinen Bericht nicht faerben.

## Was ein Kandidat ist

Ein Kandidat ist **ein konkretes Problem**, das Menschen tatsaechlich getroffen
hat. Nicht eine Datei, nicht ein Zitat.

- Beschreiben zwei Dateien denselben Fehlermechanismus, ist das **ein**
  Kandidat mit zwei Quellen.
- Beschreibt eine Datei zwei verschiedene Probleme, sind das **zwei**
  Kandidaten.
- Begeisterung, Ankuendigungen, Vermutungen und Meinungen ohne erlebten
  Vorfall sind **keine** Kandidaten. Lass sie kommentarlos weg.
- **Ob ein Kandidat wichtig ist, entscheidest du nicht.** Das macht die
  Rubrik, und sie braucht die schwachen Faelle, um ihre Schwelle ueberhaupt
  anwenden zu koennen. Eine kleine, kosmetische oder laengst umgangene
  Aergernis, die jemand wirklich erlebt hat, ist ein Kandidat. Melde sie.
  Wer hier nach Wichtigkeit filtert, entfernt Items, die nie wieder
  jemand sieht — und die Schwelle in triage.yaml wird zur Attrappe.

## Berichtsformat

Ein `##`-Abschnitt je Kandidat. Die Felder sind die aus
`pipeline/triage.yaml`, `item_schema.felder`:

```markdown
# Scout-Bericht: <quelle>

Ausgewertet: <n> Dateien unter <verzeichnis>
Kandidaten: <m>

## <titel>

- **behauptung:** <ein Satz, was schiefgeht>
- **quellen:**
  - `<datei>` — <autor/plattform>, <datum> — "<woertliches Zitat>"
  - `<datei>` — …
- **warum_relevant:** <ein bis zwei Saetze>
- **loesbar_oder_erklaerbar:** <bauen | erklaeren | unklar> — <Begruendung>
- **loesungsluecke:** <was es heute schon gibt, oder: nichts gefunden>
- **strategische_passung:** <hoch | mittel | niedrig> — <Begruendung>
```

## Zitierregeln

- Woertlich. Ein Zitat wird nicht geglaettet und nicht verstaerkt.
- Zahlen aus der Quelle uebernehmen, mit der Zahl daneben, woher sie stammt.
  Steht dort „zwischen 50 und 70", schreibst du „zwischen 50 und 70" — nicht
  „ab 50".
- Steht die Zahl nicht in der Quelle, gibt es keine Zahl. Schaetze nicht.
- Wie viele unabhaengige Stimmen dasselbe sagen, gehoert in `warum_relevant`.
  Das ist die einzige Zaehlung, die du machst — bewerten tut ein anderer.

## Abschluss

```
kanban_complete(
  summary  = "<quelle>: <n> Dateien ausgewertet, <m> Kandidaten",
  metadata = {"source": "<quelle>", "candidates": <m>,
              "report": "<berichtspfad>", "files_read": <n>},
)
```

Fehlt das Quellverzeichnis oder ist es leer: `kanban_block(reason=...)` mit dem
exakten Pfad. Weiche **nicht** auf ein anderes Verzeichnis aus.
