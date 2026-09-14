# Run-Protokoll

Läufe 1–12 vom **13.09.2026**, Lauf 13 vom **14.09.2026**; macOS, Hermes Agent v0.20.0 (2026.8.3),
Claude Code CLI **2.1.270**. Modell `sonnet`, außer wo anders vermerkt (Lauf 7).
Rohdaten (gesäubert) unter
[`probes/`](probes/).

---

## Lauf 1 — Hält ein MCP-Werkzeugaufruf 90 Sekunden?

Die Frage, an der die ganze Bauform hängt. Ein Wegwerf-MCP-Server mit einem
einzigen Werkzeug, das 90 s schläft, dazu `timeout: 600000` im `--mcp-config`.

```
1789293600.141 CALL START sleep=90.0
1789293690.143 CALL RETURN after 90.0s
```

Ergebnis (`probes/blocking-mcp-90s.log`):

```
system/init tools=['mcp__hermes__hermes_probe'] mcp=[{'name': 'hermes', 'status': 'connected'}]
assistant/tool_use toolu_01QxnNELyU7TbBsTkB7uSMPr mcp__hermes__hermes_probe
user/tool_result toolu_01QxnNELyU7TbBsTkB7uSMPr -> [{'type': 'text', 'text': 'BLOCKED_OK after 90.0s'}]
result/success turns=2 dur_ms=95511 usage={"input_tokens": 4, "cache_creation_input_tokens": 12676, "cache_read_input_tokens": 12484, "output_tokens": 310, ...}
```

**Belegt:** Die Blockade hält, das Ergebnis kommt beim Modell an, und die Sitzung
läuft im selben Prozess weiter (`num_turns=2`). Damit ist Break-early unnötig —
und der Sitzungsneubau, den `pi-claude-bridge` mit ~58 % Cache-Verlust beziffert,
entfällt.

**Nebenbefund:** `tool_use.id` und der `_meta`-Eintrag `claudecode/toolUseId` im
`tools/call` sind identisch. Der Rendezvous-Schlüssel kommt frei Haus.

Kosten: 0,057 USD.

---

## Lauf 2 — Rendezvous und paralleles Parken (ohne Modell)

Kein Modellaufruf: der MCP-Server wird direkt mit JSON-RPC gefüttert.

| Prüfung | Ergebnis |
|---|---|
| `tools/list` liefert den Schnappschuss | `['terminal']` |
| Zwei Aufrufe **gleichzeitig** geparkt | `['toolu_A', 'toolu_B']` nach 0,00 s |
| 2 s blockiert, getrennt beantwortet | `{3: 'Ergebnis A', 4: 'Ergebnis B'}` nach 2,0 s |
| Rendezvous geschlossen → lesbarer Fehler statt Hänger | `isError=True`, „Hermes hat die Sitzung beendet…" |

**Dieser Lauf fand einen echten Fehler:** Die erste Fassung des MCP-Servers
verarbeitete stdin in *einer* Schleife. Der erste blockierende `tools/call` hielt
damit die Leseschleife an, und ein zweiter, paralleler Aufruf erreichte den Host
nie. Behoben durch einen Thread je `tools/call` plus Sperre um stdout.

---

## Lauf 3 — Resident gegen Stateless, direkt am Client

Der Client wird über das registrierte Provider-Profil gebaut, Hermes' Werkzeugschleife
ist nachgespielt (zwei erfundene Werkzeuge, festverdrahtete Ergebnisse).

| Betriebsart | Runden | `prompt_tokens` | davon `cached` | Ergebnis |
|---|---|---|---|---|
| `resident` | 2 | 2643 | **1259** | Abschlusstext nach einem Werkzeug-Umlauf |
| `resident` (drei Werkzeuge) | 3 | 2865 | **1294** | beide Werkzeuge, dann Zusammenfassung |
| `stateless` | 2 | 1323 | **0** | derselbe Abschlusstext |

**Belegt:** Der residente Weg hält den Prompt-Cache **innerhalb eines Zuges** warm
(1259 bzw. 1294 gelesene Cache-Token); der stateless Weg baut je `create()` neu auf
und liest null Cache-Token. Das ist der gemessene Unterschied zwischen den beiden
Bauformen, nicht eine Schätzung.

**Belegt (Werkzeugkollision):** `probes/par.log`

```
[client] init tools=['mcp__hermes__kanban_show', 'mcp__hermes__terminal'] mcp=[{'name': 'hermes', 'status': 'connected'}]
```

Claude Code sieht **ausschließlich** die Hermes-Werkzeuge. Kein `Read`, kein `Edit`,
kein `Bash`, kein `Task`. Das ist die Wirkung von `--tools ""`.

**Nicht belegt:** Echt *paralleles* Ausspielen mehrerer `tool_use`-Blöcke in einem Zug.
Das Modell hat in diesem Lauf sequenziell gerufen (drei Runden, je ein Aufruf).
Die Nebenläufigkeit des Rendezvous ist in Lauf 2 belegt, die mehrrundige Fortsetzung
derselben residenten Sitzung hier — die Kombination aus beidem nicht.

---

## Lauf 4 — Der echte Hermes-Agent

`hermes -p claude-dev -z "…"` nach der Profilumstellung.

Erster Versuch: **`Unknown provider 'claude-code-mcp'`.** Ursache und Behebung stehen
in [VERIFIKATION.md](VERIFIKATION.md#der-fund-ein-profil-ist-sein-eigenes-hermes_home).

Nach der Behebung, `probes/tool.log`:

```
[client] init tools=['mcp__hermes__browser_exec', …, 'mcp__hermes__write_file']   (25 Werkzeuge)
[mcp] Start, 25 Werkzeuge angemeldet
[mcp] call toolu_019xoCxPXztnrXvdpFGahqME read_file
[mcp] done toolu_019xoCxPXztnrXvdpFGahqME is_error=False
[mcp] call toolu_018Lm6RwsxmeXk8fAaax3AAp search_files
[mcp] done toolu_018Lm6RwsxmeXk8fAaax3AAp is_error=False
[mcp] call toolu_01GRmFJtpDLvbJ6DN67RkwRL read_file
[mcp] done toolu_01GRmFJtpDLvbJ6DN67RkwRL is_error=False
```

Aufgabe war, eine Datei mit einem Geheimwort zu lesen. Antwort des Agenten:

```
Das Geheimwort lautet: **Nussschale-4711**
```

**Belegt:** Hermes' **echter** Werkzeugsatz (25 Werkzeuge) erreicht Claude Code über
MCP; Claude Code schlägt vor, **Hermes** führt aus (es sind Hermes' `read_file` und
`search_files`, nicht Claude Codes eigene — die existieren in dieser Sitzung nicht);
drei Umläufe laufen in **einem** CLI-Prozess.

---

## Lauf 5 — Fremde Einstellungen im Kind

Derselbe triviale Prompt, einmal ohne und einmal mit `--setting-sources ""`:

| Aufruf | Hook-Ereignisse im Strom |
|---|---|
| ohne das Flag (Lauf 1) | `hook_started` ×10, `hook_response` ×10 |
| mit `--setting-sources ""` | **0** — nur `system/init`, `rate_limit_event`, `assistant`, `result/success` |

**Belegt:** Die globalen Hooks des Nutzers laufen sonst im Kind mit; das Flag stellt
sie ab. (In Lauf 1 waren es die Hooks aus `~/.claude/`, unter anderem der
RTK-Hook.)

---

## Lauf 6 — Eine Kanban-Karte Ende zu Ende

Voraussetzung: **Gateway-Neustart.** Der laufende Gateway (PID 54702, gestartet
11:10) hatte seinen Provider-Zwischenspeicher gefüllt, bevor das Plugin existierte —
`providers/__init__.py` merkt sich `_discovered` und sucht kein zweites Mal. Ohne
Neustart scheitert der Kanban-Dispatch mit demselben „Unknown provider". Nach
`hermes gateway restart` (neue PID 12346) liefen `developer` und `summarizer`
unverändert weiter.

```
$ hermes kanban --board cc-probe assignees
NAME                  ON DISK   COUNTS
claude-dev            yes       (idle)

$ hermes kanban --board cc-probe create "Lies material.txt … schreibe ergebnis.txt …" \
      --assignee claude-dev --workspace dir:…/ws
Created t_15ab7626  (ready, assignee=claude-dev)
```

Nach rund fünf Minuten:

```
id          : t_15ab7626
status      : done
assignee    : claude-dev

$ cat ws/ergebnis.txt
Schraube M4
```

**Belegt:** Ein unbeaufsichtigter Kanban-Worker auf dem Profil `claude-dev` läuft
vollständig über die Claude-Code-CLI: Karte gezogen, Datei über Hermes' Werkzeuge
gelesen, Ergebnisdatei geschrieben, Karte auf `done`. Board danach gelöscht.

---

## Lauf 7 — Modell und Denktiefe sind konfigurierbar

Vorher war das Modell **fest verdrahtet**: der Client las `HERMES_CLAUDE_CODE_MODEL`
und ignorierte das `model`-Argument, das Hermes übergibt. `model.default`, `/model` und
`hermes kanban set-model` hatten damit keine Wirkung. `--effort` wurde gar nicht gesetzt.

`--effort` mit ungültigem Wert zeigt die erlaubten Stufen:

```
Warning: Unknown --effort value 'quatsch' — ignoring it and using the default effort.
Valid values: low, medium, high, xhigh, max.
```

Nach dem Umbau, je ein echter Lauf mit der Frage nach dem eigenen Modellnamen:

| Hermes übergibt | argv | Modell laut CLI | Antwort |
|---|---|---|---|
| `model=opus`, `reasoning_effort=xhigh` | `--model opus --effort xhigh` | `claude-opus-5` | „Ich bin Opus 5 (genaue Modell-ID: claude-opus-5)." |
| `model=fable`, `reasoning_effort=max` | `--model fable --effort max` | `claude-fable-5-1` | „…Fable 5.1 … mit der genauen Modell-ID `claude-fable-5-1`." |

Der Weg für die Denktiefe ist der dokumentierte Provider-Haken
`build_api_kwargs_extras` (`providers/base.py`) — nötig, weil dieser Client die
Transport-Schicht überspringt (`HERMES_SKIP_TRANSPORT_WRAP`). Geprüft:

```
reasoning_config={'enabled': True, 'effort': 'xhigh'}  -> {'reasoning_effort': 'xhigh'}
reasoning_config={'enabled': True, 'effort': 'ultra'}  -> {'reasoning_effort': 'max'}
reasoning_config={'enabled': False}                    -> {'reasoning_effort': 'low'}
reasoning_config=None                                  -> {}
```

Fällt Hermes aus, greift `agent.reasoning_effort` aus der `config.yaml` des Profils —
im Test `medium`, was zu `--effort medium` führt.

## Lauf 8 — Wechselt das Modell zur Laufzeit?

Rückfrage aus dem Betrieb, und die README-Formulierung („greift beim Prozessstart")
war zu pauschal. Drei aufeinanderfolgende `create()`-Aufrufe auf **einer**
Client-Instanz, je ein anderes Paar aus Modell und Denktiefe:

| angefordert | argv | Modell laut CLI | Selbstauskunft |
|---|---|---|---|
| `haiku` + `low` | `--model haiku --effort low` | `claude-haiku-4-5-20251001` | „Meine exakte Modell-ID ist **claude-haiku-4-5-20251001**." |
| `fable` + `max` | `--model fable --effort max` | `claude-fable-5-1` | „…claude-fable-5-1 (Fable 5.1)." |
| `haiku` + `medium` | `--model haiku --effort medium` | `claude-haiku-4-5-20251001` | „Meine Modell-ID ist claude-haiku-4-5-20251001…" |

**Belegt:** Der Wechsel wirkt ab dem nächsten Zug, ohne Neustart. Jeder Zug startet
einen eigenen `claude`-Prozess mit frisch gebauter Argumentliste.

**Dieser Lauf fand einen Fehler:** Der Rückfallpfad für `agent.reasoning_effort`
(gelesen aus der `config.yaml`, wenn Hermes den Wert nicht als kwarg durchreicht) hat
seinen Wert **unbegrenzt** zwischengespeichert. In einem tagelang laufenden Gateway
hätte ein `config set agent.reasoning_effort` damit nie gegriffen. Behoben: der
Zwischenspeicher hängt jetzt an der mtime der Datei. Nachgeprüft mit einem
Wegwerf-`HERMES_HOME`:

```
1. config=medium        -> medium
2. config=xhigh (neu)   -> xhigh   <- ohne Neustart
3. Hermes uebergibt max -> max     <- Hermes gewinnt
```

## Lauf 9 — `/model`, `-m` und `set-model` im echten Hermes

Lauf 8 zeigte nur, dass der *Client* ein geändertes `model`-Argument umsetzt. Offen war,
ob Hermes' drei Umschaltwege dort auch ankommen. Alles auf einem **Wegwerf-Profil**
`cc-probe-dev` — die Desktop-App hielt weiterhin einen `claude-dev`-Serve-Prozess, und
zwei Schreiber auf einem Profil sind genau die Falle aus Lauf 4.

Profilvorgabe durchgehend `model.default: haiku`.

| Weg | Befehl | Modell laut CLI |
|---|---|---|
| Profil | `config set model.default haiku` | `claude-haiku-4-5-20251001` |
| Je Aufruf | `hermes -p cc-probe-dev -m fable -z …` | `claude-fable-5-1` |
| **`/model` im TUI** | `/model fable` zwischen zwei Zügen | Zug 1 `claude-haiku-4-5-20251001`, Zug 2 **`claude-fable-5-1`** |
| Je Karte | `hermes kanban set-model <id> fable` | Worker schrieb `claude-fable-5-1` |

Das TUI musste über ein Pseudo-Terminal getrieben werden (`pty.fork`, zeichenweise
getippt): Slash-Befehle gibt es **nur** interaktiv — als `-z`-Prompt übergeben, geht
`/model fable` als Text ans Modell, das dann erklärt, wie man es richtig macht. Der
Beleg steht im Client-Protokoll, weil der TUI-Mitschnitt durch die Neuzeichnung
zerfasert:

```
argv: --model haiku
[client] Modell laut CLI: claude-haiku-4-5-20251001
argv: --model fable
[client] Modell laut CLI: claude-fable-5-1
```

Die Karten-Übersteuerung lief **ohne** Gateway-Neustart durch (Karte `done`,
`model_override: fable`, Ergebnisdatei `claude-fable-5-1`): Worker werden je Karte
frisch gestartet und machen ihre Provider-Erkennung selbst. Der Neustart aus Lauf 6 war
nötig, weil das Plugin damals **neu** war — nicht für jede spätere Umschaltung.

Danach zurückgebaut: Board gelöscht, Plugin entfernt, Profil `cc-probe-dev` gelöscht.

## Lauf 10 — Das 1M-Kontextfenster, beide Seiten

Aus dem Betrieb: `/model Opus[1m]` meldete „Context: 256,000 tokens". Gemessen auf dem
Wegwerf-Profil `cc-ctx-probe` gegen Hermes' echte Auflösungsfunktionen
(`_scope_context_length_to_default_runtime` + `resolve_display_context_length`), offline
und ohne Modellaufruf:

| Szenario | `model.default` | `context_length` | aktives Modell | angezeigt |
|---|---|---|---|---|
| A — Soll | `opus[1m]` | `1000000` | `opus[1m]` | **1.000.000** |
| B — ohne Schlüssel | `opus[1m]` | *(nicht gesetzt)* | `opus[1m]` | 256.000 |
| C — Sitzungswechsel | `sonnet` | `1000000` | `opus[1m]` | 256.000 |
| D — Schreibweise | `opus[1m]` | `1000000` | `Opus[1m]` | 256.000 |

**Belegt:** `model.context_length` wirkt nur, wenn das aktive Modell dem konfigurierten
`model.default` entspricht (C) — und der Vergleich ist **groß-/kleinschreibungsempfindlich**
(D). In beiden Fällen liefert die Abschirmung `scoped=None`, und Hermes fällt auf seine
Schätzung zurück. Die Meldung dazu nennt die Abhilfe selbst:

```
Could not determine context length for model 'opus[1m]' (base_url=claude-code://cli)
— falling back to 256,000 tokens. Set model.context_length in config.yaml to override.
```

Auf der CLI-Seite reicht das Suffix allein. Echter Lauf über Hermes:

```
[client] spawn … --model 'opus[1m]' --tools '' …
[client] Sitzungsmodell: 'claude-opus-5[1m]'
[client] Wire-Modell: claude-opus-5
```

**Dieser Lauf fand einen Fehler — in der Protokollierung, nicht im Plugin.** Der Client
hatte das `model` aus dem `assistant`-Ereignis mitgeschrieben. Das ist die nackte
Wire-ID (`claude-opus-5`); das Suffix steht im `system/init` (`claude-opus-5[1m]`). Der
erste Messlauf sah deshalb so aus, als ginge das `[1m]` unterwegs verloren — es war
die ganze Zeit aktiv. Beide Felder werden jetzt getrennt protokolliert.

Danach zurückgebaut: Plugin entfernt, Profil gelöscht, Root-Kopie wiederhergestellt.

## Lauf 11 — Komprimiert Hermes bei größerem Fenster wirklich später?

Der offene Punkt aus Lauf 10. Ein echter 1M-Lauf wäre sehr teuer, also derselbe
Mechanismus mit kleinen Zahlen und `haiku`: die Schwelle ist
`threshold_tokens = context_length × compression.threshold`
(`agent/context_engine.py:242`), also skaliert sie linear.

Aufbau: Wegwerf-Profil `cc-win-probe`, `compression.threshold: 0.5`, eine Datei mit
125.904 Zeichen einlesen lassen, dann zweimal fortsetzen. **Identisches Gespräch**, nur
`model.context_length` unterschiedlich.

| | Fenster | Schwelle | Zug 1 | Zug 2 | Zug 3 |
|---|---|---|---|---|---|
| **A** | 64.000 | 32.000 | 66.685 | **20.217** | 20.234 |
| **B** | 200.000 | 100.000 | 47.180 | **61.182** | 61.199 |

**Belegt:** In A überschreitet Zug 1 mit 66.685 die Schwelle von 32.000 — Zug 2 startet
danach bei nur noch 20.217 Token, die Historie ist zusammengefasst worden. In B bleibt
dasselbe Gespräch mit 61.182 unter der Schwelle von 100.000 und wächst unkomprimiert
weiter. `model.context_length` steuert also tatsächlich, *wann* komprimiert wird.

Hochgerechnet auf die Ausgangsfrage: 256.000 → Kompression ab ~128.000;
1.000.000 → ab ~500.000.

**Der Preis steht mit in der Tabelle.** B kostete je Fortsetzung rund 0,14 USD gegen
0,02 USD in A — ein größeres Fenster heißt später komprimieren, also mehr Token je Zug.
Das 1M-Fenster ist keine Gratis-Verbesserung.

Zwei Nebenbefunde:

- **Hermes erzwingt mindestens 64.000.** `model.context_length: 30000` wird abgelehnt:
  *„…is below the minimum 64,000 required by Hermes Agent."*
- **`--continue` setzte die Sitzung nicht fort**, sondern legte eine neue an; der erste
  Messversuch blieb deshalb ohne Kompression. Mit `--resume <session-id>` lief es.

Der Client protokolliert die Token je Zug jetzt mit
(`[client] Zugende: prompt=… (cached …) completion=… cost=…`) — ohne das wäre dieser
Lauf nicht auswertbar gewesen.

## Lauf 12 — Was `[1m]` wirklich tut

Aus dem Betrieb: `claude-dev` sollte auf Sonnet, und es war unklar, ob das Suffix nötig
ist. Hermes' Tabelle (`agent/model_metadata.py`) führt `claude-sonnet-5` mit 1.000.000 —
das las sich, als käme das Fenster ohne Zutun. Die CLI unterscheidet aber `sonnet` von
`sonnet[1m]`, was dagegen sprach.

Im CLI-Binary (v2.1.270) nachgesehen:

```
supports_1m_beta        ANTHROPIC_BETAS        context-1m-2025-08-07
"…, or /model sonnet[1m] for a 1M context window"
"' isn't available: the setting switches models in plan mode and has no 1M form."
```

**Belegt:** Das Suffix schaltet einen **Beta-Header** ein (`context-1m-2025-08-07`), der
je Modell an einer Fähigkeit (`supports_1m_beta`) hängt. Ohne Suffix kein Header, also
kein 1M-Fenster — unabhängig davon, was in Hermes' Konfiguration steht.

Damit löst sich der Widerspruch: die Tabelle beschreibt die **Fähigkeit** des Modells,
das Suffix ist die **Aktivierung**. Für ein Profil zählt die Aktivierung.

Gegenprobe am laufenden System:

| `--model` | Sitzungsmodell laut `system/init` |
|---|---|
| `sonnet` | `claude-sonnet-5` |
| `sonnet[1m]` | `claude-sonnet-5[1m]` |
| `opus[1m]` | `claude-opus-5[1m]` |

`claude-dev` steht seither auf `sonnet[1m]` mit `model.context_length: 1000000`;
Hermes löst 1.000.000 auf, Kompression ab 500.000.

**Konsequenz für die Zwischenstation:** Eine kurzzeitig gesetzte Kombination aus plain
`sonnet` und `context_length: 1000000` wäre falsch gewesen — Hermes hätte erst bei
500.000 komprimiert, während die CLI-Sitzung weit früher dicht ist. Deshalb gehören die
beiden Werte immer zusammen gesetzt.

## Lauf 13 — Modellauswahl im Desktop und das Fenster beim Wechsel

Aus dem Betrieb: Im Modell-Auswahlfeld stand nur ein Eintrag, `claude-code-mcp`. Die
Frage war, ob das Plugin mehrere Varianten (Haiku, Sonnet, Opus, Fable) anbieten kann.

**Warum die Auswahl leer ist.** Ein Plugin-Provider mit `auth_type="external_process"`
wird von der Auto-Erweiterung der kanonischen Liste ausdrücklich übersprungen
(`hermes_cli/models_catalog_static.py:361-363`), und der generische Katalogabruf bedient
nur `auth_type == "api_key"` (`hermes_cli/models.py:1390`). Damit ist `fallback_models`
im Profil totes Gewicht — gemessen `provider_model_ids("claude-code-mcp") == []`. Keiner
der fünf Läufe in `list_authenticated_providers`
(`hermes_cli/model_switch_providers.py:1078`) erzeugt eine Zeile, unter **keiner** der
vier Flag-Kombinationen. Der Desktop verwirft Gruppen ohne Modelle
(`components/model-picker.tsx:278`); übrig bleibt der synthetische Eintrag aus
`lib/chat-runtime.ts:384`, der den **Slug** als Namen einsetzt.

`copilot-acp` ist die Ausnahme und nur deshalb sichtbar, weil er an drei Stellen von
Hand eingetragen ist: `CANONICAL_PROVIDERS` (`:329`), `HERMES_OVERLAYS`
(`hermes_cli/providers.py:43`) und `_PROVIDER_MODELS` (`:167`, mit dem eigenen Slug als
einzigem „Modell").

**Was stattdessen wirkt:** ein `providers:`-Block im Profil. Wegwerf-Profil
`cc-pick-probe`, `model.default: haiku`, **kein** `model.context_length`, absichtlich
ungewöhnliche Fenster, damit jede Zahl eindeutig zuzuordnen ist:

```yaml
providers:
  claude-code-mcp:
    name: Claude Code CLI (MCP)
    base_url: claude-code://cli
    api_mode: chat_completions
    models:
      "haiku":      {context_length: 111000}
      "fable":      {context_length: 222000}
      "sonnet[1m]": {context_length: 1000000}
      "opus[1m]":   {context_length: 1000000}
```

| | Auswahlzeile im Desktop | aufgelöstes Fenster (haiku / fable) |
|---|---|---|
| **A** ohne Block | *fehlt ganz* | 256.000 / 256.000 (Rückfall) |
| **B** mit Block | `Claude Code CLI (MCP)` mit 4 Modellen | **111.000 / 222.000** |

Die Zeile in B kam mit `refresh=False` **und** `refresh=True`, also auch auf dem Pfad,
den der Desktop wirklich nimmt (`probe_current_custom_provider=True`) — das
`claude-code://`-Schema löst keine Sonde und keine Verzögerung aus. `slug` bleibt
`claude-code-mcp`, `name` wird zum Gruppentitel.

**Der echte Wechsel**, TUI über ein Pseudo-Terminal, ein Zug, `/model fable`, noch ein Zug:

```
A  10:55:44  WARNING … Could not determine context length for model 'fable' … 256,000
   10:55:44  Model switched in-place: haiku (claude-code-mcp) -> fable (claude-code-mcp)

B  10:57:48  Model switched in-place: haiku (claude-code-mcp) -> fable (claude-code-mcp)
             (keine Rückfallmeldung)
```

**Belegt:** Der Block überlebt den Laufzeitwechsel. Er ist damit genau die Ergänzung zu
`model.context_length`, das beim Wechsel gelöscht wird
(`agent/agent_runtime_helpers.py:1963-1964`) und anschließend über
`get_custom_provider_context_length` neu hergeleitet wird (`:2017`).
`hermes_cli/config_providers.py:312` mischt den `providers:`-Block dafür in dieselbe
Liste wie `custom_providers`.

**Eine Zahl aus dem Lauf beweist es unabhängig von der Log-Meldung.** In B meldete der
Prompt-Aufbau: *„Context file AGENTS.md TRUNCATED: 29556 chars exceeds limit of 26640"*.
Die Grenze ist `context_length × 4 × 0,06` (`agent/prompt_builder.py:1036-1041`):
111.000 × 0,24 = **26.640**. In A blieb dieselbe Datei unbeanstandet, weil 256.000 ×
0,24 = 61.440 reichte. Der Block wirkte also auch schon beim **Kaltstart**.

**Eine Warnung bleibt trotzdem stehen** und ist irreführend: „Could not determine context
length for model 'haiku' … falling back to 256,000" erschien in B beim Start, obwohl das
Fenster nachweislich 111.000 war. Nachgestellt: **derselbe Aufruf ohne
`custom_providers` erzeugt genau diese Zeile** und liefert 256.000, mit Liste den Wert
aus dem Block.
Es gibt solche Aufrufer (`agent/auxiliary_client.py:3975`); welcher beim Start
protokollierte, habe ich nicht bestimmt. Die maßgeblichen Pfade
(`agent/agent_init.py:1822`, `agent/context_compressor.py:1782`) reichen die Liste
durch — und die Zeichengrenze oben beweist, dass dort der richtige Wert ankam.

Der Wechsel lief durch das Plugin, nicht daran vorbei:

```
[client] spawn … --model fable --tools '' …
run_agent: claude-code-mcp client created from provider profile (switch_model, shared=True)
```

Rohdaten: `probes/lauf13-modellauswahl.log`. Danach zurückgebaut: Profil
`cc-pick-probe` gelöscht.

**Nicht gemessen:** der Klick im Desktop selbst — der Wechsel wurde als `/model fable`
getippt. Beide Wege landen im selben `switch_model`; die Oberfläche schickt
`provider.slug` plus Modell (`use-model-controls.ts:188`).

## Kosten

Die Einzelläufe lagen meist zwischen 0,02 und 0,06 USD; die gesamte Prüfleiter
inklusive der Kanban-Karte blieb unter 1 USD. Der Ausreißer steht in Lauf 13: ein
einziger Fable-Zug mit kaltem Cache kostete **0,60 USD**, derselbe Zug in Durchgang B
mit warmem Cache (30.136 von 30.138 Token) nur **0,009 USD** — der Faktor 68 ist das
beste Argument für den residenten Betrieb, das dieses Protokoll enthält. `--max-budget-usd` war **nicht** gesetzt
(so entschieden) — die Zahlen sind deshalb Messwerte, keine Obergrenzen.
