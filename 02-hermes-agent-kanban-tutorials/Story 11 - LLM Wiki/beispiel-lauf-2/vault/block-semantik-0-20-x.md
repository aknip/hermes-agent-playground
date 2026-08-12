---
slug: block-semantik-0-20-x
titel: "Block-Semantik: Seite ist veraltet und teilweise falsch (block nimmt Grund positional, --kind-Position, --initial-status blocked, --kind als Typangabe)"
status: gemergt
score: 83
score_breakdown: {neuheit: 16, quellenvertrauen: 17, themenbezug: 24,
                  versionsrelevanz: 14, klarheitsgewinn: 12}
wissensstand: widerspruch
route: konflikt
gebuendelt_aus:
  - "intake/releases.md (0.20.1/0.20.2): 'block nimmt den Grund positional, Dokumentation korrigiert' (R10); '--kind muss vor der Kartennummer stehen' (R11); '--initial-status blocked ist kein Tor' (R8); 'block_loop_detected + Triage bei wiederholter Block-Art' (R14)"
  - "intake/transcripts.md (2026-08-08-block-semantik.md): 'block kennt kein --reason, Grund ist positional' ; '--kind vor der Kartennummer' ; '--initial-status blocked setzt nur die Spalte' ; '--kind ist keine Haltekraft'"
betrifft: [kanban-block-semantik, kanban-board]
---
Der Slug beschreibt das Item (Block-Semantik der 0.20.x-Linie), nicht die
Quelle. Alle diese Kandidaten betreffen dieselbe Seitengruppe
(`kanban-block-semantik.md`, `kanban-board.md`) und stammen aus demselben
Vorgang (Block-Semantik / 0.20.1- und 0.20.2-Changelog plus das Block-Transkript)
— daher EIN Item.

KONFLIKT: `kanban-block-semantik.md` (version 0.19.0, Stand 2026-06) dokumentiert
in Zeile 24 ausdruecklich `hermes kanban block <id> --reason "…"`. Sowohl
Changelog 0.20.1 als auch das Transkript sagen: `block` kennt KEIN `--reason` —
der Grund ist ein positionales Argument. Die Seite zeigt also eine falsche
Syntax; das ist der Kern-Widerspruch, den die Route `konflikt` traegt. Dazu
kommen Ergaenzungen (gleiche Seite), die fehlen: `--kind` muss vor der
Kartennummer stehen; `--initial-status blocked` setzt nur die Spalte und erzeugt
kein `blocked`-Ereignis (kein Tor); `--kind` ist eine Typangabe und keine
Haltekraft; das Ereignis einer wiederholten Blockade heisst `block_loop_detected`
(Zaehler je Block-Art).

Bereits abgedeckt (daher nicht Doppel-Item): die Grundaussage, dass eine nach
einem `unblock` erneut mit derselben Block-Art blockierte Karte in die Triage
statt in `blocked` landet, steht bereits in `kanban-block-semantik.md`
(Zeilen 47-52). Ebenso ist `unblock --reason -> Kommentar -> ready` dort bereits
belegt (Zeilen 29-31). Nicht abgedeckt sind nur die Details (Ereignisname
`block_loop_detected`, Zaehler-Fuehrung je Block-Art), die als Teil dieses Items
ergaenzt werden.

Bewertung je Dimension:
- neuheit (16/25): teils Widerspruchs-Korrektur an einer falschen Zeile, teils
  neue Messwerte (−kind-Position, initial-status, kind-keine-Haltekraft,
  block_loop_detected); ein Teil (Triage bei Wiederholung) ist bereits bekannt.
- quellenvertrauen (17/20): offizieller Changelog 0.20.1/0.20.2 plus gemessenes
  Transkript; beide unabhängig voneinander und konsistent.
- themenbezug (24/25): die Block-Semantik ist die Mechanik, auf der diese
  Pipeline selbst ruht; die Seite ist normativ fuer jeden Tor-Bau.
- versionsrelevanz (14/15): betrifft 0.20.0-0.20.2, die aktuelle Linie; die Seite
  steht auf 0.19.0 und ist damit ueberholt.
- klarheitsgewinn (12/15): korrigiert eine aktiv falsche Syntax, auf die ein
  Agent sonst bauen und scheitern wuerde; erhoeht die Praezision einer
  Kernseite deutlich, wobei ein Teil schon bekannt ist.

summe = 83 >= schwelle 65. status -> recherche. Fan-out ueber
verifikation + seiten-abgleich; die Seite ist 0.19.0/2026-06, damit ist die
Versionrelevanz real. Route wird voraussichtlich `konflikt`.