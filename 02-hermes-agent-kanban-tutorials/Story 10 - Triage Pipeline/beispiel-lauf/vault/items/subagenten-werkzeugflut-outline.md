---
slug: subagenten-werkzeugflut
typ: outline-video
pfad: video
status: vorbereitet
erstellt_aus: vault/items/subagenten-werkzeugflut.md
---

# Auftrag: Video-Outline fuer `subagenten-werkzeugflut`

Dieses Dokument ist die Ablage der Stufe 2 (Prep). Der Orchestrator liest es in
Stufe 3 und schreibt daraus den Vorschlag nach `pipeline/proposals/video.md`.
Der Vorschlag setzt die unten kopierte Spec um (Folien, Skript, Faktencheck).

---

## 1. Gegenstand (aus der Item-Akte, Score 85)

**Titel:** Sub-Agenten waehlen Werkzeuge falsch (oder gar keins), sobald zu
viele Werkzeuge/MCP-Server im Kontext liegen.

**Kernaussage des Videos:** Ab einer Schwelle von zu vielen aktivierten
MCP-Servern bzw. zu vielen Werkzeugbeschreibungen im Kontext faellt die
Trefferquote der Werkzeugwahl von Sub-Agenten stark ab (oder sie greifen gar
keins), waehrend der Haupt-Agent nichts merkt. Die Community nennt konsistent
eine Werkzeugzahl-Schwelle (~50–70 bzw. ~60); in keiner Doku steht eine Zahl.
Die Abhilfe existiert bereits: pro-Server-Filterung (`tools.include`/`exclude`)
und per-Sub-Agent-Tool-Begrenzung (`enabled_toolsets`) — aber die
Delegations-Doku behauptet das Gegenteil und fuehrt den Nutzer in die Irre.

**Pfad-Begruendung:** loesungsqualitaet = `schlecht_erklaert` (nicht `fehlt`,
nicht `gut`). Es gibt eine funktionierende Loesung (Allow-List); fuer den
Sub-Agent-Fall ist sie schlecht/selbstwiderspruechlich dokumentiert und eine
dokumentierte Grenze fehlt ganz. Das ist eine Erklaerungsluecke, kein Neubau ->
Video.

---

## 2. Die drei Recherche-Befunde (Kurzversion, mit Fundstelle)

| Befund | Kern | Fundstelle |
|---|---|---|
| quellen-pruefen | Schmerz ist kein Einzelfrust: 6 distinkte Personen ueber 3 Plattformen (Reddit 3, YouTube 2, X 1). Zahlen intern konsistent (~60 ∈ [50,70]), aber Selbstbericht ohne N/Methodik — als Richtwert tragbar, nicht als Messwert. Extern NICHT verifizierbar (eingefrorenes Korpus, Platzhalter-URLs). | Item, Abschnitt "Recherche: quellen-pruefen" |
| kontext | Mechanik klar (Werkzeugbeschreibungen im Kontext ueberfordern die Sub-Agent-Wahl, Haupt-Agent bleibt stabil). **Keine dokumentierte Schwelle** im Korpus. Referenz-Doku hat per-Server-Filtermodell (`tools.include`/`exclude`), aber **kein per-Subagent-Allow-List-Konstrukt** und kein Tool zur Anzeige der aktiven Tool-Zahl. | Item, Abschnitt "Recherche: kontext" |
| loesungs-audit | MCP-Allow-List (`tools.include`/`exclude`) ist heute GUT dokumentiert. Auf der Sub-Agent-Seite: Tool exponiert `enabled_toolsets`, aber die Delegations-Doku sagt "does not accept a toolsets parameter" — **Doku widerspricht dem laufenden Tool**. Kein Schwellwert, kein Anzeige-/Warnwerkzeug. | Item, Abschnitt "Bahn: loesungs-audit" |

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

- kd_rasmus (Messung): "40 Werkzeuge -> 9 von 10 Laeufe gut, 80 Werkzeuge ->
  3 von 10", Schwelle "zwischen 50 und 70 Werkzeugen" (reddit Z.15-16).
- mkirsch_dev: "Ab ungefaehr 60 Werkzeugen im Kontext kippt es", "stumpf das
  falsche Werkzeug gegriffen oder gar keins", drei verlorene Stunden
  (x Z.9-13).
- Symptom-Variante: Sub-Agent greift falsches Werkzeug ODER gar keins
  (x Z.9-10).
- Fehlannahme der Betroffenen: erst das Modell verdaechtigt ("Wir dachten
  erst, es liegt am Modell", aniela.p, reddit Z.19-20).
- Pointe: Der Haupt-Agent laeuft mit denselben Werkzeugen problemlos — der
  Schaden bleibt dem Sub-Agent unsichtbar.

### Teil 2 — Warum es passiert (Mechanismus, nicht Symptome)

- Wirksamer Faktor ist die Zahl der **Werkzeugbeschreibungen im Kontext**,
  nicht ein MCP-Server-Zaehler (ilvahn nennt die Ursache explizit; konvergent
  ueber alle drei Quellen, Item Abschnitt "kontext" Abs. 1 und
  "quellen-pruefen").
- Sub-/untergeordnete Agenten kippen bei derselben Tool-Menge, der
  Haupt-Agent haelt die Trefferquote (halbmond reddit Z.12-13; mkirsch x
  Z.13; renkoe vs. ilvahn youtube Z.12-13).
- MCP-Server als Ausloeser-Metrik: halbmond "mehr als vier MCP-Server"
  (reddit Z.11-12), ilvahn "als ich auf sieben hoch bin" / renkoe "Neun"
  (youtube Z.15-18), mkirsch "sechs" (x Z.11-12) — roh kohaerent ~4-7.
- **Keine dokumentierte Grenze:** mkirsch "Niemand sagt dir das. In keiner
  Doku steht eine Zahl." (x Z.15). Im Korpus existiert keine
  Schwellen-Dokumentation (Item, kontext Abs. 3).

### Teil 3 — Die Hebel (2–3 konkrete Massnahmen)

Die Loesung existiert bereits; das Video macht sie zugengaenglich und benennt
die dokumentarischen Stolpersteine:

1. **Tool-Umfang je Sub-Agent begrenzen.** Das Tool exponiert
   `delegate_task.enabled_toolsets` — damit ist die Community-Abhilfe "pro
   Sub-Agent nur seine sechs Werkzeuge" (reddit Z.21-22) technisch umsetzbar.
   ABER: die Delegations-Doku sagt wörtlich "delegate_task does not accept a
   model-facing toolsets parameter" — eine falsche/veraltete Aussage, die
   Nutzer aktiv in die Irre fuehrt (loesungs-audit, Abs. 2).
2. **Pro MCP-Server filtern statt global begrenzen.** MCP-Doku "Per-server
   filtering": `tools.include` (Whitelist), `tools.exclude` (Blacklist),
   `enabled: false`, fnmatch-Globs fuer grosse Flaechen; Auswahl bei
   Installzeit. Das ist die dokumentierte Allow-List (Item, kontext Abs. 4).
   Konfigurationsschluessel heisst `tools.include` — "nicht so, wie man ihn
   suchen wuerde" (kd_rasmus, reddit Z.25-26).
3. **Aktive Tool-Zahl sichtbar machen.** Es gibt kein Tool, das die Tool-Anzahl
   pro Sub-Agent im Kontext anzeigt oder ueber eine Schwelle warnt; es ist
   keine Grenze dokumentiert (loesungs-audit, Abs. 3). Als Anforderung
   benennen, kein Neubau im Video.

### Teil 4 — Grenzen (was die Hebel NICHT loesen)

- **Keine belegte Schwelle:** ~50-70 bzw. ~60 ist Selbstbericht ohne N und
  ohne Laufdefinition — Richtwert, kein Messwert, kein dokumentiertes Limit
  (quellen-pruefen, Zahlenpruefung).
- **Kausalitaet nicht bewiesen:** kein Kontrollexperiment (dieselbe
  Sub-Agent-Aufgabe mit/ohne wenige Tools), das die Versagensursache isoliert
  haette (quellen-pruefen, Mechanismus-Haltbarkeit).
- **Doku-Widerspruch bleibt:** der Fehler in der Delegations-Doku
  ("does not accept a toolsets parameter") muss in der Doku korrigiert werden;
  das Video zeigt das Problem, korrigiert die Doku nicht.
- Externe Verifizierbarkeit fehlt (eingefrorenes Korpus, Platzhalter-URLs).

---

## 5. Folien-Plan (zielt auf `folien.md`, 6–8 Folien, <=5 Stichpunkte/Folie)

Geplant 7 Folien. Je Folie: Ueberschrift + Stichpunkte (werden in Stufe 3
final ausgeformt).

- **Folie 1 — Der Schmerz | "Sub-Agent waehlt das falsche Werkzeug — oder gar keins"**
  - kd_rasmus: 40 Werkzeuge -> 9/10 Laeufe gut, 80 -> 3/10
  - kd_rasmus: Schwelle "zwischen 50 und 70 Werkzeugen"
  - mkirsch: "stumpf das falsche Werkzeug gegriffen oder gar keins"
  - mkirsch: drei verlorene Stunden

- **Folie 2 — Der Schmerz | Der Haupt-Agent merkt nichts**
  - Haupt-Agent haelt die Trefferquote, Sub-Agenten kippen (gleiche Tool-Menge)
  - Symptom-Variante: falsches Werkzeug ODER gar keins
  - Erst das Modell verdaechtigt (aniela.p: "Wir dachten erst, es liegt am Modell")
  - Pointe: der Schaden bleibt unsichtbar, solange nur der Haupt-Agent beobachtet wird

- **Folie 3 — Warum es passiert | Der Mechanismus**
  - Wirksamer Faktor: Zahl der Werkzeugbeschreibungen im Kontext
  - Nicht ein MCP-Server-Zaehler, sondern die Tool-Menge im Kontext kippt die Wahl
  - MCP-Server als Ausloeser: ~4-7 (halbmond, ilvahn, renkoe, mkirsch)
  - Konvergenz der Stimmen: ~50-70 bzw. ~60 Werkzeuge

- **Folie 4 — Warum es passiert | Keine dokumentierte Grenze**
  - mkirsch: "Niemand sagt dir das. In keiner Doku steht eine Zahl."
  - Keine Schwellen-Doku im Korpus, kein Tool-Limit dokumentiert
  - Betroffene raten und verdaechtigen zuerst das Modell
  - Kern-Gap der Recherche

- **Folie 5 — Die Hebel | Die Loesung existiert bereits**
  - `delegate_task.enabled_toolsets` begrenzt den Tool-Umfang je Sub-Agent
  - MCP "Per-server filtering": `tools.include` (Whitelist), `tools.exclude`
  - `enabled: false` schaltet einen Server ganz ab; fnmatch-Globs fuer grosse Flaechen
  - Auswahl bei Installzeit ("Tool selection at install time")

- **Folie 6 — Die Hebel | Der Stolperstein: die Doku fuehrt in die Irre**
  - Delegations-Doku: "delegate_task does not accept a toolsets parameter"
  - Tatsaechlich exponiert das Tool `enabled_toolsets` — Doku widerspricht dem Tool
  - Schluessel heisst `tools.include`, nicht erwartbar (kd_rasmus)
  - Kein Anzeige-/Warnwerkzeug fuer die aktive Tool-Zahl

- **Folie 7 — Grenzen | Was das nicht loest**
  - ~50-70/~60 ist Selbstbericht ohne N — Richtwert, kein Messwert
  - Kausalitaet nicht bewiesen (kein Kontrollexperiment)
  - Doku-Widerspruch muss in der Doku korrigiert werden; das Video baut nichts
  - Extern nicht verifizierbar (eingefrorenes Korpus)

---

## 6. Skript-Plan (zielt auf `skript.md`, 90–150 Woerter je Folie)

In Stufe 3 je Folie ein Sprechtext von 90–150 Woertern. Ton: sachlich, im
Present Tense, keine Superlative, kein Marketing. Je Folie die
O-Ton-Zitate der Quelle einweben (Folie 1–2 schwerpunktmaessig), Mechanik auf
Folie 3–4, Werkzeug-Konkretheit auf Folie 5–6, Grenzen auf Folie 7.
Woerterzahl pro Folie gegensteuern.

---

## 7. Faktencheck-Plan (zielt auf `faktencheck.md`)

Jede belegbare Aussage mit Quelle aus `vault/items/subagenten-werkzeugflut.md`
bzw. darin zitierter Quelldatei. Zu pruefende Statements (nicht abschliessend):

| Aussage | Quelle |
|---|---|
| 40 Werkzeuge -> 9/10 Laeufe gut, 80 -> 3/10 | `sources/web/reddit-subagenten-werkzeugflut.md` Z.15-16 (kd_rasmus, 2026-08-04) |
| Schwelle "zwischen 50 und 70 Werkzeugen" | reddit Z.15-16 (kd_rasmus) |
| "Ab ungefaehr 60 Werkzeugen im Kontext kippt es" | `sources/x/2026-08-03-subagenten-mcp.md` Z.12-13 (mkirsch_dev, 2026-08-03) |
| "stumpf das falsche Werkzeug gegriffen oder gar keins" | x Z.9-10 (mkirsch) |
| drei verlorene Stunden | x (mkirsch, Item "Warum relevant") |
| Haupt-Agent haelt Trefferquote, Sub-Agenten kippen | reddit Z.12-13; x Z.13; youtube Z.12-13 |
| "Wir dachten erst, es liegt am Modell" | reddit Z.19-20 (aniela.p) |
| MCP-Server-Ausloeser ~4-7 (>4, 7, 9, 6) | reddit Z.11-12; youtube Z.15-18; x Z.11-12 |
| "Niemand sagt dir das. In keiner Doku steht eine Zahl." | x Z.15 (mkirsch) |
| Keine Schwellen-Doku im Korpus | Item "kontext" Abs. 3 |
| MCP "Per-server filtering": `tools.include`/`tools.exclude`/`enabled: false`/Globs | Item "kontext" Abs. 4 (MCP-Doku) |
| Auswahl bei Installzeit | Item "kontext" Abs. 4 |
| `tools.include` heisst "nicht so, wie man ihn suchen wuerde" | reddit Z.25-26 (kd_rasmus) |
| Delegation: Sub-Agenten erben Parent-Toolsets; `delegate_task` "does not accept a toolsets parameter" | Item "kontext" Abs. 5; "loesungs-audit" Abs. 2 |
| Tool exponiert tatsaechlich `enabled_toolsets` | Item "loesungs-audit" Abs. 2 |
| Kein Anzeige-/Warnwerkzeug fuer aktive Tool-Zahl, kein dokumentierter Schwellwert | Item "loesungs-audit" Abs. 3 |

**Ungeklaert (kommen in faktencheck.md unter "ungeklaert", nicht weglassen):**
- Exakte Schwelle als Messwert: kd_rasmus' Messung liefert kein N, keine
  Laufdefinition, kein Modell/Prompt; "9/10"/"3/10" ist Selbstbericht, nicht
  kontrolliert.
- Kausalitaet "zu viele Werkzeugbeschreibungen verschlechtert die Wahl":
  kein Kontrollexperiment — haltbar als Muster, nicht als Kausalgesetz.
- Externe Verifizierbarkeit: Quelle-URLs sind `.example`-Platzhalter im
  eingefrorenen Korpus; echte Plattform-Verifikation nicht moeglich.
- Stimmenzahl-Diskrepanz: Item nennt "8 Stimmen (Reddit 4, YouTube 3, X 1)",
  tatsaechlich 6 distinkte Personen (Reddit 3, YouTube 2, X 1);
  YouTube-frontmatter "stimmen: 3" vs. 2 Kommentatoren. Im Faktencheck als
  Einschraenkung fuehren, nicht als 8 belegen.
- Ob die echte Produkt-Changelog eine Grenze nennt: Changelog-Quelle von
  halbmond ist im Korpus nicht enthalten; muss gegen die echte Doku/Changelog
  verifiziert werden. (MCP "Current limits" betrifft nur eingebetteten
  `hermes mcp serve`, nicht die Tool-Anzahl.)

---

## 8. Offene Punkte (fuellt "Offene Punkte" im Vorschlag)

1. Schwellen-Doku (in Doku/Changelog) ist aus dem Korpus nicht belegbar —
   das Video fuehrt ~50-70/~60 als Community-Richtwert mit Quelle und Datum,
   nicht als offizielles Limit; die echte Doku/Changelog ist zu verifizieren.
2. Die Delegations-Doku ("does not accept a toolsets parameter") widerspricht
   dem laufenden Tool (`enabled_toolsets` exponiert) — als Doku-Veraltung
   fuehren; das Video zeigt den Widerspruch, korrigiert die Doku nicht.
3. Kein Anzeige-/Warnwerkzeug fuer die aktive Tool-Zahl und keine
   dokumentierte Grenze bestehen fort — als Anforderung benennen, kein Neubau.
4. Kausalitaet und Messwerte sind Selbstbericht ohne Kontrolle; extern nicht
   verifizierbar (eingefrorenes Korpus).
