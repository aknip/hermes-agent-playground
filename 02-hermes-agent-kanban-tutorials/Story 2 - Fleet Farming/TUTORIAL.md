# Story 2 — Zwölf Tasks, drei Spezialisten, alle gleichzeitig

**Eigenständiges Tutorial.** Setup, Durchlauf und Rückbau stehen hier
vollständig; keine andere Story wird vorausgesetzt.

| | |
|---|---|
| Board | `kanban-story-2` |
| Profile | `translator`, `transcriber`, `copywriter` |
| Mandant | `content-ops` |
| Workspace-Art | `dir:` — ein gemeinsames Verzeichnis |
| Dauer | ca. 10 Minuten |
| Verifiziert gegen | Hermes Agent v0.20.0 (2026.8.3), macOS |

---

## Worum es geht

Der einfachste Anwendungsfall und der, für den ein Board sich am schnellsten
bezahlt macht: ein Haufen **unabhängiger** Aufgaben, drei Spezialisten, alle
sollen gleichzeitig ziehen.

```
translator    3 Tasks   Homepage nach ES / FR / DE
transcriber   5 Tasks   fünf rohe Gesprächsnotizen aufbereiten
copywriter    4 Tasks   vier Produkttexte aus SKU-Daten
```

Kein `--parent`, keine Abhängigkeiten: alle zwölf stehen sofort auf `ready` und
werden im selben Dispatch-Fenster beansprucht.

Wenn du Story 5 kennst: dort trennt der **Mandant** die Arbeit bei *einem*
Profil. Hier trennt das **Profil** die Arbeit bei *einem* Mandanten. Beides
sind Achsen desselben Boards.

---

## Schritt 2.1 — Setup

```bash
cd "Story 2 - Fleet Farming"
chmod +x setup.sh teardown.sh pump.sh reset-workspace.sh create-tasks.sh
./setup.sh
```

Das legt Board `kanban-story-2`, die drei Profile (mit `SOUL.md`,
Beschreibung, `config.yaml`) und `workspace/` aus `seed/` an.

Ein Profil zählt für den Dispatcher erst dann als Assignee, wenn in seinem
Verzeichnis eine **`config.yaml`** liegt (`kanban_db.list_profiles_on_disk`).
`hermes profile create` legt sie nicht an, `hermes -p <profil> config set …`
schon — deshalb schreibt `setup.sh` alle vier Modell-Schlüssel aus deiner
Root-Konfiguration ins Profil.

```bash
hermes kanban --board kanban-story-2 assignees
```

```console
NAME                  ON DISK   COUNTS
copywriter            yes       (idle)
transcriber           yes       (idle)
translator            yes       (idle)
…
```

### Die Arbeitsdateien

```
workspace/
├── source/homepage.md      englische Marketing-Seite (Vorlage zum Übersetzen)
├── calls/call-1.txt … 5    fünf rohe, unstrukturierte Gesprächsmitschriften
├── products/skus.csv       vier Produkte mit Attributen
├── translations/           leer — Ziel der Übersetzer
├── transcripts/            leer — Ziel der Transkribierer
└── descriptions/           leer — Ziel der Texter
```

`products/skus.csv` — bewusst nur Fakten, damit man erkennt, ob ein Texter
etwas dazuerfindet:

```csv
sku,name,category,material,colour,weight_g,key_feature,price_eur
SKU-1001,Trailhead 30L Daypack,Backpacks,recycled ripstop nylon,slate blue,780,ventilated back panel with removable frame,129.00
SKU-1002,Kettle Peak Insulated Bottle,Drinkware,18/8 stainless steel,matte sand,410,keeps drinks cold 24h / hot 12h,34.90
SKU-1003,Fieldnote Hardcover Journal,Stationery,recycled paper 120gsm,forest green,320,lay-flat binding with numbered pages,18.50
SKU-1004,Ridgeline Merino Beanie,Headwear,merino wool blend,charcoal,85,itch-free flatlock seam,27.00
```

Die fünf `calls/call-N.txt` sind absichtlich hässlich — Kleinschreibung,
Abkürzungen, Gedankensprünge, eingestreute `action:`-Zeilen. Genau daran zeigt
sich, ob der Transkribierer strukturiert statt halluziniert. Auszug aus
`calls/call-2.txt`:

```
Q3 CUSTOMER CALL — RAW NOTES
acct: Halden Logistics / enterprise trial, day 19 of 30
who: Tobias (head of data eng), Sam (analyst)

tobias opens with: "we're not going to buy this if the API rate limit stays"
       — hitting 429s on backfill, 5k events/min ceiling
       their backfill is 40M events, math doesnt work
...
sentiment: at risk — technical blocker is real, not a negotiating tactic
```

---

## Schritt 2.2 — Die zwölf Tasks anlegen

```bash
./create-tasks.sh
```

Der Kern von [`create-tasks.sh`](create-tasks.sh) — beachte, dass hier **kein**
`--parent` vorkommt:

```bash
BOARD=kanban-story-2
WS="$PWD/workspace"

for lang in Spanish French German; do
    hermes kanban --board $BOARD create "Translate homepage to $lang" \
        --assignee translator --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Übersetze source/homepage.md nach $lang → translations/homepage.<code>.md …"
done

for i in 1 2 3 4 5; do
    hermes kanban --board $BOARD create "Transcribe Q3 customer call #$i" \
        --assignee transcriber --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Bereite calls/call-$i.txt zu transcripts/call-$i.md auf …"
done

for sku in 1001 1002 1003 1004; do
    hermes kanban --board $BOARD create "Generate product description: SKU-$sku" \
        --assignee copywriter --tenant content-ops \
        --workspace "dir:$WS" \
        --body "Schreibe descriptions/SKU-$sku.md aus products/skus.csv …"
done
```

`--workspace dir:<pfad>` muss absolut sein. Ohne die Angabe bekäme jeder Task
ein Wegwerf-Verzeichnis (`scratch`) und du sähest das Ergebnis nur im Summary.

Alle zwölf stehen danach auf `ready`:

```bash
hermes kanban --board kanban-story-2 list --tenant content-ops
```

---

## Schritt 2.3 — Laufen lassen und weggehen

```bash
./pump.sh
```

Im Normalbetrieb übernimmt das der Dispatcher im Gateway:

```bash
hermes gateway start
```

Das Gateway enthält den Dispatcher und bedient **alle** Boards — auch ein
gerade neu angelegtes. Sein Takt ist `kanban.dispatch_interval_seconds`
(Standard 60 s), was für ein Tutorial zäh ist; `pump.sh` tickt alle 15
Sekunden und nur auf diesem Board.

Deckeln, wenn zwölf gleichzeitige Prozesse zu viel für die Maschine sind:

```bash
hermes kanban --board kanban-story-2 dispatch --max 4
```

---

## Schritt 2.4 — Beim Arbeiten zusehen

```bash
hermes kanban --board kanban-story-2 list --tenant content-ops
hermes kanban --board kanban-story-2 stats
hermes kanban --board kanban-story-2 watch --kinds completed,blocked,gave_up
```

`stats` ist die Flottenübersicht:

```console
By status:
  triage    0
  todo      0
  scheduled  0
  ready     0
  running   1
  blocked   0
  done      11

By assignee:
  copywriter            done=4
  transcriber           done=4, running=1
  translator            done=3
```

**Im Dashboard:** oben auf `content-ops` filtern. Die Spalte *In progress* ist
mit „Lanes by profile" (Standard) nach Assignee unterteilt — du siehst pro
Worker eine eigene Bahn statt einer gemischten Liste. Schaltest du den Regler
aus, wird eine flache Liste nach Claim-Zeitpunkt daraus.

---

## Das solltest du sehen

Real gemessen: **alle zwölf Tasks starteten innerhalb von zwei
Dispatch-Ticks** und waren nach gut zwei Minuten Wanduhrzeit fertig — je ein
Run, kein Fehlversuch:

```console
  1  completed     translator              1m  2026-08-10 10:48
  1  completed     translator              1m  2026-08-10 10:48
  1  completed     translator              1m  2026-08-10 10:48
  1  completed     transcriber             1m  2026-08-10 10:48
  1  completed     transcriber             1m  2026-08-10 10:49
  1  completed     transcriber             1m  2026-08-10 10:49
  1  completed     transcriber             2m  2026-08-10 10:49
  1  completed     transcriber             1m  2026-08-10 10:49
  1  completed     copywriter              1m  2026-08-10 10:49
  1  completed     copywriter              1m  2026-08-10 10:49
  1  completed     copywriter              1m  2026-08-10 10:49
  1  completed     copywriter              2m  2026-08-10 10:49
```

Und zwölf neue Dateien:

```bash
./reset-workspace.sh --diff
```

```console
workspace/descriptions/SKU-1001.md … SKU-1004.md
workspace/transcripts/call-1.md … call-5.md
workspace/translations/homepage.de.md
workspace/translations/homepage.es.md
workspace/translations/homepage.fr.md
```

Stichprobe `translations/homepage.de.md` — Markdown-Struktur erhalten, Ton
übertragen statt wörtlich übersetzt:

```markdown
# Northwind Analytics — Startseite

## Hero

**Hör auf zu raten. Fang an zu wissen.**

Northwind Analytics verwandelt deinen rohen Event-Stream in Entscheidungen, die
du im Board-Meeting verteidigen kannst. Eine Datenquelle in vier Minuten
angebunden, und dein erstes Dashboard ist fertig, bevor dein Kaffee kalt wird.

## Warum Teams umsteigen

- **Kein Warehouse nötig.** Gib uns deine App, dein CRM oder eine CSV. Das
  Modellieren übernehmen wir.
```

Stichprobe `descriptions/SKU-1002.md` — jede Zahl, jedes Material und jede
Farbe stammt aus der CSV, nichts ist dazuerfunden:

```markdown
# Kettle Peak Insulated Bottle

Stay hydrated wherever the trail takes you with the Kettle Peak insulated
bottle from the Drinkware range. Its matte sand finish and lightweight build
make it an easy companion, while the tough 18/8 stainless steel body keeps your
drinks exactly the way you like them for hours on end.

- 18/8 stainless steel construction in a matte sand finish
- Keeps drinks cold for 24h and hot for 12h
- Weighs just 410 g

**34,90 €**
```

Der Texter bleibt in der Sprache der Quelldaten. Willst du deutsche
Produkttexte, gehört das in den Task-Body oder in die `SOUL.md` des Profils —
nicht in die Hoffnung.

Auch ohne Abhängigkeiten hat jeder dieser Worker
`kanban_complete(summary=…, metadata=…)` aufgerufen. Sichtbar mit:

```bash
hermes kanban --board kanban-story-2 show <id> | grep -A3 "Latest summary"
```

Nützlich für Auswertungen — und unverzichtbar, sobald doch ein Task von einem
dieser Ergebnisse abhängt.

---

## Aufräumen

```bash
hermes kanban --board kanban-story-2 list --tenant content-ops --json \
  | jq -r '.[].id' \
  | xargs hermes kanban --board kanban-story-2 archive

./reset-workspace.sh
```

Alles entfernen:

⚠ **Vorher die Desktop App schließen** (oder im Board-Switcher auf `Default`
schalten). Solange sie dieses Board anzeigt, pollt der Zähler in der
Statusleiste es weiter — auch ohne offene Kanban-Seite — und legt es nach dem
Löschen innerhalb von 60 s als leeres Board neu an.

```bash
./teardown.sh                  # Board + Profile + Arbeitsdateien
./teardown.sh --keep-profiles  # Board + Arbeitsdateien
./teardown.sh --files-only     # nur Arbeitsdateien
```

`teardown.sh` entfernt ausschließlich Board `kanban-story-2` und die Profile
`translator`, `transcriber`, `copywriter`.

---

## Befehle dieser Story

| Befehl | Zweck |
|---|---|
| `hermes kanban create … --assignee <profil>` | Zuweisen (Profilname, nicht Person) |
| `… --tenant <name>` | Mandantenraum, praktisch als Filter |
| `… --workspace dir:<absoluter-pfad>` | Gemeinsames Arbeitsverzeichnis |
| `hermes kanban list --tenant <name> [--json]` | Board auflisten bzw. maschinenlesbar |
| `hermes kanban stats` | Zählwerte je Status und Assignee |
| `hermes kanban watch --kinds completed,blocked,gave_up` | Event-Stream des Boards |
| `hermes kanban dispatch --max N` | Spawns pro Tick begrenzen |
| `hermes gateway start` / `status` / `stop` | Normalbetrieb, alle Boards |
| `hermes kanban archive <id…>` | Aus der Ansicht nehmen |
