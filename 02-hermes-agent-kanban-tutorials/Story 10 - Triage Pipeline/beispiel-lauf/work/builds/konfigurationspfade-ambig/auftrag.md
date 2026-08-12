# Auftrag: Werkzeug bauen — effektive Konfigurationspfade anzeigen

**Slug:** `konfigurationspfade-ambig`  ·  **Pfad:** `build`  ·  **Punkte:** 76/100
**Arbeitsverzeichnis:** `work/builds/konfigurationspfade-ambig/`

---

## 1. Wortlaut der menschlichen Entscheidung (verbatim)

> UNBLOCK: modify: Route auf build korrigieren. hermes config path/show zeigt
> PFADE, aber nicht, welcher Wert am Ende gilt und aus welcher Datei er stammt
> — genau das ist die Luecke aus den Quellen. Baue das Werkzeug: alle
> Kandidatenpfade auflisten, effektive Werte mit Herkunftsdatei ausgeben,
> Secrets redigieren. Rails einhalten.

**Routenkorrektur:** Der Mensch korrigierte die Route von `video` auf `build`
(bei Lauf 2 des Tors). Der urspruengliche Klassifikatorwert
`loesungsqualitaet: schlecht_erklaert` bleibt in der Item-Datei stehen — er
wird nicht ueberschrieben, sondern durch die menschliche Entscheidung
widerlegt. Die Prep-Stufe des Pfades `build` (`synthese`) wird **nicht
nachgeholt**; die Luecken aus der menschlichen Antwort sind in diesen Auftrag
aufgenommen.

---

## 2. Der freigegebene Vorschlag (aus build.md-Vorlage, gefuellt)

### Der Schmerz

Mehrere Kandidaten fuer dieselbe `config.toml` (Home-Verzeichnis, Projektpfad,
unter Windows zusaetzlich WSL und Roaming) machen unklar, welche Datei
tatsaechlich wirkt. Die Erweiterung liest eine ANDERE `config.toml` als die
IDE-Oberflaeche schreibt — Einstellungen wie "approve required" wirken deshalb
nicht. Drei Meldungen aus zwei getrennten Threads belegen den Schaden: marek.o
setzte die Freigabepflicht "in der Oberflaeche" und "in der wirksamen Datei
nicht" — und erlebte einen Commit im Kundenrepo. tnowak setzte "approve
required", doch "der Agent schrieb ohne Rueckfrage", was zwei verlorene
Arbeitstage kostete. Eine Schutzvorgabe des Nutzers wird stumm umgangen.

### Belege

- `sources/web/forum-konfigurationspfade.md` — wenzelb (3 Kandidaten, Z.11-13),
  marek.o (Freigabepflicht umgangen, Commit im Kundenrepo, Z.15-17; Roaming als
  4. Stelle, Z.21-22)
- `sources/x/2026-08-05-config-pfad.md` — @tnowak ("approve required" gesetzt,
  Agent schrieb ohne Rueckfrage, 2 verlorene Tage; "zwei Pfade, ein Name, keine
  Warnung", Z.8-15)
- Scout-Berichte: `intake/web.md`, `intake/x.md`

### Was gebaut werden soll

Das Werkzeug zeigt dem Nutzer, welche Konfigurationsdatei tatsaechlich wirkt
und welche Werte am Ende gelten:

1. **Alle Kandidatenpfade auflisten.** Die bekannten Fundorte derselben
   `config.toml` bzw. Konfigdatei (Home-Verzeichnis, Projektpfad, unter Windows
   zusaetzlich WSL und Roaming) werden systematisch durchsucht und jede
   vorhandene Datei wird gemeldet.
2. **Effektive Werte mit Herkunftsdatei ausgeben.** Fuer jedes Konfigfeld wird
   der aufgeloeste Wert gedruckt **und** die Datei/die Kandidatenposition, aus
   der er stammt. Das ist genau die Luecke aus den Quellen: `hermes config
   path/show` zeigt PFADE, aber nicht, welcher Wert am Ende gilt und aus
   welcher Datei er kommt.
3. **Secrets redigieren.** Findet das Werkzeug etwas, das nach Token, Passwort
   oder Schluessel aussieht, gibt es `***redigiert***` aus, nie den Wert.

Das Werkzeug **veraendert nichts**: Es liest Dateien und schreibt einen Bericht
nach stdout. Es baut keine Konkurrenz-Warnung im Sinne eines Daemons und
konsultiert keine netzwerkgebundene Quelle — die Such-/Vorrangsordnung wird als
konfigurierbare Eingabe gefuehrt, nicht erfunden.

### Warum jetzt

Das Loesungs-Audit widerlegt die Nutzer-Behauptung "es gibt kein Werkzeug":
Die Hermes-CLI zeigt den effektiv geladenen Pfad und die effektiven Werte
bereits an (`hermes config path`/`show`/`get`, CLI-getestet). Aber diese
Bordmittel drucken die Pfade, nicht die effektiven Werte samt Herkunftsdatei,
und sprechen nicht die Verwechslung gleichnamiger `config.toml` an. Genau
diese Luecke — woher der gewinnende Wert stammt — macht die Nutzer ahnungslos
und fuehrt zu umgangenen Approve-Gates (marek.o, tnowak). Ein kleines, auf
genau diese Frage zugeschnittenes Werkzeug schliesst sie.

### Aufwand und Grenzen

- eine Python-Datei, hoechstens **200 Zeilen**, nur Standardbibliothek
- keine Netzwerkzugriffe, keine Subprozesse, keine Shell-Aufrufe zur Laufzeit
- die konkreteste bekannte Einschraenkung: die exakte Vorrangs-/Suchreihenfolge
  der Erweiterung ist aus dem eingefrorenen Korpus nicht belegbar — das
  Werkzeug muss die Ordnung als Eingabe/Parametrisierung aufnehmen und die
  Kandidaten so auflisten, dass die gewinnende Datei und die Herkunft jedes
  effektiven Werts sichtbar werden, ohne die Ordnung zu erfinden.

### Offene Punkte

1. Prioritaets-/Suchreihenfolge der Konfigurationspfade ist nicht im Korpus
   belegbar — als konfigurierbare Eingabe fuehren, nicht erfinden.
2. Secrets-Redaktion ist zwingende Designvorgabe (API-Keys liegen in denselben
   Konfig-Dateien, tessa_k forum Z.24).
3. Die Schadensfaelle sind reine Selbstauskunft ohne Artefakte; extern nicht
   verifizierbar (eingefrorenes Korpus, Platzhalter-URLs).

---

## 3. Rails (aus `pipeline/rails/build.md`, kopiert — nicht verlinkt)

Diese Grenzen sind hart. Passt eine Idee nicht hinein, wird sie **abgelegt oder
umgeroutet** — die Grenzen werden nicht gedehnt.

### Erlaubt

- **Genau eine Datei** Programmcode, Python 3, **hoechstens 200 Zeilen**.
- Nur die Standardbibliothek. Keine Installation, kein `pip`, keine Netzwerk-
  zugriffe zur Laufzeit.
- Das Werkzeug liest Dateien und schreibt einen Bericht nach stdout. Es
  **veraendert nichts** ausserhalb seines Arbeitsverzeichnisses.
- Alles entsteht unterhalb des zugewiesenen Arbeitsverzeichnisses
  (`$HERMES_KANBAN_WORKSPACE`). Kein Pfad mit `..`, keine absoluten Pfade
  nach draussen.

### Verboten

- Netzwerk, Subprozesse, Shell-Aufrufe aus dem erzeugten Werkzeug heraus.
- Geheimnisse ausgeben. Findet das Werkzeug etwas, das nach Token, Passwort
  oder Schluessel aussieht, gibt es `***redigiert***` aus, nie den Wert.
- Dateien ausserhalb des Arbeitsverzeichnisses lesen oder schreiben.
- Ein zweites Werkzeug, ein Paket, ein Framework. **Eine Datei.**

### Wenn es nicht passt

Rufe `kanban_block(reason="…")` und benenne genau, welche Grenze im Weg steht.
Baue nicht eine kleinere, sinnlose Variante, nur damit etwas fertig wird.

---

## 4. Umsetzungskette

Alle nachfolgenden Karten arbeiten in diesem Verzeichnis:
`~/github/hermes-agent-kanban-tutorials/Story 10 - Triage Pipeline/workspace/work/builds/konfigurationspfade-ambig`

1. **Fulfill prototyp** — `triage-builder`: baut genau eine Python-Datei
   (<=200 Zeilen, Standardbibliothek) nach den Rails in Abschnitt 3 und dem
   Vorschlag in Abschnitt 2.
2. **Fulfill test** — `triage-tester`: prueft das Werkzeug gegen die Rails
   (eine Datei, <=200 Zeilen, keine Geheimnis-Ausgabe, keine Netzwerk/
   Subprozesse) und gegen die Anforderungen in Abschnitt 2 (Kandidatenpfade,
   effektive Werte mit Herkunft, Secrets-Redaktion).