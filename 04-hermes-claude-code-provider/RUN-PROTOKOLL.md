# Run-Protokoll

Alle Läufe vom **13.09.2026**, macOS, Hermes Agent v0.20.0 (2026.8.3),
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

## Kosten

Die Einzelläufe lagen zwischen 0,02 und 0,06 USD; die gesamte Prüfleiter inklusive
der Kanban-Karte blieb deutlich unter 1 USD. `--max-budget-usd` war **nicht** gesetzt
(so entschieden) — die Zahlen sind deshalb Messwerte, keine Obergrenzen.
