# Arbeitsverzeichnis der Triage-Pipeline

Das hier ist die Arbeitskopie. Der Master liegt in `seed/` und wird nie
beschrieben — `../reset-workspace.sh` baut dieses Verzeichnis daraus neu auf.

```
pipeline/            die Pipeline-Definition — Rubrik, Route, Pfade, Rails
  triage.yaml        die EINE Datei, in der die Fachlichkeit steht
  rails/build.md     harte Grenzen fuer den Bau-Pfad
  specs/video.md     Ausgabeformat fuer den Video-Pfad
  proposals/*.md     die Vorlagen fuer die Vorschlaege am Tor

sources/x/           das eingefrorene X-Korpus   — was Scout 1 sieht
sources/web/         das eingefrorene Web-Korpus — was Scout 2 sieht

intake/              Scout-Berichte, eine Datei je Quelle
vault/items/         eine Markdown-Datei je verfolgtem Item — die Aktenlage
work/builds/<slug>/  dauerhaftes Arbeitsverzeichnis des Bau-Pfads
work/videos/<slug>/  dauerhaftes Arbeitsverzeichnis des Video-Pfads
```

`intake/`, `vault/items/` und `work/` sind zu Beginn leer. Was dort am Ende
liegt, hat die Flotte erzeugt.
