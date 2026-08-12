# Seiten-Abgleich: cron-no-agent-leerer-lauf

Lane: seiten-abgleich
Item: vault/cron-no-agent-leerer-lauf.md
Slug: cron-no-agent-leerer-lauf

## Die Aussage (Quelle)

changelog-0.20.1.md, Zeilen 26-28 (Veröffentlicht 2026-08-06, offizieller Changelog):

> **Cron:** Jobs mit `--no-agent` schrieben bei leerem stdout eine leere
> Ausgabedatei nach `~/.hermes/cron/output/<job-id>/`. Leere Läufe erzeugen
> keine Datei mehr.

Die zu pruefende Regel: **Ein `--no-agent`-Job mit leerem stdout erzeugt keine
Ausgabedatei mehr unter `~/.hermes/cron/output/<job-id>/`.**

## Betroffene Seiten

Primaer betroffen: `wiki/pages/cron-und-zeitplan.md` (betrifft im Item-Schema).
Geprueft, NICHT betroffen: `wiki/pages/release-historie.md` (nennt nur "Cron:
--no-agent fuer tokenfreie Skript-Jobs" als Versionszeile, keine
Ausgabeverhalten-Regel). Uebrige Seiten unter `wiki/pages/` weisen kein
treffendes Stichwort auf (geprueft via Suchlauf "leer|empty|stdout|no-agent|
keine Datei").

## Was die Seite tatsaechlich sagt

`wiki/pages/cron-und-zeitplan.md` (updated 2026-07-14, version 0.20.0):

- Zeile 40, Abschnitt `### Ablageorte`: `Ausgaben:
  ~/.hermes/cron/output/<job-id>/` — nennt NUR den Ablageort.
- Zeilen 15-17, Kurzfassung: `--no-agent` laeuft kein Modell mit, das Skript
  ist der Job, keine Tokens — sagt NICHTS ueber die Ausgabedatei bei leerem
  stdout.
- Zeilen 44-47, `### Cron in Verbindung mit dem Board`: erwaehnt `--no-agent`
  + `hermes kanban create`, kein Ausgabeverhalten.

## Befund

- Die Seite existiert und ist der natuerliche Heimatort der Regel (sie deckt
  `--no-agent` und die Ablageorte `output/<job-id>/` bereits ab).
- Die **Leerlauf-keine-Datei-Regel** selbst (leerer stdout -> keine Datei) ist
  auf der Seite an KEINER Stelle gefasst — weder in Kurzfassung noch in
  Details. Weder genauer noch ungenauer steht sie dort; sie fehlt ganz.
- Kein Widerspruch: Die Seite behauptet nichts, was der Regel widerspricht.
  Die Existenz des Ablageorts (`output/<job-id>/`) ist mit der neuen Regel
  vereinbar (Datei wird nur noch bei nicht-leerem stdout geschrieben).
- Da die zustaendige Seite existiert und die Aussage dort nur fehlt/ungenau
  aufgenommen waere, ist das ein `update` auf die bestehende Seite — KEINE
  neue Seite noetig.

## Klassifikation

Route-Tabelle (ingest.yaml `route.tabelle`):
`unvollstaendig` -> `update` ("Seite existiert, Aussage fehlt oder ist ungenau").

Zutreffend, weil: cron-und-zeitplan.md existiert und ist der richtige Ort,
aber die Leerlauf-keine-Datei-Regel ist dort nicht in gleicher (noch in
irgendeiner) Genauigkeit aufgenommen. Ein neues Seiten-Anlegen (fehlt ->
neue_seite) waere falsch, da der Platz vorhanden ist.

wissensstand: unvollstaendig