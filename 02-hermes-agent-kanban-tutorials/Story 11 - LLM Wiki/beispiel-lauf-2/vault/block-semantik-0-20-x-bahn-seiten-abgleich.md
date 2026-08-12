# SEITEN-ABGLEICH — Item `block-semantik-0-20-x`

Bahnen-Regel: ich unterscheide durchgehend, was die QUELLE sagt, was ich in
der Wissensbasis GEPRUEFT habe, und was ich schliesse. Ueber die inhaltliche
Wahrheit der neuen Aussagen entscheidet die Bahn `verifikation` — hier zaehlt
nur, was die Seiten WIRKLICH schon wissen.

## Betroffene Seiten

Geprueft (tatsaechlich geoeffnet und Zeile fuer Zeile gelesen):

- `wiki/pages/kanban-block-semantik.md` — version 0.19.0, updated 2026-06-02,
  status: aktuell
- `wiki/pages/kanban-board.md` — version 0.20.0, updated 2026-07-28,
  status: aktuell
- `wiki/index.md` — ohne eigene Aussage zum Block; beide Seiten sind dort
  verlinkt (Zeile 13-14), keine Widersprueche im Index.

Quellen der neuen Aussagen (zum Abgleich zitiert, nicht bewertet):

- `sources/releases/changelog-0.20.1.md` (2026-08-06), Zeilen 9-20
- `sources/releases/changelog-0.20.2.md` (2026-08-09), Zeilen 9-15
- `sources/transcripts/2026-08-08-block-semantik.md` (2026-08-08)

---

## Einzelaussagen — wo steht was in welcher Genauigkeit

### A. `hermes kanban block` nimmt den Grund POSITIONAL, kennt KEIN `--reason`
Genauigkeit der neuen Aussage: spezifische Syntax. Quelle sagt (changelog-0.20.1,
Z.16-18): „`hermes kanban block` nahm den Grund bereits seit 0.20.0 positional;
die Dokumentation zeigte weiterhin `--reason`." Transkript Z.13-20: „Das gibt es
nicht … Der Grund ist ein positionales Argument."

Was die Seite tatsaechlich sagt (kanban-block-semantik.md, Z.24):
```
hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"
```
GEPRUEFT: Die Seite zeigt eine Syntax MIT `--reason`. Das ist nicht
ungenau (unvollstaendig) — es ist die gegenteilige Aussage zur neuen. Eine
Karte, die dem Tor-Bau in Z.24 folgt, bricht laut Quelle mit
`unrecognized arguments` ab.

Befund: **widerspruch** (die falsche Syntax steht ausdruecklich in der Seite).

### B. `--kind` muss VOR der Kartennummer stehen
Genauigkeit: spezifische Argument-Position. Quelle sagt (changelog-0.20.1, Z.18):
„`--kind` muss vor der Kartennummer stehen." Transkript Z.22-27: `hermes kanban
block --kind needs_input <id> "…"`.

Was die Seite tatsaechlich sagt: Z.24-26 zeigt die drei Befehle OHNE jedes
`--kind`; die Block-Arten-Tabelle (Z.35-40) listet die `--kind`-Werte und ihre
Bedeutung, sagt aber an keiner Stelle, wo das Argument stehen muss. Die
Position selbst steht nirgends.

Befund: **fehlt** (der Aspekt „Position von --kind" ist in der Seite nicht
enthalten — die Tabelle erwaehnt `--kind` nur als Wert, nicht die Stellung).

### C. `--initial-status blocked` setzt nur die Spalte, KEIN Tor
Genauigkeit: spezifisches Verhalten beim Anlegen. Quelle sagt (changelog-0.20.1,
Z.12-14): „`--initial-status blocked` die Spalte setzt, aber **kein**
`blocked`-Ereignis erzeugt, und deshalb kein Tor ist." Transkript Z.36-42:
„`--initial-status blocked` setzt die **Spalte** … Parken beim Anlegen ist es
richtig. Als Tor ist es falsch."

Was die Seite tatsaechlich sagt: `kanban-block-semantik.md` erwaehnt
`--initial-status` an keiner Zeile. `kanban-board.md` nennt in Z.25-38 den
Spaltenvorrat inklusive `blocked` (Z.36: „`blocked` | einen **Menschen**") und
sagt an keiner Stelle, dass `--initial-status blocked` kein blocked-Ereignis/
Tor erzeugt. Der Unterschied „parken (Spalte) vs. halten (Ereignis)" fehlt
vollstaendig.

Befund: **fehlt** (beide Seiten kennen `--initial-status blocked` nicht).

### D. `--kind` ist eine TYPANGABE, keine Haltekraft (Block ohne --kind haelt genauso)
Genauigkeit: spezifische Mechanik. Quelle sagt (Transkript Z.44-48): „Was den
Block haelt, ist … nicht die Block-Art. Ein Block ohne `--kind` haelt genauso …
`--kind` ist eine Typangabe, keine Haltekraft."

Was die Seite tatsaechlich sagt: kanban-block-semantik.md Z.44 belegt den
Worker-Pfad `kanban_block(kind=\"needs_input\", reason=…)` und die Tabelle
Z.35-40 fuehrt die `--kind`-Werte als „Bedeutung"/Typen auf. An keiner Stelle
steht, ob ein Block ohne `--kind` haelt oder nicht; die Seite schweigt zur
Haltekraft. Die neue Aussage (kind = Typ, nicht Haltemechanik) steht nicht da.

Befund: **fehlt** (nichts in der Seite widerspricht, aber nichts belegt die
Typangabe-ohne-Haltekraft-Aussage).

### E. Wiederholtes Blockieren derselben Art -> TRIAGE; Ereignis `block_loop_detected`, Zaehler je Block-Art
Zweiteilig. Quelle sagt (changelog-0.20.2, Z.9-15): Karte nach `unblock` mit
**derselben** Block-Art erneut blockiert „landet in der Triage statt in
`blocked`"; neu ist, dass das ausgeloeste Ereignis `block_loop_detected`
heisst und Zaehler/Grenze im Payload traegt. Transkript Z.50-56 bestaetigt den
Weg in die Triage.

Was die Seite tatsaechlich sagt (kanban-block-semantik.md, Z.48-52):
> „Wird eine Karte nach einem `unblock` erneut mit derselben Block-Art
> blockiert, routet Hermes sie in die Triage statt nach `blocked`. Das bricht
> Endlosschleifen aus Blockieren und Entblocken auf."

GEPRUEFT: Der ROUTE-TEIL (erneuter Block derselben Art -> Triage) steht dort in
gleicher Genauigkeit — ABGEDECKT. Was NICHT steht: der Ereignisname
`block_loop_detected`, der Zaehler `block_recurrences` je Block-Art und der
Reset nur bei erfolgreichem Abschluss (changelog-0.20.2 Z.11-12). Diese
Detail-Tiefe (Ereignisname + Zaehlerfuehrung) fehlt.

Befund: Kernaussage **abgedeckt**; die neue Praezision (Ereignisname,
Zaehlerfuehrung) **fehlt** (unvollstaendig fuer das Gesamtdetail).

---

## Zusammenfassung je Seite

**kanban-block-semantik.md (0.19.0):**
- Z.24 `block <id> --reason`: widerspricht Aussage A -> **widerspruch**.
- Z.24-26 / Z.35-40: keine Position von `--kind` -> B **fehlt**.
- Z.35-40: keine Aussage zur Haltekraft von `--kind` -> D **fehlt**.
- Z.48-52: Triage bei Wiederholung -> E abgedeckt; Ereignisname/Zaehler -> E fehlt.
- `--initial-status blocked`: nicht erwaehnt -> C **fehlt**.

**kanban-board.md (0.20.0):**
- Z.25-38 Spaltenliste mit `blocked`; keine `--initial-status`-Aussage -> C **fehlt**.
- Keine der uebrigen Aussagen A/B/D/E beruehrt die Board-Seite inhaltlich;
  sie bleibt korrekt und unveraendert.

**Index (wiki/index.md):** beide Seiten sind korrekt verlinkt (Z.13-14); keine
Aenderung noetig.

## Fazit

Der Kern des Items ist ein echter, wörtlicher Widerspruch: `kanban-block-
semantik.md` Zeile 24 dokumentiert `block <id> --reason` und sagt damit das
Gegenteil der neuen, aus zwei unabhängigen Quellen belegten Syntax (positionaler
Grund, kein `--reason`). Ein Agent, der nach dieser Zeile ein Tor baut, laeuft
laut Quelle mit `unrecognized arguments` auf. Dazu kommen vier rein fehlende
Ergaenzungen (B, C, D und die Detail-Ebene von E) — diese sind Fehlt/Update-
Material, KEIN Widerspruch, und stecken im selben Item, weil sie dieselbe
Seite betreffen und aus demselben 0.20.x-Vorgang stammen.

Für die Route entscheidend ist die widersprechende Zeile 24: solange die Seite
eine falsche Syntax zeigt, ist `konflikt` die ehrliche Klassifikation — nicht
`update`. (Reine Ergänzungen ohne den Widerspruch wären `unvollstaendig`.)

wissensstand: widerspruch
