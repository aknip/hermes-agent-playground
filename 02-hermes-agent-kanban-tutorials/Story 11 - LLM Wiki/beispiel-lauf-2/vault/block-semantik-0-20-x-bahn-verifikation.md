# Bahn VERIFIKATION — Item `block-semantik-0-20-x`

**Lane:** verifikation
**Datum des Befunds:** 2026-08-11
**Geprüft gegen:**
- offizielle Changelogs: `sources/releases/changelog-0.20.1.md` (2026-08-06), `changelog-0.20.2.md` (2026-08-09)
- Transkript (gemessene Demo): `sources/transcripts/2026-08-08-block-semantik.md`
- ITEM: `vault/block-semantik-0-20-x.md`
- **Eigenmessung** auf lokaler Installation: `hermes --version` → **Hermes Agent v0.20.0 (2026.8.3)**

Leseart je Aussage: `bestätigt` = durch offizielle Quelle und/oder lokale Messung belegt; `unbelegt` = keine belastbare Quelle; `widersprüchlich` = Quellen widersprechen sich oder widersprechen der Aussage.

---

## Herzstück: der KONFLIKT `--reason` (positional) vs. `--reason` (Flag)

### Seite (Stand der Wissensbasis — was da steht)
`wiki/pages/kanban-block-semantik.md`, Zeile 24 (nur 3 Befehle-Block):

```
hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"
```

- **version:** 0.19.0 · **updated:** 2026-06-02 · **status:** `aktuell`
- **Quelltyp (Seite):** dokumentierter Bestand der Wissensbasis, basierend auf
  `hermes-docs/kanban.md` (Stand 2026-06)
- Behauptet: `block` nimmt den Grund als `--reason`-**Flag hinter** dem `<id>`.

### Quellen (was die neue Information sagt)
1. **offizieller Changelog 0.20.1** (2026-08-06), Abschnitt „Kanban / CLI":
   > „`hermes kanban block` nahm den Grund bereits seit 0.20.0 **positional**;
   > die Dokumentation zeigte weiterhin `--reason`. Die Dokumentation ist
   > korrigiert."
2. **Transkript / gemessene Demo** 2026-08-08, Zeitmarke 00:03:12:
   > „Ich habe monatelang `hermes kanban block <id> --reason "…"` geschrieben,
   > weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl bricht mit
   > `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument:
   > `hermes kanban block <id> "brauche eine Entscheidung"`."
3. **EIGENMESSUNG** (dieser Befund, lokales Hermes v0.20.0):
   - `hermes kanban block --help` → `positional arguments: task_id, reason`
     (Reason ist positional); es gibt **keinen** `--reason`-Options-Eintrag.
   - `hermes kanban block 999 --reason "test"` →
     `hermes: error: unrecognized arguments: --reason test` ← exakt die im
     Transkript genannte Fehlermeldung.

### Gegenüberstellung

| Seite | | Changelog 0.20.1 / Transkript / Eigenmessung |
|---|---|---|
| `block <id> --reason "…"` | vs. | Grund ist **positional**: `block <id> "…"` |
| version 0.19.0 · Stand 2026-06 | | 0.20.0+ (seit 0.20.0 positional) · 2026-08 |
| Quelltyp: Wiki-Seite (Doku-Nachbau) | | Quelltyp: offizieller Changelog + gemessene Demo + **lokale CLI-Messung** |

### Folgerung
Die Seite zeigt eine **objektiv falsche Syntax**. Drei unabhängige Belege
(offizieller Changelog, gemessene Demo, lokale `--help`/Ausführungs-Test auf
v0.20.0) stimmen darin überein; die Seite trägt `status: aktuell`, ist aber
versionstechnisch (0.19.0) überholt. Das ist ein echter **Widerstreit** — die
Wissensbasis sagt das Gegenteil der verifizierten Realität.
**Aussage 1: `bestätigt` (Seite falsch).** Ein Falsifizieren dieser Aussage
wäre: ein funktionierendes `hermes kanban block <id> --reason "…"` auf
≥ 0.20.0 demonstrieren — ist nicht der Fall.

---

## Die fünf zu verifizierenden Aussagen

### 1. `block` nimmt den Grund positional; `--reason` existiert dort NICHT
- laeuft gegen: **offizielle Quelle + Messung** (Changelog 0.20.1; lokale
  `hermes kanban block --help` + Ausführungstest).
- **Markierung: `bestätigt`**. Lokal direkt beobachtet:
  `unrecognized arguments: --reason test`.
- Zusatz (wichtig, nicht widersprechend): Bei **`unblock` gibt es `--reason`
  sehr wohl** und legt den Text als Kommentar an die Karte, bevor diese nach
  `ready` geht (Changelog 0.20.1; Transkript 00:03:12; im Einklang mit der
  bestehenden Seite Zeilen 29–31). Die Seite verwechselt hier `block` und
  `unblock` in derselben Befehls-Box (Zeile 24 vs. Zeile 26).

### 2. `--kind` muss bei `block` VOR der Kartennummer stehen; dahinter bricht es ab
- laeuft gegen: **offizielle Quelle + Messung** (Changelog 0.20.1:
  „`--kind` muss **vor** der Kartennummer stehen"; Transkript 00:03:12).
- **Markierung: `bestätigt`**. Lokal direkt beobachtet (v0.20.0):
  - `block --kind needs_input 999 "r"` → parse OK, scheitert erst am
    Task-Lookup (`unknown task 999`) → Syntax akzeptiert.
  - `block 999 --kind needs_input "r"` → `unrecognized arguments: reason`
    → Syntax bricht ab.
- Falsifikation wäre: ein erfolgreicher `block <id> --kind …` auf ≥ 0.20.0.

### 3. `--initial-status blocked` setzt nur die Spalte, erzeugt KEIN `blocked`-Ereignis, ist kein Tor; Karte läuft bei Eltern-Fertigstellung durch
- laeuft gegen: **offizielle Quelle** (Changelog 0.20.1, Abschnitt „Kanban /
  Dispatcher": setzt die Spalte, kein `blocked`-Ereignis, kein Tor; nur echtes
  `block` bzw. `kanban_block()` hält) + **gemessene Demo** (Transkript
  00:08:45, 00:12:20: Dispatcher sieht in `recompute_ready` `todo` und
  `blocked`).
- **Markierung: `bestätigt`** (gegen offizielle Quelle + gemessenes Transkript;
  nicht lokal re-gemessen — würde vollständiges Board/Dispatcher-Setup
  erfordern).
- Alternative Sichtweise im Transkript, konsistent: „`--initial-status blocked`
  **parkt**, `block` hält" (00:12:20).

### 4. `--kind` ist eine Typangabe, keine Haltekraft; ein Block ohne `--kind` hält genauso
- laeuft gegen: **Messung** (Transkript 00:16:05: drei Ticks + `dispatch
  --dry-run` geprüft; „`--kind` ist eine Typangabe, keine Haltekraft") +
  **indirekt offizielle Quelle** (Changelog 0.20.1: „Nur ein echtes `block`
  bzw. `kanban_block()` hält" — nennt keinen `--kind` als Bedingung).
- **Markierung: `bestätigt`**. Kein Widerspruch in den Quellen.
- Einschränkung: Das Transkript belegt es als gemessene Demo, der Changelog
  bestätigt es nur implizit; nicht lokal re-gemessen.

### 5. Wiederholte Blockade mit derselben Block-Art nach `unblock` landet in der Triage statt in `blocked`; Ereignis `block_loop_detected`; Zähler pro Block-Art, nur bei erfolgreichem Abschluss zurückgesetzt
- laeuft gegen: **offizielle Quelle** (Changelog 0.20.2, Abschnitt „Kanban /
  Block-Schleifen": Triage statt `blocked`, Zähler `block_recurrences` je
  Block-Art, Reset **nur bei erfolgreichem Abschluss**, neues Ereignis
  `block_loop_detected` trägt Zähler und Grenze im Payload) + **gemessene
  Demo** (Transkript 00:19:40, 00:23:10) + **Bestätigung durch diese Pipeline
  selbst** (`ingest.yaml` Kopf-Kommentar, Zeilen 226–230: BLOCK_RECURRENCE_LIMIT
  = 2 je Art, wiederholte Blockade → Triage/Ereignis `block_loop_detected`).
- **Markierung: `bestätigt`** (gegen offizielle Quelle + gemessene Demo).
- Präzisierung gegenüber dem Item-Text: der Zähler heißt in der Quelle konkret
  `block_recurrences` (je Block-Art, Reset bei erfolgreichem Abschluss); das
  Item sagt nur „Zähler je Block-Art" — konsistent, aber der konkrete Name
  sollte bei einem Ingest mitgenommen werden.

---

## Zusammenfassung

| # | Aussage | Markierung | Gegen was geprüft |
|---|---|---|---|
| 1 | `block` positional, kein `--reason` (WIDERSPRUCH zur Seite Z.24) | **bestätigt** | Changelog 0.20.1 + Transkript 00:03:12 + **lokale Messung** |
| 2 | `--kind` vor der Kartennummer | **bestätigt** | Changelog 0.20.1 + **lokale Messung** |
| 3 | `--initial-status blocked` = Spalte, kein Ereignis, kein Tor | **bestätigt** | Changelog 0.20.1 + Transkript 00:08:45/00:12:20 |
| 4 | `--kind` = Typangabe, keine Haltekraft | **bestätigt** | Transkript 00:16:05 (Messung) + Changelog 0.20.1 implizit |
| 5 | Wiederholte Block-Art → Triage, `block_loop_detected`, Zähler je Art | **bestätigt** | Changelog 0.20.2 + Transkript 00:19:40/00:23:10 + ingest.yaml |

- **Keine Aussage ist `unbelegt` oder `widersprüchlich` intern** — die Quellen
  (offizieller Changelog 0.20.1/0.20.2 und das gemessene Transkript) sind unter
  sich **konsistent**.
- Der einzige Widerstreit ist **extern**: zwischen der **Wissensbasis**
  (`kanban-block-semantik.md`, 0.19.0, Zeile 24, `--reason`) und der
  **verifizierten Realität** (positional, 0.20.x). Die Seite ist die Seite mit
  dem Fehler.
- **Quellbelastbarkeit:** Rang „offizieller Changelog > gemessene Demo" —
  beide Quelltypen hier vorhanden und deckungsgleich; zusätzlich drei von fünf
  Aussagen (1, 2) lokal auf v0.20.0 **direkt nachgemessen**.
- **Zu entscheiden für die Route-Karte** (nicht meine Entscheidung, aber die
  Faktenlage): Der Konflikt in Zeile 24 ist real und durch Messung belegt →
  spricht für Route `konflikt` / Korrektur der Seite; die übrigen Punkte sind
  Ergänzungen derselben Seite (0.19.0 → 0.20.x, `status` müsste geprüft werden).

## Was die Aussagen falsifizieren würde
- Aussage 1/2: ein lauffähiges `block --reason …` bzw. `block <id> --kind …`
  auf Version ≥ 0.20.0. Nicht demonstrierbar (siehe Messung).
- Aussage 3–5: ein kontrollierter Lauf, in dem `--initial-status blocked` ein
  `blocked`-Ereignis erzeugt bzw. eine Karte hält, oder eine wiederholte
  Block-Art nach `unblock` in `blocked` statt Triage läuft. Kein solcher Befund
  in den Quellen; nicht lokal re-gemessen (aufwendiges Board-Setup).
