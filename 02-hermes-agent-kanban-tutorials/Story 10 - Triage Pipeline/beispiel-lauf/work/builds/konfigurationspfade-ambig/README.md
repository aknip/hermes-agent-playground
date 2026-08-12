# konfigpfade — effektive Konfigurationspfade anzeigen

Eine einzige Python-Datei (`konfigpfade.py`, 197 Zeilen, nur Standardbibliothek),
die beantwortet, **welche** `config.toml` unter mehreren Kandidaten gewinnt und
**aus welcher Datei** jeder effektive Konfigwert stammt.

## Was es tut

1. **Kandidatenpfade auflisten.** Alle uebergebenen Kandidaten-Verzeichnisse
   werden in Prioritaetsreihenfolge geprueft; jede vorhandene/fehlende Datei
   wird gemeldet und die erste vorhandene als **GEWINNT** markiert.
2. **Effektive Werte mit Herkunftsdatei ausgeben.** Fuer jeden Konfigwert wird
   der aufgeloeste Wert **und** die Datei gedruckt, aus der er stammt
   (Kandidat mit dem hoechsten Vorrang, der den Wert definiert).
3. **Secrets redigieren.** Werte, deren Schluesselname nach Geheimnis klingt
   (token, password, api_key, secret, auth, …) oder deren Wert nach Token/
   Schluessel aussieht (sk-/pk-/ghp_-Praefixe, JWT, lange Schlüsselstrings),
   werden als `***redigiert***` ausgegeben — nie der Wert.

Das Werkzeug liest nur Dateien und schreibt einen Bericht nach stdout. Es
**veraendert nichts**, nimmt keine Netzwerk-/Subprozess-/Shell-Aufrufe vor und
baut keine Warnung/keinen Daemon.

## Ausfuehren

    python3 konfigpfade.py [--file NAME] DIR1 [DIR2 ...]

- `DIR1 DIR2 …` sind die Kandidaten-Verzeichnisse **in Prioritaetsreihenfolge**
  (zuerst = hoechster Vorrang = gewinnt). Beispiel fuer die vier
  Kandidatenorte aus dem Item (Home, Projekt, WSL, Windows-Roaming):

      python3 konfigpfade.py "$HOME/.config/app" "$PWD" \
          "/mnt/wslg/home/user/.config/app" \
          "$APPDATA/app"

- `--file NAME` waehlt den Dateinamen der Konfigdatei (Standard: `config.toml`).

## Rails-Einordnung / bewusste Entscheidungen

- **Genau eine Datei, 197 <= 200 Zeilen, nur Standardbibliothek** (`os`, `sys`,
  `re`, `argparse`, `tomllib` ab Python 3.11). Kein `pip`, keine Installation.
- **Die Prioritaets-/Suchreihenfolge wird nicht erfunden**, sondern als
  Positional-Argumente gefuehrt (Auftrag Abschnitt 2, Offener Punkt 1). Der
  Nutzer bestimmt die Ordnung; das Werkzeug haertet keinen absoluten Pfad und
  keinen `..`-Pfad ein.
- **Kein Netzwerk / Subprozess / Shell** im erzeugten Werkzeug.
- **Secrets-Redaktion** ist zwingend (Abschnitt 2, Offener Punkt 2 und Rails):
  der Bericht gibt nie einen Wert aus, der nach Token/Passwort/Schluessel
  aussieht.
- **Nur lesen / nur stdout**: keine Schreibzugriffe irgendwohin.

## Bewusst NICHT enthalten

- Keine eigenstaendige Ermittlung der "echten" Suchreihenfolge der Erweiterung
  (ist im eingefrorenen Korpus nicht belegbar) — die Ordnung kommt als Eingabe.
- Keine Daemon-Warnung bei Konkurrenz; das Werkzeug ist ein reines
  Anzeige-Werkzeug (einmaliger Lauf, stdout), wie im Vorschlag verlangt.
- Keine Schreib/Editier-Funktion, keine Rekursion in Unterverzeichnisse.
- Unparsbare TOML-Dateien werden gemeldet und uebersprungen, nicht abgebrochen.