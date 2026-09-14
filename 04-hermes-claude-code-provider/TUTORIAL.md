# Claude Code als Modell eines Hermes-Profils

Einbau, Betrieb und Rückbau des Provider-Plugins `claude-code-mcp`.

Voraussetzungen: Hermes Agent v0.20.0, Claude Code CLI ≥ 2.1 (`claude --version`),
einmal `claude` interaktiv gestartet und angemeldet, `python3` im `PATH`.

---

## 1. Was hier passiert

Ein Hermes-Profil bekommt die lokale `claude`-CLI als **Modell**. Nicht als Werkzeug,
das ein anderes Modell bei Bedarf ruft (das ist der mitgelieferte
`autonomous-ai-agents/claude-code`-Skill), sondern als das Gehirn des Profils: die
Orchestrierungsschleife läuft mit in der CLI.

```
Hermes AIAgent (Profil claude-dev)
   │  create(messages, tools=[read_file, terminal, …])
   ▼
ClaudeCodeClient              client.py — baut argv, hält die Sitzung, liest stream-json
   │  claude -p --tools "" --mcp-config … --session-id …
   ▼
claude (CLI, werkzeuglos)     das Modell + Hermes' System-Prompt
   │  MCP-Aufruf: mcp__hermes__read_file({...})
   ▼
mcp_server.py                 meldet Hermes' Werkzeuge an, führt keines aus
   │  Unix-Socket, Schlüssel = toolUseId
   ▼
Rendezvous  ──►  Client gibt den Aufruf an Hermes zurück
                 Hermes führt aus — mit seinen Approvals, seinem Logging, seinem Kanban
            ◄──  der nächste create() liefert das Ergebnis
   │
   ▼
mcp_server.py kehrt zurück  ──►  claude macht im selben Prozess weiter
```

Zwei Entscheidungen tragen das Ganze:

**`--tools ""` — Claude Code bekommt keine eigenen Werkzeuge.** Kein `Read`, kein
`Edit`, kein `Bash`. Alles läuft über Hermes zurück. Das löst die Werkzeugkollision,
vor der `agent/acp_openai_bridge.py` warnt, an der Wurzel — die dort nötige `allowlist`
entfällt, und Hermes' Approval-Gate bleibt für jede Dateiänderung zuständig.

**Der MCP-Aufruf blockiert, statt abzubrechen.** `pi-claude-cli` bricht die CLI nach
dem Werkzeugvorschlag ab und baut die Sitzung später neu auf; `pi-claude-bridge` misst
dafür ~58 % Cache-Verlust. Hier wartet der MCP-Server einfach, bis Hermes geliefert hat.
Gemessener Unterschied: 1259 gelesene Cache-Token im residenten Betrieb gegen 0 im
stateless (siehe [RUN-PROTOKOLL.md](RUN-PROTOKOLL.md), Lauf 3).

---

## 2. Einbau

```bash
cd 04-hermes-claude-code-provider
./install.sh claude-dev
```

Erwartete Ausgabe:

```
==> Plugin ausrollen
    /Users/…/.hermes/plugins/model-providers/claude-code-mcp
    /Users/…/.hermes/profiles/claude-dev/plugins/model-providers/claude-code-mcp
==> Registrierung prüfen
    root-home              Profil+Registry=ja CLI=/Users/…/.local/bin/claude
    profil:claude-dev      Profil+Registry=ja CLI=/Users/…/.local/bin/claude
```

> **Zwei Ziele, kein Versehen.** Ein Profil ist sein eigenes `HERMES_HOME`
> (`hermes_cli/main.py:435`, `hermes_constants.py:102`). Ein nur nach
> `~/.hermes/plugins/` gelegtes Provider-Plugin ist für `hermes -p claude-dev`
> **unsichtbar** und endet in `Unknown provider` (`hermes_cli/auth.py:1471`).
> Die FAQ nennt nur den Root-Pfad; das gilt nur für das Standardprofil.

## 3. Profil umstellen

```bash
./switch-profile.sh claude-dev
```

Das Skript sichert zuerst (`config.yaml.pre-claude-code-<zeitstempel>.bak`), setzt dann
**alle vier** Modell-Schlüssel — ein Profil ist nur dispatchbar, wenn sie in
`~/.hermes/profiles/<name>/config.yaml` stehen:

```yaml
model:
  default: sonnet
  provider: claude-code-mcp
  base_url: claude-code://cli
  api_mode: chat_completions
```

Danach nagelt es `auxiliary.compression`, `.title_generation` und `.kanban_decomposer`
auf die billige Route fest, für die das Profil schon Zugangsdaten hat. Grund: diese
Blöcke stehen auf `provider: auto` und lösen sonst auf den Hauptprovider auf — je
Kompression und je Kanban-Zerlegung ein CLI-Kaltstart. Wer das bewusst anders will:

```bash
HERMES_CC_AUX_PROVIDER=claude-code-mcp ./switch-profile.sh claude-dev
```

Prüfen:

```bash
hermes -p claude-dev config get model
hermes kanban --board <slug> assignees      # claude-dev muss ON DISK = yes zeigen
```

## 3a. Modell und Denktiefe umstellen

Beides kommt aus Hermes, nicht aus dem Plugin:

```bash
hermes -p claude-dev config set model.default opus            # sonnet | opus | fable | haiku
hermes -p claude-dev config set agent.reasoning_effort xhigh  # s. Tabelle unten
```

**Modell.** Alles, was `claude --model` frisst: die öffentlichen Aliase `sonnet`,
`opus`, `fable`, `haiku` oder ein voll qualifizierter Name (`claude-opus-5`,
`claude-fable-5-1`, `claude-haiku-4-5-20251001`). Ein angehängtes `[1m]`
(`opus[1m]`, `sonnet[1m]`) **aktiviert** Claude Codes 1M-Kontextfenster — es setzt den
Beta-Header `context-1m-2025-08-07`, den die CLI je Modell an der Fähigkeit
`supports_1m_beta` festmacht. Ohne Suffix kein 1M. Dazu gehört immer
`model.context_length: 1000000`, sonst schätzt Hermes 256.000 (siehe README). Ein vorangestelltes `anbieter/` schneidet das Plugin ab.

Wirksam sind damit auch `/model` in der Sitzung und die Karten-Übersteuerung
`hermes kanban set-model <task-id> fable` (das Modell ist positional; `none` löscht
die Übersteuerung wieder).

**Denktiefe.** Hermes kennt sieben Stufen, Claude Codes `--effort` fünf; die Enden
werden zusammengefaltet:

| `agent.reasoning_effort` | `--effort` |
|---|---|
| `minimal`, `low` | `low` |
| `medium` *(Vorgabe des Profils)* | `medium` |
| `high` | `high` |
| `xhigh` | `xhigh` |
| `max`, `ultra` | `max` |
| `none` / `false` | `low` — Claude Code kennt kein Abschalten |

Belegt mit echten Läufen: `--model opus --effort xhigh` → die CLI fuhr
`claude-opus-5`; `--model fable --effort max` → `claude-fable-5-1`.

Reihenfolge, wenn mehrere Quellen etwas sagen: **Hermes gewinnt**, dann
`HERMES_CLAUDE_CODE_MODEL` bzw. `HERMES_CLAUDE_CODE_EFFORT`, dann die Vorgaben
(`sonnet`, `medium`). Die Umgebungsvariablen sind der Notausgang zum Ausprobieren —
umgekehrte Reihenfolge hieße, dass ein vergessenes `export` jede Profiländerung
still schluckt.

### Auswahl statt Tippen: der `providers:`-Block

Im Auswahlfeld der Desktop-App steht ohne Zutun nur ein Eintrag, `claude-code-mcp` —
das ist die aktuelle Auswahl, kein Modell. Ein Provider-Plugin mit
`auth_type="external_process"` kommt an den Auswähler grundsätzlich nicht heran
(`hermes_cli/models_catalog_static.py:361-363`), auch nicht über `fallback_models`.

```bash
./install.sh --with-model-picker claude-dev
```

Das schreibt einen `providers:`-Block mit vier Modellen in die `config.yaml` des
Profils — und zwar nur dort, wo `model.provider` bereits `claude-code-mcp` ist. Danach
bietet das Auswahlfeld `sonnet[1m]`, `opus[1m]`, `haiku` und `fable` unter dem Titel
„Claude Code CLI (MCP)" an.

Der Block trägt außerdem je Modell ein `context_length`. Das ist der einzige Weg, auf
dem ein Kontextfenster einen `/model`-Wechsel zur Laufzeit übersteht: `model.context_length`
wird dabei gelöscht (`agent/agent_runtime_helpers.py:1963-1964`) und danach aus diesem
Block neu hergeleitet (`:2017`). Gemessen in Lauf 13.

Rückbau: `./uninstall.sh` entfernt den Block mit (`--keep-profile` lässt die
`config.yaml` unangetastet); gezielt geht auch
`hermes -p claude-dev config unset providers.claude-code-mcp`.

## 4. Für den Kanban-Betrieb: Gateway neu starten

`kanban.dispatch_in_gateway: true` — die Worker laufen im langlebigen
Gateway-Prozess, und der merkt sich seine Provider-Erkennung (`providers/__init__.py`,
`_discovered`). Ein Gateway, der vor dem Einbau gestartet wurde, kennt das Plugin nicht
und scheitert mit demselben `Unknown provider`.

```bash
hermes gateway restart
```

⚠ Bricht laufende Agenten ab. Vorher `hermes gateway status` lesen.

Für den interaktiven Betrieb (`hermes -p claude-dev -z …`) ist das **nicht** nötig.

## 5. Betrieb

```bash
hermes -p claude-dev -z "Lies notiz.txt und nenne mir das Geheimwort."
```

Mitlesen, was zwischen CLI und Hermes passiert:

```bash
HERMES_CLAUDE_CODE_DEBUG=/tmp/cc.log hermes -p claude-dev -z "…"
grep "\[mcp\]" /tmp/cc.log
```

```
[mcp] Start, 25 Werkzeuge angemeldet
[mcp] call toolu_019xoCxPXztnrXvdpFGahqME read_file
[mcp] done toolu_019xoCxPXztnrXvdpFGahqME is_error=False
```

⚠ Die Datei enthält Prompt-Inhalte (Profilgedächtnis, Skills-Schnappschuss). Nicht
committen.

> ⚠ **Nicht zwei Hermes-Prozesse auf dasselbe Profil loslassen.** Hat die Desktop-App
> `claude-dev` offen und läuft parallel ein `hermes -p claude-dev -z …`, schreiben beide
> auf `profiles/claude-dev/state.db`. Hermes zieht dann WAL-Generationen zurück und
> bricht Züge ab — sichtbar als *„No reply: the turn was stopped because a live Hermes
> process held a retired state.db-wal generation"* und als leere Assistentenantworten.
> Das ist kein Fehler dieses Providers, aber beim Bau genau so passiert. Zum Testen ein
> eigenes Profil nehmen oder die App schließen.
>
> Die laufende Datenbank nimmt dabei keinen Schaden: die abgezweigten Nachrichten landen
> in `sessions/<id>.jsonl`, und die zurückgezogene Generation liegt daneben in
> `state.db.retired-wal-*/` mit `manifest.json`. Vor dem Zurückspielen erst
> `hermes sessions recover --source <…>/state.db --inspect-only` lesen und mit der
> lebenden Datenbank vergleichen — ist die schon weiter, gehören die alten Frames nicht
> darauf.

### Stellschrauben

Alle optional, alle als Umgebungsvariablen.

| Variable | Vorgabe | Wirkung |
|---|---|---|
| `HERMES_CLAUDE_CODE_COMMAND` · `CLAUDE_CLI_PATH` | `claude` (aus `PATH`) | Binärpfad |
| `HERMES_CLAUDE_CODE_MODEL` | *leer* | `--model`, **nur** wenn Hermes nichts übergibt |
| `HERMES_CLAUDE_CODE_EFFORT` | *leer* | `--effort`, **nur** wenn Hermes nichts übergibt |
| `HERMES_CLAUDE_CODE_MODE` | `resident` | `resident` \| `stateless` |
| `HERMES_CLAUDE_CODE_BUDGET_USD` | *leer* | setzt `--max-budget-usd`, wenn belegt |
| `HERMES_CLAUDE_CODE_MCP_TIMEOUT_MS` | `600000` | hartes Zeitlimit je Werkzeugaufruf |
| `HERMES_CLAUDE_CODE_ORPHAN_TIMEOUT` | `300` | Frist, nach der eine verwaiste Sitzung abgeräumt wird |
| `HERMES_CLAUDE_CODE_SYSTEM_PROMPT_MODE` | `replace` | `replace` \| `append` |
| `HERMES_CLAUDE_CODE_CWD` | aktuelles Verzeichnis | Arbeitsverzeichnis der CLI |
| `HERMES_CLAUDE_CODE_PYTHON` | `python3` | Interpreter für den MCP-Server |
| `HERMES_CLAUDE_CODE_ARGS` | *leer* | zusätzliche CLI-Argumente |
| `HERMES_CLAUDE_CODE_DEBUG` | *leer* | Protokolldatei |

**Ohne Budgetgrenze.** So entschieden: `--max-budget-usd` ist standardmäßig nicht
gesetzt. Ein durchgedrehter Worker hat damit keine Obergrenze je Aufruf.

### Die drei Zeitlimits, und warum sie gestaffelt sind

| Frist | Vorgabe | Wer |
|---|---|---|
| Rendezvous-Wachhund | 300 s | das Plugin — räumt ab, wenn Hermes nicht zurückkommt |
| MCP-`timeout` je Server | 600 s | Claude Code — harte Wanduhr je Aufruf |
| `agent.gateway_timeout` | 1800 s | Hermes |

Die mittlere Frist bemisst sich am **Werkzeug**-Budget (`terminal.timeout: 180` plus
`approvals.timeout: 60` plus Reserve), nicht am Gateway-Budget. Stünde sie auf 1800 s,
hinge ein verwaister Aufruf eine halbe Stunde — die schlechteste Fehlerform für einen
unbeaufsichtigten Worker. Der Wachhund liegt darunter, damit so ein Fall schnell und
mit lesbarer Meldung scheitert.

---

## 6. Fehlersuche

| Symptom | Ursache |
|---|---|
| `Unknown provider 'claude-code-mcp'` bei `hermes -p <profil>` | Plugin liegt nicht im Home **des Profils**. `./install.sh <profil>` |
| Dasselbe, aber nur beim Kanban-Dispatch | Gateway kennt das Plugin nicht. `hermes gateway restart` |
| `Could not find the 'claude-code-mcp' CLI command` | `claude` nicht im `PATH`. `HERMES_CLAUDE_CODE_COMMAND` setzen |
| Die CLI endet sofort | `claude` ist nicht angemeldet. Einmal interaktiv starten |
| Werkzeuge kommen nie an | `grep "\[mcp\]"` im Debug-Log; wenn dort nur „Start" steht, hat das Modell keines gerufen |
| Der Lauf hängt | Wachhund greift nach 300 s. `HERMES_CLAUDE_CODE_ORPHAN_TIMEOUT` senken zum Nachstellen |
| Desktop zeigt `Opus[1m]` statt `opus[1m]` | Anzeige-Kosmetik der App; `config get model` zeigt den echten Wert |
| Hermes meldet 256.000 statt 1.000.000 | `model.default` und aktives Modell weichen ab (Schreibweise zählt) oder `model.context_length` fehlt |
| `model.context_length` wird abgelehnt | Hermes erzwingt mindestens 64.000 |
| `--continue` setzt die Sitzung nicht fort | Bekannt; `--resume <session-id>` benutzen |
| `could not reach the claude-code-mcp API to validate …` | Erwartbar: der Provider hat keinen `/models`-Endpunkt. Kosmetik |

---

## 7. Rückbau

```bash
./uninstall.sh claude-dev
```

Spielt das Profil aus der jüngsten Sicherung zurück, entfernt den `providers:`-Block
der Modellauswahl, beide Plugin-Kopien und verwaiste Rendezvous-Ordner unter
`/tmp/hcc-*`. Was es tun würde, ohne es zu tun:

```bash
DRY_RUN=1 ./uninstall.sh claude-dev
```

Nur die Dateien, Profil unangetastet — dann bleibt auch der `providers:`-Block stehen
und böte weiter vier Modelle eines entfernten Providers an:

```bash
./uninstall.sh claude-dev --keep-profile
```

Ein nach dem Rückbau noch laufender Gateway hält das Plugin weiter im Speicher —
`hermes gateway restart`, wenn das stören würde.

---

## 8. Was das **nicht** ist

- **Keine Sitzungsfortsetzung über Hermes-Züge.** `--resume` ist nicht umgesetzt; jeder
  neue Zug baut die CLI-Sitzung aus dem vollen Transkript neu auf. Der Cache-Gewinn
  liegt innerhalb eines Zuges — für einen Kanban-Worker (eine Karte ≈ ein Zug mit
  vielen Werkzeug-Umläufen) ist das der Fall, auf den es ankommt.
- **Keine Token-Zahlen auf Werkzeug-Runden.** `usage` kommt erst mit dem Abschluss der
  CLI; auf Runden mit `finish_reason=tool_calls` meldet der Client Nullen.
- **Keine Freigabe durch Anthropic.** Es startet der offizielle Client, was die
  stärkere Position ist als geliehene Zugangsdaten — aber ob das, gesteuert von einem
  fremden Harness, gedeckt ist, hat Anthropic nicht entschieden.

Vollständig in [VERIFIKATION.md](VERIFIKATION.md), Abschnitt „Was ich **nicht**
verifiziert habe".
