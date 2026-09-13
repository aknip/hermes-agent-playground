# 04 — Claude Code als Hermes-Provider

Ein Provider-Plugin, das die lokale **Claude-Code-CLI zum Modell eines
Hermes-Profils** macht. Das Profil `claude-dev` läuft damit vollständig über
`claude` — die Orchestrierungsschleife eingeschlossen.

Das ist **Weg B** aus
[`00-hermes-FAQ/Hermes-Claude-Code-Integration.md`](../00-hermes-FAQ/Hermes-Claude-Code-Integration.md),
umgesetzt mit dem MCP-Kniff aus Weg D: Hermes' Werkzeuge erreichen Claude Code über
einen Schema-only-MCP-Server statt als Text im Prompt mit Regex-Rückparsing.

| Datei | Inhalt |
|---|---|
| [TUTORIAL.md](TUTORIAL.md) | Einbau, Betrieb, Stellschrauben, Fehlersuche, Rückbau |
| [VERIFIKATION.md](VERIFIKATION.md) | Was am Quelltext belegt ist, was nur durch Läufe — und was **nicht** |
| [RUN-PROTOKOLL.md](RUN-PROTOKOLL.md) | Die sieben gemessenen Läufe mit Rohdaten |
| [`plugin/`](plugin/) | Der Master. `install.sh` leitet die Kopien nach `~/.hermes/` ab |
| [`probes/`](probes/) | Gesäuberte Protokolle der Läufe |

## Modell und Denktiefe

Beides steuert **Hermes**, nicht das Plugin. Das Plugin reicht nur durch und bildet
auf Claude Codes Flags ab.

```bash
hermes -p claude-dev config set model.default opus            # -> claude --model opus
hermes -p claude-dev config set agent.reasoning_effort xhigh  # -> claude --effort xhigh
```

### Modelle

Alles, was `claude --model` annimmt:

| Schreibweise | Beispiele |
|---|---|
| Öffentliche Aliase | `sonnet`, `opus`, `fable`, `haiku` |
| Voll qualifiziert | `claude-opus-5`, `claude-sonnet-5`, `claude-fable-5-1`, `claude-haiku-4-5-20251001` |
| Mit 1M-Kontextfenster | `opus[1m]` — das Suffix bleibt erhalten, es ist für Claude Code bedeutungstragend |

Ein vorangestelltes `anbieter/` (Hermes' Aggregator-Schreibweise) schneidet das Plugin
ab, `claude-code-mcp/opus` wird also zu `opus`. Ein Name, den die CLI nicht kennt,
scheitert dort mit `unrecognized_model` — das Plugin prüft ihn nicht vorab.

### Denktiefe

Hermes kennt sieben Stufen (`hermes_constants.py:927`), Claude Codes `--effort` fünf.
Die Enden werden zusammengefaltet:

| `agent.reasoning_effort` | `--effort` |
|---|---|
| `minimal`, `low` | `low` |
| `medium` *(Vorgabe des Profils)* | `medium` |
| `high` | `high` |
| `xhigh` | `xhigh` |
| `max`, `ultra` | `max` |
| `none`, `false` | `low` — Claude Code kennt kein Abschalten |

Die gültigen Stufen stammen aus der CLI selbst: ein unbekannter Wert meldet
*„Valid values: low, medium, high, xhigh, max"* und fällt auf die Vorgabe zurück.

### Drei Reichweiten

| Was | Wie | Gilt für |
|---|---|---|
| Profil | `hermes -p claude-dev config set model.default opus` | alles auf diesem Profil |
| Sitzung | `/model` in der laufenden Sitzung | nur diese Sitzung |
| Einzelne Karte | `hermes kanban set-model <task-id> fable` | diesen einen Worker (`none` löscht es) |

### Vorrang

**Hermes → Umgebungsvariable → Vorgabe** (`sonnet`, `medium`).

`HERMES_CLAUDE_CODE_MODEL` und `HERMES_CLAUDE_CODE_EFFORT` greifen also nur, wenn
Hermes nichts übergibt. Bewusst so herum: liefe die Umgebung vor, würde ein vergessenes
`export` jede Profiländerung still schlucken — genau der Fehler, den dieses Plugin bis
Lauf 7 selbst hatte.

Reasoning erreicht den Client über den dokumentierten Provider-Haken
`build_api_kwargs_extras` (`providers/base.py`). Der ist nötig, weil dieser Client die
Transport-Schicht überspringt (`HERMES_SKIP_TRANSPORT_WRAP`) und `reasoning_config`
sonst nirgends ankäme; als Rückfall liest der Client `agent.reasoning_effort` direkt
aus der `config.yaml` des Profils.

### Wann es greift

Beim **Prozessstart**. Eine Änderung wirkt ab dem nächsten `hermes -p … -z …`; für
Kanban-Worker braucht es `hermes gateway restart`, für eine offene Desktop-Sitzung
deren Neustart.

Gemessen (Lauf 7): `--model opus --effort xhigh` → die CLI fuhr `claude-opus-5`;
`--model fable --effort max` → `claude-fable-5-1`. Beide Modelle nannten ihre ID selbst.

## Schnellstart

```bash
./install.sh claude-dev          # Plugin in Root-Home UND Profil-Home
./switch-profile.sh claude-dev   # sichert, setzt alle vier Modell-Schlüssel
hermes gateway restart           # nur für Kanban-Betrieb nötig
hermes -p claude-dev -z "Lies notiz.txt und nenne mir das Geheimwort."
```

Rückbau: `./uninstall.sh claude-dev` (vorher `DRY_RUN=1` zum Nachsehen).

## Die zwei Entscheidungen, die das Ganze tragen

**`--tools ""` — Claude Code bekommt keine eigenen Werkzeuge.** Gemessen: die
`system/init`-Zeile listet danach ausschließlich `mcp__hermes__*`, kein `Read`, kein
`Edit`, kein `Bash`. Damit läuft jede Ausführung über Hermes zurück — mit Hermes'
Approvals, Logging und Kanban-Semantik. Die Werkzeugkollision, vor der
`agent/acp_openai_bridge.py` warnt, entsteht gar nicht erst; die dort nötige
`allowlist` entfällt.

**Der MCP-Aufruf blockiert, statt abzubrechen.** `pi-claude-cli` bricht die CLI nach
dem Werkzeugvorschlag ab und baut die Sitzung neu auf — `pi-claude-bridge` beziffert
das mit ~58 % Cache-Verlust. Hier wartet der MCP-Server, bis Hermes geliefert hat, und
dieselbe CLI-Sitzung macht weiter. Real gemessen: 90 s Blockade halten; 1259 gelesene
Cache-Token im residenten Betrieb gegen 0 im stateless.

## Der teuerste Befund

**Ein Hermes-Profil ist sein eigenes `HERMES_HOME`.** `hermes -p claude-dev` setzt es
auf `~/.hermes/profiles/claude-dev` (`hermes_cli/main.py:435`,
`hermes_constants.py:102`), und `providers._user_plugins_dir()` sucht unter
`$HERMES_HOME/plugins/model-providers/`. Ein nur nach `~/.hermes/plugins/` gelegtes
Provider-Plugin ist für jedes benannte Profil unsichtbar und endet in
`Unknown provider` (`hermes_cli/auth.py:1471`).

Die FAQ nennt nur den Root-Pfad — das gilt allein für das Standardprofil. `install.sh`
rollt deshalb in beide Homes aus und prüft beide einzeln nach.

## Stand

Belegt: Einbau, Profilumstellung, interaktiver Lauf, Werkzeug-Umlauf mit Hermes'
echtem 25-Werkzeug-Satz, eine Kanban-Karte Ende zu Ende.

Offen und ausdrücklich als solches vermerkt: echt paralleles Ausspielen mehrerer
Werkzeuge in einem Zug, Sitzungsfortsetzung über Hermes-Züge (`--resume` ist nicht
umgesetzt), Token-Zahlen auf Werkzeug-Runden, Kosten im Dauerbetrieb. Die vollständige
Liste steht in [VERIFIKATION.md](VERIFIKATION.md).

Zu den Nutzungsbedingungen: Es startet der **offizielle** Client — die stärkere
Position als geliehene Zugangsdaten, aber keine Freigabe. Ob der offizielle Client,
gesteuert von einem fremden Harness, gedeckt ist, hat Anthropic nicht entschieden.
Die Einschätzung bleibt beim Betreiber.
