# GBrain als LLM-Wiki für Hermes: was wohin installiert wird

**Stand:** 16.09.2026 · Zuerst Recherche, am selben Tag **real installiert**.
Das Zielverzeichnis `~/github/hermes-llm-wiki-gbrain` ist angelegt und läuft;
der protokollierte Lauf steht in [Abschnitt 6](#6-der-reale-lauf-vom-16092026).
Abschnitte 1 bis 5 sind unverändert die Analyse **vor** dem Lauf — was der Lauf
widerlegt oder bestätigt hat, steht jeweils in Abschnitt 6, nicht rückwirkend
eingearbeitet.

**Ausgangsfrage:** [GBrain](https://github.com/garrytan/gbrain) soll als Wiki für
Hermes Agent dienen, die Inhalte nach `~/github/hermes-llm-wiki-gbrain`. Was
installiert die Anleitung **außerhalb** dieses Pfades — und lässt sich alles
(Profile, Skills, Skripte, Laufzeit) so hineinlegen, dass eine self-contained,
auf andere Rechner übertragbare Lösung entsteht?

---

## Beweislage

Drei ungleiche Quellen sind im Spiel; sie werden hier nicht vermischt.

| Quelle | Status |
|---|---|
| Hermes-Quelltext `~/.hermes/hermes-agent/` | **v0.21.2 (2026.9.11)** — nicht die im Repo festgeschriebene v0.20.0. Alle Hermes-Zitate gelten für 0.21.2. |
| GBrain-Quelltext | `VERSION 0.50.5.0`, sha `668b9ba`. Zur Analysezeit ein `master`-Klon nach `/tmp`; der Lauf hat dann gezeigt, dass Tag `latest-stable` **auf genau diesen Commit** zeigt — Analyse und Installation stehen auf demselben Stand. |
| Protokollierter Lauf | 16.09.2026, `~/github/hermes-llm-wiki-gbrain`. Alles mit „Real gemessen" markierte in Abschnitt 6 stammt daher. |
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
| Schema-Pack | Sieben-Stufen-Auflösungskette (`schema.ts:160-167`): CLI-Flag, `GBRAIN_SCHEMA_PACK`, pro Source, brain-weit, `gbrain.yml`, `config.json`, Default. Umstellbar per `gbrain config set schema_pack`; `gbrain schema sync --apply` backfillt `page.type` bestehender Zeilen (`schema.ts:154`) |
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

## Was ich **nicht** verifiziert habe

| Aussage | Warum offen |
|---|---|
| Ob eine **private** Bun-Laufzeit unter `runtime/` funktioniert | der Lauf nutzt das System-Bun (`/opt/homebrew/bin/bun`) über den Launcher-Pfad. Echte Isolation der Bun-Version ist ungetestet — auf einem Rechner ohne Bun schlägt `setup.sh` fehl statt nachzuinstallieren |
| Portabilität von `brain.pglite` zwischen Rechnern und Architekturen | weiterhin nicht getestet — nur auf diesem Mac erzeugt. Gegenmittel bleibt der Rebuild aus `memory/` |
| Welche GBrain-Version `bun install -g github:garrytan/gbrain` liefert | dieser Weg wurde nicht benutzt; installiert wurde per `git clone` + Tag |
| Kontextkosten von 187 aktivierten Skills im Profil | gezählt, nicht gemessen. `docs/guides/scaling-skills.md` behandelt das, ungelesen |
| Kosten und Nutzen des `tools.include`-Filters für die 135 MCP-Tools | nicht gesetzt; nur `tools/mcp_tool_registration.py:208` gelesen |
| Ob `--no-skills` beim `profile create` die 47 MB vermeidet | nicht probiert |
| Alles ab `import` in der Reihenfolge aus Abschnitt 4 | `memory/` ist leer — `import`, `embed --stale`, `schema detect/sync`, `extract links/timeline` sind nicht gelaufen |
| Ob die semantische Suche über OpenRouter im Lauf trägt | `doctor` bestätigt Konfiguration und Schemabreite (1536d), aber ohne Inhalte wurde nie eingebettet oder semantisch gesucht |
| Ob der Reranker über OpenRouter funktioniert | bewusst deaktiviert gelassen; nur das Modell umgestellt |
| Verhalten der Fünf-Stufen-Postgres-Leiter (`init --prefer-postgres`) | PGLite gewählt; die Leiter blieb unberührt |
| Tatsächliche Kosten eines Re-Embed beim Provider-Wechsel | weiterhin nur die Aussage der Migrations-Skill |
| Ob `gbrain schema sync --apply` bestehende Seiten verlustfrei umtypt | leeres Brain, nichts umzutypen |
| Ob die Umbenennungs-Erkennung in `sync` greift | kein `sync` gelaufen |
| Ob `sync` wirklich `git init` auslöst | der Zielordner wurde **vorher** zum Git-Repo gemacht, genau um das zu vermeiden — der Pfad blieb ungetestet |
| Vollständigkeit der Liste „was außerhalb landet" | der Lauf bestätigt sie für diesen Weg; ein `autopilot --install`, `sources harden`, `mounts add` oder `integrations` würde weitere Pfade anfassen, keiner davon wurde ausgeführt |
| Ob `setup.sh` auf einem fremden Rechner durchläuft | nur `bash -n` geprüft; die Registry-Erkennung und der Profil-Zweig sind auf diesem Rechner nie in ihren jeweils anderen Ast gelaufen |
