# Plan: Orchestrator-Profil für Kanban-Triage

**Stand:** 2026-09-14 · **Version:** Hermes Agent **v0.21.2 (2026.9.11)**, macOS
**Status:** umgesetzt — alle acht Schritte ausgeführt, Lauf vollständig
durchlaufen und protokolliert (Abschnitt 8)

> ⚠ **Versionsabweichung zur Repo-Konvention.** `CLAUDE.md` schreibt das Repo auf
> v0.20.0 (2026.8.3) fest. Die installierte Version ist aber **v0.21.2
> (2026.9.11)** (`hermes --version`, Install-Methode `git`). Sämtliche
> Zeilenangaben in diesem Plan stammen aus dem Quellcode dieser
> installierten Version unter `~/.hermes/hermes-agent/` — sie sind gegen
> v0.21.2 belegt, **nicht** gegen v0.20.0.

**Ziel:** Ein Profil `orchestrator` (OpenRouter, `deepseek/deepseek-v4-flash-0731`),
das eine Aufgabe analysiert und sie als eine oder mehrere Karten — parallel
und/oder sequentiell — auf dem Kanban-Board anlegt, jede Karte dem passenden
installierten Profil zugeordnet. Auslöser: Zuweisung per Chat oder eine Karte
in der Spalte **Triage**.

---

## 1. Der wichtigste Befund zuerst

Hermes v0.20.0 hat den gewünschten Mechanismus **bereits eingebaut** — als
Triage-Decomposer. Aber: was als *ein* „Orchestrator-Profil" gedacht ist, sind
im Code **drei getrennte Dinge**:

| # | Hermes-Ding | Was es tut | Ist ein Profil? |
|---|---|---|---|
| 1 | `auxiliary.kanban_decomposer` | Liest die Triage-Karte, erzeugt den JSON-Graph aus Kindkarten, wählt Assignees | **Nein** — ein einzelner LLM-Call, kein Agent, keine Tools |
| 2 | `kanban.orchestrator_profile` | Besitzt die **Wurzelkarte** *nach* dem Fan-out; wacht auf, wenn alle Kinder fertig sind | **Ja** — echtes Profil mit Modell |
| 3 | Toolset `kanban` am Profil, **pro Plattform** | Der Chat-Weg (Abschnitt 4): alle 14 `kanban_*`-Tools, u. a. `kanban_create`, `kanban_list`, `kanban_unblock` | **Ja** — Tools am Profil |

Stelle 1 + 2 sind der **Triage-Weg** (Schritte 4–6), Stelle 3 der
**Chat-/Telegram-Weg** (Schritt 3, ausführlich in Abschnitt 4). Beide Wege
erzeugen Karten, teilen aber außer der Board-Datenbank keinerlei Konfiguration.

`config_defaults.py:1741` sagt das explizit:
*„Does not control the decomposer LLM path (see auxiliary.kanban_decomposer)."*

**Konsequenz für das Zielbild:** Eine Karte in Triage wird vom **Aux-LLM**
zerlegt — unabhängig davon, wem sie zugewiesen ist. Der Satz „jede Aufgabe, die
dem Orchestrator in Triage zugewiesen wird, wird von ihm analysiert" stimmt im
*Ergebnis*, aber nicht im *Mechanismus*. Damit „der Orchestrator analysiert"
wirklich zutrifft, muss das deepseek-Modell an **Stelle 1** eingetragen werden,
nicht nur als Profil.

### Wie der Decomposer arbeitet

`kanban_decompose.py:36` ff. — der System-Prompt verlangt genau das, was
gefordert war:

- `fanout: true` → 2–6 Kindkarten, jede mit `title`, `body`, `assignee`,
  `parents` (0-basierte Indizes in dieselbe Liste).
- **Parallel** = Karte ohne `parents`. **Sequentiell** = Karte mit `parents`,
  wartet bis jeder Parent `done` ist. Der Prompt sagt ausdrücklich
  „Prefer parallelism".
- `fanout: false` → genau **eine** Karte, nur mit geschärftem Spec und
  konkretem Assignee (identisch zum Verhalten von `specify`).

Damit ist „bei einfachen Aufgaben nur 1 Karte, bei komplexeren mehrere"
bereits das eingebaute Verhalten — es braucht keine eigene Logik.

Die Wurzelkarte bleibt als Parent aller Kinder am Leben und wacht auf, wenn der
Graph fertig ist (`kanban_decompose.py:8`) — dann kann das Profil aus Stelle 2
die Fertigstellung beurteilen und weitere Arbeit nachlegen.

---

## 2. Wo die Konfiguration hingehört — **nicht** ins Profil

Der Decomposer läuft im Gateway-Dispatcher (`kanban.dispatch_in_gateway: true`).
`_load_routing()` → `_load_config()` → `load_config()` **ohne Profilargument**
(`kanban_decompose.py:129`), und `get_config_path()` (`config.py:469`) löst über
`get_hermes_home()` auf.

Das ist hier **`~/.hermes/config.yaml`** — dort steht der `kanban:`-Block bereits
(Zeile 427 ff., mit dem angepassten `dispatch_interval_seconds: 10`),
`orchestrator_profile` und `default_assignee` sind beide noch `''`.

> ⚠ **Fallstrick:** `hermes -p orchestrator config set kanban.orchestrator_profile …`
> würde in eine Datei schreiben, die niemand liest. Und es fällt nicht auf:
> `_resolve_profile_from_cfg` (`kanban_decompose.py:136`) fällt bei leerem oder
> unbekanntem Wert **stumm** auf das aktive Default-Profil zurück. Das Board
> läuft dann mit falschem Owner, ohne jede Fehlermeldung.

Merksatz: **Modell und Toolsets ins Profil (`-p orchestrator`), Routing und
Decomposer in die Root-Config (ohne `-p`).**

---

## 3. Die Schritte

### Schritt 1 — Profil anlegen

Der On-Disk-Name muss lowercase sein (`profiles.py:189`, Regex
`[a-z0-9][a-z0-9_-]{0,63}`) — „Orchestrator" wird zu **`orchestrator`**
normalisiert.

```bash
hermes profile create orchestrator \
  --description "Zerlegt Aufgaben in Kanban-Karten und routet sie an die passenden Profile. Besitzt die Wurzelkarte und ergänzt Arbeit, wenn Kindkarten fertig sind."
```

### Schritt 2 — Modell setzen (die vier Schlüssel aus CLAUDE.md)

Ohne diese existiert keine `config.yaml` im Profil → nicht dispatchbar.

```bash
hermes -p orchestrator config set model.default   deepseek/deepseek-v4-flash-0731
hermes -p orchestrator config set model.provider  openrouter
hermes -p orchestrator config set model.base_url  https://openrouter.ai/api/v1
hermes -p orchestrator config set model.api_mode  chat_completions
```

`OPENROUTER_BASE_URL` verifiziert in `hermes_constants.py:1176`;
`OPENROUTER_API_KEY` ist in `~/.hermes/.env` vorhanden.

### Schritt 3 — Kanban-Toolset freischalten (**pro Plattform**)

`kanban` steht in `_DEFAULT_OFF_TOOLSETS` (`tools_config.py:96`) und ist
ausdrücklich ein **Per-Plattform-Opt-in** („opt-in task board tools for this
platform", `tools_config.py:67`). `kanban_toolset_context.py:24` verlangt die
**explizite** Nennung — „all/default" reicht nicht.

```bash
hermes -p orchestrator config set platform_toolsets.cli      '["hermes-cli","kanban"]'
hermes -p orchestrator config set platform_toolsets.telegram '["hermes-telegram","kanban"]'
```

> ⚠ **Nicht über das Top-Level-`toolsets` gehen.** `tools_config.py:595`:
>
> ```python
> # Legacy profile opt-in is a fallback only. A saved platform list (even
> # empty) is authoritative, so a later disable cannot silently re-enable it.
> if not explicitly_configured and "kanban" in (config.get("toolsets") or []):
>     enabled_toolsets.add("kanban")
> ```
>
> Bei einem **frischen** Profil wirkt dieser Fallback noch — `_seed_model_config`
> (`profiles.py:512`) schreibt ausschließlich `{"model": …}`, also existiert kein
> `platform_toolsets`-Block. Sobald aber jemand einmal `hermes tools` oder die
> Toolset-Seite des Dashboards für das Profil benutzt, wird ein Block
> geschrieben — und ab da ist das Top-Level-`toolsets` wirkungslos. Ohne
> Fehlermeldung. Die vier bestehenden Profile haben genau so einen Block,
> `telegram:` eingeschlossen.

`kanban_create` verlangt `assignee` als Pflichtfeld
(`kanban_tools_schemas.py`, `["title","assignee"]`).

### Schritt 4 — Root-Config: Routing eintragen ← **global, ohne `-p`**

```bash
hermes config set kanban.orchestrator_profile orchestrator
hermes config set kanban.default_assignee     claude-dev
```

### Schritt 5 — Decomposer-Modell auf deepseek pinnen

Das ist der Schritt, der „der Orchestrator analysiert" wahr macht.

```bash
hermes config set auxiliary.kanban_decomposer.provider  openrouter
hermes config set auxiliary.kanban_decomposer.model     deepseek/deepseek-v4-flash-0731
hermes config set auxiliary.kanban_decomposer.base_url  https://openrouter.ai/api/v1
hermes config set auxiliary.kanban_decomposer.reasoning_effort none
```

Die vierte Zeile ist **nicht optional** — ohne sie schlägt die Zerlegung fehl.
`max_tokens` ist in `kanban_decompose.py:320` fest auf 4000 verdrahtet; ein
Reasoning-Modell verbraucht dieses Budget vollständig für Reasoning-Tokens und
liefert null Zeichen Inhalt. Der Fehler lautet dann irreführend
`"LLM returned malformed JSON"`. Real gemessen, siehe Abschnitt 8.

Drei Hinweise:

- **Kein `api_mode`** — der `_aux()`-Block (`config_defaults.py:9`) kennt nur
  `provider, model, base_url, api_key, timeout, extra_body, reasoning_effort`.
  Nur `auxiliary.review` hat zusätzlich `api_mode`.
- **Nicht verwechseln** mit `auxiliary.openrouter_model` + `auxiliary.free_only`
  — das ist die *Auto-Chain-Fallback*-Ebene. Steht `free_only: true`, wird ein
  bezahltes deepseek-Modell übersprungen.

### Schritt 6 — Beschreibungen für die bestehenden Profile ← **nicht optional**

`_build_roster()` (`kanban_decompose.py:155`) rendert Profile ohne Beschreibung
als `⚠ undescribed`, und der System-Prompt sagt ausdrücklich: *„Pick assignees
from the roster by matching the task to the profile's DESCRIPTION (not just the
name)."*

Aktueller Stand: nur `my-test-bot` hat eine `profile.yaml` mit Beschreibung.
**`claude-dev`, `developer`, `summarizer` haben keine** — das Routing wäre blind.

```bash
hermes profile describe --all --auto     # oder je Profil: --text "…"
```

### Schritt 7 — Verifikation ohne Modellkosten

```bash
hermes kanban --board <slug> assignees   # orchestrator muss ON DISK = yes zeigen
hermes config get kanban.orchestrator_profile
hermes config get auxiliary.kanban_decomposer.model
hermes -p orchestrator config get platform_toolsets
hermes -p orchestrator tools             # Checkliste: 📌 Kanban je Plattform aktiv?
```

Die letzten beiden Zeilen decken den Chat-/Telegram-Weg ab (Abschnitt 4); die
ersten drei den Triage-Weg.

### Schritt 8 — Ein kontrollierter Testlauf

Eine Karte von Hand in Triage, dann **manuell** zerlegen:

```bash
hermes kanban create --title "…" --triage
hermes kanban decompose <id>
hermes kanban show <id> --json        # ohne --json bricht v0.20.0 ab
```

Das ist ein Aux-Call, kein Dispatcher-Tick, kein Worker-Spawn — der billigste
echte Test.

> **Aber:** `auto_decompose: true` ist gesetzt, der Dispatcher tickt hier alle
> 10 s und würde die Karte ohnehin von selbst zerlegen (max.
> `auto_decompose_per_tick: 3`). Für einen isolierten manuellen Lauf vorher
> `hermes config set kanban.auto_decompose false` — und hinterher zurücksetzen.

---

## 4. Der zweite Weg: Aufgabe per Chat / Telegram

Der Chat-Weg funktioniert — aber über einen **anderen Mechanismus** als Triage.

### Was dabei passiert

In einer Chat-Session ist `HERMES_KANBAN_TASK` nicht gesetzt. `_visible()`
(`kanban_tools.py:83`) fällt damit auf `_profile_has_kanban_toolset()` zurück,
und das Profil sieht **alle 14 `kanban_*`-Tools** — `kanban_create`,
`kanban_list`, `kanban_unblock` eingeschlossen.

Weil `kanban_show` sichtbar ist, injiziert `agent_init.py:1070` zusätzlich die
`KANBAN_GUIDANCE` in den System-Prompt. Die enthält einen Abschnitt
**„## Orchestrator mode"** (`prompt_builder.py:276`):

> *„use `kanban_create` to fan out into child tasks — one per specialist, each
> with an explicit `assignee` and `parents=[...]` to express dependencies. […]
> Do NOT execute the work yourself; your job is routing, not implementation."*

Der Orchestrator-Auftrag steht also bereits im Prompt; er muss nicht in SOUL.md
nachgebaut werden.

### Der Unterschied zum Triage-Weg

| | Triage-Spalte | Chat / Telegram |
|---|---|---|
| Wer analysiert | `auxiliary.kanban_decomposer` (ein LLM-Call) | Das **Profilmodell selbst**, mit seinen Tools |
| Karten entstehen durch | `decompose_triage_task()`, atomar | Einzelne `kanban_create`-Aufrufe |
| Abhängigkeiten | `parents` als 0-basierte Indizes in die JSON-Liste | `parents` als echte Task-IDs |
| Unbekannter Assignee | wird auf `default_assignee` umgebogen | **wird stumm akzeptiert** (siehe unten) |
| Wurzelkarte | ja, Owner = `kanban.orchestrator_profile` | nein — es entstehen nur die erzeugten Karten |

Damit greifen für den Chat-Weg **weder Schritt 4 noch Schritt 5** des Plans:
`kanban.orchestrator_profile`, `kanban.default_assignee` und
`auxiliary.kanban_decomposer` sind reine Triage-Konfiguration.

### Drei Bedingungen, sonst läuft es stumm ins Leere

**a) `kanban` muss für die Plattform `telegram` freigeschaltet sein.**
Siehe Schritt 3 oben — das ist der Grund, warum dort der explizite
`platform_toolsets`-Eintrag steht und nicht das Top-Level-`toolsets`.

**b) Das Profil braucht einen eigenen Telegram-Bot-Token.**
`create_profile` legt ein Profil ohne jede Channel-Konfiguration an, und ein
geklonter Token ist ausdrücklich unerwünscht: *„a copied bot credential makes
two gateways fight over one bot"* (`profiles.py:809`). Der `telegram:`-Block in
`~/.hermes/config.yaml:389` gehört dem **Root-Profil**, nicht dem Orchestrator.

**c) Ein erfundener Assignee wird stumm verworfen.**
`_handle_create` (`kanban_tools.py:839`) prüft nur, dass `assignee` **nicht leer**
ist — **keine Existenzprüfung des Profils**. Die Karte landet dann für immer in
`ready`. Die `KANBAN_GUIDANCE` warnt selbst davor:

> *„The dispatcher SILENTLY drops a card with an unknown assignee (it sits in
> `ready` forever). Ground every assignee in a real profile (`hermes profile
> list`, or ask the user)"*

Das setzt voraus, dass das Terminal-Toolset für die jeweilige Plattform aktiv
ist — sonst kann das Modell `hermes profile list` gar nicht aufrufen. Schritt 6
(Profilbeschreibungen) hilft hier **nicht**: den Roster bekommt nur der
Decomposer gestellt, der Chat-Weg sieht ihn nie.

### Zusätzlicher Prüfschritt

```bash
# Zeigt die für eine Plattform tatsächlich aufgelösten Toolsets
hermes -p orchestrator config get platform_toolsets
hermes -p orchestrator tools            # Checkliste: 📌 Kanban muss aktiv sein
```

---

## 5. Eine Entscheidung, die offen bleibt

`default_assignee: orchestrator` wäre wörtlich das Gewünschte, hat aber einen
Haken: nicht-routbare Kindkarten landen dann beim Orchestrator, der damit
Leaf-Arbeit statt Orchestrierung macht. Im Plan steht oben `claude-dev`.

---

## 6. Was ich **nicht** verifiziert habe

| Aussage | Warum offen | Wie prüfbar |
|---|---|---|
| ~~`deepseek/deepseek-v4-flash-0731` existiert bei OpenRouter~~ | **Erledigt.** Genau dieser Slug läuft mit denselben vier Schlüsselwerten bereits in `default` und `developer` (`~/.hermes/config.yaml:1-5`) | — (`hermes models` gibt es übrigens nicht; das Unterkommando heißt `hermes model`) |
| ~~`hermes config set platform_toolsets.telegram '[...]'` parst Liste und verschachtelten Schlüssel korrekt~~ | **Erledigt.** Geschrieben und nachgemessen, siehe Abschnitt 8 — inklusive der irreführenden Warnung, die dabei erscheint | — |
| ~~`hermes-telegram` ist der korrekte Composite-Name~~ | **Erledigt.** `_get_platform_tools(cfg, "telegram")` löst zu 18 Toolsets inkl. `kanban` auf (Abschnitt 8) | — |
| Ein Chat-/Telegram-Lauf legt tatsächlich Karten an | Nur aus Tool-Gating (`kanban_tools.py:83`) und Prompt (`prompt_builder.py:276`) abgeleitet, nie ausgeführt | Testlauf mit einer harmlosen Aufgabe, danach `hermes kanban list` |
| ~~Das Terminal-Toolset ist unter Telegram aktiv~~ | **Erledigt.** `terminal` ist in der aufgelösten Telegram-Liste enthalten (Abschnitt 8) | — |
| Das Gateway läuft tatsächlich mit `HERMES_HOME` = Root | Aus dem Code zwingend, am laufenden Prozess aber nicht nachgemessen | `hermes gateway status` bzw. Prozess-Env prüfen |
| ~~Der Dispatcher dispatcht **keine** Karten in Triage an ihren Assignee~~ | **Erledigt.** Die Testkarte lag unassigned in Triage und wurde nicht dispatcht, sondern zerlegt (Abschnitt 8) | — |
| ~~Verhalten der Wurzelkarte nach Abschluss aller Kinder~~ | **Erledigt.** Sie wachte auf, wurde an `orchestrator` dispatcht und lief 1m 41s (Abschnitt 8) | — |
| ~~Ein Chat-/Telegram-Lauf legt tatsächlich Karten an~~ | **Weiterhin offen** — dieser Lauf belegt nur den Triage-Weg. Der Chat-Weg (Abschnitt 4) ist unverändert ungeprüft, und das Profil hat noch keinen Telegram-Bot-Token | `hermes -p orchestrator chat`, danach `hermes kanban list` |

---

## 7. Umfang

Alles davon ändert **`~/.hermes/`** (echtes Profil, globale Config, Board) —
nichts im Repo außer diesem Plan. Eine Story unter `02-…/` wäre ein separater
Schritt und ist hier bewusst nicht angelegt.

**Belege:** Quellcode der installierten Version unter
`~/.hermes/hermes-agent/`, zitiert als `datei.py:zeile`. Die Online-Doku war
keine Quelle.

---

## 8. Umsetzungsprotokoll (2026-09-14)

Ausgeführt gegen **v0.21.2**. Board: `default`. Alle Schritte real gemessen.

### Was ohne Zutun schon stimmte

**Schritt 2 war ein No-op.** `_seed_model_config` (`profiles.py:512`) kopiert den
Modellblock des Root-Profils in das neue Profil — und der enthält bereits exakt
die vier gewünschten Werte. Die vier `config set`-Aufrufe aus Schritt 2 sind
damit überflüssig; `deepseek/deepseek-v4-flash-0731` ist über `default` und
`developer` ohnehin als funktionierender Slug belegt.

Das frische Profil hatte erwartungsgemäß **weder** `platform_toolsets` **noch**
ein Top-Level-`toolsets` — die Analyse aus Schritt 3 trifft zu.

### Eine irreführende Warnung bei Schritt 3

`hermes -p orchestrator config set platform_toolsets.telegram '[...]'` schreibt
korrekt, meldet aber:

```
⚠ 'platform_toolsets.telegram' is not a recognized config key — it was saved
  anyway, but Hermes may not read it.  Did you mean: platform_hints.telegram
```

**Das ist ein Fehlalarm.** `platform_toolsets` steht nicht in `DEFAULT_CONFIG`,
wird von `_get_platform_tools` aber sehr wohl gelesen. Nachgemessen:

```
cli       kanban aktiv: True
telegram  kanban aktiv: True
   browser, clarify, code_execution, computer_use, connections, cronjob,
   delegation, file, image_gen, kanban, memory, session_search, skills,
   terminal, todo, tts, vision, web
```

`terminal` ist enthalten — die Voraussetzung für `hermes profile list` aus
Bedingung (c) in Abschnitt 4 ist damit erfüllt.

### Der eigentliche Stolperstein: leere Antwort des Decomposers

Nach den Schritten 1–7 blieb die Triage-Karte liegen. `hermes kanban decompose`
lieferte:

```json
{"task_id": "t_e27d3131", "ok": false, "reason": "LLM returned malformed JSON"}
```

Denselben Aufruf nachgestellt (`call_llm(task="kanban_decomposer", …,
max_tokens=4000)`):

```
finish_reason: length | len(raw): 0
```

**`finish_reason: length` bei null Zeichen Inhalt.** Das Modell hat das gesamte
Budget für Reasoning-Tokens verbraucht, bevor überhaupt Inhalt begann.
`max_tokens=4000` ist in `kanban_decompose.py:320` **fest verdrahtet** und über
keinen Konfigurationsschlüssel erreichbar — die einzige Stellschraube ist das
Reasoning selbst:

```bash
hermes config set auxiliary.kanban_decomposer.reasoning_effort none
```

Danach derselbe Aufruf:

```
finish_reason: stop | len: 3275 | parst: True | fanout: True, 3 tasks
```

> **Merksatz:** Ein Reasoning-Modell am `kanban_decomposer` braucht
> `reasoning_effort: none` (oder `minimal`). Sonst frisst das Reasoning die
> fest verdrahteten 4000 Tokens auf, und der Fehler, den man zu sehen bekommt,
> lautet irreführend „malformed JSON" — nicht „leere Antwort" oder „Limit
> erreicht". Der Schlüssel fehlte in den Schritten 1–7 und gehört dort dazu.

### Das Ergebnis der Zerlegung

Der Gateway-Dispatcher war mit seinem 10-Sekunden-Takt schneller als der
manuelle Aufruf und hat die Karte selbst zerlegt — das belegt den
`auto_decompose`-Pfad gleich mit:

| Karte | Status | Assignee | Parents |
|---|---|---|---|
| `t_e27d3131` (Wurzel) | todo | **orchestrator** | — |
| `t_cc896ed5` Implement csvstats.py | running | developer | `[]` |
| `t_6552cccb` pytest-Tests | todo | developer | `[t_cc896ed5]` |
| `t_d0f7b317` README.md | todo | summarizer | `[t_cc896ed5]` |

Damit sind auf einen Schlag belegt:

- **Schritt 4** — die Wurzelkarte gehört `orchestrator`, also greift
  `kanban.orchestrator_profile` aus der Root-Config.
- **Schritt 5** — die Zerlegung lief über das gepinnte deepseek-Modell
  (Gateway-Log: `Auxiliary kanban_decomposer: using openrouter
  (deepseek/deepseek-v4-flash-0731)`).
- **Schritt 6** — das Routing folgte den Beschreibungen, nicht den Namen:
  Implementierung und Tests an `developer`, die README an `summarizer`.
- **Das Graph-Muster aus Abschnitt 1** — die Implementierung hat keinen Parent
  und läuft zuerst; Tests und README hängen beide an ihr und laufen danach
  **parallel**. Sequentiell und parallel in einem Graphen, wie beschrieben.

### Korrektur am Verifikationsbefehl

`hermes models list` gibt es nicht — das Unterkommando heißt `hermes model`.
Die Modellfrage ist ohnehin anders geklärt (siehe oben).

### Der vollständige Lauf

| Karte | Assignee | Laufzeit | Ergebnis |
|---|---|---|---|
| `t_cc896ed5` Implementierung | developer | 18m 38s | `csvstats.py`, 6129 B, stdlib-only |
| `t_6552cccb` Tests | developer | 6m 39s | `test_csvstats.py`, 15 Tests |
| `t_d0f7b317` README | summarizer | 1m 33s | `README.md`, 2789 B |
| `t_e27d3131` Wurzel | **orchestrator** | 1m 41s | konsolidiert, Abnahme geprüft |

Die beiden abhängigen Karten liefen **gleichzeitig**, sobald die
Implementierung `done` war — sequentiell gegenüber dem Parent, parallel
zueinander, genau wie der Graph es vorgab.

Abnahme selbst nachgeprüft (nicht aus der Zusammenfassung übernommen):
`python3 -m pytest -q` → **15 passed**.

### Geschwisterkarten koordinieren sich über einen Kommentar, nicht über den Workspace

Naheliegende Fehlannahme: die Kinder erbten den Workspace des Parents. Sie tun
es **nicht**. `_insert_decomposed_child` (`kanban_db_graph.py:176-193`) vererbt
den Pfad nur, wenn die Wurzel schon einen hat — eine frisch per
`hermes kanban create --triage` angelegte Karte hat `workspace_path = None`.
Jedes Kind bekam folglich ein eigenes Scratch-Verzeichnis.

Nachgemessen: `csvstats.py` lag in beiden Workspaces inhaltlich identisch, im
README-Workspace aber mit **fünf Minuten jüngerem** mtime — der zweite Worker
hat sie sich selbst geholt. Möglich war ihm das, weil der erste Worker einen
`kanban_comment` hinterlassen hatte, der die beiden Folgekarten namentlich
adressiert und die Design-Entscheidungen festhält („eindeutig zählt den
Leerwert als eigene Kategorie", „numerisch nur bei lückenloser Spalte").

Das ist exakt das, was die `KANBAN_GUIDANCE` verlangt: *„Every child card body
must carry the decisions it depends on, because workers cannot see sibling
context."* Wer eine Story darauf aufbaut, muss den Handoff also in den
Kartentext schreiben — auf einen geteilten Workspace ist kein Verlass.

### ⚠ Nach `done` sind die Workspaces weg

Nach Abschluss aller Karten war
`~/.hermes/kanban/workspaces/` **vollständig leer** — Scratch-Workspaces werden
aufgeräumt (`_REMOVABLE_KINDS`, `kanban_db_workspace.py:22`; der Kommentar bei
Zeile 24 nennt die Bedingung: kein Kind mehr aktiv).

Erhalten bleibt nur, was ein Worker über `kanban_complete(artifacts=[…])`
anhängt. Hier hat die Wurzelkarte neun Anhänge bekommen:

```
/Users/aknipschild/.hermes/kanban/attachments/t_e27d3131/
  csvstats.py  test_csvstats.py  README.md  sample.csv
```

Dort läuft `pytest` weiterhin grün (15 passed). **Für eine Story heißt das:
Ergebnisse gehören in `artifacts`, nicht in den Workspace** — sonst ist das
Erzeugnis nach dem letzten `done` unwiederbringlich.
