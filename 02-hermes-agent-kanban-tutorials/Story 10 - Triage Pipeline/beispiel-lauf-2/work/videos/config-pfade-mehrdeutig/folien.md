# folien.md — config-pfade-mehrdeutig (Video, 7 Folien)

Jede Folie: eine Ueberschrift, hoechstens 5 Stichpunkte. Nur belegte Aussagen;
Unbelegtes steht in faktencheck.md unter "ungeklaert".

---

## Folie 1 — Der Schmerz | Welche `config.toml` gewinnt?

- Bis zu vier gleichnamige Speicherorte: Home, Projektpfad, unter WSL ein dritter, unter Windows zusaetzlich Roaming
- wenzelb (Entwicklerforum): "Die Erweiterung nimmt nicht die, die ich erwarte."
- tnowak (X): "Zwei Pfade, ein Name, keine Warnung."
- Konsequenz: unklar, welche Datei tatsaechlich wirkt

## Folie 2 — Der Schmerz | Schaden: Freigabepflicht wird stumm umgangen

- marek.o: Freigabepflicht in der Oberflaeche gesetzt, in der wirksamen Datei nicht — Agent committet in einem Kundenrepo
- tnowak: "approve required" in der Erweiterung gesetzt, der Agent schrieb trotzdem ohne Rueckfrage
- tnowak: zwei Tage Suche, bis die Ursache klar war
- Pointe: eine Schutzvorgabe des Nutzers wird umgangen, mit realem Schaden

## Folie 3 — Warum es passiert | Der Mechanismus

- Lesen und Schreiben gehen auf verschiedene Pfade
- Die Erweiterung laedt eine ANDERE `config.toml` als die IDE-Oberflaeche sie schreibt
- Einstellungen, die die Oberflaeche setzt, fehlen in der effektiv geladenen Datei
- Mehrere gleichnamige Dateien erzeugen keinen Widerspruch und keine Warnung

## Folie 4 — Warum es passiert | Die Suchreihenfolge ist nirgends dokumentiert

- Es gibt eine Aufloesung, aber keine Doku darueber
- Home vs. Projekt vs. WSL vs. Roaming: die Reihenfolge ist aus den Quellen nicht belegt
- Nutzer greifen zu `find` und lesen die Datei von Hand (marek.o)
- Kern-Luecke der Recherche: die Vorrangsordnung steht nirgends belegt

## Folie 5 — Die Hebel | Die Loesung existiert bereits

- `hermes config path` druckt den effektiv geladenen Pfad
- `hermes config show` zeigt die aufgeloeste Konfiguration samt Pfaden
- `hermes config get <key>` druckt den aufgeloesten effektiven Wert
- `hermes config check` meldet fehlende oder veraltete Optionen
- Das ersetzt `find` plus Handlesen (CLI-verifiziert)

## Folie 6 — Die Hebel | Was noch fehlt (2 Anforderungen)

- Warnung bei konkurrierenden gleichnamigen `config.toml` — existiert heute nicht
- Prioritaets-/Suchreihenfolge dokumentieren — offener Gap
- Secrets in denselben Konfig-Dateien muessen bei jeder Anzeige redigiert werden

## Folie 7 — Grenzen | Was diese Hebel nicht loesen

- Die Prioritaetsordnung ist offen; gegen die echte Erweiterung zu verifizieren, nicht erfunden
- Die Konkurrenz-Warnung muesste erst gebaut werden; das Video baut nichts
- Die Schadensfaelle sind Selbstauskunft ohne Artefakte — extern nicht verifizierbar
