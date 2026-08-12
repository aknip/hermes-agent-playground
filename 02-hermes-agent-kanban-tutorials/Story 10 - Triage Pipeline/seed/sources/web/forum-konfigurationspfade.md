---
quelle: web
url: https://forum.example/t/welche-config-gilt/9921
plattform: Entwicklerforum
datum: 2026-08-06
stimmen: 3
---

# "Welche config.toml gilt eigentlich?"

**wenzelb:** Ich habe drei Kandidaten fuer die Konfigurationsdatei gefunden —
im Home-Verzeichnis, unter dem Projektpfad und einmal in der WSL-Umgebung. Die
Erweiterung nimmt nicht die, die ich erwarte.

**marek.o:** Bei uns dasselbe Problem, mit echten Folgen: die Freigabepflicht
war in der Oberflaeche gesetzt und in der wirksamen Datei nicht. Der Agent hat
in einem Kundenrepo committet.

**wenzelb:** Gibt es irgendwas, das einem die effektiven Werte anzeigt?

**marek.o:** Nein. Ich mache es mit `find` und lese von Hand. Unter Windows
kommt der Roaming-Pfad noch dazu, dann sind es vier Stellen.

**tessa_k:** Aufpassen beim Herzeigen — in denselben Dateien stehen API-Keys.
