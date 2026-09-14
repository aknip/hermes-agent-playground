# Verifikation

Der Verifikationsvertrag dieses Repos deckt **Hermes** ab: jede Aussage am lokalen
Quelltext der installierten Version, zitiert als `datei.py:123`. Die **Claude-Code-CLI**
deckt er nicht — ihr Quelltext ist ein gebündeltes Binary, ihre Online-Doku ist keine
Quelle. Aussagen über sie sind deshalb nur durch **protokollierte Läufe** belegt.

Diese Datei ist entsprechend zweigeteilt.

---

## A — Am Hermes-Quelltext belegt

Alle Pfade relativ zu `~/.hermes/hermes-agent/` (v0.20.0).

| Aussage | Beleg |
|---|---|
| Ein Provider-Plugin registriert sich ohne Core-Eingriff | `providers/__init__.py` — `_user_plugins_dir()`, `_import_plugin_dir()`; Ladepfad `$HERMES_HOME/plugins/model-providers/<name>/` |
| Ein `external_process`-Profil landet automatisch in `PROVIDER_REGISTRY` | `hermes_cli/auth.py:264` (`_register_plugin_provider`), Aufrufschleife `:285-289` |
| Ein Plugin-Profil ohne `HERMES_OVERLAYS`-Eintrag löst trotzdem auf — sofern `base_url` nicht leer ist | `hermes_cli/providers.py:211-225`, `source="plugin-profile"` |
| Unbekannte Provider scheitern an dieser Schranke | `hermes_cli/auth.py:1471` (`resolve_provider`, `Unknown provider`) |
| **Ein Profil ist sein eigenes `HERMES_HOME`** | `hermes_cli/main.py:435` (`-p`/`--profile` → Profilpfad), `hermes_constants.py:102` (`get_hermes_home`) |
| Der Client-Vertrag ist `.chat.completions.create(...)` plus `close()`/`is_closed` | `agent/copilot_acp_client.py:241-280` |
| Ein eigener Client umgeht Transport- und Async-Wrapper | `HERMES_SKIP_TRANSPORT_WRAP` → `agent/auxiliary_client.py:1822`; `HERMES_SKIP_ASYNC_WRAP` → `:4336` |
| Aufrufstellen von `create_client` | `agent/agent_runtime_helpers.py:1613` (Hauptpfad), `agent/auxiliary_client.py:4890` (Hilfsaufrufe) |
| Hermes baut Clients mitten im Lauf neu (Stream-Retry, Credential-Rotation, Fallback-Restore, `switch_model`) | Kommentare in `agent/agent_runtime_helpers.py:1700-1760` |
| `HOME` muss ans Kind durchgereicht werden | `agent/copilot_acp_client.py:103-125` (`_resolve_home_dir`, `apply_subprocess_home_env`) |
| Die mitgelieferte ACP-Brücke reicht Werkzeuge als **Text** durch und parst sie per Regex zurück | `agent/acp_openai_bridge.py` — Modul-Docstring, `TOOL_CALL_BLOCK_RE` |
| …und warnt ausdrücklich vor überlappenden Werkzeugschichten | ebd.: *„an autonomous agent with its own read/edit/execute tools forwards only Hermes' agent-level tools, since re-offering overlapping ones makes Hermes redo finished work"* |
| Hilfsaufrufe auf `provider: auto` laufen über den Hauptprovider | `~/.hermes/profiles/claude-dev/config.yaml`, Block `auxiliary:`; Auflösung in `agent/auxiliary_client.py:4890` |
| Kanban-Worker laufen im Gateway-Prozess | `config.yaml`, `kanban.dispatch_in_gateway: true` |
| Provider-Erkennung findet **einmal** statt und wird gemerkt | `providers/__init__.py`, Modulvariable `_discovered` |

### Der Fund: ein Profil ist sein eigenes `HERMES_HOME`

Der teuerste Befund dieser Umsetzung, und er widerspricht der FAQ.

`00-hermes-FAQ/Hermes-Claude-Code-Integration.md` nennt als Ablageort

```
~/.hermes/plugins/model-providers/claude-code-mcp/
```

Das stimmt **nur für das Standardprofil**. `hermes -p <profil>` setzt `HERMES_HOME`
auf `~/.hermes/profiles/<profil>` (`hermes_cli/main.py:435`, `hermes_constants.py:102`),
und `providers._user_plugins_dir()` sucht unter `$HERMES_HOME/plugins/model-providers/`.
Ein nur ins Root-Home gelegtes Provider-Plugin ist für jedes benannte Profil unsichtbar:

```
$ HERMES_HOME=~/.hermes/profiles/claude-dev python -c "import providers; print(providers._user_plugins_dir())"
None
$ hermes -p claude-dev -z "…"
hermes -z: agent failed: Unknown provider 'claude-code-mcp'. …
```

Deshalb rollt `install.sh` in **beide** Homes aus und prüft beide einzeln nach.

---

## B — Nur durch protokollierte Läufe belegt (Claude Code CLI 2.1.270)

Alle Läufe stehen mit Rohdaten in [RUN-PROTOKOLL.md](RUN-PROTOKOLL.md).

| Aussage | Lauf |
|---|---|
| Ein MCP-Werkzeugaufruf darf 90 s blockieren; das Ergebnis kommt an und die Sitzung läuft im selben Prozess weiter | 1 |
| Das Zeitlimit ist pro Server über `timeout` (ms) im `--mcp-config` einstellbar | 1 (CLI-Schema: *„Hard wall-clock limit per call; progress notifications do not extend it"*) |
| `--tools ""` entfernt Claude Codes eingebaute Werkzeuge vollständig | 1, 3, 4 — `system/init` listet nur `mcp__hermes__*` |
| `tools/call` trägt `_meta["claudecode/toolUseId"]`, identisch mit `tool_use.id` im Strom | 1 |
| `--permission-prompts none` + `--allowedTools` genügt; keine Nachfrage in `-p` | 1, 3, 4 |
| Resident hält den Prompt-Cache innerhalb eines Zuges warm (1259/1294 gelesene Cache-Token), stateless nicht (0) | 3 |
| Hermes' echter Werkzeugsatz (25 Werkzeuge) geht durch, Hermes führt aus | 4 |
| `--setting-sources ""` hält die globalen Hooks des Nutzers draußen (20 Hook-Ereignisse → 0) | 5 |
| `--system-prompt-file` und `--append-system-prompt-file` existieren (in `--help` nicht gelistet) | geprüft mit nicht existentem Pfad: `Error: System prompt file not found` statt `unknown option` |
| Ein Kanban-Worker läuft Ende zu Ende über die CLI | 6 |
| `--effort` nimmt `low, medium, high, xhigh, max`; Unbekanntes wird verworfen statt zu scheitern | 7 (CLI: *„Unknown --effort value … Valid values: low, medium, high, xhigh, max"*) |
| Modell und Denktiefe aus Hermes schlagen auf die CLI durch | 7 — `--model opus --effort xhigh` → `claude-opus-5`; `--model fable --effort max` → `claude-fable-5-1` |
| Modell und Denktiefe wechseln **zur Laufzeit**, je Zug, ohne Neustart | 8 — drei Züge auf einer Client-Instanz mit `haiku`/`fable`/`haiku` |
| Alle vier Umschaltwege kommen beim Provider an: `model.default`, `-m`, `/model` im TUI, `kanban set-model` | 9 — je ein echter Lauf auf einem Wegwerf-Profil |
| Slash-Befehle gibt es **nur** interaktiv — `/model` als `-z`-Prompt geht als Text ans Modell | 9 |
| Eine Karten-Übersteuerung braucht **keinen** Gateway-Neustart | 9 — Worker werden je Karte frisch gestartet |
| `model.context_length` hebt Hermes' Schätzung auf — aber nur bei Übereinstimmung mit `model.default`, groß-/kleinschreibungsgenau | 10 — vier Szenarien, 1.000.000 gegen 256.000 |
| Das `[1m]`-Suffix erreicht die CLI und setzt die Sitzung auf `claude-opus-5[1m]` | 10 — `system/init`; das `assistant`-Ereignis führt die nackte Wire-ID |
| Ein größeres `model.context_length` verschiebt die Kompression nachweislich nach hinten | 11 — A/B mit identischem Gespräch: 64k-Fenster komprimiert (66.685 → 20.217), 200k-Fenster nicht (61.182 bleibt) |
| Die Schwelle ist `context_length × compression.threshold` | `agent/context_engine.py:242` |
| Hermes erzwingt ein Mindestfenster von 64.000 | 11 — `model.context_length: 30000` wird abgelehnt |
| Die Desktop-App schreibt Modellnamen nur für die **Anzeige** groß | Bundle `apps/desktop/dist/assets/*.js`: `charAt(0).toUpperCase()+e.slice(1)`; die `config.yaml` bleibt kleingeschrieben |
| `--continue` setzt die Sitzung **nicht** fort, sondern legt eine neue an | 11 — der erste Messversuch blieb deshalb ohne Kompression; `--resume <session-id>` funktioniert |
| `[1m]` **aktiviert** das 1M-Fenster (Beta-Header), es beschreibt es nicht nur | 12 — im CLI-Binary: `supports_1m_beta`, `ANTHROPIC_BETAS`, `context-1m-2025-08-07`, dazu die CLI-Meldungen *„or /model sonnet[1m] for a 1M context window"* und *„has no 1M form"* |
| Sonnet 5 kann 1M — mit Suffix | 12 — `--model sonnet[1m]` → Sitzungsmodell `claude-sonnet-5[1m]` |
| `model.context_length` gilt nur für das Modell, mit dem der Agent **startet** | `agent/agent_runtime_helpers.py:1963-1964` — der Live-Wechsel löscht den Wert ausdrücklich („Clear the per-config override…"), und `:2017` setzt danach nur den `custom_providers`-Override neu |
| Ein Plugin-Provider mit `auth_type="external_process"` erreicht die Modellauswahl **nie** — `fallback_models` ist dort totes Gewicht | `hermes_cli/models_catalog_static.py:361-363` (Auto-Erweiterung überspringt ihn), `hermes_cli/models.py:1390` (Katalogabruf nur für `api_key`); gemessen in 13: `provider_model_ids("claude-code-mcp") == []`, keine Zeile unter allen vier Flag-Kombinationen |
| Der einzelne Eintrag `claude-code-mcp` im Auswahlfeld ist die **aktuelle Auswahl**, nicht ein Modell | `apps/desktop/src/lib/chat-runtime.ts:384` setzt den Slug als Namen ein; `components/model-picker.tsx:278` verwirft Gruppen ohne Modelle |
| Ein `providers:`-Block im Profil füllt die Auswahl und überschattet die Plugin-Registrierung **nicht** | 13 — vier Modelle in der Zeile, mit `refresh=False` und `True`; `get_provider("claude-code-mcp")` bleibt `source=plugin-profile`, `auth_type=external_process` |
| Ein Kontextfenster aus diesem Block überlebt den Laufzeitwechsel — und wirkt schon beim Kaltstart | 13 — ohne Block fielen `haiku`/`fable` auf 256.000, mit Block 111.000/222.000; beim Kaltstart belegt durch die Zeichengrenze 26.640 = 111.000 × 0,24 (`agent/prompt_builder.py:1036-1041`) |
| Die Meldung „Could not determine context length … falling back to 256,000" ist **kein** Beweis für das wirksame Fenster | 13 — sie erschien, während das Fenster nachweislich 111.000 war. Nachgestellt: derselbe Aufruf ohne `custom_providers` erzeugt genau diese Zeile und liefert 256.000, mit Liste den Wert aus dem Block; solche Aufrufer existieren (`agent/auxiliary_client.py:3975`), welcher beim Start protokollierte, ist **nicht** bestimmt. `agent/agent_init.py:1822` und `agent/context_compressor.py:1782` reichen die Liste durch |

---

## Was ich **nicht** verifiziert habe

| Punkt | Stand |
|---|---|
| **Echt paralleles Ausspielen mehrerer Werkzeuge in einem Zug** | Die Nebenläufigkeit des Rendezvous ist offline belegt (Lauf 2), die mehrrundige residente Fortsetzung live (Lauf 3, 4). Die **Kombination** — zwei `tool_use`-Blöcke in *einer* Modellantwort gegen die echte CLI — ist ungeprüft; das Modell hat in allen Läufen sequenziell gerufen. |
| **Usage auf Werkzeug-Runden ist null** | Gemessen, nicht behoben: `usage` kommt erst mit dem `result`-Ereignis, also meldet der Client bei `finish_reason=tool_calls` `prompt_tokens=0, cached=0`. Hermes' Kompressionsschwelle (`compression.threshold: 0.5`) liest auf diesen Runden Nullen. Wirkung auf langlaufende Karten ungemessen. |
| **Reichweite der Sitzungstabelle** | `_SESSIONS` liegt auf Modulebene und überlebt damit *Client-Neubauten innerhalb eines Agentenprozesses* — das ist der Fall, den `agent_runtime_helpers.py:1700-1760` beschreibt. Über Prozessgrenzen hinweg (jedes `hermes -p …` ist ein eigener Prozess) trägt sie nichts. Der Neubau-Fall ist **nicht** gezielt provoziert worden. |
| **Sitzungsfortsetzung über Hermes-Züge** | `--resume` ist **nicht** umgesetzt. Jeder neue Hermes-Zug baut die CLI-Sitzung aus dem vollen Transkript neu auf. Der Cache-Gewinn liegt heute nur innerhalb eines Zuges. |
| **Der Abbruchpfad, wenn der Hermes-Prozess stirbt** | Der Wachhund ist ein Daemon-Thread und stirbt mit. Was den geparkten Aufruf dann löst, ist das EOF auf dem Rendezvous-Socket bzw. die eigene Frist des MCP-Servers (`HERMES_CC_CALL_DEADLINE`, Wachhundfrist + 30 s). Claude Code bekommt daraufhin `isError` und **denkt weiter** — es kann noch eine ganze Antwort erzeugen, nachdem Hermes weg ist, und ohne `--max-budget-usd` bremst das nichts. Der Pfad ist gebaut, aber **nicht ausgelöst worden**. |
| **`delegate_task` ist unter den 25 durchgereichten Werkzeugen** | Mit `delegation.max_concurrent_children: 10` und ohne Budgetgrenze kann eine einzige Karte auf zehn gleichzeitige residente `claude`-Prozesse auffächern. Ungetestet — und der Betriebsfall, in dem „ohne Budgetgrenze" aufhört, eine kleine Entscheidung zu sein. |
| **Zwei Hermes-Prozesse auf einem Profil** | Beim Bau real eingetreten: Desktop-App und `hermes -p claude-dev -z …` schrieben gleichzeitig auf `profiles/claude-dev/state.db`. Ergebnis waren zurückgezogene WAL-Generationen und abgebrochene Züge (leere Assistentenantworten). **Kein Fehler dieses Plugins** — der Provider verhält sich in beiden Prozessen korrekt —, aber ein Betriebsfallstrick, der ohne die Testerei nicht aufgefallen wäre. |
| **Verhalten des Wachhunds im Ernstfall** | Die Frist (`HERMES_CLAUDE_CODE_ORPHAN_TIMEOUT`, 300 s) und die gestaffelten Zeitlimits sind gesetzt, aber nie ausgelöst worden. |
| **Große Werkzeugmengen** | 25 Werkzeuge sind belegt. Ob Hermes' `tool_search` (ab `threshold_pct: 10`) den Satz mitten im Zug ändert und wie oft das die Sitzung verwirft, ist ungemessen. |
| **Hermes' System-Prompt ersetzt Claude Codes eigenen** | `--system-prompt-file` ist die Vorgabe. Ob Claude-Code-Verhalten am eigenen System-Prompt hängt, ist ungeprüft; `HERMES_CLAUDE_CODE_SYSTEM_PROMPT_MODE=append` bleibt als Schalter. |
| **Kosten im Dauerbetrieb** | Einzelläufe 0,02–0,06 USD. Ohne `--max-budget-usd` gibt es **keine** Obergrenze je Aufruf; die Kostenbremse muss woanders sitzen. |
| **Der Klick im Desktop-Auswähler** | Die Auswahlzeile ist als Nutzlast gemessen (Lauf 13), der Wechsel als `/model` im TUI. Der Weg über die Oberfläche selbst — sie schickt `provider.slug` plus Modell (`use-model-controls.ts:188`) in dasselbe `switch_model` — ist **nicht** geklickt worden. |
| **Das echte Fenster von `haiku`/`fable` in der CLI** | Ungeprüft. `install.sh --with-model-picker` trägt für sie deshalb **kein** `context_length` ein (leerer Eintrag `{}`, gemessen: Auswahlzeile vorhanden, Übersteuerung `None`) — ein erfundener Wert unter Hermes' Schätzung von 256.000 würde ihr Fenster still verkleinern. |
| **Andere Profile** | Nur `claude-dev` ist umgestellt und geprüft. |
| **Nutzungsbedingungen** | Es startet der offizielle Client — die stärkere Position als „Credentials leihen", **aber keine Freigabe**: ob der offizielle Client, gesteuert von einem fremden Harness, gedeckt ist, hat Anthropic nicht entschieden. Die Einschätzung bleibt beim Betreiber. (Satz aus der FAQ übernommen.) |

---

## Eingriffe in die Maschine

Was diese Umsetzung angefasst hat — und wie es zurückgeht:

| Eingriff | Stand / Rückbau |
|---|---|
| `~/.hermes/plugins/model-providers/claude-code-mcp/` angelegt | **liegt** — `./uninstall.sh` |
| `~/.hermes/profiles/claude-dev/plugins/model-providers/claude-code-mcp/` angelegt | **liegt** — `./uninstall.sh` |
| `claude-dev/config.yaml`: Provider, Modell, drei `auxiliary`-Blöcke | **umgestellt** — `./switch-profile.sh claude-dev --restore` |
| `claude-dev/config.yaml`: `model.default: sonnet[1m]`, `model.context_length: 1000000` | **gesetzt** (14.09.2026; zwischenzeitlich `opus[1m]`) — Sicherungen `config.yaml.pre-claude-code-20260914-*.bak` |
| `claude-dev/config.yaml`: `providers.claude-code-mcp` mit vier Modellen | **gesetzt** (14.09.2026, `./install.sh --with-model-picker claude-dev`) — Sicherung `config.yaml.bak-20260914-113833`; Rückbau `./uninstall.sh` oder `hermes -p claude-dev config unset providers.claude-code-mcp` |
| Gateway zweimal neu gestartet | erledigt; `developer` und `summarizer` liefen beide Male durch |
| Wegwerf-Boards `cc-probe`, `cc-model-probe` | gelöscht |
| Wegwerf-Profile `cc-probe-dev`, `cc-ctx-probe`, `cc-win-probe`, `cc-pick-probe` | gelöscht |

⚠ `./switch-profile.sh claude-dev --restore` spielt den Stand **vor** der Umstellung
zurück — also auch das damalige Modell ohne `[1m]`, ohne `context_length` und ohne den
`providers:`-Block.

**Nicht angefasst:** die Story-Skripte unter `02-…`, fremde Profile, `~/.claude/`.
