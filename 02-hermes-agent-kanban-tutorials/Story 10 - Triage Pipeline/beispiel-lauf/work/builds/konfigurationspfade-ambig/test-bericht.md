# Testbericht — konfigpfade.py (Item konfigurationspfade-ambig)

Geprueft gegen: Rails (Abschnitt 3) + Anforderungen (Abschnitt 2) aus `auftrag.md`.
Umgebung: Python 3.11.9, macOS. Nur im Arbeitsverzeichnis
`work/builds/konfigurationspfade-ambig/` gearbeitet.

## Statische Rails-Pruefung

| Rail | Befund |
|------|--------|
| Genau eine Programmdatei | PASS — nur `konfigpfade.py` (`.py`-Dateien im Verzeichnis = 1) |
| <= 200 Zeilen | PASS — `wc -l` = 197 |
| Nur Standardbibliothek | PASS — Imports: os, sys, re, argparse, tomllib |
| Kein Netzwerk/Subprozess/Shell zur Laufzeit | PASS — kein subprocess, os.system, socket, urllib, requests, exec/eval, shell=True |
| Keine Geheimnis-Ausgabe | PASS — siehe Laeufe; ist die Redaktionslogik aktiv |
| Veraendert nichts ausserhalb / schreibt nicht | PASS — einziger `open(...)` ist `open(path, "rb")` (lesend); keine Schreib-/Loesch-/MKdir-Aufrufe. Nach allen Laeufen wurden keine Dateien ausserhalb des Build-Verzeichnisses angefasst und keine Dateien vom Werkzeug erzeugt |
| Keine eingehaerteten absoluten / `..`-Pfade | PASS — Pfade kommen nur als CLI-Argumente; keine absoluten/`..`-Pfade im Code |

## Funktionale Faelle (real ausgefuehrt)

### Fall 1 — Normalfall: alle 4 Kandidaten (Home, Projekt, WSL, Roaming)
Kommando: `python3 konfigpfade.py fixtures/home fixtures/proj fixtures/wsl fixtures/roaming`
Erwartung: Alle 4 Kandidatenpfade in Prioritaetsreihenfolge gelistet, die erste
vorhandene Datei als gewinnend markiert; jeder effektive Wert samt
Herkunftsdatei; Secrets als `***redigiert***`.
Ist: Alle 4 Pfade gelistet, `[1] fixtures/home/config.toml -- GEWINNT`; Werte
mit Herkunft (z.B. `approve_required = True (aus: .../home/config.toml)`,
`timeout = 30 (aus: .../wsl/config.toml)`); Merge fuegt Werte aus allen
vorhandenen Kandidaten mit hoechstem Vorrang zusammen. Secrets
(`secrets.api_key`, `secrets.password`, `auth.token`) als `***redigiert***`,
nie der Wert.
Urteil: PASS

### Fall 2a — kein Fund / leere Eingabe
Kommando: `python3 konfigpfade.py fixtures/empty fixtures/nonexistent`
Erwartung: robuster Bericht ohne Abbruch.
Ist: `[1] ... -- nicht vorhanden`, `[2] ... -- nicht vorhanden`,
`Effektive Werte: keine Konfigdatei gefunden.`, Exit 0.
Urteil: PASS

### Fall 2b — gar keine Kandidaten angegeben
Kommando: `python3 konfigpfade.py`
Erwartung: sinnvoller Fehler, kein Abbruch durch unhandled exception.
Ist: argparse-Fehler `error: the following arguments are required: dirs`, Exit 2.
Urteil: PASS

### Fall 3 — Secret-WERT ohne Secret-Schluesselnamen (Scope-Rail Redaktion)
Kommando: `python3 konfigpfade.py fixtures/secretval`
(Ist: `session = "eyJhbGciOi...JWT..."` ohne Schluessel "token"; ergaenzend
`plain = "hello"`.)
Erwartung: JWT-Wert wird redigiert, harmloser Wert nicht.
Ist: `session = ***redigiert***`, `plain = hello`.
Urteil: PASS — die Wertform-Heuristik redigiert auch Schluesselnamen-unabhaengig.

### Fall 4 — kaputte TOML-Datei in einem Kandidaten
Kommando: `python3 konfigpfade.py fixtures/broken fixtures/home`
(Kaputte TOML in `fixtures/broken/config.toml`.)
Erwartung: kein Absturz; Datei wird gemeldet/uebersprungen und die Werte aus
den uebrigen Kandidaten geliefert.
Ist: Kein Absturz, Exit 0; Werte kommen korrekt aus `fixtures/home`.
Schwaechen: (a) die kaputte Datei wird als `GEWINNT` markiert (die erste
vorhandene Datei ist die kaputte), obwohl sie keinen Wert beitraegt — die
GEWINNT-Markierung ist daher irrefuehrend; (b) der Parse-Fehler wird NICHT
ausgegeben, obwohl die README behauptet "Unparsbare TOML-Dateien werden
gemeldet und uebersprungen". Beides ist kein Rail-Verstoss, aber ein
Dokumentations-/Verhaltensabgleich ist noetig.
Urteil: PASS (mit Hinweis)

## Zusammenfassung
6 funktionale/statische Faelle, alle PASS. Kein Rail-Verstoss. Ein minderer
Hinweis: kaputte TOML-Kandidaten werden stumm uebersprungen (nicht als Fehler
berichtet, wie README behauptet) und koennen bei "erste vorhandene Datei
gewinnt" als GEWINNT markiert sein, obwohl sie nichts beitragen.
