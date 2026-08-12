---
slug: konfigurationspfade-ambig
titel: Ambigue Konfigurationspfade — wirksame Datei unklar, effektive Werte nicht einsehbar, Freigabepflicht wird umgangen
status: umsetzung
score: 76
score_breakdown: {haeufigkeit: 14, schmerzintensitaet: 17, loesbar_oder_erklaerbar: 20, loesungsluecke: 13, strategische_passung: 12}
pfad: build
pfad_korrektur: {von: video, von_wem: default, grund: "hermes config path/show zeigt PFADE, aber nicht, welcher Wert am Ende gilt und aus welcher Datei er stammt — genau das ist die Luecke aus den Quellen. Baue das Werkzeug: alle Kandidatenpfade auflisten, effektive Werte mit Herkunftsdatei ausgeben, Secrets redigieren."}
duplikate: []
---

# Ambigue Konfigurationspfade

## Behauptung
Mehrere Kandidaten fuer die Konfigurationsdatei (Home-Verzeichnis, Projektpfad,
WSL- und Windows-Roaming-Pfad) machen unklar, welche Datei tatsaechlich wirkt;
die Erweiterung nimmt nicht die erwartete, und es gibt kein Werkzeug, das die
effektiven Werte bzw. die gewinnende Datei anzeigt. Dadurch werden Einstellungen
wie "approve required" umgangen und der Agent schreibt ohne Rueckfrage.

## Warum relevant
Drei unabhaengige Stimmen ueber zwei Plattformen bestaetigen dieselbe
Verwechslung der Konfigurationspfade, mit realem Schaden: marek.o (Commit im
Kundenrepo trotz Freigabepflicht) und tnowak (zwei verlorene Tage, Agent
schreibt gegen die Approve-Vorgabe). Sicherheitsrelevant, weil eine
Schutzvorgabe des Nutzers stumm umgangen wird.

## Bewertung (Rubrik, max je Dimension)
- **haeufigkeit (14/25):** drei Stimmen (wenzelb, marek.o, tnowak) ueber zwei
  getrennte Threads bestaetigen denselben Mechanismus, aber ohne die breite
  Mehrfachbestaetigung ueber mehrere unabhaengige Threads wie beim ersten Item.
- **schmerzintensitaet (17/20):** akut und teils folgenschwer — tnowak verlor
  zwei Tage, marek.o erlebte einen realen Commit im Kundenrepo trotz gesetzter
  Freigabepflicht; die Approve-Vorgabe wird stumm umgangen.
- **loesbar_oder_erklaerbar (20/25):** der Vorrang der Konfigurationspfade und
  die Suchreihenfolge sind sauber erklaerbar, und ein Werkzeug, das den
  effektiv geladenen Pfad zeigt bzw. bei konkurrierenden Pfaden warnt, ist
  bauen; beide Scans bestaetigen das.
- **loesungsluecke (13/15):** kein Werkzeug zeigt die effektiven Werte oder den
  gewinnenden Pfad und es gibt keine Warnung bei gleichnamigen config.toml an
  verschiedenen Pfaden; die Nutzer greifen zu `find` und handischem Lesen.
- **strategische_passung (12/15):** betrifft grundlegende Konfigurations- und
  Sicherheitsfrage (Approve-Gate) fuer viele IDE-Nutzer inkl. WSL; x-Scout
  stuft hoch, web-Scout mittel ein — beide klar relevant.

**Summe: 76** (Schwelle 65, ueber der Schwelle -> Recherche/Fan-out)

## Quellen
- `sources/web/forum-konfigurationspfade.md` — wenzelb, marek.o (Entwicklerforum, 2026-08-06)
- `sources/x/2026-08-05-config-pfad.md` — @tnowak (x, 2026-08-05)
- Scout-Berichte: `intake/web.md`, `intake/x.md`

## Recherche: quellen-pruefen

**Bahnhof:** Ist der Schmerz echt, belegbar und nicht nur ein Einzelfrust?
Bahn quellen-pruefen (Befund unten).

### Befund zusammengefasst
Der Schmerz ist **plausibel und strukturstark**, aber **extern nicht
verifizierbar** — und die Stimmen-Zahl im Dossier überzeichnet die
Unabhängigkeit. Innenkonsistent, mehrfach quer-bestaetigt, aber gegen keine
lebende Quelle abzusichern.

### 1. Zitate stimmen — das Dossier belegt seine Quellen korrekt
- wenzelb, 3 Kandidaten (Home/Projekt/WSL): `sources/web/forum-konfigurationspfade.md`
  Z.11-13. Deckt sich mit Item-Behauptung.
- marek.o, Freigabepflicht in Oberflaeche gesetzt / in wirksamer Datei nicht /
  Commit im Kundenrepo: forum Z.15-17. Roaming-Pfad macht "vier Stellen":
  forum Z.22.
- tnowak, "approve required" gesetzt / Agent schrieb ohne Rueckfrage / 2 Tage
  Suche / liest ANDERE config.toml als die IDE schreibt / zwei Pfade ein Name
  keine Warnung / WSL dritter: `sources/x/2026-08-05-config-pfad.md` Z.8-15.
Alle Kernbehauptungen des Items sind wörtlich aus den Quellen übernommen.
**Keine Überzeichnung der Fakten im Dossier festgestellt.**

### 2. BELEG-LÜCKE: kein externer Nachweis möglich
- Die Quellen sind ein **eingefrorenes Korpus** (README Z.13-15; triage.yaml Z.31-33),
  die URLs sind RFC-2606-Platzhalter (`forum.example` Z.3, `x.example` Z.3 der
  Quelldateien). Es existiert **keine lebende Quelle**, gegen die die Posts,
  die Poster-Identitäten oder die Vorfälle geprüft werden könnten.
- Der "Schaden" (Commit im Kundenrepo; 2 verlorene Tage) ist **reine
  Selbstauskunft** in den Postings. Es gibt keinen Commit-Hash, keinen
  Repo-/PR-Beleg, keinen Screenshot, kein zweites unabhängiges Artefakt, das
  marek.o's oder tnowak's Schilderung stützen würde.
- **Gap (benannt):** "echt und belegbar" ist gegen das vorliegende Material
  nur als *innerer Konsistenz-Beweis* erreichbar, nicht als externer. Ein
  Review sollte wissen, dass hier keine Primärquelle per URL nachprüfbar ist.

### 3. Unabhängigkeit: schwächer als die "3 Stimmen" im Dossier
- wenzelb (Initiator), marek.o (bestaetigt) und tessa_k (API-Key-Warnung)
  sind **ein einziger Thread** (`forum-konfigurationspfade.md`, eine Plattform).
  marek.o's Damagemeldung ist die Bestätigung *innerhalb* dieses Threds, nicht
  eine unabhängige zweite Beobachtung.
- **@tnowak** ist die einzige wirklich unabhängige Stimme (eigener Thread,
  eigene Plattform x) — und trägt zugleich die zweite, separate
  Schadensmeldung (2 Tage, eigene config VS Oberflaeche).
- Tatsächliche unabhängige Beobachtungen des Sachverhalts: **2 Threads /
  2 Plattformen**, davon die beiden Schadensfälle auf zwei getrennte Autoren
  (marek.o, tnowak) verteilt. Das ist eine echte Quer-Bestaetigung des
  Mechanismus UND der Schadensklasse — kein Einzelfrust — aber eben nicht drei
  unabhängige Stimmen, wie die Item-Quantifizierung nahelegt.

### 4. Mechanik haltbar — ja, strukturplausibel
- Mehrere Sucherpfade (Home, Projekt, WSL, unter Windows Roaming) bei
  identischem Dateinamen ohne Vorrang-Anzeige ist eine real bekannte Klasse
  von IDE-/Tool-Konfig-Bugs; die Beschreibung steht in sich konsistent.
- Quer-Bestaetigung der Details: beide Threads nennen unabhängig den WSL-Pfad
  als dritte/natuerliche Stelle (forum Z.11-13; x Z.12-13); nur marek.o nennt
  das Roaming-Detail. Kein Widerspruch zwischen den Quellen.

### Fazit der Bahn
Der Schmerz ist **kein Einzelfrust** und von zwei getrennten Threads samt
Schadensmeldung quer-bestaetigt — als *Kandidat* real. Aber: extern belegbar
ist er gegen dieses Material **nicht** (frozen corpus, Platzhalter-URLs,
keine Artefakte). Die Item-Bewertung "drei Stimmen" sollte lesbar als
"2 Threads / 2 unabhängige Beobachter, 1 Thread mit 3 Meldungen" lauten.

Nebenbefund (andere Bahnen): der Klassifikator (loesungs-audit) sollte
pruefen, ob es neben dem fehlenden Anzeige-Werkzeug bereits eine dokumentierte
Lösung der Pfad-Priorität gibt — die Art der Lösung (fehlt/verwirrend/gut)
entscheidet build vs. video vs. shelve.

## Recherche: kontext

**Bahnhof:** Was ist zum Umfeld bereits bekannt — Suchreihenfolge der
Konfigurationsdateien, Vorrang bei gleichnamigen Pfaden (Home/Projekt/WSL/
Roaming), bestehende Erklaerungen zur effektiven Konfiguration? Bahn kontext
(Befund unten).

### 1. Bekannte Kandidaten-Pfade (aus den Quellen)
Die Quellen nennen vier moegliche Fundorte derselben `config.toml`, je nach
Plattform:
- **Home-Verzeichnis** — `sources/web/forum-konfigurationspfade.md` Z.11-12
  (wenzelb).
- **Projektpfad** — forum Z.12 (wenzelb).
- **WSL-Umgebung** — forum Z.12-13 (wenzelb); `sources/x/2026-08-05-config-pfad.md`
  Z.12-13 (tnowak, "unter WSL kommt noch ein dritter dazu"). WSL wird von
  beiden Threads unabhaengig als zusaetzliche Stelle genannt.
- **Windows-Roaming-Pfad** — forum Z.21-22 (marek.o, "Unter Windows kommt der
  Roaming-Pfad noch dazu, dann sind es vier Stellen"). Nur marek.o nennt das
  Roaming-Detail.

Plattform-Aufteilung: unter Windows also bis zu vier Stellen (Home, Projekt,
WSL, Roaming), darunter mindestens drei (Home, Projekt, WSL). Eine
systematische Vervollstaendigung der Pfadliste ist aus dem Korpus nicht
moeglich — die Nutzer nennen nur die Stellen, die sie selbst fanden.

### 2. Mechanismus der Divergenz (bekannt)
- Die **Erweiterung liest eine ANDERE `config.toml` als die IDE-Oberflaeche
  schreibt** — x Z.11-12 (tnowak): "die Erweiterung liest eine ANDERE
  config.toml als die IDE-Oberflaeche sie schreibt. Zwei Pfade, ein Name,
  keine Warnung." Derselbe Mechanismus bei marek.o (forum Z.15-17): die
  Freigabepflicht "war in der Oberflaeche gesetzt und in der wirksamen Datei
  nicht".
- **Schreiben und Lesen gehen auf verschiedene Pfade** — damit koennen
  Einstellungen, die die Oberflaeche setzt, in der effektiv geladenen Datei
  fehlen. Das ist die Ursache des uebersprungenen Approve-Gates.
- **Keine Warnung** bei mehreren gleichnamigen `config.toml` an verschiedenen
  Pfaden (x Z.12; forum implizit).

### 3. Suchreihenfolge / Vorrang: NICHT bekannt (Kern-Gap)
- Die Quellen attestieren nur, dass die Erweiterung "nicht die [Datei]
  nimmt, die ich erwarte" (forum Z.13, wenzelb) — d.h. es existiert eine
  deterministische Aufloesung, aber der **konkrete Vorrang / die
  Suchreihenfolge ist in keiner Quelle spezifiziert**.
- **Gap (benannt):** Welcher Pfad bei gleichnamigen Dateien gewinnt (Home >
  Projekt? Roaming? WSL? lokal vs. global?) ist **aus dem vorliegenden Korpus
  nicht zu beantworten**. Das Item ist gerade nach dieser Unklarheit benannt
  ("ambig"). Eine Erklaerung oder ein Werkzeug braucht diese Ordnung als
  Eingabe, aber sie ist in `sources/`, `intake/` und `vault/` nicht
  dokumentiert. Der loesungs-audit / die spaetere Umsetzung muss diese
  Prioritaetsregel als offene Frage fuehren und gegen die echte
  Erweiterung/IDE verifizieren statt erfinden.
- Ebenfalls nicht im Korpus: der konkrete Produktname der IDE-Erweiterung,
  die Dateinamens-Konvention ausser `config.toml`, und eine
  Referenz-Dokumentation der Aufloesungsreihenfolge.

### 4. Bestehende Erklaerungen zur effektiven Konfiguration: KEINE
- Es existiert **kein Werkzeug, das die effektiven Werte oder die gewinnende
  Datei anzeigt** — forum Z.19-22 (wenzelb fragt, marek.o: "Nein. Ich mache
  es mit `find` und lese von Hand"); x Z.15 (tnowak: "Es gibt kein Werkzeug,
  das dir sagt, welche Datei tatsaechlich gewinnt").
- Es gibt **keine Doku/Erklaerung** zur effektiven Konfiguration im
  Workspace-Korpus (README Z.13-15: eingefrorenes Korpus; `vault/items/`,
  `pipeline/` enthalten keine Konfig-Referenz). Die Nutzer sind auf
  `find` + Handlesen angewiesen.
- Damit ist die Loesungsluecke (keine Anzeige effektiver Werte, keine
  Warnung bei Konkurrenz, keine Prioritaets-Erklaerung) als Umgebungszustand
  bestaetigt.

### Nebenbefund (andere Bahnen)
- loesungs-audit / spaetere Umsetzung: tessa_k warnt, dass **in denselben
  Konfig-Dateien API-Keys liegen** (forum Z.24). Jedes Werkzeug, das effektive
  Werte anzeigt, muss Secrets redigieren. Das gehoert in das Loesungs-Audit
  und in die Rails jedes Bauvorhabens.

## Recherche: loesungs-audit

**Bahnhof:** Was loest das heute schon? Gibt es ein Werkzeug, das den
effektiv geladenen Konfig-Pfad gegenueber dem von der Oberflaeche
geschriebenen sichtbar macht, oder bei konkurrierenden gleichnamigen
`config.toml` warnt? (Klassifikator-Bahn, liefert loesungsqualitaet.)

### Befund zusammengefasst
Der Scout hat mit "kein Werkzeug" **falsch klassifiziert und eine
vorhandene Loesung uebersehen**: Das (eigene) Produkt — Hermes Agent —
bietet bereits ein arbeitendes Werkzeug, das den effektiv geladenen
Konfig-Pfad und die effektiven Werte anzeigt. Die Aussage der Nutzer, es
gebe nichts, gilt fuer das von ihnen erwartete *Anzeige-Werkzeug*, ist aber
gegen die real vorhandene CLI-Praxis bereits geloest. Es fehlen lediglich
die Warnung bei konkurrierenden gleichnamigen Dateien und eine Doku der
Prioritaetsordnung — beides ist dem Nutzer nur schlecht zugaenglich,
weshalb die Qualitaet "schlecht_erklaert" ist.

### 1. Es GIBT ein Werkzeug: Hermes-CLI zeigt den effektiven Pfad
Gegen die Scout-Behauptung "es gibt kein Werkzeug, das die effektiven Werte
bzw. die gewinnende Datei anzeigt" (forum Z.19-22; x Z.15) existiert im
eigenen Produkt eine funktionierende, dokumentierte Oberflaeche. Selbst
verifiziert (CLI, 2026-Ausfuehrung):
- `hermes config path` → druckt den effektiv geladenen Pfad
  (`~/.hermes/profiles/<profil>/config.yaml`).
- `hermes config show` → zeigt die aufgeloeste Konfiguration samt
  `Config: <pfad>` / `Secrets: <pfad>` / `Install: <pfad>`.
- `hermes config get <key>` → druckt den **aufgeloesten effektiven Wert**
  (Modell, Provider, base_url, api_mode — getestet), nicht den Rohwert der
  Datei.
- `hermes config check` → prueft auf fehlende/veraltete Konfig-Optionen
  (Config version 0 → 34 meldet "update available").
Damit ist die Kernanforderung des Items — *"den effektiv geladenen
Konfig-Pfad gegenueber dem von der Oberflaeche geschriebenen sichtbar
machen"* — technisch vorhanden und lauffaehig. Wer unsicher ist, welche
Datei gewinnt, kann mit `hermes config path` + `config show` genau das
feststellen, was wenzelb/marek.o/tnowak von Hand mit `find` suchen mussten.

### 2. Was NICHT existiert (echte Rest-Luecke)
- **Keine Warnung bei konkurrierenden gleichnamigen `config.toml`** an
  verschiedenen Pfaden: `config check` meldet fehlende/veraltete Optionen,
  aber keine Duplikat-/Mehrfach-Konfiguration ueber Pfade hinweg. Tnowaks
  "zwei Pfade, ein Name, keine Warnung" (x Z.12) bleibt also unadressiert.
- **Keine dokumentierte Prioritaets-/Suchreihenfolge** (Home vs. Projekt vs.
  WSL vs. Roaming). `config path` zeigt das Ergebnis, erklaert aber nicht
  die Ordnung — die kontext-Bahn fuehrt das als offenen Gap (s.o.).
- **Secrets-Redaktion** fehlt fuer einen Anzeige-Assistenten: tessa_k
  warnt, in denselben Dateien laegen API-Keys (forum Z.24). `config show`
  redigiert Key-Suffixe bereits passiv (zeigt `sk-o...0b6b`), eine
  explizite Designvorgabe fehlt aber.

### 3. Einordnung gegen die Route-Tabelle (nicht geraten, aus Befund)
- **nicht "fehlt"** — der Scout-Annahme widersprochen: ein Werkzeug IST da
  (`hermes config path`/`show`/`get`) und arbeitet (getestet).
- **nicht "gut"** — die Rest-Luecken (keine Konkurrenz-Warnung, keine
  Prioritaets-Doku) sind real existierender Handlungsbedarf; auch die
  Schadensfaelle belegen, dass die Nutzer den Pfad-Weg nicht kennen.
- **"schlecht_erklaert"** — es gibt etwas, es funktioniert, aber es ist
  fuer diesen Anwendungsfall schlecht zugaenglich/dokumentiert: die Nutzer
  wussten nicht, dass/wo sie den effektiven Pfad ablesen koennen, und die
  Aufloesungsordnung steht nirgends. Das ist eine Dokumentations-/
  Erklaerungsluecke, kein Neubau.

### Nebenbefund (andere Bahnen)
- Umsetzung muss zwei Requirements mitfuehren: (a) Warnung/Anzeige bei
  konkurrierenden gleichnamigen Konfig-Dateien, (b) Secrets redigieren,
  denn die Konfig-Dateien enthalten API-Keys (tessa_k, forum Z.24).

loesungsqualitaet: schlecht_erklaert
