# Auftrag: config-pfade-mehrdeutig (Pfad video, Freigabe erteilt)

Dieses Verzeichnis ist das dauerhafte Arbeitsverzeichnis der Umsetzungskette.
Alle Worker der Kette laufen hier und sehen den Rest des Workspace NICHT. Alles,
was sie brauchen, steht kopiert in dieser Datei — nichts ist verlinkt.

## Freigabe (menschlicher Bescheid, woertlich)

> UNBLOCK: approve

## Der freigegebene Vorschlag

Nachfolgend der vollstaendige, freigegebene Vorschlag (Stand Lauf 1):

---

# Vorschlag: Video — Mehrdeutige config.toml-Aufloesung

**Slug:** `config-pfade-mehrdeutig`  ·  **Pfad:** `video`  ·  **Punkte:** 81/100

## Der Schmerz

Mehrere gleichnamige Speicherorte fuer dieselbe `config.toml` (Home, Projektpfad,
unter WSL ein dritter Pfad, unter Windows zusaetzlich Roaming als vierte Stelle)
machen unklar, welche Datei tatsaechlich wirkt. Schreiben und Lesen gehen auf
verschiedene Pfade: Die IDE-Erweiterung laedt eine ANDERE `config.toml` als die
Oberflaeche schreibt. Deshalb wirken dort gesetzte Einstellungen wie "approve
required" nicht — eine Schutzvorgabe des Nutzers wird stumm umgangen, mit realem
Schaden.

- @tnowak (X): "Ich habe in der IDE-Erweiterung sauber 'approve required'
  gesetzt. Der Agent hat trotzdem ohne Rueckfrage geschrieben." — nach zwei
  Tagen Suche: "Zwei Pfade, ein Name, keine Warnung."
- marek.o (Forum): "die Freigabepflicht war in der Oberflaeche gesetzt und in
  der wirksamen Datei nicht. Der Agent hat in einem Kundenrepo committet."

## Belege

- `sources/x/2026-08-05-config-pfad.md` — @tnowak (X), 2026-08-05. Sicherheitsfolge:
  "approve required" in der Erweiterung gesetzt, Agent schrieb trotzdem ohne
  Rueckfrage. Zwei Tage Suche; zwei Pfade, ein Name, keine Warnung; unter WSL ein
  dritter Pfad. "Es gibt kein Werkzeug, das dir sagt, welche Datei tatsaechlich
  gewinnt."
- `sources/web/forum-konfigurationspfade.md` — wenzelb (Entwicklerforum),
  2026-08-06: drei Kandidaten (Home, Projektpfad, WSL); "Die Erweiterung nimmt
  nicht die, die ich erwarte."
- `sources/web/forum-konfigurationspfade.md` — marek.o (gleicher Thread): reale
  Folge — Freigabepflicht in der Oberflaeche gesetzt, in der wirksamen Datei
  nicht, Agent committet in einem Kundenrepo; liest von Hand per `find`;
  Windows-Roaming als vierte Stelle.
- `sources/web/forum-konfigurationspfade.md` — tessa_k (gleicher Thread):
  "in denselben Dateien stehen API-Keys" (relevant fuer die Gestaltung einer
  Anzeige-Loesung, nicht fuer die Existenz des Schmerzes).

## Warum ein Video und kein Werkzeug

Das Loesungs-Audit klassifiziert `loesungsqualitaet: verwirrend` (nicht `fehlt`,
nicht `gut`): Das Config-System existiert und wendet die gelesene Datei real an
(der Agent committet je nach der wirksamen Datei), nur erkennbar ist davon nichts,
weil kein Wegweiser die wirksame Datei anzeigt. Das ist ein
Verstaendnis-/Auffindbarkeitsproblem, kein Neubau. Wichtig: die Prep-Stufe hat per
CLI verifiziert, dass `hermes config path`/`show`/`get`/`check` existieren und den
effektiv geladenen Pfad sowie die aufgeloesten Werte anzeigen — die loesungs-audit-
Bahn hatte "kein Anzeige-Werkzeug" nur aus den Nutzerquellen angenommen. Die Loesung
existiert also bereits; sie ist nur nicht auffindbar. Deshalb erklaert das Video die
vorhandene Loesung zugaenglich statt ein Werkzeug zu bauen.

## Der Bogen

1. **Der Schmerz** — welche `config.toml` gewinnt? Bis zu vier Kandidaten; die
   Erweiterung nimmt nicht die erwartete Datei; "zwei Pfade, ein Name, keine
   Warnung". Schaden: Freigabepflicht wird stumm umgangen (Commit im Kundenrepo),
   zwei verlorene Arbeitstage.
2. **Warum es passiert** — Lesen und Schreiben gehen auf verschiedene Pfade;
   die Oberflaeche schreibt Datei A, die Erweiterung laedt Datei B; Einstellungen
   fehlen in der effektiv geladenen Datei; keine Warnung bei konkurrierenden
   gleichnamigen Dateien; die Such-/Vorrangsordnung ist nirgends dokumentiert.
3. **Die Hebel** (die Loesung existiert bereits, das Video macht sie zugaenglich):
   - `hermes config path` druckt den effektiv geladenen Pfad;
     `hermes config show` zeigt die aufgeloeste Konfiguration samt Pfaden;
     `hermes config get <key>` den aufgeloesten effektiven Wert;
     `hermes config check` meldet fehlende/veraltete Optionen — ersetzt
     `find` + Handlesen (CLI-verifiziert).
   - Anforderung benennen: Warnung bei konkurrierenden gleichnamigen
     Konfig-Dateien (existiert heute nicht).
   - Anforderung benennen: Prioritaets-/Suchreihenfolge dokumentieren
     (offener Gap).
4. **Grenzen** — die Prioritaetsordnung ist offen (gegen die echte Erweiterung
   zu verifizieren, nicht erfunden); die Konkurrenz-Warnung muesste erst gebaut
   werden (das Video baut nichts); Secrets in den Konfig-Dateien muessen bei
   jeder Anzeige redigiert werden; die Schadensfaelle sind Selbstauskunft ohne
   Artefakte, extern nicht verifizierbar.

## Offene Punkte

1. **Prioritaets-/Suchreihenfolge** der Konfigurationspfade ist aus dem Korpus
   nicht beantwortbar — muss gegen die echte Erweiterung/IDE verifiziert werden,
   nicht erfunden.
2. Die loesungs-audit-Bahn fuehrte "kein Anzeige-Werkzeug" als Luecke, ohne das
   CLI geprueft zu haben. Die Prep-Stufe belegt per CLI, dass
   `hermes config path/show/get/check` existieren — der Vorschlag fuehrt die
   Loesung als "vorhanden, aber nicht auffindbar" und vermerkt die Korrektur
   gegenueber dem Audit.
3. Konkurrenz-Warnung und Prioritaets-Doku existieren nicht; Secrets-Redaktion
   ist als Designvorgabe mitzufuehren (API-Keys in den Dateien, tessa_k).
4. Schadensfaelle sind Selbstauskunft ohne Artefakte; extern nicht nachpruefbar.

---

# Deliverable-Spec: Pfad `video`

## Was entsteht

| Datei | Inhalt |
|---|---|
| `folien.md` | 6–8 Folien, je Folie eine Ueberschrift, hoechstens 5 Stichpunkte |
| `skript.md` | Sprechtext je Folie, 90–150 Woerter pro Folie |
| `faktencheck.md` | jede belegbare Aussage mit Quelle aus `vault/items/<slug>.md` |

## Aufbau

1. **Der Schmerz** — was genau geht schief, im O-Ton der Quelle.
2. **Warum es passiert** — der Mechanismus, nicht die Symptome.
3. **Die Hebel** — 2–3 konkrete Massnahmen, die es abstellen.
4. **Grenzen** — was diese Hebel *nicht* loesen.

## Qualitaetslatte

- Keine Aussage ohne Beleg. Was du nicht belegen kannst, kommt in
  `faktencheck.md` unter „ungeklaert" — es wird nicht weggelassen und nicht
  hochgeschrieben.
- Kein Marketing-Ton, keine Superlative, keine Emojis.
- Zahlen immer mit Quelle und Datum.

---

## Quellen zum Faktencheck (Items, kopiert aus vault/items/config-pfade-mehrdeutig.md)

Alle belegbaren Aussagen des Videos muessen gegen diese Quellen verifizierbar sein:

- `sources/x/2026-08-05-config-pfad.md` — @tnowak (X), 2026-08-05 — "Ich habe in der IDE-Erweiterung sauber 'approve required' gesetzt. Der Agent hat trotzdem ohne Rueckfrage geschrieben." (zwei Tage Suche; unter WSL kommt ein dritter Pfad dazu)
- `sources/web/forum-konfigurationspfade.md` — Entwicklerforum, 2026-08-06 — wenzelb (drei Kandidaten, Erweiterung nimmt nicht die erwartete) und marek.o (echte Folge: Freigabepflicht in der wirksamen Datei nicht gesetzt, Agent committet in einem Kundenrepo; liest von Hand per `find`; Windows-Roaming = vierte Stelle)

Offene/ungeklaerte Punkte (gehoeren in `faktencheck.md` unter „ungeklaert", nicht hochgeschrieben):
- Prioritaets-/Suchreihenfolge der Konfigurationspfade (nicht im Korpus belegt).
- Verhalten bei gleichzeitigem Windows-Roaming + WSL (nicht belegt).
- Schadensfaelle sind Selbstauskunft ohne Artefakte (extern nicht nachpruefbar).
