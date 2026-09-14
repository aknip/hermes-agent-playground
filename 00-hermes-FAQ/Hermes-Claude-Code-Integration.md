# Claude Code als Backend für ein Hermes-Profil

**Stand:** 13.09.2026 · Recherche. **Weg B ist inzwischen gebaut** — siehe
[`04-hermes-claude-code-provider/`](../04-hermes-claude-code-provider/). Zwei Aussagen
dieses Dokuments haben sich dabei als falsch erwiesen; sie sind unten markiert.

**Ausgangsfrage:** Kann man einem Hermes-Profil die **Claude-Code-CLI** (nicht die API)
als LLM zuweisen, so dass das Profil seine Aufgaben über die lokale Claude-Code-Instanz
ausführt?

Belegart je Aussage:
· **QUELLTEXT** = in `~/.hermes/hermes-agent/` nachgelesen
· **WEB** = externe Quelle, unten verlinkt

---

## Kurzantwort

Es gibt **drei** Wege, und sie beantworten unterschiedliche Fragen:

| Weg | Macht Claude Code zum *Modell*? | Aufwand | Status |
|---|---|---|---|
| **A — Mitgelieferter Skill** (Delegation) | nein | **null** | **empfohlen** |
| **B — Provider-Plugin** (ACP/MCP-Subprozess) | **ja** | Eigenbau | **gebaut** (04-…) |
| **C — Credentials leihen** | nein (ist API) | null | ToS-Problem |

**Empfehlung (Stand der Recherche):** Weg A nehmen. Weg B nur bauen, wenn sich die
Delegation als zu wenig erweist. Weg C bewusst verwerfen.

**Nachtrag:** Weg B *ist* gebaut, weil Weg A das gestellte Ziel nicht erfüllt — bei der
Delegation bleibt die Orchestrierungsschleife beim Profilmodell. Wer nur die Codierarbeit
abgeben will, ist mit Weg A weiterhin besser bedient; wer das ganze Profil über Claude
Code fahren will, nimmt [04-…](../04-hermes-claude-code-provider/).

---

## Weg A — Der mitgelieferte Skill (empfohlen)

**Liegt bereits auf der Platte** (QUELLTEXT):

```
~/.hermes/hermes-agent/skills/autonomous-ai-agents/claude-code/SKILL.md
```

745 Zeilen, Version 2.2.1, Autor „Hermes Agent + Teknium", MIT.
Doku: `/docs/user-guide/skills/bundled/autonomous-ai-agents/autonomous-ai-agents-claude-code`

### Bauform: Delegation, nicht Provider

Hermes ruft die CLI über sein `terminal`-Werkzeug:

```
terminal(command="claude -p 'Add error handling to all API calls in src/'
                  --allowedTools 'Read,Edit' --max-turns 10",
         workdir="/path/to/project", timeout=120)
```

**Die entscheidende Einschränkung:** Das Modell des Profils bleibt das Gehirn und
entscheidet, *wann* es abgibt. Die Codierarbeit landet bei Claude Code, die
Orchestrierungsschleife nicht. Das ursprüngliche Ziel „**alle** Aufgaben über Claude
Code" erfüllt das nicht — nur Weg B täte das.

### Was der Skill kann (QUELLTEXT)

| Fähigkeit | Flags |
|---|---|
| Sitzungskontinuität | `--resume <id>`, `--continue`, `--fork-session` |
| Maschinenlesbare Ergebnisse | `--output-format json`, `--json-schema`, Streaming-JSON |
| CI-Modus | `--bare` (überspringt Hooks, Plugins, MCP-Discovery, CLAUDE.md) — ⚠ **nicht** für Weg B: laut eigener Hilfe ist die Anthropic-Anmeldung dann *strikt* `ANTHROPIC_API_KEY`, „OAuth and keychain are never read“. Das zerstört die Abo-Anmeldung und damit das ToS-Argument. |
| Leine | `--allowedTools`, `--max-turns`, `--max-budget-usd`, `--fallback-model` |
| Modus 1 | Print (`-p`) — einmalig, kein PTY, **überspringt alle Dialoge** |
| Modus 2 | Interaktiv über tmux — mehrstufig, braucht Dialogbehandlung |

### Für einen unbeaufsichtigten Kanban-Worker

**Nur Print-Mode.** Der tmux/PTY-Weg braucht Dialogbehandlung (Workspace-Trust,
Permissions-Bestätigung), die ein autonomes Profil nicht leisten kann. Die Leine liegt
bei `--allowedTools` plus `--max-turns`.

Voraussetzungen: `npm install -g @anthropic-ai/claude-code`, einmal `claude` zum
Anmelden, v2.x+.

---

## Weg B — Provider-Plugin (macht Claude Code zum Modell)

Der Mechanismus existiert, ein fertiger Provider nicht.

### Was Hermes schon hat (QUELLTEXT)

```python
# hermes_cli/auth.py:191
ProviderConfig("copilot-acp", "GitHub Copilot ACP", "external_process", ...)

# providers/base.py:87-90
process_command: str = ""             # "copilot"
process_args: tuple = ()              # ("--acp", "--stdio")
process_command_env_vars: tuple = ()
process_args_env_var: str = ""
```

`copilot-acp` ist der Beweis, dass eine lokale CLI als Provider läuft. Das ganze Plugin
sind **30 Zeilen** (`plugins/model-providers/copilot-acp/__init__.py`), und sein eigener
Docstring sagt:

> *„An out-of-tree ACP provider (`~/.hermes/plugins/model-providers/` or a pip entry
> point) uses the same three lines without touching core."*

### Wo es hinkommt

```
mkdir -p ~/.hermes/plugins/model-providers/claude-code-mcp/
```

> ⚠ **Korrektur (13.09.2026, beim Bau gefunden).** Dieser Pfad genügt **nur für das
> Standardprofil**. Ein Hermes-Profil ist sein eigenes `HERMES_HOME`:
> `hermes -p <profil>` setzt es auf `~/.hermes/profiles/<profil>`
> (`hermes_cli/main.py:435`, `hermes_constants.py:102`), und
> `providers._user_plugins_dir()` sucht unter `$HERMES_HOME/plugins/model-providers/`.
> Ein nur ins Root-Home gelegtes Provider-Plugin ist für jedes benannte Profil
> unsichtbar und endet in `Unknown provider` (`hermes_cli/auth.py:1471`). Es muss
> **zusätzlich** nach `~/.hermes/profiles/<profil>/plugins/model-providers/`.

Achtung, zwei verschiedene Ladepfade (QUELLTEXT, `providers/__init__.py`):
- `plugins/model-providers/<name>/` → wird nach Provider-Profilen durchsucht
- `plugins/<name>/` → dorthin klont `hermes plugins install`, flach

Das Verzeichnis `model-providers/` existiert hier **noch nicht**; es wäre handzulegen.
Inhalt: `plugin.yaml` (`kind: model-provider`) + `__init__.py` mit einer
`ProviderProfile`-Unterklasse, deren `create_client` den eigenen Client liefert, plus
`register_provider(...)`.

### Die zwei Haken (QUELLTEXT, `agent/acp_openai_bridge.py`)

Die Datei ist **generisch** — null Copilot-Erwähnungen, also wiederverwendbar. Aber:

**1. ACP hat keinen strukturierten Tool-Kanal.**
> *„ACP has no OpenAI-style `tools`/`tool_calls` channel, so Hermes' tool schemas travel
> INTO the prompt as text and calls are parsed back OUT of the response text."*

Werkzeugaufrufe werden per Regex (`TOOL_CALL_BLOCK_RE`) aus dem Antworttext gefischt.

**2. Der Quelltext kennt den Claude-Code-Fall bereits und warnt davor.**
> *„a CLI with no tools of its own forwards everything; an autonomous agent with its own
> read/edit/execute tools forwards only Hermes' agent-level tools, since re-offering
> overlapping ones makes Hermes redo finished work."*

Copilot hat keine eigenen Werkzeuge, Claude Code schon. Ein Plugin bräuchte also eine
nicht-leere `allowlist` (`acp_openai_bridge.py:90`) — oder den besseren Kniff aus Weg D.

> ⚠ **Korrektur (13.09.2026).** Beides ist unnötig. `--tools ""` entfernt Claude Codes
> eingebaute Werkzeuge **vollständig** — die `system/init`-Zeile listet danach nur noch
> die durchgereichten MCP-Werkzeuge. Damit entsteht die Kollision gar nicht erst, und
> die `allowlist` ist überflüssig. Real gemessen, siehe
> [RUN-PROTOKOLL.md](../04-hermes-claude-code-provider/RUN-PROTOKOLL.md).

### Was der Betrieb zusätzlich verlangt (nachgetragen 14.09.2026)

Die Recherche endete beim Mechanismus. Der Bau hat gezeigt, was darüber hinaus nötig ist
— Belege in [`04-…/VERIFIKATION.md`](../04-hermes-claude-code-provider/VERIFIKATION.md):

- **Das Plugin muss in *jedes* Profil-Home**, nicht nur ins Root-Home (siehe Korrektur
  oben). `install.sh` rollt deshalb in beide aus.
- **Alle vier Modell-Schlüssel** (`model.default`, `.provider`, `.base_url`,
  `.api_mode`) müssen in der Profil-`config.yaml` stehen, sonst ist das Profil nicht
  dispatchbar — die bekannte Hermes-Invariante gilt auch hier.
- **Ein Gateway, der vor dem Einbau lief, kennt das Plugin nicht.**
  `providers/__init__.py` merkt sich seine Erkennung (`_discovered`), also einmalig
  `hermes gateway restart`. Für spätere Modellwechsel ist das *nicht* nötig.
- **Modell und Denktiefe kommen aus Hermes** und wirken zur Laufzeit: `model.default`,
  `-m`, `/model` und `hermes kanban set-model` schlagen alle durch. Reasoning läuft über
  den Provider-Haken `build_api_kwargs_extras`, weil dieser Client die Transport-Schicht
  überspringt.
- **Für das 1M-Kontextfenster sind zwei Schlüssel nötig:** `opus[1m]` versorgt Claude
  Code, `model.context_length: 1000000` versorgt Hermes — das sonst 256.000 schätzt und
  entsprechend früh komprimiert. Gemessen: ein größeres Fenster verschiebt die
  Kompression wirklich nach hinten, kostet aber mehr Token je Zug.
- **Hilfsaufrufe** (`auxiliary.compression`, `.title_generation`, `.kanban_decomposer`)
  stehen auf `provider: auto` und lösen sonst auf die CLI auf — je Aufruf ein
  Kaltstart. Sie gehören auf eine billige Route festgenagelt.

### Stand bei Nous (WEB)

- Issue **#78563** „Add Claude Code CLI backend provider" — **offen** seit 04.08.2026,
  keine Maintainer-Äußerung, nicht zugewiesen
- Issue **#48320** „claude-code provider that shells out to `claude -p`" — **als
  Duplikat geschlossen**

Weder Zusage noch Absage. Auf ein natives Feature sollte man nicht warten.

---

## Weg C — Credentials leihen (bewusst verwerfen)

Hermes liest `~/.claude/.credentials.json` bereits (QUELLTEXT):

```
hermes_cli/config.py:2650   use_anthropic_claude_code_credentials()
agent/anthropic_credentials.py  read_claude_code_credentials()
hermes_cli/model_setup_flows.py:1028-1030
```

Funktioniert sofort, kostet nichts — **ruft aber `api.anthropic.com`**. Das ist die API,
nicht die CLI, und damit nicht die gestellte Frage. Siehe Nutzungsbedingungen unten.

---

## Weg D — Was von Pi zu übernehmen wäre

Pi löst genau die Schwäche, die Weg B hat.

**Der Kniff** ([`pi-claude-cli`](https://github.com/rchern/pi-claude-cli/), WEB):
Pis eigene Werkzeuge werden Claude Code über einen **Schema-only-MCP-Server** angeboten
— nur Definitionen, keine Implementierungen. Dazu ein **Break-early-Muster**, das die
CLI daran hindert, sie selbst auszuführen. *Claude schlägt vor, der Host führt aus.*

Warum das besser ist als die mitgelieferte Brücke:

1. **MCP ist Claude Codes nativer Kanal** — strukturierte Tool-Definitionen statt
   Text-im-Prompt und Regex-Parsing.
2. **Es löst die Werkzeugkollision an der Wurzel.** Die `allowlist` aus Weg B ist
   Verzicht; Break-early braucht ihn nicht — Claude Code *sieht* die Werkzeuge und führt
   sie trotzdem nicht aus.

**Zweite Idee:** `claude -p --resume`, eine CLI-Sitzung je Host-Sitzung. Deshalb liegt
Pis Tokenverbrauch nahe an dem der CLI selbst.

> **Nachtrag (13.09.2026).** Das Break-early-Muster ist gar nicht nötig: ein
> MCP-`tools/call` darf blockieren (90 s gemessen, Zeitlimit je Server über `timeout`
> im `--mcp-config` einstellbar). Der Host beantwortet den geparkten Aufruf, und
> dieselbe CLI-Sitzung macht im selben Prozess weiter — der Sitzungsneubau, den
> `pi-claude-bridge` mit ~58 % Cache-Verlust beziffert, entfällt damit ganz.

**Der ehrliche Gegenposten** ([`pi-claude-bridge`](https://github.com/elidickinson/pi-claude-bridge), WEB):
dokumentiert **~58 % Prompt-Cache-Verlust gegenüber ~26 %** bei einfachem Resume —
*„Sessions get rebuilt more often than they need to be, and a rebuild is expensive."*
Die Sitzungsidentität ist die teure Stelle, nicht der Subprozess.

> **Eigene Messung (13.09.2026).** Der blockierende Weg hält den Cache *innerhalb eines
> Zuges* warm: 1.259 bzw. 1.294 gelesene Cache-Token gegen **0** im stateless-Betrieb
> (später bis 2.639 von 2.643 Prompt-Token). Die Aussage der Bridge wird damit auf der
> eigenen Maschine bestätigt — und der Grund dafür beseitigt, statt ihn zu bezahlen.
> **Über Hermes-Züge hinweg** ist `--resume` allerdings *nicht* umgesetzt; dort baut
> jeder neue Zug die CLI-Sitzung neu auf. Für einen Kanban-Worker (eine Karte ≈ ein Zug
> mit vielen Werkzeug-Umläufen) ist der Gewinn innerhalb des Zuges der entscheidende.

---

## Verworfen: die Kette Hermes → Pi → Claude Code

Technisch real:

```
Hermes (external_process/ACP) → pi-acp → pi --mode rpc → pi-claude-cli → claude -p
```

Vier Prozesse, **drei verschachtelte Agenten-Schleifen** mit je eigener Werkzeugschicht.
Der Fehlermodus, vor dem Hermes' Docstring warnt, wird dadurch größer, nicht kleiner.

Blocker aus [`pi-acp`](https://github.com/svkozak/pi-acp)' eigener README (WEB):
- „MVP-style", *„Expect some minor breaking changes"*
- **MCP-Server werden nicht zu Pi durchgereicht** — das killt ausgerechnet Weg D
- keine ACP-Delegation für Dateisystem und Terminal

Man stapelte drei Schichten, um am Ende wieder auf der Textbrücke zu landen.
**Die Idee übernehmen, nicht die Kette.**

---

## Nutzungsbedingungen — die Trennlinie

[`pi-claude-auth`](https://pi.dev/packages/pi-claude-auth) leiht sich das OAuth-Token und
ruft Anthropic direkt. Der Disclaimer des Pakets (WEB):

> *„Anthropic's Terms of Service state that Claude Pro/Max subscription tokens should
> only be used with official Anthropic clients."*

Das ist **derselbe Mechanismus wie Weg C**. Damit hat Weg C einen belegten Einwand gegen
sich.

Wird dagegen `claude` gestartet (Wege A, B, D), führt **der offizielle Client** die
Anfrage aus. Das ist die stärkere Position — **aber keine Freigabe**: ob der offizielle
Client, gesteuert von einem fremden Harness, gedeckt ist, hat Anthropic nicht
entschieden. Die Einschätzung bleibt beim Betreiber.

---

## Entscheidung

**Weg A nehmen.** Mitgeliefert, unterstützt, sofort nutzbar, bessere ToS-Lage.
Preis: das Profilmodell verbraucht weiter eigene Tokens für die Orchestrierung, und
„alle Aufgaben über Claude Code" ist es nicht.

**Weg B bauen, wenn A zu wenig ist.** — **Ist gebaut:**
[`04-hermes-claude-code-provider/`](../04-hermes-claude-code-provider/). Mit dem
MCP-Kniff aus Weg D statt der mitgelieferten Textbrücke, aber ohne Break-early: der
MCP-Aufruf blockiert, bis Hermes geliefert hat. Nachgewiesen bis zur Kanban-Karte Ende
zu Ende.

**Weg C nicht.**

Die Umsetzung mit allen Messwerten liegt in
[`04-hermes-claude-code-provider/`](../04-hermes-claude-code-provider/): elf
protokollierte Läufe vom blockierenden MCP-Aufruf bis zur Kanban-Karte Ende zu Ende,
dazu eine Liste dessen, was ausdrücklich **nicht** verifiziert ist.

### Randnotiz aus dem ESF-Abbau

`autonomous-ai-agents` war an **alle zwölf** ESF-Profile verteilt. Ob die kopierte
Fassung den `claude-code`-Unterskill enthielt, ist nicht mehr nachprüfbar — die Profile
sind am 13.09.2026 gelöscht worden (siehe `DEINSTALLATION-ANALYSE.md`). Unerheblich:
der Skill kommt mit Hermes mit und ist bei jedem neuen Profil wieder da.

---

## Quellen

**Lokal (QUELLTEXT)**
- `~/.hermes/hermes-agent/skills/autonomous-ai-agents/claude-code/SKILL.md`
- `~/.hermes/hermes-agent/hermes_cli/auth.py` (Provider-Registry, `external_process`)
- `~/.hermes/hermes-agent/providers/base.py`, `providers/__init__.py` (Plugin-Ladepfade)
- `~/.hermes/hermes-agent/plugins/model-providers/copilot-acp/` (30-Zeilen-Vorlage)
- `~/.hermes/hermes-agent/agent/acp_openai_bridge.py` (generische Brücke)
- `~/.hermes/hermes-agent/hermes_cli/config.py:2650`, `model_setup_flows.py:1028`

**Web**
- [Hermes: Claude Code Skill](https://hermes-agent.nousresearch.com/docs/user-guide/skills/bundled/autonomous-ai-agents/autonomous-ai-agents-claude-code)
- [Hermes: Provider-Doku](https://hermes-agent.nousresearch.com/docs/integrations/providers)
- [Issue #78563](https://github.com/NousResearch/hermes-agent/issues/78563) · [Issue #48320](https://github.com/NousResearch/hermes-agent/issues/48320)
- [pi-claude-cli](https://github.com/rchern/pi-claude-cli/) · [pi-claude-bridge](https://github.com/elidickinson/pi-claude-bridge) · [pi-claude-auth](https://pi.dev/packages/pi-claude-auth) · [pi-acp](https://github.com/svkozak/pi-acp)
- [claude-code-cli-acp](https://github.com/moabualruz/claude-code-cli-acp) · [@zed-industries/claude-code-acp](https://www.npmjs.com/package/@zed-industries/claude-code-acp)
