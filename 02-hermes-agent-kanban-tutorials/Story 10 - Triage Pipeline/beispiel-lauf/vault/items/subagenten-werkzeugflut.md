---
slug: subagenten-werkzeugflut
titel: Sub-Agenten waehlen Werkzeuge falsch (oder gar keins), sobald zu viele Werkzeuge/MCP-Server im Kontext liegen
status: umsetzung
score: 85
score_breakdown: {haeufigkeit: 22, schmerzintensitaet: 16, loesbar_oder_erklaerbar: 22, loesungsluecke: 11, strategische_passung: 14}
pfad: video
duplikate: []
---

# Sub-Agenten-Werkzeugflut

## Behauptung
Ab einer Schwelle von zu vielen aktivierten MCP-Servern bzw. zu vielen
Werkzeugbeschreibungen im Kontext faellt die Trefferquote der Werkzeugwahl von
Sub-Agenten stark ab (oder sie greifen gar keins), waehrend der Haupt-Agent
nichts merkt. Es gibt keine dokumentierte Grenze.

## Warum relevant
8 unabhaengige Stimmen ueber 3 getrennte Threads/Plattformen (Reddit 4,
YouTube 3, X 1) bestaetigen denselben Fehlermechanismus. kd_rasmus liefert
gemessene Zahlen: 40 Werkzeuge -> 9/10 Laeufe gut, 80 Werkzeuge -> 3/10;
Schwelle "zwischen 50 und 70 Werkzeugen". mkirsch_dev nennt "ab ~60
Werkzeugen" bei drei verlorenen Stunden. Mehrfach im Team wochenlang aktiv.

## Bewertung (Rubrik, max je Dimension)
- **haeufigkeit (22/25):** acht unabhaengige Stimmen in drei getrennten
  Threads auf Reddit, YouTube und X ueber Wiederkehr "seit Wochen" und
  "dasselbe im Team" belegen ein haeufig wiederkehrendes Problem.
- **schmerzintensitaet (16/20):** akut blockierender Schmerz — mkirsch
  verbrannte drei Stunden und ein Ablauf war kaputt, kd_rasmus misst einen
  Einbruch der Erfolgsquote von 9/10 auf 3/10, Teams wochenlang betroffen.
- **loesbar_oder_erklaerbar (22/25):** Ursache (Kontextueberfluss durch zu
  viele Werkzeugbeschreibungen) und Abhilfe (Allow-List je Sub-Agent) sind
  von mehreren Stimmen klar benannt und als Anleitung erklaerbar bzw. als
  Empfehlung bauen.
- **loesungsluecke (11/15):** eine funktionierende Loesung existiert bereits
  (pro Sub-Agent Allow-List), aber sie ist nirgends dokumentiert — nur in
  einem Changelog-Eintrag von vor vier Monaten, und der Konfigurationsschluessel
  heisst nicht erwartbar; die Dokumentationsluecke ist ungefuellt.
- **strategische_passung (14/15):** mehrfach bestaetigtes, messbares Problem
  mit direktem Bezug zu einem Publikum, das mit Agenten/Multi-Agent-Setups
  arbeitet.

**Summe: 85** (Schwelle 65, ueber der Schwelle -> Recherche/Fan-out)

## Quellen
- `sources/web/reddit-subagenten-werkzeugflut.md` — u/halbmond, u/kd_rasmus, u/aniela.p (r/aiagents, 2026-08-04)
- `sources/web/youtube-kommentare-agenten-werkzeuge.md` — @renkoe, @ilvahn (YouTube, 2026-08-07)
- `sources/x/2026-08-03-subagenten-mcp.md` — @mkirsch_dev (x, 2026-08-03)
- Scout-Berichte: `intake/web.md`, `intake/x.md`

## Recherche: kontext

**Bahnhof:** Was ist zum Umfeld bereits bekannt — Werkzeugwahl-Verhalten von
Agenten bei Kontextueberfluss, Schwelle/kein dokumentiertes Tool-Limit,
MCP-Handling in Doku/Changelog/Community? Bahn kontext (Befund unten).

### 1. Gemeinsame Schwelle ueber die Stimmen (aus dem Korpus)
Die Community nennt konsistent eine Tool-Anzahl-Schwelle, jenseits derer die
Werkzeugwahl von (Sub-)Agenten kippt — nicht ein MCP-Server-Zaehler, sondern
die Zahl der *Werkzeugbeschreibungen im Kontext* ist der wirksame Faktor:
- `sources/web/reddit-subagenten-werkzeugflut.md` Z.15-16 (kd_rasmus): "kippt
  es zwischen 50 und 70 Werkzeugen … 40 Werkzeuge -> 9 von 10 Laeufe gut,
  80 Werkzeuge -> 3 von 10."
- `sources/x/2026-08-03-subagenten-mcp.md` Z.12-13 (mkirsch_dev): "Ab
  ungefaehr 60 Werkzeugen im Kontext kippt es."
- MCP-Server-Zahlen als Ausloeser (dieselben Stimmen, andere Metrik):
  halbmond "mehr als vier MCP-Server" (reddit Z.11-12), ilvahn "als ich auf
  sieben hoch bin" / renkoe "Neun" (youtube Z.15-18), mkirsch "sechs
  MCP-Server" (x Z.11-12).
- Konvergenz: ~50-70 (kd_rasmus), ~60 (mkirsch) Werkzeuge; 4-7+ MCP-Server.
  Ein konkreter, widerspruchsfreier Richtwert ergibt sich ueber die Stimmen
  hinweg.

### 2. Mechanismus (bekannt, mehrfach bestaetigt)
- **Haupt-Agent merkt nichts / kommt klar, Sub-Agenten kippen** — reddit
  Z.12-13 (halbmond), x Z.13 (mkirsch), youtube Z.12-13 (renkoe vs. ilvahn).
  Der Haupt-Agent haelt bei derselben Tool-Menge die Trefferquote, die
  Sub-/untergeordneten Agenten nicht.
- **Symptom-Variante: falsches Werkzeug ODER gar keins** — x Z.9-10
  (mkirsch: "stumpf das falsche Werkzeug gegriffen oder gar keins").
- **Fehlannahme der Betroffenen: erst Modell verdaechtigt** — reddit Z.19-20
  (aniela.p: "Wir dachten erst, es liegt am Modell").

### 3. Doku/Changelog zur Werkzeugwahl unter Kontextueberfluss: KEIN Limit
- Im Workspace-Korpus (`sources/`, `intake/`, `vault/`, `pipeline/`) existiert
  **keine Dokumentation eines Tool-Anzahl-Limits oder einer
  Selektions-Schwelle** (README Z.13-15: eingefrorenes Korpus; kein
  Changelog, keine Referenz in `pipeline/`). Das deckt sich mit mkirsch:
  "Niemand sagt dir das. In keiner Doku steht eine Zahl." (x Z.15).
- **Gap (benannt):** Im vorliegenden Material ist keine offizielle
  Schwellen-Dokumentation (weder Doku noch Changelog) auffindbar, die das
  Item-Zitat "Changelog-Eintrag von vor vier Monaten" wuerde. Die
  Changelog-Quelle, auf die halbmond sich bezieht (reddit Z.22-23), ist im
  Korpus nicht enthalten — sie muss fuer die Loesungs-Audit-Bahn/reale
  Verifikation gegen die echte Produkt-Changelog geprueft werden statt aus dem
  Korpus belegt zu werden.

### 4. Dokumentiertes MCP-Handling der Referenzumgebung (Hermes, Doku-Seite)
Die Produkt-Doku (die Umgebung, auf der diese Pipeline laeuft) *hat* ein
dokumentiertes Tool-Filter-/Limit-Modell, das der Community-Abhilfe (Allow-List
je Sub-Agent) sehr nahe kommt:
- **Per-Server-Filterung statt globalem Limit** — MCP-Doku, Abschnitt
  "Per-server filtering": `tools.include` (Whitelist), `tools.exclude`
  (Blacklist), `enabled: false` (Server ganz aus), fnmatch-Globs fuer grosse
  Flaechen (Cloudflare-Beispiel ~3.300 Tools). "What happens if everything is
  filtered out" -> kein leerer Toolset (Tool-Liste bleibt sauber). Die
  Referenz empfiehlt explizit: "start filtering immediately", "Prefer
  allowlists for dangerous systems".
- **Tool-Auswahl bei Installzeit** — MCP-Doku "Tool selection at install
  time": Hermes listet alle Server-Tools und schreibt nur die angehakten in
  `tools.include`; "If you select everything, no filter is written."
- **Tool-Naming/Namespace** — `mcp__<server>__<tool>`, Namens-Sanitisierung;
  dynamische Tool-Discovery; pro Server ergibt sich ein `mcp-<server>`
  Toolset. Das dokumentierte Mittel gegen Tool-Flut ist also **per-Server
  Reduktion**, nicht ein Anzeige-/Monitoring-Werkzeug der aktiven Tool-Zahl.
- **Vergleich zur Community-Schwelle:** Die Doku nennt **keine konkrete Zahl**
  (kein "bei N Tools kippt es"), begruendet Filterung mit Sicherheit und
  Tool-Listen-Sauberkeit, nicht mit Selektionsgenauigkeit. Der
  Missbrauchs-Schmerz ("Sub-Agent waehlt falsch") ist in der Doku nicht als
  Begruendung fuer Filterung formuliert.

### 5. Sub-Agenten/Delegation: Tool-Vererbung, KEINE per-Subagent-Allow-List
- Delegations-Doku ("Inherited Tool Access"): Sub-Agenten **erben die
  Toolsets des Parent**; `delegate_task` nimmt **keinen** toolset-Parameter;
  Child-blockierte Tools (clarify, memory, send_message) werden entfernt,
  `execute_code` bleibt. Es gibt also **kein dokumentiertes
  per-aufgabe/per-Subagent-Allow-List-Konstrukt** in der Delegation — die
  Community-Abhilfe "pro Sub-Agent nur seine sechs Werkzeuge" (reddit Z.21-22)
  ist im Referenzprodukt nur indirekt ueber Parent-Toolset-Scoping bzw.
  MCP-Server-Filter umsetzbar, nicht als dokumentiertes Delegations-Feature.
- **Gap (benannt):** Wie ein Sub-Agent auf eine *reduzierte* Teilmenge der
  Parent-Werkzeuge beschraenkt wird, ist in der Doku nicht explizit
  als Anleitung beschrieben; es gibt kein Tool, das die aktuell aktive
  Tool-Zahl im Kontext anzeigt (vgl. Item-Behauptung "Es gibt keine
  dokumentierte Grenze").

### Nebenbefund (andere Bahnen)
- loesungs-audit / Umsetzung: Die Referenzumgebung hat bereits ein
  dokumentiertes Filter-Modell (`tools.include`/`exclude`, per-Server), das
  die Community-Abhilfe technisch abbildet — aber der Konfigurationsschluessel
  heisst `tools.include` (nicht erwartbar, deckt sich mit kd_rasmus'
  "Konfigurationsschluessel heisst nicht so, wie man ihn suchen wuerde",
  reddit Z.25-26). Audit sollte pruefen, ob eine existierende Loesung
  "schlecht_erklaert/verwirrend" (-> video) oder "fehlt" (-> build) ist.
- Kontext-Bahn: kein zusaetzliches Monitoring der aktiven Tool-Zahl
  dokumentiert; ein Erklaerungs-/Video-Beitrag muesste die Schwelle (~50-70)
  und das per-Server-Filtermodell gegen die echte Doku verifizieren.
## Recherche: quellen-pruefen

### Urteil
Die Behauptung ist als wiederkehrendes, quellenuebergreifend belegtes Phaenomen
haltbar — **nicht als bewiesenes Kausalgesetz**. Der Schmerz ist echt und
mehrfach bestaetigt (kein Einzelfrust), aber er stuetzt sich auf
selbstberichtete Messung ohne Methodik und auf ein synthetisches, nicht
extern verifizierbares Korpus.

### Verifikation der Quellen (intern gegen das eingefrorene Korpus)
- **Reddit r/aiagents 2026-08-04** (`sources/web/reddit-subagenten-werkzeugflut.md`,
  uralt-frontmatter `stimmen: 4`): Vorhanden, Inhalt stimmt mit dem
  Item-Zitat ueberein. kd_rasmus-Zahlen „40 Werkzeuge -> 9 von 10 Laeufe gut,
  80 Werkzeuge -> 3 von 10" und Schwelle „zwischen 50 und 70 Werkzeugen" sind
  wörtlich korrekt zitiert.
- **YouTube 2026-08-07** (`sources/web/youtube-kommentare-agenten-werkzeuge.md`,
  frontmatter `stimmen: 3`): Vorhanden, aber es sind nur **2 distinkte
  Kommentatoren** (@renkoe, @ilvahn) mit 4 Posts — „stimmen: 3" ist falsch
  gegenueber den tatsaechlich genannten Personen. Tritt-Frequenz nicht
  nachpruefbar (ein „Agent Setup 2026"-Video).
- **X 2026-08-03** (`sources/x/2026-08-03-subagenten-mcp.md`, @mkirsch_dev):
  Vorhanden, Zitat „ab ungefaehr 60 Werkzeugen" korrekt. **Eine einzige Stimme.**

### Zahlenpruefung (40->9/10, 80->3/10; 50-70 bzw. ~60)
- kd_rasmus: `40 -> 9/10`, `80 -> 3/10`, Schwelle „50 bis 70" — direkt belegt,
  keine Divergenz zum Item.
- mkirsch_dev: „ab ungefaehr 60" — konsistent mit dem 50-70-Band von kd_rasmus
  (60 liegt mittendrin). Zwei unabhaeangige Schwellenangaben stimmen ueberein.
- **Luecke:** kd_rasmus' Messung liefert kein N, keine Laufdefinition, keine
  Modell-/Promptangabe; „9 von 10" / „3 von 10" sind Selbstbericht, nicht
  kontrolliert. Die Reihenfolge (40 besser als 80) ist plausibel und passt zur
  Schwelle, aber nicht beweisbar.
- MCP-Server-Zahlen der Erzaehler (halbmond „>4", ilvahn „7", mkirsch „6 in der
  Woche davor") sind eine anderes Mass als Werkzeugzahl und roh kohaerent (~
  4-7), aber kein Beleg fuer den genauen Kipppunkt.

### Konsistenz der Stimmenzahl (Diskrepanz)
Das Item nennt „8 unabhaengige Stimmen (Reddit 4, YouTube 3, X 1)" und
`haeufigkeit 22/25`. Gezaelt werden dabei **Posts, nicht Personen**: distinkte
Individuen sind Reddit 3 (halbmond, kd_rasmus, aniela.p) + YouTube 2 (renkoe,
ilvahn) + X 1 (mkirsch) = **6 Personen, nicht 8**. halbmond/renkoe/ilvahn
sprechen je doppelt. Auch `intake/web.md` weicht intern ab („Sieben Stimmen
(Reddit 4, YouTube 3)"). **Befund:** Stimmenzahl ist ueberzogen; bei 6
Personen ueber 3 Plattformen bleibt die Mehrfachbestaetigung aber tragfaehig.

### Mechanismus-Haltbarkeit
- Konsistent ueber alle drei Quellen: **Sub-Agent** waehlt falsches/kein
  Werkzeug, **Haupt-Agent** laeuft mit denselben Werkzeugen problemlos
  (halbmond, mkirsch, renkoe). Kausalzuordnung „zu viele Werkzeugbeschreibungen
  im Kontext" nennt ilvahn explizit und deckt sich mit den anderen.
- Hebel (Allow-List je Sub-Agent) wird von halbmond und ilvahn unabhaengig
  bestaetigt. „Keine Zahl in der Doku" wird von halbmond und mkirsch
  unabhaengig beklagt.
- Einschraenkung: Es fehlt ein Kontrollexperiment (dieselbe Sub-Agent-Aufgabe
  ohne/mit wenigen Tools), das die Versagensursache Isoliert haette. Der
  Bericht stuft das als erklaerbar ein, was die Belege zulassen.

### Fazit
- Echt und belegbar: **ja**, mehrfach bestaetigt ueber 3 Plattformen und 6
  Personen; kein Einzelfrust.
- Zahlen intern konsistent und quellenuebergreifend deckungsgleich (~60 ∈
  [50,70]), aber ohne Methodik/N — als Richtwert tragbar, nicht als Messwert.
- Behauptung „zu viele Tools/MCP im Kontext verschlechtert die Werkzeugwahl
  von Sub-Agenten" ist **haltbar als wiederkehrendes Muster**; nur als
  kausaler Befund ist sie nicht beweisbar.
- **Gap (extern):** Quelle-URLs sind `.example`-Platzhalter in einem
  eingefrorenen Korpus; eine echte Plattform-Verifikation (echtes Reddit/YT/X)
  ist nicht moeglich. Alle Aussagen sind nur intern gegensteuerbar.

### Nebenbefund (andere Bahn)
Trittfrequenz/Zaehlung („8 Stimmen" vs. 6 Personen, YouTube „3" vs. 2)
betrifft die Bewertungsdimension `haeufigkeit` (22/25) und koennte bei
Neuvergabe auf ~20/25 fallen — Kategorie Korrektur in der Rubrik-Bahn.

## Bahn: loesungs-audit

Audit gegenueber dem aktuellen Hermes-Stand (Docs v0.20.0, 2026-08-11;
Doku: hermes-agent.nousresearch.com/docs — autoritativ fuer das Tool).

### Was loest es heute schon?

1. **Allow-List auf der MCP-Seite existiert und ist DOKUMENTIERT.** Die
   MCP-Feature-Doku ("Per-server filtering", docs .../features/mcp) und die
   mcp-config-reference dokumentieren pro Server `mcp_servers.<name>.tools.include`
   und `tools.exclude` samt Semantik (include gewinnt vor exclude; Glob-Unterstuetzung;
   Filtern aller Tools fuehrt zu keiner leeren-Runtime-Menge). Das ist genau die
   Allow-List, die die 4 Reddit/YouTube-Stimmen beschreiben — und sie steht heute
   klar in der Doku, nicht nur im Changelog. Damit ist der urspruengliche Kern der
   "Doku-Luecke" (nur Changelog von vor 4 Monaten) fuer den MCP-Fall inzwischen GEFUELLT.

2. **Auf der Sub-Agent-Seite ist die Allow-List NICHT als solche dokumentiert —
   und die Doku widerspricht dem laufenden Tool.** Die Delegation-Doku
   ("Subagent Delegation", Abschnitt "Inherited Tool Access") sagt wörtlich:
   "delegate_task does not accept a model-facing toolsets parameter. Each subagent
   inherits the parent's enabled toolsets." Tatsaechlich EXPONIERT das aktuelle
   Tool-Schema von `delegate_task` einen `enabled_toolsets`-Parameter (ebenso
   `cronjob.enabled_toolsets`). Das ist eine falsche/veraltete Aussage in der Doku:
   ein Nutzer, der den Sub-Agent-Werkzeugumfang per Allow-List begrenzen will, wird
   von der offiziellen Doku aktiv in die Irre gefuehrt ("gibt es nicht").

3. **Keine dokumentierte Grenze, kein Werkzeug fuer die Tool-Anzahl.** Nirgends in
   der Doku steht ein Werkzeug-Schwellwert (mkirsch/kd_rasmus nennen ~50-70 bzw.
   ~60). Der MCP-Abschnitt "Current limits" betrifft nur den eingebetteten
   `hermes mcp serve` (stdio-only), keine Tool-Anzahl. Es gibt kein Tool, das die
   aktuelle Tool-Anzahl pro Sub-Agent im Kontext anzeigt oder ueber eine Schwelle
   warnt. Die von den Quellen benannte Luecke "in keiner Doku steht eine Zahl"
   besteht unveraendert fort.

### Bewertung

- Kernmechanismus (Allow-List) vorhanden und fuer MCP gut belegt + dokumentiert.
- Sub-Agent-spezifische Begrenzung: Funktion im Tool vorhanden, aber Doku behauptet
  das Gegenteil (delegation, "Inherited Tool Access") -> nicht auffindbar/erklaert.
- Kein dokumentierter Schwellwert, kein Anzeige-/Warnwerkzeug.

Zwischenfazit: "es gibt etwas" (Allow-List, teils gut dokumentiert), aber die fuer
den Sub-Agent-Fall entscheidende Begrenzung ist mies/selbstwiderspruechlich
dokumentiert und eine dokumentierte Grenze fehlt ganz.

Nebenbefund (nicht meine Bahn): Delegation-Doku "does not accept a toolsets
parameter" wirkt veraltet gegenueber dem laufenden Tool (exponiert enabled_toolsets);
gehoert an die Kontext-/Quellen-Bahn, um als Doku-Veraltung gefuehrt zu werden.

loesungsqualitaet: schlecht_erklaert
