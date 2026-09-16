# 04 — Claude Code als Hermes-Provider

Ein Provider-Plugin, das die lokale **Claude-Code-CLI zum Modell eines
Hermes-Profils** macht. Das Profil `claude-dev` läuft damit vollständig über
`claude` — die Orchestrierungsschleife eingeschlossen.

Das ist **Weg B** aus
[`00-hermes-FAQ/Hermes-Claude-Code-Integration.md`](../00-hermes-FAQ/Hermes-Claude-Code-Integration.md),
umgesetzt mit dem MCP-Kniff aus Weg D: Hermes' Werkzeuge erreichen Claude Code über
einen Schema-only-MCP-Server statt als Text im Prompt mit Regex-Rückparsing.

## Kurzreferenz — Modell aktivieren und prüfen

**Opus mit 1M-Kontextfenster**

```bash
hermes -p claude-dev config set model.default "opus[1m]"
hermes -p claude-dev config set model.context_length 1000000
```

**Sonnet mit 1M-Kontextfenster**

```bash
hermes -p claude-dev config set model.default "sonnet[1m]"
hermes -p claude-dev config set model.context_length 1000000
```

**Ohne 1M** (Standardfenster; `sonnet` ohne Suffix bekommt **kein** 1M)

```bash
hermes -p claude-dev config set model.default sonnet
hermes -p claude-dev config set model.context_length 200000
```

**Modellauswahl im Desktop** — passiert seit 15.09.2026 **automatisch bei der
Installation**, für das Root-Home und jedes genannte Profil:

```bash
./install.sh claude-dev developer          # Plugin + Modellauswahl, ohne zu aktivieren
./install.sh --no-model-picker claude-dev  # nur das Plugin
```

Danach bietet das Auswahlfeld `sonnet[1m]`, `opus[1m]`, `haiku` und `fable` an; die
beiden `[1m]`-Einträge bringen ihr 1M-Fenster selbst mit. Rückbau: `./uninstall.sh` —
oder gezielt `hermes -p claude-dev config unset providers.claude-code-mcp`.

> **Der `providers:`-Block aktiviert nichts.** Er lässt `model.default` und
> `model.provider` unberührt und füllt nur die Liste; `get_provider` bleibt
> `source=plugin-profile`, `auth_type=external_process` (Lauf 13 in
> [`VERIFIKATION.md`](VERIFIKATION.md)). Umgestellt wird weiterhin ausschließlich
> mit `./switch-profile.sh <profil>`.
>
> Bis 15.09.2026 übersprang `--with-model-picker` jedes Home, das nicht ohnehin
> schon auf `claude-code-mcp` stand — der Provider ließ sich also genau dort nicht
> auswählen, wo man ihn erst noch auswählen wollte. Die Option wird weiterhin
> akzeptiert (sie ist jetzt der Standard), neu ist `--no-model-picker`.
>
> **Nebeneffekt:** `hermes config set` schreibt die `config.yaml` neu und verliert
> dabei auskommentierte Hilfetexte (gemessen 22–38 Zeilen je Datei). Lebende
> Schlüssel bleiben vollständig — per Diff über alle fünf Homes geprüft, keine
> einzige Nicht-Kommentarzeile verloren.

**Prüfen**

```bash
hermes -p claude-dev config get model                        # beide Schlüssel ansehen
hermes -p claude-dev config get providers.claude-code-mcp    # der Auswahl-Block
```

Im Chat `/model` — dort muss `Context: 1,000,000 tokens` stehen. Steht dort `256,000`,
wurde `model.context_length` verworfen (siehe die vier Regeln unten).

**Vier Regeln, an denen es sonst scheitert**

1. **Immer beide Zeilen.** `[1m]` schaltet Claude Codes 1M-Beta ein,
   `model.context_length` sagt es Hermes. Eine allein genügt nicht.
2. **In der Shell mit Anführungszeichen** — `[1m]` ist für zsh ein Glob-Muster.
3. **Im Chat ohne Anführungszeichen, dafür mit `--global`**: `/model opus[1m] --global`.
   Hermes zerlegt die Zeile per `split()` ohne Quote-Entfernung, und ohne `--global`
   gilt der Wechsel nur für die Sitzung — wobei `model.context_length` dabei entfällt.
4. **Alles klein.** `Opus[1m]` ≠ `opus[1m]`; bei Abweichung fällt das Fenster still auf
   256.000 zurück. Die Großschreibung in der Desktop-App ist nur Anzeige.

**Modellwechsel per Auswahlfeld statt per Befehl:** `./install.sh --with-model-picker
claude-dev` trägt einen `providers:`-Block ein — danach bietet der Auswähler vier
Modelle an, und die beiden `[1m]`-Einträge bringen ihr Kontextfenster selbst mit (siehe
[Modellauswahl im Desktop](#modellauswahl-im-desktop-dropdown)). Regel 3 entschärft sich
damit **für genau diese Einträge**: deren Fenster überlebt auch einen sitzungsweiten
Wechsel. Für jedes Modell, das nicht im Block steht — etwa ein voll qualifiziertes
`claude-opus-5` —, gilt Regel 3 unverändert.

**Danach die Desktop-Sitzung neu starten** — das Kontextfenster wird bei der
Agent-Initialisierung aufgelöst und beim Live-Wechsel sogar gelöscht
(`agent_runtime_helpers.py:1963-1964`). Das Modell allein zöge ohne Neustart nach, das
Fenster nicht. Kanban-Worker starten je Karte frisch und brauchen nichts.

| Datei | Inhalt |
|---|---|
| [TUTORIAL.md](TUTORIAL.md) | Einbau, Betrieb, Stellschrauben, Fehlersuche, Rückbau |
| [VERIFIKATION.md](VERIFIKATION.md) | Was am Quelltext belegt ist, was nur durch Läufe — und was **nicht** |
| [RUN-PROTOKOLL.md](RUN-PROTOKOLL.md) | Die dreizehn gemessenen Läufe mit Rohdaten |
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

### Vier Reichweiten — alle belegt (Lauf 9)

| Was | Wie | Gilt für |
|---|---|---|
| Profil | `hermes -p claude-dev config set model.default opus` | alles auf diesem Profil |
| Ein Aufruf | `hermes -p claude-dev -m fable -z "…"` | nur diesen Aufruf |
| Laufende Sitzung | `/model fable` im TUI | ab dem nächsten Zug dieser Sitzung |
| Einzelne Karte | `hermes kanban set-model <task-id> fable` | diesen einen Worker (`none` löscht es) |

⚠ `/model` funktioniert **nur interaktiv**. Als `-z`-Prompt übergeben, geht es als
Text ans Modell, statt umzuschalten.

### Das 1M-Kontextfenster (`opus[1m]`)

Zwei Seiten, beide nötig:

```bash
hermes -p claude-dev config set model.default "opus[1m]"   # Shell: Quotes Pflicht (zsh-Glob)
hermes -p claude-dev config set model.context_length 1000000
```

Das Suffix versorgt **Claude Code** (die Sitzung läuft dann als `claude-opus-5[1m]`);
`model.context_length` versorgt **Hermes**, das sonst 256.000 schätzt.

**`[1m]` ist die Aktivierung, kein Etikett.** Im CLI-Binary stehen das Modell-Flag
`supports_1m_beta`, der Header `ANTHROPIC_BETAS` und der Beta-Bezeichner
`context-1m-2025-08-07`; die CLI schreibt selbst *„…, or `/model sonnet[1m]` for a 1M
context window"* und kennt für Modelle ohne die Fähigkeit die Meldung *„has no 1M
form"*. Ohne Suffix wird der Beta-Header nicht gesetzt — plain `sonnet` bekommt also
**kein** 1M, egal was in der Konfiguration steht.

Das löst auch einen scheinbaren Widerspruch: Hermes' eigene Tabelle
(`agent/model_metadata.py`) führt `claude-sonnet-5` mit 1.000.000, die CLI verlangt
trotzdem das Suffix. Beide haben recht — die Tabelle beschreibt die **Fähigkeit** des
Modells, das Suffix ist die **Aktivierung**. Für ein Profil zählt die Aktivierung.

⚠ `model.context_length` wird still verworfen, wenn das aktive Modell nicht exakt
`model.default` entspricht — ein sitzungsweites `/model opus[1m]` ohne `--global` reicht
also nicht, und `Opus[1m]` ≠ `opus[1m]`. Gemessen in Lauf 10.

Was das bringt: Hermes komprimiert bei `compression.threshold: 0.5` erst ab
`context_length × 0.5` — also ab ~128.000 statt der geschätzten 256.000, und mit 1M erst
ab ~500.000. In Lauf 11 mit identischem Gespräch gemessen: 64k-Fenster komprimierte
(66.685 → 20.217 Token), 200k-Fenster nicht (61.182 blieben stehen).

⚠ Das ist keine Gratis-Verbesserung: später komprimieren heißt mehr Token je Zug. Im
selben Test kostete die Variante mit großem Fenster rund 0,14 USD je Fortsetzung gegen
0,02 USD bei kleinem. Und unter 64.000 nimmt Hermes den Wert gar nicht erst an.

**Die Desktop-App zeigt `Opus[1m]` mit großem O — das ist Kosmetik.** Das Bundle
verschönert jeden Modellnamen für die Anzeige (`charAt(0).toUpperCase()+e.slice(1)`);
in der `config.yaml` steht weiter `opus[1m]`. Für Claude Code wäre die Großschreibung
ohnehin egal (beide Varianten laufen), für Hermes' Vergleich zählt der Dateiinhalt.

⚠ Ungeprüft: ob der Modell-Auswähler der Desktop-App den kanonischen Namen
zurückschreibt oder die angezeigte, großgeschriebene Fassung. Nach einem Wechsel über
den Auswähler lohnt ein `hermes -p claude-dev config get model` — landete `Opus[1m]`
in der Datei und wäre das aktive Modell anders geschrieben, fiele `context_length`
still auf 256.000 zurück.

### Modellauswahl im Desktop (Dropdown)

Ohne Zutun steht im Auswahlfeld genau ein Eintrag: `claude-code-mcp`. Das ist kein
Modell, sondern die aktuelle Auswahl, die der Desktop selbst erzeugt und mit dem
**Slug** beschriftet (`lib/chat-runtime.ts:384`) — der Provider liefert null Modelle,
und Gruppen ohne Modelle werden verworfen (`components/model-picker.tsx:278`).

Der Grund liegt tiefer und ist **nicht** durch Plugin-Felder zu beheben: Ein
Plugin-Provider mit `auth_type="external_process"` wird von der Auto-Erweiterung der
kanonischen Providerliste ausdrücklich übersprungen
(`hermes_cli/models_catalog_static.py:361-363`), und der generische Katalogabruf bedient
nur `auth_type == "api_key"` (`hermes_cli/models.py:1390`). Das `fallback_models` im
Profil erreicht den Auswähler deshalb nie. Auch **mehrere registrierte Profile**
(`claude-code-opus`, `claude-code-sonnet`, …) ändern daran nichts — sie wären nur
weitere Provider-IDs für `/model` und die Konfiguration.

Was wirkt, ist ein `providers:`-Block im Profil — sechs Zeilen Konfiguration, kein
Eingriff ins Plugin:

```yaml
providers:
  claude-code-mcp:
    name: Claude Code CLI (MCP)     # Titel der Gruppe im Auswähler
    base_url: claude-code://cli     # muss zu model.base_url passen
    api_mode: chat_completions
    models:
      "sonnet[1m]": {context_length: 1000000}
      "opus[1m]":   {context_length: 1000000}
      "haiku": {}                   # in der Auswahl, ohne Fenster-Übersteuerung
      "fable": {}
```

Ein Modell darf leer bleiben (`{}`): es erscheint in der Auswahl, und Hermes löst sein
Fenster weiter selbst auf. Das ist für `haiku` und `fable` die richtige Wahl — ohne
Eintrag schätzt Hermes 256.000, ein kleinerer erfundener Wert würde ihr Fenster also
still **verkleinern**.

`install.sh --with-model-picker` schreibt genau diesen Block in jedes Profil, das den
Provider benutzt; ohne die Option bleibt die Konfiguration unangetastet.

**Der eigentliche Gewinn ist nicht das Dropdown, sondern die zweite Spalte.** Ein
`/model`-Wechsel zur Laufzeit löscht `model.context_length`
(`agent_runtime_helpers.py:1963-1964`) und leitet das Fenster danach aus genau diesem
Block neu her (`:2017`, über `hermes_cli/config_providers.py:312`). Damit trägt jedes
**im Block aufgeführte** Modell sein Fenster selbst — für sie entfällt die Einschränkung
aus dem Abschnitt oben („`/model` ohne `--global` verliert das Fenster"). Für alles
andere, etwa ein voll qualifiziertes `claude-opus-5`, gilt sie weiter.

In Lauf 13 gemessen, mit absichtlich ungewöhnlichen Zahlen: ohne Block fielen `haiku`
und `fable` beide auf 256.000 zurück, mit Block lösten sie 111.000 bzw. 222.000 auf —
auch über den Laufzeitwechsel hinweg.

⚠ Eine Warnung bleibt im Protokoll stehen und ist irreführend: *„Could not determine
context length for model 'haiku' … falling back to 256,000"* erscheint auch dann, wenn
das Fenster nachweislich aus dem Block kam. Nachgestellt: derselbe Aufruf **ohne**
`custom_providers` erzeugt genau diese Zeile — solche Aufrufer gibt es
(`agent/auxiliary_client.py:3975`). Die maßgeblichen Pfade
(`agent/agent_init.py:1822`, `agent/context_compressor.py:1782`) reichen die Liste
durch. Verlassen Sie sich auf die Zahl, nicht auf die Warnung.

**Prüfen und zurückbauen**

```bash
hermes -p claude-dev config get providers.claude-code-mcp    # was eingetragen ist
hermes -p claude-dev config unset providers.claude-code-mcp  # gezielt entfernen
```

`./uninstall.sh` nimmt den Block ohnehin mit; `--keep-profile` lässt ihn stehen — dann
bietet die Auswahl vier Modelle eines entfernten Providers an. Eine Änderung wird erst
nach einem Neustart der Desktop-Sitzung sichtbar.

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

### Wann es greift — zur Laufzeit, nicht erst beim Neustart

Modell und Denktiefe werden **je Zug** ausgewertet. Jeder Hermes-Zug startet einen
eigenen `claude`-Prozess, und dessen `--model`/`--effort` kommen aus dem, was Hermes
*für diesen Zug* übergibt. Ein Wechsel greift also ab dem nächsten Zug — ohne Neustart
von Gateway, Desktop-App oder sonst etwas.

Gemessen (Lauf 8), drei aufeinanderfolgende Züge auf **einer** Client-Instanz:

| angefordert | argv | Modell laut CLI |
|---|---|---|
| `haiku` + `low` | `--model haiku --effort low` | `claude-haiku-4-5-20251001` |
| `fable` + `max` | `--model fable --effort max` | `claude-fable-5-1` |
| `haiku` + `medium` | `--model haiku --effort medium` | `claude-haiku-4-5-20251001` |

Auch eine Änderung an `agent.reasoning_effort` in der `config.yaml` greift ohne
Neustart: der Rückfallpfad hängt seinen Zwischenspeicher an der mtime der Datei.

Zwei Dinge ändern sich **nicht** mitten im Lauf:

- **Innerhalb eines Zuges.** Läuft der `claude`-Prozess schon (etwa zwischen zwei
  Werkzeug-Umläufen), bleibt sein Modell bis zum Ende des Zuges.
- **Der Plugin-Code selbst.** `providers/__init__.py` merkt sich seine Erkennung
  (`_discovered`); nach `./install.sh` braucht ein laufender Gateway bzw. eine offene
  Desktop-Sitzung einen Neustart. Das betrifft den *Code*, nicht die Einstellungen.

Gemessen (Lauf 7): `--model opus --effort xhigh` → `claude-opus-5`;
`--model fable --effort max` → `claude-fable-5-1`. Beide Modelle nannten ihre ID selbst.

## Schnellstart

```bash
./install.sh claude-dev                       # Plugin in Root-Home UND Profil-Home
./switch-profile.sh claude-dev                # sichert, setzt alle vier Modell-Schlüssel
./install.sh --with-model-picker claude-dev   # optional: Modellauswahl im Desktop
hermes gateway restart                        # nur für Kanban-Betrieb nötig
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

**Belegt** (dreizehn protokollierte Läufe): Einbau, Profilumstellung, interaktiver Lauf,
Werkzeug-Umlauf mit Hermes' echtem 25-Werkzeug-Satz, eine Kanban-Karte Ende zu Ende;
Modell und Denktiefe über alle vier Umschaltwege (`model.default`, `-m`, `/model`,
`kanban set-model`), zur Laufzeit und ohne Neustart; das 1M-Kontextfenster auf beiden
Seiten, samt Nachweis, dass ein größeres Fenster die Kompression wirklich nach hinten
schiebt; und dass ein `providers:`-Block im Profil die Modellauswahl im Desktop füllt
und das Kontextfenster je Modell über den Laufzeitwechsel rettet.

**Offen** und ausdrücklich als solches vermerkt: echt paralleles Ausspielen mehrerer
Werkzeuge in *einer* Modellantwort, Sitzungsfortsetzung über Hermes-Züge (`--resume`
ist nicht umgesetzt), Token-Zahlen auf Werkzeug-Runden (dort meldet der Client Nullen),
`delegate_task`-Auffächerung ohne Budgetgrenze, und ob der Desktop-Modellauswähler den
kanonischen Modellnamen zurückschreibt. Die vollständige Liste steht in
[VERIFIKATION.md](VERIFIKATION.md).

Zu den Nutzungsbedingungen: Es startet der **offizielle** Client — die stärkere
Position als geliehene Zugangsdaten, aber keine Freigabe. Ob der offizielle Client,
gesteuert von einem fremden Harness, gedeckt ist, hat Anthropic nicht entschieden.
Die Einschätzung bleibt beim Betreiber.
