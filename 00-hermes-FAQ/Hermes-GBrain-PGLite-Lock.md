# Der PGLite-Lock bei GBrain-MCP-Aufrufen: Ursache und Auswege

**Stand:** 17.09.2026 · **Reine Analyse und Recherche, nichts umgesetzt.**

Gelesen am lokalen Quellcode der installierten Version
(`~/github/hermes-llm-wiki-gbrain/runtime/gbrain/`, Tag `668b9ba` =
**gbrain 0.50.5.0**) und an der installierten Hermes-Version
(`~/.hermes/hermes-agent/`). Dazu **read-only Messungen** am laufenden System:
Prozessliste, Lock-Datei, Profil-Konfiguration, alle Logs des Profils
`wiki-llm`.

**Nachtrag vom selben Tag:** Abschnitt 5 ist um den konkreten Umzugsweg
erweitert (Bereitstellung, Ablauf, Embeddings, der Bootstrap-Hook als Preis) —
gelesen an `migrate-engine.ts`, `docker-postgres.ts`,
`init-prefer-postgres.ts` und `skills/postgres-adopt/SKILL.md`. Dadurch sind
zwei Zeilen aus der Tabelle am Ende geschlossen.

Kein `gbrain`-Unterbefehl wurde ausgeführt. Jeder davon öffnet die Engine und
hätte genau den Zustand zerstört, der hier vermessen wird — oder den Fehler
selbst ausgelöst. Der laufende Halter wurde **nicht** beendet.

**Ausgangsfrage:** Bei MCP-Aufrufen aus Hermes Desktop erscheint wieder der
PGLite-Lock-Fehler. Wie löst man das grundlegend? Gibt es andere
DB-Anbindungen? Wäre SQLite denkbar — oder hätte es dieselben Konflikte?

Vorgeschichte: Die Designschranke und der erste Vorfall stehen in
[`Hermes-GBrain-LLM-Wiki-Installation.md`](Hermes-GBrain-LLM-Wiki-Installation.md)
— Abschnitt 3 („Eine harte Designschranke"), die Betriebsanweisung in
Abschnitt 0 („Die Lock-Falle"), der Vorfall selbst in Abschnitt 6 („Der
Lock-Vorfall"). Dieses Dokument wiederholt das nicht, sondern geht auf die
Ebene darunter: **warum** es passiert und **was es dagegen gibt**.

---

## ⚠ Vorab: die heutige Meldung steht in keinem Log

Bevor irgendeine Ursachenzuordnung trägt, gehört dieser Befund an den Anfang.
Durchsucht wurden `mcp-stderr.log`, `agent.log`, `errors.log` und `gui.log` des
Profils `wiki-llm` sowie `~/.hermes/logs/`:

| | Befund |
|---|---|
| Lock-Meldung am **16.09.** | ✅ 16 Vorkommen, 21:38 bis 21:50, alle in `mcp-stderr.log`, alle mit PID 35816 |
| Lock-Meldung am **17.09.** | ❌ **kein einziges Vorkommen**, in keiner der vier Logdateien |
| GBrain-MCP-Aufrufe am 17.09. | ✅ alle erfolgreich — `get_stats`, `sources_list`, `list_pages`, `get_page`, `get_tags`, je 0,01–0,16 s |
| Fehler bei GBrain-Aufrufen heute | nur `page_not_found` und eine Enum-Validierung (`sort: 'created_asc'`) — **keine** Lock-Fehler |
| Server-Starts heute | 08:20:05, 08:20:12, 09:47:52 sauber beendet; 09:55:20 läuft |
| Andere Clients am selben Brain | keine — `.gbrain/integrations/` ist leer, keine `.mcp.json`, keine Claude-Code-Verdrahtung |

**Das heißt:** Was hier beschrieben wird, ist der Mechanismus des Vorfalls vom
**16.09.** Ob die heutige Meldung derselben Ursache entspringt, ist **nicht
belegt**. Sie kann aus einer anderen Oberfläche, einem anderen Profil oder dem
Terminal stammen — oder aus der Kollisionsform 2b unten, die in diesen Logs
gar nicht erscheinen würde.

Für die eigentlichen Fragen (DB-Anbindungen, SQLite, Auswege) ist das
folgenlos: Die Schranke ist dieselbe, egal welche der beiden Kollisionsformen
zugeschlagen hat. Für die Diagnose des konkreten Vorfalls ist es der
entscheidende Punkt — siehe Abschnitt 8.

---

## Die Kurzfassung

1. **Es gibt zwei Kollisionsformen, aber nur eine Schranke.** PGLite erlaubt
   genau eine Verbindung. Kollidieren kann (a) ein **zweiter Serverstart**,
   während ein alter `gbrain serve` noch lebt, und (b) ein **CLI-Aufruf aus
   einem Skill heraus**, während der eigene MCP-Server läuft. Form (a) ist am
   16.09. belegt; Form (b) ist in dieser Installation strukturell angelegt und
   bislang nicht beobachtet.
2. **Es gibt genau zwei DB-Anbindungen: `pglite` und `postgres`** — mehr kennt
   die Engine-Fabrik nicht. Ein Umzug auf Postgres ist ein mitgelieferter
   Befehl (`gbrain migrate --to supabase`) und **entfernt diese Fehlerklasse**,
   weil die Lock-Schicht ausschließlich vom PGLite-Pfad aufgerufen wird.
3. **SQLite ist ausgeschlossen** — explizit im Code abgewiesen, und das Schema
   ist so tief Postgres-spezifisch (pgvector, HNSW, `tsvector`, PL/pgSQL), dass
   es eine Neuimplementierung wäre, keine Migration.
4. **Der pragmatische Zwischenschritt** ist ein einziger langlebiger
   `gbrain serve --http`, an den Hermes sich per `url:` anhängt statt einen
   eigenen Prozess zu starten. Das entschärft **beide** Kollisionsformen. Beide
   Seiten können es nachweislich — im selben Profil läuft bereits ein
   MCP-Server auf diesem Weg.

---

## 1. Was der Fehler wörtlich sagt

Der exakte Wortlaut, wie er im MCP-Log steht
(`~/.hermes/profiles/wiki-llm/logs/mcp-stderr.log`, gemessen):

> GBrain's local database is already open through `gbrain serve` (MCP, PID
> 35816). This brain uses PGLite, so a separate CLI process cannot open it at
> the same time. […] A process with the recorded PID is still running, so
> GBrain will not remove
> `…/.gbrain/brain.pglite/.gbrain-lock` automatically.

Quelle: `pglite-lock.ts:584` wirft `LiveServeLockError`, eine Unterklasse von
`PgliteBusyError` (`code = 'pglite_busy'`, `pglite-lock.ts:30-38`).

Der Modulkopf nennt den Grund unverblümt (`pglite-lock.ts:4-7`):

> PGLite uses embedded Postgres (WASM) which only supports **one connection at
> a time**.

Das ist keine Konfigurationsfrage. Es ist die Eigenschaft der Engine.

Bemerkenswert am Wortlaut: Er ist **für einen CLI-Aufrufer geschrieben** („for
other CLI write commands, stop `gbrain serve` and retry"). Das passt auf
Kollisionsform 2b besser als auf 2a — der Text ist dieselbe Ausnahme, die beide
Fälle wirft.

---

## 2a. Kollisionsform 1: ein Serverstart zu viel (belegt, 16.09.)

### Hermes startet jedes Mal einen neuen Server

Die Verdrahtung im Profil (`~/.hermes/profiles/wiki-llm/config.yaml:610-615`):

```yaml
  gbrain:
    command: /Users/aknipschild/github/hermes-llm-wiki-gbrain/bin/gbrain
    args:
      - serve
    connect_timeout: 60.0
    enabled: true
```

`command:` bedeutet **stdio**: Hermes forkt den Prozess selbst, für jede
Sitzung neu. Real gemessen, die aktuell lebende Kette:

```
73664  Hermes.app (Desktop, Electron)
 └ 87899  python -m hermes_cli.main --profile wiki-llm serve --host 127.0.0.1 --port 0
    ├ 88062  bun … runtime/gbrain/src/cli.ts --brain host serve   ← der Lock-Halter
    └ 88067  python tools/mcp_death_supervisor.py --parent-pgid 73664
```

Und die Lock-Datei selbst, `…/brain.pglite/.gbrain-lock/lock`, gemessen:

```json
{"pid":88062,"acquired_at":1789631720837,"refreshed_at":1789631750844,
 "command":"…/src/cli.ts --brain host serve","subcommand":"serve", … }
```

Nur ein Profil ist betroffen: Von allen `~/.hermes/profiles/*/config.yaml`
trägt **allein** `wiki-llm` einen `gbrain`-Eintrag. Mehrere Hermes-Profile
gleichzeitig sind also **nicht** die Ursache.

### Das Log zeigt das Muster — und den Ausreißer

`mcp-stderr.log`, gemessen. Der Normalfall ist ein Paar aus Start und
sauberem Abbau:

```
===== [2026-09-16 21:25:11] starting MCP server 'gbrain' =====
Starting GBrain MCP server (stdio)...
[gbrain-serve] shutdown: stdin end          ← sauber beendet
```

Am 16.09. um 21:31:48 fehlt diese dritte Zeile. Der Prozess **35816** blieb am
Leben. Ab 21:38:48 sieht jeder weitere Start so aus:

```
===== [2026-09-16 21:38:48] starting MCP server 'gbrain' =====
GBrain's local database is already open through `gbrain serve` (MCP, PID 35816)…
```

Sechzehnmal derselbe Satz, immer dieselbe PID. **Ein einziger nicht
abgeräumter Prozess legt die Integration still, bis jemand ihn von Hand
findet.**

### Warum sich das nicht von selbst löst

Das ist eine bewusste Entscheidung, dokumentiert in `pglite-lock.ts:53-72`
(Issue #2348):

> there is **NO steal-on-stale-heartbeat anymore**. A holder whose PID is alive
> AND still the same program is **NEVER** reaped, regardless of how long its
> heartbeat has been stale.

Begründet mit Datenverlust: Ein `embed`-Lauf blockiert die Event-Loop, sein
Heartbeat sieht tot aus, obwohl er arbeitet. Das frühere Zeitfenster ließ einen
zweiten Prozess dasselbe Verzeichnis öffnen und zerstörte Katalog und
pgvector-Zustand („recoverable only by wipe+restore").

Abgeräumt wird also nur bei **affirmativem Todesbeweis**: `ESRCH` aus `kill 0`,
oder eine Kommandozeile, die PID-Recycling durch ein Nicht-GBrain-Programm
beweist (`pglite-lock.ts:570-573`). Ein **hängender, aber lebender** Halter
fällt durch beide Raster. Der wartende Prozess läuft in den Timeout — Default
30 s, `pglite-lock.ts:553` — und gibt auf.

Für `serve`-Halter gibt es nicht einmal den Timeout: Die Klassifikation
`isServeCommand` (`pglite-lock.ts:40-52`) führt sofort zum Abbruch mit der
obigen Meldung, ohne Wartezeit.

### Nebenbefund: `postmaster.pid` ist als Diagnose unbrauchbar

Die bisherige Betriebsanweisung empfiehlt einen Blick auf
`brain.pglite/postmaster.pid`. Deren Inhalt, gemessen:

```
-42
/pglite/data
1789631720
5432
```

PID `-42`, Datenverzeichnis `/pglite/data` — beides Platzhalter, die das
WASM-Postgres schreibt, nicht die Realität. Die Datei taugt als Ja/Nein-Indiz,
dass irgendwann jemand da war; **wer** hält, steht ausschließlich in
`.gbrain-lock/lock`. Das gehört in das Diagnose-Rezept (Abschnitt 8).

---

## 2b. Kollisionsform 2: der Agent kollidiert mit sich selbst

Diese Form erklärt „bei MCP calls" besser als 2a — und sie hinterlässt in
`mcp-stderr.log` **keine Spur**, weil kein Serverstart scheitert.

Der Aufbau, der sie ermöglicht (beides gemessen):

```yaml
# ~/.hermes/profiles/wiki-llm/config.yaml:367-369
skills:
  external_dirs:
    - ~/github/hermes-llm-wiki-gbrain/skills
```

```json
// ~/github/hermes-llm-wiki-gbrain/.gbrain/config.json
"mcp": { "publish_skills": true }
```

Damit sind GBrains eigene Skills im Profil aktiv (laut Installationsdoku 111
lokale Skills). Und diese Skills weisen den Agenten an, die **CLI** zu
benutzen. Zwei Beispiele im Original:

```
skills/capture/SKILL.md:51      gbrain capture "the thought I want to remember"
skills/book-mirror/SKILL.md:46  book-mirror runs as a CLI command (`gbrain book-mirror`),
                                NOT as a pure [MCP call]
```

Führt der Agent das über sein Terminal-Werkzeug aus, während sein **eigener**
`gbrain serve` den Lock hält, dann kollidiert er mit sich selbst. Der Fehler
erscheint dann als Ergebnis eines Terminal-Aufrufs mitten im Gespräch — also
an derselben Stelle wie ein fehlgeschlagener Werkzeugaufruf, und leicht als
solcher zu lesen.

> Ob Hermes Desktop die beiden in der Oberfläche unterscheidbar darstellt, ist
> **nicht geprüft**: `gui.log` protokolliert keine Werkzeugdarstellung. In
> `agent.log` sind sie klar getrennt (`tool terminal` gegen
> `tool mcp__gbrain__…`) — was die Oberfläche daraus macht, steht dort nicht.

Genau davor warnt die Installationsdoku bereits unter „Weg 3 — die CLI über das
Terminal-Werkzeug". Neu ist hier nur: **Die Skills fordern diesen Weg aktiv
ein**, der Agent wählt ihn also nicht aus Versehen.

Was dagegen spricht, dass es heute so war: In `agent.log` liefen am 17.09. 14
Terminal-Aufrufe, alle erfolgreich bis auf einen Timeout wegen fehlender
Zustimmung. Ein Lock-Fehler ist nicht darunter. Die Form ist **strukturell
belegt, im Betrieb aber nicht beobachtet.**

Der MCP-Server selbst ruft die CLI nicht auf — `src/mcp/` enthält keinen
einzigen `Bun.spawn`, `execFile` oder `child_process`. Die Kollision entsteht
ausschließlich über den Agenten als Zwischenschritt.

---

## 3. GBrain hat eine IPC-Schicht — sie löst dieses Problem aber nicht

Im Datenverzeichnis liegen `.gbrain-resolve.sock` und `.gbrain-ipc-secret`.
Dahinter steht eine echte Delegations-Architektur: Ein laufender `serve` lauscht
auf einem Unix-Socket und beantwortet Anfragen **mit der Verbindung, die er
ohnehin besitzt**, statt dass ein zweiter Prozess eine eigene aufmacht
(`context/resolve-ipc.ts:1-47`).

Der Haken: Es ist bewusst **keine generische** Datenbankschicht. Der Kopf des
Moduls listet die erlaubten Anfragearten abschließend auf:

| `kind` | wofür |
|---|---|
| `resolve` | Retrieval-Reflex, Pointer-Blöcke |
| `turn_context` | Kontextfenster pro Gesprächsschritt |
| `sync_start` / `sync_status` / `sync_abort` | serve-delegiertes `gbrain sync` |
| `sweep_start` / `sweep_status` | serve-delegierte Wartung |

Ausdrücklich: „raw SQL never crosses the wire (closes the trust hole)".

Deshalb steht in der Fehlermeldung auch nur `gbrain sync` als Ausnahme. Für
Kollisionsform 2b heißt das: `gbrain capture` oder `gbrain book-mirror` haben
**keinen** Delegationspfad — sie scheitern hart. Und ein zweiter MCP-Server
(Form 2a) kann darüber erst recht nichts ausrichten; seine 137 Werkzeuge sind
in dieser Liste nicht vorgesehen.

Die IPC-Schicht rettet vier Sonderfälle, nicht das Grundproblem.

---

## 3a. Was das für `gbrain sweep` heißt — und der PATH-Eintrag (17.09.2026)

Nachgetragen am 17.09.2026, nachdem beim Anlegen einer Wiki-Notiz zwei Hinweise
kamen und das Modell im Chat meldete, es könne `gbrain sweep --once` nicht
anstoßen: `which gbrain` → Exit 1.

**Die vier Sonderfälle aus Abschnitt 3 sind genau die, die hier gebraucht
werden.** `sweep_start`/`sweep_status` steht in der Tabelle oben, und der
CLI-seitige Gegenpart ist ausgebaut: `commands/sweep-delegate.ts` (Kopf, #677)

> „On a PGLite brain a live `gbrain serve` holds the single-writer lock for its
> lifetime, so `gbrain sweep --once` used to exit 1 with LiveServeLockError. The
> pre-connect hook in cli.ts calls maybeDelegateSweepToServe: when the holder is
> a live serve, the sweep runs INSIDE the serve over the resolve-IPC socket
> (sweep_start / sweep_status) … and this module polls to completion and prints
> the report."

`gbrain sweep --once` läuft also **auch bei laufendem Server** — es öffnet die
Datenbank nicht selbst, sondern lässt den Lock-Halter arbeiten. `--no-delegate`
schaltet das ab und scheitert dann erwartungsgemäß am Lock.

Die Voraussetzungen sind an der laufenden Installation nachgesehen (read-only,
17.09. 16:30):

| | Befund |
|---|---|
| Socket | `.gbrain/brain.pglite/.gbrain-resolve.sock` vorhanden, 16:27 angelegt |
| Geheimnis | `.gbrain-ipc-secret`, Modus 0600 |
| Lock-Halter | `.gbrain-lock/`, PID 33681 = `bun … runtime/gbrain/src/cli.ts` unter dem `hermes --profile wiki-llm serve` (PID 33392) |

**Nicht delegiert** sind alle übrigen Unterbefehle — `gbrain sources add
--path`, `capture`, `extract`, `migrate`. Die brauchen den Lock selbst und
laufen nur, wenn **kein** `serve` lebt (Hermes zu).

### Der PATH-Eintrag

`~/github/hermes-llm-wiki-gbrain/bin/gbrain` lag in keinem PATH-Verzeichnis.
Ergänzt als **Wrapper** unter `~/.local/bin/gbrain` — angelegt von `setup.sh`
des Wiki-Repos (Schritt 7/7, idempotent; Ziel über `HERMES_WIKI_BIN_DIR`
umlenkbar, leer gesetzt übersprungen, ein fremdes `gbrain` im PATH wird erkannt
und nicht überschrieben):

```bash
#!/usr/bin/env bash
# hermes-llm-wiki-gbrain: PATH-Wrapper (von setup.sh erzeugt)
exec "/Users/aknipschild/github/hermes-llm-wiki-gbrain/bin/gbrain" "$@"
```

Bewusst kein Symlink: der Launcher leitet `GBRAIN_HOME` aus
`"$(dirname "${BASH_SOURCE[0]}")/.."` ab, und `BASH_SOURCE` löst Symlinks
**nicht** auf — über einen Symlink in `~/.local/bin` wäre `GBRAIN_HOME`
also `~/.local`, und der Launcher bräche mit „GBrain-Laufzeit fehlt" ab.

`~/.local/bin` liegt in beiden PATHs: in dem der interaktiven Shell und in dem,
den Hermes' `terminal`-Werkzeug sieht (nachgesehen im Umgebungs-Schnappschuss
der laufenden Sitzung, `/var/folders/…/hermes-snap-*.sh`). Das ist nicht
selbstverständlich — Hermes liest für diesen Schnappschuss `~/.profile`,
`~/.bash_profile` und `~/.bashrc` (`tools/environments/local.py:600-618`),
**nicht** die zsh-Dateien des Nutzers. Ein PATH-Eintrag, der nur in `~/.zshrc`
steht, erreicht den Agenten deshalb nie.

Hier hält es doppelt: alle drei Dateien existieren und setzen `~/.local/bin`
jeweils selbst (`~/.profile:10`, `~/.bash_profile:9`, `~/.bashrc:3`) — der
Eintrag hängt also nicht allein an der ererbten Umgebung des Desktop-Prozesses.

Profil-eng ginge auch: `~/.hermes/profiles/wiki-llm/bin/` liegt ebenfalls im
Schnappschuss-PATH (dort wohnt `tirith`). Ein Eintrag reicht; der globale ist
gewählt, weil der echte, nicht delegierbare Wartungslauf ohnehin in der eigenen
Shell bei geschlossenem Hermes stattfindet.

Geprüft mit `gbrain --version` → `gbrain 0.50.5.0`, auch aus dem
Umgebungs-Schnappschuss des Agenten heraus. `--version` öffnet die Engine nicht
und fasst den Lock nicht an; kein weiterer Unterbefehl wurde ausgeführt.

### Die beiden Hinweise aus dem Chat

**`auto_links: skipped: remote`** — Schreibzugriffe über MCP gelten als
„untrusted writer", die Wikilinks im Rumpf werden als Text gespeichert und
nicht in den Graph überführt (`core/ops/pages.ts:337`). Der Nachtrag passiert
von selbst, weil dieser Brain per **stdio** bedient wird:

- **beim Start** — `armStartupSweep`, rund 3 s nach dem Verbinden
  (`mcp/server.ts:342-356`),
- **im Leerlauf** — Tick alle 10 min, gefeuert wird nach 10–20 min echter
  Untätigkeit (`commands/serve.ts:59, 650-711`), Budget 3 s. Abschalter:
  `GBRAIN_SWEEP=0`.

Nur `gbrain serve --http` fegt nicht selbst — dort wäre der manuelle Lauf
Pflicht. Praktisch heißt das: **ein Hermes-Neustart ist selbst schon ein
Sweep.**

**`write_through: no_repo_configured`** — die Quelle `default` hat kein
`local_path`/Repo, die Seite lebt also nur als PGLite-Zeile, ohne dauerhafte
Markdown-Datei (`core/write-through.ts:337`, Vertrag in `:75-90`). Das ist die
Kehrseite des Kernkonzepts aus
[`Hermes-GBrain-LLM-Wiki-Installation.md`](Hermes-GBrain-LLM-Wiki-Installation.md):
GBrain aggregiert registrierte Quellen lesend — was **neu** im Chat entsteht,
braucht eine eigene, an ein Verzeichnis gebundene Quelle, sonst gibt es keine
Datei. Das Binden (`gbrain sources add …  --path …`) ist **nicht** delegiert und
geht deshalb nur bei geschlossenem Hermes. Hier bewusst nicht ausgeführt.

---

## 4. Hermes' eigene Gegenmaßnahme — und ihre Lücke

Hermes kennt das Problem verwaister stdio-Server und hat einen Wächter dafür,
`tools/mcp_death_supervisor.py` (im Prozessbaum oben als PID 88067 sichtbar).
Sein Kopfkommentar beschreibt genau den Fall:

> When Hermes dies without running its cleanup path (SIGKILL, OOM killer, a hard
> crash), stdio MCP servers it spawned are reparented to init and keep running
> forever. macOS has no `PR_SET_PDEATHSIG`, so something has to outlive Hermes
> and reap them.

Der Wächter hält ein Pipe-Ende; stirbt Hermes, liefert der Read EOF, und er
`killpg`t alle noch registrierten Prozessgruppen.

**Was er abdeckt:** Hermes stirbt hart.
**Was er nicht abdeckt:** Hermes lebt weiter, aber der `gbrain serve` reagiert
nicht mehr auf das stdin-EOF. Dann meldet Hermes den Server sauber ab
(`unregister`), der Wächter fasst ihn nie an — und der Prozess hält den Lock
weiter. Genau dieses Profil hat der Vorfall vom 21:31:48.

Gegen Kollisionsform 2b hilft er gar nicht — dort ist nichts verwaist.

---

## 5. Welche DB-Anbindungen es gibt

### Genau zwei

`core/engine-factory.ts` ist die einzige Stelle, an der eine Engine entsteht:

```ts
const engineType = config.engine || 'postgres';        // :10
switch (engineType) {
  case 'pglite':   { … new PGLiteEngine(); }           // :14
  case 'postgres': { … new PostgresEngine(); }         // :18
  default: throw new Error(
    `Unknown engine type: "${engineType}". Supported engines: postgres, pglite.` +   // :24
    (engineType === 'sqlite' ? ' SQLite is not supported. Use pglite instead.' : '') // :25
  );
}
```

Bemerkenswert an Zeile 10: **Postgres ist der Default.** Die `package.json`
beschreibt GBrain als „Postgres-native personal knowledge brain"; die
Installationsleiter `init --prefer-postgres` steigt über fünf Stufen ab und
erreicht PGLite erst ganz unten (`commands/init-prefer-postgres.ts:7-25`):

| Stufe | Bedingung |
|---|---|
| 1 `env_url` | `GBRAIN_DATABASE_URL` / `DATABASE_URL` gesetzt |
| 2 `supabase_token` | `SUPABASE_ACCESS_TOKEN` (+ ggf. `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`) |
| 3 `local_postgres` | erreichbarer Server **mit pgvector**; `CREATE DATABASE` nur mit `--allow-create-db` |
| 4 `docker` | nur mit `--allow-docker`; GBrains eigenes pgvector-Image |
| 5 `pglite` | terminal — der Boden, nicht das Ziel |

**PGLite ist der Kompatibilitätsboden, nicht die vorgesehene Betriebsform.**
Diese Installation steht auf Stufe 5 (`.gbrain/config.json`:
`"engine": "pglite"`).

### Der Umzug ist ein mitgelieferter Befehl

`commands/migrate-engine.ts:1-8`:

```
gbrain migrate --to supabase [--url <connection_string>]
gbrain migrate --to pglite  [--path <db_path>]
gbrain migrate --to <engine> --force   # nicht-leeres Ziel überschreiben
```

`--to supabase` wird intern auf `postgres` abgebildet (`migrate-engine.ts:41`)
— jede pgvector-fähige Postgres-URL ist damit ein gültiges Ziel, nicht nur
Supabase.

#### Zwei Wege, die man nicht verwechseln darf

| | `init --prefer-postgres` | `migrate --to supabase --url <conn>` |
|---|---|---|
| für | **neues** Brain | **bestehendes** Brain |
| Postgres bereitstellen | ja, über die Leiter | **nein** — verlangt eine fertige URL |
| bei vorhandenem Brain | **verweigert** | der vorgesehene Weg |

`runPreferPostgresLadder` weigert sich ausdrücklich, über ein konfiguriertes
Brain zu laufen (`init-prefer-postgres.ts:159-175`). Begründung im Quelltext:
Ein temporär nicht erreichbarer Postgres fiele durch alle fünf Sprossen, und
der PGLite-Boden überschriebe die `config.json` — *„orphaning the whole brain
because of an OUTAGE"*. Die Fehlermeldung nennt selbst den Ersatzweg:

```
Move PGLite → PG:   gbrain migrate --to supabase --url <conn>  (the postgres-adopt skill walks it)
```

**Konsequenz für diese Installation: Der Postgres muss von Hand hingestellt
werden.** `migrate` provisioniert nichts.

#### Die Docker-Sprosse — was sie anlegen würde

Auch wenn sie hier nicht greift, ist sie die Vorlage für die Handarbeit
(`core/docker-postgres.ts`):

| | |
|---|---|
| Image | **`pgvector/pgvector:pg16`** |
| Container | **`gbrain-postgres`** |
| Volume | `gbrain-pgdata` (benannt — ein Recreate verliert das Brain nicht) |
| Port | **`127.0.0.1:5434:5432`** — *„a single-machine brain store, not a network service"* |
| Neustart | `--restart unless-stopped` |
| Passwort | über die **Umgebung**, nie über argv (*„argv is world-readable in `ps`"*) |
| Erster Lauf | zieht das Image, deshalb 10 min Zeitlimit statt 30 s |

**Eigentumsvertrag** (Modulkopf): gbrain startet und benutzt den Container
wieder, aber *„it NEVER stops or removes it"* — und fasst keinen Container an,
dessen Zugangsdaten es nicht per `docker inspect` belegen kann.

Von Hand, nach derselben Konvention — wichtig, damit `db-repair` den Container
später als seinen erkennt (`isGbrainDockerUrl` prüft auf Loopback **und** Port
5434):

```bash
POSTGRES_PASSWORD=$(openssl rand -hex 16) \
docker run -d --name gbrain-postgres --restart unless-stopped \
  -e POSTGRES_PASSWORD \
  -v gbrain-pgdata:/var/lib/postgresql/data \
  -p 127.0.0.1:5434:5432 \
  pgvector/pgvector:pg16
```

Die URL, die gbrain selbst bauen würde (`init-prefer-postgres.ts:309`):

```
postgresql://postgres:<passwort>@localhost:5434/postgres
```

Stand auf diesem Rechner (gemessen 17.09.2026): Docker **29.1.3 vorhanden**,
Container und Image **nicht**, lokaler Postgres/pgvector **nicht**.

#### Der Ablauf der Migration

`migrate-engine.ts`, in dieser Reihenfolge:

1. **Autopilot stilllegen** — vor allem anderen. Die Pause-Markierung ist
   zugleich der Mutex gegen eine zweite Migration. Ohne sie bricht der Lauf ab:
   *„a daemon this migration cannot pause keeps writing into the source engine,
   and those writes are lost at the flip."*
2. Ziel verbinden, `initSchema()`.
3. **Manifest** laden. Ein Teilabbruch lässt dich auf PGLite und endet mit
   Exit ≠ 0; derselbe Befehl nochmal setzt fort. Zeigt das Manifest auf ein
   anderes Ziel, beginnt der Lauf frisch.
4. Nicht-leeres Ziel ist geschützt; `--force` löscht es (`DELETE FROM pages`,
   kaskadiert über die Fremdschlüssel).
5. Kopieren: Seiten, Chunks **mitsamt Embeddings** (`copyPageToTarget:521-528`),
   Fakten, Links, Tags, Timeline, Konfiguration.
6. **Config-Flip nur bei komplett sauberem Lauf** (`Config updated to engine:
   postgres`).
7. Das alte `brain.pglite/` **bleibt als Backup liegen**.
8. Verifikation: Seitenzahl, Timeline-Zeilen, Embedding-Abdeckung,
   Schema-Version. Unter 90 % Abdeckung folgt der Hinweis
   `gbrain embed --stale`.

**Die Embeddings werden übertragen, nicht neu berechnet.** Fakten-Embeddings
gehen über `embedding::text::<typ>`; scheitert der Cast (Dimensions-Mismatch),
wird die Zeile mit `embedding NULL` übernommen und in `embeddings_dropped`
gezählt — verloren geht nichts, es wäre nur neu einzubetten. Damit ist die
frühere Vermutung „ein Neu-Embedding ist nicht vorgesehen" positiv bestätigt.

#### Der Umzug braucht den Lock noch einmal

`migrate` bekommt die Quell-Engine bereits verbunden (`cli.ts:3088`), läuft
also durch `connectEngine()` → `acquireLock` auf PGLite. Solange ein
MCP-`serve` aus Hermes Desktop lebt, scheitert die Migration an
`LiveServeLockError` (Kollisionsform 2a). Die Desktop-Sitzung muss vorher
beendet sein — ausgerechnet der Umzug, der den Lock beseitigt, braucht ihn ein
letztes Mal.

### Warum Postgres diese Fehlerklasse beseitigt

Das ist der entscheidende Beleg. `acquireLock` wird im gesamten Quellbaum an
genau **zwei** produktiven Stellen gerufen:

```
core/pglite-engine.ts:727     this._lock = await acquireLock(dataDir);
commands/pglite-repair.ts:226 lock = await acquireLock(dataDir, { timeoutMs: 5_000 });
```

(Die Treffer in `sync-failure-ledger.ts` und `skillpack/installer.ts` sind
gleichnamige lokale Funktionen für andere Zwecke.)

Der `PostgresEngine` fasst die Dateisperre **nie** an. Ein echter
Postgres-Server ist ein Mehrverbindungs-Server: Beliebig viele `gbrain
serve`-Instanzen, CLI-Aufrufe und Cron-Jobs können gleichzeitig verbunden sein.
`LiveServeLockError` kann dort nicht auftreten — **beide** Kollisionsformen
verschwinden, und mit ihnen der Cron-Konflikt mit `embed`/`dream` aus
Abschnitt 3 der Installationsdoku.

**Präzisierung, damit die Aussage nicht zu weit trägt:** Lock-frei wird GBrain
damit nicht. `core/db-lock.ts` ist ein **engine-agnostisches** Sperrprimitiv —
eine Zeile in der Tabelle `gbrain_cycle_locks` mit `holder_pid` und
`ttl_expires_at`, mit eigenen Zweigen für `engine.kind === 'postgres'` (:234)
und `'pglite'` (:302). Es serialisiert `gbrain-cycle` und `gbrain-sync` und gilt
auf Postgres genauso. Der Unterschied ist die Natur der Sperre:

| | PGLite-Dateisperre | `db-lock.ts` |
|---|---|---|
| Granularität | ganzes Datenverzeichnis | eine benannte Operation |
| Dauer | Lebensdauer des Prozesses | Dauer des Schreibfensters |
| Bei totem Halter | kein Selbstheilen (#2348) | TTL läuft ab |
| Auf Postgres aktiv | **nein** | ja |

Was verschwindet, ist der Prozess-Ausschluss. Was bleibt, ist gewöhnliche
Transaktionsarbeit mit Zeitüberschreitung. Genau das ist der Gewinn.

Das ist die Antwort auf „grundlegend lösen".

---

## 6. SQLite — die Frage in drei Teilen

### a) Wird es unterstützt? Nein, und zwar ausdrücklich

`engine-factory.ts:25` behandelt `sqlite` als eigenen Sonderfall im
Fehlertext — jemand hat die Frage erwartet und beantwortet:
„SQLite is not supported. Use pglite instead."

### b) Wäre eine Migration denkbar? Es wäre eine Neuimplementierung

Das Schema (`src/schema.sql`, 1670 Zeilen) beginnt mit:

```sql
-- GBrain Postgres + pgvector schema
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Was davon tragend ist und in SQLite kein Gegenstück hat:

| Konstrukt | Beleg | in SQLite |
|---|---|---|
| `vector(1536)`, `vector(1024)` Spalten | `schema.sql:302, 328, 331` | fehlt — nur über Fremd-Erweiterungen |
| HNSW-Index `USING hnsw (embedding vector_cosine_ops)` | `schema.sql:336, 343` | fehlt |
| Volltext über `tsvector` + `setweight`/`to_tsvector`, gewichtet A/B/C | `schema.sql:993, 1004-1028, 362-376` | anderes Modell (FTS5), keine Gewichtungssemantik |
| 6 PL/pgSQL-Funktionen mit Triggern | `grep -c "CREATE OR REPLACE FUNCTION"` → 6 | keine prozedurale Sprache |
| `JSONB` inkl. `jsonb_typeof`-CHECKs, `jsonb_array_elements_text` | `schema.sql:755-759, 811-813` | JSON als Text, andere Funktionsnamen |
| `pg_trgm` für Fuzzy-Matching | `schema.sql:4` | fehlt |

Dazu kommt der Engine-Code selbst: `postgres-engine.ts` ist 274 KB,
`pglite-engine.ts` 6123 Zeilen — beide sprechen Postgres-Dialekt. Eine
SQLite-Anbindung hieße: dritte Engine schreiben, hybride Suche neu bauen,
Vektorsuche extern lösen. Das ist kein Konfigurationsschalter und kein
Migrationsziel, sondern ein Produktprojekt. Bei einem Upstream-Projekt mit
diesem Änderungstempo wäre es außerdem ein Fork, den man dauerhaft nachzieht.

### c) Hätte SQLite dieselben Lock-Konflikte?

**Die konkrete Fehlerklasse nicht — ein Rest bliebe.** Zur Einordnung, nicht
als GBrain-Befund:

PGLite sperrt **prozessexklusiv auf Datenverzeichnisebene**, für die gesamte
Lebensdauer der Verbindung: eine Verbindung, ein Prozess, alles andere fliegt
raus. SQLite sperrt **pro Transaktion** und erlaubt im WAL-Modus prozess-
übergreifend viele Leser parallel zu einem Schreiber. Ein zweiter MCP-Server könnte
also lesen, während der erste läuft — der heutige Fehler „Datenbank ist
belegt, solange irgendein Server lebt" entstünde nicht.

Geblieben wäre: Schreibvorgänge serialisieren weiterhin, und ein langer
Schreiber (das SQLite-Gegenstück zu `gbrain embed`) ließe andere Schreiber in
`SQLITE_BUSY` laufen. Statt eines harten Ausschlusses gäbe es Wartezeiten und
Timeouts.

Praktisch ist der Punkt allerdings **gegenstandslos**, weil (a) und (b) den Weg
versperren. Und: Genau diesen Gewinn — viele gleichzeitige Verbindungen —
liefert der **Postgres**-Pfad heute schon, mitgeliefert und ohne Fork.

> Dieser Abschnitt ist architektonische Einordnung aus den Sperrmodellen beider
> Systeme, **nicht am GBrain-Code gemessen** — es gibt dort keinen
> SQLite-Code zu messen. Er steht entsprechend in der Tabelle am Ende.

---

## 7. Die Auswege, bewertet

### A — Ein einziger langlebiger `gbrain serve --http`, Hermes hängt sich an

**Die Idee:** Statt dass jede Hermes-Sitzung einen eigenen Prozess forkt, läuft
**ein** GBrain-Server dauerhaft und bedient alle Clients über HTTP.

Beide Seiten können das nachweislich:

*GBrain-Seite* — `cli.ts:3983`:

```
serve --http [--port N]            HTTP MCP server with OAuth 2.1
  --token-ttl N                    Access token TTL in seconds (default: 3600)
  --public-url URL                 Public issuer URL (required behind proxy/tunnel)
connect <mcp-url> --token <t>      Wire Claude Code to a remote gbrain (bearer token)
auth <create|list|revoke|...>      Manage legacy tokens + OAuth 2.1 clients
```

Dazu ein eigener Rate-Limiter (`mcp/rate-limit.ts`) und ein
Legacy-Bearer-Transport (`mcp/http-transport.ts`) — der Mehrklient-Betrieb ist
die vorgesehene Betriebsform dieses Modus, nicht ein Nebenweg.

*Hermes-Seite* — `tools/mcp_tool_transport.py` implementiert
`streamablehttp_client` (`:363-388`) und `sse_client` (`:339-361`), mit
`headers`, `oauth`, `ssl_verify` und Client-Zertifikaten (`:399-412`).

*Der beste Beleg steht im selben Profil:* Direkt über dem `gbrain`-Eintrag
läuft bereits ein MCP-Server auf genau diesem Weg
(`~/.hermes/profiles/wiki-llm/config.yaml:607-609`):

```yaml
  uwwb:
    url: http://localhost:3001/api/agent-runtime/mcp
    enabled: true
```

Und dieser Eintrag zeigt nebenbei, wie robust der Weg ist. `uwwb` war heute
nicht erreichbar; Hermes reagierte so (`agent.log`, gemessen):

```
WARNING tools.mcp_tool: MCP server 'uwwb' failed initial connection after 3 attempts,
        parking until a reconnect is requested (state: connecting → parked)
```

**Geparkt statt kaputt** — ein URL-Server, der gerade nicht läuft, kostet die
Sitzung nichts und wird später wieder eingesammelt. Ein stdio-Server, der nicht
startet, ist für die ganze Sitzung weg. Das ist ein eigenständiges Argument für
diesen Weg, unabhängig vom Lock.

Der `gbrain`-Eintrag müsste von `command:`/`args:` auf `url:` (plus `headers:`
oder `oauth:`) umgestellt werden, und der Server selbst außerhalb von Hermes
laufen — z. B. als `launchd`-Dienst.

| | |
|---|---|
| **Löst Form 2a** | vollständig. Es gibt strukturell nur noch einen Halter, also niemanden, der beim Start kollidieren könnte |
| **Löst Form 2b** | ja — die CLI kann gegen denselben HTTP-Endpunkt arbeiten (`gbrain connect <url> --token`), statt eine eigene Verbindung zu öffnen |
| **Löst nicht** | Wenn dieser eine Server hängt, hängt alles. Die Single-Writer-Eigenschaft bleibt — ein `embed` blockiert weiter alles andere |
| **Kosten** | Dienst einrichten und überwachen (z. B. `launchd`); Authentifizierung (OAuth 2.1 oder Bearer-Token); ein zusätzlicher lokaler Port |
| **Portabilität** | unverändert — das Datenverzeichnis bleibt, wo es ist |

### B — Postgres statt PGLite

**Die Idee:** Die Engine wechseln (Abschnitt 5). Damit verschwindet die
Dateisperre aus dem Bild, nicht nur ihre häufigste Auslösung.

| | |
|---|---|
| **Löst** | Beide Kollisionsformen — `LiveServeLockError` existiert im Postgres-Pfad nicht. Dazu: Cron-Läufe (`embed`, `dream`) parallel zum laufenden MCP-Server; CLI parallel zum Chat; mehrere Profile am selben Brain |
| **Löst nicht** | `db-lock.ts` bleibt aktiv (siehe Abschnitt 5) — aber als TTL-behaftete Zeilensperre, nicht als Prozess-Ausschluss |
| **Kosten** | Ein Postgres mit **pgvector** muss laufen. Da die Leiter über ein bestehendes Brain **verweigert** wird, ist die Bereitstellung Handarbeit — Rezept und Ablauf in Abschnitt 5. Der `migrate`-Lauf braucht den PGLite-Lock ein letztes Mal, die Desktop-Sitzung muss also aus sein |
| **Preis** | **Der Bootstrap-Hook geht verloren.** `skills/postgres-adopt/SKILL.md`: *„PGLite keeps the per-turn bootstrap hook lane (hook injection is PGLite-only today)"*. Auf Postgres läuft ambienter Kontext stattdessen über MCP-pro-Sitzung und das Pull-Protokoll |
| **Portabilität** | verschlechtert sich: statt eines kopierbaren Verzeichnisses gibt es eine Verbindungs-URL. Für die self-contained-Idee aus der Installationsdoku ein echter Zielkonflikt |
| **Wann empfohlen** | der Skill nennt die Schwelle: *„concurrent agents, multiple machines, or a 1000+ page brain"* — sonst sei PGLite „genuinely fine" |

### C — Betriebsdisziplin (der Status quo)

Halter suchen, beenden, neu starten. Funktioniert gegen Form 2a, ist aber
Handarbeit nach jedem Vorfall und hat die tückische stille Variante („leer bei
Exit 0") aus dem ersten Vorfall. Gegen Form 2b hilft sie nicht — dort gibt es
keinen verwaisten Prozess zu beenden, sondern nur die Regel „die Skills nicht
über das Terminal ausführen lassen".

### Einschätzung

**B ist die Antwort auf „grundlegend", A die Antwort auf „ohne großen Umbau".**
Sie schließen einander nicht aus — im Gegenteil: Ein langlebiger
`serve --http` auf einem Postgres-Brain ist die Form, in der beide Schwächen
verschwinden, und es ist die Betriebsform, für die GBrain erkennbar gebaut ist
(Default `postgres`, OAuth-HTTP-Server, `connect`-Befehl für entfernte Brains).

Bleibt die self-contained-Übertragbarkeit das höhere Ziel — oder hängt an
diesem Brain der PGLite-eigene Bootstrap-Hook —, dann ist B unattraktiv und
**A allein** der richtige Schritt: Er kostet keine
Portabilität, entschärft beide Kollisionsformen und macht die Integration
nebenbei ausfalltoleranter.

---

## 8. Diagnose-Rezept (read-only, korrigiert)

### Zuerst: welche Kollisionsform war es?

Das entscheidet sich an der Logdatei, in der die Meldung steht:

| Meldung steht in | Form | Bedeutung |
|---|---|---|
| `logs/mcp-stderr.log`, direkt unter einem `===== starting MCP server 'gbrain' =====` | **2a** | ein Serverstart scheiterte — es lebt ein alter `serve` |
| `logs/agent.log` als Ergebnis eines `tool terminal`-Aufrufs | **2b** | der Agent kollidierte mit seinem eigenen Server |
| nirgends | — | die Meldung stammt aus einer anderen Oberfläche, einem anderen Profil oder dem Terminal. Genau dieser Fall liegt für den 17.09. vor |

### Dann: wer hält den Lock?

Ersetzt den `postmaster.pid`-Griff aus der bisherigen Betriebsanweisung:

```bash
D=~/github/hermes-llm-wiki-gbrain/.gbrain/brain.pglite

# 1. Wer hält? Das steht hier -- und nur hier.
cat "$D/.gbrain-lock/lock"          # JSON: pid, acquired_at, refreshed_at, subcommand

# 2. Lebt der Halter, und woran hängt er?
ps -o pid,ppid,lstart,command -p <pid aus dem JSON>

# 3. Elternkette bis zur Wurzel -- Desktop, Gateway oder verwaist?
ps -o pid,ppid,command -p <ppid>
```

Drei Befunde, drei Bedeutungen:

- **Elternteil ist ein lebender `hermes … serve`** → Normalzustand, kein
  Fehler. Die MCP-Werkzeuge benutzen, nicht die CLI.
- **Elternteil ist `1` (init)** → verwaist. Der Fall, den
  `mcp_death_supervisor.py` abfangen soll; wenn er hier steht, hat der Wächter
  ihn nicht erwischt.
- **Elternteil lebt, aber die Sitzung ist längst zu** → der hängende `serve`.
  Das ist der Fall aus dem Log vom 21:31:48 und der einzige, den keine
  Automatik abräumt.

`postmaster.pid` gibt darauf **keine** Antwort — siehe Abschnitt 2a.

---

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Ob die heutige Meldung des Nutzers derselben Ursache entspringt | **sie steht in keinem eingesehenen Log** — siehe den Kasten am Anfang. Die Ursachenzuordnung dieses Dokuments stützt sich auf den Vorfall vom 16.09. Um das zu klären, fehlt die Angabe, **wo** die Meldung erschien (Chatfenster, Terminal, anderes Profil) |
| Ob Kollisionsform 2b jemals zugeschlagen hat | strukturell belegt (Skills fordern CLI-Aufrufe, `external_dirs` ist aktiv, `publish_skills: true`), im Betrieb **nie beobachtet**. Die 14 Terminal-Aufrufe vom 17.09. liefen alle durch |
| Ob `gbrain serve --http` mit Hermes' `url:`-Transport tatsächlich zusammenspielt | beide Seiten sind am Quelltext belegt und der Nachbareintrag `uwwb` beweist den Hermes-Pfad — die **Kombination** ist nicht ausgeführt. Offen: Authentifizierungsform (OAuth 2.1 vs. Legacy-Bearer), ob der Werkzeugpräfix `mcp__gbrain__*` gleich bleibt, ob die 137 Werkzeuge über HTTP identisch registriert werden |
| Ob `gbrain connect` die CLI wirklich lock-frei gegen den HTTP-Server führt | nur am Hilfetext gelesen (`cli.ts:3988`), der Codepfad nicht verfolgt |
| Ob `gbrain migrate --to <postgres-url>` auf diesem Brain durchläuft | der Ablauf ist am Quelltext gelesen (Abschnitt 5), der **Lauf** nicht. Offen bleiben die Laufzeit, die Größe des Ergebnisses und ob der Image-Pull hier durchgeht |
| ~~Ob die Einbettungen den Engine-Wechsel überstehen~~ | ✅ **geschlossen 17.09.2026:** sie werden kopiert, nicht neu berechnet (`copyPageToTarget:521-528`); ein misslungener Cast zählt in `embeddings_dropped` statt Daten zu verlieren |
| ~~Wie Postgres überhaupt bereitgestellt wird~~ | ✅ **geschlossen 17.09.2026:** Fünf-Stufen-Leiter, Docker-Sprosse mit `pgvector/pgvector:pg16` auf `127.0.0.1:5434` — aber über ein bestehendes Brain verweigert, also Handarbeit. Siehe Abschnitt 5 |
| Ob der von Hand angelegte Container von `db-repair` als eigener erkannt wird | `isGbrainDockerUrl` prüft nur Loopback + Port 5434, das Rezept trifft beides — ausprobiert ist es nicht |
| Ob der Verlust des Bootstrap-Hooks diese Installation trifft | der Skill sagt, dass es ihn auf Postgres nicht gibt; ob `wiki-llm` ihn überhaupt nutzt, wurde nicht geprüft |
| Ob `serve --http` denselben Single-Writer-Lock hält | mit hoher Wahrscheinlichkeit ja (ein Prozess, eine PGLite-Verbindung), aber der Codepfad `serve --http` → `acquireLock` wurde nicht verfolgt. Für Ausweg A ist das folgenlos — es gibt dann nur einen Halter |
| Warum der `serve` vom 16.09. 21:31:48 nicht auf stdin-EOF reagierte | die Wirkung steht im Log, die Ursache nicht. Ohne sie bleibt unklar, wie häufig der Fall wiederkehrt |
| Das SQLite-Sperrverhalten (Abschnitt 6c) | architektonische Einordnung aus den Sperrmodellen, nicht an GBrain gemessen — es gibt dort keinen SQLite-Code |
| Ob es außerhalb von Hermes weitere Clients gibt | geprüft: `~/.hermes/profiles/*/config.yaml` (nur `wiki-llm`), `~/.claude.json`, `~/.claude/settings*.json`, `.mcp.json` unter `~/github` (drei Ebenen tief), `.gbrain/integrations/` (leer). Ein Client außerhalb dieser Pfade wäre unentdeckt geblieben |
| Ob `hermes mcp`-Bordmittel den Halter sauberer beenden als `kill` | nicht gesucht |
| Ob der delegierte `gbrain sweep --once` auf dieser Installation wirklich durchläuft | der Pfad ist am Quelltext belegt und die drei Voraussetzungen (Socket, Geheimnis, lebender Halter) sind nachgesehen — **ausgeführt wurde er nicht**. Offen bleibt auch, ob der Lauf Modellkosten auslöst: Durchgang 3 des Sweeps (Korpus-Ingest) ist „spend-gated" und bei gesetztem Provider-Key nicht kostenlos |
| Ob die Wikilinks der neuen Notiz inzwischen im Graph stehen | nur aus dem Chat prüfbar (`mcp__gbrain__get_links` / `get_backlinks` auf die Seite). Ein zweiter `hermes -p wiki-llm`-Prozess von außen bekäme den `gbrain`-Server wegen desselben Locks gar nicht erst verbunden |
