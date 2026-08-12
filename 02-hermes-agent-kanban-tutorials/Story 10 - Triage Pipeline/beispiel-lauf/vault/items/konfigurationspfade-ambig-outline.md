---
slug: konfigurationspfade-ambig
typ: outline-video
pfad: video
status: vorbereitet
erstellt_aus: vault/items/konfigurationspfade-ambig.md
---

# Auftrag: Video-Outline fuer `konfigurationspfade-ambig`

Dieses Dokument ist die Ablage der Stufe 2 (Prep). Der Orchestrator liest es in
Stufe 3 und schreibt daraus den Vorschlag nach `pipeline/proposals/video.md`.
Der Vorschlag setzt die unten kopierte Spec um (Folien, Skript, Faktencheck).

---

## 1. Gegenstand (aus der Item-Akte, Score 76)

**Titel:** Ambigue Konfigurationspfade — wirksame Datei unklar, effektive Werte
nicht einsehbar, Freigabepflicht wird umgangen.

**Kernaussage des Videos:** Mehrere Kandidaten fuer dieselbe `config.toml`
(Home, Projektpfad, unter Windows zusaetzlich WSL und Roaming) machen unklar,
welche Datei tatsaechlich wirkt. Die Erweiterung liest eine ANDERE `config.toml`
als die IDE-Oberflaeche schreibt. Einstellungen wie "approve required" wirken
deshalb nicht: Der Agent schreibt ohne Rueckfrage. Es GIBT bereits ein Werkzeug,
das den effektiv geladenen Pfad und die effektiven Werte anzeigt
(`hermes config path`/`show`/`get`) — die Nutzer kennen es nur nicht. Es fehlen
die Warnung bei konkurrierenden gleichnamigen Dateien und eine dokumentierte
Prioritaetsordnung.

**Pfad-Begruendung:** loesungsqualitaet = `schlecht_erklaert` (nicht `fehlt`,
nicht `gut`). Es gibt eine funktionierende Loesung; sie ist fuer diesen
Anwendungsfall schlecht zugaenglich/dokumentiert. Das ist eine
Erklaerungsluecke, kein Neubau -> Video.

---

## 2. Die drei Recherche-Befunde (Kurzversion, mit Fundstelle)

| Befund | Kern | Fundstelle |
|---|---|---|
| quellen-pruefen | Schmerz ist kein Einzelfrust; 2 Threads / 2 unabhaengige Beobachter (marek.o, tnowak) mit zwei getrennten Schadensfaellen. Extern NICHT verifizierbar (eingefrorenes Korpus, Platzhalter-URLs, keine Artefakte). | Item, Abschnitt "Recherche: quellen-pruefen" |
| kontext | Mechanik klar (Schreiben/Lesen auf verschiedenen Pfaden), aber die **Prioritaets-/Suchreihenfolge ist nirgends dokumentiert** — offener Gap. Kein Anzeige-Werkzeug bekannt ausser Handarbeit (`find`). | Item, Abschnitt "Recherche: kontext" |
| loesungs-audit | **Es gibt bereits ein Werkzeug:** `hermes config path`/`show`/`get`/`check` zeigen effektiven Pfad und Werte (selbst getestet). Scout-Behauptung "kein Werkzeug" widerlegt. Rest-Luecken: keine Konkurrenz-Warnung, keine Prioritaets-Doku, Secrets-Redaktion fehlt als Designvorgabe. | Item, Abschnitt "Recherche: loesungs-audit" |

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

- wenzelb: 3 Kandidaten (Home, Projekt, WSL) — "die Erweiterung nimmt nicht
  die [Datei], die ich erwarte" (forum Z.11-13).
- marek.o: Freigabepflicht "war in der Oberflaeche gesetzt und in der wirksamen
  Datei nicht" — Commit im Kundenrepo (forum Z.15-17).
- tnowak: "approve required" gesetzt, Agent schrieb ohne Rueckfrage, 2 verlorene
  Tage, "zwei Pfade, ein Name, keine Warnung" (x Z.8-15).
- Pointe: Eine Schutzvorgabe des Nutzers (Approve-Gate) wird stumm umgangen.

### Teil 2 — Warum es passiert (Mechanismus, nicht Symptome)

- Die Erweiterung liest eine **ANDERE `config.toml` als die IDE-Oberflaeche
  schreibt** (x Z.11-12; forum Z.15-17).
- Schreiben und Lesen gehen auf verschiedene Pfade -> in der effektiv geladenen
  Datei fehlen Einstellungen, die die Oberflaeche gesetzt hat.
- Keine Warnung bei mehreren gleichnamigen `config.toml` (x Z.12; forum implizit).
- Die **Such- und Vorrangsordnung ist nirgends dokumentiert** (offener Gap der
  kontext-Bahn) — deshalb kann niemand aus der Doku lernen, welche Datei gewinnt.

### Teil 3 — Die Hebel (2–3 konkrete Massnahmen)

Die Loesung existiert bereits; das Video macht sie zugengaenglich und benennt
die zwei fehlenden Stuecke:

1. **Den effektiven Pfad ablesen statt handisch suchen.** `hermes config path`
   druckt den effektiv geladenen Pfad; `hermes config show` zeigt die
   aufgeloeste Konfiguration samt `Config:`/`Secrets:`/`Install:`; `hermes
   config get <key>` druckt den aufgeloesten effektiven Wert (loesungs-audit,
   CLI-getestet).
2. **Warnung bei konkurrierenden gleichnamigen Konfig-Dateien.** Existiert
   heute nicht (`config check` meldet nur fehlende/veraltete Optionen) — als
   Anforderung benennen, kein Neubau im Video.
3. **Die Prioritaets-/Suchreihenfolge dokumentieren.** Aktuell offener Gap;
   Reihenfolge gegen die echte Erweiterung verifizieren statt erfinden.

### Teil 4 — Grenzen (was die Hebel NICHT loesen)

- Die Prioritaetsordnung steht nirgends; das Video kann sie nur als offene
  Frage fuehren, nicht aufloesen (kontext-Gap).
- Die Konkurrenz-Warnung existiert noch nicht — das Video zeigt das Problem,
  baut nichts.
- **Secrets:** In denselben Konfig-Dateien liegen API-Keys (tessa_k, forum
  Z.24). Jede Anzeige effektiver Werte muss Secrets redigieren.
- Die Schadensfaelle sind reine Selbstauskunft (eingefrorenes Korpus, keine
  Artefakte) — extern nicht verifizierbar.

---

## 5. Folien-Plan (zielt auf `folien.md`, 6–8 Folien, <=5 Stichpunkte/Folie)

Geplant 7 Folien. Je Folie: Ueberschrift + Stichpunkte (werden in Stufe 3
final ausgeformt).

- **Folie 1 — Der Schmerz | "Welche `config.toml` gewinnt?"**
  - 3–4 Kandidaten: Home, Projektpfad, WSL, unter Windows Roaming
  - wenzelb: Erweiterung nimmt nicht die erwartete Datei
  - tnowak: "zwei Pfade, ein Name, keine Warnung"
  - Konsequenz: unklar, welche Datei tatsaechlich wirkt

- **Folie 2 — Der Schmerz | Der Schaden: Freigabepflicht wird umgangen**
  - marek.o: Freigabepflicht gesetzt, wirkt nicht, Commit im Kundenrepo
  - tnowak: "approve required" gesetzt, Agent schrieb ohne Rueckfrage
  - tnowak: 2 verlorene Arbeitstage
  - Pointe: Schutzvorgabe des Nutzers stumm unterlaufen

- **Folie 3 — Warum es passiert | Der Mechanismus**
  - Lesen und Schreiben gehen auf verschiedene Pfade
  - Oberflaeche schreibt Datei A, Erweiterung laedt Datei B
  - Einstellungen fehlen in der effektiv geladenen Datei
  - Kein Widerspruch, keine Warnung

- **Folie 4 — Warum es passiert | Die Suchreihenfolge ist nirgends dokumentiert**
  - Widerspruch: Es gibt eine deterministische Aufloesung, aber keine Doku
  - Home vs. Projekt vs. WSL vs. Roaming: Reihenfolge unbekannt
  - Nutzer greifen zu `find` und Handlesen
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
  - Warnung ist gebaut werden muessen, das Video baut nichts
  - Schadensfaelle extern nicht belegbar (frozenes Korpus)

---

## 6. Skript-Plan (zielt auf `skript.md`, 90–150 Woerter je Folie)

In Stufe 3 je Folie ein Sprechtext von 90–150 Woertern. Ton: sachlich, im
Present Tense, keine Superlative, kein Marketing. Je Folie die O-Ton-Zitate der
Quelle einweben (Folie 1–2 schwerpunktmaessig), Mechanik auf Folie 3–4,
Werkzeug-Konkretheit auf Folie 5, die zwei offenen Anforderungen auf Folie 6,
Grenzen auf Folie 7. Woerterzahl pro Folie gegensteuern.

---

## 7. Faktencheck-Plan (zielt auf `faktencheck.md`)

Jede belegbare Aussage mit Quelle aus `vault/items/konfigurationspfade-ambig.md`
bzw. darin zitierter Quelldatei. Zu pruefende Statements (nicht abschliessend):

| Aussage | Quelle |
|---|---|
| 3 Kandidaten (Home/Projekt/WSL) | `sources/web/forum-konfigurationspfade.md` Z.11-13 (wenzelb) |
| Roaming-Pfad = 4. Stelle unter Windows | forum Z.21-22 (marek.o) |
| Freigabepflicht in Oberflaeche gesetzt, wirksame Datei nicht; Commit im Kundenrepo | forum Z.15-17 (marek.o) |
| Erweiterung liest andere `config.toml` als die IDE schreibt | x Z.11-12 (tnowak) |
| "approve required" gesetzt, Agent schrieb ohne Rueckfrage, 2 Tage | x Z.8-15 (tnowak) |
| "zwei Pfade, ein Name, keine Warnung" | x Z.12 (tnowak) |
| WSL als dritte Stelle (beide Threads) | forum Z.12-13; x Z.12-13 |
| Kein Anzeige-Werkzeug; Nutzer nutzen `find` | forum Z.19-22; x Z.15 |
| `hermes config path`/`show`/`get`/`check` zeigen effektiven Pfad/Werte | Item "loesungs-audit" (CLI-getestet) |
| API-Keys liegen in denselben Konfig-Dateien | forum Z.24 (tessa_k) |
| Prioritaets-/Suchreihenfolge nicht dokumentiert | Item "kontext", Gap-Absatz |

**Ungeklaert (kommen in faktencheck.md unter "ungeklaert", nicht weglassen):**
- Konkrete Vorrangsreihenfolge bei gleichnamigen Dateien (Home > Projekt? WSL?
  Roaming? lokal vs. global?) — nicht im Korpus beantwortbar.
- Konkreter Produktname der IDE-Erweiterung und die Dateinamens-Konvention
  ausser `config.toml`.
- Externe Verifizierbarkeit der Schadensfaelle (kein Commit-Hash, keine
  Artefakte; eingefrorenes Korpus mit Platzhalter-URLs).

---

## 8. Offene Punkte (fuellt "Offene Punkte" im Vorschlag)

1. Prioritaets-/Suchreihenfolge der Konfigurationspfade ist aus dem Korpus
   nicht beantwortbar — muss gegen die echte Erweiterung/IDE verifiziert
   werden, nicht erfunden.
2. Konkurrenz-Warnung und Prioritaets-Doku existieren nicht; Secrets-Redaktion
   ist als Designvorgabe mitzufuehren (API-Keys in den Dateien).
3. Schadensfaelle sind Selbstauskunft ohne Artefakte; extern nicht nachpruefbar.