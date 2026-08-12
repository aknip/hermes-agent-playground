---
name: kb-scout-report
description: "Berichtsformat fuer den Wissensbasis-Scout: ein ##-Abschnitt je Kandidat mit den Feldern aus ingest.yaml, woertlichen Zitaten samt Zeitmarke, Version und einer als Vermutung gekennzeichneten Neuheitsschaetzung. Enthaelt die Abgrenzung, was ein Kandidat ist und was nicht."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Scout-Bericht

Ein Bericht, eine Quelle, ein `##`-Abschnitt je Kandidat. Die Feldliste steht in
`ingest.yaml` unter `item_schema.felder` — nicht hier. Lies sie.

## Der Rahmen

```markdown
# Scout-Bericht: <quell-id>

Ausgewertet: <n> Dateien unter <verzeichnis>
Kandidaten: <m>
```

Wenn `n` nicht mit der Anzahl der Dateien im Verzeichnis uebereinstimmt, ist der
Bericht falsch. Du liest **alle**.

## Ein Kandidat

```markdown
## <Titel: die Aussage als Satz, nicht als Schlagwort>

- **aussage:** <was genau behauptet wird, in einem Satz. Praezise genug, dass
  jemand sie widerlegen koennte.>
- **quellen:**
  - `<datei>` — <zeitmarke oder abschnitt>, <datum> — „<woertliches zitat>"
  - `<datei>` — … — „<woertliches zitat>"
- **version:** <auf welche Hermes-Version sich die Aussage bezieht, oder
  `unbestimmt`>
- **betrifft_vermutlich:** <Seiten der Wissensbasis, die das beruehren koennte —
  als Vermutung. Du hast die Wissensbasis nicht gelesen.>
- **neuheit_vermutet:** <`vermutlich neu` | `vermutlich abgedeckt`> — <ein Satz,
  woran du das vermutest>
```

## Zitieren

**Ein Zitat ist woertlich oder es ist kein Zitat.** Drei Regeln, die alle
denselben Zweck haben:

1. **Nie verstaerken.** Sagt die Quelle „bei mir hat das nicht funktioniert",
   schreibe nicht „der Befehl ist defekt".
2. **Zahlen bleiben bei ihrer Herkunft.** „Ab ungefaehr 60 Werkzeugen" aus einem
   Transkript ist eine **Schaetzung des Sprechers**, keine gemessene Grenze.
   Wenn du das im Bericht verwischst, kann es spaeter niemand mehr trennen.
3. **Zeitmarke bzw. Abschnitt immer mit.** Ein Zitat ohne Fundstelle ist fuer
   die Verifikations-Bahn wertlos — sie muesste die ganze Datei erneut lesen.

## Version

Ohne Version ist eine Aussage ueber ein Produkt, das sich fast taeglich aendert,
nicht ueberpruefbar. Steht sie nicht in der Quelle: `unbestimmt`. **Nicht aus
dem Kontext raten** — eine falsche Version ist schaedlicher als keine, weil sie
in der Wissensbasis wie eine Tatsache aussieht.

## Was ein Kandidat ist — und was nicht

| Ist ein Kandidat | Ist keiner |
|---|---|
| eine ueberpruefbare Aussage ueber Hermes Agent | Kanal-Neuigkeiten, Abonnentenzahlen |
| ein gemessenes Verhalten, auch ein ueberraschendes | Ankuendigungen kuenftiger Inhalte |
| eine korrigierte Annahme („ich hatte das falsch") | Lob, Kritik, Stimmung |
| eine erklaerte Mechanik | Werkzeug- und Font-Vorlieben |
| eine Deprecation, ein geaendertes Standardverhalten | Namensfindung, Umfragen |

**Zwei Dateien, die dieselbe Aenderung beschreiben, sind EIN Kandidat mit zwei
Quellen** — nicht zwei Kandidaten.

## Die Grenze, die du nicht ueberschreitest

Du entscheidest, **ob es eine ueberpruefbare Aussage ist**.

Du entscheidest **nicht**, ob sie **wichtig** ist, und **nicht**, ob die
Wissensbasis sie **schon kennt**.

| Stufe | darf entscheiden | darf **nicht** entscheiden |
|---|---|---|
| Scout | Ist das eine ueberpruefbare Aussage? | Ist sie neu? Ist sie wichtig? |
| Triage | Ist sie neu (gelesen), ist sie wichtig (Punkte)? | Ob es sie gibt |

Zwei Filter hintereinander, die dasselbe Kriterium anlegen, sind kein doppelter
Schutz — sie sind ein blinder Fleck. Der zweite kann nicht mehr zeigen, was der
erste schon entfernt hat. Ein Kandidat, den du weglaesst, hinterlaesst **keine
Spur**: kein Board-Eintrag, keine Datei, nichts. Die Schwelle in `ingest.yaml`
wird dadurch zur Attrappe.

`neuheit_vermutet` ist deshalb ausdruecklich als **Vermutung** benannt. Sie ist
ein Hinweis fuer die naechste Stufe, keine Entscheidung.

## Abschluss

```
kanban_complete(
  summary  = "<n> Dateien unter <verzeichnis> ausgewertet, <m> Kandidaten",
  metadata = {"source": "<quell-id>", "candidates": <m>,
              "report": "<pfad>", "files_read": <n>},
)
```

Fehlt das Quellverzeichnis oder ist es leer: `kanban_block(reason=…)` mit dem
exakten Pfad. Kein Ausweichen auf ein anderes Verzeichnis, keine erfundenen
Kandidaten.
