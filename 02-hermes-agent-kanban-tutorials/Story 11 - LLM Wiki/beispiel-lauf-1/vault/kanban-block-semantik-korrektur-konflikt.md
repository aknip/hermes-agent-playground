# KONFLIKT-DOSSIER · kanban-block-semantik-korrektur

Item: `vault/kanban-block-semantik-korrektur.md` · Route: **konflikt**
Lane: konflikt-dossier · Datum: 2026-08-11 · Bearbeiter: kb-researcher
Vorgänger-Bahnen: `…-verifikation.md` (alle 6 Teilaussagen verifiziert),
`…-seitenabgleich.md` (wissensstand: widerspruch).

Dieses Dossier stellt die widersprüchlichen Aussagen gegeneinander und macht
die Entscheidung für einen Menschen billig. Es entscheidet **nicht** selbst.

Konvention überall: **QUELLE** = was die Quelle sagt · **VERIFIZIERT** = was
ich selbst gelesen / am CLI ausgeführt habe · **INFERENZ** = Schluss, den ich
ziehe.

---

## 1. Der Widerspruch in einem Satz

Die Wissensbasis dokumentiert eine `block`-Syntax (`--reason`), die es am CLI
**nicht** gibt und die mit `unrecognized arguments` abbricht; die Quelle (und
die lokale v0.20.0-Installation) belegen, dass der Grund **positional** ist
und `--kind` **vor** der Kartennummer stehen muss.

---

## 2. Die beiden widersprüchlichen Aussagen, wörtlich

### 2a. Was die Wissensbasis sagt (die zu korrigierende Seite)

Datei `wiki/pages/kanban-block-semantik.md`, Abschnitt „Die drei Befehle",
**Z. 24**:

```
hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"
```

- Fundstelle: `wiki/pages/kanban-block-semantik.md`, Z. 24
- Frontmatter: `updated: 2026-06-02` · `version: 0.19.0` · `status: aktuell`
- Bezugsquelle laut Frontmatter: `hermes-docs/kanban.md`

Die Zeile behauptet damit dreierlei, von dem der Befund (2b) das Gegenteil
belegt:
1. dass `block` einen Flag `--reason` hat (→ existiert nicht, Grund ist positional),
2. dass Flags hinter der Kartennummer stehen können (→ `--kind` muss **davor**),
3. als Folge: dass diese Syntax ein gültiger Tor-Aufruf ist (→ bricht ab).

### 2b. Was die Quelle belegt

**CHANGELOG 0.20.1** — `sources/releases/changelog-0.20.1.md`, Abschnitt
„Behoben", Z. 16–18 (Changelog veröffentlicht **2026-08-06**, Bezug 0.20.0):

> „`hermes kanban block` nahm den Grund bereits seit 0.20.0 **positional**; die
> Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist korrigiert.
> `--kind` muss **vor** der Kartennummer stehen."

**TRANSCRIPT 2026-08-08** — `sources/transcripts/2026-08-08-block-semantik.md`,
[00:03:12] (veröffentlicht **2026-08-08**, Bezug 0.20.0 / 0.20.1):

> „Ich habe monatelang `hermes kanban block <id> --reason "…"` geschrieben,
> weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl bricht mit
> `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument:
> `hermes kanban block <id> "brauche eine Entscheidung"`. Und wenn ihr eine
> Block-Art angeben wollt, muss `--kind` **vor** die Kartennummer:
> `hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"`.
> Andersherum bricht es ebenfalls ab."

Korrekte Form laut Quelle:

```
hermes kanban block <id> "brauche eine Entscheidung"
hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"
```

### 2c. VERIFIZIERT — gegen die lokale Installation (Hermes v0.20.0)

Ort: `~/.hermes/hermes-agent`, `hermes --version` → v0.20.0.
Alle Befehle am 2026-08-11 hier ausgeführt.

- `hermes kanban block --help` →
  `usage: hermes kanban block [-h] [--ids IDS [...]] [--kind {capability,dependency,needs_input,transient}] task_id [reason ...]`
  — `task_id` und `reason` sind **positionale** Argumente; unter `options` steht
  **kein** `--reason`.
- Syntax der Wissensbasis:
  `hermes kanban block 999999 --reason test` →
  `hermes: error: unrecognized arguments: --reason test` (argparse bricht ab).
- Syntax der Quelle (kind vor id, Grund positional):
  `hermes kanban block --kind needs_input 999999 "brauche eine Entscheidung"` →
  `kanban: unknown task 999999` — parst fehlerfrei; der Abbruch ist erst die
  (hier erwartete) Task-Prüfung. Syntax ist akzeptiert.
- `--kind` hinter die ID gestellt:
  `hermes kanban block 999999 --kind needs_input "x"` →
  `hermes: error: unrecognized arguments: x` (bricht ab, wie die Quelle sagt:
  „Andersherum bricht es ebenfalls ab").

INFERENZ: Die Seite (Z. 24) dokumentiert exakt die Syntax, die die Quelle für
nicht existent erklärt und die am CLI real mit `unrecognized arguments`
abbricht. Ein Worker, der die Seite befolgt, blockiert seine Karte nie und
hängt — der praktische Schaden, den der Seiten-Abgleich (F1) beschreibt, ist
plausibel.

---

## 3. Ergänzungs-Befunde (F2–F5) — KEINE Widersprüche, muss der Ingest mit abdecken

Diese vier Befunde stammen aus der Seiten-Abgleich-Bahn und der Verifikation.
Die Seite widerspricht ihnen **nicht**; sie schweigt (F2–F4) oder deckt sie
nur teilweise ab (F5). Sie gehören in dasselbe Ingest-Paket, ändern aber die
Klassifikation nicht (bleibt `widerspruch` wegen 2a/2b).

### F2 · `--kind` muss VOR der Kartennummer — FEHLT
QUELLE: changelog-0.20.1 Z. 18 („`--kind` muss **vor** der Kartennummer
stehen"); Transkript [00:03:12] (Z. 22–27, Beispiel + „Andersherum bricht es
ebenfalls ab").
SEITE: Block-Arten-Tabelle (Z. 35–40) listet die `--kind`-Werte, aber keine
Reihenfolgeregel; die einzige Befehlszeile (Z. 24) steht ohnehin falsch.
VERIFIZIERT: siehe 2c — `--kind` vor id parst, hinter id bricht ab.
INFERENZ: Reihenfolge-Vorgabe fehlt auf der Seite vollständig.

### F3 · `--initial-status blocked` setzt die Spalte, ist aber KEIN Tor — FEHLT
QUELLE: changelog-0.20.1 Z. 9–14 (recompute_ready beförderte `--initial-status
blocked`-Karten mit; dokumentiert: Spalte ja, **kein** `blocked`-Ereignis,
„deshalb kein Tor. Nur ein echtes `block` bzw. `kanban_block()` hält");
Transkript [00:08:45] + Merksatz [00:12:20]: „`--initial-status blocked` parkt,
`block` hält."
SEITE: erwähnt `initial-status` an keiner Stelle (search_files: 0 Treffer).
VERIFIZIERT: `hermes kanban create --help` → `--initial-status {blocked,running}`
„Skip the brief running-to-blocked transition".
INFERENZ: der volle „parken ≠ halten"-Befund fehlt; kein Widerspruch, nur Lücke.

### F4 · Haltekraft unabhängig von der Block-Art; `--kind` ist Typangabe — FEHLT
QUELLE: Transkript [00:16:05] („Was den Block hält, ist übrigens nicht die
Block-Art. Ein Block **ohne** `--kind` hält genauso … `--kind` ist eine
**Typangabe**, keine Haltekraft."); changelog-0.20.1 Z. 16–17 implizit
(`--kind` optional).
SEITE: Z. 35–40 beschreibt die `--kind`-Bedeutungen, sagt aber nichts dazu,
dass ein Block ohne `--kind` genauso hält.
VERIFIZIERT: `hermes kanban block 999999 "brauche entscheidung"` (ohne `--kind`)
parst fehlerfrei; `block --help` → „Omit for a generic block."
INFERENZ: „Art = Typ, nicht Haltekraft" fehlt; die Seite wirbt nicht gegen die
Fehllesung „ohne `--kind` hält nicht".

### F5 · Schleifenerkennung: Triage-Ubergang steht, Ereignis-Detail fehlt — UNVOLLSTÄNDIG
QUELLE: changelog-0.20.2 Z. 9–15 (same-kind-Re-Block nach `unblock` → Triage;
das ausgelöste Ereignis heißt jetzt `block_loop_detected` und trägt Zähler +
Grenze im Payload; Zähler `block_recurrences` pro Art, **nur bei Erfolg**
zurückgesetzt; vorher gewöhnliches `blocked`-Ereignis, Triage-Wechsel von außen
nicht erkennbar).
SEITE: Z. 48–52 deckt den Triage-Ubergang und das „derselbe Art"-Kriterium
korrekt ab, nennt aber weder den Ereignisnamen `block_loop_detected` noch
Payload (Zähler + Grenze), noch Zählerführung pro Art, noch Reset-nur-bei-Erfolg.
VERIFIZIERT: `block --help` der lokalen v0.20.0 nennt bereits „Repeated
same-kind re-blocks after unblock route the task to triage to break unblock
loops."; die 0.20.2-Details (Ereignisname/Payload) sind lokal (v0.20.0) nicht
gegenprüfbar — OFF-Quelle, Changelog 0.20.2 vom **2026-08-09**.
INFERENZ: Kern stimmt; das Diagnose-Detail des 0.20.2-Befunds fehlt → hier
unvollständig, **nicht** widersprüchlich.

---

## 4. Wie sich der Konflikt prüfen lässt (entscheidet die Frage in einer Minute)

Das Entscheidende ist **nicht** der Doku-Stand, sondern das Verhalten des
realen CLI. Beide Befehle unten sind auf einer Hermes-Installation (getestet
auf v0.20.0) ausführbar; `999999` ist eine garantiert nicht existierende Karte,
so dass **keine** echte Karte verändert wird.

**Befehl A — zeigt die tatsächliche Signatur:**
```
hermes kanban block --help
```
- **erwartet, wenn die QUELLE recht hat:** unter `positional arguments` stehen
  `task_id` und `reason`; unter `options` gibt es **kein** `--reason`. → genau
  das beobachte ich (siehe 2c).
- **erwartet, wenn die WISSENSBASIS recht hat:** unter `options` stünde ein
  `--reason REASON`.

**Befehl B — führt die von der Seite dokumentierte Syntax aus:**
```
hermes kanban block 999999 --reason test
```
- **erwartet, wenn die QUELLE recht hat:** bricht ab mit
  `hermes: error: unrecognized arguments: --reason test`. → genau das beobachte
  ich (siehe 2c).
- **erwartet, wenn die WISSENSBASIS recht hat:** läuft bis zur Task-Prüfung
  durch und meldet `kanban: unknown task 999999` (Syntax akzeptiert).

**Befehl C (Ergänzung, stützt 2b):** `--kind` Positionsregel:
```
hermes kanban block --kind needs_input 999999 "test"   # vor id  → akzeptiert
hermes kanban block 999999 --kind needs_input "test"   # nach id → unrecognized arguments
```
- Quelle recht hat: erste Zeile läuft bis `unknown task`, zweite bricht ab.
  → genau das beobachte ich.

Der Test entscheidet eindeutig zugunsten der Quelle: Der Widerspruch ist real,
die Seite (Z. 24) dokumentiert eine Syntax, die nicht existiert.

---

## 5. Was der Ingest täte (Vorbereitung für Vorschlag + Tor 1)

Nur die Folgestufe (Vorschlag + Tor 1) entscheidet; hier nur die erwartete
Ingest-Form, damit die Folgestufe daraus einen Vorschlag bauen kann.

1. **ERSETZEN (nicht ergänzen)** der falschen Aussage in
   `wiki/pages/kanban-block-semantik.md` Z. 24:
   - falsch: `hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"`
   - richtig: `hermes kanban block   <id> "brauche eine Entscheidung von dir"`
     und, für den Typfall: `hermes kanban block --kind needs_input <id> "…"`
2. **Nachziehen** des Frontmatters:
   - `updated: 2026-06-02` → `2026-08-11`
   - `version: 0.19.0` → `0.20.2` (die Seite deckt ab jetzt 0.20.2-Detail ab)
   - `sources:` ergänzen um `releases/changelog-0.20.1.md`,
     `releases/changelog-0.20.2.md`, `transcripts/2026-08-08-block-semantik.md`
     (neben dem bestehenden `hermes-docs/kanban.md`)
   - `status: aktuell` bleibt (die Seite wird durch die Korrektur gültiger, nicht
     veraltet).
3. **Ergänzen** der fehlenden/teilweisen Befunde am selben Ort der Seite:
   - F2: Regelsatz, dass `--kind` **vor** der Kartennummer stehen muss.
   - F3: `--initial-status blocked` setzt die **Spalte**, erzeugt **kein**
     `blocked`-Ereignis und ist **kein Tor** (Merksatz: „parkt ≠ hält").
   - F4: Haltekraft ist unabhängig von der Block-Art; `--kind` ist eine
     Typangabe („Omit for a generic block"); ein Block ohne `--kind` hält genauso.
   - F5: ergänzen, dass das ausgelöste Ereignis `block_loop_detected` heißt und
     Zähler (`block_recurrences`, pro Art, nur bei Erfolg zurückgesetzt) + Grenze
     im Payload trägt (0.20.2).
   - F5-Hinweis für Betreiber (aus changelog-0.20.2): zwei menschliche Tore auf
     **derselben** Karte brauchen unterschiedliche Block-Arten, sonst Triage.

Passt die Seite so nicht unter die 120-Zeilen-Grenze des Lints, ist der F5-Teil
(kandidat für Auslagerung) gesondert zu prüfen — eine Design-Entscheidung der
Folgestufe, nicht dieses Dossiers.

---

## 6. Falsifizierbarkeit / Abschluss des Dossiers

- Der Widerspruch (2a vs. 2b) ist **falsifizierbar** durch Test B: wäre
  `block <id> --reason …` am CLI akzeptiert, hätte die Seite recht. Das
  beobachte ich **nicht** (2c).
- Die Ergänzungen (F2–F4) sind falsifizierbar durch die jeweiligen
  „Sprechend für Widerlegung"-Befunde in `…-verifikation.md` (dort Teilaussagen
  2, 4, 5). F5 (0.20.2-Detail) ist vor Ort mangels 0.20.2-Installation nicht
  gegenprüfbar, aber durch den offiziellen Changelog 0.20.2 gedeckt; keine
  Gegenquelle.

wissensstand: widerspruch
