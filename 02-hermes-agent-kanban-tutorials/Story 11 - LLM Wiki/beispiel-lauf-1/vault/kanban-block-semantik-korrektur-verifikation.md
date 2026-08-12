# Verifikation — Item kanban-block-semantik-korrektur

Lane: verifikation
Gegenstand: vault/kanban-block-semantik-korrektur.md (Score 91, Status triage)
Quellen: sources/releases/changelog-0.20.1.md, sources/releases/changelog-0.20.2.md,
         sources/transcripts/2026-08-08-block-semantik.md
Geprüft gegen: lokal installiertes Hermes v0.20.0
              (~/.hermes/hermes-agent, `hermes --version` → v0.20.0)

Quellenstärke je Teilaussage notiert. Legende:
  OFF  = offizieller Changelog (höchste Stufe)
  DEMO = gemessene Live-Demo im Transkript
  MESS = selbst gegen die lokale Installation gemessen
Verdikt je Teilaussage: verifiziert / uneindeutig / widerlegt.

---

## 1. `hermes kanban block` nimmt den Grund POSITIONAL, `--reason` existiert dort NICHT

Quelle SAYS
- Transkript [00:03:12]: "Ich habe monatelang `hermes kanban block <id> --reason "…"`
  geschrieben, weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl bricht
  mit `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument:
  `hermes kanban block <id> "brauche eine Entscheidung"`."
- Changelog 0.20.1 (Abschnitt "Behoben: Kanban / CLI", Z. 16–18): "`hermes kanban block`
  nahm den Grund bereits seit 0.20.0 **positional**; die Dokumentation zeigte weiterhin
  `--reason`. Die Dokumentation ist korrigiert."

VERIFIED (MESS)
- `hermes kanban block --help` → `usage: hermes kanban block [-h] [--ids ...]
  [--kind {capability,dependency,needs_input,transient}] task_id [reason ...]`
  Positionals: `task_id`, `reason`. Kein `--reason` unter options.
- `hermes kanban block 999999 --reason test` →
  `hermes: error: unrecognized arguments: --reason test` (argparse bricht ab).
- Der Grund wird als letztes positional übergeben:
  `hermes kanban block 999999 "brauche eine Entscheidung"` liest fehlerfrei (bricht
  erst mit `kanban: unknown task 999999` ab — d.h. Syntax akzeptiert).

Sprechend für Widerlegung: ein `--reason`, das auf `block` akzeptiert würde
(argparse ohne `unrecognized arguments`-Fehler).

Verdikt: **verifiziert** (OFF + DEMO + MESS dreifach belegt).

---

## 2. `--kind` muss VOR der Kartennummer stehen

Quelle SAYS
- Transkript [00:03:12]: "…muss `--kind` **vor** die Kartennummer:
  `hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"`.
  Andersherum bricht es ebenfalls ab."
- Changelog 0.20.1 (Z. 18): "`--kind` muss **vor** der Kartennummer stehen."

VERIFIED (MESS)
- `hermes kanban block --kind needs_input 999999 "brauche entscheidung"` (kind vor id) →
  parst fehlerfrei, bricht nur mit `kanban: unknown task 999999` ab.
- `hermes kanban block 999999 --kind needs_input "x"` (kind hinter id) →
  `hermes: error: unrecognized arguments: x` (bricht ab). Genau wie behauptet
  ("Andersherum bricht es ebenfalls ab").

Sprechend für Widerlegung: `block <id> --kind needs_input <reason>` liefe ohne
argparse-Fehler durch.

Verdikt: **verifiziert** (OFF + MESS; DEMO bestätigt die gleiche Richtung).

---

## 3. Bei `unblock` existiert `--reason` und legt den Text als Kommentar an; Karte geht nach ready

Quelle SAYS
- Transkript [00:03:12]: "Bei `unblock` gibt es `--reason` sehr wohl, und dort ist es
  genau das, was man für ein Tor braucht: der Text wird als Kommentar an die Karte
  gelegt, und die Karte geht danach nach `ready`."
- Changelog 0.20.1 (Z. 19–20): "Bei `unblock` gibt es `--reason` weiterhin, und dort
  legt es den Text als Kommentar an die Karte, bevor sie nach `ready` geht."

VERIFIED (MESS, teilweise)
- `hermes kanban unblock --help` → `--reason REASON  Optional reason/note — recorded
  as a comment before unblocking.` — Existenz von `--reason` und die
  Kommentar-Mechanik sind direkt belegt.
- Der Schritt "Karte geht danach nach `ready`" ist ein Seiteneffekt auf eine reale
  Karte und wurde bewusst nicht mit einer echten Karte ausgelöst (kein
  Kartenzustand geändert). Er ist durch Changelog (OFF) + Help-Doku belegt.

Sprechend für Widerlegung: Ein `unblock`-Lauf, der nach der Kommentarreihung nicht
nach `ready` ginge (z.B. wieder in `blocked` bliebe).

Verdikt: **verifiziert**.

---

## 4. `--initial-status blocked` setzt die Spalte, erzeugt aber kein `blocked`-Ereignis; `recompute_ready` befördert `todo` UND `blocked`

Quelle SAYS
- Transkript [00:08:45]: "…`--initial-status blocked` setzt die **Spalte**, es erzeugt
  aber kein `blocked`-**Ereignis** — und der Dispatcher schaut sich in
  `recompute_ready` `todo` **und** `blocked` an. Liegen bleibt nur eine Karte, deren
  jüngstes Ereignis ein echtes `blocked` ist."
- Changelog 0.20.1 (Z. 9–14): "`recompute_ready` beförderte Karten mit
  `--initial-status blocked` mit, sobald deren Eltern fertig waren… dokumentiert ist
  nun ausdrücklich, dass `--initial-status blocked` die Spalte setzt, aber **kein**
  `blocked`-Ereignis erzeugt, und deshalb kein Tor ist."

VERIFIED (OFF + DEMO; MESS nur teilweise)
- `hermes kanban create --help` → `--initial-status {blocked,running}` existiert und
  beschreibt: "Skip the brief running-to-blocked transition" — d.h. `blocked` ist
  eine initiale Spalte, nicht ein Block-Ereignis.
- Das "kein blocked-Ereignis" und das `recompute_ready`-Verhalten (todo UND blocked)
  sind Dispatcher-Interna; am CLI ohne echte Karte nicht abbildbar. Belegt durch
  Changelog (OFF) + Transkript (DEMO), zwei übereinstimmende Quellen.

Sprechend für Widerlegung: Eine `--initial-status blocked`-Karte, deren jüngstes
Ereignis `blocked` wäre bzw. die nach Elternfertigstellung haften bliebe — der
Changelog sagt explizit das Gegenteil (Verhalten als unverändert dokumentiert).

Verdikt: **verifiziert**.

---

## 5. Haltekraft ist unabhängig von der Block-Art; ein Block ohne `--kind` hält genauso

Quelle SAYS
- Transkript [00:16:05]: "Was den Block hält, ist übrigens nicht die Block-Art. Ein
  Block ohne `--kind` hält genauso — ich habe das drei Ticks lang und mit
  `dispatch --dry-run` geprüft. `--kind` ist eine **Typangabe**, keine Haltekraft."
- Changelog: schweigt zu dieser Teilaussage explizit; Changelog 0.20.1 stützt nur
  "nur ein echtes `block` bzw. `kanban_block()` hält".

VERIFIED (DEMO, teilweise MESS)
- MESS: `--kind` ist im CLI optional — `hermes kanban block --help`: "…`--kind`
  {capability,…}. … Omit for a generic block." `hermes kanban block 999999
  "brauche entscheidung"` (ohne --kind) parst fehlerfrei → generischer Block ist
  regulär möglich.
- Die Haltekraft-Gleichheit ("hält genauso") ist nur über einen realen, mehrere Ticks
  laufenden Block beobachtbar; wurde hier nicht nachgestellt. Belegt durch
  Transkript (DEMO, mit messmethodischer Angabe: drei Ticks + `dispatch --dry-run`).
  Keine Quelle widerspricht; keine Widerlegung gefunden.

Sprechend für Widerlegung: Eine Wartekarte, die nur mit `--kind` tatsächlich in
`blocked` gehalten würde und ohne `--kind` durchliefe.

Verdikt: **verifiziert** (auf DEMO-Stärke; Changelog schweigt, keine Gegenaussage).

---

## 6. Zweiter Block nach unblock mit derselben Art → Triage statt blocked; Ereignis `block_loop_detected`; Zähler `block_recurrences` je Art, nur bei Erfolg zurückgesetzt (0.20.2)

Quelle SAYS
- Changelog 0.20.2 (Z. 9–15): "Eine Karte, die nach einem `unblock` erneut mit
  **derselben** Block-Art blockiert wird, landet in der Triage statt in `blocked`.
  Der Zähler dafür (`block_recurrences`) wird pro Block-Art geführt und **nur bei
  erfolgreichem Abschluss** zurückgesetzt. Neu ist, dass das ausgelöste Ereignis
  `block_loop_detected` heißt und Zähler und Grenze im Payload trägt; vorher war es
  ein gewöhnliches `blocked`-Ereignis und der Wechsel in die Triage war von außen
  nicht erkennbar."
- Transkript [00:19:40]: "Zweiter Block, dieselbe Block-Art — und die Karte landet in
  der **Triage**, nicht in `blocked`. Das ist die Schleifenerkennung: nach einem
  `unblock` zählt Hermes einen erneuten Block mit derselben Art als Schleife und
  eskaliert."
- Transkript [00:23:10] (Empfehlung, konsistent): "…die zweite Blockade bekommt eine
  **andere** Block-Art — dann hält sie."

Untergliederung:
- 6a Zweiter Block mit derselben Art → Triage statt blocked:
  VERIFIED (OFF changelog-0.20.2 + DEMO [00:19:40]). Auch die lokale v0.20.0-CLI-Hilfe
  von `block` erwähnt bereits: "Repeated same-kind re-blocks after unblock route the
  task to triage to break unblock loops."
- 6b Ereignisname `block_loop_detected` und Payload (Zähler + Grenze):
  VERIFIED NUR gegen changelog-0.20.2.md (OFF, Z. 13–14). Das Transkript (veröffentlicht
  2026-08-08) nennt den Ereignisnamen nicht — plausibel, weil `block_loop_detected` laut
  Changelog als neu in 0.20.2 (2026-08-09) eingeführt wurde. Die lokale Installation
  ist v0.20.0 und kann 0.20.2-Details deshalb nicht bestätigen/widerlegen. Kein
  widerlegender Befund.
- 6c Zähler `block_recurrences` pro Art, nur bei erfolgreichem Abschluss zurückgesetzt:
  VERIFIED NUR gegen changelog-0.20.2.md (OFF, Z. 11–12). Keine Gegenquelle.

Konsistenzhinweis (kein Widerspruch): Das Transkript (0.20.1-Ära) beschreibt den
sichtbaren Effekt (Karte hängt in Triage); der Changelog 0.20.2 präzisiert, dass der
Wechsel zuvor "von außen nicht erkennbar" war (gewöhnliches `blocked`-Ereignis) und
erst 0.20.2 das Ereignis `block_loop_detected` sichtbar macht. Beides ist vereinbar:
der Effekt (Triage) bestand schon, die Sichtbarkeit des Ereignisses ist neu.

Sprechend für Widerlegung: (a) Ein zweiter same-kind-Block, der in `blocked` statt
Triage landete; (b) ein 0.20.2-Run, der ein anderes als `block_loop_detected`-Ereignis
auslöste; (c) ein `block_recurrences`-Zähler, der nicht pro Art geführt bzw. nicht
nur bei Erfolg zurückgesetzt würde.

Verdikt: **verifiziert** (6a OFF+DEMO; 6b, 6c OFF — höchste Quellenstufe, lokal
nicht gegenprüfbar, da Installation v0.20.0).

---

## Zusammenfassung

| # | Teilaussage | Verdikt | Führende Quelle |
|---|-------------|---------|-----------------|
| 1 | Grund positional, `--reason` existiert nicht (block) | verifiziert | OFF + DEMO + MESS |
| 2 | `--kind` muss vor der Kartennummer | verifiziert | OFF + MESS |
| 3 | unblock hat `--reason` → Kommentar, Karte nach ready | verifiziert | OFF + DEMO + MESS(teil) |
| 4 | `--initial-status blocked` = Spalte, kein Ereignis; recompute_ready (todo+blocked) | verifiziert | OFF + DEMO |
| 5 | Haltekraft unabhängig von Block-Art | verifiziert | DEMO (Changelog schweigt) |
| 6 | Same-kind-Re-Block → Triage; `block_loop_detected`; `block_recurrences` je Art, Reset nur bei Erfolg | verifiziert | 6a OFF+DEMO, 6b/c OFF |

Keine der sechs Teilaussagen konnte widerlegt werden. Die einzigen
Einschränkungen sind Quellenstufen, keine Gegenbefunde: #5 stützt sich auf die
gemessene Demo (Changelog schweigt); #6b/#6c stützen sich allein auf den offiziellen
Changelog 0.20.2, weil lokal v0.20.0 installiert ist und das Transkript der
0.20.1-Ära entstammt.
