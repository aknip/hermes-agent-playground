# faktencheck.md — config-pfade-mehrdeutig

Jede belegbare Aussage des Videos mit ihrer Quelle. Belegquellen sind die
Quelldateien aus `vault/items/config-pfade-mehrdeutig.md`:
- `sources/x/2026-08-05-config-pfad.md` — @tnowak (X), 2026-08-05.
- `sources/web/forum-konfigurationspfade.md` — Entwicklerforum, 2026-08-06
  (wenzelb, marek.o, tessa_k).

Aussagen, die sich nicht belegen lassen, stehen unter "ungeklaert".

---

## Belegte Aussagen

| # | Aussage (Folie) | Quelle |
|---|---|---|
| 1 | Bis zu vier gleichnamige Speicherorte: Home, Projektpfad, WSL, unter Windows Roaming | wenzelb (Home, Projektpfad, WSL; drei Kandidaten) + tnowak (WSL als dritter Pfad) + marek.o (Roaming als vierte Stelle); kontext-Sektion der Item-Datei |
| 2 | wenzelb: "Die Erweiterung nimmt nicht die, die ich erwarte." | forum, wenzelb, Zeilen 11–13 |
| 3 | tnowak: "Zwei Pfade, ein Name, keine Warnung." | x-Quelle, Zeile 12 |
| 4 | Unklar, welche Datei tatsaechlich wirkt | tnowak: "Es gibt kein Werkzeug, das dir sagt, welche Datei tatsaechlich gewinnt." (Zeile 15); marek.o: "Nein." (auf Frage nach Anzeige-Werkzeug) |
| 5 | marek.o: Freigabepflicht in der Oberflaeche gesetzt, in der wirksamen Datei nicht; Agent committet in einem Kundenrepo | forum, marek.o, Zeilen 15–17 |
| 6 | tnowak: "approve required" in der Erweiterung gesetzt, Agent schrieb trotzdem ohne Rueckfrage | x-Quelle, Zeilen 8–9 |
| 7 | tnowak: zwei Tage Suche, bis die Ursache klar war | x-Quelle, Zeile 11 ("Nach zwei Tagen Suche") |
| 8 | Die Erweiterung liest eine ANDERE config.toml als die IDE-Oberflaeche sie schreibt (Lesen/Schreiben auf verschiedenen Pfaden) | tnowak, x-Quelle, Zeilen 11–12; item-Datei kontext |
| 9 | Einstellungen der Oberflaeche fehlen in der effektiv geladenen Datei | marek.o-Fall (Freigabepflicht nur in der Oberflaeche), forum Zeilen 15–17 |
| 10 | Mehrere gleichnamige Dateien erzeugen keinen Widerspruch und keine Warnung | tnowak: "keine Warnung", x-Quelle Zeile 12; loesungs-audit-Sektion belegt fehlende Warnung |
| 11 | Es gibt eine Aufloesung, aber keine Doku darueber (Prioritaets-/Suchreihenfolge nicht belegt) | kontext-Sektion der Item-Datei ("die Quellen ... geben nirgends die PRIORITAET/Aufloesungsreihenfolge an") |
| 12 | Nutzer greifen zu `find` und lesen die Datei von Hand | marek.o: "Ich mache es mit `find` und lese von Hand." forum Zeile 21–22 |
| 13 | `hermes config path` druckt den effektiv geladenen Pfad | CLI-verifiziert durch Prep-Stufe (auftrag.md, Abschnitt "Warum ein Video", Punkt 2) |
| 14 | `hermes config show` zeigt die aufgeloeste Konfiguration samt Pfaden | CLI-verifiziert durch Prep-Stufe (auftrag.md) |
| 15 | `hermes config get <key>` druckt den aufgeloesten effektiven Wert | CLI-verifiziert durch Prep-Stufe (auftrag.md) |
| 16 | `hermes config check` meldet fehlende oder veraltete Optionen | CLI-verifiziert durch Prep-Stufe (auftrag.md) |
| 17 | Die CLI-Befehle ersetzen `find` plus Handlesen | CLI-Verifikation (auftrag.md, Punkt 2); marek.o's `find`-Arbeit als Kontrast |
| 18 | Warnung bei konkurrierenden gleichnamigen config.toml existiert heute nicht | loesungs-audit-Sektion ("Keine Warnung bei mehreren/konkurrierenden Kandidaten"); von Prep/kommend als offene Anforderung |
| 19 | Prioritaets-/Suchreihenfolge dokumentieren — offener Gap | auftrag.md "Offene Punkte" 1 und 3; kontext-Sektion Item-Datei |
| 20 | In denselben Konfig-Dateien stehen API-Keys; Secrets muessen bei jeder Anzeige redigiert werden | tessa_k, forum Zeile 24; item-Datei Nebenbefund |
| 21 | Die Prioritaetsordnung ist offen, gegen die echte Erweiterung zu verifizieren, nicht erfunden | auftrag.md "Offene Punkte" 1 und 4 (Grenzen) |
| 22 | Die Konkurrenz-Warnung muesste erst gebaut werden; das Video baut nichts | auftrag.md Grenzen ("das Video baut nichts"); loesungs-audit-Sektion (Warnung existiert nicht) |
| 23 | Die Schadensfaelle sind Selbstauskunft ohne Artefakte, extern nicht verifizierbar | auftrag.md "Offene Punkte" 4; item-Datei Grenzen |

---

## Ungeklaert

Diese Punkte sind nicht belegbar und werden im Video nicht als Fakten
ausgegeben.

- **Prioritaets-/Suchreihenfolge der Konfigurationspfade** (in welcher
  Reihenfolge geprueft wird, welche Ebene Vorrang hat): im Korpus nicht
  belegt. Muss gegen die echte Erweiterung/IDE verifiziert werden, nicht
  erfunden.
- **Verhalten bei gleichzeitigem Windows-Roaming und WSL** (ob beide
  zusaetzlichen Pfade gleichzeitig auftreten und wie sie sich dann
  zueinander verhalten): nicht belegt.
- **Schadensfaelle (Commit im Kundenrepo, zwei Arbeitstage Suche)** sind
  Selbstauskunft ohne Artefakte; extern nicht nachpruefbar. tnowak und
  marek.o koennen nicht zweifelsfrei als vollstaendig unabhaengig gelten:
  wenzelb und marek.o posten im selben Forum-Thread (Konsensorroboration);
  die plattform-unabhaengige Stimme ist @tnowak auf X.
- **Konkreter lokaler Pfad unter dem Projektpfad** (Dateiname/Layout): nicht
  spezifiziert in den Quellen.
