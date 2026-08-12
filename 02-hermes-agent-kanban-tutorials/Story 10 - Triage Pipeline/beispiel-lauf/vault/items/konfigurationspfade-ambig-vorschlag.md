# Vorschlag: Video — Ambigue Konfigurationspfade

**Slug:** `konfigurationspfade-ambig`  ·  **Pfad:** `video`  ·  **Punkte:** 76/100

## Der Schmerz

Mehrere Kandidaten fuer dieselbe `config.toml` (Home-Verzeichnis, Projektpfad,
unter Windows zusaetzlich WSL und Roaming) machen unklar, welche Datei
tatsaechlich wirkt. Die Erweiterung liest eine ANDERE `config.toml` als die
IDE-Oberflaeche schreibt — Einstellungen wie "approve required" wirken deshalb
nicht. Drei Meldungen aus zwei getrennten Threads belegen den Schaden: marek.o
setzte die Freigabepflicht "in der Oberflaeche" und "in der wirksamen Datei
nicht" — und erlebte einen Commit im Kundenrepo. tnowak setzte "approve
required", doch "der Agent schrieb ohne Rueckfrage", was zwei verlorene
Arbeitstage kostete. Eine Schutzvorgabe des Nutzers wird stumm umgangen.

## Belege

- `sources/web/forum-konfigurationspfade.md` — wenzelb (3 Kandidaten, Z.11-13),
  marek.o (Freigabepflicht umgangen, Commit im Kundenrepo, Z.15-17; Roaming als
  4. Stelle, Z.21-22)
- `sources/x/2026-08-05-config-pfad.md` — @tnowak ("approve required" gesetzt,
  Agent schrieb ohne Rueckfrage, 2 verlorene Tage; "zwei Pfade, ein Name, keine
  Warnung", Z.8-15)
- Scout-Berichte: `intake/web.md`, `intake/x.md`

## Warum ein Video und kein Werkzeug

Das Loesungs-Audit widerlegt die Nutzer-Behauptung "es gibt kein Werkzeug":
Die Hermes-CLI zeigt den effektiv geladenen Pfad und die effektiven Werte
bereits an — `hermes config path` druckt den gewinnenden Pfad, `config show`
die aufgeloeste Konfiguration samt `Config:`/`Secrets:`/`Install:`, `config
get <key>` den aufgeloesten effektiven Wert (CLI-getestet). Damit ist die
Kernanforderung des Items technisch geloest. Was fehlt, ist eine
Erklaerungs-/Dokumentationsluecke: die Nutzer wissen nicht, dass/wo sie den
effektiven Pfad ablesen koennen, und die Aufloesungsordnung steht nirgends.
`loesungsqualitaet = schlecht_erklaert` -> ein Video, kein Neubau.

## Der Bogen

1. **Der Schmerz** — Welche `config.toml` gewinnt? 3–4 Kandidaten (Home,
   Projekt, WSL, unter Windows Roaming); wenzelb "nimmt nicht die [Datei], die
   ich erwarte"; tnowak "zwei Pfade, ein Name, keine Warnung". Schaden: marek.o
   (Commit im Kundenrepo trotz Freigabepflicht), tnowak (2 verlorene Tage).
2. **Warum es passiert** — Schreiben und Lesen gehen auf verschiedene Pfade:
   die Oberflaeche schreibt Datei A, die Erweiterung laedt Datei B; in der
   effektiv geladenen Datei fehlen die gesetzten Einstellungen. Die Such- und
   Vorrangsordnung ist nirgends dokumentiert, deshalb kann niemand aus der Doku
   lernen, welche Datei gewinnt.
3. **Die Hebel** — (1) Den effektiven Pfad ablesen statt handisch `find`en:
   `hermes config path`/`show`/`get`. (2) Als Anforderung benennen: Warnung bei
   konkurrierenden gleichnamigen Konfig-Dateien (existiert heute nicht).
   (3) Die Prioritaets-/Suchreihenfolge dokumentieren (gegen die echte
   Erweiterung verifizieren, nicht erfinden).
4. **Grenzen** — Die Prioritaetsordnung ist offen; die Konkurrenz-Warnung wird
   nicht gebaut; Secrets in den Konfig-Dateien (API-Keys, tessa_k) muessen bei
   jeder Anzeige redigiert werden; die Schadensfaelle sind reine Selbstauskunft
   ohne Artefakte und extern nicht verifizierbar.

## Offene Punkte

1. Prioritaets-/Suchreihenfolge der Konfigurationspfade ist aus dem Korpus
   nicht beantwortbar — muss gegen die echte Erweiterung/IDE verifiziert
   werden, nicht erfunden.
2. Konkurrenz-Warnung und Prioritaets-Doku existieren nicht; Secrets-Redaktion
   ist als Designvorgabe mitzufuehren (API-Keys in den Dateien).
3. Schadensfaelle sind Selbstauskunft ohne Artefakte; extern nicht nachpruefbar.

---

**Antworte auf dem Board:**

    hermes kanban --board kanban-story-10 unblock t_a96d0cf5 --reason "approve"
    hermes kanban --board kanban-story-10 unblock t_a96d0cf5 --reason "shelve: <grund>"
    hermes kanban --board kanban-story-10 unblock t_a96d0cf5 --reason "modify: <aenderung>"