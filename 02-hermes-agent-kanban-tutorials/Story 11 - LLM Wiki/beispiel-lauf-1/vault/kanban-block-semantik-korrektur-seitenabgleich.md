# SEITEN-ABGLEICH · kanban-block-semantik-korrektur

Item: `vault/kanban-block-semantik-korrektur.md` · Bahn: seiten-abgleich · Datum: 2026-08-11
Triage-Bezug: `kanban-block-semantik`

## Betroffene Seite

- `wiki/pages/kanban-block-semantik.md` (slug `kanban-block-semantik`, `updated: 2026-06-02`,
  `version: 0.19.0`, `status: aktuell`) — **die einzige Seite, die die Block-Befehle, `--kind`,
  Unblock- und Schleifen-Semantik dokumentiert.**

Weitere Seiten, geprueft, betroffen nur indirekt (kein Widerspruch, kein eigener Inhalt):
- `wiki/pages/kanban-board.md` Zeile 36: `blocked` verlinkt nur auf `[[kanban-block-semantik]]`.
- `wiki/pages/gateway-und-dispatcher.md` Zeile 35: ``Promoted`` zaehlt Karten aus `todo`
  (und `blocked`) — konsistent mit der Quelle, traegt aber keine neue Aussage zum Blocken.

---

## Befunde gegen die Verifikation (Verifikations-Bahn t_15fd404a-korrekturbefund)

Konvention: **QUELLE** = was die Quelle sagt · **VERIFIZIERT** = was ich selbst gelesen / am
CLI ausgefuehrt habe · **INFERENZ** = Schluss, den ich ziehe.

### F1 — `block` hat keinen Flag `--reason`; der Grund ist positional. **WIDERSPRUCH.**

QUELLE
- `sources/releases/changelog-0.20.1.md` Z.16–18: „`hermes kanban block` nahm den Grund
  bereits seit 0.20.0 **positional**; die Dokumentation zeigte weiterhin `--reason`. Die
  Dokumentation ist korrigiert."
- `sources/transcripts/2026-08-08-block-semantik.md` Z.13–21: „`hermes kanban block <id> --reason
  "…"` … Das gibt es **nicht**. Der Befehl bricht mit `unrecognized arguments` ab. Der Grund ist
  ein **positionales** Argument: `hermes kanban block <id> "brauche eine Entscheidung"`."

SEITE — Z.24: `hermes kanban block   <id> --reason "brauche eine Entscheidung von dir"`

VERIFIZIERT
- Seitenzeile 24 wörtlich gelesen: dokumentiert genau die Syntax, die die Quelle fuer nicht
  existent erklaert.
- Live-CLI auf diesem Rechner: `hermes kanban block --help` zeigt **kein** `--reason`.
  Signature: `block [-h] [--ids …] [--kind …] task_id [reason …]` — `reason` ist **positional**.

INFERENZ: Eine Karte, die per `--reason` blockiert, beabsichtigt, bricht mit
`unrecognized arguments` ab, und die Wissensbasis haelt die Karten in `blocked`, wo der
Worker haengt. Die Seite sagt hier etwas ANDERES als die geregelte Realitaet.

### F2 — `--kind` muss VOR die Kartennummer; Reihenfolge nicht dokumentiert. **FEHLT.**

QUELLE
- `changelog-0.20.1.md` Z.18: „`--kind` muss **vor** der Kartennummer stehen."
- `2026-08-08-block-semantik.md` Z.26: `hermes kanban block --kind needs_input <id> "…"`,
  Z.27: „Andersherum bricht es ebenfalls ab."

SEITE — Z.24 zeigt `block <id> --reason …` (Flag nach der ID, und zusaetzlich falsches Flag).
Die Block-Arten-Tabelle (Z.35–40) listet `--kind`-Werte, aber **keine** Reihenfolgeregel.

VERIFIZIERT: Im CLI-Help sind `task_id` und `reason` positional und folgen den Optionen;
`--kind` ist eine Option vor der Kartennummer. Die Seite dokumentiert diese Regel nirgends.

INFERENZ: Die Reihenfolge-Vorgabe `--kind <id>` fehlt; die einzige Befehlszeile auf der Seite
violiert sie (fuehrt aber wegen F1 sowieso ab).

### F3 — `--initial-status blocked` setzt die Spalte, ist aber KEIN Tor. **FEHLT.**

QUELLE
- `changelog-0.20.1.md` Z.9–14: „`--initial-status blocked` setzt die **Spalte**, aber **kein**
  `blocked`-**Ereignis** … und deshalb kein Tor. Nur ein echtes `block` bzw. `kanban_block()`
  haelt."
- `2026-08-08-block-semantik.md` Z.33–42 (Merksatz Z.41: „`--initial-status blocked` **parkt**,
  `block` **haelt**.").

SEITE: erwaehnt `initial-status` an keiner Stelle.

VERIFIZIERT: `search_files` nach `initial-status` ueber `wiki/pages/` — 0 Treffer in der
Seite; die Seite hat keinen Absatz, der die Spalte-vs.-Ereignis-Semantikfalle erklaert.

INFERENZ: Der volle Befund (parken ≠ halten) fehlt. Kein Widerspruch — die Seite behauptet
nirgends, dass `--initial-status blocked` haelt; sie schweigt nur dazu.

### F4 — Haltekraft unabhaengig von der Art; `--kind` ist Typangabe. **FEHLT.**

QUELLE
- `2026-08-08-block-semantik.md` Z.44–48: „Was den Block haelt, ist uebrigens nicht die
  Block-Art. Ein Block **ohne** `--kind` haelt genauso — … `--kind` ist eine **Typangabe**,
  keine Haltekraft."
- `changelog-0.20.1.md` Z.16–17 implizit: Grund positional, `--kind` optional.

SEITE: Block-Arten-Tabelle (Z.35–40) beschreibt die `--kind`-Werte mit ihrer Bedeutung,
sagt aber nichts dazu, dass ein Block ohne `--kind` genauso haelt, und nichts zur
Haltekraft-unabhaengig-von-Art.

VERIFIZIERT: CLI-Help Z.„Omit for a generic block" — bestaetigt: `--kind` weglassen ergibt
einen generischen (weiterhin haltenden) Block.

INFERENZ: Die Aussage „Art ist Typ, nicht Haltekraft" fehlt. Die Seite widerspricht ihr
nicht, aber sie wirbt auch nicht gegen die Fehllesung „ohne `--kind` haelt nicht".

### F5 — Schleifenerkennung: Triage-Uebergang steht, Ereignisdetail `block_loop_detected` fehlt. **UNVOLLSTAENDIG.**

QUELLE
- `changelog-0.20.2.md` Z.9–15: erneuter Block mit **derselben** Art nach `unblock` -> Triage;
  das ausgeloeste Ereignis heisst jetzt `block_loop_detected` und traegt Zaehler und Grenze im
  Payload (vorher gewoehnliches `blocked`-Ereignis, Triage-Wechsel von aussen nicht erkennbar);
  Zaehler `block_recurrences` pro Art, **nur bei erfolgreichem Abschluss** zurueckgesetzt.

SEITE — Z.48–52: „Wird eine Karte nach einem `unblock` erneut mit derselben Block-Art
blockiert, routet Hermes sie in die Triage statt nach `blocked`. Das bricht Endlosschleifen
aus Blockieren und Entblocken auf."

VERIFIZIERT: Seitenabschnitt Z.48–52 wörtlich gelesen; er deckt den Triage-Uebergang und
das „derselbe Art"-Kriterium korrekt ab. Das Ereignis `block_loop_detected`, der Payload
(Zaehler + Grenze), die Zaehlerfuehrung pro Art und das Reset-nur-bei-Erfolg stehen **nicht**
auf der Seite.

INFERENZ: Der Kern (Triage statt blocked) ist da und stimmt; die Diagnose/_Detail_ des
0.20.2-Befunds fehlt. Auf dieser Teilfrage ist die Seite unvollstaendig, nicht widerspruechlich.

---

## Gesamturteil

Weil F1 die **Befehlszeile der Seite** (Z.24) direkt widerlegt — die Seite dokumentiert
`--reason` fuer `block`, das weder im Changelog noch am CLI existiert (Grund positional) —
**widerspricht** die Seite dem neuen Befund. Gemaeß Auftrag („Falls die Seite dem neuen
Befund widerspricht, ist das Wort widerspruch") ist das Gesamturteil WIDERSPRUCH, nicht
unvollstaendig. F2–F4 fehlen, F5 ist auf der Seite unvollstaendig — der Widerspruch aus F1
dominiert die Klassifikation.

Die anderen drei Punkte (F2–F4) sind keine Widersprueche, sondern schlichte Luecken; F5 ist
teilweise vorhanden. Diese Differenz macht der Route-Karte der Aufwand, das Update/Konflikt-
Dossier vollstaendig zu fassen.

wissensstand: widerspruch