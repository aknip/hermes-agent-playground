# Scope-Rails: Pfad `build`

Diese Grenzen sind hart. Passt eine Idee nicht hinein, wird sie **abgelegt oder
umgeroutet** — die Grenzen werden nicht gedehnt.

## Erlaubt

- **Genau eine Datei** Programmcode, Python 3, **hoechstens 200 Zeilen**.
- Nur die Standardbibliothek. Keine Installation, kein `pip`, keine Netzwerk-
  zugriffe zur Laufzeit.
- Das Werkzeug liest Dateien und schreibt einen Bericht nach stdout. Es
  **veraendert nichts** ausserhalb seines Arbeitsverzeichnisses.
- Alles entsteht unterhalb des zugewiesenen Arbeitsverzeichnisses
  (`$HERMES_KANBAN_WORKSPACE`). Kein Pfad mit `..`, keine absoluten Pfade
  nach draussen.

## Verboten

- Netzwerk, Subprozesse, Shell-Aufrufe aus dem erzeugten Werkzeug heraus.
- Geheimnisse ausgeben. Findet das Werkzeug etwas, das nach Token, Passwort
  oder Schluessel aussieht, gibt es `***redigiert***` aus, nie den Wert.
- Dateien ausserhalb des Arbeitsverzeichnisses lesen oder schreiben.
- Ein zweites Werkzeug, ein Paket, ein Framework. **Eine Datei.**

## Wenn es nicht passt

Rufe `kanban_block(reason="…")` und benenne genau, welche Grenze im Weg steht.
Baue nicht eine kleinere, sinnlose Variante, nur damit etwas fertig wird.
