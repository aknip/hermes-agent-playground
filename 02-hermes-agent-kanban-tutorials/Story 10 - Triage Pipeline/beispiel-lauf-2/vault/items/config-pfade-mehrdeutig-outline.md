---
slug: config-pfade-mehrdeutig
typ: outline-video
pfad: video
status: vorbereitet
erstellt_aus: vault/items/config-pfade-mehrdeutig.md
---

# Auftrag: Video-Outline fuer `config-pfade-mehrdeutig`

Dieses Dokument ist die Ablage der Stufe 2 (Prep). Der Orchestrator liest es in
Stufe 3 und schreibt daraus den Vorschlag nach `pipeline/proposals/video.md`.
Der Vorschlag setzt die unten kopierte Spec um (Folien, Skript, Faktencheck).

Hinweis zur Bahn-Divergenz: Die loesungs-audit-Bahn (siehe Item) hat
"kein Werkzeug zeigt effektive Werte an" als offene Luecke gefuehrt, gestuetzt
nur auf die beiden Nutzerquellen. Diese Prep-Stufe hat das CLI selbst geprueft
und widerlegt: `hermes config path/show/get` existieren und zeigen den
effektiv geladenen Pfad sowie die aufgeloesten Werte (Verifikation unten).
Das aendert den Hebel-Teil: Die Loesung existiert bereits; sie ist nur nicht
auffindbar. Der Rest der Luecken (Warnung, Prioritaets-Doku) bleibt offen.

---

## 1. Gegenstand (aus der Item-Akte, Score 81)

**Titel:** Mehrdeutige config.toml-Aufloesung — wirksame Datei unklar,
approve-required umgangen.

**Kernaussage des Videos:** Mehrere Kandidaten fuer dieselbe `config.toml`
(Home, Projektpfad, unter WSL ein dritter, unter Windows zusaetzlich Roaming
als vierte) machen unklar, welche Datei tatsaechlich wirkt. Schreiben und
Lesen gehen auf verschiedene Pfade: Die Erweiterung liest eine ANDERE
`config.toml` als die IDE-Oberflaeche schreibt. Deshalb wirken in der
Oberflaeche gesetzte Einstellungen wie "approve required" nicht — der Agent
schreibt ohne Rueckfrage, mit realen Schadensfaellen. Es GIBT bereits ein
Werkzeug, das den effektiv geladenen Pfad und die effektiven Werte anzeigt
(`hermes config path`/`show`/`get`) — die Nutzer kennen es nur nicht. Es
fehlen eine Warnung bei konkurrierenden gleichnamigen Dateien und eine
dokumentierte Prioritaetsordnung.

**Pfad-Begruendung:** loesungsqualitaet = `verwirrend` (nicht `fehlt`, nicht
`gut`). Es gibt eine funktionierende Loesung (das Config-System wendet die
gelesene Datei real an); nur erkennbar ist nichts davon, weil kein Wegweiser
die wirksame Datei anzeigt. Das ist ein Verstaendnis-/Auffindbarkeitsproblem,
kein Neubau -> Video.

---

## 2. Die drei Recherche-Befunde (Kurzversion, mit Fundstelle)

| Befund | Kern | Fundstelle |
|---|---|---|
| quellen-pruefen | Schmerz ist kein Einzelfrust: 3 Stimmen / 2 Plattformen (X, Forum), 2 davon mit realen Schadensfaellen (2 Tage Suche; Commit im Kundenrepo). Sicherheitsrelevanz doppelt belegt. Extern NICHT verifizierbar (eingefrorenes Korpus, Platzhalter-URLs). | Item, Abschnitt "Bahn: quellen-pruefen" |
| kontext | Mechanik klar (bis zu vier gleichnamige Speicherorte, Schreiben/Lesen auf getrennten Pfaden), aber die **Prioritaets-/Aufloesungsreihenfolge ist nirgends belegt** — offener Gap. Kein Anzeige-Werkzeug in den Quellen genannt; Nutzer lesen per `find` von Hand. | Item, Abschnitt "Bahn: kontext" |
| loesungs-audit | Config-System existiert und wendet die gelesene Datei real an (marek.o: Agent committet je nach wirksamer Datei). Als Luecke gefuehrt: kein Werkzeug zeige effektive Werte. **Diese Prep-Stufe hat das CLI geprueft: `hermes config path/show/get/check` existieren und zeigen den effektiven Pfad samt aufgeloester Werte** — die "kein Werkzeug"-Annahme gilt nur fuer die von den Quellen erwaehnten Mittel, nicht fuer das vorhandene CLI. Bleibende Luecken: keine Konkurrenz-Warnung, keine Prioritaets-Doku, Secrets-Redaktion als Designvorgabe. | Item, Abschnitt "Bahn: loesungs-audit"; CLI-Verifikation dieser Stufe |

---

## 3. Spec (aus `pipeline/specs/video.md`, kopiert — nicht verlinkt)

### Was entsteht

| Datei | Inhalt |
|---|---|
| `folien.md` | 6–8 Folien, je Folie eine Ueberschrift, hoechstens 5 Stichpunkte |
| `skript.md` | Sprechtext je Folie, 90–150 Woerter pro Folie |
| `faktencheck.md` | jede belegbare Aussage mit Quelle aus `vault/items/<slug>.md` |

### Aufbau

1. **Der Schmerz** — was genau geht schief, im O-Ton der Quelle.
2. **Warum es passiert** — der Mechanismus, nicht die Symptome.
3. **Die Hebel** — 2–3 konkrete Massnahmen, die es abstellen.
4. **Grenzen** — was diese Hebel *nicht* loesen.

### Qualitaetslatte

- Keine Aussage ohne Beleg. Was du nicht belegen kannst, kommt in
  `faktencheck.md` unter "ungeklaert" — es wird nicht weggelassen und nicht
  hochgeschrieben.
- Kein Marketing-Ton, keine Superlative, keine Emojis.
- Zahlen immer mit Quelle und Datum.

---

## 4. Der Bogen (fuellt "Der Bogen" im Vorschlag)

Der Vorschlag und das Video folgen der 4-teiligen Struktur der Spec. Pro Teil
stehen hier die inhaltlichen Bausteine, jede Aussage mit Fundstelle.

### Teil 1 — Der Schmerz (O-Ton der Quelle)

- tnowak (X): "Ich habe in der IDE-Erweiterung sauber 'approve required'
  gesetzt. Der Agent hat trotzdem ohne Rueckfrage geschrieben." (x Z.8-9)
- tnowak: nach zwei Tagen Suche "liest [die Erweiterung] eine ANDERE config.toml
  als die IDE-Oberflaeche sie schreibt. Zwei Pfade, ein Name, keine Warnung."
  (x Z.11-12)
- marek.o (Forum): "die Freigabepflicht war in der Oberflaeche gesetzt und in
  der wirksamen Datei nicht. Der Agent hat in einem Kundenrepo committet."
  (forum Z.15-17)
- Pointe: Eine Schutzvorgabe des Nutzers (Approve-Gate) wird stumm umgangen —
  mit realem Schaden.

### Teil 2 — Warum es passiert (Mechanismus, nicht Symptome)

- Es gibt mehrere gleichnamige Speicherorte: Home (global), Projektpfad
  (lokal), WSL (dritter, x Z.12-13; forum Z.12-13), Windows-Roaming (vierter,
  forum Z.21-22).
- Schreiben und Lesen gehen auf verschiedene Pfade -> die Erweiterung laedt
  eine andere Datei, als die Oberflaeche schreibt (x Z.11-12). Einstellungen,
  die die Oberflaeche setzt, fehlen in der effektiv geladenen Datei.
- Keine Warnung bei mehreren gleichnamigen `config.toml` (x Z.12 "keine
  Warnung"; forum implizit).
- Die **Such- und Vorrangsordnung ist nirgends dokumentiert** (kontext-Bahn,
  Gap) — deshalb kann niemand aus der Doku lernen, welche Datei gewinnt; Nutzer
  greifen zu `find` und Handlesen (forum Z.21-22).

### Teil 3 — Die Hebel (2–3 konkrete Massnahmen)

Die Loesung existiert bereits; das Video macht sie zugengaenglich und benennt
die zwei fehlenden Stuecke:

1. **Den effektiven Pfad ablesen statt handisch suchen.** `hermes config path`
   druckt den effektiv geladenen Pfad; `hermes config show` zeigt die
   aufgeloeste Konfiguration samt `Config:`/`Secrets:`/`Install:`; `hermes
   config get <key>` druckt den aufgeloesten effektiven Wert; `hermes config
   check` meldet fehlende/veraltete Optionen. **CLI-verifiziert (dieser Lauf):
   `config path` liefert den Pfad, `config get model` liefert aufgeloeste
   Werte, `config show` fuehrt den Pfad der wirksamen Datei auf.** Das ersetzt
   `find` + Handlesen.
2. **Warnung bei konkurrierenden gleichnamigen Konfig-Dateien.** Existiert
   heute nicht — als Anforderung benennen, kein Neubau im Video.
3. **Die Prioritaets-/Suchreihenfolge dokumentieren.** Aktuell offener Gap;
   Reihenfolge gegen die echte Erweiterung verifizieren statt erfinden.

### Teil 4 — Grenzen (was die Hebel NICHT loesen)

- Die Prioritaetsordnung steht nirgends; das Video kann sie nur als offene
  Frage fuehren, nicht aufloesen (kontext-Gap).
- Die Konkurrenz-Warnung existiert noch nicht — das Video zeigt das Problem,
  baut nichts.
- **Secrets:** In denselben Konfig-Dateien liegen API-Keys (tessa_k, forum
  Z.24). Eine Anzeige effektiver Werte muss Secrets redigieren.
- Die Schadensfaelle sind reine Selbstauskunft (eingefrorenes Korpus, keine
  Artefakte) — extern nicht verifizierbar.

---

## 5. Folien-Plan (zielt auf `folien.md`, 6–8 Folien, <=5 Stichpunkte/Folie)

Geplant 7 Folien. Je Folie: Ueberschrift + Stichpunkte (werden in Stufe 3
final ausgeformt).

- **Folie 1 — Der Schmerz | "Welche `config.toml` gewinnt?"**
  - bis zu vier Kandidaten: Home, Projektpfad, WSL, unter Windows Roaming
  - wenzelb: Erweiterung nimmt nicht die erwartete Datei
  - tnowak: "zwei Pfade, ein Name, keine Warnung"
  - Konsequenz: unklar, welche Datei tatsaechlich wirkt

- **Folie 2 — Der Schmerz | Der Schaden: Freigabepflicht wird umgangen**
  - marek.o: Freigabepflicht gesetzt, wirkt nicht, Commit im Kundenrepo
  - tnowak: "approve required" gesetzt, Agent schrieb ohne Rueckfrage
  - tnowak: zwei verlorene Arbeitstage
  - Pointe: Schutzvorgabe des Nutzers stumm unterlaufen

- **Folie 3 — Warum es passiert | Der Mechanismus**
  - Lesen und Schreiben gehen auf verschiedene Pfade
  - Oberflaeche schreibt Datei A, Erweiterung laedt Datei B
  - Einstellungen fehlen in der effektiv geladenen Datei
  - Kein Widerspruch, keine Warnung

- **Folie 4 — Warum es passiert | Die Suchreihenfolge ist nirgends dokumentiert**
  - Es gibt eine Aufloesung, aber keine Doku darueber
  - Home vs. Projekt vs. WSL vs. Roaming: Reihenfolge unbekannt
  - Nutzer greifen zu `find` und Handlesen (marek.o)
  - Kern-Gap der Recherche

- **Folie 5 — Die Hebel | Die Loesung existiert bereits**
  - `hermes config path` -> druckt den effektiv geladenen Pfad
  - `hermes config show` -> aufgeloeste Konfiguration samt Pfaden
  - `hermes config get <key>` -> aufgeloester effektiver Wert
  - `hermes config check` -> fehlende/veraltete Optionen
  - Das ersetzt `find` + Handlesen

- **Folie 6 — Die Hebel | Was noch fehlt (2 Anforderungen)**
  - Warnung bei konkurrierenden gleichnamigen `config.toml` (fehlt heute)
  - Prioritaets-/Suchreihenfolge dokumentieren (offener Gap)
  - Secrets in den Konfig-Dateien muessen redigiert werden

- **Folie 7 — Grenzen | Was das nicht loest**
  - Prioritaetsordnung ist offen; gegen die echte Erweiterung verifizieren
  - Warnung muesste gebaut werden; das Video baut nichts
  - Schadensfaelle extern nicht belegbar (eingefrorenes Korpus)

---

## 6. Skript-Plan (zielt auf `skript.md`, 90–150 Woerter je Folie)

In Stufe 3 je Folie ein Sprechtext von 90–150 Woertern. Ton: sachlich, im
Present Tense, keine Superlative, kein Marketing. Je Folie die O-Ton-Zitate der
Quelle einweben (Folie 1–2 schwerpunktmaessig), Mechanik auf Folie 3–4,
Werkzeug-Konkretheit auf Folie 5, die zwei offenen Anforderungen auf Folie 6,
Grenzen auf Folie 7. Woerterzahl pro Folie gegensteuern.

---

## 7. Faktencheck-Plan (zielt auf `faktencheck.md`)

Jede belegbare Aussage mit Quelle aus `vault/items/config-pfade-mehrdeutig.md`
bzw. darin zitierter Quelldatei. Zu pruefende Statements (nicht abschliessend):

| Aussage | Quelle |
|---|---|
| "approve required" gesetzt, Agent schrieb ohne Rueckfrage | `sources/x/2026-08-05-config-pfad.md` Z.8-9 (tnowak, 2026-08-05) |
| Erweiterung liest andere `config.toml` als die IDE schreibt; zwei Pfade, ein Name, keine Warnung | x Z.11-12 (tnowak) |
| zwei verlorene Arbeitstage | x Z.11 (tnowak) |
| WSL als dritter Pfad | x Z.12-13; forum Z.12-13 |
| 3 Kandidaten (Home/Projekt/WSL); Erweiterung nimmt nicht die erwartete | `sources/web/forum-konfigurationspfade.md` Z.11-13 (wenzelb) |
| Freigabepflicht in Oberflaeche gesetzt, wirksame Datei nicht; Commit im Kundenrepo | forum Z.15-17 (marek.o) |
| kein Anzeige-Werkzeug genannt; Nutzer nutzen `find` und lesen von Hand | forum Z.19-22; x Z.15 |
| Windows-Roaming als vierte Stelle | forum Z.21-22 (marek.o) |
| API-Keys liegen in denselben Konfig-Dateien | forum Z.24 (tessa_k) |
| Config-System wendet gelesene Datei real an (Agent committet je nach wirksamer Datei) | Item "Bahn: loesungs-audit" (marek.o) |
| `hermes config path`/`show`/`get`/`check` zeigen effektiven Pfad / aufgeloeste Werte | CLI-Verifikation dieser Prep-Stufe (hermes config path/show/get auf dem Rechner ausgefuehrt) |
| Prioritaets-/Suchreihenfolge nicht dokumentiert | Item "Bahn: kontext", Gap-Absatz |

**Ungeklaert (kommen in faktencheck.md unter "ungeklaert", nicht weglassen):**
- Konkrete Vorrangsreihenfolge bei gleichnamigen Dateien (Home > Projekt? WSL?
  Roaming? lokal vs. global?) — nicht im Korpus beantwortbar.
- Konkreter Produktname der IDE-Erweiterung und die Dateinamens-Konvention
  ausser `config.toml`.
- Verhalten bei gleichzeitiger WSL + Windows-Roaming (beide zusaetzlichen
  Pfade) — in keiner Quelle belegt.
- Ob die loesungs-audit-Bahn die Existenz von `hermes config path/show/get`
  bereits kannte: sie fuehrte es nicht; der Beleg stammt aus der
  CLI-Verifikation dieser Prep-Stufe, nicht aus dem Item.
- Externe Verifizierbarkeit der Schadensfaelle (kein Commit-Hash, keine
  Artefakte; eingefrorenes Korpus mit Platzhalter-URLs).

---

## 8. Offene Punkte (fuellt "Offene Punkte" im Vorschlag)

1. Prioritaets-/Suchreihenfolge der Konfigurationspfade ist aus dem Korpus
   nicht beantwortbar — muss gegen die echte Erweiterung/IDE verifiziert
   werden, nicht erfunden.
2. Die loesungs-audit-Bahn fuehrte "kein Anzeige-Werkzeug" als Luecke, ohne
   das CLI geprueft zu haben. Diese Prep-Stufe belegt per CLI, dass
   `hermes config path/show/get/check` existieren — der Vorschlag sollte die
   Loesung als "vorhanden, aber nicht auffindbar" fuehren und die Korrektur
   gegenueber dem Audit vermerken.
3. Konkurrenz-Warnung und Prioritaets-Doku existieren nicht; Secrets-Redaktion
   ist als Designvorgabe mitzufuehren (API-Keys in den Dateien).
4. Schadensfaelle sind Selbstauskunft ohne Artefakte; extern nicht
   nachpruefbar.
