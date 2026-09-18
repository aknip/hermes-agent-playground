# GBrain als LLM-Wiki für Hermes: was wohin installiert wird

**Stand:** 16.09.2026 · Zuerst Recherche, am selben Tag **real installiert**.
Das Zielverzeichnis `~/github/hermes-llm-wiki-gbrain` ist angelegt und läuft;
der protokollierte Lauf steht in [Abschnitt 6](#6-der-reale-lauf-vom-16092026).
Abschnitte 1 bis 5 sind unverändert die Analyse **vor** dem Lauf — was der Lauf
widerlegt oder bestätigt hat, steht jeweils in Abschnitt 6, nicht rückwirkend
eingearbeitet. [Abschnitt 7](#7-bestehenden-notizbestand-importieren--der-konkrete-fall)
ist wieder reine Analyse: der Import eines konkreten Notizbestands, gelesen am
Quellcode, nicht ausgeführt. Das **Kernkonzept** direkt unter der Ausgangsfrage
ist am 17.09.2026 nachgetragen und fasst die Rollenverteilung zusammen, die
sich über die Abschnitte 4, 6 und 7 verteilt.

**Ausgangsfrage:** [GBrain](https://github.com/garrytan/gbrain) soll als Wiki für
Hermes Agent dienen, die Inhalte nach `~/github/hermes-llm-wiki-gbrain`. Was
installiert die Anleitung **außerhalb** dieses Pfades — und lässt sich alles
(Profile, Skills, Skripte, Laufzeit) so hineinlegen, dass eine self-contained,
auf andere Rechner übertragbare Lösung entsteht?

---

## Kernkonzept: Index über Quellen — plus ein eigenes Verzeichnis für Neues

Vorangestellt, weil es das Modell für alles Weitere setzt. Nachgetragen am
17.09.2026; belegt am Quelltext plus drei Read-only-Abfragen gegen das
installierte Brain.

**Lesend aggregiert GBrain, es sammelt nicht ein.** Eine Source ist ein
*registrierter Pfad* (`gbrain sources add <id> --path`, `sources.ts:131-184`),
`gbrain import <dir>` liest daraus. Was in `brain.pglite` landet, ist
**abgeleitet** — Seiten, Chunks, Embeddings, Kanten, Fakten. Die Markdown-Dateien
bleiben, wo sie liegen, mehrere Quellen stehen nebeneinander, und das
Original-Notizverzeichnis kann unangetastet Master bleiben
([Abschnitt 4](#4-vorhandene-notizen-vorher-hineinlegen-oder-nachträglich-importieren)).
So weit ist die Datenbank ein **Index**, kein Wissensspeicher: aus den Quellen
jederzeit neu herstellbar.

**Schreibend hält GBrain aber ein eigenes Verzeichnis.** Neue Inhalte — `capture`,
`put_page`, `remember` und alles, was der Agent im Chat anlegt — enden nicht in
der Datenbank, sondern werden als Markdown auf die Platte geschrieben. Ziel ist
das Arbeitsverzeichnis der zugeordneten Quelle (`sources.local_path`),
ersatzweise das Brain-Repo (`sync.repo_path`). Zwei Bahnen, mit **umgekehrter
Reihenfolge**:

| | Seiten — `capture`, `put_page` | Fakten — `remember` |
|---|---|---|
| zuerst | die DB-Zeile | der `## Facts`-Fence in der Entity-`.md` |
| dann | Write-Through rendert die Zeile zurück nach `.md` | der DB-Stempel als Index |
| Ziel | `sources.local_path`, sonst `sync.repo_path` | nur `sources.local_path` |
| Beleg | `core/write-through.ts:1-22`, `:297` | `core/facts/fence-write.ts:1-12`, `core/facts/write-single.ts:172-173` |

Beide Bahnen sagen dasselbe über die Rollenverteilung. `write-through.ts:8-10`:
die Datei wird **aus der DB-Zeile gerendert**, „so the two sinks cannot diverge".
`fence-write.ts:3-11` nennt Markdown wörtlich das **„system of record"** und
führt den Ein-Zeilen-`insertFact` in die Datenbank ausdrücklich nur als Fallback
für Brains ohne `sources.local_path`.

Nach Entwurf lautet die Antwort auf „wird die Datenbank zum Wissensspeicher?"
also **nein** — aber nur, solange dieses Schreibverzeichnis existiert.

> **Doku-Abweichung.** Der Kopfkommentar von `capture.ts:14-17` verspricht, die
> CLI schreibe „to `~/.gbrain/inbox/<slug>.md` OR routes through put_page". Den
> `inbox/`-Zweig gibt es im Code nicht: lokal wie thin-client geht jeder Pfad
> über die `put_page`-Operation (`capture.ts:453`, `:483`) und damit über das
> Write-Through oben. Gleiche Klasse wie die `mcp_gbrain_`-Abweichung in
> Abschnitt 0 — Kommentar veraltet, nicht Code.

### In dieser Installation gibt es dieses Verzeichnis nicht

`schema.sql:60-66` sät die Quelle `default` **ohne** `local_path` („fresh
installs have no local_path until `sources add` or the first `sync`"), und
`sync.repo_path` wird im gesamten Quelltext an genau **einer** Stelle gesetzt:
von `gbrain import` — und auch dort nur, wenn das Importverzeichnis ein
Git-Repository ist (`import.ts:900-962`). Real gemessen am 17.09.2026,
read-only, bei freiem Lock:

```
./bin/gbrain sources list                  → default, federated, 0 pages, never synced
./bin/gbrain config get sync.repo_path     → Config key not found
./bin/gbrain config get sync.write_through → Config key not found
```

Damit greift `no_repo_configured` (Rückgabe in `write-through.ts:337`,
Bedeutung im Kommentar `:75-78`), und die Warnung,
die `withNoRepoWriteThroughWarning` (`:104`) dazu ausgibt, ist die wörtliche
Antwort auf die Frage: „put_page wrote only to the database … no durable
markdown file was created." Fakten fallen über `fence-write.ts:278` in den
`legacyFallback` — reine DB-Zeile, keine Datei. Der in
[Abschnitt 6](#real-gemessen-ende-zu-ende) protokollierte Fakt `#1` ist genau so
entstanden.

Das ist **kein Versehen, sondern die Entscheidung** aus
[Abschnitt 7](#die-nebenwirkung-die-man-kennen-sollte): ohne `local_path` bleibt
kein Zeiger auf das Notizverzeichnis zurück, und genau deshalb darf man es nach
dem Import löschen. Der Preis steht dort — `gbrain export` ist der einzige Weg
zurück zu Dateien.

Wer stattdessen ein dauerhaftes Schreibziel will, hängt eines an — beides
gelesen, nicht ausgeführt:

```bash
# deckt beide Bahnen, Seiten und Fakten
gbrain sources set-path default ~/github/hermes-llm-wiki-gbrain/memory
# deckt nur Seiten
gbrain config set sync.repo_path ~/github/hermes-llm-wiki-gbrain/memory
```

`sources set-path` ist genau für diesen Fall gebaut: der Kopfkommentar
(`commands/sources-set-path.ts:1-16`) nennt als Anlass „a brain's `default`
source sat with `local_path: null`". Es repariert **nur den DB-Zeiger**, legt
kein Verzeichnis an und verlangt — anders als `sources add`
(`sources.ts:1878-1880`: „--path must be a git repo with committed files") —
kein Git-Repository.

Wichtig: Dieses Verzeichnis sollte **nicht** der Import-Bestand sein. Eine
registrierte, versionierte Quelle macht genau das Löschen unmöglich, das
Abschnitt 7 als Vorteil der pfadlosen `default`-Quelle beschreibt.

---

## 0. Benutzung: Chat oder CLI?

Vorangestellt, weil es die erste Frage nach der Installation ist.

**`gbrain search` im Hermes-Chat einzutippen funktioniert nicht.** Das ist ein
Shell-Kommando; im Chat landet es als Text beim Modell, nicht als Aufruf. GBrain
hängt als **MCP-Server** am Profil, seine Verben sind **Werkzeuge**.

### Weg 1 — natürliche Sprache (der Normalfall)

Beschreiben, was gebraucht wird; der Agent wählt das Werkzeug:

```
Durchsuche mein Wiki nach allem zu Kanban-Dispatch.
Was weisst du ueber das Orchestrator-Profil?
Merk dir: Wir nutzen OpenRouter statt direkter Provider-Keys.
```

### Weg 2 — Werkzeug beim Namen nennen

Wenn der Agent danebengreift. Der Name trägt **zwei** Unterstriche:

| CLI-Verb | Werkzeug in Hermes |
|---|---|
| `gbrain search` | `mcp__gbrain__search` |
| `gbrain think` | `mcp__gbrain__think` |
| `gbrain capture` | `mcp__gbrain__capture` |
| `gbrain query` / `recall` / `remember` | `mcp__gbrain__query` / `__recall` / `__remember` |

> **Doku-Abweichung.** `docs/mcp/HERMES.md` schreibt `mcp_gbrain_<tool>` mit
> **einfachem** Unterstrich. Das ist falsch: `agent/anthropic_adapter.py:246`
> setzt `_MCP_TOOL_PREFIX = "mcp__"`. Real gemessen — auf die Frage nach seinen
> Werkzeugnamen antwortete das Profil `mcp__gbrain__query`,
> `mcp__gbrain__get_page`, `mcp__gbrain__put_page`.

Insgesamt registriert der Server **135** Werkzeuge.

### Weg 3 — die CLI über das Terminal-Werkzeug

`~/github/hermes-llm-wiki-gbrain/bin/gbrain search …` funktioniert, aber siehe
die Warnung unten. Für den Alltag sind Weg 1 und 2 richtig.

**Seit 17.09.2026 liegt `gbrain` im PATH** — als Wrapper unter
`~/.local/bin/gbrain`, den `setup.sh` in Schritt 7/7 anlegt:

```bash
#!/usr/bin/env bash
# hermes-llm-wiki-gbrain: PATH-Wrapper (von setup.sh erzeugt)
exec "/Users/aknipschild/github/hermes-llm-wiki-gbrain/bin/gbrain" "$@"
```

Bewusst **kein Symlink**: der Launcher leitet `GBRAIN_HOME` aus
`"$(dirname "${BASH_SOURCE[0]}")/.."` ab, und `BASH_SOURCE` löst Symlinks nicht
auf — über einen Symlink wäre `GBRAIN_HOME` gleich `~/.local`, und der Launcher
bräche mit „GBrain-Laufzeit fehlt" ab.

Warum ausgerechnet `~/.local/bin`: Hermes nimmt für das Terminal-Werkzeug einen
Login-Shell-Schnappschuss und sourct dafür `~/.profile`, `~/.bash_profile` und
`~/.bashrc` (`tools/environments/local.py:600-618`) — **nicht** die
zsh-Dateien. Alle drei setzen `~/.local/bin` selbst, der Eintrag gilt also in
der eigenen Shell **und** im Agenten. Ein PATH-Eintrag nur in `~/.zshrc` würde
den Agenten nie erreichen. Profil-eng ginge auch:
`~/.hermes/profiles/wiki-llm/bin/` liegt ebenfalls im Schnappschuss-PATH.

Ohne diesen Eintrag meldet das Modell im Chat `which gbrain` → Exit 1 und kann
CLI-only-Befehle nicht anstoßen. Einzelheiten und die Herleitung in
[`Hermes-GBrain-PGLite-Lock.md`](Hermes-GBrain-PGLite-Lock.md), Abschnitt 3a.

### Die Lock-Falle

⚠ **Solange eine Hermes-Sitzung GBrain angeschlossen hält, scheitert jeder
CLI-Aufruf am PGLite-Lock — und umgekehrt.** Das ist die Single-Writer-Schranke
aus [Abschnitt 3](#eine-harte-designschranke-kein-fußnotenthema), und sie ist
im Lauf wirklich zugeschlagen: siehe [Abschnitt 6](#der-lock-vorfall).

Wenn Suche oder Chat plötzlich leer antworten:

```bash
ps aux | grep cli.ts     # haelt noch ein serve das Brain?
ls ~/github/hermes-llm-wiki-gbrain/.gbrain/brain.pglite/postmaster.pid
```

Was der Befund bedeutet:

- **Ein lebender Hermes-Prozess ist der Halter** (`--profile <name> serve` als
  Elternprozess) — das ist der Normalzustand, kein Fehler. Dann Weg 1 oder 2
  statt der CLI.
- **Der Prozess ist verwaist** — beenden, dann geht beides wieder. Genau das war
  im Lauf nötig.

**Zwei Ausnahmen** (belegt am Quelltext, 17.09.2026): `gbrain sync` und
`gbrain sweep --once` werden an den laufenden `serve` **delegiert** — der
Pre-Connect-Hook in `cli.ts` erkennt den lebenden Lock-Halter und lässt ihn die
Arbeit über den IPC-Socket erledigen (`commands/sweep-delegate.ts`,
`sweep_start`/`sweep_status`). Diese beiden laufen also auch bei gehaltenem
Lock; `--no-delegate` schaltet die Delegation ab und scheitert dann wieder.
Alle übrigen Unterbefehle — `sources add`, `capture`, `extract`, `migrate` —
brauchen den Lock selbst.

`gbrain pglite-repair` ist dafür **nicht** zuständig: es repariert ein
zerrissenes WAL nach unsauberem Shutdown (`RuntimeError: Aborted()`), mit
pg_resetwal-Semantik und möglichem Verlust nicht gecheckpointeter Transaktionen.
Ein gehaltener Lock ist ein anderes Problem — dafür hilft nur, den Halter zu
finden.

### Seiten sind nicht Fakten

`search` und `think` arbeiten auf **Seiten**, `recall` und `entity` auf
**Fakten**. Real gemessen: `gbrain think "Was weisst du ueber
projects/gbrain-setup?"` meldete `Pages: 0`, während `gbrain recall
projects/gbrain-setup` denselben Fakt sauber lieferte. Wer über `remember`
Gespeichertes sucht, braucht `recall`/`entity`, nicht `search`.

---

## Beweislage

Drei ungleiche Quellen sind im Spiel; sie werden hier nicht vermischt.

| Quelle | Status |
|---|---|
| Hermes-Quelltext `~/.hermes/hermes-agent/` | **v0.21.2 (2026.9.11)** — nicht die im Repo festgeschriebene v0.20.0. Alle Hermes-Zitate gelten für 0.21.2. |
| GBrain-Quelltext | `VERSION 0.50.5.0`, sha `668b9ba`. Zur Analysezeit ein `master`-Klon nach `/tmp`; der Lauf hat dann gezeigt, dass Tag `latest-stable` **auf genau diesen Commit** zeigt — Analyse und Installation stehen auf demselben Stand. |
| Protokollierter Lauf | 16.09.2026, `~/github/hermes-llm-wiki-gbrain`. Alles mit „Real gemessen" markierte in Abschnitt 6 stammt daher. |
| Read-only-Abfragen | 17.09.2026, dasselbe Brain: `sources list`, `config get`. Nur im Kernkonzept oben zitiert; sie schreiben nichts. |
| `INSTALL_FOR_AGENTS.md`, `docs/mcp/HERMES.md` | Online-Doku, nach dem Verifikationsvertrag **keine Quelle.** Nur Abschnitt 1 referiert sie; Abschnitt 2 und 3 stehen am Code. |

Vorhanden war Bun (`/opt/homebrew/bin/bun`, via Homebrew) — der `curl | bash`-Schritt
der Anleitung entfällt.

---

## 1. Die Installationsschritte, zusammengefasst

Neun Schritte, davon vier für den keyless-Pfad zwingend:

1. **Install** — `bun install -g github:garrytan/gbrain`. Ausdrückliche Warnung:
   **niemals** `npm install -g gbrain`, das ist ein fremdes Paket. Fallback bei
   blockiertem postinstall-Hook: `git clone ~/gbrain && bun install && bun link`.
2. **API-Keys** — für den Einstieg übersprungen. Ohne Key bleibt Keyword-Suche;
   Voyage (Embedding + Reranker) bzw. Anthropic/OpenAI (Fakt-Extraktion,
   Query-Expansion) sind opt-in. **Die Anleitung verschweigt eine dritte
   Option — siehe unten.**

3. **`gbrain init`** — PGLite, kein Server. Für Harness-Installs empfiehlt die
   Doku `--prefer-postgres` (Fünf-Stufen-Leiter bis zum PGLite-Boden).
4. **Schritt 3.5 Suchmodus** — `conservative | balanced | tokenmax` muss beim
   Operator *rückgefragt* werden; 25-fache Kostenspreizung über die
   Neun-Felder-Matrix (Modus × nachgelagertes Modell).
5. **`gbrain import` + `embed --stale`**, danach Schritt 4.5
   `extract links|timeline` für den Graphen (bei leerem Brain überspringbar).
6. **Skills** — `gbrain skillpack scaffold --all` in einen Workspace. Im Klon
   sind es **85** Verzeichnisse unter `skills/`, nicht die genannten „50+".
7. **MCP-Registrierung** —
   `hermes mcp add gbrain --env GBRAIN_HOME=$HOME --connect-timeout 60 --command $(which gbrain) --args serve`,
   Prüfung mit `hermes mcp test gbrain`.
8. **Identität** (optional), **Cron** (sync / dream / doctor, oder
   `gbrain autopilot --install`), **Integrationen**, **Verify**.

Zwei Gotchas der Doku sind gegen den **installierten** Hermes 0.21.2 geprüft und
gelten weiterhin: `hermes_cli/subcommands/mcp.py:34` deklariert `--args` als
`nargs=argparse.REMAINDER` — alles danach wird verschluckt, es muss die letzte
Option sein. `mcp.py:41` deklariert `--env` als `nargs="*"` — ein zweites `--env`
**ersetzt** das erste, statt zu ergänzen; mehrere Variablen gehören hinter *ein*
`--env`.

### Nicht in der Anleitung: OpenRouter deckt alle vier Lanes

`INSTALL_FOR_AGENTS.md` nennt in Schritt 2 nur Voyage, OpenAI und Anthropic.
Der Code führt OpenRouter aber als vollwertiges Rezept, und zwar für **alle
vier** Touchpoints (`src/core/ai/recipes/openrouter.ts:157-300`):

| Lane | Was OpenRouter liefert |
|---|---|
| Embedding | `/v1/embeddings` proxyt `openai/text-embedding-3-small` (1536d, Matryoshka-Shrink auf 512/768/1024). Katalog zusätzlich `text-embedding-3-large` (3072d), `qwen3-embedding-8b` (4096d), `gemini-embedding-2-preview`, `bge-m3` |
| Chat | `/v1/chat/completions` über den gesamten OpenRouter-Katalog; die kuratierte Liste ist nur ein Einstiegspunkt, die openai-compat-Ebene erzwingt sie nicht |
| Expansion | dieselbe Lane wie Chat; empfohlenes Set `anthropic/claude-haiku-4.5`, `google/gemini-3-flash-preview`, `deepseek/deepseek-chat` |
| Reranker | `/api/v1/rerank` mit Cohere v3.5 / 4-fast / 4-pro und NVIDIA Nemotron. **Hier gilt die Allowlist strikt**, kein openai-compat-Bypass |

Das ist der praktische Weg, wenn wie in diesem Repo ohnehin ein
`OPENROUTER_API_KEY` existiert: **ein Key deckt Embedding, Chat, Expansion und
Reranking**, statt Voyage plus Anthropic nebeneinander zu betreiben.

```bash
gbrain init --pglite \
  --embedding-model openrouter:openai/text-embedding-3-small \
  --embedding-dimensions 1536 \
  --expansion-model openrouter:anthropic/claude-haiku-4.5 \
  --chat-model  openrouter:anthropic/claude-haiku-4.5
```

Zwei Stolpersteine, beide im Lauf aufgetreten und in Abschnitt 6 belegt: der
Suchmodus-Automatismus erkennt OpenRouter nicht als expansionsfähig, und die
Subagent-Lane braucht `agent.use_gateway_loop true`.

---

## 2. Was bei Standard-Installation außerhalb des Zielpfads landet

### Geschrieben wird

| Pfad | Was | Beleg |
|---|---|---|
| `~/.bun/install/global/node_modules/gbrain`, `~/.bun/bin/gbrain` | Paket und Binary | `bun pm -g bin` nennt `~/.bun/install/global` |
| **`~/.gbrain/`** | `config.json`, **`brain.pglite`** (die komplette Datenbank), `.env`, `git-credentials`, `clones/`, `transcripts/`. Folgt daraus, dass die Anleitung `GBRAIN_HOME=$HOME` setzt | `config.ts:1738-1755`, `doctor.ts:1825` |
| `~/.hermes/config.yaml` | Block `mcp_servers.gbrain` | `hermes_cli/config.py:469` |
| `~/.hermes/.env` | Provider-Key, falls headless oder Cron | Doku |
| `~/Library/LaunchAgents/<label>.plist` | **nur** bei `gbrain autopilot --install` | `autopilot.ts:1659-1660` |
| `~/.hermes/cron/` bzw. `crontab` | nur bei Schritt 7 | — |
| `~/.gbrain/mounts.json`, `~/.gbrain/mounts-cache/` | **hartkodiert auf `homedir()`, ignoriert `GBRAIN_HOME`** — geschrieben aber nur von `gbrain mounts`, auf dem Ein-Brain-Pfad unberührt | `brain-registry.ts:49`, `mounts-cache.ts:36` |
| `~/.claude/plugins/` | nur wenn der Claude-Code-Plugin-Weg gewählt wird | — |

### Nicht geschrieben, entgegen naheliegender Vermutung

**Keine Git-Hooks im umgebenden Repository.** `hardenBrainRepo` läuft
ausschließlich über `gbrain sources harden` (`sources.ts:468`); `init`, `import`
und `sync` committen nur, wenn vorher gehärtet wurde
(`fence-write.ts:50` prüft `isDurabilityHardened`). Ein `post-commit`-Hook und
`brain-push.log` entstehen also nur auf ausdrückliche Anweisung.

### Nur gelesen

`~/.hermes/sessions/` für den Transkript-Ingest (`src/core/transcripts/hermes.ts`)
und `~/.claude/skills/gstack` u. ä. zur Erkennung (`init.ts:1924`).

---

## 3. Self-contained — machbar, mit genau drei Ausnahmen

### Was vollständig nach `~/github/hermes-llm-wiki-gbrain` kann

**Daten und Konfiguration.** `GBRAIN_HOME` ist ein *Elternverzeichnis*, `.gbrain`
wird immer angehängt (`config.ts:1738-1755`; der Wert muss absolut sein und darf
kein `..` enthalten, sonst wirft es). `GBRAIN_HOME=~/github/hermes-llm-wiki-gbrain`
ergibt also:

```
~/github/hermes-llm-wiki-gbrain/.gbrain/config.json
~/github/hermes-llm-wiki-gbrain/.gbrain/brain.pglite
```

Der PGLite-Default ist `gbrainPath('brain.pglite')` (`doctor.ts:1825`), folgt also
mit. `--brain host` meint genau diese Datenbank aus `config.json`
(`brain-registry.ts:5`), ohne `mounts.json`.

**Die Laufzeit.** GBrain macht das selbst vor: der In-Agent-Install legt unter
einer frei gewählten Root `bin/gbrain`, `runtime/`, `.gbrain/`, `memory/` und
`instructions/` an. Der generierte Launcher (`agent-install/launcher.ts`) setzt
`GBRAIN_HOME`, entfernt geerbte `GBRAIN_*`- und Provider-Variablen
(`agent-install/environment.ts`) und ruft
`bun --no-env-file <cli> --brain host "$@"`. Die Argumentreihenfolge stimmt:
`--brain` ist globales Flag und wird vor dem Dispatch abgeräumt
(`cli-options.ts:113ff`).

> **Aber dieser Weg ist für Hermes nicht vorgesehen.**
> `scripts/setup-in-agent.sh:38` akzeptiert nur `grok-bot|muse`,
> `gbrain bootstrap` nur `claude-code|codex|opencode` (`bootstrap.ts:1054`).
> Für Hermes müsste er von Hand nachgebaut werden: privates `bun install` nach
> `runtime/`, eigener Launcher nach demselben Muster.

**Die Skills.** `skillpack scaffold` schreibt workspace-relativ nach
`<workspace>/skills/<slug>/` (`core/skillpack/scaffold.ts`), also direkt in den
Zielordner.

### Was zwingend draußen bleibt: drei Zeiger in *einer* YAML-Datei

1. `mcp_servers.gbrain` mit `command:` auf den absoluten Launcher-Pfad,
2. ein Eintrag in `skills.external_dirs` (`agent/skill_utils.py:337` — Einträge
   werden `~`/`${VAR}`-expandiert, sind relativ zu HERMES_HOME und müssen
   existieren, sonst werden sie still übersprungen),
3. optional der Provider-Key in `.env`.

**Nachtrag 17.09.2026 — ein vierter, optionaler Zeiger:** der PATH-Wrapper
`~/.local/bin/gbrain` (siehe [Abschnitt 0, Weg 3](#weg-3--die-cli-über-das-terminal-werkzeug)).
Er liegt ebenfalls außerhalb des Zielpfads, ist aber **keine Voraussetzung** für
den Betrieb: Chat und MCP-Werkzeuge laufen ohne ihn. Gebraucht wird er nur für
CLI-only-Befehle — allen voran `gbrain sweep --once`, das ein Modell sonst
mangels `gbrain` im PATH nicht anstoßen kann. `setup.sh` legt ihn seit dem
17.09.2026 selbst an (Schritt 7/7, abschaltbar über `HERMES_WIKI_BIN_DIR=`).

**Empfehlung: profil-scoped statt global.** `get_config_path()` ist
`get_hermes_home()/config.yaml` (`config.py:469`), und `-p <profil>` verschiebt
HERMES_HOME nach `~/.hermes/profiles/<name>/` (`service_manager.py:245`). Ein
`hermes -p wiki mcp add gbrain …` landet damit in
`~/.hermes/profiles/wiki/config.yaml` und lässt die globale Installation
unberührt; `get_skills_dir()` ist dann ebenfalls profil-eigen
(`hermes_constants.py:1140`). Siehe [Hermes-Custom-Root.md](Hermes-Custom-Root.md)
für die Grenze zwischen Profil und Root.

**Der projektlokale Weg als Alternative zu `external_dirs`:** Wird
`~/github/hermes-llm-wiki-gbrain` ein eigenes Git-Repository, ist es selbst der
nächste `.git`-Vorfahr, und `<root>/.hermes/skills` bzw. `<root>/.agents/skills`
werden geladen — aber nur, wenn die Wurzel in `skills.trusted_project_dirs` steht
(`skill_utils.py:454ff`) **und** das Arbeitsverzeichnis der Sitzung darin liegt
(`find_project_root()` nimmt `TERMINAL_CWD`, sonst `cwd`). Für ein Wiki, das über
MCP aus beliebigen Sitzungen erreichbar sein soll, ist das zu wackelig;
`skills.external_dirs` ist der robuste Weg. Beides braucht ohnehin denselben einen
Eintrag in derselben `config.yaml`.

### Der Transport auf einen anderen Rechner

Ein idempotentes `setup.sh` im Ordner, das genau diese Zeiger neu schreibt — mehr
ist die Übertragung nicht. Nicht mitnehmen und in `.gitignore`: `runtime/`
(plattformspezifische Binaries) und `.gbrain/` (Secrets und Datenbank). Master
sind die Markdown-Dateien unter `memory/`; die Datenbank wird per
`gbrain import` / `gbrain sync` neu aufgebaut.

> **Nachtrag vom 17.09.2026.** Dieser Satz beschreibt die Absicht, nicht den
> Ist-Zustand: `memory/` ist leer und weder als Quelle noch als
> `sync.repo_path` registriert, die Quelle `default` trägt bewusst kein
> `local_path`. Solange das so bleibt, gibt es nichts, woraus sich die
> Datenbank neu aufbauen ließe — der Rückweg ist `gbrain export`. Siehe
> [Kernkonzept](#in-dieser-installation-gibt-es-dieses-verzeichnis-nicht) und
> [Abschnitt 7](#die-nebenwirkung-die-man-kennen-sollte).

### Eine harte Designschranke, kein Fußnotenthema

PGLite ist Single-Writer: der erste laufende `gbrain serve` hält den Lock auf das
Datenverzeichnis. Hält Hermes diesen `serve`, kollidiert jeder Cron-Lauf von
`embed` oder `dream` daran — nur `sync` delegiert an den laufenden `serve`.
Drei Auswege: ein gemeinsames `gbrain serve --http`, auf das alle Clients zeigen;
Postgres statt PGLite; oder Wartung strikt außerhalb der Hermes-Laufzeit.

---

## 4. Vorhandene Notizen: vorher hineinlegen oder nachträglich importieren?

**Die Trennlinie verläuft nicht zwischen „vorher" und „nachher", sondern zwischen
Dateien und Schema: die Dateien gehören vor dem ersten Import an ihren
endgültigen Platz, das Schema entsteht danach aus den echten Daten.**

### „Kopieren" heißt: Pfad festlegen und registrieren

Eine Source ist ein registrierter Pfad — `gbrain sources add <id> --path <p>`
(`sources.ts:1878`), und `gbrain import <dir>` liest aus einem Verzeichnis. Die
Datenbank hält abgeleitete Seiten; das Markdown bleibt, wo es liegt. „Ins GBrain
kopieren" bedeutet also: die Dateien an ihren endgültigen Pfad legen und diesen
Pfad registrieren. Das Original-Notizverzeichnis kann unangetastet als Master
bestehen bleiben — dieselbe Trennung, die die Stories im Repo mit `seed/` und
`workspace/` machen.

Ein Import-Ziel außerhalb eines konfigurierten Roots ist erlaubt; der Riegel
`import.require_configured_root` ist Opt-in und standardmäßig aus
(`import.ts:442-468`).

### Nachträglich billig

| Entscheidung | warum unkritisch |
|---|---|
| Schema-Pack | Sieben-Stufen-Auflösungskette (`schema.ts:160-167`): CLI-Flag, `GBRAIN_SCHEMA_PACK`, pro Source, brain-weit, `gbrain.yml`, `config.json`, Default. Umstellbar per `gbrain config set schema_pack`; `gbrain schema sync --apply` backfillt `page.type` — aber **nur für untypisierte Zeilen**, siehe die Korrektur in [Abschnitt 7](#nachträglich-umtypen-geht-aber-nicht-mit-schema-sync) (`schema.ts:154`, `schema-pack/sync.ts:71`) |
| Seitentypen finden | `schema detect` / `suggest` / `review-candidates` clustern Seiten nach `source_path` zu Kandidatentypen — das funktioniert **besser mit** bereits importierten Inhalten, nicht ohne |
| Graph und Zeitleiste | `extract links --source db`, `extract timeline --source db`; idempotent, mit `--since` inkrementell |
| Bare Wikilinks | `link_resolution.global_basename` ist jederzeit umlegbar, danach `extract links` neu |
| Suchmodus, weitere Verzeichnisse | `config set search.mode`, weitere `sources add` |

Genau dafür ist Schritt 4.5 der Anleitung da („If the user already had a brain
repo"). Nachträglich importieren ist der **vorgesehene** Weg, nicht der Notnagel.

### Vorher entscheiden

1. **Embedding-Provider und Dimensionen.** Ein Wechsel später ist möglich
   (`gbrain migrate embeddings --to <provider:model> --dim N`), kostet aber ein
   **vollständiges Re-Embed** — Geld und Zeit proportional zur Korpusgröße
   (`skills/migrations/v0.46.3.0.md`). Wer semantische Suche will, wählt den
   Provider vor dem großen Import.
2. **Engine.** Kein Einbahnstraßen-Beschluss, aber ein Spurwechsel: die
   `init --prefer-postgres`-Leiter **verweigert** über einem bereits
   konfigurierten Brain, Engine-Wechsel läuft über `gbrain migrate`. Bei
   erwarteten >1000 Seiten also gleich Postgres wählen statt später migrieren.
3. **Verzeichnislayout.** Slugs werden aus dem Pfad abgeleitet, und bare
   Wikilinks lösen standardmäßig **nicht** über Ordnergrenzen auf:
   `isGlobalBasenameEnabled` gibt ohne gesetztes Flag `false` zurück
   (`link-extraction.ts:1796, 1810`), `[[name]]` trifft nur die wurzelexakte
   Form oder den Ancestor-Walk. Ein Umbau der Ordnerstruktur nach dem Import
   ändert also Slugs und Kanten. `gbrain sync` versöhnt Umbenennungen über git
   (`core/sync.ts:226`, `manifest.renamed`); `gbrain import` tut das nicht —
   Staleness auf Commit-Ebene ist ausdrücklich `sync`s Aufgabe, nicht die des
   Imports (`import.ts:988`).

### Vor dem ersten `sync`: ein eigenes Git-Repository anlegen

`gbrain sync` legt selbst eines an, wenn keines gefunden wird:
`git init --quiet` plus Baseline-Commit im Notizverzeichnis (`sync.ts:1551`).
Die Suche läuft dabei **nach oben** — liegt das Verzeichnis irgendwo innerhalb
eines fremden Checkouts, bindet sync an dieses Vorfahren-Repository, statt ein
eigenes anzulegen. Beides passiert stillschweigend beim ersten Lauf.

Deshalb: `~/github/hermes-llm-wiki-gbrain` bewusst zum eigenen Git-Repository
machen, **bevor** das erste `sync` läuft. Das ist ohnehin die Voraussetzung für
die Umbenennungs-Erkennung oben und für den projektlokalen Skill-Weg aus
Abschnitt 3.

### Die Reihenfolge, die beides verbindet

1. Zielverzeichnis anlegen, `git init`, `.gitignore` für `runtime/` und `.gbrain/`.
2. Notizen an ihren endgültigen Platz kopieren (Original bleibt Master).
3. `gbrain init` mit bewusster Engine- und Embedding-Entscheidung, Suchmodus
   rückfragen.
4. `gbrain import` + `embed --stale`.
5. `schema detect` / `sync --apply` auf den echten Daten, Typen nachziehen.
6. `extract links` / `extract timeline`, bei Obsidian-Beständen vorher
   `link_resolution.global_basename` prüfen.

---

## 5. Wie viele Hermes-Profile legt die Installation an?

**Keines.** Eine Suche über den gesamten Klon (`src/`, `docs/`, `skills/`,
`scripts/`) nach `hermes profile` liefert keinen einzigen Treffer. Der einzige
Ort, an dem GBrain das `hermes`-Binary überhaupt aufruft, ist der Test-Harness
`src/core/claw-test/runners/hermes.ts` mit `hermes -z "<brief>"` — und der gehört
nicht zum Installationsweg.

Auf der Hermes-Seite entsteht genau ein YAML-Block, geschrieben von
`hermes mcp add` in die *aktive* `config.yaml` (`hermes_cli/config.py:469`):

```yaml
mcp_servers:
  gbrain:
    command: …
    args: [serve]
```

Ohne `-p` ist das die globale `~/.hermes/config.yaml`. Ein Profil wird dabei
weder erzeugt noch vorausgesetzt.

Zwei GBrain-Begriffe, die man leicht für Profile hält, es aber nicht sind:
**„brains"** (`--brain host`, `mounts.json`) sind Datenbanken
(`brain-registry.ts:5`), und die **Identität** aus dem optionalen Schritt 6
(`SOUL.md`, `USER.md`) ist eine Markdown-Datei im Brain-Verzeichnis.

Damit ist auch die Kollisionsfalle aus `CLAUDE.md` — Profilnamen überschneiden
sich zwischen den Stories, `teardown.sh` löscht global nach Namen — hier kein
Thema: GBrain hinterlässt nichts, was ein Teardown erwischen könnte.

### Das eine Profil, das man bewusst selbst anlegt

Die Empfehlung aus Abschnitt 3, die Registrierung profil-scoped statt global zu
halten, ist der **einzige** Grund für ein Profil — und es entsteht von Hand.
GBrain könnte das auch nicht: benannte Profile müssen ausdrücklich erzeugt
werden, sonst greift der Guard `assert_named_profile_home_live`
(`hermes_cli/config.py:641`).

Wichtig vorab: **ein Profil erbt die globale `config.yaml` nicht.**
`_load_config_impl` merged `DEFAULT_CONFIG` plus die *aktive* Datei, sonst nichts
(`config.py:2198-2212`). Ein frisches `wiki-llm` stünde also ohne
Modellkonfiguration da — deshalb `--clone`, das `config.yaml`, `.env`, `SOUL.md`
und Skills vom aktiven Profil übernimmt (Bot-Tokens und Allowlists bleiben
zurück).

```bash
# 1. Profil anlegen, Modellkonfiguration vom aktiven Profil übernehmen
hermes profile create wiki-llm --clone

# 2. Prüfen, dass die Modell-Schlüssel angekommen sind
hermes -p wiki-llm config get model.default
hermes -p wiki-llm config get model.provider

# 3. GBrain als MCP-Server in genau diesem Profil registrieren.
#    --env und --connect-timeout VOR --command, --args als letzte Option.
printf 'Y\n' | hermes -p wiki-llm mcp add gbrain \
  --env GBRAIN_HOME="$HOME/github/hermes-llm-wiki-gbrain" \
  --connect-timeout 60 \
  --command "$HOME/github/hermes-llm-wiki-gbrain/bin/gbrain" \
  --args serve

# 4. Das Skills-Verzeichnis des Wikis bekannt machen
hermes -p wiki-llm config set skills.external_dirs \
  '["~/github/hermes-llm-wiki-gbrain/skills"]'

# 5. Prüfen — mcp add liefert auch im Fehlerfall Exit-Code 0
hermes -p wiki-llm mcp list
hermes -p wiki-llm mcp test gbrain
```

Zu Schritt 4: `hermes config set` parst Listen- und Mapping-Literale über
`yaml.safe_load`, sobald der Wert strukturiert aussieht
(`config.py:3296-3326`) — es landet also eine echte Liste in der YAML, kein
String. Das `~` bleibt stehen und wird erst beim Lesen expandiert
(`skill_utils.py:337`).

`wiki-llm` ist als Name zulässig: `[a-z0-9][a-z0-9_-]{0,63}`
(`hermes_cli/profiles.py:200`).

### Was dieser Schritt selbst außerhalb des Zielpfads anlegt

| Pfad | Was |
|---|---|
| `~/.hermes/profiles/wiki-llm/` | das Profil mit eigener `config.yaml`, `.env`, `skills/` (`service_manager.py:245`) |
| `~/.local/bin/wiki-llm` | Wrapper-Skript, das `hermes -p wiki-llm` aufruft (`profiles.py:149-155`). Mit `--no-alias` abschaltbar |

Beides ist Absicht und in Abschnitt 3 als „drei Zeiger" eingepreist — es
verschiebt nur, *wohin* die zwei Konfigurationseinträge gehen, und hält die
globale Installation sauber.

---

## 6. Der reale Lauf vom 16.09.2026

Installiert nach `~/github/hermes-llm-wiki-gbrain`, self-contained nach
Abschnitt 3, Engine PGLite, Suchmodus `tokenmax`, alle Modell-Lanes über
OpenRouter. Ergebnis: GBrain **0.50.5.0**, 68 Skills, Hermes-Profil `wiki-llm`
mit 135 MCP-Tools, `doctor` ohne einen einzigen FAIL-Check.

### Real gemessen: der Fußabdruck

Die zentrale Behauptung aus Abschnitt 3 hält. Nach der vollständigen
Installation:

| geprüft | Ergebnis |
|---|---|
| `~/.gbrain` | **existiert nicht** — `GBRAIN_HOME` trägt vollständig |
| `~/.hermes/config.yaml` | **0 Treffer** für `gbrain`; die globale Installation ist unberührt |
| `~/.bun/install/global` | **0** gbrain-Pakete |
| `~/Library/LaunchAgents` | **0** Einträge (kein `autopilot --install`) |
| `~/.npmrc` | unverändert |

Außerhalb liegen exakt die zwei vorhergesagten Dinge plus das Profil selbst:
`~/.hermes/profiles/wiki-llm/` (47 MB, überwiegend durch `--clone`) und
`~/.local/bin/wiki-llm` (69 Bytes Wrapper).

Das Brain-Verzeichnis nach `init`:

```
.gbrain/config.json      539 B, database_path zeigt in den Zielpfad
.gbrain/brain.pglite     43 MB
.gbrain/.env             chmod 600, enthält den Provider-Key
.gbrain/.gitignore       von gbrain selbst angelegt
```

Größe gesamt 535 MB, davon 490 MB `runtime/` — und genau das ist gitignored.
Der Commit umfasst 126 Dateien; `git diff --cached -S'sk-or-v'` findet null
Treffer, der Key ist nicht im Index.

### Real gemessen: Ende-zu-Ende

`gbrain remember` schrieb Fakt `#1`, ein **separater Prozess** las ihn per
`gbrain recall` zurück. Danach durch Hermes hindurch:

```
hermes -p wiki-llm -z "… nenne mir die gespeicherte Testphrase …"
→ bernstein-orbit-7Q4X          (exit 0)
```

`hermes mcp test gbrain`: verbunden in **1476 ms**, 135 Tools entdeckt.

### Vier Abweichungen vom Plan

**1. Der handgebaute Launcher trägt.** `bin/gbrain --version` meldet
`gbrain 0.50.5.0`. Die Nachbildung von `renderAgentLauncher` samt Env-Abräumung
funktioniert für Hermes, obwohl `setup-in-agent.sh` diesen Harness ablehnt.
Konsequenz aus dem Abräumen: der Provider-Key **muss** in `.gbrain/.env`, aus
der Shell wird er entfernt.

**2. `bunfig.toml` verliert gegen `~/.npmrc`.** Ein `[install] registry = …` in
`runtime/gbrain/bunfig.toml` blieb wirkungslos — bun zog weiter die Registry aus
`~/.npmrc`. Erst eine verzeichnislokale `.npmrc` griff. Wer hinter einer
Firmen-Registry sitzt, die gerade nicht auflöst, braucht also die `.npmrc`,
nicht das `bunfig.toml`. (`BUN_CONFIG_REGISTRY` als Env-Variable wirkte
ebenfalls.)

**3. `init` wählte `conservative`, obwohl `tokenmax` gewünscht war.** Genau der
Mechanismus aus Abschnitt 1: `hasExpansionKey` prüft ausschließlich
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY` und
`GEMINI_API_KEY` (`init-mode-picker.ts:117-122`) — **OpenRouter steht dort
nicht**, auch wenn Expansion über OpenRouter zur Laufzeit funktioniert. Wer
OpenRouter fährt, bekommt automatisch den engsten Modus und muss ihn von Hand
setzen:

```bash
gbrain config set search.mode tokenmax
```

**4. Zwei Konfigurationen mussten nachgezogen werden.** `doctor` fand beide:

- `subagent_capability` warnte, dass `dream`, `agent run` und `autopilot` bei
  der Job-Abgabe scheitern, weil das Chat-Modell nicht-Anthropic ist und kein
  `ANTHROPIC_API_KEY` existiert. Fix: `gbrain config set agent.use_gateway_loop true`.
- Der Reranker zeigte auf `voyage:rerank-2.5`, wofür es keinen Key gibt —
  folgenlos, solange er deaktiviert ist, aber ein Blindgänger. Auf
  `openrouter:cohere/rerank-v3.5` umgestellt.

### Der Lock-Vorfall

Nachgetragen am selben Tag, beim Abschalten der Skills. Zwischendurch schlug
`hermes mcp test gbrain` fehl (`✗ Connection failed (10615ms): Connection
closed`) und ein `hermes -z`-Durchlauf lieferte **leer bei Exit 0** — die
tückischste Variante, weil nichts nach einem Fehler aussieht.

Ursache, real gemessen:

```
PID 35816  bun … src/cli.ts --brain host serve
PPID 35645 python -m hermes_cli.main --profile wiki-llm serve --host 127.0.0.1 --port 0
.gbrain/brain.pglite/postmaster.pid  vorhanden
```

Ein hängengebliebener `gbrain serve`, Kind eines Hermes-`serve`, hielt das
PGLite-Datenverzeichnis. Jeder zweite `serve` — und `mcp test` startet genau
den — scheiterte am Lock. Nach `kill 35645` verschwand die `postmaster.pid`,
CLI und Chat liefen sofort wieder, und der nächste `-z`-Durchlauf hinterließ
**keinen** Halter mehr.

Damit ist die Designschranke aus Abschnitt 3 nicht mehr Theorie. Die
Betriebsanweisung daraus steht in [Abschnitt 0](#die-lock-falle).

### Real gemessen: die OpenRouter-Chat-Lane trägt

```
gbrain think "Was weisst du ueber projects/gbrain-setup?"
→ Model: openrouter:anthropic/claude-haiku-4.5 | Pages: 0 | … | exit 0
```

Chat und Expansion über OpenRouter funktionieren also nachweislich — was die
Anleitung in Schritt 2 gar nicht als Option führt. Offen bleibt die
**Embedding**-Lane: ohne Inhalte wurde nie eingebettet.

Nebenbei zeigte derselbe Aufruf die Trennung von Seiten und Fakten: `Pages: 0`,
obwohl `recall` den Fakt liefert. Siehe Abschnitt 0.

### Real gemessen: Skills abschalten wirkt profil-lokal

`--clone` schleppte 123 Skill-Verzeichnisse mit, die Hermes als 57 `builtin`,
19 `official` und 47 eigene `local` einordnet; dazu die 64 GBrain-Verzeichnisse
als weitere `local`. Abgeschaltet wurden die **48** lokalen Nicht-GBrain-Skills
über `skills.disabled`:

| | vorher | nachher |
|---|---|---|
| Profil `wiki-llm` | 187 aktiv | **139** aktiv (63 GBrain + 57 builtin + 19 official) |
| Profil `default` | 133 | 133 — unberührt |
| Profil `developer` | 70 | 70 — unberührt |

Zwei Details: `hermes config set` warnt, `skills.disabled` sei „not a recognized
config key" — der Schlüssel steht nicht in `DEFAULT_CONFIG`, wird aber von
`get_disabled_skills` (`hermes_cli/skills_config.py:28`) gelesen; die Warnung
ist folgenlos. Und GBrain liefert **63** Skills statt 64, weil `skills/conventions/`
kein `SKILL.md` hat: es ist das Verzeichnis der geteilten Konventionsdateien,
das andere Skills referenzieren.

`hermes-agent` lässt sich nicht abschalten (`ESSENTIAL_SKILLS`,
`agent/skill_utils.py:275`).

### Was `doctor` danach noch anmerkt

Keine FAIL-Checks, Brain-Score 100/100. Vier Warnungen, alle erwartbar:
`home_dir_in_worktree` (`.gbrain` liegt im Git-Worktree — hier Absicht, per
`.gitignore` abgedeckt), `retrieval_reflex_health` (braucht ein laufendes
`serve`, das liefert Hermes), `skill_preconditions` und `takes_count` (leeres
Brain bzw. Opt-in-Funktion).

### Was an Abschnitt 3 zu ergänzen ist

**135 MCP-Tools** landen im Hermes-Kontext. Das ist viel; ein
`mcp_servers.gbrain.tools.include`-Filter (`tools/mcp_tool_registration.py:208`)
würde das eindämmen. Im Lauf nicht gesetzt.

Und: `hermes profile create --clone` kopiert rund **47 MB** mit. Für ein reines
Wiki-Profil ist `--no-skills` womöglich die bessere Wahl — ungetestet.

---

## 7. Bestehenden Notizbestand importieren — der konkrete Fall

Ausgangslage: `~/github/hermes-llm-wiki-notes-vault` (bis 17.09.2026
`…-notes-for-import`), ein Obsidian-artiger
Bestand mit **3155 Dateien** in elf nummerierten Ordnern. Reine Analyse am
Quellcode und am Verzeichnis, Stand 16.09.2026 — importiert wurde nichts.

**Die drei Antworten vorweg:** Die 1580 Markdown-Dateien dürfen nach dem Import
weg, die 1479 Bilder nicht. Alles landet in genau einer Datei,
`~/github/hermes-llm-wiki-gbrain/.gbrain/brain.pglite`. Und ohne Vorarbeit
bekommen **alle 1580 Seiten den Typ `concept`**.

### Was von den 3155 Dateien überhaupt ankommt

`isAllowedByStrategy` (`core/sync.ts:272-288`) lässt in der Vorgabe-Strategie
`auto` nur Markdown und Code durch; Bilder ausschließlich dann, wenn
`GBRAIN_EMBEDDING_MULTIMODAL=true` gesetzt ist (`sync.ts:268-270`).

| Dateien | Anzahl | Import? | Was in der Datenbank landet |
|---|---|---|---|
| `.md` | 1580 | ja | Volltext in `pages.compiled_truth`, Chunks, Embeddings |
| `.html`, `.sh` | 17 | **ja, als Code-Seiten** | `page_kind='code'` — beide stehen in `CODE_EXTENSIONS` (`sync.ts:84-85`) |
| png/jpg/jpeg/gif/webp/heic | 1479 | nur mit Multimodal-Schalter | Pfad + OCR-Text + Vektor, **keine Bytes** |
| pdf, docx, epub, svg, ico, tiff, zip, xml, plist | 59 | nein | nichts, kommentarlos übersprungen |

Zwei stille Filter: Dateien mit den Namen `README.md`, `index.md`, `log.md`,
`schema.md`, `RESOLVER.md` werden immer übersprungen (`SYNC_SKIP_FILES`,
`sync.ts:540`) — in diesem Bestand null Treffer. Und `gbrain import` hat auf der
CLI **kein** `--exclude`; die Flag-Liste in `import.ts` kennt nur `--source`,
`--fresh`, `--no-embed`, `--workers`, `--json`, `--include-gitignored`,
`--allow-noncanonical-root`, `--cached`, `--others`, `--exclude-standard`,
`--log-noop`. Wer die 17 Code-Dateien nicht will, räumt sie vorher weg.

### Warum alles als `concept` landet

Der Typ wird **beim Import** gestempelt: `parseMarkdown` nimmt
`frontmatter.type`, sonst `inferTypeFromPack` (`core/markdown.ts:295-297`).
Gemessen an diesem Bestand:

| Signal | Messung |
|---|---|
| `type:` im Frontmatter | **0 von 1580** |
| `slug:` im Frontmatter | 0 (der Pfad bestimmt den Slug) |
| `title:` im Frontmatter | 1520 — bleiben erhalten |
| `tags:` im Frontmatter | 268 — gingen zunächst **verloren**, seit 17.09.2026 repariert: [Die Tag-Falle](#die-tag-falle-tags-pkm-system-ist-ein-yaml-kommentar) |
| Verzeichnisse, die auf ein `path_prefixes` von `gbrain-base-v2` passen | **keines** |

Der Abgleich ist `lower.includes('/people/')` (`markdown.ts:783-789`) —
`/07-people/` enthält kein `/people/`, `/05-projects-business/` kein
`/projects/`. Passt nichts, ist der Rückfallwert **`concept`**
(`markdown.ts:792`), nicht `note`.

### Nachträglich umtypen: geht, aber nicht mit `schema sync`

Das ist die Stelle, an der [Abschnitt 4](#4-vorhandene-notizen-vorher-hineinlegen-oder-nachträglich-importieren) zu
präzisieren ist. Dort steht, `gbrain schema sync --apply` backfille `page.type`
bestehender Zeilen. Das stimmt nur für **untypisierte** Zeilen: beide Abfragen
tragen `AND (type IS NULL OR type = '')` (`schema-pack/sync.ts:71` und
`:126`). Nach dem Import steht überall `concept` — nicht leer. `schema sync
--apply` fände also **null Zeilen**.

Der Weg, der trägt, sind Retype-Regeln: `retype.ts` kennt neben `from_type` ein
optionales `path_filter` (`source_path LIKE`) und ein `slug_filter`
(`retype.ts:51-58`). Eine Regel `from_type: concept` + `path_filter:
'07-people/%'` → `person` trennt also nach Ordner, ganz ohne die Quelldateien.
Ausgeführt wird sie vom geschützten Minion-Handler:

```bash
gbrain jobs submit unify-types --params '{"target_pack":"<pack>"}' --allow-protected --dry-run
```

(registriert in `commands/jobs.ts:3107-3115`, Schutzstatus in
`minions/protected-names.ts:54`).

Die dritte Variante — `gbrain reindex --markdown --force` — stempelt die Typen
ebenfalls neu, **liest dafür aber die Quelldateien wieder von der Platte**
(`reindex.ts:44-45`). Genau die Dateien also, die man loswerden wollte. Wer
löschen will, darf sich auf diesen Weg nicht verlassen.

Fazit für die Reihenfolge: das Schema **vor** dem Import zu klären ist die
billigere Variante, aber keine Einbahnstraße.

### Datumsfeld: der stille Totalausfall

`computeEffectiveDate` kennt nur `event_date`, `date`, `published` und ein
führendes `YYYY-MM-DD` im Dateinamen (`core/effective-date.ts:125-143`).
Dieser Bestand hat **1520 × `created:`, 0 × `date:`, 0 × `published:`**.
Ergebnis: jede Seite bekommt `effective_date_source = 'fallback'`, also die
Importzeit. Zeitfilter (`--since`/`--until`) und Recency-Ranking wären damit
wertlos, und der Doctor-Check `effective_date_health` ist genau dafür da, diese
„sieht befüllt aus, ist aber NULL-äquivalent"-Zeilen zu finden
(`effective-date.ts:21-23`).

Ein Suchen-und-Ersetzen `created:` → `date:` über die Kopie behebt das in einem
Durchgang.

### Die Reihenfolge

1. **Schema klären** — am 16.09.2026 ausgeführt, siehe
   [Der reale Schema-Lauf](#der-reale-schema-lauf-vom-16092026).
2. **Datumsfeld nachrüsten** — ebenda.
3. **MCP-Server stoppen.** Der Import hält den PGLite-Einzelschreiber-Lock über
   die gesamte Laufzeit; ein laufender `gbrain serve` aus dem Hermes-Profil
   blockiert ihn. Prüfen wie in [Abschnitt 0](#0-benutzung-chat-oder-cli) mit
   `ps aux | grep cli.ts`.
4. **Probelauf.** `gbrain import` hat kein `--dry-run`. Ersatz ist ein kleiner
   Ordner — aber Slugs entstehen relativ zum übergebenen Verzeichnis, ein
   `gbrain import …/08-thoughts` erzeugt `foo` statt `08-thoughts/foo`, und der
   spätere Vollimport findet diese Seiten nicht wieder. Also in eine
   Wegwerf-Quelle (`--source test`), danach
   `gbrain sources remove test --confirm-destructive`.
5. **Import.** `gbrain import ~/github/hermes-llm-wiki-notes-staging` — die
   Form, die `docs/INSTALL.md:87` als Massenimport nennt. **Nicht** der
   Master-Pfad: Quelle ist seit dem Schema-Lauf die Staging-Kopie. `--no-embed` gibt
   einen billigen Strukturdurchlauf ohne Modellkosten, Vektoren später per
   `gbrain embed --stale`. Abgebrochene Läufe setzen über den Checkpoint fort,
   `--fresh` beginnt von vorn.
6. **Indizierung nachziehen:** `gbrain extract --stale` (Links und Zeitleiste),
   dann `gbrain sources status` (Embedding-Abdeckung) und `gbrain doctor`.

### Warum das Löschen hier gefahrlos ist

Das Notizverzeichnis ist **kein Git-Repository** (nachgeprüft). Das ist an
dieser Stelle ein Vorteil: der gesamte Block, der `sync.repo_path`,
`sync.last_commit` und `sync.last_run` schreiben würde, hängt an
`if (gitHead && …)` (`import.ts:900-962`) und wird ohne `.git` nie betreten.
Die Quelle `default` trägt entsprechend weiterhin kein `local_path` — geprüft
per `gbrain sources list` vor dem Import: eine Quelle, 0 Seiten, „never
synced".

Damit bleibt **kein Zeiger auf das Notizverzeichnis zurück**, und auch ein
späterer `gbrain sync` kann die Seiten nicht wieder wegräumen: der Löschpfad
(`D`-Einträge im Git-Manifest → `deletePage`, `commands/sync.ts:2295ff`) setzt
eine registrierte, versionierte Quelle voraus, die es hier nicht gibt.

### Löschen: die Antwort zerfällt in drei Teile

| Was | In der Datenbank nach dem Import | Löschen? |
|---|---|---|
| `.md` (1580) | Rumpf in `pages.compiled_truth`, Chunks in `content_chunks`, Embeddings | **ja** |
| Bilder (1479) | nur `files.storage_path` als relativer Pfad, dazu OCR-Text und Vektor — die **Bytes werden nie kopiert** (`import-file.ts:2274`) | **nein** |
| pdf, docx, epub (59) | nichts | **nein**, und ohne jede Spur |

Nach dem Löschen importierter Bilder schlägt der Doctor-Check `image_assets` an:
er löst `storage_path` gegen die Repo-Wurzel auf und ruft `stat` — das Ergebnis
lautet „missing from disk, restore from git" (`doctor-asset-paths.ts`,
Kopfkommentar). Die 57 `.assets`-Ordner dieses Bestands gehören dazu.

Praktisch: den Ordner als Ganzes behalten, oder — wenn Platz das Thema ist — die
`.md` löschen und die `.assets`-Ordner stehen lassen.

Es gibt einen Weg, auch die Bytes in die Installation zu holen:
`storage.backend = 'local'` mit `localPath` unterhalb von `.gbrain/`
(`core/storage.ts:45-48`). Der ist hier aber **nicht** empfohlen: das
Local-Backend ist im Quelltext selbst als „for testing and development"
markiert (`storage/local.ts:5`), `gbrain files mirror` schreibt eine
`.supabase`-Markerdatei **in das Quellverzeichnis** (`files.ts:647-653`), und
`gbrain files redirect` löscht anschließend die Originale. Das gehört in einen
eigenen, vorsichtigen Versuch.

### Wo die Notizen am Ende liegen

Zwei Antworten, und die zweite ist die, die man meistens sucht.

**Physisch** in einer einzigen Datei:
`~/github/hermes-llm-wiki-gbrain/.gbrain/brain.pglite`. Keine durchsuchbaren
Markdown-Dateien mehr, nirgends.

**Logisch** über den Slug, abgeleitet aus dem Pfad relativ zum Importverzeichnis
ohne Endung. `validateSlug` (`core/utils.ts:37-58`) verbietet nur
Pfad-Traversal, Steuerzeichen, RTL-Overrides und Backslashes — Leerzeichen und
Umlaute bleiben, alles wird kleingeschrieben. Aus
`09-knowledge/345.26 AI und Karriere ….md` wird also
`09-knowledge/345.26 ai und karriere …`. Kollisionen wären ein Risiko, weil
`UNIQUE (source_id, slug)` gilt und die Kleinschreibung Groß-/Kleinvarianten
zusammenfallen lässt — in diesem Bestand geprüft: **0 Kollisionen**. Auch keine
Datei über 1 MB, damit kein Konflikt mit `MAX_FILE_SIZE = 5_000_000`
(`import-file.ts:276`).

Wiederfinden über `gbrain search`, `gbrain pages`, die Werkzeuge
`mcp__gbrain__*` oder schlicht im Chat — siehe Abschnitt 0. Zurück nach
Markdown führt nur `gbrain export --out <verzeichnis>`
(`commands/export.ts:14,139`).

### Die Nebenwirkung, die man kennen sollte

Weil `default` kein `local_path` bekommt, bleibt die Rückschreibung dauerhaft
auf `no_repo_configured` stehen (`core/write-through.ts:335-338`). Seiten, die
der Agent später im Chat anlegt, existieren dann **nur** in der Datenbank;
`gbrain export` ist der einzige Weg zurück zu Dateien.

Das ist der Preis für die Freiheit, das Quellverzeichnis löschen zu dürfen. Die
Alternative — `gbrain sources add notes --path …` plus `sync` — verbietet genau
dieses Löschen, weil dann jede fehlende Datei als Löschung interpretiert wird.


### Der reale Schema-Lauf vom 16.09.2026

Schritt 1 und 2 sind ausgeführt. Was dabei anders lief als oben geplant, steht
hier — die Planung darüber ist absichtlich nicht rückwirkend geglättet.

**Die Import-Quelle ist nicht mehr der Master.** Statt am Bestand selbst zu
arbeiten, liegt jetzt unter `~/github/hermes-llm-wiki-notes-staging` eine reine
Markdown-Kopie (1580 Dateien, 13 MB statt 591 MB). Gründe: die Platte ist zu
99 % voll, und der Master bleibt so unangetastet. (Ein dritter, damals
genannter Grund — `02-calendar/` und `11-readwise/` seien auto-sync-Ordner,
eine Änderung am Master werde überschrieben — hat sich am 17.09.2026 als
falsch erwiesen, siehe [Der eigentliche Vault](#der-eigentliche-vault-liegt-woanders).) Die 1479 Bilder sind bewusst **nicht** mitkopiert, weil
sie ohne Multimodal-Schalter ohnehin nicht importiert werden — sie existieren
damit nur noch im Master.

```bash
rsync -a --include='*/' --include='*.md' --exclude='*' <master>/ <staging>/
find <staging> -type d -empty -delete
```

#### Das Pack

`gbrain schema fork gbrain-base-v2 hermes-wiki-notes` legte
`.gbrain/schema-packs/hermes-wiki-notes/pack.json` an — innerhalb des
Zielpfads, wie in Abschnitt 3 vorhergesagt. Zwei Typen fehlten im
Basis-Pack und wurden ergänzt:

```bash
gbrain schema add-type task      --primitive temporal --prefix 03-tasks/     --pack hermes-wiki-notes
gbrain schema add-type flashcard --primitive concept  --prefix 12-flashcards/ --pack hermes-wiki-notes
```

Die übrigen Ordner gingen per `add-prefix` auf vorhandene Typen (Nummerierung
nach der Umnummerierung vom 17.09.2026, siehe unten):

| Ordner | Typ | warum |
|---|---|---|
| `02-calendar/` | `event` | Termine |
| `03-tasks/` | `task` (neu) | kein Aufgaben-Typ im Basis-Pack |
| `04-reports/` | `analysis` | generierte Auswertungen |
| `05-projects-business/` | `project` | |
| `06-projects-personal/` | `project` | |
| `07-people/` | `person` | |
| `08-companies/` | `company` | Firmenseiten (Ordner am 17.09. ergänzt) |
| `09-software/` | `software` (neu) | Softwareprodukte, Frameworks (Ordner am 17.09. ergänzt) |
| `10-thoughts/` | `note` | flüchtige Zettel — genau die Catch-all-Bedeutung |
| `11-knowledge/` | `concept` | permanente Zettel |
| `12-ressources/` | `source` | Quell- und Referenzmaterial |
| `13-readwise/` | `highlight` (neu) | Markierungen aus Büchern, PDFs, Webseiten |
| `14-flashcards/` | `flashcard` (neu) | kein Lernkarten-Typ im Basis-Pack |

**Warum `software` das Primitiv `concept` bekommt.** Die Alternativen taugen
nicht: `entity` bringt `works_at`, `founded`, `invested_in`, `advises` als
Standardverben und `email`/`location`/`role` als Frontmatter-Felder mit —
Personen- und Firmenvokabular. `media` bringt `cites`/`references`/`authored_by`
für Dokumente. `concept` liefert `relates_to`, `supersedes`, `mentions`, und
gerade **`supersedes` trifft den Software-Fall** (ein Framework löst ein
anderes ab). `extractable` ist gesetzt, damit Aussagen über Werkzeuge in die
Fakt-Extraktion gehen.

**Warum `highlight` und nicht `media` oder `source`.** Readwise-Einträge sind
Markierungen *aus* einem Werk — weder das Werk selbst (`media`) noch das
Originalmaterial (`source`). Funktional wäre die Wahl gleichgültig: alle drei
tragen das Primitiv `media` und sind `extractable`, und die sechs Subtypen von
`media` sind auf `^videos/`, `^books/`, `^articles/` verankert, feuern bei
`11-readwise/` also ohnehin nicht. Ausschlaggebend war die Verteilung — auf
`source` gelegt teilten sich 1008 Literaturnotizen und 23 Ressourcen einen Typ,
zwei Drittel des Wikis in einem Topf, obwohl die Ordner bewusst getrennt sind.

Gegenprobe mit der echten `inferTypeFromPack` über je eine reale Datei pro
Ordner: **elf von elf treffen den gewünschten Typ.** `schema validate` meldet
ein gültiges Manifest mit 22 Seitentypen; `schema lint` zeigt 59 Warnungen,
aber **exakt dieselben 59 wie `gbrain-base-v2`** — alle aus einer Kategorie
(`alias_references_undeclared_type`, eine Design-Eigenheit des v2-Alias-Graphen)
und null Fehler. Der Fork bringt keine neue Warnung mit.

#### Drei CLI-Fallen

**Ein Präfix und ein Alias dürfen nur einem Typ gehören — und eine abgelehnte
Mutation kann eine Lücke hinterlassen.** Beim Umhängen von `11-readwise/` von
`media` auf `highlight` scheiterte `add-type` an zwei Validierungsregeln
gleichzeitig: `alias_declared_by_two_types` (der Alias `ref` gehört bereits
`source`) und `prefix_collision` (`11-readwise/` hing noch an `media`). Das
zuvor abgesetzte `remove-prefix media 11-readwise/` war da aber **schon
durchgelaufen** — der Ordner hing einen Moment lang an gar keinem Typ und wäre
beim Import auf `concept` zurückgefallen. Reihenfolge ist also: erst
`remove-prefix`, dann `add-type` **ohne** kollidierenden Alias, und danach
zwingend `schema validate` plus eine Typ-Gegenprobe.

**`--pack` gilt nicht überall.** `add-type`, `add-prefix` und die übrigen
Mutationsverben nehmen `--pack <name>` (`schema.ts:949-957`); `validate` und
`lint` nehmen den Namen **positional** — `gbrain schema validate --pack foo`
antwortet mit `Unknown pack: --pack`.

**`gbrain config set schema_pack` scheitert an einer laufenden Hermes-Sitzung.**
Genau die Lock-Falle aus Abschnitt 0, hier zum zweiten Mal — diesmal aber
**kein verwaister Prozess**: Halter war ein `gbrain serve` (PID 95476) unter
`hermes_cli.main --profile wiki-llm serve`, dessen Großelternprozess die seit
Stunden laufende `Hermes.app` war. Diesen Halter beendet man nicht.

Der Ausweg ohne Datenbank: `schema_pack` ist ein Schlüssel der **Datei-Ebene**
(Tier 6, `.gbrain/config.json` — `schema active` weist ihn als
`Source: home-config` aus). Ein atomarer Schreibvorgang in diese Datei
aktiviert das Pack, ohne PGLite anzufassen — Stand unmittelbar nach der
Aktivierung, vor den späteren Mutationen:

```
Active pack: hermes-wiki-notes v0.0.1
Source: home-config
Pack identity: hermes-wiki-notes@0.0.1+b03d4323
Page types: 21
```

Der laufende `serve` hält seinen geladenen Pack im Prozess-Cache; er sieht das
neue Pack erst nach einem Neustart. Für den Import ist das ohne Belang — der
braucht den Lock ohnehin exklusiv.

Die Identität hinter dem `+` ist ein Inhalts-Hash und wandert bei **jeder**
Pack-Mutation weiter (`b03d4323` → … → `a6d78b4f` nach `highlight` und den
deutschen Mustern unten). Sie ist damit auch der Invalidierungsschlüssel des
Query-Caches — ein geänderter Pack entwertet zwischengespeicherte Antworten von
selbst.

#### Deutsche Muster für die Beziehungs-Erkennung

Vier Linkverben tragen im Basis-Pack eine `inference.regex`: `founded`,
`works_at`, `invested_in`, `advises`. Alle vier sind englisch formuliert. Die
Ergänzung um deutsche Alternativen hängt an zwei Eigenheiten der Ausführung,
die beide nicht in der Doku stehen:

**Die Muster laufen ohne Flags.** `runRegexBounded` kompiliert mit
`new RegExp(pattern)` (`redos-guard.ts:204`) — also **case-sensitive**.
Deutsche Substantive müssen großgeschrieben im Muster stehen, sonst greifen sie
nie. Angenehmer Nebeneffekt: `\bBerater\b` trifft **nicht** in
„Steuerberaterkammer".

**`\b` ist ASCII-basiert.** `\w` ist `[A-Za-z0-9_]`, ein Umlaut also kein
Wortzeichen. `\bÜbernahme` erzeugt deshalb **keine** Wortgrenze und läuft ins
Leere. Jede Alternative muss mit einem ASCII-Wortzeichen beginnen und enden;
Umlaute dürfen nur im Wortinneren stehen (`gegründet`, `tätig bei`, `berät`,
`Geschäftsführer`). Das lässt sich beim Schreiben maschinell prüfen.

Dazu die harte Schranke `NESTED_QUANTIFIER_RE` (`redos-guard.ts:88`): Muster
mit verschachtelten Quantoren werden zur Laufzeit **verweigert**, nie
ausgeführt. Die Ergänzungen kommen ohne `+` und `*` aus, nur `?`.

Die englischen Muster bleiben byte-identisch und werden um `|<deutsch>`
erweitert — Regression ausgeschlossen:

| Verb | ergänzt um |
|---|---|
| `founded` | gegründet · mitgegründet · gründete · Gründer/in · Mitgründer/in · Mitbegründer · Gründungsmitglied · Gründung von · ins Leben gerufen |
| `works_at` | arbeitet bei/für · arbeitete bei/für · tätig bei/für · angestellt bei · beschäftigt bei · Mitarbeiter/in bei/von · Geschäftsführer/in von/bei · Vorstand bei/von · wechselte zu/nach |
| `invested_in` | investierte/investiert in · investiert bei · Investor/in bei/von · beteiligt an · Beteiligung an · finanzierte · mitfinanziert |
| `advises` | berät · beriet · Berater/in · Beirat · im Beirat von · Advisor bei/von |

Gegenprobe mit der echten `inferLinkTypeFromPack` unter echtem
`PageRegexBudget`: **21 von 21** — vierzehn deutsche Treffer, vier englische
Regressionsfälle, drei Negativfälle.

Zwei Fehlalarme bleiben bewusst stehen: „staatlich **finanzierte** Projekte"
löst `invested_in` aus, „KI-**Beirat**" löst `advises` aus. Beide zeigen sich
erst im echten `extract links`-Lauf.

`mentions`, `discusses` und `relates_to` haben weiterhin **keine** Regex, und
das ist Absicht: die Auswertung nimmt den ersten Treffer in
Deklarationsreihenfolge (`link-inference.ts:70-84`), und diese drei stehen an
Position 1 bis 3 — ein Muster auf „erwähnt" würde jedes spezifischere Verb
dahinter dauerhaft verdecken. `sourced_from` und `derived_from` (Position 10
und 11) wären dagegen gefahrlos nachrüstbar.

#### Das Datumsfeld

`date:` wird aus `created:` **gespiegelt, nicht umbenannt** — `created` bleibt
stehen und landet als gewöhnlicher Frontmatter-Schlüssel in der JSONB-Spalte.
Kein Informationsverlust.

Gegenprobe mit `parseMarkdown` (Validierungsmodus) plus `computeEffectiveDate`
über **alle 1580 Dateien** der Staging-Kopie:

| Messung | Ergebnis |
|---|---|
| YAML-Parse-Fehler | **0** |
| `effective_date_source = 'date'` | **1520** |
| `effective_date_source = 'fallback'` | 60 (31 ohne Frontmatter, 29 mit Frontmatter ohne `created:`) |
| Seitentypen | highlight 1008 · concept 311 · project 180 · analysis 35 · source 23 · note 17 · flashcard 2 · event 2 · task 1 · person 1 = **1580** |

Die Typverteilung deckt sich Datei für Datei mit den Ordnergrößen — kein
`concept`-Sammelbecken mehr. Alle `created:`-Werte liegen zwischen 2020-08-18
und 2026-07-24, also innerhalb des Gültigkeitsfensters
`[1990-01-01, jetzt + 1 Jahr]` von `validateInRange`; keiner fällt heraus.

#### `04-reports/` bleibt draußen

Vor dem Import wurde der Chunker offline über den Bestand gefahren, um das
Embedding-Volumen zu kennen statt zu schätzen. Ergebnis: **3488 Chunks aus
1582 Seiten, rund 2,39 Mio Tokens** — und ein Missverhältnis:

| Ordner | Seiten | Chunks |
|---|---|---|
| `04-reports/` | 35 (2 %) | **1369 (39 %)** |
| alle übrigen | 1547 | 2119 |

Die 35 generierten Reports belegten 4,6 der 13 MB und erzeugten fast vier
Zehntel des Embedding-Volumens. Inhaltlich sind sie Ableitungen aus den
übrigen Notizen — ein Suchtreffer aus einem Report statt aus dem Originalzettel
wäre die schlechtere Antwort. Sie sind deshalb aus der Staging-Kopie entfernt
(im Vault bleiben sie).

Danach: **1547 Seiten, 2119 Chunks, rund 1,08 Mio Tokens** — weniger als die
Hälfte. Nebeneffekt: die Zahl undatierter Seiten fiel von 60 auf 30, die Hälfte
davon waren Reports.

Der Preis sind **6 tote Links**: so viele Verweise zeigen aus anderen Notizen
in den Reportordner hinein (die übrigen 42 Verweise darauf waren
reportintern). Beim Import ist das folgenlos — `addLink` überspringt ein
fehlendes Ziel stillschweigend. Das Präfix `04-reports/` → `analysis` bleibt im
Pack stehen; es ist jetzt ein totes Präfix, das `schema sync` als solches
ausweist, und wird wieder scharf, falls die Reports später doch mitsollen.

#### Die Tag-Falle: `tags: #pkm-system` ist ein YAML-Kommentar

Beim Anlegen der Beispielseite `09-software/Hermes Agent.md` fiel auf, dass die
Frontmatter-Konvention des Bestands nicht trägt. In YAML beginnt ein `#` nach
einem Leerzeichen einen **Kommentar** — `tags: #pkm-system` weist `tags` damit
den Wert `null` zu und wirft den Rest weg. Gemessen mit `parseMarkdown`:

| Schreibweise | Ergebnis |
|---|---|
| `tags: #pkm-system` | `[]` — **verloren** |
| `tags: #ressources, #pkm-system` | `[]` — **verloren** |
| `tags: "#pkm-system"` | `["#pkm-system"]` |
| `tags: "#ressources, #pkm-system"` | `["#ressources","#pkm-system"]` |
| YAML-Liste (`- pkm-system`) | `["pkm-system"]` |
| `tags: pkm-system` | `["pkm-system"]` |

Betroffen sind **268 Dateien** im Bestand. Deren Tags — `#mgm` (164×),
`#mgm-insurance` (93×), `#ressources` (63×), `#privat` (52×) und weitere —
erreichen die `tags`-Tabelle nicht. Kein Fehler, keine Warnung: die Zeile
verschwindet stillschweigend beim Parsen.

**Repariert am 17.09.2026** auf ausdrücklichen Wunsch. Gewählt wurde nicht das
Quotieren, sondern die kanonische YAML-Liste **ohne Raute**:

```yaml
tags:
  - mgm
  - mgm-insurance
```

Das ist die Form, die Obsidian für Frontmatter-Tags vorsieht, und sie liefert
in GBrain saubere Werte (`mgm` statt `#mgm`). Quotieren hätte nur GBrain
geholfen und die Raute in den Tagnamen geschleppt.

Die Erhebung vorab zeigte einen erfreulich einheitlichen Bestand: **269-mal**
die unquotierte Rautenform, **einmal** quotiert (die Beispielseite), keine
Listen, keine Inline-Arrays, keine Sonderzeichen außer `#`, Komma und
Bindestrich. Das Werkzeug `tools/fixtags.py` fasst deshalb ausschließlich die
`tags:`-Zeile innerhalb des Frontmatter-Blocks an und lässt eine vorhandene
Liste in Ruhe.

Ergebnis, mit `parseMarkdown` gegengeprüft: **265 Seiten** der Importquelle
tragen jetzt Tags, **21 verschiedene** insgesamt, null YAML-Fehler. Die
Häufigkeiten decken sich mit der Rohzählung — `mgm` 163, `mgm-insurance` 93,
`ressources` 58, `mgm-AI` 55, `privat` 52. Im Vault waren es 270 Dateien, fünf
davon in `04-reports/`, das in der Importquelle nicht mehr liegt.

Nicht verifiziert: ob Obsidian die Tags vorher tatsächlich auch verschluckt
hat. Es ist Standard-YAML, der Verdacht liegt nahe — geprüft habe ich nur den
GBrain-Parser. Die neue Form ist für beide Seiten die richtige.

#### Die Umnummerierungen vom 17.09.2026

Zwei Einschübe an einem Tag, beide nach demselben Muster. Erst kam
`08-companies/` dazu (Typ `company`, im Basis-Pack vorhanden) und alle
Folgeordner rückten um eins auf: `08-thoughts` → `09-thoughts`,
`09-knowledge` → `10-knowledge`, `10-ressources` → `11-ressources`,
`11-readwise` → `12-readwise`, `12-flashcards` → `13-flashcards`. Danach
`09-software/` (Typ `software`, neu angelegt) mit demselben Schub eins weiter:
`09-thoughts` → `10-thoughts` bis `13-flashcards` → `14-flashcards`.

Beim zweiten Mal war das Werkzeug generalisiert — `tools/renumber.py` nimmt die
Paare jetzt als Argumente (`alt=neu …`, dazu `--mkdir`) und sortiert die
Umbenennungen selbst absteigend nach führender Nummer. Der Durchgang meldete
3258 statt 3251 Verweise: die Differenz von genau sieben sind die
Fließtext-Nennungen, die das Muster seit der unten beschriebenen Lektion
mitnimmt.

**Im Pack** hieß das elf Mutationen. Reihenfolge: erst alle **neuen** Präfixe
anlegen, dann die alten entfernen. Umgekehrt stünde ein Typ wie `flashcard`
mit seinem einzigen Präfix kurzzeitig ohne da. Eine Kollision droht hier
nicht — alle neuen Namen sind eindeutig, anders als bei der `highlight`-Falle
oben, wo zwei Typen um *dasselbe* Präfix stritten.

**In den Notizen** sind die Verweise durchgängig markdownförmig mit absolutem
Vault-Pfad: `[Text](</10-knowledge/Datei.md>)`, teils in spitzen Klammern,
teils URL-kodiert. Betroffen waren **2276 Referenzen in 375 Dateien**, ganz
überwiegend auf `09-knowledge` (1586) und `08-thoughts` (325). Ersetzt wurde in
einem Durchgang mit einer Grenze davor — `(?<![0-9A-Za-z-])` —, damit ein
hypothetisches `109-knowledge/` nicht mitgerissen wird.

**Die Lektion aus dem ersten Durchgang:** das Muster verlangte anfangs einen
direkt folgenden Schrägstrich und ließ damit **sieben Nennungen im Fließtext**
stehen — Reporttitel wie „priorisierte Überführung in 09-knowledge /
10-ressources" und Aufzählungen wie ``Einzelne Zettel in `08-thoughts` ``.
Kaputt war dadurch nichts, aber die Texte waren falsch, und die
Erfolgsmeldung „null Restvorkommen" war zu eng gemessen. Seither steht hinten
ein `(?![0-9A-Za-z])` statt eines Schrägstrichs: das Muster trifft den
Ordnernamen als ganzes Token, mit Schrägstrich wie ohne.

Die Gegenprobe ist die aussagekräftigste des ganzen Umbaus: ein Linkchecker,
der jeden Markdown-Link gegen die tatsächlich vorhandenen Dateien auflöst,
liefert für Master **und** Staging **3172 von 3264 (97,2 %)** — Ziffer für
Ziffer identisch. Die 92 toten Links waren schon vorher tot; die Umnummerierung
hat keinen einzigen Link zerstört und keinen repariert.

Typverteilung und Datumsquellen bleiben nach dem Umbau unverändert, jetzt über
die neuen Präfixe aufgelöst.

**Der Master ist nachgezogen.** Zuerst lief nur die Staging-Kopie um; der
Master folgte am selben Tag auf ausdrückliche Ansage, weil eine Divergenz beim
nächsten `rsync` stillschweigend die alte Nummerierung zurückgeholt hätte.

Dabei kam eine Kategorie ans Licht, die in der Kopie gar nicht existiert:
**neun generierte HTML-Reports unter `04-reports/` verlinken mit
`href="/08-thoughts/…"`** — URL-kodiert, 975 weitere Vorkommen. Die
Staging-Kopie enthält nur Markdown, dort wäre das nie aufgefallen. Das Skript
läuft seither über `('.md', '.html')`; im Master waren es damit **3251
Referenzen in 384 Dateien** statt 2276 in 375.

Sicherheitsnetz vorab: ein Tar aller Dateien, deren *Inhalt* angefasst wird
(1596 Stück, 5,4 MB) — Ordnerumbenennungen sind ohnehin trivial umkehrbar.
Der Dateibestand danach unverändert: 1580 Markdown, 1479 Bilder, 3155 Dateien
gesamt, 57 `.assets`-Ordner. Markdown-Links lösen in beiden Bäumen weiter
3172 von 3264 auf.

Die Bildverweise sind ein eigener Fall. Ein naiver Prüfer meldete zunächst
**1 von 118** — ein Fehlalarm des Prüfers, nicht des Umbaus: Obsidian löst
Kurzformen wie `Fgzhrv1WQAIcnyV.jpeg` über einen Basename-Index auf, nicht
relativ zum Dokument. Mit dieser Auflösung sind es **98 von 118**, zwei sind
http-URLs und **18 waren schon vorher tot** (`zettel/assets/…` steht 46-mal im
Backup, einen Ordner `zettel` gibt es nicht). Entscheidend: **kein einziger
toter Verweis enthält einen umnummerierten Ordnernamen**, weder alt noch neu.

#### Der eigentliche Vault liegt woanders

Bei der Suche nach Abhängigkeiten des Pfades kam heraus, dass
`~/github/hermes-llm-wiki-notes-vault` **gar nicht der lebende Obsidian-Vault
ist**. Der steht laut `~/Library/Application Support/obsidian/obsidian.json`
unter `~/github/ai-notes-review-v3` — ein Git-Repo mit **2545** Markdown-Dateien
und zusätzlichen Ordnern (`00-inbox/`, `_archives/`, `_staging/`, `docs/` …).
Was hier umgebaut wurde, ist eine kuratierte Teilkopie davon: 1580 Dateien,
nur die Ordner 02 bis 12.

Das widerlegt zwei frühere Aussagen dieses Abschnitts.

**Die Sync-Werkzeuge schreiben nicht hierher.** Sie liegen unter
`ai-notes-review-v3/.claude/skills/` und leiten ihr Wurzelverzeichnis über
`git rev-parse --show-toplevel` **relativ zu ihrem eigenen Ort** ab
(`sync_readwise.py:8-13`) — also stets nach `ai-notes-review-v3`. Eine
Umbenennung hier erreicht sie nie. `sync_readwise.py` wird weiterhin brav nach
`ai-notes-review-v3/11-readwise` schreiben, und dort stimmt die Nummerierung
unverändert. **Es ist also nichts kaputt und nichts umzustellen** — die frühere
Warnung, die Readwise-Anbindung lege sonst `11-readwise/` neu an, ging von der
falschen Annahme aus, dieser Baum sei das Sync-Ziel.

**Und der Kopie drohte nie eine Überschreibung**, weil sie kein Sync-Ziel ist.
Der Umweg über die Staging-Kopie bleibt trotzdem richtig — nur aus den beiden
anderen Gründen (Plattenplatz, unversehrter Ausgangsbestand).

Die offene Frage ist damit eine andere: der lebende Vault trägt weiterhin die
**alte** Nummerierung und kennt weder `08-companies/` noch das `date:`-Feld.
Wer die Struktur dort ebenfalls will, muss `tools/renumber.py` und
`tools/adddate.py` gegen `ai-notes-review-v3` laufen lassen **und** die drei
Skripte nachziehen, die die Ordnernamen fest verdrahtet haben:
`sync_readwise.py:13`, `create_reports.py:21-24`, `create_daily_review.py`
(Zeilen 109, 335, 350, 353, 365, 441).

#### Der Importlauf vom 17.09.2026

Schritte 3 bis 7 in einem Zug, Hermes Desktop vorher beendet.

| Schritt | Ergebnis |
|---|---|
| `import --no-embed` | **1547 Seiten, 0 Fehler, 2157 Chunks in 17,7 s** |
| `embed --stale` | **2157 Chunks über 1547 Seiten in 41 s** |
| `extract --stale` | **0 Links, 0 Zeitleisteneinträge** — siehe unten |
| `doctor` | embed 35/35, dead-links 10/10, links 0/25, Brain-Score 45/100 |
| `search` | trägt (siehe unten) |
| `think` | 40 Seiten, 11 Zitate, `openrouter:anthropic/claude-haiku-4.5` |
| `hermes -p wiki-llm mcp test gbrain` | ✓ Connected (1640 ms), 135 Werkzeuge, kein Lock-Rest |

**Die Embedding-Spur über OpenRouter trägt** — der größte offene Posten der
Nicht-verifiziert-Tabelle ist damit erledigt. 2157 Chunks, keine Fehlschläge,
`embed=100%`, `embed_staleness: No stale chunks`.

**Real gemessen: die Suche trifft.** `search "Ontologie im Versicherungsumfeld"`
liefert fünf Treffer zwischen 0,88 und 0,82 — aus fünf verschiedenen Ordnern und
vier verschiedenen Typen (`project`, `concept`, `note`, `source`). Die
semantische Spur funktioniert quer über die Ordnergrenzen, ohne jede Kante.

#### Warum der Linkgraph leer blieb

`extract --stale` meldete `0 link(s)` und `Skipped 2951 candidate(s) whose
target page doesn't exist`. Die Ursache liegt in der Linksyntax des Bestands:

```
[Ontologie](</11-knowledge/075.92 Ontologie Linked Data RDF OWL.md>)
```

Durchgetestet gegen den echten `extractPageLinks` ergibt sich ein klares Bild —
**zwei unabhängige Blocker, jeder für sich tödlich**:

| Form | erkannt |
|---|---|
| `[X](</ordner/Datei mit Leerzeichen.md>)` — die Ist-Form | **nein** |
| `[X](/ordner/datei-slug.md)` — nur führender Slash | **nein** |
| `[X](ordner/Datei mit Leerzeichen.md)` — nur Leerzeichen | **nein** |
| `[X](ordner/datei-slug.md)` | ja |
| `[X](ordner/datei-slug)` | ja |
| `[X](<ordner/datei-slug>)` | ja |
| `[X](ordner/Datei-Gross.md)` | ja |
| `[[Basename]]` | ja |
| `[[ordner/datei-slug]]` | ja |
| `[X](ordner/075.92-name.md)` — Punktnummer, **ohne** spitze Klammern | ja, vollständig |
| `[X](<ordner/075.92-name.md>)` — Punktnummer, **in** spitzen Klammern | **Kandidat, aber am Punkt abgeschnitten** (`ordner/075`) |

Der **führende Schrägstrich** scheitert an `ENTITY_REF_RE`
(`link-extraction.ts:195`): das Ziel muss mit einem Verzeichnissegment
`[a-z0-9][a-z0-9_-]*` beginnen, nicht mit `/`. Die **Leerzeichen** scheitern am
Zielmuster `[^)\s#]+?`, das Whitespace ausschließt. Großbuchstaben sind
unschädlich.

> **Nachtrag 18.09.2026 — spitze Klammern sind es nicht.** Hier stand, spitze
> Klammern seien unschädlich. Das gilt nur für Ziele ohne Punkt. Steht eine
> Punktnummer im Namen — also bei der Nummerierung dieses Bestands —, endet das
> Ziel in der spitze-Klammer-Form **am Punkt**:
>
> ```
> [X](ordner/075.92-name.md)    → ordner/075.92-name     vollständig
> [X](<ordner/075.92-name.md>)  → ordner/075             abgeschnitten
> ```
>
> Das ist der stillere Fehler: kein ausbleibender Kandidat, sondern ein
> falscher. Für eine Reparatur der 1214 internen Links heißt das, dass die
> Zielform **ohne** spitze Klammern geschrieben werden muss — sonst brechen
> genau die 139 punkt-nummerierten Ziele, ohne dass es auffällt.
>
> Die Tabelle oben ist davon unberührt; sie wurde Zeile für Zeile nachgetestet
> und stimmt. Betroffen war nur dieser Absatz.

Einen Konfigurationsschalter dafür gibt es nicht — unter `link_resolution.*`
existieren nur `global_basename` und `cross_source`.

Was dadurch fehlt: `graph_signals` (0 % Seiten mit eingehenden Links),
`entity_link_coverage` 0 %, `timeline_coverage` 0 %, 1524 von 1524 Seiten als
Orphans, und `think` arbeitet mit `Graph: 0`. Suche, `think` und die Typen sind
davon **nicht** betroffen — die tragen über Vektoren und Volltext.

Ein Ausweg zeichnet sich ab: **alle 1547 Basenames im Bestand sind eindeutig.**
Damit wären Obsidian-Wikilinks (`[[075.92 Ontologie Linked Data RDF OWL]]`)
kollisionsfrei auflösbar — sie sind Obsidians native Form und werden von GBrain
erkannt. `doctor` weist bereits darauf hin: von 229 bereits vorhandenen bare
Wikilinks würden 25 auflösen. Die Umstellung wäre ein Eingriff in rund 1210
Links und ist **nicht** vollzogen.

#### Eine Typabweichung, aufgeklärt

Die Offline-Vorhersage sagte `event` 2 / `note` 17, das Brain zeigt `event` 1 /
`note` 18. Ursache ist `applyInference` (`import-file.ts:1381-1392`): für
Dateien **ohne Frontmatter** synthetisiert GBrain welches — inklusive `type` —
und ein expliziter Typ schlägt in `parseMarkdown` die Pfad-Inferenz des Packs.
Der Auffangfall der `DIRECTORY_RULES` ist `{ pathPrefix: '', type: 'note' }`
(`frontmatter-inference.ts:208`).

Betroffen ist genau **eine** Seite: `02-calendar/calendar` (ohne Frontmatter)
wurde `note` statt `event`. Nachgewiesen durch eine Offline-Reproduktion des
Importpfads *mit* `applyInference` — sie trifft die Zahlen des Brains exakt.
Wer hier Pack-Treue will, gibt den betroffenen Dateien ein Frontmatter.

**Typverteilung im Brain, 100 % typisiert, 0 untypisiert:** highlight 1008 ·
concept 311 · project 180 · source 23 · note 18 · flashcard 2 · company 1 ·
event 1 · person 1 · software 1 · task 1.

---

## Durch den Lauf erledigt

Diese Punkte standen bis zum 16.09.2026 in der Tabelle unten und sind jetzt
gemessen:

| vormals offen | Ergebnis |
|---|---|
| Ob `gbrain init` mit `GBRAIN_HOME` außerhalb des Home durchläuft | ✅ läuft; `~/.gbrain` entsteht nicht |
| Ob der handgebaute Launcher für Hermes funktioniert | ✅ `bin/gbrain --version` → `gbrain 0.50.5.0`, MCP-Handshake 1476 ms |
| Ob Hermes die GBrain-Frontmatter klaglos lädt | ✅ `brain-ops`, `signal-detector` u. a. stehen als `local` im Index; Kategoriespalte bleibt leer, sonst unauffällig |
| Ob `skills.external_dirs` mit einem Pfad außerhalb von HERMES_HOME greift | ✅ 111 lokale Skills im Profil, darunter die scaffoldeten |
| Ob `skills.external_dirs` als Liste akzeptiert wird | ✅ `config set` schrieb eine echte YAML-Liste, der Loader nimmt sie |
| Ob `--clone` eine ausreichende Modellkonfiguration liefert | ✅ vom aktiven Profil `default` (OpenRouter, `z-ai/glm-5.3-flash`); der `hermes -z`-Durchlauf gelang damit |
| Der Befehlsblock aus Abschnitt 5 | ✅ ausgeführt, bis auf `--env GBRAIN_HOME` (bewusst weggelassen, der Launcher räumt `GBRAIN_*` ohnehin ab) |
| Welche Version hinter `latest-stable` steht | ✅ Tag zeigt auf `668b9ba` — derselbe Commit wie die Analyse |
| Ob die PGLite-Single-Writer-Schranke im Betrieb wirklich beißt | ✅ zugeschlagen, inklusive der stillen Variante „leer bei Exit 0" — siehe [Der Lock-Vorfall](#der-lock-vorfall) |
| Ob Chat und Expansion über OpenRouter tragen | ✅ `gbrain think` antwortete über `openrouter:anthropic/claude-haiku-4.5` |
| Wie die GBrain-Werkzeuge im Agenten heißen | ✅ `mcp__gbrain__*` mit zwei Unterstrichen — die Doku schreibt einen |
| Ob sich Skills profil-lokal abschalten lassen | ✅ 187 → 139 in `wiki-llm`, `default` und `developer` unverändert |
| Alles ab `import` in der Reihenfolge aus Abschnitt 4 | ✅ am 17.09.2026 gelaufen — [Der Importlauf](#der-importlauf-vom-17092026) |
| Ob die **Embedding**-Lane über OpenRouter trägt | ✅ 2157 Chunks in 41 s, `embed=100%`, keine Fehlschläge |
| Ob `search` und `query` sinnvolle Treffer liefern | ✅ fünf Treffer 0,88–0,82 aus vier Typen; `think` 40 Seiten / 11 Zitate |
| Ob `schema fork` + `add-prefix` die Präfixe so schreibt, dass `inferTypeFromPack` sie sieht | ✅ elf von elf Ordnern treffen den gewünschten Typ — siehe [Der reale Schema-Lauf](#der-reale-schema-lauf-vom-16092026) |

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Ob eine **private** Bun-Laufzeit unter `runtime/` funktioniert | der Lauf nutzt das System-Bun (`/opt/homebrew/bin/bun`) über den Launcher-Pfad. Echte Isolation der Bun-Version ist ungetestet — auf einem Rechner ohne Bun schlägt `setup.sh` fehl statt nachzuinstallieren |
| Portabilität von `brain.pglite` zwischen Rechnern und Architekturen | weiterhin nicht getestet — nur auf diesem Mac erzeugt. Gegenmittel bleibt der Rebuild aus `memory/` |
| Welche GBrain-Version `bun install -g github:garrytan/gbrain` liefert | dieser Weg wurde nicht benutzt; installiert wurde per `git clone` + Tag |
| Kontextkosten von 187 aktivierten Skills im Profil | gezählt, nicht gemessen. `docs/guides/scaling-skills.md` behandelt das, ungelesen |
| Kosten und Nutzen des `tools.include`-Filters für die 135 MCP-Tools | nicht gesetzt; nur `tools/mcp_tool_registration.py:208` gelesen |
| Ob `--no-skills` beim `profile create` die 47 MB vermeidet | nicht probiert |
| Ob `gbrain capture` funktioniert | als MCP-Werkzeug vorhanden, nie aufgerufen. Der Schreibweg ist am Quelltext gelesen (Kernkonzept), nicht ausgeführt |
| Ob sich nachträglich ein Schreibziel anhängen lässt | `gbrain sources set-path` ist dafür gebaut (`sources-set-path.ts:1-16`) und nur gelesen, nicht ausgeführt — ebenso die Variante über `sync.repo_path` |
| Woher der verwaiste `serve` im Lock-Vorfall stammte | der Elternprozess (`--profile wiki-llm serve --port 0`) war eindeutig, sein Auslöser nicht — weder `mcp add` noch `-z` hinterließen im Nachtest einen Halter |
| Ob `skills.disabled` auch Hub- und Builtin-Skills abschaltet | nur an lokalen Skills erprobt; `skills opt-out --remove` ist laut Hilfetext die Lane für Bundled-Skills, ungetestet |
| Ob der Reranker über OpenRouter funktioniert | bewusst deaktiviert gelassen; nur das Modell umgestellt |
| Verhalten der Fünf-Stufen-Postgres-Leiter (`init --prefer-postgres`) | PGLite gewählt; die Leiter blieb unberührt |
| Tatsächliche Kosten eines Re-Embed beim Provider-Wechsel | weiterhin nur die Aussage der Migrations-Skill |
| Ob `gbrain schema sync --apply` bestehende Seiten verlustfrei umtypt | leeres Brain, nichts umzutypen |
| Ob die Umbenennungs-Erkennung in `sync` greift | kein `sync` gelaufen |
| Ob `sync` wirklich `git init` auslöst | der Zielordner wurde **vorher** zum Git-Repo gemacht, genau um das zu vermeiden — der Pfad blieb ungetestet |
| Vollständigkeit der Liste „was außerhalb landet" | der Lauf bestätigt sie für diesen Weg; ein `autopilot --install`, `sources harden`, `mounts add` oder `integrations` würde weitere Pfade anfassen, keiner davon wurde ausgeführt |
| Ob `setup.sh` auf einem fremden Rechner durchläuft | nur `bash -n` geprüft; die Registry-Erkennung und der Profil-Zweig sind auf diesem Rechner nie in ihren jeweils anderen Ast gelaufen |
| Ob die OpenRouter-Embedding-Spur Bilder (Multimodal) überhaupt kann | nie ausgeführt; `embedMultimodal` nicht auf Provider-Unterstützung geprüft |
| Ob `GBRAIN_EMBEDDING_MULTIMODAL=true` aus `.gbrain/.env` durchschlägt | der Loader setzt jeden Schlüssel ohne Whitelist (`gbrain-env-file.ts:56`) und der Launcher exportiert diesen Namen nicht — beides spricht dafür, gemessen ist es nicht |
| Verhalten von `gbrain sync` auf einem `local_path` **ohne** `.git` | der Code deutet auf einen vollen Walk hin, nachgewiesen ist es nicht |
| Laufzeit und Modellkosten für 1580 Dateien / 10,3 MB Markdown | keine Messung |
| Ob Retype-Regeln mit `path_filter` über `unify-types` wirklich nach Ordnern trennen | nur am Quelltext gelesen (`retype.ts:51-58`), nie submittet |
| Ob eine Umstellung auf Wikilinks den Graphen wirklich füllt | **am 18.09.2026 nachgemessen: nur zu 64 %.** Von den 442 verlinkten Zielen, die als Datei existieren, lösen 281 eindeutig als `[[Basename]]` auf, 0 mehrdeutig. Die übrigen scheitern an einem Drift zwischen `normalizeBasename` (Linkauflösung) und `slugifyPath` (Slug-Erzeugung): 139 an der Punktnummer (`075.92` → Slug behält den Punkt, die Normalisierung entfernt ihn), 22 an Doppel-Bindestrichen (`GTD- und` → der Slug kollabiert sie, die Normalisierung nicht). Die Eindeutigkeit der Basenames genügt also nicht. Die Umstellung selbst ist weiterhin nicht vollzogen |
| Ob `link_resolution.global_basename` die 229 vorhandenen bare Wikilinks hebt | `doctor` schätzt 25 Auflösungen, gesetzt wurde das Flag nicht |
| Ob `gbrain reconcile-links` an der Linksyntax etwas ändert | nicht ausgeführt |
| Kosten des Embedding-Laufs in Euro | 2157 Chunks gemessen, Abrechnung beim Provider nicht eingesehen |
