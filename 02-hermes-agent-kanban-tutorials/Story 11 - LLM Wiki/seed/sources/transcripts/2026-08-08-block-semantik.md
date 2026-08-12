# Transkript — „Menschliche Tore auf dem Kanban-Board, live gemessen"

**Kanal:** Tonbi's AI Garage
**Veröffentlicht:** 2026-08-08
**Länge:** 28 min
**Bezug:** Hermes Agent 0.20.0 / 0.20.1

---

[00:01:30] „Heute räumen wir etwas auf, das ich selbst falsch hatte, und das
in der Dokumentation bis vor zwei Tagen auch falsch stand."

[00:03:12] „Ich habe monatelang `hermes kanban block <id> --reason "…"`
geschrieben, weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl
bricht mit `unrecognized arguments` ab. Der Grund ist ein **positionales**
Argument:

```
hermes kanban block <id> "brauche eine Entscheidung"
```

Und wenn ihr eine Block-Art angeben wollt, muss `--kind` **vor** die
Kartennummer:

```
hermes kanban block --kind needs_input <id> "brauche eine Entscheidung"
```

Andersherum bricht es ebenfalls ab. Bei `unblock` gibt es `--reason` sehr wohl,
und dort ist es genau das, was man für ein Tor braucht: der Text wird als
Kommentar an die Karte gelegt, und die Karte geht danach nach `ready`."

[00:08:45] „Der zweite Punkt ist ernster, weil er stumm ist. Ich habe ein Tor
mit `--initial-status blocked` gebaut. Sah gut aus, Karte stand in `blocked`.
Und dann lief sie durch, sobald ihr Elternteil fertig war. Ohne Fehler, ohne
Warnung. `--initial-status blocked` setzt die **Spalte**, es erzeugt aber kein
`blocked`-**Ereignis** — und der Dispatcher schaut sich in `recompute_ready`
`todo` **und** `blocked` an. Liegen bleibt nur eine Karte, deren jüngstes
Ereignis ein echtes `blocked` ist."

[00:12:20] „Merksatz: **`--initial-status blocked` parkt, `block` hält.** Zum
Parken beim Anlegen ist es richtig. Als Tor ist es falsch."

[00:16:05] „Was den Block hält, ist übrigens nicht die Block-Art. Ein Block
ohne `--kind` hält genauso — ich habe das drei Ticks lang und mit
`dispatch --dry-run` geprüft. `--kind` ist eine **Typangabe**, keine
Haltekraft. `needs_input` ist trotzdem die richtige Angabe, weil sie jedem
Leser sagt: hier wartet ein Mensch."

[00:19:40] „Und jetzt die Falle, in die ich beim zweiten Tor gelaufen bin.
Ich wollte zwei Tore hintereinander auf **derselben** Karte: erst
Inhalt freigeben, dann Merge freigeben. Zweiter Block, dieselbe Block-Art —
und die Karte landet in der **Triage**, nicht in `blocked`. Das ist die
Schleifenerkennung: nach einem `unblock` zählt Hermes einen erneuten Block mit
derselben Art als Schleife und eskaliert. Ich habe eine halbe Stunde gesucht,
warum meine Karte plötzlich in der Triage-Spalte hängt."

[00:23:10] „Zwei Wege raus. Entweder die zweite Blockade bekommt eine
**andere** Block-Art — dann hält sie. Oder, und das würde ich empfehlen: zwei
Tore sind zwei **Karten**. Dann ist es egal, wie der Zähler geführt wird, und
man sieht auf dem Board, an welchem Tor man steht."

[00:26:30] „Für alle, die eine Pipeline mit Freigaben bauen: schreibt in den
Block-Grund alles, was man zum Entscheiden braucht. Ich will nicht eine Datei
öffnen müssen, um `approve` tippen zu können."
