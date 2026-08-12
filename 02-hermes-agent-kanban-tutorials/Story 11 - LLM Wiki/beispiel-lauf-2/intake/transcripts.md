# Scout-Bericht: transcripts

Ausgewertet: 3 Dateien unter sources/transcripts
Kandidaten: 12

Hinweis: 2026-08-10-community.md liefert KEINE Kandidaten. Sie enthaelt nur
Kanal-Neuigkeiten (Abonnentenzahl, Lob, Tempo der Entwicklung), die Ankuendigung
einer kuenftigen Masterclass, eine Terminal-/Font-Vorliebe (Ghostty, Nerd Font)
und eine Namenssuche („Cyberbrain"). Das sind laut Abgrenzung keine
ueberpruefbaren Aussagen ueber Hermes Agent.

---

## Eine Skill ist ein Verzeichnis mit einer `SKILL.md` (YAML-Frontmatter, darunter Markdown); keine Registrierung noetig

- **aussage:** Eine Hermes-Skill ist ein Verzeichnis, das eine `SKILL.md` enthaelt; oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown, und Hermes findet die Skill, ohne dass sie registriert oder installiert werden muss.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:05:40] — „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein YAML-Frontmatter mit `name` und `description`, darunter Markdown. Das ist alles. Keine Registrierung, keine Installation im engeren Sinne — das Verzeichnis liegt da, und Hermes findet es."
- **version:** 0.20.0 (Datei-Kopf: „Bezug: Hermes Agent 0.20.0")
- **betrifft_vermutlich:** moegliche neue Seite zu Skill-/Skill-System; beruehrt evtl. profile-system.md und memory-system.md
- **neuheit_vermutet:** vermutlich abgedeckt — der Werkzeug-Satz dieser Story hat keine Skill-Seite, aber der Verdacht ist ungeprueft; kann von der Triage erst nach Lesen von wiki/pages beurteilt werden

## Es gibt drei Orte fuer Skills: global, profil-lokal (als `local` ausgezeichnet) und eingebaut

- **aussage:** Skills liegen an drei Orten: `~/.hermes/skills/` (gilt global fuer jedes Profil), `~/.hermes/profiles/<name>/skills/` (nur fuer das Profil; erscheint in der Skills-Liste als `local`) und den mit Hermes mitgelieferten eingebauten; die Reihenfolge ist bedeutsam.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:07:55] — „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens `~/.hermes/skills/` — die gelten global für jedes Profil. Zweitens `~/.hermes/profiles/<name>/skills/` — die gelten **nur** für dieses Profil, und in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens die eingebauten, die mit Hermes selbst kommen."
- **version:** 0.20.0
- **betrifft_vermutlich:** profile-system.md, moegliche Skill-Seite
- **neuheit_vermutet:** vermutlich abgedeckt — profil-lokale Pfade stehen plausibel schon in profile-system.md; Einordnung der Triage

## Nur die `description` einer Skill landet ungefragt im Kontext; der Rumpf wird erst bei Bedarf geladen

- **aussage:** Von einer Skill sieht das Modell garantiert nur die `description`; der Rumpf der `SKILL.md` wird nur geladen, wenn das Modell die Skill fuer relevant haelt.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:09:30] — „**nur die `description` landet ungefragt im Kontext.** Der Rumpf der `SKILL.md` wird erst geladen, wenn das Modell entscheidet, dass die Skill relevant ist. Deshalb ist die `description` die wichtigste Zeile der ganzen Datei — sie ist der einzige Teil, den das Modell garantiert sieht."
- **version:** 0.20.0
- **betrifft_vermutlich:** moegliche Skill-Seite; memory-system.md (Kontextmechanik)
- **neuheit_vermutet:** vermutlich neu — dies beschreibt eine konkrete Lade-Mechanik, die in den vorhandenen Seiten (cron, gateway, memory, profile, kanban) nicht naheliegt

## `hermes kanban create … --skill <name>` erzwingt eine Skill im Kontext des Kanban-Workers

- **aussage:** Mit `hermes kanban create … --skill <name>` liegt die genannte Skill im Kontext des Workers, unabhaengig davon, ob das Modell sie relevant findet.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:12:10] — „Wer eine Skill für einen Kanban-Worker schreibt, kann sie auch erzwingen: `hermes kanban create … --skill <name>`. Dann liegt sie im Kontext des Workers, unabhängig davon, ob das Modell sie für relevant hält."
- **version:** 0.20.0
- **betrifft_vermutlich:** kanban-board.md, moegliche Skill-Seite
- **neuheit_vermutet:** vermutlich neu — ein konkretes Kommando-Flag fuer die Kanban/Agency-Integration, das kein vorhandener Seitentitel anklingen laesst

## `hermes -p <profil> skills list` zeigt die Aufloesung mit Herkunft und enabled/disabled

- **aussage:** Der Befehl ist `hermes -p <profil> skills list`; er listet Skills mit Herkunft (`hub-installed`, `builtin`, `local`) und je Zeile `enabled` oder `disabled`.
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:18:22] — „`hermes -p <profil> skills list` zeigt euch die Auflösung mit Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder `disabled`."
- **version:** 0.20.0
- **betrifft_vermutlich:** moegliche Skill-Seite, profile-system.md
- **neuheit_vermutet:** vermutlich neu — aufzaehlt konkrete Herkunfts-Auszeichnungen, die kein vorhandener Seitentitel abdeckt

## Eine Skill kostet Kontext, ein MCP-Server kostet Kontext UND Werkzeug-Slots

- **aussage:** Eine Skill ist Text (fuegt Wissen/Anweisungen, kostet Kontext); ein MCP-Server ist ein Werkzeug (fuegt Faehigkeiten, kostet Kontext und Werkzeug-Slots); daher lautet die Regel „was Text sein kann, soll Text sein".
- **quellen:**
  - `2026-08-07-skills-system.md` — [00:24:05] — „Eine Skill ist **Text**. Sie fügt Wissen und Anweisungen hinzu. Ein MCP-Server ist **Werkzeug** — er fügt Fähigkeiten hinzu, also Funktionen, die der Agent aufrufen kann. Eine Skill kostet Kontext, ein MCP-Server kostet Kontext **und** Werkzeug-Slots. Deshalb: was Text sein kann, soll Text sein."
- **version:** 0.20.0
- **betrifft_vermutlich:** moegliche Skill-Seite; evtl. neue Seite zu MCP-Werkzeugen
- **neuheit_vermutet:** vermutlich neu — benennt ein Ressourcen-Kostenverhaeltnis (Tool-Slots), das in den vorhandenen Seiten nicht auftaucht

## `hermes kanban block` kennt kein `--reason`; der Grund ist ein positionales Argument

- **aussage:** `hermes kanban block <id> --reason "…"` ist kein gueltiger Aufruf und bricht mit `unrecognized arguments` ab; der Grund ist ein positionales Argument: `hermes kanban block <id> "brauche eine Entscheidung"`.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — „Ich habe monatelang `hermes kanban block <id> --reason "…"` geschrieben, weil es so dokumentiert war. Das gibt es **nicht**. Der Befehl bricht mit `unrecognized arguments` ab. Der Grund ist ein **positionales** Argument: `hermes kanban block <id> \"brauche eine Entscheidung\"`."
- **version:** 0.20.0 / 0.20.1 (Datei-Kopf: „Bezug: Hermes Agent 0.20.0 / 0.20.1")
- **betrifft_vermutlich:** kanban-block-semantik.md, kanban-board.md
- **neuheit_vermutet:** vermutlich neu — eine korrigierte Annahme ueber die Block-Syntax; betrifft genau den Pfad, der in ingest.yaml als `block` dokumentiert ist und dort als `--reason` beschrieben wird

## `--kind` muss bei `hermes kanban block` VOR der Kartennummer stehen

- **aussage:** Eine Block-Art wird mit `--kind` vor der Kartennummer angegeben (`hermes kanban block --kind needs_input <id> "…"`); `--kind` hinter der Nummer laesst den Befehl abbrechen.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — „Und wenn ihr eine Block-Art angeben wollt, muss `--kind` **vor** die Kartennummer: `hermes kanban block --kind needs_input <id> \"brauche eine Entscheidung\"`. Andersherum bricht es ebenfalls ab."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** kanban-block-semantik.md, kanban-board.md
- **neuheit_vermutet:** vermutlich neu — pragmatische Syntax-Detail zu `block`, das in der Block-Semantik-Seite ergaenzend waere

## `hermes kanban unblock` hat `--reason`; der Text wird als Kommentar an die Karte gelegt, die Karte geht danach nach `ready`

- **aussage:** Anders als bei `block` existiert bei `unblock` das `--reason`-Flag: der Text landet als Kommentar an der Karte, und die Karte geht anschliessend nach `ready`.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:03:12] — „Bei `unblock` gibt es `--reason` sehr wohl, und dort ist es genau das, was man für ein Tor braucht: der Text wird als Kommentar an die Karte gelegt, und die Karte geht danach nach `ready`."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** kanban-block-semantik.md, kanban-board.md, gateway-und-dispatcher.md
- **neuheit_vermutet:** vermutlich abgedeckt — der Uebergang nach `ready` steht plausibel schon in der Kanban-Semantik; die konkrete `--reason`-Kommentar-Mechanik koennte dagegen fehlen

## `--initial-status blocked` setzt nur die Spalte, erzeugt kein `blocked`-Ereignis; die Karte laeuft trotzdem durch

- **aussage:** `--initial-status blocked` platziert eine Karte in der Spalte `blocked`, erzeugt aber kein `blocked`-Ereignis; weil der Dispatcher in `recompute_ready` sowohl `todo` als auch `blocked` prueft, laeuft die Karte durch, sobald das Elternteil fertig ist — stumm, ohne Fehler oder Warnung.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:08:45] — „Ich habe ein Tor mit `--initial-status blocked` gebaut. Sah gut aus, Karte stand in `blocked`. Und dann lief sie durch, sobald ihr Elternteil fertig war. Ohne Fehler, ohne Warnung. `--initial-status blocked` setzt die **Spalte**, es erzeugt aber kein `blocked`-**Ereignis** — und der Dispatcher schaut sich in `recompute_ready` `todo` **und** `blocked` an."
  - `2026-08-08-block-semantik.md` — [00:12:20] — „**`--initial-status blocked` parkt, `block` hält.** Zum Parken beim Anlegen ist es richtig. Als Tor ist es falsch."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** kanban-block-semantik.md, gateway-und-dispatcher.md
- **neuheit_vermutet:** vermutlich neu — ein gemessenes, stuilles Fehlverhalten (Spalte vs. Ereignis) und die `recompute_ready`-Mechanik, die als solche in keiner vorhandenen Seite erkennbar ist

## `--kind` ist keine Haltekraft; ein Block ohne `--kind` haelt genauso

- **aussage:** Die Haltekraft eines Blocks haengt nicht von der Block-Art ab; ein Block ohne `--kind` haelt genauso. `--kind` ist eine Typangabe zur Kennzeichnung. (Vom Sprecher drei Ticks lang und mit `dispatch --dry-run` geprueft.)
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:16:05] — „Was den Block hält, ist übrigens nicht die Block-Art. Ein Block ohne `--kind` hält genauso — ich habe das drei Ticks lang und mit `dispatch --dry-run` geprüft. `--kind` ist eine **Typangabe**, keine Haltekraft."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** kanban-block-semantik.md, kanban-board.md
- **neuheit_vermutet:** vermutlich neu — ein gemessenes Verhalten, das die Semantik-Seite praezisiert; HINWEIS zur Zitattreue: „drei Ticks und `dispatch --dry-run`" ist die Messmethode des Sprechers, keine verifizierte Grenze

## Nach einem `unblock` landet ein erneuter Block mit derselben Block-Art in der Triage (Schleifenerkennung)

- **aussage:** Nach einem `unblock` zaehlt Hermes einen erneuten Block mit derselben Block-Art als Schleife und eskaliert: die Karte landet in der Triage statt in `blocked`. Ein zweiter Block (z.B. als zweites Tor) mit neuer Block-Art haelt dagegen.
- **quellen:**
  - `2026-08-08-block-semantik.md` — [00:19:40] — „Zweiter Block, dieselbe Block-Art — und die Karte landet in der **Triage**, nicht in `blocked`. Das ist die Schleifenerkennung: nach einem `unblock` zählt Hermes einen erneuten Block mit derselben Art als Schleife und eskaliert."
  - `2026-08-08-block-semantik.md` — [00:23:10] — „Entweder die zweite Blockade bekommt eine **andere** Block-Art — dann hält sie."
- **version:** 0.20.0 / 0.20.1
- **betrifft_vermutlich:** kanban-block-semantik.md, kanban-board.md (entspricht der in ingest.yaml benannten `BLOCK_RECURRENCE_LIMIT`-Mechanik / `block_loop_detected`)
- **neuheit_vermutet:** vermutlich abgedeckt — ingest.yaml beschreibt die Schleifenerkennung bereits im Kommentar zu den Toren („landet sie in der TRIAGE statt in blocked (Ereignis: block_loop_detected)"); inhaltlich ist die Aussage aber aus dem Transkript zu verifizieren

---

Nicht beruecksichtigte Passagen (keine Kandidaten, Begruendung):

- `2026-08-07-skills-system.md` [00:31:47] — Empfehlung zur Flotten-Architektur („der Orchestrator bekommt den Ablauf, der Rechercheur nicht"); Meinung/Designratschlag, kein Produktverhalten.
- `2026-08-07-skills-system.md` [00:37:12] — Empfehlung, Versionsnummern in der SKILL.md zu pflegen; Arbeitshinweis, kein ueberpruefbares Produktverhalten.
- `2026-08-08-block-semantik.md` [00:26:30] — Ratschlag, Entscheidungsmaterial in den Block-Grund zu schreiben; Best Practice, kein Produktverhalten.
- `2026-08-10-community.md` — gesamte Datei (Kanal-Neuigkeiten, Lob, Masterclass-Ankuendigung, Terminal/Font-Vorliebe, Namenssuche).