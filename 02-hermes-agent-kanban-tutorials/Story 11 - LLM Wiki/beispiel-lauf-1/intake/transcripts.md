# Scout-Bericht: transcripts

Ausgewertet: 3 Dateien unter sources/transcripts
Kandidaten: 12

Quellen:
- `2026-08-07-skills-system.md` — "Skills in Hermes Agent, von unten aufgebaut", Bezug: Hermes Agent 0.20.0
- `2026-08-08-block-semantik.md` — "Menschliche Tore auf dem Kanban-Board, live gemessen", Bezug: Hermes Agent 0.20.0 / 0.20.1
- `2026-08-10-community.md` — Community-Update Nr. 47, Bezug: allgemein (0 Kandidaten: nur Kanal-Neuigkeiten, Ankuendigung, Terminal-Vorliebe, Namensfindung)

---

## Eine Skill ist ein Verzeichnis mit einer SKILL.md (YAML-Frontmatter + Markdown), ohne Registrierung oder Installation

- **aussage:** Eine Hermes-Skill ist ein Verzeichnis, das eine `SKILL.md` enthaelt, oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown; es gibt keine Registrierung oder Installation, Hermes findet die Skill allein darueber, dass das Verzeichnis liegt.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:05:40] — "Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown. Das ist alles. Keine Registrierung, keine Installation im engeren Sinne — das Verzeichnis liegt da, und Hermes findet es."
- **version:** 0.20.0 (laut Kopfzeile "Bezug: Hermes Agent 0.20.0")
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skills bzw. deren Aufbau
- **neuheit_vermutet:** vermutlich abgedeckt — die Grundstruktur einer Skill duerfte in der Wissensbasis bereits stehen; die Aussage praezisiert aber das "keine Registrierung".

## Es gibt drei Skill-Speicherorte mit unterschiedlicher Reichweite

- **aussage:** Skills liegen an drei Orten: ~/.hermes/skills/ (global, gilt fuer jedes Profil), ~/.hermes/profiles/<name>/skills/ (nur fuer dieses Profil, erscheint in `hermes -p <name> skills list` als `local`), sowie eingebaute Skills, die mit Hermes selbst kommen. Die Reihenfolge der Orte ist wichtig.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:07:55] — "Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens `~/.hermes/skills/` — die gelten global für jedes Profil. Zweitens `~/.hermes/profiles/<name>/skills/` — die gelten **nur** für dieses Profil, und in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens die eingebauten, die mit Hermes selbst kommen."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skill-Speicherorte bzw. Skill-Verwaltung
- **neuheit_vermutet:** vermutlich abgedeckt — die drei Orte sind ein haeufig dokumentiertes Detail; "die Reihenfolge ist wichtig" wuerde die Triage gegen die aktuelle Doku pruefen muessen.

## Nur die description einer SKILL.md landet ungefragt im Kontext; der Rumpf wird erst bei Relevanzentscheidung geladen

- **aussage:** Von einer Skill landet nur die `description` automatisch im Kontext; der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell die Skill fuer relevant haelt, sodass die `description` die einzige garantiert sichtbare Zeile ist.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:09:30] — "nur die `description` landet ungefragt im Kontext. Der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill relevant ist. Deshalb ist die `description` die wichtigste Zeile der ganzen Datei — sie ist der einzige Teil, den das Modell garantiert sieht."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skills und Kontextbelastung
- **neuheit_vermutet:** vermutlich neu — die genaue Mechanik (description automatisch im Kontext, Rumpf bedarfsgeladen) ist ein praeziser, ueberpruefbarer Punkt, der in einer Wissensbasis leicht fehlt.

## `hermes kanban create … --skill <name>` erzwingt eine Skill im Kontext des Workers

- **aussage:** Eine Skill kann fuer einen Kanban-Worker erzwungen werden, indem man `hermes kanban create … --skill <name>` nutzt; dann liegt sie im Kontext des Workers, unabhaengig davon, ob das Modell sie fuer relevant haelt.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:12:10] — "Wer eine Skill für einen Kanban-Worker schreibt, kann sie auch erzwingen: `hermes kanban create … --skill <name>`. Dann liegt sie im Kontext des Workers, unabhängig davon, ob das Modell sie für relevant hält."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Worker bzw. Skills
- **neuheit_vermutet:** vermutlich neu — die `--skill`-Erzwingung beim `kanban create` ist ein spezifisches Kommando-Detail.

## `hermes -p <profil> skills list` zeigt die Herkunft und den Status je Skill

- **aussage:** `hermes -p <profil> skills list` zeigt die Aufloesung der Skills mit Herkunft (`hub-installed`, `builtin`, `local`) und je Zeile `enabled` oder `disabled`; eine nicht greifende Skill liegt laut des Sprechers meist im falschen Verzeichnis oder ist disabled.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:18:22] — "`hermes -p <profil> skills list` zeigt euch die Auflösung mit Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder `disabled`."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skills-Verwaltung / `skills list`
- **neuheit_vermutet:** vermutlich neu — die genauen Herkunftswerte und das enabled/disabled-Feld je Zeile sind detailierte, ueberpruefbare Ausgaben-Eigenschaften.

## Skill kostet Kontext, MCP-Server kostet Kontext und Werkzeug-Slots

- **aussage:** Eine Skill ist Text und fuegt Wissen und Anweisungen hinzu (kostet Kontext); ein MCP-Server ist ein Werkzeug und fuegt Funktionen hinzu (kostet Kontext UND Werkzeug-Slots).
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:24:05] — "Eine Skill ist **Text**. Sie fügt Wissen und Anweisungen hinzu. Ein MCP-Server ist **Werkzeug** — er fügt Fähigkeiten hinzu, also Funktionen, die der Agent aufrufen kann. Eine Skill kostet Kontext, ein MCP-Server kostet Kontext **und** Werkzeug-Slots."
- **version:** 0.20.0
- **betrifft_vermutlich:** vermutlich eine Seite ueber Skills vs. MCP bzw. Kontext-/Werkzeugbudget
- **neuheit_vermutet:** vermutlich abgedeckt — der Unterschied Skill=Text vs. MCP=Werkzeug ist ein haeufig genannter Konzeptpunkt; dass MCP zusaetzlich Werkzeug-Slots kostet, koennte die Triage gegen die MCP-Seite pruefen.

## `hermes kanban block` akzeptiert keinen --reason-Flag; der Grund ist ein positionales Argument

- **aussage:** `hermes kanban block <id> --reason "…"` gibt es nicht und bricht mit `unrecognized arguments` ab; der Grund wird als positionales Argument uebergeben: `hermes kanban block <id> "brauche eine Entscheidung"`. Die Dokumentation stand laut Sprecher bis zwei Tage vor dem Video falsch.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — "Ich habe monatelang `hermes kanban block <id> --reason \"…\"` geschrieben, weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl bricht mit `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument: `hermes kanban block <id> \"brauche eine Entscheidung\"`."
- **version:** 0.20.0 / 0.20.1 (laut Kopfzeile "Bezug: Hermes Agent 0.20.0 / 0.20.1")
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Kommandos / `block`
- **neuheit_vermutet:** vermutlich neu — eine korrigierte Annahme ueber eine dokumentierte, aber nicht existierende Syntax; genau der Fall, den die Wissensbasis sonst falsch uebernimmt.

## Bei `hermes kanban block` muss --kind vor der Kartennummer stehen

- **aussage:** Will man eine Block-Art angeben, muss `--kind` vor der Kartennummer stehen (`hermes kanban block --kind needs_input <id> "…"`); andersherum bricht der Befehl ebenfalls ab.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — "Und wenn ihr eine Block-Art angeben wollt, muss `--kind` **vor** die Kartennummer: `hermes kanban block --kind needs_input <id> \"brauche eine Entscheidung\"`. Andersherum bricht es ebenfalls ab."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Kommandos / `block`
- **neuheit_vermutet:** vermutlich neu — die Argument-Reihenfolge von `--kind` ist ein spezifisches, ueberpruefbares Kommando-Detail.

## Beim `hermes kanban unblock` gibt es --reason sehr wohl; der Text landet als Kommentar und die Karte geht nach ready

- **aussage:** Bei `unblock` existiert `--reason`; der uebergebene Text wird als Kommentar an die Karte gelegt, und die Karte geht danach nach `ready`.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — "Bei `unblock` gibt es `--reason` sehr wohl, und dort ist es genau das, was man für ein Tor braucht: der Text wird als Kommentar an die Karte gelegt, und die Karte geht danach nach `ready`."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Kommandos / `unblock`
- **neuheit_vermutet:** vermutlich neu — der Gegenpunkt zu den `block`-Befunden: `unblock --reason` existiert und hat diese Semantik.

## `--initial-status blocked` setzt die Spalte, erzeugt aber kein blocked-Ereignis; der Dispatcher betrachtet in recompute_ready todo und blocked

- **aussage:** `--initial-status blocked` setzt nur die Spalte, erzeugt aber kein `blocked`-Ereignis; der Dispatcher schaut sich in `recompute_ready` sowohl `todo` als auch `blocked` an, sodass eine so angelegte Karte nach Fertigstellung des Elternteils ohne Fehler und Warnung durchlaeuft. Liegen bleibt nur eine Karte, deren juengstes Ereignis ein echtes `blocked` ist.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:08:45] — "`--initial-status blocked` setzt die **Spalte**, es erzeugt aber kein `blocked`-**Ereignis** — und der Dispatcher schaut sich in `recompute_ready` `todo` **und** `blocked` an. Liegen bleibt nur eine Karte, deren jüngstes Ereignis ein echtes `blocked` ist."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Dispatcher bzw. Block-Semantik
- **neuheit_vermutet:** vermutlich neu — ein gemessenes, stummes Verhalten (Spalte vs. Ereignis), das genau die Sorte detailierte Mechanik ist, die eine Wissensbasis selten abdeckt.

## Die Block-Art haelt einen Block nicht; ein Block ohne --kind haelt genauso

- **aussage:** Die Haltekraft eines Blocks haengt nicht von der Block-Art ab; ein Block ohne `--kind` haelt genauso (vom Sprecher drei Ticks lang und mit `dispatch --dry-run` geprueft). `--kind` ist eine Typangabe, keine Haltekraft; `needs_input` ist trotzdem die richtige Angabe, weil sie Kommunikation ueber einen wartenden Menschen ist.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:16:05] — "Was den Block hält, ist übrigens nicht die Block-Art. Ein Block ohne `--kind` hält genauso — ich habe das drei Ticks lang und mit `dispatch --dry-run` geprüft. `--kind` ist eine **Typangabe**, keine Haltekraft."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Block-Semantik / Dispatcher
- **neuheit_vermutet:** vermutlich neu — ein gemessenes Verhalten (Haltekraft unabhaengig von der Block-Art), das eine verbreitete Annahme korrigiert.

## Ein zweiter Block mit derselben Block-Art nach unblock auf derselben Karte landet in der Triage statt in blocked

- **aussage:** Blockiert man eine Karte nach einem `unblock` erneut mit derselben Block-Art, zaehlt Hermes das als Schleife (Schleifenerkennung) und die Karte landet in der Triage statt in `blocked`. Ein Ausweg ist eine andere Block-Art (dann haelt sie), empfohlen sind zwei Tore als zwei Karten.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:19:40] — "Zweiter Block, dieselbe Block-Art — und die Karte landet in der **Triage**, nicht in `blocked`. Das ist die Schleifenerkennung: nach einem `unblock` zählt Hermes einen erneuten Block mit derselben Art als Schleife und eskaliert."
  - `2026-08-08-block-semantik.md` — [00:23:10] — "Entweder die zweite Blockade bekommt eine **andere** Block-Art — dann hält sie. Oder, und das würde ich empfehlen: zwei Tore sind zwei **Karten**."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** vermutlich eine Seite ueber Kanban-Block-Semantik bzw. Triage-Eskalation
- **neuheit_vermutet:** vermutlich neu — ein gemessenes Eskalationsverhalten (Schleifenerkennung fuehrt in die Triage), das fuer den Aufbau der beiden Tore dieser Story direkt relevant ist.
