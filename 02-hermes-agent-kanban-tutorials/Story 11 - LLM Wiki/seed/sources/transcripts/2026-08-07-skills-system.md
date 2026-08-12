# Transkript — „Skills in Hermes Agent, von unten aufgebaut"

**Kanal:** Tonbi's AI Garage
**Veröffentlicht:** 2026-08-07
**Länge:** 41 min
**Bezug:** Hermes Agent 0.20.0

---

[00:02:14] „Ich sehe in den Kommentaren dauernd dieselbe Verwirrung: Skills,
Profile und MCP-Server werden in einen Topf geworfen. Das sind drei völlig
verschiedene Dinge, und wenn man sie verwechselt, baut man sich einen Agenten,
der zu viel im Kontext hat und trotzdem nichts kann."

[00:05:40] „Eine Skill ist ein Verzeichnis mit einer `SKILL.md`. Ganz oben ein
YAML-Frontmatter mit `name` und `description`, darunter Markdown. Das ist alles.
Keine Registrierung, keine Installation im engeren Sinne — das Verzeichnis liegt
da, und Hermes findet es."

[00:07:55] „Es gibt drei Orte, und die Reihenfolge ist wichtig. Erstens
`~/.hermes/skills/` — die gelten global für jedes Profil. Zweitens
`~/.hermes/profiles/<name>/skills/` — die gelten **nur** für dieses Profil, und
in `hermes -p <name> skills list` erscheinen sie als `local`. Drittens die
eingebauten, die mit Hermes selbst kommen."

[00:09:30] „Und jetzt der Punkt, den fast alle übersehen: **nur die
`description` landet ungefragt im Kontext.** Der Rumpf der `SKILL.md` wird erst
geladen, wenn das Modell entscheidet, dass die Skill relevant ist. Deshalb ist
die `description` die wichtigste Zeile der ganzen Datei — sie ist der einzige
Teil, den das Modell garantiert sieht."

[00:12:10] „Wer eine Skill für einen Kanban-Worker schreibt, kann sie auch
erzwingen: `hermes kanban create … --skill <name>`. Dann liegt sie im Kontext
des Workers, unabhängig davon, ob das Modell sie für relevant hält. Bei
Pipelines mit festen Abläufen ist das der richtige Weg — man will nicht, dass
der Ablauf davon abhängt, wie überzeugend die `description` gerade wirkt."

[00:18:22] „`hermes -p <profil> skills list` zeigt euch die Auflösung mit
Herkunft: `hub-installed`, `builtin`, `local`, und je Zeile `enabled` oder
`disabled`. Wenn eine Skill nicht greift, schaut da zuerst hin — in neun von
zehn Fällen liegt sie im falschen Verzeichnis oder ist disabled."

[00:24:05] „Zum Verhältnis zu MCP: eine Skill ist **Text**. Sie fügt Wissen und
Anweisungen hinzu. Ein MCP-Server ist **Werkzeug** — er fügt Fähigkeiten hinzu,
also Funktionen, die der Agent aufrufen kann. Eine Skill kostet Kontext, ein
MCP-Server kostet Kontext **und** Werkzeug-Slots. Deshalb: was Text sein kann,
soll Text sein."

[00:31:47] „Profil-lokale Skills sind das schärfste Werkzeug im ganzen Kasten,
wenn man eine Flotte baut. Der Orchestrator bekommt den Ablauf, der Rechercheur
bekommt ihn **nicht**. Er soll seine Bahn bearbeiten, nicht mitdenken, was
danach kommt. Wenn jeder Agent alles weiß, hat man keine Flotte, sondern fünf
Kopien desselben Agenten mit fünf verschiedenen Namen."

[00:37:12] „Versionsnummern in der `SKILL.md` sind übrigens keine Kosmetik.
Wenn eine Skill sich ändert und ein Agent auf einem alten Board noch nach dem
alten Ablauf arbeitet, wollt ihr das sehen können."
